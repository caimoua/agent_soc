`include "rv32i_defs.vh"

module rv32i_pipe_hazard (
  input  wire        if_id_valid,
  input  wire [6:0]  id_opcode,
  input  wire [4:0]  id_rs1_addr,
  input  wire [4:0]  id_rs2_addr,
  input  wire [31:0] id_rs1_data,
  input  wire [31:0] id_rs2_data,

  input  wire        id_ex_valid,
  input  wire        id_ex_mem_valid,
  input  wire        id_ex_mem_write,
  input  wire        id_ex_reg_we,
  input  wire        id_ex_illegal,
  input  wire [4:0]  id_ex_rd_addr,
  input  wire [4:0]  id_ex_rs1_addr,
  input  wire [4:0]  id_ex_rs2_addr,
  input  wire [31:0] id_ex_rs1_data,
  input  wire [31:0] id_ex_rs2_data,

  input  wire        ex_mem_valid,
  input  wire        ex_mem_reg_we,
  input  wire        ex_mem_illegal,
  input  wire [4:0]  ex_mem_rd_addr,
  input  wire [2:0]  ex_mem_wb_sel,
  input  wire [31:0] ex_mem_pc4,
  input  wire [31:0] ex_mem_alu_result,
  input  wire [31:0] ex_mem_imm_u,
  input  wire [31:0] ex_mem_csr_rdata,

  input  wire        wb_reg_we,
  input  wire [4:0]  wb_rd_addr,
  input  wire [31:0] wb_wdata,

  output wire        load_use_stall,
  output wire [31:0] id_rs1_data_bypass,
  output wire [31:0] id_rs2_data_bypass,
  output wire [31:0] forward_rs1_data,
  output wire [31:0] forward_rs2_data
);

  wire        id_uses_rs1;
  wire        id_uses_rs2;
  wire [31:0] ex_mem_forward_data;
  wire        ex_mem_forward_rs1;
  wire        ex_mem_forward_rs2;
  wire        mem_wb_forward_rs1;
  wire        mem_wb_forward_rs2;

  assign id_uses_rs1 = (id_opcode == `RV32I_OPCODE_OP_IMM) ||
                       (id_opcode == `RV32I_OPCODE_OP) ||
                       (id_opcode == `RV32I_OPCODE_LOAD) ||
                       (id_opcode == `RV32I_OPCODE_STORE) ||
                       (id_opcode == `RV32I_OPCODE_JALR) ||
                       (id_opcode == `RV32I_OPCODE_BRANCH) ||
                       (id_opcode == `RV32I_OPCODE_SYSTEM);
  assign id_uses_rs2 = (id_opcode == `RV32I_OPCODE_OP) ||
                       (id_opcode == `RV32I_OPCODE_STORE) ||
                       (id_opcode == `RV32I_OPCODE_BRANCH);

  assign load_use_stall = if_id_valid &&
                          id_ex_valid &&
                          id_ex_mem_valid &&
                          !id_ex_mem_write &&
                          id_ex_reg_we &&
                          !id_ex_illegal &&
                          (id_ex_rd_addr != 5'd0) &&
                          ((id_uses_rs1 && (id_ex_rd_addr == id_rs1_addr)) ||
                           (id_uses_rs2 && (id_ex_rd_addr == id_rs2_addr)));

  assign id_rs1_data_bypass = (wb_reg_we &&
                               (wb_rd_addr != 5'd0) &&
                               (wb_rd_addr == id_rs1_addr)) ? wb_wdata :
                                                               id_rs1_data;
  assign id_rs2_data_bypass = (wb_reg_we &&
                               (wb_rd_addr != 5'd0) &&
                               (wb_rd_addr == id_rs2_addr)) ? wb_wdata :
                                                               id_rs2_data;

  assign ex_mem_forward_data = (ex_mem_wb_sel == `RV32I_WB_LUI)   ? ex_mem_imm_u :
                               (ex_mem_wb_sel == `RV32I_WB_AUIPC) ? ((ex_mem_pc4 - 32'd4) + ex_mem_imm_u) :
                               (ex_mem_wb_sel == `RV32I_WB_PC4)   ? ex_mem_pc4 :
                               (ex_mem_wb_sel == `RV32I_WB_CSR)   ? ex_mem_csr_rdata :
                                                                    ex_mem_alu_result;

  assign ex_mem_forward_rs1 = ex_mem_valid &&
                              ex_mem_reg_we &&
                              !ex_mem_illegal &&
                              (ex_mem_rd_addr != 5'd0) &&
                              (ex_mem_rd_addr == id_ex_rs1_addr) &&
                              (ex_mem_wb_sel != `RV32I_WB_MEM);
  assign ex_mem_forward_rs2 = ex_mem_valid &&
                              ex_mem_reg_we &&
                              !ex_mem_illegal &&
                              (ex_mem_rd_addr != 5'd0) &&
                              (ex_mem_rd_addr == id_ex_rs2_addr) &&
                              (ex_mem_wb_sel != `RV32I_WB_MEM);
  assign mem_wb_forward_rs1 = wb_reg_we &&
                              (wb_rd_addr != 5'd0) &&
                              (wb_rd_addr == id_ex_rs1_addr);
  assign mem_wb_forward_rs2 = wb_reg_we &&
                              (wb_rd_addr != 5'd0) &&
                              (wb_rd_addr == id_ex_rs2_addr);

  assign forward_rs1_data = ex_mem_forward_rs1 ? ex_mem_forward_data :
                            mem_wb_forward_rs1 ? wb_wdata :
                                                 id_ex_rs1_data;
  assign forward_rs2_data = ex_mem_forward_rs2 ? ex_mem_forward_data :
                            mem_wb_forward_rs2 ? wb_wdata :
                                                 id_ex_rs2_data;

endmodule
