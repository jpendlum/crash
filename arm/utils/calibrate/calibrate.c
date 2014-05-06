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
**  File:         calibrate.c
**  Author(s):    Jonathon Pendlum (jon.pendlum@gmail.com)
**  Description:  Calibrate CRASH-USRP interface
**
******************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>
#include <signal.h>
#include <time.h>
#include <math.h>
#include <sched.h>
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

#define XFER_SIZE 1024

int main (int argc, char **argv) {
  int i;
  int j;
  int rx_phase = 0;
  int tx_phase = 0;
  uint error_matrix[56][56];
  struct crash_plblock *usrp_intf_rx;
  struct crash_plblock *usrp_intf_tx;

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

  //crash_set_bit(usrp_intf_rx->regs,DMA_S2MM_INTERRUPT);
  //crash_set_bit(usrp_intf_tx->regs,DMA_MM2S_INTERRUPT);

  // Wait for USRP DDR interface to finish calibrating (due to reset).
  while(!crash_get_bit(usrp_intf_rx->regs,USRP_RX_CAL_COMPLETE));
  while(!crash_get_bit(usrp_intf_tx->regs,USRP_TX_CAL_COMPLETE));

  // Set USRP Mode
  while(crash_get_bit(usrp_intf_tx->regs,USRP_UART_BUSY));
  crash_write_reg(usrp_intf_tx->regs,USRP_USRP_MODE_CTRL,CMD_TX_MODE + TX_DAC_RAW_MODE);
  while(crash_get_bit(usrp_intf_tx->regs,USRP_UART_BUSY));
  crash_write_reg(usrp_intf_tx->regs,USRP_USRP_MODE_CTRL,CMD_RX_MODE + RX_TX_LOOPBACK_MODE);
  while(crash_get_bit(usrp_intf_tx->regs,USRP_UART_BUSY));

  // Setup RX path
  crash_write_reg(usrp_intf_rx->regs, USRP_AXIS_MASTER_TDEST, DMA_PLBLOCK_ID);  // Set tdest to ps_pl_interface
  crash_write_reg(usrp_intf_rx->regs, USRP_RX_PACKET_SIZE, XFER_SIZE);          // Set packet size
  crash_set_bit(usrp_intf_rx->regs, USRP_RX_FIX2FLOAT_BYPASS);                  // Bypass fix2float
  crash_set_bit(usrp_intf_rx->regs, USRP_RX_CIC_BYPASS);                        // Bypass CIC Filter
  crash_set_bit(usrp_intf_rx->regs, USRP_RX_HB_BYPASS);                         // Bypass HB Filter
  crash_write_reg(usrp_intf_rx->regs, USRP_RX_GAIN, 1);                         // Set gain = 1

  // Setup TX path
  crash_set_bit(usrp_intf_tx->regs, USRP_TX_FIX2FLOAT_BYPASS);                  // Bypass fix2float
  crash_set_bit(usrp_intf_tx->regs, USRP_TX_CIC_BYPASS);                        // Bypass CIC Filter
  crash_set_bit(usrp_intf_tx->regs, USRP_TX_HB_BYPASS);                         // Bypass HB Filter
  crash_write_reg(usrp_intf_tx->regs, USRP_TX_GAIN, 1);                         // Set gain = 1

  volatile uint *rx_sample = (volatile uint*)(usrp_intf_rx->dma_buff);
  volatile uint *tx_sample = (volatile uint*)(usrp_intf_tx->dma_buff);

  for (i = 0; i < XFER_SIZE/4; i++) {
    tx_sample[4*i  ] = 1;//0x1A1B;
    tx_sample[4*i+1] = 3;//0x2A2B;
    tx_sample[4*i+2] = 7;//0x1C1D;
    tx_sample[4*i+3] = 0xF;//0x2C2D;
  }

  for (rx_phase = 280; rx_phase < 560; rx_phase += 10) {
    // Set RX phase
    crash_write_reg(usrp_intf_rx->regs,USRP_RX_PHASE_INIT,rx_phase);
    crash_set_bit(usrp_intf_rx->regs,USRP_RX_RESET_CAL);
    crash_clear_bit(usrp_intf_rx->regs,USRP_RX_RESET_CAL);
    while(!crash_get_bit(usrp_intf_rx->regs,USRP_RX_CAL_COMPLETE));
    for (tx_phase = 180; tx_phase < 560; tx_phase += 10) {
      // Set TX phase
      crash_write_reg(usrp_intf_tx->regs,USRP_TX_PHASE_INIT,tx_phase);
      crash_set_bit(usrp_intf_tx->regs,USRP_TX_RESET_CAL);
      crash_clear_bit(usrp_intf_tx->regs,USRP_TX_RESET_CAL);
      while(!crash_get_bit(usrp_intf_tx->regs,USRP_TX_CAL_COMPLETE));
      // Transmit & receive test pattern
      crash_write(usrp_intf_tx, USRP_INTF_PLBLOCK_ID, XFER_SIZE);
      crash_set_bit(usrp_intf_tx->regs, USRP_TX_ENABLE);                        // Enable TX
      //crash_clear_bit(usrp_intf_rx->regs, USRP_RX_FIFO_RESET);                  // Disable RX FIFO Reset
      crash_set_bit(usrp_intf_rx->regs, USRP_RX_ENABLE);                        // Enable RX
      crash_read(usrp_intf_rx, USRP_INTF_PLBLOCK_ID, XFER_SIZE);
      crash_clear_bit(usrp_intf_tx->regs, USRP_TX_ENABLE);                      // Disable TX
      //crash_set_bit(usrp_intf_rx->regs, USRP_RX_FIFO_RESET);                    // Enable RX FIFO Reset
      //crash_clear_bit(usrp_intf_rx->regs, USRP_RX_ENABLE);                      // Disable RX
      error_matrix[rx_phase/10][tx_phase/10] = 0;
      for (i = 0; i < 32; i++) {
        printf("%08x ",rx_sample[4*i] >> 18);
        printf("%08x ",rx_sample[4*i+2] >> 18);
        printf("%08x ",rx_sample[4*i+1] >> 18);
        printf("%08x\n",rx_sample[4*i+3] >> 18);
      }
      goto done;
      for (i = 0; i < XFER_SIZE/4; i++) {
        if (rx_sample[4*i  ] != 0x1A1B && rx_sample[4*i+2] != 0x1C1D &&
            rx_sample[4*i+1] != 0x2A2B && rx_sample[4*i+3] != 0x2C2D) {
          error_matrix[rx_phase/10][tx_phase/10] += 1;
        }
      }
    }
  }
done:
  //crash_clear_bit(usrp_intf_rx->regs, USRP_RX_ENABLE);                          // Disable RX
  crash_clear_bit(usrp_intf_rx->regs, USRP_TX_ENABLE);                          // Disable TX

  crash_close(usrp_intf_rx);
  crash_close(usrp_intf_tx);

  // Write calibration data
  FILE *fp = 0;
  fp = fopen("calibrate.txt","w");
  fprintf(fp,"Errors per RX / TX phase\n");
  fprintf(fp,"   TX");
  for (i = 0; i < 560; i += 10) {
    fprintf(fp," %3d",i);
  }
  fprintf(fp,"\n");
  fprintf(fp,"RX   ");
  for (i = 0; i < 560; i += 10) {
    fprintf(fp,"----");
  }
  fprintf(fp,"\n");
  for (i = 0; i < 56; i++) {
    fprintf(fp,"%3d |",i);
    for (j = 0; j < 56; j++) {
      fprintf(fp," %3u",error_matrix[i][j]);
    }
    fprintf(fp,"\n");
  }
  fclose(fp);

  return 0;
}