`timescale 1ns/1ps

module rv32i_uart_tb;

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
  wire         tx_valid;
  wire [7:0]  tx_data;
  wire [31:0] dbg_tx_count;
  wire [7:0]  dbg_last_tx;

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
        $fatal(1, "uart write did not complete");
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
        $fatal(1, "uart read did not complete");
      end
      valid = 1'b0;
      addr  = 32'd0;
    end
  endtask

  rv32i_uart u_uart (
    .clk          (clk),
    .rst_n        (rst_n),
    .valid        (valid),
    .write        (write),
    .addr         (addr),
    .wdata        (wdata),
    .wstrb        (wstrb),
    .ready        (ready),
    .rdata        (rdata),
    .tx_valid     (tx_valid),
    .tx_data      (tx_data),
    .dbg_tx_count (dbg_tx_count),
    .dbg_last_tx  (dbg_last_tx)
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

    read_reg(32'h0000_0004, read_value);
    if (read_value !== 32'h0000_0001) begin
      $fatal(1, "uart status reset mismatch: expected 1, got 0x%08x", read_value);
    end

    write_reg(32'h0000_0000, 32'h0000_0041, 4'b0001);
    if (!tx_valid || (tx_data !== 8'h41)) begin
      $fatal(1, "uart tx A mismatch: valid=%0d data=0x%02x", tx_valid, tx_data);
    end
    if ((dbg_tx_count !== 32'd1) || (dbg_last_tx !== 8'h41)) begin
      $fatal(1, "uart debug after A mismatch: count=%0d last=0x%02x",
             dbg_tx_count, dbg_last_tx);
    end

    write_reg(32'h0000_0000, 32'h0000_0042, 4'b0000);
    if (tx_valid) begin
      $fatal(1, "uart should ignore TXDATA write without byte0 strobe");
    end
    if (dbg_tx_count !== 32'd1) begin
      $fatal(1, "uart count changed after masked write: %0d", dbg_tx_count);
    end

    write_reg(32'h0000_0000, 32'h0000_005a, 4'b1111);
    if (!tx_valid || (tx_data !== 8'h5a)) begin
      $fatal(1, "uart tx Z mismatch: valid=%0d data=0x%02x", tx_valid, tx_data);
    end

    read_reg(32'h0000_0000, read_value);
    if (read_value !== 32'h0000_005a) begin
      $fatal(1, "uart txdata readback mismatch: expected 0x5a, got 0x%08x", read_value);
    end
    if (dbg_tx_count !== 32'd2) begin
      $fatal(1, "uart final tx_count mismatch: expected 2, got %0d", dbg_tx_count);
    end

    $display("[PASS] rv32i_uart_tb");
    $display("  tx_count=%0d last_tx=0x%02x status=0x%08x",
             dbg_tx_count, dbg_last_tx, 32'h0000_0001);
    $finish;
  end

endmodule
