`timescale 1ns/1ps

module rv32i_pipe_dcache_tb;

  localparam CLK_PERIOD_NS = 10;

  logic clk;
  logic rst_n;

  wire        imem_valid;
  wire [31:0] imem_addr;
  wire        imem_ready;
  wire [31:0] imem_rdata;

  wire        core_dmem_valid;
  wire        core_dmem_write;
  wire [31:0] core_dmem_addr;
  wire [31:0] core_dmem_wdata;
  wire [3:0]  core_dmem_wstrb;
  wire        core_dmem_ready;
  wire [31:0] core_dmem_rdata;
  wire        core_dmem_error;

  wire        dc_mem_valid;
  wire        dc_mem_write;
  wire [31:0] dc_mem_addr;
  wire [31:0] dc_mem_wdata;
  wire [3:0]  dc_mem_wstrb;
  wire        dc_mem_ready;
  wire [31:0] dc_mem_rdata;
  wire        dc_mem_error;

  wire [31:0] dbg_pc;
  wire [31:0] dbg_cycle;
  wire [31:0] dbg_instret;
  wire [31:0] dbg_stall_cycle;
  wire [31:0] dbg_flush_cycle;
  logic [4:0] dbg_reg_addr;
  wire [31:0] dbg_reg_rdata;
  wire        dbg_illegal_instr;
  wire        dbg_ecall;
  wire        dbg_ebreak;

  wire        dc_dbg_hit;
  wire        dc_dbg_miss;
  wire [31:0] dc_dbg_hit_count;
  wire [31:0] dc_dbg_miss_count;

  logic [31:0] imem [0:255];
  logic [31:0] dmem [0:255];
  logic [1:0]  mem_wait_q;
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
      dmem[i] = 32'h3000_0000 + i;
    end

    dmem[1] = 32'd7;

    if (!$value$plusargs("IMEM_MEMH=%s", imem_memh)) begin
      imem_memh = "../software/bin/pipe_dcache.memh";
    end

    memh_fd = $fopen(imem_memh, "r");
    if (memh_fd == 0) begin
      $fatal(1, "failed to open IMEM_MEMH='%s'", imem_memh);
    end
    $fclose(memh_fd);
    $readmemh(imem_memh, imem);
  end

  assign imem_ready = 1'b1;
  assign imem_rdata = imem[imem_addr[9:2]];

  assign dc_mem_ready = dc_mem_valid && (mem_wait_q == 2'd0);
  assign dc_mem_rdata = dmem[dc_mem_addr[9:2]];
  assign dc_mem_error = 1'b0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem_wait_q <= 2'd1;
    end else if (!dc_mem_valid) begin
      mem_wait_q <= 2'd1;
    end else if (mem_wait_q != 2'd0) begin
      mem_wait_q <= mem_wait_q - 2'd1;
    end
  end

  always @(posedge clk) begin
    if (dc_mem_valid && dc_mem_ready && dc_mem_write) begin
      if (dc_mem_wstrb[0]) dmem[dc_mem_addr[9:2]][7:0]   <= dc_mem_wdata[7:0];
      if (dc_mem_wstrb[1]) dmem[dc_mem_addr[9:2]][15:8]  <= dc_mem_wdata[15:8];
      if (dc_mem_wstrb[2]) dmem[dc_mem_addr[9:2]][23:16] <= dc_mem_wdata[23:16];
      if (dc_mem_wstrb[3]) dmem[dc_mem_addr[9:2]][31:24] <= dc_mem_wdata[31:24];
    end
  end

  rv32i_dcache #(
    .INDEX_BITS(2)
  ) u_dcache (
    .clk            (clk),
    .rst_n          (rst_n),
    .cpu_valid      (core_dmem_valid),
    .cpu_write      (core_dmem_write),
    .cpu_addr       (core_dmem_addr),
    .cpu_wdata      (core_dmem_wdata),
    .cpu_wstrb      (core_dmem_wstrb),
    .cpu_ready      (core_dmem_ready),
    .cpu_rdata      (core_dmem_rdata),
    .cpu_error      (core_dmem_error),
    .mem_valid      (dc_mem_valid),
    .mem_write      (dc_mem_write),
    .mem_addr       (dc_mem_addr),
    .mem_wdata      (dc_mem_wdata),
    .mem_wstrb      (dc_mem_wstrb),
    .mem_ready      (dc_mem_ready),
    .mem_rdata      (dc_mem_rdata),
    .mem_error      (dc_mem_error),
    .dbg_hit        (dc_dbg_hit),
    .dbg_miss       (dc_dbg_miss),
    .dbg_hit_count  (dc_dbg_hit_count),
    .dbg_miss_count (dc_dbg_miss_count)
  );

  rv32i_pipe_core u_core (
    .clk        (clk),
    .rst_n      (rst_n),
    .timer_irq  (1'b0),
    .imem_valid (imem_valid),
    .imem_addr  (imem_addr),
    .imem_ready (imem_ready),
    .imem_rdata (imem_rdata),
    .imem_error (1'b0),
    .dmem_valid (core_dmem_valid),
    .dmem_write (core_dmem_write),
    .dmem_addr  (core_dmem_addr),
    .dmem_wdata (core_dmem_wdata),
    .dmem_wstrb (core_dmem_wstrb),
    .dmem_ready (core_dmem_ready),
    .dmem_rdata (core_dmem_rdata),
    .dmem_error (core_dmem_error),
    .dbg_pc     (dbg_pc),
    .dbg_cycle  (dbg_cycle),
    .dbg_instret(dbg_instret),
    .dbg_stall_cycle(dbg_stall_cycle),
    .dbg_flush_cycle(dbg_flush_cycle),
    .dbg_reg_addr (dbg_reg_addr),
    .dbg_reg_rdata(dbg_reg_rdata),
    .dbg_illegal_instr(dbg_illegal_instr),
    .dbg_ecall  (dbg_ecall),
    .dbg_ebreak (dbg_ebreak)
  );

  initial begin
    dbg_reg_addr = 5'd0;
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    timeout = 0;
    while (!dbg_ebreak && (timeout < 220)) begin
      @(posedge clk);
      #1ps;
      timeout = timeout + 1;
    end

    if (!dbg_ebreak) begin
      $fatal(1, "timeout waiting for pipeline ebreak");
    end

    if (dbg_illegal_instr) begin
      $fatal(1, "unexpected illegal instruction in pipe dcache test");
    end

    if (dbg_ecall) begin
      $fatal(1, "unexpected ECALL event in pipe dcache test");
    end

    check_reg(5'd1, 32'd4,   "x1");
    check_reg(5'd2, 32'd7,   "x2");
    check_reg(5'd3, 32'd14,  "x3");
    check_reg(5'd4, 32'd170, "x4");
    check_reg(5'd5, 32'd170, "x5");
    check_reg(5'd6, 32'd177, "x6");
    check_reg(5'd7, 32'd128, "x7");
    check_reg(5'd8, 32'd170, "x8");

    if (dmem[2] !== 32'd170) begin
      $fatal(1, "dmem[2] mismatch: expected 170, got 0x%08x", dmem[2]);
    end
    if (dmem[32] !== 32'd170) begin
      $fatal(1, "dmem[32] mismatch: expected 170, got 0x%08x", dmem[32]);
    end
    if (dbg_instret !== 32'd11) begin
      $fatal(1, "instret mismatch: expected 11, got %0d", dbg_instret);
    end
    if (dbg_stall_cycle == 32'd0) begin
      $fatal(1, "expected data memory stalls from D-cache");
    end
    if (dc_dbg_hit_count == 32'd0) begin
      $fatal(1, "expected D-cache hits");
    end
    if (dc_dbg_miss_count < 32'd3) begin
      $fatal(1, "expected at least 3 D-cache misses, got %0d", dc_dbg_miss_count);
    end

    $display("[PASS] rv32i_pipe_dcache_tb");
    $display("  pc=0x%08x cycle=%0d instret=%0d stall_cycle=%0d",
             dbg_pc, dbg_cycle, dbg_instret, dbg_stall_cycle);
    $display("  dcache_hit_count=%0d dcache_miss_count=%0d",
             dc_dbg_hit_count, dc_dbg_miss_count);
    $display("  rv32i_pipe_core load/store through write-through no-write-allocate rv32i_dcache passed");
    $finish;
  end

endmodule
