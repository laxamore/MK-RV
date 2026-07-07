`timescale 1ns / 1ps

module uart_tx #(
    parameter int BAUD_DIVIDER = 434  // e.g. 50MHz / 115200 = 434
) (
    input logic clk_i,
    input logic rst_i,

    input logic       tx_start_i,
    input logic [7:0] tx_data_i,

    output logic tx_o,
    output logic tx_ready_o
);

  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    START = 2'b01,
    DATA  = 2'b10,
    STOP  = 2'b11
  } state_t;

  state_t state_q, state_d;

  logic [15:0] clk_div_q, clk_div_d;
  logic [2:0] bit_cnt_q, bit_cnt_d;
  logic [7:0] shift_reg_q, shift_reg_d;
  logic tx_q, tx_d;

  assign tx_o       = tx_q;
  assign tx_ready_o = (state_q == IDLE);

  always_comb begin
    state_d     = state_q;
    clk_div_d   = clk_div_q;
    bit_cnt_d   = bit_cnt_q;
    shift_reg_d = shift_reg_q;
    tx_d        = tx_q;

    case (state_q)
      IDLE: begin
        tx_d = 1'b1;  // Idle state is high
        if (tx_start_i) begin
          shift_reg_d = tx_data_i;
          state_d     = START;
          clk_div_d   = '0;
        end
      end

      START: begin
        tx_d = 1'b0;  // Start bit is low
        if (clk_div_q == BAUD_DIVIDER - 1) begin
          clk_div_d = '0;
          state_d   = DATA;
          bit_cnt_d = '0;
        end else begin
          clk_div_d = clk_div_q + 1;
        end
      end

      DATA: begin
        tx_d = shift_reg_q[0];  // Send LSB first
        if (clk_div_q == BAUD_DIVIDER - 1) begin
          clk_div_d   = '0;
          shift_reg_d = {1'b0, shift_reg_q[7:1]};
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
        tx_d = 1'b1;  // Stop bit is high
        if (clk_div_q == BAUD_DIVIDER - 1) begin
          clk_div_d = '0;
          state_d   = IDLE;
        end else begin
          clk_div_d = clk_div_q + 1;
        end
      end

      default: state_d = IDLE;
    endcase
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      state_q     <= IDLE;
      clk_div_q   <= '0;
      bit_cnt_q   <= '0;
      shift_reg_q <= '0;
      tx_q        <= 1'b1;
    end else begin
      state_q     <= state_d;
      clk_div_q   <= clk_div_d;
      bit_cnt_q   <= bit_cnt_d;
      shift_reg_q <= shift_reg_d;
      tx_q        <= tx_d;
    end
  end

endmodule
