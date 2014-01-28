While there are three different boards, there is only one toplevel testbench as the differences reside in the processing system. This does not simulate the processing system (I'm not sure that is even possible).

To run this simulation requires a mixed HDL (VHDL & Verilog) simulator, such as ModelSim.

It is assumed you have ran Xilinx's compxlib (or the GUI version compxlibgui) and compiled all the VHDL & Verilog libraries simulation for Modelsim.

axi_interconnect_8x8.vhd crudely (and quickly!) simulates the AXI-Stream interconnect. This file is used for simulation instead of the files from Xilinx's coregen, because Xilinx's version does not simulate properly. It may be possible that a newer version of Xilinx's core will fix this issue.
