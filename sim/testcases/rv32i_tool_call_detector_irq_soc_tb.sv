`timescale 1ns/1ps

module rv32i_tool_call_detector_irq_soc_tb;

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

  wire        uart_tx_valid;
  wire [7:0]  uart_tx_data;
  wire        timer_irq;
  wire        agent_matrix_irq;
  wire        tool_call_irq;
  wire        cpu_timer_irq;

  wire [31:0] dbg_pc;
  wire [31:0] dbg_cycle;
  wire [31:0] dbg_instret;
  wire [31:0] dbg_stall_cycle;
  wire [31:0] dbg_flush_cycle;
  wire [31:0] dbg_branch_count;
  wire [31:0] dbg_branch_mispredict_count;
  wire [31:0] dbg_btb_hit_count;
  wire [31:0] dbg_btb_miss_count;
  wire [31:0] dbg_bht_update_count;
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
  wire        dbg_apb_decode_error;
  wire [31:0] dbg_matrix_m0_grant_count;
  wire [31:0] dbg_matrix_m1_grant_count;
  wire [31:0] dbg_agent_irq_status;
  wire [31:0] dbg_timer_mtime_lo;
  wire [31:0] dbg_timer_mtime_hi;
  wire [31:0] dbg_timer_mtimecmp_lo;
  wire [31:0] dbg_timer_mtimecmp_hi;
  wire [31:0] dbg_timer_ctrl;
  wire [31:0] dbg_uart_tx_count;
  wire [7:0]  dbg_uart_last_tx;
  wire [31:0] dbg_agent_matrix_status;
  wire [31:0] dbg_agent_matrix_result0;
  wire [31:0] dbg_agent_matrix_result1;
  wire [31:0] dbg_agent_matrix_result2;
  wire [31:0] dbg_agent_matrix_result3;
  wire [31:0] dbg_agent_matrix_start_count;
  wire [31:0] dbg_tool_call_status;
  wire [31:0] dbg_tool_call_match_count;
  wire [31:0] dbg_tool_call_token_count;
  wire [31:0] dbg_tool_call_last_token;

  logic [31:0] flash [0:511];
  logic [31:0] sram [0:255];
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
    for (i = 0; i < 512; i = i + 1) begin
      flash[i] = 32'h0000_0013; // addi x0, x0, 0
    end
    for (i = 0; i < 256; i = i + 1) begin
      sram[i] = 32'd0;
    end

    if (!$value$plusargs("FLASH_MEMH=%s", flash_memh)) begin
      flash_memh = "../software/bin/tool_call_detector_irq.memh";
    end

    memh_fd = $fopen(flash_memh, "r");
    if (memh_fd == 0) begin
      $fatal(1, "failed to open FLASH_MEMH='%s'", flash_memh);
    end
    $fclose(memh_fd);
    $readmemh(flash_memh, flash);
  end

  assign flash_hrdata    = flash[flash_haddr[10:2]];
  assign flash_hreadyout = 1'b1;
  assign flash_hresp     = 2'b00;

  assign sram_hrdata     = sram[sram_haddr[9:2]];
  assign sram_hreadyout  = 1'b1;
  assign sram_hresp      = 2'b00;

  assign ahb_periph_hrdata    = 32'd0;
  assign ahb_periph_hreadyout = 1'b1;
  assign ahb_periph_hresp     = 2'b00;

  always @(posedge clk) begin
    if (flash_hsel && flash_hwrite) begin
      $fatal(1, "unexpected flash write in tool-call detector IRQ test");
    end
    if (ahb_periph_hsel) begin
      $fatal(1, "unexpected AHB peripheral access in tool-call detector IRQ test");
    end
    if (sram_hsel && sram_hwrite) begin
      if (sram_hsize != 3'b010) begin
        $fatal(1, "unexpected non-word SRAM write in tool-call detector IRQ test");
      end
      if (^sram_hwdata === 1'bx) begin
        $fatal(1, "unexpected X SRAM write data");
      end
      sram[sram_haddr[9:2]] <= sram_hwdata;
    end
  end

  rv32i_ahb_matrix_apb_soc_top #(
    .ICACHE_INDEX_BITS(2),
    .DCACHE_INDEX_BITS(2),
    .RESET_PC(32'h0800_0000)
  ) u_top (
    .clk                         (clk),
    .rst_n                       (rst_n),
    .flash_hsel                  (flash_hsel),
    .flash_haddr                 (flash_haddr),
    .flash_hburst                (flash_hburst),
    .flash_hprot                 (flash_hprot),
    .flash_hsize                 (flash_hsize),
    .flash_htrans                (flash_htrans),
    .flash_hwdata                (flash_hwdata),
    .flash_hwrite                (flash_hwrite),
    .flash_hready                (flash_hready),
    .flash_hrdata                (flash_hrdata),
    .flash_hreadyout             (flash_hreadyout),
    .flash_hresp                 (flash_hresp),
    .sram_hsel                   (sram_hsel),
    .sram_haddr                  (sram_haddr),
    .sram_hburst                 (sram_hburst),
    .sram_hprot                  (sram_hprot),
    .sram_hsize                  (sram_hsize),
    .sram_htrans                 (sram_htrans),
    .sram_hwdata                 (sram_hwdata),
    .sram_hwrite                 (sram_hwrite),
    .sram_hready                 (sram_hready),
    .sram_hrdata                 (sram_hrdata),
    .sram_hreadyout              (sram_hreadyout),
    .sram_hresp                  (sram_hresp),
    .ahb_periph_hsel             (ahb_periph_hsel),
    .ahb_periph_haddr            (ahb_periph_haddr),
    .ahb_periph_hburst           (ahb_periph_hburst),
    .ahb_periph_hprot            (ahb_periph_hprot),
    .ahb_periph_hsize            (ahb_periph_hsize),
    .ahb_periph_htrans           (ahb_periph_htrans),
    .ahb_periph_hwdata           (ahb_periph_hwdata),
    .ahb_periph_hwrite           (ahb_periph_hwrite),
    .ahb_periph_hready           (ahb_periph_hready),
    .ahb_periph_hrdata           (ahb_periph_hrdata),
    .ahb_periph_hreadyout        (ahb_periph_hreadyout),
    .ahb_periph_hresp            (ahb_periph_hresp),
    .uart_tx_valid               (uart_tx_valid),
    .uart_tx_data                (uart_tx_data),
    .timer_irq                   (timer_irq),
    .agent_matrix_irq            (agent_matrix_irq),
    .tool_call_irq               (tool_call_irq),
    .cpu_timer_irq               (cpu_timer_irq),
    .dbg_pc                      (dbg_pc),
    .dbg_cycle                   (dbg_cycle),
    .dbg_instret                 (dbg_instret),
    .dbg_stall_cycle             (dbg_stall_cycle),
    .dbg_flush_cycle             (dbg_flush_cycle),
    .dbg_branch_count            (dbg_branch_count),
    .dbg_branch_mispredict_count (dbg_branch_mispredict_count),
    .dbg_btb_hit_count           (dbg_btb_hit_count),
    .dbg_btb_miss_count          (dbg_btb_miss_count),
    .dbg_bht_update_count        (dbg_bht_update_count),
    .dbg_reg_addr                (dbg_reg_addr),
    .dbg_reg_rdata               (dbg_reg_rdata),
    .dbg_illegal_instr           (dbg_illegal_instr),
    .dbg_ecall                   (dbg_ecall),
    .dbg_ebreak                  (dbg_ebreak),
    .dbg_icache_hit_count        (dbg_icache_hit_count),
    .dbg_icache_miss_count       (dbg_icache_miss_count),
    .dbg_dcache_hit_count        (dbg_dcache_hit_count),
    .dbg_dcache_miss_count       (dbg_dcache_miss_count),
    .dbg_bus_i_grant_count       (dbg_bus_i_grant_count),
    .dbg_bus_d_grant_count       (dbg_bus_d_grant_count),
    .dbg_cpu_bus_error           (dbg_cpu_bus_error),
    .dbg_matrix_decode_error     (dbg_matrix_decode_error),
    .dbg_apb_decode_error        (dbg_apb_decode_error),
    .dbg_matrix_m0_grant_count   (dbg_matrix_m0_grant_count),
    .dbg_matrix_m1_grant_count   (dbg_matrix_m1_grant_count),
    .dbg_agent_irq_status        (dbg_agent_irq_status),
    .dbg_timer_mtime_lo          (dbg_timer_mtime_lo),
    .dbg_timer_mtime_hi          (dbg_timer_mtime_hi),
    .dbg_timer_mtimecmp_lo       (dbg_timer_mtimecmp_lo),
    .dbg_timer_mtimecmp_hi       (dbg_timer_mtimecmp_hi),
    .dbg_timer_ctrl              (dbg_timer_ctrl),
    .dbg_uart_tx_count           (dbg_uart_tx_count),
    .dbg_uart_last_tx            (dbg_uart_last_tx),
    .dbg_agent_matrix_status     (dbg_agent_matrix_status),
    .dbg_agent_matrix_result0    (dbg_agent_matrix_result0),
    .dbg_agent_matrix_result1    (dbg_agent_matrix_result1),
    .dbg_agent_matrix_result2    (dbg_agent_matrix_result2),
    .dbg_agent_matrix_result3    (dbg_agent_matrix_result3),
    .dbg_agent_matrix_start_count(dbg_agent_matrix_start_count),
    .dbg_tool_call_status        (dbg_tool_call_status),
    .dbg_tool_call_match_count   (dbg_tool_call_match_count),
    .dbg_tool_call_token_count   (dbg_tool_call_token_count),
    .dbg_tool_call_last_token    (dbg_tool_call_last_token)
  );

  initial begin
    dbg_reg_addr = 5'd0;
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    timeout = 0;
    while (!dbg_ebreak && (timeout < 5000)) begin
      @(posedge clk);
      #1ps;
      timeout = timeout + 1;
    end

    if (!dbg_ebreak) begin
      $fatal(1, "timeout waiting for tool-call detector IRQ ebreak");
    end
    if (dbg_illegal_instr || dbg_ecall ||
        dbg_cpu_bus_error || dbg_matrix_decode_error || dbg_apb_decode_error) begin
      $fatal(1, "unexpected trap or bus error in tool-call detector IRQ test");
    end

    check_reg(5'd10, 32'h8000_0007, "x10 handler mcause");
    check_reg(5'd12, 32'h0000_0080, "x12 handler mstatus");
    check_reg(5'd13, 32'h0000_0080, "x13 handler mie");
    check_reg(5'd14, 32'h0000_0080, "x14 handler mip");
    check_reg(5'd15, 32'd1,         "x15 tool IRQ_STATUS before clear");
    check_reg(5'd21, 32'h0000_0077, "x21 main resumed after mret");
    check_reg(5'd29, 32'ha700_0004, "x29 tool-call IRQ signature");
    check_reg(5'd30, 32'd0,         "x30 failure code");
    check_reg(5'd31, 32'd1,         "x31 interrupt handler marker");

    if (sram[0] !== 32'h8000_0007) begin
      $fatal(1, "mcause mismatch: expected machine timer interrupt, got 0x%08x", sram[0]);
    end
    if ((sram[1][1:0] !== 2'b00) ||
        (sram[1] < 32'h0800_0000) ||
        (sram[1] > 32'h0800_013c)) begin
      $fatal(1, "mepc out of expected flash main-program window: 0x%08x", sram[1]);
    end
    if (sram[2] !== 32'h0000_0080 ||
        sram[3] !== 32'h0000_0080 ||
        sram[4] !== 32'h0000_0080 ||
        sram[5] !== 32'd1) begin
      $fatal(1, "handler CSR/source record mismatch: mstatus=0x%08x mie=0x%08x mip=0x%08x irq_status=0x%08x",
             sram[2], sram[3], sram[4], sram[5]);
    end

    if (timer_irq || agent_matrix_irq || tool_call_irq || cpu_timer_irq) begin
      $fatal(1, "unexpected IRQ output after tool-call detector IRQ clear");
    end
    if (dbg_agent_irq_status !== 32'd0) begin
      $fatal(1, "IRQ aggregator status should be idle, got 0x%08x", dbg_agent_irq_status);
    end
    if (dbg_tool_call_status !== 32'h0000_0003 ||
        dbg_tool_call_match_count !== 32'd1 ||
        dbg_tool_call_token_count !== 32'd8 ||
        dbg_tool_call_last_token !== 32'h0000_1004) begin
      $fatal(1, "tool-call detector debug mismatch after IRQ handler");
    end
    if (dbg_agent_matrix_start_count !== 32'd0) begin
      $fatal(1, "agent matrix should remain idle in tool-call detector IRQ test");
    end
    if (uart_tx_valid || (dbg_uart_tx_count !== 32'd0)) begin
      $fatal(1, "unexpected UART activity in tool-call detector IRQ test");
    end

    $display("[PASS] rv32i_tool_call_detector_irq_soc_tb");
    $display("  pc=0x%08x cycle=%0d instret=%0d stall_cycle=%0d flush_cycle=%0d",
             dbg_pc, dbg_cycle, dbg_instret, dbg_stall_cycle, dbg_flush_cycle);
    $display("  mcause=0x%08x mepc=0x%08x mstatus=0x%08x mie=0x%08x mip=0x%08x tool_irq_status=0x%08x",
             sram[0], sram[1], sram[2], sram[3], sram[4], sram[5]);
    $display("  detector status=0x%08x match_count=%0d token_count=%0d irq_agg=0x%08x",
             dbg_tool_call_status, dbg_tool_call_match_count,
             dbg_tool_call_token_count, dbg_agent_irq_status);
    $finish;
  end

endmodule
