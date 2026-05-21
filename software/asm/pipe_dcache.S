// Pipeline core load/store through D-cache smoke test.

  .option norvc
  .option norelax
  .section .text.init, "ax", @progbits
  .globl _start

_start:
  addi x1, x0, 4
  lw   x2, 0(x1)
  add  x3, x2, x2
  addi x4, x0, 0x0aa
  sw   x4, 4(x1)
  lw   x5, 4(x1)
  add  x6, x5, x2
  addi x7, x0, 0x80
  sw   x4, 0(x7)
  lw   x8, 0(x7)
  ebreak
