`ifndef RV32I_DEFS_VH
`define RV32I_DEFS_VH

`define RV32I_XLEN 32

`define RV32I_OPCODE_LUI      7'b0110111
`define RV32I_OPCODE_AUIPC    7'b0010111
`define RV32I_OPCODE_JAL      7'b1101111
`define RV32I_OPCODE_JALR     7'b1100111
`define RV32I_OPCODE_BRANCH   7'b1100011
`define RV32I_OPCODE_LOAD     7'b0000011
`define RV32I_OPCODE_STORE    7'b0100011
`define RV32I_OPCODE_OP_IMM   7'b0010011
`define RV32I_OPCODE_OP       7'b0110011
`define RV32I_OPCODE_SYSTEM   7'b1110011

`define RV32I_ALU_ADD  4'd0
`define RV32I_ALU_SUB  4'd1
`define RV32I_ALU_AND  4'd2
`define RV32I_ALU_OR   4'd3
`define RV32I_ALU_XOR  4'd4
`define RV32I_ALU_SLL  4'd5
`define RV32I_ALU_SRL  4'd6
`define RV32I_ALU_SRA  4'd7
`define RV32I_ALU_SLT  4'd8
`define RV32I_ALU_SLTU 4'd9

`define RV32I_MULDIV_MUL    3'b000
`define RV32I_MULDIV_MULH   3'b001
`define RV32I_MULDIV_MULHSU 3'b010
`define RV32I_MULDIV_MULHU  3'b011
`define RV32I_MULDIV_DIV    3'b100
`define RV32I_MULDIV_DIVU   3'b101
`define RV32I_MULDIV_REM    3'b110
`define RV32I_MULDIV_REMU   3'b111

`define RV32I_WB_ALU    3'b000
`define RV32I_WB_LUI    3'b001
`define RV32I_WB_AUIPC  3'b010
`define RV32I_WB_PC4    3'b011  // pc + 4
`define RV32I_WB_MEM    3'b100  // data memory read data
`define RV32I_WB_CSR    3'b101  // CSR read data

`define RV32I_PC_NEXT    2'b00  // pc + 4
`define RV32I_PC_JAL     2'b01  // pc + imm_j
`define RV32I_PC_JALR    2'b10  // (rs1 + imm_i) & ~1
`define RV32I_PC_BRANCH  2'b11  // taken ? pc + imm_b : pc + 4

`define RV32I_BR_BEQ   3'b000
`define RV32I_BR_BNE   3'b001
`define RV32I_BR_BLT   3'b100
`define RV32I_BR_BGE   3'b101
`define RV32I_BR_BLTU  3'b110
`define RV32I_BR_BGEU  3'b111

`define RV32I_MEM_BYTE 2'b00
`define RV32I_MEM_HALF 2'b01
`define RV32I_MEM_WORD 2'b10

`define RV32I_CSR_MSTATUS 12'h300
`define RV32I_CSR_MIE     12'h304
`define RV32I_CSR_MTVEC   12'h305
`define RV32I_CSR_MEPC    12'h341
`define RV32I_CSR_MCAUSE  12'h342
`define RV32I_CSR_MIP     12'h344
`define RV32I_CSR_CYCLE   12'hc00

`define RV32I_MSTATUS_MIE   3
`define RV32I_MSTATUS_MPIE  7
`define RV32I_MIE_MTIE      7
`define RV32I_MIP_MTIP      7

`define RV32I_SYS_NONE    2'd0
`define RV32I_SYS_ECALL   2'd1
`define RV32I_SYS_EBREAK  2'd2
`define RV32I_SYS_MRET    2'd3

`define RV32I_CSR_OP_NONE 2'd0
`define RV32I_CSR_OP_RW   2'd1
`define RV32I_CSR_OP_RS   2'd2

`define RV32I_TRAP_CAUSE_INSTR_ADDR_MISALIGNED 32'd0
`define RV32I_TRAP_CAUSE_INSTR_ACCESS_FAULT    32'd1
`define RV32I_TRAP_CAUSE_ILLEGAL               32'd2
`define RV32I_TRAP_CAUSE_EBREAK                32'd3
`define RV32I_TRAP_CAUSE_LOAD_ADDR_MISALIGNED  32'd4
`define RV32I_TRAP_CAUSE_LOAD_ACCESS_FAULT     32'd5
`define RV32I_TRAP_CAUSE_STORE_ADDR_MISALIGNED 32'd6
`define RV32I_TRAP_CAUSE_STORE_ACCESS_FAULT    32'd7
`define RV32I_TRAP_CAUSE_ECALL                 32'd11
`define RV32I_TRAP_CAUSE_MTIMER                32'h8000_0007

`endif
