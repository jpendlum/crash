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
**  File:         arm-spectrum-sense.c
**  Author(s):    Jonathon Pendlum (jon.pendlum@gmail.com)
**  Description:  Performs both Spectrum Sensing and the Spectrum Decision. Uses the FFTW3
**                library of FFT kernels to speed up FFT computation.
**
**                Spectrum decision is simple: If all FFT bins are below
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
#include <fftw3.h>
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
  int c = 0;
  int i = 0;
  int j = 0;
  uint num_loops = 0;
  bool interrupt_flag = false;
  uint number_samples = 0;
  uint decim_rate = 0;
  uint fft_size = 0;
  float threshold = 0.0;
  double gain = 0.0;
  int threshold_exceeded = 0;
  float threshold_exceeded_mag = 0.0;
  int threshold_exceeded_index = 0;
  uint32_t start_decision;
  uint32_t stop_decision;
  uint32_t start_sensing;
  uint32_t stop_sensing;
  uint32_t start_overhead;
  uint32_t stop_overhead;
  uint32_t start_dma;
  uint32_t stop_dma;
  float dma_time[30];
  float sensing_time[30];
  float decision_time[30];
  float* fft_out_real;
  float* fft_out_imag;
  float fft_mag;
  uint32_t decisions[4096];
  fftwf_complex *in1;
  fftwf_complex out[8192];  // Must be 2x max FFT size
  fftwf_plan p1;
  struct crash_plblock *usrp_intf_tx;
  struct crash_plblock *usrp_intf_rx;

  // Parse command line arguments
  while (1) {
    static struct option long_options[] = {
      /* These options don't set a flag.
         We distinguish them by their indices. */
      {"interrupt",   no_argument,       0, 'i'},
      {"loop prog",   no_argument,       0, 'l'},
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

  // Set this process to be real time
  //struct sched_param param;
  //param.sched_priority = 99;
  //if (sched_setscheduler(0, SCHED_FIFO, & param) != 0) {
  //    perror("sched_setscheduler");
  //    exit(EXIT_FAILURE);
  //}


  usrp_intf_tx = crash_open(USRP_INTF_PLBLOCK_ID,WRITE);
  if (usrp_intf_tx == 0) {
    printf("ERROR: Failed to allocate usrp_intf_tx plblock\n");
    return -1;
  }

  usrp_intf_rx = crash_open(USRP_INTF_PLBLOCK_ID,READ);
  if (usrp_intf_rx == 0) {
    crash_close(usrp_intf_rx);
    printf("ERROR: Failed to allocate usrp_intf_rx plblock\n");
    return -1;
  }

  in1 = (fftw_complex *)(usrp_intf_rx->dma_buff);
  fft_out_real = (float *)(&out[0][0]);
  fft_out_imag = (float *)(&out[0][1]);

  start_overhead = crash_read_reg(usrp_intf_tx->regs,DMA_DEBUG_CNT);
  stop_overhead = crash_read_reg(usrp_intf_tx->regs,DMA_DEBUG_CNT);
  printf("Overhead (us): %f\n",(1e6/150e6)*(stop_overhead - start_overhead));

  do {
    // Setup FFTW3
    p1 = fftwf_plan_dft_1d(fft_size, in1, out, FFTW_FORWARD, FFTW_ESTIMATE);

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
    crash_write_reg(usrp_intf_tx->regs, USRP_AXIS_MASTER_TDEST, DMA_PLBLOCK_ID);  // Set tdest to spec_sense
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

    // Create a CW signal to transmit
    float *tx_sample = (float*)(usrp_intf_tx->dma_buff);
    for (i = 0; i < 4096; i++) {
      tx_sample[2*i+1] = 0;
      tx_sample[2*i] = 0.5;
    }

    // Load waveform into TX FIFO so it can immediately trigger
    crash_write(usrp_intf_tx, USRP_INTF_PLBLOCK_ID, number_samples);

    crash_set_bit(usrp_intf_tx->regs,USRP_RX_ENABLE);                             // Enable RX

    // First, loop until threshold is exceeded
    j = 0;
    while (threshold_exceeded == 0) {
      crash_read(usrp_intf_rx, USRP_INTF_PLBLOCK_ID, number_samples);
      // Run FFT
      fftwf_execute(p1);
      for (i = 0; i < number_samples; i++) {
        // Calculate sqrt(I^2 + Q^2)
        fft_mag = sqrt(fft_out_real[i]*fft_out_real[i] + fft_out_imag[i]*fft_out_imag[i]);
        if (fft_mag > threshold) {
          // Do not break loop
          threshold_exceeded = 1;
          // Save threshold data
          threshold_exceeded_mag = fft_mag;
          threshold_exceeded_index = i;
          break;
        }
      }
      if (j > 10) {
        printf("TIMEOUT: Threshold never exceeded\n");
        goto cleanup;
      }
      j++;
      sleep(1);
    }

    // Second, perform specturm sensing and the spectrum decision
    while (threshold_exceeded == 1) {
      threshold_exceeded = 0;
      crash_read(usrp_intf_rx, USRP_INTF_PLBLOCK_ID, number_samples);
      // Run FFT
      fftwf_execute(p1);
      for (i = 0; i < number_samples; i++) {
        // Calculate sqrt(I^2 + Q^2)
        fft_mag = sqrt(fft_out_real[i]*fft_out_real[i] + fft_out_imag[i]*fft_out_imag[i]);
        // Was the threshold exceeded?
        if (fft_mag > threshold) {
          // Do not break loop
          threshold_exceeded = 1;
          break;
        }
      }
      if (threshold_exceeded == 0) {
        // Enable TX
        crash_set_bit(usrp_intf_tx->regs,USRP_TX_ENABLE);
      }
    }

    // Calculate how long the DMA and the thresholding took by using a counter in the FPGA
    // running at 150 MHz.
    start_dma = crash_read_reg(usrp_intf_tx->regs,DMA_DEBUG_CNT);
    crash_read(usrp_intf_rx, USRP_INTF_PLBLOCK_ID, number_samples);
    stop_dma = crash_read_reg(usrp_intf_tx->regs,DMA_DEBUG_CNT);

    start_sensing = crash_read_reg(usrp_intf_tx->regs,DMA_DEBUG_CNT);
    fftwf_execute(p1);
    for (i = 0; i < number_samples; i++) {
      fft_mag = sqrt(fft_out_real[i]*fft_out_real[i] + fft_out_imag[i]*fft_out_imag[i]);
      decisions[i] = (fft_mag > 100000000.0);
    }
    stop_sensing = crash_read_reg(usrp_intf_tx->regs,DMA_DEBUG_CNT);

    start_decision = crash_read_reg(usrp_intf_tx->regs,DMA_DEBUG_CNT);
    for (i = 0; i < number_samples; i++) {
        if (decisions[i] == 1) {
        printf("This shouldn't happen\n");
      }
    }
    stop_decision = crash_read_reg(usrp_intf_tx->regs,DMA_DEBUG_CNT);

    // Print threshold information
    printf("Threshold:\t\t\t%f\n",threshold);
    printf("Threshold Exceeded Index:\t%d\n",threshold_exceeded_index);
    printf("Threshold Exceeded Mag:\t\t%f\n",threshold_exceeded_mag);
    printf("DMA Time (us): %f\n",(1e6/150e6)*(stop_dma - start_dma));
    printf("Sensing Time (us): %f\n",(1e6/150e6)*(stop_sensing - start_sensing));
    printf("Decision Time (us): %f\n",(1e6/150e6)*(stop_decision - start_decision));

    // Keep track of times so we can report an average at the end
    if (num_loops < 30) {
      dma_time[num_loops] = (1e6/150e6)*(stop_dma - start_dma);
      sensing_time[num_loops] = (1e6/150e6)*(stop_sensing - start_sensing);
      decision_time[num_loops] = (1e6/150e6)*(stop_decision - start_decision);
    }
    num_loops++;

    if (loop_prog == 1) {
      printf("Ctrl-C to end program after this loop\n");
    }

    // Force printf to flush since. We are at a real-time priority, so it cannot unless we force it.
    fflush(stdout);
    //if (nanosleep(&ask_sleep,&act_sleep) < 0) {
    //    perror("nanosleep");
    //    exit(EXIT_FAILURE);
    //}

cleanup:
    crash_clear_bit(usrp_intf_tx->regs,USRP_RX_ENABLE);                           // Disable RX
    crash_clear_bit(usrp_intf_tx->regs,USRP_TX_ENABLE);                           // Disable TX
    threshold_exceeded = 0;
    threshold_exceeded_mag = 0.0;
    threshold_exceeded_index = 0;
    fftwf_destroy_plan(p1);
    sleep(1);
  } while (loop_prog == 1);

  float dma_time_avg = 0.0;
  float sensing_time_avg = 0.0;
  float decision_time_avg = 0.0;
  if (num_loops > 30) {
    for (i = 0; i < 30; i++) {
      dma_time_avg += dma_time[i];
      sensing_time_avg += sensing_time[i];
      decision_time_avg += decision_time[i];
    }
    dma_time_avg = dma_time_avg/30;
    sensing_time_avg = sensing_time_avg/30;
    decision_time_avg = decision_time_avg/30;
  } else {
    for (i = 0; i < num_loops; i++) {
      dma_time_avg += dma_time[i];
      sensing_time_avg += sensing_time[i];
      decision_time_avg += decision_time[i];
    }
    dma_time_avg = dma_time_avg/num_loops;
    sensing_time_avg = sensing_time_avg/num_loops;
    decision_time_avg = decision_time_avg/num_loops;
  }
  printf("Number of loops: %d\n",num_loops);
  printf("Average DMA time (us): %f\n",dma_time_avg);
  printf("Average Sensing time (us): %f\n",sensing_time_avg);
  printf("Average Decision time (us): %f\n",decision_time_avg);

  crash_close(usrp_intf_tx);
  crash_close(usrp_intf_rx);
  return 0;
}