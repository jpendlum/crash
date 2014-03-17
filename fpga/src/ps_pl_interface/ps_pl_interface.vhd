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
--  File: ps_pl_interface.vhd
--  Author: Jonathon Pendlum (jon.pendlum@gmail.com)
--  Description: Interfaces the Processing System (PS) with the
--               Programmable Logic (PL) via the AXI ACP bus and
--               an AXI Datamover IP core. Includes a AXI-Stream 8x8
--               interconnect.
--
--               The destination of each interface matches its enumeration,
--               i.e. slave 1's tdest = "001". The master transfers data to
--               a slave by setting tdest and then asserting tvalid. Each
--               slave port arbitrates when tlast is asserted.
--
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ps_pl_interface is
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
end entity;

architecture RTL of ps_pl_interface is

  -------------------------------------------------------------------------------
  -- Component Declaration
  -------------------------------------------------------------------------------
  component axi_lite_to_parallel_bus is
    generic (
      -- 32K word address space
      C_BASEADDR                    : std_logic_vector(31 downto 0) := x"40000000";
      C_HIGHADDR                    : std_logic_vector(31 downto 0) := x"4001ffff");
    port (
      S_AXI_ACLK                    : in    std_logic;
      S_AXI_ARESETN                 : in    std_logic;
      S_AXI_ARADDR                  : in    std_logic_vector(31 downto 0);
      S_AXI_ARVALID                 : in    std_logic;
      S_AXI_ARREADY                 : out   std_logic;
      S_AXI_RDATA                   : out   std_logic_vector(31 downto 0);
      S_AXI_RRESP                   : out   std_logic_vector(1 downto 0);
      S_AXI_RVALID                  : out   std_logic;
      S_AXI_RREADY                  : in    std_logic;
      S_AXI_AWADDR                  : in    std_logic_vector(31 downto 0);
      S_AXI_AWVALID                 : in    std_logic;
      S_AXI_AWREADY                 : out   std_logic;
      S_AXI_WDATA                   : in    std_logic_vector(31 downto 0);
      S_AXI_WSTRB                   : in    std_logic_vector(3 downto 0);
      S_AXI_WVALID                  : in    std_logic;
      S_AXI_WREADY                  : out   std_logic;
      S_AXI_BRESP                   : out   std_logic_vector(1 downto 0);
      S_AXI_BVALID                  : out   std_logic;
      S_AXI_BREADY                  : in    std_logic;
      read_addr                     : out   std_logic_vector(14 downto 0);
      read_data                     : in    std_logic_vector(31 downto 0);
      read_stb                      : out   std_logic;
      write_addr                    : out   std_logic_vector(14 downto 0);
      write_data                    : out   std_logic_vector(31 downto 0);
      write_stb                     : out   std_logic);
  end component;

  component xlnx_axi_datamover is
    port (
      m_axi_mm2s_aclk               : in    std_logic;
      m_axi_mm2s_aresetn            : in    std_logic;
      mm2s_halt                     : in    std_logic;
      mm2s_halt_cmplt               : out   std_logic;
      mm2s_err                      : out   std_logic;
      m_axis_mm2s_cmdsts_aclk       : in    std_logic;
      m_axis_mm2s_cmdsts_aresetn    : in    std_logic;
      s_axis_mm2s_cmd_tvalid        : in    std_logic;
      s_axis_mm2s_cmd_tready        : out   std_logic;
      s_axis_mm2s_cmd_tdata         : in    std_logic_vector(71 downto 0);
      m_axis_mm2s_sts_tvalid        : out   std_logic;
      m_axis_mm2s_sts_tready        : in    std_logic;
      m_axis_mm2s_sts_tdata         : out   std_logic_vector(7 downto 0);
      m_axis_mm2s_sts_tkeep         : out   std_logic_vector(0 downto 0);
      m_axis_mm2s_sts_tlast         : out   std_logic;
      mm2s_allow_addr_req           : in    std_logic;
      mm2s_addr_req_posted          : out   std_logic;
      mm2s_rd_xfer_cmplt            : out   std_logic;
      m_axi_mm2s_arid               : out   std_logic_vector(3 downto 0);
      m_axi_mm2s_araddr             : out   std_logic_vector(31 downto 0);
      m_axi_mm2s_arlen              : out   std_logic_vector(7 downto 0);
      m_axi_mm2s_arsize             : out   std_logic_vector(2 downto 0);
      m_axi_mm2s_arburst            : out   std_logic_vector(1 downto 0);
      m_axi_mm2s_arprot             : out   std_logic_vector(2 downto 0);
      m_axi_mm2s_arcache            : out   std_logic_vector(3 downto 0);
      m_axi_mm2s_arvalid            : out   std_logic;
      m_axi_mm2s_arready            : in    std_logic;
      m_axi_mm2s_rdata              : in    std_logic_vector(63 downto 0);
      m_axi_mm2s_rresp              : in    std_logic_vector(1 downto 0);
      m_axi_mm2s_rlast              : in    std_logic;
      m_axi_mm2s_rvalid             : in    std_logic;
      m_axi_mm2s_rready             : out   std_logic;
      m_axis_mm2s_tdata             : out   std_logic_vector(63 downto 0);
      m_axis_mm2s_tkeep             : out   std_logic_vector(7 downto 0);
      m_axis_mm2s_tlast             : out   std_logic;
      m_axis_mm2s_tvalid            : out   std_logic;
      m_axis_mm2s_tready            : in    std_logic;
      mm2s_dbg_sel                  : in    std_logic_vector( 3 downto 0);
      mm2s_dbg_data                 : out   std_logic_vector(31 downto 0) ;
      m_axi_s2mm_aclk               : in    std_logic;
      m_axi_s2mm_aresetn            : in    std_logic;
      s2mm_halt                     : in    std_logic;
      s2mm_halt_cmplt               : out   std_logic;
      s2mm_err                      : out   std_logic;
      m_axis_s2mm_cmdsts_awclk      : in    std_logic;
      m_axis_s2mm_cmdsts_aresetn    : in    std_logic;
      s_axis_s2mm_cmd_tvalid        : in    std_logic;
      s_axis_s2mm_cmd_tready        : out   std_logic;
      s_axis_s2mm_cmd_tdata         : in    std_logic_vector(71 downto 0);
      m_axis_s2mm_sts_tvalid        : out   std_logic;
      m_axis_s2mm_sts_tready        : in    std_logic;
      m_axis_s2mm_sts_tdata         : out   std_logic_vector(7 downto 0);
      m_axis_s2mm_sts_tkeep         : out   std_logic_vector(0 downto 0);
      m_axis_s2mm_sts_tlast         : out   std_logic;
      s2mm_allow_addr_req           : in    std_logic;
      s2mm_addr_req_posted          : out   std_logic;
      s2mm_wr_xfer_cmplt            : out   std_logic;
      s2mm_ld_nxt_len               : out   std_logic;
      s2mm_wr_len                   : out   std_logic_vector(7 downto 0);
      m_axi_s2mm_awid               : out   std_logic_vector(3 downto 0);
      m_axi_s2mm_awaddr             : out   std_logic_vector(31 downto 0);
      m_axi_s2mm_awlen              : out   std_logic_vector(7 downto 0);
      m_axi_s2mm_awsize             : out   std_logic_vector(2 downto 0);
      m_axi_s2mm_awburst            : out   std_logic_vector(1 downto 0);
      m_axi_s2mm_awprot             : out   std_logic_vector(2 downto 0);
      m_axi_s2mm_awcache            : out   std_logic_vector(3 downto 0);
      m_axi_s2mm_awvalid            : out   std_logic;
      m_axi_s2mm_awready            : in    std_logic;
      m_axi_s2mm_wdata              : out   std_logic_vector(63 downto 0);
      m_axi_s2mm_wstrb              : out   std_logic_vector(7 downto 0);
      m_axi_s2mm_wlast              : out   std_logic;
      m_axi_s2mm_wvalid             : out   std_logic;
      m_axi_s2mm_wready             : in    std_logic;
      m_axi_s2mm_bresp              : in    std_logic_vector(1 downto 0);
      m_axi_s2mm_bvalid             : in    std_logic;
      m_axi_s2mm_bready             : out   std_logic;
      s_axis_s2mm_tdata             : in    std_logic_vector(63 downto 0);
      s_axis_s2mm_tkeep             : in    std_logic_vector(7 downto 0);
      s_axis_s2mm_tlast             : in    std_logic;
      s_axis_s2mm_tvalid            : in    std_logic;
      s_axis_s2mm_tready            : out   std_logic;
      s2mm_dbg_sel                  : in    std_logic_vector( 3 downto 0);
      s2mm_dbg_data                 : out   std_logic_vector(31 downto 0));
  end component;

  component fifo_72x64
    port (
      clk                           : in    std_logic;
      rst                           : in    std_logic;
      din                           : in    std_logic_vector(71 downto 0);
      wr_en                         : in    std_logic;
      rd_en                         : in    std_logic;
      dout                          : out   std_logic_vector(71 downto 0);
      full                          : out   std_logic;
      empty                         : out   std_logic);
  end component;

  component fifo_8x64
    port (
      clk                           : in    std_logic;
      rst                           : in    std_logic;
      din                           : in    std_logic_vector(7 downto 0);
      wr_en                         : in    std_logic;
      rd_en                         : in    std_logic;
      dout                          : out   std_logic_vector(7 downto 0);
      full                          : out   std_logic;
      empty                         : out   std_logic);
  end component;

  component axis_interconnect_8x8
    port (
      aclk                          : in    std_logic;
      aresetn                       : in    std_logic;
      s00_axis_aclk                 : in    std_logic;
      s01_axis_aclk                 : in    std_logic;
      s02_axis_aclk                 : in    std_logic;
      s03_axis_aclk                 : in    std_logic;
      s04_axis_aclk                 : in    std_logic;
      s05_axis_aclk                 : in    std_logic;
      s06_axis_aclk                 : in    std_logic;
      s07_axis_aclk                 : in    std_logic;
      s00_axis_aresetn              : in    std_logic;
      s01_axis_aresetn              : in    std_logic;
      s02_axis_aresetn              : in    std_logic;
      s03_axis_aresetn              : in    std_logic;
      s04_axis_aresetn              : in    std_logic;
      s05_axis_aresetn              : in    std_logic;
      s06_axis_aresetn              : in    std_logic;
      s07_axis_aresetn              : in    std_logic;
      s00_axis_tvalid               : in    std_logic;
      s01_axis_tvalid               : in    std_logic;
      s02_axis_tvalid               : in    std_logic;
      s03_axis_tvalid               : in    std_logic;
      s04_axis_tvalid               : in    std_logic;
      s05_axis_tvalid               : in    std_logic;
      s06_axis_tvalid               : in    std_logic;
      s07_axis_tvalid               : in    std_logic;
      s00_axis_tready               : out   std_logic;
      s01_axis_tready               : out   std_logic;
      s02_axis_tready               : out   std_logic;
      s03_axis_tready               : out   std_logic;
      s04_axis_tready               : out   std_logic;
      s05_axis_tready               : out   std_logic;
      s06_axis_tready               : out   std_logic;
      s07_axis_tready               : out   std_logic;
      s00_axis_tdata                : in    std_logic_vector(63 downto 0);
      s01_axis_tdata                : in    std_logic_vector(63 downto 0);
      s02_axis_tdata                : in    std_logic_vector(63 downto 0);
      s03_axis_tdata                : in    std_logic_vector(63 downto 0);
      s04_axis_tdata                : in    std_logic_vector(63 downto 0);
      s05_axis_tdata                : in    std_logic_vector(63 downto 0);
      s06_axis_tdata                : in    std_logic_vector(63 downto 0);
      s07_axis_tdata                : in    std_logic_vector(63 downto 0);
      s00_axis_tlast                : in    std_logic;
      s01_axis_tlast                : in    std_logic;
      s02_axis_tlast                : in    std_logic;
      s03_axis_tlast                : in    std_logic;
      s04_axis_tlast                : in    std_logic;
      s05_axis_tlast                : in    std_logic;
      s06_axis_tlast                : in    std_logic;
      s07_axis_tlast                : in    std_logic;
      s00_axis_tdest                : in    std_logic_vector(2 downto 0);
      s01_axis_tdest                : in    std_logic_vector(2 downto 0);
      s02_axis_tdest                : in    std_logic_vector(2 downto 0);
      s03_axis_tdest                : in    std_logic_vector(2 downto 0);
      s04_axis_tdest                : in    std_logic_vector(2 downto 0);
      s05_axis_tdest                : in    std_logic_vector(2 downto 0);
      s06_axis_tdest                : in    std_logic_vector(2 downto 0);
      s07_axis_tdest                : in    std_logic_vector(2 downto 0);
      s00_axis_tid                  : in    std_logic_vector(2 downto 0);
      s01_axis_tid                  : in    std_logic_vector(2 downto 0);
      s02_axis_tid                  : in    std_logic_vector(2 downto 0);
      s03_axis_tid                  : in    std_logic_vector(2 downto 0);
      s04_axis_tid                  : in    std_logic_vector(2 downto 0);
      s05_axis_tid                  : in    std_logic_vector(2 downto 0);
      s06_axis_tid                  : in    std_logic_vector(2 downto 0);
      s07_axis_tid                  : in    std_logic_vector(2 downto 0);
      m00_axis_aclk                 : in    std_logic;
      m01_axis_aclk                 : in    std_logic;
      m02_axis_aclk                 : in    std_logic;
      m03_axis_aclk                 : in    std_logic;
      m04_axis_aclk                 : in    std_logic;
      m05_axis_aclk                 : in    std_logic;
      m06_axis_aclk                 : in    std_logic;
      m07_axis_aclk                 : in    std_logic;
      m00_axis_aresetn              : in    std_logic;
      m01_axis_aresetn              : in    std_logic;
      m02_axis_aresetn              : in    std_logic;
      m03_axis_aresetn              : in    std_logic;
      m04_axis_aresetn              : in    std_logic;
      m05_axis_aresetn              : in    std_logic;
      m06_axis_aresetn              : in    std_logic;
      m07_axis_aresetn              : in    std_logic;
      m00_axis_tvalid               : out   std_logic;
      m01_axis_tvalid               : out   std_logic;
      m02_axis_tvalid               : out   std_logic;
      m03_axis_tvalid               : out   std_logic;
      m04_axis_tvalid               : out   std_logic;
      m05_axis_tvalid               : out   std_logic;
      m06_axis_tvalid               : out   std_logic;
      m07_axis_tvalid               : out   std_logic;
      m00_axis_tready               : in    std_logic;
      m01_axis_tready               : in    std_logic;
      m02_axis_tready               : in    std_logic;
      m03_axis_tready               : in    std_logic;
      m04_axis_tready               : in    std_logic;
      m05_axis_tready               : in    std_logic;
      m06_axis_tready               : in    std_logic;
      m07_axis_tready               : in    std_logic;
      m00_axis_tdata                : out   std_logic_vector(63 downto 0);
      m01_axis_tdata                : out   std_logic_vector(63 downto 0);
      m02_axis_tdata                : out   std_logic_vector(63 downto 0);
      m03_axis_tdata                : out   std_logic_vector(63 downto 0);
      m04_axis_tdata                : out   std_logic_vector(63 downto 0);
      m05_axis_tdata                : out   std_logic_vector(63 downto 0);
      m06_axis_tdata                : out   std_logic_vector(63 downto 0);
      m07_axis_tdata                : out   std_logic_vector(63 downto 0);
      m00_axis_tlast                : out   std_logic;
      m01_axis_tlast                : out   std_logic;
      m02_axis_tlast                : out   std_logic;
      m03_axis_tlast                : out   std_logic;
      m04_axis_tlast                : out   std_logic;
      m05_axis_tlast                : out   std_logic;
      m06_axis_tlast                : out   std_logic;
      m07_axis_tlast                : out   std_logic;
      m00_axis_tdest                : out   std_logic_vector(2 downto 0);
      m01_axis_tdest                : out   std_logic_vector(2 downto 0);
      m02_axis_tdest                : out   std_logic_vector(2 downto 0);
      m03_axis_tdest                : out   std_logic_vector(2 downto 0);
      m04_axis_tdest                : out   std_logic_vector(2 downto 0);
      m05_axis_tdest                : out   std_logic_vector(2 downto 0);
      m06_axis_tdest                : out   std_logic_vector(2 downto 0);
      m07_axis_tdest                : out   std_logic_vector(2 downto 0);
      m00_axis_tid                  : out   std_logic_vector(2 downto 0);
      m01_axis_tid                  : out   std_logic_vector(2 downto 0);
      m02_axis_tid                  : out   std_logic_vector(2 downto 0);
      m03_axis_tid                  : out   std_logic_vector(2 downto 0);
      m04_axis_tid                  : out   std_logic_vector(2 downto 0);
      m05_axis_tid                  : out   std_logic_vector(2 downto 0);
      m06_axis_tid                  : out   std_logic_vector(2 downto 0);
      m07_axis_tid                  : out   std_logic_vector(2 downto 0);
      s00_decode_err                : out   std_logic;
      s01_decode_err                : out   std_logic;
      s02_decode_err                : out   std_logic;
      s03_decode_err                : out   std_logic;
      s04_decode_err                : out   std_logic;
      s05_decode_err                : out   std_logic;
      s06_decode_err                : out   std_logic;
      s07_decode_err                : out   std_logic);
  end component;

  -------------------------------------------------------------------------------
  -- Signal Declaration
  -------------------------------------------------------------------------------
  type slv_256x32 is array(0 to 255) of std_logic_vector(31 downto 0);
  type slv_8x72   is array(0 to 7)   of std_logic_vector(71 downto 0);

  signal ctrl_0_reg                 : slv_256x32 := (others=>(others=>'0'));
  signal status_0_reg               : slv_256x32 := (others=>(others=>'0'));
  signal ctrl_127_reg               : slv_256x32 := (others=>(others=>'0'));
  signal status_127_reg             : slv_256x32 := (others=>(others=>'0'));
  signal ctrl_0_stb_dly             : std_logic;
  signal status_0_addr              : std_logic_vector(7 downto 0);
  signal status_0_data              : std_logic_vector(31 downto 0);
  signal status_0_stb               : std_logic;
  signal ctrl_0_addr                : std_logic_vector(7 downto 0);
  signal ctrl_0_data                : std_logic_vector(31 downto 0);
  signal ctrl_0_stb                 : std_logic;
  signal status_127_addr            : std_logic_vector(7 downto 0);
  signal status_127_data            : std_logic_vector(31 downto 0);
  signal status_127_stb             : std_logic;
  signal ctrl_127_addr              : std_logic_vector(7 downto 0);
  signal ctrl_127_data              : std_logic_vector(31 downto 0);
  signal ctrl_127_stb               : std_logic;

  signal status_id                  : std_logic_vector(6 downto 0);
  signal ctrl_id                    : std_logic_vector(6 downto 0);
  signal read_addr                  : std_logic_vector(14 downto 0);
  signal read_data                  : std_logic_vector(31 downto 0);
  signal read_stb                   : std_logic;
  signal write_addr                 : std_logic_vector(14 downto 0);
  signal write_data                 : std_logic_vector(31 downto 0);
  signal write_stb                  : std_logic;

  signal rst_global_n               : std_logic;
  signal rst_global                 : std_logic;
  signal rst_mm2s_cmd_fifo          : std_logic;
  signal rst_s2mm_cmd_fifo          : std_logic;
  signal rst_sts_fifo               : std_logic;
  signal mm2s_cmd_fifo_loop         : std_logic_vector(7 downto 0);
  signal s2mm_cmd_fifo_loop         : std_logic_vector(7 downto 0);
  signal sts_fifo_auto_read         : std_logic;
  signal irq_s2mm_en                : std_logic;
  signal irq_mm2s_en                : std_logic;
  signal irq_axis_master_en         : std_logic_vector(7 downto 0);
  signal irq_axis_slave_en          : std_logic_vector(7 downto 0);
  signal mm2s_cmd_addr              : std_logic_vector(31 downto 0);
  signal mm2s_cmd_seq_num           : std_logic_vector(11 downto 0);
  signal mm2s_cmd_size              : std_logic_vector(22 downto 0);
  signal mm2s_cmd_cache             : std_logic_vector(3 downto 0);
  signal mm2s_cmd_tdest             : std_logic_vector(2 downto 0);
  signal mm2s_cmd_en                : std_logic;
  signal s2mm_cmd_addr              : std_logic_vector(31 downto 0);
  signal s2mm_cmd_seq_num           : std_logic_vector(11 downto 0);
  signal s2mm_cmd_size              : std_logic_vector(22 downto 0);
  signal s2mm_cmd_cache             : std_logic_vector(3 downto 0);
  signal s2mm_cmd_tid               : std_logic_vector(2 downto 0);
  signal s2mm_cmd_en                : std_logic;

  signal mm2s_err                   : std_logic;
  signal axis_mm2s_cmd_tvalid       : std_logic;
  signal axis_mm2s_cmd_tready       : std_logic;
  signal axis_mm2s_cmd_tdata        : std_logic_vector(71 downto 0);
  signal axis_mm2s_sts_tvalid       : std_logic;
  signal axis_mm2s_sts_tdata        : std_logic_vector(7 downto 0);
  signal axis_mm2s_tdata            : std_logic_vector(63 downto 0);
  signal axis_mm2s_tkeep            : std_logic_vector(7 downto 0);
  signal axis_mm2s_tlast            : std_logic;
  signal axis_mm2s_tvalid           : std_logic;
  signal axis_mm2s_tready           : std_logic;
  signal axis_mm2s_tdest            : std_logic_vector(2 downto 0);
  signal mm2s_rd_xfer_cmplt         : std_logic;
  signal s2mm_err                   : std_logic;
  signal axis_s2mm_cmd_tvalid       : std_logic;
  signal axis_s2mm_cmd_tready       : std_logic;
  signal axis_s2mm_cmd_tdata        : std_logic_vector(71 downto 0);
  signal axis_s2mm_sts_tvalid       : std_logic;
  signal axis_s2mm_sts_tdata        : std_logic_vector(7 downto 0);
  signal axis_s2mm_tdata            : std_logic_vector(63 downto 0);
  signal axis_s2mm_tkeep            : std_logic_vector(7 downto 0);
  signal axis_s2mm_tlast            : std_logic;
  signal axis_s2mm_tvalid           : std_logic;
  signal axis_s2mm_tready           : std_logic;
  signal axis_s2mm_tid              : std_logic_vector(2 downto 0);
  signal s2mm_wr_xfer_cmplt         : std_logic;
  signal m00_fifo_data_count        : std_logic_vector(31 downto 0);

  signal mm2s_cmd_fifo_din          : slv_8x72;
  signal mm2s_cmd_fifo_wr_en        : std_logic_vector(7 downto 0);
  signal mm2s_cmd_fifo_rd_en        : std_logic_vector(7 downto 0);
  signal mm2s_cmd_fifo_dout         : slv_8x72;
  signal mm2s_cmd_fifo_full         : std_logic_vector(7 downto 0);
  signal mm2s_cmd_fifo_empty        : std_logic_vector(7 downto 0);
  signal s2mm_cmd_fifo_din          : slv_8x72;
  signal s2mm_cmd_fifo_wr_en        : std_logic_vector(7 downto 0);
  signal s2mm_cmd_fifo_rd_en        : std_logic_vector(7 downto 0);
  signal s2mm_cmd_fifo_dout         : slv_8x72;
  signal s2mm_cmd_fifo_full         : std_logic_vector(7 downto 0);
  signal s2mm_cmd_fifo_empty        : std_logic_vector(7 downto 0);

  signal mm2s_sts_fifo_rd_en        : std_logic;
  signal mm2s_sts_fifo_dout         : std_logic_vector(7 downto 0);
  signal mm2s_sts_fifo_full         : std_logic;
  signal mm2s_sts_fifo_empty        : std_logic;
  signal s2mm_sts_fifo_rd_en        : std_logic;
  signal s2mm_sts_fifo_dout         : std_logic_vector(7 downto 0);
  signal s2mm_sts_fifo_full         : std_logic;
  signal s2mm_sts_fifo_empty        : std_logic;

  signal mm2s_tdest                 : integer range 0 to 7;
  signal mm2s_xfer_in_progress      : std_logic;
  signal s2mm_xfer_in_progress      : std_logic;
  signal mm2s_xfer_en               : std_logic;
  signal s2mm_xfer_en               : std_logic;
  signal s2mm_xfer_cnt              : integer;
  signal clear_s2mm_xfer_cnt        : std_logic;
  signal mm2s_xfer_cnt              : integer;
  signal clear_mm2s_xfer_cnt        : std_logic;

  signal irq_long_cnt               : integer range 0 to 15;
  signal irq_queue_cnt              : integer range 0 to 31;
  signal irq_concat                 : std_logic_vector(15 downto 0);
  signal irq_reduce                 : std_logic;
  signal axis_master_0_irq          : std_logic;
  signal axis_slave_0_irq           : std_logic;

  signal debug_counter              : integer;

  attribute keep                        : string;
  attribute keep of mm2s_err            : signal is "true";
  attribute keep of s2mm_err            : signal is "true";
  attribute keep of mm2s_rd_xfer_cmplt  : signal is "true";
  attribute keep of s2mm_wr_xfer_cmplt  : signal is "true";

begin

  rst_global_n                      <= NOT(rst_global);
  rst_glb_n                         <= rst_global_n;

  proc_debug_count : process(clk,rst_global_n)
  begin
    if (rst_global_n = '0') then
      debug_counter                 <= 0;
    elsif rising_edge(clk) then
      if (debug_counter = 2**30-1) then
        debug_counter               <= 0;
      else
        debug_counter               <= debug_counter + 1;
      end if;
    end if;
  end process;

  -------------------------------------------------------------------------------
  -- Processor Interrupt Controller is on a different clock, so stretch the
  -- interrupts 8 clock cycles to ensure it does no miss the pulse. Also
  -- includes logic to count interrupts so none are missed in case they
  -- occur simultaneously.
  -------------------------------------------------------------------------------
  proc_irq_stretch : process(clk,rst_global_n)
  begin
    if (rst_global_n = '0') then
      irq_long_cnt                  <= 0;
      irq_queue_cnt                 <= 0;
      irq                           <= '0';
    else
      if rising_edge(clk) then
        if (irq_reduce = '1') then
          irq_queue_cnt             <= irq_queue_cnt + 1;
        end if;
        if (irq_long_cnt = 0 AND irq_queue_cnt > 0) then
          -- Reduce queue count, except in the case when
          -- another irq occurs which would case no net
          -- change.
          if (irq_reduce = '0') then
            irq_queue_cnt           <= irq_queue_cnt - 1;
          end if;
          irq_long_cnt              <= 15;
          irq                       <= '1';
        end if;
        if (irq_long_cnt = 7) then
          irq                       <= '0';
        end if;
        if (irq_long_cnt > 0) then
          irq_long_cnt              <= irq_long_cnt - 1;
        end if;
      end if;
    end if;
  end process;

  irq_concat                        <= axis_master_0_irq & axis_slave_0_irq &
                                       axis_master_1_irq & axis_slave_1_irq &
                                       axis_master_2_irq & axis_slave_2_irq &
                                       axis_master_3_irq & axis_slave_3_irq &
                                       axis_master_4_irq & axis_slave_4_irq &
                                       axis_master_5_irq & axis_slave_5_irq &
                                       axis_master_6_irq & axis_slave_6_irq &
                                       axis_master_7_irq & axis_slave_7_irq;
  axis_master_0_irq                 <= axis_mm2s_sts_tvalid AND irq_mm2s_en;
  axis_slave_0_irq                  <= axis_s2mm_sts_tvalid AND irq_s2mm_en;
  irq_reduce                        <= '1' when irq_concat /= (irq_concat'length-1 downto 0 => '0') else
                                       '0';

  -------------------------------------------------------------------------------
  -- Converts AXI-4 Lite interface to a simple parallel bus.
  -- This interfaces with the control / status register banks.
  -------------------------------------------------------------------------------
  inst_axi_lite_to_parallel_bus : axi_lite_to_parallel_bus
    generic map (
      C_BASEADDR                    => C_BASEADDR,
      C_HIGHADDR                    => C_HIGHADDR)
    port map (
      S_AXI_ACLK                    => clk,
      S_AXI_ARESETN                 => rst_n,
      S_AXI_ARADDR                  => S_AXI_ARADDR,
      S_AXI_ARVALID                 => S_AXI_ARVALID,
      S_AXI_ARREADY                 => S_AXI_ARREADY,
      S_AXI_RDATA                   => S_AXI_RDATA,
      S_AXI_RRESP                   => S_AXI_RRESP,
      S_AXI_RVALID                  => S_AXI_RVALID,
      S_AXI_RREADY                  => S_AXI_RREADY,
      S_AXI_AWADDR                  => S_AXI_AWADDR,
      S_AXI_AWVALID                 => S_AXI_AWVALID,
      S_AXI_AWREADY                 => S_AXI_AWREADY,
      S_AXI_WDATA                   => S_AXI_WDATA,
      S_AXI_WSTRB                   => S_AXI_WSTRB,
      S_AXI_WVALID                  => S_AXI_WVALID,
      S_AXI_WREADY                  => S_AXI_WREADY,
      S_AXI_BRESP                   => S_AXI_BRESP,
      S_AXI_BVALID                  => S_AXI_BVALID,
      S_AXI_BREADY                  => S_AXI_BREADY,
      read_addr                     => read_addr,
      read_data                     => read_data,
      read_stb                      => read_stb,
      write_addr                    => write_addr,
      write_data                    => write_data,
      write_stb                     => write_stb);

  read_data                         <= status_0_data   when status_id = std_logic_vector(to_unsigned(  0,7)) else
                                       status_1_data   when status_id = std_logic_vector(to_unsigned(  1,7)) else
                                       status_2_data   when status_id = std_logic_vector(to_unsigned(  2,7)) else
                                       status_3_data   when status_id = std_logic_vector(to_unsigned(  3,7)) else
                                       status_4_data   when status_id = std_logic_vector(to_unsigned(  4,7)) else
                                       status_5_data   when status_id = std_logic_vector(to_unsigned(  5,7)) else
                                       status_6_data   when status_id = std_logic_vector(to_unsigned(  6,7)) else
                                       status_7_data   when status_id = std_logic_vector(to_unsigned(  7,7)) else
                                       status_127_data when status_id = std_logic_vector(to_unsigned(127,7)) else
                                       (others=>'0');
  status_0_addr                     <= read_addr(7 downto 0);
  status_1_addr                     <= read_addr(7 downto 0);
  status_2_addr                     <= read_addr(7 downto 0);
  status_3_addr                     <= read_addr(7 downto 0);
  status_4_addr                     <= read_addr(7 downto 0);
  status_5_addr                     <= read_addr(7 downto 0);
  status_6_addr                     <= read_addr(7 downto 0);
  status_7_addr                     <= read_addr(7 downto 0);
  status_127_addr                   <= read_addr(7 downto 0);
  status_id                         <= read_addr(14 downto 8);
  status_0_stb                      <= '1' when read_stb = '1' AND status_id = std_logic_vector(to_unsigned(  0,7)) else '0';
  status_1_stb                      <= '1' when read_stb = '1' AND status_id = std_logic_vector(to_unsigned(  1,7)) else '0';
  status_2_stb                      <= '1' when read_stb = '1' AND status_id = std_logic_vector(to_unsigned(  2,7)) else '0';
  status_3_stb                      <= '1' when read_stb = '1' AND status_id = std_logic_vector(to_unsigned(  3,7)) else '0';
  status_4_stb                      <= '1' when read_stb = '1' AND status_id = std_logic_vector(to_unsigned(  4,7)) else '0';
  status_5_stb                      <= '1' when read_stb = '1' AND status_id = std_logic_vector(to_unsigned(  5,7)) else '0';
  status_6_stb                      <= '1' when read_stb = '1' AND status_id = std_logic_vector(to_unsigned(  6,7)) else '0';
  status_7_stb                      <= '1' when read_stb = '1' AND status_id = std_logic_vector(to_unsigned(  7,7)) else '0';
  status_127_stb                    <= '1' when read_stb = '1' AND status_id = std_logic_vector(to_unsigned(127,7)) else '0';
  ctrl_0_addr                       <= write_addr(7 downto 0);
  ctrl_1_addr                       <= write_addr(7 downto 0);
  ctrl_2_addr                       <= write_addr(7 downto 0);
  ctrl_3_addr                       <= write_addr(7 downto 0);
  ctrl_4_addr                       <= write_addr(7 downto 0);
  ctrl_5_addr                       <= write_addr(7 downto 0);
  ctrl_6_addr                       <= write_addr(7 downto 0);
  ctrl_7_addr                       <= write_addr(7 downto 0);
  ctrl_127_addr                     <= write_addr(7 downto 0);
  ctrl_id                           <= write_addr(14 downto 8);
  ctrl_0_stb                        <= '1' when write_stb = '1' AND ctrl_id = std_logic_vector(to_unsigned(  0,7)) else '0';
  ctrl_1_stb                        <= '1' when write_stb = '1' AND ctrl_id = std_logic_vector(to_unsigned(  1,7)) else '0';
  ctrl_2_stb                        <= '1' when write_stb = '1' AND ctrl_id = std_logic_vector(to_unsigned(  2,7)) else '0';
  ctrl_3_stb                        <= '1' when write_stb = '1' AND ctrl_id = std_logic_vector(to_unsigned(  3,7)) else '0';
  ctrl_4_stb                        <= '1' when write_stb = '1' AND ctrl_id = std_logic_vector(to_unsigned(  4,7)) else '0';
  ctrl_5_stb                        <= '1' when write_stb = '1' AND ctrl_id = std_logic_vector(to_unsigned(  5,7)) else '0';
  ctrl_6_stb                        <= '1' when write_stb = '1' AND ctrl_id = std_logic_vector(to_unsigned(  6,7)) else '0';
  ctrl_7_stb                        <= '1' when write_stb = '1' AND ctrl_id = std_logic_vector(to_unsigned(  7,7)) else '0';
  ctrl_127_stb                      <= '1' when write_stb = '1' AND ctrl_id = std_logic_vector(to_unsigned(127,7)) else '0';
  ctrl_0_data                       <= write_data;
  ctrl_1_data                       <= write_data;
  ctrl_2_data                       <= write_data;
  ctrl_3_data                       <= write_data;
  ctrl_4_data                       <= write_data;
  ctrl_5_data                       <= write_data;
  ctrl_6_data                       <= write_data;
  ctrl_7_data                       <= write_data;
  ctrl_127_data                     <= write_data;

  -------------------------------------------------------------------------------
  -- Converts AXI-4 to AXI-Stream and vice versa. This component is how the FPGA
  -- accelerators read/write RAM and/or processor cache via AXI ACP.
  -------------------------------------------------------------------------------
  inst_xlnx_axi_datamover : xlnx_axi_datamover
    port map (
      m_axi_mm2s_aclk               => clk,
      m_axi_mm2s_aresetn            => rst_global_n,
      mm2s_halt                     => '0',
      mm2s_halt_cmplt               => open,
      mm2s_err                      => mm2s_err,
      m_axis_mm2s_cmdsts_aclk       => clk,
      m_axis_mm2s_cmdsts_aresetn    => rst_global_n,
      s_axis_mm2s_cmd_tvalid        => axis_mm2s_cmd_tvalid,
      s_axis_mm2s_cmd_tready        => axis_mm2s_cmd_tready,
      s_axis_mm2s_cmd_tdata         => axis_mm2s_cmd_tdata,
      m_axis_mm2s_sts_tvalid        => axis_mm2s_sts_tvalid,
      m_axis_mm2s_sts_tready        => '1', -- Always ready. If not ready, stalls core
      m_axis_mm2s_sts_tdata         => axis_mm2s_sts_tdata,
      m_axis_mm2s_sts_tkeep         => open,
      m_axis_mm2s_sts_tlast         => open,
      mm2s_allow_addr_req           => '1',
      mm2s_addr_req_posted          => open,
      mm2s_rd_xfer_cmplt            => mm2s_rd_xfer_cmplt,
      m_axi_mm2s_arid               => open,
      m_axi_mm2s_araddr             => M_AXI_ARADDR,
      m_axi_mm2s_arlen              => M_AXI_ARLEN,
      m_axi_mm2s_arsize             => M_AXI_ARSIZE,
      m_axi_mm2s_arburst            => M_AXI_ARBURST,
      m_axi_mm2s_arprot             => open,
      m_axi_mm2s_arcache            => open,
      m_axi_mm2s_arvalid            => M_AXI_ARVALID,
      m_axi_mm2s_arready            => M_AXI_ARREADY,
      m_axi_mm2s_rdata              => M_AXI_RDATA,
      m_axi_mm2s_rresp              => M_AXI_RRESP,
      m_axi_mm2s_rlast              => M_AXI_RLAST,
      m_axi_mm2s_rvalid             => M_AXI_RVALID,
      m_axi_mm2s_rready             => M_AXI_RREADY,
      m_axis_mm2s_tdata             => axis_mm2s_tdata,
      m_axis_mm2s_tkeep             => axis_mm2s_tkeep,
      m_axis_mm2s_tlast             => axis_mm2s_tlast,
      m_axis_mm2s_tvalid            => axis_mm2s_tvalid,
      m_axis_mm2s_tready            => axis_mm2s_tready,
      mm2s_dbg_sel                  => "0000",
      mm2s_dbg_data                 => open,
      m_axi_s2mm_aclk               => clk,
      m_axi_s2mm_aresetn            => rst_global_n,
      s2mm_halt                     => '0',
      s2mm_halt_cmplt               => open,
      s2mm_err                      => s2mm_err,
      m_axis_s2mm_cmdsts_awclk      => clk,
      m_axis_s2mm_cmdsts_aresetn    => rst_global_n,
      s_axis_s2mm_cmd_tvalid        => axis_s2mm_cmd_tvalid,
      s_axis_s2mm_cmd_tready        => axis_s2mm_cmd_tready,
      s_axis_s2mm_cmd_tdata         => axis_s2mm_cmd_tdata,
      m_axis_s2mm_sts_tvalid        => axis_s2mm_sts_tvalid,
      m_axis_s2mm_sts_tready        => '1', -- Always ready. If not ready, stalls core
      m_axis_s2mm_sts_tdata         => axis_s2mm_sts_tdata,
      m_axis_s2mm_sts_tkeep         => open,
      m_axis_s2mm_sts_tlast         => open,
      s2mm_allow_addr_req           => '1',
      s2mm_addr_req_posted          => open,
      s2mm_wr_xfer_cmplt            => s2mm_wr_xfer_cmplt,
      s2mm_ld_nxt_len               => open,
      s2mm_wr_len                   => open,
      m_axi_s2mm_awid               => open,
      m_axi_s2mm_awaddr             => M_AXI_AWADDR,
      m_axi_s2mm_awlen              => M_AXI_AWLEN,
      m_axi_s2mm_awsize             => M_AXI_AWSIZE,
      m_axi_s2mm_awburst            => M_AXI_AWBURST,
      m_axi_s2mm_awprot             => open,
      m_axi_s2mm_awcache            => open,
      m_axi_s2mm_awvalid            => M_AXI_AWVALID,
      m_axi_s2mm_awready            => M_AXI_AWREADY,
      m_axi_s2mm_wdata              => M_AXI_WDATA,
      m_axi_s2mm_wstrb              => M_AXI_WSTRB,
      m_axi_s2mm_wlast              => M_AXI_WLAST,
      m_axi_s2mm_wvalid             => M_AXI_WVALID,
      m_axi_s2mm_wready             => M_AXI_WREADY,
      m_axi_s2mm_bresp              => M_AXI_BRESP,
      m_axi_s2mm_bvalid             => M_AXI_BVALID,
      m_axi_s2mm_bready             => M_AXI_BREADY,
      s_axis_s2mm_tdata             => axis_s2mm_tdata,
      s_axis_s2mm_tkeep             => x"FF",   -- Keep all bytes
      s_axis_s2mm_tlast             => axis_s2mm_tlast,
      s_axis_s2mm_tvalid            => axis_s2mm_tvalid,
      s_axis_s2mm_tready            => axis_s2mm_tready,
      s2mm_dbg_sel                  => "0000",
      s2mm_dbg_data                 => open);

  -------------------------------------------------------------------------------
  -- AXI-Stream Interconnect 8x8
  -- Note: This interconnect has 8 slaves and 8 masters with full connectivity.
  --       M00 & S00 (Master & Slave 0) each have 4K FIFO buffers. These help
  --       buffer the uneven read & write speeds over the AXI ACP interface.
  --       Arbitrates on tlast or after 16383 cycles with tvalid low. 16383 was
  --       chosen to accommodate the slow output rate of a decimation filter.
  -------------------------------------------------------------------------------
  inst_axis_interconnect_8x8 : axis_interconnect_8x8
    port map (
      aclk                          => clk,
      aresetn                       => rst_global_n,
      s00_axis_aclk                 => clk,
      s01_axis_aclk                 => clk,
      s02_axis_aclk                 => clk,
      s03_axis_aclk                 => clk,
      s04_axis_aclk                 => clk,
      s05_axis_aclk                 => clk,
      s06_axis_aclk                 => clk,
      s07_axis_aclk                 => clk,
      s00_axis_aresetn              => rst_global_n,
      s01_axis_aresetn              => rst_global_n,
      s02_axis_aresetn              => rst_global_n,
      s03_axis_aresetn              => rst_global_n,
      s04_axis_aresetn              => rst_global_n,
      s05_axis_aresetn              => rst_global_n,
      s06_axis_aresetn              => rst_global_n,
      s07_axis_aresetn              => rst_global_n,
      s00_axis_tvalid               => axis_mm2s_tvalid,
      s01_axis_tvalid               => axis_master_1_tvalid,
      s02_axis_tvalid               => axis_master_2_tvalid,
      s03_axis_tvalid               => axis_master_3_tvalid,
      s04_axis_tvalid               => axis_master_4_tvalid,
      s05_axis_tvalid               => axis_master_5_tvalid,
      s06_axis_tvalid               => axis_master_6_tvalid,
      s07_axis_tvalid               => axis_master_7_tvalid,
      s00_axis_tready               => axis_mm2s_tready,
      s01_axis_tready               => axis_master_1_tready,
      s02_axis_tready               => axis_master_2_tready,
      s03_axis_tready               => axis_master_3_tready,
      s04_axis_tready               => axis_master_4_tready,
      s05_axis_tready               => axis_master_5_tready,
      s06_axis_tready               => axis_master_6_tready,
      s07_axis_tready               => axis_master_7_tready,
      s00_axis_tdata                => axis_mm2s_tdata,
      s01_axis_tdata                => axis_master_1_tdata(63 downto 0),
      s02_axis_tdata                => axis_master_2_tdata(63 downto 0),
      s03_axis_tdata                => axis_master_3_tdata(63 downto 0),
      s04_axis_tdata                => axis_master_4_tdata(63 downto 0),
      s05_axis_tdata                => axis_master_5_tdata(63 downto 0),
      s06_axis_tdata                => axis_master_6_tdata(63 downto 0),
      s07_axis_tdata                => axis_master_7_tdata(63 downto 0),
      s00_axis_tlast                => axis_mm2s_tlast,
      s01_axis_tlast                => axis_master_1_tlast,
      s02_axis_tlast                => axis_master_2_tlast,
      s03_axis_tlast                => axis_master_3_tlast,
      s04_axis_tlast                => axis_master_4_tlast,
      s05_axis_tlast                => axis_master_5_tlast,
      s06_axis_tlast                => axis_master_6_tlast,
      s07_axis_tlast                => axis_master_7_tlast,
      s00_axis_tdest                => axis_mm2s_tdest,
      s01_axis_tdest                => axis_master_1_tdest,
      s02_axis_tdest                => axis_master_2_tdest,
      s03_axis_tdest                => axis_master_3_tdest,
      s04_axis_tdest                => axis_master_4_tdest,
      s05_axis_tdest                => axis_master_5_tdest,
      s06_axis_tdest                => axis_master_6_tdest,
      s07_axis_tdest                => axis_master_7_tdest,
      s00_axis_tid                  => "000",
      s01_axis_tid                  => "001",
      s02_axis_tid                  => "010",
      s03_axis_tid                  => "011",
      s04_axis_tid                  => "100",
      s05_axis_tid                  => "101",
      s06_axis_tid                  => "110",
      s07_axis_tid                  => "111",
      m00_axis_aclk                 => clk,
      m01_axis_aclk                 => clk,
      m02_axis_aclk                 => clk,
      m03_axis_aclk                 => clk,
      m04_axis_aclk                 => clk,
      m05_axis_aclk                 => clk,
      m06_axis_aclk                 => clk,
      m07_axis_aclk                 => clk,
      m00_axis_aresetn              => rst_global_n,
      m01_axis_aresetn              => rst_global_n,
      m02_axis_aresetn              => rst_global_n,
      m03_axis_aresetn              => rst_global_n,
      m04_axis_aresetn              => rst_global_n,
      m05_axis_aresetn              => rst_global_n,
      m06_axis_aresetn              => rst_global_n,
      m07_axis_aresetn              => rst_global_n,
      m00_axis_tvalid               => axis_s2mm_tvalid,
      m01_axis_tvalid               => axis_slave_1_tvalid,
      m02_axis_tvalid               => axis_slave_2_tvalid,
      m03_axis_tvalid               => axis_slave_3_tvalid,
      m04_axis_tvalid               => axis_slave_4_tvalid,
      m05_axis_tvalid               => axis_slave_5_tvalid,
      m06_axis_tvalid               => axis_slave_6_tvalid,
      m07_axis_tvalid               => axis_slave_7_tvalid,
      m00_axis_tready               => axis_s2mm_tready,
      m01_axis_tready               => axis_slave_1_tready,
      m02_axis_tready               => axis_slave_2_tready,
      m03_axis_tready               => axis_slave_3_tready,
      m04_axis_tready               => axis_slave_4_tready,
      m05_axis_tready               => axis_slave_5_tready,
      m06_axis_tready               => axis_slave_6_tready,
      m07_axis_tready               => axis_slave_7_tready,
      m00_axis_tdata                => axis_s2mm_tdata,
      m01_axis_tdata                => axis_slave_1_tdata(63 downto 0),
      m02_axis_tdata                => axis_slave_2_tdata(63 downto 0),
      m03_axis_tdata                => axis_slave_3_tdata(63 downto 0),
      m04_axis_tdata                => axis_slave_4_tdata(63 downto 0),
      m05_axis_tdata                => axis_slave_5_tdata(63 downto 0),
      m06_axis_tdata                => axis_slave_6_tdata(63 downto 0),
      m07_axis_tdata                => axis_slave_7_tdata(63 downto 0),
      m00_axis_tlast                => axis_s2mm_tlast,
      m01_axis_tlast                => axis_slave_1_tlast,
      m02_axis_tlast                => axis_slave_2_tlast,
      m03_axis_tlast                => axis_slave_3_tlast,
      m04_axis_tlast                => axis_slave_4_tlast,
      m05_axis_tlast                => axis_slave_5_tlast,
      m06_axis_tlast                => axis_slave_6_tlast,
      m07_axis_tlast                => axis_slave_7_tlast,
      m00_axis_tdest                => open,
      m01_axis_tdest                => open,
      m02_axis_tdest                => open,
      m03_axis_tdest                => open,
      m04_axis_tdest                => open,
      m05_axis_tdest                => open,
      m06_axis_tdest                => open,
      m07_axis_tdest                => open,
      m00_axis_tid                  => axis_s2mm_tid,
      m01_axis_tid                  => axis_slave_1_tid,
      m02_axis_tid                  => axis_slave_2_tid,
      m03_axis_tid                  => axis_slave_3_tid,
      m04_axis_tid                  => axis_slave_4_tid,
      m05_axis_tid                  => axis_slave_5_tid,
      m06_axis_tid                  => axis_slave_6_tid,
      m07_axis_tid                  => axis_slave_7_tid,
      s00_decode_err                => open,
      s01_decode_err                => open,
      s02_decode_err                => open,
      s03_decode_err                => open,
      s04_decode_err                => open,
      s05_decode_err                => open,
      s06_decode_err                => open,
      s07_decode_err                => open);

  -------------------------------------------------------------------------------
  -- FIFOs for the Datamover MM2S and S2MM Command interfaces
  -- One FIFO per destination which queues transfers solely for that tdest.
  -- Note: The Datamover is configured to only queue one command at a time and
  --       the FIFOs below can queue the remainder. This is necessary due to
  --       the need to retain tdest signals which are used for routing
  --       with the AXI-Stream interconnect.
  -------------------------------------------------------------------------------
  gen_mm2s_cmd_fifos : for i in 0 to 7 generate
    mm2s_cmd_fifo_72x64 : fifo_72x64
      port map (
        clk                         => clk,
        rst                         => rst_mm2s_cmd_fifo,
        din                         => mm2s_cmd_fifo_din(i),
        wr_en                       => mm2s_cmd_fifo_wr_en(i),
        rd_en                       => mm2s_cmd_fifo_rd_en(i),
        dout                        => mm2s_cmd_fifo_dout(i),
        full                        => mm2s_cmd_fifo_full(i),
        empty                       => mm2s_cmd_fifo_empty(i));

    s2mm_cmd_fifo_72x64 : fifo_72x64
      port map (
        clk                         => clk,
        rst                         => rst_s2mm_cmd_fifo,
        din                         => s2mm_cmd_fifo_din(i),
        wr_en                       => s2mm_cmd_fifo_wr_en(i),
        rd_en                       => s2mm_cmd_fifo_rd_en(i),
        dout                        => s2mm_cmd_fifo_dout(i),
        full                        => s2mm_cmd_fifo_full(i),
        empty                       => s2mm_cmd_fifo_empty(i));

  mm2s_cmd_fifo_din(i)              <= "0000" &                 -- Reserved
                                       '0' & mm2s_cmd_tdest &   -- Destination
                                       mm2s_cmd_addr &          -- Start Address
                                       '0' &                    -- No DRE
                                       '1' &                    -- Always EOF
                                       "000000" &               -- No DRE
                                       '0' &                    -- Type Fixed Address
                                       mm2s_cmd_size            -- Number of bytes to read
                                       when mm2s_cmd_fifo_loop(i) = '0' else
                                       mm2s_cmd_fifo_dout(i); -- Loopback dout, useful for ring buffer

  -- Push command to the FIFO based on tdest
  mm2s_cmd_fifo_wr_en(i)            <= '1' when (mm2s_cmd_en = '1' AND
                                                 ctrl_0_addr = x"03" AND
                                                 ctrl_0_stb_dly = '1' AND
                                                 mm2s_cmd_tdest = std_logic_vector(to_unsigned(i,3)))
                                                OR
                                                (mm2s_cmd_fifo_rd_en(i) = '1' AND mm2s_cmd_fifo_loop(i) = '1')
                                                else '0';

  s2mm_cmd_fifo_din(i)              <= "0000" &                 -- Reserved
                                       '0' & s2mm_cmd_tid &     -- Destination
                                       s2mm_cmd_addr &          -- Start Address
                                       '0' &                    -- No DRE
                                       '1' &                    -- Always EOF
                                       "000000" &               -- No DRE
                                       '0' &                    -- Type Fixed Address
                                       s2mm_cmd_size            -- Number of bytes to write
                                       when s2mm_cmd_fifo_loop(i) = '0' else
                                       s2mm_cmd_fifo_dout(i);

  -- Push command to the FIFO based on tdest
  s2mm_cmd_fifo_wr_en(i)            <= '1' when (s2mm_cmd_en = '1' AND
                                                 ctrl_0_addr = x"05" AND
                                                 ctrl_0_stb_dly = '1' AND
                                                 s2mm_cmd_tid = std_logic_vector(to_unsigned(i,3)))
                                                OR
                                                (s2mm_cmd_fifo_rd_en(i) = '1' AND s2mm_cmd_fifo_loop(i) = '1')
                                                else '0';
  end generate;

  -- Controls the MM2S interface with round robin selection for which AXI-Stream (via tdest)
  -- to output data on.
  proc_mm2s_cmd_intf : process(clk,rst_global_n)
  begin
    if (rst_global_n = '0') then
      mm2s_cmd_fifo_rd_en                   <= (others=>'0');
      axis_mm2s_cmd_tvalid                  <= '0';
      axis_mm2s_cmd_tdata                   <= (others=>'0');
      axis_mm2s_tdest                       <= (others=>'0');
      mm2s_xfer_in_progress                 <= '0';
      mm2s_tdest                            <= 0;
    else
      if rising_edge(clk) then
        -- Check each command FIFO. If not empty, the Datamover is ready, and a transfer is currently not in
        -- process, execute a new transfer.
        if (mm2s_cmd_fifo_empty(mm2s_tdest) = '0' AND axis_mm2s_cmd_tready = '1' AND mm2s_xfer_in_progress = '0' AND mm2s_xfer_en = '1') then
          mm2s_cmd_fifo_rd_en(mm2s_tdest)   <= '1';
          axis_mm2s_cmd_tvalid              <= '1';
          axis_mm2s_cmd_tdata               <= mm2s_cmd_fifo_dout(mm2s_tdest);
          axis_mm2s_tdest                   <= std_logic_vector(to_unsigned(mm2s_tdest,3));
          mm2s_xfer_in_progress             <= '1';
        else
          mm2s_cmd_fifo_rd_en               <= (others=>'0');
          axis_mm2s_cmd_tvalid              <= '0';
        end if;
        -- While an xfer is not in progress, loop through the available destinations
        if (mm2s_xfer_in_progress = '0') then
          if (mm2s_tdest = 7) then
            mm2s_tdest                      <= 0;
          else
            mm2s_tdest                      <= mm2s_tdest + 1;
          end if;
        end if;
        -- Clear transfer in progress register when the write is complete
        if (axis_mm2s_sts_tvalid = '1') then
          mm2s_xfer_in_progress             <= '0';
        end if;
      end if;
    end if;
  end process;

  proc_s2mm_cmd_intf : process(clk,rst_global_n)
  begin
    if (rst_global_n = '0') then
      s2mm_xfer_in_progress                     <= '0';
      s2mm_cmd_fifo_rd_en                       <= (others=>'0');
      axis_s2mm_cmd_tvalid                      <= '0';
      axis_s2mm_cmd_tdata                       <= (others=>'0');
    else
      if rising_edge(clk) then
        -- Wait until the Datamover is ready, the command FIFO is not empty, the AXI-Stream master
        -- has valid data, and no other transfers are in progress.
        if (axis_s2mm_cmd_tready = '1' AND s2mm_cmd_fifo_empty(to_integer(unsigned(axis_s2mm_tid))) = '0' AND
            axis_s2mm_tvalid = '1'     AND s2mm_xfer_in_progress = '0'  AND s2mm_xfer_en = '1') then
          s2mm_cmd_fifo_rd_en(to_integer(unsigned(axis_s2mm_tid)))  <= '1';
          axis_s2mm_cmd_tvalid                  <= '1';
          axis_s2mm_cmd_tdata                   <= s2mm_cmd_fifo_dout(to_integer(unsigned(axis_s2mm_tid)));
          s2mm_xfer_in_progress                 <= '1';
        else
          s2mm_cmd_fifo_rd_en                   <= (others=>'0');
          axis_s2mm_cmd_tvalid                  <= '0';
        end if;
        if (axis_s2mm_sts_tvalid = '1') then
          s2mm_xfer_in_progress                 <= '0';
        end if;
      end if;
    end if;
  end process;

  -------------------------------------------------------------------------------
  -- FIFOs for the Datamover MM2S and S2MM Status interfaces
  -- Note: The sts_tready signals are always asserted on the Datamover as
  --       deasserting the signal can cause it to stall. This means that these
  --       FIFOs may overflow if not read, but ultimately that is not a serious
  --       issue (especially if sts_fifo_auto_read is enabled).
  -------------------------------------------------------------------------------
  mm2s_sts_fifo_8x64 : fifo_8x64
    port map (
      clk                         => clk,
      rst                         => rst_sts_fifo,
      din                         => axis_mm2s_sts_tdata,
      wr_en                       => axis_mm2s_sts_tvalid,
      rd_en                       => mm2s_sts_fifo_rd_en,
      dout                        => mm2s_sts_fifo_dout,
      full                        => mm2s_sts_fifo_full,
      empty                       => mm2s_sts_fifo_empty);

  -- Pop FIFO when either Status Register Bank 6 is accessed or if auto-read is enabled and the FIFO is full (to avoid
  -- overflow)
  mm2s_sts_fifo_rd_en             <= '1' when (status_0_addr = x"06" AND status_0_stb = '1') OR
                                              (sts_fifo_auto_read = '1' AND mm2s_sts_fifo_full = '1') else '0';

  s2mm_sts_fifo_8x64 : fifo_8x64
    port map (
      clk                         => clk,
      rst                         => rst_sts_fifo,
      din                         => axis_s2mm_sts_tdata,
      wr_en                       => axis_s2mm_sts_tvalid,
      rd_en                       => s2mm_sts_fifo_rd_en,
      dout                        => s2mm_sts_fifo_dout,
      full                        => s2mm_sts_fifo_full,
      empty                       => s2mm_sts_fifo_empty);

  -- Pop FIFO when either Status Register Bank 7 is accessed or if auto-read is enabled and the FIFO is full (to avoid
  -- overflow)
  s2mm_sts_fifo_rd_en             <= '1' when (status_0_addr = x"07" AND status_0_stb = '1') OR
                                              (sts_fifo_auto_read = '1' AND s2mm_sts_fifo_full = '1') else '0';

  -- Count the number of transfers per plblock in each direction
  proc_xfer_counters : process(clk,rst_global_n)
  begin
    if (rst_global_n = '0') then
      s2mm_xfer_cnt               <= 0;
      mm2s_xfer_cnt               <= 0;
    else
      if rising_edge(clk) then
        for i in 0 to 7 loop
          if (clear_s2mm_xfer_cnt = '1' AND status_0_addr = x"00" AND status_0_stb = '1') then
            -- Xfer occured when we were commanded to clear the count
            if (axis_s2mm_sts_tvalid = '1') then
              s2mm_xfer_cnt       <= 1;
            else
              s2mm_xfer_cnt       <= 0;
            end if;
          elsif (axis_s2mm_sts_tvalid = '1') then
            s2mm_xfer_cnt         <= s2mm_xfer_cnt + 1;
          end if;
          if (clear_mm2s_xfer_cnt = '1' AND status_0_addr = x"00" AND status_0_stb = '1') then
            if (axis_mm2s_sts_tvalid = '1') then
              mm2s_xfer_cnt       <= 1;
            else
              mm2s_xfer_cnt       <= 0;
            end if;
          elsif (axis_s2mm_sts_tvalid = '1') then
            mm2s_xfer_cnt         <= mm2s_xfer_cnt + 1;
          end if;
        end loop;
      end if;
    end if;
  end process;

  -------------------------------------------------------------------------------
  -- Control and status registers.
  -------------------------------------------------------------------------------
  -- Global registers for all accelerators
  proc_global_reg : process(clk,rst_n)
  begin
    if (rst_n = '0') then
      ctrl_127_reg                      <= (others=>(others=>'0'));
      status_127_data                   <= (others=>'0');
    else
      if rising_edge(clk) then
        -- Update control registers only when the global registers are accessed
        if (ctrl_127_stb = '1') then
          ctrl_127_reg(to_integer(unsigned(ctrl_127_addr))) <= ctrl_127_data;
        end if;
        -- Always update status registers, regardless of which status regs
        -- are accessed (see above)
        if (status_127_stb = '1') then
          status_127_data               <= status_127_reg(to_integer(unsigned(status_127_addr)));
        end if;
      end if;
    end if;
  end process;

  -- Control Registers Bank 0 (General)
  rst_global                            <= ctrl_127_reg(0)(0) OR NOT(rst_n);
  -- Control Registers Bank 1 (AXI Cache & User)
  -- AxPROT(1): "0" = Secure, "1" = Non-secure. To access the ACP bus, we must be in secure mode.
  -- AxCACHE: "1111" = Cacheable write-back, allocate on both read and write per ARM documenation
  -- AxUSER(4:1): "1111" = Write-Back Write Allocate per ARM documentation
  -- AxUSER(0): Enable transaction sharing. From ARM documentation: "AxUSER(0) is ANDed with
  --            AxCACHE(1) to decide if it is a coherent shared request. Such requests can access
  --            level-1 cache coherent data."
  --                                                                           Recommended Values:
  M_AXI_AWPROT                          <= ctrl_127_reg(1)(2 downto 0);     -- "000"
  M_AXI_AWCACHE                         <= ctrl_127_reg(1)(6 downto 3);     -- "1111"
  M_AXI_AWUSER                          <= ctrl_127_reg(1)(11 downto 7);    -- "11111"
  M_AXI_ARPROT                          <= ctrl_127_reg(1)(14 downto 12);   -- "000"
  M_AXI_ARCACHE                         <= ctrl_127_reg(1)(18 downto 15);   -- "1111"
  M_AXI_ARUSER                          <= ctrl_127_reg(1)(23 downto 19);   -- "11111"

  -- Status Registers Bank 0 (Readback)
  status_127_reg(0)(0)                  <= rst_global;
  -- Status Registers Bank 1 (Readback)
  status_127_reg(1)(2 downto 0)         <= ctrl_127_reg(1)(2 downto 0);
  status_127_reg(1)(6 downto 3)         <= ctrl_127_reg(1)(6 downto 3);
  status_127_reg(1)(11 downto 7)        <= ctrl_127_reg(1)(11 downto 7);
  status_127_reg(1)(14 downto 12)       <= ctrl_127_reg(1)(14 downto 12);
  status_127_reg(1)(18 downto 15)       <= ctrl_127_reg(1)(18 downto 15);
  status_127_reg(1)(23 downto 19)       <= ctrl_127_reg(1)(23 downto 19);

  -- Registers for datamover and PS PL interface
  proc_datamover_reg : process(clk,rst_global_n)
  begin
    if (rst_global_n = '0') then
      ctrl_0_stb_dly                    <= '0';
      ctrl_0_reg                        <= (others=>(others=>'0'));
      status_0_data                     <= (others=>'0');
    else
      if rising_edge(clk) then
        ctrl_0_stb_dly                  <= ctrl_0_stb;
        -- Update control registers only when accelerator 0 is accessed
        if (ctrl_0_stb = '1') then
          ctrl_0_reg(to_integer(unsigned(ctrl_0_addr))) <= ctrl_0_data;
        end if;
        -- Always update status registers, regardless of which accelerator's status regs
        -- are accessed (see above)
        if (status_0_stb = '1') then
          status_0_data                 <= status_0_reg(to_integer(unsigned(status_0_addr)));
        end if;
      end if;
    end if;
  end process;

  -- Control Registers Bank 0 (General)
  mm2s_xfer_en                          <= ctrl_0_reg(0)(0);
  s2mm_xfer_en                          <= ctrl_0_reg(0)(1);
  rst_mm2s_cmd_fifo                     <= ctrl_0_reg(0)(2) OR rst_global;
  rst_s2mm_cmd_fifo                     <= ctrl_0_reg(0)(3) OR rst_global;
  mm2s_cmd_fifo_loop                    <= ctrl_0_reg(0)(11 downto 4);    -- Re-write command fifo output back to input
  s2mm_cmd_fifo_loop                    <= ctrl_0_reg(0)(19 downto 12);   -- Re-write command fifo output back to input
  sts_fifo_auto_read                    <= ctrl_0_reg(0)(20);  -- Automatically read FIFO if full to prevent overflow
  rst_sts_fifo                          <= ctrl_0_reg(0)(21) OR rst_global;
  clear_mm2s_xfer_cnt                   <= ctrl_0_reg(0)(22);
  clear_s2mm_xfer_cnt                   <= ctrl_0_reg(0)(23);
  -- Control Registers Bank 1 (Accelerator Interrupts)
  irq_s2mm_en                           <= ctrl_0_reg(1)(0);
  irq_mm2s_en                           <= ctrl_0_reg(1)(1);
  irq_axis_master_en                    <= ctrl_0_reg(1)(15 downto 8);
  irq_axis_slave_en                     <= ctrl_0_reg(1)(23 downto 16);
  -- Control Registers Bank 2 (MM2S Command Interface Address)
  mm2s_cmd_addr                         <= ctrl_0_reg(2);
  -- Control Registers Bank 3 (MM2S Command Interface FIFO Write Enable, tdest, Cache, Size)
  mm2s_cmd_size                         <= ctrl_0_reg(3)(22 downto 0);
  mm2s_cmd_tdest                        <= ctrl_0_reg(3)(25 downto 23);
  mm2s_cmd_en                           <= ctrl_0_reg(3)(31);
  -- Control Registers Bank 4 (S2MM Command Interface Address)
  s2mm_cmd_addr                         <= ctrl_0_reg(4);
  -- Control Registers Bank 5 (S2MM Command Interface FIFO Write Enable, tid, Cache, Size)
  s2mm_cmd_size                         <= ctrl_0_reg(5)(22 downto 0);
  s2mm_cmd_tid                          <= ctrl_0_reg(5)(25 downto 23);
  s2mm_cmd_en                           <= ctrl_0_reg(5)(31);

  -- Status Registers Bank 0 (General Readback)
  status_0_reg(0)(0)                    <= mm2s_xfer_en;
  status_0_reg(0)(1)                    <= s2mm_xfer_en;
  status_0_reg(0)(2)                    <= rst_mm2s_cmd_fifo;
  status_0_reg(0)(3)                    <= rst_s2mm_cmd_fifo;
  status_0_reg(0)(11 downto 4)          <= mm2s_cmd_fifo_loop;
  status_0_reg(0)(19 downto 12)         <= s2mm_cmd_fifo_loop;
  status_0_reg(0)(20)                   <= sts_fifo_auto_read;
  status_0_reg(0)(21)                   <= rst_sts_fifo;
  status_0_reg(0)(22)                   <= clear_mm2s_xfer_cnt;
  status_0_reg(0)(23)                   <= clear_s2mm_xfer_cnt;
  status_0_reg(0)(24)                   <= mm2s_xfer_in_progress;
  status_0_reg(0)(25)                   <= s2mm_xfer_in_progress;
  -- Status Registers Bank 1 (Interrupts Readback)
  status_0_reg(1)(0)                    <= irq_s2mm_en;
  status_0_reg(1)(1)                    <= irq_mm2s_en;
  status_0_reg(1)(15 downto 8)          <= irq_axis_master_en;
  status_0_reg(1)(23 downto 16)         <= irq_axis_slave_en;
  -- Status Registers Bank 2 (MM2S Command Interface Address Readback)
  status_0_reg(2)                       <= mm2s_cmd_addr;
  -- Status Registers Bank 3 (MM2S Command Interface FIFO Write Enable, tdest, Cache, Size Readback)
  status_0_reg(3)(22 downto 0)          <= mm2s_cmd_size;
  status_0_reg(3)(25 downto 23)         <= mm2s_cmd_tdest;
  status_0_reg(3)(31)                   <= mm2s_cmd_en;
  -- Status Registers Bank 4 (S2MM Command Interface Address Readback)
  status_0_reg(4)                       <= s2mm_cmd_addr;
  -- Status Registers Bank 5 (S2MM Command Interface FIFO Write Enable, tid, Cache, Size Readback)
  status_0_reg(5)(22 downto 0)          <= s2mm_cmd_size;
  status_0_reg(5)(25 downto 23)         <= s2mm_cmd_tid;
  status_0_reg(5)(31)                   <= s2mm_cmd_en;
  -- Status Registers Bank 6 (MM2S Sts)
  status_0_reg(6)(7 downto 0)           <= mm2s_sts_fifo_dout;
  -- Status Registers Bank 7 (S2MM Sts)
  status_0_reg(7)(7 downto 0)           <= s2mm_sts_fifo_dout;
  -- Status Registers Bank 8 (Sts FIFO Status)
  status_0_reg(8)(0)                    <= mm2s_sts_fifo_empty;
  status_0_reg(8)(1)                    <= mm2s_sts_fifo_full;
  status_0_reg(8)(2)                    <= s2mm_sts_fifo_empty;
  status_0_reg(8)(3)                    <= s2mm_sts_fifo_full;
  -- Status Registers Bank 9 (Command FIFO Status)
  status_0_reg(9)(7 downto 0)           <= mm2s_cmd_fifo_empty;
  status_0_reg(9)(15 downto 8)          <= mm2s_cmd_fifo_full;
  status_0_reg(9)(23 downto 16)         <= s2mm_cmd_fifo_empty;
  status_0_reg(9)(31 downto 24)         <= s2mm_cmd_fifo_full;
  -- Status Register Bank 11 (MM2S Xfer count)
  status_0_reg(10)                      <= std_logic_vector(to_unsigned(mm2s_xfer_cnt,32));
  -- Status Register Bank 12 (S2MM Xfer count)
  status_0_reg(11)                      <= std_logic_vector(to_unsigned(s2mm_xfer_cnt,32));
  -- Status Registers Bank 20 (Test Word)
  status_0_reg(12)                      <= x"CA11AB1E";
  -- Status Registers Bank 21 (Debug Counter)
  status_0_reg(13)                      <= std_logic_vector(to_unsigned(debug_counter,32));

end architecture;