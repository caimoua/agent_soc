// Cached system wrapper smoke test.
//
// Expected final state:
//   x1 = 0x20000000
//   x2 = 7
//   x3 = 14
//   x4 = 0xaa
//   x5 = 0xaa
//   x6 = 184
//   sram[2] = 0xaa

  .option norvc
  .section .text.init, "ax", @progbits
  .globl _start

_start:
  lui   x1, 0x20000
  lw    x2, 4(x1)
  add   x3, x2, x2
  addi  x4, x0, 0xaa
  sw    x4, 8(x1)
  lw    x5, 8(x1)
  add   x6, x3, x5
  ebreak
