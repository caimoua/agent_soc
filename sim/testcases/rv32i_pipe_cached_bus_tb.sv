`timescale 1ns/1ps

module rv32i_pipe_cached_bus_tb;

  localparam CLK_PERIOD_NS = 10;

  logic clk;
  logic rst_n;

  wire        core_imem_valid;
  wire [31:0] core_imem_addr;
  wire        core_imem_ready;
  wire [31:0] core_imem_rdata;
  wire        core_imem_error;

  wire        core_dmem_valid;
  wire        core_dmem_write;
  wire [31:0] core_dmem_addr;
  wire [31:0] core_dmem_wdata;
  wire [3:0]  core_dmem_wstrb;
  wire        core_dmem_ready;
  wire [31:0] core_dmem_rdata;
  wire        core_dmem_error;

  wire        ic_mem_valid;
  wire [31:0] ic_mem_addr;
  wire        ic_mem_ready;
  wire [31:0] ic_mem_rdata;
  wire        ic_mem_error;

  wire        dc_mem_valid;
  wire        dc_mem_write;
  wire [31:0] dc_mem_addr;
  wire [31:0] dc_mem_wdata;
  wire [3:0]  dc_mem_wstrb;
  wire        dc_mem_ready;
  wire [31:0] dc_mem_rdata;
  wire        dc_mem_error;

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

  wire        ic_dbg_hit;
  wire        ic_dbg_miss;
  wire [31:0] ic_dbg_hit_count;
  wire [31:0] ic_dbg_miss_count;
  wire        dc_dbg_hit;
  wire        dc_dbg_miss;
  wire [31:0] dc_dbg_hit_count;
  wire [31:0] dc_dbg_miss_count;

  wire        bus_dbg_active;
  wire        bus_dbg_grant_is_d;
  wire [1:0]  bus_dbg_target;
  wire        bus_dbg_decode_error;
  wire [31:0] bus_dbg_i_grant_count;
  wire [31:0] bus_dbg_d_grant_count;

  logic [31:0] rom [0:255];
  logic [31:0] sram [0:255];
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
      sram[i] = 32'h3000_0000 + i;
    end

    sram[1] = 32'd7;

    if (!$value$plusargs("ROM_MEMH=%s", rom_memh)) begin
      rom_memh = "../software/bin/pipe_cached_bus.memh";
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
    if (sram_valid && sram_ready && sram_write) begin
      if (sram_wstrb[0]) sram[sram_addr[9:2]][7:0]   <= sram_wdata[7:0];
      if (sram_wstrb[1]) sram[sram_addr[9:2]][15:8]  <= sram_wdata[15:8];
      if (sram_wstrb[2]) sram[sram_addr[9:2]][23:16] <= sram_wdata[23:16];
      if (sram_wstrb[3]) sram[sram_addr[9:2]][31:24] <= sram_wdata[31:24];
    end
  end

  rv32i_icache #(
    .INDEX_BITS(2)
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

  rv32i_mem_bus u_bus (
    .clk               (clk),
    .rst_n             (rst_n),
    .i_valid           (ic_mem_valid),
    .i_addr            (ic_mem_addr),
    .i_ready           (ic_mem_ready),
    .i_rdata           (ic_mem_rdata),
    .i_error           (ic_mem_error),
    .d_valid           (dc_mem_valid),
    .d_write           (dc_mem_write),
    .d_addr            (dc_mem_addr),
    .d_wdata           (dc_mem_wdata),
    .d_wstrb           (dc_mem_wstrb),
    .d_ready           (dc_mem_ready),
    .d_rdata           (dc_mem_rdata),
    .d_error           (dc_mem_error),
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
    .dbg_active        (bus_dbg_active),
    .dbg_grant_is_d    (bus_dbg_grant_is_d),
    .dbg_target        (bus_dbg_target),
    .dbg_decode_error  (bus_dbg_decode_error),
    .dbg_i_grant_count (bus_dbg_i_grant_count),
    .dbg_d_grant_count (bus_dbg_d_grant_count)
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
    while (!dbg_ebreak && (timeout < 320)) begin
      @(posedge clk);
      #1ps;
      timeout = timeout + 1;
    end

    if (!dbg_ebreak) begin
      $fatal(1, "timeout waiting for pipeline ebreak");
    end
    if (dbg_illegal_instr) begin
      $fatal(1, "unexpected illegal instruction in cached bus test");
    end
    if (dbg_ecall) begin
      $fatal(1, "unexpected ECALL event in cached bus test");
    end
    if (bus_dbg_decode_error) begin
      $fatal(1, "unexpected bus decode error");
    end

    check_reg(5'd1, 32'h2000_0000, "x1");
    check_reg(5'd2, 32'd7,         "x2");
    check_reg(5'd3, 32'd14,        "x3");
    check_reg(5'd4, 32'd170,       "x4");
    check_reg(5'd5, 32'd170,       "x5");
    check_reg(5'd6, 32'd184,       "x6");

    if (sram[2] !== 32'd170) begin
      $fatal(1, "sram[2] mismatch: expected 170, got 0x%08x", sram[2]);
    end
    if (dbg_instret !== 32'd8) begin
      $fatal(1, "instret mismatch: expected 8, got %0d", dbg_instret);
    end
    if (bus_dbg_i_grant_count == 32'd0) begin
      $fatal(1, "expected I-cache bus grants");
    end
    if (bus_dbg_d_grant_count == 32'd0) begin
      $fatal(1, "expected D-cache bus grants");
    end
    if ((ic_dbg_miss_count == 32'd0) || (dc_dbg_miss_count == 32'd0)) begin
      $fatal(1, "expected both I-cache and D-cache misses");
    end

    $display("[PASS] rv32i_pipe_cached_bus_tb");
    $display("  pc=0x%08x cycle=%0d instret=%0d stall_cycle=%0d",
             dbg_pc, dbg_cycle, dbg_instret, dbg_stall_cycle);
    $display("  bus_i_grants=%0d bus_d_grants=%0d",
             bus_dbg_i_grant_count, bus_dbg_d_grant_count);
    $display("  icache_hit=%0d icache_miss=%0d dcache_hit=%0d dcache_miss=%0d",
             ic_dbg_hit_count, ic_dbg_miss_count, dc_dbg_hit_count, dc_dbg_miss_count);
    $display("  rv32i_pipe_core fetch/load/store through I-cache, D-cache and memory bus passed");
    $finish;
  end

endmodule
