`timescale 1ns/1ps

module rv32i_dcache_tb;

  localparam CLK_PERIOD_NS = 10;

  logic        clk;
  logic        rst_n;

  logic        cpu_valid;
  logic        cpu_write;
  logic [31:0] cpu_addr;
  logic [31:0] cpu_wdata;
  logic [3:0]  cpu_wstrb;
  wire         cpu_ready;
  wire [31:0] cpu_rdata;
  wire         cpu_error;

  wire         mem_valid;
  wire         mem_write;
  wire [31:0] mem_addr;
  wire [31:0] mem_wdata;
  wire [3:0]  mem_wstrb;
  wire         mem_ready;
  wire [31:0] mem_rdata;
  wire         mem_error;

  wire         dbg_hit;
  wire         dbg_miss;
  wire [31:0] dbg_hit_count;
  wire [31:0] dbg_miss_count;

  logic [31:0] dmem [0:255];
  logic [1:0]  mem_wait_q;

  integer i;

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD_NS/2) clk = ~clk;
  end

  initial begin
    for (i = 0; i < 256; i = i + 1) begin
      dmem[i] = 32'h2000_0000 + i;
    end
  end

  assign mem_ready = mem_valid && (mem_wait_q == 2'd0);
  assign mem_rdata = dmem[mem_addr[9:2]];
  assign mem_error = 1'b0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem_wait_q <= 2'd1;
    end else if (!mem_valid) begin
      mem_wait_q <= 2'd1;
    end else if (mem_wait_q != 2'd0) begin
      mem_wait_q <= mem_wait_q - 2'd1;
    end
  end

  always @(posedge clk) begin
    if (mem_valid && mem_ready && mem_write) begin
      if (mem_wstrb[0]) dmem[mem_addr[9:2]][7:0]   <= mem_wdata[7:0];
      if (mem_wstrb[1]) dmem[mem_addr[9:2]][15:8]  <= mem_wdata[15:8];
      if (mem_wstrb[2]) dmem[mem_addr[9:2]][23:16] <= mem_wdata[23:16];
      if (mem_wstrb[3]) dmem[mem_addr[9:2]][31:24] <= mem_wdata[31:24];
    end
  end

  task automatic load_expect(
    input [31:0] addr,
    input [31:0] expected,
    input string name
  );
    integer wait_cycles;
    begin
      @(negedge clk);
      cpu_valid = 1'b1;
      cpu_write = 1'b0;
      cpu_addr  = addr;
      cpu_wdata = 32'd0;
      cpu_wstrb = 4'b0000;
      wait_cycles = 0;

      #1ps;
      while (!cpu_ready) begin
        @(posedge clk);
        #1ps;
        wait_cycles = wait_cycles + 1;
        if (wait_cycles > 64) begin
          $fatal(1, "%s timeout waiting for dcache load ready", name);
        end
      end

      if (cpu_rdata !== expected) begin
        $fatal(1, "%s data mismatch: expected 0x%08x, got 0x%08x",
               name, expected, cpu_rdata);
      end

      @(posedge clk);
      #1ps;
      cpu_valid = 1'b0;
      cpu_addr  = 32'd0;
    end
  endtask

  task automatic store_word(
    input [31:0] addr,
    input [31:0] data,
    input [3:0]  wstrb,
    input string name
  );
    integer wait_cycles;
    begin
      @(negedge clk);
      cpu_valid = 1'b1;
      cpu_write = 1'b1;
      cpu_addr  = addr;
      cpu_wdata = data;
      cpu_wstrb = wstrb;
      wait_cycles = 0;

      #1ps;
      while (!cpu_ready) begin
        @(posedge clk);
        #1ps;
        wait_cycles = wait_cycles + 1;
        if (wait_cycles > 64) begin
          $fatal(1, "%s timeout waiting for dcache store ready", name);
        end
      end

      @(posedge clk);
      #1ps;
      cpu_valid = 1'b0;
      cpu_write = 1'b0;
      cpu_addr  = 32'd0;
      cpu_wdata = 32'd0;
      cpu_wstrb = 4'b0000;
    end
  endtask

  rv32i_dcache #(
    .INDEX_BITS(2)
  ) u_dcache (
    .clk            (clk),
    .rst_n          (rst_n),
    .cpu_valid      (cpu_valid),
    .cpu_write      (cpu_write),
    .cpu_addr       (cpu_addr),
    .cpu_wdata      (cpu_wdata),
    .cpu_wstrb      (cpu_wstrb),
    .cpu_ready      (cpu_ready),
    .cpu_rdata      (cpu_rdata),
    .cpu_error      (cpu_error),
    .mem_valid      (mem_valid),
    .mem_write      (mem_write),
    .mem_addr       (mem_addr),
    .mem_wdata      (mem_wdata),
    .mem_wstrb      (mem_wstrb),
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
    cpu_write = 1'b0;
    cpu_addr  = 32'd0;
    cpu_wdata = 32'd0;
    cpu_wstrb = 4'b0000;
    rst_n     = 1'b0;

    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    load_expect(32'h0000_0000, 32'h2000_0000, "load miss fill line 0x00");
    load_expect(32'h0000_0004, 32'h2000_0001, "load hit line 0x00 word1");

    store_word(32'h0000_0004, 32'hABCD_1234, 4'b1111, "store hit word 0x04");
    load_expect(32'h0000_0004, 32'hABCD_1234, "load hit after store hit");

    store_word(32'h0000_0080, 32'h5566_7788, 4'b1111, "store miss no-allocate 0x80");
    load_expect(32'h0000_0080, 32'h5566_7788, "load miss after no-allocate store");
    load_expect(32'h0000_0084, 32'h2000_0021, "load hit after line fill 0x80");

    if (dmem[1] !== 32'hABCD_1234) begin
      $fatal(1, "dmem[1] mismatch after store hit: expected 0xABCD1234, got 0x%08x", dmem[1]);
    end
    if (dmem[32] !== 32'h5566_7788) begin
      $fatal(1, "dmem[32] mismatch after store miss: expected 0x55667788, got 0x%08x", dmem[32]);
    end
    if (dbg_hit_count == 32'd0) begin
      $fatal(1, "expected dcache hits");
    end
    if (dbg_miss_count < 32'd3) begin
      $fatal(1, "expected at least 3 dcache misses, got %0d", dbg_miss_count);
    end

    $display("[PASS] rv32i_dcache_tb");
    $display("  hit_count=%0d miss_count=%0d", dbg_hit_count, dbg_miss_count);
    $display("  2-way 4-word-line D-cache load refill, store hit write-through and store miss no-allocate passed");
    $finish;
  end

endmodule
