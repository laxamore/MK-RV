`timescale 1ns / 1ps

module timer_wb_slave (
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

    // Interrupt output to CPU trap engine
    output logic timer_irq_o
);

  // =========================================================================
  // Timer MMIO Register Map
  // =========================================================================
  // 0x00 : MTIME_LOW     (R)   - Lower 32 bits of free-running counter
  // 0x04 : MTIME_HIGH    (R)   - Upper 32 bits of free-running counter
  // 0x08 : MTIMECMP_LOW  (R/W) - Lower 32 bits of compare value
  // 0x0C : MTIMECMP_HIGH (R/W) - Upper 32 bits of compare value

  logic [31:0] mtime_low;
  logic [31:0] mtime_high;
  logic [31:0] mtimecmp_low;
  logic [31:0] mtimecmp_high;

  logic valid_access;

  assign valid_access = wb_cyc_i && wb_stb_i;
  assign wb_ack_o     = valid_access;
  assign wb_err_o     = 1'b0;

  // Free-running 64-bit counter
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      mtime_low  <= '0;
      mtime_high <= '0;
    end else begin
      {mtime_high, mtime_low} <= {mtime_high, mtime_low} + 64'd1;
    end
  end

  // mtimecmp registers (write-only)
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      mtimecmp_low  <= '0;
      mtimecmp_high <= '0;
    end else if (valid_access && wb_we_i) begin
      unique case (wb_adr_i[3:2])
        2'h2: begin
          if (wb_sel_i[0]) mtimecmp_low[7:0] <= wb_dat_i[7:0];
          if (wb_sel_i[1]) mtimecmp_low[15:8] <= wb_dat_i[15:8];
          if (wb_sel_i[2]) mtimecmp_low[23:16] <= wb_dat_i[23:16];
          if (wb_sel_i[3]) mtimecmp_low[31:24] <= wb_dat_i[31:24];
        end
        2'h3: begin
          if (wb_sel_i[0]) mtimecmp_high[7:0] <= wb_dat_i[7:0];
          if (wb_sel_i[1]) mtimecmp_high[15:8] <= wb_dat_i[15:8];
          if (wb_sel_i[2]) mtimecmp_high[23:16] <= wb_dat_i[23:16];
          if (wb_sel_i[3]) mtimecmp_high[31:24] <= wb_dat_i[31:24];
        end
        default: ;
      endcase
    end
  end

  // Combinational read-data mux
  always_comb begin
    wb_dat_o = '0;
    if (valid_access && !wb_we_i) begin
      unique case (wb_adr_i[3:2])
        2'h0: wb_dat_o = mtime_low;
        2'h1: wb_dat_o = mtime_high;
        2'h2: wb_dat_o = mtimecmp_low;
        2'h3: wb_dat_o = mtimecmp_high;
        default: ;
      endcase
    end
  end

  // Combinational 64-bit compare: mtime >= mtimecmp
  // Split into high/low to avoid a full 64-bit carry chain.
  logic high_gt;
  logic high_eq;
  logic low_ge;
  assign high_gt   = (mtime_high >  mtimecmp_high);
  assign high_eq   = (mtime_high == mtimecmp_high);
  assign low_ge    = (mtime_low  >= mtimecmp_low);
  assign timer_irq_o = high_gt || (high_eq && low_ge);

endmodule
