// Cached instruction access fault trap test.
//
// Expected final state:
//   x1  = 0x80000000
//   x10 = 1
//   x11 = 0x10
//   x12 = 0
//   x21 = 0x55
//   x31 = 1
//   sram[0] = instruction access fault mcause
//   sram[1] = faulting fetch PC
//   sram[2] = handler mstatus

  .option norvc
  .section .text.init, "ax", @progbits
  .globl _start

_start:
  addi  x5, x0, 0x140
  .word 0x30529073 // csrrw x0, mtvec, x5
  lui   x1, 0x80000
  jalr  x0, x1, 0
  addi  x21, x0, 0x55

  .rept 75
    addi x0, x0, 0
  .endr

  .org 0x140
instr_access_fault_handler:
  .word 0x34202573 // csrrs x10, mcause, x0
  .word 0x341025f3 // csrrs x11, mepc, x0
  .word 0x30002673 // csrrs x12, mstatus, x0
  lui   x20, 0x20000
  sw    x10, 0(x20)
  sw    x11, 4(x20)
  sw    x12, 8(x20)
  addi  x11, x0, 0x10
  .word 0x34159073 // csrrw x0, mepc, x11
  addi  x31, x0, 1
  .word 0x30200073 // mret
