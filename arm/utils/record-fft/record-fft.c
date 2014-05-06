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
**  File:         record-fft.c
**  Author(s):    Jonathon Pendlum (jon.pendlum@gmail.com)
**  Description:  Record FFT data from CRASH
**
******************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>
#include <time.h>
#include <math.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <string.h>
#include <getopt.h>
#include <crash-kmod.h>
#include <libcrash.h>

int main (int argc, char **argv) {
  int c;
  int i;
  bool interrupt_flag = false;
  uint fft_size = 0;
  uint number_samples = 0;
  uint decim_rate = 0;
  double gain = 0.0;
  struct crash_plblock *usrp_intf;
  struct crash_plblock *spec_sense;

  // Parse command line arguments
  while (1) {
    static struct option long_options[] = {
      /* These options don't set a flag.
         We distinguish them by their indices. */
      {"interrupt",   no_argument,       0, 'i'},
      {"fft size",    required_argument, 0, 'k'},
      {"decim",       required_argument, 0, 'd'},
      {0, 0, 0, 0}
    };
    /* getopt_long stores the option index here. */
    int option_index = 0;
    // 'n' is the short option, ':' means it requires an argument
    c = getopt_long (argc, argv, "ik:d:",
                     long_options, &option_index);
    /* Detect the end of the options. */
    if (c == -1) break;

    switch (c) {
      case 'i':
        interrupt_flag = true;
        break;
      case 'k':
        fft_size = (uint)ceil(log2((double)atoi(optarg)));
        break;
      case 'd':
        decim_rate = atoi(optarg);
        break;
      case '?':
        /* getopt_long already printed an error message. */
        break;
      default:
        abort ();
    }
  }
  /* Print any remaining command line arguments (not options). */
  if (optind < argc)
  {
    printf ("Invalid options:\n");
    while (optind < argc) {
      printf ("\t%s\n", argv[optind++]);
    }
    return -1;
  }

  // Check arguments
  if (fft_size == 0) {
    printf("INFO: FFT size not specified, defaulting to 256\n");
    fft_size = 8;
  }

  // FFT size cannot be greater than 4096 or less than 64
  if (fft_size > 13 || fft_size < 6) {
    printf("ERROR: FFT size cannot be greater than 4096 or less than 64\n");
    return -1;
  }

  if (decim_rate == 0) {
    printf("INFO: Decimation rate not specified, defaulting to 8\n");
    decim_rate = 8;
  }

  if (decim_rate > 2047) {
    printf("ERROR: Decimation rate too high\n");
    return -1;
  }

  number_samples = (uint)pow(2.0,(double)fft_size);


  usrp_intf = crash_open(USRP_INTF_PLBLOCK_ID,READ);
  if (usrp_intf == 0) {
    printf("ERROR: Failed to allocate usrp_intf plblock\n");
    return -1;
  }

  spec_sense = crash_open(SPEC_SENSE_PLBLOCK_ID,READ);
  if (spec_sense == 0) {
    crash_close(usrp_intf);
    printf("ERROR: Failed to allocate spec_sense plblock\n");
    return -1;
  }

  // Global Reset to get us to a clean slate
  crash_reset(usrp_intf);

  if (interrupt_flag == true) {
    crash_set_bit(usrp_intf->regs,DMA_S2MM_INTERRUPT);
  }

  // Wait for USRP DDR interface to finish calibrating (due to reset). This is necessary
  // as the next steps recalibrate the interface and are ignored if issued while it is
  // currently calibrating.
  while(!crash_get_bit(usrp_intf->regs,USRP_RX_CAL_COMPLETE));
  while(!crash_get_bit(usrp_intf->regs,USRP_TX_CAL_COMPLETE));

  // Set RX phase
  crash_write_reg(usrp_intf->regs,USRP_RX_PHASE_INIT,RX_PHASE_CAL);
  crash_set_bit(usrp_intf->regs,USRP_RX_RESET_CAL);
  printf("RX PHASE INIT: %d\n",crash_read_reg(usrp_intf->regs,USRP_RX_PHASE_INIT));
  while(!crash_get_bit(usrp_intf->regs,USRP_RX_CAL_COMPLETE));

  // Set TX phase
  crash_write_reg(usrp_intf->regs,USRP_TX_PHASE_INIT,TX_PHASE_CAL);
  crash_set_bit(usrp_intf->regs,USRP_TX_RESET_CAL);
  printf("TX PHASE INIT: %d\n",crash_read_reg(usrp_intf->regs,USRP_TX_PHASE_INIT));
  while(!crash_get_bit(usrp_intf->regs,USRP_TX_CAL_COMPLETE));

  // Set USRP Mode
  while(crash_get_bit(usrp_intf_tx->regs,USRP_UART_BUSY));
  crash_write_reg(usrp_intf_tx->regs,USRP_USRP_MODE_CTRL,CMD_TX_MODE + TX_DAC_RAW_MODE);
  while(crash_get_bit(usrp_intf_tx->regs,USRP_UART_BUSY));
  while(crash_get_bit(usrp_intf_tx->regs,USRP_UART_BUSY));
  crash_write_reg(usrp_intf_tx->regs,USRP_USRP_MODE_CTRL,CMD_RX_MODE + RX_ADC_DSP_MODE);
  while(crash_get_bit(usrp_intf_tx->regs,USRP_UART_BUSY));

  crash_write_reg(usrp_intf->regs, USRP_AXIS_MASTER_TDEST, SPEC_SENSE_PLBLOCK_ID);  // Set tdest to spectrum sense block
  crash_write_reg(usrp_intf->regs, USRP_RX_PACKET_SIZE, number_samples);            // Set packet size
  crash_clear_bit(usrp_intf->regs, USRP_RX_FIX2FLOAT_BYPASS);                       // Do not bypass fix2float
  if (decim_rate == 1) {
    crash_set_bit(usrp_intf->regs, USRP_RX_CIC_BYPASS);                       // Bypass CIC Filter
    crash_set_bit(usrp_intf->regs, USRP_RX_HB_BYPASS);                        // Bypass HB Filter
    crash_write_reg(usrp_intf->regs, USRP_RX_GAIN, 1);                        // Set gain = 1
  } else if (decim_rate == 2) {
    crash_set_bit(usrp_intf->regs, USRP_RX_CIC_BYPASS);                       // Bypass CIC Filter
    crash_clear_bit(usrp_intf->regs, USRP_RX_HB_BYPASS);                      // Enable HB Filter
    crash_write_reg(usrp_intf->regs, USRP_RX_GAIN, 1);                        // Set gain = 1
  // Even, use both CIC and Halfband filters
  } else if ((decim_rate % 2) == 0) {
    crash_clear_bit(usrp_intf->regs, USRP_RX_CIC_BYPASS);                     // Enable CIC Filter
    crash_write_reg(usrp_intf->regs, USRP_RX_CIC_DECIM, decim_rate/2);        // Set CIC decimation rate (div by 2 as we are using HB filter)
    crash_clear_bit(usrp_intf->regs, USRP_RX_HB_BYPASS);                      // Enable HB Filter
    // Offset CIC bit growth. A 32-bit multiplier in the receive chain allows us
    // to scale the CIC output.
    gain = 26.0-3.0*log2(decim_rate/2);
    gain = (gain > 1.0) ? (ceil(pow(2.0,gain))) : (1.0);                      // Do not allow gain to be set to 0
    crash_write_reg(usrp_intf->regs, USRP_RX_GAIN, (uint32_t)gain);           // Set gain
  // Odd, use only CIC filter
  } else {
    crash_clear_bit(usrp_intf->regs, USRP_RX_CIC_BYPASS);                     // Enable CIC Filter
    crash_write_reg(usrp_intf->regs, USRP_RX_CIC_DECIM, decim_rate);          // Set CIC decimation rate
    crash_set_bit(usrp_intf->regs, USRP_RX_HB_BYPASS);                        // Bypass HB Filter
    //
    gain = 26.0-3.0*log2(decim_rate);
    gain = (gain > 1.0) ? (ceil(pow(2.0,gain))) : (1.0);                      // Do not allow gain to be set to 0
    crash_write_reg(usrp_intf->regs, USRP_RX_GAIN, (uint32_t)gain);           // Set gain
  }

  // Set spectrum sense registers
  crash_write_reg(spec_sense->regs, SPEC_SENSE_AXIS_CONFIG_TDATA, fft_size);        // Set FFT size
  crash_set_bit(spec_sense->regs, SPEC_SENSE_AXIS_CONFIG_TVALID);                   // Set FFT size Enable
  crash_write_reg(spec_sense->regs, SPEC_SENSE_OUTPUT_MODE, 1);                     // Output Mode "01": Magnitude / Threshold Data
  crash_write_reg(spec_sense->regs, SPEC_SENSE_AXIS_MASTER_TDEST, DMA_PLBLOCK_ID);  // Set destination of FFT output to DMA plblock
  crash_set_bit(spec_sense->regs, SPEC_SENSE_ENABLE_FFT);                           // Enable FFT

  crash_set_bit(usrp_intf->regs, USRP_RX_ENABLE);                             // Enable RX

  // Read from spectrum sensing plblock
  crash_read(spec_sense, SPEC_SENSE_PLBLOCK_ID, number_samples);

  crash_clear_bit(usrp_intf->regs, USRP_RX_ENABLE);                           // Disable RX

  float *sample = (float*)(spec_sense->dma_buff);

  for (i = 0; i < 64; i++) {
    printf("%2d: %f\n",i,sample[2*i]);    // Lower 32-bits is floating point magnitude of FFT
  }

  // Write number_samples complex samples to file
  FILE *fp = 0;
  fp = fopen("data.txt","w");
  fwrite(sample,number_samples,sizeof(uint64_t),fp);
  fclose(fp);

  crash_close(spec_sense);
  crash_close(usrp_intf);
  return 0;
}