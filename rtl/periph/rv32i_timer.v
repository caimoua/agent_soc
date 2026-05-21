module rv32i_timer (
  input  wire        clk,
  input  wire        rst_n,

  input  wire        valid,
  input  wire        write,
  input  wire [31:0] addr,
  input  wire [31:0] wdata,
  input  wire [3:0]  wstrb,
  output wire        ready,
  output wire [31:0] rdata,

  output wire        timer_irq,
  output wire [31:0] dbg_mtime_lo,
  output wire [31:0] dbg_mtime_hi,
  output wire [31:0] dbg_mtimecmp_lo,
  output wire [31:0] dbg_mtimecmp_hi,
  output wire [31:0] dbg_ctrl
);

  localparam [5:0] ADDR_MTIME_LO    = 6'h00;
  localparam [5:0] ADDR_MTIME_HI    = 6'h04;
  localparam [5:0] ADDR_MTIMECMP_LO = 6'h08;
  localparam [5:0] ADDR_MTIMECMP_HI = 6'h0c;
  localparam [5:0] ADDR_CTRL        = 6'h10;

  reg [63:0] mtime_q;
  reg [63:0] mtimecmp_q;
  reg        enable_q;
  reg        irq_enable_q;

  wire [5:0]  reg_offset;
  wire [31:0] ctrl_rdata;
  wire [31:0] ctrl_wdata_masked;

  function [31:0] apply_wstrb;
    input [31:0] old_value;
    input [31:0] new_value;
    input [3:0]  byte_en;
    begin
      apply_wstrb = old_value;
      if (byte_en[0]) apply_wstrb[7:0]   = new_value[7:0];
      if (byte_en[1]) apply_wstrb[15:8]  = new_value[15:8];
      if (byte_en[2]) apply_wstrb[23:16] = new_value[23:16];
      if (byte_en[3]) apply_wstrb[31:24] = new_value[31:24];
    end
  endfunction

  assign reg_offset = addr[5:0];
  assign timer_irq  = irq_enable_q && (mtime_q >= mtimecmp_q);
  assign ctrl_rdata = {timer_irq, 29'd0, irq_enable_q, enable_q};
  assign ctrl_wdata_masked = apply_wstrb(ctrl_rdata, wdata, wstrb);

  assign ready = valid;
  assign rdata = (reg_offset == ADDR_MTIME_LO)    ? mtime_q[31:0] :
                 (reg_offset == ADDR_MTIME_HI)    ? mtime_q[63:32] :
                 (reg_offset == ADDR_MTIMECMP_LO) ? mtimecmp_q[31:0] :
                 (reg_offset == ADDR_MTIMECMP_HI) ? mtimecmp_q[63:32] :
                 (reg_offset == ADDR_CTRL)        ? ctrl_rdata :
                                                     32'd0;

  assign dbg_mtime_lo    = mtime_q[31:0];
  assign dbg_mtime_hi    = mtime_q[63:32];
  assign dbg_mtimecmp_lo = mtimecmp_q[31:0];
  assign dbg_mtimecmp_hi = mtimecmp_q[63:32];
  assign dbg_ctrl        = ctrl_rdata;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mtime_q      <= 64'd0;
      mtimecmp_q   <= 64'hFFFF_FFFF_FFFF_FFFF;
      enable_q     <= 1'b0;
      irq_enable_q <= 1'b0;
    end else begin
      if (enable_q) begin
        mtime_q <= mtime_q + 64'd1;
      end

      if (valid && ready && write) begin
        case (reg_offset)
          ADDR_MTIME_LO: begin
            mtime_q[31:0] <= apply_wstrb(mtime_q[31:0], wdata, wstrb);
          end

          ADDR_MTIME_HI: begin
            mtime_q[63:32] <= apply_wstrb(mtime_q[63:32], wdata, wstrb);
          end

          ADDR_MTIMECMP_LO: begin
            mtimecmp_q[31:0] <= apply_wstrb(mtimecmp_q[31:0], wdata, wstrb);
          end

          ADDR_MTIMECMP_HI: begin
            mtimecmp_q[63:32] <= apply_wstrb(mtimecmp_q[63:32], wdata, wstrb);
          end

          ADDR_CTRL: begin
            enable_q     <= ctrl_wdata_masked[0];
            irq_enable_q <= ctrl_wdata_masked[1];
            if (ctrl_wdata_masked[2]) begin
              mtime_q <= 64'd0;
            end
          end

          default: begin
          end
        endcase
      end
    end
  end

endmodule
