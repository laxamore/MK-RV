import os
import pytest
from cocotb_test.simulator import run

# We use pytest.mark.parametrize to tell Pytest to run this wrapper function
# multiple times, once for each specific Cocotb test we want to execute.
@pytest.mark.parametrize("cocotb_testcase", [
    "test_bram_region_write",
    "test_uart_region_write",
    "test_unmapped_hardware_fault",
    "test_bram_region_read",
    "test_byte_select_routing",
    "test_wait_states_routing"
])
def test_wishbone_bus(cocotb_testcase):
    """
    This Pytest runner will now be executed 3 separate times by Pytest.
    Each time, it will tell Cocotb to run ONLY the specific testcase.
    """
    
    current_dir = os.path.dirname(os.path.abspath(__file__))
    rtl_dir = os.path.abspath(os.path.join(current_dir, "..", "rtl"))
    
    run(
        verilog_sources=[
            os.path.join(rtl_dir, "wb_crossbar.sv"),
            os.path.join(rtl_dir, "wb_crossbar_wrapper.sv"),
            os.path.join(current_dir, "tb_wb_crossbar.sv")
        ],
        toplevel="tb_wb_crossbar",
        module="test_wb_bus",
        
        # This is the magic line! It tells Cocotb to only run this specific test.
        testcase=cocotb_testcase, 
        
        simulator="verilator",
        extra_args=["--trace", "--trace-fst", "-Wno-fatal"]
    )
