`timescale 1ns/1ps

module rv32i_branch_predictor_tb;

  localparam CLK_PERIOD_NS = 10;

  logic clk;
  logic rst_n;

  logic [31:0] if_pc;
  logic [31:0] if_instr;
  logic        if_error;
  wire [31:0]  if_predicted_pc;
  wire         if_predict_taken;
  wire         if_is_branch;
  wire         if_btb_hit;

  logic        ex_update_valid;
  logic [31:0] ex_pc;
  logic        ex_taken;
  logic [31:0] ex_target_pc;
  logic        ex_fetch_btb_hit;

  wire [31:0] dbg_btb_hit_count;
  wire [31:0] dbg_btb_miss_count;
  wire [31:0] dbg_bht_update_count;

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD_NS/2) clk = ~clk;
  end

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

  rv32i_branch_predictor #(
    .INDEX_BITS(2)
  ) u_bpu (
    .clk                  (clk),
    .rst_n                (rst_n),
    .if_pc                (if_pc),
    .if_instr             (if_instr),
    .if_error             (if_error),
    .if_predicted_pc      (if_predicted_pc),
    .if_predict_taken     (if_predict_taken),
    .if_is_branch         (if_is_branch),
    .if_btb_hit           (if_btb_hit),
    .ex_update_valid      (ex_update_valid),
    .ex_pc                (ex_pc),
    .ex_taken             (ex_taken),
    .ex_target_pc         (ex_target_pc),
    .ex_fetch_btb_hit     (ex_fetch_btb_hit),
    .dbg_btb_hit_count    (dbg_btb_hit_count),
    .dbg_btb_miss_count   (dbg_btb_miss_count),
    .dbg_bht_update_count (dbg_bht_update_count)
  );

  initial begin
    if_pc = 32'd0;
    if_instr = 32'h0000_0013;
    if_error = 1'b0;
    ex_update_valid = 1'b0;
    ex_pc = 32'd0;
    ex_taken = 1'b0;
    ex_target_pc = 32'd0;
    ex_fetch_btb_hit = 1'b0;

    rst_n = 1'b0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
    #1ps;

    // Forward BEQ starts as static not-taken because the BTB is empty.
    if_pc = 32'h0000_0010;
    if_instr = 32'h0000_0463; // beq x0, x0, +8
    if_error = 1'b0;
    #1ps;
    check_bit(if_is_branch, 1'b1, "if_is_branch before training");
    check_bit(if_btb_hit, 1'b0, "if_btb_hit before training");
    check_bit(if_predict_taken, 1'b0, "if_predict_taken before training");
    check_value(if_predicted_pc, 32'h0000_0014, "if_predicted_pc before training");

    // A taken update installs the BTB entry and strengthens the BHT.
    ex_update_valid = 1'b1;
    ex_pc = 32'h0000_0010;
    ex_taken = 1'b1;
    ex_target_pc = 32'h0000_0018;
    ex_fetch_btb_hit = 1'b0;
    @(posedge clk);
    #1ps;
    ex_update_valid = 1'b0;
    ex_fetch_btb_hit = 1'b0;
    check_value(dbg_bht_update_count, 32'd1, "bht_update_count after taken update");
    check_value(dbg_btb_miss_count, 32'd1, "btb_miss_count after taken update");
    check_value(dbg_btb_hit_count, 32'd0, "btb_hit_count after taken update");
    check_bit(if_btb_hit, 1'b1, "if_btb_hit after training");
    check_bit(if_predict_taken, 1'b1, "if_predict_taken after training");
    check_value(if_predicted_pc, 32'h0000_0018, "if_predicted_pc after training");

    // A not-taken update keeps the BTB entry but weakens the BHT to not-taken.
    ex_update_valid = 1'b1;
    ex_pc = 32'h0000_0010;
    ex_taken = 1'b0;
    ex_target_pc = 32'h0000_0018;
    ex_fetch_btb_hit = 1'b1;
    @(posedge clk);
    #1ps;
    ex_update_valid = 1'b0;
    ex_fetch_btb_hit = 1'b0;
    check_value(dbg_bht_update_count, 32'd2, "bht_update_count after not-taken update");
    check_value(dbg_btb_miss_count, 32'd1, "btb_miss_count after not-taken update");
    check_value(dbg_btb_hit_count, 32'd1, "btb_hit_count after not-taken update");
    check_bit(if_btb_hit, 1'b1, "if_btb_hit after not-taken update");
    check_bit(if_predict_taken, 1'b0, "if_predict_taken after not-taken update");
    check_value(if_predicted_pc, 32'h0000_0014, "if_predicted_pc after not-taken update");

    // JAL still predicts directly from its immediate and does not need BTB.
    if_pc = 32'h0000_0020;
    if_instr = 32'h0080_006f; // jal x0, +8
    #1ps;
    check_bit(if_is_branch, 1'b0, "if_is_branch for jal");
    check_bit(if_predict_taken, 1'b1, "if_predict_taken for jal");
    check_value(if_predicted_pc, 32'h0000_0028, "if_predicted_pc for jal");

    // Fetch errors suppress prediction even if the instruction bits look like JAL.
    if_error = 1'b1;
    #1ps;
    check_bit(if_predict_taken, 1'b0, "if_predict_taken with if_error");
    check_value(if_predicted_pc, 32'h0000_0024, "if_predicted_pc with if_error");

    $display("[PASS] rv32i_branch_predictor_tb");
    $display("  btb_hit=%0d btb_miss=%0d bht_update=%0d",
             dbg_btb_hit_count, dbg_btb_miss_count, dbg_bht_update_count);
    $display("  standalone BHT/BTB predictor query and update paths passed");
    $finish;
  end

endmodule
