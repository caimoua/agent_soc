`include "rv32i_defs.vh"

module rv32i_alu (
  input  wire [3:0]  alu_op,
  input  wire [31:0] src_a,
  input  wire [31:0] src_b,
  output reg  [31:0] result
);

  always @(*) begin
    case (alu_op)
      `RV32I_ALU_ADD:  result = src_a + src_b;
      `RV32I_ALU_SUB:  result = src_a - src_b;
      `RV32I_ALU_AND:  result = src_a & src_b;
      `RV32I_ALU_OR:   result = src_a | src_b;
      `RV32I_ALU_XOR:  result = src_a ^ src_b;
      `RV32I_ALU_SLL:  result = src_a << src_b[4:0];
      `RV32I_ALU_SRL:  result = src_a >> src_b[4:0];
      `RV32I_ALU_SRA:  result = $signed(src_a) >>> src_b[4:0];
      `RV32I_ALU_SLT:  result = ($signed(src_a) < $signed(src_b)) ? 32'd1 : 32'd0;
      `RV32I_ALU_SLTU: result = (src_a < src_b) ? 32'd1 : 32'd0;
      default:         result = 32'd0;
    endcase
  end

endmodule
