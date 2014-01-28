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
--  File: axi_lite_to_parallel_bus.vhd
--  Author: Jonathon Pendlum (jon.pendlum@gmail.com)
--  Description: Converts a AXI-4 Lite slave interface to a simple parallel
--               address + data interface.
--
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity axi_lite_to_parallel_bus is
  generic (
    -- 32K word address space
    C_BASEADDR                  : std_logic_vector(31 downto 0) := x"40000000";
    C_HIGHADDR                  : std_logic_vector(31 downto 0) := x"4001ffff");
  port (
    S_AXI_ACLK                  : in    std_logic;
    S_AXI_ARESETN               : in    std_logic;
    S_AXI_ARADDR                : in    std_logic_vector(31 downto 0);
    S_AXI_ARVALID               : in    std_logic;
    S_AXI_ARREADY               : out   std_logic;
    S_AXI_RDATA                 : out   std_logic_vector(31 downto 0);
    S_AXI_RRESP                 : out   std_logic_vector(1 downto 0);
    S_AXI_RVALID                : out   std_logic;
    S_AXI_RREADY                : in    std_logic;
    S_AXI_AWADDR                : in    std_logic_vector(31 downto 0);
    S_AXI_AWVALID               : in    std_logic;
    S_AXI_AWREADY               : out   std_logic;
    S_AXI_WDATA                 : in    std_logic_vector(31 downto 0);
    S_AXI_WSTRB                 : in    std_logic_vector(3 downto 0);
    S_AXI_WVALID                : in    std_logic;
    S_AXI_WREADY                : out   std_logic;
    S_AXI_BRESP                 : out   std_logic_vector(1 downto 0);
    S_AXI_BVALID                : out   std_logic;
    S_AXI_BREADY                : in    std_logic;
    read_addr                   : out   std_logic_vector(14 downto 0);
    read_data                   : in    std_logic_vector(31 downto 0);
    read_stb                    : out   std_logic;
    write_addr                  : out   std_logic_vector(14 downto 0);
    write_data                  : out   std_logic_vector(31 downto 0);
    write_stb                   : out   std_logic);
end entity;

architecture RTL of axi_lite_to_parallel_bus is

  -------------------------------------------------------------------------------
  -- Signal Declaration
  -------------------------------------------------------------------------------
  type read_state_type is (READ_IDLE,WAIT_FOR_READ_DATA,SET_READ_DATA_VALID);
  type write_state_type is (WRITE_IDLE,WAIT_FOR_WVALID,WAIT_TO_WRITE_DATA);

  signal read_state             : read_state_type;
  signal write_state            : write_state_type;

begin

  -----------------------------------------------------------------------------
  -- State machine for Read Interface
  -----------------------------------------------------------------------------
  proc_read_state_machine : process(S_AXI_ACLK,S_AXI_ARESETN)
  begin
    if (S_AXI_ARESETN = '0') then
      S_AXI_ARREADY             <= '0';
      S_AXI_RVALID              <= '0';
      S_AXI_RDATA               <= (others=>'0');
      read_addr                 <= (others=>'0');
      read_stb                  <= '0';
      read_state                <= READ_IDLE;
    else
      if rising_edge(S_AXI_ACLK) then
        case read_state is
          when READ_IDLE =>
            read_stb            <= '0';
            S_AXI_RVALID        <= '0';
            S_AXI_ARREADY       <= '0';
            if (S_AXI_ARVALID = '1') then
              -- ARREADY is held low until ARVALID is asserted.
              -- This may seem a little backwards, but this is similar to Xilinx's
              -- AXI4-Lite IPIF LogiCore documentation.
              S_AXI_ARREADY     <= '1';
              -- Bus access is assumed to be by words so the lower 2 bits are not needed.
              read_addr         <= S_AXI_ARADDR(16 downto 2) - C_BASEADDR(16 downto 2);
              read_stb          <= '1';
              read_state        <= WAIT_FOR_READ_DATA;
            end if;

          -- Wait a single cycle for the strobe signal to propagate and
          -- read_data to update
          when WAIT_FOR_READ_DATA =>
            S_AXI_ARREADY       <= '0';
            read_stb            <= '0';
            read_state          <= SET_READ_DATA_VALID;

          when SET_READ_DATA_VALID =>
            if (S_AXI_RREADY = '1') then
              S_AXI_RVALID      <= '1';
              S_AXI_RDATA       <= read_data;
              read_state        <= READ_IDLE;
            end if;

          when others =>
            read_state          <= READ_IDLE;
        end case;
      end if;
    end if;
  end process;

  S_AXI_RRESP                   <= "00";

  -----------------------------------------------------------------------------
  -- State machine for Write Interface
  -----------------------------------------------------------------------------
  proc_write_state_machine : process(S_AXI_ACLK,S_AXI_ARESETN)
  begin
    if (S_AXI_ARESETN = '0') then
      S_AXI_AWREADY             <= '0';
      S_AXI_WREADY              <= '0';
      write_addr                <= (others=>'0');
      write_data                <= (others=>'0');
      write_stb                 <= '0';
      write_state               <= WRITE_IDLE;
    else
      if rising_edge(S_AXI_ACLK) then
        case write_state is
          when WRITE_IDLE =>
            S_AXI_AWREADY       <= '0';
            S_AXI_WREADY        <= '0';
            write_stb           <= '0';
            if (S_AXI_AWVALID = '1') then
              S_AXI_AWREADY     <= '1';
              write_addr        <= S_AXI_AWADDR(16 downto 2) - C_BASEADDR(16 downto 2);
              if (S_AXI_WVALID = '1') then
                S_AXI_WREADY    <= '1';
                write_data      <= S_AXI_WDATA;
                write_stb       <= '1';
                write_state     <= WAIT_TO_WRITE_DATA;
              else
                write_state     <= WAIT_FOR_WVALID;
              end if;
            end if;

          when WAIT_FOR_WVALID =>
            S_AXI_AWREADY       <= '0';
            if (S_AXI_WVALID = '1') then
              S_AXI_WREADY      <= '1';
              write_data        <= S_AXI_WDATA;
              write_stb         <= '1';
              write_state       <= WAIT_TO_WRITE_DATA;
            end if;

          when WAIT_TO_WRITE_DATA =>
            S_AXI_AWREADY       <= '0';
            S_AXI_WREADY        <= '0';
            write_stb           <= '0';
            write_state         <= WRITE_IDLE;

          when others =>
            write_state         <= WRITE_IDLE;
        end case;
      end if;
    end if;
  end process;

  S_AXI_BRESP                   <= "00";
  S_AXI_BVALID                  <= S_AXI_BREADY;

end architecture;