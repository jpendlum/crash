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
--  File: zc706.vhd
--  Author: Jonathon Pendlum (jon.pendlum@gmail.com)
--  Description: Toplevel file for ZC706.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library unisim;
use unisim.vcomponents.all;

entity zc706 is
  port (
    -- ARM Connections
    MIO                  : inout std_logic_vector(53 downto 0);
    PS_SRSTB             : in    std_logic;
    PS_CLK               : in    std_logic;
    PS_PORB              : in    std_logic;
    DDR_Clk              : inout std_logic;
    DDR_Clk_n            : inout std_logic;
    DDR_CKE              : inout std_logic;
    DDR_CS_n             : inout std_logic;
    DDR_RAS_n            : inout std_logic;
    DDR_CAS_n            : inout std_logic;
    DDR_WEB_pin          : out   std_logic;
    DDR_BankAddr         : inout std_logic_vector(2 downto 0);
    DDR_Addr             : inout std_logic_vector(14 downto 0);
    DDR_ODT              : inout std_logic;
    DDR_DRSTB            : inout std_logic;
    DDR_DQ               : inout std_logic_vector(31 downto 0);
    DDR_DM               : inout std_logic_vector(3 downto 0);
    DDR_DQS              : inout std_logic_vector(3 downto 0);
    DDR_DQS_n            : inout std_logic_vector(3 downto 0);
    DDR_VRP              : inout std_logic;
    DDR_VRN              : inout std_logic;
    -- USRP DDR Interface
    RX_DATA_CLK_N         : in    std_logic;
    RX_DATA_CLK_P         : in    std_logic;
    RX_DATA_N             : in    std_logic_vector(4 downto 0);
    RX_DATA_P             : in    std_logic_vector(4 downto 0);
    RX_DATA_STB_N         : in    std_logic;
    RX_DATA_STB_P         : in    std_logic;
    TX_DATA_N             : out   std_logic_vector(5 downto 0);
    TX_DATA_P             : out   std_logic_vector(5 downto 0);
    TX_DATA_STB_N         : out   std_logic;
    TX_DATA_STB_P         : out   std_logic;
    SPARE                 : out   std_logic_vector(4 downto 0);
    UART_TX               : out   std_logic);
end entity;

architecture RTL of zc706 is

  -------------------------------------------------------------------------------
  -- Component Declaration
  -------------------------------------------------------------------------------
  component zc706_ps is
    port (
      processing_system7_0_MIO                  : inout std_logic_vector(53 downto 0);
      processing_system7_0_PS_SRSTB_pin         : in    std_logic;
      processing_system7_0_PS_CLK_pin           : in    std_logic;
      processing_system7_0_PS_PORB_pin          : in    std_logic;
      processing_system7_0_DDR_Clk              : inout std_logic;
      processing_system7_0_DDR_Clk_n            : inout std_logic;
      processing_system7_0_DDR_CKE              : inout std_logic;
      processing_system7_0_DDR_CS_n             : inout std_logic;
      processing_system7_0_DDR_RAS_n            : inout std_logic;
      processing_system7_0_DDR_CAS_n            : inout std_logic;
      processing_system7_0_DDR_WEB_pin          : out   std_logic;
      processing_system7_0_DDR_BankAddr         : inout std_logic_vector(2 downto 0);
      processing_system7_0_DDR_Addr             : inout std_logic_vector(14 downto 0);
      processing_system7_0_DDR_ODT              : inout std_logic;
      processing_system7_0_DDR_DRSTB            : inout std_logic;
      processing_system7_0_DDR_DQ               : inout std_logic_vector(31 downto 0);
      processing_system7_0_DDR_DM               : inout std_logic_vector(3 downto 0);
      processing_system7_0_DDR_DQS              : inout std_logic_vector(3 downto 0);
      processing_system7_0_DDR_DQS_n            : inout std_logic_vector(3 downto 0);
      processing_system7_0_DDR_VRN              : inout std_logic;
      processing_system7_0_DDR_VRP              : inout std_logic;
      axi_ext_slave_conn_0_M_AXI_AWADDR_pin     : out   std_logic_vector(31 downto 0);
      axi_ext_slave_conn_0_M_AXI_AWVALID_pin    : out   std_logic;
      axi_ext_slave_conn_0_M_AXI_AWREADY_pin    : in    std_logic;
      axi_ext_slave_conn_0_M_AXI_WDATA_pin      : out   std_logic_vector(31 downto 0);
      axi_ext_slave_conn_0_M_AXI_WSTRB_pin      : out   std_logic_vector(3 downto 0);
      axi_ext_slave_conn_0_M_AXI_WVALID_pin     : out   std_logic;
      axi_ext_slave_conn_0_M_AXI_WREADY_pin     : in    std_logic;
      axi_ext_slave_conn_0_M_AXI_BRESP_pin      : in    std_logic_vector(1 downto 0);
      axi_ext_slave_conn_0_M_AXI_BVALID_pin     : in    std_logic;
      axi_ext_slave_conn_0_M_AXI_BREADY_pin     : out   std_logic;
      axi_ext_slave_conn_0_M_AXI_ARADDR_pin     : out   std_logic_vector(31 downto 0);
      axi_ext_slave_conn_0_M_AXI_ARVALID_pin    : out   std_logic;
      axi_ext_slave_conn_0_M_AXI_ARREADY_pin    : in    std_logic;
      axi_ext_slave_conn_0_M_AXI_RDATA_pin      : in    std_logic_vector(31 downto 0);
      axi_ext_slave_conn_0_M_AXI_RRESP_pin      : in    std_logic_vector(1 downto 0);
      axi_ext_slave_conn_0_M_AXI_RVALID_pin     : in    std_logic;
      axi_ext_slave_conn_0_M_AXI_RREADY_pin     : out   std_logic;
      processing_system7_0_IRQ_F2P_pin          : in    std_logic_vector(15 downto 0);
      processing_system7_0_FCLK_CLK0_pin        : out   std_logic;
      processing_system7_0_FCLK_RESET0_N_pin    : out   std_logic;
      axi_ext_master_conn_0_S_AXI_AWADDR_pin    : in    std_logic_vector(31 downto 0);
      axi_ext_master_conn_0_S_AXI_AWLEN_pin     : in    std_logic_vector(7 downto 0);
      axi_ext_master_conn_0_S_AXI_AWSIZE_pin    : in    std_logic_vector(2 downto 0);
      axi_ext_master_conn_0_S_AXI_AWBURST_pin   : in    std_logic_vector(1 downto 0);
      axi_ext_master_conn_0_S_AXI_AWCACHE_pin   : in    std_logic_vector(3 downto 0);
      axi_ext_master_conn_0_S_AXI_AWPROT_pin    : in    std_logic_vector(2 downto 0);
      axi_ext_master_conn_0_S_AXI_AWVALID_pin   : in    std_logic;
      axi_ext_master_conn_0_S_AXI_AWREADY_pin   : out   std_logic;
      axi_ext_master_conn_0_S_AXI_WDATA_pin     : in    std_logic_vector(63 downto 0);
      axi_ext_master_conn_0_S_AXI_WSTRB_pin     : in    std_logic_vector(7 downto 0);
      axi_ext_master_conn_0_S_AXI_WLAST_pin     : in    std_logic;
      axi_ext_master_conn_0_S_AXI_WVALID_pin    : in    std_logic;
      axi_ext_master_conn_0_S_AXI_WREADY_pin    : out   std_logic;
      axi_ext_master_conn_0_S_AXI_BRESP_pin     : out   std_logic_vector(1 downto 0);
      axi_ext_master_conn_0_S_AXI_BVALID_pin    : out   std_logic;
      axi_ext_master_conn_0_S_AXI_BREADY_pin    : in    std_logic;
      axi_ext_master_conn_0_S_AXI_ARADDR_pin    : in    std_logic_vector(31 downto 0);
      axi_ext_master_conn_0_S_AXI_ARLEN_pin     : in    std_logic_vector(7 downto 0);
      axi_ext_master_conn_0_S_AXI_ARSIZE_pin    : in    std_logic_vector(2 downto 0);
      axi_ext_master_conn_0_S_AXI_ARBURST_pin   : in    std_logic_vector(1 downto 0);
      axi_ext_master_conn_0_S_AXI_ARCACHE_pin   : in    std_logic_vector(3 downto 0);
      axi_ext_master_conn_0_S_AXI_ARPROT_pin    : in    std_logic_vector(2 downto 0);
      axi_ext_master_conn_0_S_AXI_ARVALID_pin   : in    std_logic;
      axi_ext_master_conn_0_S_AXI_ARREADY_pin   : out   std_logic;
      axi_ext_master_conn_0_S_AXI_RDATA_pin     : out   std_logic_vector(63 downto 0);
      axi_ext_master_conn_0_S_AXI_RRESP_pin     : out   std_logic_vector(1 downto 0);
      axi_ext_master_conn_0_S_AXI_RLAST_pin     : out   std_logic;
      axi_ext_master_conn_0_S_AXI_RVALID_pin    : out   std_logic;
      axi_ext_master_conn_0_S_AXI_RREADY_pin    : in    std_logic;
      axi_ext_master_conn_0_S_AXI_AWUSER_pin    : in    std_logic_vector(4 downto 0);
      axi_ext_master_conn_0_S_AXI_ARUSER_pin    : in    std_logic_vector(4 downto 0));
  end component;

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
      RX_DATA_N                   : in    std_logic_vector(4 downto 0);   -- Receive data (N)
      RX_DATA_P                   : in    std_logic_vector(4 downto 0);   -- Receive data (P)
      RX_DATA_STB_N               : in    std_logic;                      -- Receive data strobe (N)
      RX_DATA_STB_P               : in    std_logic;                      -- Receive data strobe (P)
      TX_DATA_N                   : out   std_logic_vector(5 downto 0);   -- Transmit data (N)
      TX_DATA_P                   : out   std_logic_vector(5 downto 0);   -- Transmit data (P)
      TX_DATA_STB_N               : out   std_logic;                      -- Transmit data strobe (N)
      TX_DATA_STB_P               : out   std_logic;                      -- Transmit data strobe (P)
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

  -----------------------------------------------------------------------------
  -- Signals Declaration
  -----------------------------------------------------------------------------
  signal clk                              : std_logic;
  signal rst_n                            : std_logic;

  signal S_AXI_AWADDR                     : std_logic_vector(31 downto 0);
  signal S_AXI_AWVALID                    : std_logic;
  signal S_AXI_AWREADY                    : std_logic;
  signal S_AXI_WDATA                      : std_logic_vector(31 downto 0);
  signal S_AXI_WSTRB                      : std_logic_vector(3 downto 0);
  signal S_AXI_WVALID                     : std_logic;
  signal S_AXI_WREADY                     : std_logic;
  signal S_AXI_BRESP                      : std_logic_vector(1 downto 0);
  signal S_AXI_BVALID                     : std_logic;
  signal S_AXI_BREADY                     : std_logic;
  signal S_AXI_ARADDR                     : std_logic_vector(31 downto 0);
  signal S_AXI_ARVALID                    : std_logic;
  signal S_AXI_ARREADY                    : std_logic;
  signal S_AXI_RDATA                      : std_logic_vector(31 downto 0);
  signal S_AXI_RRESP                      : std_logic_vector(1 downto 0);
  signal S_AXI_RVALID                     : std_logic;
  signal S_AXI_RREADY                     : std_logic;
  signal M_AXI_AWADDR                     : std_logic_vector(31 downto 0);
  signal M_AXI_AWPROT                     : std_logic_vector(2 downto 0);
  signal M_AXI_AWVALID                    : std_logic;
  signal M_AXI_AWREADY                    : std_logic;
  signal M_AXI_WDATA                      : std_logic_vector(63 downto 0);
  signal M_AXI_WSTRB                      : std_logic_vector(7 downto 0);
  signal M_AXI_WVALID                     : std_logic;
  signal M_AXI_WREADY                     : std_logic;
  signal M_AXI_BRESP                      : std_logic_vector(1 downto 0);
  signal M_AXI_BVALID                     : std_logic;
  signal M_AXI_BREADY                     : std_logic;
  signal M_AXI_AWLEN                      : std_logic_vector(7 downto 0);
  signal M_AXI_AWSIZE                     : std_logic_vector(2 downto 0);
  signal M_AXI_AWBURST                    : std_logic_vector(1 downto 0);
  signal M_AXI_AWCACHE                    : std_logic_vector(3 downto 0);
  signal M_AXI_AWUSER                     : std_logic_vector(4 downto 0);
  signal M_AXI_WLAST                      : std_logic;
  signal M_AXI_ARADDR                     : std_logic_vector(31 downto 0);
  signal M_AXI_ARPROT                     : std_logic_vector(2 downto 0);
  signal M_AXI_ARVALID                    : std_logic;
  signal M_AXI_ARREADY                    : std_logic;
  signal M_AXI_RDATA                      : std_logic_vector(63 downto 0);
  signal M_AXI_RRESP                      : std_logic_vector(1 downto 0);
  signal M_AXI_RVALID                     : std_logic;
  signal M_AXI_RREADY                     : std_logic;
  signal M_AXI_RLAST                      : std_logic;
  signal M_AXI_ARCACHE                    : std_logic_vector(3 downto 0);
  signal M_AXI_ARUSER                     : std_logic_vector(4 downto 0);
  signal M_AXI_ARLEN                      : std_logic_vector(7 downto 0);
  signal M_AXI_ARBURST                    : std_logic_vector(1 downto 0);
  signal M_AXI_ARSIZE                     : std_logic_vector(2 downto 0);
  signal processing_system7_0_IRQ_F2P_pin : std_logic_vector(15 downto 0);
  signal irq                              : std_logic;
  signal rst_glb_n                        : std_logic;
  signal axis_master_1_tvalid             : std_logic;
  signal axis_master_1_tready             : std_logic;
  signal axis_master_1_tdata              : std_logic_vector(63 downto 0);
  signal axis_master_1_tdest              : std_logic_vector(2 downto 0);
  signal axis_master_1_tlast              : std_logic;
  signal axis_master_1_irq                : std_logic;
  signal axis_slave_1_tvalid              : std_logic;
  signal axis_slave_1_tready              : std_logic;
  signal axis_slave_1_tdata               : std_logic_vector(63 downto 0);
  signal axis_slave_1_tid                 : std_logic_vector(2 downto 0);
  signal axis_slave_1_tlast               : std_logic;
  signal axis_slave_1_irq                 : std_logic;
  signal status_1_addr                    : std_logic_vector(7 downto 0);
  signal status_1_data                    : std_logic_vector(31 downto 0);
  signal status_1_stb                     : std_logic;
  signal ctrl_1_addr                      : std_logic_vector(7 downto 0);
  signal ctrl_1_data                      : std_logic_vector(31 downto 0);
  signal ctrl_1_stb                       : std_logic;
  signal axis_master_2_tvalid             : std_logic;
  signal axis_master_2_tready             : std_logic;
  signal axis_master_2_tdata              : std_logic_vector(63 downto 0);
  signal axis_master_2_tdest              : std_logic_vector(2 downto 0);
  signal axis_master_2_tlast              : std_logic;
  signal axis_master_2_irq                : std_logic;
  signal axis_slave_2_tvalid              : std_logic;
  signal axis_slave_2_tready              : std_logic;
  signal axis_slave_2_tdata               : std_logic_vector(63 downto 0);
  signal axis_slave_2_tid                 : std_logic_vector(2 downto 0);
  signal axis_slave_2_tlast               : std_logic;
  signal axis_slave_2_irq                 : std_logic;
  signal status_2_addr                    : std_logic_vector(7 downto 0);
  signal status_2_data                    : std_logic_vector(31 downto 0);
  signal status_2_stb                     : std_logic;
  signal ctrl_2_addr                      : std_logic_vector(7 downto 0);
  signal ctrl_2_data                      : std_logic_vector(31 downto 0);
  signal ctrl_2_stb                       : std_logic;
  signal axis_master_3_tvalid             : std_logic;
  signal axis_master_3_tready             : std_logic;
  signal axis_master_3_tdata              : std_logic_vector(63 downto 0);
  signal axis_master_3_tdest              : std_logic_vector(2 downto 0);
  signal axis_master_3_tlast              : std_logic;
  signal axis_master_3_irq                : std_logic;
  signal axis_slave_3_tvalid              : std_logic;
  signal axis_slave_3_tready              : std_logic;
  signal axis_slave_3_tdata               : std_logic_vector(63 downto 0);
  signal axis_slave_3_tid                 : std_logic_vector(2 downto 0);
  signal axis_slave_3_tlast               : std_logic;
  signal axis_slave_3_irq                 : std_logic;
  signal status_3_addr                    : std_logic_vector(7 downto 0);
  signal status_3_data                    : std_logic_vector(31 downto 0);
  signal status_3_stb                     : std_logic;
  signal ctrl_3_addr                      : std_logic_vector(7 downto 0);
  signal ctrl_3_data                      : std_logic_vector(31 downto 0);
  signal ctrl_3_stb                       : std_logic;
  signal axis_master_4_tvalid             : std_logic;
  signal axis_master_4_tready             : std_logic;
  signal axis_master_4_tdata              : std_logic_vector(63 downto 0);
  signal axis_master_4_tdest              : std_logic_vector(2 downto 0);
  signal axis_master_4_tlast              : std_logic;
  signal axis_master_4_irq                : std_logic;
  signal axis_slave_4_tvalid              : std_logic;
  signal axis_slave_4_tready              : std_logic;
  signal axis_slave_4_tdata               : std_logic_vector(63 downto 0);
  signal axis_slave_4_tid                 : std_logic_vector(2 downto 0);
  signal axis_slave_4_tlast               : std_logic;
  signal axis_slave_4_irq                 : std_logic;
  signal status_4_addr                    : std_logic_vector(7 downto 0);
  signal status_4_data                    : std_logic_vector(31 downto 0);
  signal status_4_stb                     : std_logic;
  signal ctrl_4_addr                      : std_logic_vector(7 downto 0);
  signal ctrl_4_data                      : std_logic_vector(31 downto 0);
  signal ctrl_4_stb                       : std_logic;
  signal axis_master_5_tvalid             : std_logic;
  signal axis_master_5_tready             : std_logic;
  signal axis_master_5_tdata              : std_logic_vector(63 downto 0);
  signal axis_master_5_tdest              : std_logic_vector(2 downto 0);
  signal axis_master_5_tlast              : std_logic;
  signal axis_master_5_irq                : std_logic;
  signal axis_slave_5_tvalid              : std_logic;
  signal axis_slave_5_tready              : std_logic;
  signal axis_slave_5_tdata               : std_logic_vector(63 downto 0);
  signal axis_slave_5_tid                 : std_logic_vector(2 downto 0);
  signal axis_slave_5_tlast               : std_logic;
  signal axis_slave_5_irq                 : std_logic;
  signal status_5_addr                    : std_logic_vector(7 downto 0);
  signal status_5_data                    : std_logic_vector(31 downto 0);
  signal status_5_stb                     : std_logic;
  signal ctrl_5_addr                      : std_logic_vector(7 downto 0);
  signal ctrl_5_data                      : std_logic_vector(31 downto 0);
  signal ctrl_5_stb                       : std_logic;
  signal axis_master_6_tvalid             : std_logic;
  signal axis_master_6_tready             : std_logic;
  signal axis_master_6_tdata              : std_logic_vector(63 downto 0);
  signal axis_master_6_tdest              : std_logic_vector(2 downto 0);
  signal axis_master_6_tlast              : std_logic;
  signal axis_master_6_irq                : std_logic;
  signal axis_slave_6_tvalid              : std_logic;
  signal axis_slave_6_tready              : std_logic;
  signal axis_slave_6_tdata               : std_logic_vector(63 downto 0);
  signal axis_slave_6_tid                 : std_logic_vector(2 downto 0);
  signal axis_slave_6_tlast               : std_logic;
  signal axis_slave_6_irq                 : std_logic;
  signal status_6_addr                    : std_logic_vector(7 downto 0);
  signal status_6_data                    : std_logic_vector(31 downto 0);
  signal status_6_stb                     : std_logic;
  signal ctrl_6_addr                      : std_logic_vector(7 downto 0);
  signal ctrl_6_data                      : std_logic_vector(31 downto 0);
  signal ctrl_6_stb                       : std_logic;
  signal axis_master_7_tvalid             : std_logic;
  signal axis_master_7_tready             : std_logic;
  signal axis_master_7_tdata              : std_logic_vector(63 downto 0);
  signal axis_master_7_tdest              : std_logic_vector(2 downto 0);
  signal axis_master_7_tlast              : std_logic;
  signal axis_master_7_irq                : std_logic;
  signal axis_slave_7_tvalid              : std_logic;
  signal axis_slave_7_tready              : std_logic;
  signal axis_slave_7_tdata               : std_logic_vector(63 downto 0);
  signal axis_slave_7_tid                 : std_logic_vector(2 downto 0);
  signal axis_slave_7_tlast               : std_logic;
  signal axis_slave_7_irq                 : std_logic;
  signal status_7_addr                    : std_logic_vector(7 downto 0);
  signal status_7_data                    : std_logic_vector(31 downto 0);
  signal status_7_stb                     : std_logic;
  signal ctrl_7_addr                      : std_logic_vector(7 downto 0);
  signal ctrl_7_data                      : std_logic_vector(31 downto 0);
  signal ctrl_7_stb                       : std_logic;

  signal rx_enable_aux                    : std_logic;
  signal tx_enable_aux                    : std_logic;
  signal threshold_not_exceeded           : std_logic;
  signal threshold_not_exceeded_stb       : std_logic;
  signal threshold_exceeded               : std_logic;
  signal threshold_exceeded_stb           : std_logic;
  signal trigger_stb                      : std_logic;

begin

  inst_zc706_ps : zc706_ps
    port map (
      processing_system7_0_MIO                  => MIO,
      processing_system7_0_PS_SRSTB_pin         => PS_SRSTB,
      processing_system7_0_PS_CLK_pin           => PS_CLK,
      processing_system7_0_PS_PORB_pin          => PS_PORB,
      processing_system7_0_DDR_Clk              => DDR_Clk,
      processing_system7_0_DDR_Clk_n            => DDR_Clk_n,
      processing_system7_0_DDR_CKE              => DDR_CKE,
      processing_system7_0_DDR_CS_n             => DDR_CS_n,
      processing_system7_0_DDR_RAS_n            => DDR_RAS_n,
      processing_system7_0_DDR_CAS_n            => DDR_CAS_n,
      processing_system7_0_DDR_WEB_pin          => DDR_WEB_pin,
      processing_system7_0_DDR_BankAddr         => DDR_BankAddr,
      processing_system7_0_DDR_Addr             => DDR_Addr,
      processing_system7_0_DDR_ODT              => DDR_ODT,
      processing_system7_0_DDR_DRSTB            => DDR_DRSTB,
      processing_system7_0_DDR_DQ               => DDR_DQ,
      processing_system7_0_DDR_DM               => DDR_DM,
      processing_system7_0_DDR_DQS              => DDR_DQS,
      processing_system7_0_DDR_DQS_n            => DDR_DQS_n,
      processing_system7_0_DDR_VRN              => DDR_VRN,
      processing_system7_0_DDR_VRP              => DDR_VRP,
      axi_ext_slave_conn_0_M_AXI_AWADDR_pin     => S_AXI_AWADDR,
      axi_ext_slave_conn_0_M_AXI_AWVALID_pin    => S_AXI_AWVALID,
      axi_ext_slave_conn_0_M_AXI_AWREADY_pin    => S_AXI_AWREADY,
      axi_ext_slave_conn_0_M_AXI_WDATA_pin      => S_AXI_WDATA,
      axi_ext_slave_conn_0_M_AXI_WSTRB_pin      => S_AXI_WSTRB,
      axi_ext_slave_conn_0_M_AXI_WVALID_pin     => S_AXI_WVALID,
      axi_ext_slave_conn_0_M_AXI_WREADY_pin     => S_AXI_WREADY,
      axi_ext_slave_conn_0_M_AXI_BRESP_pin      => S_AXI_BRESP,
      axi_ext_slave_conn_0_M_AXI_BVALID_pin     => S_AXI_BVALID,
      axi_ext_slave_conn_0_M_AXI_BREADY_pin     => S_AXI_BREADY,
      axi_ext_slave_conn_0_M_AXI_ARADDR_pin     => S_AXI_ARADDR,
      axi_ext_slave_conn_0_M_AXI_ARVALID_pin    => S_AXI_ARVALID,
      axi_ext_slave_conn_0_M_AXI_ARREADY_pin    => S_AXI_ARREADY,
      axi_ext_slave_conn_0_M_AXI_RDATA_pin      => S_AXI_RDATA,
      axi_ext_slave_conn_0_M_AXI_RRESP_pin      => S_AXI_RRESP,
      axi_ext_slave_conn_0_M_AXI_RVALID_pin     => S_AXI_RVALID,
      axi_ext_slave_conn_0_M_AXI_RREADY_pin     => S_AXI_RREADY,
      processing_system7_0_IRQ_F2P_pin          => processing_system7_0_IRQ_F2P_pin,
      processing_system7_0_FCLK_CLK0_pin        => clk,
      processing_system7_0_FCLK_RESET0_N_pin    => rst_n,
      axi_ext_master_conn_0_S_AXI_AWADDR_pin    => M_AXI_AWADDR,
      axi_ext_master_conn_0_S_AXI_AWLEN_pin     => M_AXI_AWLEN,
      axi_ext_master_conn_0_S_AXI_AWSIZE_pin    => M_AXI_AWSIZE,
      axi_ext_master_conn_0_S_AXI_AWBURST_pin   => M_AXI_AWBURST,
      axi_ext_master_conn_0_S_AXI_AWCACHE_pin   => M_AXI_AWCACHE,
      axi_ext_master_conn_0_S_AXI_AWPROT_pin    => M_AXI_AWPROT,
      axi_ext_master_conn_0_S_AXI_AWVALID_pin   => M_AXI_AWVALID,
      axi_ext_master_conn_0_S_AXI_AWREADY_pin   => M_AXI_AWREADY,
      axi_ext_master_conn_0_S_AXI_WDATA_pin     => M_AXI_WDATA,
      axi_ext_master_conn_0_S_AXI_WSTRB_pin     => M_AXI_WSTRB,
      axi_ext_master_conn_0_S_AXI_WLAST_pin     => M_AXI_WLAST,
      axi_ext_master_conn_0_S_AXI_WVALID_pin    => M_AXI_WVALID,
      axi_ext_master_conn_0_S_AXI_WREADY_pin    => M_AXI_WREADY,
      axi_ext_master_conn_0_S_AXI_BRESP_pin     => M_AXI_BRESP,
      axi_ext_master_conn_0_S_AXI_BVALID_pin    => M_AXI_BVALID,
      axi_ext_master_conn_0_S_AXI_BREADY_pin    => M_AXI_BREADY,
      axi_ext_master_conn_0_S_AXI_ARADDR_pin    => M_AXI_ARADDR,
      axi_ext_master_conn_0_S_AXI_ARLEN_pin     => M_AXI_ARLEN,
      axi_ext_master_conn_0_S_AXI_ARSIZE_pin    => M_AXI_ARSIZE,
      axi_ext_master_conn_0_S_AXI_ARBURST_pin   => M_AXI_ARBURST,
      axi_ext_master_conn_0_S_AXI_ARCACHE_pin   => M_AXI_ARCACHE,
      axi_ext_master_conn_0_S_AXI_ARPROT_pin    => M_AXI_ARPROT,
      axi_ext_master_conn_0_S_AXI_ARVALID_pin   => M_AXI_ARVALID,
      axi_ext_master_conn_0_S_AXI_ARREADY_pin   => M_AXI_ARREADY,
      axi_ext_master_conn_0_S_AXI_RDATA_pin     => M_AXI_RDATA,
      axi_ext_master_conn_0_S_AXI_RRESP_pin     => M_AXI_RRESP,
      axi_ext_master_conn_0_S_AXI_RLAST_pin     => M_AXI_RLAST,
      axi_ext_master_conn_0_S_AXI_RVALID_pin    => M_AXI_RVALID,
      axi_ext_master_conn_0_S_AXI_RREADY_pin    => M_AXI_RREADY,
      axi_ext_master_conn_0_S_AXI_AWUSER_pin    => M_AXI_AWUSER,
      axi_ext_master_conn_0_S_AXI_ARUSER_pin    => M_AXI_ARUSER);

  processing_system7_0_IRQ_F2P_pin(15)          <= irq;

  inst_ps_pl_interface : ps_pl_interface
    generic map (
      C_BASEADDR                                => x"40000000",
      C_HIGHADDR                                => x"4001ffff")
    port map (
      clk                                       => clk,
      rst_n                                     => rst_n,
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
      BAUD                                      => 1e6)
    port map (
      UART_TX                                   => UART_TX,
      RX_DATA_CLK_N                             => RX_DATA_CLK_N,
      RX_DATA_CLK_P                             => RX_DATA_CLK_P,
      RX_DATA_N                                 => RX_DATA_N,
      RX_DATA_P                                 => RX_DATA_P,
      RX_DATA_STB_N                             => RX_DATA_STB_N,
      RX_DATA_STB_P                             => RX_DATA_STB_P,
      TX_DATA_N                                 => TX_DATA_N,
      TX_DATA_P                                 => TX_DATA_P,
      TX_DATA_STB_N                             => TX_DATA_STB_N,
      TX_DATA_STB_P                             => TX_DATA_STB_P,
      clk                                       => clk,
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
      clk                                       => clk,
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

  -- Unused Accelerators
  axis_slave_3_tready                           <= '0';
  axis_slave_3_irq                              <= '0';
  axis_master_3_tvalid                          <= '0';
  axis_master_3_tdata                           <= x"0000000000000000";
  axis_master_3_tdest                           <= "000";
  axis_master_3_tlast                           <= '0';
  axis_master_3_irq                             <= '0';
  status_3_data                                 <= x"00000000";
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

  SPARE                                         <= (others=>'Z');

end architecture;