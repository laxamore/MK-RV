# Makefile for MK-RV Firmware (RISC-V cross-compilation)
# Produces .elf, .hex, .bin, and .mem (Verilog $readmemh format)

CROSS   ?= riscv64-unknown-elf-
CC      := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump
SIZE    := $(CROSS)size

ARCH    := rv32i_zicsr
ABI     := ilp32

FREERTOS_DIR = lib/FreeRTOS-Kernel
FREERTOS_SRC += \
        $(FREERTOS_DIR)/tasks.c \
        $(FREERTOS_DIR)/queue.c \
        $(FREERTOS_DIR)/list.c \
        $(FREERTOS_DIR)/timers.c \
        $(FREERTOS_DIR)/portable/MemMang/heap_4.c \
        $(FREERTOS_DIR)/portable/GCC/RISC-V/port.c \
        $(FREERTOS_DIR)/portable/GCC/RISC-V/portASM.S

CFLAGS 	:= -march=$(ARCH) -mabi=$(ABI) --specs=picolibc.specs -O3 -T link.ld
CFLAGS  += -DPICOLIBC_MINIMAL_PRINTF_SCANF
CFLAGS  += -Wall -Wextra -Werror -Wno-unused-parameter
CFLAGS  += -I.

# Default firmware
TARGET  ?= blinky

SRCS    := $(TARGET)/$(TARGET).c
ELF     := $(addprefix build/,$(SRCS:.c=.elf))
HEX     := build/$(TARGET)/$(TARGET).hex
BIN     := build/$(TARGET)/$(TARGET).bin
MEM     := build/$(TARGET)/$(TARGET).mem
LST     := build/$(TARGET)/$(TARGET).lst

.PHONY: fw clean size

fw: $(ELF) $(HEX) $(BIN) $(MEM) $(LST)

build/%.elf: %.S build/$(TARGET)
	$(CC) $(CFLAGS) -o $@ $<

build/%.elf: %.c build/$(TARGET)
	$(CC) $(CFLAGS) -o $@ $<

$(HEX): $(ELF)
	$(OBJCOPY) -O ihex $< $@

$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

$(LST): $(ELF)
	$(OBJDUMP) -d $< > $@

# $readmemh-compatible hex file (one 32-bit word per line, big-endian byte order)
$(MEM): $(BIN)
	python3 ../hw/ip/serv/sw/makehex.py $< > $@

build/$(TARGET):
	mkdir -p build/$(TARGET)

build/freertos:
	mkdir -p build/freertos

size: $(ELF)
	$(SIZE) $<

clean:
	rm -rf build

.PHONY: all blinky uart_hello freertos

all: blinky uart_hello freertos

blinky:
	$(MAKE) TARGET=blinky fw

uart_hello:
	$(MAKE) TARGET=uart_hello fw

freertos_elf: build/freertos
	$(CC) $(CFLAGS) -o build/freertos/freertos.elf \
	  freertos/rtos_main.c $(FREERTOS_SRC) \
		-I./freertos \
		-I$(FREERTOS_DIR)/include \
		-I$(FREERTOS_DIR)/portable/GCC/RISC-V \
		-I$(FREERTOS_DIR)/portable/GCC/RISC-V/chip_specific_extensions/RISCV_MTIME_CLINT_no_extensions

freertos_fw: freertos_elf $(HEX) $(BIN) $(MEM) $(LST)

freertos:
	$(MAKE) TARGET=freertos freertos_fw