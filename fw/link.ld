OUTPUT_ARCH("riscv")
ENTRY(_start)

__flash          = 0x00000000;
__flash_size     = 32K;
__ram            = 0x00008000;
__ram_size       = 32K;
__stack_size     = 4K;

INCLUDE picolibc.ld