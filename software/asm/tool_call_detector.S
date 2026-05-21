// APB Tool-call Detector smoke program.

  .option norvc
  .option norelax
  .section .text.init, "ax", @progbits
  .globl _start

  .macro CHECK_EQ reg, expected, code
    li    x28, \expected
    beq   \reg, x28, 9f
    li    x30, \code
    jal   x0, fail
9:
  .endm

_start:
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

  lw    x5, 0x004(x1)   // STATUS = enable + match + irq_pending
  lw    x6, 0x010(x1)   // MATCH_COUNT
  lw    x7, 0x014(x1)   // TOKEN_COUNT
  lw    x8, 0x018(x1)   // IRQ_STATUS before clear

  CHECK_EQ x5, 0x0000000b, 30
  CHECK_EQ x6, 1,          31
  CHECK_EQ x7, 8,          32
  CHECK_EQ x8, 1,          33

  addi  x2, x0, 1
  sw    x2, 0x01c(x1)
  lw    x9, 0x018(x1)
  CHECK_EQ x9, 0,          34

  lw    x10, 0x004(x1)
  CHECK_EQ x10, 0x00000003, 35

pass:
  li    x29, 0xa7000001
  addi  x30, x0, 0
  addi  x31, x0, 1
  ebreak

fail:
  addi  x31, x0, 0
  ebreak
