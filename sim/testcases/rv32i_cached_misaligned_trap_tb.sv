`timescale 1ns/1ps
`include "rv32i_defs.vh"

module rv32i_cached_misaligned_trap_tb;

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

  logic [31:0] rom [0:255];
  logic [31:0] sram [0:255];
  string       rom_memh;
  logic        bus_decode_error_seen;
  logic        load_handler_done;
  logic        store_handler_done;
  logic        instr_handler_done;
  logic        load_resume_done;
  logic        store_resume_done;
  logic        instr_resume_done;
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
      rom_memh = "../software/bin/cached_misaligned_trap.memh";
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

  assign mmio_ready = mmio_valid;
  assign mmio_rdata = 32'd0;

  always @(posedge clk) begin
    if (rom_valid && rom_ready && rom_write) begin
      $fatal(1, "unexpected ROM write in cached misaligned trap test");
    end

    if (mmio_valid) begin
      $fatal(1, "unexpected MMIO access in cached misaligned trap test");
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
      bus_decode_error_seen <= 1'b0;
    end else if (dbg_bus_decode_error) begin
      bus_decode_error_seen <= 1'b1;
    end
  end

  rv32i_cached_system_top #(
    .ICACHE_INDEX_BITS(2),
    .DCACHE_INDEX_BITS(2)
  ) u_top (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .timer_irq              (1'b0),
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

  initial begin
    dbg_reg_addr = 5'd0;
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    timeout = 0;
    load_handler_done  = 1'b0;
    store_handler_done = 1'b0;
    instr_handler_done = 1'b0;
    load_resume_done   = 1'b0;
    store_resume_done  = 1'b0;
    instr_resume_done  = 1'b0;
    while ((!load_handler_done || !store_handler_done || !instr_handler_done ||
            !load_resume_done || !store_resume_done || !instr_resume_done) &&
           (timeout < 1200)) begin
      @(posedge clk);
      #1ps;
      dbg_reg_addr = 5'd31;
      #1ps;
      load_handler_done = (dbg_reg_rdata === 32'd1);
      dbg_reg_addr = 5'd30;
      #1ps;
      store_handler_done = (dbg_reg_rdata === 32'd1);
      dbg_reg_addr = 5'd29;
      #1ps;
      instr_handler_done = (dbg_reg_rdata === 32'd1);
      dbg_reg_addr = 5'd21;
      #1ps;
      load_resume_done = (dbg_reg_rdata === 32'h55);
      dbg_reg_addr = 5'd22;
      #1ps;
      store_resume_done = (dbg_reg_rdata === 32'h66);
      dbg_reg_addr = 5'd23;
      #1ps;
      instr_resume_done = (dbg_reg_rdata === 32'h77);
      timeout = timeout + 1;
    end

    if (!load_handler_done || !store_handler_done || !instr_handler_done ||
        !load_resume_done || !store_resume_done || !instr_resume_done) begin
      $fatal(1, "timeout waiting for misaligned trap handlers and resumes");
    end
    if (dbg_illegal_instr) begin
      $fatal(1, "unexpected illegal instruction in cached misaligned trap test");
    end
    if (dbg_ecall) begin
      $fatal(1, "unexpected ECALL event in cached misaligned trap test");
    end
    if (dbg_ebreak) begin
      $fatal(1, "unexpected EBREAK event in cached misaligned trap test");
    end
    if (bus_decode_error_seen) begin
      $fatal(1, "misaligned traps should be raised before bus decode errors");
    end

    check_reg(5'd1,  32'h2000_0000, "x1");
    check_reg(5'd2,  32'd0,         "x2 (faulting load must not write back)");
    check_reg(5'd21, 32'h55,        "x21 (load misaligned resume)");
    check_reg(5'd22, 32'h66,        "x22 (store misaligned resume)");
    check_reg(5'd23, 32'h77,        "x23 (instruction misaligned resume)");
    check_reg(5'd29, 32'd1,         "x29 (instruction misaligned handler marker)");
    check_reg(5'd30, 32'd1,         "x30 (store misaligned handler marker)");
    check_reg(5'd31, 32'd1,         "x31 (load misaligned handler marker)");

    if (sram[0] !== `RV32I_TRAP_CAUSE_LOAD_ADDR_MISALIGNED) begin
      $fatal(1, "load misaligned mcause mismatch: expected 4, got 0x%08x", sram[0]);
    end
    if (sram[1] !== 32'h0000_000c) begin
      $fatal(1, "load misaligned mepc mismatch: expected 0x0000000c, got 0x%08x", sram[1]);
    end
    if (sram[2] !== `RV32I_TRAP_CAUSE_STORE_ADDR_MISALIGNED) begin
      $fatal(1, "store misaligned mcause mismatch: expected 6, got 0x%08x", sram[2]);
    end
    if (sram[3] !== 32'h0000_001c) begin
      $fatal(1, "store misaligned mepc mismatch: expected 0x0000001c, got 0x%08x", sram[3]);
    end
    if (sram[4] !== `RV32I_TRAP_CAUSE_INSTR_ADDR_MISALIGNED) begin
      $fatal(1, "instruction misaligned mcause mismatch: expected 0, got 0x%08x", sram[4]);
    end
    if (sram[5] !== 32'h0000_0030) begin
      $fatal(1, "instruction misaligned mepc mismatch: expected 0x00000030, got 0x%08x", sram[5]);
    end
    if (sram[6] !== 32'd0) begin
      $fatal(1, "faulting misaligned store unexpectedly modified SRAM word 6: 0x%08x", sram[6]);
    end
    if (dbg_bus_i_grant_count == 32'd0) begin
      $fatal(1, "expected I-cache bus grants");
    end
    if (dbg_bus_d_grant_count == 32'd0) begin
      $fatal(1, "expected D-cache/bus grants for handler stores");
    end

    $display("[PASS] rv32i_cached_misaligned_trap_tb");
    $display("  pc=0x%08x cycle=%0d instret=%0d stall_cycle=%0d",
             dbg_pc, dbg_cycle, dbg_instret, dbg_stall_cycle);
    $display("  load_misaligned:  mcause=0x%08x mepc=0x%08x",
             sram[0], sram[1]);
    $display("  store_misaligned: mcause=0x%08x mepc=0x%08x",
             sram[2], sram[3]);
    $display("  instr_misaligned: mcause=0x%08x mepc=0x%08x",
             sram[4], sram[5]);
    $display("  bus_i_grants=%0d bus_d_grants=%0d icache_miss=%0d dcache_miss=%0d",
             dbg_bus_i_grant_count, dbg_bus_d_grant_count,
             dbg_icache_miss_count, dbg_dcache_miss_count);
    $display("  load/store/instruction misaligned traps were precise and resumed with MRET");
    $finish;
  end

endmodule
