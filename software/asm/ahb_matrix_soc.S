// AHB matrix SoC smoke test.
//
// Expected final state:
//   x2  = 7
//   x3  = 12
//   x4  = 12
//   x12 = 0x5a
//   x13 = 0x66
//   x16 = 0x33
//   x17 = 0x99

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

  lui   x14, 0x42000
  addi  x15, x0, 0x33
  sw    x15, 0(x14)
  lw    x16, 0(x14)

  add   x13, x4, x12
  add   x17, x13, x16
  ebreak
