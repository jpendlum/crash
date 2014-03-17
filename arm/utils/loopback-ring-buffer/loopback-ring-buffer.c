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
**                in the USRP and using ring buffers for DMA.
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
  uint number_samples = 0;
  struct crash_plblock *usrp_intf_rx;
  struct crash_plblock *usrp_intf_tx;

  // Parse command line arguments
  while (1) {
    static struct option long_options[] = {
      /* These options don't set a flag.
         We distinguish them by their indices. */
      {"samples",     required_argument, 0, 'n'},
      {0, 0, 0, 0}
    };
    /* getopt_long stores the option index here. */
    int option_index = 0;
    // 'n' is the short option, ':' means it requires an argument
    c = getopt_long (argc, argv, "n:",
                     long_options, &option_index);
    /* Detect the end of the options. */
    if (c == -1) break;

    switch (c) {
        break;
      case 'n':
        number_samples = atoi(optarg);
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
  if (number_samples == 0) {
    printf("INFO: Number of samples not specified, defaulting to 4096\n");
    number_samples = 4096;
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

  // Set USRP Mode
  while(crash_get_bit(usrp_intf_rx->regs,USRP_UART_BUSY));
  crash_write_reg(usrp_intf_rx->regs,USRP_USRP_MODE_CTRL,TX_PASSTHRU_MODE + RX_TX_LOOPBACK_MODE);
  while(crash_get_bit(usrp_intf_rx->regs,USRP_UART_BUSY));

  // Setup RX path
  crash_write_reg(usrp_intf_rx->regs, USRP_AXIS_MASTER_TDEST, DMA_PLBLOCK_ID);  // Set tdest to ps_pl_interface
  crash_write_reg(usrp_intf_rx->regs, USRP_RX_PACKET_SIZE, number_samples);     // Set packet size
  crash_set_bit(usrp_intf_rx->regs, USRP_RX_FIX2FLOAT_BYPASS);                  // Bypass fix2float
  crash_set_bit(usrp_intf_rx->regs, USRP_RX_CIC_BYPASS);                        // Bypass CIC Filter
  crash_set_bit(usrp_intf_rx->regs, USRP_RX_HB_BYPASS);                         // Bypass HB Filter
  crash_write_reg(usrp_intf_rx->regs, USRP_RX_GAIN, 1);                         // Set gain = 1

  // Setup TX path
  // Note: Every plblock type have access to all registers, so we can use usrp_intf_rx here. In the future,
  //       each plblock will only have access to its own registers.
  crash_set_bit(usrp_intf_rx->regs, USRP_TX_FIX2FLOAT_BYPASS);                  // Bypass fix2float
  crash_set_bit(usrp_intf_rx->regs, USRP_TX_CIC_BYPASS);                        // Bypass CIC Filter
  crash_set_bit(usrp_intf_rx->regs, USRP_TX_HB_BYPASS);                         // Bypass HB Filter
  crash_write_reg(usrp_intf_rx->regs, USRP_TX_GAIN, 1);                         // Set gain = 1

  // Create counter
  int *tx_sample = (int*)(usrp_intf_tx->dma_buff);
  for (i = 0; i < 64*number_samples; i++) {
    tx_sample[2*i+1] = i;//cos(2.0*M_PI*(freq/100e6)*i);
    tx_sample[2*i] = i+256;//sin(2.0*M_PI*(freq/100e6)*i);
  }

  crash_write(usrp_intf_tx, number_samples, USRP_INTF_PLBLOCK_ID);

  crash_start_dma(usrp_intf_tx, USRP_INTF_PLBLOCK_ID, 64, number_samples);
  crash_set_bit(usrp_intf_rx->regs, USRP_TX_ENABLE);                            // Enable TX

  crash_start_dma(usrp_intf_rx, USRP_INTF_PLBLOCK_ID, 64, number_samples);
  crash_set_bit(usrp_intf_rx->regs, USRP_RX_ENABLE);                            // Enable TX

  struct dma_buff rx_dma_buff;
  bool no_match = true;
  int timer = 0;
  int runs = 0;
  int j = 0;
  for (runs = 0; runs < 128; runs++) {
    no_match = true;
    while (no_match) {
      rx_dma_buff = crash_get_dma_buffer(usrp_intf_rx,number_samples);
      if (rx_dma_buff.num_words > 0) {
        no_match = false;
        for (i = 0; i < number_samples; i++) {
          if (rx_dma_buff.buff[2*i+1] != j || rx_dma_buff.buff[2*i] != j+256) {
            no_match = true;
          }
        }
      }
      // Timeout
      if (timer > 1000) {
        crash_stop_dma(usrp_intf_rx);
        crash_stop_dma(usrp_intf_tx);
        crash_close(usrp_intf_rx);
        crash_close(usrp_intf_tx);
        printf("Failed to align\n");
        return 0;
      }
      timer++;
    }
    j += number_samples;
  }

  printf("Loopback with ring buffers worked!\n");

  crash_close(usrp_intf_rx);
  crash_close(usrp_intf_tx);
  return 0;
}