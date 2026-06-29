# Default simulator
SIM ?= icarus

# Language of the hardware
TOPLEVEL_LANG ?= verilog

# Your NEW Verilog source file
VERILOG_SOURCES += $(PWD)/../rtl/async_fifo.sv

# The name of the NEW top-level Verilog module
TOPLEVEL = async_fifo

# The name of your NEW Python test file
# Your Python test file is now in the tb/ folder
# Tell cocotb to look in the tb/ directory for Python modules
export PYTHONPATH := $(PWD)/../tb:$(PYTHONPATH)
MODULE = test_async_fifo

# Include Cocotb's standard simulation rules
include $(shell cocotb-config --makefiles)/Makefile.sim