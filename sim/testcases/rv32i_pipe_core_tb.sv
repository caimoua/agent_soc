`timescale 1ns/1ps

module rv32i_pipe_core_tb;

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
  logic        imem_wait_10_done;
  logic        imem_wait_38_done;
  logic        imem_wait_88_done;
  logic        dmem_ready_q;
  logic        illegal_seen;
  string       imem_memh;
  integer i;
  integer memh_fd;
  integer timeout;
  wire         imem_wait_req;

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
      imem_memh = "../software/bin/pipe_core.memh";
    end

    memh_fd = $fopen(imem_memh, "r");
    if (memh_fd == 0) begin
      $fatal(1, "failed to open IMEM_MEMH='%s'", imem_memh);
    end
    $fclose(memh_fd);
    $readmemh(imem_memh, imem);
  end

  assign imem_wait_req = imem_valid &&
                         (((imem_addr == 32'h0000_0010) && !imem_wait_10_done) ||
                          ((imem_addr == 32'h0000_0038) && !imem_wait_38_done) ||
                          ((imem_addr == 32'h0000_0088) && !imem_wait_88_done));
  assign imem_ready = !imem_wait_req;
  assign imem_rdata = imem[imem_addr[9:2]];
  assign dmem_ready = dmem_valid ? dmem_ready_q : 1'b1;
  assign dmem_rdata = dmem[dmem_addr[9:2]];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      imem_wait_10_done <= 1'b0;
      imem_wait_38_done <= 1'b0;
      imem_wait_88_done <= 1'b0;
    end else if (imem_wait_req) begin
      if (imem_addr == 32'h0000_0010) begin
        imem_wait_10_done <= 1'b1;
      end
      if (imem_addr == 32'h0000_0038) begin
        imem_wait_38_done <= 1'b1;
      end
      if (imem_addr == 32'h0000_0088) begin
        imem_wait_88_done <= 1'b1;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dmem_ready_q <= 1'b0;
    end else if (!dmem_valid) begin
      dmem_ready_q <= 1'b0;
    end else begin
      dmem_ready_q <= !dmem_ready_q;
    end
  end

  always @(posedge clk) begin
    if (dmem_valid && dmem_ready && dmem_write) begin
      if (dmem_wstrb[0]) dmem[dmem_addr[9:2]][7:0]   <= dmem_wdata[7:0];
      if (dmem_wstrb[1]) dmem[dmem_addr[9:2]][15:8]  <= dmem_wdata[15:8];
      if (dmem_wstrb[2]) dmem[dmem_addr[9:2]][23:16] <= dmem_wdata[23:16];
      if (dmem_wstrb[3]) dmem[dmem_addr[9:2]][31:24] <= dmem_wdata[31:24];
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      illegal_seen <= 1'b0;
    end else if (dbg_illegal_instr) begin
      illegal_seen <= 1'b1;
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
    while (!dbg_ebreak && (timeout < 120)) begin
      @(posedge clk);
      #1ps;
      timeout = timeout + 1;
    end

    if (!dbg_ebreak) begin
      $fatal(1, "timeout waiting for pipeline ebreak");
    end

    if (illegal_seen) begin
      $fatal(1, "unexpected illegal instruction in pipe test");
    end

    if (dbg_ecall) begin
      $fatal(1, "unexpected ECALL event in pipe test");
    end

    check_reg(5'd1, 32'd5,         "x1");
    check_reg(5'd2, 32'd7,         "x2");
    check_reg(5'd3, 32'd12,        "x3");
    check_reg(5'd4, 32'd7,         "x4");
    check_reg(5'd5, 32'd19,        "x5");
    check_reg(5'd6, 32'd28,        "x6");
    check_reg(5'd7, 32'd31,        "x7");
    check_reg(5'd8, 32'd28,        "x8");
    check_reg(5'd9, 32'd3,         "x9");
    check_reg(5'd10, 32'd3,        "x10");
    check_reg(5'd11, 32'h1234_5000, "x11");
    check_reg(5'd12, 32'h0000_1034, "x12");
    check_reg(5'd13, 32'd28,        "x13 (load-use producer)");
    check_reg(5'd14, 32'd35,        "x14 (load-use rs1)");
    check_reg(5'd15, 32'd28,        "x15 (load-use producer)");
    check_reg(5'd16, 32'd35,        "x16 (load-use rs2)");
    check_reg(5'd17, 32'd28,        "x17 (load-use store data)");
    check_reg(5'd18, 32'd28,        "x18 (load-use store addr)");
    check_reg(5'd19, 32'd15,        "x19 (control-flow score)");
    check_reg(5'd20, 32'h0000_0074, "x20 (jal return)");
    check_reg(5'd21, 32'h0000_0088, "x21 (jalr target base)");
    check_reg(5'd22, 32'h0000_0084, "x22 (jalr return)");

    if (dmem[0] !== 32'd28) begin
      $fatal(1, "dmem[0] mismatch: expected 28, got 0x%08x", dmem[0]);
    end
    if (dmem[1] !== 32'd28) begin
      $fatal(1, "dmem[1] mismatch: expected 28, got 0x%08x", dmem[1]);
    end
    if (dmem[7] !== 32'd7) begin
      $fatal(1, "dmem[7] mismatch: expected 7, got 0x%08x", dmem[7]);
    end
    if (dbg_instret !== 32'd33) begin
      $fatal(1, "instret mismatch: expected 33, got %0d", dbg_instret);
    end
    if (dbg_stall_cycle !== 32'd16) begin
      $fatal(1, "stall_cycle mismatch: expected 16, got %0d", dbg_stall_cycle);
    end
    if (dbg_flush_cycle !== 32'd2) begin
      $fatal(1, "flush_cycle mismatch: expected 2, got %0d", dbg_flush_cycle);
    end

    $display("[PASS] rv32i_pipe_core_tb");
    $display("  pc=0x%08x cycle=%0d instret=%0d", dbg_pc, dbg_cycle, dbg_instret);
    $display("  stall_cycle=%0d flush_cycle=%0d", dbg_stall_cycle, dbg_flush_cycle);
    $display("  forwarding, load-use stall, instruction/data memory wait-state, control flush and perf counters passed");
    $finish;
  end

endmodule
