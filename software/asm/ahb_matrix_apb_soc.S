// AHB matrix + APB peripheral SoC smoke test.
//
// Expected final state:
//   x2  = 7
//   x3  = 12
//   x4  = 12
//   x12 = 0x5a
//   x16 = 0x22
//   x19 = 0x41
//   x20 = 1
//   x21 = 0x66
//   x22 = 0x63
//   x23 = 1

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
  addi  x15, x0, 0x22
  sw    x15, 8(x14)
  lw    x16, 8(x14)

  lui   x18, 0x42001
  addi  x17, x0, 0x41
  sw    x17, 0(x18)
  lw    x19, 0(x18)
  lw    x20, 4(x18)

  add   x21, x4, x12
  add   x22, x16, x19
  add   x23, x20, x0
  ebreak
