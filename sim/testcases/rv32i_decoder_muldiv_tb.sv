`timescale 1ns/1ps
`include "rv32i_defs.vh"

module rv32i_decoder_muldiv_tb;

  logic [31:0] instr;

  wire [4:0]  m_rs1_addr;
  wire [4:0]  m_rs2_addr;
  wire [4:0]  m_rd_addr;
  wire        m_reg_we;
  wire        m_alu_src_imm;
  wire [3:0]  m_alu_op;
  wire [2:0]  m_wb_sel;
  wire [1:0]  m_pc_sel;
  wire [2:0]  m_branch_op;
  wire        m_mem_valid;
  wire        m_mem_write;
  wire [1:0]  m_mem_size;
  wire        m_mem_unsigned;
  wire [11:0] m_csr_addr;
  wire [1:0]  m_csr_op;
  wire [1:0]  m_system_op;
  wire        m_system_ecall;
  wire        m_system_ebreak;
  wire        m_system_mret;
  wire        m_muldiv_valid;
  wire [2:0]  m_muldiv_op;
  wire        m_illegal_instr;

  wire [4:0]  i_rs1_addr;
  wire [4:0]  i_rs2_addr;
  wire [4:0]  i_rd_addr;
  wire        i_reg_we;
  wire        i_alu_src_imm;
  wire [3:0]  i_alu_op;
  wire [2:0]  i_wb_sel;
  wire [1:0]  i_pc_sel;
  wire [2:0]  i_branch_op;
  wire        i_mem_valid;
  wire        i_mem_write;
  wire [1:0]  i_mem_size;
  wire        i_mem_unsigned;
  wire [11:0] i_csr_addr;
  wire [1:0]  i_csr_op;
  wire [1:0]  i_system_op;
  wire        i_system_ecall;
  wire        i_system_ebreak;
  wire        i_system_mret;
  wire        i_muldiv_valid;
  wire [2:0]  i_muldiv_op;
  wire        i_illegal_instr;

  function automatic [31:0] rv32m_instr(input [2:0] funct3);
    begin
      rv32m_instr = {7'b0000001, 5'd2, 5'd1, funct3, 5'd3,
                     `RV32I_OPCODE_OP};
    end
  endfunction

  function automatic [31:0] rv32i_add_instr();
    begin
      rv32i_add_instr = {7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3,
                         `RV32I_OPCODE_OP};
    end
  endfunction

  task automatic check_bit(
    input actual,
    input expected,
    input string name
  );
    begin
      if (actual !== expected) begin
        $fatal(1, "%s mismatch: expected %0d, got %0d",
               name, expected, actual);
      end
    end
  endtask

  task automatic check_value(
    input [31:0] actual,
    input [31:0] expected,
    input string name
  );
    begin
      if (actual !== expected) begin
        $fatal(1, "%s mismatch: expected 0x%08x, got 0x%08x",
               name, expected, actual);
      end
    end
  endtask

  task automatic check_m_decode(
    input [2:0] op,
    input string name
  );
    begin
      instr = rv32m_instr(op);
      #1ps;

      check_bit(m_muldiv_valid, 1'b1, {name, " ENABLE_M muldiv_valid"});
      check_value({29'd0, m_muldiv_op}, {29'd0, op},
                  {name, " ENABLE_M muldiv_op"});
      check_bit(m_illegal_instr, 1'b0, {name, " ENABLE_M illegal"});
      check_bit(m_reg_we, 1'b1, {name, " ENABLE_M reg_we"});
      check_value({29'd0, m_wb_sel}, {29'd0, `RV32I_WB_ALU},
                  {name, " ENABLE_M wb_sel"});
      check_value({30'd0, m_pc_sel}, {30'd0, `RV32I_PC_NEXT},
                  {name, " ENABLE_M pc_sel"});
      check_bit(m_mem_valid, 1'b0, {name, " ENABLE_M mem_valid"});
      check_bit(m_mem_write, 1'b0, {name, " ENABLE_M mem_write"});

      check_bit(i_muldiv_valid, 1'b0, {name, " RV32I-only muldiv_valid"});
      check_bit(i_illegal_instr, 1'b1, {name, " RV32I-only illegal"});
    end
  endtask

  rv32i_decoder #(
    .ENABLE_M(1)
  ) u_decoder_m (
    .instr         (instr),
    .rs1_addr     (m_rs1_addr),
    .rs2_addr     (m_rs2_addr),
    .rd_addr      (m_rd_addr),
    .reg_we       (m_reg_we),
    .alu_src_imm  (m_alu_src_imm),
    .alu_op       (m_alu_op),
    .wb_sel       (m_wb_sel),
    .pc_sel       (m_pc_sel),
    .branch_op    (m_branch_op),
    .mem_valid    (m_mem_valid),
    .mem_write    (m_mem_write),
    .mem_size     (m_mem_size),
    .mem_unsigned (m_mem_unsigned),
    .csr_addr     (m_csr_addr),
    .csr_op       (m_csr_op),
    .system_op    (m_system_op),
    .system_ecall (m_system_ecall),
    .system_ebreak(m_system_ebreak),
    .system_mret  (m_system_mret),
    .muldiv_valid (m_muldiv_valid),
    .muldiv_op    (m_muldiv_op),
    .illegal_instr(m_illegal_instr)
  );

  rv32i_decoder u_decoder_i (
    .instr         (instr),
    .rs1_addr     (i_rs1_addr),
    .rs2_addr     (i_rs2_addr),
    .rd_addr      (i_rd_addr),
    .reg_we       (i_reg_we),
    .alu_src_imm  (i_alu_src_imm),
    .alu_op       (i_alu_op),
    .wb_sel       (i_wb_sel),
    .pc_sel       (i_pc_sel),
    .branch_op    (i_branch_op),
    .mem_valid    (i_mem_valid),
    .mem_write    (i_mem_write),
    .mem_size     (i_mem_size),
    .mem_unsigned (i_mem_unsigned),
    .csr_addr     (i_csr_addr),
    .csr_op       (i_csr_op),
    .system_op    (i_system_op),
    .system_ecall (i_system_ecall),
    .system_ebreak(i_system_ebreak),
    .system_mret  (i_system_mret),
    .muldiv_valid (i_muldiv_valid),
    .muldiv_op    (i_muldiv_op),
    .illegal_instr(i_illegal_instr)
  );

  initial begin
    instr = 32'h0000_0013;
    #1ps;

    instr = rv32i_add_instr();
    #1ps;
    check_bit(m_muldiv_valid, 1'b0, "add ENABLE_M muldiv_valid");
    check_bit(m_illegal_instr, 1'b0, "add ENABLE_M illegal");
    check_bit(m_reg_we, 1'b1, "add ENABLE_M reg_we");
    check_value({28'd0, m_alu_op}, {28'd0, `RV32I_ALU_ADD},
                "add ENABLE_M alu_op");
    check_bit(i_muldiv_valid, 1'b0, "add RV32I-only muldiv_valid");
    check_bit(i_illegal_instr, 1'b0, "add RV32I-only illegal");
    check_bit(i_reg_we, 1'b1, "add RV32I-only reg_we");

    check_m_decode(`RV32I_MULDIV_MUL,    "mul");
    check_m_decode(`RV32I_MULDIV_MULH,   "mulh");
    check_m_decode(`RV32I_MULDIV_MULHSU, "mulhsu");
    check_m_decode(`RV32I_MULDIV_MULHU,  "mulhu");
    check_m_decode(`RV32I_MULDIV_DIV,    "div");
    check_m_decode(`RV32I_MULDIV_DIVU,   "divu");
    check_m_decode(`RV32I_MULDIV_REM,    "rem");
    check_m_decode(`RV32I_MULDIV_REMU,   "remu");

    $display("[PASS] rv32i_decoder_muldiv_tb");
    $display("  ENABLE_M decoder accepts all RV32M funct3 values");
    $display("  default RV32I decoder still reports RV32M encodings illegal");
    $finish;
  end

endmodule
