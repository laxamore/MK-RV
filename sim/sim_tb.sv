// sim_tb.sv — Verilog testbench wrapper for standalone C++ simulation
// Provides a top-level Verilog module that the C++ sim_main drives.
// The C++ code controls all I/O pins and preloads boot RAM via VPI.
//
// This is the "DUT wrapper" that Verilator compiles into the Vmcu_top class.
// The actual testbench logic (clock, reset, monitoring) is in sim_main.cpp.

`default_nettype none
`timescale 1ns / 1ps

module tb_mk_rv_serv_sim #(
    parameter MEMFILE = ""
) (
    input  wire       clk,
    input  wire       rst,
    // GPIO
    input  wire [7:0] gpio_in,
    output wire [7:0] gpio_out,
    output wire [7:0] gpio_dir,
    // UART
    input  wire       uart_rx,
    output wire       uart_tx,
    // Timer
    output wire       timer_irq
);

  mk_rv_serv_soc #(
      .W(),
      .WITH_CSR(),
      .WITH_MDU(),
      .WITH_C(),
      .RESET_STRATEGY(),
      .MEMFILE(MEMFILE),
      .MEM_DEPTH()
  ) dut (
      .clk_i(clk),
      .rst_i(rst),
      .uart_rx_i(uart_rx),
      .uart_tx_o(uart_tx),
      .gpio_in_i(gpio_in),
      .gpio_out_o(gpio_out),
      .gpio_dir_o(gpio_dir),
      .timer_irq_o(timer_irq)
  );

endmodule
`default_nettype wire
