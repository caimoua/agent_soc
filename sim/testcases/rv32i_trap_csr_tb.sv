`timescale 1ns/1ps

module rv32i_trap_csr_tb;

  localparam CLK_PERIOD_NS = 10;

  logic clk;
  logic rst_n;

  wire        imem_valid;
  wire [31:0] imem_addr;
  wire        imem_ready;
  wire [31:0] imem_rdata;

  wire        dmem_valid;
  wire        dmem_write;
  wire [31:0] dmem_addr;
  wire [31:0] dmem_wdata;
  wire [3:0]  dmem_wstrb;
  wire        dmem_ready;
  wire [31:0] dmem_rdata;

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

  logic [31:0] imem [0:255];
  logic [31:0] dmem [0:255];
  logic        illegal_seen;
  logic        ecall_seen;
  string       imem_memh;
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
      imem[i] = 32'h0000_0013; // addi x0, x0, 0
      dmem[i] = 32'd0;
    end

    if (!$value$plusargs("IMEM_MEMH=%s", imem_memh)) begin
      imem_memh = "../software/bin/trap_csr.memh";
    end

    memh_fd = $fopen(imem_memh, "r");
    if (memh_fd == 0) begin
      $fatal(1, "failed to open IMEM_MEMH='%s'", imem_memh);
    end
    $fclose(memh_fd);
    $readmemh(imem_memh, imem);
  end

  assign imem_ready = 1'b1;
  assign imem_rdata = imem[imem_addr[9:2]];
  assign dmem_ready = 1'b1;
  assign dmem_rdata = dmem[dmem_addr[9:2]];

  always @(posedge clk) begin
    if (dmem_valid && dmem_write) begin
      if (dmem_wstrb[0]) dmem[dmem_addr[9:2]][7:0]   <= dmem_wdata[7:0];
      if (dmem_wstrb[1]) dmem[dmem_addr[9:2]][15:8]  <= dmem_wdata[15:8];
      if (dmem_wstrb[2]) dmem[dmem_addr[9:2]][23:16] <= dmem_wdata[23:16];
      if (dmem_wstrb[3]) dmem[dmem_addr[9:2]][31:24] <= dmem_wdata[31:24];
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      illegal_seen <= 1'b0;
      ecall_seen   <= 1'b0;
    end else begin
      if (dbg_illegal_instr) begin
        illegal_seen <= 1'b1;
      end
      if (dbg_ecall) begin
        ecall_seen <= 1'b1;
      end
    end
  end

  rv32i_pipe_core u_core (
    .clk        (clk),
    .rst_n      (rst_n),
    .timer_irq  (1'b0),
    .imem_valid (imem_valid),
    .imem_addr  (imem_addr),
    .imem_ready (imem_ready),
    .imem_rdata (imem_rdata),
    .imem_error (1'b0),
    .dmem_valid (dmem_valid),
    .dmem_write (dmem_write),
    .dmem_addr  (dmem_addr),
    .dmem_wdata (dmem_wdata),
    .dmem_wstrb (dmem_wstrb),
    .dmem_ready (dmem_ready),
    .dmem_rdata (dmem_rdata),
    .dmem_error (1'b0),
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
    while (!dbg_ebreak && (timeout < 160)) begin
      @(posedge clk);
      #1ps;
      timeout = timeout + 1;
    end

    if (!dbg_ebreak) begin
      $fatal(1, "timeout waiting for EBREAK after MRET");
    end
    if (!ecall_seen) begin
      $fatal(1, "ECALL trap was not observed");
    end
    if (!illegal_seen) begin
      $fatal(1, "illegal instruction trap was not observed");
    end

    check_reg(5'd1,  32'd99, "x1");
    check_reg(5'd5,  32'h0000_0140, "x5 (mtvec value)");
    check_reg(5'd6,  32'd2, "x6 (last mcause read in handler)");
    check_reg(5'd7,  32'h0000_001c, "x7 (last mepc + 4 in handler)");
    check_reg(5'd9,  32'd99, "x9 (pre-return memory value for illegal trap)");
    check_reg(5'd10, 32'd1, "x10 (main resumed after mret)");
    check_reg(5'd11, 32'd1, "x11 (main resumed after illegal mret)");

    if (dmem[5] !== 32'd99) begin
      $fatal(1, "dmem[5] mismatch: expected post-MRET store 99, got 0x%08x", dmem[5]);
    end
    if (dmem[21] !== 32'd11) begin
      $fatal(1, "dmem[21] mismatch: expected ECALL mcause 11, got 0x%08x", dmem[21]);
    end
    if (dmem[31] !== 32'h0000_000c) begin
      $fatal(1, "dmem[31] mismatch: expected ECALL mepc 0x0000000c, got 0x%08x", dmem[31]);
    end
    if (dmem[41] !== 32'd0) begin
      $fatal(1, "dmem[41] mismatch: expected precise ECALL pre-store value 0, got 0x%08x", dmem[41]);
    end
    if (dmem[12] !== 32'd2) begin
      $fatal(1, "dmem[12] mismatch: expected illegal mcause 2, got 0x%08x", dmem[12]);
    end
    if (dmem[22] !== 32'h0000_0018) begin
      $fatal(1, "dmem[22] mismatch: expected illegal mepc 0x00000018, got 0x%08x", dmem[22]);
    end
    if (dmem[32] !== 32'd99) begin
      $fatal(1, "dmem[32] mismatch: expected illegal pre-trap memory value 99, got 0x%08x", dmem[32]);
    end

    $display("[PASS] rv32i_trap_csr_tb");
    $display("  pc=0x%08x cycle=%0d instret=%0d", dbg_pc, dbg_cycle, dbg_instret);
    $display("  stall_cycle=%0d flush_cycle=%0d", dbg_stall_cycle, dbg_flush_cycle);
    $display("  ecall: mcause=%0d mepc=0x%08x pre_store=0x%08x",
             dmem[21], dmem[31], dmem[41]);
    $display("  illegal: mcause=%0d mepc=0x%08x pre_store=0x%08x",
             dmem[12], dmem[22], dmem[32]);
    $display("  mret resumed main after ECALL and illegal traps");
    $finish;
  end

endmodule
