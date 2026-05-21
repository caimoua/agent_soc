module rv32i_mmio_periph_mux #(
  parameter [31:0] TIMER_BASE = 32'h4000_0000,
  parameter [31:0] TIMER_MASK = 32'hFFFF_F000,
  parameter [31:0] UART_BASE  = 32'h4000_1000,
  parameter [31:0] UART_MASK  = 32'hFFFF_F000
) (
  input  wire        valid,
  input  wire        write,
  input  wire [31:0] addr,
  input  wire [31:0] wdata,
  input  wire [3:0]  wstrb,
  output wire        ready,
  output wire [31:0] rdata,

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

  wire timer_sel;
  wire uart_sel;

  assign timer_sel = valid && ((addr & TIMER_MASK) == TIMER_BASE);
  assign uart_sel  = valid && ((addr & UART_MASK) == UART_BASE);

  assign timer_valid = timer_sel;
  assign timer_write = write;
  assign timer_addr  = addr;
  assign timer_wdata = wdata;
  assign timer_wstrb = wstrb;

  assign uart_valid = uart_sel;
  assign uart_write = write;
  assign uart_addr  = addr;
  assign uart_wdata = wdata;
  assign uart_wstrb = wstrb;

  assign ready = timer_sel ? timer_ready :
                 uart_sel  ? uart_ready  :
                             valid;
  assign rdata = timer_sel ? timer_rdata :
                 uart_sel  ? uart_rdata  :
                             32'd0;

  assign dbg_decode_error = valid && !timer_sel && !uart_sel;

endmodule
