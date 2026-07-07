`timescale 1ns/1ps

module uart_wb_slave (
    input  logic        clk_i,
    input  logic        rst_i,

    // Wishbone Slave Interface
    input  logic [31:0] wb_adr_i,
    input  logic [31:0] wb_dat_i,
    input  logic [3:0]  wb_sel_i,
    input  logic        wb_we_i,
    input  logic        wb_cyc_i,
    input  logic        wb_stb_i,
    output logic [31:0] wb_dat_o,
    output logic        wb_ack_o,
    output logic        wb_err_o,
    
    // External Physical Pins
    input  logic        rx_i,
    output logic        tx_o
);

    // =========================================================================
    // UART MMIO Register Map
    // =========================================================================
    // 0x00 : UART_TXDATA (Write-only, pushes byte to TX FIFO)
    // 0x04 : UART_RXDATA (Read-only, pops byte from RX FIFO)
    // 0x08 : UART_STATUS (Read-only: Bit 0=TX Full, Bit 1=RX Empty, Bit 2=TX Idle)
    // 0x0C : UART_CTRL   (Read/Write: Bit 0=RX Int En, Bit 1=TX Int En)

    logic [31:0] uart_ctrl;
    logic        tx_full;
    logic        rx_empty;
    logic        tx_idle;
    
    // Internal FIFO push/pop signals
    logic        tx_push;
    logic [7:0]  tx_data_in;
    logic        rx_pop;
    logic [7:0]  rx_data_out;

    // Wishbone Handshake logic
    logic valid_access;
    logic ack_q;
    
    assign valid_access = wb_cyc_i && wb_stb_i;
    assign wb_ack_o     = valid_access && ack_q;
    assign wb_err_o     = 1'b0; // No unmapped memory inside the UART 4-word window

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            ack_q     <= 1'b0;
            uart_ctrl <= 32'h0;
            tx_push   <= 1'b0;
            rx_pop    <= 1'b0;
            wb_dat_o  <= 32'h0;
        end else begin
            tx_push <= 1'b0;
            rx_pop  <= 1'b0;
            
            // Single-cycle ACK response
            if (valid_access && !ack_q) begin
                ack_q <= 1'b1;
                
                // --- WRITE OPERATIONS ---
                if (wb_we_i) begin
                    case (wb_adr_i[3:0])
                        4'h0: begin // 0x00: TXDATA
                            // Only push if the FIFO isn't full to prevent dropping data
                            if (!tx_full) begin
                                tx_push    <= 1'b1;
                                tx_data_in <= wb_dat_i[7:0]; // We only send 8 bits at a time
                            end
                        end
                        4'hC: begin // 0x0C: CTRL
                            // For simplicity, we assume 32-bit writes for control registers
                            uart_ctrl <= wb_dat_i;
                        end
                        default: ; // Writing to RXDATA or STATUS is ignored
                    endcase
                end
                // --- READ OPERATIONS ---
                else begin
                    case (wb_adr_i[3:0])
                        4'h0: wb_dat_o <= 32'h0; // TXDATA is write-only
                        4'h4: begin // 0x04: RXDATA
                            // Only pop if the FIFO isn't empty
                            if (!rx_empty) begin
                                rx_pop   <= 1'b1;
                                wb_dat_o <= {24'h0, rx_data_out};
                            end else begin
                                wb_dat_o <= 32'h0;
                            end
                        end
                        4'h8: begin // 0x08: STATUS
                            wb_dat_o <= {29'h0, tx_idle, rx_empty, tx_full};
                        end
                        4'hC: begin // 0x0C: CTRL
                            wb_dat_o <= uart_ctrl;
                        end
                        default: wb_dat_o <= 32'h0;
                    endcase
                end
            end else begin
                ack_q <= 1'b0;
            end
        end
    end

    // =========================================================================
    // UART Submodule Instantiations
    // =========================================================================
    
    logic tx_start;
    logic tx_ready;
    logic [7:0] tx_data_to_engine;
    logic tx_fifo_empty;
    
    // TX FIFO (CPU writes to FIFO, UART TX engine pops from FIFO)
    sync_fifo #(
        .DATA_WIDTH(8),
        .DEPTH(8)
    ) tx_fifo (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .push_i(tx_push),
        .data_i(tx_data_in),
        .pop_i(tx_ready && !tx_fifo_empty),
        .data_o(tx_data_to_engine),
        .full_o(tx_full),
        .empty_o(tx_fifo_empty)
    );
    
    assign tx_idle  = tx_ready && tx_fifo_empty;
    assign tx_start = tx_ready && !tx_fifo_empty;
    
    uart_tx #(
        .BAUD_DIVIDER(434) // 50MHz / 115200
    ) tx_engine (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .tx_start_i(tx_start),
        .tx_data_i(tx_data_to_engine),
        .tx_o(tx_o),
        .tx_ready_o(tx_ready)
    );
    
    // RX FIFO (UART RX engine pushes to FIFO, CPU pops from FIFO)
    logic rx_valid;
    logic [7:0] rx_data_from_engine;
    
    uart_rx #(
        .BAUD_DIVIDER(434)
    ) rx_engine (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .rx_i(rx_i),
        .rx_valid_o(rx_valid),
        .rx_data_o(rx_data_from_engine)
    );
    
    // Note: If RX FIFO is full and a new byte arrives, it will be dropped in this simple implementation.
    sync_fifo #(
        .DATA_WIDTH(8),
        .DEPTH(8)
    ) rx_fifo (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .push_i(rx_valid),
        .data_i(rx_data_from_engine),
        .pop_i(rx_pop),
        .data_o(rx_data_out),
        .full_o(), // Ignoring full condition for now
        .empty_o(rx_empty)
    );

endmodule
