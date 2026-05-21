`include "rv32i_defs.vh"

module rv32i_muldiv (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        valid,
  input  wire [2:0]  op,
  input  wire [31:0] lhs,
  input  wire [31:0] rhs,
  input  wire        consume,
  input  wire        flush,
  output wire        ready,
  output wire        busy,
  output wire [31:0] result
);

  reg        busy_q;
  reg        ready_q;
  reg [31:0] result_q;

  reg [31:0] div_dividend_q;
  reg [31:0] div_divisor_q;
  reg [31:0] div_quotient_q;
  reg [32:0] div_remainder_q;
  reg [5:0]  div_count_q;
  reg        div_is_rem_q;
  reg        div_quotient_neg_q;
  reg        div_remainder_neg_q;

  wire signed [32:0] lhs_s33;
  wire signed [32:0] rhs_s33;
  wire signed [32:0] rhs_u33_as_signed;
  wire [32:0] lhs_u33;
  wire [32:0] rhs_u33;
  wire signed [65:0] mul_ss;
  wire signed [65:0] mul_su;
  wire [65:0] mul_uu;
  wire [31:0] mul_result;

  wire        div_op;
  wire        div_signed;
  wire        div_by_zero;
  wire        div_overflow;
  wire        div_lhs_neg;
  wire        div_rhs_neg;
  wire [31:0] div_lhs_abs;
  wire [31:0] div_rhs_abs;
  wire [32:0] div_remainder_shift;
  wire        div_subtract;
  wire [32:0] div_remainder_next;
  wire [31:0] div_quotient_next;
  wire [31:0] div_dividend_next;
  wire [31:0] div_quotient_signed;
  wire [31:0] div_remainder_signed;

  assign lhs_s33 = {lhs[31], lhs};
  assign rhs_s33 = {rhs[31], rhs};
  assign rhs_u33_as_signed = {1'b0, rhs};
  assign lhs_u33 = {1'b0, lhs};
  assign rhs_u33 = {1'b0, rhs};
  assign mul_ss = lhs_s33 * rhs_s33;
  assign mul_su = lhs_s33 * rhs_u33_as_signed;
  assign mul_uu = lhs_u33 * rhs_u33;
  assign mul_result =
    (op == `RV32I_MULDIV_MUL)    ? mul_ss[31:0]  :
    (op == `RV32I_MULDIV_MULH)   ? mul_ss[63:32] :
    (op == `RV32I_MULDIV_MULHSU) ? mul_su[63:32] :
                                   mul_uu[63:32];

  assign div_op = (op == `RV32I_MULDIV_DIV)  ||
                  (op == `RV32I_MULDIV_DIVU) ||
                  (op == `RV32I_MULDIV_REM)  ||
                  (op == `RV32I_MULDIV_REMU);
  assign div_signed = (op == `RV32I_MULDIV_DIV) ||
                      (op == `RV32I_MULDIV_REM);
  assign div_by_zero = (rhs == 32'd0);
  assign div_overflow = div_signed &&
                        (lhs == 32'h8000_0000) &&
                        (rhs == 32'hffff_ffff);
  assign div_lhs_neg = div_signed && lhs[31];
  assign div_rhs_neg = div_signed && rhs[31];
  assign div_lhs_abs = div_lhs_neg ? (~lhs + 32'd1) : lhs;
  assign div_rhs_abs = div_rhs_neg ? (~rhs + 32'd1) : rhs;

  assign div_remainder_shift = {div_remainder_q[31:0], div_dividend_q[31]};
  assign div_subtract = div_remainder_shift >= {1'b0, div_divisor_q};
  assign div_remainder_next =
    div_subtract ? (div_remainder_shift - {1'b0, div_divisor_q}) :
                   div_remainder_shift;
  assign div_quotient_next = {div_quotient_q[30:0], div_subtract};
  assign div_dividend_next = {div_dividend_q[30:0], 1'b0};
  assign div_quotient_signed =
    div_quotient_neg_q ? (~div_quotient_next + 32'd1) : div_quotient_next;
  assign div_remainder_signed =
    div_remainder_neg_q ? (~div_remainder_next[31:0] + 32'd1) :
                          div_remainder_next[31:0];

  assign ready = ready_q;
  assign busy = busy_q;
  assign result = result_q;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      busy_q              <= 1'b0;
      ready_q             <= 1'b0;
      result_q            <= 32'd0;
      div_dividend_q      <= 32'd0;
      div_divisor_q       <= 32'd0;
      div_quotient_q      <= 32'd0;
      div_remainder_q     <= 33'd0;
      div_count_q         <= 6'd0;
      div_is_rem_q        <= 1'b0;
      div_quotient_neg_q  <= 1'b0;
      div_remainder_neg_q <= 1'b0;
    end else if (flush) begin
      busy_q              <= 1'b0;
      ready_q             <= 1'b0;
      result_q            <= 32'd0;
      div_dividend_q      <= 32'd0;
      div_divisor_q       <= 32'd0;
      div_quotient_q      <= 32'd0;
      div_remainder_q     <= 33'd0;
      div_count_q         <= 6'd0;
      div_is_rem_q        <= 1'b0;
      div_quotient_neg_q  <= 1'b0;
      div_remainder_neg_q <= 1'b0;
    end else begin
      if (ready_q && consume) begin
        ready_q <= 1'b0;
      end

      if (busy_q) begin
        div_dividend_q  <= div_dividend_next;
        div_quotient_q  <= div_quotient_next;
        div_remainder_q <= div_remainder_next;

        if (div_count_q == 6'd31) begin
          busy_q <= 1'b0;
          ready_q <= 1'b1;
          result_q <= div_is_rem_q ? div_remainder_signed :
                                      div_quotient_signed;
        end else begin
          div_count_q <= div_count_q + 6'd1;
        end
      end else if (valid && !ready_q) begin
        if (div_op) begin
          if (div_by_zero) begin
            ready_q <= 1'b1;
            result_q <= ((op == `RV32I_MULDIV_REM) ||
                         (op == `RV32I_MULDIV_REMU)) ? lhs : 32'hffff_ffff;
          end else if (div_overflow) begin
            ready_q <= 1'b1;
            result_q <= (op == `RV32I_MULDIV_REM) ? 32'd0 : 32'h8000_0000;
          end else begin
            busy_q              <= 1'b1;
            div_dividend_q      <= div_lhs_abs;
            div_divisor_q       <= div_rhs_abs;
            div_quotient_q      <= 32'd0;
            div_remainder_q     <= 33'd0;
            div_count_q         <= 6'd0;
            div_is_rem_q        <= (op == `RV32I_MULDIV_REM) ||
                                   (op == `RV32I_MULDIV_REMU);
            div_quotient_neg_q  <= div_signed && (lhs[31] ^ rhs[31]);
            div_remainder_neg_q <= div_signed && lhs[31];
          end
        end else begin
          ready_q <= 1'b1;
          result_q <= mul_result;
        end
      end
    end
  end

endmodule
