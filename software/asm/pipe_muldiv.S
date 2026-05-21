// RV32M mul/div/rem directed test for rv32i_pipe_muldiv_tb.

  .option norvc
  .option norelax
  .section .text.init, "ax", @progbits
  .globl _start

_start:
  addi   x1,  x0, 6
  addi   x2,  x0, 7
  mul    x3,  x1,  x2
  addi   x4,  x0, -3
  addi   x5,  x0, 5
  mul    x6,  x4,  x5
  mulh   x7,  x4,  x5
  mulhsu x8,  x4,  x5
  addi   x10, x0, -1
  addi   x11, x0, 2
  mulhu  x9,  x10, x11
  addi   x12, x0, -21
  addi   x13, x0, 21
  addi   x14, x0, 0
  div    x15, x12, x5
  rem    x16, x12, x5
  divu   x17, x13, x5
  remu   x24, x13, x5
  div    x25, x13, x14
  rem    x26, x13, x14
  divu   x27, x13, x14
  remu   x28, x13, x14
  lui    x18, 0x80000
  addi   x19, x0, -1
  div    x29, x18, x19
  rem    x30, x18, x19
  mul    x20, x1,  x2
  addi   x21, x20, 1
  div    x22, x12, x5
  addi   x23, x22, 2
  ebreak
