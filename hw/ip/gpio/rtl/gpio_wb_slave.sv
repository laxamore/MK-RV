`timescale 1ns / 1ps

module gpio_wb_slave #(
    parameter integer GPIO_WIDTH = 32
) (
    input logic clk_i,
    input logic rst_i,

    // Wishbone Slave Interface
    input  logic [31:0] wb_adr_i,
    input  logic [31:0] wb_dat_i,
    input  logic [ 3:0] wb_sel_i,
    input  logic        wb_we_i,
    input  logic        wb_cyc_i,
    input  logic        wb_stb_i,
    output logic [31:0] wb_dat_o,
    output logic        wb_ack_o,
    output logic        wb_err_o,

    // Physical I/O Ports (Tristate mux belongs in the chip pad-frame)
    input  logic [GPIO_WIDTH-1:0] gpio_in,
    output logic [GPIO_WIDTH-1:0] gpio_out,
    output logic [GPIO_WIDTH-1:0] gpio_dir
);

  // =========================================================================
  // GPIO MMIO Register Map (8-bit, zero-extended to 32-bit Wishbone)
  // =========================================================================
  // 0x00 : GPIO_DATA_OUT (R/W)  - Write to drive outputs, read back value
  // 0x04 : GPIO_DATA_IN  (R)    - Read actual pin state
  // 0x08 : GPIO_DIR      (R/W)  - 1=output, 0=input

  logic [GPIO_WIDTH-1:0] data_out_reg;
  logic [GPIO_WIDTH-1:0] dir_reg;

  logic valid_access;

  assign valid_access = wb_cyc_i && wb_stb_i;
  assign wb_ack_o     = valid_access;
  assign wb_err_o     = 1'b0;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      data_out_reg <= '0;
      dir_reg      <= '0;
    end else if (valid_access && wb_we_i) begin
      unique case (wb_adr_i[3:2])
        2'h0:    if (wb_sel_i[0]) data_out_reg <= wb_dat_i[7:0];
        2'h2:    if (wb_sel_i[0]) dir_reg <= wb_dat_i[7:0];
        default: ;
      endcase
    end
  end

  // Narrow read-data mux
  logic [7:0] rd_dat;
  always_comb begin
    unique case (wb_adr_i[3:2])
      2'h0: rd_dat = data_out_reg;
      2'h1: rd_dat = gpio_in;
      2'h2: rd_dat = dir_reg;
      default: rd_dat = '0;
    endcase
  end

  assign wb_dat_o = (valid_access && !wb_we_i) ? rd_dat : '0;

  assign gpio_out = data_out_reg;
  assign gpio_dir = dir_reg;

endmodule
