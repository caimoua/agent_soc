`timescale 1ns/1ps

module rv32i_pipe_icache_tb;

  localparam CLK_PERIOD_NS = 10;

  logic clk;
  logic rst_n;

  wire        core_imem_valid;
  wire [31:0] core_imem_addr;
  wire        core_imem_ready;
  wire [31:0] core_imem_rdata;
  wire        core_imem_error;

  wire        ic_mem_valid;
  wire [31:0] ic_mem_addr;
  wire        ic_mem_ready;
  wire [31:0] ic_mem_rdata;
  wire        ic_mem_error;

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
  logic [4:0] dbg_reg_addr;
  wire [31:0] dbg_reg_rdata;
  wire        dbg_illegal_instr;
  wire        dbg_ecall;
  wire        dbg_ebreak;

  wire        ic_dbg_hit;
  wire        ic_dbg_miss;
  wire [31:0] ic_dbg_hit_count;
  wire [31:0] ic_dbg_miss_count;

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
      imem_memh = "../software/bin/pipe_icache.memh";
    end

    memh_fd = $fopen(imem_memh, "r");
    if (memh_fd == 0) begin
      $fatal(1, "failed to open IMEM_MEMH='%s'", imem_memh);
    end
    $fclose(memh_fd);
    $readmemh(imem_memh, imem);
  end

  assign ic_mem_ready = ic_mem_valid;
  assign ic_mem_rdata = imem[ic_mem_addr[9:2]];
  assign ic_mem_error = 1'b0;

  assign dmem_ready = 1'b1;
  assign dmem_rdata = 32'd0;

  rv32i_icache #(
    .INDEX_BITS(3)
  ) u_icache (
    .clk            (clk),
    .rst_n          (rst_n),
    .cpu_valid      (core_imem_valid),
    .cpu_addr       (core_imem_addr),
    .cpu_ready      (core_imem_ready),
    .cpu_rdata      (core_imem_rdata),
    .cpu_error      (core_imem_error),
    .mem_valid      (ic_mem_valid),
    .mem_addr       (ic_mem_addr),
    .mem_ready      (ic_mem_ready),
    .mem_rdata      (ic_mem_rdata),
    .mem_error      (ic_mem_error),
    .dbg_hit        (ic_dbg_hit),
    .dbg_miss       (ic_dbg_miss),
    .dbg_hit_count  (ic_dbg_hit_count),
    .dbg_miss_count (ic_dbg_miss_count)
  );

  rv32i_pipe_core u_core (
    .clk        (clk),
    .rst_n      (rst_n),
    .timer_irq  (1'b0),
    .imem_valid (core_imem_valid),
    .imem_addr  (core_imem_addr),
    .imem_ready (core_imem_ready),
    .imem_rdata (core_imem_rdata),
    .imem_error (core_imem_error),
    .dmem_valid (dmem_valid),
    .dmem_write (dmem_write),
    .dmem_addr  (dmem_addr),
    .dmem_wdata (dmem_wdata),
    .dmem_wstrb (dmem_wstrb),
    .dmem_ready (dmem_ready),
    .dmem_rdata (dmem_rdata),
    .dmem_error (1'b0),
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
    while (!dbg_ebreak && (timeout < 160)) begin
      @(posedge clk);
      #1ps;
      timeout = timeout + 1;
    end

    if (!dbg_ebreak) begin
      $fatal(1, "timeout waiting for pipeline ebreak");
    end

    if (dbg_illegal_instr) begin
      $fatal(1, "unexpected illegal instruction in pipe icache test");
    end

    if (dbg_ecall) begin
      $fatal(1, "unexpected ECALL event in pipe icache test");
    end

    check_reg(5'd1, 32'd5,  "x1");
    check_reg(5'd2, 32'd7,  "x2");
    check_reg(5'd3, 32'd12, "x3");
    check_reg(5'd4, 32'd19, "x4");

    if (dbg_instret !== 32'd5) begin
      $fatal(1, "instret mismatch: expected 5, got %0d", dbg_instret);
    end

    if (dbg_stall_cycle == 32'd0) begin
      $fatal(1, "expected instruction fetch stalls from I-cache misses");
    end

    if (ic_dbg_miss_count < 32'd2) begin
      $fatal(1, "expected at least 2 I-cache line misses, got %0d", ic_dbg_miss_count);
    end

    if (ic_dbg_hit_count == 32'd0) begin
      $fatal(1, "expected I-cache hits after refill");
    end

    $display("[PASS] rv32i_pipe_icache_tb");
    $display("  pc=0x%08x cycle=%0d instret=%0d stall_cycle=%0d",
             dbg_pc, dbg_cycle, dbg_instret, dbg_stall_cycle);
    $display("  icache_hit_count=%0d icache_miss_count=%0d",
             ic_dbg_hit_count, ic_dbg_miss_count);
    $display("  rv32i_pipe_core fetch through 2-way 4-word-line rv32i_icache passed");
    $finish;
  end

endmodule
