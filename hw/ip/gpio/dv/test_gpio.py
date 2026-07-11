import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.wishbone.driver import WishboneMaster, WBOp

GPIO_DATA_OUT = 0x00
GPIO_DATA_IN  = 0x04
GPIO_DIR      = 0x08
GPIO_CTRL     = 0x0C

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
async def test_gpio_dir_init(dut):
    """After reset, DIR should read 0 (all inputs)."""
    wb_master = await setup_dut(dut)

    res = await wb_master.send_cycle([WBOp(adr=GPIO_DIR)])
    dir_val = int(res[0].datrd)
    assert dir_val == 0, f"DIR should be 0 on reset, got 0x{dir_val:08X}"

@cocotb.test()
async def test_gpio_dir_write(dut):
    """Write a direction mask and verify it latches."""
    wb_master = await setup_dut(dut)

    expected = 0x5A
    await wb_master.send_cycle([WBOp(adr=GPIO_DIR, dat=expected)])

    res = await wb_master.send_cycle([WBOp(adr=GPIO_DIR)])
    dir_val = int(res[0].datrd)
    assert dir_val == expected, f"Expected DIR=0x{expected:02X}, got 0x{dir_val:02X}"

@cocotb.test()
async def test_gpio_dir_byte_write(dut):
    """Verify byte-select writes only affect the target byte."""
    wb_master = await setup_dut(dut)

    await wb_master.send_cycle([WBOp(adr=GPIO_DIR, dat=0xFF)])

    await wb_master.send_cycle([WBOp(adr=GPIO_DIR, dat=0x00, sel=0x01)])

    res = await wb_master.send_cycle([WBOp(adr=GPIO_DIR)])
    dir_val = int(res[0].datrd)
    assert dir_val == 0x00, "Byte-select write to byte 0 failed"

@cocotb.test()
async def test_gpio_data_out_write(dut):
    """Write to DATA_OUT, verify latch and gpio_out port mirror the value."""
    wb_master = await setup_dut(dut)

    out_val = 0xA5
    await wb_master.send_cycle([WBOp(adr=GPIO_DATA_OUT, dat=out_val)])

    res = await wb_master.send_cycle([WBOp(adr=GPIO_DATA_OUT)])
    assert int(res[0].datrd) == out_val, "DATA_OUT latch mismatch"

    assert int(dut.gpio_out.value) == out_val, "gpio_out port mismatch"

@cocotb.test()
async def test_gpio_data_in_read(dut):
    """Stimulate gpio_in and verify DATA_IN reflects sampled value."""
    wb_master = await setup_dut(dut)

    dut.gpio_in.value = 0xAB

    res = await wb_master.send_cycle([WBOp(adr=GPIO_DATA_IN)])
    assert int(res[0].datrd) == 0xAB, "DATA_IN mismatch"

@cocotb.test()
async def test_gpio_data_out_bytes(dut):
    """Byte-select write to DATA_OUT should work with sel=0x01."""
    wb_master = await setup_dut(dut)

    await wb_master.send_cycle([WBOp(adr=GPIO_DATA_OUT, dat=0xFF)])

    await wb_master.send_cycle([WBOp(adr=GPIO_DATA_OUT, dat=0x00, sel=0x01)])

    res = await wb_master.send_cycle([WBOp(adr=GPIO_DATA_OUT)])
    assert int(res[0].datrd) == 0x00, "Byte-select write with sel=0x01 failed"

@cocotb.test()
async def test_gpio_full_flow(dut):
    """End-to-end: set pins to output, write pattern, verify ports.
       Then set pins to input, drive gpio_in, read DATA_IN."""
    wb_master = await setup_dut(dut)

    # 1. Set all pins to output
    await wb_master.send_cycle([WBOp(adr=GPIO_DIR, dat=0xFF)])

    # 2. Write output pattern
    await wb_master.send_cycle([WBOp(adr=GPIO_DATA_OUT, dat=0xAA)])

    await RisingEdge(dut.clk_i)

    # 3. Verify outputs
    assert int(dut.gpio_out.value) == 0xAA, "gpio_out mismatch"
    res = await wb_master.send_cycle([WBOp(adr=GPIO_DATA_OUT)])
    assert int(res[0].datrd) == 0xAA, "DATA_OUT latch mismatch"

    # 4. Set all pins to input, drive gpio_in, read DATA_IN
    await wb_master.send_cycle([WBOp(adr=GPIO_DIR, dat=0x00)])

    dut.gpio_in.value = 0x5A

    res = await wb_master.send_cycle([WBOp(adr=GPIO_DATA_IN)])
    assert int(res[0].datrd) == 0x5A, "DATA_IN mismatch"
