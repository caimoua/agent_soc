`timescale 1ns/1ps

module rv32i_icache_tb;

  localparam CLK_PERIOD_NS = 10;

  logic        clk;
  logic        rst_n;

  logic        cpu_valid;
  logic [31:0] cpu_addr;
  wire         cpu_ready;
  wire [31:0] cpu_rdata;
  wire         cpu_error;

  wire         mem_valid;
  wire [31:0] mem_addr;
  wire         mem_ready;
  wire [31:0] mem_rdata;
  wire         mem_error;

  wire         dbg_hit;
  wire         dbg_miss;
  wire [31:0] dbg_hit_count;
  wire [31:0] dbg_miss_count;

  logic [31:0] imem [0:255];
  logic [1:0]  mem_wait_q;

  integer i;

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD_NS/2) clk = ~clk;
  end

  initial begin
    for (i = 0; i < 256; i = i + 1) begin
      imem[i] = 32'h1000_0000 + i;
    end
  end

  assign mem_ready = mem_valid && (mem_wait_q == 2'd0);
  assign mem_rdata = imem[mem_addr[9:2]];
  assign mem_error = 1'b0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem_wait_q <= 2'd2;
    end else if (!mem_valid) begin
      mem_wait_q <= 2'd2;
    end else if (mem_wait_q != 2'd0) begin
      mem_wait_q <= mem_wait_q - 2'd1;
    end
  end

  task automatic fetch_expect(
    input [31:0] addr,
    input [31:0] expected,
    input string name
  );
    integer wait_cycles;
    begin
      @(negedge clk);
      cpu_valid = 1'b1;
      cpu_addr  = addr;
      wait_cycles = 0;

      #1ps;
      while (!cpu_ready) begin
        @(posedge clk);
        #1ps;
        wait_cycles = wait_cycles + 1;
        if (wait_cycles > 32) begin
          $fatal(1, "%s timeout waiting for cache ready", name);
        end
      end

      if (cpu_rdata !== expected) begin
        $fatal(1, "%s data mismatch: expected 0x%08x, got 0x%08x",
               name, expected, cpu_rdata);
      end
      if (cpu_error) begin
        $fatal(1, "%s unexpected I-cache CPU error", name);
      end

      @(posedge clk);
      #1ps;
      cpu_valid = 1'b0;
      cpu_addr  = 32'd0;
    end
  endtask

  rv32i_icache #(
    .INDEX_BITS(2)
  ) u_icache (
    .clk            (clk),
    .rst_n          (rst_n),
    .cpu_valid      (cpu_valid),
    .cpu_addr       (cpu_addr),
    .cpu_ready      (cpu_ready),
    .cpu_rdata      (cpu_rdata),
    .cpu_error      (cpu_error),
    .mem_valid      (mem_valid),
    .mem_addr       (mem_addr),
    .mem_ready      (mem_ready),
    .mem_rdata      (mem_rdata),
    .mem_error      (mem_error),
    .dbg_hit        (dbg_hit),
    .dbg_miss       (dbg_miss),
    .dbg_hit_count  (dbg_hit_count),
    .dbg_miss_count (dbg_miss_count)
  );

  initial begin
    cpu_valid = 1'b0;
    cpu_addr  = 32'd0;
    rst_n     = 1'b0;

    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    fetch_expect(32'h0000_0000, 32'h1000_0000, "miss fill line 0x00");
    fetch_expect(32'h0000_0004, 32'h1000_0001, "hit line 0x00 word1");
    fetch_expect(32'h0000_000c, 32'h1000_0003, "hit line 0x00 word3");

    fetch_expect(32'h0000_0040, 32'h1000_0010, "same set fill way1 line 0x40");
    fetch_expect(32'h0000_0000, 32'h1000_0000, "way0 remains resident");

    fetch_expect(32'h0000_0080, 32'h1000_0020, "third tag replaces one way");
    fetch_expect(32'h0000_0000, 32'h1000_0000, "recent way remains resident");
    fetch_expect(32'h0000_0040, 32'h1000_0010, "evicted way refilled");

    if (dbg_hit_count !== 32'd8) begin
      $fatal(1, "hit_count mismatch: expected 8, got %0d", dbg_hit_count);
    end
    if (dbg_miss_count !== 32'd4) begin
      $fatal(1, "miss_count mismatch: expected 4, got %0d", dbg_miss_count);
    end

    $display("[PASS] rv32i_icache_tb");
    $display("  hit_count=%0d miss_count=%0d", dbg_hit_count, dbg_miss_count);
    $display("  2-way 4-word-line I-cache hit, miss, refill and replacement passed");
    $finish;
  end

endmodule
