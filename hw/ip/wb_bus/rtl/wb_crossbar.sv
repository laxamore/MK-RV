`timescale 1ns/1ps

module wb_crossbar #(
    parameter int NUM_SLAVES = 5,
    // Provide a flat packed array for base addresses.
    // Index 0 is the lowest 32 bits (Slave 0).
    parameter logic [(NUM_SLAVES*32)-1:0] SLAVE_BASE_ADDR = {
        32'h4000_3000, // Slave 4: Custom
        32'h4000_2000, // Slave 3: Timer
        32'h4000_1000, // Slave 2: GPIO
        32'h4000_0000, // Slave 1: UART
        32'h0000_0000  // Slave 0: BRAM
    },
    parameter logic [(NUM_SLAVES*32)-1:0] SLAVE_ADDR_MASK = {
        32'hFFFF_F000, // Slave 4
        32'hFFFF_F000, // Slave 3
        32'hFFFF_F000, // Slave 2
        32'hFFFF_F000, // Slave 1
        32'hFFFF_C000  // Slave 0
    }
) (
    input  logic        clk_i,
    input  logic        rst_i,

    // Master Interface
    input  logic [31:0] m_wb_adr_i,
    input  logic [31:0] m_wb_dat_i,
    input  logic [3:0]  m_wb_sel_i,
    input  logic        m_wb_we_i,
    input  logic        m_wb_cyc_i,
    input  logic        m_wb_stb_i,
    output logic [31:0] m_wb_dat_o,
    output logic        m_wb_ack_o,
    output logic        m_wb_err_o,

    // Slaves Interface (Flat 1D arrays for maximum tool compatibility)
    output logic [(NUM_SLAVES*32)-1:0] s_wb_adr_o,
    output logic [(NUM_SLAVES*32)-1:0] s_wb_dat_o,
    output logic [(NUM_SLAVES*4)-1:0]  s_wb_sel_o,
    output logic [NUM_SLAVES-1:0]      s_wb_we_o,
    output logic [NUM_SLAVES-1:0]      s_wb_cyc_o,
    output logic [NUM_SLAVES-1:0]      s_wb_stb_o,
    
    input  logic [(NUM_SLAVES*32)-1:0] s_wb_dat_i,
    input  logic [NUM_SLAVES-1:0]      s_wb_ack_i,
    input  logic [NUM_SLAVES-1:0]      s_wb_err_i
);

    logic [NUM_SLAVES-1:0] slave_sel;
    logic any_slave_sel;

    // Address Decoding
    always_comb begin
        slave_sel = '0;
        any_slave_sel = 1'b0;

        if (m_wb_stb_i && m_wb_cyc_i) begin
            for (int i = 0; i < NUM_SLAVES; i++) begin
                if ((m_wb_adr_i & SLAVE_ADDR_MASK[i*32 +: 32]) == (SLAVE_BASE_ADDR[i*32 +: 32] & SLAVE_ADDR_MASK[i*32 +: 32])) begin
                    slave_sel[i] = 1'b1;
                    any_slave_sel = 1'b1;
                end
            end
        end
    end

    // Slave Routing (Master -> Slaves)
    always_comb begin
        for (int i = 0; i < NUM_SLAVES; i++) begin
            s_wb_adr_o[i*32 +: 32] = m_wb_adr_i;
            s_wb_dat_o[i*32 +: 32] = m_wb_dat_i;
            s_wb_sel_o[i*4  +: 4]  = m_wb_sel_i;
            s_wb_we_o[i]           = m_wb_we_i;
            
            // Only assert CYC and STB to the selected slave
            s_wb_cyc_o[i]          = m_wb_cyc_i && slave_sel[i];
            s_wb_stb_o[i]          = m_wb_stb_i && slave_sel[i];
        end
    end

    // Master Routing (Slaves -> Master)
    always_comb begin
        // Default assignments
        m_wb_dat_o = '0;
        m_wb_ack_o = 1'b0;
        m_wb_err_o = 1'b0;

        for (int i = 0; i < NUM_SLAVES; i++) begin
            if (slave_sel[i]) begin
                m_wb_dat_o = s_wb_dat_i[i*32 +: 32];
                m_wb_ack_o = s_wb_ack_i[i];
                m_wb_err_o = s_wb_err_i[i];
            end
        end

        // Hardware fault (unmapped memory access)
        if (m_wb_cyc_i && m_wb_stb_i && !any_slave_sel) begin
            m_wb_err_o = 1'b1;
        end
    end

endmodule
