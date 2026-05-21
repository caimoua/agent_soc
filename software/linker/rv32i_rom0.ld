OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
  ROM  (rx)  : ORIGIN = 0x00000000, LENGTH = 256K
  SRAM (rwx) : ORIGIN = 0x20000000, LENGTH = 256K
}

SECTIONS
{
  . = ORIGIN(ROM);

  .text : ALIGN(4)
  {
    KEEP(*(.text.init))
    *(.text*)
    *(.rodata*)
  } > ROM

  .data : ALIGN(4)
  {
    *(.sdata*)
    *(.data*)
  } > SRAM AT > ROM

  .bss (NOLOAD) : ALIGN(4)
  {
    *(.sbss*)
    *(.bss*)
    *(COMMON)
  } > SRAM

  /DISCARD/ :
  {
    *(.comment)
    *(.riscv.attributes)
  }
}
