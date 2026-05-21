module rv32i_apb_periph_mux #(
  parameter [31:0] TIMER_BASE = 32'h4200_0000,
  parameter [31:0] TIMER_MASK = 32'hFFFF_F000,
  parameter [31:0] UART_BASE  = 32'h4200_1000,
  parameter [31:0] UART_MASK  = 32'hFFFF_F000
) (
  input  wire        psel,
  input  wire        penable,
  input  wire [31:0] paddr,
  input  wire        pwrite,
  input  wire [31:0] pwdata,
  input  wire [3:0]  pstrb,
  input  wire [2:0]  pprot,
  output wire [31:0] prdata,
  output wire        pready,
  output wire        pslverr,

  output wire        timer_valid,
  output wire        timer_write,
  output wire [31:0] timer_addr,
  output wire [31:0] timer_wdata,
  output wire [3:0]  timer_wstrb,
  input  wire        timer_ready,
  input  wire [31:0] timer_rdata,

  output wire        uart_valid,
  output wire        uart_write,
  output wire [31:0] uart_addr,
  output wire [31:0] uart_wdata,
  output wire [3:0]  uart_wstrb,
  input  wire        uart_ready,
  input  wire [31:0] uart_rdata,

  output wire        dbg_decode_error
);

  wire apb_access;
  wire timer_sel;
  wire uart_sel;

  assign apb_access = psel && penable;
  assign timer_sel  = ((paddr & TIMER_MASK) == TIMER_BASE);
  assign uart_sel   = ((paddr & UART_MASK) == UART_BASE);

  assign timer_valid = apb_access && timer_sel;
  assign timer_write = pwrite;
  assign timer_addr  = paddr;
  assign timer_wdata = pwdata;
  assign timer_wstrb = pstrb;

  assign uart_valid = apb_access && uart_sel;
  assign uart_write = pwrite;
  assign uart_addr  = paddr;
  assign uart_wdata = pwdata;
  assign uart_wstrb = pstrb;

  assign pready = !apb_access ? 1'b1 :
                  timer_sel   ? timer_ready :
                  uart_sel    ? uart_ready  :
                                1'b1;
  assign prdata = timer_sel ? timer_rdata :
                  uart_sel  ? uart_rdata  :
                              32'd0;
  assign pslverr = apb_access && !timer_sel && !uart_sel;

  assign dbg_decode_error = pslverr;

  wire [2:0] unused_pprot = pprot;

endmodule
