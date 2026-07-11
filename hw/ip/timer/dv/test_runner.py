import os
import pytest
from cocotb_test.simulator import run

@pytest.mark.parametrize("cocotb_testcase", [
    "test_mtime_increment",
    "test_mtime_low_rollover",
    "test_mtime_read_coherency",
    "test_mtimecmp_write_read",
    "test_timer_irq_fire",
    "test_timer_irq_clear",
    "test_mtimecmp_byte_write",
])
def test_timer(cocotb_testcase):
    current_dir = os.path.dirname(os.path.abspath(__file__))
    rtl_dir = os.path.join(current_dir, "..", "rtl")

    verilog_sources = [
        os.path.join(rtl_dir, "timer_wb_slave.sv"),
        os.path.join(current_dir, "tb_timer_wb_slave.sv"),
    ]

    run(
        verilog_sources=verilog_sources,
        toplevel="tb_timer_wb_slave",
        module="test_timer",
        testcase=cocotb_testcase,
        simulator="verilator",
        extra_args=["--trace", "--trace-fst", "-Wno-fatal"],
    )
