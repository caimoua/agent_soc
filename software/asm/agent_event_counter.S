// Agent event/perf counter smoke program.

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

  .macro CHECK_NEZ reg, code
    bne   \reg, x0, 9f
    li    x30, \code
    jal   x0, fail
9:
  .endm

  .macro CHECK_REG_EQ lhs, rhs, code
    beq   \lhs, \rhs, 9f
    li    x30, \code
    jal   x0, fail
9:
  .endm

_start:
  li    x18, 0x42004000
  addi  x2, x0, 1
  sw    x2, 0x000(x18)  // clear event counters

  li    x1, 0x42002000

  li    x2, 0xfe02ff01
  sw    x2, 0x100(x1)
  li    x2, 0x06fb0403
  sw    x2, 0x104(x1)
  li    x2, 0xf60908f9
  sw    x2, 0x108(x1)
  li    x2, 0x0e0df40b
  sw    x2, 0x10c(x1)
  li    x2, 0x04030201
  sw    x2, 0x140(x1)

  addi  x2, x0, 3      // start + irq_en
  sw    x2, 0x000(x1)

poll_matrix_done:
  lw    x3, 0x004(x1)
  andi  x4, x3, 2
  beq   x4, x0, poll_matrix_done

  lw    x20, 0x180(x1)
  CHECK_EQ x20, 0xfffffffd, 10
  lw    x20, 0x184(x1)
  CHECK_EQ x20, 20,         11
  lw    x20, 0x188(x1)
  CHECK_EQ x20, 0xfffffffc, 12
  lw    x20, 0x18c(x1)
  CHECK_EQ x20, 82,         13

  lw    x20, 0x028(x1)
  CHECK_EQ x20, 1,          14
  addi  x2, x0, 1
  sw    x2, 0x02c(x1)

  li    x17, 0x42003000

  addi  x2, x0, 4
  sw    x2, 0x008(x17)
  li    x2, 0x10021001
  sw    x2, 0x020(x17)
  li    x2, 0x10041003
  sw    x2, 0x024(x17)
  addi  x2, x0, 5      // enable + irq_en
  sw    x2, 0x000(x17)

  li    x2, 0x0001
  sw    x2, 0x00c(x17)
  li    x2, 0x1001
  sw    x2, 0x00c(x17)
  li    x2, 0x1002
  sw    x2, 0x00c(x17)
  li    x2, 0x9999
  sw    x2, 0x00c(x17)
  li    x2, 0x1001
  sw    x2, 0x00c(x17)
  li    x2, 0x1002
  sw    x2, 0x00c(x17)
  li    x2, 0x1003
  sw    x2, 0x00c(x17)
  li    x2, 0x1004
  sw    x2, 0x00c(x17)

  .rept 8
  addi  x0, x0, 0
  .endr

  lw    x20, 0x018(x17)
  CHECK_EQ x20, 1,          20
  addi  x2, x0, 1
  sw    x2, 0x01c(x17)

  lw    x5,  0x008(x18)  // TOOL_TOKEN_COUNT
  lw    x6,  0x00c(x18)  // TOOL_MATCH_COUNT
  lw    x7,  0x010(x18)  // TOOL_IRQ_COUNT
  lw    x8,  0x014(x18)  // MATRIX_START_COUNT
  lw    x9,  0x018(x18)  // MATRIX_DONE_COUNT
  lw    x10, 0x01c(x18)  // AGENT_IRQ_COUNT
  lw    x11, 0x020(x18)  // LAST_IRQ_SOURCE
  lw    x12, 0x024(x18)  // LATENCY_LAST
  lw    x16, 0x028(x18)  // LATENCY_MIN
  lw    x19, 0x02c(x18)  // LATENCY_MAX
  lw    x13, 0x030(x18)  // LATENCY_COUNT
  lw    x14, 0x034(x18)  // MATRIX_IRQ_COUNT
  lw    x15, 0x038(x18)  // TIMER_IRQ_COUNT

  CHECK_EQ  x5,  8,          30
  CHECK_EQ  x6,  1,          31
  CHECK_EQ  x7,  1,          32
  CHECK_EQ  x8,  1,          33
  CHECK_EQ  x9,  1,          34
  CHECK_EQ  x10, 2,          35
  CHECK_EQ  x11, 0x0000000c, 36
  CHECK_NEZ x12,             37
  CHECK_EQ  x13, 1,          38
  CHECK_EQ  x14, 1,          39
  CHECK_EQ  x15, 0,          40
  CHECK_REG_EQ x16, x12,     41
  CHECK_REG_EQ x19, x12,     42

pass:
  li    x29, 0xa8000001
  addi  x30, x0, 0
  addi  x31, x0, 1
  ebreak

fail:
  addi  x31, x0, 0
  ebreak
