// Pipeline trap/CSR directed test.
//
// The trap handler is intentionally placed at 0x140 to prove that mtvec is
// updated before ECALL. CSR and MRET instructions use raw encodings so this
// image still builds with the base RV32I toolchain flags.

  .option norvc
  .option norelax
  .section .text.init, "ax", @progbits
  .globl _start

_start:
  addi  x1, x0, 99
  addi  x5, x0, 0x140
  .word 0x30529073  // csrrw x0, mtvec, x5
  ecall
  sw    x1, 20(x0)
  addi  x10, x0, 1
  .word 0x00000000  // illegal instruction
  addi  x11, x0, 1
  ebreak

  .rept 71
  addi  x0, x0, 0
  .endr

trap_handler:
  .word 0x34202373  // csrrs x6, mcause, x0
  .word 0x341023f3  // csrrs x7, mepc, x0
  slli  x8, x6, 2
  lw    x9, 20(x0)
  sw    x6, 40(x8)
  sw    x7, 80(x8)
  sw    x9, 120(x8)
  addi  x7, x7, 4
  .word 0x34139073  // csrrw x0, mepc, x7
  .word 0x30200073  // mret
