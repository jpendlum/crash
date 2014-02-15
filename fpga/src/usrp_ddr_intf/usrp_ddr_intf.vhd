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
--  File: usrp_ddr_intf.vhd
--  Author: Jonathon Pendlum (jon.pendlum@gmail.com)
--  Description: Interfaces transmit and receive data between the FPGA
--               development board and the USRP N2xx and includes
--               RX decimation and TX interpolation filters with rate changes
--               from 1 to 8188. Includes fixed point to floating point
--               converts (bypassable) and multipliers for gain correction.
--               Most components are based on Xilinx IP.
--
--               Converts DDR input data (data transitions on both rising and
--               falling edges) to SDR data (data transition only on rising
--               edge). To conserve pins at the physical interface, the DDR
--               data runs at twice the SDR data rate. This means the SDR
--               data is split across two clocks, i.e. for 16-bit data the
--               upper byte is sent first, then the lower byte second.
--
--               The interface has independent RX and TX PLLs for calibration/
--               The calibration procedure requires putting the custom
--               firmware running on the USRP into RX_TEST_PATTERN_MODE. The
--               RX PLL is shifted until the RX data matches the pattern
--               without error. Then, the custom USRP firmware is set into
--               RX_TX_LOOPBACK_MODE and a unique pattern sent to the USRP
--               through this block. The TX PLL can be adjusted until the same
--               pattern is received back with errors. This entire process is
--               automated in a software program called calibrate provided
--               with the framework code.
--
--               A UART is used to control the custom firmware running on
--               the USRP that receives RX/ADC data and injects our TX/DAC data.
--
--               The RX and TX filter paths use two FIR and one CIC filter
--               per path per I & Q. This results in 8 FIR filters and 4
--               CIC filters. The FIR filters are half-band 23 tap filters
--               with +60 dB out of band attenuation.
--
--               Note: The USRP operates at 100 MHz.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
library unisim;
use unisim.vcomponents.all;

entity usrp_ddr_intf is
  generic (
    DDR_CLOCK_FREQ          : integer := 100e6;       -- Clock rate of DDR interface
    BAUD                    : integer := 115200);     -- UART baud rate
  port (
    reset                   : in    std_logic;                      -- Asynchronous reset
    -- Control registers (internally synchronized to clk_rx clock domain)
    usrp_mode_ctrl          : in    std_logic_vector(7 downto 0);   -- USRP Mode
    usrp_mode_ctrl_en       : in    std_logic;                      -- USRP Mode data valid, hold until acknowledge
    usrp_mode_ctrl_ack      : out   std_logic;                      -- USRP Mode register acknowledge
    rx_enable               : in    std_logic;                      -- Enable RX processing chain (clears resets)
    rx_gain                 : in    std_logic_vector(31 downto 0);  -- Scales decimating CIC filter output
    rx_cic_decim            : in    std_logic_vector(10 downto 0);  -- Receive CIC decimation rate
    rx_cic_decim_en         : in    std_logic;                      -- Set receive CIC decimation rate
    rx_cic_decim_ack        : out   std_logic;                      -- Set receive CIC decimation rate acknowledge
    rx_fix2float_bypass     : in    std_logic;                      -- Bypass RX fixed to floating point conversion
    rx_cic_bypass           : in    std_logic;                      -- Bypass RX CIC filter
    rx_hb_bypass            : in    std_logic;                      -- Bypass RX half band filter
    tx_enable               : in    std_logic;                      -- Enable TX processing chain (clears resets)
    tx_gain                 : in    std_logic_vector(31 downto 0);  -- Scales interpolating CIC filter output
    tx_cic_interp           : in    std_logic_vector(10 downto 0);  -- Transmit CIC interpolation rate
    tx_cic_interp_en        : in    std_logic;                      -- Set transmit CIC interpolation rate
    tx_cic_interp_ack       : out   std_logic;                      -- Set transmit CIC interpolation rate acknowledge
    tx_float2fix_bypass     : in    std_logic;                      -- Bypass TX floating to fixed point conversion
    tx_cic_bypass           : in    std_logic;                      -- Bypass TX CIC filter
    tx_hb_bypass            : in    std_logic;                      -- Bypass TX half band filter
    -- UART output signals
    uart_busy               : out   std_logic;                      -- UART busy
    UART_TX                 : out   std_logic;                      -- UART
    -- Physical Transmit / Receive data interface
    RX_DATA_CLK_N           : in    std_logic;                      -- Receive data clock (N)
    RX_DATA_CLK_P           : in    std_logic;                      -- Receive data clock (P)
    RX_DATA_N               : in    std_logic_vector(6 downto 0);   -- Receive data (N)
    RX_DATA_P               : in    std_logic_vector(6 downto 0);   -- Receive data (N)
    TX_DATA_N               : out   std_logic_vector(7 downto 0);   -- Transmit data (N)
    TX_DATA_P               : out   std_logic_vector(7 downto 0);   -- Transmit data (P)
    clk_rx_locked           : out   std_logic;                      -- RX data MMCM clock locked
    clk_rx_phase            : out   std_logic_vector(9 downto 0);   -- RX data MMCM phase offset, 0 - 559
    rx_phase_init           : in    std_logic_vector(9 downto 0);   -- RX data MMCM phase offset initialization, 0 - 559
    rx_phase_incdec         : in    std_logic;                      -- '1' = Increment, '0' = Decrement
    rx_phase_en             : in    std_logic;                      -- Increment / decrements RX data MMCM phase (Rising edge)
    rx_phase_busy           : out   std_logic;                      -- RX data MMCM phase adjustment in process
    rx_restart_cal          : in    std_logic;                      -- Restart RX data MMCM phase calibration
    rx_cal_complete         : out   std_logic;                      -- RX data MMCM phase calibration complete
    clk_tx_locked           : out   std_logic;                      -- TX data MMCM clock locked
    clk_tx_phase            : out   std_logic_vector(9 downto 0);   -- TX data MMCM phase offset, 0 - 559
    tx_phase_init           : in    std_logic_vector(9 downto 0);   -- TX data MMCM phase offset initialization, 0 - 559
    tx_phase_incdec         : in    std_logic;                      -- '1' = Increment, '0' = Decrement
    tx_phase_en             : in    std_logic;                      -- Increment / decrements TX data MMCM phase (Rising edge)
    tx_phase_busy           : out   std_logic;                      -- TX data MMCM phase adjustment in process
    tx_restart_cal          : in    std_logic;                      -- Restart TX data MMCM phase calibration
    tx_cal_complete         : out   std_logic;                      -- TX data MMCM phase calibration complete
    -- Receive data FIFO interface (all signals on clk_rx_fifo clock domain)
    clk_rx_fifo             : in    std_logic;                      -- Receive data FIFO clock
    rx_fifo_reset           : in    std_logic;                      -- Receive data FIFO reset
    rx_fifo_data_i          : out   std_logic_vector(31 downto 0);  -- Receive data FIFO output
    rx_fifo_data_q          : out   std_logic_vector(31 downto 0);  -- Receive data FIFO output
    rx_fifo_rd_en           : in    std_logic;                      -- Receive data FIFO read enable
    rx_fifo_underflow       : out   std_logic;                      -- Receive data FIFO underflow
    rx_fifo_empty           : out   std_logic;                      -- Receive data FIFO empty
    rx_fifo_almost_empty    : out   std_logic;                      -- Receive data FIFO almost empty
    rx_fifo_overflow_latch  : out   std_logic;                      -- Receive data FIFO overflow (clears on reset)
    -- Receive data FIFO interface (all signals on clk_tx_fifo clock domain)
    clk_tx_fifo             : in    std_logic;                      -- Transmit data FIFO clock
    tx_fifo_reset           : in    std_logic;                      -- Transmit data FIFO reset
    tx_fifo_data_i          : in    std_logic_vector(31 downto 0);  -- Transmit data FIFO output
    tx_fifo_data_q          : in    std_logic_vector(31 downto 0);  -- Transmit data FIFO output
    tx_fifo_wr_en           : in    std_logic;                      -- Transmit data FIFO write enable
    tx_fifo_overflow        : out   std_logic;                      -- Transmit data FIFO overflow
    tx_fifo_full            : out   std_logic;                      -- Transmit data FIFO full
    tx_fifo_almost_full     : out   std_logic;                      -- Transmit data FIFO almost full
    tx_fifo_underflow_latch : out   std_logic);                     -- Transmit data FIFO underflow (clears on reset)
end entity;

architecture RTL of usrp_ddr_intf is

  -------------------------------------------------------------------------------
  -- Component Declaration
  -------------------------------------------------------------------------------
  component BUFG is
    port (
      O                         : out   std_logic;  -- Clock buffer output
      I                         : in    std_logic); -- Clock buffer input
  end component;

  component synchronizer is
    generic (
      STROBE_EDGE               : string    := "N";  -- "R"ising, "F"alling, "B"oth, or "N"one.
      RESET_OUTPUT              : std_logic := '0');
    port (
      clk                       : in    std_logic;
      reset                     : in    std_logic;
      async                     : in    std_logic;      -- Asynchronous input
      sync                      : out   std_logic);     -- Synchronized output
  end component;

  component synchronizer_slv is
    generic (
      STROBE_EDGE               : string           := "NONE";  -- "R"ising, "F"alling, "B"oth, or "N"one.
      RESET_OUTPUT              : std_logic_vector := "0");
    port (
      clk                       : in    std_logic;
      reset                     : in    std_logic;
      async                     : in    std_logic_vector;     -- Asynchronous input
      sync                      : out   std_logic_vector);     -- Synchronized output
  end component;

  component mmcm_ddr_to_sdr is
    port (
      CLKIN_100MHz              : in     std_logic;
      CLKOUT_100MHz             : out    std_logic;
      CLKOUT_200MHz             : out    std_logic;
      -- Dynamic phase shift ports
      PSCLK                     : in     std_logic;
      PSEN                      : in     std_logic;
      PSINCDEC                  : in     std_logic;
      PSDONE                    : out    std_logic;
      -- Status and control signals
      RESET                     : in     std_logic;
      LOCKED                    : out    std_logic);
  end component;

  component fifo_64x4096 is
    port (
      wr_rst                    : in std_logic;
      wr_clk                    : in std_logic;
      rd_rst                    : in std_logic;
      rd_clk                    : in std_logic;
      din                       : in std_logic_vector(63 downto 0);
      wr_en                     : in std_logic;
      rd_en                     : in std_logic;
      dout                      : out std_logic_vector(63 downto 0);
      full                      : out std_logic;
      almost_full               : out std_logic;
      empty                     : out std_logic;
      almost_empty              : out std_logic;
      overflow                  : out std_logic;
      underflow                 : out std_logic);
  end component;

  component uart is
    generic (
      CLOCK_FREQ        : integer := 100e6;           -- Input clock frequency (Hz)
      BAUD              : integer := 115200;          -- Baud rate (bits/sec)
      DATA_BITS         : integer := 8;               -- Number of data bits
      PARITY            : string  := "MARK";          -- EVEN, ODD, MARK (always = '1'), SPACE (always = '0'), NONE
      NO_STROBE_ON_ERR  : string  := "TRUE");         -- No rx_data_stb if error in received data.
    port (
      clk               : in    std_logic;            -- Clock
      reset             : in    std_logic;            -- Active high reset
      tx_busy           : out   std_logic;            -- Transmitting data
      tx_data_stb       : in    std_logic;            -- Transmit buffer load and begin transmission strobe
      tx_data           : in    std_logic_vector(DATA_BITS-1 downto 0);
      rx_busy           : out   std_logic;            -- Receiving data
      rx_data_stb       : out   std_logic;            -- Receive buffer data valid strobe
      rx_data           : out   std_logic_vector(DATA_BITS-1 downto 0);
      rx_error          : out   std_logic;            -- '1' = Invalid parity bit, start bit, or stop bit(s)
      tx                : out   std_logic;            -- TX output
      rx                : in    std_logic);           -- RX input
  end component;

  component fifo_32to16
    port (
      rst               : in    std_logic;
      wr_clk            : in    std_logic;
      rd_clk            : in    std_logic;
      din               : in    std_logic_vector(31 downto 0);
      wr_en             : in    std_logic;
      rd_en             : in    std_logic;
      dout              : out   std_logic_vector(15 downto 0);
      full              : out   std_logic;
      empty             : out   std_logic);
  end component;

  component fifo_14to28
    port (
      rst               : in    std_logic;
      wr_clk            : in    std_logic;
      rd_clk            : in    std_logic;
      din               : in    std_logic_vector(13 downto 0);
      wr_en             : in    std_logic;
      rd_en             : in    std_logic;
      dout              : out   std_logic_vector(27 downto 0);
      full              : out   std_logic;
      empty             : out   std_logic);
  end component;

  component cic_decimator is
    port (
      din               : in    std_logic_vector(13 downto 0);
      rate              : in    std_logic_vector(10 downto 0);
      rate_we           : in    std_logic;
      sclr              : in    std_logic;
      clk               : in    std_logic;
      dout              : out   std_logic_vector(46 downto 0);
      nd                : in    std_logic;
      rdy               : out   std_logic;
      rfd               : out   std_logic);
  end component;

  component mult_rx_gain_adjust is
    port (
      clk               : in    std_logic;
      a                 : in    std_logic_vector(46 downto 0);
      b                 : in    std_logic_vector(31 downto 0);
      sclr              : in    std_logic;
      p                 : out   std_logic_vector(35 downto 0));
  end component;

  component fir_halfband_decimator is
    port (
      sclr              : in    std_logic;
      clk               : in    std_logic;
      nd                : in    std_logic;
      rfd               : out   std_logic;
      rdy               : out   std_logic;
      data_valid        : out   std_logic;
      din               : in    std_logic_vector(31 downto 0);
      dout              : out   std_logic_vector(31 downto 0));
  end component;

  component fix1_31_to_float32 is
    port (
      a                 : in    std_logic_vector(31 downto 0);
      clk               : in    std_logic;
      sclr              : in    std_logic;
      operation_nd      : in    std_logic;
      operation_rfd     : out   std_logic;
      rdy               : out   std_logic;
      result            : out   std_logic_vector(31 downto 0));
  end component;

  component cic_interpolator is
    port (
      din               : in    std_logic_vector(19 downto 0);
      rate              : in    std_logic_vector(10 downto 0);
      rate_we           : in    std_logic;
      sclr              : in    std_logic;
      clk               : in    std_logic;
      dout              : out   std_logic_vector(41 downto 0);
      nd                : in    std_logic;
      rdy               : out   std_logic;
      rfd               : out   std_logic);
  end component;

  component mult_tx_gain_adjust is
    port (
      clk               : in    std_logic;
      a                 : in    std_logic_vector(41 downto 0);
      b                 : in    std_logic_vector(31 downto 0);
      sclr              : in    std_logic;
      p                 : out   std_logic_vector(19 downto 0));
  end component;

  component fir_halfband_interpolator is
    port (
      sclr              : in    std_logic;
      clk               : in    std_logic;
      nd                : in    std_logic;
      ce                : in    std_logic;
      rfd               : out   std_logic;
      rdy               : out   std_logic;
      data_valid        : out   std_logic;
      din               : in    std_logic_vector(19 downto 0);
      dout              : out   std_logic_vector(19 downto 0));
  end component;

  component float32_to_fix1_19 is
    port (
      a                 : in    std_logic_vector(31 downto 0);
      clk               : in    std_logic;
      sclr              : in    std_logic;
      operation_nd      : in    std_logic;
      operation_rfd     : out   std_logic;
      rdy               : out   std_logic;
      result            : out   std_logic_vector(19 downto 0));
  end component;

  component trunc_unbiased is
    generic (
      WIDTH_IN          : integer;
      TRUNCATE          : integer);
    port (
      i                 : in    std_logic_vector(WIDTH_IN-1 downto 0);
      o                 : out   std_logic_vector(WIDTH_IN-TRUNCATE-1 downto 0));
  end component;

  -----------------------------------------------------------------------------
  -- Constants Declaration
  -----------------------------------------------------------------------------
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

  -------------------------------------------------------------------------------
  -- Signal Declaration
  -------------------------------------------------------------------------------
  type rx_state_type is (SET_RX_PHASE,WAIT_RX_PHASE,RX_CALIBRATION_COMPLETE);
  type tx_state_type is (SET_TX_PHASE,WAIT_TX_PHASE,TX_CALIBRATION_COMPLETE);

  signal rx_state                     : rx_state_type;
  signal tx_state                     : tx_state_type;

  signal clk_rx                       : std_logic;
  signal clk_rx_2x                    : std_logic;
  signal clk_tx                       : std_logic;
  signal clk_tx_2x                    : std_logic;
  signal ddr_data_clk                 : std_logic;
  signal ddr_data_clk_bufg            : std_logic;
  signal clk_rx_locked_int            : std_logic;
  signal clk_tx_locked_int            : std_logic;
  signal rx_reset                     : std_logic;
  signal tx_reset                     : std_logic;
  signal rx_psen                      : std_logic;
  signal rx_psincdec                  : std_logic;
  signal rx_psdone                    : std_logic;
  signal rx_phase_busy_int            : std_logic;
  signal tx_psen                      : std_logic;
  signal tx_psincdec                  : std_logic;
  signal tx_psdone                    : std_logic;
  signal tx_phase_busy_int            : std_logic;
  signal tx_busy                      : std_logic;
  signal tx_test_pattern_en           : std_logic;
  signal rx_mmcm_phase                : integer range 0 to 559;
  signal tx_mmcm_phase                : integer range 0 to 559;

  signal rx_async                     : std_logic_vector(67 downto 0);
  signal rx_sync                      : std_logic_vector(67 downto 0);
  signal rx_async_rising              : std_logic_vector(4 downto 0);
  signal rx_sync_rising               : std_logic_vector(4 downto 0);
  signal tx_async                     : std_logic_vector(58 downto 0);
  signal tx_sync                      : std_logic_vector(58 downto 0);
  signal tx_async_rising              : std_logic_vector(3 downto 0);
  signal tx_sync_rising               : std_logic_vector(3 downto 0);
  signal rx_phase_init_sync           : std_logic_vector(9 downto 0);
  signal rx_phase_incdec_sync         : std_logic;
  signal rx_phase_en_sync             : std_logic;
  signal tx_phase_init_sync           : std_logic_vector(9 downto 0);
  signal tx_phase_incdec_sync         : std_logic;
  signal tx_phase_en_sync             : std_logic;
  signal usrp_mode_ctrl_sync          : std_logic_vector(7 downto 0);
  signal usrp_mode_ctrl_en_sync       : std_logic;
  signal usrp_mode_ctrl_stb           : std_logic;
  signal rx_fix2float_bypass_sync     : std_logic;
  signal rx_cic_bypass_sync           : std_logic;
  signal rx_hb_bypass_sync            : std_logic;
  signal rx_cic_decim_sync            : std_logic_vector(10 downto 0);
  signal rx_cic_decim_en_sync         : std_logic;
  signal rx_cic_decim_stb             : std_logic;
  signal rx_gain_sync                 : std_logic_vector(31 downto 0);
  signal tx_float2fix_bypass_sync     : std_logic;
  signal tx_cic_bypass_sync           : std_logic;
  signal tx_hb_bypass_sync            : std_logic;
  signal tx_cic_interp_sync           : std_logic_vector(10 downto 0);
  signal tx_cic_interp_en_sync        : std_logic;
  signal tx_cic_interp_stb            : std_logic;
  signal tx_gain_sync                 : std_logic_vector(31 downto 0);
  signal rx_enable_sync               : std_logic;
  signal rx_enable_stb                : std_logic;
  signal rx_enable_n                  : std_logic;
  signal tx_enable_sync               : std_logic;
  signal tx_enable_stb                : std_logic;
  signal tx_enable_n                  : std_logic;
  signal usrp_mode_ctrl_ack_int       : std_logic;
  signal rx_restart_cal_sync          : std_logic;
  signal tx_restart_cal_sync          : std_logic;
  signal rx_cic_decim_ack_int         : std_logic;
  signal tx_cic_interp_ack_int        : std_logic;

  -- 2x FIFO signals
  signal tx_2x_fifo_din               : std_logic_vector(31 downto 0);
  signal tx_2x_fifo_full_n            : std_logic;
  signal tx_2x_fifo_empty_n           : std_logic;
  signal tx_2x_fifo_dout              : std_logic_vector(15 downto 0);
  signal tx_2x_fifo_full              : std_logic;
  signal tx_2x_fifo_empty             : std_logic;
  signal rx_2x_fifo_din               : std_logic_vector(13 downto 0);
  signal rx_2x_fifo_full_n            : std_logic;
  signal rx_2x_fifo_empty_n           : std_logic;
  signal rx_2x_fifo_dout              : std_logic_vector(27 downto 0);
  signal rx_2x_fifo_full              : std_logic;
  signal rx_2x_fifo_empty             : std_logic;

  -- RX signals
  signal rx_data_a                    : std_logic_vector(13 downto 0);
  signal rx_data_b                    : std_logic_vector(13 downto 0);
  signal rx_data_a_ddr                : std_logic_vector(13 downto 0);
  signal rx_data_b_ddr                : std_logic_vector(13 downto 0);
  signal rx_data_2x_a                 : std_logic_vector( 6 downto 0);
  signal rx_data_2x_b                 : std_logic_vector( 6 downto 0);
  signal rx_data_2x_ddr               : std_logic_vector( 6 downto 0);

  signal rx_cic_rate                  : std_logic_vector(10 downto 0);
  signal rx_cic_rate_we               : std_logic;

  signal rx_data_i                    : std_logic_vector(13 downto 0);
  signal rx_data_q                    : std_logic_vector(13 downto 0);
  signal rx_cic_nd                    : std_logic;
  signal rx_cic_din_i                 : std_logic_vector(13 downto 0);
  signal rx_cic_din_q                 : std_logic_vector(13 downto 0);
  signal rx_cic_dout_i                : std_logic_vector(46 downto 0);
  signal rx_cic_dout_q                : std_logic_vector(46 downto 0);
  signal rx_cic_rdy_i                 : std_logic;
  signal rx_cic_rfd_i                 : std_logic;
  signal rx_gain_din_i                : std_logic_vector(46 downto 0);
  signal rx_gain_din_q                : std_logic_vector(46 downto 0);
  signal rx_gain_dout_i               : std_logic_vector(35 downto 0);
  signal rx_gain_dout_q               : std_logic_vector(35 downto 0);
  signal rx_gain_dout_trunc_i         : std_logic_vector(31 downto 0);
  signal rx_gain_dout_trunc_q         : std_logic_vector(31 downto 0);
  signal rx_halfband_nd               : std_logic;
  signal rx_halfband_rfd_i            : std_logic;
  signal rx_halfband_dout_valid_i     : std_logic;
  signal rx_halfband_din_i            : std_logic_vector(31 downto 0);
  signal rx_halfband_dout_i           : std_logic_vector(31 downto 0);
  signal rx_halfband_din_q            : std_logic_vector(31 downto 0);
  signal rx_halfband_dout_q           : std_logic_vector(31 downto 0);
  signal rx_fix2float_nd              : std_logic;
  signal rx_fix2float_rfd_i           : std_logic;
  signal rx_fix2float_rdy_i           : std_logic;
  signal rx_fix2float_din_i           : std_logic_vector(31 downto 0);
  signal rx_fix2float_dout_i          : std_logic_vector(31 downto 0);
  signal rx_fix2float_din_q           : std_logic_vector(31 downto 0);
  signal rx_fix2float_dout_q          : std_logic_vector(31 downto 0);

  signal rx_fifo_wr_en                : std_logic;
  signal rx_fifo_wr_en_int            : std_logic;
  signal rx_fifo_rd_en_int            : std_logic;
  signal rx_fifo_empty_int            : std_logic;
  signal rx_fifo_full                 : std_logic;
  signal rx_fifo_almost_full          : std_logic;
  signal rx_fifo_overflow             : std_logic;
  signal rx_fifo_overflow_latch_int   : std_logic;
  signal rx_fifo_din                  : std_logic_vector(63 downto 0);
  signal rx_fifo_dout                 : std_logic_vector(63 downto 0);

  -- TX signals
  signal tx_data_i                    : std_logic_vector(31 downto 0);
  signal tx_data_q                    : std_logic_vector(31 downto 0);
  signal tx_data_a                    : std_logic_vector(15 downto 0);
  signal tx_data_b                    : std_logic_vector(15 downto 0);
  signal tx_data_2x_a                 : std_logic_vector( 7 downto 0);
  signal tx_data_2x_b                 : std_logic_vector( 7 downto 0);
  signal tx_data_2x_ddr               : std_logic_vector( 7 downto 0);

  signal tx_cic_rate                  : std_logic_vector(10 downto 0);
  signal tx_cic_rate_we               : std_logic;

  signal tx_cic_nd                    : std_logic;
  signal tx_cic_nd_int                : std_logic;
  signal tx_cic_din_i                 : std_logic_vector(19 downto 0);
  signal tx_cic_din_q                 : std_logic_vector(19 downto 0);
  signal tx_cic_dout_i                : std_logic_vector(41 downto 0);
  signal tx_cic_dout_q                : std_logic_vector(41 downto 0);
  signal tx_cic_rdy_i                 : std_logic;
  signal tx_cic_rfd_i                 : std_logic;
  signal tx_gain_din_i                : std_logic_vector(41 downto 0);
  signal tx_gain_din_q                : std_logic_vector(41 downto 0);
  signal tx_gain_dout_i               : std_logic_vector(19 downto 0);
  signal tx_gain_dout_q               : std_logic_vector(19 downto 0);
  signal tx_halfband_ce               : std_logic;
  signal tx_halfband_nd               : std_logic;
  signal tx_halfband_nd_int           : std_logic;
  signal tx_halfband_rfd_i            : std_logic;
  signal tx_halfband_dout_valid_i     : std_logic;
  signal tx_halfband_din_i            : std_logic_vector(19 downto 0);
  signal tx_halfband_dout_i           : std_logic_vector(19 downto 0);
  signal tx_halfband_din_q            : std_logic_vector(19 downto 0);
  signal tx_halfband_dout_q           : std_logic_vector(19 downto 0);
  signal tx_float2fix_nd              : std_logic;
  signal tx_float2fix_rfd_i           : std_logic;
  signal tx_float2fix_rdy_i           : std_logic;
  signal tx_float2fix_dout_i          : std_logic_vector(19 downto 0);
  signal tx_float2fix_dout_q          : std_logic_vector(19 downto 0);
  signal tx_trunc_din_i               : std_logic_vector(19 downto 0);
  signal tx_trunc_din_q               : std_logic_vector(19 downto 0);
  signal tx_trunc_dout_i              : std_logic_vector(15 downto 0);
  signal tx_trunc_dout_q              : std_logic_vector(15 downto 0);

  signal tx_fifo_wr_en_int            : std_logic;
  signal tx_fifo_rd_en                : std_logic;
  signal tx_fifo_rd_en_int            : std_logic;
  signal tx_fifo_full_int             : std_logic;
  signal tx_fifo_empty                : std_logic;
  signal tx_fifo_almost_empty         : std_logic;
  signal tx_fifo_underflow            : std_logic;
  signal tx_fifo_underflow_latch_int  : std_logic;
  signal tx_fifo_din                  : std_logic_vector(63 downto 0);
  signal tx_fifo_dout                 : std_logic_vector(63 downto 0);

begin

  inst_rx_clk_IBUFDS : IBUFDS
    generic map (
      DIFF_TERM                     => TRUE,
      IOSTANDARD                    => "DEFAULT")
    port map (
      I                             => RX_DATA_CLK_P,
      IB                            => RX_DATA_CLK_N,
      O                             => ddr_data_clk);

    -- Use a BUFG to buffer the DDR data clk
  inst_BUFG : BUFG
    port map (
      I                             => ddr_data_clk,
      O                             => ddr_data_clk_bufg);

  -----------------------------------------------------------------------------
  -- State machine to adjust the RX and TX data MMCM phase
  -----------------------------------------------------------------------------
  proc_calibrate_rx_mmcm : process(clk_rx,rx_reset)
  begin
    if (rx_reset = '1') then
      rx_mmcm_phase                   <= 0;
      rx_psincdec                     <= '0';
      rx_psen                         <= '0';
      rx_phase_busy_int               <= '0';
      rx_cal_complete                 <= '0';
      rx_state                        <= SET_RX_PHASE;
    else
      if rising_edge(clk_rx) then
        case rx_state is
          when SET_RX_PHASE =>
            if (rx_mmcm_phase /= rx_phase_init_sync) then
              rx_psincdec             <= '1';
              rx_psen                 <= '1';
              if (rx_mmcm_phase = 559) then
                rx_mmcm_phase         <= 0;
              else
                rx_mmcm_phase         <= rx_mmcm_phase + 1;
              end if;
              rx_state                <= WAIT_RX_PHASE;
            else
              rx_state                <= RX_CALIBRATION_COMPLETE;
            end if;

          when WAIT_RX_PHASE =>
            rx_psen                   <= '0';
            if (rx_psdone = '1') then
              rx_state                <= SET_RX_PHASE;
            end if;

          when RX_CALIBRATION_COMPLETE =>
            -- Only forward USRP DDR interface mode changes when
            -- we are not calibrating the interface.
            rx_cal_complete           <= '1';
            rx_psen                   <= '0';
            if (rx_restart_cal_sync = '1') then
              rx_cal_complete         <= '0';
              rx_state                <= SET_RX_PHASE;
            end if;
            -- Allow manual manipulation of MMCM phase
            if (rx_phase_en_sync = '1' AND rx_phase_busy_int = '0') then
              rx_psincdec             <= rx_phase_incdec_sync;
              rx_psen                 <= '1';
              rx_phase_busy_int       <= '1';
              -- Adjust mmcm phase counter based on whether we are incrementing
              -- or decrementing
              if (rx_phase_incdec_sync = '1') then
                if (rx_mmcm_phase = 559) then
                  rx_mmcm_phase       <= 0;
                else
                  rx_mmcm_phase       <= rx_mmcm_phase + 1;
                end if;
              else
                if (rx_mmcm_phase = 0) then
                  rx_mmcm_phase       <= 559;
                else
                  rx_mmcm_phase       <= rx_mmcm_phase - 1;
                end if;
              end if;
            end if;
            if (rx_psdone = '1') then
              rx_phase_busy_int       <= '0';
            end if;

          when others =>
            rx_state                  <= SET_RX_PHASE;
        end case;
      end if;
    end if;
  end process;

  proc_calibrate_tx_mmcm : process(clk_tx,tx_reset)
  begin
    if (tx_reset = '1') then
      tx_mmcm_phase                   <= 0;
      tx_psincdec                     <= '0';
      tx_psen                         <= '0';
      tx_phase_busy_int               <= '0';
      tx_cal_complete                 <= '0';
      tx_state                        <= SET_TX_PHASE;
    else
      if rising_edge(clk_tx) then
        case tx_state is
          when SET_TX_PHASE =>
            if (tx_mmcm_phase /= tx_phase_init_sync) then
              tx_psincdec             <= '1';
              tx_psen                 <= '1';
              if (tx_mmcm_phase = 559) then
                tx_mmcm_phase         <= 0;
              else
                tx_mmcm_phase         <= tx_mmcm_phase + 1;
              end if;
              tx_state                <= WAIT_TX_PHASE;
            else
              tx_state                <= TX_CALIBRATION_COMPLETE;
            end if;

          when WAIT_TX_PHASE =>
            tx_psen                   <= '0';
            if (tx_psdone = '1') then
              tx_state                <= SET_TX_PHASE;
            end if;

          when TX_CALIBRATION_COMPLETE =>
            tx_cal_complete           <= '1';
            tx_psen                   <= '0';
            if (tx_restart_cal_sync = '1') then
              tx_cal_complete         <= '0';
              tx_state                <= SET_TX_PHASE;
            end if;
            -- Allow manual manipulation of MMCM phase
            if (tx_phase_en_sync = '1' AND tx_phase_busy_int = '0') then
              tx_psincdec             <= tx_phase_incdec_sync;
              tx_psen                 <= '1';
              tx_phase_busy_int       <= '1';
              -- Adjust mmcm phase counter based on whether we are incrementing
              -- or decrementing
              if (tx_phase_incdec_sync = '1') then
                if (tx_mmcm_phase = 559) then
                  tx_mmcm_phase       <= 0;
                else
                  tx_mmcm_phase       <= tx_mmcm_phase + 1;
                end if;
              else
                if (tx_mmcm_phase = 0) then
                  tx_mmcm_phase       <= 559;
                else
                  tx_mmcm_phase       <= tx_mmcm_phase - 1;
                end if;
              end if;
            end if;
            if (tx_psdone = '1') then
              tx_phase_busy_int       <= '0';
            end if;
          when others =>
            tx_state                  <= SET_TX_PHASE;
        end case;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- RX Path
  -----------------------------------------------------------------------------
  -- Route BUFR DDR data clock to MMCM to generate a phase shifted
  -- global clock whose rising edge is ideally in the middle of
  -- the DDR data bit
  inst_rx_mmcm_ddr_to_sdr : mmcm_ddr_to_sdr
    port map (
      CLKIN_100MHz                  => ddr_data_clk_bufg,
      CLKOUT_100MHz                 => clk_rx,
      CLKOUT_200MHz                 => clk_rx_2x,
      PSCLK                         => clk_rx,
      PSEN                          => rx_psen,
      PSINCDEC                      => rx_psincdec,
      PSDONE                        => rx_psdone,
      RESET                         => reset,
      LOCKED                        => clk_rx_locked_int);

  rx_reset                          <= NOT(clk_rx_locked_int);

-- TX data fifo, Interleaved DDR 8 bit I & Q to interleaved SDR 16 bit I & Q
  inst_rx_2x_fifo : fifo_14to28
    port map (
      rst                       => rx_reset,
      wr_clk                    => clk_rx_2x,
      rd_clk                    => clk_rx,
      din                       => rx_2x_fifo_din,
      wr_en                     => rx_2x_fifo_full_n,
      rd_en                     => rx_2x_fifo_empty_n,
      dout                      => rx_2x_fifo_dout,
      full                      => rx_2x_fifo_full,
      empty                     => rx_2x_fifo_empty);

  rx_2x_fifo_full_n             <= NOT(rx_2x_fifo_full);
  rx_2x_fifo_empty_n            <= NOT(rx_2x_fifo_empty);
  rx_2x_fifo_din                <= rx_data_2x_a & rx_data_2x_b;
  rx_data_i                     <= rx_2x_fifo_dout(27 downto 21) & rx_2x_fifo_dout(13 downto 7);
  rx_data_q                     <= rx_2x_fifo_dout(20 downto 14) & rx_2x_fifo_dout(6 downto 0);

  -- DDR LVDS Data Input
  gen_rx_ddr_lvds : for i in 0 to 6 generate
    inst_IDDR : IDDR
      generic map (
        DDR_CLK_EDGE                => "SAME_EDGE_PIPELINED",
        SRTYPE                      => "ASYNC")
      port map (
        Q1                          => rx_data_2x_a(i),
        Q2                          => rx_data_2x_b(i),
        C                           => clk_rx_2x,
        CE                          => '1',
        D                           => rx_data_2x_ddr(i),
        R                           => rx_reset,
        S                           => '0');

    inst_IBUFDS : IBUFDS
      generic map (
        DIFF_TERM                   => TRUE,
        IOSTANDARD                  => "DEFAULT")
      port map (
        I                           => RX_DATA_P(i),
        IB                          => RX_DATA_N(i),
        O                           => rx_data_2x_ddr(i));
  end generate;

  rx_cic_rate                         <= rx_cic_decim_sync;
  rx_cic_rate_we                      <= rx_cic_decim_stb OR rx_enable_stb;

  i_cic_decimator : cic_decimator
    port map (
      clk                             => clk_rx,
      sclr                            => rx_enable_n,
      din                             => rx_cic_din_i,
      rate                            => rx_cic_rate,
      rate_we                         => rx_cic_rate_we,
      dout                            => rx_cic_dout_i,
      nd                              => rx_cic_nd,
      rdy                             => rx_cic_rdy_i,
      rfd                             => rx_cic_rfd_i);

  q_cic_decimator : cic_decimator
    port map (
      clk                             => clk_rx,
      sclr                            => rx_enable_n,
      din                             => rx_cic_din_q,
      rate                            => rx_cic_rate,
      rate_we                         => rx_cic_rate_we,
      dout                            => rx_cic_dout_q,
      nd                              => rx_cic_nd,
      rdy                             => open,
      rfd                             => open);

  -- The halfband FIR filters use 32 bit wide inputs. To ensure we use the
  -- maximum dynamic range, we apply gain to CIC filter's output based on the
  -- decimation rate.
  -- WARNING: Input a is 47 bits, input b is 32 bits, so the resulting output
  --          p internally is 72 bits wide. However, the output is the
  --          bit slice p(47 down 16).
  i_mult_rx_gain_adjust : mult_rx_gain_adjust
    port map (
      clk                             => clk_rx,
      sclr                            => rx_enable_n,
      a                               => rx_gain_din_i,
      b                               => rx_gain_sync,
      p                               => rx_gain_dout_i);

  q_mult_rx_gain_adjust : mult_rx_gain_adjust
    port map (
      clk                             => clk_rx,
      sclr                            => rx_enable_n,
      a                               => rx_gain_din_q,
      b                               => rx_gain_sync,
      p                               => rx_gain_dout_q);

  -- Truncation causes a -0.5 bias. This performs unbiased truncation of multiplier output to 32 bits.
  -- We only use 4 bits as rounding more bits yields diminishing returns.
  i_rx_gain_trunc_unbiased : trunc_unbiased
    generic map (
      WIDTH_IN                        => 36,
      TRUNCATE                        => 4)
    port map (
      i                               => rx_gain_dout_i,
      o                               => rx_gain_dout_trunc_i);

  q_rx_gain_trunc_unbiased : trunc_unbiased
    generic map (
      WIDTH_IN                        => 36,
      TRUNCATE                        => 4)
    port map (
      i                               => rx_gain_dout_q,
      o                               => rx_gain_dout_trunc_q);

  -- FIR Halfband Decimation
  -- Input is fixed1_31, output is fixed2_30 due to the very small filter gain
  i_fir_halfband_decimator : fir_halfband_decimator
    port map (
      clk                             => clk_rx,
      sclr                            => rx_enable_n,
      nd                              => rx_halfband_nd,
      rfd                             => rx_halfband_rfd_i,
      rdy                             => open,
      data_valid                      => rx_halfband_dout_valid_i,
      din                             => rx_halfband_din_i,
      dout                            => rx_halfband_dout_i);

  q_fir_halfband_decimator : fir_halfband_decimator
    port map (
      clk                             => clk_rx,
      sclr                            => rx_enable_n,
      nd                              => rx_halfband_nd,
      rfd                             => open,
      rdy                             => open,
      data_valid                      => open,
      din                             => rx_halfband_din_q,
      dout                            => rx_halfband_dout_q);

  -- Convert 32 bit fixed point to 32 bit floating point
  i_fix1_31_to_float32 : fix1_31_to_float32
    port map (
      clk                             => clk_rx,
      sclr                            => rx_enable_n,
      operation_nd                    => rx_fix2float_nd,
      operation_rfd                   => rx_fix2float_rfd_i,
      rdy                             => rx_fix2float_rdy_i,
      a                               => rx_fix2float_din_i,
      result                          => rx_fix2float_dout_i);

  q_fix1_31_to_float32 : fix1_31_to_float32
    port map (
      clk                             => clk_rx,
      sclr                            => rx_enable_n,
      operation_nd                    => rx_fix2float_nd,
      operation_rfd                   => open,
      rdy                             => open,
      a                               => rx_fix2float_din_q,
      result                          => rx_fix2float_dout_q);

  -- Implement flow control signals and bypass logic
  rx_cic_din_i                        <= rx_data_i;
  rx_cic_din_q                        <= rx_data_q;
  rx_cic_nd                           <= '1'                              when rx_cic_bypass_sync = '1' else rx_cic_rfd_i;
  rx_gain_din_i                       <= rx_data_i & (32 downto 0 => '0') when rx_cic_bypass_sync = '1' else rx_cic_dout_i;
  rx_gain_din_q                       <= rx_data_q & (32 downto 0 => '0') when rx_cic_bypass_sync = '1' else rx_cic_dout_q;
  rx_halfband_din_i                   <= rx_gain_dout_trunc_i;
  rx_halfband_din_q                   <= rx_gain_dout_trunc_q;
  rx_halfband_nd                      <= rx_cic_nd                        when rx_cic_bypass_sync = '1' else rx_cic_rdy_i;
  rx_fix2float_din_i                  <= rx_halfband_din_i                when rx_hb_bypass_sync = '1' else rx_halfband_dout_i;
  rx_fix2float_din_q                  <= rx_halfband_din_q                when rx_hb_bypass_sync = '1' else rx_halfband_dout_q;
  rx_fix2float_nd                     <= rx_halfband_nd                   when rx_hb_bypass_sync = '1' else rx_halfband_dout_valid_i;

  -- FIFO for clock crossing and buffering (Receive)
  -- Bypass fixed to float conversion and output raw data when decimation is set to 0
  rx_fifo_din                         <= rx_fix2float_din_i & rx_fix2float_din_q when rx_fix2float_bypass_sync = '1' else
                                         rx_fix2float_dout_i & rx_fix2float_dout_q;
  rx_fifo_wr_en                       <= rx_fifo_wr_en_int AND NOT(rx_fifo_full);
  rx_fifo_wr_en_int                   <= rx_fix2float_nd when rx_fix2float_bypass_sync = '1' else
                                         rx_fix2float_rdy_i;
  rx_fifo_rd_en_int                   <= rx_fifo_rd_en AND NOT(rx_fifo_empty_int);
  rx_fifo_data_i                      <= rx_fifo_dout(63 downto 32);
  rx_fifo_data_q                      <= rx_fifo_dout(31 downto 0);

  inst_rx_data_fifo_64x4096 : fifo_64x4096
    port map (
      wr_rst                          => rx_reset,
      wr_clk                          => clk_rx,
      rd_rst                          => rx_fifo_reset,
      rd_clk                          => clk_rx_fifo,
      din                             => rx_fifo_din,
      wr_en                           => rx_fifo_wr_en,
      rd_en                           => rx_fifo_rd_en_int,
      dout                            => rx_fifo_dout,
      full                            => rx_fifo_full,
      almost_full                     => rx_fifo_almost_full,
      empty                           => rx_fifo_empty_int,
      almost_empty                    => rx_fifo_almost_empty,
      overflow                        => rx_fifo_overflow,
      underflow                       => rx_fifo_underflow);

  -- Latch overflow to indicate that the FIFO needs to be reset
  proc_rx_overflow_latch : process(clk_rx,rx_enable_sync)
  begin
    if (rx_enable_sync = '0') then
      rx_fifo_overflow_latch_int      <= '0';
    else
      if rising_edge(clk_rx) then
        if (rx_fifo_wr_en = '1' AND rx_fifo_full = '1') then
          rx_fifo_overflow_latch_int  <= '1';
        end if;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- TX Path
  -----------------------------------------------------------------------------
  -- This MMCM is used to phase shift the TX data clock independently of the
  -- RX data clock.
  inst_tx_mmcm_ddr_to_sdr : mmcm_ddr_to_sdr
    port map (
      CLKIN_100MHz                  => ddr_data_clk_bufg,
      CLKOUT_100MHz                 => clk_tx,
      CLKOUT_200MHz                 => clk_tx_2x,
      PSCLK                         => clk_tx,
      PSEN                          => tx_psen,
      PSINCDEC                      => tx_psincdec,
      PSDONE                        => tx_psdone,
      RESET                         => reset,
      LOCKED                        => clk_tx_locked_int);

  tx_reset                          <= NOT(clk_tx_locked_int);

  -- LVDS DDR Data Interface, 2x Clock Domain (200 MHz)
  -- Transmit 16-bit TX I/Q data at 200 MHz DDR.

  -- Buffer TX data so we can correct data alignment
  proc_tx_data_1x : process(clk_tx, tx_reset)
  begin
    if (tx_reset = '1') then
      tx_data_a                     <= (others=>'0');
      tx_data_b                     <= (others=>'0');
    else
      if rising_edge(clk_tx) then
        tx_data_a                   <= tx_trunc_dout_i;
        tx_data_b                   <= tx_trunc_dout_q;
      end if;
    end if;
  end process;

  -- TX data fifo, Interleaved SDR 16 bit I & Q to interleaved DDR 8 bit I & Q
  inst_tx_2x_fifo : fifo_32to16
    port map (
      rst                       => tx_reset,
      wr_clk                    => clk_tx,
      rd_clk                    => clk_tx_2x,
      din                       => tx_2x_fifo_din,
      wr_en                     => tx_2x_fifo_full_n,
      rd_en                     => tx_2x_fifo_empty_n,
      dout                      => tx_2x_fifo_dout,
      full                      => tx_2x_fifo_full,
      empty                     => tx_2x_fifo_empty);

  tx_2x_fifo_full_n             <= NOT(tx_2x_fifo_full);
  tx_2x_fifo_empty_n            <= NOT(tx_2x_fifo_empty);
  tx_data_2x_a                  <= tx_2x_fifo_dout(15 downto 8);
  tx_data_2x_b                  <= tx_2x_fifo_dout( 7 downto 0);
  tx_2x_fifo_din                <= tx_data_a(15 downto 8) & tx_data_b(15 downto 8) &
                                   tx_data_a( 7 downto 0) & tx_data_b( 7 downto 0);

  -- DDR LVDS Data Output
  gen_tx_ddr_lvds : for i in 0 to 7 generate
    inst_ODDR : ODDR
      generic map (
        DDR_CLK_EDGE                => "SAME_EDGE",
        SRTYPE                      => "ASYNC")
      port map (
        Q                           => tx_data_2x_ddr(i),
        C                           => clk_tx_2x,
        CE                          => '1',
        D1                          => tx_data_2x_a(i),
        D2                          => tx_data_2x_b(i),
        R                           => tx_reset,
        S                           => '0');

    inst_OBUFDS : OBUFDS
      generic map (
        IOSTANDARD                  => "DEFAULT")
      port map (
        I                           => tx_data_2x_ddr(i),
        O                           => TX_DATA_P(i),
        OB                          => TX_DATA_N(i));
  end generate;

  -- TX Interpolation Chain
  -- Convert 32 bit floating point to 20 bit fixed point (fix1_19)
  i_float32_to_fix1_19 : float32_to_fix1_19
    port map (
      clk                             => clk_tx,
      sclr                            => tx_enable_n,
      operation_nd                    => tx_float2fix_nd,
      operation_rfd                   => tx_float2fix_rfd_i,
      rdy                             => tx_float2fix_rdy_i,
      a                               => tx_data_i,
      result                          => tx_float2fix_dout_i);

  q_float32_to_fix1_19 : float32_to_fix1_19
    port map (
      clk                             => clk_tx,
      sclr                            => tx_enable_n,
      operation_nd                    => tx_float2fix_nd,
      operation_rfd                   => open,
      rdy                             => open,
      a                               => tx_data_q,
      result                          => tx_float2fix_dout_q);

  -- FIR Halfband Interpolator
  -- Input is fixed1_31, output is fixed2_30 due to the very small filter gain
  i_fir_halfband_interpolator : fir_halfband_interpolator
    port map (
      clk                             => clk_tx,
      sclr                            => tx_enable_n,
      nd                              => tx_halfband_nd,
      ce                              => tx_halfband_ce,
      rfd                             => tx_halfband_rfd_i,
      rdy                             => open,
      data_valid                      => tx_halfband_dout_valid_i,
      din                             => tx_halfband_din_i,
      dout                            => tx_halfband_dout_i);

  q_fir_halfband_interpolator : fir_halfband_interpolator
    port map (
      clk                             => clk_tx,
      sclr                            => tx_enable_n,
      nd                              => tx_halfband_nd,
      ce                              => tx_halfband_ce,
      rfd                             => open,
      rdy                             => open,
      data_valid                      => open,
      din                             => tx_halfband_din_q,
      dout                            => tx_halfband_dout_q);

  -- CIC Filter with programmabled decimation rate of 4 - 2047.
  tx_cic_rate                         <= tx_cic_interp;
  tx_cic_rate_we                      <= tx_cic_interp_stb OR tx_enable_stb;

  i_cic_interpolator : cic_interpolator
    port map (
      clk                             => clk_tx,
      sclr                            => tx_enable_n,
      din                             => tx_cic_din_i,
      rate                            => tx_cic_rate,
      rate_we                         => tx_cic_rate_we,
      dout                            => tx_cic_dout_i,
      nd                              => tx_cic_nd,
      rdy                             => tx_cic_rdy_i,
      rfd                             => tx_cic_rfd_i);

  q_cic_interpolator : cic_interpolator
    port map (
      clk                             => clk_tx,
      sclr                            => tx_enable_n,
      din                             => tx_cic_din_q,
      rate                            => tx_cic_rate,
      rate_we                         => tx_cic_rate_we,
      dout                            => tx_cic_dout_q,
      nd                              => tx_cic_nd,
      rdy                             => open,
      rfd                             => open);

  -- To ensure we use the maximum dynamic range, we apply gain to CIC filter's
  -- output based on the interpolation rate.
  -- WARNING: Input a is 42 bits, input b is 32 bits, so the resulting output
  --          p internally is 74 bits wide. However, the output is the
  --          bit slice p(41 downto 22).
  i_mult_tx_gain_adjust : mult_tx_gain_adjust
    port map (
      clk                             => clk_tx,
      sclr                            => tx_enable_n,
      a                               => tx_gain_din_i,
      b                               => tx_gain_sync,
      p                               => tx_gain_dout_i);

  q_mult_tx_gain_adjust : mult_tx_gain_adjust
    port map (
      clk                             => clk_tx,
      sclr                            => tx_enable_n,
      a                               => tx_gain_din_q,
      b                               => tx_gain_sync,
      p                               => tx_gain_dout_q);

  i_tx_trunc_unbiased : trunc_unbiased
    generic map (
      WIDTH_IN                        => 20,
      TRUNCATE                        => 4)
    port map (
      i                               => tx_trunc_din_i,
      o                               => tx_trunc_dout_i);

  q_tx_trunc_unbiased : trunc_unbiased
    generic map (
      WIDTH_IN                        => 20,
      TRUNCATE                        => 4)
    port map (
      i                               => tx_trunc_din_q,
      o                               => tx_trunc_dout_q);

  -- TX data flow control and bypassing
  tx_float2fix_nd                     <= '1'                    when tx_hb_bypass_sync = '1' AND tx_cic_bypass_sync = '1' else
                                         tx_cic_rfd_i           when tx_hb_bypass_sync = '1' AND tx_cic_bypass_sync = '0' else
                                         tx_halfband_rfd_i;
  tx_halfband_din_i                   <= tx_data_i(19 downto 0) when tx_float2fix_bypass_sync = '1' else tx_float2fix_dout_i;
  tx_halfband_din_q                   <= tx_data_q(19 downto 0) when tx_float2fix_bypass_sync = '1' else tx_float2fix_dout_q;
  tx_halfband_ce                      <= '1'                    when tx_cic_bypass_sync = '1' else tx_cic_rfd_i;
  tx_halfband_nd                      <= tx_halfband_rfd_i AND tx_halfband_nd_int;
  tx_halfband_nd_int                  <= tx_float2fix_nd        when tx_float2fix_bypass_sync = '1' else tx_float2fix_rdy_i;
  tx_cic_din_i                        <= tx_halfband_din_i      when tx_hb_bypass_sync = '1' else tx_halfband_dout_i;
  tx_cic_din_q                        <= tx_halfband_din_q      when tx_hb_bypass_sync = '1' else tx_halfband_dout_q;
  tx_cic_nd                           <= tx_cic_rfd_i AND tx_cic_nd_int;
  tx_cic_nd_int                       <= tx_halfband_nd_int     when tx_hb_bypass_sync = '1' else tx_halfband_dout_valid_i;
  tx_gain_din_i                       <= tx_cic_din_i & (21 downto 0 => '0') when tx_cic_bypass_sync = '1' else tx_cic_dout_i;
  tx_gain_din_q                       <= tx_cic_din_q & (21 downto 0 => '0') when tx_cic_bypass_sync = '1' else tx_cic_dout_q;
  tx_trunc_din_i                      <= tx_gain_dout_i;
  tx_trunc_din_q                      <= tx_gain_dout_q;

  -- FIFOs for clock crossing and buffering (Transmit)
  tx_fifo_rd_en                     <= tx_fifo_rd_en_int AND NOT(tx_fifo_empty);
  tx_fifo_rd_en_int                 <= tx_float2fix_nd AND tx_enable_sync;
  tx_fifo_wr_en_int                 <= tx_fifo_wr_en AND NOT(tx_fifo_full_int);
  tx_fifo_din                       <= tx_fifo_data_i & tx_fifo_data_q;
  tx_data_i                         <= tx_fifo_dout(63 downto 32);
  tx_data_q                         <= tx_fifo_dout(31 downto 0);

  inst_tx_data_fifo_64x4096 : fifo_64x4096
    port map (
      wr_rst                        => tx_fifo_reset,
      wr_clk                        => clk_tx_fifo,
      rd_rst                        => tx_reset,
      rd_clk                        => clk_tx,
      din                           => tx_fifo_din,
      wr_en                         => tx_fifo_wr_en_int,
      rd_en                         => tx_fifo_rd_en,
      dout                          => tx_fifo_dout,
      full                          => tx_fifo_full_int,
      almost_full                   => tx_fifo_almost_full,
      empty                         => tx_fifo_empty,
      almost_empty                  => tx_fifo_almost_empty,
      overflow                      => tx_fifo_overflow,
      underflow                     => tx_fifo_underflow);

  -- Latch underflow to indicate that the FIFO needs to be reset
  proc_tx_underflow_latch : process(clk_tx,tx_enable_sync)
  begin
    if (tx_enable_sync = '0') then
      tx_fifo_underflow_latch_int         <= '0';
    else
      if rising_edge(clk_tx) then
        if (tx_fifo_rd_en_int = '1' AND tx_fifo_empty = '1') then
          tx_fifo_underflow_latch_int     <= '1';
        end if;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- UART to set USRP receive and transmit modes
  -----------------------------------------------------------------------------
  inst_uart : uart
    generic map (
      CLOCK_FREQ                    => DDR_CLOCK_FREQ,
      BAUD                          => BAUD,
      DATA_BITS                     => 8,
      PARITY                        => "EVEN",
      NO_STROBE_ON_ERR              => "TRUE")
    port map (
      clk                           => clk_rx,
      reset                         => rx_reset,
      tx_busy                       => tx_busy,
      tx_data_stb                   => usrp_mode_ctrl_stb,
      tx_data                       => usrp_mode_ctrl_sync,
      rx_busy                       => open,
      rx_data_stb                   => open,
      rx_data                       => open,
      rx_error                      => open,
      tx                            => UART_TX,
      rx                            => '1');

  uart_busy                         <= tx_busy;

  -----------------------------------------------------------------------------
  -- Acknowledgement Logic
  -----------------------------------------------------------------------------
  proc_acknowledgements : process(clk_rx,rx_reset)
  begin
    if (rx_reset = '1') then
      usrp_mode_ctrl_ack_int          <= '0';
      rx_cic_decim_ack_int            <= '0';
      tx_cic_interp_ack_int           <= '0';
    else
      if rising_edge(clk_rx) then
        -- Acknowledgement for UART control interface
        if (usrp_mode_ctrl_en_sync = '1' AND usrp_mode_ctrl_ack_int = '0') then
          usrp_mode_ctrl_ack_int      <= '1';
        end if;
        if (usrp_mode_ctrl_en_sync = '0') then
          usrp_mode_ctrl_ack_int  <= '0';
        end if;
        -- Acknowledgement for RX CIC
        if (rx_cic_decim_en_sync = '1' AND rx_cic_decim_ack_int = '0') then
          rx_cic_decim_ack_int        <= '1';
        end if;
        if (rx_cic_decim_en_sync = '0') then
          rx_cic_decim_ack_int        <= '0';
        end if;
        -- Acknowledgement for TX CIC
        if (tx_cic_interp_en_sync = '1' AND tx_cic_interp_ack_int = '0') then
          tx_cic_interp_ack_int       <= '1';
        end if;
        if (tx_cic_interp_en_sync = '0') then
          tx_cic_interp_ack_int       <= '0';
        end if;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Synchronizers
  -----------------------------------------------------------------------------
  -- RX Synchronizers
  inst_rx_synchronizer : synchronizer_slv
    generic map (
      STROBE_EDGE                     => "N", -- None, Output is input
      -- Note: RESET_OUTPUT sets the reset state of the sync output. There is
      --       some special handling in this module with regards to the value.
      --       It can be a single value, such as "0", which will set all the
      --       reset values to "0". Or you can enter the individual reset values
      --       of each bit in the sync output signal.
      --       See the source code for more details.
      RESET_OUTPUT                    => "0")
    port map (
      clk                             => clk_rx,
      reset                           => rx_reset,
      async                           => rx_async,
      sync                            => rx_sync);

  inst_rx_synchronizer_rising_edge_detect : synchronizer_slv
    generic map (
      STROBE_EDGE                     => "R", -- Risinge edge, strobe output on the rising edge
      RESET_OUTPUT                    => "0")
    port map (
      clk                             => clk_rx,
      reset                           => rx_reset,
      async                           => rx_async_rising,
      sync                            => rx_sync_rising);

  rx_async_rising(0)                  <= usrp_mode_ctrl_en;
  rx_async_rising(1)                  <= rx_phase_en;
  rx_async_rising(2)                  <= rx_cic_decim_en;
  rx_async_rising(3)                  <= rx_restart_cal;
  rx_async_rising(4)                  <= rx_enable;
  usrp_mode_ctrl_stb                  <= rx_sync_rising(0);
  rx_phase_en_sync                    <= rx_sync_rising(1);
  rx_cic_decim_stb                    <= rx_sync_rising(2);
  rx_restart_cal_sync                 <= rx_sync_rising(3);
  rx_enable_stb                       <= rx_sync_rising(4);

  rx_async(7 downto 0)                <= usrp_mode_ctrl;
  rx_async(8)                         <= rx_phase_incdec;
  rx_async(19 downto 9)               <= rx_cic_decim;
  rx_async(20)                        <= rx_fix2float_bypass;
  rx_async(21)                        <= rx_cic_bypass;
  rx_async(22)                        <= rx_hb_bypass;
  rx_async(54 downto 23)              <= rx_gain;
  rx_async(64 downto 55)              <= rx_phase_init;
  rx_async(65)                        <= rx_enable;
  rx_async(66)                        <= rx_cic_decim_en;
  rx_async(67)                        <= usrp_mode_ctrl_en;
  usrp_mode_ctrl_sync                 <= rx_sync(7 downto 0);
  rx_phase_incdec_sync                <= rx_sync(8);
  rx_cic_decim_sync                   <= rx_sync(19 downto 9);
  rx_fix2float_bypass_sync            <= rx_sync(20);
  rx_cic_bypass_sync                  <= rx_sync(21);
  rx_hb_bypass_sync                   <= rx_sync(22);
  rx_gain_sync                        <= rx_sync(54 downto 23);
  rx_phase_init_sync                  <= rx_sync(64 downto 55);
  rx_enable_sync                      <= rx_sync(65);
  rx_cic_decim_en_sync                <= rx_sync(66);
  usrp_mode_ctrl_en_sync              <= rx_sync(67);

  rx_enable_n                         <= NOT(rx_enable_sync);

  -- TX Synchronizers
  inst_tx_synchronizer : synchronizer_slv
    generic map (
      STROBE_EDGE                     => "N",
      RESET_OUTPUT                    => "0")
    port map (
      clk                             => clk_tx,
      reset                           => tx_reset,
      async                           => tx_async,
      sync                            => tx_sync);

  inst_tx_synchronizer_rising_edge_detect : synchronizer_slv
    generic map (
      STROBE_EDGE                     => "R",
      RESET_OUTPUT                    => "0")
    port map (
      clk                             => clk_tx,
      reset                           => tx_reset,
      async                           => tx_async_rising,
      sync                            => tx_sync_rising);

  tx_async_rising(0)                  <= tx_phase_en;
  tx_async_rising(1)                  <= tx_cic_interp_en;
  tx_async_rising(2)                  <= tx_restart_cal;
  tx_async_rising(3)                  <= tx_enable;
  tx_phase_en_sync                    <= tx_sync_rising(0);
  tx_cic_interp_stb                   <= tx_sync_rising(1);
  tx_restart_cal_sync                 <= tx_sync_rising(2);
  tx_enable_stb                       <= tx_sync_rising(3);

  tx_async(0)                         <= tx_phase_incdec;
  tx_async(11 downto 1)               <= tx_cic_interp;
  tx_async(12)                        <= tx_float2fix_bypass;
  tx_async(13)                        <= tx_cic_bypass;
  tx_async(14)                        <= tx_hb_bypass;
  tx_async(46 downto 15)              <= tx_gain;
  tx_async(56 downto 47)              <= tx_phase_init;
  tx_async(57)                        <= tx_enable;
  tx_async(58)                        <= tx_cic_interp_en;
  tx_phase_incdec_sync                <= tx_sync(0);
  tx_cic_interp_sync                  <= tx_sync(11 downto 1);
  tx_float2fix_bypass_sync            <= tx_sync(12);
  tx_cic_bypass_sync                  <= tx_sync(13);
  tx_hb_bypass_sync                   <= tx_sync(14);
  tx_gain_sync                        <= tx_sync(46 downto 15);
  tx_phase_init_sync                  <= tx_sync(56 downto 47);
  tx_enable_sync                      <= tx_sync(57);
  tx_cic_interp_en_sync               <= tx_sync(58);

  tx_enable_n                         <= NOT(tx_enable_sync);

  -- Sychronizer for rx overflow latch
  inst_rx_overflow_latch_synchronizer : synchronizer
    port map (
      clk                             => clk_rx_fifo,
      reset                           => rx_fifo_reset,
      async                           => rx_fifo_overflow_latch_int,
      sync                            => rx_fifo_overflow_latch);

  -- Sychronizer for tx underflow latch
  inst_tx_underflow_latch_synchronizer : synchronizer
    port map (
      clk                             => clk_tx_fifo,
      reset                           => tx_fifo_reset,
      async                           => tx_fifo_underflow_latch_int,
      sync                            => tx_fifo_underflow_latch);

  -----------------------------------------------------------------------------
  -- Internal signals to output ports
  -----------------------------------------------------------------------------
  usrp_mode_ctrl_ack                <= usrp_mode_ctrl_ack_int;
  rx_cic_decim_ack                  <= rx_cic_decim_ack_int;
  tx_cic_interp_ack                 <= tx_cic_interp_ack_int;
  rx_phase_busy                     <= rx_phase_busy_int;
  tx_phase_busy                     <= tx_phase_busy_int;
  clk_rx_locked                     <= clk_rx_locked_int;
  clk_tx_locked                     <= clk_tx_locked_int;
  clk_rx_phase                      <= std_logic_vector(to_unsigned(rx_mmcm_phase,10));
  clk_tx_phase                      <= std_logic_vector(to_unsigned(tx_mmcm_phase,10));
  tx_fifo_full                      <= tx_fifo_full_int;
  rx_fifo_empty                     <= rx_fifo_empty_int;

end RTL;

