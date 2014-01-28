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
--  File: synchronizer.vhd
--  Author: Jonathon Pendlum (jon.pendlum@gmail.com)
--  Description: Sychronizer to cross clock domains using two registers. If
--               the signal is a strobe, the edge can be specified.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity synchronizer is
  generic (
    STROBE_EDGE               : string    := "N";  -- "R"ising, "F"alling, "B"oth, or "N"one.
    RESET_OUTPUT              : std_logic := '0');
  port (
    clk                       : in    std_logic;
    reset                     : in    std_logic;
    async                     : in    std_logic;      -- Asynchronous input
    sync                      : out   std_logic);     -- Synchronized output
end entity;

architecture RTL of synchronizer is

  component edge_detect
    generic (
      EDGE                      : string  := "R"); -- "R"ising, "F"alling, "B"oth, or "N"one.
    port (
      clk                       : in    std_logic;
      reset                     : in    std_logic;
      input_detect              : in    std_logic;      -- Input data
      edge_detect_stb           : out   std_logic);     -- Edge detected strobe
  end component;

  signal async_meta1            : std_logic;
  signal async_meta2            : std_logic;

begin

  proc_synchronize : process(clk,reset)
  begin
    if (reset = '1') then
      async_meta1             <= RESET_OUTPUT;
      async_meta2             <= RESET_OUTPUT;
    else
      if rising_edge(clk) then
        async_meta1           <= async;
        async_meta2           <= async_meta1;
      end if;
    end if;
  end process;

  gen_if_use_edge_detect : if (STROBE_EDGE(STROBE_EDGE'left) /= 'N') generate
    inst_edge_detect : edge_detect
      generic map (
        EDGE                  => STROBE_EDGE)
      port map (
        clk                   => clk,
        reset                 => reset,
        input_detect          => async_meta2,
        edge_detect_stb       => sync);
  end generate;

  gen_if_no_edge_detect : if (STROBE_EDGE(STROBE_EDGE'left) = 'N') generate
    sync                      <= async_meta2;
  end generate;

end RTL;