-------------------------------------------------------------------------------
--  Copyright 2013-2014 Jonathon Pendlum
--
--  This is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  This is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
--
--  File: toplevel_testbench.vhd
--  Author: Jonathon Pendlum (jon.pendlum@gmail.com)
--  Description: Testbench for toplevel file for the Zedboard, ZC702, and ZC706.
--               Does not simulate the processor system, but it does simulate
--               the AXI ACP and AXI GP ports used for DMA transfers and
--               control / status register access.
--
--               The testbench does the following:
--                 - Simulates the modified USRP firmware and simulates it
--                   receiving a sinusoid. This is used to trigger the
--                   threshold detection portion of the Spectrum Sensing block.
--                 - Reads and writes 256 words over AXI ACP to test the interface.
--                 - Sets up a transmission by reading 4096 words over AXI ACP and
--                   buffering them. These words will be sent to the transmit
--                   path of the USRP DDR Interface block when TX is enabled via
--                   a control register.
--                 - Sets up the Spectrum Sense block to trigger the USRP DDR
--                   Interface block when the threshold is exceeded.
--                 - Sets up the USRP DDR Interface block to receive sample and
--                   filter sample data.
--
--              All of these steps together simulate the code detecting a
--              sinusoid and triggering a tranmission due to that signal.
--              It is also possible to configure the system to transmit when
--              the threshold is not exceeded in the Spectrum Sensing block,
--              i.e. transmit when detecting the absence of the sinusoid signal.
--
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

entity toplevel_testbench is
end entity;

architecture Testbench of toplevel_testbench is
  -------------------------------------------------------------------------------
  -- Component Declaration
  -------------------------------------------------------------------------------
  component ps_pl_interface is
    generic (
      C_BASEADDR                      : std_logic_vector(31 downto 0) := x"40000000";
      C_HIGHADDR                      : std_logic_vector(31 downto 0) := x"4001ffff");
    port (
      -- AXIS Stream Clock and Reset
      clk                             : in    std_logic;
      rst_n                           : in    std_logic;
      -- AXI-Lite Slave bus for access to control & status registers
      S_AXI_AWADDR                    : in    std_logic_vector(31 downto 0);
      S_AXI_AWVALID                   : in    std_logic;
      S_AXI_AWREADY                   : out   std_logic;
      S_AXI_WDATA                     : in    std_logic_vector(31 downto 0);
      S_AXI_WSTRB                     : in    std_logic_vector(3 downto 0);
      S_AXI_WVALID                    : in    std_logic;
      S_AXI_WREADY                    : out   std_logic;
      S_AXI_BRESP                     : out   std_logic_vector(1 downto 0);
      S_AXI_BVALID                    : out   std_logic;
      S_AXI_BREADY                    : in    std_logic;
      S_AXI_ARADDR                    : in    std_logic_vector(31 downto 0);
      S_AXI_ARVALID                   : in    std_logic;
      S_AXI_ARREADY                   : out   std_logic;
      S_AXI_RDATA                     : out   std_logic_vector(31 downto 0);
      S_AXI_RRESP                     : out   std_logic_vector(1 downto 0);
      S_AXI_RVALID                    : out   std_logic;
      S_AXI_RREADY                    : in    std_logic;
      -- AXI ACP Bus to interface with processor system
      M_AXI_AWADDR                    : out   std_logic_vector(31 downto 0);
      M_AXI_AWPROT                    : out   std_logic_vector(2 downto 0);
      M_AXI_AWVALID                   : out   std_logic;
      M_AXI_AWREADY                   : in    std_logic;
      M_AXI_WDATA                     : out   std_logic_vector(63 downto 0);
      M_AXI_WSTRB                     : out   std_logic_vector(7 downto 0);
      M_AXI_WVALID                    : out   std_logic;
      M_AXI_WREADY                    : in    std_logic;
      M_AXI_BRESP                     : in    std_logic_vector(1 downto 0);
      M_AXI_BVALID                    : in    std_logic;
      M_AXI_BREADY                    : out   std_logic;
      M_AXI_AWLEN                     : out   std_logic_vector(7 downto 0);
      M_AXI_AWSIZE                    : out   std_logic_vector(2 downto 0);
      M_AXI_AWBURST                   : out   std_logic_vector(1 downto 0);
      M_AXI_AWCACHE                   : out   std_logic_vector(3 downto 0);
      M_AXI_AWUSER                    : out   std_logic_vector(4 downto 0);
      M_AXI_WLAST                     : out   std_logic;
      M_AXI_ARADDR                    : out   std_logic_vector(31 downto 0);
      M_AXI_ARPROT                    : out   std_logic_vector(2 downto 0);
      M_AXI_ARVALID                   : out   std_logic;
      M_AXI_ARREADY                   : in    std_logic;
      M_AXI_RDATA                     : in    std_logic_vector(63 downto 0);
      M_AXI_RRESP                     : in    std_logic_vector(1 downto 0);
      M_AXI_RVALID                    : in    std_logic;
      M_AXI_RREADY                    : out   std_logic;
      M_AXI_RLAST                     : in    std_logic;
      M_AXI_ARCACHE                   : out   std_logic_vector(3 downto 0);
      M_AXI_ARUSER                    : out   std_logic_vector(4 downto 0);
      M_AXI_ARLEN                     : out   std_logic_vector(7 downto 0);
      M_AXI_ARBURST                   : out   std_logic_vector(1 downto 0);
      M_AXI_ARSIZE                    : out   std_logic_vector(2 downto 0);
      -- Interrupt on successfully completed AXI ACP writes
      irq                             : out   std_logic;
      -- Global reset for all accelerators
      rst_glb_n                       : out   std_logic;
      -- Accelerator interfaces
      -- Note: Master & Slave 0 are not listed as the Datamover componeent
      --       uses both.
      -- Accelerator 1
      axis_master_1_tvalid            : in    std_logic;
      axis_master_1_tready            : out   std_logic;
      axis_master_1_tdata             : in    std_logic_vector(63 downto 0);
      axis_master_1_tdest             : in    std_logic_vector(2 downto 0);
      axis_master_1_tlast             : in    std_logic;
      axis_master_1_irq               : in    std_logic;
      axis_slave_1_tvalid             : out   std_logic;
      axis_slave_1_tready             : in    std_logic;
      axis_slave_1_tdata              : out   std_logic_vector(63 downto 0);
      axis_slave_1_tid                : out   std_logic_vector(2 downto 0);
      axis_slave_1_tlast              : out   std_logic;
      axis_slave_1_irq                : in    std_logic;
      status_1_addr                   : out   std_logic_vector(7 downto 0);
      status_1_data                   : in    std_logic_vector(31 downto 0);
      status_1_stb                    : out   std_logic;
      ctrl_1_addr                     : out   std_logic_vector(7 downto 0);
      ctrl_1_data                     : out   std_logic_vector(31 downto 0);
      ctrl_1_stb                      : out   std_logic;
      -- Accelerator 2
      axis_master_2_tvalid            : in    std_logic;
      axis_master_2_tready            : out   std_logic;
      axis_master_2_tdata             : in    std_logic_vector(63 downto 0);
      axis_master_2_tdest             : in    std_logic_vector(2 downto 0);
      axis_master_2_tlast             : in    std_logic;
      axis_master_2_irq               : in    std_logic;
      axis_slave_2_tvalid             : out   std_logic;
      axis_slave_2_tready             : in    std_logic;
      axis_slave_2_tdata              : out   std_logic_vector(63 downto 0);
      axis_slave_2_tid                : out   std_logic_vector(2 downto 0);
      axis_slave_2_tlast              : out   std_logic;
      axis_slave_2_irq                : in    std_logic;
      status_2_addr                   : out   std_logic_vector(7 downto 0);
      status_2_data                   : in    std_logic_vector(31 downto 0);
      status_2_stb                    : out   std_logic;
      ctrl_2_addr                     : out   std_logic_vector(7 downto 0);
      ctrl_2_data                     : out   std_logic_vector(31 downto 0);
      ctrl_2_stb                      : out   std_logic;
      -- Accelerator 3
      axis_master_3_tvalid            : in    std_logic;
      axis_master_3_tready            : out   std_logic;
      axis_master_3_tdata             : in    std_logic_vector(63 downto 0);
      axis_master_3_tdest             : in    std_logic_vector(2 downto 0);
      axis_master_3_tlast             : in    std_logic;
      axis_master_3_irq               : in    std_logic;
      axis_slave_3_tvalid             : out   std_logic;
      axis_slave_3_tready             : in    std_logic;
      axis_slave_3_tdata              : out   std_logic_vector(63 downto 0);
      axis_slave_3_tid                : out   std_logic_vector(2 downto 0);
      axis_slave_3_tlast              : out   std_logic;
      axis_slave_3_irq                : in    std_logic;
      status_3_addr                   : out   std_logic_vector(7 downto 0);
      status_3_data                   : in    std_logic_vector(31 downto 0);
      status_3_stb                    : out   std_logic;
      ctrl_3_addr                     : out   std_logic_vector(7 downto 0);
      ctrl_3_data                     : out   std_logic_vector(31 downto 0);
      ctrl_3_stb                      : out   std_logic;
      -- Accelerator 4
      axis_master_4_tvalid            : in    std_logic;
      axis_master_4_tready            : out   std_logic;
      axis_master_4_tdata             : in    std_logic_vector(63 downto 0);
      axis_master_4_tdest             : in    std_logic_vector(2 downto 0);
      axis_master_4_tlast             : in    std_logic;
      axis_master_4_irq               : in    std_logic;
      axis_slave_4_tvalid             : out   std_logic;
      axis_slave_4_tready             : in    std_logic;
      axis_slave_4_tdata              : out   std_logic_vector(63 downto 0);
      axis_slave_4_tid                : out   std_logic_vector(2 downto 0);
      axis_slave_4_tlast              : out   std_logic;
      axis_slave_4_irq                : in    std_logic;
      status_4_addr                   : out   std_logic_vector(7 downto 0);
      status_4_data                   : in    std_logic_vector(31 downto 0);
      status_4_stb                    : out   std_logic;
      ctrl_4_addr                     : out   std_logic_vector(7 downto 0);
      ctrl_4_data                     : out   std_logic_vector(31 downto 0);
      ctrl_4_stb                      : out   std_logic;
      -- Accelerator 5
      axis_master_5_tvalid            : in    std_logic;
      axis_master_5_tready            : out   std_logic;
      axis_master_5_tdata             : in    std_logic_vector(63 downto 0);
      axis_master_5_tdest             : in    std_logic_vector(2 downto 0);
      axis_master_5_tlast             : in    std_logic;
      axis_master_5_irq               : in    std_logic;
      axis_slave_5_tvalid             : out   std_logic;
      axis_slave_5_tready             : in    std_logic;
      axis_slave_5_tdata              : out   std_logic_vector(63 downto 0);
      axis_slave_5_tid                : out   std_logic_vector(2 downto 0);
      axis_slave_5_tlast              : out   std_logic;
      axis_slave_5_irq                : in    std_logic;
      status_5_addr                   : out   std_logic_vector(7 downto 0);
      status_5_data                   : in    std_logic_vector(31 downto 0);
      status_5_stb                    : out   std_logic;
      ctrl_5_addr                     : out   std_logic_vector(7 downto 0);
      ctrl_5_data                     : out   std_logic_vector(31 downto 0);
      ctrl_5_stb                      : out   std_logic;
      -- Accelerator 6
      axis_master_6_tvalid            : in    std_logic;
      axis_master_6_tready            : out   std_logic;
      axis_master_6_tdata             : in    std_logic_vector(63 downto 0);
      axis_master_6_tdest             : in    std_logic_vector(2 downto 0);
      axis_master_6_tlast             : in    std_logic;
      axis_master_6_irq               : in    std_logic;
      axis_slave_6_tvalid             : out   std_logic;
      axis_slave_6_tready             : in    std_logic;
      axis_slave_6_tdata              : out   std_logic_vector(63 downto 0);
      axis_slave_6_tid                : out   std_logic_vector(2 downto 0);
      axis_slave_6_tlast              : out   std_logic;
      axis_slave_6_irq                : in    std_logic;
      status_6_addr                   : out   std_logic_vector(7 downto 0);
      status_6_data                   : in    std_logic_vector(31 downto 0);
      status_6_stb                    : out   std_logic;
      ctrl_6_addr                     : out   std_logic_vector(7 downto 0);
      ctrl_6_data                     : out   std_logic_vector(31 downto 0);
      ctrl_6_stb                      : out   std_logic;
      -- Accelerator 7
      axis_master_7_tvalid            : in    std_logic;
      axis_master_7_tready            : out   std_logic;
      axis_master_7_tdata             : in    std_logic_vector(63 downto 0);
      axis_master_7_tdest             : in    std_logic_vector(2 downto 0);
      axis_master_7_tlast             : in    std_logic;
      axis_master_7_irq               : in    std_logic;
      axis_slave_7_tvalid             : out   std_logic;
      axis_slave_7_tready             : in    std_logic;
      axis_slave_7_tdata              : out   std_logic_vector(63 downto 0);
      axis_slave_7_tid                : out   std_logic_vector(2 downto 0);
      axis_slave_7_tlast              : out   std_logic;
      axis_slave_7_irq                : in    std_logic;
      status_7_addr                   : out   std_logic_vector(7 downto 0);
      status_7_data                   : in    std_logic_vector(31 downto 0);
      status_7_stb                    : out   std_logic;
      ctrl_7_addr                     : out   std_logic_vector(7 downto 0);
      ctrl_7_data                     : out   std_logic_vector(31 downto 0);
      ctrl_7_stb                      : out   std_logic);
  end component;

  component usrp_ddr_intf_axis is
    generic (
      DDR_CLOCK_FREQ              : integer := 100e6;       -- Clock rate of DDR interface
      BAUD                        : integer := 115200);     -- UART baud rate
    port (
      -- USRP Interface
      UART_TX                     : out   std_logic;                      -- UART
      RX_DATA_CLK_N               : in    std_logic;                      -- Receive data clock (N)
      RX_DATA_CLK_P               : in    std_logic;                      -- Receive data clock (P)
      RX_DATA_N                   : in    std_logic_vector(6 downto 0);   -- Receive data (N)
      RX_DATA_P                   : in    std_logic_vector(6 downto 0);   -- Receive data (N)
      TX_DATA_N                   : out   std_logic_vector(7 downto 0);   -- Transmit data (N)
      TX_DATA_P                   : out   std_logic_vector(7 downto 0);   -- Transmit data (P)
      -- Clock and Reset
      clk                         : in    std_logic;
      rst_n                       : in    std_logic;
      -- Control and Status Registers
      status_addr                 : in    std_logic_vector(7 downto 0);
      status_data                 : out   std_logic_vector(31 downto 0);
      status_stb                  : in    std_logic;
      ctrl_addr                   : in    std_logic_vector(7 downto 0);
      ctrl_data                   : in    std_logic_vector(31 downto 0);
      ctrl_stb                    : in    std_logic;
      -- AXIS Stream Slave Interface (DAC / TX Data)
      axis_slave_tvalid           : in    std_logic;
      axis_slave_tready           : out   std_logic;
      axis_slave_tdata            : in    std_logic_vector(63 downto 0);
      axis_slave_tid              : in    std_logic_vector(2 downto 0);
      axis_slave_tlast            : in    std_logic;
      axis_slave_irq              : out   std_logic;    -- Not used
      -- AXIS Stream Master Interface (ADC / RX Data)
      axis_master_tvalid          : out   std_logic;
      axis_master_tready          : in    std_logic;
      axis_master_tdata           : out   std_logic_vector(63 downto 0);
      axis_master_tdest           : out   std_logic_vector(2 downto 0);
      axis_master_tlast           : out   std_logic;
      axis_master_irq             : out   std_logic;    -- Not used
      -- Sideband signals
      rx_enable_aux               : in    std_logic;
      tx_enable_aux               : in    std_logic);
  end component;

  component spectrum_sense is
    port (
      -- Clock and Reset
      clk                         : in    std_logic;
      rst_n                       : in    std_logic;
      -- Control and Status Registers
      status_addr                 : in    std_logic_vector(7 downto 0);
      status_data                 : out   std_logic_vector(31 downto 0);
      status_stb                  : in    std_logic;
      ctrl_addr                   : in    std_logic_vector(7 downto 0);
      ctrl_data                   : in    std_logic_vector(31 downto 0);
      ctrl_stb                    : in    std_logic;
      -- AXIS Stream Slave Interface (Time Domain / FFT Input)
      axis_slave_tvalid           : in    std_logic;
      axis_slave_tready           : out   std_logic;
      axis_slave_tdata            : in    std_logic_vector(63 downto 0);
      axis_slave_tid              : in    std_logic_vector(2 downto 0);
      axis_slave_tlast            : in    std_logic;
      axis_slave_irq              : out   std_logic;    -- Not used
      -- AXIS Stream Master Interface (Frequency Domain / FFT Output)
      axis_master_tvalid          : out   std_logic;
      axis_master_tready          : in    std_logic;
      axis_master_tdata           : out   std_logic_vector(63 downto 0);
      axis_master_tdest           : out   std_logic_vector(2 downto 0);
      axis_master_tlast           : out   std_logic;
      axis_master_irq             : out   std_logic;    -- Strobes when threshold exceeded
      -- Sideband signals
      threshold_not_exceeded      : out   std_logic;
      threshold_not_exceeded_stb  : out   std_logic;
      threshold_exceeded          : out   std_logic;
      threshold_exceeded_stb      : out   std_logic);
  end component;

  component bpsk_mod is
    port (
      -- Clock and Reset
      clk                         : in    std_logic;
      rst_n                       : in    std_logic;
      -- Control and Status Registers
      status_addr                 : in    std_logic_vector(7 downto 0);
      status_data                 : out   std_logic_vector(31 downto 0);
      status_stb                  : in    std_logic;
      ctrl_addr                   : in    std_logic_vector(7 downto 0);
      ctrl_data                   : in    std_logic_vector(31 downto 0);
      ctrl_stb                    : in    std_logic;
      -- AXIS Stream Slave Interface (Binary Data)
      axis_slave_tvalid           : in    std_logic;
      axis_slave_tready           : out   std_logic;
      axis_slave_tdata            : in    std_logic_vector(63 downto 0);
      axis_slave_tid              : in    std_logic_vector(2 downto 0);
      axis_slave_tlast            : in    std_logic;
      axis_slave_irq              : out   std_logic;    -- Not used (TODO: maybe use for near empty input FIFO?)
      -- AXIS Stream Master Interface (Modulated complex samples)
      axis_master_tvalid          : out   std_logic;
      axis_master_tready          : in    std_logic;
      axis_master_tdata           : out   std_logic_vector(63 downto 0);
      axis_master_tdest           : out   std_logic_vector(2 downto 0);
      axis_master_tlast           : out   std_logic;
      axis_master_irq             : out   std_logic;    -- Not used
      -- Sideband signals
      trigger_stb                 : in    std_logic);
  end component;

  component crash_ddr_intf is
    generic (
      CLOCK_FREQ        : integer := 100e6;           -- Clock rate of DDR interface
      BAUD              : integer := 115200);         -- UART baud rate
    port (
      clk               : in    std_logic;            -- Clock (from ADC)
      reset             : in    std_logic;            -- Active high reset
      RX_DATA_CLK_N     : out   std_logic;            -- RX data clock (P)
      RX_DATA_CLK_P     : out   std_logic;            -- RX data clock (N)
      RX_DATA_N         : out   std_logic_vector(6 downto 0);  -- RX data (P)
      RX_DATA_P         : out   std_logic_vector(6 downto 0);  -- RX data (N)
      TX_DATA_N         : in    std_logic_vector(7 downto 0);  -- TX data (P)
      TX_DATA_P         : in    std_logic_vector(7 downto 0);  -- TX data (N)
      UART_RX           : in    std_logic;            -- Control interface from CRASH (RX)
      adc_channel_a     : in    std_logic_vector(13 downto 0);  -- ADC data channel a, Raw data from ADC
      adc_channel_b     : in    std_logic_vector(13 downto 0);  -- ADC data channel b, Raw data from ADC
      adc_i             : in    std_logic_vector(23 downto 0);  -- ADC data I, With DC offset correction & IQ Balance
      adc_q             : in    std_logic_vector(23 downto 0);  -- ADC data Q, With DC offset correction & IQ Balance
      dac_channel_a_in  : in    std_logic_vector(15 downto 0);  -- DAC data channel a from USRP (for muxing purposes)
      dac_channel_b_in  : in    std_logic_vector(15 downto 0);  -- DAC data channel b from USRP (for muxing purposes)
      dac_i_in          : in    std_logic_vector(23 downto 0);  -- DAC data I from USRP (for muxing purposes)
      dac_q_in          : in    std_logic_vector(23 downto 0);  -- DAC data Q from USRP (for muxing purposes)
      dac_channel_a     : out   std_logic_vector(15 downto 0);  -- DAC data channel a, Raw data to DAC
      dac_channel_b     : out   std_logic_vector(15 downto 0);  -- DAC data channel b, Raw data to DAC
      dac_i             : out   std_logic_vector(23 downto 0);  -- DAC data I, USRP corrects DC offset correction & IQ Balance
      dac_q             : out   std_logic_vector(23 downto 0)); -- DAC data Q, USRP corrects DC offset correction & IQ Balance
  end component;

  -----------------------------------------------------------------------------
  -- Constants Declaration
  -----------------------------------------------------------------------------
  constant AXIS_CLOCK_RATE          : real    := 150.0e6;
  constant AXIS_CLOCK_PERIOD        : time    := (1.0e12/AXIS_CLOCK_RATE)*(1 ps);
  constant CLOCK_RATE_100MHz        : real    := 100.0e6;
  constant CLOCK_PERIOD_100MHz      : time    := (1.0e12/CLOCK_RATE_100MHz)*(1 ps);

  constant TIMEOUT                  : time    := 5 sec;

  -- Control registers
  constant REG_USRP_MODE            : std_logic_vector(31 downto 0) := x"00000001";
  constant REG_RX_PKT_SIZE          : std_logic_vector(31 downto 0) := x"00000002";
  constant REG_RX_DECIM             : std_logic_vector(31 downto 0) := x"00000003";
  constant REG_RX_GAIN              : std_logic_vector(31 downto 0) := x"00000004";
  constant REG_TXRX_RESET           : std_logic_vector(31 downto 0) := x"00000005";
  constant REG_TX_INTERP            : std_logic_vector(31 downto 0) := x"00000006";
  constant REG_TX_GAIN              : std_logic_vector(31 downto 0) := x"00000007";
  constant REG_TXRX_MMCM_PHASE_INIT : std_logic_vector(31 downto 0) := x"00000008";
  constant REG_TXRX_MMCM_PHASE_ADJ  : std_logic_vector(31 downto 0) := x"00000009";
  constant REG_MISC                 : std_logic_vector(31 downto 0) := x"0000000A";
    -- RX modes (lower nibble)
  constant RX_ADC_RAW_MODE          : std_logic_vector(3 downto 0) := x"0";
  constant RX_ADC_DSP_MODE          : std_logic_vector(3 downto 0) := x"1";
  constant RX_SINE_TEST_MODE        : std_logic_vector(3 downto 0) := x"2";
  constant RX_TEST_PATTERN_MODE     : std_logic_vector(3 downto 0) := x"3";
  constant RX_ALL_1s_MODE           : std_logic_vector(3 downto 0) := x"4";
  constant RX_ALL_0s_MODE           : std_logic_vector(3 downto 0) := x"5";
  constant RX_CHA_1s_CHB_0s_MODE    : std_logic_vector(3 downto 0) := x"6";
  constant RX_CHA_0s_CHB_1s_MODE    : std_logic_vector(3 downto 0) := x"7";
  constant RX_CHECK_ALIGN_MODE      : std_logic_vector(3 downto 0) := x"8";
  constant RX_TX_LOOPBACK_MODE      : std_logic_vector(3 downto 0) := x"9";
  -- TX modes (upper nibble)
  constant TX_PASSTHRU_MODE         : std_logic_vector(3 downto 0) := x"0";
  constant TX_DAC_RAW_MODE          : std_logic_vector(3 downto 0) := x"1";
  constant TX_DAC_DSP_MODE          : std_logic_vector(3 downto 0) := x"2";
  constant TX_SINE_TEST_MODE        : std_logic_vector(3 downto 0) := x"3";
  constant TX_RX_LOOPBACK_MODE      : std_logic_vector(3 downto 0) := x"4";

  -----------------------------------------------------------------------------
  -- Signal Declaration
  -----------------------------------------------------------------------------
  signal axis_clk                 : std_logic;
  signal axis_rst_n               : std_logic;
  signal clk_100MHz               : std_logic;
  signal reset                    : std_logic;

  signal S_AXI_AWADDR             : std_logic_vector(31 downto 0);
  signal S_AXI_AWVALID            : std_logic;
  signal S_AXI_AWREADY            : std_logic;
  signal S_AXI_WDATA              : std_logic_vector(31 downto 0);
  signal S_AXI_WSTRB              : std_logic_vector(3 downto 0);
  signal S_AXI_WVALID             : std_logic;
  signal S_AXI_WREADY             : std_logic;
  signal S_AXI_BRESP              : std_logic_vector(1 downto 0);
  signal S_AXI_BVALID             : std_logic;
  signal S_AXI_BREADY             : std_logic;
  signal S_AXI_ARADDR             : std_logic_vector(31 downto 0);
  signal S_AXI_ARVALID            : std_logic;
  signal S_AXI_ARREADY            : std_logic;
  signal S_AXI_RDATA              : std_logic_vector(31 downto 0);
  signal S_AXI_RRESP              : std_logic_vector(1 downto 0);
  signal S_AXI_RVALID             : std_logic;
  signal S_AXI_RREADY             : std_logic;
  signal M_AXI_AWADDR             : std_logic_vector(31 downto 0);
  signal M_AXI_AWPROT             : std_logic_vector(2 downto 0);
  signal M_AXI_AWVALID            : std_logic;
  signal M_AXI_AWREADY            : std_logic;
  signal M_AXI_WDATA              : std_logic_vector(63 downto 0);
  signal M_AXI_WSTRB              : std_logic_vector(7 downto 0);
  signal M_AXI_WVALID             : std_logic;
  signal M_AXI_WREADY             : std_logic;
  signal M_AXI_BRESP              : std_logic_vector(1 downto 0);
  signal M_AXI_BVALID             : std_logic;
  signal M_AXI_BREADY             : std_logic;
  signal M_AXI_AWLEN              : std_logic_vector(7 downto 0);
  signal M_AXI_AWSIZE             : std_logic_vector(2 downto 0);
  signal M_AXI_AWBURST            : std_logic_vector(1 downto 0);
  signal M_AXI_AWCACHE            : std_logic_vector(3 downto 0);
  signal M_AXI_AWUSER             : std_logic_vector(4 downto 0);
  signal M_AXI_WLAST              : std_logic;
  signal M_AXI_ARADDR             : std_logic_vector(31 downto 0);
  signal M_AXI_ARPROT             : std_logic_vector(2 downto 0);
  signal M_AXI_ARVALID            : std_logic;
  signal M_AXI_ARREADY            : std_logic;
  signal M_AXI_RDATA              : std_logic_vector(63 downto 0);
  signal M_AXI_RRESP              : std_logic_vector(1 downto 0);
  signal M_AXI_RVALID             : std_logic;
  signal M_AXI_RREADY             : std_logic;
  signal M_AXI_RLAST              : std_logic;
  signal M_AXI_ARCACHE            : std_logic_vector(3 downto 0);
  signal M_AXI_ARUSER             : std_logic_vector(4 downto 0);
  signal M_AXI_ARLEN              : std_logic_vector(7 downto 0);
  signal M_AXI_ARBURST            : std_logic_vector(1 downto 0);
  signal M_AXI_ARSIZE             : std_logic_vector(2 downto 0);
  signal irq                      : std_logic;
  signal rst_glb_n                : std_logic;
  signal axis_master_1_tvalid     : std_logic;
  signal axis_master_1_tready     : std_logic;
  signal axis_master_1_tdata      : std_logic_vector(63 downto 0);
  signal axis_master_1_tdest      : std_logic_vector(2 downto 0);
  signal axis_master_1_tlast      : std_logic;
  signal axis_master_1_irq        : std_logic;
  signal axis_slave_1_tvalid      : std_logic;
  signal axis_slave_1_tready      : std_logic;
  signal axis_slave_1_tdata       : std_logic_vector(63 downto 0);
  signal axis_slave_1_tid         : std_logic_vector(2 downto 0);
  signal axis_slave_1_tlast       : std_logic;
  signal axis_slave_1_irq         : std_logic;
  signal status_1_addr            : std_logic_vector(7 downto 0);
  signal status_1_data            : std_logic_vector(31 downto 0);
  signal status_1_stb             : std_logic;
  signal ctrl_1_addr              : std_logic_vector(7 downto 0);
  signal ctrl_1_data              : std_logic_vector(31 downto 0);
  signal ctrl_1_stb               : std_logic;
  signal axis_master_2_tvalid     : std_logic;
  signal axis_master_2_tready     : std_logic;
  signal axis_master_2_tdata      : std_logic_vector(63 downto 0);
  signal axis_master_2_tdest      : std_logic_vector(2 downto 0);
  signal axis_master_2_tlast      : std_logic;
  signal axis_master_2_irq        : std_logic;
  signal axis_slave_2_tvalid      : std_logic;
  signal axis_slave_2_tready      : std_logic;
  signal axis_slave_2_tdata       : std_logic_vector(63 downto 0);
  signal axis_slave_2_tid         : std_logic_vector(2 downto 0);
  signal axis_slave_2_tlast       : std_logic;
  signal axis_slave_2_irq         : std_logic;
  signal status_2_addr            : std_logic_vector(7 downto 0);
  signal status_2_data            : std_logic_vector(31 downto 0);
  signal status_2_stb             : std_logic;
  signal ctrl_2_addr              : std_logic_vector(7 downto 0);
  signal ctrl_2_data              : std_logic_vector(31 downto 0);
  signal ctrl_2_stb               : std_logic;
  signal axis_master_3_tvalid     : std_logic;
  signal axis_master_3_tready     : std_logic;
  signal axis_master_3_tdata      : std_logic_vector(63 downto 0);
  signal axis_master_3_tdest      : std_logic_vector(2 downto 0);
  signal axis_master_3_tlast      : std_logic;
  signal axis_master_3_irq        : std_logic;
  signal axis_slave_3_tvalid      : std_logic;
  signal axis_slave_3_tready      : std_logic;
  signal axis_slave_3_tdata       : std_logic_vector(63 downto 0);
  signal axis_slave_3_tid         : std_logic_vector(2 downto 0);
  signal axis_slave_3_tlast       : std_logic;
  signal axis_slave_3_irq         : std_logic;
  signal status_3_addr            : std_logic_vector(7 downto 0);
  signal status_3_data            : std_logic_vector(31 downto 0);
  signal status_3_stb             : std_logic;
  signal ctrl_3_addr              : std_logic_vector(7 downto 0);
  signal ctrl_3_data              : std_logic_vector(31 downto 0);
  signal ctrl_3_stb               : std_logic;
  signal axis_master_4_tvalid     : std_logic;
  signal axis_master_4_tready     : std_logic;
  signal axis_master_4_tdata      : std_logic_vector(63 downto 0);
  signal axis_master_4_tdest      : std_logic_vector(2 downto 0);
  signal axis_master_4_tlast      : std_logic;
  signal axis_master_4_irq        : std_logic;
  signal axis_slave_4_tvalid      : std_logic;
  signal axis_slave_4_tready      : std_logic;
  signal axis_slave_4_tdata       : std_logic_vector(63 downto 0);
  signal axis_slave_4_tid         : std_logic_vector(2 downto 0);
  signal axis_slave_4_tlast       : std_logic;
  signal axis_slave_4_irq         : std_logic;
  signal status_4_addr            : std_logic_vector(7 downto 0);
  signal status_4_data            : std_logic_vector(31 downto 0);
  signal status_4_stb             : std_logic;
  signal ctrl_4_addr              : std_logic_vector(7 downto 0);
  signal ctrl_4_data              : std_logic_vector(31 downto 0);
  signal ctrl_4_stb               : std_logic;
  signal axis_master_5_tvalid     : std_logic;
  signal axis_master_5_tready     : std_logic;
  signal axis_master_5_tdata      : std_logic_vector(63 downto 0);
  signal axis_master_5_tdest      : std_logic_vector(2 downto 0);
  signal axis_master_5_tlast      : std_logic;
  signal axis_master_5_irq        : std_logic;
  signal axis_slave_5_tvalid      : std_logic;
  signal axis_slave_5_tready      : std_logic;
  signal axis_slave_5_tdata       : std_logic_vector(63 downto 0);
  signal axis_slave_5_tid         : std_logic_vector(2 downto 0);
  signal axis_slave_5_tlast       : std_logic;
  signal axis_slave_5_irq         : std_logic;
  signal status_5_addr            : std_logic_vector(7 downto 0);
  signal status_5_data            : std_logic_vector(31 downto 0);
  signal status_5_stb             : std_logic;
  signal ctrl_5_addr              : std_logic_vector(7 downto 0);
  signal ctrl_5_data              : std_logic_vector(31 downto 0);
  signal ctrl_5_stb               : std_logic;
  signal axis_master_6_tvalid     : std_logic;
  signal axis_master_6_tready     : std_logic;
  signal axis_master_6_tdata      : std_logic_vector(63 downto 0);
  signal axis_master_6_tdest      : std_logic_vector(2 downto 0);
  signal axis_master_6_tlast      : std_logic;
  signal axis_master_6_irq        : std_logic;
  signal axis_slave_6_tvalid      : std_logic;
  signal axis_slave_6_tready      : std_logic;
  signal axis_slave_6_tdata       : std_logic_vector(63 downto 0);
  signal axis_slave_6_tid         : std_logic_vector(2 downto 0);
  signal axis_slave_6_tlast       : std_logic;
  signal axis_slave_6_irq         : std_logic;
  signal status_6_addr            : std_logic_vector(7 downto 0);
  signal status_6_data            : std_logic_vector(31 downto 0);
  signal status_6_stb             : std_logic;
  signal ctrl_6_addr              : std_logic_vector(7 downto 0);
  signal ctrl_6_data              : std_logic_vector(31 downto 0);
  signal ctrl_6_stb               : std_logic;
  signal axis_master_7_tvalid     : std_logic;
  signal axis_master_7_tready     : std_logic;
  signal axis_master_7_tdata      : std_logic_vector(63 downto 0);
  signal axis_master_7_tdest      : std_logic_vector(2 downto 0);
  signal axis_master_7_tlast      : std_logic;
  signal axis_master_7_irq        : std_logic;
  signal axis_slave_7_tvalid      : std_logic;
  signal axis_slave_7_tready      : std_logic;
  signal axis_slave_7_tdata       : std_logic_vector(63 downto 0);
  signal axis_slave_7_tid         : std_logic_vector(2 downto 0);
  signal axis_slave_7_tlast       : std_logic;
  signal axis_slave_7_irq         : std_logic;
  signal status_7_addr            : std_logic_vector(7 downto 0);
  signal status_7_data            : std_logic_vector(31 downto 0);
  signal status_7_stb             : std_logic;
  signal ctrl_7_addr              : std_logic_vector(7 downto 0);
  signal ctrl_7_data              : std_logic_vector(31 downto 0);
  signal ctrl_7_stb               : std_logic;

  signal UART_TX                    : std_logic;
  signal RX_DATA_CLK_N              : std_logic;
  signal RX_DATA_CLK_P              : std_logic;
  signal RX_DATA_N                  : std_logic_vector(6 downto 0);
  signal RX_DATA_P                  : std_logic_vector(6 downto 0);
  signal TX_DATA_N                  : std_logic_vector(7 downto 0);
  signal TX_DATA_P                  : std_logic_vector(7 downto 0);
  signal rx_enable_aux              : std_logic;
  signal tx_enable_aux              : std_logic;
  signal threshold_not_exceeded     : std_logic;
  signal threshold_not_exceeded_stb : std_logic;
  signal threshold_exceeded         : std_logic;
  signal threshold_exceeded_stb     : std_logic;
  signal trigger_stb                : std_logic;

  signal adc_channel_a            : std_logic_vector(13 downto 0);
  signal adc_channel_b            : std_logic_vector(13 downto 0);
  signal adc_i                    : std_logic_vector(23 downto 0);
  signal adc_q                    : std_logic_vector(23 downto 0);
  signal dac_channel_a_in         : std_logic_vector(15 downto 0);
  signal dac_channel_b_in         : std_logic_vector(15 downto 0);
  signal dac_i_in                 : std_logic_vector(23 downto 0);
  signal dac_q_in                 : std_logic_vector(23 downto 0);
  signal dac_channel_a            : std_logic_vector(15 downto 0);
  signal dac_channel_b            : std_logic_vector(15 downto 0);
  signal dac_i                    : std_logic_vector(23 downto 0);
  signal dac_q                    : std_logic_vector(23 downto 0);

  signal RX_DATA_CLK_N_wire_dly   : std_logic;
  signal RX_DATA_CLK_P_wire_dly   : std_logic;
  signal RX_DATA_N_wire_dly       : std_logic_vector(6 downto 0);
  signal RX_DATA_P_wire_dly       : std_logic_vector(6 downto 0);
  signal TX_DATA_N_wire_dly       : std_logic_vector(7 downto 0);
  signal TX_DATA_P_wire_dly       : std_logic_vector(7 downto 0);

  type slv_8192x64 is array(0 to 8192) of std_logic_vector(63 downto 0);
  signal ram                      : slv_8192x64 := (others=>(others=>'0'));

  signal addr_inc                 : integer;

  signal set_ctrl                 : std_logic;
  signal set_ctrl_busy            : std_logic;
  signal set_ctrl_addr            : std_logic_vector(15 downto 0);
  signal set_ctrl_data            : std_logic_vector(31 downto 0);
  signal set_status               : std_logic;
  signal set_status_busy          : std_logic;
  signal set_status_addr          : std_logic_vector(15 downto 0);
  signal set_status_data          : std_logic_vector(31 downto 0);
  signal set_ram                  : std_logic;
  signal set_ram_addr             : integer;
  signal set_ram_data             : std_logic_vector(63 downto 0);

begin

  -------------------------------------------------------------------------------
  -- Create Clock Process
  -------------------------------------------------------------------------------
  proc_create_axis_clk : process
  begin
    axis_clk          <= '1';
    wait for AXIS_CLOCK_PERIOD/2;
    axis_clk          <= '0';
    wait for AXIS_CLOCK_PERIOD/2;
  end process;

  proc_create_clock_100MHz : process
  begin
    clk_100MHz        <= '0';
    wait for CLOCK_PERIOD_100MHz/2;
    clk_100MHz        <= '1';
    wait for CLOCK_PERIOD_100MHz/2;
  end process;

  -------------------------------------------------------------------------------
  -- Reset Process
  -------------------------------------------------------------------------------
  proc_reset : process
  begin
    reset             <= '1';
    wait for 20*CLOCK_PERIOD_100MHz;
    reset             <= '0';
    wait;
  end process;

  proc_axis_rst_n : process
  begin
    axis_rst_n        <= '0';
    wait for 20*AXIS_CLOCK_PERIOD;
    axis_rst_n        <= '1';
    wait;
  end process;

  -------------------------------------------------------------------------------
  -- Timeout Process
  -------------------------------------------------------------------------------
  proc_timeout : process
  begin
    wait for TIMEOUT;
    assert(FALSE)
      report "ERROR: Simulation timed out."
      severity FAILURE;
    wait;
  end process;

  -------------------------------------------------------------------------------
  -- Components
  -------------------------------------------------------------------------------
  inst_ps_pl_interface : ps_pl_interface
    generic map (
      C_BASEADDR                                => x"40000000",
      C_HIGHADDR                                => x"4001ffff")
    port map (
      clk                                       => axis_clk,
      rst_n                                     => axis_rst_n,
      S_AXI_AWADDR                              => S_AXI_AWADDR,
      S_AXI_AWVALID                             => S_AXI_AWVALID,
      S_AXI_AWREADY                             => S_AXI_AWREADY,
      S_AXI_WDATA                               => S_AXI_WDATA,
      S_AXI_WSTRB                               => S_AXI_WSTRB,
      S_AXI_WVALID                              => S_AXI_WVALID,
      S_AXI_WREADY                              => S_AXI_WREADY,
      S_AXI_BRESP                               => S_AXI_BRESP,
      S_AXI_BVALID                              => S_AXI_BVALID,
      S_AXI_BREADY                              => S_AXI_BREADY,
      S_AXI_ARADDR                              => S_AXI_ARADDR,
      S_AXI_ARVALID                             => S_AXI_ARVALID,
      S_AXI_ARREADY                             => S_AXI_ARREADY,
      S_AXI_RDATA                               => S_AXI_RDATA,
      S_AXI_RRESP                               => S_AXI_RRESP,
      S_AXI_RVALID                              => S_AXI_RVALID,
      S_AXI_RREADY                              => S_AXI_RREADY,
      M_AXI_AWADDR                              => M_AXI_AWADDR,
      M_AXI_AWPROT                              => M_AXI_AWPROT,
      M_AXI_AWVALID                             => M_AXI_AWVALID,
      M_AXI_AWREADY                             => M_AXI_AWREADY,
      M_AXI_WDATA                               => M_AXI_WDATA,
      M_AXI_WSTRB                               => M_AXI_WSTRB,
      M_AXI_WVALID                              => M_AXI_WVALID,
      M_AXI_WREADY                              => M_AXI_WREADY,
      M_AXI_BRESP                               => M_AXI_BRESP,
      M_AXI_BVALID                              => M_AXI_BVALID,
      M_AXI_BREADY                              => M_AXI_BREADY,
      M_AXI_AWLEN                               => M_AXI_AWLEN,
      M_AXI_AWSIZE                              => M_AXI_AWSIZE,
      M_AXI_AWBURST                             => M_AXI_AWBURST,
      M_AXI_AWCACHE                             => M_AXI_AWCACHE,
      M_AXI_AWUSER                              => M_AXI_AWUSER,
      M_AXI_WLAST                               => M_AXI_WLAST,
      M_AXI_ARADDR                              => M_AXI_ARADDR,
      M_AXI_ARPROT                              => M_AXI_ARPROT,
      M_AXI_ARVALID                             => M_AXI_ARVALID,
      M_AXI_ARREADY                             => M_AXI_ARREADY,
      M_AXI_RDATA                               => M_AXI_RDATA,
      M_AXI_RRESP                               => M_AXI_RRESP,
      M_AXI_RVALID                              => M_AXI_RVALID,
      M_AXI_RREADY                              => M_AXI_RREADY,
      M_AXI_RLAST                               => M_AXI_RLAST,
      M_AXI_ARCACHE                             => M_AXI_ARCACHE,
      M_AXI_ARUSER                              => M_AXI_ARUSER,
      M_AXI_ARLEN                               => M_AXI_ARLEN,
      M_AXI_ARBURST                             => M_AXI_ARBURST,
      M_AXI_ARSIZE                              => M_AXI_ARSIZE,
      irq                                       => irq,
      rst_glb_n                                 => rst_glb_n,
      -- Note: Master 0 & Slave 0 interfaces are occupied by the
      --       datamover component internally.
      axis_master_1_tvalid                      => axis_master_1_tvalid,
      axis_master_1_tready                      => axis_master_1_tready,
      axis_master_1_tdata                       => axis_master_1_tdata,
      axis_master_1_tdest                       => axis_master_1_tdest,
      axis_master_1_tlast                       => axis_master_1_tlast,
      axis_master_1_irq                         => axis_master_1_irq,
      axis_slave_1_tvalid                       => axis_slave_1_tvalid,
      axis_slave_1_tready                       => axis_slave_1_tready,
      axis_slave_1_tdata                        => axis_slave_1_tdata,
      axis_slave_1_tid                          => axis_slave_1_tid,
      axis_slave_1_tlast                        => axis_slave_1_tlast,
      axis_slave_1_irq                          => axis_slave_1_irq,
      status_1_addr                             => status_1_addr,
      status_1_data                             => status_1_data,
      status_1_stb                              => status_1_stb,
      ctrl_1_addr                               => ctrl_1_addr,
      ctrl_1_data                               => ctrl_1_data,
      ctrl_1_stb                                => ctrl_1_stb,
      axis_master_2_tvalid                      => axis_master_2_tvalid,
      axis_master_2_tready                      => axis_master_2_tready,
      axis_master_2_tdata                       => axis_master_2_tdata,
      axis_master_2_tdest                       => axis_master_2_tdest,
      axis_master_2_tlast                       => axis_master_2_tlast,
      axis_master_2_irq                         => axis_master_2_irq,
      axis_slave_2_tvalid                       => axis_slave_2_tvalid,
      axis_slave_2_tready                       => axis_slave_2_tready,
      axis_slave_2_tdata                        => axis_slave_2_tdata,
      axis_slave_2_tid                          => axis_slave_2_tid,
      axis_slave_2_tlast                        => axis_slave_2_tlast,
      axis_slave_2_irq                          => axis_slave_2_irq,
      status_2_addr                             => status_2_addr,
      status_2_data                             => status_2_data,
      status_2_stb                              => status_2_stb,
      ctrl_2_addr                               => ctrl_2_addr,
      ctrl_2_data                               => ctrl_2_data,
      ctrl_2_stb                                => ctrl_2_stb,
      axis_master_3_tvalid                      => axis_master_3_tvalid,
      axis_master_3_tready                      => axis_master_3_tready,
      axis_master_3_tdata                       => axis_master_3_tdata,
      axis_master_3_tdest                       => axis_master_3_tdest,
      axis_master_3_tlast                       => axis_master_3_tlast,
      axis_master_3_irq                         => axis_master_3_irq,
      axis_slave_3_tvalid                       => axis_slave_3_tvalid,
      axis_slave_3_tready                       => axis_slave_3_tready,
      axis_slave_3_tdata                        => axis_slave_3_tdata,
      axis_slave_3_tid                          => axis_slave_3_tid,
      axis_slave_3_tlast                        => axis_slave_3_tlast,
      axis_slave_3_irq                          => axis_slave_3_irq,
      status_3_addr                             => status_3_addr,
      status_3_data                             => status_3_data,
      status_3_stb                              => status_3_stb,
      ctrl_3_addr                               => ctrl_3_addr,
      ctrl_3_data                               => ctrl_3_data,
      ctrl_3_stb                                => ctrl_3_stb,
      axis_master_4_tvalid                      => axis_master_4_tvalid,
      axis_master_4_tready                      => axis_master_4_tready,
      axis_master_4_tdata                       => axis_master_4_tdata,
      axis_master_4_tdest                       => axis_master_4_tdest,
      axis_master_4_tlast                       => axis_master_4_tlast,
      axis_master_4_irq                         => axis_master_4_irq,
      axis_slave_4_tvalid                       => axis_slave_4_tvalid,
      axis_slave_4_tready                       => axis_slave_4_tready,
      axis_slave_4_tdata                        => axis_slave_4_tdata,
      axis_slave_4_tid                          => axis_slave_4_tid,
      axis_slave_4_tlast                        => axis_slave_4_tlast,
      axis_slave_4_irq                          => axis_slave_4_irq,
      status_4_addr                             => status_4_addr,
      status_4_data                             => status_4_data,
      status_4_stb                              => status_4_stb,
      ctrl_4_addr                               => ctrl_4_addr,
      ctrl_4_data                               => ctrl_4_data,
      ctrl_4_stb                                => ctrl_4_stb,
      axis_master_5_tvalid                      => axis_master_5_tvalid,
      axis_master_5_tready                      => axis_master_5_tready,
      axis_master_5_tdata                       => axis_master_5_tdata,
      axis_master_5_tdest                       => axis_master_5_tdest,
      axis_master_5_tlast                       => axis_master_5_tlast,
      axis_master_5_irq                         => axis_master_5_irq,
      axis_slave_5_tvalid                       => axis_slave_5_tvalid,
      axis_slave_5_tready                       => axis_slave_5_tready,
      axis_slave_5_tdata                        => axis_slave_5_tdata,
      axis_slave_5_tid                          => axis_slave_5_tid,
      axis_slave_5_tlast                        => axis_slave_5_tlast,
      axis_slave_5_irq                          => axis_slave_5_irq,
      status_5_addr                             => status_5_addr,
      status_5_data                             => status_5_data,
      status_5_stb                              => status_5_stb,
      ctrl_5_addr                               => ctrl_5_addr,
      ctrl_5_data                               => ctrl_5_data,
      ctrl_5_stb                                => ctrl_5_stb,
      axis_master_6_tvalid                      => axis_master_6_tvalid,
      axis_master_6_tready                      => axis_master_6_tready,
      axis_master_6_tdata                       => axis_master_6_tdata,
      axis_master_6_tdest                       => axis_master_6_tdest,
      axis_master_6_tlast                       => axis_master_6_tlast,
      axis_master_6_irq                         => axis_master_6_irq,
      axis_slave_6_tvalid                       => axis_slave_6_tvalid,
      axis_slave_6_tready                       => axis_slave_6_tready,
      axis_slave_6_tdata                        => axis_slave_6_tdata,
      axis_slave_6_tid                          => axis_slave_6_tid,
      axis_slave_6_tlast                        => axis_slave_6_tlast,
      axis_slave_6_irq                          => axis_slave_6_irq,
      status_6_addr                             => status_6_addr,
      status_6_data                             => status_6_data,
      status_6_stb                              => status_6_stb,
      ctrl_6_addr                               => ctrl_6_addr,
      ctrl_6_data                               => ctrl_6_data,
      ctrl_6_stb                                => ctrl_6_stb,
      axis_master_7_tvalid                      => axis_master_7_tvalid,
      axis_master_7_tready                      => axis_master_7_tready,
      axis_master_7_tdata                       => axis_master_7_tdata,
      axis_master_7_tdest                       => axis_master_7_tdest,
      axis_master_7_tlast                       => axis_master_7_tlast,
      axis_master_7_irq                         => axis_master_7_irq,
      axis_slave_7_tvalid                       => axis_slave_7_tvalid,
      axis_slave_7_tready                       => axis_slave_7_tready,
      axis_slave_7_tdata                        => axis_slave_7_tdata,
      axis_slave_7_tid                          => axis_slave_7_tid,
      axis_slave_7_tlast                        => axis_slave_7_tlast,
      axis_slave_7_irq                          => axis_slave_7_irq,
      status_7_addr                             => status_7_addr,
      status_7_data                             => status_7_data,
      status_7_stb                              => status_7_stb,
      ctrl_7_addr                               => ctrl_7_addr,
      ctrl_7_data                               => ctrl_7_data,
      ctrl_7_stb                                => ctrl_7_stb);

  -- Accelerator 1
  inst_usrp_ddr_intf_axis : usrp_ddr_intf_axis
    generic map (
      DDR_CLOCK_FREQ                            => 100e6,
      BAUD                                      => 10e6)
    port map (
      UART_TX                                   => UART_TX,
      RX_DATA_CLK_N                             => RX_DATA_CLK_N_wire_dly,
      RX_DATA_CLK_P                             => RX_DATA_CLK_P_wire_dly,
      RX_DATA_N                                 => RX_DATA_N_wire_dly,
      RX_DATA_P                                 => RX_DATA_P_wire_dly,
      TX_DATA_N                                 => TX_DATA_N,
      TX_DATA_P                                 => TX_DATA_P,
      clk                                       => axis_clk,
      rst_n                                     => rst_glb_n,
      status_addr                               => status_1_addr,
      status_data                               => status_1_data,
      status_stb                                => status_1_stb,
      ctrl_addr                                 => ctrl_1_addr,
      ctrl_data                                 => ctrl_1_data,
      ctrl_stb                                  => ctrl_1_stb,
      axis_slave_tvalid                         => axis_slave_1_tvalid,
      axis_slave_tready                         => axis_slave_1_tready,
      axis_slave_tdata                          => axis_slave_1_tdata,
      axis_slave_tid                            => axis_slave_1_tid,
      axis_slave_tlast                          => axis_slave_1_tlast,
      axis_slave_irq                            => axis_slave_1_irq,
      axis_master_tvalid                        => axis_master_1_tvalid,
      axis_master_tready                        => axis_master_1_tready,
      axis_master_tdata                         => axis_master_1_tdata,
      axis_master_tdest                         => axis_master_1_tdest,
      axis_master_tlast                         => axis_master_1_tlast,
      axis_master_irq                           => axis_master_1_irq,
      rx_enable_aux                             => rx_enable_aux,
      tx_enable_aux                             => tx_enable_aux);

  rx_enable_aux                                 <= '0';
  tx_enable_aux                                 <= threshold_exceeded OR threshold_not_exceeded;

  -- Accelerator 2
  inst_spectrum_sense : spectrum_sense
    port map (
      clk                                       => axis_clk,
      rst_n                                     => rst_glb_n,
      status_addr                               => status_2_addr,
      status_data                               => status_2_data,
      status_stb                                => status_2_stb,
      ctrl_addr                                 => ctrl_2_addr,
      ctrl_data                                 => ctrl_2_data,
      ctrl_stb                                  => ctrl_2_stb,
      axis_slave_tvalid                         => axis_slave_2_tvalid,
      axis_slave_tready                         => axis_slave_2_tready,
      axis_slave_tdata                          => axis_slave_2_tdata,
      axis_slave_tid                            => axis_slave_2_tid,
      axis_slave_tlast                          => axis_slave_2_tlast,
      axis_slave_irq                            => axis_slave_2_irq,
      axis_master_tvalid                        => axis_master_2_tvalid,
      axis_master_tready                        => axis_master_2_tready,
      axis_master_tdata                         => axis_master_2_tdata,
      axis_master_tdest                         => axis_master_2_tdest,
      axis_master_tlast                         => axis_master_2_tlast,
      axis_master_irq                           => axis_master_2_irq,
      threshold_not_exceeded                    => threshold_not_exceeded,
      threshold_not_exceeded_stb                => threshold_not_exceeded_stb,
      threshold_exceeded                        => threshold_exceeded,
      threshold_exceeded_stb                    => threshold_exceeded_stb);

  -- Accelerator 3
  inst_bpsk_mod : bpsk_mod
    port map (
      clk                                       => axis_clk,
      rst_n                                     => rst_glb_n,
      status_addr                               => status_3_addr,
      status_data                               => status_3_data,
      status_stb                                => status_3_stb,
      ctrl_addr                                 => ctrl_3_addr,
      ctrl_data                                 => ctrl_3_data,
      ctrl_stb                                  => ctrl_3_stb,
      axis_slave_tvalid                         => axis_slave_3_tvalid,
      axis_slave_tready                         => axis_slave_3_tready,
      axis_slave_tdata                          => axis_slave_3_tdata,
      axis_slave_tid                            => axis_slave_3_tid,
      axis_slave_tlast                          => axis_slave_3_tlast,
      axis_slave_irq                            => axis_slave_3_irq,
      axis_master_tvalid                        => axis_master_3_tvalid,
      axis_master_tready                        => axis_master_3_tready,
      axis_master_tdata                         => axis_master_3_tdata,
      axis_master_tdest                         => axis_master_3_tdest,
      axis_master_tlast                         => axis_master_3_tlast,
      axis_master_irq                           => axis_master_3_irq,
      trigger_stb                               => trigger_stb);

  trigger_stb                                   <= threshold_exceeded_stb;

  -- Unused Accelerators
  axis_slave_4_tready                           <= '0';
  axis_slave_4_irq                              <= '0';
  axis_master_4_tvalid                          <= '0';
  axis_master_4_tdata                           <= x"0000000000000000";
  axis_master_4_tdest                           <= "000";
  axis_master_4_tlast                           <= '0';
  axis_master_4_irq                             <= '0';
  status_4_data                                 <= x"00000000";
  axis_slave_5_tready                           <= '0';
  axis_slave_5_irq                              <= '0';
  axis_master_5_tvalid                          <= '0';
  axis_master_5_tdata                           <= x"0000000000000000";
  axis_master_5_tdest                           <= "000";
  axis_master_5_tlast                           <= '0';
  axis_master_5_irq                             <= '0';
  status_5_data                                 <= x"00000000";
  axis_slave_6_tready                           <= '0';
  axis_slave_6_irq                              <= '0';
  axis_master_6_tvalid                          <= '0';
  axis_master_6_tdata                           <= x"0000000000000000";
  axis_master_6_tdest                           <= "000";
  axis_master_6_tlast                           <= '0';
  axis_master_6_irq                             <= '0';
  status_6_data                                 <= x"00000000";
  axis_slave_7_tready                           <= '0';
  axis_slave_7_irq                              <= '0';
  axis_master_7_tvalid                          <= '0';
  axis_master_7_tdata                           <= x"0000000000000000";
  axis_master_7_tdest                           <= "000";
  axis_master_7_tlast                           <= '0';
  axis_master_7_irq                             <= '0';
  status_7_data                                 <= x"00000000";

  -----------------------------------------------------------------------------
  -- CRASH DDR Interface (on USRP)
  -----------------------------------------------------------------------------
  inst_crash_ddr_intf : crash_ddr_intf
    generic map (
      CLOCK_FREQ                  => 100e6,
      BAUD                        => 10e6)
    port map (
      clk                         => clk_100MHz,
      reset                       => reset,
      RX_DATA_CLK_N               => RX_DATA_CLK_N,
      RX_DATA_CLK_P               => RX_DATA_CLK_P,
      RX_DATA_N                   => RX_DATA_N(6 downto 0),
      RX_DATA_P                   => RX_DATA_P(6 downto 0),
      TX_DATA_N                   => TX_DATA_N_wire_dly,
      TX_DATA_P                   => TX_DATA_P_wire_dly,
      UART_RX                     => UART_TX,
      adc_channel_a               => adc_channel_a,
      adc_channel_b               => adc_channel_b,
      adc_i                       => adc_i,
      adc_q                       => adc_q,
      dac_channel_a_in            => dac_channel_a_in,
      dac_channel_b_in            => dac_channel_b_in,
      dac_i_in                    => dac_i_in,
      dac_q_in                    => dac_q_in,
      dac_channel_a               => dac_channel_a,
      dac_channel_b               => dac_channel_b,
      dac_i                       => dac_i,
      dac_q                       => dac_q);

  -- Simulate delay due to MICTOR cable
  RX_DATA_CLK_N_wire_dly    <= transport RX_DATA_CLK_N after 13 ns;
  RX_DATA_CLK_P_wire_dly    <= transport RX_DATA_CLK_P after 13 ns;
  RX_DATA_N_wire_dly        <= transport RX_DATA_N after 11 ns;
  RX_DATA_P_wire_dly        <= transport RX_DATA_P after 11 ns;
  TX_DATA_N_wire_dly        <= transport TX_DATA_N after 11 ns;
  TX_DATA_P_wire_dly        <= transport TX_DATA_P after 11 ns;

  -------------------------------------------------------------------------------
  -- Create ADC Data
  -------------------------------------------------------------------------------
  proc_create_adc_data : process
    variable PHASE_ACCUM  : real := 0.0;
  begin
    adc_channel_a         <= (others=>'0');
    adc_i                 <= (others=>'0');
    adc_channel_b         <= (others=>'0');
    adc_q                 <= (others=>'0');
    wait until reset = '1';
    loop
      PHASE_ACCUM         := PHASE_ACCUM + 2.0*MATH_PI*0.5/100.0;   -- 500 KHz off center freq
      if (PHASE_ACCUM > 2.0*MATH_PI) then
        PHASE_ACCUM       := PHASE_ACCUM - 2.0*MATH_PI;
      end if;
      adc_channel_a       <= std_logic_vector(to_signed(integer(round((2.0**13.0-1.0)*cos(PHASE_ACCUM))),14));
      adc_channel_b       <= std_logic_vector(to_signed(integer(round((2.0**13.0-1.0)*sin(PHASE_ACCUM))),14));
      adc_i               <= std_logic_vector(to_signed(integer(round((2.0**13.0-1.0)*cos(PHASE_ACCUM))),24));
      adc_q               <= std_logic_vector(to_signed(integer(round((2.0**13.0-1.0)*sin(PHASE_ACCUM))),24));
      wait until clk_100MHz = '1';
    end loop;
  end process;

  -------------------------------------------------------------------------------
  -- Create DAC Data
  -------------------------------------------------------------------------------
  proc_create_dac_data : process
    variable PHASE_ACCUM  : real := 0.0;
  begin
    dac_channel_a_in      <= (others=>'0');
    dac_channel_b_in      <= (others=>'0');
    dac_i_in              <= (others=>'0');
    dac_q_in              <= (others=>'0');
    wait until reset = '1';
    loop
      PHASE_ACCUM         := PHASE_ACCUM + 2.0*MATH_PI*0.5/100.0;
      if (PHASE_ACCUM > 2.0*MATH_PI) then
        PHASE_ACCUM       := PHASE_ACCUM - 2.0*MATH_PI;
      end if;
      dac_channel_a_in    <= std_logic_vector(to_signed(integer(round((2.0**15.0-1.0)*cos(PHASE_ACCUM))),16));
      dac_channel_b_in    <= std_logic_vector(to_signed(integer(round((2.0**15.0-1.0)*sin(PHASE_ACCUM))),16));
      dac_i_in            <= std_logic_vector(to_signed(integer(round((2.0**15.0-1.0)*cos(PHASE_ACCUM))),24));
      dac_q_in            <= std_logic_vector(to_signed(integer(round((2.0**15.0-1.0)*sin(PHASE_ACCUM))),24));
      wait until axis_clk = '1';
    end loop;
  end process;

  -------------------------------------------------------------------------------
  -- AXI ACP Write & Read // Simulated memory accessed by AXI ACP interface
  -------------------------------------------------------------------------------
  proc_axi_acp_write : process(axis_clk,axis_rst_n)
    variable m_axi_awaddr_base  : integer := 0;
    variable m_axi_awlen_cnt    : integer := 0;
    variable addr_inc           : integer := 0;
  begin
    if (axis_rst_n = '0') then
      M_AXI_AWREADY         <= '0';
      M_AXI_WREADY          <= '0';
      m_axi_awaddr_base     := 0;
      m_axi_awlen_cnt       := 0;
      addr_inc              := 0;
      ram                   <= (others=>(others=>'0'));
    else
      if rising_edge(axis_clk) then
        if (M_AXI_AWVALID = '1') then
          M_AXI_AWREADY     <= '1';
          if (m_axi_awlen_cnt = 0) then
            m_axi_awaddr_base := to_integer(unsigned(M_AXI_AWADDR(12 downto 0)));
          end if;
          m_axi_awlen_cnt   := m_axi_awlen_cnt + to_integer(unsigned(M_AXI_AWLEN));
        else
          M_AXI_AWREADY     <= '0';
        end if;

        if (M_AXI_WVALID = '1') then
          M_AXI_WREADY      <= '1';
          ram(m_axi_awaddr_base + addr_inc) <= M_AXI_WDATA;
          addr_inc          := addr_inc + 1;
          m_axi_awlen_cnt   := m_axi_awlen_cnt - 1;
        else
          M_AXI_WREADY      <= '0';
        end if;

        if (m_axi_awlen_cnt = 1) then
          addr_inc          := 0;
        end if;

        -- Manually fill RAM
        if (set_ram = '1') then
          ram(set_ram_addr) <= set_ram_data;
        end if;
      end if;
    end if;
  end process;

  M_AXI_BRESP             <= "00";
  M_AXI_BVALID            <= M_AXI_BREADY;

  proc_axi_acp_read : process(axis_clk)
    variable m_axi_arlen_cnt    : integer := 0;
    variable m_axi_araddr_base  : integer := 0;
    variable addr_inc           : integer := 0;
  begin
    if (axis_rst_n = '0') then
      M_AXI_ARREADY         <= '0';
      M_AXI_RVALID          <= '0';
      M_AXI_RLAST           <= '0';
      M_AXI_RDATA           <= (others=>'0');
      m_axi_arlen_cnt       := 0;
      m_axi_araddr_base     := 0;
      addr_inc              := 0;
    else
      if rising_edge(axis_clk) then
        if (m_axi_arlen_cnt > 0) then
          M_AXI_RVALID      <= '1';
          if (M_AXI_RREADY = '1') then
            M_AXI_RDATA     <= ram(m_axi_araddr_base + addr_inc);
            -- On last beat, set rlast
            if (m_axi_arlen_cnt = 1) then
              M_AXI_RLAST   <= '1';
            end if;
            if (addr_inc = 4096) then
              addr_inc      := 0;
            else
              addr_inc      := addr_inc + 1;
            end if;
            m_axi_arlen_cnt := m_axi_arlen_cnt - 1;
          end if;
        else
          addr_inc          := 0;
          M_AXI_RVALID      <= '0';
          M_AXI_RLAST       <= '0';
        end if;
        if (M_AXI_ARVALID = '1' AND M_AXI_ARREADY = '0') then
          M_AXI_ARREADY     <= '1';
          if (m_axi_arlen_cnt = 0) then
            m_axi_araddr_base := to_integer(unsigned(M_AXI_ARADDR(15 downto 3)));
          end if;
          m_axi_arlen_cnt   := m_axi_arlen_cnt + to_integer(unsigned(M_AXI_ARLEN)) + 1;
        else
          M_AXI_ARREADY     <= '0';
        end if;
      end if;
    end if;
  end process;

  M_AXI_RRESP               <= "00";

  -------------------------------------------------------------------------------
  -- AXI-Lite // interface to access control & status registers
  -------------------------------------------------------------------------------
  proc_axi_lite_ctrl_reg : process(axis_clk,axis_rst_n)
  begin
    if (axis_rst_n = '0') then
      S_AXI_AWADDR        <= (others=>'0');
      S_AXI_AWVALID       <= '0';
      S_AXI_WDATA         <= (others=>'0');
      S_AXI_WSTRB         <= (others=>'0');
      S_AXI_WVALID        <= '0';
      S_AXI_BREADY        <= '0';
      set_ctrl_busy       <= '0';
    else
      if rising_edge(axis_clk) then
        if (set_ctrl = '1') then
          -- Address left shifted by 2 due to access on word boundaries
          S_AXI_AWADDR    <= x"40000000" + (set_ctrl_addr & "00");
          S_AXI_AWVALID   <= '1';
          S_AXI_WDATA     <= set_ctrl_data;
          S_AXI_WVALID    <= '1';
          set_ctrl_busy   <= '1';
        end if;
        if (set_ctrl_busy = '1' AND S_AXI_WREADY = '1') then
          S_AXI_AWVALID   <= '0';
          S_AXI_WVALID    <= '0';
          set_ctrl_busy   <= '0';
        end if;
      end if;
    end if;
  end process;

  proc_axi_lite_status_reg : process(axis_clk,axis_rst_n)
  begin
    if (axis_rst_n = '0') then
      S_AXI_ARADDR        <= (others=>'0');
      S_AXI_ARVALID       <= '0';
      S_AXI_RREADY        <= '0';
      set_status_busy     <= '0';
      set_status_data     <= (others=>'0');
    else
      if rising_edge(axis_clk) then
        if (set_status = '1') then
          -- Address left shifted by 2 due to access on word boundaries
          S_AXI_ARADDR    <= x"40000000" + (set_status_addr & "00");
          S_AXI_ARVALID   <= '1';
          set_status_busy <= '1';
          S_AXI_RREADY    <= '1';
        end if;
        if (S_AXI_ARREADY = '1') then
          S_AXI_ARVALID   <= '0';
        end if;
        if (S_AXI_RVALID = '1') then
          S_AXI_RREADY    <= '0';
          set_status_data <= S_AXI_RDATA;
          set_status_busy <= '0';
        end if;
      end if;
    end if;
  end process;

  -------------------------------------------------------------------------------
  -- Test Bench
  -------------------------------------------------------------------------------
  proc_test_bench : process
  begin
    set_ctrl                    <= '0';
    set_ctrl_addr               <= (others=>'0');
    set_ctrl_data               <= (others=>'0');
    set_status                  <= '0';
    set_status_addr             <= (others=>'0');
    set_ram                     <= '0';
    set_ram_addr                <= 0;
    set_ram_data                <= (others=>'0');
    wait until axis_rst_n = '1';
    wait until axis_clk = '1';
    -----------------------------------------------------------------------------
    -- Set the first 4096 words of memory to a sine wave
    -----------------------------------------------------------------------------
    for i in 0 to 4095 loop
      set_ram                   <= '1';
      set_ram_addr              <= i;
      set_ram_data              <= (63 downto 48 => dac_channel_a_in(15)) & dac_channel_a_in & (31 downto 16 => dac_channel_b_in(15)) & dac_channel_b_in;
      wait until axis_clk = '1';
    end loop;
    set_ram                     <= '0';
    wait until axis_clk = '1';
    -----------------------------------------------------------------------------
    -- Test AXI ACP interface with a loopback. Set ps_pl_interface to
    -- read the first 256 words from memory and immediately write them back.
    -----------------------------------------------------------------------------
    -- Set ps_pl_interface Control Register Bank 2: MM2S Command Address
    --                       Accelerator & Register Bank
    set_ctrl_addr               <= x"00" & x"02";
    set_ctrl_data               <= (others=>'0');                             -- Address
    set_ctrl                    <= '1';
    wait until set_ctrl_busy = '1';
    set_ctrl                    <= '0';
    wait until set_ctrl_busy = '0';
    wait until axis_clk = '1';
    -- Set ps_pl_interface Control Register Bank 3: MM2S Command Size, Cache, tdest
    set_ctrl_addr               <= x"00" & x"03";
    ---- Send 64 words (64*8 bytes) and set the enable to push the command into the command FIFO
    set_ctrl_data               <= (others=>'0');
    set_ctrl_data(22 downto 0)  <= std_logic_vector(to_unsigned(256*8,23));   -- Number of bytes to transfer
    set_ctrl_data(25 downto 23) <= "000";                                     -- Tdest
    set_ctrl_data(31)           <= '1';                                       -- Push command to FIFO
    set_ctrl                    <= '1';
    wait until set_ctrl_busy = '1';
    set_ctrl                    <= '0';
    wait until set_ctrl_busy = '0';
    wait until axis_clk = '1';
    -- Set ps_pl_interface Control Register Bank 4: S2MM Command Address
    set_ctrl_addr               <= x"00" & x"04";
    set_ctrl_data               <= std_logic_vector(to_unsigned(0,32));     -- Address
    set_ctrl                    <= '1';
    wait until set_ctrl_busy = '1';
    set_ctrl                    <= '0';
    wait until set_ctrl_busy = '0';
    wait until axis_clk = '1';
    -- Set ps_pl_interface Control Register Bank 5: S2MM Command Size, Cache, tdest
    set_ctrl_addr               <= x"00" & x"05";
    set_ctrl_data               <= (others=>'0');
    set_ctrl_data(22 downto 0)  <= std_logic_vector(to_unsigned(256*8,23));   -- Number of bytes to transfer
    set_ctrl_data(25 downto 23) <= "000";                                     -- Tdest
    set_ctrl_data(31)           <= '1';                                       -- Push command to FIFO
    set_ctrl                    <= '1';
    wait until set_ctrl_busy = '1';
    set_ctrl                    <= '0';
    wait until set_ctrl_busy = '0';
    wait until axis_clk = '1';
    -- Wait for transfer to complete by checking if S2MM STS FIFO is empty
    set_status_addr             <= x"00" & x"08";
    set_status                  <= '1';
    wait until set_status_busy = '1';
    set_status                  <= '0';
    wait until set_status_busy = '0';
    wait until axis_clk = '1';
    ---- While S2MM STS FIFO is empty
    while (set_status_data(2) = '1') loop
      set_status                <= '1';
      wait until set_status_busy = '1';
      set_status                <= '0';
      wait until set_status_busy = '0';
      wait until axis_clk = '1';
    end loop;
    -- Read M2SS STS FIFO
    set_status_addr             <= x"00" & x"06";
    set_status                  <= '1';
    wait until set_status_busy = '1';
    set_status                  <= '0';
    wait until set_status_busy = '0';
    wait until axis_clk = '1';
    -- Read S2MM STS FIFO
    set_status_addr             <= x"00" & x"07";
    set_status                  <= '1';
    wait until set_status_busy = '1';
    set_status                  <= '0';
    wait until set_status_busy = '0';
    wait until axis_clk = '1';
    -----------------------------------------------------------------------------
    -- Test spectrum sensing. Setup spectrum_sense to enable FFT, discard
    -- output (i.e. do not route the FFT output to anywhere meaningful so it
    -- can constantly run), and trigger on threshold exceeded
    -----------------------------------------------------------------------------
    -- Set spectrum_sense Control Register Bank 1
    set_ctrl_addr               <= x"02" & x"01";
    set_ctrl_data               <= (others=>'0');
    set_ctrl_data(4 downto 0)   <= "00111";           -- FFT Size ("00111" = 128)
    set_ctrl_data(5)            <= '1';               -- Set FFT Size
    set_ctrl_data(9 downto 8)   <= "11";              -- FFT Mode "11", discard FFT output
    set_ctrl_data(10)           <= '1';               -- Enable IRQ
    set_ctrl_data(11)           <= '1';               -- Enable threshold exceeded sideband signal
    set_ctrl_data(13)           <= '1';               -- Enable clear threshold latched
    set_ctrl                    <= '1';
    wait until set_ctrl_busy = '1';
    set_ctrl                    <= '0';
    wait until set_ctrl_busy = '0';
    wait until axis_clk = '1';
    -- Set spectrum_sense Control Register Bank 0
    set_ctrl_addr               <= x"02" & x"00";
    set_ctrl_data               <= (others=>'0');
    set_ctrl_data(0)            <= '1';               -- Enable FFT
    set_ctrl                    <= '1';
    wait until set_ctrl_busy = '1';
    set_ctrl                    <= '0';
    wait until set_ctrl_busy = '0';
    wait until axis_clk = '1';
    -- Set spectrum_sense Control Register Bank 2
    set_ctrl_addr               <= x"02" & x"02";
    set_ctrl_data               <= x"40A00000";       -- Threshold level (floating point, value = 5.0)
    set_ctrl                    <= '1';
    wait until set_ctrl_busy = '1';
    set_ctrl                    <= '0';
    wait until set_ctrl_busy = '0';
    wait until axis_clk = '1';
    -----------------------------------------------------------------------------
    -- Setup usrp_ddr_interface_axis to enable RX, bypass TX floating to fixed
    -- point, set interp/decim rates, RX & TX gain, and MICTOR cable calibration.
    -----------------------------------------------------------------------------
    -- Set usrp_ddr_interface_axis Control Register Bank 0
    -- Note: Tdest can only be set when a transfer is not in progress (i.e.
    -- usrp_ddr_interface_axis rx_enable = 0). This prevents switching destinations
    -- in the middle of a transfer, which may cause problems with the AXI interconnect
    set_ctrl_addr               <= x"01" & x"00";
    set_ctrl_data               <= (others=>'0');
    set_ctrl_data(31 downto 29) <= "010";             -- Master Tdest
    set_ctrl                    <= '1';
    wait until set_ctrl_busy = '1';
    set_ctrl                    <= '0';
    wait until set_ctrl_busy = '0';
    wait until axis_clk = '1';
    -- Set usrp_ddr_interface_axis Control Register Bank 2
    set_ctrl_addr               <= x"01" & x"02";
    set_ctrl_data               <= (others=>'0');
    set_ctrl_data(23 downto 0)  <= std_logic_vector(to_unsigned(128,24)); -- RX packet size
    set_ctrl_data(24)           <= '0';                                   -- RX fix2float bypass
    set_ctrl_data(25)           <= '0';                                   -- RX CIC bypass
    set_ctrl_data(26)           <= '0';                                   -- RX Halfband bypass
    set_ctrl_data(27)           <= '1';                                   -- TX float2fix bypass
    set_ctrl_data(28)           <= '0';                                   -- TX CIC bypass
    set_ctrl_data(29)           <= '0';                                   -- TX Halfband bypass
    set_ctrl                    <= '1';
    wait until set_ctrl_busy = '1';
    set_ctrl                    <= '0';
    wait until set_ctrl_busy = '0';
    wait until axis_clk = '1';
    -- Set usrp_ddr_interface_axis Control Register Bank 3
    set_ctrl_addr               <= x"01" & x"03";
    set_ctrl_data               <= (others=>'0');
    set_ctrl_data(10 downto 0)  <= std_logic_vector(to_unsigned(4,11));   -- RX decimation
    set_ctrl_data(26 downto 16) <= std_logic_vector(to_unsigned(4,11));   -- TX interpolation
    set_ctrl                    <= '1';
    wait until set_ctrl_busy = '1';
    set_ctrl                    <= '0';
    wait until set_ctrl_busy = '0';
    wait until axis_clk = '1';
    -- Set usrp_ddr_interface_axis Control Register Bank 4, RX gain
    -- NOTE: If the CIC filter is bypassed, then gain can be safely set to 1 as our test sinusoid
    -- already uses the full dynamic range.
    set_ctrl_addr               <= x"01" & x"04";
    set_ctrl_data               <= std_logic_vector(to_unsigned(1,32));   -- RX gain
    set_ctrl                    <= '1';
    wait until set_ctrl_busy = '1';
    set_ctrl                    <= '0';
    wait until set_ctrl_busy = '0';
    wait until axis_clk = '1';
    -- Set usrp_ddr_interface_axis Control Register Bank 5, TX gain
    -- NOTE: If the CIC filter is bypassed, then gain can be safely set to 1 as our test sinusoid
    -- already uses the full dynamic range.
    set_ctrl_addr               <= x"01" & x"05";
    set_ctrl_data               <= std_logic_vector(to_unsigned(1,32));   -- TX gain
    set_ctrl                    <= '1';
    wait until set_ctrl_busy = '1';
    set_ctrl                    <= '0';
    wait until set_ctrl_busy = '0';
    wait until axis_clk = '1';
    -- Set MMCM phase values to calibrate MICTOR cable
    set_ctrl_addr               <= x"01" & x"06";
    set_ctrl_data               <= (others=>'0');
    set_ctrl_data(0)            <= '1';                                   -- RX restart calibration
    set_ctrl_data(10 downto 1)  <= std_logic_vector(to_unsigned(250,10)); -- RX phase
    set_ctrl_data(16)           <= '1';                                   -- TX restart calibration
    set_ctrl_data(26 downto 17) <= std_logic_vector(to_unsigned(150,10)); -- TX phase
    set_ctrl                    <= '1';
    wait until set_ctrl_busy = '1';
    set_ctrl                    <= '0';
    wait until set_ctrl_busy = '0';
    wait until axis_clk = '1';
    -- Read usrp_ddr_interface_axis Status Register 7 and wait until the link is re-calibrated
    set_status_addr             <= x"01" & x"07";
    set_status                  <= '1';
    wait until set_status_busy = '1';
    set_status                  <= '0';
    wait until set_status_busy = '0';
    wait until axis_clk = '1';
    ---- Wait for calibration busy
    while (set_status_data(3) = '1' OR set_status_data(4) = '1') loop
      set_status                <= '1';
      wait until set_status_busy = '1';
      set_status                <= '0';
      wait until set_status_busy = '0';
      wait until axis_clk = '1';
    end loop;
    wait until axis_clk = '1';
    set_status_addr             <= x"01" & x"07";
    set_status                  <= '1';
    wait until set_status_busy = '1';
    set_status                  <= '0';
    wait until set_status_busy = '0';
    wait until axis_clk = '1';
    ---- Wait for calibration to complete
    while (set_status_data(3) = '0' OR set_status_data(4) = '0') loop
      set_status                <= '1';
      wait until set_status_busy = '1';
      set_status                <= '0';
      wait until set_status_busy = '0';
      wait until axis_clk = '1';
    end loop;
    wait until axis_clk = '1';
    -- Enable RX to kickoff spectrum sensing. Route RX data to spectrum_sense
    set_ctrl_addr               <= x"01" & x"00";
    set_ctrl_data               <= (others=>'0');
    set_ctrl_data(0)            <= '1';               -- RX Enable
    set_ctrl_data(3)            <= '0';               -- TX Enable Aux
    set_ctrl_data(31 downto 29) <= "010";             -- Master Tdest
    set_ctrl                    <= '1';
    wait until set_ctrl_busy = '1';
    set_ctrl                    <= '0';
    wait until set_ctrl_busy = '0';
    wait until axis_clk = '1';
    -----------------------------------------------------------------------------
    -- Setup ps_pl_interface to transfer TX data from RAM to usrp_ddr_intf_axis
    -- which is AXI-Stream slave interface "001"
    -----------------------------------------------------------------------------
    -- Set ps_pl_interface Control Register Bank 2: MM2S Command Address
    set_ctrl_addr               <= x"00" & x"02";
    set_ctrl_data               <= (others=>'0');                             -- Address
    set_ctrl                    <= '1';
    wait until set_ctrl_busy = '1';
    set_ctrl                    <= '0';
    wait until set_ctrl_busy = '0';
    wait until axis_clk = '1';
    -- Set ps_pl_interface Control Register Bank 3: MM2S Command Size, Cache, tdest
    set_ctrl_addr               <= x"00" & x"03";
    set_ctrl_data               <= (others=>'0');
    set_ctrl_data(22 downto 0)  <= std_logic_vector(to_unsigned(4096*8,23));  -- Number of bytes to transfer
    set_ctrl_data(25 downto 23) <= "001";                                     -- Tdest
    set_ctrl_data(31)           <= '1';                                       -- Push command to FIFO
    set_ctrl                    <= '1';
    wait until set_ctrl_busy = '1';
    set_ctrl                    <= '0';
    wait until set_ctrl_busy = '0';
    wait until axis_clk = '1';
    -----------------------------------------------------------------------------
    -- Setup usrp_ddr_interface_axis control registers to enable TX to trigger
    -- if the spectrum sensing threshold is exceeded.
    -----------------------------------------------------------------------------
    -- Enable TX Enable Aux to kickoff the entire simulation
    -- Set usrp_ddr_interface_axis Control Register Bank 0
    set_ctrl_addr               <= x"01" & x"00";
    set_ctrl_data               <= (others=>'0');
    set_ctrl_data(0)            <= '1';               -- RX Enable
    set_ctrl_data(3)            <= '1';               -- TX Enable Aux
    set_ctrl_data(31 downto 29) <= "010";             -- Master Tdest
    set_ctrl                    <= '1';
    wait until set_ctrl_busy = '1';
    set_ctrl                    <= '0';
    wait until set_ctrl_busy = '0';
    wait until axis_clk = '1';
    wait;
  end process;

end architecture;
