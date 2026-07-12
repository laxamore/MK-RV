// ============================================================================
// sim/sim_main.cpp — Standalone Verilator C++ testbench for mk_rv_serv_soc
//
// This is a native C++ simulation driver (no Cocotb/Python needed).
// It generates the clock, drives reset, preloads boot RAM, monitors UART
// output in real time, and observes GPIO pins.
//
// Key concepts:
//   Verilator  — converts (System)Verilog into a cycle-accurate C++ model.
//                The generated class (Vtb_mk_rv_serv_sim) has ports as
//                member variables (clk, rst, uart_tx, gpio_*, etc.)
//                and an eval() method that recomputes all logic.
//
//   UART monitor — watches the uart_tx pin, reconstructs serial bytes at
//                  115200 baud (8N1), prints characters to stdout in
//                  real time as they are transmitted.
//
//   Boot RAM preload — writes firmware bytes into the DUT's internal
//                      memory array via Verilator's public signal access.
//
//   Main loop — toggles the clock, calls eval(), runs the UART monitor.
//               Stops after a timeout or when GPIO matches a test pattern.
// ============================================================================

#include "Vtb_mk_rv_serv_sim.h"
#include "Vtb_mk_rv_serv_sim__Syms.h"
#include "verilated.h"
#if VM_TRACE
# include "verilated_vcd_c.h"
#endif

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

// ============================================================================
// Configuration
// ============================================================================
static const int    CLK_HZ        = 50000000;       // 50 MHz
static const double CLK_PERIOD_NS = 1e9 / CLK_HZ;   // 20 ns
static const double BAUD_RATE     = 115200;
static const double BAUD_PERIOD_NS = 1e9 / BAUD_RATE;  // ~8680 ns
static const int    BAUD_CYCLES   = (int)(BAUD_PERIOD_NS / CLK_PERIOD_NS);  // 434
static const int    BAUD_HALF     = BAUD_CYCLES / 2;  // 217

// Maximum simulation time (2000 ms)
static const uint64_t MAX_SIM_PS  = 2000ULL * 1000 * 1000 * 1000;

// ============================================================================
// Boot RAM Preloader
// ============================================================================
// Reads a Verilog $readmemh-format hex file and writes each word into
// the DUT's boot_ram.mem array via Verilator's public signal API.
//
// The hex format is one 32-bit hex word per line (big-endian byte order):
//   00003117    ← word at index 0
//   07010113    ← word at index 1
//   ...

static void preload_boot_ram(Vtb_mk_rv_serv_sim* top, const char* memfile) {
    std::ifstream f(memfile);
    if (!f.is_open()) {
        fprintf(stderr, "[TB] WARNING: Cannot open boot RAM file: %s\n", memfile);
        return;
    }
    // Access the internal memory array.
    // Verilator hierarchy: top -> tb_mk_rv_serv_sim -> dut -> boot_ram -> mem
    auto& mem = top->tb_mk_rv_serv_sim->dut->boot_ram->mem;
    std::string line;
    int i = 0;
    while (std::getline(f, line)) {
        // Skip empty lines and comments
        if (line.empty() || line[0] == '/' || line[0] == '#') continue;
        uint32_t val = (uint32_t)std::strtoul(line.c_str(), nullptr, 16);
        if (i < (int)mem.size()) {
            mem[i] = val;
            i++;
        }
    }
    f.close();
    printf("[TB] Preloaded boot RAM with %d words from %s\n", i, memfile);
}

// ============================================================================
// UART Monitor — real-time serial output to console
// ============================================================================
// Reconstructs bytes from the single-bit UART TX line at 115200-8-N-1.
// Prints each character to stdout immediately (real-time output).

struct UartMonitor {
    bool        prev_tx;
    bool        sampling;
    int         cycle_count;
    int         bit_idx;
    uint8_t     rx_byte;
    std::string captured;

    void reset() {
        prev_tx     = true;
        sampling    = false;
        cycle_count = 0;
        bit_idx     = 0;
        rx_byte     = 0;
        captured.clear();
    }

    // Called on every positive clock edge.
    void eval(bool uart_tx) {
        if (!sampling) {
            // Idle: look for start bit (HIGH→LOW transition)
            if (!uart_tx && prev_tx) {
                sampling    = true;
                cycle_count = 1;  // We're already 1 cycle in (this rising edge)
                bit_idx     = 0;
                rx_byte     = 0;
            }
        } else {
            cycle_count++;
            if (bit_idx == 0) {
                // Middle of start bit is at BAUD_HALF cycles (217)
                if (cycle_count >= BAUD_HALF) {
                    bit_idx = 1;
                }
            } else if (bit_idx <= 8) {
                // Sample each data bit at its middle: BAUD_HALF + N*BAUD_CYCLES
                if (cycle_count >= BAUD_HALF + bit_idx * BAUD_CYCLES) {
                    rx_byte |= (uart_tx ? 1 : 0) << (bit_idx - 1);
                    bit_idx++;
                }
            } else {
                // Stop bit period — byte complete
                if (cycle_count >= BAUD_HALF + 9 * BAUD_CYCLES) {
                    putchar(rx_byte);
                    fflush(stdout);
                    captured += (char)rx_byte;
                    sampling = false;
                    cycle_count = 0;
                    bit_idx = 0;
                }
            }
        }
        prev_tx = uart_tx;
    }

    void print_summary() {
        printf("\n==================================================\n");
        printf("FULL UART OUTPUT (%zu bytes):\n", captured.size());
        printf("%s\n", captured.c_str());
        printf("==================================================\n");
    }
};

// ============================================================================
// GPIO Observer — watches for test pattern
// ============================================================================
// The blinky firmware toggles GPIO pins. The uart_hello firmware sends UART.
// We also watch for gpio_dir to verify the CPU is executing code.
//
// Convention: if gpio_out[7:0] transitions, the CPU is alive.

struct GpioObserver {
    uint8_t prev_out;
    int     transitions;

    void reset() {
        prev_out    = 0;
        transitions = 0;
    }

    void eval(uint8_t gpio_out, uint8_t gpio_dir) {
        if (gpio_out != prev_out) {
            transitions++;
            prev_out = gpio_out;
        }
    }
};

// ============================================================================
// Main — simulation entry point
// ============================================================================
int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vtb_mk_rv_serv_sim* top = new Vtb_mk_rv_serv_sim;

    // Trace setup
    bool trace_en = false;
#if VM_TRACE
    VerilatedVcdC* tfp = nullptr;
#endif
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--trace") == 0) trace_en = true;
    }
    if (trace_en) {
#if VM_TRACE
        Verilated::traceEverOn(true);
        tfp = new VerilatedVcdC;
        top->trace(tfp, 99);
        tfp->open("waves.vcd");
        printf("[TB] Tracing enabled → waves.vcd\n");
#else
        fprintf(stderr, "ERROR: rebuild with TRACE=1 for --trace support\n");
        exit(1);
#endif
    }

    // Preload firmware into boot RAM
    const char* memfile = getenv("MEMFILE");
    if (memfile) preload_boot_ram(top, memfile);

    // Create behavioural models
    UartMonitor  uart;
    GpioObserver gpio;
    uart.reset();
    gpio.reset();

    // Simulation state
    uint64_t sim_time_ps = 0;
    const int HALF_PERIOD_PS = 10000;  // 10 ns

    // ---- Reset Sequence ----
    top->clk     = 0;
    top->rst     = 1;  // active-high reset
    top->uart_rx = 1;  // UART RX idle HIGH
    top->gpio_in = 0;
    top->eval();
    sim_time_ps += HALF_PERIOD_PS;

    // 4 half-cycles with reset asserted
    for (int r = 0; r < 4; r++) {
        top->clk = !top->clk;
        sim_time_ps += HALF_PERIOD_PS;
        top->eval();
#if VM_TRACE
        if (trace_en) tfp->dump(sim_time_ps);
#endif
    }

    // Release reset
    top->rst = 0;

    // 2 more half-cycles for CPU to start
    for (int r = 0; r < 2; r++) {
        top->clk = !top->clk;
        sim_time_ps += HALF_PERIOD_PS;
        top->eval();
#if VM_TRACE
        if (trace_en) tfp->dump(sim_time_ps);
#endif
    }

    printf("[TB] Reset done. Starting simulation (max %.3f ms)...\n",
           MAX_SIM_PS / 1e9);

    // ---- Main Simulation Loop ----
    bool uart_ever_active = false;
    uint64_t last_report_ps = 0;

    while (sim_time_ps < MAX_SIM_PS) {
        top->clk = !top->clk;
        sim_time_ps += HALF_PERIOD_PS;
        top->eval();

#if VM_TRACE
        if (trace_en) tfp->dump(sim_time_ps);
#endif

        // On rising edge, run monitors
        if (top->clk) {
            uart.eval(top->uart_tx);
            gpio.eval(top->gpio_out, top->gpio_dir);

            if (!top->uart_tx) uart_ever_active = true;

            // // Progress report every 2 ms (faster for debugging)
            // if (sim_time_ps - last_report_ps > 2ULL * 1000 * 1000 * 1000) {
            //     last_report_ps = sim_time_ps;
            //     printf("[TB] %.1f ms  gpio_out=0x%02x  gpio_dir=0x%02x  "
            //            "uart_tx=%d\n",
            //            sim_time_ps / 1e9,
            //            (unsigned)top->gpio_out, (unsigned)top->gpio_dir,
            //            (unsigned)top->uart_tx);
            // }
        }
    }

    // ---- Post-Simulation Summary ----
    printf("\n========================================\n");
    printf("SIMULATION COMPLETE\n");
    printf("========================================\n");
    printf("Time:        %.3f ms\n", sim_time_ps / 1e9);
    printf("GPIO:        out=0x%02x  dir=0x%02x\n",
           (unsigned)top->gpio_out, (unsigned)top->gpio_dir);
    printf("GPIO toggles: %d\n", gpio.transitions);
    printf("UART active:  %s\n", uart_ever_active ? "yes" : "no");

    // uart.print_summary();

#if VM_TRACE
    if (trace_en) tfp->close();
#endif
    delete top;
    return 0;
}
