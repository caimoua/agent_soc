// Single-cycle RV32I core directed smoke test.
//
// Keep this sequence aligned with rv32i_core_tb snapshots:
//   0x084 captures the JAL return value before x24 is reused.
//   0x0e8 captures the branch score before memory tests reuse x24.
//   0x100 captures the LW result.
//   0x124/0x128 are ECALL/EBREAK debug events.

  .option norvc
  .option norelax
  .section .text.init, "ax", @progbits
  .globl _start

_start:
  addi x1, x0, 5
  addi x2, x0, 7
  add  x3, x1, x2
  sub  x4, x3, x1

  addi x5, x0, -8

  slti  x6, x5, 0
  sltiu x7, x5, 0
  andi  x8, x1, 4
  ori   x9, x1, 8
  xori  x10, x1, 7
  slli  x11, x2, 2
  srli  x12, x2, 1
  srai  x13, x5, 2

  sll   x14, x1, x2
  slt   x15, x5, x1
  sltu  x16, x5, x1
  xor   x17, x1, x2
  srl   x18, x5, x1
  sra   x19, x5, x1
  or    x20, x1, x2
  and   x21, x1, x2

  lui   x22, 0x12345
  auipc x23, 0x10000

  jal   x24, jal_landing
  addi  x25, x0, 1
jal_landing:
  addi  x25, x0, 0x0de
  addi  x26, x0, 0x80
  jalr  x27, x26, 0
  addi  x28, x0, 1
  addi  x0, x0, 0
  addi  x0, x0, 0
  addi  x0, x0, 0
jalr_landing:
  addi  x28, x0, 0x0ff

  addi x24, x0, 0
  beq  x1, x1, beq_pass
  addi x24, x24, 1024
  jal  x0, beq_done
beq_pass:
  addi x24, x24, 1
beq_done:
  bne  x1, x2, bne_pass
  addi x24, x24, 1024
  jal  x0, bne_done
bne_pass:
  addi x24, x24, 2
bne_done:
  blt  x5, x1, blt_pass
  addi x24, x24, 1024
  jal  x0, blt_done
blt_pass:
  addi x24, x24, 4
blt_done:
  bge  x1, x5, bge_pass
  addi x24, x24, 1024
  jal  x0, bge_done
bge_pass:
  addi x24, x24, 8
bge_done:
  bltu x1, x5, bltu_pass
  addi x24, x24, 1024
  jal  x0, bltu_done
bltu_pass:
  addi x24, x24, 16
bltu_done:
  bgeu x1, x5, bgeu_fail
  addi x24, x24, 32
  jal  x0, branch_done
bgeu_fail:
  addi x24, x24, 1024

branch_done:
  lui  x24, 0x12345
  addi x24, x24, 0x678
  sw   x24, 4(x0)
  addi x24, x0, 0
  lw   x24, 4(x0)

  addi x29, x0, -1
  sb   x29, 8(x0)
  sb   x29, 11(x0)
  lb   x30, 8(x0)
  lbu  x31, 11(x0)
  sh   x29, 14(x0)
  lh   x29, 14(x0)
  lhu  x24, 14(x0)

  sw    x25, 16(x0)
  .word 0xc0002cf3  // csrrs x25, cycle, x0
  ecall
  ebreak
