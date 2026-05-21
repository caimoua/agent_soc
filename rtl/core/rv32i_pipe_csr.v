`include "rv32i_defs.vh"

module rv32i_pipe_csr (
  input  wire        clk,
  input  wire        rst_n,

  input  wire [31:0] cycle_value,
  input  wire        timer_irq,

  input  wire [11:0] ex_csr_addr,
  output wire [31:0] ex_csr_rdata,

  input  wire        commit_valid,
  input  wire [31:0] commit_pc4,
  input  wire        commit_illegal,
  input  wire        commit_ecall,
  input  wire        commit_ebreak,
  input  wire        commit_mret,
  input  wire        commit_instr_addr_misaligned,
  input  wire        commit_instr_fault,
  input  wire        commit_load_addr_misaligned,
  input  wire        commit_load_fault,
  input  wire        commit_store_addr_misaligned,
  input  wire        commit_store_fault,

  input  wire        commit_csr_write_req,
  input  wire [11:0] commit_csr_addr,
  input  wire [1:0]  commit_csr_op,
  input  wire [31:0] commit_csr_rdata,
  input  wire [31:0] commit_csr_wdata,

  output wire        commit_redirect,
  output wire [31:0] commit_redirect_pc,

  output wire        dbg_illegal_instr,
  output wire        dbg_ecall,
  output wire        dbg_ebreak
);

  reg [31:0] csr_mtvec_q;
  reg [31:0] csr_mepc_q;
  reg [31:0] csr_mcause_q;
  reg [31:0] csr_mstatus_q;
  reg [31:0] csr_mie_q;
  reg        dbg_illegal_instr_q;
  reg        dbg_ecall_q;
  reg        dbg_ebreak_q;

  wire [31:0] commit_pc;
  wire [31:0] commit_trap_pc;
  wire [31:0] csr_mip_value;
  wire [31:0] csr_mstatus_trap_value;
  wire [31:0] csr_mstatus_mret_value;
  wire        timer_interrupt_enabled;
  wire        commit_exception_trap;
  wire        commit_timer_interrupt;
  wire        commit_trap;
  wire        commit_mret_taken;
  wire        commit_redirect_int;
  wire [31:0] commit_exception_cause;
  wire        commit_csr_write;
  wire [31:0] commit_csr_write_data;

  function [31:0] mask_mstatus;
    input [31:0] value;
    begin
      mask_mstatus = 32'd0;
      mask_mstatus[`RV32I_MSTATUS_MIE]  = value[`RV32I_MSTATUS_MIE];
      mask_mstatus[`RV32I_MSTATUS_MPIE] = value[`RV32I_MSTATUS_MPIE];
    end
  endfunction

  function [31:0] mask_mie;
    input [31:0] value;
    begin
      mask_mie = 32'd0;
      mask_mie[`RV32I_MIE_MTIE] = value[`RV32I_MIE_MTIE];
    end
  endfunction

  assign commit_pc = commit_pc4 - 32'd4;
  assign csr_mip_value = timer_irq ? (32'd1 << `RV32I_MIP_MTIP) : 32'd0;
  assign csr_mstatus_trap_value =
    (csr_mstatus_q & ~((32'd1 << `RV32I_MSTATUS_MIE) |
                       (32'd1 << `RV32I_MSTATUS_MPIE))) |
    (csr_mstatus_q[`RV32I_MSTATUS_MIE] ? (32'd1 << `RV32I_MSTATUS_MPIE) : 32'd0);
  assign csr_mstatus_mret_value =
    (csr_mstatus_q & ~((32'd1 << `RV32I_MSTATUS_MIE) |
                       (32'd1 << `RV32I_MSTATUS_MPIE))) |
    (csr_mstatus_q[`RV32I_MSTATUS_MPIE] ? (32'd1 << `RV32I_MSTATUS_MIE) : 32'd0) |
    (32'd1 << `RV32I_MSTATUS_MPIE);
  assign timer_interrupt_enabled = csr_mstatus_q[`RV32I_MSTATUS_MIE] &&
                                   csr_mie_q[`RV32I_MIE_MTIE] &&
                                   csr_mip_value[`RV32I_MIP_MTIP];

  assign ex_csr_rdata = (commit_timer_interrupt && (ex_csr_addr == `RV32I_CSR_MCAUSE)) ? `RV32I_TRAP_CAUSE_MTIMER :
                        (commit_exception_trap && (ex_csr_addr == `RV32I_CSR_MCAUSE)) ? commit_exception_cause :
                        (commit_trap && (ex_csr_addr == `RV32I_CSR_MEPC))             ? commit_trap_pc :
                        (commit_trap && (ex_csr_addr == `RV32I_CSR_MSTATUS))          ? csr_mstatus_trap_value :
                        (commit_mret_taken && (ex_csr_addr == `RV32I_CSR_MSTATUS))    ? csr_mstatus_mret_value :
                        (ex_csr_addr == `RV32I_CSR_MSTATUS) ? csr_mstatus_q :
                        (ex_csr_addr == `RV32I_CSR_MIE)     ? csr_mie_q :
                        (ex_csr_addr == `RV32I_CSR_MIP)     ? csr_mip_value :
                        (ex_csr_addr == `RV32I_CSR_CYCLE)   ? cycle_value :
                        (ex_csr_addr == `RV32I_CSR_MTVEC)  ? csr_mtvec_q :
                        (ex_csr_addr == `RV32I_CSR_MEPC)   ? csr_mepc_q :
                        (ex_csr_addr == `RV32I_CSR_MCAUSE) ? csr_mcause_q :
                                                              32'd0;

  assign commit_exception_trap = commit_valid &&
                                 (commit_illegal ||
                                  commit_ecall ||
                                  commit_ebreak ||
                                  commit_instr_addr_misaligned ||
                                  commit_instr_fault ||
                                  commit_load_addr_misaligned ||
                                  commit_load_fault ||
                                  commit_store_addr_misaligned ||
                                  commit_store_fault);
  assign commit_timer_interrupt = commit_valid &&
                                  timer_interrupt_enabled &&
                                  !commit_illegal &&
                                  !commit_ecall &&
                                  !commit_ebreak &&
                                  !commit_instr_addr_misaligned &&
                                  !commit_instr_fault &&
                                  !commit_load_addr_misaligned &&
                                  !commit_load_fault &&
                                  !commit_store_addr_misaligned &&
                                  !commit_store_fault &&
                                  !commit_mret &&
                                  !commit_csr_write_req;
  assign commit_trap = commit_exception_trap || commit_timer_interrupt;
  assign commit_mret_taken = commit_valid &&
                             !commit_illegal &&
                             !commit_instr_addr_misaligned &&
                             !commit_instr_fault &&
                             !commit_load_addr_misaligned &&
                             !commit_load_fault &&
                             !commit_store_addr_misaligned &&
                             !commit_store_fault &&
                             commit_mret;
  assign commit_redirect_int = commit_trap || commit_mret_taken;
  assign commit_redirect = commit_redirect_int;

  assign commit_exception_cause = commit_instr_addr_misaligned ? `RV32I_TRAP_CAUSE_INSTR_ADDR_MISALIGNED :
                                  commit_instr_fault ? `RV32I_TRAP_CAUSE_INSTR_ACCESS_FAULT :
                                  commit_illegal ? `RV32I_TRAP_CAUSE_ILLEGAL :
                                  commit_ebreak  ? `RV32I_TRAP_CAUSE_EBREAK :
                                  commit_ecall   ? `RV32I_TRAP_CAUSE_ECALL :
                                  commit_load_addr_misaligned ? `RV32I_TRAP_CAUSE_LOAD_ADDR_MISALIGNED :
                                  commit_load_fault ? `RV32I_TRAP_CAUSE_LOAD_ACCESS_FAULT :
                                  commit_store_addr_misaligned ? `RV32I_TRAP_CAUSE_STORE_ADDR_MISALIGNED :
                                                       `RV32I_TRAP_CAUSE_STORE_ACCESS_FAULT;
  assign commit_trap_pc = commit_timer_interrupt ? commit_pc4 : commit_pc;
  assign commit_redirect_pc = commit_trap ? (csr_mtvec_q & ~32'd3) :
                                            (csr_mepc_q & ~32'd3);

  assign commit_csr_write = commit_valid &&
                            !commit_illegal &&
                            !commit_instr_addr_misaligned &&
                            !commit_instr_fault &&
                            !commit_load_addr_misaligned &&
                            !commit_store_addr_misaligned &&
                            commit_csr_write_req &&
                            !commit_redirect_int;
  assign commit_csr_write_data =
    (commit_csr_op == `RV32I_CSR_OP_RW) ? commit_csr_wdata :
    (commit_csr_op == `RV32I_CSR_OP_RS) ? (commit_csr_rdata | commit_csr_wdata) :
                                          commit_csr_rdata;

  assign dbg_illegal_instr = dbg_illegal_instr_q;
  assign dbg_ecall         = dbg_ecall_q;
  assign dbg_ebreak        = dbg_ebreak_q;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      csr_mtvec_q         <= 32'h0000_0100;
      csr_mepc_q          <= 32'd0;
      csr_mcause_q        <= 32'd0;
      csr_mstatus_q       <= 32'd0;
      csr_mie_q           <= 32'd0;
      dbg_illegal_instr_q <= 1'b0;
      dbg_ecall_q         <= 1'b0;
      dbg_ebreak_q        <= 1'b0;
    end else begin
      dbg_illegal_instr_q <= commit_exception_trap && commit_illegal;
      dbg_ecall_q         <= commit_exception_trap && commit_ecall && !commit_illegal;
      dbg_ebreak_q        <= commit_exception_trap && commit_ebreak && !commit_illegal;

      if (commit_timer_interrupt) begin
        csr_mepc_q   <= commit_trap_pc;
        csr_mcause_q <= `RV32I_TRAP_CAUSE_MTIMER;
        csr_mstatus_q[`RV32I_MSTATUS_MPIE] <= csr_mstatus_q[`RV32I_MSTATUS_MIE];
        csr_mstatus_q[`RV32I_MSTATUS_MIE]  <= 1'b0;
      end else if (commit_exception_trap) begin
        csr_mepc_q   <= commit_trap_pc;
        csr_mcause_q <= commit_exception_cause;
        csr_mstatus_q[`RV32I_MSTATUS_MPIE] <= csr_mstatus_q[`RV32I_MSTATUS_MIE];
        csr_mstatus_q[`RV32I_MSTATUS_MIE]  <= 1'b0;
      end else if (commit_mret_taken) begin
        csr_mstatus_q[`RV32I_MSTATUS_MIE]  <= csr_mstatus_q[`RV32I_MSTATUS_MPIE];
        csr_mstatus_q[`RV32I_MSTATUS_MPIE] <= 1'b1;
      end else if (commit_csr_write) begin
        case (commit_csr_addr)
          `RV32I_CSR_MSTATUS: csr_mstatus_q <= mask_mstatus(commit_csr_write_data);
          `RV32I_CSR_MIE:     csr_mie_q     <= mask_mie(commit_csr_write_data);
          `RV32I_CSR_MTVEC:   csr_mtvec_q   <= commit_csr_write_data;
          `RV32I_CSR_MEPC:    csr_mepc_q    <= commit_csr_write_data;
          `RV32I_CSR_MCAUSE:  csr_mcause_q  <= commit_csr_write_data;
          default: begin
          end
        endcase
      end
    end
  end

endmodule
