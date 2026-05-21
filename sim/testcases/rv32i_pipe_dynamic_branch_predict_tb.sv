`timescale 1ns/1ps

module rv32i_pipe_dynamic_branch_predict_tb;

  localparam CLK_PERIOD_NS = 10;

  logic clk;
  logic rst_n;

  wire        imem_valid;
  wire [31:0] imem_addr;
  wire        imem_ready;
  wire [31:0] imem_rdata;

  wire        dmem_valid;
  wire        dmem_write;
  wire [31:0] dmem_addr;
  wire [31:0] dmem_wdata;
  wire [3:0]  dmem_wstrb;
  wire        dmem_ready;
  wire [31:0] dmem_rdata;

  wire [31:0] dbg_pc;
  wire [31:0] dbg_cycle;
  wire [31:0] dbg_instret;
  wire [31:0] dbg_stall_cycle;
  wire [31:0] dbg_flush_cycle;
  wire [31:0] dbg_branch_count;
  wire [31:0] dbg_branch_mispredict_count;
  wire [31:0] dbg_btb_hit_count;
  wire [31:0] dbg_btb_miss_count;
  wire [31:0] dbg_bht_update_count;
  logic [4:0] dbg_reg_addr;
  wire [31:0] dbg_reg_rdata;
  wire        dbg_illegal_instr;
  wire        dbg_ecall;
  wire        dbg_ebreak;

  logic [31:0] imem [0:255];
  string       imem_memh;
  integer i;
  integer memh_fd;
  integer timeout;

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD_NS/2) clk = ~clk;
  end

  task automatic check_reg(
    input [4:0]  reg_addr,
    input [31:0] expected,
    input string reg_name
  );
    begin
      dbg_reg_addr = reg_addr;
      #1ps;
      if (dbg_reg_rdata !== expected) begin
        $fatal(1, "%s mismatch: expected 0x%08x, got 0x%08x",
               reg_name, expected, dbg_reg_rdata);
      end
    end
  endtask

  initial begin
    for (i = 0; i < 256; i = i + 1) begin
      imem[i] = 32'h0000_0013; // addi x0, x0, 0
    end

    if (!$value$plusargs("IMEM_MEMH=%s", imem_memh)) begin
      imem_memh = "../software/bin/pipe_dynamic_branch_predict.memh";
    end

    memh_fd = $fopen(imem_memh, "r");
    if (memh_fd == 0) begin
      $fatal(1, "failed to open IMEM_MEMH='%s'", imem_memh);
    end
    $fclose(memh_fd);
    $readmemh(imem_memh, imem);
  end

  assign imem_ready = imem_valid;
  assign imem_rdata = imem[imem_addr[9:2]];
  assign dmem_ready = 1'b1;
  assign dmem_rdata = 32'd0;

  always @(posedge clk) begin
    if (dmem_valid) begin
      $fatal(1, "unexpected data-memory access in dynamic branch predictor test");
    end
  end

  rv32i_pipe_core u_core (
    .clk                         (clk),
    .rst_n                       (rst_n),
    .timer_irq                   (1'b0),
    .imem_valid                  (imem_valid),
    .imem_addr                   (imem_addr),
    .imem_ready                  (imem_ready),
    .imem_rdata                  (imem_rdata),
    .imem_error                  (1'b0),
    .dmem_valid                  (dmem_valid),
    .dmem_write                  (dmem_write),
    .dmem_addr                   (dmem_addr),
    .dmem_wdata                  (dmem_wdata),
    .dmem_wstrb                  (dmem_wstrb),
    .dmem_ready                  (dmem_ready),
    .dmem_rdata                  (dmem_rdata),
    .dmem_error                  (1'b0),
    .dbg_pc                      (dbg_pc),
    .dbg_cycle                   (dbg_cycle),
    .dbg_instret                 (dbg_instret),
    .dbg_stall_cycle             (dbg_stall_cycle),
    .dbg_flush_cycle             (dbg_flush_cycle),
    .dbg_branch_count            (dbg_branch_count),
    .dbg_branch_mispredict_count (dbg_branch_mispredict_count),
    .dbg_btb_hit_count           (dbg_btb_hit_count),
    .dbg_btb_miss_count          (dbg_btb_miss_count),
    .dbg_bht_update_count        (dbg_bht_update_count),
    .dbg_reg_addr                (dbg_reg_addr),
    .dbg_reg_rdata               (dbg_reg_rdata),
    .dbg_illegal_instr           (dbg_illegal_instr),
    .dbg_ecall                   (dbg_ecall),
    .dbg_ebreak                  (dbg_ebreak)
  );

  initial begin
    dbg_reg_addr = 5'd0;
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    timeout = 0;
    while (!dbg_ebreak && (timeout < 160)) begin
      @(posedge clk);
      #1ps;
      timeout = timeout + 1;
    end

    if (!dbg_ebreak) begin
      $fatal(1, "timeout waiting for dynamic branch predictor ebreak");
    end
    if (dbg_illegal_instr) begin
      $fatal(1, "unexpected illegal instruction in dynamic branch predictor test");
    end
    if (dbg_ecall) begin
      $fatal(1, "unexpected ECALL event in dynamic branch predictor test");
    end

    check_reg(5'd1, 32'd4,  "x1 loop counter");
    check_reg(5'd2, 32'd4,  "x2 loop limit");
    check_reg(5'd3, 32'd4,  "x3 forward branch target counter");
    check_reg(5'd4, 32'd0,  "x4 wrong-path guard");
    check_reg(5'd5, 32'h55, "x5 done marker");

    if (dbg_instret !== 32'd22) begin
      $fatal(1, "instret mismatch: expected 22, got %0d", dbg_instret);
    end
    if (dbg_branch_count !== 32'd8) begin
      $fatal(1, "branch_count mismatch: expected 8, got %0d", dbg_branch_count);
    end
    if (dbg_branch_mispredict_count !== 32'd2) begin
      $fatal(1, "branch_mispredict_count mismatch: expected 2, got %0d",
             dbg_branch_mispredict_count);
    end
    if (dbg_bht_update_count !== 32'd8) begin
      $fatal(1, "bht_update_count mismatch: expected 8, got %0d",
             dbg_bht_update_count);
    end
    if (dbg_btb_miss_count !== 32'd2) begin
      $fatal(1, "btb_miss_count mismatch: expected 2, got %0d",
             dbg_btb_miss_count);
    end
    if (dbg_btb_hit_count !== 32'd6) begin
      $fatal(1, "btb_hit_count mismatch: expected 6, got %0d",
             dbg_btb_hit_count);
    end
    if (dbg_flush_cycle !== 32'd2) begin
      $fatal(1, "flush_cycle mismatch: expected 2, got %0d", dbg_flush_cycle);
    end

    $display("[PASS] rv32i_pipe_dynamic_branch_predict_tb");
    $display("  pc=0x%08x cycle=%0d instret=%0d stall_cycle=%0d flush_cycle=%0d",
             dbg_pc, dbg_cycle, dbg_instret, dbg_stall_cycle, dbg_flush_cycle);
    $display("  branch_count=%0d branch_mispredict_count=%0d",
             dbg_branch_count, dbg_branch_mispredict_count);
    $display("  btb_hit=%0d btb_miss=%0d bht_update=%0d",
             dbg_btb_hit_count, dbg_btb_miss_count, dbg_bht_update_count);
    $display("  dynamic BHT+BTB learned repeated taken branches");
    $finish;
  end

endmodule
