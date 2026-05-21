`timescale 1ns/1ps

module rv32i_timer_tb;

  localparam CLK_PERIOD_NS = 10;

  logic clk;
  logic rst_n;
  logic        valid;
  logic        write;
  logic [31:0] addr;
  logic [31:0] wdata;
  logic [3:0]  wstrb;
  wire         ready;
  wire [31:0] rdata;
  wire         timer_irq;
  wire [31:0] dbg_mtime_lo;
  wire [31:0] dbg_mtime_hi;
  wire [31:0] dbg_mtimecmp_lo;
  wire [31:0] dbg_mtimecmp_hi;
  wire [31:0] dbg_ctrl;

  reg [31:0] read_value;

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD_NS/2) clk = ~clk;
  end

  task automatic write_reg(
    input [31:0] wr_addr,
    input [31:0] wr_data,
    input [3:0]  wr_strb
  );
    begin
      @(negedge clk);
      valid = 1'b1;
      write = 1'b1;
      addr  = wr_addr;
      wdata = wr_data;
      wstrb = wr_strb;
      @(posedge clk);
      #1ps;
      if (!ready) begin
        $fatal(1, "timer write did not complete");
      end
      valid = 1'b0;
      write = 1'b0;
      addr  = 32'd0;
      wdata = 32'd0;
      wstrb = 4'b0000;
    end
  endtask

  task automatic read_reg(
    input  [31:0] rd_addr,
    output [31:0] rd_data
  );
    begin
      @(negedge clk);
      valid = 1'b1;
      write = 1'b0;
      addr  = rd_addr;
      wdata = 32'd0;
      wstrb = 4'b0000;
      #1ps;
      rd_data = rdata;
      @(posedge clk);
      #1ps;
      if (!ready) begin
        $fatal(1, "timer read did not complete");
      end
      valid = 1'b0;
      addr  = 32'd0;
    end
  endtask

  rv32i_timer u_timer (
    .clk              (clk),
    .rst_n            (rst_n),
    .valid            (valid),
    .write            (write),
    .addr             (addr),
    .wdata            (wdata),
    .wstrb            (wstrb),
    .ready            (ready),
    .rdata            (rdata),
    .timer_irq        (timer_irq),
    .dbg_mtime_lo     (dbg_mtime_lo),
    .dbg_mtime_hi     (dbg_mtime_hi),
    .dbg_mtimecmp_lo  (dbg_mtimecmp_lo),
    .dbg_mtimecmp_hi  (dbg_mtimecmp_hi),
    .dbg_ctrl         (dbg_ctrl)
  );

  initial begin
    valid = 1'b0;
    write = 1'b0;
    addr  = 32'd0;
    wdata = 32'd0;
    wstrb = 4'b0000;
    rst_n = 1'b0;

    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    read_reg(32'h0000_0010, read_value);
    if (read_value !== 32'd0) begin
      $fatal(1, "ctrl reset mismatch: expected 0, got 0x%08x", read_value);
    end

    write_reg(32'h0000_0008, 32'd5, 4'b1111);
    write_reg(32'h0000_000c, 32'd0, 4'b1111);
    read_reg(32'h0000_0008, read_value);
    if (read_value !== 32'd5) begin
      $fatal(1, "mtimecmp_lo mismatch: expected 5, got 0x%08x", read_value);
    end

    write_reg(32'h0000_0010, 32'd3, 4'b1111);
    repeat (8) @(posedge clk);

    if (!timer_irq) begin
      $fatal(1, "timer_irq was not asserted after mtime reached mtimecmp");
    end
    if (dbg_mtime_lo < 32'd5) begin
      $fatal(1, "mtime did not advance enough: got %0d", dbg_mtime_lo);
    end

    read_reg(32'h0000_0010, read_value);
    if (read_value !== 32'h8000_0003) begin
      $fatal(1, "ctrl irq status mismatch: expected 0x80000003, got 0x%08x", read_value);
    end

    write_reg(32'h0000_0010, 32'd4, 4'b1111);
    read_reg(32'h0000_0000, read_value);
    if (read_value !== 32'd0) begin
      $fatal(1, "mtime clear mismatch: expected 0, got 0x%08x", read_value);
    end

    write_reg(32'h0000_0000, 32'h1122_3344, 4'b1111);
    write_reg(32'h0000_0000, 32'hAABB_CCDD, 4'b0011);
    read_reg(32'h0000_0000, read_value);
    if (read_value !== 32'h1122_CCDD) begin
      $fatal(1, "mtime byte strobe mismatch: expected 0x1122CCDD, got 0x%08x", read_value);
    end

    $display("[PASS] rv32i_timer_tb");
    $display("  mtime=0x%08x_%08x mtimecmp=0x%08x_%08x ctrl=0x%08x",
             dbg_mtime_hi, dbg_mtime_lo, dbg_mtimecmp_hi, dbg_mtimecmp_lo, dbg_ctrl);
    $finish;
  end

endmodule
