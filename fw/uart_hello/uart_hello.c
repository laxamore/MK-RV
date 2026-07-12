#include <stdio.h>
#include "mk_rv_regs.h"

static int uart_putc(char c, FILE *f) {
    (void)f;
    while (reg_read32(UART_BASE + UART_STATUS) & 0x01)
        ;
    reg_write8(UART_BASE + UART_TXDATA, c);
    return c;
}

static int uart_getc(FILE *f) {
    (void)f;
    return 0;
}

static FILE __uart = FDEV_SETUP_STREAM(uart_putc, uart_getc, NULL, _FDEV_SETUP_RW);
FILE *const stdout = &__uart;
FILE *const stdin  = &__uart;

int main(void) {
    int s = 42;

    printf("\n\r");
    printf("==============================\n\r");
    printf(" MK-RV 39 SERV SoC\n\r");
    printf("==============================\n\r");
    printf("UART, GPIO, Timer peripherals\n\r");
    printf("all working with SERV CPU!\n\r");
    printf("The answer is: %d\n\r", s);
    printf("==============================\n\r");

    while (1) {
        printf("Hello from MK-RV SERV SoC!\n\r");
        for (volatile int i = 0; i < 100000; i++)
            ;
    }

    return 0;
}
