#ifndef MK_RV_REGS_H
#define MK_RV_REGS_H

// Memory-mapped I/O addresses for MK-RV peripherals

// UART at 0x4000_0000 (4 KB window)
#define UART_BASE       0x40000000UL
#define UART_TXDATA     0x00  // (W) Write byte to TX FIFO
#define UART_RXDATA     0x04  // (R) Read byte from RX FIFO
#define UART_STATUS     0x08  // (R) Bit 0=TX Full, Bit 1=RX Empty, Bit 2=TX Idle
#define UART_CTRL       0x0C  // (R/W) Control register

// GPIO at 0x4000_1000 (4 KB window, 8-bit)
#define GPIO_BASE       0x40001000UL
#define GPIO_DATA_OUT   0x00  // (R/W) Output data
#define GPIO_DATA_IN    0x04  // (R)   Input pin state
#define GPIO_DIR        0x08  // (R/W) Direction: 1=output, 0=input

// Timer at 0x4000_2000 (4 KB window)
#define TIMER_BASE      0x40002000UL
#define MTIME_LOW       0x00  // (R) Lower 32 bits of mtime counter
#define MTIME_HIGH      0x04  // (R) Upper 32 bits of mtime counter
#define MTIMECMP_LOW    0x08  // (R/W) Lower 32 bits of compare
#define MTIMECMP_HIGH   0x0C  // (R/W) Upper 32 bits of compare

// Helper: read/write 32-bit word from MMIO address
static inline void reg_write32(unsigned long addr, unsigned long val) {
    *(volatile unsigned long *)addr = val;
}

static inline unsigned long reg_read32(unsigned long addr) {
    return *(volatile unsigned long *)addr;
}

// Helper: write byte to MMIO address (for UART TX)
static inline void reg_write8(unsigned long addr, unsigned char val) {
    *(volatile unsigned char *)addr = val;
}

static inline unsigned char reg_read8(unsigned long addr) {
    return *(volatile unsigned char *)addr;
}

#endif // MK_RV_REGS_H
