`timescale 1ns / 1ps

module tb_gpio_wb_slave (
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

  logic [ 7:0] gpio_in;
  logic [ 7:0] gpio_out;
  logic [ 7:0] gpio_dir;

  initial begin
    wb_adr_i = 0;
    wb_dat_i = 0;
    wb_sel_i = 0;
    wb_we_i  = 0;
    wb_cyc_i = 0;
    wb_stb_i = 0;
    gpio_in  = 8'h00;
  end

  gpio_wb_slave #(
      .GPIO_WIDTH(8)
  ) dut (
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
      .gpio_in(gpio_in),
      .gpio_out(gpio_out),
      .gpio_dir(gpio_dir)
  );

  initial begin
    $dumpfile("tb_gpio_wb_slave.vcd");
    $dumpvars(0, tb_gpio_wb_slave);
  end

endmodule
