// Pipeline core directed test for forwarding, load-use stalls, memory waits,
// branch/JAL/JALR flushes and performance counters.

  .option norvc
  .option norelax
  .section .text.init, "ax", @progbits
  .globl _start

_start:
  // Forwarding and load-use program.
  addi  x1, x0, 5
  addi  x2, x0, 7
  add   x3, x1, x2
  sub   x4, x3, x1
  add   x5, x4, x3
  xori  x6, x5, 15
  or    x7, x6, x5
  and   x8, x7, x6
  sw    x8, 0(x0)
  addi  x9, x0, 1
  addi  x9, x9, 2
  add   x10, x9, x0
  lui   x11, 0x12345
  auipc x12, 0x1

  // Direct load-use hazards: each consumer immediately follows a load.
  lw    x13, 0(x0)
  add   x14, x13, x2
  lw    x15, 0(x0)
  add   x16, x2, x15
  lw    x17, 0(x0)
  sw    x17, 4(x0)
  lw    x18, 0(x0)
  sw    x2, 0(x18)

  // Control hazards: taken branch, JAL and JALR must flush wrong-path ops.
  addi  x19, x0, 0
  beq   x1, x2, branch_not_taken_skip
  addi  x19, x19, 1
branch_not_taken_skip:
  bne   x1, x2, branch_taken_target
  addi  x19, x19, 1024
branch_taken_target:
  addi  x19, x19, 2
  jal   x20, jal_target
  addi  x19, x19, 1024
jal_target:
  addi  x19, x19, 4
  addi  x21, x0, 0x88
  jalr  x22, x21, 0
  addi  x19, x19, 1024

jalr_target:
  addi  x19, x19, 8
  ebreak
