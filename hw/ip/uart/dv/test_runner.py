import os
import pytest
from cocotb_test.simulator import run

@pytest.mark.parametrize("cocotb_testcase", [
    "test_uart_tx",
    "test_uart_rx",
    "test_uart_status_flags"
])
def test_uart(cocotb_testcase):
    current_dir = os.path.dirname(os.path.abspath(__file__))
    rtl_dir = os.path.join(current_dir, "..", "rtl")

    # Source files to compile
    verilog_sources = [
        os.path.join(rtl_dir, "sync_fifo.sv"),
        os.path.join(rtl_dir, "uart_tx.sv"),
        os.path.join(rtl_dir, "uart_rx.sv"),
        os.path.join(rtl_dir, "uart_wb_slave.sv"),
        os.path.join(current_dir, "tb_uart_wb_slave.sv")
    ]

    # Run the simulation
    run(
        verilog_sources=verilog_sources,
        toplevel="tb_uart_wb_slave",
        module="test_uart",
        testcase=cocotb_testcase,
        simulator="verilator",
        extra_args=["--trace", "--trace-fst", "-Wno-fatal"]
    )
