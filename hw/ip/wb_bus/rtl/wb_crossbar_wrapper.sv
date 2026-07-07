`timescale 1ns / 1ps

module wb_crossbar_wrapper (
    input logic clk_i,
    input logic rst_i,

    // Master Interface (CPU)
    input  logic [31:0] m_wb_adr_i,
    input  logic [31:0] m_wb_dat_i,
    input  logic [ 3:0] m_wb_sel_i,
    input  logic        m_wb_we_i,
    input  logic        m_wb_cyc_i,
    input  logic        m_wb_stb_i,
    output logic [31:0] m_wb_dat_o,
    output logic        m_wb_ack_o,
    output logic        m_wb_err_o,

    // Slave 0 Interface (Boot BRAM: 0x0000_0000 - 0x0000_3FFF)
    output logic [31:0] s0_wb_adr_o,
    output logic [31:0] s0_wb_dat_o,
    output logic [ 3:0] s0_wb_sel_o,
    output logic        s0_wb_we_o,
    output logic        s0_wb_cyc_o,
    output logic        s0_wb_stb_o,
    input  logic [31:0] s0_wb_dat_i,
    input  logic        s0_wb_ack_i,
    input  logic        s0_wb_err_i,

    // Slave 1 Interface (UART: 0x4000_0000 - 0x4000_0FFF)
    output logic [31:0] s1_wb_adr_o,
    output logic [31:0] s1_wb_dat_o,
    output logic [ 3:0] s1_wb_sel_o,
    output logic        s1_wb_we_o,
    output logic        s1_wb_cyc_o,
    output logic        s1_wb_stb_o,
    input  logic [31:0] s1_wb_dat_i,
    input  logic        s1_wb_ack_i,
    input  logic        s1_wb_err_i,

    // Slave 2 Interface (GPIO: 0x4000_1000 - 0x4000_1FFF)
    output logic [31:0] s2_wb_adr_o,
    output logic [31:0] s2_wb_dat_o,
    output logic [ 3:0] s2_wb_sel_o,
    output logic        s2_wb_we_o,
    output logic        s2_wb_cyc_o,
    output logic        s2_wb_stb_o,
    input  logic [31:0] s2_wb_dat_i,
    input  logic        s2_wb_ack_i,
    input  logic        s2_wb_err_i,

    // Slave 3 Interface (Timer: 0x4000_2000 - 0x4000_2FFF)
    output logic [31:0] s3_wb_adr_o,
    output logic [31:0] s3_wb_dat_o,
    output logic [ 3:0] s3_wb_sel_o,
    output logic        s3_wb_we_o,
    output logic        s3_wb_cyc_o,
    output logic        s3_wb_stb_o,
    input  logic [31:0] s3_wb_dat_i,
    input  logic        s3_wb_ack_i,
    input  logic        s3_wb_err_i,

    // Slave 4 Interface (Custom Regs: 0x4000_3000 - 0x4000_3FFF)
    output logic [31:0] s4_wb_adr_o,
    output logic [31:0] s4_wb_dat_o,
    output logic [ 3:0] s4_wb_sel_o,
    output logic        s4_wb_we_o,
    output logic        s4_wb_cyc_o,
    output logic        s4_wb_stb_o,
    input  logic [31:0] s4_wb_dat_i,
    input  logic        s4_wb_ack_i,
    input  logic        s4_wb_err_i
);

  localparam int NUM_SLAVES = 5;

  // Internal Flattened Arrays for the Core
  logic [(NUM_SLAVES*32)-1:0] flat_s_wb_adr_o;
  logic [(NUM_SLAVES*32)-1:0] flat_s_wb_dat_o;
  logic [ (NUM_SLAVES*4)-1:0] flat_s_wb_sel_o;
  logic [     NUM_SLAVES-1:0] flat_s_wb_we_o;
  logic [     NUM_SLAVES-1:0] flat_s_wb_cyc_o;
  logic [     NUM_SLAVES-1:0] flat_s_wb_stb_o;

  logic [(NUM_SLAVES*32)-1:0] flat_s_wb_dat_i;
  logic [     NUM_SLAVES-1:0] flat_s_wb_ack_i;
  logic [     NUM_SLAVES-1:0] flat_s_wb_err_i;

  // Map Master -> Slaves (Unpacking the arrays into distinct named ports)
  assign s0_wb_adr_o = flat_s_wb_adr_o[0*32+:32];
  assign s1_wb_adr_o = flat_s_wb_adr_o[1*32+:32];
  assign s2_wb_adr_o = flat_s_wb_adr_o[2*32+:32];
  assign s3_wb_adr_o = flat_s_wb_adr_o[3*32+:32];
  assign s4_wb_adr_o = flat_s_wb_adr_o[4*32+:32];

  assign s0_wb_dat_o = flat_s_wb_dat_o[0*32+:32];
  assign s1_wb_dat_o = flat_s_wb_dat_o[1*32+:32];
  assign s2_wb_dat_o = flat_s_wb_dat_o[2*32+:32];
  assign s3_wb_dat_o = flat_s_wb_dat_o[3*32+:32];
  assign s4_wb_dat_o = flat_s_wb_dat_o[4*32+:32];

  assign s0_wb_sel_o = flat_s_wb_sel_o[0*4+:4];
  assign s1_wb_sel_o = flat_s_wb_sel_o[1*4+:4];
  assign s2_wb_sel_o = flat_s_wb_sel_o[2*4+:4];
  assign s3_wb_sel_o = flat_s_wb_sel_o[3*4+:4];
  assign s4_wb_sel_o = flat_s_wb_sel_o[4*4+:4];

  assign s0_wb_we_o = flat_s_wb_we_o[0];
  assign s1_wb_we_o = flat_s_wb_we_o[1];
  assign s2_wb_we_o = flat_s_wb_we_o[2];
  assign s3_wb_we_o = flat_s_wb_we_o[3];
  assign s4_wb_we_o = flat_s_wb_we_o[4];

  assign s0_wb_cyc_o = flat_s_wb_cyc_o[0];
  assign s1_wb_cyc_o = flat_s_wb_cyc_o[1];
  assign s2_wb_cyc_o = flat_s_wb_cyc_o[2];
  assign s3_wb_cyc_o = flat_s_wb_cyc_o[3];
  assign s4_wb_cyc_o = flat_s_wb_cyc_o[4];

  assign s0_wb_stb_o = flat_s_wb_stb_o[0];
  assign s1_wb_stb_o = flat_s_wb_stb_o[1];
  assign s2_wb_stb_o = flat_s_wb_stb_o[2];
  assign s3_wb_stb_o = flat_s_wb_stb_o[3];
  assign s4_wb_stb_o = flat_s_wb_stb_o[4];

  // Map Slaves -> Master (Packing distinct named ports back into the array)
  assign flat_s_wb_dat_i = {s4_wb_dat_i, s3_wb_dat_i, s2_wb_dat_i, s1_wb_dat_i, s0_wb_dat_i};
  assign flat_s_wb_ack_i = {s4_wb_ack_i, s3_wb_ack_i, s2_wb_ack_i, s1_wb_ack_i, s0_wb_ack_i};
  assign flat_s_wb_err_i = {s4_wb_err_i, s3_wb_err_i, s2_wb_err_i, s1_wb_err_i, s0_wb_err_i};

  // Instantiate the Dynamic Core
  wb_crossbar #(
      .NUM_SLAVES(NUM_SLAVES)
  ) core (
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

      .s_wb_adr_o(flat_s_wb_adr_o),
      .s_wb_dat_o(flat_s_wb_dat_o),
      .s_wb_sel_o(flat_s_wb_sel_o),
      .s_wb_we_o (flat_s_wb_we_o),
      .s_wb_cyc_o(flat_s_wb_cyc_o),
      .s_wb_stb_o(flat_s_wb_stb_o),

      .s_wb_dat_i(flat_s_wb_dat_i),
      .s_wb_ack_i(flat_s_wb_ack_i),
      .s_wb_err_i(flat_s_wb_err_i)
  );

endmodule
