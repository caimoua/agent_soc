`timescale 1ns/1ps

module rv32i_mem_bus_tb;

  localparam CLK_PERIOD_NS = 10;

  logic clk;
  logic rst_n;

  logic        i_valid;
  logic [31:0] i_addr;
  wire         i_ready;
  wire [31:0]  i_rdata;
  wire         i_error;

  logic        d_valid;
  logic        d_write;
  logic [31:0] d_addr;
  logic [31:0] d_wdata;
  logic [3:0]  d_wstrb;
  wire         d_ready;
  wire [31:0]  d_rdata;
  wire         d_error;

  wire        rom_valid;
  wire        rom_write;
  wire [31:0] rom_addr;
  wire [31:0] rom_wdata;
  wire [3:0]  rom_wstrb;
  wire        rom_ready;
  wire [31:0] rom_rdata;

  wire        sram_valid;
  wire        sram_write;
  wire [31:0] sram_addr;
  wire [31:0] sram_wdata;
  wire [3:0]  sram_wstrb;
  wire        sram_ready;
  wire [31:0] sram_rdata;

  wire        mmio_valid;
  wire        mmio_write;
  wire [31:0] mmio_addr;
  wire [31:0] mmio_wdata;
  wire [3:0]  mmio_wstrb;
  wire        mmio_ready;
  wire [31:0] mmio_rdata;

  wire        dbg_active;
  wire        dbg_grant_is_d;
  wire [1:0]  dbg_target;
  wire        dbg_decode_error;
  wire [31:0] dbg_i_grant_count;
  wire [31:0] dbg_d_grant_count;

  logic [31:0] rom [0:255];
  logic [31:0] sram [0:255];
  logic [31:0] mmio_reg;
  integer i;
  integer timeout;

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD_NS/2) clk = ~clk;
  end

  initial begin
    for (i = 0; i < 256; i = i + 1) begin
      rom[i]  = 32'h1000_0000 + i;
      sram[i] = 32'h2000_0000 + i;
    end
    mmio_reg = 32'h4000_0000;
  end

  assign rom_ready = rom_valid;
  assign rom_rdata = rom[rom_addr[9:2]];

  assign sram_ready = sram_valid;
  assign sram_rdata = sram[sram_addr[9:2]];

  assign mmio_ready = mmio_valid;
  assign mmio_rdata = mmio_reg;

  always @(posedge clk) begin
    if (sram_valid && sram_ready && sram_write) begin
      if (sram_wstrb[0]) sram[sram_addr[9:2]][7:0]   <= sram_wdata[7:0];
      if (sram_wstrb[1]) sram[sram_addr[9:2]][15:8]  <= sram_wdata[15:8];
      if (sram_wstrb[2]) sram[sram_addr[9:2]][23:16] <= sram_wdata[23:16];
      if (sram_wstrb[3]) sram[sram_addr[9:2]][31:24] <= sram_wdata[31:24];
    end

    if (mmio_valid && mmio_ready && mmio_write) begin
      if (mmio_wstrb[0]) mmio_reg[7:0]   <= mmio_wdata[7:0];
      if (mmio_wstrb[1]) mmio_reg[15:8]  <= mmio_wdata[15:8];
      if (mmio_wstrb[2]) mmio_reg[23:16] <= mmio_wdata[23:16];
      if (mmio_wstrb[3]) mmio_reg[31:24] <= mmio_wdata[31:24];
    end
  end

  task automatic clear_masters;
    begin
      i_valid = 1'b0;
      i_addr  = 32'd0;
      d_valid = 1'b0;
      d_write = 1'b0;
      d_addr  = 32'd0;
      d_wdata = 32'd0;
      d_wstrb = 4'b0000;
    end
  endtask

  task automatic wait_i_ready;
    begin
      timeout = 0;
      while (!i_ready && (timeout < 20)) begin
        @(posedge clk);
        #1ps;
        timeout = timeout + 1;
      end
      if (!i_ready) begin
        $fatal(1, "timeout waiting for I bus ready");
      end
    end
  endtask

  task automatic wait_d_ready;
    begin
      timeout = 0;
      while (!d_ready && (timeout < 20)) begin
        @(posedge clk);
        #1ps;
        timeout = timeout + 1;
      end
      if (!d_ready) begin
        $fatal(1, "timeout waiting for D bus ready");
      end
    end
  endtask

  task automatic i_read_check(
    input [31:0] addr,
    input [31:0] expected
  );
    begin
      i_addr  = addr;
      i_valid = 1'b1;
      wait_i_ready();
      if (i_rdata !== expected) begin
        $fatal(1, "I read mismatch at 0x%08x: expected 0x%08x, got 0x%08x",
               addr, expected, i_rdata);
      end
      i_valid = 1'b0;
      @(posedge clk);
      #1ps;
    end
  endtask

  task automatic d_read_check(
    input [31:0] addr,
    input [31:0] expected
  );
    begin
      d_addr  = addr;
      d_write = 1'b0;
      d_wdata = 32'd0;
      d_wstrb = 4'b0000;
      d_valid = 1'b1;
      wait_d_ready();
      if (d_rdata !== expected) begin
        $fatal(1, "D read mismatch at 0x%08x: expected 0x%08x, got 0x%08x",
               addr, expected, d_rdata);
      end
      d_valid = 1'b0;
      @(posedge clk);
      #1ps;
    end
  endtask

  task automatic d_write_word(
    input [31:0] addr,
    input [31:0] wdata,
    input [3:0]  wstrb
  );
    begin
      d_addr  = addr;
      d_write = 1'b1;
      d_wdata = wdata;
      d_wstrb = wstrb;
      d_valid = 1'b1;
      wait_d_ready();
      d_valid = 1'b0;
      d_write = 1'b0;
      @(posedge clk);
      #1ps;
    end
  endtask

  rv32i_mem_bus u_bus (
    .clk               (clk),
    .rst_n             (rst_n),
    .i_valid           (i_valid),
    .i_addr            (i_addr),
    .i_ready           (i_ready),
    .i_rdata           (i_rdata),
    .i_error           (i_error),
    .d_valid           (d_valid),
    .d_write           (d_write),
    .d_addr            (d_addr),
    .d_wdata           (d_wdata),
    .d_wstrb           (d_wstrb),
    .d_ready           (d_ready),
    .d_rdata           (d_rdata),
    .d_error           (d_error),
    .rom_valid         (rom_valid),
    .rom_write         (rom_write),
    .rom_addr          (rom_addr),
    .rom_wdata         (rom_wdata),
    .rom_wstrb         (rom_wstrb),
    .rom_ready         (rom_ready),
    .rom_rdata         (rom_rdata),
    .sram_valid        (sram_valid),
    .sram_write        (sram_write),
    .sram_addr         (sram_addr),
    .sram_wdata        (sram_wdata),
    .sram_wstrb        (sram_wstrb),
    .sram_ready        (sram_ready),
    .sram_rdata        (sram_rdata),
    .mmio_valid        (mmio_valid),
    .mmio_write        (mmio_write),
    .mmio_addr         (mmio_addr),
    .mmio_wdata        (mmio_wdata),
    .mmio_wstrb        (mmio_wstrb),
    .mmio_ready        (mmio_ready),
    .mmio_rdata        (mmio_rdata),
    .dbg_active        (dbg_active),
    .dbg_grant_is_d    (dbg_grant_is_d),
    .dbg_target        (dbg_target),
    .dbg_decode_error  (dbg_decode_error),
    .dbg_i_grant_count (dbg_i_grant_count),
    .dbg_d_grant_count (dbg_d_grant_count)
  );

  initial begin
    clear_masters();
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
    #1ps;

    i_read_check(32'h0000_0004, 32'h1000_0001);
    d_read_check(32'h2000_0008, 32'h2000_0002);

    d_write_word(32'h2000_0008, 32'hAA_BB_CC_DD, 4'b0101);
    d_read_check(32'h2000_0008, 32'h20BB_00DD);

    d_write_word(32'h4000_0000, 32'hCAFE_BABE, 4'b1111);
    d_read_check(32'h4000_0000, 32'hCAFE_BABE);

    i_addr   = 32'h0000_0000;
    i_valid  = 1'b1;
    d_addr   = 32'h2000_0000;
    d_write  = 1'b0;
    d_wdata  = 32'd0;
    d_wstrb  = 4'b0000;
    d_valid  = 1'b1;
    wait_d_ready();
    if (i_ready) begin
      $fatal(1, "I bus should not complete in the same grant as D bus");
    end
    if (d_rdata !== 32'h2000_0000) begin
      $fatal(1, "D priority read mismatch: got 0x%08x", d_rdata);
    end
    d_valid = 1'b0;
    wait_i_ready();
    if (i_rdata !== 32'h1000_0000) begin
      $fatal(1, "I read after D priority mismatch: got 0x%08x", i_rdata);
    end
    i_valid = 1'b0;
    @(posedge clk);
    #1ps;

    d_addr  = 32'h8000_0000;
    d_write = 1'b0;
    d_wstrb = 4'b0000;
    d_valid = 1'b1;
    wait_d_ready();
    if (!dbg_decode_error) begin
      $fatal(1, "expected decode error for unmapped address");
    end
    if (!d_error) begin
      $fatal(1, "expected D error response for unmapped address");
    end
    if (d_rdata !== 32'd0) begin
      $fatal(1, "unmapped read should return zero, got 0x%08x", d_rdata);
    end
    d_valid = 1'b0;
    @(posedge clk);
    #1ps;

    i_addr  = 32'h8000_0000;
    i_valid = 1'b1;
    wait_i_ready();
    if (!dbg_decode_error) begin
      $fatal(1, "expected decode error for unmapped instruction address");
    end
    if (!i_error) begin
      $fatal(1, "expected I error response for unmapped instruction address");
    end
    if (i_rdata !== 32'd0) begin
      $fatal(1, "unmapped instruction read should return zero, got 0x%08x", i_rdata);
    end
    i_valid = 1'b0;
    @(posedge clk);
    #1ps;

    if (dbg_i_grant_count < 32'd2) begin
      $fatal(1, "expected at least two I grants, got %0d", dbg_i_grant_count);
    end
    if (dbg_d_grant_count < 32'd6) begin
      $fatal(1, "expected at least six D grants, got %0d", dbg_d_grant_count);
    end

    $display("[PASS] rv32i_mem_bus_tb");
    $display("  i_grants=%0d d_grants=%0d", dbg_i_grant_count, dbg_d_grant_count);
    $display("  D-priority arbitration, ROM/SRAM/MMIO decode and byte writes passed");
    $finish;
  end

endmodule
