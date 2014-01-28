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
--  File: axis_interconnect_8x8_dummy.vhd
--  Author: Jonathon Pendlum (jon.pendlum@gmail.com)
--  Description: Simplified version of AXI-Stream interconnect made for
--               simulation purposes only.
--
-------------------------------------------------------------------------------
library ieee;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_interconnect_8x8 is
  port (
    aclk                  : in std_logic;
    aresetn               : in std_logic;
    s00_axis_aclk         : in std_logic;
    s01_axis_aclk         : in std_logic;
    s02_axis_aclk         : in std_logic;
    s03_axis_aclk         : in std_logic;
    s04_axis_aclk         : in std_logic;
    s05_axis_aclk         : in std_logic;
    s06_axis_aclk         : in std_logic;
    s07_axis_aclk         : in std_logic;
    s00_axis_aresetn      : in std_logic;
    s01_axis_aresetn      : in std_logic;
    s02_axis_aresetn      : in std_logic;
    s03_axis_aresetn      : in std_logic;
    s04_axis_aresetn      : in std_logic;
    s05_axis_aresetn      : in std_logic;
    s06_axis_aresetn      : in std_logic;
    s07_axis_aresetn      : in std_logic;
    s00_axis_tvalid       : in std_logic;
    s01_axis_tvalid       : in std_logic;
    s02_axis_tvalid       : in std_logic;
    s03_axis_tvalid       : in std_logic;
    s04_axis_tvalid       : in std_logic;
    s05_axis_tvalid       : in std_logic;
    s06_axis_tvalid       : in std_logic;
    s07_axis_tvalid       : in std_logic;
    s00_axis_tready       : out std_logic;
    s01_axis_tready       : out std_logic;
    s02_axis_tready       : out std_logic;
    s03_axis_tready       : out std_logic;
    s04_axis_tready       : out std_logic;
    s05_axis_tready       : out std_logic;
    s06_axis_tready       : out std_logic;
    s07_axis_tready       : out std_logic;
    s00_axis_tdata        : in std_logic_vector(63 downto 0);
    s01_axis_tdata        : in std_logic_vector(63 downto 0);
    s02_axis_tdata        : in std_logic_vector(63 downto 0);
    s03_axis_tdata        : in std_logic_vector(63 downto 0);
    s04_axis_tdata        : in std_logic_vector(63 downto 0);
    s05_axis_tdata        : in std_logic_vector(63 downto 0);
    s06_axis_tdata        : in std_logic_vector(63 downto 0);
    s07_axis_tdata        : in std_logic_vector(63 downto 0);
    s00_axis_tlast        : in std_logic;
    s01_axis_tlast        : in std_logic;
    s02_axis_tlast        : in std_logic;
    s03_axis_tlast        : in std_logic;
    s04_axis_tlast        : in std_logic;
    s05_axis_tlast        : in std_logic;
    s06_axis_tlast        : in std_logic;
    s07_axis_tlast        : in std_logic;
    s00_axis_tdest        : in std_logic_vector(2 downto 0);
    s01_axis_tdest        : in std_logic_vector(2 downto 0);
    s02_axis_tdest        : in std_logic_vector(2 downto 0);
    s03_axis_tdest        : in std_logic_vector(2 downto 0);
    s04_axis_tdest        : in std_logic_vector(2 downto 0);
    s05_axis_tdest        : in std_logic_vector(2 downto 0);
    s06_axis_tdest        : in std_logic_vector(2 downto 0);
    s07_axis_tdest        : in std_logic_vector(2 downto 0);
    s00_axis_tid          : in std_logic_vector(2 downto 0);
    s01_axis_tid          : in std_logic_vector(2 downto 0);
    s02_axis_tid          : in std_logic_vector(2 downto 0);
    s03_axis_tid          : in std_logic_vector(2 downto 0);
    s04_axis_tid          : in std_logic_vector(2 downto 0);
    s05_axis_tid          : in std_logic_vector(2 downto 0);
    s06_axis_tid          : in std_logic_vector(2 downto 0);
    s07_axis_tid          : in std_logic_vector(2 downto 0);
    m00_axis_aclk         : in std_logic;
    m01_axis_aclk         : in std_logic;
    m02_axis_aclk         : in std_logic;
    m03_axis_aclk         : in std_logic;
    m04_axis_aclk         : in std_logic;
    m05_axis_aclk         : in std_logic;
    m06_axis_aclk         : in std_logic;
    m07_axis_aclk         : in std_logic;
    m00_axis_aresetn      : in std_logic;
    m01_axis_aresetn      : in std_logic;
    m02_axis_aresetn      : in std_logic;
    m03_axis_aresetn      : in std_logic;
    m04_axis_aresetn      : in std_logic;
    m05_axis_aresetn      : in std_logic;
    m06_axis_aresetn      : in std_logic;
    m07_axis_aresetn      : in std_logic;
    m00_axis_tvalid       : out std_logic;
    m01_axis_tvalid       : out std_logic;
    m02_axis_tvalid       : out std_logic;
    m03_axis_tvalid       : out std_logic;
    m04_axis_tvalid       : out std_logic;
    m05_axis_tvalid       : out std_logic;
    m06_axis_tvalid       : out std_logic;
    m07_axis_tvalid       : out std_logic;
    m00_axis_tready       : in std_logic;
    m01_axis_tready       : in std_logic;
    m02_axis_tready       : in std_logic;
    m03_axis_tready       : in std_logic;
    m04_axis_tready       : in std_logic;
    m05_axis_tready       : in std_logic;
    m06_axis_tready       : in std_logic;
    m07_axis_tready       : in std_logic;
    m00_axis_tdata        : out std_logic_vector(63 downto 0);
    m01_axis_tdata        : out std_logic_vector(63 downto 0);
    m02_axis_tdata        : out std_logic_vector(63 downto 0);
    m03_axis_tdata        : out std_logic_vector(63 downto 0);
    m04_axis_tdata        : out std_logic_vector(63 downto 0);
    m05_axis_tdata        : out std_logic_vector(63 downto 0);
    m06_axis_tdata        : out std_logic_vector(63 downto 0);
    m07_axis_tdata        : out std_logic_vector(63 downto 0);
    m00_axis_tlast        : out std_logic;
    m01_axis_tlast        : out std_logic;
    m02_axis_tlast        : out std_logic;
    m03_axis_tlast        : out std_logic;
    m04_axis_tlast        : out std_logic;
    m05_axis_tlast        : out std_logic;
    m06_axis_tlast        : out std_logic;
    m07_axis_tlast        : out std_logic;
    m00_axis_tdest        : out std_logic_vector(2 downto 0);
    m01_axis_tdest        : out std_logic_vector(2 downto 0);
    m02_axis_tdest        : out std_logic_vector(2 downto 0);
    m03_axis_tdest        : out std_logic_vector(2 downto 0);
    m04_axis_tdest        : out std_logic_vector(2 downto 0);
    m05_axis_tdest        : out std_logic_vector(2 downto 0);
    m06_axis_tdest        : out std_logic_vector(2 downto 0);
    m07_axis_tdest        : out std_logic_vector(2 downto 0);
    m00_axis_tid          : out std_logic_vector(2 downto 0);
    m01_axis_tid          : out std_logic_vector(2 downto 0);
    m02_axis_tid          : out std_logic_vector(2 downto 0);
    m03_axis_tid          : out std_logic_vector(2 downto 0);
    m04_axis_tid          : out std_logic_vector(2 downto 0);
    m05_axis_tid          : out std_logic_vector(2 downto 0);
    m06_axis_tid          : out std_logic_vector(2 downto 0);
    m07_axis_tid          : out std_logic_vector(2 downto 0);
    s00_decode_err        : out std_logic;
    s01_decode_err        : out std_logic;
    s02_decode_err        : out std_logic;
    s03_decode_err        : out std_logic;
    s04_decode_err        : out std_logic;
    s05_decode_err        : out std_logic;
    s06_decode_err        : out std_logic;
    s07_decode_err        : out std_logic;
    s00_fifo_data_count   : out std_logic_vector(31 downto 0);
    m00_fifo_data_count   : out std_logic_vector(31 downto 0));
  end entity;

architecture RTL of axis_interconnect_8x8 is

  component fifo_axis_64x4096
    port (
      s_aclk            : in    std_logic;
      s_aresetn         : in    std_logic;
      s_axis_tvalid     : in    std_logic;
      s_axis_tready     : out   std_logic;
      s_axis_tdata      : in    std_logic_vector(63 downto 0);
      s_axis_tlast      : in    std_logic;
      m_axis_tvalid     : out   std_logic;
      m_axis_tready     : in    std_logic;
      m_axis_tdata      : out   std_logic_vector(63 downto 0);
      m_axis_tlast      : out   std_logic;
      axis_overflow     : out   std_logic;
      axis_underflow    : out   std_logic);
  end component;

  type int_arr_8 is array(0 to 7) of integer;
  type slv_8x64 is array(0 to 7) of std_logic_vector(63 downto 0);
  type slv_8x3 is array(0 to 7) of std_logic_vector(2 downto 0);

  signal m_axis_map       : int_arr_8 := (0,0,0,0,0,0,0,0);
  signal m_axis_busy      : std_logic_vector(7 downto 0);

  signal s_axis_tvalid    : std_logic_vector(7 downto 0);
  signal s_axis_tready    : std_logic_vector(7 downto 0);
  signal s_axis_tlast     : std_logic_vector(7 downto 0);
  signal s_axis_tdata     : slv_8x64;
  signal s_axis_tdest     : slv_8x3;
  signal s_axis_tid       : slv_8x3;
  signal m_axis_tvalid    : std_logic_vector(7 downto 0);
  signal m_axis_tready    : std_logic_vector(7 downto 0);
  signal m_axis_tlast     : std_logic_vector(7 downto 0);
  signal m_axis_tdata     : slv_8x64;
  signal m_axis_tdest     : slv_8x3;
  signal m_axis_tid       : slv_8x3;

begin

  gen_all : for i in 0 to 7 generate
    proc_round_robin : process(aclk,aresetn)
    begin
      if (aresetn = '0') then
        m_axis_map(i)       <= 0;
        m_axis_busy(i)      <= '0';
      else
        if rising_edge(aclk) then
          if (s_axis_tdest(m_axis_map(i)) = std_logic_vector(to_unsigned(i,3)) AND
              s_axis_tvalid(m_axis_map(i)) = '1' AND m_axis_busy(i) = '0') then
            m_axis_busy(i)  <= '1';
          else
            if (m_axis_busy(i) = '0') then
              if (m_axis_map(i) = 7) then
                m_axis_map(i) <= 0;
              else
                m_axis_map(i) <= m_axis_map(i) + 1;
              end if;
            end if;
          end if;
          if (m_axis_busy(i) = '1' AND s_axis_tlast(m_axis_map(i)) = '1' AND s_axis_tvalid(m_axis_map(i)) = '1') then
            m_axis_busy(i)  <= '0';
            if (m_axis_map(i) = 7) then
              m_axis_map(i) <= 0;
            else
              m_axis_map(i) <= m_axis_map(i) + 1;
            end if;
          end if;
        end if;
      end if;
    end process;

    m_axis_tdest(i)         <= (others=>'0') when m_axis_busy(i) = '0' else
                               s_axis_tdest(m_axis_map(i));

    m_axis_tid(i)           <= (others=>'0') when m_axis_busy(i) = '0' else
                               s_axis_tid(m_axis_map(i));

    m_axis_tdata(i)         <= (others=>'0') when m_axis_busy(i) = '0' else
                               s_axis_tdata(m_axis_map(i));

    m_axis_tvalid(i)        <= '0' when m_axis_busy(i) = '0' else
                               s_axis_tvalid(m_axis_map(i));

    m_axis_tlast(i)         <= '0' when m_axis_busy(i) = '0' else
                               s_axis_tlast(m_axis_map(i));

    s_axis_tready(i)        <= m_axis_tready(0) when m_axis_map(0) = i AND m_axis_busy(0) = '1' else
                               m_axis_tready(1) when m_axis_map(1) = i AND m_axis_busy(1) = '1' else
                               m_axis_tready(2) when m_axis_map(2) = i AND m_axis_busy(2) = '1' else
                               m_axis_tready(3) when m_axis_map(3) = i AND m_axis_busy(3) = '1' else
                               m_axis_tready(4) when m_axis_map(4) = i AND m_axis_busy(4) = '1' else
                               m_axis_tready(5) when m_axis_map(5) = i AND m_axis_busy(5) = '1' else
                               m_axis_tready(6) when m_axis_map(6) = i AND m_axis_busy(6) = '1' else
                               m_axis_tready(7) when m_axis_map(7) = i AND m_axis_busy(7) = '1' else '0';
  end generate;


  slave_fifo_axis_64x4096 : fifo_axis_64x4096
  port map (
    s_aclk                  => aclk,
    s_aresetn               => aresetn,
    s_axis_tvalid           => s00_axis_tvalid,
    s_axis_tready           => s00_axis_tready,
    s_axis_tdata            => s00_axis_tdata,
    s_axis_tlast            => s00_axis_tlast,
    m_axis_tvalid           => s_axis_tvalid(0),
    m_axis_tready           => s_axis_tready(0),
    m_axis_tdata            => s_axis_tdata(0),
    m_axis_tlast            => s_axis_tlast(0),
    axis_overflow           => open,
    axis_underflow          => open);

  --s_axis_tvalid(0)          <= s00_axis_tvalid;
  --s_axis_tlast(0)           <= s00_axis_tlast;
  --s_axis_tdata(0)           <= s00_axis_tdata;
  s_axis_tdest(0)           <= s00_axis_tdest;
  s_axis_tid(0)             <= s00_axis_tid;
  --s00_axis_tready           <= s_axis_tready(0);
  s_axis_tvalid(1)          <= s01_axis_tvalid;
  s_axis_tlast(1)           <= s01_axis_tlast;
  s_axis_tdata(1)           <= s01_axis_tdata;
  s_axis_tdest(1)           <= s01_axis_tdest;
  s_axis_tid(1)             <= s01_axis_tid;
  s01_axis_tready           <= s_axis_tready(1);
  s_axis_tvalid(2)          <= s02_axis_tvalid;
  s_axis_tlast(2)           <= s02_axis_tlast;
  s_axis_tdata(2)           <= s02_axis_tdata;
  s_axis_tdest(2)           <= s02_axis_tdest;
  s_axis_tid(2)             <= s02_axis_tid;
  s02_axis_tready           <= s_axis_tready(2);
  s_axis_tvalid(3)          <= s03_axis_tvalid;
  s_axis_tlast(3)           <= s03_axis_tlast;
  s_axis_tdata(3)           <= s03_axis_tdata;
  s_axis_tdest(3)           <= s03_axis_tdest;
  s_axis_tid(3)             <= s03_axis_tid;
  s03_axis_tready           <= s_axis_tready(3);
  s_axis_tvalid(4)          <= s04_axis_tvalid;
  s_axis_tlast(4)           <= s04_axis_tlast;
  s_axis_tdata(4)           <= s04_axis_tdata;
  s_axis_tdest(4)           <= s04_axis_tdest;
  s_axis_tid(4)             <= s04_axis_tid;
  s04_axis_tready           <= s_axis_tready(4);
  s_axis_tvalid(5)          <= s05_axis_tvalid;
  s_axis_tlast(5)           <= s05_axis_tlast;
  s_axis_tdata(5)           <= s05_axis_tdata;
  s_axis_tdest(5)           <= s05_axis_tdest;
  s_axis_tid(5)             <= s05_axis_tid;
  s05_axis_tready           <= s_axis_tready(5);
  s_axis_tvalid(6)          <= s06_axis_tvalid;
  s_axis_tlast(6)           <= s06_axis_tlast;
  s_axis_tdata(6)           <= s06_axis_tdata;
  s_axis_tdest(6)           <= s06_axis_tdest;
  s_axis_tid(6)             <= s06_axis_tid;
  s06_axis_tready           <= s_axis_tready(6);
  s_axis_tvalid(7)          <= s07_axis_tvalid;
  s_axis_tlast(7)           <= s07_axis_tlast;
  s_axis_tdata(7)           <= s07_axis_tdata;
  s_axis_tdest(7)           <= s07_axis_tdest;
  s_axis_tid(7)             <= s07_axis_tid;
  s07_axis_tready           <= s_axis_tready(7);

  m00_axis_tvalid           <= m_axis_tvalid(0);
  m00_axis_tlast            <= m_axis_tlast(0);
  m00_axis_tdata            <= m_axis_tdata(0);
  m00_axis_tdest            <= m_axis_tdest(0);
  m00_axis_tid              <= m_axis_tid(0);
  m_axis_tready(0)          <= m00_axis_tready;
  m01_axis_tvalid           <= m_axis_tvalid(1);
  m01_axis_tlast            <= m_axis_tlast(1);
  m01_axis_tdata            <= m_axis_tdata(1);
  m01_axis_tdest            <= m_axis_tdest(1);
  m01_axis_tid              <= m_axis_tid(1);
  m_axis_tready(1)          <= m01_axis_tready;
  m02_axis_tvalid           <= m_axis_tvalid(2);
  m02_axis_tlast            <= m_axis_tlast(2);
  m02_axis_tdata            <= m_axis_tdata(2);
  m02_axis_tdest            <= m_axis_tdest(2);
  m02_axis_tid              <= m_axis_tid(2);
  m_axis_tready(2)          <= m02_axis_tready;
  m03_axis_tvalid           <= m_axis_tvalid(3);
  m03_axis_tlast            <= m_axis_tlast(3);
  m03_axis_tdata            <= m_axis_tdata(3);
  m03_axis_tdest            <= m_axis_tdest(3);
  m03_axis_tid              <= m_axis_tid(3);
  m_axis_tready(3)          <= m03_axis_tready;
  m04_axis_tvalid           <= m_axis_tvalid(4);
  m04_axis_tlast            <= m_axis_tlast(4);
  m04_axis_tdata            <= m_axis_tdata(4);
  m04_axis_tdest            <= m_axis_tdest(4);
  m04_axis_tid              <= m_axis_tid(4);
  m_axis_tready(4)          <= m04_axis_tready;
  m05_axis_tvalid           <= m_axis_tvalid(5);
  m05_axis_tlast            <= m_axis_tlast(5);
  m05_axis_tdata            <= m_axis_tdata(5);
  m05_axis_tdest            <= m_axis_tdest(5);
  m05_axis_tid              <= m_axis_tid(5);
  m_axis_tready(5)          <= m05_axis_tready;
  m06_axis_tvalid           <= m_axis_tvalid(6);
  m06_axis_tlast            <= m_axis_tlast(6);
  m06_axis_tdata            <= m_axis_tdata(6);
  m06_axis_tdest            <= m_axis_tdest(6);
  m06_axis_tid              <= m_axis_tid(6);
  m_axis_tready(6)          <= m06_axis_tready;
  m07_axis_tvalid           <= m_axis_tvalid(7);
  m07_axis_tlast            <= m_axis_tlast(7);
  m07_axis_tdata            <= m_axis_tdata(7);
  m07_axis_tdest            <= m_axis_tdest(7);
  m07_axis_tid              <= m_axis_tid(7);
  m_axis_tready(7)          <= m07_axis_tready;

end RTL;
