# ============================================================================
# sim/Makefile — Build and run standalone Verilator simulation of mk_rv_serv_soc
#
# This simulates the full SERV SoC (CPU + UART + GPIO + Timer) as a native
# C++ executable. The C++ testbench drives the clock, preloads boot RAM with
# firmware, monitors UART TX output in real time, and observes GPIO pins.
#
# Usage:
#   make            — build and run with blinky firmware
#   make run        — same as above
#   make uart       — build and run with uart_hello firmware
#   make waves      — build and run with VCD trace (for GTKWave)
#   make build      — compile only, no run
#   make clean      — remove build artifacts
# ============================================================================

TOP       ?= tb_mk_rv_serv_sim
EXE        = V$(TOP)
TRACE     ?= 0
FW_TARGET ?= blinky

# Directories
PROJ_ROOT  = ..
RTL_DIR    = $(PROJ_ROOT)/hw/ip
SERV_DIR   = $(RTL_DIR)/serv
SOC_DIR    = $(RTL_DIR)/serv_SoC
UART_DIR   = $(RTL_DIR)/uart
GPIO_DIR   = $(RTL_DIR)/gpio
TIMER_DIR  = $(RTL_DIR)/timer
WB_DIR     = $(RTL_DIR)/wb_bus
FW_DIR     = $(PROJ_ROOT)/fw

# Firmware .mem file (Verilog $readmemh format)
MEMFILE    = $(FW_DIR)/build/$(FW_TARGET)/$(FW_TARGET).mem

# All RTL source files — collected into one flat list
RTL_SRCS = \
	$(wildcard $(SERV_DIR)/rtl/*.v) \
	$(wildcard $(SERV_DIR)/servile/*.v) \
	$(SOC_DIR)/rtl/serv_boot_ram.sv \
	$(SOC_DIR)/rtl/mk_rv_serv_soc.sv \
	$(UART_DIR)/rtl/sync_fifo.sv \
	$(UART_DIR)/rtl/uart_tx.sv \
	$(UART_DIR)/rtl/uart_rx.sv \
	$(UART_DIR)/rtl/uart_wb_slave.sv \
	$(GPIO_DIR)/rtl/gpio_wb_slave.sv \
	$(TIMER_DIR)/rtl/timer_wb_slave.sv \
	$(WB_DIR)/rtl/wb_crossbar.sv \
	$(WB_DIR)/rtl/wb_crossbar_wrapper.sv \
	sim_tb.sv

# Filter out synth_wrapper (not needed for sim)
RTL_SRCS := $(filter-out %synth_wrapper%, $(RTL_SRCS))

# Verilator flags
VERILATOR_FLAGS = -Wall -Wno-fatal -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
                  -Wno-WIDTH -Wno-CASEOVERLAP -Wno-CASEX \
                  -Wno-BLKANDNBLK -Wno-UNOPTFLAT -Wno-UNSIGNED \
                  -Wno-PINCONNECTEMPTY -Wno-MODDUP -Wno-TIMESCALEMOD \
                  -I$(SOC_DIR)/rtl \
                  --top-module $(TOP) \
                  --exe sim_main.cpp \
                  -o $(EXE)

ifeq ($(TRACE),1)
  VERILATOR_FLAGS += --trace
  SIM_ARGS += --trace
endif

.PHONY: all run build waves clean fw uart blinky quick

all: run

# Build firmware first, then the simulation executable
fw:
	$(MAKE) -C $(FW_DIR) $(FW_TARGET)

build: fw $(EXE)

$(EXE): sim_main.cpp sim_tb.sv $(RTL_SRCS) Makefile
	@echo "[VERILATOR] Verilating $(TOP)..."
	verilator --cc $(VERILATOR_FLAGS) $(RTL_SRCS)
	@echo "[BUILD] Compiling C++ model..."
	$(MAKE) -C obj_dir -f V$(TOP).mk CXX=g++ OBJCACHE= VM_PARALLEL_BUILDS=1
	@ln -sf obj_dir/V$(TOP) $(EXE)

run: build
	@echo "[SIM] Running $(EXE) with $(FW_TARGET) firmware..."
	MEMFILE=$(MEMFILE) ./$(EXE) $(SIM_ARGS)

waves: TRACE=1
waves: run

# Convenience: build + run with specific firmware
uart: FW_TARGET=uart_hello
uart: build run

blinky: FW_TARGET=blinky
blinky: build run

freertos: FW_TARGET=freertos
freertos: build run

clean:
	rm -rf obj_dir V$(TOP) waves.vcd
