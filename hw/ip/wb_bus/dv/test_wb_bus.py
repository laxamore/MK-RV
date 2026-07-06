import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.wishbone.driver import WishboneMaster, WBOp

# ==============================================================================
# Helper Functions
# ==============================================================================

async def setup_dut(dut):
    """Starts the clock, resets the DUT, and returns a configured WishboneMaster."""
    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    wb_master = WishboneMaster(
        dut, "", dut.clk_i,
        width=32,
        timeout=100, # Increased timeout to handle wait-states safely
        signals_dict={
            "cyc":   "m_wb_cyc_i",
            "stb":   "m_wb_stb_i",
            "we":    "m_wb_we_i",
            "adr":   "m_wb_adr_i",
            "datwr": "m_wb_dat_i",
            "datrd": "m_wb_dat_o",
            "ack":   "m_wb_ack_o",
            "err":   "m_wb_err_o",
            "sel":   "m_wb_sel_i"
        }
    )
    
    dut.rst_i.value = 1
    await Timer(20, units="ns")
    dut.rst_i.value = 0
    await RisingEdge(dut.clk_i)
    
    # Pre-clear all slave returning signals
    for i in range(5):
        getattr(dut, f"s{i}_wb_ack_i").value = 0
        getattr(dut, f"s{i}_wb_err_i").value = 0
        getattr(dut, f"s{i}_wb_dat_i").value = 0
    
    return wb_master

async def generic_mock_slave(dut, name, slave_idx, expected_adr=None, expected_datwr=None, expected_sel=None, return_datrd=0x0, wait_cycles=0):
    """A highly configurable mock slave for strict verification coverage."""
    cyc_sig   = getattr(dut, f"s{slave_idx}_wb_cyc_o")
    stb_sig   = getattr(dut, f"s{slave_idx}_wb_stb_o")
    ack_sig   = getattr(dut, f"s{slave_idx}_wb_ack_i")
    adr_sig   = getattr(dut, f"s{slave_idx}_wb_adr_o")
    datwr_sig = getattr(dut, f"s{slave_idx}_wb_dat_o")
    datrd_sig = getattr(dut, f"s{slave_idx}_wb_dat_i")
    sel_sig   = getattr(dut, f"s{slave_idx}_wb_sel_o")
    we_sig    = getattr(dut, f"s{slave_idx}_wb_we_o")
    
    while True:
        await RisingEdge(dut.clk_i)
        
        # Guard against unresolvable states (X/Z) at startup
        try:
            cyc = int(cyc_sig.value)
            stb = int(stb_sig.value)
        except ValueError:
            continue
            
        if cyc == 1 and stb == 1:
            
            # 1. Assert Forwarding Correctness
            if expected_adr is not None:
                assert int(adr_sig.value) == expected_adr, f"{name} Address mismatch: {hex(int(adr_sig.value))} != {hex(expected_adr)}"
            if int(we_sig.value) == 1 and expected_datwr is not None:
                assert int(datwr_sig.value) == expected_datwr, f"{name} Write Data mismatch: {hex(int(datwr_sig.value))} != {hex(expected_datwr)}"
            if expected_sel is not None:
                assert int(sel_sig.value) == expected_sel, f"{name} SEL mismatch: {bin(int(sel_sig.value))} != {bin(expected_sel)}"

            # 2. Emulate Wait States (Latency)
            for _ in range(wait_cycles):
                await RisingEdge(dut.clk_i)
                
            # 3. Drive Response
            datrd_sig.value = return_datrd
            ack_sig.value = 1
            await RisingEdge(dut.clk_i)
            
            # 4. De-assert Response
            ack_sig.value = 0
            datrd_sig.value = 0
        else:
            try:
                ack_sig.value = 0
                datrd_sig.value = 0
            except ValueError:
                pass


# ==============================================================================
# Independent Tests
# ==============================================================================

@cocotb.test()
async def test_bram_region_write(dut):
    """Test standard write routing to Slave 0 (BRAM)"""
    wb_master = await setup_dut(dut)
    cocotb.start_soon(generic_mock_slave(dut, "BRAM", 0, expected_adr=0x0000_1000, expected_datwr=0xDEADBEEF))
    await wb_master.send_cycle([WBOp(adr=0x0000_1000, dat=0xDEADBEEF)])
    assert int(dut.s1_wb_cyc_o.value) == 0, "UART should not be selected"

@cocotb.test()
async def test_uart_region_write(dut):
    """Test standard write routing to Slave 1 (UART)"""
    wb_master = await setup_dut(dut)
    cocotb.start_soon(generic_mock_slave(dut, "UART", 1, expected_adr=0x4000_0000, expected_datwr=0xCAFEBABE))
    await wb_master.send_cycle([WBOp(adr=0x4000_0000, dat=0xCAFEBABE)])
    assert int(dut.s0_wb_cyc_o.value) == 0, "BRAM should not be selected"

@cocotb.test()
async def test_unmapped_hardware_fault(dut):
    """Test that accessing an unmapped region instantly throws an error."""
    _ = await setup_dut(dut)
    dut.m_wb_adr_i.value = 0x8000_0000
    dut.m_wb_cyc_i.value = 1
    dut.m_wb_stb_i.value = 1
    await RisingEdge(dut.clk_i)
    assert int(dut.m_wb_err_o.value) == 1, "Unmapped region did not throw m_wb_err_o!"
    dut.m_wb_cyc_i.value = 0
    dut.m_wb_stb_i.value = 0

@cocotb.test()
async def test_bram_region_read(dut):
    """Test that data returning from a Slave reaches the Master (datrd_o validation)."""
    wb_master = await setup_dut(dut)
    # Configure mock BRAM to return a specific magic number when read
    cocotb.start_soon(generic_mock_slave(dut, "BRAM", 0, expected_adr=0x0000_2000, return_datrd=0x11223344))
    
    # Send a read request (no 'dat' argument means read)
    res = await wb_master.send_cycle([WBOp(adr=0x0000_2000)])
    
    # Verify the master successfully received the data through the crossbar MUX
    assert res[0].datrd == 0x11223344, f"Read data failed to route back! Got {hex(res[0].datrd)}"

@cocotb.test()
async def test_byte_select_routing(dut):
    """Test that the sel_i (byte select) lines correctly route to the slaves for SB/SH operations."""
    wb_master = await setup_dut(dut)
    
    # Expect the UART to receive sel = 0b0001 (writing only to the lowest byte)
    cocotb.start_soon(generic_mock_slave(dut, "UART", 1, expected_sel=0b0001))
    
    # Send a transaction with explicit byte selection
    await wb_master.send_cycle([WBOp(adr=0x4000_0000, dat=0xAA, sel=0b0001)])

@cocotb.test()
async def test_wait_states_routing(dut):
    """Test that the crossbar successfully holds the connection open for slow peripherals."""
    wb_master = await setup_dut(dut)
    
    # We will use Slave 2 (GPIO - 0x4000_1000) and tell it to wait 5 clock cycles before acknowledging
    cocotb.start_soon(generic_mock_slave(dut, "GPIO", 2, wait_cycles=5))
    
    # If the crossbar doesn't handle wait states, this VIP call will timeout or fail
    await wb_master.send_cycle([WBOp(adr=0x4000_1000, dat=0x12345678)])
    
    # If we made it here without an exception, the wait state successfully held the bus!
    assert True
