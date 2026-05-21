`timescale 1ns/1ps

module rv32i_cached_timer_irq_tb;

  localparam CLK_PERIOD_NS = 10;

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

  logic [31:0] rom [0:255];
  logic [31:0] sram [0:255];
  logic        handler_done;
  logic        main_done;
  string       rom_memh;
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
      rom[i]  = 32'h0000_0013; // addi x0, x0, 0
      sram[i] = 32'd0;
    end

    if (!$value$plusargs("ROM_MEMH=%s", rom_memh)) begin
      rom_memh = "../software/bin/cached_timer_irq.memh";
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
      $fatal(1, "unexpected ROM write in cached timer IRQ test");
    end

    if (sram_valid && sram_ready && sram_write) begin
      if (sram_wstrb[0]) sram[sram_addr[9:2]][7:0]   <= sram_wdata[7:0];
      if (sram_wstrb[1]) sram[sram_addr[9:2]][15:8]  <= sram_wdata[15:8];
      if (sram_wstrb[2]) sram[sram_addr[9:2]][23:16] <= sram_wdata[23:16];
      if (sram_wstrb[3]) sram[sram_addr[9:2]][31:24] <= sram_wdata[31:24];
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

  rv32i_timer u_timer (
    .clk              (clk),
    .rst_n            (rst_n),
    .valid            (mmio_valid),
    .write            (mmio_write),
    .addr             (mmio_addr),
    .wdata            (mmio_wdata),
    .wstrb            (mmio_wstrb),
    .ready            (mmio_ready),
    .rdata            (mmio_rdata),
    .timer_irq        (timer_irq),
    .dbg_mtime_lo     (timer_mtime_lo),
    .dbg_mtime_hi     (timer_mtime_hi),
    .dbg_mtimecmp_lo  (timer_mtimecmp_lo),
    .dbg_mtimecmp_hi  (timer_mtimecmp_hi),
    .dbg_ctrl         (timer_ctrl)
  );

  initial begin
    dbg_reg_addr = 5'd0;
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    timeout = 0;
    handler_done = 1'b0;
    main_done    = 1'b0;
    while ((!handler_done || !main_done) && (timeout < 800)) begin
      @(posedge clk);
      #1ps;
      dbg_reg_addr = 5'd31;
      #1ps;
      handler_done = (dbg_reg_rdata === 32'd1);
      dbg_reg_addr = 5'd21;
      #1ps;
      main_done = (dbg_reg_rdata === 32'h55);
      timeout = timeout + 1;
    end

    if (!handler_done || !main_done) begin
      $fatal(1, "timeout waiting for timer interrupt handler and MRET resume");
    end
    if (dbg_illegal_instr) begin
      $fatal(1, "unexpected illegal instruction in cached timer interrupt test");
    end
    if (dbg_ecall) begin
      $fatal(1, "unexpected ECALL event in cached timer interrupt test");
    end
    if (dbg_bus_decode_error) begin
      $fatal(1, "unexpected bus decode error in cached timer interrupt test");
    end

    check_reg(5'd1,  32'h4000_0000, "x1");
    check_reg(5'd2,  32'd10,        "x2");
    check_reg(5'd3,  32'd3,         "x3");
    check_reg(5'd10, 32'h8000_0007, "x10 (handler mcause)");
    check_reg(5'd12, 32'h0000_0080, "x12 (handler mstatus)");
    check_reg(5'd13, 32'h0000_0080, "x13 (handler mie)");
    check_reg(5'd14, 32'h0000_0080, "x14 (handler mip)");
    check_reg(5'd21, 32'h55,        "x21 (main resumed after mret)");
    check_reg(5'd31, 32'd1,         "x31 (interrupt handler marker)");

    if (!timer_irq) begin
      $fatal(1, "timer_irq expected high after CPU programmed timer");
    end
    if (timer_mtimecmp_lo !== 32'd10) begin
      $fatal(1, "timer_mtimecmp_lo mismatch: expected 10, got %0d", timer_mtimecmp_lo);
    end
    if (timer_mtimecmp_hi !== 32'd0) begin
      $fatal(1, "timer_mtimecmp_hi mismatch: expected 0, got %0d", timer_mtimecmp_hi);
    end

    if (sram[0] !== 32'h8000_0007) begin
      $fatal(1, "mcause mismatch: expected machine timer interrupt, got 0x%08x", sram[0]);
    end
    if ((sram[1][1:0] !== 2'b00) ||
        (sram[1] < 32'h0000_0030) ||
        (sram[1] > 32'h0000_00fc)) begin
      $fatal(1, "mepc out of expected main-program window: 0x%08x", sram[1]);
    end
    if (sram[2] !== 32'h0000_0080) begin
      $fatal(1, "mstatus in handler mismatch: expected MPIE=1 and MIE=0, got 0x%08x", sram[2]);
    end
    if (sram[3] !== 32'h0000_0080) begin
      $fatal(1, "mie in handler mismatch: expected MTIE=1, got 0x%08x", sram[3]);
    end
    if (sram[4] !== 32'h0000_0080) begin
      $fatal(1, "mip in handler mismatch: expected MTIP=1, got 0x%08x", sram[4]);
    end
    if (dbg_bus_i_grant_count == 32'd0) begin
      $fatal(1, "expected I-cache bus grants");
    end
    if (dbg_bus_d_grant_count == 32'd0) begin
      $fatal(1, "expected D/MMIO bus grants");
    end

    $display("[PASS] rv32i_cached_timer_irq_tb");
    $display("  pc=0x%08x cycle=%0d instret=%0d stall_cycle=%0d",
             dbg_pc, dbg_cycle, dbg_instret, dbg_stall_cycle);
    $display("  mcause=0x%08x mepc=0x%08x mstatus=0x%08x mie=0x%08x mip=0x%08x",
             sram[0], sram[1], sram[2], sram[3], sram[4]);
    $display("  timer mtime=0x%08x_%08x mtimecmp=0x%08x_%08x ctrl=0x%08x irq=%0d",
             timer_mtime_hi, timer_mtime_lo, timer_mtimecmp_hi, timer_mtimecmp_lo,
             timer_ctrl, timer_irq);
    $display("  bus_i_grants=%0d bus_d_grants=%0d icache_miss=%0d dcache_miss=%0d",
             dbg_bus_i_grant_count, dbg_bus_d_grant_count,
             dbg_icache_miss_count, dbg_dcache_miss_count);
    $display("  machine timer interrupt entered handler and returned with MRET");
    $finish;
  end

endmodule
