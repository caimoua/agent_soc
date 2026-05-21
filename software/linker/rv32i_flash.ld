OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
  FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 256K
  SRAM  (rwx) : ORIGIN = 0x20000000, LENGTH = 256K
}

SECTIONS
{
  . = ORIGIN(FLASH);

  .text : ALIGN(4)
  {
    KEEP(*(.text.init))
    *(.text*)
    *(.rodata*)
  } > FLASH

  .data : ALIGN(4)
  {
    *(.sdata*)
    *(.data*)
  } > SRAM AT > FLASH

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
