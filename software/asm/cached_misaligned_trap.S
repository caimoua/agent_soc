// Cached load/store/instruction misaligned trap test.
//
// Expected final state:
//   x1  = 0x20000000
//   x21 = 0x55
//   x22 = 0x66
//   x23 = 0x77
//   x29/x30/x31 = 1
//   sram[0..5] contain mcause/mepc pairs for load/store/instruction traps

  .option norvc
  .section .text.init, "ax", @progbits
  .globl _start

_start:
  addi  x5, x0, 0x140
  .word 0x30529073 // csrrw x0, mtvec, x5
  lui   x1, 0x20000
  lw    x2, 2(x1)
  addi  x21, x0, 0x55
  addi  x5, x0, 0x180
  .word 0x30529073 // csrrw x0, mtvec, x5
  sw    x21, 26(x1)
  addi  x22, x0, 0x66
  addi  x5, x0, 0x1c0
  .word 0x30529073 // csrrw x0, mtvec, x5
  addi  x6, x0, 0x32
  jalr  x0, x6, 0
  addi  x23, x0, 0x77

  .rept 66
    addi x0, x0, 0
  .endr

  .org 0x140
load_misaligned_handler:
  .word 0x34202573 // csrrs x10, mcause, x0
  .word 0x341025f3 // csrrs x11, mepc, x0
  lui   x20, 0x20000
  sw    x10, 0(x20)
  sw    x11, 4(x20)
  addi  x11, x11, 4
  .word 0x34159073 // csrrw x0, mepc, x11
  addi  x31, x0, 1
  .word 0x30200073 // mret

  .rept 7
    addi x0, x0, 0
  .endr

  .org 0x180
store_misaligned_handler:
  .word 0x34202573 // csrrs x10, mcause, x0
  .word 0x341025f3 // csrrs x11, mepc, x0
  lui   x20, 0x20000
  sw    x10, 8(x20)
  sw    x11, 12(x20)
  addi  x11, x11, 4
  .word 0x34159073 // csrrw x0, mepc, x11
  addi  x30, x0, 1
  .word 0x30200073 // mret

  .rept 7
    addi x0, x0, 0
  .endr

  .org 0x1c0
instr_misaligned_handler:
  .word 0x34202573 // csrrs x10, mcause, x0
  .word 0x341025f3 // csrrs x11, mepc, x0
  lui   x20, 0x20000
  sw    x10, 16(x20)
  sw    x11, 20(x20)
  addi  x11, x11, 4
  .word 0x34159073 // csrrw x0, mepc, x11
  addi  x29, x0, 1
  .word 0x30200073 // mret
