#include <stdio.h>
#include <stdint.h>

#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

#include "mk_rv_regs.h"

#define GPIO_OUT_REG (*(volatile unsigned long *)(GPIO_BASE + GPIO_DATA_OUT))
#define MTIME_LOW_REG (*(volatile unsigned long *)(TIMER_BASE + MTIME_LOW))

static int up(char c, FILE *f)
{
    (void)f;
    while (reg_read32(UART_BASE + UART_STATUS) & 0x01)
        ;
    reg_write8(UART_BASE + UART_TXDATA, c);
    return c;
}

static FILE __stdio = FDEV_SETUP_STREAM(up, NULL, NULL, _FDEV_SETUP_WRITE);
FILE *const stdout = &__stdio;

SemaphoreHandle_t xUartMutex = NULL;

void vTaskBlink(void *pvParameters) {
    static uint32_t shadow_gpio = 0;
    uint32_t pin = (uint32_t)pvParameters;
    
    for (;;) {
        // Toggle the LED
        shadow_gpio ^= (1 << pin);
        GPIO_OUT_REG = shadow_gpio;

        
        if (xUartMutex != NULL) {
            xSemaphoreTake(xUartMutex, portMAX_DELAY);
            printf("Task %ld toggled LED\n", pin);
            xSemaphoreGive(xUartMutex);
        }
        
        // Delay for 500ms
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

void vTaskCompute(void *pvParameters) {
    for (;;) {
        if (xUartMutex != NULL) {
            xSemaphoreTake(xUartMutex, portMAX_DELAY);
            printf("Starting Math Benchmark...\n");
            xSemaphoreGive(xUartMutex);
        }
        
        volatile uint32_t a = 12345;
        volatile uint32_t b = 67890;
        volatile uint32_t res = 0;
        
        uint32_t start_time = MTIME_LOW_REG;
        
        for (int i = 0; i < 200; i++) {
            res += (a * b);
            a++;
            b--;
        }
        
        uint32_t end_time = MTIME_LOW_REG;
        uint32_t elapsed = end_time - start_time;
        
        if (xUartMutex != NULL) {
            xSemaphoreTake(xUartMutex, portMAX_DELAY);
            printf("Math done! Result: %lu, Elapsed Timer Ticks: %lu\n", res, elapsed);
            xSemaphoreGive(xUartMutex);
        }
        
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

int main(void) {
    // Set the trap vector to FreeRTOS trap handler.
    // jumps to address 0 on any trap (ecall/timer interrupt), causing
    // an infinite reboot loop.
    extern void freertos_risc_v_trap_handler(void);
    __asm__ volatile ("csrw mtvec, %0" :: "r"(freertos_risc_v_trap_handler));

    printf("Starting FreeRTOS on Bit-Serial RISC-V MCU...\n");

    // Initialize GPIO Pin 0 and Pin 1 as output
    reg_write32(GPIO_BASE + GPIO_DIR, 0x03);

    // Create Mutex
    xUartMutex = xSemaphoreCreateMutex();
    if (xUartMutex == NULL) printf("Failed Mutex\n");

    // Create Tasks
    printf("Creating Blink0...\n");
    if (xTaskCreate(vTaskBlink, "Blink0", 128, (void*)0, tskIDLE_PRIORITY + 1, NULL) != pdPASS) {
        printf("Failed to create Blink0\n");
    }
    printf("Creating Blink1...\n");
    if (xTaskCreate(vTaskBlink, "Blink1", 128, (void*)1, tskIDLE_PRIORITY + 1, NULL) != pdPASS) {
        printf("Failed to create Blink1\n");
    }
    printf("Creating Compute...\n");
    if (xTaskCreate(vTaskCompute, "Compute", 128, NULL, tskIDLE_PRIORITY + 1, NULL) != pdPASS) {
        printf("Failed to create Compute\n");
    } else {
        printf("Compute created successfully!\n");
    }

    // Start the Scheduler
    printf("Starting scheduler...\n");
    vTaskStartScheduler();

    // Should never reach here
    for (;;);
    return 0;
}

// FreeRTOS hooks
void vApplicationMallocFailedHook(void) {
    printf("Malloc failed!\n");
    for (;;);
}

void vApplicationIdleHook(void) {
    // Optionally enter low power mode
}

void vApplicationStackOverflowHook(TaskHandle_t pxTask, char *pcTaskName) {
    printf("Stack overflow in task %s\n", pcTaskName);
    for (;;);
}

void vApplicationTickHook(void) {
    // Called from ISR
}
