// Boot RAM for SERV SoC — synchronous Wishbone slave, preloadable from hex file
// Modeled after servile's servant_ram.v for compatibility.
`default_nettype none
module serv_boot_ram #(
    parameter DEPTH          = 16384,   // 16 KB default
    parameter MEMFILE        = "",
    parameter RESET_STRATEGY = "MINI"
) (
    input wire i_clk,
    input wire i_rst,

    input  wire [31:0] i_wb_adr,  // word-aligned address (aw-1:2 expected in usage)
    input  wire [31:0] i_wb_dat,
    input  wire [ 3:0] i_wb_sel,
    input  wire        i_wb_we,
    input  wire        i_wb_cyc,
    output reg  [31:0] o_wb_rdt,
    output reg         o_wb_ack
);

  localparam AW = $clog2(DEPTH);
  localparam NUM_WORDS = DEPTH / 4;

  wire [3:0] we = {4{i_wb_we & i_wb_cyc}} & i_wb_sel;
  wire [AW-3:0] addr = i_wb_adr[AW-1:2];

  reg [31:0] mem[0:NUM_WORDS-1]  /* verilator public */;

  always @(posedge i_clk) begin
    if (i_rst & (RESET_STRATEGY != "NONE")) o_wb_ack <= 1'b0;
    else o_wb_ack <= i_wb_cyc & !o_wb_ack;
  end

  always @(posedge i_clk) begin
    if (we[0]) mem[addr][7:0] <= i_wb_dat[7:0];
    if (we[1]) mem[addr][15:8] <= i_wb_dat[15:8];
    if (we[2]) mem[addr][23:16] <= i_wb_dat[23:16];
    if (we[3]) mem[addr][31:24] <= i_wb_dat[31:24];
    o_wb_rdt <= mem[addr];
  end

  initial begin
    if (MEMFILE != "") begin
      $display("Preloading boot RAM from %s", MEMFILE);
      $readmemh(MEMFILE, mem);
    end
  end

endmodule
`default_nettype wire
