// Cached timer interrupt smoke test.
//
// Expected final state:
//   mtvec = 0x00000140
//   timer mtimecmp_lo = 10
//   timer ctrl = 3
//   handler stores mcause/mepc/mstatus/mie/mip at SRAM 0x20000000
//   x21 = 0x55 after MRET resume
//   x31 = 1 after interrupt handler

  .option norvc
  .section .text.init, "ax", @progbits
  .globl _start

_start:
  addi  x5, x0, 0x140
  csrrw x0, mtvec, x5
  addi  x6, x0, 8
  csrrw x0, mstatus, x6
  addi  x7, x0, 128
  csrrw x0, mie, x7
  lui   x1, 0x40000
  addi  x2, x0, 10
  sw    x2, 8(x1)
  sw    x0, 12(x1)
  addi  x3, x0, 3
  sw    x3, 16(x1)
  addi  x16, x0, 0x11

  .rept 49
  addi  x0, x0, 0
  .endr

  addi  x21, x0, 0x55
  addi  x0, x0, 0

  .rept 16
  addi  x0, x0, 0
  .endr

  .if (. - _start) != 0x140
  .error "cached_timer_irq handler must start at 0x140"
  .endif
  .org 0x140

timer_irq_handler:
  csrrs x10, mcause, x0
  csrrs x11, mepc, x0
  csrrs x12, mstatus, x0
  csrrs x13, mie, x0
  csrrs x14, mip, x0
  lui   x20, 0x20000
  sw    x10, 0(x20)
  sw    x11, 4(x20)
  sw    x12, 8(x20)
  sw    x13, 12(x20)
  sw    x14, 16(x20)
  csrrw x0, mie, x0
  addi  x31, x0, 1
  mret
