`include "rv32i_defs.vh"

module rv32i_pipe_lsu (
  input  wire        ex_mem_valid,
  input  wire        ex_mem_illegal,
  input  wire        ex_mem_mem_valid,
  input  wire        ex_mem_mem_write,
  input  wire [1:0]  ex_mem_mem_size,
  input  wire        ex_mem_mem_unsigned,
  input  wire [31:0] ex_mem_mem_addr,
  input  wire [31:0] ex_mem_store_data,

  input  wire        commit_redirect,

  output wire        dmem_valid,
  output wire        dmem_write,
  output wire [31:0] dmem_addr,
  output wire [31:0] dmem_wdata,
  output wire [3:0]  dmem_wstrb,
  input  wire        dmem_ready,
  input  wire [31:0] dmem_rdata,
  input  wire        dmem_error,

  output wire        mem_stall,
  output wire [31:0] mem_load_data,
  output wire        mem_load_addr_misaligned,
  output wire        mem_store_addr_misaligned,
  output wire        mem_load_fault,
  output wire        mem_store_fault
);

  wire        mem_access_valid;
  wire        mem_addr_misaligned;
  wire        mem_access_done;
  wire [7:0]  mem_load_byte;
  wire [15:0] mem_load_half;
  wire [31:0] mem_store_data;
  wire [3:0]  mem_store_wstrb;

  assign mem_access_valid = ex_mem_valid &&
                            ex_mem_mem_valid &&
                            !ex_mem_illegal;
  assign mem_addr_misaligned =
    ((ex_mem_mem_size == `RV32I_MEM_HALF) && ex_mem_mem_addr[0]) ||
    ((ex_mem_mem_size == `RV32I_MEM_WORD) && (ex_mem_mem_addr[1:0] != 2'b00));

  assign dmem_valid = mem_access_valid && !mem_addr_misaligned && !commit_redirect;
  assign dmem_write = dmem_valid && ex_mem_mem_write;
  assign dmem_addr  = ex_mem_mem_addr;
  assign dmem_wdata = mem_store_data;
  assign dmem_wstrb = dmem_write ? mem_store_wstrb : 4'b0000;

  assign mem_stall = dmem_valid && !dmem_ready;
  assign mem_access_done = dmem_valid && dmem_ready;
  assign mem_load_addr_misaligned  = mem_access_valid && mem_addr_misaligned && !ex_mem_mem_write;
  assign mem_store_addr_misaligned = mem_access_valid && mem_addr_misaligned &&  ex_mem_mem_write;
  assign mem_load_fault  = mem_access_done && dmem_error && !ex_mem_mem_write;
  assign mem_store_fault = mem_access_done && dmem_error &&  ex_mem_mem_write;

  assign mem_load_byte = (ex_mem_mem_addr[1:0] == 2'b00) ? dmem_rdata[7:0] :
                         (ex_mem_mem_addr[1:0] == 2'b01) ? dmem_rdata[15:8] :
                         (ex_mem_mem_addr[1:0] == 2'b10) ? dmem_rdata[23:16] :
                                                           dmem_rdata[31:24];
  assign mem_load_half = ex_mem_mem_addr[1] ? dmem_rdata[31:16] : dmem_rdata[15:0];
  assign mem_load_data = (ex_mem_mem_size == `RV32I_MEM_BYTE) ?
                           (ex_mem_mem_unsigned ? {24'd0, mem_load_byte} :
                                                  {{24{mem_load_byte[7]}}, mem_load_byte}) :
                         (ex_mem_mem_size == `RV32I_MEM_HALF) ?
                           (ex_mem_mem_unsigned ? {16'd0, mem_load_half} :
                                                  {{16{mem_load_half[15]}}, mem_load_half}) :
                         dmem_rdata;

  assign mem_store_data = (ex_mem_mem_size == `RV32I_MEM_BYTE) ? {4{ex_mem_store_data[7:0]}} :
                          (ex_mem_mem_size == `RV32I_MEM_HALF) ? {2{ex_mem_store_data[15:0]}} :
                                                                 ex_mem_store_data;
  assign mem_store_wstrb = (ex_mem_mem_size == `RV32I_MEM_BYTE) ? (4'b0001 << ex_mem_mem_addr[1:0]) :
                           (ex_mem_mem_size == `RV32I_MEM_HALF) ? (ex_mem_mem_addr[1] ? 4'b1100 : 4'b0011) :
                                                                  4'b1111;

endmodule
