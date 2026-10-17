ENTRY(_start)

MEMORY
{
    SRAM (rwx) : ORIGIN = 0x00000000, LENGTH = 256K
}

SECTIONS
{
    . = ORIGIN(SRAM);
    .text : ALIGN(4) { KEEP(*(.text.init)) *(.text .text.*) } > SRAM
    .rodata : ALIGN(4) { *(.rodata .rodata.*) } > SRAM
    .data : ALIGN(4) { *(.data .data.*) } > SRAM
    .bss (NOLOAD) : ALIGN(4) { *(.bss .bss.* COMMON) } > SRAM
    . = ALIGN(16);
    __stack_top = ORIGIN(SRAM) + LENGTH(SRAM) - 16;
}
