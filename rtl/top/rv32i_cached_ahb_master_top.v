module rv32i_cached_ahb_master_top #(
  parameter ICACHE_INDEX_BITS = 2,
  parameter DCACHE_INDEX_BITS = 2,
  parameter [31:0] RESET_PC = 32'h0000_0000,
  parameter BRANCH_PRED_INDEX_BITS = 6
) (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        timer_irq,

  output wire [31:0] ahb_haddr,
  output wire [2:0]  ahb_hburst,
  output wire [3:0]  ahb_hprot,
  output wire [2:0]  ahb_hsize,
  output wire [1:0]  ahb_htrans,
  output wire [31:0] ahb_hwdata,
  output wire        ahb_hwrite,
  input  wire [31:0] ahb_hrdata,
  input  wire        ahb_hready,
  input  wire [1:0]  ahb_hresp,

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
  output wire        dbg_bus_error
);

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

  wire        unused_icache_dbg_hit;
  wire        unused_icache_dbg_miss;
  wire        unused_dcache_dbg_hit;
  wire        unused_dcache_dbg_miss;
  wire        unused_bus_dbg_active;
  wire        unused_bus_dbg_grant_is_d;

  rv32i_pipe_core #(
    .RESET_PC(RESET_PC),
    .BRANCH_PRED_INDEX_BITS(BRANCH_PRED_INDEX_BITS)
  ) u_core (
    .clk              (clk),
    .rst_n            (rst_n),
    .timer_irq        (timer_irq),
    .imem_valid       (core_imem_valid),
    .imem_addr        (core_imem_addr),
    .imem_ready       (core_imem_ready),
    .imem_rdata       (core_imem_rdata),
    .imem_error       (core_imem_error),
    .dmem_valid       (core_dmem_valid),
    .dmem_write       (core_dmem_write),
    .dmem_addr        (core_dmem_addr),
    .dmem_wdata       (core_dmem_wdata),
    .dmem_wstrb       (core_dmem_wstrb),
    .dmem_ready       (core_dmem_ready),
    .dmem_rdata       (core_dmem_rdata),
    .dmem_error       (core_dmem_error),
    .dbg_pc           (dbg_pc),
    .dbg_cycle        (dbg_cycle),
    .dbg_instret      (dbg_instret),
    .dbg_stall_cycle  (dbg_stall_cycle),
    .dbg_flush_cycle  (dbg_flush_cycle),
    .dbg_branch_count (dbg_branch_count),
    .dbg_branch_mispredict_count(dbg_branch_mispredict_count),
    .dbg_btb_hit_count(dbg_btb_hit_count),
    .dbg_btb_miss_count(dbg_btb_miss_count),
    .dbg_bht_update_count(dbg_bht_update_count),
    .dbg_reg_addr     (dbg_reg_addr),
    .dbg_reg_rdata    (dbg_reg_rdata),
    .dbg_illegal_instr(dbg_illegal_instr),
    .dbg_ecall        (dbg_ecall),
    .dbg_ebreak       (dbg_ebreak)
  );

  rv32i_icache #(
    .INDEX_BITS(ICACHE_INDEX_BITS)
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
    .dbg_hit        (unused_icache_dbg_hit),
    .dbg_miss       (unused_icache_dbg_miss),
    .dbg_hit_count  (dbg_icache_hit_count),
    .dbg_miss_count (dbg_icache_miss_count)
  );

  rv32i_dcache #(
    .INDEX_BITS(DCACHE_INDEX_BITS)
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
    .dbg_hit        (unused_dcache_dbg_hit),
    .dbg_miss       (unused_dcache_dbg_miss),
    .dbg_hit_count  (dbg_dcache_hit_count),
    .dbg_miss_count (dbg_dcache_miss_count)
  );

  rv32i_ahb_master_bus u_bus (
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
    .ahb_haddr         (ahb_haddr),
    .ahb_hburst        (ahb_hburst),
    .ahb_hprot         (ahb_hprot),
    .ahb_hsize         (ahb_hsize),
    .ahb_htrans        (ahb_htrans),
    .ahb_hwdata        (ahb_hwdata),
    .ahb_hwrite        (ahb_hwrite),
    .ahb_hrdata        (ahb_hrdata),
    .ahb_hready        (ahb_hready),
    .ahb_hresp         (ahb_hresp),
    .dbg_active        (unused_bus_dbg_active),
    .dbg_grant_is_d    (unused_bus_dbg_grant_is_d),
    .dbg_bus_error     (dbg_bus_error),
    .dbg_i_grant_count (dbg_bus_i_grant_count),
    .dbg_d_grant_count (dbg_bus_d_grant_count)
  );

endmodule
