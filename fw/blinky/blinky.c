// Blinky — toggles GPIO pin 0 as a simple smoke test
// GPIO_DIR[0] = 1 (output), then toggles GPIO_DATA_OUT[0] in a delay loop
#include "mk_rv_regs.h"

static void delay(volatile unsigned long count) {
    while (count--)
        asm volatile("");
}

int main(void) {
    unsigned long i;

    // Set GPIO pin 0 as output
    reg_write32(GPIO_BASE + GPIO_DIR, 0x01);

    // Also set pin 1 as output for effect
    reg_write32(GPIO_BASE + GPIO_DIR, 0x03);

    i = 0;
    while (1) {
        // Write pattern to GPIO outputs
        reg_write32(GPIO_BASE + GPIO_DATA_OUT, i & 0xFF);

        // Increment and wrap
        i = (i + 1) & 0xFF;

        // Delay
        delay(200000);
    }

    return 0;
}
