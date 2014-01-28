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
--  File: synchronizer_slv.vhd
--  Author: Jonathon Pendlum (jon.pendlum@gmail.com)
--  Description: Sychronizer to cross clock domains using two registers.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity synchronizer_slv is
  generic (
    STROBE_EDGE               : string           := "N";  -- "R"ising, "F"alling, "B"oth, or "N"one.
    RESET_OUTPUT              : std_logic_vector := "0"); -- Can either set everything to the same value or individualize each bit
  port (
    clk                       : in    std_logic;
    reset                     : in    std_logic;
    async                     : in    std_logic_vector;     -- Asynchronous input
    sync                      : out   std_logic_vector);     -- Synchronized output
end entity;

architecture RTL of synchronizer_slv is

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

begin

  -- The default outputs are all the same
  gen_same_default_output : if RESET_OUTPUT'length = 1 generate
    gen_synchronizers : for i in 0 to async'length-1 generate
      inst_synchronizer : synchronizer
        generic map (
          STROBE_EDGE             => STROBE_EDGE,
          RESET_OUTPUT            => RESET_OUTPUT(0))
        port map (
          clk                     => clk,
          reset                   => reset,
          async                   => async(i),
          sync                    => sync(i));
    end generate;
  end generate;

-- The outputs are individualized and async was declared using 'downto' orientation.
-- This kludge is necessary (as far as I know), because I could not think of another
-- way to deal with the fact that RESET_OUTPUT and async could have different
-- orientations, i.e. '0 to n' vs 'n downto 0'.
gen_individualized_default_output : if ((RESET_OUTPUT'length /= 1) AND (RESET_OUTPUT'left = async'left)) generate
    gen_synchronizers : for i in 0 to async'length-1 generate
      inst_synchronizer : synchronizer
        generic map (
          STROBE_EDGE             => STROBE_EDGE,
          RESET_OUTPUT            => RESET_OUTPUT(i))
        port map (
          clk                     => clk,
          reset                   => reset,
          async                   => async(i),
          sync                    => sync(i));
    end generate;
  end generate;

gen_individualized_default_output_inverted : if ((RESET_OUTPUT'length /= 1) AND (RESET_OUTPUT'left /= async'left)) generate
    gen_synchronizers : for i in 0 to async'length-1 generate
      inst_synchronizer : synchronizer
        generic map (
          STROBE_EDGE             => STROBE_EDGE,
          RESET_OUTPUT            => RESET_OUTPUT(async'length-1-i))
        port map (
          clk                     => clk,
          reset                   => reset,
          async                   => async(i),
          sync                    => sync(i));
    end generate;
  end generate;

end RTL;