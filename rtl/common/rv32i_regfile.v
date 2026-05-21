module rv32i_regfile (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        we,
  input  wire [4:0]  waddr,
  input  wire [31:0] wdata,
  input  wire [4:0]  raddr0,
  input  wire [4:0]  raddr1,
  output wire [31:0] rdata0,
  output wire [31:0] rdata1,
  input  wire [4:0]  dbg_raddr,
  output wire [31:0] dbg_rdata
);

  reg [31:0] regs [0:31];
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < 32; i = i + 1)
        regs[i] <= 32'd0;
    end else if (we && (waddr != 5'd0)) begin
      regs[waddr] <= wdata;
    end
  end

  assign rdata0 = (raddr0 == 5'd0) ? 32'd0 : regs[raddr0];
  assign rdata1 = (raddr1 == 5'd0) ? 32'd0 : regs[raddr1];
  assign dbg_rdata = (dbg_raddr == 5'd0) ? 32'd0 : regs[dbg_raddr];

endmodule
