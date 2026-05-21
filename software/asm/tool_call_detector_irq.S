// APB Tool-call Detector interrupt smoke program.
//
// The current core only exposes MTIP/MTIE, so the SoC maps Agent IRQs
// through the lightweight IRQ aggregator into the machine timer interrupt
// path. The handler identifies the real source from the detector IRQ_STATUS.

  .option norvc
  .option norelax
  .section .text.init, "ax", @progbits
  .globl _start

_start:
  addi  x21, x0, 0
  addi  x31, x0, 0

  li    x5, 0x08000140
  csrrw x0, mtvec, x5
  addi  x6, x0, 8
  csrrw x0, mstatus, x6
  addi  x7, x0, 128
  csrrw x0, mie, x7

  li    x1, 0x42003000

  addi  x2, x0, 4
  sw    x2, 0x008(x1)   // PATTERN_LEN = 4

  li    x2, 0x10021001  // pattern[0]=0x1001, pattern[1]=0x1002
  sw    x2, 0x020(x1)
  li    x2, 0x10041003  // pattern[2]=0x1003, pattern[3]=0x1004
  sw    x2, 0x024(x1)

  addi  x2, x0, 5      // enable + irq_en
  sw    x2, 0x000(x1)

  li    x2, 0x0001
  sw    x2, 0x00c(x1)
  li    x2, 0x1001
  sw    x2, 0x00c(x1)
  li    x2, 0x1002
  sw    x2, 0x00c(x1)
  li    x2, 0x9999
  sw    x2, 0x00c(x1)
  li    x2, 0x1001
  sw    x2, 0x00c(x1)
  li    x2, 0x1002
  sw    x2, 0x00c(x1)
  li    x2, 0x1003
  sw    x2, 0x00c(x1)
  li    x2, 0x1004
  sw    x2, 0x00c(x1)

wait_irq:
  beq   x31, x0, wait_irq

  addi  x21, x0, 0x77
  li    x29, 0xa7000004
  addi  x30, x0, 0
  ebreak

  .org 0x140

tool_call_irq_handler:
  csrrs x10, mcause, x0
  csrrs x11, mepc, x0
  csrrs x12, mstatus, x0
  csrrs x13, mie, x0
  csrrs x14, mip, x0

  li    x1, 0x42003000
  lw    x15, 0x018(x1)  // Tool-call Detector IRQ_STATUS before clear
  addi  x2, x0, 1
  sw    x2, 0x01c(x1)
  csrrw x0, mie, x0

  li    x20, 0x20000000
  sw    x10, 0(x20)
  sw    x11, 4(x20)
  sw    x12, 8(x20)
  sw    x13, 12(x20)
  sw    x14, 16(x20)
  sw    x15, 20(x20)

  addi  x31, x0, 1
  mret
