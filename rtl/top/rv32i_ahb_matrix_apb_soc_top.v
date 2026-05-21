module rv32i_ahb_matrix_apb_soc_top #(
  parameter ICACHE_INDEX_BITS = 2,
  parameter DCACHE_INDEX_BITS = 2,
  parameter [31:0] RESET_PC = 32'h0800_0000,
  parameter BRANCH_PRED_INDEX_BITS = 6
) (
  input  wire        clk,
  input  wire        rst_n,

  output wire        flash_hsel,
  output wire [31:0] flash_haddr,
  output wire [2:0]  flash_hburst,
  output wire [3:0]  flash_hprot,
  output wire [2:0]  flash_hsize,
  output wire [1:0]  flash_htrans,
  output wire [31:0] flash_hwdata,
  output wire        flash_hwrite,
  output wire        flash_hready,
  input  wire [31:0] flash_hrdata,
  input  wire        flash_hreadyout,
  input  wire [1:0]  flash_hresp,

  output wire        sram_hsel,
  output wire [31:0] sram_haddr,
  output wire [2:0]  sram_hburst,
  output wire [3:0]  sram_hprot,
  output wire [2:0]  sram_hsize,
  output wire [1:0]  sram_htrans,
  output wire [31:0] sram_hwdata,
  output wire        sram_hwrite,
  output wire        sram_hready,
  input  wire [31:0] sram_hrdata,
  input  wire        sram_hreadyout,
  input  wire [1:0]  sram_hresp,

  output wire        ahb_periph_hsel,
  output wire [31:0] ahb_periph_haddr,
  output wire [2:0]  ahb_periph_hburst,
  output wire [3:0]  ahb_periph_hprot,
  output wire [2:0]  ahb_periph_hsize,
  output wire [1:0]  ahb_periph_htrans,
  output wire [31:0] ahb_periph_hwdata,
  output wire        ahb_periph_hwrite,
  output wire        ahb_periph_hready,
  input  wire [31:0] ahb_periph_hrdata,
  input  wire        ahb_periph_hreadyout,
  input  wire [1:0]  ahb_periph_hresp,

  output wire        uart_tx_valid,
  output wire [7:0]  uart_tx_data,
  output wire        timer_irq,

  output wire [31:0] dbg_pc,
  output wire [31:0] dbg_cycle,
  output wire [31:0] dbg_instret,
  output wire [31:0] dbg_stall_cycle,
  output wire [31:0] dbg_flush_cycle,
  output wire [31:0] dbg_branch_count,
  output wire [31:0] dbg_branch_mispredict_count,
  output wire [31:0] dbg_btb_hit_count,
  output wire [31:0] dbg_btb_miss_count,
  output wire [31:0] dbg_bht_update_count,
  input  wire [4:0]  dbg_reg_addr,
  output wire [31:0] dbg_reg_rdata,
  output wire        dbg_illegal_instr,
  output wire        dbg_ecall,
  output wire        dbg_ebreak,

  output wire [31:0] dbg_icache_hit_count,
  output wire [31:0] dbg_icache_miss_count,
  output wire [31:0] dbg_dcache_hit_count,
  output wire [31:0] dbg_dcache_miss_count,
  output wire [31:0] dbg_bus_i_grant_count,
  output wire [31:0] dbg_bus_d_grant_count,
  output wire        dbg_cpu_bus_error,
  output wire        dbg_matrix_decode_error,
  output wire        dbg_apb_decode_error,

  output wire [31:0] dbg_timer_mtime_lo,
  output wire [31:0] dbg_timer_mtime_hi,
  output wire [31:0] dbg_timer_mtimecmp_lo,
  output wire [31:0] dbg_timer_mtimecmp_hi,
  output wire [31:0] dbg_timer_ctrl,
  output wire [31:0] dbg_uart_tx_count,
  output wire [7:0]  dbg_uart_last_tx
);

  wire        apb_hsel;
  wire [31:0] apb_haddr;
  wire [2:0]  apb_hburst;
  wire [3:0]  apb_hprot;
  wire [2:0]  apb_hsize;
  wire [1:0]  apb_htrans;
  wire [31:0] apb_hwdata;
  wire        apb_hwrite;
  wire        apb_hready;
  wire [31:0] apb_hrdata;
  wire        apb_hreadyout;
  wire [1:0]  apb_hresp;

  wire        psel;
  wire        penable;
  wire [31:0] paddr;
  wire        pwrite;
  wire [31:0] pwdata;
  wire [3:0]  pstrb;
  wire [2:0]  pprot;
  wire [31:0] prdata;
  wire        pready;
  wire        pslverr;

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

  rv32i_ahb_matrix_soc_top #(
    .ICACHE_INDEX_BITS(ICACHE_INDEX_BITS),
    .DCACHE_INDEX_BITS(DCACHE_INDEX_BITS),
    .RESET_PC(RESET_PC),
    .BRANCH_PRED_INDEX_BITS(BRANCH_PRED_INDEX_BITS)
  ) u_matrix_soc (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .timer_irq              (timer_irq),
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
    .apb_periph_hsel        (apb_hsel),
    .apb_periph_haddr       (apb_haddr),
    .apb_periph_hburst      (apb_hburst),
    .apb_periph_hprot       (apb_hprot),
    .apb_periph_hsize       (apb_hsize),
    .apb_periph_htrans      (apb_htrans),
    .apb_periph_hwdata      (apb_hwdata),
    .apb_periph_hwrite      (apb_hwrite),
    .apb_periph_hready      (apb_hready),
    .apb_periph_hrdata      (apb_hrdata),
    .apb_periph_hreadyout   (apb_hreadyout),
    .apb_periph_hresp       (apb_hresp),
    .dbg_pc                 (dbg_pc),
    .dbg_cycle              (dbg_cycle),
    .dbg_instret            (dbg_instret),
    .dbg_stall_cycle        (dbg_stall_cycle),
    .dbg_flush_cycle        (dbg_flush_cycle),
    .dbg_branch_count       (dbg_branch_count),
    .dbg_branch_mispredict_count(dbg_branch_mispredict_count),
    .dbg_btb_hit_count      (dbg_btb_hit_count),
    .dbg_btb_miss_count     (dbg_btb_miss_count),
    .dbg_bht_update_count   (dbg_bht_update_count),
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

  rv32i_ahb_to_apb u_ahb_to_apb (
    .clk       (clk),
    .rst_n     (rst_n),
    .hsel      (apb_hsel),
    .haddr     (apb_haddr),
    .hburst    (apb_hburst),
    .hprot     (apb_hprot),
    .hsize     (apb_hsize),
    .htrans    (apb_htrans),
    .hwdata    (apb_hwdata),
    .hwrite    (apb_hwrite),
    .hready    (apb_hready),
    .hrdata    (apb_hrdata),
    .hreadyout (apb_hreadyout),
    .hresp     (apb_hresp),
    .psel      (psel),
    .penable   (penable),
    .paddr     (paddr),
    .pwrite    (pwrite),
    .pwdata    (pwdata),
    .pstrb     (pstrb),
    .pprot     (pprot),
    .prdata    (prdata),
    .pready    (pready),
    .pslverr   (pslverr)
  );

  rv32i_apb_periph_mux u_apb_periph_mux (
    .psel             (psel),
    .penable          (penable),
    .paddr            (paddr),
    .pwrite           (pwrite),
    .pwdata           (pwdata),
    .pstrb            (pstrb),
    .pprot            (pprot),
    .prdata           (prdata),
    .pready           (pready),
    .pslverr          (pslverr),
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
    .dbg_decode_error (dbg_apb_decode_error)
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
    .dbg_mtime_lo     (dbg_timer_mtime_lo),
    .dbg_mtime_hi     (dbg_timer_mtime_hi),
    .dbg_mtimecmp_lo  (dbg_timer_mtimecmp_lo),
    .dbg_mtimecmp_hi  (dbg_timer_mtimecmp_hi),
    .dbg_ctrl         (dbg_timer_ctrl)
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
    .dbg_tx_count (dbg_uart_tx_count),
    .dbg_last_tx  (dbg_uart_last_tx)
  );

endmodule
