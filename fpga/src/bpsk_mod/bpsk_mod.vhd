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
--  File: tx_mod.vhd
--  Author: Jonathon Pendlum (jon.pendlum@gmail.com)
--  Description: Transmit data modulator. Biphase modulates signal with
--               input binary data with option to trigger.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bpsk_mod is
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
end entity;

architecture RTL of bpsk_mod is
  -----------------------------------------------------------------------------
  -- Signals Declaration
  -----------------------------------------------------------------------------
  type slv_256x32 is array(0 to 255) of std_logic_vector(31 downto 0);

  signal ctrl_reg                     : slv_256x32 := (others=>(others=>'0'));
  signal status_reg                   : slv_256x32 := (others=>(others=>'0'));
  signal axis_master_tdest_hold       : std_logic_vector(2 downto 0);
  signal axis_master_tdest_safe       : std_logic_vector(2 downto 0);

  signal mod_data                     : std_logic_vector(63 downto 0);
  signal bit_cnt                      : integer range 0 to 63;

  signal enable                       : std_logic;
  signal external_enable              : std_logic;
  signal external_trigger_enable      : std_logic;
  signal packet_size_cnt              : integer;
  signal packet_size                  : integer;

  signal trigger_stb_reg              : std_logic;
  signal transmitting                 : std_logic;

begin

  axis_slave_irq                                <= '0';
  axis_master_irq                               <= '0';
  axis_master_tdest                             <= axis_master_tdest_safe;

  proc_modulate : process(clk,enable,external_enable)
  begin
    if (enable = '0' AND external_enable = '0') then
      axis_slave_tready                         <= '0';
      axis_master_tvalid                        <= '0';
      axis_master_tlast                         <= '0';
      axis_master_tdata                         <= (others=>'0');
      packet_size_cnt                           <= packet_size; -- This is intentional
      transmitting                              <= '0';
    else
      if rising_edge(clk) then
        transmitting                            <= '1';
        -- TODO: This code takes 65 clock cycles to transfer 64 complex samples. Should look into
        --       redoing this so the single clock cycle delay is avoided.
        -- Grab the AXI-Stream data when enabled
        if (axis_slave_tvalid = '1' AND bit_cnt = 0) then
          axis_slave_tready                     <= '1';
          axis_master_tvalid                    <= '1';
          mod_data                              <= axis_slave_tdata;
        else
          axis_slave_tready                     <= '0';
        end if;
        -- Count the number of data bits sent
        axis_master_tlast                       <= '0';
        if (axis_master_tready = '1') then
          if (bit_cnt = 63) then
            if (packet_size_cnt = 1) then
              axis_master_tlast                 <= '1';
              packet_size_cnt                   <= packet_size;
            else
              packet_size_cnt                   <= packet_size_cnt - 1;
            end if;
            axis_master_tvalid                  <= '0';
            bit_cnt                             <= 0;
          else
            bit_cnt                             <= bit_cnt + 1;
          end if;
        end if;
        -- Modulate I & Q
        -- I
        if (mod_data(bit_cnt) = '1') then
          axis_master_tdata(31 downto 0)      <= x"7FFFFFFF";
        else
          axis_master_tdata(31 downto 0)      <= x"80000000";
        end if;
        -- Q
        axis_master_tdata(63 downto 32)       <= (others=>'0');
      end if;
    end if;
  end process;

  -------------------------------------------------------------------------------
  -- Control and status registers.
  -------------------------------------------------------------------------------
  proc_ctrl_status_reg : process(clk,rst_n)
  begin
    if (rst_n = '0') then
      external_enable                           <= '0';
      ctrl_reg                                  <= (others=>(others=>'0'));
      axis_master_tdest_safe                    <= (others=>'0');
      trigger_stb_reg                           <= '0';
    else
      if rising_edge(clk) then
        -- Update control registers only when accelerator 0 is accessed
        if (ctrl_stb = '1') then
          ctrl_reg(to_integer(unsigned(ctrl_addr(7 downto 0)))) <= ctrl_data;
        end if;
        -- Output status register
        if (status_stb = '1') then
          status_data                           <= status_reg(to_integer(unsigned(status_addr(7 downto 0))));
        end if;
        -- The destination can only update when no data is being transmitted, i.e. FFT disabled
        if (enable = '0' AND external_enable = '0') then
          axis_master_tdest_safe                <= axis_master_tdest_hold;
        end if;
        -- Register sideband signals
        trigger_stb_reg                         <= trigger_stb;
        -- Enable on trigger and disable only when external_trigger_enable is deasserted
        if (trigger_stb_reg = '1' AND external_trigger_enable = '1') then
          external_enable                       <= '1';
        end if;
        if (external_trigger_enable = '0') then
          external_enable                       <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Control Registers
  -- Bank 0 (Enable and destination)
  enable                                <= ctrl_reg(0)(0);
  external_trigger_enable               <= ctrl_reg(0)(1);
  axis_master_tdest_hold                <= ctrl_reg(0)(31 downto 29);
  -- Bank 1 (Packet size)
  packet_size                           <= to_integer(unsigned(ctrl_reg(1)(31 downto 0)));

  -- Status Registers
  -- Bank 0 (Enable and destination Readback)
  status_reg(0)(0)                      <= enable;
  status_reg(0)(1)                      <= external_trigger_enable;
  status_reg(0)(31 downto 29)           <= axis_master_tdest_hold;
  -- Bank 1 (Packet size Readback)
  status_reg(1)                         <= std_logic_vector(to_unsigned(packet_size,32));
  -- Bank 2
  status_reg(2)(0)                      <= transmitting;

end architecture;