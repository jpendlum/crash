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
**  File:         fpga-spectrum-sense.c
**  Author(s):    Jonathon Pendlum (jon.pendlum@gmail.com)
**  Description:  Offload spectrum sensing & spectrum decision to the FPGA.
**                Spectrum decision is simple: If all FFT bins are behold
**                the threshold -> transmit.
**
**                Lab setup for this program
**                  Run GNU Radio Companion program that has both a USRP Source and Sink.
**                  USRP Source should be tuned to 130MHz with +30 gain, USRP Sink 75MHz with 0 gain.
**                  The USRP source and sink are necessary as CRASH does not program the USRP.
**                  USRP Input: Pulsed Sinusoid 130.5MHz, -50 dBm, 5 second period, 4.9 sec duty cycle
**                              (i.e. sine wave that is on for 4.9 seconds, off 0.1)
**                  USRP will output a short sine wave pulse, that can be used
**                  to measure the turn around time.
**                  Make sure to check the USRP input / output power levels to not
**
******************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>
#include <signal.h>
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

// Global variable used to kill final loop
int loop_prog = 0;

void ctrl_c(int dummy)
{
    loop_prog = 0;
    return;
}

int main (int argc, char **argv) {
  int c;
  int i;
  bool interrupt_flag = false;
  uint number_samples = 0;
  uint decim_rate = 0;
  uint fft_size = 0;
  float threshold = 0.0;
  uint temp_int;
  float temp_float;
  double gain = 0.0;
  struct crash_plblock *spec_sense;
  struct crash_plblock *usrp_intf_tx;

  // Parse command line arguments
  while (1) {
    static struct option long_options[] = {
      /* These options don't set a flag.
         We distinguish them by their indices. */
      {"interrupt",   no_argument,       0, 'i'},
      {"loop prog",   no_argument,       0, 'l'},
      {"samples",     required_argument, 0, 'n'},
      {"decim",       required_argument, 0, 'd'},
      {"fft size",    required_argument, 0, 'k'},
      {"threshold",   required_argument, 0, 't'},
      {0, 0, 0, 0}
    };
    /* getopt_long stores the option index here. */
    int option_index = 0;
    // 'n' is the short option, ':' means it requires an argument
    c = getopt_long (argc, argv, "ild:k:t:",
                     long_options, &option_index);
    /* Detect the end of the options. */
    if (c == -1) break;

    switch (c) {
      case 'i':
        interrupt_flag = true;
        break;
      case 'l':
        loop_prog = 1;
        break;
      case 'd':
        decim_rate = atoi(optarg);
        break;
      case 'k':
        fft_size = (uint)ceil(log2((double)atoi(optarg)));
        break;
      case 't':
        threshold = atof(optarg);
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

  if (decim_rate == 0) {
    printf("INFO: Decimation rate not specified, defaulting to 1\n");
    decim_rate = 1;
  }

  if (decim_rate > 2047) {
    printf("ERROR: Decimation rate too high\n");
    return -1;
  }

  if (fft_size == 0) {
    printf("INFO: FFT size not specified, defaulting to 256\n");
    fft_size = 8;
  }

  // FFT size cannot be greater than 4096 or less than 64
  if (fft_size > 13 || fft_size < 6) {
    printf("ERROR: FFT size cannot be greater than 4096 or less than 64\n");
    return -1;
  }

  if (threshold == 0.0) {
    printf("INFO: Threshold not set, default to 1.0\n");
    threshold = 1.0;
  }

  number_samples = (uint)pow(2.0,(double)fft_size);

  // Set Ctrl-C handler
  signal(SIGINT, ctrl_c);


  usrp_intf_tx = crash_open(USRP_INTF_PLBLOCK_ID,WRITE);
  if (usrp_intf_tx == 0) {
    printf("ERROR: Failed to allocate usrp_intf_tx plblock\n");
    return -1;
  }

  spec_sense = crash_open(SPEC_SENSE_PLBLOCK_ID,READ);
  if (spec_sense == 0) {
    crash_close(usrp_intf_tx);
    printf("ERROR: Failed to allocate spec_sense plblock\n");
    return -1;
  }

  do {
    // Global Reset to get us to a clean slate
    crash_reset(usrp_intf_tx);

    if (interrupt_flag == true) {
      crash_set_bit(usrp_intf_tx->regs,DMA_MM2S_INTERRUPT);
    }
    // Wait for USRP DDR interface to finish calibrating (due to reset). This is necessary
    // as the next steps recalibrate the interface and are ignored if issued while it is
    // currently calibrating.
    while(!crash_get_bit(usrp_intf_tx->regs,USRP_RX_CAL_COMPLETE));
    while(!crash_get_bit(usrp_intf_tx->regs,USRP_TX_CAL_COMPLETE));

    // Set RX phase
    crash_write_reg(usrp_intf_tx->regs,USRP_RX_PHASE_INIT,RX_PHASE_CAL);
    crash_set_bit(usrp_intf_tx->regs,USRP_RX_RESET_CAL);
    //printf("RX PHASE INIT: %d\n",crash_read_reg(usrp_intf_tx->regs,USRP_RX_PHASE_INIT));
    while(!crash_get_bit(usrp_intf_tx->regs,USRP_RX_CAL_COMPLETE));

    // Set TX phase
    crash_write_reg(usrp_intf_tx->regs,USRP_TX_PHASE_INIT,TX_PHASE_CAL);
    crash_set_bit(usrp_intf_tx->regs,USRP_TX_RESET_CAL);
    //printf("TX PHASE INIT: %d\n",crash_read_reg(usrp_intf_tx->regs,USRP_TX_PHASE_INIT));
    while(!crash_get_bit(usrp_intf_tx->regs,USRP_TX_CAL_COMPLETE));

    // Set USRP TX / RX Modes
    while(crash_get_bit(usrp_intf_tx->regs,USRP_UART_BUSY));
    crash_write_reg(usrp_intf_tx->regs,USRP_USRP_MODE_CTRL,CMD_TX_MODE + TX_DAC_RAW_MODE);
    while(crash_get_bit(usrp_intf_tx->regs,USRP_UART_BUSY));
    while(crash_get_bit(usrp_intf_tx->regs,USRP_UART_BUSY));
    crash_write_reg(usrp_intf_tx->regs,USRP_USRP_MODE_CTRL,CMD_RX_MODE + RX_ADC_DSP_MODE);
    while(crash_get_bit(usrp_intf_tx->regs,USRP_UART_BUSY));

    // Setup RX path
    crash_set_bit(usrp_intf_tx->regs, USRP_RX_FIFO_BYPASS);                       // Bypass RX FIFO so stale data in the FIFO does not cause latency
    crash_write_reg(usrp_intf_tx->regs, USRP_AXIS_MASTER_TDEST, SPEC_SENSE_PLBLOCK_ID);  // Set tdest to spec_sense
    crash_write_reg(usrp_intf_tx->regs, USRP_RX_PACKET_SIZE, number_samples);     // Set packet size
    crash_clear_bit(usrp_intf_tx->regs, USRP_RX_FIX2FLOAT_BYPASS);                // Do not bypass fix2float
    if (decim_rate == 1) {
      crash_set_bit(usrp_intf_tx->regs, USRP_RX_CIC_BYPASS);                      // Bypass CIC Filter
      crash_set_bit(usrp_intf_tx->regs, USRP_RX_HB_BYPASS);                       // Bypass HB Filter
      crash_write_reg(usrp_intf_tx->regs, USRP_RX_GAIN, 1);                       // Set gain = 1
    } else if (decim_rate == 2) {
      crash_set_bit(usrp_intf_tx->regs, USRP_RX_CIC_BYPASS);                      // Bypass CIC Filter
      crash_clear_bit(usrp_intf_tx->regs, USRP_RX_HB_BYPASS);                     // Enable HB Filter
      crash_write_reg(usrp_intf_tx->regs, USRP_RX_GAIN, 1);                       // Set gain = 1
    // Even, use both CIC and Halfband filters
    } else if ((decim_rate % 2) == 0) {
      crash_clear_bit(usrp_intf_tx->regs, USRP_RX_CIC_BYPASS);                    // Enable CIC Filter
      crash_write_reg(usrp_intf_tx->regs, USRP_RX_CIC_DECIM, decim_rate/2);       // Set CIC decimation rate (div by 2 as we are using HB filter)
      crash_clear_bit(usrp_intf_tx->regs, USRP_RX_HB_BYPASS);                     // Enable HB Filter
      // Offset CIC bit growth. A 32-bit multiplier in the receive chain allows us
      // to scale the CIC output.
      gain = 26.0-3.0*log2(decim_rate/2);
      gain = (gain > 1.0) ? (ceil(pow(2.0,gain))) : (1.0);                        // Do not allow gain to be set to 0
      crash_write_reg(usrp_intf_tx->regs, USRP_RX_GAIN, (uint32_t)gain);          // Set gain
    // Odd, use only CIC filter
    } else {
      crash_clear_bit(usrp_intf_tx->regs, USRP_RX_CIC_BYPASS);                    // Enable CIC Filter
      crash_write_reg(usrp_intf_tx->regs, USRP_RX_CIC_DECIM, decim_rate);         // Set CIC decimation rate
      crash_set_bit(usrp_intf_tx->regs, USRP_RX_HB_BYPASS);                       // Bypass HB Filter
      //
      gain = 26.0-3.0*log2(decim_rate);
      gain = (gain > 1.0) ? (ceil(pow(2.0,gain))) : (1.0);                        // Do not allow gain to be set to 0
      crash_write_reg(usrp_intf_tx->regs, USRP_RX_GAIN, (uint32_t)gain);          // Set gain
    }

    // Setup TX path
    crash_clear_bit(usrp_intf_tx->regs, USRP_TX_FIX2FLOAT_BYPASS);                // Do not bypass fix2float
    crash_set_bit(usrp_intf_tx->regs, USRP_TX_CIC_BYPASS);                        // Bypass CIC Filter
    crash_set_bit(usrp_intf_tx->regs, USRP_TX_HB_BYPASS);                         // Bypass HB Filter
    crash_write_reg(usrp_intf_tx->regs, USRP_TX_GAIN, 1);                         // Set gain = 1

    // Create a CW signal
    float *tx_sample = (float*)(usrp_intf_tx->dma_buff);
    for (i = 0; i < 4095; i++) {
      tx_sample[2*i+1] = 0;
      tx_sample[2*i] = 0.5;
    }
    tx_sample[2*4095+1] = 0;
    tx_sample[2*4095] = 0;

    // Load waveform into TX FIFO so it can immediately trigger
    crash_write(usrp_intf_tx, USRP_INTF_PLBLOCK_ID, 4096);

    // Setup Spectrum Sense
    crash_write_reg(spec_sense->regs,SPEC_SENSE_OUTPUT_MODE,3);                   // Throw away FFT output
    crash_write_reg(spec_sense->regs,SPEC_SENSE_AXIS_CONFIG_TDATA,fft_size);      // FFT Size
    crash_set_bit(spec_sense->regs,SPEC_SENSE_AXIS_CONFIG_TVALID);                // FFT Size Enable
    crash_set_bit(spec_sense->regs,SPEC_SENSE_ENABLE_FFT);                        // Enable FFT
    crash_clear_bit(spec_sense->regs,SPEC_SENSE_AXIS_CONFIG_TVALID);
    //crash_set_bit(spec_sense->regs,SPEC_SENSE_ENABLE_THRESH_SIDEBAND);            // Enable sideband threshold exceeded output (to trigger TX)
    crash_set_bit(spec_sense->regs,SPEC_SENSE_ENABLE_NOT_THRESH_SIDEBAND);        // Enable sideband threshold NOT exceeded output (to trigger TX)
    memcpy(&temp_int,&threshold,sizeof(float));                                   // Copy float value to an int without a cast
    crash_write_reg(spec_sense->regs,SPEC_SENSE_THRESHOLD,temp_int);              // Threshold level in single precision floating point


    crash_set_bit(usrp_intf_tx->regs,USRP_RX_ENABLE);                             // Enable RX

    i = 0;
    while(crash_get_bit(spec_sense->regs,SPEC_SENSE_THRESHOLD_EXCEEDED) == 0) {
      sleep(1);
      if (i > 10) {
        printf("TIMEOUT\n");
        goto cleanup;
      }
      i++;
    }

    crash_set_bit(spec_sense->regs,SPEC_SENSE_CLEAR_THRESHOLD_LATCHED);           // Enable clear threshold latched
    crash_set_bit(usrp_intf_tx->regs,USRP_TX_ENABLE_SIDEBAND);                    // Enable TX Sideband

    while(crash_get_bit(spec_sense->regs,SPEC_SENSE_THRESHOLD_EXCEEDED) == 1);

    // Print threshold information
    temp_int = crash_read_reg(spec_sense->regs,SPEC_SENSE_THRESHOLD);
    memcpy(&temp_float,&temp_int,sizeof(int));
    printf("Threshold:\t\t\t%f\n",temp_float);
    printf("Threshold Exceeded:\t\t%d\n",crash_get_bit(spec_sense->regs,SPEC_SENSE_THRESHOLD_EXCEEDED));
    printf("Threshold Exceeded Index:\t%d\n",crash_read_reg(spec_sense->regs,SPEC_SENSE_THRESHOLD_EXCEEDED_INDEX));
    temp_int = crash_read_reg(spec_sense->regs,SPEC_SENSE_THRESHOLD_EXCEEDED_MAG);
    memcpy(&temp_float,&temp_int,sizeof(int));
    printf("Threshold Exceeded Mag:\t\t%f\n",temp_float);

    if (loop_prog == 1) {
      printf("Ctrl-C to end program after this loop\n");
    }

  cleanup:
    crash_set_bit(spec_sense->regs,SPEC_SENSE_CLEAR_THRESHOLD_LATCHED);           // Enable clear threshold latched
    crash_clear_bit(usrp_intf_tx->regs,USRP_RX_ENABLE);                           // Disable RX
    crash_clear_bit(spec_sense->regs,SPEC_SENSE_ENABLE_FFT);                      // Disable FFT
    crash_clear_bit(usrp_intf_tx->regs,USRP_TX_ENABLE_SIDEBAND);                  // Disable TX Sideband
    crash_clear_bit(usrp_intf_tx->regs,USRP_TX_ENABLE);                           // Disable TX
    sleep(1);
  } while (loop_prog == 1);

  crash_close(usrp_intf_tx);
  crash_close(spec_sense);
  return 0;
}