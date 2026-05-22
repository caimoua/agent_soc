`timescale 1ns/1ps

module rv32i_agent_event_counter_soc_tb;

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
  wire [31:0] dbg_agent_event_status;
  wire [31:0] dbg_agent_event_tool_token_count;
  wire [31:0] dbg_agent_event_tool_match_count;
  wire [31:0] dbg_agent_event_tool_irq_count;
  wire [31:0] dbg_agent_event_matrix_start_count;
  wire [31:0] dbg_agent_event_matrix_done_count;
  wire [31:0] dbg_agent_event_agent_irq_count;
  wire [31:0] dbg_agent_event_last_irq_source;
  wire [31:0] dbg_agent_event_latency_last;

  logic [31:0] flash [0:511];
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

    if (!$value$plusargs("FLASH_MEMH=%s", flash_memh)) begin
      flash_memh = "../software/bin/agent_event_counter.memh";
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

  assign sram_hrdata     = 32'd0;
  assign sram_hreadyout  = 1'b1;
  assign sram_hresp      = 2'b00;

  assign ahb_periph_hrdata    = 32'd0;
  assign ahb_periph_hreadyout = 1'b1;
  assign ahb_periph_hresp     = 2'b00;

  always @(posedge clk) begin
    if (flash_hsel && flash_hwrite) begin
      $fatal(1, "unexpected flash write in agent event counter test");
    end
    if (sram_hsel) begin
      $fatal(1, "unexpected SRAM access in agent event counter test");
    end
    if (ahb_periph_hsel) begin
      $fatal(1, "unexpected AHB peripheral access in agent event counter test");
    end
  end

  rv32i_ahb_matrix_apb_soc_top #(
    .ICACHE_INDEX_BITS(2),
    .DCACHE_INDEX_BITS(2),
    .RESET_PC(32'h0800_0000)
  ) u_top (
    .clk                                  (clk),
    .rst_n                                (rst_n),
    .flash_hsel                           (flash_hsel),
    .flash_haddr                          (flash_haddr),
    .flash_hburst                         (flash_hburst),
    .flash_hprot                          (flash_hprot),
    .flash_hsize                          (flash_hsize),
    .flash_htrans                         (flash_htrans),
    .flash_hwdata                         (flash_hwdata),
    .flash_hwrite                         (flash_hwrite),
    .flash_hready                         (flash_hready),
    .flash_hrdata                         (flash_hrdata),
    .flash_hreadyout                      (flash_hreadyout),
    .flash_hresp                          (flash_hresp),
    .sram_hsel                            (sram_hsel),
    .sram_haddr                           (sram_haddr),
    .sram_hburst                          (sram_hburst),
    .sram_hprot                           (sram_hprot),
    .sram_hsize                           (sram_hsize),
    .sram_htrans                          (sram_htrans),
    .sram_hwdata                          (sram_hwdata),
    .sram_hwrite                          (sram_hwrite),
    .sram_hready                          (sram_hready),
    .sram_hrdata                          (sram_hrdata),
    .sram_hreadyout                       (sram_hreadyout),
    .sram_hresp                           (sram_hresp),
    .ahb_periph_hsel                      (ahb_periph_hsel),
    .ahb_periph_haddr                     (ahb_periph_haddr),
    .ahb_periph_hburst                    (ahb_periph_hburst),
    .ahb_periph_hprot                     (ahb_periph_hprot),
    .ahb_periph_hsize                     (ahb_periph_hsize),
    .ahb_periph_htrans                    (ahb_periph_htrans),
    .ahb_periph_hwdata                    (ahb_periph_hwdata),
    .ahb_periph_hwrite                    (ahb_periph_hwrite),
    .ahb_periph_hready                    (ahb_periph_hready),
    .ahb_periph_hrdata                    (ahb_periph_hrdata),
    .ahb_periph_hreadyout                 (ahb_periph_hreadyout),
    .ahb_periph_hresp                     (ahb_periph_hresp),
    .uart_tx_valid                        (uart_tx_valid),
    .uart_tx_data                         (uart_tx_data),
    .timer_irq                            (timer_irq),
    .agent_matrix_irq                     (agent_matrix_irq),
    .tool_call_irq                        (tool_call_irq),
    .cpu_timer_irq                        (cpu_timer_irq),
    .dbg_pc                               (dbg_pc),
    .dbg_cycle                            (dbg_cycle),
    .dbg_instret                          (dbg_instret),
    .dbg_stall_cycle                      (dbg_stall_cycle),
    .dbg_flush_cycle                      (dbg_flush_cycle),
    .dbg_branch_count                     (dbg_branch_count),
    .dbg_branch_mispredict_count          (dbg_branch_mispredict_count),
    .dbg_btb_hit_count                    (dbg_btb_hit_count),
    .dbg_btb_miss_count                   (dbg_btb_miss_count),
    .dbg_bht_update_count                 (dbg_bht_update_count),
    .dbg_reg_addr                         (dbg_reg_addr),
    .dbg_reg_rdata                        (dbg_reg_rdata),
    .dbg_illegal_instr                    (dbg_illegal_instr),
    .dbg_ecall                            (dbg_ecall),
    .dbg_ebreak                           (dbg_ebreak),
    .dbg_icache_hit_count                 (dbg_icache_hit_count),
    .dbg_icache_miss_count                (dbg_icache_miss_count),
    .dbg_dcache_hit_count                 (dbg_dcache_hit_count),
    .dbg_dcache_miss_count                (dbg_dcache_miss_count),
    .dbg_bus_i_grant_count                (dbg_bus_i_grant_count),
    .dbg_bus_d_grant_count                (dbg_bus_d_grant_count),
    .dbg_cpu_bus_error                    (dbg_cpu_bus_error),
    .dbg_matrix_decode_error              (dbg_matrix_decode_error),
    .dbg_apb_decode_error                 (dbg_apb_decode_error),
    .dbg_matrix_m0_grant_count            (dbg_matrix_m0_grant_count),
    .dbg_matrix_m1_grant_count            (dbg_matrix_m1_grant_count),
    .dbg_agent_irq_status                 (dbg_agent_irq_status),
    .dbg_timer_mtime_lo                   (dbg_timer_mtime_lo),
    .dbg_timer_mtime_hi                   (dbg_timer_mtime_hi),
    .dbg_timer_mtimecmp_lo                (dbg_timer_mtimecmp_lo),
    .dbg_timer_mtimecmp_hi                (dbg_timer_mtimecmp_hi),
    .dbg_timer_ctrl                       (dbg_timer_ctrl),
    .dbg_uart_tx_count                    (dbg_uart_tx_count),
    .dbg_uart_last_tx                     (dbg_uart_last_tx),
    .dbg_agent_matrix_status              (dbg_agent_matrix_status),
    .dbg_agent_matrix_result0             (dbg_agent_matrix_result0),
    .dbg_agent_matrix_result1             (dbg_agent_matrix_result1),
    .dbg_agent_matrix_result2             (dbg_agent_matrix_result2),
    .dbg_agent_matrix_result3             (dbg_agent_matrix_result3),
    .dbg_agent_matrix_start_count         (dbg_agent_matrix_start_count),
    .dbg_tool_call_status                 (dbg_tool_call_status),
    .dbg_tool_call_match_count            (dbg_tool_call_match_count),
    .dbg_tool_call_token_count            (dbg_tool_call_token_count),
    .dbg_tool_call_last_token             (dbg_tool_call_last_token),
    .dbg_agent_event_status               (dbg_agent_event_status),
    .dbg_agent_event_tool_token_count     (dbg_agent_event_tool_token_count),
    .dbg_agent_event_tool_match_count     (dbg_agent_event_tool_match_count),
    .dbg_agent_event_tool_irq_count       (dbg_agent_event_tool_irq_count),
    .dbg_agent_event_matrix_start_count   (dbg_agent_event_matrix_start_count),
    .dbg_agent_event_matrix_done_count    (dbg_agent_event_matrix_done_count),
    .dbg_agent_event_agent_irq_count      (dbg_agent_event_agent_irq_count),
    .dbg_agent_event_last_irq_source      (dbg_agent_event_last_irq_source),
    .dbg_agent_event_latency_last         (dbg_agent_event_latency_last)
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
      $fatal(1, "timeout waiting for agent event counter ebreak");
    end
    if (dbg_illegal_instr || dbg_ecall ||
        dbg_cpu_bus_error || dbg_matrix_decode_error || dbg_apb_decode_error) begin
      $fatal(1, "unexpected trap or bus error in agent event counter test");
    end

    check_reg(5'd5,  32'd8,         "x5 tool_token_count");
    check_reg(5'd6,  32'd1,         "x6 tool_match_count");
    check_reg(5'd7,  32'd1,         "x7 tool_irq_count");
    check_reg(5'd8,  32'd1,         "x8 matrix_start_count");
    check_reg(5'd9,  32'd1,         "x9 matrix_done_count");
    check_reg(5'd10, 32'd2,         "x10 agent_irq_count");
    check_reg(5'd11, 32'h0000_000c, "x11 last_irq_source");
    check_reg(5'd13, 32'd1,         "x13 latency_count");
    check_reg(5'd14, 32'd1,         "x14 matrix_irq_count");
    check_reg(5'd15, 32'd0,         "x15 timer_irq_count");
    check_reg(5'd29, 32'ha800_0001, "x29 event counter signature");
    check_reg(5'd30, 32'd0,         "x30 failure code");
    check_reg(5'd31, 32'd1,         "x31 pass marker");

    dbg_reg_addr = 5'd12;
    #1ps;
    if (dbg_reg_rdata === 32'd0) begin
      $fatal(1, "latency_last should be nonzero");
    end

    if (dbg_agent_event_tool_token_count !== 32'd8 ||
        dbg_agent_event_tool_match_count !== 32'd1 ||
        dbg_agent_event_tool_irq_count !== 32'd1 ||
        dbg_agent_event_matrix_start_count !== 32'd1 ||
        dbg_agent_event_matrix_done_count !== 32'd1 ||
        dbg_agent_event_agent_irq_count !== 32'd2 ||
        dbg_agent_event_last_irq_source !== 32'h0000_000c ||
        dbg_agent_event_latency_last === 32'd0) begin
      $fatal(1, "agent event counter debug mismatch");
    end
    if (dbg_agent_event_status[7:0] !== 8'hc2) begin
      $fatal(1, "agent event status mismatch: got 0x%08x",
             dbg_agent_event_status);
    end
    if (timer_irq || agent_matrix_irq || tool_call_irq || cpu_timer_irq) begin
      $fatal(1, "unexpected IRQ output after event counter test clears IRQs");
    end
    if (dbg_tool_call_match_count !== 32'd1 ||
        dbg_tool_call_token_count !== 32'd8 ||
        dbg_agent_matrix_start_count !== 32'd1) begin
      $fatal(1, "source block debug counters mismatch");
    end
    if (uart_tx_valid || (dbg_uart_tx_count !== 32'd0)) begin
      $fatal(1, "unexpected UART activity in agent event counter test");
    end

    $display("[PASS] rv32i_agent_event_counter_soc_tb");
    $display("  pc=0x%08x cycle=%0d instret=%0d stall_cycle=%0d flush_cycle=%0d",
             dbg_pc, dbg_cycle, dbg_instret, dbg_stall_cycle, dbg_flush_cycle);
    $display("  event token=%0d match=%0d tool_irq=%0d matrix_start=%0d matrix_done=%0d agent_irq=%0d",
             dbg_agent_event_tool_token_count, dbg_agent_event_tool_match_count,
             dbg_agent_event_tool_irq_count, dbg_agent_event_matrix_start_count,
             dbg_agent_event_matrix_done_count, dbg_agent_event_agent_irq_count);
    $display("  last_irq_source=0x%08x latency_last=%0d status=0x%08x",
             dbg_agent_event_last_irq_source, dbg_agent_event_latency_last,
             dbg_agent_event_status);
    $finish;
  end

endmodule
