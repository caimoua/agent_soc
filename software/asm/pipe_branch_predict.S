// Static branch predictor directed test for rv32i_pipe_branch_predict_tb.

  .option norvc
  .option norelax
  .section .text.init, "ax", @progbits
  .globl _start

_start:
  addi  x1, x0, 0
  addi  x2, x0, 4

loop:
  addi  x1, x1, 1
  bne   x1, x2, loop

  addi  x3, x0, 0x33
  beq   x0, x0, forward_target
  addi  x4, x0, 0x44

forward_target:
  jal   x5, jal_target
  addi  x4, x0, 0x55

jal_target:
  addi  x6, x0, 0x66
  addi  x7, x0, 0x38
  jalr  x8, 0(x7)
  addi  x10, x0, 0x7a
  addi  x10, x0, 0x7b

jalr_target:
  addi  x9, x0, 0x77
  ebreak
