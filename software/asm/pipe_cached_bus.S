// Pipeline core through I-cache, D-cache and simple memory bus.

  .option norvc
  .option norelax
  .section .text.init, "ax", @progbits
  .globl _start

_start:
  lui  x1, 0x20000
  lw   x2, 4(x1)
  add  x3, x2, x2
  addi x4, x0, 0x0aa
  sw   x4, 8(x1)
  lw   x5, 8(x1)
  add  x6, x3, x5
  ebreak
