#ifndef FREERTOS_CONFIG_H
#define FREERTOS_CONFIG_H

#define configMTIME_BASE_ADDRESS       ( 0x40002000UL )
#define configMTIMECMP_BASE_ADDRESS    ( 0x40002008UL )

#define configUSE_PREEMPTION                    1
#define configUSE_IDLE_HOOK                     1
#define configUSE_TICK_HOOK                     1
#define configCPU_CLOCK_HZ                      ( 50000000 )
#define configTICK_RATE_HZ                      ( ( TickType_t ) 2 ) // 2Hz tick rate
#define configMAX_PRIORITIES                    ( 5 )
#define configMINIMAL_STACK_SIZE                ( 128 ) 
#define configTOTAL_HEAP_SIZE                   ( ( size_t ) ( 5120 ) )
#define configISR_STACK_SIZE_WORDS              ( 128 )
#define configMAX_TASK_NAME_LEN                 ( 16 )
#define configUSE_TRACE_FACILITY                0
#define configUSE_16_BIT_TICKS                  0
#define configIDLE_SHOULD_YIELD                 1
#define configUSE_MUTEXES                       1
#define configQUEUE_REGISTRY_SIZE               8
#define configCHECK_FOR_STACK_OVERFLOW          1
#define configUSE_RECURSIVE_MUTEXES             1
#define configUSE_MALLOC_FAILED_HOOK            1
#define configUSE_APPLICATION_TASK_TAG          0
#define configUSE_COUNTING_SEMAPHORES           1
#define configGENERATE_RUN_TIME_STATS           0

/* Co-routine definitions. */
#define configUSE_CO_ROUTINES                   0
#define configMAX_CO_ROUTINE_PRIORITIES         ( 2 )

/* Software timer definitions. */
#define configUSE_TIMERS                        1
#define configTIMER_TASK_PRIORITY               ( 2 )
#define configTIMER_QUEUE_LENGTH                2
#define configTIMER_TASK_STACK_DEPTH            ( configMINIMAL_STACK_SIZE )

/* Set the following definitions to 1 to include the API function, or zero
to exclude the API function. */
#define INCLUDE_vTaskPrioritySet                1
#define INCLUDE_uxTaskPriorityGet               1
#define INCLUDE_vTaskDelete                     1
#define INCLUDE_vTaskCleanUpResources           1
#define INCLUDE_vTaskSuspend                    1
#define INCLUDE_vTaskDelayUntil                 1
#define INCLUDE_vTaskDelay                      1

/* The RISC-V port uses mtime/mtimecmp hardware via the addresses above. */

#endif /* FREERTOS_CONFIG_H */
