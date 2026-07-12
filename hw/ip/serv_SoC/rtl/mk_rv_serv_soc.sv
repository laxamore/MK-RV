`default_nettype none
// mk_rv_serv_soc — Top-level SoC integrating SERV CPU with MK-RV Wishbone peripherals
//
// Architecture:
//   SERV CPU (via servile wrapper) has two Wishbone Classic ports:
//     - o_wb_mem_* : Memory bus  (addr[31:30] == 00) → Boot RAM
//     - o_wb_ext_* : Extension bus (addr[31:30] != 00) → wb_crossbar → UART/GPIO/Timer
//
//   The servile_mux inside servile decodes addr[31:30]:
//     00 → memory bus (boot RAM)
//     01 → extension bus → crossbar → peripherals at 0x4000_xxxx
module mk_rv_serv_soc #(
    parameter W              = 1,              // SERV datapath width (1=bit-serial)
    parameter RESET_STRATEGY = "MINI",
    parameter RESET_PC       = 32'h0000_0000,
    parameter MEMFILE        = "",             // hex file for boot RAM
    parameter MEM_DEPTH      = 65536,
    parameter WITH_CSR       = 1,
    parameter WITH_MDU       = 0,
    parameter WITH_C         = 0
) (
    input wire clk_i,
    input wire rst_i,

    // UART
    input  wire uart_rx_i,
    output wire uart_tx_o,

    // GPIO (8-bit, split for testability)
    input  wire [7:0] gpio_in_i,
    output wire [7:0] gpio_out_o,
    output wire [7:0] gpio_dir_o,

    // Timer IRQ
    output wire timer_irq_o
);

  // ─────────────────────────────────────────────────────────────────────
  // Internal parameter calculation (mirrors servile's internal logic)
  // ─────────────────────────────────────────────────────────────────────
  localparam B = W - 1;
  localparam CSR_REGS = WITH_CSR ? 4 : 0;
  localparam REGS = 32 + CSR_REGS;  // 36 with CSR
  localparam RF_WIDTH = 2 * W;  // 2 for W=1
  localparam RF_L2D = $clog2(REGS * 32 / RF_WIDTH);  // 10 for W=1

  // ─────────────────────────────────────────────────────────────────────
  // SERV servile signals
  // ─────────────────────────────────────────────────────────────────────
  // Memory bus (addr[31:30] == 00) → Boot RAM
  wire [        31:0] wb_mem_adr;
  wire [        31:0] wb_mem_dat;
  wire [         3:0] wb_mem_sel;
  wire                wb_mem_we;
  wire                wb_mem_stb;
  wire [        31:0] wb_mem_rdt;
  wire                wb_mem_ack;

  // Extension bus (addr[31:30] != 00) → Crossbar → Peripherals
  wire [        31:0] wb_ext_adr;
  wire [        31:0] wb_ext_dat;
  wire [         3:0] wb_ext_sel;
  wire                wb_ext_we;
  wire                wb_ext_stb;
  wire [        31:0] wb_ext_rdt;
  wire                wb_ext_ack;

  // Register File SRAM interface
  wire [  RF_L2D-1:0] rf_waddr;
  wire [RF_WIDTH-1:0] rf_wdata;
  wire                rf_wen;
  wire [  RF_L2D-1:0] rf_raddr;
  wire                rf_ren;
  wire [RF_WIDTH-1:0] rf_rdata;

  // Timer IRQ internal
  wire                timer_irq_int;

  // ─────────────────────────────────────────────────────────────────────
  // 1. Boot RAM — directly on the memory bus
  // ─────────────────────────────────────────────────────────────────────
  serv_boot_ram #(
      .DEPTH         (MEM_DEPTH),
      .MEMFILE       (MEMFILE),
      .RESET_STRATEGY(RESET_STRATEGY)
  ) boot_ram (
      .i_clk   (clk_i),
      .i_rst   (rst_i),
      .i_wb_adr(wb_mem_adr),
      .i_wb_dat(wb_mem_dat),
      .i_wb_sel(wb_mem_sel),
      .i_wb_we (wb_mem_we),
      .i_wb_cyc(wb_mem_stb),
      .o_wb_rdt(wb_mem_rdt),
      .o_wb_ack(wb_mem_ack)
  );

  // ─────────────────────────────────────────────────────────────────────
  // 2. RF (Register File) SRAM — required by SERV
  // ─────────────────────────────────────────────────────────────────────
  serv_rf_ram #(
      .width   (RF_WIDTH),
      .csr_regs(CSR_REGS)
  ) rf_ram (
      .i_clk  (clk_i),
      .i_waddr(rf_waddr),
      .i_wdata(rf_wdata),
      .i_wen  (rf_wen),
      .i_raddr(rf_raddr),
      .i_ren  (rf_ren),
      .o_rdata(rf_rdata)
  );

  // ─────────────────────────────────────────────────────────────────────
  // 3. SERV CPU via servile wrapper
  // ─────────────────────────────────────────────────────────────────────
  servile #(
      .width         (W),
      .reset_pc      (RESET_PC),
      .reset_strategy(RESET_STRATEGY),
      .sim           (1'b0),
      .debug         (1'b0),
      .with_c        (WITH_C),
      .with_csr      (WITH_CSR),
      .with_mdu      (WITH_MDU)
  ) cpu (
      .i_clk      (clk_i),
      .i_rst      (rst_i),
      .i_timer_irq(timer_irq_int),

      // Memory bus → Boot RAM
      .o_wb_mem_adr(wb_mem_adr),
      .o_wb_mem_dat(wb_mem_dat),
      .o_wb_mem_sel(wb_mem_sel),
      .o_wb_mem_we (wb_mem_we),
      .o_wb_mem_stb(wb_mem_stb),
      .i_wb_mem_rdt(wb_mem_rdt),
      .i_wb_mem_ack(wb_mem_ack),

      // Extension bus → Crossbar
      .o_wb_ext_adr(wb_ext_adr),
      .o_wb_ext_dat(wb_ext_dat),
      .o_wb_ext_sel(wb_ext_sel),
      .o_wb_ext_we (wb_ext_we),
      .o_wb_ext_stb(wb_ext_stb),
      .i_wb_ext_rdt(wb_ext_rdt),
      .i_wb_ext_ack(wb_ext_ack),

      // RF interface → serv_rf_ram
      .o_rf_waddr(rf_waddr),
      .o_rf_wdata(rf_wdata),
      .o_rf_wen  (rf_wen),
      .o_rf_raddr(rf_raddr),
      .o_rf_ren  (rf_ren),
      .i_rf_rdata(rf_rdata)
  );

  // ─────────────────────────────────────────────────────────────────────
  // 4. Wishbone Crossbar — connects ext bus to UART / GPIO / Timer
  // ─────────────────────────────────────────────────────────────────────
  // The crossbar has 5 slave ports. Slaves 1-3 are our peripherals.
  // Slave 0 (BRAM at 0x0000_0000) and Slave 4 (custom at 0x4000_3000)
  // are unused from the ext bus (addr[31:30]=00 never reaches ext bus).
  //
  // servile's ext bus uses stb as the cycle qualifier (no separate cyc).
  // We connect both m_wb_cyc_i and m_wb_stb_i to wb_ext_stb for
  // Wishbone Classic compatibility.

  // Crossbar slave-side signals (for the 3 active peripherals)
  wire [31:0] s_uart_adr, s_uart_dat_o;
  wire [3:0] s_uart_sel;
  wire s_uart_we, s_uart_cyc, s_uart_stb;
  wire [31:0] s_uart_dat_i;
  wire s_uart_ack, s_uart_err;

  wire [31:0] s_gpio_adr, s_gpio_dat_o;
  wire [3:0] s_gpio_sel;
  wire s_gpio_we, s_gpio_cyc, s_gpio_stb;
  wire [31:0] s_gpio_dat_i;
  wire s_gpio_ack, s_gpio_err;

  wire [31:0] s_timer_adr, s_timer_dat_o;
  wire [3:0] s_timer_sel;
  wire s_timer_we, s_timer_cyc, s_timer_stb;
  wire [31:0] s_timer_dat_i;
  wire s_timer_ack, s_timer_err;

  // Unused slaves — safety terminated
  wire [31:0] s0_dat_i = '0;
  wire        s0_ack_i = 1'b0;
  wire        s0_err_i = 1'b0;
  wire [31:0] s4_dat_i = '0;
  wire        s4_ack_i = 1'b0;
  wire        s4_err_i = 1'b0;

  wb_crossbar_wrapper crossbar (
      .clk_i(clk_i),
      .rst_i(rst_i),

      // Master (from SERV ext bus)
      .m_wb_adr_i(wb_ext_adr),
      .m_wb_dat_i(wb_ext_dat),
      .m_wb_sel_i(wb_ext_sel),
      .m_wb_we_i(wb_ext_we),
      .m_wb_cyc_i(wb_ext_stb),
      .m_wb_stb_i(wb_ext_stb),
      .m_wb_dat_o(wb_ext_rdt),
      .m_wb_ack_o(wb_ext_ack),
      .m_wb_err_o(),  // not connected

      // Slave 0 — Boot BRAM (unreachable from ext bus, safety terminated)
      .s0_wb_adr_o(),
      .s0_wb_dat_o(),
      .s0_wb_sel_o(),
      .s0_wb_we_o (),
      .s0_wb_cyc_o(),
      .s0_wb_stb_o(),
      .s0_wb_dat_i(s0_dat_i),
      .s0_wb_ack_i(s0_ack_i),
      .s0_wb_err_i(s0_err_i),

      // Slave 1 — UART at 0x4000_0000
      .s1_wb_adr_o(s_uart_adr),
      .s1_wb_dat_o(s_uart_dat_o),
      .s1_wb_sel_o(s_uart_sel),
      .s1_wb_we_o (s_uart_we),
      .s1_wb_cyc_o(s_uart_cyc),
      .s1_wb_stb_o(s_uart_stb),
      .s1_wb_dat_i(s_uart_dat_i),
      .s1_wb_ack_i(s_uart_ack),
      .s1_wb_err_i(s_uart_err),

      // Slave 2 — GPIO at 0x4000_1000
      .s2_wb_adr_o(s_gpio_adr),
      .s2_wb_dat_o(s_gpio_dat_o),
      .s2_wb_sel_o(s_gpio_sel),
      .s2_wb_we_o (s_gpio_we),
      .s2_wb_cyc_o(s_gpio_cyc),
      .s2_wb_stb_o(s_gpio_stb),
      .s2_wb_dat_i(s_gpio_dat_i),
      .s2_wb_ack_i(s_gpio_ack),
      .s2_wb_err_i(s_gpio_err),

      // Slave 3 — Timer at 0x4000_2000
      .s3_wb_adr_o(s_timer_adr),
      .s3_wb_dat_o(s_timer_dat_o),
      .s3_wb_sel_o(s_timer_sel),
      .s3_wb_we_o (s_timer_we),
      .s3_wb_cyc_o(s_timer_cyc),
      .s3_wb_stb_o(s_timer_stb),
      .s3_wb_dat_i(s_timer_dat_i),
      .s3_wb_ack_i(s_timer_ack),
      .s3_wb_err_i(s_timer_err),

      // Slave 4 — Custom regs at 0x4000_3000 (unused, safety terminated)
      .s4_wb_adr_o(),
      .s4_wb_dat_o(),
      .s4_wb_sel_o(),
      .s4_wb_we_o (),
      .s4_wb_cyc_o(),
      .s4_wb_stb_o(),
      .s4_wb_dat_i(s4_dat_i),
      .s4_wb_ack_i(s4_ack_i),
      .s4_wb_err_i(s4_err_i)
  );

  // ─────────────────────────────────────────────────────────────────────
  // 5. Peripheral IPs
  // ─────────────────────────────────────────────────────────────────────

  // UART at 0x4000_0000
  uart_wb_slave uart (
      .clk_i   (clk_i),
      .rst_i   (rst_i),
      .wb_adr_i(s_uart_adr),
      .wb_dat_i(s_uart_dat_o),
      .wb_sel_i(s_uart_sel),
      .wb_we_i (s_uart_we),
      .wb_cyc_i(s_uart_cyc),
      .wb_stb_i(s_uart_stb),
      .wb_dat_o(s_uart_dat_i),
      .wb_ack_o(s_uart_ack),
      .wb_err_o(s_uart_err),
      .rx_i    (uart_rx_i),
      .tx_o    (uart_tx_o)
  );

  // GPIO at 0x4000_1000 (8-bit)
  gpio_wb_slave #(
      .GPIO_WIDTH(8)
  ) gpio (
      .clk_i   (clk_i),
      .rst_i   (rst_i),
      .wb_adr_i(s_gpio_adr),
      .wb_dat_i(s_gpio_dat_o),
      .wb_sel_i(s_gpio_sel),
      .wb_we_i (s_gpio_we),
      .wb_cyc_i(s_gpio_cyc),
      .wb_stb_i(s_gpio_stb),
      .wb_dat_o(s_gpio_dat_i),
      .wb_ack_o(s_gpio_ack),
      .wb_err_o(s_gpio_err),
      .gpio_in (gpio_in_i),
      .gpio_out(gpio_out_o),
      .gpio_dir(gpio_dir_o)
  );

  // Timer at 0x4000_2000
  timer_wb_slave timer (
      .clk_i      (clk_i),
      .rst_i      (rst_i),
      .wb_adr_i   (s_timer_adr),
      .wb_dat_i   (s_timer_dat_o),
      .wb_sel_i   (s_timer_sel),
      .wb_we_i    (s_timer_we),
      .wb_cyc_i   (s_timer_cyc),
      .wb_stb_i   (s_timer_stb),
      .wb_dat_o   (s_timer_dat_i),
      .wb_ack_o   (s_timer_ack),
      .wb_err_o   (s_timer_err),
      .timer_irq_o(timer_irq_int)
  );

  // Route timer IRQ to top-level output
  assign timer_irq_o = timer_irq_int;

endmodule
`default_nettype wire
