`include "rv32i_defs.vh"

module rv32i_branch_predictor #(
  parameter INDEX_BITS = 6
) (
  input  wire        clk,
  input  wire        rst_n,

  input  wire [31:0] if_pc,
  input  wire [31:0] if_instr,
  input  wire        if_error,
  output wire [31:0] if_predicted_pc,
  output wire        if_predict_taken,
  output wire        if_is_branch,
  output wire        if_btb_hit,

  input  wire        ex_update_valid,
  input  wire [31:0] ex_pc,
  input  wire        ex_taken,
  input  wire [31:0] ex_target_pc,
  input  wire        ex_fetch_btb_hit,

  output wire [31:0] dbg_btb_hit_count,
  output wire [31:0] dbg_btb_miss_count,
  output wire [31:0] dbg_bht_update_count
);

  localparam BP_ENTRIES = (1 << INDEX_BITS);
  localparam BP_TAG_BITS = 32 - INDEX_BITS - 2;

  reg [1:0] bht [0:BP_ENTRIES-1];
  reg       btb_valid [0:BP_ENTRIES-1];
  reg [BP_TAG_BITS-1:0] btb_tag [0:BP_ENTRIES-1];
  reg [31:0] btb_target [0:BP_ENTRIES-1];

  reg [31:0] btb_hit_count_q;
  reg [31:0] btb_miss_count_q;
  reg [31:0] bht_update_count_q;

  wire [6:0]  if_opcode;
  wire [31:0] if_imm_b;
  wire [31:0] if_imm_j;
  wire [31:0] if_branch_target_pc;
  wire [31:0] if_jal_target_pc;
  wire        if_is_jal;
  wire        if_jal_predict_taken;
  wire        if_dynamic_branch_predict_taken;
  wire        if_static_branch_predict_taken;
  wire [INDEX_BITS-1:0] if_bp_index;
  wire [BP_TAG_BITS-1:0] if_bp_tag;
  wire [31:0] if_btb_target_pc;
  wire [1:0]  if_bht_counter;
  wire        if_bht_predict_taken;
  wire        if_btb_target_aligned;

  wire [INDEX_BITS-1:0] ex_bp_index;
  wire [BP_TAG_BITS-1:0] ex_bp_tag;

  integer bp_i;

  assign if_opcode = if_instr[6:0];
  assign if_imm_b = {{19{if_instr[31]}}, if_instr[31], if_instr[7],
                     if_instr[30:25], if_instr[11:8], 1'b0};
  assign if_imm_j = {{11{if_instr[31]}}, if_instr[31], if_instr[19:12],
                     if_instr[20], if_instr[30:21], 1'b0};
  assign if_branch_target_pc = if_pc + if_imm_b;
  assign if_jal_target_pc = if_pc + if_imm_j;
  assign if_is_jal = (if_opcode == `RV32I_OPCODE_JAL);
  assign if_is_branch = (if_opcode == `RV32I_OPCODE_BRANCH);

  assign if_bp_index = if_pc[INDEX_BITS+1:2];
  assign if_bp_tag = if_pc[31:INDEX_BITS+2];
  assign if_bht_counter = bht[if_bp_index];
  assign if_bht_predict_taken = if_bht_counter[1];
  assign if_btb_hit = btb_valid[if_bp_index] &&
                      (btb_tag[if_bp_index] == if_bp_tag);
  assign if_btb_target_pc = btb_target[if_bp_index];
  assign if_btb_target_aligned = (if_btb_target_pc[1:0] == 2'b00);

  assign if_jal_predict_taken = if_is_jal &&
                                (if_jal_target_pc[1:0] == 2'b00);
  assign if_dynamic_branch_predict_taken =
    if_is_branch && if_btb_hit && if_bht_predict_taken &&
    if_btb_target_aligned;
  assign if_static_branch_predict_taken =
    if_is_branch && !if_btb_hit && if_imm_b[31] &&
    (if_branch_target_pc[1:0] == 2'b00);
  assign if_predict_taken =
    !if_error &&
    (if_jal_predict_taken ||
     if_dynamic_branch_predict_taken ||
     if_static_branch_predict_taken);
  assign if_predicted_pc =
    (!if_predict_taken) ? (if_pc + 32'd4) :
    if_jal_predict_taken ? if_jal_target_pc :
    if_dynamic_branch_predict_taken ? if_btb_target_pc :
                                      if_branch_target_pc;

  assign ex_bp_index = ex_pc[INDEX_BITS+1:2];
  assign ex_bp_tag = ex_pc[31:INDEX_BITS+2];

  assign dbg_btb_hit_count = btb_hit_count_q;
  assign dbg_btb_miss_count = btb_miss_count_q;
  assign dbg_bht_update_count = bht_update_count_q;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      btb_hit_count_q    <= 32'd0;
      btb_miss_count_q   <= 32'd0;
      bht_update_count_q <= 32'd0;
      for (bp_i = 0; bp_i < BP_ENTRIES; bp_i = bp_i + 1) begin
        bht[bp_i]        <= 2'b01;
        btb_valid[bp_i]  <= 1'b0;
        btb_tag[bp_i]    <= {BP_TAG_BITS{1'b0}};
        btb_target[bp_i] <= 32'd0;
      end
    end else if (ex_update_valid) begin
      bht_update_count_q <= bht_update_count_q + 32'd1;
      if (ex_fetch_btb_hit) begin
        btb_hit_count_q <= btb_hit_count_q + 32'd1;
      end else begin
        btb_miss_count_q <= btb_miss_count_q + 32'd1;
      end

      if (ex_taken) begin
        if (bht[ex_bp_index] != 2'b11) begin
          bht[ex_bp_index] <= bht[ex_bp_index] + 2'd1;
        end
        btb_valid[ex_bp_index]  <= 1'b1;
        btb_tag[ex_bp_index]    <= ex_bp_tag;
        btb_target[ex_bp_index] <= ex_target_pc;
      end else if (bht[ex_bp_index] != 2'b00) begin
        bht[ex_bp_index] <= bht[ex_bp_index] - 2'd1;
      end
    end
  end

endmodule
