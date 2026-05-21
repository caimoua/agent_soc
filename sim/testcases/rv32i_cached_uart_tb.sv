`timescale 1ns/1ps

module rv32i_cached_uart_tb;

  localparam CLK_PERIOD_NS = 10;
  localparam UART_EXPECT_LEN = 5;

  logic clk;
  logic rst_n;

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

  wire        timer_valid;
  wire        timer_write;
  wire [31:0] timer_addr;
  wire [31:0] timer_wdata;
  wire [3:0]  timer_wstrb;
  wire        timer_ready;
  wire [31:0] timer_rdata;

  wire        uart_valid;
  wire        uart_write;
  wire [31:0] uart_addr;
  wire [31:0] uart_wdata;
  wire [3:0]  uart_wstrb;
  wire        uart_ready;
  wire [31:0] uart_rdata;

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

  wire [31:0] dbg_icache_hit_count;
  wire [31:0] dbg_icache_miss_count;
  wire [31:0] dbg_dcache_hit_count;
  wire [31:0] dbg_dcache_miss_count;
  wire [31:0] dbg_bus_i_grant_count;
  wire [31:0] dbg_bus_d_grant_count;
  wire        dbg_bus_decode_error;

  wire        timer_irq;
  wire [31:0] timer_mtime_lo;
  wire [31:0] timer_mtime_hi;
  wire [31:0] timer_mtimecmp_lo;
  wire [31:0] timer_mtimecmp_hi;
  wire [31:0] timer_ctrl;

  wire        uart_tx_valid;
  wire [7:0]  uart_tx_data;
  wire [31:0] uart_tx_count;
  wire [7:0]  uart_last_tx;
  wire        mmio_decode_error;
  logic       mmio_decode_error_seen;

  logic [31:0] rom [0:255];
  logic [31:0] sram [0:255];
  logic [7:0]  uart_capture [0:15];
  string rom_memh;
  integer rom_i;
  integer capture_i;
  integer check_i;
  integer memh_fd;
  integer timeout;
  integer uart_capture_count;

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD_NS/2) clk = ~clk;
  end

  function [7:0] expected_uart_char;
    input integer index;
    begin
      case (index)
        0: expected_uart_char = 8'h55; // U
        1: expected_uart_char = 8'h41; // A
        2: expected_uart_char = 8'h52; // R
        3: expected_uart_char = 8'h54; // T
        default: expected_uart_char = 8'h0a;
      endcase
    end
  endfunction

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
    for (rom_i = 0; rom_i < 256; rom_i = rom_i + 1) begin
      rom[rom_i]  = 32'h0000_0013; // addi x0, x0, 0
      sram[rom_i] = 32'd0;
    end

    if (!$value$plusargs("ROM_MEMH=%s", rom_memh)) begin
      rom_memh = "../software/bin/cached_uart.memh";
    end

    memh_fd = $fopen(rom_memh, "r");
    if (memh_fd == 0) begin
      $fatal(1, "failed to open ROM_MEMH='%s'", rom_memh);
    end
    $fclose(memh_fd);
    $readmemh(rom_memh, rom);
  end

  assign rom_ready = rom_valid;
  assign rom_rdata = rom[rom_addr[9:2]];

  assign sram_ready = sram_valid;
  assign sram_rdata = sram[sram_addr[9:2]];

  always @(posedge clk) begin
    if (rom_valid && rom_ready && rom_write) begin
      $fatal(1, "unexpected ROM write in cached UART test");
    end

    if (sram_valid && sram_ready && sram_write) begin
      if (sram_wstrb[0]) sram[sram_addr[9:2]][7:0]   <= sram_wdata[7:0];
      if (sram_wstrb[1]) sram[sram_addr[9:2]][15:8]  <= sram_wdata[15:8];
      if (sram_wstrb[2]) sram[sram_addr[9:2]][23:16] <= sram_wdata[23:16];
      if (sram_wstrb[3]) sram[sram_addr[9:2]][31:24] <= sram_wdata[31:24];
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      uart_capture_count <= 0;
      for (capture_i = 0; capture_i < 16; capture_i = capture_i + 1) begin
        uart_capture[capture_i] <= 8'd0;
      end
    end else if (uart_tx_valid) begin
      if (uart_capture_count < 16) begin
        uart_capture[uart_capture_count] <= uart_tx_data;
      end
      uart_capture_count <= uart_capture_count + 1;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mmio_decode_error_seen <= 1'b0;
    end else if (mmio_decode_error) begin
      mmio_decode_error_seen <= 1'b1;
    end
  end

  rv32i_cached_system_top #(
    .ICACHE_INDEX_BITS(2),
    .DCACHE_INDEX_BITS(2)
  ) u_top (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .timer_irq              (timer_irq),
    .rom_valid              (rom_valid),
    .rom_write              (rom_write),
    .rom_addr               (rom_addr),
    .rom_wdata              (rom_wdata),
    .rom_wstrb              (rom_wstrb),
    .rom_ready              (rom_ready),
    .rom_rdata              (rom_rdata),
    .sram_valid             (sram_valid),
    .sram_write             (sram_write),
    .sram_addr              (sram_addr),
    .sram_wdata             (sram_wdata),
    .sram_wstrb             (sram_wstrb),
    .sram_ready             (sram_ready),
    .sram_rdata             (sram_rdata),
    .mmio_valid             (mmio_valid),
    .mmio_write             (mmio_write),
    .mmio_addr              (mmio_addr),
    .mmio_wdata             (mmio_wdata),
    .mmio_wstrb             (mmio_wstrb),
    .mmio_ready             (mmio_ready),
    .mmio_rdata             (mmio_rdata),
    .dbg_pc                 (dbg_pc),
    .dbg_cycle              (dbg_cycle),
    .dbg_instret            (dbg_instret),
    .dbg_stall_cycle        (dbg_stall_cycle),
    .dbg_flush_cycle        (dbg_flush_cycle),
    .dbg_reg_addr           (dbg_reg_addr),
    .dbg_reg_rdata          (dbg_reg_rdata),
    .dbg_illegal_instr      (dbg_illegal_instr),
    .dbg_ecall              (dbg_ecall),
    .dbg_ebreak             (dbg_ebreak),
    .dbg_icache_hit_count   (dbg_icache_hit_count),
    .dbg_icache_miss_count  (dbg_icache_miss_count),
    .dbg_dcache_hit_count   (dbg_dcache_hit_count),
    .dbg_dcache_miss_count  (dbg_dcache_miss_count),
    .dbg_bus_i_grant_count  (dbg_bus_i_grant_count),
    .dbg_bus_d_grant_count  (dbg_bus_d_grant_count),
    .dbg_bus_decode_error   (dbg_bus_decode_error)
  );

  rv32i_mmio_periph_mux u_mmio_mux (
    .valid            (mmio_valid),
    .write            (mmio_write),
    .addr             (mmio_addr),
    .wdata            (mmio_wdata),
    .wstrb            (mmio_wstrb),
    .ready            (mmio_ready),
    .rdata            (mmio_rdata),
    .timer_valid      (timer_valid),
    .timer_write      (timer_write),
    .timer_addr       (timer_addr),
    .timer_wdata      (timer_wdata),
    .timer_wstrb      (timer_wstrb),
    .timer_ready      (timer_ready),
    .timer_rdata      (timer_rdata),
    .uart_valid       (uart_valid),
    .uart_write       (uart_write),
    .uart_addr        (uart_addr),
    .uart_wdata       (uart_wdata),
    .uart_wstrb       (uart_wstrb),
    .uart_ready       (uart_ready),
    .uart_rdata       (uart_rdata),
    .dbg_decode_error (mmio_decode_error)
  );

  rv32i_timer u_timer (
    .clk              (clk),
    .rst_n            (rst_n),
    .valid            (timer_valid),
    .write            (timer_write),
    .addr             (timer_addr),
    .wdata            (timer_wdata),
    .wstrb            (timer_wstrb),
    .ready            (timer_ready),
    .rdata            (timer_rdata),
    .timer_irq        (timer_irq),
    .dbg_mtime_lo     (timer_mtime_lo),
    .dbg_mtime_hi     (timer_mtime_hi),
    .dbg_mtimecmp_lo  (timer_mtimecmp_lo),
    .dbg_mtimecmp_hi  (timer_mtimecmp_hi),
    .dbg_ctrl         (timer_ctrl)
  );

  rv32i_uart u_uart (
    .clk          (clk),
    .rst_n        (rst_n),
    .valid        (uart_valid),
    .write        (uart_write),
    .addr         (uart_addr),
    .wdata        (uart_wdata),
    .wstrb        (uart_wstrb),
    .ready        (uart_ready),
    .rdata        (uart_rdata),
    .tx_valid     (uart_tx_valid),
    .tx_data      (uart_tx_data),
    .dbg_tx_count (uart_tx_count),
    .dbg_last_tx  (uart_last_tx)
  );

  initial begin
    dbg_reg_addr = 5'd0;
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    timeout = 0;
    while (!dbg_ebreak && (timeout < 400)) begin
      @(posedge clk);
      #1ps;
      timeout = timeout + 1;
    end

    if (!dbg_ebreak) begin
      $fatal(1, "timeout waiting for cached UART ebreak");
    end
    if (dbg_illegal_instr) begin
      $fatal(1, "unexpected illegal instruction in cached UART test");
    end
    if (dbg_ecall) begin
      $fatal(1, "unexpected ECALL event in cached UART test");
    end
    if (dbg_bus_decode_error) begin
      $fatal(1, "unexpected bus decode error in cached UART test");
    end
    if (mmio_decode_error_seen) begin
      $fatal(1, "unexpected MMIO peripheral decode error in cached UART test");
    end

    check_reg(5'd1, 32'h4000_1000, "x1 (UART base)");
    check_reg(5'd2, 32'd10,        "x2 (last character)");
    check_reg(5'd3, 32'd1,         "x3 (UART status)");
    check_reg(5'd4, 32'd10,        "x4 (UART TXDATA readback)");

    if (uart_tx_count !== UART_EXPECT_LEN) begin
      $fatal(1, "UART tx_count mismatch: expected %0d, got %0d",
             UART_EXPECT_LEN, uart_tx_count);
    end
    if (uart_capture_count !== UART_EXPECT_LEN) begin
      $fatal(1, "UART capture count mismatch: expected %0d, got %0d",
             UART_EXPECT_LEN, uart_capture_count);
    end
    for (check_i = 0; check_i < UART_EXPECT_LEN; check_i = check_i + 1) begin
      if (uart_capture[check_i] !== expected_uart_char(check_i)) begin
        $fatal(1, "UART char[%0d] mismatch: expected 0x%02x, got 0x%02x",
               check_i, expected_uart_char(check_i), uart_capture[check_i]);
      end
    end
    if (uart_last_tx !== 8'h0a) begin
      $fatal(1, "UART last_tx mismatch: expected newline, got 0x%02x", uart_last_tx);
    end
    if (timer_irq) begin
      $fatal(1, "timer_irq should remain low in cached UART test");
    end
    if (dbg_bus_i_grant_count == 32'd0) begin
      $fatal(1, "expected I-cache bus grants");
    end
    if (dbg_bus_d_grant_count < 32'd7) begin
      $fatal(1, "expected at least 7 D/MMIO bus grants, got %0d", dbg_bus_d_grant_count);
    end
    if (dbg_dcache_miss_count !== 32'd0) begin
      $fatal(1, "UART MMIO accesses should bypass D-cache misses, got %0d",
             dbg_dcache_miss_count);
    end

    $display("[PASS] rv32i_cached_uart_tb");
    $display("  pc=0x%08x cycle=%0d instret=%0d stall_cycle=%0d",
             dbg_pc, dbg_cycle, dbg_instret, dbg_stall_cycle);
    $display("  uart_tx_count=%0d output=\"UART\\n\" last_tx=0x%02x",
             uart_tx_count, uart_last_tx);
    $display("  bus_i_grants=%0d bus_d_grants=%0d icache_miss=%0d dcache_miss=%0d",
             dbg_bus_i_grant_count, dbg_bus_d_grant_count,
             dbg_icache_miss_count, dbg_dcache_miss_count);
    $display("  CPU MMIO write to rv32i_uart through cached system top passed");
    $finish;
  end

endmodule
