`timescale 1ns/1ps

module rv32i_cached_ahb_master_top_tb;

  localparam CLK_PERIOD_NS = 10;

  logic clk;
  logic rst_n;

  wire [31:0] ahb_haddr;
  wire [2:0]  ahb_hburst;
  wire [3:0]  ahb_hprot;
  wire [2:0]  ahb_hsize;
  wire [1:0]  ahb_htrans;
  wire [31:0] ahb_hwdata;
  wire        ahb_hwrite;
  wire [31:0] ahb_hrdata;
  wire        ahb_hready;
  wire [1:0]  ahb_hresp;

  wire        rom_hsel;
  wire [31:0] rom_haddr;
  wire [2:0]  rom_hburst;
  wire [3:0]  rom_hprot;
  wire [2:0]  rom_hsize;
  wire [1:0]  rom_htrans;
  wire [31:0] rom_hwdata;
  wire        rom_hwrite;
  wire        rom_hready;
  wire [31:0] rom_hrdata;
  wire        rom_hreadyout;
  wire [1:0]  rom_hresp;

  wire        sram_hsel;
  wire [31:0] sram_haddr;
  wire [2:0]  sram_hburst;
  wire [3:0]  sram_hprot;
  wire [2:0]  sram_hsize;
  wire [1:0]  sram_htrans;
  wire [31:0] sram_hwdata;
  wire        sram_hwrite;
  wire        sram_hready;
  wire [31:0] sram_hrdata;
  wire        sram_hreadyout;
  wire [1:0]  sram_hresp;

  wire        mmio_hsel;
  wire [31:0] mmio_haddr;
  wire [2:0]  mmio_hburst;
  wire [3:0]  mmio_hprot;
  wire [2:0]  mmio_hsize;
  wire [1:0]  mmio_htrans;
  wire [31:0] mmio_hwdata;
  wire        mmio_hwrite;
  wire        mmio_hready;
  wire [31:0] mmio_hrdata;
  wire        mmio_hreadyout;
  wire [1:0]  mmio_hresp;

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
  wire        dbg_bus_error;

  logic [31:0] rom [0:255];
  logic [31:0] sram [0:255];
  logic [31:0] mmio_reg;
  wire         ahb_decode_error;
  string rom_memh;
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

    sram[1]  = 32'd7;
    mmio_reg = 32'd0;

    if (!$value$plusargs("ROM_MEMH=%s", rom_memh)) begin
      rom_memh = "../software/bin/cached_ahb_master.memh";
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
  assign mmio_rdata = mmio_reg;

  always @(posedge clk) begin
    if (rom_valid && rom_ready && rom_write) begin
      $fatal(1, "unexpected ROM write through external AHB bus");
    end

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

  rv32i_cached_ahb_master_top #(
    .ICACHE_INDEX_BITS(2),
    .DCACHE_INDEX_BITS(2)
  ) u_cpu (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .timer_irq              (1'b0),
    .ahb_haddr              (ahb_haddr),
    .ahb_hburst             (ahb_hburst),
    .ahb_hprot              (ahb_hprot),
    .ahb_hsize              (ahb_hsize),
    .ahb_htrans             (ahb_htrans),
    .ahb_hwdata             (ahb_hwdata),
    .ahb_hwrite             (ahb_hwrite),
    .ahb_hrdata             (ahb_hrdata),
    .ahb_hready             (ahb_hready),
    .ahb_hresp              (ahb_hresp),
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
    .dbg_bus_error          (dbg_bus_error)
  );

  rv32i_ahb_lite_decoder u_ahb_decoder (
    .clk              (clk),
    .rst_n            (rst_n),
    .m_haddr          (ahb_haddr),
    .m_hburst         (ahb_hburst),
    .m_hprot          (ahb_hprot),
    .m_hsize          (ahb_hsize),
    .m_htrans         (ahb_htrans),
    .m_hwdata         (ahb_hwdata),
    .m_hwrite         (ahb_hwrite),
    .m_hrdata         (ahb_hrdata),
    .m_hready         (ahb_hready),
    .m_hresp          (ahb_hresp),
    .s0_hsel          (rom_hsel),
    .s0_haddr         (rom_haddr),
    .s0_hburst        (rom_hburst),
    .s0_hprot         (rom_hprot),
    .s0_hsize         (rom_hsize),
    .s0_htrans        (rom_htrans),
    .s0_hwdata        (rom_hwdata),
    .s0_hwrite        (rom_hwrite),
    .s0_hready        (rom_hready),
    .s0_hrdata        (rom_hrdata),
    .s0_hreadyout     (rom_hreadyout),
    .s0_hresp         (rom_hresp),
    .s1_hsel          (sram_hsel),
    .s1_haddr         (sram_haddr),
    .s1_hburst        (sram_hburst),
    .s1_hprot         (sram_hprot),
    .s1_hsize         (sram_hsize),
    .s1_htrans        (sram_htrans),
    .s1_hwdata        (sram_hwdata),
    .s1_hwrite        (sram_hwrite),
    .s1_hready        (sram_hready),
    .s1_hrdata        (sram_hrdata),
    .s1_hreadyout     (sram_hreadyout),
    .s1_hresp         (sram_hresp),
    .s2_hsel          (mmio_hsel),
    .s2_haddr         (mmio_haddr),
    .s2_hburst        (mmio_hburst),
    .s2_hprot         (mmio_hprot),
    .s2_hsize         (mmio_hsize),
    .s2_htrans        (mmio_htrans),
    .s2_hwdata        (mmio_hwdata),
    .s2_hwrite        (mmio_hwrite),
    .s2_hready        (mmio_hready),
    .s2_hrdata        (mmio_hrdata),
    .s2_hreadyout     (mmio_hreadyout),
    .s2_hresp         (mmio_hresp),
    .dbg_decode_error (ahb_decode_error)
  );

  rv32i_ahb_to_simple u_rom_ahb_to_simple (
    .clk       (clk),
    .rst_n     (rst_n),
    .hsel      (rom_hsel),
    .haddr     (rom_haddr),
    .hburst    (rom_hburst),
    .hprot     (rom_hprot),
    .hsize     (rom_hsize),
    .htrans    (rom_htrans),
    .hwdata    (rom_hwdata),
    .hwrite    (rom_hwrite),
    .hready    (rom_hready),
    .hrdata    (rom_hrdata),
    .hreadyout (rom_hreadyout),
    .hresp     (rom_hresp),
    .valid     (rom_valid),
    .write     (rom_write),
    .addr      (rom_addr),
    .wdata     (rom_wdata),
    .wstrb     (rom_wstrb),
    .ready     (rom_ready),
    .rdata     (rom_rdata),
    .error     (1'b0)
  );

  rv32i_ahb_to_simple u_sram_ahb_to_simple (
    .clk       (clk),
    .rst_n     (rst_n),
    .hsel      (sram_hsel),
    .haddr     (sram_haddr),
    .hburst    (sram_hburst),
    .hprot     (sram_hprot),
    .hsize     (sram_hsize),
    .htrans    (sram_htrans),
    .hwdata    (sram_hwdata),
    .hwrite    (sram_hwrite),
    .hready    (sram_hready),
    .hrdata    (sram_hrdata),
    .hreadyout (sram_hreadyout),
    .hresp     (sram_hresp),
    .valid     (sram_valid),
    .write     (sram_write),
    .addr      (sram_addr),
    .wdata     (sram_wdata),
    .wstrb     (sram_wstrb),
    .ready     (sram_ready),
    .rdata     (sram_rdata),
    .error     (1'b0)
  );

  rv32i_ahb_to_simple u_mmio_ahb_to_simple (
    .clk       (clk),
    .rst_n     (rst_n),
    .hsel      (mmio_hsel),
    .haddr     (mmio_haddr),
    .hburst    (mmio_hburst),
    .hprot     (mmio_hprot),
    .hsize     (mmio_hsize),
    .htrans    (mmio_htrans),
    .hwdata    (mmio_hwdata),
    .hwrite    (mmio_hwrite),
    .hready    (mmio_hready),
    .hrdata    (mmio_hrdata),
    .hreadyout (mmio_hreadyout),
    .hresp     (mmio_hresp),
    .valid     (mmio_valid),
    .write     (mmio_write),
    .addr      (mmio_addr),
    .wdata     (mmio_wdata),
    .wstrb     (mmio_wstrb),
    .ready     (mmio_ready),
    .rdata     (mmio_rdata),
    .error     (1'b0)
  );

  initial begin
    dbg_reg_addr = 5'd0;
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    timeout = 0;
    while (!dbg_ebreak && (timeout < 520)) begin
      @(posedge clk);
      #1ps;
      timeout = timeout + 1;
    end

    if (!dbg_ebreak) begin
      $fatal(1, "timeout waiting for cached AHB master top ebreak");
    end
    if (dbg_illegal_instr || dbg_ecall || dbg_bus_error || ahb_decode_error) begin
      $fatal(1, "unexpected trap or bus event in cached AHB master top test");
    end

    check_reg(5'd1,  32'h2000_0000, "x1");
    check_reg(5'd2,  32'd7,         "x2");
    check_reg(5'd3,  32'd12,        "x3");
    check_reg(5'd4,  32'd12,        "x4");
    check_reg(5'd10, 32'h4000_0000, "x10");
    check_reg(5'd11, 32'h5a,        "x11");
    check_reg(5'd12, 32'h5a,        "x12");
    check_reg(5'd13, 32'h66,        "x13");

    if (sram[2] !== 32'd12) begin
      $fatal(1, "sram[2] mismatch: expected 12, got 0x%08x", sram[2]);
    end
    if (mmio_reg !== 32'h5a) begin
      $fatal(1, "mmio_reg mismatch: expected 0x5a, got 0x%08x", mmio_reg);
    end
    if (dbg_instret !== 32'd11) begin
      $fatal(1, "instret mismatch: expected 11, got %0d", dbg_instret);
    end
    if ((dbg_bus_i_grant_count == 32'd0) || (dbg_bus_d_grant_count == 32'd0)) begin
      $fatal(1, "expected I and D AHB master grants");
    end

    $display("[PASS] rv32i_cached_ahb_master_top_tb");
    $display("  pc=0x%08x cycle=%0d instret=%0d stall_cycle=%0d",
             dbg_pc, dbg_cycle, dbg_instret, dbg_stall_cycle);
    $display("  bus_i_grants=%0d bus_d_grants=%0d icache_miss=%0d dcache_miss=%0d",
             dbg_bus_i_grant_count, dbg_bus_d_grant_count,
             dbg_icache_miss_count, dbg_dcache_miss_count);
    $display("  CPU subsystem exposes AHB-Lite master and external AHB slaves passed");
    $finish;
  end

endmodule
