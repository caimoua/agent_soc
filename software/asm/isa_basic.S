// Project-local RV32I/RV32M ISA smoke subset for rv32i_pipe_isa_basic_tb.

  .option norvc
  .option norelax
  .section .text.init, "ax", @progbits
  .globl _start

  .macro CHECK_EQ reg, expected, code
    li    x31, \expected
    beq   \reg, x31, 9f
    li    x30, \code
    jal   x0, fail
9:
  .endm

_start:
  addi  x30, x0, 0
  addi  x31, x0, 0

  // RV32I integer register/immediate operations.
  addi  x1, x0, 10
  addi  x2, x0, -3
  add   x3, x1, x2
  CHECK_EQ x3, 7, 1
  sub   x4, x1, x2
  CHECK_EQ x4, 13, 2
  xori  x5, x4, 0x55
  CHECK_EQ x5, 0x58, 3
  ori   x6, x5, 0x0f
  CHECK_EQ x6, 0x5f, 4
  andi  x7, x6, 0x33
  CHECK_EQ x7, 0x13, 5
  slli  x8, x7, 2
  CHECK_EQ x8, 0x4c, 6
  srli  x9, x8, 3
  CHECK_EQ x9, 9, 7
  li    x10, 0x80000000
  srai  x11, x10, 31
  CHECK_EQ x11, 0xffffffff, 8
  srli  x12, x10, 31
  CHECK_EQ x12, 1, 9
  slti  x13, x2, 0
  CHECK_EQ x13, 1, 10
  sltiu x14, x0, -1
  CHECK_EQ x14, 1, 11
  slt   x15, x2, x1
  CHECK_EQ x15, 1, 12
  sltu  x16, x2, x1
  CHECK_EQ x16, 0, 13
  xor   x17, x6, x7
  CHECK_EQ x17, 0x4c, 14
  or    x18, x7, x8
  CHECK_EQ x18, 0x5f, 15
  and   x19, x18, x6
  CHECK_EQ x19, 0x5f, 16
  lui   x20, 0x12345
  CHECK_EQ x20, 0x12345000, 17
  auipc x21, 0
  addi  x21, x21, 8
  auipc x22, 0
  beq   x21, x22, auipc_ok
  li    x30, 18
  jal   x0, fail
auipc_ok:

  // RV32I load/store sizes and sign extension.
  addi  x23, x0, 0
  li    x1, 0x12345678
  sw    x1, 0(x23)
  lw    x2, 0(x23)
  CHECK_EQ x2, 0x12345678, 30
  li    x3, -1
  sb    x3, 4(x23)
  lb    x4, 4(x23)
  CHECK_EQ x4, 0xffffffff, 31
  lbu   x5, 4(x23)
  CHECK_EQ x5, 0xff, 32
  li    x3, 0x80
  sb    x3, 5(x23)
  lb    x6, 5(x23)
  CHECK_EQ x6, 0xffffff80, 33
  lbu   x7, 5(x23)
  CHECK_EQ x7, 0x80, 34
  li    x3, 0x8001
  sh    x3, 8(x23)
  lh    x8, 8(x23)
  CHECK_EQ x8, 0xffff8001, 35
  lhu   x9, 8(x23)
  CHECK_EQ x9, 0x8001, 36
  li    x10, 0
  sw    x10, 12(x23)
  li    x11, 0xaa
  sb    x11, 13(x23)
  lw    x12, 12(x23)
  CHECK_EQ x12, 0x0000aa00, 37

  // RV32I branch and jump behavior.
  addi  x1, x0, 10
  addi  x2, x0, -3
  addi  x24, x0, 0
  beq   x0, x0, beq_taken
  li    x30, 50
  jal   x0, fail
beq_taken:
  addi  x24, x24, 1
  bne   x24, x0, bne_taken
  li    x30, 51
  jal   x0, fail
bne_taken:
  addi  x24, x24, 2
  blt   x2, x1, blt_taken
  li    x30, 52
  jal   x0, fail
blt_taken:
  addi  x24, x24, 4
  bge   x1, x2, bge_taken
  li    x30, 53
  jal   x0, fail
bge_taken:
  addi  x24, x24, 8
  bltu  x1, x2, bltu_taken
  li    x30, 54
  jal   x0, fail
bltu_taken:
  addi  x24, x24, 16
  bgeu  x2, x1, bgeu_taken
  li    x30, 55
  jal   x0, fail
bgeu_taken:
  addi  x24, x24, 32
  CHECK_EQ x24, 63, 56

  auipc x25, 0
  jal   x26, jal_target
  li    x30, 57
  jal   x0, fail
jal_target:
  addi  x25, x25, 8
  beq   x25, x26, jal_ra_ok
  li    x30, 58
  jal   x0, fail
jal_ra_ok:
  auipc x25, 0
  addi  x25, x25, 20
  jalr  x26, x25, 0
  li    x30, 59
  jal   x0, fail
jalr_target:
  addi  x25, x25, -8
  beq   x25, x26, jalr_ra_ok
  li    x30, 60
  jal   x0, fail
jalr_ra_ok:

  // RV32M multiply/divide/remainder and architectural edge cases.
  addi   x1,  x0, 6
  addi   x2,  x0, 7
  mul    x3,  x1, x2
  CHECK_EQ x3, 42, 70
  addi   x4,  x0, -3
  addi   x5,  x0, 5
  mul    x6,  x4, x5
  CHECK_EQ x6, 0xfffffff1, 71
  mulh   x7,  x4, x5
  CHECK_EQ x7, 0xffffffff, 72
  mulhsu x8,  x4, x5
  CHECK_EQ x8, 0xffffffff, 73
  li     x9,  0xffffffff
  addi   x10, x0, 2
  mulhu  x11, x9, x10
  CHECK_EQ x11, 1, 74
  addi   x12, x0, -21
  div    x13, x12, x5
  CHECK_EQ x13, 0xfffffffc, 75
  rem    x14, x12, x5
  CHECK_EQ x14, 0xffffffff, 76
  addi   x15, x0, 21
  divu   x16, x15, x5
  CHECK_EQ x16, 4, 77
  remu   x17, x15, x5
  CHECK_EQ x17, 1, 78
  addi   x18, x0, 0
  div    x19, x15, x18
  CHECK_EQ x19, 0xffffffff, 79
  rem    x20, x15, x18
  CHECK_EQ x20, 21, 80
  li     x21, 0x80000000
  addi   x22, x0, -1
  div    x23, x21, x22
  CHECK_EQ x23, 0x80000000, 81
  rem    x24, x21, x22
  CHECK_EQ x24, 0, 82

pass:
  li    x29, 0x1a500003
  addi  x30, x0, 0
  addi  x31, x0, 1
  ebreak

fail:
  addi  x31, x0, 0
  ebreak
