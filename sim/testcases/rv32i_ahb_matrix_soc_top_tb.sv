`timescale 1ns/1ps

module rv32i_ahb_matrix_soc_top_tb;

  localparam CLK_PERIOD_NS = 10;

  logic clk;
  logic rst_n;

  wire        flash_hsel;
  wire [31:0] flash_haddr;
  wire [2:0]  flash_hburst;
  wire [3:0]  flash_hprot;
  wire [2:0]  flash_hsize;
  wire [1:0]  flash_htrans;
  wire [31:0] flash_hwdata;
  wire        flash_hwrite;
  wire        flash_hready;
  wire [31:0] flash_hrdata;
  wire        flash_hreadyout;
  wire [1:0]  flash_hresp;

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

  wire        ahb_periph_hsel;
  wire [31:0] ahb_periph_haddr;
  wire [2:0]  ahb_periph_hburst;
  wire [3:0]  ahb_periph_hprot;
  wire [2:0]  ahb_periph_hsize;
  wire [1:0]  ahb_periph_htrans;
  wire [31:0] ahb_periph_hwdata;
  wire        ahb_periph_hwrite;
  wire        ahb_periph_hready;
  wire [31:0] ahb_periph_hrdata;
  wire        ahb_periph_hreadyout;
  wire [1:0]  ahb_periph_hresp;

  wire        apb_periph_hsel;
  wire [31:0] apb_periph_haddr;
  wire [2:0]  apb_periph_hburst;
  wire [3:0]  apb_periph_hprot;
  wire [2:0]  apb_periph_hsize;
  wire [1:0]  apb_periph_htrans;
  wire [31:0] apb_periph_hwdata;
  wire        apb_periph_hwrite;
  wire        apb_periph_hready;
  wire [31:0] apb_periph_hrdata;
  wire        apb_periph_hreadyout;
  wire [1:0]  apb_periph_hresp;

  wire        flash_valid;
  wire        flash_write;
  wire [31:0] flash_addr;
  wire [31:0] flash_wdata;
  wire [3:0]  flash_wstrb;
  wire        flash_ready;
  wire [31:0] flash_rdata;

  wire        sram_valid;
  wire        sram_write;
  wire [31:0] sram_addr;
  wire [31:0] sram_wdata;
  wire [3:0]  sram_wstrb;
  wire        sram_ready;
  wire [31:0] sram_rdata;

  wire        ahb_periph_valid;
  wire        ahb_periph_write;
  wire [31:0] ahb_periph_addr;
  wire [31:0] ahb_periph_wdata;
  wire [3:0]  ahb_periph_wstrb;
  wire        ahb_periph_ready;
  wire [31:0] ahb_periph_rdata;

  wire        apb_periph_valid;
  wire        apb_periph_write;
  wire [31:0] apb_periph_addr;
  wire [31:0] apb_periph_wdata;
  wire [3:0]  apb_periph_wstrb;
  wire        apb_periph_ready;
  wire [31:0] apb_periph_rdata;

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
  wire        dbg_cpu_bus_error;
  wire        dbg_matrix_decode_error;

  logic [31:0] flash [0:255];
  logic [31:0] sram [0:255];
  logic [31:0] ahb_periph_reg;
  logic [31:0] apb_periph_reg;
  string flash_memh;
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
      flash[i] = 32'h0000_0013; // addi x0, x0, 0
      sram[i]  = 32'h3000_0000 + i;
    end

    sram[1] = 32'd7;
    ahb_periph_reg = 32'd0;
    apb_periph_reg = 32'd0;

    if (!$value$plusargs("FLASH_MEMH=%s", flash_memh)) begin
      flash_memh = "../software/bin/ahb_matrix_soc.memh";
    end

    memh_fd = $fopen(flash_memh, "r");
    if (memh_fd == 0) begin
      $fatal(1, "failed to open FLASH_MEMH='%s'", flash_memh);
    end
    $fclose(memh_fd);
    $readmemh(flash_memh, flash);
  end

  assign flash_ready = flash_valid;
  assign flash_rdata = flash[flash_addr[9:2]];

  assign sram_ready = sram_valid;
  assign sram_rdata = sram[sram_addr[9:2]];

  assign ahb_periph_ready = ahb_periph_valid;
  assign ahb_periph_rdata = ahb_periph_reg;

  assign apb_periph_ready = apb_periph_valid;
  assign apb_periph_rdata = apb_periph_reg;

  always @(posedge clk) begin
    if (flash_valid && flash_ready && flash_write) begin
      $fatal(1, "unexpected flash write in AHB matrix SoC test");
    end

    if (sram_valid && sram_ready && sram_write) begin
      if (sram_wstrb[0]) sram[sram_addr[9:2]][7:0]   <= sram_wdata[7:0];
      if (sram_wstrb[1]) sram[sram_addr[9:2]][15:8]  <= sram_wdata[15:8];
      if (sram_wstrb[2]) sram[sram_addr[9:2]][23:16] <= sram_wdata[23:16];
      if (sram_wstrb[3]) sram[sram_addr[9:2]][31:24] <= sram_wdata[31:24];
    end

    if (ahb_periph_valid && ahb_periph_ready && ahb_periph_write) begin
      if (ahb_periph_wstrb[0]) ahb_periph_reg[7:0]   <= ahb_periph_wdata[7:0];
      if (ahb_periph_wstrb[1]) ahb_periph_reg[15:8]  <= ahb_periph_wdata[15:8];
      if (ahb_periph_wstrb[2]) ahb_periph_reg[23:16] <= ahb_periph_wdata[23:16];
      if (ahb_periph_wstrb[3]) ahb_periph_reg[31:24] <= ahb_periph_wdata[31:24];
    end

    if (apb_periph_valid && apb_periph_ready && apb_periph_write) begin
      if (apb_periph_wstrb[0]) apb_periph_reg[7:0]   <= apb_periph_wdata[7:0];
      if (apb_periph_wstrb[1]) apb_periph_reg[15:8]  <= apb_periph_wdata[15:8];
      if (apb_periph_wstrb[2]) apb_periph_reg[23:16] <= apb_periph_wdata[23:16];
      if (apb_periph_wstrb[3]) apb_periph_reg[31:24] <= apb_periph_wdata[31:24];
    end
  end

  rv32i_ahb_matrix_soc_top #(
    .ICACHE_INDEX_BITS(2),
    .DCACHE_INDEX_BITS(2),
    .RESET_PC(32'h0800_0000)
  ) u_top (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .timer_irq              (1'b0),
    .flash_hsel             (flash_hsel),
    .flash_haddr            (flash_haddr),
    .flash_hburst           (flash_hburst),
    .flash_hprot            (flash_hprot),
    .flash_hsize            (flash_hsize),
    .flash_htrans           (flash_htrans),
    .flash_hwdata           (flash_hwdata),
    .flash_hwrite           (flash_hwrite),
    .flash_hready           (flash_hready),
    .flash_hrdata           (flash_hrdata),
    .flash_hreadyout        (flash_hreadyout),
    .flash_hresp            (flash_hresp),
    .sram_hsel              (sram_hsel),
    .sram_haddr             (sram_haddr),
    .sram_hburst            (sram_hburst),
    .sram_hprot             (sram_hprot),
    .sram_hsize             (sram_hsize),
    .sram_htrans            (sram_htrans),
    .sram_hwdata            (sram_hwdata),
    .sram_hwrite            (sram_hwrite),
    .sram_hready            (sram_hready),
    .sram_hrdata            (sram_hrdata),
    .sram_hreadyout         (sram_hreadyout),
    .sram_hresp             (sram_hresp),
    .ahb_periph_hsel        (ahb_periph_hsel),
    .ahb_periph_haddr       (ahb_periph_haddr),
    .ahb_periph_hburst      (ahb_periph_hburst),
    .ahb_periph_hprot       (ahb_periph_hprot),
    .ahb_periph_hsize       (ahb_periph_hsize),
    .ahb_periph_htrans      (ahb_periph_htrans),
    .ahb_periph_hwdata      (ahb_periph_hwdata),
    .ahb_periph_hwrite      (ahb_periph_hwrite),
    .ahb_periph_hready      (ahb_periph_hready),
    .ahb_periph_hrdata      (ahb_periph_hrdata),
    .ahb_periph_hreadyout   (ahb_periph_hreadyout),
    .ahb_periph_hresp       (ahb_periph_hresp),
    .apb_periph_hsel        (apb_periph_hsel),
    .apb_periph_haddr       (apb_periph_haddr),
    .apb_periph_hburst      (apb_periph_hburst),
    .apb_periph_hprot       (apb_periph_hprot),
    .apb_periph_hsize       (apb_periph_hsize),
    .apb_periph_htrans      (apb_periph_htrans),
    .apb_periph_hwdata      (apb_periph_hwdata),
    .apb_periph_hwrite      (apb_periph_hwrite),
    .apb_periph_hready      (apb_periph_hready),
    .apb_periph_hrdata      (apb_periph_hrdata),
    .apb_periph_hreadyout   (apb_periph_hreadyout),
    .apb_periph_hresp       (apb_periph_hresp),
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
    .dbg_cpu_bus_error      (dbg_cpu_bus_error),
    .dbg_matrix_decode_error(dbg_matrix_decode_error)
  );

  rv32i_ahb_to_simple u_flash_ahb_to_simple (
    .clk       (clk),
    .rst_n     (rst_n),
    .hsel      (flash_hsel),
    .haddr     (flash_haddr),
    .hburst    (flash_hburst),
    .hprot     (flash_hprot),
    .hsize     (flash_hsize),
    .htrans    (flash_htrans),
    .hwdata    (flash_hwdata),
    .hwrite    (flash_hwrite),
    .hready    (flash_hready),
    .hrdata    (flash_hrdata),
    .hreadyout (flash_hreadyout),
    .hresp     (flash_hresp),
    .valid     (flash_valid),
    .write     (flash_write),
    .addr      (flash_addr),
    .wdata     (flash_wdata),
    .wstrb     (flash_wstrb),
    .ready     (flash_ready),
    .rdata     (flash_rdata),
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

  rv32i_ahb_to_simple u_ahb_periph_ahb_to_simple (
    .clk       (clk),
    .rst_n     (rst_n),
    .hsel      (ahb_periph_hsel),
    .haddr     (ahb_periph_haddr),
    .hburst    (ahb_periph_hburst),
    .hprot     (ahb_periph_hprot),
    .hsize     (ahb_periph_hsize),
    .htrans    (ahb_periph_htrans),
    .hwdata    (ahb_periph_hwdata),
    .hwrite    (ahb_periph_hwrite),
    .hready    (ahb_periph_hready),
    .hrdata    (ahb_periph_hrdata),
    .hreadyout (ahb_periph_hreadyout),
    .hresp     (ahb_periph_hresp),
    .valid     (ahb_periph_valid),
    .write     (ahb_periph_write),
    .addr      (ahb_periph_addr),
    .wdata     (ahb_periph_wdata),
    .wstrb     (ahb_periph_wstrb),
    .ready     (ahb_periph_ready),
    .rdata     (ahb_periph_rdata),
    .error     (1'b0)
  );

  rv32i_ahb_to_simple u_apb_periph_ahb_to_simple (
    .clk       (clk),
    .rst_n     (rst_n),
    .hsel      (apb_periph_hsel),
    .haddr     (apb_periph_haddr),
    .hburst    (apb_periph_hburst),
    .hprot     (apb_periph_hprot),
    .hsize     (apb_periph_hsize),
    .htrans    (apb_periph_htrans),
    .hwdata    (apb_periph_hwdata),
    .hwrite    (apb_periph_hwrite),
    .hready    (apb_periph_hready),
    .hrdata    (apb_periph_hrdata),
    .hreadyout (apb_periph_hreadyout),
    .hresp     (apb_periph_hresp),
    .valid     (apb_periph_valid),
    .write     (apb_periph_write),
    .addr      (apb_periph_addr),
    .wdata     (apb_periph_wdata),
    .wstrb     (apb_periph_wstrb),
    .ready     (apb_periph_ready),
    .rdata     (apb_periph_rdata),
    .error     (1'b0)
  );

  initial begin
    dbg_reg_addr = 5'd0;
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    timeout = 0;
    while (!dbg_ebreak && (timeout < 650)) begin
      @(posedge clk);
      #1ps;
      timeout = timeout + 1;
    end

    if (!dbg_ebreak) begin
      $fatal(1, "timeout waiting for AHB matrix SoC top ebreak");
    end
    if (dbg_illegal_instr || dbg_ecall || dbg_cpu_bus_error || dbg_matrix_decode_error) begin
      $fatal(1, "unexpected trap or bus event in AHB matrix SoC top test");
    end

    check_reg(5'd1,  32'h2000_0000, "x1");
    check_reg(5'd2,  32'd7,         "x2");
    check_reg(5'd3,  32'd12,        "x3");
    check_reg(5'd4,  32'd12,        "x4");
    check_reg(5'd10, 32'h4000_0000, "x10");
    check_reg(5'd11, 32'h5a,        "x11");
    check_reg(5'd12, 32'h5a,        "x12");
    check_reg(5'd13, 32'h66,        "x13");
    check_reg(5'd14, 32'h4200_0000, "x14");
    check_reg(5'd15, 32'h33,        "x15");
    check_reg(5'd16, 32'h33,        "x16");
    check_reg(5'd17, 32'h99,        "x17");

    if (sram[2] !== 32'd12) begin
      $fatal(1, "sram[2] mismatch: expected 12, got 0x%08x", sram[2]);
    end
    if (ahb_periph_reg !== 32'h5a) begin
      $fatal(1, "ahb_periph_reg mismatch: expected 0x5a, got 0x%08x", ahb_periph_reg);
    end
    if (apb_periph_reg !== 32'h33) begin
      $fatal(1, "apb_periph_reg mismatch: expected 0x33, got 0x%08x", apb_periph_reg);
    end
    if (dbg_instret !== 32'd16) begin
      $fatal(1, "instret mismatch: expected 16, got %0d", dbg_instret);
    end
    if ((dbg_bus_i_grant_count == 32'd0) || (dbg_bus_d_grant_count == 32'd0)) begin
      $fatal(1, "expected I and D AHB master grants");
    end

    $display("[PASS] rv32i_ahb_matrix_soc_top_tb");
    $display("  pc=0x%08x cycle=%0d instret=%0d stall_cycle=%0d",
             dbg_pc, dbg_cycle, dbg_instret, dbg_stall_cycle);
    $display("  bus_i_grants=%0d bus_d_grants=%0d icache_miss=%0d dcache_miss=%0d",
             dbg_bus_i_grant_count, dbg_bus_d_grant_count,
             dbg_icache_miss_count, dbg_dcache_miss_count);
    $display("  clean-room AHB-Lite matrix SoC top routed flash/SRAM/AHB/APB slots");
    $finish;
  end

endmodule
