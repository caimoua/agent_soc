// Agent workload baseline for rv32i_agent_workload_tb.
//
// Workloads:
// - event loop / tool dispatch branch chain
// - token pattern scan
// - INT8 dot product
// - tiny INT8 matvec

  .option norvc
  .option norelax
  .section .text.init, "ax", @progbits
  .globl _start

  .macro CHECK_EQ reg, expected, code
    li    x31, \expected
    beq   \reg, x31, 9f
    li    x30, \code
    jal   x0, fail
9:
  .endm

_start:
  addi  x30, x0, 0
  addi  x31, x0, 0
  addi  x20, x0, 0       // dmem base used by current directed testbenches

  // --------------------------------------------------------------------------
  // Agent event loop + tool dispatch.
  // task types: 1, 3, 2, 1. Dispatch score: 10 + 1000 + 100 + 10 = 1120.
  // --------------------------------------------------------------------------
  addi  x1, x20, 64
  addi  x2, x0, 1
  sw    x2, 0(x1)
  addi  x2, x0, 3
  sw    x2, 4(x1)
  addi  x2, x0, 2
  sw    x2, 8(x1)
  addi  x2, x0, 1
  sw    x2, 12(x1)

  addi  x3, x0, 0        // i
  addi  x4, x0, 4        // task_count
  addi  x5, x0, 0        // dispatch_score
event_loop:
  slli  x6, x3, 2
  add   x7, x1, x6
  lw    x8, 0(x7)

  addi  x9, x0, 0
  beq   x8, x9, tool_none
  addi  x9, x0, 1
  beq   x8, x9, tool_gpio
  addi  x9, x0, 2
  beq   x8, x9, tool_timer
  addi  x9, x0, 3
  beq   x8, x9, tool_uart
  li    x30, 10
  jal   x0, fail

tool_none:
  addi  x5, x5, 1
  jal   x0, tool_done
tool_gpio:
  addi  x5, x5, 10
  jal   x0, tool_done
tool_timer:
  addi  x5, x5, 100
  jal   x0, tool_done
tool_uart:
  li    x10, 1000
  add   x5, x5, x10

tool_done:
  addi  x3, x3, 1
  blt   x3, x4, event_loop
  CHECK_EQ x5, 1120, 11
  sw    x5, 0(x20)

  // --------------------------------------------------------------------------
  // Token pattern scan.
  // Pattern appears once at token index 2.
  // --------------------------------------------------------------------------
  addi  x1, x20, 128
  li    x2, 0x0011
  sh    x2, 0(x1)
  li    x2, 0x0022
  sh    x2, 2(x1)
  li    x2, 0x0102
  sh    x2, 4(x1)
  li    x2, 0x0203
  sh    x2, 6(x1)
  li    x2, 0x0304
  sh    x2, 8(x1)
  li    x2, 0x0405
  sh    x2, 10(x1)
  li    x2, 0x0033
  sh    x2, 12(x1)
  li    x2, 0x0044
  sh    x2, 14(x1)

  addi  x3, x0, 0        // scan index
  addi  x4, x0, 5        // last start index + 1
  addi  x5, x0, 0        // match count
  addi  x6, x0, -1       // first match index
token_scan_loop:
  slli  x7, x3, 1
  add   x8, x1, x7
  lhu   x9, 0(x8)
  li    x10, 0x0102
  bne   x9, x10, token_next
  lhu   x9, 2(x8)
  li    x10, 0x0203
  bne   x9, x10, token_next
  lhu   x9, 4(x8)
  li    x10, 0x0304
  bne   x9, x10, token_next
  lhu   x9, 6(x8)
  li    x10, 0x0405
  bne   x9, x10, token_next
  addi  x5, x5, 1
  add   x6, x3, x0
token_next:
  addi  x3, x3, 1
  blt   x3, x4, token_scan_loop
  CHECK_EQ x5, 1, 21
  CHECK_EQ x6, 2, 22
  sw    x5, 4(x20)
  sw    x6, 8(x20)

  // --------------------------------------------------------------------------
  // INT8 dot product:
  // [1, -2, 3, -4] dot [5, 6, -7, -8] = 4.
  // --------------------------------------------------------------------------
  addi  x1, x20, 192
  addi  x2, x0, 1
  sb    x2, 0(x1)
  addi  x2, x0, -2
  sb    x2, 1(x1)
  addi  x2, x0, 3
  sb    x2, 2(x1)
  addi  x2, x0, -4
  sb    x2, 3(x1)
  addi  x2, x0, 5
  sb    x2, 4(x1)
  addi  x2, x0, 6
  sb    x2, 5(x1)
  addi  x2, x0, -7
  sb    x2, 6(x1)
  addi  x2, x0, -8
  sb    x2, 7(x1)

  addi  x3, x0, 0        // i
  addi  x4, x0, 4        // len
  addi  x5, x0, 0        // accumulator
dot_loop:
  add   x6, x1, x3
  lb    x7, 0(x6)
  addi  x6, x6, 4
  lb    x8, 0(x6)
  mul   x9, x7, x8
  add   x5, x5, x9
  addi  x3, x3, 1
  blt   x3, x4, dot_loop
  CHECK_EQ x5, 4, 31
  sw    x5, 12(x20)

  // --------------------------------------------------------------------------
  // Tiny INT8 matvec, 2 rows x 4 columns.
  // vec = [1, 2, 3, 4]
  // row0 = [1, -1, 2, -2] => -3
  // row1 = [3, 4, -5, 6]  => 20
  // checksum = 17
  // --------------------------------------------------------------------------
  addi  x1, x20, 224     // vector base
  addi  x2, x0, 1
  sb    x2, 0(x1)
  addi  x2, x0, 2
  sb    x2, 1(x1)
  addi  x2, x0, 3
  sb    x2, 2(x1)
  addi  x2, x0, 4
  sb    x2, 3(x1)

  addi  x11, x20, 240    // matrix base
  addi  x2, x0, 1
  sb    x2, 0(x11)
  addi  x2, x0, -1
  sb    x2, 1(x11)
  addi  x2, x0, 2
  sb    x2, 2(x11)
  addi  x2, x0, -2
  sb    x2, 3(x11)
  addi  x2, x0, 3
  sb    x2, 4(x11)
  addi  x2, x0, 4
  sb    x2, 5(x11)
  addi  x2, x0, -5
  sb    x2, 6(x11)
  addi  x2, x0, 6
  sb    x2, 7(x11)

  addi  x12, x0, 0       // checksum
  addi  x13, x0, 0       // row
  addi  x14, x0, 2       // rows
matvec_row_loop:
  addi  x15, x0, 0       // col
  addi  x16, x0, 0       // row acc
matvec_col_loop:
  add   x17, x1, x15
  lb    x18, 0(x17)
  slli  x19, x13, 2
  add   x19, x19, x15
  add   x19, x11, x19
  lb    x21, 0(x19)
  mul   x22, x18, x21
  add   x16, x16, x22
  addi  x15, x15, 1
  blt   x15, x4, matvec_col_loop
  slli  x23, x13, 2
  addi  x23, x23, 16
  add   x23, x20, x23
  sw    x16, 0(x23)
  add   x12, x12, x16
  addi  x13, x13, 1
  blt   x13, x14, matvec_row_loop
  CHECK_EQ x12, 17, 41
  sw    x12, 24(x20)

pass:
  li    x29, 0xa6000001
  addi  x30, x0, 0
  addi  x31, x0, 1
  ebreak

fail:
  addi  x31, x0, 0
  ebreak
