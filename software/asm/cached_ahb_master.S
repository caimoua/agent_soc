// Cached AHB master CPU-subsystem smoke test.
//
// Expected final state:
//   x1  = 0x20000000
//   x2  = 7
//   x3  = 12
//   x4  = 12
//   x10 = 0x40000000
//   x11 = 0x5a
//   x12 = 0x5a
//   x13 = 0x66
//   sram[2] = 12
//   mmio[0] = 0x5a

  .option norvc
  .section .text.init, "ax", @progbits
  .globl _start

_start:
  lui   x1, 0x20000
  lw    x2, 4(x1)
  addi  x3, x2, 5
  sw    x3, 8(x1)
  lw    x4, 8(x1)

  lui   x10, 0x40000
  addi  x11, x0, 0x5a
  sw    x11, 0(x10)
  lw    x12, 0(x10)

  add   x13, x4, x12
  ebreak
