`timescale 1ns / 1ps

module tb_wb_crossbar (
    input logic clk_i,
    input logic rst_i
);

  // =========================================================================
  // Master Interface (Driven by Cocotb)
  // =========================================================================
  logic [31:0] m_wb_adr_i;
  logic [31:0] m_wb_dat_i;
  logic [ 3:0] m_wb_sel_i;
  logic        m_wb_we_i;
  logic        m_wb_cyc_i;
  logic        m_wb_stb_i;
  logic [31:0] m_wb_dat_o;
  logic        m_wb_ack_o;
  logic        m_wb_err_o;

  // =========================================================================
  // Slave Interfaces (Observed/Driven by Cocotb via the Wrapper)
  // =========================================================================
  logic [31:0] s0_wb_adr_o, s1_wb_adr_o, s2_wb_adr_o, s3_wb_adr_o, s4_wb_adr_o;
  logic [31:0] s0_wb_dat_o, s1_wb_dat_o, s2_wb_dat_o, s3_wb_dat_o, s4_wb_dat_o;
  logic [3:0] s0_wb_sel_o, s1_wb_sel_o, s2_wb_sel_o, s3_wb_sel_o, s4_wb_sel_o;
  logic s0_wb_we_o, s1_wb_we_o, s2_wb_we_o, s3_wb_we_o, s4_wb_we_o;
  logic s0_wb_cyc_o, s1_wb_cyc_o, s2_wb_cyc_o, s3_wb_cyc_o, s4_wb_cyc_o;
  logic s0_wb_stb_o, s1_wb_stb_o, s2_wb_stb_o, s3_wb_stb_o, s4_wb_stb_o;

  logic [31:0] s0_wb_dat_i, s1_wb_dat_i, s2_wb_dat_i, s3_wb_dat_i, s4_wb_dat_i;
  logic s0_wb_ack_i, s1_wb_ack_i, s2_wb_ack_i, s3_wb_ack_i, s4_wb_ack_i;
  logic s0_wb_err_i, s1_wb_err_i, s2_wb_err_i, s3_wb_err_i, s4_wb_err_i;

  // Default driver assignment to prevent X states in Verilator/Simulator
  initial begin
    m_wb_adr_i  = 0;
    m_wb_dat_i  = 0;
    m_wb_sel_i  = 0;
    m_wb_we_i   = 0;
    m_wb_cyc_i  = 0;
    m_wb_stb_i  = 0;

    s0_wb_dat_i = 0;
    s0_wb_ack_i = 0;
    s0_wb_err_i = 0;
    s1_wb_dat_i = 0;
    s1_wb_ack_i = 0;
    s1_wb_err_i = 0;
    s2_wb_dat_i = 0;
    s2_wb_ack_i = 0;
    s2_wb_err_i = 0;
    s3_wb_dat_i = 0;
    s3_wb_ack_i = 0;
    s3_wb_err_i = 0;
    s4_wb_dat_i = 0;
    s4_wb_ack_i = 0;
    s4_wb_err_i = 0;
  end

  // =========================================================================
  // DUT Instantiation (Using the Wrapper for GTKWave Readability)
  // =========================================================================
  wb_crossbar_wrapper dut (
      .clk_i(clk_i),
      .rst_i(rst_i),

      .m_wb_adr_i(m_wb_adr_i),
      .m_wb_dat_i(m_wb_dat_i),
      .m_wb_sel_i(m_wb_sel_i),
      .m_wb_we_i (m_wb_we_i),
      .m_wb_cyc_i(m_wb_cyc_i),
      .m_wb_stb_i(m_wb_stb_i),
      .m_wb_dat_o(m_wb_dat_o),
      .m_wb_ack_o(m_wb_ack_o),
      .m_wb_err_o(m_wb_err_o),

      .s0_wb_adr_o(s0_wb_adr_o),
      .s0_wb_dat_o(s0_wb_dat_o),
      .s0_wb_sel_o(s0_wb_sel_o),
      .s0_wb_we_o (s0_wb_we_o),
      .s0_wb_cyc_o(s0_wb_cyc_o),
      .s0_wb_stb_o(s0_wb_stb_o),
      .s0_wb_dat_i(s0_wb_dat_i),
      .s0_wb_ack_i(s0_wb_ack_i),
      .s0_wb_err_i(s0_wb_err_i),
      .s1_wb_adr_o(s1_wb_adr_o),
      .s1_wb_dat_o(s1_wb_dat_o),
      .s1_wb_sel_o(s1_wb_sel_o),
      .s1_wb_we_o (s1_wb_we_o),
      .s1_wb_cyc_o(s1_wb_cyc_o),
      .s1_wb_stb_o(s1_wb_stb_o),
      .s1_wb_dat_i(s1_wb_dat_i),
      .s1_wb_ack_i(s1_wb_ack_i),
      .s1_wb_err_i(s1_wb_err_i),
      .s2_wb_adr_o(s2_wb_adr_o),
      .s2_wb_dat_o(s2_wb_dat_o),
      .s2_wb_sel_o(s2_wb_sel_o),
      .s2_wb_we_o (s2_wb_we_o),
      .s2_wb_cyc_o(s2_wb_cyc_o),
      .s2_wb_stb_o(s2_wb_stb_o),
      .s2_wb_dat_i(s2_wb_dat_i),
      .s2_wb_ack_i(s2_wb_ack_i),
      .s2_wb_err_i(s2_wb_err_i),
      .s3_wb_adr_o(s3_wb_adr_o),
      .s3_wb_dat_o(s3_wb_dat_o),
      .s3_wb_sel_o(s3_wb_sel_o),
      .s3_wb_we_o (s3_wb_we_o),
      .s3_wb_cyc_o(s3_wb_cyc_o),
      .s3_wb_stb_o(s3_wb_stb_o),
      .s3_wb_dat_i(s3_wb_dat_i),
      .s3_wb_ack_i(s3_wb_ack_i),
      .s3_wb_err_i(s3_wb_err_i),
      .s4_wb_adr_o(s4_wb_adr_o),
      .s4_wb_dat_o(s4_wb_dat_o),
      .s4_wb_sel_o(s4_wb_sel_o),
      .s4_wb_we_o (s4_wb_we_o),
      .s4_wb_cyc_o(s4_wb_cyc_o),
      .s4_wb_stb_o(s4_wb_stb_o),
      .s4_wb_dat_i(s4_wb_dat_i),
      .s4_wb_ack_i(s4_wb_ack_i),
      .s4_wb_err_i(s4_wb_err_i)
  );

  // Waveform dumping
`ifdef COCOTB_SIM
  initial begin
    $dumpfile("tb_wb_crossbar.vcd");
    $dumpvars(0, tb_wb_crossbar);
  end
`endif

endmodule
