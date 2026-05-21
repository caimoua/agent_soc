// Dynamic BHT/BTB learning test for rv32i_pipe_dynamic_branch_predict_tb.

  .option norvc
  .option norelax
  .section .text.init, "ax", @progbits
  .globl _start

_start:
  addi  x1, x0, 0
  addi  x2, x0, 4
  addi  x3, x0, 0
  addi  x4, x0, 0

forward_branch:
  beq   x0, x0, forward_target
  addi  x4, x4, 1

forward_target:
  addi  x3, x3, 1
  addi  x1, x1, 1
  bne   x1, x2, forward_branch
  addi  x5, x0, 0x55
  ebreak
