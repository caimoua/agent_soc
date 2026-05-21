// Cached timer MMIO smoke test.
//
// Expected final state:
//   x1 = 0x40000000
//   x2 = 10
//   x3 = 3
//   x4 >= 10
//   x5 & 0x80000003 = 0x80000003
//   x6 = 10

  .option norvc
  .section .text.init, "ax", @progbits
  .globl _start

_start:
  lui   x1, 0x40000
  addi  x2, x0, 10
  sw    x2, 8(x1)
  sw    x0, 12(x1)
  addi  x3, x0, 3
  sw    x3, 16(x1)
  lw    x6, 8(x1)

  addi  x0, x0, 0
  addi  x0, x0, 0
  addi  x0, x0, 0
  addi  x0, x0, 0
  addi  x0, x0, 0
  addi  x0, x0, 0
  addi  x0, x0, 0
  addi  x0, x0, 0

  lw    x4, 0(x1)
  lw    x5, 16(x1)
  ebreak
