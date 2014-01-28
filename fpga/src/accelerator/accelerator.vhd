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
--  File: accelerator.vhd
--  Author: Jonathon Pendlum (jon.pendlum@gmail.com)
--  Description: Template file for custom accelerators.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity accelerator is
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
    -- AXIS Stream Slave Interface
    axis_slave_tvalid           : in    std_logic;
    axis_slave_tready           : out   std_logic;
    axis_slave_tdata            : in    std_logic_vector(63 downto 0);
    axis_slave_tid              : in    std_logic_vector(2 downto 0);
    axis_slave_tlast            : in    std_logic;
    axis_slave_irq              : out   std_logic;
    -- AXIS Stream Master Interface
    axis_master_tvalid          : out   std_logic;
    axis_master_tready          : in    std_logic;
    axis_master_tdata           : out   std_logic_vector(63 downto 0);
    axis_master_tdest           : out   std_logic_vector(2 downto 0);
    axis_master_tlast           : out   std_logic;
    axis_master_irq             : out   std_logic;
    -- Sideband signals
    example_sideband_signals    : out   std_logic_vector(7 downto 0));
end entity;

architecture RTL of spectrum_sense is

  -------------------------------------------------------------------------------
  -- Component Declaration
  -------------------------------------------------------------------------------
  component fifo_axis_64x4096
    port (
      s_aclk                        : in    std_logic;
      s_aresetn                     : in    std_logic;
      s_axis_tvalid                 : in    std_logic;
      s_axis_tready                 : out   std_logic;
      s_axis_tdata                  : in    std_logic_vector(63 downto 0);
      s_axis_tlast                  : in    std_logic;
      m_axis_tvalid                 : out   std_logic;
      m_axis_tready                 : in    std_logic;
      m_axis_tdata                  : out   std_logic_vector(63 downto 0);
      m_axis_tlast                  : out   std_logic;
      axis_data_count               : out   std_logic_vector(12 downto 0);
      axis_overflow                 : out   std_logic;
      axis_underflow                : out   std_logic);
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
  signal reset_fifo                   : std_logic;
  signal reset_fifo_n                 : std_logic;
  signal axis_data_count              : std_logic_vector(12 downto 0);

begin

  rst                                 <= NOT(rst_n);
  reset_fifo_n                        <= NOT(reset_fifo_n) AND rst_n;

  -- Interrupt signals trigger on a rising edge
  axis_slave_irq                      <= '0';
  axis_master_irq                     <= '0';

  -- Loopback FIFO.
  example_fifo_axis_64x4096 : fifo_axis_64x4096
    port map (
      s_aclk                          => clk,
      s_aresetn                       => reset_fifo_n,
      s_axis_tvalid                   => axis_slave_tvalid,
      s_axis_tready                   => axis_slave_tready,
      s_axis_tdata                    => axis_slave_tdata,
      s_axis_tlast                    => axis_slave_tlast,
      m_axis_tvalid                   => axis_master_tvalid,
      m_axis_tready                   => axis_master_tready,
      m_axis_tdata                    => axis_master_tdata,
      m_axis_tlast                    => axis_master_tlast,
      axis_data_count                 => axis_data_count,
      axis_overflow                   => open,
      axis_underflow                  => open);

  -------------------------------------------------------------------------------
  -- Control and status registers.
  -------------------------------------------------------------------------------
  proc_ctrl_status_reg : process(clk,rst_n)
  begin
    if (rst_n = '0') then
      ctrl_reg                                  <= (others=>(others=>'0'));
      status_data                               <= (others=>'0');
      axis_master_tdest_safe                    <= (others=>'0');
    else
      if rising_edge(clk) then
        -- Update control registers only when the accelerator is accessed
        if (ctrl_stb = '1') then
          ctrl_reg(to_integer(unsigned(ctrl_addr(7 downto 0)))) <= ctrl_data;
        end if;
        -- Output status register when selected
        if (status_stb = '1') then
          status_data                           <= status_reg(to_integer(unsigned(status_addr(7 downto 0))));
        end if;
        -- The destination should only update when no data is being transmitted over the AXI bus.
        if (reset_fifo = '1') then
          axis_master_tdest_safe                <= axis_master_tdest_hold;
        end if;
      end if;
    end if;
  end process;

  -- Control Registers
  -- Bank 0
  reset_fifo                                    <= ctrl_reg(0)(0);
  axis_master_tdest_hold                        <= ctrl_reg(0)(31 downto 29);
  -- Bank 1
  example_sideband_signals                      <= ctrl_reg(1)(7 downto 0);

  -- Status Registers
  -- Bank 0
  status_reg(0)(0)                              <= reset_fifo;
  status_reg(0)(31 downto 29)                   <= axis_master_tdest_safe;
  -- Bank 1
  status_reg(1)(7 downto 0)                     <= example_sideband_signals;
  -- Bank 2
  status_reg(2)(12 downto 0)                    <= axis_data_count;

end architecture;