`include "rv32i_defs.vh"

module rv32i_pipe_core #(
  parameter [31:0] RESET_PC = 32'h0000_0000,
  parameter BRANCH_PRED_INDEX_BITS = 6
) (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        timer_irq,

  output wire        imem_valid,
  output wire [31:0] imem_addr,
  input  wire        imem_ready,
  input  wire [31:0] imem_rdata,
  input  wire        imem_error,

  output wire        dmem_valid,
  output wire        dmem_write,
  output wire [31:0] dmem_addr,
  output wire [31:0] dmem_wdata,
  output wire [3:0]  dmem_wstrb,
  input  wire        dmem_ready,
  input  wire [31:0] dmem_rdata,
  input  wire        dmem_error,

  output wire [31:0] dbg_pc,
  output wire [31:0] dbg_cycle,
  output wire [31:0] dbg_instret,
  output wire [31:0] dbg_stall_cycle,
  output wire [31:0] dbg_flush_cycle,
  output wire [31:0] dbg_branch_count,
  output wire [31:0] dbg_branch_mispredict_count,
  output wire [31:0] dbg_btb_hit_count,
  output wire [31:0] dbg_btb_miss_count,
  output wire [31:0] dbg_bht_update_count,
  input  wire [4:0]  dbg_reg_addr,
  output wire [31:0] dbg_reg_rdata,
  output wire        dbg_illegal_instr,
  output wire        dbg_ecall,
  output wire        dbg_ebreak
);

  reg [31:0] pc_q;
  reg        if_discard_q;

  reg        if_id_valid_q;
  reg [31:0] if_id_pc_q;
  reg [31:0] if_id_pc4_q;
  reg [31:0] if_id_instr_q;
  reg        if_id_instr_fault_q;
  reg [31:0] if_id_predicted_pc_q;
  reg        if_id_btb_hit_q;

  reg        id_ex_valid_q;
  reg [31:0] id_ex_pc_q;
  reg [31:0] id_ex_pc4_q;
  reg [4:0]  id_ex_rs1_addr_q;
  reg [4:0]  id_ex_rs2_addr_q;
  reg [4:0]  id_ex_rd_addr_q;
  reg [31:0] id_ex_rs1_data_q;
  reg [31:0] id_ex_rs2_data_q;
  reg [31:0] id_ex_imm_i_q;
  reg [31:0] id_ex_imm_s_q;
  reg [31:0] id_ex_imm_b_q;
  reg [31:0] id_ex_imm_u_q;
  reg [31:0] id_ex_imm_j_q;
  reg        id_ex_reg_we_q;
  reg        id_ex_alu_src_imm_q;
  reg [3:0]  id_ex_alu_op_q;
  reg [2:0]  id_ex_wb_sel_q;
  reg [1:0]  id_ex_pc_sel_q;
  reg [2:0]  id_ex_branch_op_q;
  reg        id_ex_mem_valid_q;
  reg        id_ex_mem_write_q;
  reg [1:0]  id_ex_mem_size_q;
  reg        id_ex_mem_unsigned_q;
  reg [11:0] id_ex_csr_addr_q;
  reg [1:0]  id_ex_csr_op_q;
  reg        id_ex_system_ecall_q;
  reg        id_ex_system_ebreak_q;
  reg        id_ex_system_mret_q;
  reg        id_ex_muldiv_valid_q;
  reg [2:0]  id_ex_muldiv_op_q;
  reg        id_ex_illegal_q;
  reg        id_ex_instr_fault_q;
  reg [31:0] id_ex_predicted_pc_q;
  reg        id_ex_btb_hit_q;

  reg        ex_mem_valid_q;
  reg [31:0] ex_mem_pc4_q;
  reg [4:0]  ex_mem_rd_addr_q;
  reg [31:0] ex_mem_alu_result_q;
  reg [31:0] ex_mem_store_data_q;
  reg [31:0] ex_mem_mem_addr_q;
  reg [31:0] ex_mem_imm_u_q;
  reg [31:0] ex_mem_csr_rdata_q;
  reg [31:0] ex_mem_csr_wdata_q;
  reg [11:0] ex_mem_csr_addr_q;
  reg [1:0]  ex_mem_csr_op_q;
  reg        ex_mem_csr_write_q;
  reg        ex_mem_reg_we_q;
  reg [2:0]  ex_mem_wb_sel_q;
  reg        ex_mem_mem_valid_q;
  reg        ex_mem_mem_write_q;
  reg [1:0]  ex_mem_mem_size_q;
  reg        ex_mem_mem_unsigned_q;
  reg        ex_mem_system_ecall_q;
  reg        ex_mem_system_ebreak_q;
  reg        ex_mem_system_mret_q;
  reg        ex_mem_illegal_q;
  reg        ex_mem_instr_addr_misaligned_q;
  reg        ex_mem_instr_fault_q;

  reg        mem_wb_valid_q;
  reg [31:0] mem_wb_pc4_q;
  reg [4:0]  mem_wb_rd_addr_q;
  reg [31:0] mem_wb_alu_result_q;
  reg [31:0] mem_wb_load_data_q;
  reg [31:0] mem_wb_imm_u_q;
  reg [31:0] mem_wb_csr_rdata_q;
  reg [31:0] mem_wb_csr_wdata_q;
  reg [11:0] mem_wb_csr_addr_q;
  reg [1:0]  mem_wb_csr_op_q;
  reg        mem_wb_csr_write_q;
  reg        mem_wb_reg_we_q;
  reg [2:0]  mem_wb_wb_sel_q;
  reg        mem_wb_system_ecall_q;
  reg        mem_wb_system_ebreak_q;
  reg        mem_wb_system_mret_q;
  reg        mem_wb_illegal_q;
  reg        mem_wb_instr_addr_misaligned_q;
  reg        mem_wb_instr_fault_q;
  reg        mem_wb_load_addr_misaligned_q;
  reg        mem_wb_load_fault_q;
  reg        mem_wb_store_addr_misaligned_q;
  reg        mem_wb_store_fault_q;

  wire [4:0]  id_rs1_addr;
  wire [4:0]  id_rs2_addr;
  wire [4:0]  id_rd_addr;
  wire        id_reg_we;
  wire        id_alu_src_imm;
  wire [3:0]  id_alu_op;
  wire [2:0]  id_wb_sel;
  wire [1:0]  id_pc_sel;
  wire [2:0]  id_branch_op;
  wire        id_mem_valid;
  wire        id_mem_write;
  wire [1:0]  id_mem_size;
  wire        id_mem_unsigned;
  wire [11:0] id_csr_addr;
  wire [1:0]  id_csr_op;
  wire [1:0]  id_system_op;
  wire [1:0]  unused_id_system_op = id_system_op;
  wire        id_system_ecall;
  wire        id_system_ebreak;
  wire        id_system_mret;
  wire        id_muldiv_valid;
  wire [2:0]  id_muldiv_op;
  wire        id_illegal;
  wire [31:0] id_imm_i;
  wire [31:0] id_imm_s;
  wire [31:0] id_imm_b;
  wire [31:0] id_imm_u;
  wire [31:0] id_imm_j;
  wire [31:0] id_rs1_data;
  wire [31:0] id_rs2_data;
  wire [31:0] id_rs1_data_bypass;
  wire [31:0] id_rs2_data_bypass;
  wire        load_use_stall;
  wire        if_stall;
  wire [31:0] if_instr;
  wire [31:0] if_predicted_pc;
  wire        if_is_branch;
  wire        if_btb_hit;
  wire        perf_instret_event;
  wire        perf_stall_event;
  wire        perf_flush_event;
  wire        perf_branch_event;
  wire        perf_branch_mispredict_event;
  wire [31:0] perf_cycle_count;
  wire [31:0] perf_instret_count;
  wire [31:0] perf_stall_cycle_count;
  wire [31:0] perf_flush_cycle_count;
  wire [31:0] perf_branch_count;
  wire [31:0] perf_branch_mispredict_count;

  wire [31:0] ex_alu_src_b;
  wire [31:0] ex_alu_result;
  wire [31:0] ex_result;
  wire [31:0] ex_mem_addr;
  wire [31:0] ex_csr_rdata;
  wire        ex_csr_write;
  wire        ex_muldiv_valid;
  wire        ex_muldiv_ready;
  wire        ex_muldiv_consume;
  wire        ex_muldiv_stall;
  wire [31:0] ex_muldiv_result;
  wire        ex_branch_taken;
  wire        ex_control_taken;
  wire        ex_control_instr;
  wire        ex_branch_instr;
  wire        ex_branch_update;
  wire        ex_prediction_mismatch;
  wire        ex_redirect;
  wire        ex_instr_addr_misaligned;
  wire [31:0] ex_control_target_pc;
  wire [31:0] ex_actual_next_pc;
  wire [31:0] ex_redirect_pc;

  wire        mem_stall;
  wire [31:0] mem_load_data;
  wire        mem_load_addr_misaligned;
  wire        mem_store_addr_misaligned;
  wire        mem_load_fault;
  wire        mem_store_fault;

  wire [31:0] wb_wdata;
  wire        wb_reg_we;
  wire        commit_redirect;
  wire [31:0] commit_redirect_pc;

  wire        pipe_commit_flush;
  wire        pipe_front_advance;
  wire        pipe_if_discard_flush;
  wire        pipe_if_redirect_flush;
  wire        pipe_if_normal_load;
  wire        pipe_id_ex_advance;
  wire        pipe_id_ex_bubble;
  wire        pipe_ex_mem_advance;
  wire        pipe_ex_mem_bubble;

  wire [31:0] forward_rs1_data;
  wire [31:0] forward_rs2_data;

  assign imem_valid = 1'b1;
  assign imem_addr  = pc_q;
  assign if_stall   = imem_valid && !imem_ready;

  assign dbg_pc            = pc_q;
  assign dbg_cycle         = perf_cycle_count;
  assign dbg_instret       = perf_instret_count;
  assign dbg_stall_cycle   = perf_stall_cycle_count;
  assign dbg_flush_cycle   = perf_flush_cycle_count;
  assign dbg_branch_count  = perf_branch_count;
  assign dbg_branch_mispredict_count = perf_branch_mispredict_count;

  assign if_instr = imem_error ? 32'h0000_0013 : imem_rdata;

  assign perf_instret_event = ex_mem_valid_q &&
                              !ex_mem_illegal_q &&
                              !ex_mem_instr_addr_misaligned_q &&
                              !ex_mem_instr_fault_q &&
                              !mem_stall &&
                              !mem_load_addr_misaligned &&
                              !mem_load_fault &&
                              !mem_store_addr_misaligned &&
                              !mem_store_fault &&
                              !commit_redirect;
  assign perf_branch_event = ex_branch_update;
  assign perf_branch_mispredict_event = ex_branch_update &&
                                        ex_prediction_mismatch;

  rv32i_pipe_ctrl u_pipe_ctrl (
    .commit_redirect  (commit_redirect),
    .ex_redirect      (ex_redirect),
    .mem_stall        (mem_stall),
    .ex_muldiv_stall  (ex_muldiv_stall),
    .load_use_stall   (load_use_stall),
    .if_stall         (if_stall),
    .if_discard       (if_discard_q),
    .commit_flush     (pipe_commit_flush),
    .front_advance    (pipe_front_advance),
    .if_discard_flush (pipe_if_discard_flush),
    .if_redirect_flush(pipe_if_redirect_flush),
    .if_normal_load   (pipe_if_normal_load),
    .id_ex_advance    (pipe_id_ex_advance),
    .id_ex_bubble     (pipe_id_ex_bubble),
    .ex_mem_advance   (pipe_ex_mem_advance),
    .ex_mem_bubble    (pipe_ex_mem_bubble),
    .perf_stall_event (perf_stall_event),
    .perf_flush_event (perf_flush_event)
  );

  rv32i_perf_counter u_perf_counter (
    .clk                      (clk),
    .rst_n                    (rst_n),
    .instret_event            (perf_instret_event),
    .stall_event              (perf_stall_event),
    .flush_event              (perf_flush_event),
    .branch_event             (perf_branch_event),
    .branch_mispredict_event  (perf_branch_mispredict_event),
    .cycle_count              (perf_cycle_count),
    .instret_count            (perf_instret_count),
    .stall_cycle_count        (perf_stall_cycle_count),
    .flush_cycle_count        (perf_flush_cycle_count),
    .branch_count             (perf_branch_count),
    .branch_mispredict_count  (perf_branch_mispredict_count)
  );

  rv32i_branch_predictor #(
    .INDEX_BITS(BRANCH_PRED_INDEX_BITS)
  ) u_branch_predictor (
    .clk                  (clk),
    .rst_n                (rst_n),
    .if_pc                (pc_q),
    .if_instr             (if_instr),
    .if_error             (imem_error),
    .if_predicted_pc      (if_predicted_pc),
    .if_predict_taken     (),
    .if_is_branch         (if_is_branch),
    .if_btb_hit           (if_btb_hit),
    .ex_update_valid      (ex_branch_update),
    .ex_pc                (id_ex_pc_q),
    .ex_taken             (ex_branch_taken),
    .ex_target_pc         (ex_control_target_pc),
    .ex_fetch_btb_hit     (id_ex_btb_hit_q),
    .dbg_btb_hit_count    (dbg_btb_hit_count),
    .dbg_btb_miss_count   (dbg_btb_miss_count),
    .dbg_bht_update_count (dbg_bht_update_count)
  );

  rv32i_decoder #(
    .ENABLE_M(1)
  ) u_decoder (
    .instr         (if_id_instr_q),
    .rs1_addr     (id_rs1_addr),
    .rs2_addr     (id_rs2_addr),
    .rd_addr      (id_rd_addr),
    .reg_we       (id_reg_we),
    .alu_src_imm  (id_alu_src_imm),
    .alu_op       (id_alu_op),
    .wb_sel       (id_wb_sel),
    .pc_sel       (id_pc_sel),
    .branch_op    (id_branch_op),
    .mem_valid    (id_mem_valid),
    .mem_write    (id_mem_write),
    .mem_size     (id_mem_size),
    .mem_unsigned (id_mem_unsigned),
    .csr_addr     (id_csr_addr),
    .csr_op       (id_csr_op),
    .system_op    (id_system_op),
    .system_ecall (id_system_ecall),
    .system_ebreak(id_system_ebreak),
    .system_mret  (id_system_mret),
    .muldiv_valid (id_muldiv_valid),
    .muldiv_op    (id_muldiv_op),
    .illegal_instr(id_illegal)
  );

  rv32i_imm_gen u_imm_gen (
    .instr (if_id_instr_q),
    .imm_i (id_imm_i),
    .imm_s (id_imm_s),
    .imm_b (id_imm_b),
    .imm_u (id_imm_u),
    .imm_j (id_imm_j)
  );

  rv32i_regfile u_regfile (
    .clk       (clk),
    .rst_n     (rst_n),
    .we        (wb_reg_we),
    .waddr     (mem_wb_rd_addr_q),
    .wdata     (wb_wdata),
    .raddr0    (id_rs1_addr),
    .raddr1    (id_rs2_addr),
    .rdata0    (id_rs1_data),
    .rdata1    (id_rs2_data),
    .dbg_raddr (dbg_reg_addr),
    .dbg_rdata (dbg_reg_rdata)
  );

  rv32i_pipe_hazard u_pipe_hazard (
    .if_id_valid        (if_id_valid_q),
    .id_opcode          (if_id_instr_q[6:0]),
    .id_rs1_addr        (id_rs1_addr),
    .id_rs2_addr        (id_rs2_addr),
    .id_rs1_data        (id_rs1_data),
    .id_rs2_data        (id_rs2_data),
    .id_ex_valid        (id_ex_valid_q),
    .id_ex_mem_valid    (id_ex_mem_valid_q),
    .id_ex_mem_write    (id_ex_mem_write_q),
    .id_ex_reg_we       (id_ex_reg_we_q),
    .id_ex_illegal      (id_ex_illegal_q),
    .id_ex_rd_addr      (id_ex_rd_addr_q),
    .id_ex_rs1_addr     (id_ex_rs1_addr_q),
    .id_ex_rs2_addr     (id_ex_rs2_addr_q),
    .id_ex_rs1_data     (id_ex_rs1_data_q),
    .id_ex_rs2_data     (id_ex_rs2_data_q),
    .ex_mem_valid       (ex_mem_valid_q),
    .ex_mem_reg_we      (ex_mem_reg_we_q),
    .ex_mem_illegal     (ex_mem_illegal_q),
    .ex_mem_rd_addr     (ex_mem_rd_addr_q),
    .ex_mem_wb_sel      (ex_mem_wb_sel_q),
    .ex_mem_pc4         (ex_mem_pc4_q),
    .ex_mem_alu_result  (ex_mem_alu_result_q),
    .ex_mem_imm_u       (ex_mem_imm_u_q),
    .ex_mem_csr_rdata   (ex_mem_csr_rdata_q),
    .wb_reg_we          (wb_reg_we),
    .wb_rd_addr         (mem_wb_rd_addr_q),
    .wb_wdata           (wb_wdata),
    .load_use_stall     (load_use_stall),
    .id_rs1_data_bypass (id_rs1_data_bypass),
    .id_rs2_data_bypass (id_rs2_data_bypass),
    .forward_rs1_data   (forward_rs1_data),
    .forward_rs2_data   (forward_rs2_data)
  );

  assign ex_alu_src_b = id_ex_alu_src_imm_q ? id_ex_imm_i_q : forward_rs2_data;
  assign ex_mem_addr  = id_ex_mem_write_q ? (forward_rs1_data + id_ex_imm_s_q) :
                                             ex_alu_result;
  assign ex_csr_write = (id_ex_csr_op_q == `RV32I_CSR_OP_RW) ||
                        ((id_ex_csr_op_q == `RV32I_CSR_OP_RS) &&
                         (id_ex_rs1_addr_q != 5'd0));
  assign ex_branch_taken = (id_ex_branch_op_q == `RV32I_BR_BEQ)  ? (forward_rs1_data == forward_rs2_data) :
                           (id_ex_branch_op_q == `RV32I_BR_BNE)  ? (forward_rs1_data != forward_rs2_data) :
                           (id_ex_branch_op_q == `RV32I_BR_BLT)  ? ($signed(forward_rs1_data) < $signed(forward_rs2_data)) :
                           (id_ex_branch_op_q == `RV32I_BR_BGE)  ? ($signed(forward_rs1_data) >= $signed(forward_rs2_data)) :
                           (id_ex_branch_op_q == `RV32I_BR_BLTU) ? (forward_rs1_data < forward_rs2_data) :
                           (id_ex_branch_op_q == `RV32I_BR_BGEU) ? (forward_rs1_data >= forward_rs2_data) :
                                                                   1'b0;
  assign ex_control_target_pc = (id_ex_pc_sel_q == `RV32I_PC_JAL)  ? (id_ex_pc_q + id_ex_imm_j_q) :
                                (id_ex_pc_sel_q == `RV32I_PC_JALR) ? ((forward_rs1_data + id_ex_imm_i_q) & ~32'd1) :
                                                                     (id_ex_pc_q + id_ex_imm_b_q);
  assign ex_control_taken = (id_ex_pc_sel_q == `RV32I_PC_JAL) ||
                            (id_ex_pc_sel_q == `RV32I_PC_JALR) ||
                            ((id_ex_pc_sel_q == `RV32I_PC_BRANCH) && ex_branch_taken);
  assign ex_control_instr = (id_ex_pc_sel_q == `RV32I_PC_JAL) ||
                            (id_ex_pc_sel_q == `RV32I_PC_JALR) ||
                            (id_ex_pc_sel_q == `RV32I_PC_BRANCH);
  assign ex_branch_instr = (id_ex_pc_sel_q == `RV32I_PC_BRANCH);
  assign ex_actual_next_pc = ex_control_taken ? ex_control_target_pc : id_ex_pc4_q;
  assign ex_instr_addr_misaligned = id_ex_valid_q &&
                                    !id_ex_illegal_q &&
                                    !id_ex_instr_fault_q &&
                                    ex_control_taken &&
                                    (ex_control_target_pc[1:0] != 2'b00);
  assign ex_branch_update = id_ex_valid_q &&
                            !id_ex_illegal_q &&
                            !id_ex_instr_fault_q &&
                            ex_branch_instr &&
                            !ex_instr_addr_misaligned &&
                            !mem_stall &&
                            !commit_redirect;
  assign ex_prediction_mismatch = id_ex_valid_q &&
                                  !id_ex_illegal_q &&
                                  !id_ex_instr_fault_q &&
                                  ex_control_instr &&
                                  !ex_instr_addr_misaligned &&
                                  (id_ex_predicted_pc_q != ex_actual_next_pc);
  assign ex_redirect = ex_prediction_mismatch;
  assign ex_redirect_pc = ex_actual_next_pc;

  rv32i_alu u_alu (
    .alu_op (id_ex_alu_op_q),
    .src_a  (forward_rs1_data),
    .src_b  (ex_alu_src_b),
    .result (ex_alu_result)
  );

  assign ex_muldiv_valid = id_ex_valid_q &&
                            id_ex_muldiv_valid_q &&
                            !id_ex_illegal_q &&
                            !id_ex_instr_fault_q &&
                            !commit_redirect;
  assign ex_muldiv_stall = ex_muldiv_valid && !ex_muldiv_ready;
  assign ex_muldiv_consume = ex_muldiv_valid &&
                              ex_muldiv_ready &&
                              !mem_stall &&
                              !commit_redirect;
  assign ex_result = id_ex_muldiv_valid_q ? ex_muldiv_result : ex_alu_result;

  rv32i_muldiv u_muldiv (
    .clk     (clk),
    .rst_n   (rst_n),
    .valid   (ex_muldiv_valid && !mem_stall),
    .op      (id_ex_muldiv_op_q),
    .lhs     (forward_rs1_data),
    .rhs     (forward_rs2_data),
    .consume (ex_muldiv_consume),
    .flush   (commit_redirect),
    .ready   (ex_muldiv_ready),
    .busy    (),
    .result  (ex_muldiv_result)
  );

  rv32i_pipe_csr u_pipe_csr (
    .clk                  (clk),
    .rst_n                (rst_n),
    .cycle_value          (perf_cycle_count),
    .timer_irq            (timer_irq),
    .ex_csr_addr          (id_ex_csr_addr_q),
    .ex_csr_rdata         (ex_csr_rdata),
    .commit_valid         (mem_wb_valid_q),
    .commit_pc4           (mem_wb_pc4_q),
    .commit_illegal       (mem_wb_illegal_q),
    .commit_ecall         (mem_wb_system_ecall_q),
    .commit_ebreak        (mem_wb_system_ebreak_q),
    .commit_mret          (mem_wb_system_mret_q),
    .commit_instr_addr_misaligned (mem_wb_instr_addr_misaligned_q),
    .commit_instr_fault   (mem_wb_instr_fault_q),
    .commit_load_addr_misaligned  (mem_wb_load_addr_misaligned_q),
    .commit_load_fault    (mem_wb_load_fault_q),
    .commit_store_addr_misaligned (mem_wb_store_addr_misaligned_q),
    .commit_store_fault   (mem_wb_store_fault_q),
    .commit_csr_write_req (mem_wb_csr_write_q),
    .commit_csr_addr      (mem_wb_csr_addr_q),
    .commit_csr_op        (mem_wb_csr_op_q),
    .commit_csr_rdata     (mem_wb_csr_rdata_q),
    .commit_csr_wdata     (mem_wb_csr_wdata_q),
    .commit_redirect      (commit_redirect),
    .commit_redirect_pc   (commit_redirect_pc),
    .dbg_illegal_instr    (dbg_illegal_instr),
    .dbg_ecall            (dbg_ecall),
    .dbg_ebreak           (dbg_ebreak)
  );

  rv32i_pipe_lsu u_pipe_lsu (
    .ex_mem_valid        (ex_mem_valid_q),
    .ex_mem_illegal      (ex_mem_illegal_q),
    .ex_mem_mem_valid    (ex_mem_mem_valid_q),
    .ex_mem_mem_write    (ex_mem_mem_write_q),
    .ex_mem_mem_size     (ex_mem_mem_size_q),
    .ex_mem_mem_unsigned (ex_mem_mem_unsigned_q),
    .ex_mem_mem_addr     (ex_mem_mem_addr_q),
    .ex_mem_store_data   (ex_mem_store_data_q),
    .commit_redirect     (commit_redirect),
    .dmem_valid          (dmem_valid),
    .dmem_write          (dmem_write),
    .dmem_addr           (dmem_addr),
    .dmem_wdata          (dmem_wdata),
    .dmem_wstrb          (dmem_wstrb),
    .dmem_ready          (dmem_ready),
    .dmem_rdata          (dmem_rdata),
    .dmem_error          (dmem_error),
    .mem_stall           (mem_stall),
    .mem_load_data       (mem_load_data),
    .mem_load_addr_misaligned  (mem_load_addr_misaligned),
    .mem_store_addr_misaligned (mem_store_addr_misaligned),
    .mem_load_fault      (mem_load_fault),
    .mem_store_fault     (mem_store_fault)
  );

  assign wb_wdata = (mem_wb_wb_sel_q == `RV32I_WB_LUI)   ? mem_wb_imm_u_q :
                    (mem_wb_wb_sel_q == `RV32I_WB_AUIPC) ? ((mem_wb_pc4_q - 32'd4) + mem_wb_imm_u_q) :
                    (mem_wb_wb_sel_q == `RV32I_WB_PC4)   ? mem_wb_pc4_q :
                    (mem_wb_wb_sel_q == `RV32I_WB_MEM)   ? mem_wb_load_data_q :
                    (mem_wb_wb_sel_q == `RV32I_WB_CSR)   ? mem_wb_csr_rdata_q :
                                                            mem_wb_alu_result_q;
  assign wb_reg_we = mem_wb_valid_q && mem_wb_reg_we_q &&
                     !mem_wb_illegal_q &&
                     !mem_wb_instr_addr_misaligned_q &&
                     !mem_wb_instr_fault_q &&
                     !mem_wb_load_addr_misaligned_q &&
                     !mem_wb_load_fault_q &&
                     !mem_wb_store_addr_misaligned_q &&
                     !mem_wb_store_fault_q;

  // Keep bubble/flush contents in one place so stage blocks stay readable.
  task clear_if_id;
    begin
      if_id_valid_q        <= 1'b0;
      if_id_pc_q           <= 32'd0;
      if_id_pc4_q          <= 32'd0;
      if_id_instr_q        <= 32'h0000_0013;
      if_id_instr_fault_q  <= 1'b0;
      if_id_predicted_pc_q <= 32'd0;
      if_id_btb_hit_q      <= 1'b0;
    end
  endtask

  task clear_id_ex;
    begin
      id_ex_valid_q         <= 1'b0;
      id_ex_pc_q            <= 32'd0;
      id_ex_pc4_q           <= 32'd0;
      id_ex_rs1_addr_q      <= 5'd0;
      id_ex_rs2_addr_q      <= 5'd0;
      id_ex_rd_addr_q       <= 5'd0;
      id_ex_rs1_data_q      <= 32'd0;
      id_ex_rs2_data_q      <= 32'd0;
      id_ex_imm_i_q         <= 32'd0;
      id_ex_imm_s_q         <= 32'd0;
      id_ex_imm_b_q         <= 32'd0;
      id_ex_imm_u_q         <= 32'd0;
      id_ex_imm_j_q         <= 32'd0;
      id_ex_reg_we_q        <= 1'b0;
      id_ex_alu_src_imm_q   <= 1'b0;
      id_ex_alu_op_q        <= `RV32I_ALU_ADD;
      id_ex_wb_sel_q        <= `RV32I_WB_ALU;
      id_ex_pc_sel_q        <= `RV32I_PC_NEXT;
      id_ex_branch_op_q     <= `RV32I_BR_BEQ;
      id_ex_mem_valid_q     <= 1'b0;
      id_ex_mem_write_q     <= 1'b0;
      id_ex_mem_size_q      <= `RV32I_MEM_WORD;
      id_ex_mem_unsigned_q  <= 1'b0;
      id_ex_csr_addr_q      <= 12'd0;
      id_ex_csr_op_q        <= `RV32I_CSR_OP_NONE;
      id_ex_system_ecall_q  <= 1'b0;
      id_ex_system_ebreak_q <= 1'b0;
      id_ex_system_mret_q   <= 1'b0;
      id_ex_muldiv_valid_q  <= 1'b0;
      id_ex_muldiv_op_q     <= `RV32I_MULDIV_MUL;
      id_ex_illegal_q       <= 1'b0;
      id_ex_instr_fault_q   <= 1'b0;
      id_ex_predicted_pc_q  <= 32'd0;
      id_ex_btb_hit_q       <= 1'b0;
    end
  endtask

  task clear_ex_mem;
    begin
      ex_mem_valid_q         <= 1'b0;
      ex_mem_pc4_q           <= 32'd0;
      ex_mem_rd_addr_q       <= 5'd0;
      ex_mem_alu_result_q    <= 32'd0;
      ex_mem_store_data_q    <= 32'd0;
      ex_mem_mem_addr_q      <= 32'd0;
      ex_mem_imm_u_q         <= 32'd0;
      ex_mem_csr_rdata_q     <= 32'd0;
      ex_mem_csr_wdata_q     <= 32'd0;
      ex_mem_csr_addr_q      <= 12'd0;
      ex_mem_csr_op_q        <= `RV32I_CSR_OP_NONE;
      ex_mem_csr_write_q     <= 1'b0;
      ex_mem_reg_we_q        <= 1'b0;
      ex_mem_wb_sel_q        <= `RV32I_WB_ALU;
      ex_mem_mem_valid_q     <= 1'b0;
      ex_mem_mem_write_q     <= 1'b0;
      ex_mem_mem_size_q      <= `RV32I_MEM_WORD;
      ex_mem_mem_unsigned_q  <= 1'b0;
      ex_mem_system_ecall_q  <= 1'b0;
      ex_mem_system_ebreak_q <= 1'b0;
      ex_mem_system_mret_q   <= 1'b0;
      ex_mem_illegal_q       <= 1'b0;
      ex_mem_instr_addr_misaligned_q <= 1'b0;
      ex_mem_instr_fault_q   <= 1'b0;
    end
  endtask

  task clear_mem_wb;
    begin
      mem_wb_valid_q         <= 1'b0;
      mem_wb_pc4_q           <= 32'd0;
      mem_wb_rd_addr_q       <= 5'd0;
      mem_wb_alu_result_q    <= 32'd0;
      mem_wb_load_data_q     <= 32'd0;
      mem_wb_imm_u_q         <= 32'd0;
      mem_wb_csr_rdata_q     <= 32'd0;
      mem_wb_csr_wdata_q     <= 32'd0;
      mem_wb_csr_addr_q      <= 12'd0;
      mem_wb_csr_op_q        <= `RV32I_CSR_OP_NONE;
      mem_wb_csr_write_q     <= 1'b0;
      mem_wb_reg_we_q        <= 1'b0;
      mem_wb_wb_sel_q        <= `RV32I_WB_ALU;
      mem_wb_system_ecall_q  <= 1'b0;
      mem_wb_system_ebreak_q <= 1'b0;
      mem_wb_system_mret_q   <= 1'b0;
      mem_wb_illegal_q       <= 1'b0;
      mem_wb_instr_addr_misaligned_q <= 1'b0;
      mem_wb_instr_fault_q   <= 1'b0;
      mem_wb_load_addr_misaligned_q  <= 1'b0;
      mem_wb_load_fault_q    <= 1'b0;
      mem_wb_store_addr_misaligned_q <= 1'b0;
      mem_wb_store_fault_q   <= 1'b0;
    end
  endtask

  // PC and IF/ID own fetch redirection and stale fetch response discard.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_q                 <= RESET_PC;
      if_discard_q         <= 1'b0;
      clear_if_id;
    end else begin
      if (pipe_commit_flush) begin
        pc_q         <= commit_redirect_pc;
        if_discard_q <= 1'b1;
        clear_if_id;
      end else if (pipe_front_advance) begin
        if (pipe_if_discard_flush) begin
          if (imem_ready) begin
            if_discard_q <= 1'b0;
          end
          clear_if_id;
        end else if (pipe_if_redirect_flush) begin
          pc_q         <= ex_redirect_pc;
          if_discard_q <= 1'b1;
          clear_if_id;
        end else if (pipe_if_normal_load) begin
          pc_q                 <= if_predicted_pc;
          if_id_valid_q        <= 1'b1;
          if_id_pc_q           <= pc_q;
          if_id_pc4_q          <= pc_q + 32'd4;
          if_id_instr_q        <= if_instr;
          if_id_instr_fault_q  <= imem_error;
          if_id_predicted_pc_q <= if_predicted_pc;
          if_id_btb_hit_q      <= !imem_error && if_is_branch && if_btb_hit;
        end
      end
    end
  end

  // ID/EX carries decoded controls; bubbles clear write/mem/system side effects.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      clear_id_ex;
    end else begin
      if (pipe_commit_flush) begin
        clear_id_ex;
      end else if (pipe_id_ex_advance) begin
        if (pipe_id_ex_bubble) begin
          clear_id_ex;
        end else begin
          id_ex_valid_q         <= if_id_valid_q;
          id_ex_pc_q            <= if_id_pc_q;
          id_ex_pc4_q           <= if_id_pc4_q;
          id_ex_rs1_addr_q      <= id_rs1_addr;
          id_ex_rs2_addr_q      <= id_rs2_addr;
          id_ex_rd_addr_q       <= id_rd_addr;
          id_ex_rs1_data_q      <= id_rs1_data_bypass;
          id_ex_rs2_data_q      <= id_rs2_data_bypass;
          id_ex_imm_i_q         <= id_imm_i;
          id_ex_imm_s_q         <= id_imm_s;
          id_ex_imm_b_q         <= id_imm_b;
          id_ex_imm_u_q         <= id_imm_u;
          id_ex_imm_j_q         <= id_imm_j;
          id_ex_reg_we_q        <= id_reg_we;
          id_ex_alu_src_imm_q   <= id_alu_src_imm;
          id_ex_alu_op_q        <= id_alu_op;
          id_ex_wb_sel_q        <= id_wb_sel;
          id_ex_pc_sel_q        <= id_pc_sel;
          id_ex_branch_op_q     <= id_branch_op;
          id_ex_mem_valid_q     <= id_mem_valid;
          id_ex_mem_write_q     <= id_mem_write;
          id_ex_mem_size_q      <= id_mem_size;
          id_ex_mem_unsigned_q  <= id_mem_unsigned;
          id_ex_csr_addr_q      <= id_csr_addr;
          id_ex_csr_op_q        <= id_csr_op;
          id_ex_system_ecall_q  <= id_system_ecall;
          id_ex_system_ebreak_q <= id_system_ebreak;
          id_ex_system_mret_q   <= id_system_mret;
          id_ex_muldiv_valid_q  <= id_muldiv_valid;
          id_ex_muldiv_op_q     <= id_muldiv_op;
          id_ex_illegal_q       <= id_illegal;
          id_ex_instr_fault_q   <= if_id_instr_fault_q;
          id_ex_predicted_pc_q  <= if_id_predicted_pc_q;
          id_ex_btb_hit_q       <= if_id_btb_hit_q;
        end
      end
    end
  end

  // EX/MEM accepts execute results, or a bubble while a multi-cycle op waits.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      clear_ex_mem;
    end else begin
      if (pipe_commit_flush) begin
        clear_ex_mem;
      end else if (pipe_ex_mem_advance) begin
        if (pipe_ex_mem_bubble) begin
          clear_ex_mem;
        end else begin
          ex_mem_valid_q         <= id_ex_valid_q;
          ex_mem_pc4_q           <= id_ex_pc4_q;
          ex_mem_rd_addr_q       <= id_ex_rd_addr_q;
          ex_mem_alu_result_q    <= ex_result;
          ex_mem_store_data_q    <= forward_rs2_data;
          ex_mem_mem_addr_q      <= ex_mem_addr;
          ex_mem_imm_u_q         <= id_ex_imm_u_q;
          ex_mem_csr_rdata_q     <= ex_csr_rdata;
          ex_mem_csr_wdata_q     <= forward_rs1_data;
          ex_mem_csr_addr_q      <= id_ex_csr_addr_q;
          ex_mem_csr_op_q        <= id_ex_csr_op_q;
          ex_mem_csr_write_q     <= ex_csr_write;
          ex_mem_reg_we_q        <= id_ex_reg_we_q;
          ex_mem_wb_sel_q        <= id_ex_wb_sel_q;
          ex_mem_mem_valid_q     <= id_ex_mem_valid_q;
          ex_mem_mem_write_q     <= id_ex_mem_write_q;
          ex_mem_mem_size_q      <= id_ex_mem_size_q;
          ex_mem_mem_unsigned_q  <= id_ex_mem_unsigned_q;
          ex_mem_system_ecall_q  <= id_ex_system_ecall_q;
          ex_mem_system_ebreak_q <= id_ex_system_ebreak_q;
          ex_mem_system_mret_q   <= id_ex_system_mret_q;
          ex_mem_illegal_q       <= id_ex_illegal_q;
          ex_mem_instr_addr_misaligned_q <= ex_instr_addr_misaligned;
          ex_mem_instr_fault_q   <= id_ex_instr_fault_q;
        end
      end
    end
  end

  // MEM/WB drains from old EX/MEM when EX is held by mul/div, and holds on memory stalls.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      clear_mem_wb;
    end else begin
      if (pipe_commit_flush) begin
        clear_mem_wb;
      end else if (pipe_ex_mem_advance) begin
        mem_wb_valid_q         <= ex_mem_valid_q;
        mem_wb_pc4_q           <= ex_mem_pc4_q;
        mem_wb_rd_addr_q       <= ex_mem_rd_addr_q;
        mem_wb_alu_result_q    <= ex_mem_alu_result_q;
        mem_wb_load_data_q     <= mem_load_data;
        mem_wb_imm_u_q         <= ex_mem_imm_u_q;
        mem_wb_csr_rdata_q     <= ex_mem_csr_rdata_q;
        mem_wb_csr_wdata_q     <= ex_mem_csr_wdata_q;
        mem_wb_csr_addr_q      <= ex_mem_csr_addr_q;
        mem_wb_csr_op_q        <= ex_mem_csr_op_q;
        mem_wb_csr_write_q     <= ex_mem_csr_write_q;
        mem_wb_reg_we_q        <= ex_mem_reg_we_q;
        mem_wb_wb_sel_q        <= ex_mem_wb_sel_q;
        mem_wb_system_ecall_q  <= ex_mem_system_ecall_q;
        mem_wb_system_ebreak_q <= ex_mem_system_ebreak_q;
        mem_wb_system_mret_q   <= ex_mem_system_mret_q;
        mem_wb_illegal_q       <= ex_mem_illegal_q;
        mem_wb_instr_addr_misaligned_q <= ex_mem_instr_addr_misaligned_q;
        mem_wb_instr_fault_q   <= ex_mem_instr_fault_q;
        mem_wb_load_addr_misaligned_q  <= mem_load_addr_misaligned;
        mem_wb_load_fault_q    <= mem_load_fault;
        mem_wb_store_addr_misaligned_q <= mem_store_addr_misaligned;
        mem_wb_store_fault_q   <= mem_store_fault;
      end
    end
  end

`ifndef SYNTHESIS
`ifndef RV32I_DISABLE_ASSERT
  // Commit-stage redirect has the highest priority and must suppress younger flow.
  property p_commit_flush_controls_priority;
    @(posedge clk) disable iff (!rst_n)
      pipe_commit_flush |-> (!pipe_front_advance &&
                             !pipe_ex_mem_advance &&
                             !perf_flush_event);
  endproperty

  assert property (p_commit_flush_controls_priority)
    else $fatal(1, "commit redirect must have priority over front/backend flow");

  // A trap/MRET redirect flushes all in-flight pipeline valid bits on the next edge.
  property p_commit_flush_clears_pipeline;
    @(posedge clk) disable iff (!rst_n)
      pipe_commit_flush |=> (!if_id_valid_q &&
                             !id_ex_valid_q &&
                             !ex_mem_valid_q &&
                             !mem_wb_valid_q);
  endproperty

  assert property (p_commit_flush_clears_pipeline)
    else $fatal(1, "commit redirect did not clear pipeline valid bits");

  // A memory wait-state freezes the backend until the LSU transaction completes.
  property p_mem_stall_holds_backend;
    @(posedge clk) disable iff (!rst_n)
      (mem_stall && !pipe_commit_flush) |=>
        $stable({
          ex_mem_valid_q,
          ex_mem_pc4_q,
          ex_mem_rd_addr_q,
          ex_mem_alu_result_q,
          ex_mem_store_data_q,
          ex_mem_mem_addr_q,
          ex_mem_imm_u_q,
          ex_mem_csr_rdata_q,
          ex_mem_csr_wdata_q,
          ex_mem_csr_addr_q,
          ex_mem_csr_op_q,
          ex_mem_csr_write_q,
          ex_mem_reg_we_q,
          ex_mem_wb_sel_q,
          ex_mem_mem_valid_q,
          ex_mem_mem_write_q,
          ex_mem_mem_size_q,
          ex_mem_mem_unsigned_q,
          ex_mem_system_ecall_q,
          ex_mem_system_ebreak_q,
          ex_mem_system_mret_q,
          ex_mem_illegal_q,
          ex_mem_instr_addr_misaligned_q,
          ex_mem_instr_fault_q,
          mem_wb_valid_q,
          mem_wb_pc4_q,
          mem_wb_rd_addr_q,
          mem_wb_alu_result_q,
          mem_wb_load_data_q,
          mem_wb_imm_u_q,
          mem_wb_csr_rdata_q,
          mem_wb_csr_wdata_q,
          mem_wb_csr_addr_q,
          mem_wb_csr_op_q,
          mem_wb_csr_write_q,
          mem_wb_reg_we_q,
          mem_wb_wb_sel_q,
          mem_wb_system_ecall_q,
          mem_wb_system_ebreak_q,
          mem_wb_system_mret_q,
          mem_wb_illegal_q,
          mem_wb_instr_addr_misaligned_q,
          mem_wb_instr_fault_q,
          mem_wb_load_addr_misaligned_q,
          mem_wb_load_fault_q,
          mem_wb_store_addr_misaligned_q,
          mem_wb_store_fault_q
        });
  endproperty

  assert property (p_mem_stall_holds_backend)
    else $fatal(1, "memory stall did not hold EX/MEM and MEM/WB state");

  // A multi-cycle M operation holds fetch/decode and inserts a bubble into EX/MEM.
  property p_muldiv_stall_holds_frontend;
    @(posedge clk) disable iff (!rst_n)
      (ex_muldiv_stall && !mem_stall && !pipe_commit_flush) |=>
        ($stable({
           pc_q,
           if_discard_q,
           if_id_valid_q,
           if_id_pc_q,
           if_id_pc4_q,
           if_id_instr_q,
           if_id_instr_fault_q,
           if_id_predicted_pc_q,
           if_id_btb_hit_q,
           id_ex_valid_q,
           id_ex_pc_q,
           id_ex_pc4_q,
           id_ex_rs1_addr_q,
           id_ex_rs2_addr_q,
           id_ex_rd_addr_q,
           id_ex_rs1_data_q,
           id_ex_rs2_data_q,
           id_ex_imm_i_q,
           id_ex_imm_s_q,
           id_ex_imm_b_q,
           id_ex_imm_u_q,
           id_ex_imm_j_q,
           id_ex_reg_we_q,
           id_ex_alu_src_imm_q,
           id_ex_alu_op_q,
           id_ex_wb_sel_q,
           id_ex_pc_sel_q,
           id_ex_branch_op_q,
           id_ex_mem_valid_q,
           id_ex_mem_write_q,
           id_ex_mem_size_q,
           id_ex_mem_unsigned_q,
           id_ex_csr_addr_q,
           id_ex_csr_op_q,
           id_ex_system_ecall_q,
           id_ex_system_ebreak_q,
           id_ex_system_mret_q,
           id_ex_muldiv_valid_q,
           id_ex_muldiv_op_q,
           id_ex_illegal_q,
           id_ex_instr_fault_q,
           id_ex_predicted_pc_q,
           id_ex_btb_hit_q
         }) &&
         !ex_mem_valid_q);
  endproperty

  assert property (p_muldiv_stall_holds_frontend)
    else $fatal(1, "mul/div stall did not hold frontend or bubble EX/MEM");

  // Predictor training is only legal for a valid, non-faulting B-type branch.
  property p_branch_update_is_valid_branch;
    @(posedge clk) disable iff (!rst_n)
      ex_branch_update |-> (id_ex_valid_q &&
                            ex_branch_instr &&
                            !id_ex_illegal_q &&
                            !id_ex_instr_fault_q &&
                            !ex_instr_addr_misaligned &&
                            !mem_stall &&
                            !pipe_commit_flush);
  endproperty

  assert property (p_branch_update_is_valid_branch)
    else $fatal(1, "branch predictor updated from an invalid branch state");

  // Faulting or illegal instructions must never reach the architectural writeback port.
  property p_wb_reg_we_has_no_fault;
    @(posedge clk) disable iff (!rst_n)
      wb_reg_we |-> (mem_wb_valid_q &&
                     mem_wb_reg_we_q &&
                     !mem_wb_illegal_q &&
                     !mem_wb_instr_addr_misaligned_q &&
                     !mem_wb_instr_fault_q &&
                     !mem_wb_load_addr_misaligned_q &&
                     !mem_wb_load_fault_q &&
                     !mem_wb_store_addr_misaligned_q &&
                     !mem_wb_store_fault_q);
  endproperty

  assert property (p_wb_reg_we_has_no_fault)
    else $fatal(1, "writeback enabled while commit-stage fault is present");
`endif
`endif

endmodule
