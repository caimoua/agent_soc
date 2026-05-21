// Cached load/store access fault trap test.
//
// Expected final state:
//   x1  = 0x80000000
//   x2  = 0
//   x21 = 0x55
//   x22 = 0x66
//   x30 = 1
//   x31 = 1
//   sram[0] = load access fault mcause
//   sram[1] = load fault mepc
//   sram[2] = store access fault mcause
//   sram[3] = store fault mepc

  .option norvc
  .section .text.init, "ax", @progbits
  .globl _start

_start:
  addi  x5, x0, 0x140
  .word 0x30529073 // csrrw x0, mtvec, x5
  lui   x1, 0x80000
  lw    x2, 0(x1)
  addi  x21, x0, 0x55
  addi  x5, x0, 0x180
  .word 0x30529073 // csrrw x0, mtvec, x5
  sw    x21, 4(x1)
  addi  x22, x0, 0x66

  .rept 71
    addi x0, x0, 0
  .endr

  .org 0x140
load_access_fault_handler:
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
store_access_fault_handler:
  .word 0x34202573 // csrrs x10, mcause, x0
  .word 0x341025f3 // csrrs x11, mepc, x0
  lui   x20, 0x20000
  sw    x10, 8(x20)
  sw    x11, 12(x20)
  addi  x11, x11, 4
  .word 0x34159073 // csrrw x0, mepc, x11
  addi  x30, x0, 1
  .word 0x30200073 // mret
