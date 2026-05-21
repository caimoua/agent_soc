`timescale 1ns/1ps

module rv32i_agent_workload_tb;

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

  logic [31:0] imem [0:2047];
  logic [31:0] dmem [0:511];
  logic        illegal_seen;
  logic        ecall_seen;
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

  task automatic check_dmem(
    input integer word_index,
    input [31:0] expected,
    input string label
  );
    begin
      if (dmem[word_index] !== expected) begin
        $fatal(1, "%s mismatch at dmem[%0d]: expected 0x%08x, got 0x%08x",
               label, word_index, expected, dmem[word_index]);
      end
    end
  endtask

  initial begin
    for (i = 0; i < 2048; i = i + 1) begin
      imem[i] = 32'h0000_0013; // addi x0, x0, 0
    end
    for (i = 0; i < 512; i = i + 1) begin
      dmem[i] = 32'd0;
    end

    if (!$value$plusargs("IMEM_MEMH=%s", imem_memh)) begin
      imem_memh = "../software/bin/agent_workload.memh";
    end

    memh_fd = $fopen(imem_memh, "r");
    if (memh_fd == 0) begin
      $fatal(1, "failed to open IMEM_MEMH='%s'", imem_memh);
    end
    $fclose(memh_fd);
    $readmemh(imem_memh, imem);
  end

  assign imem_ready = imem_valid;
  assign imem_rdata = imem[imem_addr[12:2]];
  assign dmem_ready = dmem_valid;
  assign dmem_rdata = dmem[dmem_addr[10:2]];

  always @(posedge clk) begin
    if (dmem_valid && dmem_ready && dmem_write) begin
      if (dmem_wstrb[0]) dmem[dmem_addr[10:2]][7:0]   <= dmem_wdata[7:0];
      if (dmem_wstrb[1]) dmem[dmem_addr[10:2]][15:8]  <= dmem_wdata[15:8];
      if (dmem_wstrb[2]) dmem[dmem_addr[10:2]][23:16] <= dmem_wdata[23:16];
      if (dmem_wstrb[3]) dmem[dmem_addr[10:2]][31:24] <= dmem_wdata[31:24];
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      illegal_seen <= 1'b0;
      ecall_seen   <= 1'b0;
    end else begin
      if (dbg_illegal_instr) begin
        illegal_seen <= 1'b1;
      end
      if (dbg_ecall) begin
        ecall_seen <= 1'b1;
      end
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
    while (!dbg_ebreak && (timeout < 5000)) begin
      @(posedge clk);
      #1ps;
      timeout = timeout + 1;
    end

    if (!dbg_ebreak) begin
      $fatal(1, "timeout waiting for agent workload ebreak");
    end
    if (illegal_seen) begin
      $fatal(1, "unexpected illegal instruction in agent workload test");
    end
    if (ecall_seen) begin
      $fatal(1, "unexpected ECALL event in agent workload test");
    end

    check_reg(5'd30, 32'd0,          "x30 failure code");
    check_reg(5'd31, 32'd1,          "x31 pass marker");
    check_reg(5'd29, 32'ha600_0001,  "x29 agent workload signature");

    check_dmem(0, 32'd1120,       "event/tool dispatch score");
    check_dmem(1, 32'd1,          "token match count");
    check_dmem(2, 32'd2,          "token first match index");
    check_dmem(3, 32'd4,          "int8 dot product");
    check_dmem(4, 32'hffff_fffd,  "matvec row0");
    check_dmem(5, 32'd20,         "matvec row1");
    check_dmem(6, 32'd17,         "matvec checksum");

    if (dbg_branch_count < 32'd8) begin
      $fatal(1, "expected branch-heavy agent workload, got branch_count=%0d",
             dbg_branch_count);
    end
    if (dbg_stall_cycle < 32'd4) begin
      $fatal(1, "expected RV32M/int8 workload stalls, got stall_cycle=%0d",
             dbg_stall_cycle);
    end

    $display("[PASS] rv32i_agent_workload_tb");
    $display("  pc=0x%08x cycle=%0d instret=%0d stall_cycle=%0d flush_cycle=%0d",
             dbg_pc, dbg_cycle, dbg_instret, dbg_stall_cycle, dbg_flush_cycle);
    $display("  branch_count=%0d branch_mispredict_count=%0d btb_hit=%0d btb_miss=%0d bht_update=%0d",
             dbg_branch_count, dbg_branch_mispredict_count,
             dbg_btb_hit_count, dbg_btb_miss_count, dbg_bht_update_count);
    $display("  agent event loop, token scan, int8 dot, and tiny matvec baseline passed");
    $finish;
  end

endmodule
