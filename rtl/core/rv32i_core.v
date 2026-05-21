`include "rv32i_defs.vh"

module rv32i_core (
  input  wire        clk,
  input  wire        rst_n,

  output wire        imem_valid,
  output wire [31:0] imem_addr,
  input  wire [31:0] imem_rdata,

  output wire        dmem_valid,
  output wire        dmem_write,
  output wire [31:0] dmem_addr,
  output wire [31:0] dmem_wdata,
  output wire [3:0]  dmem_wstrb,
  input  wire        dmem_ready,
  input  wire [31:0] dmem_rdata,

  output wire [31:0] dbg_pc,
  output wire [31:0] dbg_cycle,
  input  wire [4:0]  dbg_reg_addr,
  output wire [31:0] dbg_reg_rdata,
  output wire        dbg_illegal_instr,
  output wire        dbg_ecall,
  output wire        dbg_ebreak
);

  reg [31:0] pc_q;
  reg [31:0] cycle_q;

  wire        unused_dmem_ready = dmem_ready;

  wire [31:0] instr = imem_rdata;
  wire [4:0]  rs1_addr;
  wire [4:0]  rs2_addr;
  wire [4:0]  rd_addr;
  wire        reg_we;
  wire        alu_src_imm;
  wire [3:0]  alu_op;
  wire [31:0] imm_i;
  wire [31:0] imm_s;
  wire [31:0] imm_b;
  wire [31:0] imm_u;
  wire [31:0] imm_j;
  wire [31:0] rs1_data;
  wire [31:0] rs2_data;
  wire [31:0] alu_src_b;
  wire [31:0] alu_result;
  wire [2:0]  wb_sel;
  wire [1:0]  pc_sel;
  wire [2:0]  branch_op;
  wire        mem_valid;
  wire        mem_write;
  wire [1:0]  mem_size;
  wire        mem_unsigned;
  wire [11:0] csr_addr;
  wire [1:0]  csr_op;
  wire [1:0]  system_op;
  wire        system_ecall;
  wire        system_ebreak;
  wire        system_mret;
  wire        unused_muldiv_valid;
  wire [2:0]  unused_muldiv_op;
  wire [31:0] wdata;
  wire [31:0] csr_rdata;
  wire [31:0] mem_addr;
  wire [7:0]  mem_load_byte;
  wire [15:0] mem_load_half;
  wire [31:0] mem_load_data;
  wire [31:0] mem_store_data;
  wire [3:0]  mem_store_wstrb;
  wire        branch_taken;
  wire        core_reg_we;
  wire        core_mem_valid;
  wire        illegal_instr;
  wire        unused_system_mret = system_mret;
  wire [1:0]  unused_csr_op = csr_op;
  wire [1:0]  unused_system_op = system_op;

  assign imem_valid = 1'b1;
  assign imem_addr  = pc_q;

  assign core_mem_valid = mem_valid && !illegal_instr;
  assign mem_addr       = mem_write ? (rs1_data + imm_s) : alu_result;
  assign dmem_valid     = core_mem_valid;
  assign dmem_write     = core_mem_valid && mem_write;
  assign dmem_addr      = mem_addr;
  assign dmem_wdata     = mem_store_data;
  assign dmem_wstrb     = dmem_write ? mem_store_wstrb : 4'b0000;

  assign dbg_pc     = pc_q;
  assign dbg_cycle  = cycle_q;
  assign dbg_illegal_instr = illegal_instr;
  assign dbg_ecall  = system_ecall && !illegal_instr;
  assign dbg_ebreak = system_ebreak && !illegal_instr;
  assign core_reg_we = reg_we && !illegal_instr;
  assign alu_src_b   = alu_src_imm ? imm_i : rs2_data;
  assign csr_rdata   = (csr_addr == `RV32I_CSR_CYCLE) ? cycle_q : 32'd0;
  assign branch_taken = (branch_op == `RV32I_BR_BEQ)  ? (rs1_data == rs2_data) :
                        (branch_op == `RV32I_BR_BNE)  ? (rs1_data != rs2_data) :
                        (branch_op == `RV32I_BR_BLT)  ? ($signed(rs1_data) < $signed(rs2_data)) :
                        (branch_op == `RV32I_BR_BGE)  ? ($signed(rs1_data) >= $signed(rs2_data)) :
                        (branch_op == `RV32I_BR_BLTU) ? (rs1_data < rs2_data) :
                        (branch_op == `RV32I_BR_BGEU) ? (rs1_data >= rs2_data) :
                                                        1'b0;
  assign mem_load_byte = (mem_addr[1:0] == 2'b00) ? dmem_rdata[7:0] :
                         (mem_addr[1:0] == 2'b01) ? dmem_rdata[15:8] :
                         (mem_addr[1:0] == 2'b10) ? dmem_rdata[23:16] :
                                                     dmem_rdata[31:24];
  assign mem_load_half = mem_addr[1] ? dmem_rdata[31:16] : dmem_rdata[15:0];
  assign mem_load_data = (mem_size == `RV32I_MEM_BYTE) ?
                           (mem_unsigned ? {24'd0, mem_load_byte} :
                                           {{24{mem_load_byte[7]}}, mem_load_byte}) :
                         (mem_size == `RV32I_MEM_HALF) ?
                           (mem_unsigned ? {16'd0, mem_load_half} :
                                           {{16{mem_load_half[15]}}, mem_load_half}) :
                         dmem_rdata;
  assign mem_store_data = (mem_size == `RV32I_MEM_BYTE) ? {4{rs2_data[7:0]}} :
                          (mem_size == `RV32I_MEM_HALF) ? {2{rs2_data[15:0]}} :
                                                           rs2_data;
  assign mem_store_wstrb = (mem_size == `RV32I_MEM_BYTE) ? (4'b0001 << mem_addr[1:0]) :
                           (mem_size == `RV32I_MEM_HALF) ? (mem_addr[1] ? 4'b1100 : 4'b0011) :
                                                            4'b1111;

  assign wdata = (wb_sel == `RV32I_WB_LUI)   ? imm_u :
                 (wb_sel == `RV32I_WB_AUIPC) ? (pc_q + imm_u) :
                 (wb_sel == `RV32I_WB_PC4)   ? (pc_q + 32'd4) :
                 (wb_sel == `RV32I_WB_MEM)   ? mem_load_data :
                 (wb_sel == `RV32I_WB_CSR)   ? csr_rdata :
                                               alu_result;

  rv32i_decoder u_decoder (
    .instr         (instr),
    .rs1_addr     (rs1_addr),
    .rs2_addr     (rs2_addr),
    .rd_addr      (rd_addr),
    .reg_we       (reg_we),
    .alu_src_imm  (alu_src_imm),
    .alu_op       (alu_op),
    .wb_sel       (wb_sel),
    .pc_sel       (pc_sel),
    .branch_op    (branch_op),
    .mem_valid    (mem_valid),
    .mem_write    (mem_write),
    .mem_size     (mem_size),
    .mem_unsigned (mem_unsigned),
    .csr_addr     (csr_addr),
    .csr_op       (csr_op),
    .system_op    (system_op),
    .system_ecall (system_ecall),
    .system_ebreak(system_ebreak),
    .system_mret  (system_mret),
    .muldiv_valid (unused_muldiv_valid),
    .muldiv_op    (unused_muldiv_op),
    .illegal_instr(illegal_instr)
  );

  rv32i_imm_gen u_imm_gen (
    .instr (instr),
    .imm_i (imm_i),
    .imm_s (imm_s),
    .imm_b (imm_b),
    .imm_u (imm_u),
    .imm_j (imm_j)
  );

  rv32i_regfile u_regfile (
    .clk    (clk),
    .rst_n  (rst_n),
    .we     (core_reg_we),
    .waddr  (rd_addr),
    .wdata  (wdata),
    .raddr0 (rs1_addr),
    .raddr1 (rs2_addr),
    .rdata0 (rs1_data),
    .rdata1 (rs2_data),
    .dbg_raddr (dbg_reg_addr),
    .dbg_rdata (dbg_reg_rdata)
  );

  rv32i_alu u_alu (
    .alu_op (alu_op),
    .src_a  (rs1_data),
    .src_b  (alu_src_b),
    .result (alu_result)
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_q    <= 32'h0000_0000;
      cycle_q <= 32'd0;
    end else begin
      pc_q <= (pc_sel == `RV32I_PC_JAL)  ? (pc_q + imm_j) :
              (pc_sel == `RV32I_PC_JALR) ? (alu_result & ~32'd1) :
              ((pc_sel == `RV32I_PC_BRANCH) && branch_taken) ? (pc_q + imm_b) :
                                           (pc_q + 32'd4);
      cycle_q <= cycle_q + 32'd1;
    end
  end

endmodule
