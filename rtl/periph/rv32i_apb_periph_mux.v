module rv32i_apb_periph_mux #(
  parameter [31:0] TIMER_BASE = 32'h4200_0000,
  parameter [31:0] TIMER_MASK = 32'hFFFF_F000,
  parameter [31:0] UART_BASE  = 32'h4200_1000,
  parameter [31:0] UART_MASK  = 32'hFFFF_F000,
  parameter [31:0] AGENT_MATRIX_BASE = 32'h4200_2000,
  parameter [31:0] AGENT_MATRIX_MASK = 32'hFFFF_F000,
  parameter [31:0] TOOL_CALL_BASE = 32'h4200_3000,
  parameter [31:0] TOOL_CALL_MASK = 32'hFFFF_F000,
  parameter [31:0] AGENT_EVENT_BASE = 32'h4200_4000,
  parameter [31:0] AGENT_EVENT_MASK = 32'hFFFF_F000
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

  output wire        agent_matrix_valid,
  output wire        agent_matrix_write,
  output wire [31:0] agent_matrix_addr,
  output wire [31:0] agent_matrix_wdata,
  output wire [3:0]  agent_matrix_wstrb,
  input  wire        agent_matrix_ready,
  input  wire [31:0] agent_matrix_rdata,

  output wire        tool_call_valid,
  output wire        tool_call_write,
  output wire [31:0] tool_call_addr,
  output wire [31:0] tool_call_wdata,
  output wire [3:0]  tool_call_wstrb,
  input  wire        tool_call_ready,
  input  wire [31:0] tool_call_rdata,

  output wire        agent_event_valid,
  output wire        agent_event_write,
  output wire [31:0] agent_event_addr,
  output wire [31:0] agent_event_wdata,
  output wire [3:0]  agent_event_wstrb,
  input  wire        agent_event_ready,
  input  wire [31:0] agent_event_rdata,

  output wire        dbg_decode_error
);

  wire apb_access;
  wire timer_sel;
  wire uart_sel;
  wire agent_matrix_sel;
  wire tool_call_sel;
  wire agent_event_sel;

  assign apb_access       = psel && penable;
  assign timer_sel        = ((paddr & TIMER_MASK) == TIMER_BASE);
  assign uart_sel         = ((paddr & UART_MASK) == UART_BASE);
  assign agent_matrix_sel = ((paddr & AGENT_MATRIX_MASK) == AGENT_MATRIX_BASE);
  assign tool_call_sel    = ((paddr & TOOL_CALL_MASK) == TOOL_CALL_BASE);
  assign agent_event_sel  = ((paddr & AGENT_EVENT_MASK) == AGENT_EVENT_BASE);

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

  assign agent_matrix_valid = apb_access && agent_matrix_sel;
  assign agent_matrix_write = pwrite;
  assign agent_matrix_addr  = paddr;
  assign agent_matrix_wdata = pwdata;
  assign agent_matrix_wstrb = pstrb;

  assign tool_call_valid = apb_access && tool_call_sel;
  assign tool_call_write = pwrite;
  assign tool_call_addr  = paddr;
  assign tool_call_wdata = pwdata;
  assign tool_call_wstrb = pstrb;

  assign agent_event_valid = apb_access && agent_event_sel;
  assign agent_event_write = pwrite;
  assign agent_event_addr  = paddr;
  assign agent_event_wdata = pwdata;
  assign agent_event_wstrb = pstrb;

  assign pready = !apb_access ? 1'b1 :
                  timer_sel   ? timer_ready :
                  uart_sel    ? uart_ready  :
                  agent_matrix_sel ? agent_matrix_ready :
                  tool_call_sel    ? tool_call_ready :
                  agent_event_sel  ? agent_event_ready :
                                1'b1;
  assign prdata = timer_sel ? timer_rdata :
                  uart_sel  ? uart_rdata  :
                  agent_matrix_sel ? agent_matrix_rdata :
                  tool_call_sel    ? tool_call_rdata :
                  agent_event_sel  ? agent_event_rdata :
                              32'd0;
  assign pslverr = apb_access && !timer_sel && !uart_sel &&
                   !agent_matrix_sel && !tool_call_sel &&
                   !agent_event_sel;

  assign dbg_decode_error = pslverr;

  wire [2:0] unused_pprot = pprot;

endmodule
