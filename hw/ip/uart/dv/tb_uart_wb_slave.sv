`timescale 1ns / 1ps

module tb_uart_wb_slave (
    input logic clk_i,
    input logic rst_i
);
  // Wishbone interface
  logic [31:0] wb_adr_i;
  logic [31:0] wb_dat_i;
  logic [ 3:0] wb_sel_i;
  logic        wb_we_i;
  logic        wb_cyc_i;
  logic        wb_stb_i;
  logic [31:0] wb_dat_o;
  logic        wb_ack_o;
  logic        wb_err_o;

  // Physical pins
  logic        rx_i;
  logic        tx_o;

  initial begin
    wb_adr_i = 0;
    wb_dat_i = 0;
    wb_sel_i = 0;
    wb_we_i  = 0;
    wb_cyc_i = 0;
    wb_stb_i = 0;
    rx_i     = 1;  // Default UART idle is HIGH
  end

  uart_wb_slave dut (
      .clk_i(clk_i),
      .rst_i(rst_i),
      .wb_adr_i(wb_adr_i),
      .wb_dat_i(wb_dat_i),
      .wb_sel_i(wb_sel_i),
      .wb_we_i(wb_we_i),
      .wb_cyc_i(wb_cyc_i),
      .wb_stb_i(wb_stb_i),
      .wb_dat_o(wb_dat_o),
      .wb_ack_o(wb_ack_o),
      .wb_err_o(wb_err_o),
      .rx_i(rx_i),
      .tx_o(tx_o)
  );

`ifdef COCOTB_SIM
  initial begin
    $dumpfile("tb_uart_wb_slave.vcd");
    $dumpvars(0, tb_uart_wb_slave);
  end
`endif

endmodule
