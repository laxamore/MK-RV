`timescale 1ns / 1ps

module tb_mk_rv_serv_soc (
    input logic clk_i,
    input logic rst_i
);

  // UART loopback (rx connected to tx for echo test)
  logic uart_rx;
  logic uart_tx;

  // GPIO — drive inputs, observe outputs
  logic [7:0] gpio_in;
  logic [7:0] gpio_out;
  logic [7:0] gpio_dir;

  logic timer_irq;

  initial begin
    gpio_in = 8'h00;
  end

  mk_rv_serv_soc #(
      .W(),
      .WITH_CSR(),
      .WITH_MDU(),
      .WITH_C(),
      .MEMFILE(""),
      .MEM_DEPTH()
  ) dut (
      .clk_i(clk_i),
      .rst_i(rst_i),
      .uart_rx_i(uart_rx),
      .uart_tx_o(uart_tx),
      .gpio_in_i(gpio_in),
      .gpio_out_o(gpio_out),
      .gpio_dir_o(gpio_dir),
      .timer_irq_o(timer_irq)
  );

  initial begin
    $dumpfile("tb_mk_rv_serv_soc.vcd");
    $dumpvars(0, tb_mk_rv_serv_soc);
  end

endmodule
