module rv32i_agent_periph_cluster #(
  parameter [31:0] AGENT_MATRIX_BASE = 32'h4200_2000,
  parameter [31:0] AGENT_MATRIX_MASK = 32'hFFFF_F000,
  parameter [31:0] TOOL_CALL_BASE    = 32'h4200_3000,
  parameter [31:0] TOOL_CALL_MASK    = 32'hFFFF_F000,
  parameter [31:0] AGENT_EVENT_BASE  = 32'h4200_4000,
  parameter [31:0] AGENT_EVENT_MASK  = 32'hFFFF_F000
) (
  input  wire        clk,
  input  wire        rst_n,

  input  wire        valid,
  input  wire        write,
  input  wire [31:0] addr,
  input  wire [31:0] wdata,
  input  wire [3:0]  wstrb,
  output wire        ready,
  output wire [31:0] rdata,
  output wire        decode_error,

  output wire        matrix_mem_valid,
  output wire        matrix_mem_write,
  output wire [31:0] matrix_mem_addr,
  output wire [31:0] matrix_mem_wdata,
  output wire [3:0]  matrix_mem_wstrb,
  input  wire        matrix_mem_ready,
  input  wire [31:0] matrix_mem_rdata,
  input  wire        matrix_mem_error,

  input  wire        timer_irq,
  output wire        agent_matrix_irq,
  output wire        tool_call_irq,
  output wire        cpu_timer_irq,
  output wire [31:0] dbg_agent_irq_status,

  output wire [31:0] dbg_agent_matrix_status,
  output wire [31:0] dbg_agent_matrix_result0,
  output wire [31:0] dbg_agent_matrix_result1,
  output wire [31:0] dbg_agent_matrix_result2,
  output wire [31:0] dbg_agent_matrix_result3,
  output wire [31:0] dbg_agent_matrix_start_count,
  output wire [31:0] dbg_tool_call_status,
  output wire [31:0] dbg_tool_call_match_count,
  output wire [31:0] dbg_tool_call_token_count,
  output wire [31:0] dbg_tool_call_last_token,
  output wire [31:0] dbg_agent_event_status,
  output wire [31:0] dbg_agent_event_tool_token_count,
  output wire [31:0] dbg_agent_event_tool_match_count,
  output wire [31:0] dbg_agent_event_tool_irq_count,
  output wire [31:0] dbg_agent_event_matrix_start_count,
  output wire [31:0] dbg_agent_event_matrix_done_count,
  output wire [31:0] dbg_agent_event_agent_irq_count,
  output wire [31:0] dbg_agent_event_last_irq_source,
  output wire [31:0] dbg_agent_event_latency_last
);

  wire matrix_sel;
  wire tool_call_sel;
  wire agent_event_sel;

  wire        matrix_valid;
  wire        matrix_write;
  wire [31:0] matrix_addr;
  wire [31:0] matrix_wdata;
  wire [3:0]  matrix_wstrb;
  wire        matrix_ready;
  wire [31:0] matrix_rdata;

  wire        tool_call_valid;
  wire        tool_call_write;
  wire [31:0] tool_call_addr;
  wire [31:0] tool_call_wdata;
  wire [3:0]  tool_call_wstrb;
  wire        tool_call_ready;
  wire [31:0] tool_call_rdata;

  wire        agent_event_valid;
  wire        agent_event_write;
  wire [31:0] agent_event_addr;
  wire [31:0] agent_event_wdata;
  wire [3:0]  agent_event_wstrb;
  wire        agent_event_ready;
  wire [31:0] agent_event_rdata;

  wire        agent_matrix_irq_w;
  wire        tool_call_irq_w;
  wire        cpu_timer_irq_w;

  wire        tool_event_token;
  wire        tool_event_match;
  wire        tool_event_irq_clear;
  wire        matrix_event_start;
  wire        matrix_event_done;

  assign matrix_sel      = ((addr & AGENT_MATRIX_MASK) == AGENT_MATRIX_BASE);
  assign tool_call_sel   = ((addr & TOOL_CALL_MASK) == TOOL_CALL_BASE);
  assign agent_event_sel = ((addr & AGENT_EVENT_MASK) == AGENT_EVENT_BASE);

  assign matrix_valid = valid && matrix_sel;
  assign matrix_write = write;
  assign matrix_addr  = addr;
  assign matrix_wdata = wdata;
  assign matrix_wstrb = wstrb;

  assign tool_call_valid = valid && tool_call_sel;
  assign tool_call_write = write;
  assign tool_call_addr  = addr;
  assign tool_call_wdata = wdata;
  assign tool_call_wstrb = wstrb;

  assign agent_event_valid = valid && agent_event_sel;
  assign agent_event_write = write;
  assign agent_event_addr  = addr;
  assign agent_event_wdata = wdata;
  assign agent_event_wstrb = wstrb;

  assign ready = !valid ? 1'b1 :
                 matrix_sel      ? matrix_ready :
                 tool_call_sel   ? tool_call_ready :
                 agent_event_sel ? agent_event_ready :
                                   1'b1;

  assign rdata = matrix_sel      ? matrix_rdata :
                 tool_call_sel   ? tool_call_rdata :
                 agent_event_sel ? agent_event_rdata :
                                   32'd0;

  assign decode_error = valid && !matrix_sel && !tool_call_sel && !agent_event_sel;

  assign agent_matrix_irq = agent_matrix_irq_w;
  assign tool_call_irq    = tool_call_irq_w;
  assign cpu_timer_irq    = cpu_timer_irq_w;

  rv32i_agent_matrix_accel u_agent_matrix_accel (
    .clk             (clk),
    .rst_n           (rst_n),
    .valid           (matrix_valid),
    .write           (matrix_write),
    .addr            (matrix_addr),
    .wdata           (matrix_wdata),
    .wstrb           (matrix_wstrb),
    .ready           (matrix_ready),
    .rdata           (matrix_rdata),
    .mem_valid       (matrix_mem_valid),
    .mem_write       (matrix_mem_write),
    .mem_addr        (matrix_mem_addr),
    .mem_wdata       (matrix_mem_wdata),
    .mem_wstrb       (matrix_mem_wstrb),
    .mem_ready       (matrix_mem_ready),
    .mem_rdata       (matrix_mem_rdata),
    .mem_error       (matrix_mem_error),
    .irq             (agent_matrix_irq_w),
    .dbg_status      (dbg_agent_matrix_status),
    .dbg_result0     (dbg_agent_matrix_result0),
    .dbg_result1     (dbg_agent_matrix_result1),
    .dbg_result2     (dbg_agent_matrix_result2),
    .dbg_result3     (dbg_agent_matrix_result3),
    .dbg_start_count (dbg_agent_matrix_start_count),
    .event_start     (matrix_event_start),
    .event_done      (matrix_event_done)
  );

  rv32i_tool_call_detector u_tool_call_detector (
    .clk             (clk),
    .rst_n           (rst_n),
    .valid           (tool_call_valid),
    .write           (tool_call_write),
    .addr            (tool_call_addr),
    .wdata           (tool_call_wdata),
    .wstrb           (tool_call_wstrb),
    .ready           (tool_call_ready),
    .rdata           (tool_call_rdata),
    .irq             (tool_call_irq_w),
    .dbg_status      (dbg_tool_call_status),
    .dbg_match_count (dbg_tool_call_match_count),
    .dbg_token_count (dbg_tool_call_token_count),
    .dbg_last_token  (dbg_tool_call_last_token),
    .event_token     (tool_event_token),
    .event_match     (tool_event_match),
    .event_irq_clear (tool_event_irq_clear)
  );

  rv32i_agent_irq_aggregator u_agent_irq_aggregator (
    .timer_irq        (timer_irq),
    .agent_matrix_irq (agent_matrix_irq_w),
    .tool_call_irq    (tool_call_irq_w),
    .cpu_timer_irq    (cpu_timer_irq_w),
    .dbg_status       (dbg_agent_irq_status)
  );

  rv32i_agent_event_counter u_agent_event_counter (
    .clk                         (clk),
    .rst_n                       (rst_n),
    .valid                       (agent_event_valid),
    .write                       (agent_event_write),
    .addr                        (agent_event_addr),
    .wdata                       (agent_event_wdata),
    .wstrb                       (agent_event_wstrb),
    .ready                       (agent_event_ready),
    .rdata                       (agent_event_rdata),
    .tool_token_event            (tool_event_token),
    .tool_match_event            (tool_event_match),
    .tool_irq_clear_event        (tool_event_irq_clear),
    .matrix_start_event          (matrix_event_start),
    .matrix_done_event           (matrix_event_done),
    .timer_irq                   (timer_irq),
    .agent_matrix_irq            (agent_matrix_irq_w),
    .tool_call_irq               (tool_call_irq_w),
    .cpu_timer_irq               (cpu_timer_irq_w),
    .dbg_status                  (dbg_agent_event_status),
    .dbg_tool_token_count        (dbg_agent_event_tool_token_count),
    .dbg_tool_match_count        (dbg_agent_event_tool_match_count),
    .dbg_tool_irq_count          (dbg_agent_event_tool_irq_count),
    .dbg_matrix_start_count      (dbg_agent_event_matrix_start_count),
    .dbg_matrix_done_count       (dbg_agent_event_matrix_done_count),
    .dbg_agent_irq_count         (dbg_agent_event_agent_irq_count),
    .dbg_last_irq_source         (dbg_agent_event_last_irq_source),
    .dbg_latency_last            (dbg_agent_event_latency_last)
  );

endmodule
