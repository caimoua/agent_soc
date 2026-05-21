`timescale 1ns/1ps

module rv32i_perf_counter_tb;

  localparam CLK_PERIOD_NS = 10;

  logic clk;
  logic rst_n;

  logic instret_event;
  logic stall_event;
  logic flush_event;
  logic branch_event;
  logic branch_mispredict_event;

  wire [31:0] cycle_count;
  wire [31:0] instret_count;
  wire [31:0] stall_cycle_count;
  wire [31:0] flush_cycle_count;
  wire [31:0] branch_count;
  wire [31:0] branch_mispredict_count;

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

  task automatic clear_events;
    begin
      instret_event = 1'b0;
      stall_event = 1'b0;
      flush_event = 1'b0;
      branch_event = 1'b0;
      branch_mispredict_event = 1'b0;
    end
  endtask

  task automatic check_counts(
    input [31:0] expected_cycle,
    input [31:0] expected_instret,
    input [31:0] expected_stall,
    input [31:0] expected_flush,
    input [31:0] expected_branch,
    input [31:0] expected_mispredict
  );
    begin
      check_value(cycle_count, expected_cycle, "cycle_count");
      check_value(instret_count, expected_instret, "instret_count");
      check_value(stall_cycle_count, expected_stall, "stall_cycle_count");
      check_value(flush_cycle_count, expected_flush, "flush_cycle_count");
      check_value(branch_count, expected_branch, "branch_count");
      check_value(branch_mispredict_count, expected_mispredict,
                  "branch_mispredict_count");
    end
  endtask

  rv32i_perf_counter u_perf_counter (
    .clk                     (clk),
    .rst_n                   (rst_n),
    .instret_event           (instret_event),
    .stall_event             (stall_event),
    .flush_event             (flush_event),
    .branch_event            (branch_event),
    .branch_mispredict_event (branch_mispredict_event),
    .cycle_count             (cycle_count),
    .instret_count           (instret_count),
    .stall_cycle_count       (stall_cycle_count),
    .flush_cycle_count       (flush_cycle_count),
    .branch_count            (branch_count),
    .branch_mispredict_count (branch_mispredict_count)
  );

  initial begin
    clear_events();
    rst_n = 1'b0;
    repeat (3) @(posedge clk);
    #1ps;
    check_counts(32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0);

    rst_n = 1'b1;
    @(posedge clk);
    #1ps;
    check_counts(32'd1, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0);

    instret_event = 1'b1;
    stall_event = 1'b1;
    branch_event = 1'b1;
    @(posedge clk);
    #1ps;
    check_counts(32'd2, 32'd1, 32'd1, 32'd0, 32'd1, 32'd0);

    clear_events();
    flush_event = 1'b1;
    branch_event = 1'b1;
    branch_mispredict_event = 1'b1;
    @(posedge clk);
    #1ps;
    check_counts(32'd3, 32'd1, 32'd1, 32'd1, 32'd2, 32'd1);

    instret_event = 1'b1;
    stall_event = 1'b1;
    flush_event = 1'b1;
    branch_event = 1'b1;
    branch_mispredict_event = 1'b1;
    @(posedge clk);
    #1ps;
    check_counts(32'd4, 32'd2, 32'd2, 32'd2, 32'd3, 32'd2);

    clear_events();
    @(posedge clk);
    #1ps;
    check_counts(32'd5, 32'd2, 32'd2, 32'd2, 32'd3, 32'd2);

    rst_n = 1'b0;
    #1ps;
    check_counts(32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0);

    $display("[PASS] rv32i_perf_counter_tb");
    $display("  cycle=%0d instret=%0d stall=%0d flush=%0d",
             cycle_count, instret_count, stall_cycle_count,
             flush_cycle_count);
    $display("  branch=%0d branch_mispredict=%0d",
             branch_count, branch_mispredict_count);
    $display("  standalone performance counter events and reset passed");
    $finish;
  end

endmodule
