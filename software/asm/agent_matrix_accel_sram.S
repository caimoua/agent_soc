// APB Agent Matrix Accelerator SRAM-mode smoke program.

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
  li    x1, 0x42002000
  li    x12, 0x20000000
  li    x13, 0x20000040
  li    x14, 0x20000080

  // Matrix rows, packed little-endian int8 per word.
  li    x2, 0xfe02ff01
  sw    x2, 0x00(x12)
  li    x2, 0x06fb0403
  sw    x2, 0x04(x12)
  li    x2, 0xf60908f9
  sw    x2, 0x08(x12)
  li    x2, 0x0e0df40b
  sw    x2, 0x0c(x12)

  // Vector = [1, 2, 3, 4].
  li    x2, 0x04030201
  sw    x2, 0x00(x13)

  sw    x12, 0x008(x1)  // SRC_A
  sw    x13, 0x00c(x1)  // SRC_B
  sw    x14, 0x010(x1)  // DST
  addi  x2, x0, 4
  sw    x2, 0x018(x1)   // STRIDE_A
  sw    x2, 0x01c(x1)   // STRIDE_B
  sw    x2, 0x020(x1)   // STRIDE_D
  addi  x2, x0, 1
  sw    x2, 0x024(x1)   // FLAGS.bit0 = SRAM mode
  sw    x2, 0x000(x1)   // CTRL.start

poll_done:
  lw    x3, 0x004(x1)
  andi  x4, x3, 2
  beq   x4, x0, poll_done
  andi  x4, x3, 8
  beq   x4, x0, no_error
  li    x30, 20
  jal   x0, fail

no_error:
  lw    x5, 0x00(x14)
  lw    x6, 0x04(x14)
  lw    x7, 0x08(x14)
  lw    x8, 0x0c(x14)

  CHECK_EQ x5, 0xfffffffd, 21
  CHECK_EQ x6, 20,         22
  CHECK_EQ x7, 0xfffffffc, 23
  CHECK_EQ x8, 82,         24

  add   x9, x5, x6
  add   x9, x9, x7
  add   x9, x9, x8
  CHECK_EQ x9, 95, 25

  lw    x10, 0x028(x1)
  CHECK_EQ x10, 1, 26
  addi  x2, x0, 1
  sw    x2, 0x02c(x1)
  lw    x11, 0x028(x1)
  CHECK_EQ x11, 0, 27

pass:
  li    x29, 0xa6000003
  addi  x30, x0, 0
  addi  x31, x0, 1
  ebreak

fail:
  addi  x31, x0, 0
  ebreak
