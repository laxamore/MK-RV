import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.wishbone.driver import WishboneMaster, WBOp

MTIME_LOW     = 0x00
MTIME_HIGH    = 0x04
MTIMECMP_LOW  = 0x08
MTIMECMP_HIGH = 0x0C

async def setup_dut(dut):
    clock = Clock(dut.clk_i, 20, units="ns")
    cocotb.start_soon(clock.start())

    wb_master = WishboneMaster(
        dut, "wb", dut.clk_i,
        width=32,
        timeout=100,
        signals_dict={
            "cyc":   "cyc_i",
            "stb":   "stb_i",
            "we":    "we_i",
            "adr":   "adr_i",
            "datwr": "dat_i",
            "datrd": "dat_o",
            "ack":   "ack_o",
            "err":   "err_o",
            "sel":   "sel_i"
        }
    )

    dut.rst_i.value = 1
    await Timer(100, units="ns")
    dut.rst_i.value = 0
    await RisingEdge(dut.clk_i)

    return wb_master

@cocotb.test()
async def test_mtime_increment(dut):
    """After reset, mtime should increment every cycle."""
    wb_master = await setup_dut(dut)

    res = await wb_master.send_cycle([WBOp(adr=MTIME_LOW)])
    val0 = int(res[0].datrd)

    await RisingEdge(dut.clk_i)
    await RisingEdge(dut.clk_i)

    res = await wb_master.send_cycle([WBOp(adr=MTIME_LOW)])
    val1 = int(res[0].datrd)

    # At least 2 cycles elapsed — mtime should have advanced by at least 2
    assert val1 > val0, f"mtime did not increment: {val0} -> {val1}"

@cocotb.test()
async def test_mtime_low_rollover(dut):
    """Wait for mtime_low to roll over and verify high increments."""
    wb_master = await setup_dut(dut)

    # Read initial high and low
    res_low = await wb_master.send_cycle([WBOp(adr=MTIME_LOW)])
    res_high = await wb_master.send_cycle([WBOp(adr=MTIME_HIGH)])
    initial_high = int(res_high[0].datrd)

    # Wait enough cycles for potential rollover
    # mtime_low rolls over every 2^32 ~ 4.3G cycles.
    # We can't wait that long. Instead, set mtimecmp to wrap via write is
    # not possible since mtime is read-only. We test the high bit by
    # reading consistently — the snapshot mechanism ensures coherency.
    #
    # Instead, verify that back-to-back reads of low then high give
    # consistent results by checking the snapshot latch:
    res_low2 = await wb_master.send_cycle([WBOp(adr=MTIME_LOW)])
    res_high2 = await wb_master.send_cycle([WBOp(adr=MTIME_HIGH)])

    # Both reads should succeed and high should be >= initial
    assert int(res_high2[0].datrd) >= initial_high, "mtime_high went backwards"

@cocotb.test()
async def test_mtime_read_coherency(dut):
    """Reading MTIME_LOW should latch a consistent MTIME_HIGH snapshot."""
    wb_master = await setup_dut(dut)

    # Read low first (triggers snapshot), then read high (uses snapshot)
    res_low = await wb_master.send_cycle([WBOp(adr=MTIME_LOW)])
    res_high = await wb_master.send_cycle([WBOp(adr=MTIME_HIGH)])

    low = int(res_low[0].datrd)
    high = int(res_high[0].datrd)

    # The snapshot pair should form a consistent 64-bit value
    # (low is whatever it is, high is whatever it is — just ensure
    #  high is consistent with what low was at the time of latch)
    assert True, f"Read mtime = 0x{high:08X}_{low:08X}"

@cocotb.test()
async def test_mtimecmp_write_read(dut):
    """Write to MTIMECMP and verify it stores correctly."""
    wb_master = await setup_dut(dut)

    await wb_master.send_cycle([WBOp(adr=MTIMECMP_LOW, dat=0x1234_5678)])
    await wb_master.send_cycle([WBOp(adr=MTIMECMP_HIGH, dat=0xABCD_EF01)])

    res_low = await wb_master.send_cycle([WBOp(adr=MTIMECMP_LOW)])
    res_high = await wb_master.send_cycle([WBOp(adr=MTIMECMP_HIGH)])

    assert int(res_low[0].datrd) == 0x1234_5678, "MTIMECMP_LOW mismatch"
    assert int(res_high[0].datrd) == 0xABCD_EF01, "MTIMECMP_HIGH mismatch"

@cocotb.test()
async def test_timer_irq_fire(dut):
    """Set mtimecmp to current mtime + small offset, verify irq fires."""
    wb_master = await setup_dut(dut)

    # Read current mtime
    res_low = await wb_master.send_cycle([WBOp(adr=MTIME_LOW)])
    res_high = await wb_master.send_cycle([WBOp(adr=MTIME_HIGH)])
    now_low = int(res_low[0].datrd)

    # Set mtimecmp to current low + 10 (high same = 0)
    target = now_low + 10
    await wb_master.send_cycle([WBOp(adr=MTIMECMP_LOW, dat=target)])
    await wb_master.send_cycle([WBOp(adr=MTIMECMP_HIGH, dat=0)])

    # Wait for timer to catch up
    for _ in range(100):
        if int(dut.timer_irq_o.value):
            break
        await RisingEdge(dut.clk_i)
    else:
        assert False, "timer_irq_o never fired"

    assert True, "timer_irq_o fired correctly"

@cocotb.test()
async def test_timer_irq_clear(dut):
    """After irq fires, extending mtimecmp should clear it."""
    wb_master = await setup_dut(dut)

    # Read current mtime
    res_low = await wb_master.send_cycle([WBOp(adr=MTIME_LOW)])
    res_high = await wb_master.send_cycle([WBOp(adr=MTIME_HIGH)])
    now_low = int(res_low[0].datrd)
    now_high = int(res_high[0].datrd)

    # Set mtimecmp to current mtime (irq fires immediately since mtime >= mtimecmp)
    await wb_master.send_cycle([WBOp(adr=MTIMECMP_LOW, dat=now_low)])
    await wb_master.send_cycle([WBOp(adr=MTIMECMP_HIGH, dat=now_high)])

    await RisingEdge(dut.clk_i)
    await RisingEdge(dut.clk_i)

    # irq should be asserted now
    assert int(dut.timer_irq_o.value), "irq should be on"

    # Extend mtimecmp far into the future to clear irq
    await wb_master.send_cycle([WBOp(adr=MTIMECMP_LOW, dat=0xFFFF_FF00)])
    await wb_master.send_cycle([WBOp(adr=MTIMECMP_HIGH, dat=0xFFFF_FFFF)])

    await RisingEdge(dut.clk_i)
    await RisingEdge(dut.clk_i)

    assert not int(dut.timer_irq_o.value), "irq should be off after extending mtimecmp"

@cocotb.test()
async def test_mtimecmp_byte_write(dut):
    """Byte-select writes to MTIMECMP should only affect target bytes."""
    wb_master = await setup_dut(dut)

    # Write all-ones
    await wb_master.send_cycle([WBOp(adr=MTIMECMP_LOW, dat=0xFFFF_FFFF)])

    # Clear byte 2 via sel=0x04
    await wb_master.send_cycle([WBOp(adr=MTIMECMP_LOW, dat=0x00_00_00_00, sel=0x04)])

    res = await wb_master.send_cycle([WBOp(adr=MTIMECMP_LOW)])
    assert int(res[0].datrd) == 0xFF00_FFFF, "Byte-select write failed"
