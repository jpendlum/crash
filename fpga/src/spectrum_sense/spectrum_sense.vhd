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
--  File: spectrum_sense.vhd
--  Author: Jonathon Pendlum (jon.pendlum@gmail.com)
--  Description: Specturm sensing by implementing a FFT, magnitude calculation,
--               and threshold detection. The entire pipeline is single
--               precision floating point and based on Xilinx IP.
--               Maximum FFT size of 4096.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity spectrum_sense is
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
    axis_slave_irq              : out   std_logic;      -- Not used
    -- AXIS Stream Master Interface (Frequency Domain / FFT Output)
    axis_master_tvalid          : out   std_logic;
    axis_master_tready          : in    std_logic;
    axis_master_tdata           : out   std_logic_vector(63 downto 0);
    axis_master_tdest           : out   std_logic_vector(2 downto 0);
    axis_master_tlast           : out   std_logic;
    axis_master_irq             : out   std_logic;      -- Strobes when threshold exceeded
    -- Sideband signals
    threshold_not_exceeded      : out   std_logic;
    threshold_not_exceeded_stb  : out   std_logic;
    threshold_exceeded          : out   std_logic;
    threshold_exceeded_stb      : out   std_logic);
end entity;

architecture RTL of spectrum_sense is

  -------------------------------------------------------------------------------
  -- Function / Procedure Declaration
  -------------------------------------------------------------------------------
  function float2real(fpin: std_logic_vector(31 downto 0)) return real is
    constant xdiv       : real := 2.0**23;
    variable exp        : integer;
    variable mant       : integer;
    variable multexp    : real;
    variable mantdec    : real;
    variable res        : real;
  begin
    exp                 := to_integer(unsigned(fpin(30 downto 23))) - 127;
    multexp             := 2.0**exp;
    mant                := to_integer(unsigned('1' & fpin(22 downto 0)));
    mantdec             := real(mant)/xdiv;
    res                 := mantdec*multexp;
    -- Check sign
    if (fpin(31) = '1') then
      res               := -res;
    end if;
    return(res);
  end function;

  -------------------------------------------------------------------------------
  -- Component Declaration
  -------------------------------------------------------------------------------
  component fft_axis
    port (
      aclk                          : in    std_logic;
      aresetn                       : in    std_logic;
      s_axis_config_tdata           : in    std_logic_vector(23 downto 0);
      s_axis_config_tvalid          : in    std_logic;
      s_axis_config_tready          : out   std_logic;
      s_axis_data_tdata             : in    std_logic_vector(63 downto 0);
      s_axis_data_tvalid            : in    std_logic;
      s_axis_data_tready            : out   std_logic;
      s_axis_data_tlast             : in    std_logic;
      m_axis_data_tdata             : out   std_logic_vector(63 downto 0);
      m_axis_data_tuser             : out   std_logic_vector(15 downto 0);
      m_axis_data_tvalid            : out   std_logic;
      m_axis_data_tready            : in    std_logic;
      m_axis_data_tlast             : out   std_logic;
      event_frame_started           : out   std_logic;
      event_tlast_unexpected        : out   std_logic;
      event_tlast_missing           : out   std_logic;
      event_status_channel_halt     : out   std_logic;
      event_data_in_channel_halt    : out   std_logic;
      event_data_out_channel_halt   : out   std_logic);
    end component;

  component add_floating_point
    port (
      aclk                          : in    std_logic;
      aresetn                       : in    std_logic;
      s_axis_a_tvalid               : in    std_logic;
      s_axis_a_tready               : out   std_logic;
      s_axis_a_tdata                : in    std_logic_vector(31 downto 0);
      s_axis_a_tlast                : in    std_logic;
      s_axis_a_tuser                : in    std_logic_vector(15 downto 0);
      s_axis_b_tvalid               : in    std_logic;
      s_axis_b_tready               : out   std_logic;
      s_axis_b_tdata                : in    std_logic_vector(31 downto 0);
      m_axis_result_tvalid          : out   std_logic;
      m_axis_result_tready          : in    std_logic;
      m_axis_result_tdata           : out   std_logic_vector(31 downto 0);
      m_axis_result_tlast           : out   std_logic;
      m_axis_result_tuser           : out   std_logic_vector(15 downto 0));
  end component;

  component multiply_floating_point
    port (
      aclk                          : in    std_logic;
      aresetn                       : in    std_logic;
      s_axis_a_tvalid               : in    std_logic;
      s_axis_a_tready               : out   std_logic;
      s_axis_a_tdata                : in    std_logic_vector(31 downto 0);
      s_axis_a_tlast                : in    std_logic;
      s_axis_a_tuser                : in    std_logic_vector(15 downto 0);
      s_axis_b_tvalid               : in    std_logic;
      s_axis_b_tready               : out   std_logic;
      s_axis_b_tdata                : in    std_logic_vector(31 downto 0);
      m_axis_result_tvalid          : out   std_logic;
      m_axis_result_tready          : in    std_logic;
      m_axis_result_tdata           : out   std_logic_vector(31 downto 0);
      m_axis_result_tlast           : out   std_logic;
      m_axis_result_tuser           : out   std_logic_vector(15 downto 0));
  end component;

  component sqrt_floating_point
    port (
      aclk                          : in    std_logic;
      aresetn                       : in    std_logic;
      s_axis_a_tvalid               : in    std_logic;
      s_axis_a_tready               : out   std_logic;
      s_axis_a_tdata                : in    std_logic_vector(31 downto 0);
      s_axis_a_tlast                : in    std_logic;
      s_axis_a_tuser                : in    std_logic_vector(15 downto 0);
      m_axis_result_tvalid          : out   std_logic;
      m_axis_result_tready          : in    std_logic;
      m_axis_result_tdata           : out   std_logic_vector(31 downto 0);
      m_axis_result_tlast           : out   std_logic;
      m_axis_result_tuser           : out   std_logic_vector(15 downto 0));
  end component;

  component gteq_floating_point
    port (
      aclk                          : in    std_logic;
      aresetn                       : in    std_logic;
      s_axis_a_tvalid               : in    std_logic;
      s_axis_a_tready               : out   std_logic;
      s_axis_a_tdata                : in    std_logic_vector(31 downto 0);
      s_axis_a_tlast                : in    std_logic;
      s_axis_a_tuser                : in    std_logic_vector(47 downto 0);
      s_axis_b_tvalid               : in    std_logic;
      s_axis_b_tready               : out   std_logic;
      s_axis_b_tdata                : in    std_logic_vector(31 downto 0);
      m_axis_result_tvalid          : out   std_logic;
      m_axis_result_tready          : in    std_logic;
      m_axis_result_tdata           : out   std_logic_vector(7 downto 0);
      m_axis_result_tlast           : out   std_logic;
      m_axis_result_tuser           : out   std_logic_vector(47 downto 0));
  end component;

  component edge_detect is
    generic (
      EDGE                          : string  := "R");      -- "R"ising, "F"alling, "B"oth, or "N"one.
    port (
      clk                           : in    std_logic;      -- Clock
      reset                         : in    std_logic;      -- Active high reset
      input_detect                  : in    std_logic;      -- Input data
      edge_detect_stb               : out   std_logic);     -- Edge detected strobe
  end component;

  -----------------------------------------------------------------------------
  -- Signals Declaration
  -----------------------------------------------------------------------------
  type slv_256x32 is array(0 to 255) of std_logic_vector(31 downto 0);

  signal ctrl_reg                     : slv_256x32 := (others=>(others=>'0'));
  signal status_reg                   : slv_256x32 := (others=>(others=>'0'));
  signal ctrl_stb_dly                 : std_logic;
  signal axis_master_tdest_hold       : std_logic_vector(2 downto 0);
  signal axis_master_tdest_safe       : std_logic_vector(2 downto 0);

  signal rst                          : std_logic;

  signal enable_fft                   : std_logic;
  signal config_tvalid                : std_logic;
  signal config_tdata                 : std_logic_vector(23 downto 0);
  signal output_mode                  : std_logic_vector(1 downto 0);
  signal output_mode_safe             : std_logic_vector(1 downto 0);
  signal enable_threshold_irq         : std_logic;
  signal clear_threshold_latched      : std_logic;
  signal enable_thresh_sideband       : std_logic;
  signal enable_not_thresh_sideband   : std_logic;

  signal index_fft                    : std_logic_vector(15 downto 0);
  signal axis_slave_tvalid_fft        : std_logic;
  signal axis_slave_tready_fft        : std_logic;
  signal axis_master_tdata_fft        : std_logic_vector(63 downto 0);
  signal axis_master_tvalid_fft       : std_logic;
  signal axis_master_tready_fft       : std_logic;
  signal axis_master_tlast_fft        : std_logic;
  signal axis_master_tlast_fft_dly    : std_logic_vector(3 downto 0);
  signal axis_config_tdata            : std_logic_vector(23 downto 0);
  signal axis_config_tvalid           : std_logic;
  signal axis_config_tready           : std_logic;
  signal event_frame_started          : std_logic;
  signal event_tlast_unexpected       : std_logic;
  signal event_tlast_missing          : std_logic;
  signal event_status_channel_halt    : std_logic;
  signal event_data_in_channel_halt   : std_logic;
  signal event_data_out_channel_halt  : std_logic;

  signal index_real_sqr               : std_logic_vector(15 downto 0);
  signal axis_real_tready             : std_logic;
  signal axis_real_sqr_tvalid         : std_logic;
  signal axis_real_sqr_tready         : std_logic;
  signal axis_real_sqr_tdata          : std_logic_vector(31 downto 0);
  signal axis_real_sqr_tlast          : std_logic;
  signal axis_imag_sqr_tvalid         : std_logic;
  signal axis_imag_sqr_tready         : std_logic;
  signal axis_imag_sqr_tdata          : std_logic_vector(31 downto 0);
  signal index_mag_sqr                : std_logic_vector(15 downto 0);
  signal axis_mag_sqr_tlast           : std_logic;
  signal axis_mag_sqr_tvalid          : std_logic;
  signal axis_mag_sqr_tready          : std_logic;
  signal axis_mag_sqr_tdata           : std_logic_vector(31 downto 0);
  signal index_mag                    : std_logic_vector(15 downto 0);
  signal axis_mag_tlast               : std_logic;
  signal axis_mag_tvalid              : std_logic;
  signal axis_mag_tready              : std_logic;
  signal axis_mag_tdata               : std_logic_vector(31 downto 0);
  signal axis_mag_tuser               : std_logic_vector(47 downto 0);
  signal index_threshold              : std_logic_vector(15 downto 0);
  signal threshold_mag                : std_logic_vector(31 downto 0);
  signal axis_threshold_tlast         : std_logic;
  signal axis_threshold_tvalid        : std_logic;
  signal axis_threshold_tready        : std_logic;
  signal axis_threshold_tdata         : std_logic_vector(7 downto 0);
  signal axis_threshold_tuser         : std_logic_vector(47 downto 0);

  signal threshold_latched            : std_logic;
  signal threshold                    : std_logic_vector(31 downto 0);
  signal threshold_exceeded_int       : std_logic;
  signal threshold_exceeded_reg       : std_logic;
  signal threshold_exceeded_index     : std_logic_vector(15 downto 0);
  signal threshold_exceeded_mag       : std_logic_vector(31 downto 0);
  signal update_threshold_stb         : std_logic;
  signal fft_load                     : std_logic;

  -- Debug signals
  -- signal fft_in_real                  : real;
  -- signal fft_in_imag                  : real;
  -- signal fft_out_real                 : real;
  -- signal fft_out_imag                 : real;

begin

  rst                                 <= NOT(rst_n);
  axis_slave_irq                      <= '0';

  -- Output AXI-S Master Signals
  axis_master_tvalid                  <= axis_master_tvalid_fft when output_mode_safe = "00" else
                                         axis_threshold_tvalid  when output_mode_safe = "01" else
                                         '0';
  axis_master_tlast                   <= axis_master_tlast_fft when output_mode_safe = "00" else
                                         axis_threshold_tlast  when output_mode_safe = "01" else
                                         '0';
  axis_master_tdata                   <= axis_master_tdata_fft when output_mode_safe = "00" else
                                         axis_threshold_tdata(0) & (62 downto 48 => '0') & axis_threshold_tuser;
  axis_master_tdest                   <= axis_master_tdest_safe;

  inst_fft_axis : fft_axis
    port map (
      aclk                            => clk,
      aresetn                         => rst_n,
      s_axis_config_tdata             => axis_config_tdata,
      s_axis_config_tvalid            => axis_config_tvalid,
      s_axis_config_tready            => axis_config_tready,
      s_axis_data_tdata               => axis_slave_tdata,
      s_axis_data_tvalid              => axis_slave_tvalid_fft,
      s_axis_data_tready              => axis_slave_tready_fft,
      s_axis_data_tlast               => axis_slave_tlast,
      m_axis_data_tdata               => axis_master_tdata_fft,
      m_axis_data_tuser               => index_fft,
      m_axis_data_tvalid              => axis_master_tvalid_fft,
      m_axis_data_tready              => axis_master_tready_fft,
      m_axis_data_tlast               => axis_master_tlast_fft,
      event_frame_started             => event_frame_started,
      event_tlast_unexpected          => event_tlast_unexpected,
      event_tlast_missing             => event_tlast_missing,
      event_status_channel_halt       => event_status_channel_halt,
      event_data_in_channel_halt      => event_data_in_channel_halt,
      event_data_out_channel_halt     => event_data_out_channel_halt);

  -- It is possible we may want to only detect a signal without saving the FFT output.
  -- In the case that we have no destination for the FFT output, this logic overrides the
  -- FFT output AXI-Stream handshaking signals tvalid and tready to make sure the FFT core
  -- does not stall.
  axis_slave_tvalid_fft               <= axis_slave_tvalid when enable_fft = '1' AND fft_load = '1' else '0';
  axis_slave_tready                   <= axis_slave_tready_fft AND fft_load;
  axis_master_tready_fft              <= axis_master_tready when output_mode_safe = "00" else
                                         axis_real_tready   when output_mode_safe = "01" else
                                         '1';

  -- Counteract Xilinx's annoying behavior to partially preload the FFT. This is not necesary
  -- unless the sampling rate is high enough that FFT takes longer to execute than it takes
  -- to buffer the samples.
  proc_fft_load : process(clk,rst_n)
  begin
    if (rst_n = '0') then
      fft_load                        <= '1';
    else
      if rising_edge(clk) then
        if (enable_fft = '1') then
          if (fft_load = '1' AND axis_slave_tlast = '1' AND axis_slave_tvalid = '1') then
            fft_load                  <= '0';
          end if;
          if (fft_load = '0' AND axis_master_tlast_fft = '1' AND axis_master_tvalid_fft = '1') then
            fft_load                  <= '1';
          end if;
          -- Reset on error
          if (event_tlast_missing = '1' OR event_tlast_unexpected = '1') then
            fft_load                  <= '1';
          end if;
        else
          fft_load                    <= '1';
        end if;
      end if;
    end if;
  end process;

  real_squared_multiply_floating_point : multiply_floating_point
    port map (
      aclk                            => clk,
      aresetn                         => rst_n,
      s_axis_a_tvalid                 => axis_master_tvalid_fft,
      s_axis_a_tready                 => axis_real_tready,
      s_axis_a_tdata                  => axis_master_tdata_fft(31 downto 0),
      s_axis_a_tlast                  => axis_master_tlast_fft,
      s_axis_a_tuser                  => index_fft,
      s_axis_b_tvalid                 => axis_master_tvalid_fft,
      s_axis_b_tready                 => open,
      s_axis_b_tdata                  => axis_master_tdata_fft(31 downto 0),
      m_axis_result_tvalid            => axis_real_sqr_tvalid,
      m_axis_result_tready            => axis_real_sqr_tready,
      m_axis_result_tdata             => axis_real_sqr_tdata,
      m_axis_result_tlast             => axis_real_sqr_tlast,
      m_axis_result_tuser             => index_real_sqr);

  imag_squared_multiply_floating_point : multiply_floating_point
    port map (
      aclk                            => clk,
      aresetn                         => rst_n,
      s_axis_a_tvalid                 => axis_master_tvalid_fft,
      s_axis_a_tready                 => open,
      s_axis_a_tdata                  => axis_master_tdata_fft(63 downto 32),
      s_axis_a_tlast                  => '0',
      s_axis_a_tuser                  => (others=>'0'),
      s_axis_b_tvalid                 => axis_master_tvalid_fft,
      s_axis_b_tready                 => open,
      s_axis_b_tdata                  => axis_master_tdata_fft(63 downto 32),
      m_axis_result_tvalid            => axis_imag_sqr_tvalid,
      m_axis_result_tready            => axis_imag_sqr_tready,
      m_axis_result_tdata             => axis_imag_sqr_tdata,
      m_axis_result_tlast             => open,
      m_axis_result_tuser             => open);

  magnitude_squared_add_floating_point : add_floating_point
    port map (
      aclk                            => clk,
      aresetn                         => rst_n,
      s_axis_a_tvalid                 => axis_real_sqr_tvalid,
      s_axis_a_tready                 => axis_real_sqr_tready,
      s_axis_a_tdata                  => axis_real_sqr_tdata,
      s_axis_a_tlast                  => axis_real_sqr_tlast,
      s_axis_a_tuser                  => index_real_sqr,
      s_axis_b_tvalid                 => axis_imag_sqr_tvalid,
      s_axis_b_tready                 => axis_imag_sqr_tready,
      s_axis_b_tdata                  => axis_imag_sqr_tdata,
      m_axis_result_tvalid            => axis_mag_sqr_tvalid,
      m_axis_result_tready            => axis_mag_sqr_tready,
      m_axis_result_tdata             => axis_mag_sqr_tdata,
      m_axis_result_tlast             => axis_mag_sqr_tlast,
      m_axis_result_tuser             => index_mag_sqr);

  magnitude_sqrt_floating_point : sqrt_floating_point
    port map (
      aclk                            => clk,
      aresetn                         => rst_n,
      s_axis_a_tvalid                 => axis_mag_sqr_tvalid,
      s_axis_a_tready                 => axis_mag_sqr_tready,
      s_axis_a_tdata                  => axis_mag_sqr_tdata,
      s_axis_a_tlast                  => axis_mag_sqr_tlast,
      s_axis_a_tuser                  => index_mag_sqr,
      m_axis_result_tvalid            => axis_mag_tvalid,
      m_axis_result_tready            => axis_mag_tready,
      m_axis_result_tdata             => axis_mag_tdata,
      m_axis_result_tlast             => axis_mag_tlast,
      m_axis_result_tuser             => index_mag);

  threshold_gteq_floating_point : gteq_floating_point
    port map (
      aclk                            => clk,
      aresetn                         => rst_n,
      s_axis_a_tvalid                 => axis_mag_tvalid,
      s_axis_a_tready                 => axis_mag_tready,
      s_axis_a_tdata                  => axis_mag_tdata,
      s_axis_a_tlast                  => axis_mag_tlast,
      s_axis_a_tuser                  => axis_mag_tuser,
      s_axis_b_tvalid                 => axis_mag_tvalid,
      s_axis_b_tready                 => open,
      s_axis_b_tdata                  => threshold,
      m_axis_result_tvalid            => axis_threshold_tvalid,
      m_axis_result_tready            => axis_threshold_tready,
      m_axis_result_tdata             => axis_threshold_tdata,
      m_axis_result_tlast             => axis_threshold_tlast,
      m_axis_result_tuser             => axis_threshold_tuser);

  axis_mag_tuser                      <= index_mag & axis_mag_tdata;

  axis_threshold_tready               <= axis_master_tready when output_mode_safe = "01" else
                                         '1';
  threshold_mag                       <= axis_threshold_tuser(31 downto 0);
  index_threshold                     <= axis_threshold_tuser(47 downto 32);

  -- TODO: Restructuring this code could give up to a 15% reduction in the latency of reporting threshold
  --       exceeded. Right now threshold exceeded is updated at the end of a FFT cycle, mostly to
  --       support the threshold not exceeded cases. Allowing it to update as soon as the threshold is
  --       exceeded can provide a speed up. The threshold not exceeded logic will have to be changed
  --       though.
  proc_latch_threshold : process(clk,enable_fft)
  begin
    if (enable_fft = '0') then
      threshold_latched                 <= '0';
      threshold_exceeded_int            <= '0';
      threshold_exceeded_reg            <= '0';
      threshold_exceeded                <= '0';
      threshold_exceeded_stb            <= '0';
      threshold_not_exceeded            <= '0';
      threshold_not_exceeded_stb        <= '0';
      threshold_exceeded_index          <= (others=>'0');
      threshold_exceeded_mag            <= (others=>'0');
      axis_master_irq                   <= '0';
    else
      if rising_edge(clk) then
        -- If the threshold is exceeded, latch the magnitude and index. This can be updated
        if (axis_threshold_tvalid = '1' AND axis_threshold_tdata(0) = '1' AND threshold_latched = '0') then
          threshold_latched             <= '1';
          threshold_exceeded_int        <= '1';
          threshold_exceeded_index      <= index_threshold;
          threshold_exceeded_mag        <= threshold_mag;
        end if;
        -- Set sideband signals at the end of every frame based on the threshold exceeded state
        if (update_threshold_stb = '1') then
          -- Update threshold exceeded status register
          threshold_exceeded_reg        <= threshold_exceeded_int;
          -- IRQ
          if (enable_threshold_irq = '1') then
            axis_master_irq             <= threshold_exceeded_int;
          end if;
          -- Exceeds threshold
          if (enable_thresh_sideband = '1') then
            threshold_exceeded          <= threshold_exceeded_int;
            threshold_exceeded_stb      <= threshold_exceeded_int;
          end if;
          -- Not Exceed Threshold
          if (enable_not_thresh_sideband = '1') then
            threshold_not_exceeded      <= NOT(threshold_exceeded_int);
            threshold_not_exceeded_stb  <= NOT(threshold_exceeded_int);
          end if;
        else
          axis_master_irq               <= '0';
          threshold_exceeded_stb        <= '0';
          threshold_not_exceeded_stb    <= '0';
        end if;
        -- Reset threshold exceeded on start of a new frame
        if (update_threshold_stb = '1' AND clear_threshold_latched = '1') then
          threshold_latched             <= '0';
          threshold_exceeded_int        <= '0';
        end if;
      end if;
    end if;
  end process;

  update_threshold_edge_detect : edge_detect
    generic map (
      EDGE                              => "R")
    port map (
      clk                               => clk,
      reset                             => rst,
      input_detect                      => axis_threshold_tlast,
      edge_detect_stb                   => update_threshold_stb);

  -------------------------------------------------------------------------------
  -- Control and status registers.
  -------------------------------------------------------------------------------
  proc_ctrl_status_reg : process(clk,rst_n)
  begin
    if (rst_n = '0') then
      ctrl_stb_dly                              <= '0';
      ctrl_reg                                  <= (others=>(others=>'0'));
      axis_master_tdest_safe                    <= (others=>'0');
      output_mode_safe                          <= (others=>'0');
    else
      if rising_edge(clk) then
        ctrl_stb_dly                            <= ctrl_stb;
        -- Update control registers only when accelerator 0 is accessed
        if (ctrl_stb = '1') then
          ctrl_reg(to_integer(unsigned(ctrl_addr(7 downto 0)))) <= ctrl_data;
        end if;
        -- Output status register
        if (status_stb = '1') then
          status_data                           <= status_reg(to_integer(unsigned(status_addr(7 downto 0))));
        end if;
        -- The destination should only update when no data is being transmitted over the AXI bus.
        if (enable_fft = '0') then
          axis_master_tdest_safe                <= axis_master_tdest_hold;
        end if;
        -- We can only update the mode when the FFT is complete or disabled. This prevents mode switches in the middle
        -- of a AXI transfer which may corrupt it.
        if (update_threshold_stb = '1' OR enable_fft = '0') then
          output_mode_safe                      <= output_mode;
        end if;
      end if;
    end if;
  end process;

  -- Control Registers
  -- Bank 0 (Enable FFT and destination)
  enable_fft                            <= ctrl_reg(0)(0);
  axis_master_tdest_hold                <= ctrl_reg(0)(31 downto 29);
  -- Bank 1 (FFT Configuration)
  axis_config_tdata                     <= "000" & "000000000000" & '1' & "000" & ctrl_reg(1)(4 downto 0);
  axis_config_tvalid                    <= '1' when (ctrl_addr = std_logic_vector(to_unsigned(1,8)) AND
                                                     ctrl_reg(1)(5) = '1' AND ctrl_stb_dly = '1') else
                                           '0';
    -- output_mode: 00 - Normal FFT frequency output
    --              01 - Threshold result, Index, & Magnitude
    --           10,11 - Discard output. Useful for running the FFT when we only want to trigger on
    --                   the threshold being exceeded without having to send the FFT output somewhere.
  output_mode                           <= ctrl_reg(1)(9 downto 8);
  enable_threshold_irq                  <= ctrl_reg(1)(10);
  enable_thresh_sideband                <= ctrl_reg(1)(11);
  enable_not_thresh_sideband            <= ctrl_reg(1)(12);
  clear_threshold_latched               <= ctrl_reg(1)(13);
  -- Bank 2 (Theshold value)
  threshold                             <= ctrl_reg(2)(31 downto 0);

  -- Status Registers
  -- Bank 0 (Enable FFT and destination Readback)
  status_reg(0)(0)                      <= enable_fft;
  status_reg(0)(31 downto 29)           <= axis_master_tdest_safe;
  -- Bank 1 (FFT Configuration Readback)
  status_reg(1)(4 downto 0)             <= axis_config_tdata(4 downto 0);
  status_reg(1)(5)                      <= axis_config_tvalid;
  status_reg(1)(9 downto 8)             <= output_mode_safe;
  status_reg(1)(10)                     <= enable_threshold_irq;
  status_reg(1)(11)                     <= enable_thresh_sideband;
  status_reg(1)(12)                     <= enable_not_thresh_sideband;
  status_reg(1)(13)                     <= clear_threshold_latched;
  -- Bank 2 (Theshold comparison value)
  status_reg(2)(31 downto 0)            <= threshold;
  -- Bank 3 (Threshold exceeded index and flag)
  status_reg(3)(15 downto 0)            <= threshold_exceeded_index;
  status_reg(3)(31)                     <= threshold_exceeded_reg;
  -- Bank 4 (Magnitude that exceeded the threshold)
  status_reg(4)(31 downto 0)            <= threshold_exceeded_mag;

  -- Debug
  -- fft_in_real     <= float2real(axis_slave_tdata(63 downto 32));
  -- fft_in_imag     <= float2real(axis_slave_tdata(31 downto 0));
  -- fft_out_real    <= float2real(axis_master_tdata_fft(63 downto 32));
  -- fft_out_imag    <= float2real(axis_master_tdata_fft(31 downto 0));

end architecture;