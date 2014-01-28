/******************************************************************************
**  This is free software: you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation, either version 3 of the License, or
**  (at your option) any later version.
**
**  This is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**  GNU General Public License for more details.
**
**  You should have received a copy of the GNU General Public License
**  along with this code.  If not, see <http://www.gnu.org/licenses/>.
**
**
**
**  File:         zynq_crush_example.vhd
**  Author(s):    Jonathon Pendlum (jon.pendlum@gmail.com)
**  Dependencies:
**
**  Description:
**
******************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#include <libudev.h>
#include <unistd.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <string.h>

// Macros to read / write registers
#define READ_REG(reg,offset,n)          ((reg >> offset) & ((1 << n) - 1))
#define GET_BIT(reg,bit)                ((reg >> bit) & 1)
#define WRITE_REG(reg,val,offset,n)     reg = (reg & ~(((1 << n)-1) << offset)) | ((val & ((1 << n)-1)) << offset)
#define SET_BIT(reg,bit)                reg = (reg | (1 << bit))
#define CLEAR_BIT(reg,bit)              reg = (reg & ~(1 << bit))

// The kernel driver allocates 2^17 bytes (2^15 addressable) for control registers
// and 2^10*4096 bytes for data.
#define NUM_REGISTERS           256
#define RX_PHASE_CAL            460
#define TX_PHASE_CAL            467

// USRP Modes
// RX modes (lower nibble)
#define RX_ADC_RAW_MODE         0x0
#define RX_ADC_DSP_MODE         0x1
#define RX_SINE_TEST_MODE       0x2
#define RX_TEST_PATTERN_MODE    0x3
#define RX_ALL_1s_MODE          0x4
#define RX_ALL_0s_MODE          0x5
#define RX_CHA_1s_CHB_0s_MODE   0x6
#define RX_CHA_0s_CHB_1s_MODE   0x7
#define RX_CHECK_ALIGN_MODE     0x8
#define RX_TX_LOOPBACK_MODE     0x9
// TX modes (upper nibble)
#define TX_PASSTHRU_MODE        (0x0 << 4)
#define TX_DAC_RAW_MODE         (0x1 << 4)
#define TX_DAC_DSP_MODE         (0x2 << 4)
#define TX_SINE_TEST_MODE       (0x3 << 4)

#define RX_SAMPLES_OFFSET       0
#define CTRL_DATA_OFFSET        8192

long read_fpga_status();
static int get_params_from_sysfs(uint32_t *buffer_length, uint32_t *control_length, uint32_t *phys_addr);
int open_driver(int *fd, uint32_t *buffer_length, uint32_t *control_length, uint32_t *phys_addr,
    uint32_t **control_regs, uint32_t **buff);
int close_driver(int fd, uint32_t buffer_length, uint32_t control_length, uint32_t *control_regs,
    uint32_t *buff);
void ctrl_c(int dummy);

// Global variable used to kill final loop
int kill_prog = 0;

int main()
{
    int fd;
    uint32_t buffer_length;
    uint32_t control_length;
    uint32_t phys_addr;
    uint32_t *control_regs;
    uint32_t *buff;
    uint64_t *buffer;
    uint32_t number_of_words;
    int i = 0;

    printf("\n");
    printf("Read the FPGA status... \n");
    if (read_fpga_status() != 1)
    {
        printf("FPGA not programmed!\n");
        return(0);
    }
    printf("Setup the driver... \n");
    open_driver(&fd,&buffer_length,&control_length,&phys_addr,&control_regs,&buff);
    // ACP bus is 64 bits wide, so use appropriate sized variable
    buffer = (uint64_t *)buff;
    // Buffer length is in bytes
    buffer_length = buffer_length/sizeof(uint64_t);
    printf("\n");
    printf("Control Registers Address: \t%p\n",control_regs);
    printf("Control Registers Length: \t%x\n",control_length);
    printf("Buffer Address: \t\t%p\n",buffer);
    printf("Buffer Length: \t\t\t%x\n",buffer_length);

    // Setup control / status registers
    // Each accelerator has 256 banks of 32-bit registers, although the vast majority
    // are not used.
    // There are two kinds of registers: control and status.
    // Control registers can be written to and their current state read.
    // Status registers can only be read, all writes are ignored.
    // Each accelerator has its own map of control / status registers.
    // Accelerator 0 is reserved for the PS PL interface.
    // Accelerator 127 is reserved for global registers.
    uint32_t *ps_pl_interface_reg = &control_regs[0*NUM_REGISTERS];
    uint32_t *usrp_ddr_intf_reg = &control_regs[1*NUM_REGISTERS];
    uint32_t *spectrum_sense_reg = &control_regs[2*NUM_REGISTERS];
    uint32_t *bpsk_mod_reg = &control_regs[3*NUM_REGISTERS];
    uint32_t *global_reg = &control_regs[127*NUM_REGISTERS];

    // Check readback word to see if all is well
    printf("Readback Word: \t\t\t%08x",ps_pl_interface_reg[10]);
    if (ps_pl_interface_reg[10] == 0xca11ab1e) {
        printf(" (Valid)\n");
    }
    else
    {
        printf(" (Invalid)\n");
        printf("Exiting due to invalid readback word.");
        close_driver(fd,buffer_length,control_length,control_regs,buff);
        return(0);
    }

    // Global Reset
    SET_BIT(global_reg[0],0);
    CLEAR_BIT(global_reg[0],0);
    // Set AXI CACHE and USER Signals. This affects if AXI transfers will access the L2 cache.
    WRITE_REG(global_reg[1],7,3,4);    // ARCACHE: "1111"
    WRITE_REG(global_reg[1],31,7,5);    //  ARUSER: "11111"
    WRITE_REG(global_reg[1],7,15,4);   // AWCACHE: "1111"
    WRITE_REG(global_reg[1],31,19,5);   //  AWUSER: "11111"

    // Wait for USRP DDR interface to finish calibrating (due to reset). This is necessary
    // as the next steps recalibrate the interface and are ignored if issued while it is
    // currently calibrating.
    while(GET_BIT(usrp_ddr_intf_reg[3],3) == 1);

    // Set RX phase
    WRITE_REG(usrp_ddr_intf_reg[6],RX_PHASE_CAL,1,10);
    SET_BIT(usrp_ddr_intf_reg[6],0);
    while(GET_BIT(usrp_ddr_intf_reg[3],3) == 1);

    // Set TX phase
    WRITE_REG(usrp_ddr_intf_reg[6],TX_PHASE_CAL,17,10);
    SET_BIT(usrp_ddr_intf_reg[6],16);
    while(GET_BIT(usrp_ddr_intf_reg[3],4) == 1);

    // Set USRP Mode
    while(GET_BIT(usrp_ddr_intf_reg[7],7) == 1);
    WRITE_REG(usrp_ddr_intf_reg[1],TX_DAC_RAW_MODE + RX_ADC_DSP_MODE,0,8);
    while(GET_BIT(usrp_ddr_intf_reg[7],7) == 1);

    // Transmit tone
    for (i = 0; i < 4095; i++) {
        buffer[i] = (0LL << 32) + 2000LL;
    }

    WRITE_REG(ps_pl_interface_reg[2],phys_addr,0,32);   // Set buffer address
    WRITE_REG(ps_pl_interface_reg[3],4096*8,0,23);      // Number of bytes to send
    WRITE_REG(ps_pl_interface_reg[3],1,23,3);           // Set slave / accelerator to transfer to (tdest)
    SET_BIT(ps_pl_interface_reg[3],31);                 // Push CMD to MM2S CMD FIFO

    // Wait for awhile so TX buffers
    // AXI MM2S transfers are only at about 250 MB/sec (or 32M Floating Point I/Q Samples/sec)
    // TODO: Should be able to do better than that
    for (i = 0; i < 1000; i++) {
      asm("nop");
    }

    // Transmit enable, bypass float2fix and interp = 1 and gain = 1
    SET_BIT(usrp_ddr_intf_reg[2],24);           // Bypass float2fix
    WRITE_REG(usrp_ddr_intf_reg[3],1,16,13);    // Set interp = 1
    WRITE_REG(usrp_ddr_intf_reg[5],1,0,25);     // Set gain = 1
    SET_BIT(usrp_ddr_intf_reg[0],1);            // Enable TX

    // Receive signal
    SET_BIT(ps_pl_interface_reg[1],0);                          // Enable interrupt on successful s2mm transfer
    WRITE_REG(ps_pl_interface_reg[4],phys_addr+4096*8,0,32);    // Set buffer address
    WRITE_REG(ps_pl_interface_reg[5],4096*8,0,23);              // Number of bytes to send
    WRITE_REG(ps_pl_interface_reg[5],1,23,3);                   // Set master / accelerator to transfer from (tid)
    SET_BIT(ps_pl_interface_reg[5],31);                         // Push CMD to S2MM CMD FIFO
    // Receive enable, bypass fix2float and decim = 1 and gain = 1
    WRITE_REG(usrp_ddr_intf_reg[2],4096,0,23);  // Set packet size
    CLEAR_BIT(usrp_ddr_intf_reg[2],23);         // Do not bypass fix2float
    WRITE_REG(usrp_ddr_intf_reg[3],1,0,13);     // Set decim = 1
    WRITE_REG(usrp_ddr_intf_reg[4],1,0,25);     // Set gain = 1
    SET_BIT(usrp_ddr_intf_reg[0],0);            // Enable RX
    read(fd,0,0);

    float *sample = (float*)(&buffer[4096]);

    printf("I:\tQ:\n");
    for (i = 0; i < 31; i++) {
        printf("%f\t%f\n",(sample[2*i+1]), (sample[2*i]));
    }

    // Write 4096 complex samples to file
    FILE *fp = 0;
    fp = fopen("data.txt","w");
    fwrite(sample,4096,sizeof(uint64_t),fp);
    fclose(fp);

    // Global Reset
    SET_BIT(global_reg[0],0);
    CLEAR_BIT(global_reg[0],0);

    close_driver(fd,buffer_length,control_length,control_regs,buff);

    return(0);
}

int open_driver(
    int *fd,
    uint32_t *buffer_length,
    uint32_t *control_length,
    uint32_t *phys_addr,
    uint32_t **control_regs,
    uint32_t **buff)
{
    // open the file descriptor to our kernel module
    const char* dev = "/dev/user_peripheral";

    // Open with read / write access and block until write has completed
    *fd = open(dev, O_RDWR|O_SYNC);
    if (*fd == 0)
    {
        printf("Failed to open %s\n",dev);
        perror("");
        return(-1);
    }

    // Get user peripheral parameters
    if (get_params_from_sysfs(buffer_length, control_length, phys_addr) != 0)
    {
        close(*fd);
        return(-1);
    }

    // mmap the control and data regions into virtual space
    *control_regs = (uint32_t*)mmap(NULL, *control_length, PROT_READ|PROT_WRITE, MAP_SHARED, *fd, 0x1000);
    if (control_regs == MAP_FAILED)
    {
        perror("Error mapping control_regs");
        close(*fd);
        return(-1);
    }

    *buff = (uint32_t*)mmap(NULL, *buffer_length, PROT_READ|PROT_WRITE, MAP_SHARED, *fd, 0x2000);
    if (buff == MAP_FAILED)
    {
        perror("Error mapping buff");
        close(*fd);
        return(-1);
    }

    // zero out the data region
    memset((void *)*buff, 0, (uint32_t)(*buffer_length));
    return(0);
}

int close_driver(
    int fd,
    uint32_t buffer_length,
    uint32_t control_length,
    uint32_t *control_regs,
    uint32_t *buff)
{
    munmap(control_regs,control_length);
    munmap(buff,buffer_length);
    close(fd);
    return(0);
}

long read_fpga_status()
{
    struct udev *udev;
    struct udev_enumerate *enumerate;
    struct udev_list_entry *device;
    struct udev_device *dev;
    const char *path;
    long prog_done = 0;

    udev = udev_new();
    if (!udev) {
        printf("ERROR: Failed udev_new()\n");
        return -1;
    }

    // Enumerate devcfg
    enumerate = udev_enumerate_new(udev);
    udev_enumerate_add_match_sysname(enumerate, "f8007000.ps7-dev-cfg");
    udev_enumerate_scan_devices(enumerate);
    device = udev_enumerate_get_list_entry(enumerate);

    // Did not find a device, lets try a different name
    if (device == NULL)
    {
        udev_enumerate_add_match_sysname(enumerate, "f8007000.devcfg");
        udev_enumerate_scan_devices(enumerate);
        device = udev_enumerate_get_list_entry(enumerate);
        // No luck, error out
        if (device == NULL)
        {
          printf("ERROR: Did not find xdevcfg!\n");
          return(-1);
        }
    }

    // List should have only one entry
    if (udev_list_entry_get_next(device) != NULL)
    {
        printf("ERROR: Found more than one devcfg device!\n");
        return(-1);
    }

    // Create udev device
    path = udev_list_entry_get_name(device);
    dev = udev_device_new_from_syspath(udev, path);

    prog_done = atol(udev_device_get_sysattr_value(dev, "prog_done"));

    printf("%s/prog_done = %ld\n", udev_device_get_syspath(dev),prog_done);

    udev_enumerate_unref(enumerate);
    udev_unref(udev);

    return(prog_done);
}

static int get_params_from_sysfs(
    uint32_t *buffer_length,
    uint32_t *control_length,
    uint32_t *phys_addr)
{
    struct udev *udev;
    struct udev_enumerate *enumerate;
    struct udev_list_entry *devices, *dev_list_entry;
    struct udev_device *dev;

    udev = udev_new();
    if (!udev) {
        printf("Fail\n");
        return(-1);
    }


    enumerate = udev_enumerate_new(udev);
    udev_enumerate_add_match_sysname(enumerate, "40000000.user_peripheral");
    udev_enumerate_scan_devices(enumerate);
    devices = udev_enumerate_get_list_entry(enumerate);

    udev_list_entry_foreach(dev_list_entry, devices) {
        const char *path;

        path = udev_list_entry_get_name(dev_list_entry);
        dev = udev_device_new_from_syspath(udev, path);

        printf("Sys Path: %s\n", udev_device_get_syspath(dev));

        *buffer_length = atol(udev_device_get_sysattr_value(dev, "xx_buf_len"));
        *control_length = atol(udev_device_get_sysattr_value(dev, "regs_len"));
        *phys_addr = atol(udev_device_get_sysattr_value(dev, "xx_phys_addr"));

        printf("buffer_length = %X\n", *buffer_length);
        printf("control_length = %X\n", *control_length);
        printf("phy_addr = %X\n", *phys_addr);
    }

    udev_enumerate_unref(enumerate);
    udev_unref(udev);

    return(0);
}

void ctrl_c(int dummy)
{
    kill_prog = 1;
    return;
}
