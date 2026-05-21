`include "rv32i_defs.vh"

module rv32i_decoder #(
  parameter ENABLE_M = 0
) (
  input  wire [31:0] instr,

  output wire [4:0]  rs1_addr,
  output wire [4:0]  rs2_addr,
  output wire [4:0]  rd_addr,

  output reg         reg_we,
  output reg         alu_src_imm,
  output reg  [3:0]  alu_op,
  output reg  [2:0]  wb_sel,
  output reg  [1:0]  pc_sel,
  output reg  [2:0]  branch_op,
  output reg         mem_valid,
  output reg         mem_write,
  output reg  [1:0]  mem_size,
  output reg         mem_unsigned,
  output reg  [11:0] csr_addr,
  output reg  [1:0]  csr_op,
  output reg  [1:0]  system_op,
  output reg         system_ecall,
  output reg         system_ebreak,
  output reg         system_mret,
  output reg         muldiv_valid,
  output reg  [2:0]  muldiv_op,
  output reg         illegal_instr
);

  wire [6:0] opcode = instr[6:0];
  wire [2:0] funct3 = instr[14:12];
  wire [6:0] funct7 = instr[31:25];
  wire [11:0] csr_addr_field = instr[31:20];

  assign rd_addr  = instr[11:7];
  assign rs1_addr = instr[19:15];
  assign rs2_addr = instr[24:20];

  always @(*) begin
    reg_we        = 1'b0;
    alu_src_imm   = 1'b0;
    alu_op        = `RV32I_ALU_ADD;
    wb_sel        = `RV32I_WB_ALU;
    pc_sel        = `RV32I_PC_NEXT;
    branch_op     = `RV32I_BR_BEQ;
    mem_valid     = 1'b0;
    mem_write     = 1'b0;
    mem_size      = `RV32I_MEM_WORD;
    mem_unsigned  = 1'b0;
    csr_addr      = 12'd0;
    csr_op        = `RV32I_CSR_OP_NONE;
    system_op     = `RV32I_SYS_NONE;
    system_ecall  = 1'b0;
    system_ebreak = 1'b0;
    system_mret   = 1'b0;
    muldiv_valid  = 1'b0;
    muldiv_op     = `RV32I_MULDIV_MUL;
    illegal_instr = 1'b0;

    case (opcode)
      `RV32I_OPCODE_OP_IMM: begin
        case (funct3)
          3'b000: begin // addi
            reg_we      = 1'b1;
            alu_src_imm = 1'b1;
            alu_op      = `RV32I_ALU_ADD;
          end
          3'b001: begin // slli
            reg_we      = 1'b1;
            alu_src_imm = 1'b1;
            case (funct7)
              7'b0000000: alu_op = `RV32I_ALU_SLL;
              default:    illegal_instr = 1'b1;
            endcase
          end
          3'b010: begin // slti
            reg_we      = 1'b1;
            alu_src_imm = 1'b1;
            alu_op      = `RV32I_ALU_SLT;
          end
          3'b011: begin // sltiu
            reg_we      = 1'b1;
            alu_src_imm = 1'b1;
            alu_op      = `RV32I_ALU_SLTU;
          end
          3'b100: begin // xori
            reg_we      = 1'b1;
            alu_src_imm = 1'b1;
            alu_op      = `RV32I_ALU_XOR;
          end
          3'b110: begin // ori
            reg_we      = 1'b1;
            alu_src_imm = 1'b1;
            alu_op      = `RV32I_ALU_OR;
          end
          3'b111: begin // andi
            reg_we      = 1'b1;
            alu_src_imm = 1'b1;
            alu_op      = `RV32I_ALU_AND;
          end
          3'b101: begin // srli / srai
            reg_we      = 1'b1;
            alu_src_imm = 1'b1;
            case (funct7)
              7'b0000000: alu_op = `RV32I_ALU_SRL;
              7'b0100000: alu_op = `RV32I_ALU_SRA;
              default:    illegal_instr = 1'b1;
            endcase
          end
          default: begin
            illegal_instr = 1'b1;
          end
        endcase
      end

      `RV32I_OPCODE_OP: begin
        case ({funct7, funct3})
          {7'b0000000, 3'b000}: begin // add
            reg_we = 1'b1;
            alu_op = `RV32I_ALU_ADD;
          end
          {7'b0100000, 3'b000}: begin // sub
            reg_we = 1'b1;
            alu_op = `RV32I_ALU_SUB;
          end
          {7'b0000000, 3'b001}: begin // sll
            reg_we = 1'b1;
            alu_op = `RV32I_ALU_SLL;
          end
          {7'b0000000, 3'b010}: begin // slt
            reg_we = 1'b1;
            alu_op = `RV32I_ALU_SLT;
          end
          {7'b0000000, 3'b011}: begin // sltu
            reg_we = 1'b1;
            alu_op = `RV32I_ALU_SLTU;
          end
          {7'b0000000, 3'b100}: begin // xor
            reg_we = 1'b1;
            alu_op = `RV32I_ALU_XOR;
          end
          {7'b0000000, 3'b101}: begin // srl
            reg_we = 1'b1;
            alu_op = `RV32I_ALU_SRL;
          end
          {7'b0100000, 3'b101}: begin // sra
            reg_we = 1'b1;
            alu_op = `RV32I_ALU_SRA;
          end
          {7'b0000000, 3'b110}: begin // or
            reg_we = 1'b1;
            alu_op = `RV32I_ALU_OR;
          end
          {7'b0000000, 3'b111}: begin // and
            reg_we = 1'b1;
            alu_op = `RV32I_ALU_AND;
          end
          {7'b0000001, 3'b000}, // mul
          {7'b0000001, 3'b001}, // mulh
          {7'b0000001, 3'b010}, // mulhsu
          {7'b0000001, 3'b011}, // mulhu
          {7'b0000001, 3'b100}, // div
          {7'b0000001, 3'b101}, // divu
          {7'b0000001, 3'b110}, // rem
          {7'b0000001, 3'b111}: begin // remu
            if (ENABLE_M) begin
              reg_we       = 1'b1;
              wb_sel       = `RV32I_WB_ALU;
              muldiv_valid = 1'b1;
              muldiv_op    = funct3;
            end else begin
              illegal_instr = 1'b1;
            end
          end
          default: begin
            illegal_instr = 1'b1;
          end
        endcase
      end

      `RV32I_OPCODE_LUI: begin
        reg_we = 1'b1;
        wb_sel = `RV32I_WB_LUI;
      end

      `RV32I_OPCODE_AUIPC: begin
        reg_we = 1'b1;
        wb_sel = `RV32I_WB_AUIPC;
      end

      `RV32I_OPCODE_JAL: begin
        reg_we = 1'b1;
        wb_sel = `RV32I_WB_PC4;
        pc_sel = `RV32I_PC_JAL;
      end

      `RV32I_OPCODE_JALR: begin
        if (funct3 == 3'b000) begin
          reg_we      = 1'b1;
          alu_src_imm = 1'b1;
          alu_op      = `RV32I_ALU_ADD;
          wb_sel      = `RV32I_WB_PC4;
          pc_sel      = `RV32I_PC_JALR;
        end else begin
          illegal_instr = 1'b1;
        end
      end

      `RV32I_OPCODE_BRANCH: begin
        case (funct3)
          `RV32I_BR_BEQ,
          `RV32I_BR_BNE,
          `RV32I_BR_BLT,
          `RV32I_BR_BGE,
          `RV32I_BR_BLTU,
          `RV32I_BR_BGEU: begin
            pc_sel    = `RV32I_PC_BRANCH;
            branch_op = funct3;
          end
          default: begin
            illegal_instr = 1'b1;
          end
        endcase
      end

      `RV32I_OPCODE_LOAD: begin
        reg_we      = 1'b1;
        alu_src_imm = 1'b1;
        alu_op      = `RV32I_ALU_ADD;
        wb_sel      = `RV32I_WB_MEM;
        mem_valid   = 1'b1;
        mem_write   = 1'b0;

        case (funct3)
          3'b000: begin // lb
            mem_size     = `RV32I_MEM_BYTE;
            mem_unsigned = 1'b0;
          end
          3'b001: begin // lh
            mem_size     = `RV32I_MEM_HALF;
            mem_unsigned = 1'b0;
          end
          3'b010: begin // lw
            mem_size     = `RV32I_MEM_WORD;
            mem_unsigned = 1'b0;
          end
          3'b100: begin // lbu
            mem_size     = `RV32I_MEM_BYTE;
            mem_unsigned = 1'b1;
          end
          3'b101: begin // lhu
            mem_size     = `RV32I_MEM_HALF;
            mem_unsigned = 1'b1;
          end
          default: begin
            illegal_instr = 1'b1;
          end
        endcase
      end

      `RV32I_OPCODE_STORE: begin
        mem_valid = 1'b1;
        mem_write = 1'b1;

        case (funct3)
          3'b000: mem_size = `RV32I_MEM_BYTE; // sb
          3'b001: mem_size = `RV32I_MEM_HALF; // sh
          3'b010: mem_size = `RV32I_MEM_WORD; // sw
          default: begin
            illegal_instr = 1'b1;
          end
        endcase
      end

      `RV32I_OPCODE_SYSTEM: begin
        case (funct3)
          3'b000: begin
            if ((csr_addr_field == 12'h000) &&
                (rs1_addr == 5'd0) &&
                (rd_addr == 5'd0)) begin
              system_op    = `RV32I_SYS_ECALL;
              system_ecall = 1'b1;
            end else if ((csr_addr_field == 12'h001) &&
                         (rs1_addr == 5'd0) &&
                         (rd_addr == 5'd0)) begin
              system_op     = `RV32I_SYS_EBREAK;
              system_ebreak = 1'b1;
            end else if ((csr_addr_field == 12'h302) &&
                         (rs1_addr == 5'd0) &&
                         (rd_addr == 5'd0)) begin
              system_op   = `RV32I_SYS_MRET;
              system_mret = 1'b1;
            end else begin
              illegal_instr = 1'b1;
            end
          end

          3'b001: begin // csrrw
            case (csr_addr_field)
              `RV32I_CSR_MSTATUS,
              `RV32I_CSR_MIE,
              `RV32I_CSR_MTVEC,
              `RV32I_CSR_MEPC,
              `RV32I_CSR_MCAUSE: begin
                reg_we   = (rd_addr != 5'd0);
                wb_sel   = `RV32I_WB_CSR;
                csr_addr = csr_addr_field;
                csr_op   = `RV32I_CSR_OP_RW;
              end
              default: begin
                illegal_instr = 1'b1;
              end
            endcase
          end

          3'b010: begin // csrrs
            case (csr_addr_field)
              `RV32I_CSR_CYCLE: begin
                if (rs1_addr == 5'd0) begin
                  reg_we   = (rd_addr != 5'd0);
                  wb_sel   = `RV32I_WB_CSR;
                  csr_addr = csr_addr_field;
                  csr_op   = `RV32I_CSR_OP_RS;
                end else begin
                  illegal_instr = 1'b1;
                end
              end
              `RV32I_CSR_MTVEC,
              `RV32I_CSR_MSTATUS,
              `RV32I_CSR_MIE,
              `RV32I_CSR_MEPC,
              `RV32I_CSR_MCAUSE: begin
                reg_we   = (rd_addr != 5'd0);
                wb_sel   = `RV32I_WB_CSR;
                csr_addr = csr_addr_field;
                csr_op   = `RV32I_CSR_OP_RS;
              end
              `RV32I_CSR_MIP: begin
                if (rs1_addr == 5'd0) begin
                  reg_we   = (rd_addr != 5'd0);
                  wb_sel   = `RV32I_WB_CSR;
                  csr_addr = csr_addr_field;
                  csr_op   = `RV32I_CSR_OP_RS;
                end else begin
                  illegal_instr = 1'b1;
                end
              end
              default: begin
                illegal_instr = 1'b1;
              end
            endcase
          end

          3'b101: begin // csrrwi is not implemented in this teaching core.
            illegal_instr = 1'b1;
          end

          3'b110: begin // csrrsi is not implemented in this teaching core.
            illegal_instr = 1'b1;
          end

          3'b111: begin // csrrci is not implemented in this teaching core.
            illegal_instr = 1'b1;
          end

          3'b011: begin // csrrc is not implemented in this teaching core.
            illegal_instr = 1'b1;
          end

          default: begin
            illegal_instr = 1'b1;
          end
        endcase
      end

      default: begin
        illegal_instr = 1'b1;
      end
    endcase
end

endmodule
