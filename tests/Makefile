.DEFAULT_GOAL := sim
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)

# Use the already-built sibling checkout; override with make LHD=/path/to/lhd.
LHD ?= $(ROOT)/../livehd/bazel-bin/lhd/lhd
SIM ?= verilator
TOPLEVEL_LANG := verilog
TOPLEVEL := pyrope_wrapper
COCOTB_TEST_MODULES := test_systolic
VERILOG_SOURCES := $(ROOT)/generated/top.v $(ROOT)/tests/pyrope_wrapper.sv
SIM_BUILD := $(ROOT)/generated/sim_build
COCOTB_RESULTS_FILE := $(ROOT)/generated/results.xml
COCOTB_HDL_TIMEUNIT := 1ns
COCOTB_HDL_TIMEPRECISION := 1ps
export PYTHONPATH := $(ROOT)/tests:$(PYTHONPATH)
export PYTHONDONTWRITEBYTECODE := 1

$(ROOT)/generated/top.v: $(ROOT)/src_pyrope/top.prp $(LHD)
	mkdir -p $(ROOT)/generated
	$(LHD) compile $< --emit verilog:$@ --workdir $(ROOT)/generated/livehd-work

.PHONY: compile
compile: $(ROOT)/generated/top.v

include $(shell cocotb-config --makefiles)/Makefile.sim
