// Cached UART MMIO smoke test.
//
// Expected final state:
//   x1 = 0x40001000
//   x2 = 0x0a
//   x3 = 1
//   x4 = 0x0a
//   UART output = "UART\n"

  .option norvc
  .section .text.init, "ax", @progbits
  .globl _start

_start:
  lui   x1, 0x40001
  lw    x3, 4(x1)

  addi  x2, x0, 0x55
  sb    x2, 0(x1)
  addi  x2, x0, 0x41
  sb    x2, 0(x1)
  addi  x2, x0, 0x52
  sb    x2, 0(x1)
  addi  x2, x0, 0x54
  sb    x2, 0(x1)
  addi  x2, x0, 0x0a
  sb    x2, 0(x1)

  lw    x4, 0(x1)
  ebreak
