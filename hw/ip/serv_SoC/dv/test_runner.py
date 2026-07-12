import os
import pytest
from cocotb_test.simulator import run

# Root of the project
PROJ_ROOT = os.path.dirname(os.path.abspath(__file__))
while not os.path.exists(os.path.join(PROJ_ROOT, "fusesoc.conf")):
    PROJ_ROOT = os.path.dirname(PROJ_ROOT)

SERV_DIR   = os.path.join(PROJ_ROOT, "hw", "ip", "serv")
SOC_DIR    = os.path.join(PROJ_ROOT, "hw", "ip", "serv_SoC")
UART_DIR   = os.path.join(PROJ_ROOT, "hw", "ip", "uart")
GPIO_DIR   = os.path.join(PROJ_ROOT, "hw", "ip", "gpio")
TIMER_DIR  = os.path.join(PROJ_ROOT, "hw", "ip", "timer")
WB_BUS_DIR = os.path.join(PROJ_ROOT, "hw", "ip", "wb_bus")
FW_DIR     = os.path.join(PROJ_ROOT, "fw")

MEMFILE = os.path.join(FW_DIR, "build", "blinky", "blinky.mem")

# Collect all RTL sources
verilog_sources = []
for d, subdirs, files in os.walk(os.path.join(SERV_DIR, "rtl")):
    for f in files:
        if f.endswith(".v") and "synth_wrapper" not in f:
            verilog_sources.append(os.path.join(d, f))
for d, subdirs, files in os.walk(os.path.join(SERV_DIR, "servile")):
    for f in files:
        if f.endswith(".v"):
            verilog_sources.append(os.path.join(d, f))
for d, subdirs, files in os.walk(os.path.join(SOC_DIR, "rtl")):
    for f in files:
        if f.endswith(".sv"):
            verilog_sources.append(os.path.join(d, f))
for d, subdirs, files in os.walk(os.path.join(UART_DIR, "rtl")):
    for f in files:
        if f.endswith(".sv"):
            verilog_sources.append(os.path.join(d, f))
for d, subdirs, files in os.walk(os.path.join(GPIO_DIR, "rtl")):
    for f in files:
        if f.endswith(".sv"):
            verilog_sources.append(os.path.join(d, f))
for d, subdirs, files in os.walk(os.path.join(TIMER_DIR, "rtl")):
    for f in files:
        if f.endswith(".sv"):
            verilog_sources.append(os.path.join(d, f))
for d, subdirs, files in os.walk(os.path.join(WB_BUS_DIR, "rtl")):
    for f in files:
        if f.endswith(".sv"):
            verilog_sources.append(os.path.join(d, f))

# Add the testbench
verilog_sources.append(os.path.join(SOC_DIR, "dv", "tb_mk_rv_serv_soc.sv"))

VERILATOR_ARGS = [
    "--trace",
    "--trace-fst",
    "-Wno-fatal",
    "-Wno-WIDTH",
    "-Wno-CASEOVERLAP",
    "-Wno-CASEX",
    "-Wno-BLKANDNBLK",
    "-Wno-UNOPTFLAT",
    "-Wno-UNSIGNED",
    "-Wno-PINCONNECTEMPTY",
    "-Wno-MODDUP",
    "-Wno-TIMESCALEMOD",
]


@pytest.mark.parametrize("cocotb_testcase", [
    "test_soc_boots",
    "test_reset_initial_state",
])
def test_mk_rv_serv_soc(cocotb_testcase):
    env = os.environ.copy()
    env["MEMFILE"] = MEMFILE
    run(
        verilog_sources=verilog_sources,
        toplevel="tb_mk_rv_serv_soc",
        module="test_mk_rv_serv_soc",
        testcase=cocotb_testcase,
        simulator="verilator",
        extra_args=VERILATOR_ARGS,
        waves=True,
        env=env,
    )


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
