`timescale 1ns/1ps

module uart_rx #(
    parameter int BAUD_DIVIDER = 434
) (
    input  logic       clk_i,
    input  logic       rst_i,
    
    input  logic       rx_i,
    
    output logic       rx_valid_o,
    output logic [7:0] rx_data_o
);

    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } state_t;

    state_t state_q, state_d;
    
    logic [15:0] clk_div_q, clk_div_d;
    logic [2:0]  bit_cnt_q, bit_cnt_d;
    logic [7:0]  shift_reg_q, shift_reg_d;
    logic        rx_valid_q, rx_valid_d;
    
    // Double-flop synchronizer for asynchronous RX input
    logic rx_sync_1, rx_sync_2;

    assign rx_valid_o = rx_valid_q;
    assign rx_data_o  = shift_reg_q;

    always_comb begin
        state_d     = state_q;
        clk_div_d   = clk_div_q;
        bit_cnt_d   = bit_cnt_q;
        shift_reg_d = shift_reg_q;
        rx_valid_d  = 1'b0; // Default to 0, pulses high for 1 cycle when valid

        case (state_q)
            IDLE: begin
                if (rx_sync_2 == 1'b0) begin
                    state_d   = START;
                    // Start checking in the middle of the start bit
                    clk_div_d = BAUD_DIVIDER / 2;
                end
            end

            START: begin
                if (clk_div_q == BAUD_DIVIDER - 1) begin
                    clk_div_d = '0;
                    // Confirm it is still low (valid start bit)
                    if (rx_sync_2 == 1'b0) begin
                        state_d   = DATA;
                        bit_cnt_d = '0;
                    end else begin
                        state_d = IDLE; // Glitch detected
                    end
                end else begin
                    clk_div_d = clk_div_q + 1;
                end
            end

            DATA: begin
                if (clk_div_q == BAUD_DIVIDER - 1) begin
                    clk_div_d   = '0;
                    shift_reg_d = {rx_sync_2, shift_reg_q[7:1]};
                    if (bit_cnt_q == 7) begin
                        state_d = STOP;
                    end else begin
                        bit_cnt_d = bit_cnt_q + 1;
                    end
                end else begin
                    clk_div_d = clk_div_q + 1;
                end
            end

            STOP: begin
                if (clk_div_q == BAUD_DIVIDER - 1) begin
                    clk_div_d = '0;
                    // Confirm stop bit is high
                    if (rx_sync_2 == 1'b1) begin
                        rx_valid_d = 1'b1;
                    end
                    state_d = IDLE;
                end else begin
                    clk_div_d = clk_div_q + 1;
                end
            end
            
            default: state_d = IDLE;
        endcase
    end

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            rx_sync_1   <= 1'b1;
            rx_sync_2   <= 1'b1;
            state_q     <= IDLE;
            clk_div_q   <= '0;
            bit_cnt_q   <= '0;
            shift_reg_q <= '0;
            rx_valid_q  <= 1'b0;
        end else begin
            rx_sync_1   <= rx_i;
            rx_sync_2   <= rx_sync_1;
            state_q     <= state_d;
            clk_div_q   <= clk_div_d;
            bit_cnt_q   <= bit_cnt_d;
            shift_reg_q <= shift_reg_d;
            rx_valid_q  <= rx_valid_d;
        end
    end

endmodule
