import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.wishbone.driver import WishboneMaster, WBOp
from cocotbext.uart import UartSource, UartSink

UART_TXDATA = 0x00
UART_RXDATA = 0x04
UART_STATUS = 0x08
UART_CTRL   = 0x0C

async def setup_dut(dut):
    # 50 MHz Clock -> 20ns period
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
    
    # 50MHz / 434 = 115207 Baud (Close enough to 115200 for VIP!)
    uart_source = UartSource(dut.rx_i, baud=115207, bits=8)
    uart_sink   = UartSink(dut.tx_o, baud=115207, bits=8)
    
    dut.rst_i.value = 1
    await Timer(100, units="ns")
    dut.rst_i.value = 0
    await RisingEdge(dut.clk_i)
    
    return wb_master, uart_source, uart_sink

@cocotb.test()
async def test_uart_tx(dut):
    """Test CPU writing to TX FIFO and hardware shifting it out via serial."""
    wb_master, uart_source, uart_sink = await setup_dut(dut)
    
    # Write a burst of data to the TX FIFO
    test_string = b"HELLO"
    for char in test_string:
        await wb_master.send_cycle([WBOp(adr=UART_TXDATA, dat=char)])
        
    # Wait for the physical serial traffic to be received by the VIP
    rx_data = bytearray()
    for _ in range(len(test_string)):
        byte = await uart_sink.read(1)
        rx_data.extend(byte)
    
    assert rx_data == test_string, f"Expected {test_string}, got {rx_data}"

@cocotb.test()
async def test_uart_rx(dut):
    """Test external hardware sending serial data and CPU reading it from RX FIFO."""
    wb_master, uart_source, uart_sink = await setup_dut(dut)
    
    # Send physical serial data into the RX pin
    test_string = b"WORLD"
    await uart_source.write(test_string)
    
    # Wait for the transmission to physically complete
    await uart_source.wait()
    
    # Give the IP a few clock cycles to latch the stop bit into the FIFO
    for _ in range(10):
        await RisingEdge(dut.clk_i)
    
    # Verify STATUS register shows RX FIFO is not empty (Bit 1 = 0)
    status_res = await wb_master.send_cycle([WBOp(adr=UART_STATUS)])
    rx_empty = (int(status_res[0].datrd) >> 1) & 1
    assert rx_empty == 0, "STATUS register incorrectly reports RX FIFO as empty!"
    
    # Read the data back out over the Wishbone bus
    rx_bytes = bytearray()
    for _ in range(len(test_string)):
        res = await wb_master.send_cycle([WBOp(adr=UART_RXDATA)])
        rx_bytes.append(int(res[0].datrd) & 0xFF)
        
    assert rx_bytes == test_string, f"Expected {test_string}, got {rx_bytes}"

@cocotb.test()
async def test_uart_status_flags(dut):
    """Verify that TX_IDLE and TX_FULL flags behave correctly."""
    wb_master, uart_source, uart_sink = await setup_dut(dut)
    
    # Check initial status (should be Idle and Empty)
    res = await wb_master.send_cycle([WBOp(adr=UART_STATUS)])
    tx_idle = (int(res[0].datrd) >> 2) & 1
    assert tx_idle == 1, "Should be TX_IDLE on reset"
    
    # Fill the 8-byte TX FIFO + 1 byte in the active shift register (Total 9 bytes)
    for i in range(9):
        await wb_master.send_cycle([WBOp(adr=UART_TXDATA, dat=i)])
        
    # Verify TX_FULL flag (Bit 0) goes high
    res = await wb_master.send_cycle([WBOp(adr=UART_STATUS)])
    tx_full = int(res[0].datrd) & 1
    assert tx_full == 1, "TX_FULL flag should be 1 after filling 9 bytes"
