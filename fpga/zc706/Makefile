##################################################
# Project Setup
##################################################
TOP_MODULE = zc706
CUSTOM_SRCS =
CUSTOM_DEFS =

##################################################
# Constants
##################################################
# ISE_VER = $(shell xtclsh -h | head -n1 | cut -f2 -d" " | cut -f1 -d.)
ISE_EXISTS := $(shell which ise)
ISE_EXT = xise
BASE_DIR = $(abspath ..)
SOURCE_DIR = $(BASE_DIR)/src
BUILD_DIR = $(abspath build$(ISE))
ISE_HELPER = xtclsh $(BASE_DIR)/tcl/ise_helper.tcl
ISE_FILE = $(BUILD_DIR)/$(TOP_MODULE).$(ISE_EXT)
BIN_FILE = $(BUILD_DIR)/$(TOP_MODULE).bin
BIT_FILE = $(BUILD_DIR)/$(TOP_MODULE).bit
MCS_FILE = $(BUILD_DIR)/$(TOP_MODULE).mcs
TWR_FILE = $(BUILD_DIR)/$(TOP_MODULE).twr
XPS_PROJECT_FILES = $(abspath $(SOURCE_DIR)/xps_project_files)
XPS_PROJECT = $(abspath $(BUILD_DIR)/zynq-ps)
BUILD_ZYNQ = $(BASE_DIR)/tcl/build_zynq_proj.tcl

##################################################
# Includes
##################################################
include $(SOURCE_DIR)/Makefile.srcs

##################################################
# Check if ISE installed
##################################################
ifeq ($(ISE_EXISTS),)
$(error ISE not detected. Make sure you ran ISE\'s settings64.sh script.)
endif

##################################################
# Sources
##################################################
ZYNQ_PS_SRCS = $(abspath $(addprefix $(XPS_PROJECT)/, \
	hdl/$(TOP_MODULE)_ps_stub.v \
	implementation/$(TOP_MODULE)_ps.ngc \
))

SOURCES = \
	$(SOURCE_DIR)/toplevel/$(TOP_MODULE).vhd \
	$(SOURCE_DIR)/constraints/$(TOP_MODULE).ucf \
	$(ZYNQ_PS_SRCS) \
	$(FPGA_SRCS)

##################################################
# Global Targets
##################################################
all: bin promgen

proj: $(ISE_FILE)

check: $(ISE_FILE)
	$(ISE_HELPER) "Check Syntax"

synth: $(ISE_FILE)
	$(ISE_HELPER) "Synthesize - XST"

bin: $(BIN_FILE)

clean:
	$(RM) -r $(BUILD_DIR)

promgen: $(BIT_FILE)
	promgen -w -p bin -c FF -o $(BIN_FILE) -b -s 16384 -u 00000000 $< -bpi_dc parallel -data_width 32
	cp $(BUILD_DIR)/$(TOP_MODULE).bin .

.PHONY: all proj check synth bin mcs clean

##################################################
# Generate ZYNQ PS Sub-system
##################################################
$(ZYNQ_PS_SRCS): $(BUILD_ZYNQ) $(XPS_PROJECT_FILES)/$(TOP_MODULE)_master.mhs $(XPS_PROJECT_FILES)/ps7_$(TOP_MODULE)_ps_prj.xml
	@echo "Rebuilding ZYNQ PS subsystem"
	@echo "source dir $(XPS_PROJECT_FILES)"
	@echo "build dir $(XPS_PROJECT)"
	mkdir -p $(XPS_PROJECT)
	(cd $(XPS_PROJECT) ; xps -nw -scr $(BUILD_ZYNQ))

##################################################
# Dependency Targets
##################################################
.SECONDEXPANSION:
$(ISE_FILE): $$(SOURCES) $$(MAKEFILE_LIST)
	@echo $@
	$(ISE_HELPER) ""

$(BIN_FILE): $(ISE_FILE) $$(SOURCES) $$(MAKEFILE_LIST)
	@echo $@
	$(ISE_HELPER) "Generate Programming File" 2>&1 | tee $(BUILD_DIR)/build.log
	touch $@

$(MCS_FILE): $(BIN_FILE)
	promgen -w -spi -p mcs -o $(MCS_FILE) -s 4096 -u 0 $(BIT_FILE)

.EXPORT_ALL_VARIABLES:

##################################################
# Project Properties
##################################################
export PROJECT_PROPERTIES := \
family "Zynq" \
device XC7Z045 \
package FFG900 \
speed -2 \
top_level_module_type "HDL" \
synthesis_tool "XST (VHDL/Verilog)" \
simulator "ISim (VHDL/Verilog)" \
"Preferred Language" "Verilog" \
"Enable Message Filtering" FALSE \
"Display Incremental Messages" FALSE

##################################################
# Process Properties
##################################################
SYNTHESIZE_PROPERTIES = \
"Pack I/O Registers into IOBs" Yes \
"Optimization Effort" High \
"Optimize Instantiated Primitives" TRUE \
"Register Balancing" Yes \
"Use Clock Enable" Auto \
"Use Synchronous Reset" Auto \
"Use Synchronous Set" Auto

TRANSLATE_PROPERTIES = \
"Macro Search Path" "$(shell pwd)/../../coregen/"

MAP_PROPERTIES = \
"Generate Detailed MAP Report" TRUE \
"Allow Logic Optimization Across Hierarchy" TRUE \
"Pack I/O Registers/Latches into IOBs" "For Inputs and Outputs" \
"Combinatorial Logic Optimization" TRUE \
"Register Duplication" ON

PLACE_ROUTE_PROPERTIES = \
"Place & Route Effort Level (Overall)" High

STATIC_TIMING_PROPERTIES = \
"Number of Paths in Error/Verbose Report" 10 \
"Report Type" "Error Report"

GEN_PROG_FILE_PROPERTIES = \
"Create Binary Configuration File" TRUE \
"Done (Output Events)" 5 \
"Enable Bitstream Compression" TRUE \
"Enable Outputs (Output Events)" 6

SIM_MODEL_PROPERTIES = ""
