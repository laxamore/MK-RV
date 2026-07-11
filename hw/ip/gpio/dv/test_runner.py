import os
import pytest
from cocotb_test.simulator import run

@pytest.mark.parametrize("cocotb_testcase", [
    "test_gpio_dir_init",
    "test_gpio_dir_write",
    "test_gpio_dir_byte_write",
    "test_gpio_data_out_write",
    "test_gpio_data_in_read",
    "test_gpio_data_out_bytes",
    "test_gpio_full_flow",
])
def test_gpio(cocotb_testcase):
    current_dir = os.path.dirname(os.path.abspath(__file__))
    rtl_dir = os.path.join(current_dir, "..", "rtl")

    # Source files to compile
    verilog_sources = [
        os.path.join(rtl_dir, "gpio_wb_slave.sv"),
        os.path.join(current_dir, "tb_gpio_wb_slave.sv"),
    ]

    # Run the simulation
    run(
        verilog_sources=verilog_sources,
        toplevel="tb_gpio_wb_slave",
        module="test_gpio",
        testcase=cocotb_testcase,
        simulator="verilator",
        extra_args=["--trace", "--trace-fst", "-Wno-fatal"],
    )
