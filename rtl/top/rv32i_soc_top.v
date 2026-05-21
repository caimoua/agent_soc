module rv32i_soc_top (
  input  wire        clk,
  input  wire        rst_n,
  output wire [31:0] dbg_pc,
  output wire [31:0] dbg_cycle,
  input  wire [4:0]  dbg_reg_addr,
  output wire [31:0] dbg_reg_rdata,
  output wire        dbg_illegal_instr,
  output wire        dbg_ecall,
  output wire        dbg_ebreak
);

  wire        imem_valid;
  wire [31:0] imem_addr;
  wire [31:0] imem_rdata;
  wire        dmem_valid;
  wire        dmem_write;
  wire [31:0] dmem_addr;
  wire [31:0] dmem_wdata;
  wire [3:0]  dmem_wstrb;
  wire        dmem_ready;
  wire [31:0] dmem_rdata;

  wire unused_imem_valid = imem_valid;
  wire [31:0] unused_imem_addr = imem_addr;
  wire unused_dmem_valid = dmem_valid;
  wire unused_dmem_write = dmem_write;
  wire [31:0] unused_dmem_addr = dmem_addr;
  wire [31:0] unused_dmem_wdata = dmem_wdata;
  wire [3:0] unused_dmem_wstrb = dmem_wstrb;

  assign imem_rdata = 32'h0000_0013; // addi x0, x0, 0
  assign dmem_ready = 1'b1;
  assign dmem_rdata = 32'd0;

  rv32i_core u_core (
    .clk        (clk),
    .rst_n      (rst_n),
    .imem_valid (imem_valid),
    .imem_addr  (imem_addr),
    .imem_rdata (imem_rdata),
    .dmem_valid (dmem_valid),
    .dmem_write (dmem_write),
    .dmem_addr  (dmem_addr),
    .dmem_wdata (dmem_wdata),
    .dmem_wstrb (dmem_wstrb),
    .dmem_ready (dmem_ready),
    .dmem_rdata (dmem_rdata),
    .dbg_pc     (dbg_pc),
    .dbg_cycle  (dbg_cycle),
    .dbg_reg_addr (dbg_reg_addr),
    .dbg_reg_rdata(dbg_reg_rdata),
    .dbg_illegal_instr(dbg_illegal_instr),
    .dbg_ecall   (dbg_ecall),
    .dbg_ebreak  (dbg_ebreak)
  );

endmodule
