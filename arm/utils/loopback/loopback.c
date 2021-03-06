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
**  File:         loopback.c
**  Author(s):    Jonathon Pendlum (jon.pendlum@gmail.com)
**  Description:  Test transmit and receive by looping back transmit data
**                in the USRP.
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
  uint number_samples = 0;
  uint decim_rate = 0;
  uint interp_rate = 0;
  float freq = 0.0;
  double gain = 0.0;
  struct crash_plblock *usrp_intf_rx;
  struct crash_plblock *usrp_intf_tx;

  // Parse command line arguments
  while (1) {
    static struct option long_options[] = {
      /* These options don't set a flag.
         We distinguish them by their indices. */
      {"interrupt",   no_argument,       0, 'i'},
      {"samples",     required_argument, 0, 'n'},
      {"decim",       required_argument, 0, 'd'},
      {"interp",      required_argument, 0, 'u'},
      {"freq",        required_argument, 0, 'f'},
      {0, 0, 0, 0}
    };
    /* getopt_long stores the option index here. */
    int option_index = 0;
    // 'n' is the short option, ':' means it requires an argument
    c = getopt_long (argc, argv, "in:d:u:",
                     long_options, &option_index);
    /* Detect the end of the options. */
    if (c == -1) break;

    switch (c) {
      case 'i':
        interrupt_flag = true;
        break;
      case 'n':
        number_samples = atoi(optarg);
        break;
      case 'd':
        decim_rate = atoi(optarg);
        break;
      case 'u':
        interp_rate = atoi(optarg);
        break;
      case 'f':
        freq = atof(optarg);
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
  if (number_samples == 0) {
    printf("INFO: Number of samples not specified, defaulting to 4096\n");
    number_samples = 4096;
  }

  if (decim_rate == 0) {
    printf("INFO: Decimation rate not specified, defaulting to 8\n");
    decim_rate = 8;
  }

  if (decim_rate > 2047) {
    printf("ERROR: Decimation rate too high\n");
    return -1;
  }

  if (interp_rate == 0) {
    printf("INFO: Interpolation rate not specified, defaulting to 8\n");
    interp_rate = 8;
  }

  if (interp_rate > 2047) {
    printf("ERROR: Interpolation rate too high\n");
    return -1;
  }

  if (freq == 0.0) {
    printf("INFO: Frequency not specified, defaulting to 1 MHz\n");
    freq = 1e6;
  }

  if ((freq >= 50e6) || (freq <= -50e6)) {
    printf("ERROR: Sampling rate is 100 MSPS, stay within +/-50MHz\n");
    return -1;
  }


  usrp_intf_rx = crash_open(USRP_INTF_PLBLOCK_ID,READ);
  if (usrp_intf_rx == 0) {
    printf("ERROR: Failed to allocate usrp_intf plblock\n");
    return -1;
  }

  usrp_intf_tx = crash_open(USRP_INTF_PLBLOCK_ID,WRITE);
  if (usrp_intf_tx == 0) {
    printf("ERROR: Failed to allocate usrp_intf plblock\n");
    return -1;
  }

  // Global Reset to get us to a clean slate
  crash_reset(usrp_intf_rx);

  if (interrupt_flag == true) {
    crash_set_bit(usrp_intf_rx->regs,DMA_S2MM_INTERRUPT);
    crash_set_bit(usrp_intf_tx->regs,DMA_MM2S_INTERRUPT);
  }

  // Wait for USRP DDR interface to finish calibrating (due to reset). This is necessary
  // as the next steps recalibrate the interface and are ignored if issued while it is
  // currently calibrating.
  while(!crash_get_bit(usrp_intf_rx->regs,USRP_RX_CAL_COMPLETE));
  while(!crash_get_bit(usrp_intf_rx->regs,USRP_TX_CAL_COMPLETE));

  // Set RX phase
  crash_write_reg(usrp_intf_rx->regs,USRP_RX_PHASE_INIT,RX_PHASE_CAL);
  crash_set_bit(usrp_intf_rx->regs,USRP_RX_RESET_CAL);
  printf("RX PHASE INIT: %d\n",crash_read_reg(usrp_intf_rx->regs,USRP_RX_PHASE_INIT));
  while(!crash_get_bit(usrp_intf_rx->regs,USRP_RX_CAL_COMPLETE));

  // Set TX phase
  crash_write_reg(usrp_intf_rx->regs,USRP_TX_PHASE_INIT,TX_PHASE_CAL);
  crash_set_bit(usrp_intf_rx->regs,USRP_TX_RESET_CAL);
  printf("TX PHASE INIT: %d\n",crash_read_reg(usrp_intf_rx->regs,USRP_TX_PHASE_INIT));
  while(!crash_get_bit(usrp_intf_rx->regs,USRP_TX_CAL_COMPLETE));

  // Set USRP TX / RX Modes
  while(crash_get_bit(usrp_intf_tx->regs,USRP_UART_BUSY));
  crash_write_reg(usrp_intf_tx->regs,USRP_USRP_MODE_CTRL,CMD_TX_MODE + TX_PASSTHRU_MODE);
  while(crash_get_bit(usrp_intf_tx->regs,USRP_UART_BUSY));
  while(crash_get_bit(usrp_intf_tx->regs,USRP_UART_BUSY));
  crash_write_reg(usrp_intf_tx->regs,USRP_USRP_MODE_CTRL,CMD_RX_MODE + RX_TX_LOOPBACK_MODE);
  while(crash_get_bit(usrp_intf_tx->regs,USRP_UART_BUSY));

  // Setup RX path
  crash_write_reg(usrp_intf_rx->regs, USRP_AXIS_MASTER_TDEST, DMA_PLBLOCK_ID);  // Set tdest to ps_pl_interface
  crash_write_reg(usrp_intf_rx->regs, USRP_RX_PACKET_SIZE, number_samples);     // Set packet size
  crash_clear_bit(usrp_intf_rx->regs, USRP_RX_FIX2FLOAT_BYPASS);                // Do not bypass fix2float
  if (decim_rate == 1) {
    crash_set_bit(usrp_intf_rx->regs, USRP_RX_CIC_BYPASS);                      // Bypass CIC Filter
    crash_set_bit(usrp_intf_rx->regs, USRP_RX_HB_BYPASS);                       // Bypass HB Filter
    crash_write_reg(usrp_intf_rx->regs, USRP_RX_GAIN, 1);                       // Set gain = 1
  } else if (decim_rate == 2) {
    crash_set_bit(usrp_intf_rx->regs, USRP_RX_CIC_BYPASS);                      // Bypass CIC Filter
    crash_clear_bit(usrp_intf_rx->regs, USRP_RX_HB_BYPASS);                     // Enable HB Filter
    crash_write_reg(usrp_intf_rx->regs, USRP_RX_GAIN, 1);                       // Set gain = 1
  // Even, use both CIC and Halfband filters
  } else if ((decim_rate % 2) == 0) {
    crash_clear_bit(usrp_intf_rx->regs, USRP_RX_CIC_BYPASS);                    // Enable CIC Filter
    crash_write_reg(usrp_intf_rx->regs, USRP_RX_CIC_DECIM, decim_rate/2);       // Set CIC decimation rate (div by 2 as we are using HB filter)
    crash_clear_bit(usrp_intf_rx->regs, USRP_RX_HB_BYPASS);                     // Enable HB Filter
    // Offset CIC bit growth. A 32-bit multiplier in the receive chain allows us
    // to scale the CIC output.
    gain = 26.0-3.0*log2(decim_rate/2);
    gain = (gain > 1.0) ? (ceil(pow(2.0,gain))) : (1.0);                        // Do not allow gain to be set to 0
    crash_write_reg(usrp_intf_rx->regs, USRP_RX_GAIN, (uint32_t)gain);          // Set gain
  // Odd, use only CIC filter
  } else {
    crash_clear_bit(usrp_intf_rx->regs, USRP_RX_CIC_BYPASS);                    // Enable CIC Filter
    crash_write_reg(usrp_intf_rx->regs, USRP_RX_CIC_DECIM, decim_rate);         // Set CIC decimation rate
    crash_set_bit(usrp_intf_rx->regs, USRP_RX_HB_BYPASS);                       // Bypass HB Filter
    //
    gain = 26.0-3.0*log2(decim_rate);
    gain = (gain > 1.0) ? (ceil(pow(2.0,gain))) : (1.0);                        // Do not allow gain to be set to 0
    crash_write_reg(usrp_intf_rx->regs, USRP_RX_GAIN, (uint32_t)gain);          // Set gain
  }

  // Setup TX path
  // Note: Every plblock type have access to all registers, so we can use usrp_intf_rx here. In the future,
  //       each plblock will only have access to its own registers.
  crash_clear_bit(usrp_intf_rx->regs, USRP_TX_FIX2FLOAT_BYPASS);                // Do not bypass fix2float
  if (interp_rate == 1) {
    crash_set_bit(usrp_intf_rx->regs, USRP_TX_CIC_BYPASS);                      // Bypass CIC Filter
    crash_set_bit(usrp_intf_rx->regs, USRP_TX_HB_BYPASS);                       // Bypass HB Filter
    crash_write_reg(usrp_intf_rx->regs, USRP_TX_GAIN, 1);                       // Set gain = 1
  } else if (interp_rate == 2) {
    crash_set_bit(usrp_intf_rx->regs, USRP_TX_CIC_BYPASS);                      // Bypass CIC Filter
    crash_clear_bit(usrp_intf_rx->regs, USRP_TX_HB_BYPASS);                     // Enable HB Filter
    crash_write_reg(usrp_intf_rx->regs, USRP_TX_GAIN, 1);                       // Set gain = 1
  // Even, use both CIC and Halfband filters
  } else if ((interp_rate % 2) == 0) {
    crash_clear_bit(usrp_intf_rx->regs, USRP_TX_CIC_BYPASS);                    // Enable CIC Filter
    crash_write_reg(usrp_intf_rx->regs, USRP_TX_CIC_INTERP, interp_rate/2);     // Set CIC decimation rate (div by 2 as we are using HB filter)
    crash_clear_bit(usrp_intf_rx->regs, USRP_TX_HB_BYPASS);                     // Enable HB Filter
    // Offset CIC bit growth. A 32-bit multiplier in the receive chain allows us
    // to scale the CIC output.
    gain = 20.0-3.0*log2(interp_rate/2);
    gain = (gain > 1.0) ? (ceil(pow(2.0,gain))) : (1.0);                        // Do not allow gain to be set to 0
    crash_write_reg(usrp_intf_rx->regs, USRP_TX_GAIN, (uint32_t)gain);          // Set gain
  // Odd, use only CIC filter
  } else {
    crash_clear_bit(usrp_intf_rx->regs, USRP_TX_CIC_BYPASS);                    // Enable CIC Filter
    crash_write_reg(usrp_intf_rx->regs, USRP_TX_CIC_INTERP, interp_rate);       // Set CIC decimation rate
    crash_set_bit(usrp_intf_rx->regs, USRP_TX_HB_BYPASS);                       // Bypass HB Filter
    //
    gain = 20.0-3.0*log2(interp_rate);
    gain = (gain > 1.0) ? (ceil(pow(2.0,gain))) : (1.0);                        // Do not allow gain to be set to 0
    crash_write_reg(usrp_intf_rx->regs, USRP_TX_GAIN, (uint32_t)gain);          // Set gain
  }

  // Create and Send a CW signal
  int *tx_sample = (int*)(usrp_intf_tx->dma_buff);
  for (i = 0; i < number_samples; i++) {
    tx_sample[2*i+1] = i;//cos(2.0*M_PI*(freq/100e6)*i);
    tx_sample[2*i] = i+256;//sin(2.0*M_PI*(freq/100e6)*i);
  }

  for (i = 0; i < 1e6; i++) {
    asm("nop");
  }

  crash_write(usrp_intf_tx, USRP_INTF_PLBLOCK_ID, number_samples);

  crash_set_bit(usrp_intf_rx->regs, USRP_RX_ENABLE);                            // Enable RX
  crash_set_bit(usrp_intf_rx->regs, USRP_TX_ENABLE);                            // Enable TX

  // Read from usrp_intf
  crash_read(usrp_intf_rx, USRP_INTF_PLBLOCK_ID, number_samples);

  crash_clear_bit(usrp_intf_rx->regs, USRP_RX_ENABLE);                          // Disable RX

  float *rx_sample = (float*)(usrp_intf_rx->dma_buff);

  printf("I:\tQ:\n");
  for (i = 0; i < 31; i++) {
    printf("%f\t%f\n",(rx_sample[2*i+1]), (rx_sample[2*i]));
  }

  // Write number_samples complex samples to file
  FILE *fp = 0;
  fp = fopen("data.txt","w");
  fwrite(rx_sample,number_samples,sizeof(uint64_t),fp);
  fclose(fp);

  crash_close(usrp_intf_rx);
  crash_close(usrp_intf_tx);
  return 0;
}