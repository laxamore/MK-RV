`timescale 1ns / 1ps

module sync_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 8   // Must be a power of 2 for this simple pointer logic
) (
    input logic clk_i,
    input logic rst_i,

    input logic                  push_i,
    input logic [DATA_WIDTH-1:0] data_i,

    input  logic                  pop_i,
    output logic [DATA_WIDTH-1:0] data_o,

    output logic full_o,
    output logic empty_o
);

  localparam int ADDR_WIDTH = $clog2(DEPTH);

  // The distributed RAM
  logic [DATA_WIDTH-1:0] mem[0:DEPTH-1];

  // Write and read pointers with an extra bit for empty/full detection
  logic [ADDR_WIDTH:0] wr_ptr;
  logic [ADDR_WIDTH:0] rd_ptr;

  assign full_o  = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) && 
                     (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);
  assign empty_o = (wr_ptr == rd_ptr);

  // Continuous assignment for read data (FWFT - First Word Fall Through behavior)
  assign data_o = mem[rd_ptr[ADDR_WIDTH-1:0]];

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      wr_ptr <= '0;
      rd_ptr <= '0;
    end else begin
      if (push_i && !full_o) begin
        mem[wr_ptr[ADDR_WIDTH-1:0]] <= data_i;
        wr_ptr <= wr_ptr + 1;
      end
      if (pop_i && !empty_o) begin
        rd_ptr <= rd_ptr + 1;
      end
    end
  end

endmodule
