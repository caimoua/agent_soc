module rv32i_agent_event_counter (
  input  wire        clk,
  input  wire        rst_n,

  input  wire        valid,
  input  wire        write,
  input  wire [31:0] addr,
  input  wire [31:0] wdata,
  input  wire [3:0]  wstrb,
  output wire        ready,
  output wire [31:0] rdata,

  input  wire        tool_token_event,
  input  wire        tool_match_event,
  input  wire        tool_irq_clear_event,
  input  wire        matrix_start_event,
  input  wire        matrix_done_event,
  input  wire        timer_irq,
  input  wire        agent_matrix_irq,
  input  wire        tool_call_irq,
  input  wire        cpu_timer_irq,

  output wire [31:0] dbg_status,
  output wire [31:0] dbg_tool_token_count,
  output wire [31:0] dbg_tool_match_count,
  output wire [31:0] dbg_tool_irq_count,
  output wire [31:0] dbg_matrix_start_count,
  output wire [31:0] dbg_matrix_done_count,
  output wire [31:0] dbg_agent_irq_count,
  output wire [31:0] dbg_last_irq_source,
  output wire [31:0] dbg_latency_last
);

  localparam [11:0] ADDR_CTRL               = 12'h000;
  localparam [11:0] ADDR_STATUS             = 12'h004;
  localparam [11:0] ADDR_TOOL_TOKEN_COUNT   = 12'h008;
  localparam [11:0] ADDR_TOOL_MATCH_COUNT   = 12'h00c;
  localparam [11:0] ADDR_TOOL_IRQ_COUNT     = 12'h010;
  localparam [11:0] ADDR_MATRIX_START_COUNT = 12'h014;
  localparam [11:0] ADDR_MATRIX_DONE_COUNT  = 12'h018;
  localparam [11:0] ADDR_AGENT_IRQ_COUNT    = 12'h01c;
  localparam [11:0] ADDR_LAST_IRQ_SOURCE    = 12'h020;
  localparam [11:0] ADDR_LATENCY_LAST       = 12'h024;
  localparam [11:0] ADDR_LATENCY_MIN        = 12'h028;
  localparam [11:0] ADDR_LATENCY_MAX        = 12'h02c;
  localparam [11:0] ADDR_LATENCY_COUNT      = 12'h030;
  localparam [11:0] ADDR_MATRIX_IRQ_COUNT   = 12'h034;
  localparam [11:0] ADDR_TIMER_IRQ_COUNT    = 12'h038;

  reg [31:0] tool_token_count_q;
  reg [31:0] tool_match_count_q;
  reg [31:0] tool_irq_count_q;
  reg [31:0] matrix_start_count_q;
  reg [31:0] matrix_done_count_q;
  reg [31:0] agent_irq_count_q;
  reg [31:0] matrix_irq_count_q;
  reg [31:0] timer_irq_count_q;
  reg [31:0] latency_counter_q;
  reg [31:0] latency_last_q;
  reg [31:0] latency_min_q;
  reg [31:0] latency_max_q;
  reg [31:0] latency_count_q;
  reg [3:0]  last_irq_source_q;
  reg        last_irq_valid_q;
  reg        latency_active_q;
  reg        timer_irq_q;
  reg        agent_matrix_irq_q;
  reg        tool_call_irq_q;
  reg        cpu_timer_irq_q;

  wire [11:0] reg_offset;
  wire        write_fire;
  wire        clear_write;
  wire        timer_irq_rise;
  wire        agent_matrix_irq_rise;
  wire        tool_call_irq_rise;
  wire        cpu_timer_irq_rise;
  wire [3:0]  irq_source_event;
  wire        any_irq_rise;
  wire [31:0] latency_sample;
  wire [31:0] latency_min_rdata;
  wire [31:0] status_rdata;

  assign reg_offset = addr[11:0];
  assign write_fire = valid && ready && write;
  assign clear_write = write_fire && (reg_offset == ADDR_CTRL) &&
                       wstrb[0] && wdata[0];

  assign timer_irq_rise        = timer_irq && !timer_irq_q;
  assign agent_matrix_irq_rise = agent_matrix_irq && !agent_matrix_irq_q;
  assign tool_call_irq_rise    = tool_call_irq && !tool_call_irq_q;
  assign cpu_timer_irq_rise    = cpu_timer_irq && !cpu_timer_irq_q;

  assign irq_source_event = {
    cpu_timer_irq_rise,
    tool_call_irq_rise,
    agent_matrix_irq_rise,
    timer_irq_rise
  };
  assign any_irq_rise = |irq_source_event;

  assign latency_sample = latency_counter_q;
  assign latency_min_rdata = (latency_count_q == 32'd0) ? 32'd0 : latency_min_q;
  assign status_rdata = {24'd0, last_irq_source_q, 2'd0,
                         last_irq_valid_q, latency_active_q};

  assign ready = valid;
  assign rdata = (reg_offset == ADDR_CTRL)               ? 32'd0 :
                 (reg_offset == ADDR_STATUS)             ? status_rdata :
                 (reg_offset == ADDR_TOOL_TOKEN_COUNT)   ? tool_token_count_q :
                 (reg_offset == ADDR_TOOL_MATCH_COUNT)   ? tool_match_count_q :
                 (reg_offset == ADDR_TOOL_IRQ_COUNT)     ? tool_irq_count_q :
                 (reg_offset == ADDR_MATRIX_START_COUNT) ? matrix_start_count_q :
                 (reg_offset == ADDR_MATRIX_DONE_COUNT)  ? matrix_done_count_q :
                 (reg_offset == ADDR_AGENT_IRQ_COUNT)    ? agent_irq_count_q :
                 (reg_offset == ADDR_LAST_IRQ_SOURCE)    ? {28'd0, last_irq_source_q} :
                 (reg_offset == ADDR_LATENCY_LAST)       ? latency_last_q :
                 (reg_offset == ADDR_LATENCY_MIN)        ? latency_min_rdata :
                 (reg_offset == ADDR_LATENCY_MAX)        ? latency_max_q :
                 (reg_offset == ADDR_LATENCY_COUNT)      ? latency_count_q :
                 (reg_offset == ADDR_MATRIX_IRQ_COUNT)   ? matrix_irq_count_q :
                 (reg_offset == ADDR_TIMER_IRQ_COUNT)    ? timer_irq_count_q :
                                                            32'd0;

  assign dbg_status             = status_rdata;
  assign dbg_tool_token_count   = tool_token_count_q;
  assign dbg_tool_match_count   = tool_match_count_q;
  assign dbg_tool_irq_count     = tool_irq_count_q;
  assign dbg_matrix_start_count = matrix_start_count_q;
  assign dbg_matrix_done_count  = matrix_done_count_q;
  assign dbg_agent_irq_count    = agent_irq_count_q;
  assign dbg_last_irq_source    = {28'd0, last_irq_source_q};
  assign dbg_latency_last       = latency_last_q;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tool_token_count_q   <= 32'd0;
      tool_match_count_q   <= 32'd0;
      tool_irq_count_q     <= 32'd0;
      matrix_start_count_q <= 32'd0;
      matrix_done_count_q  <= 32'd0;
      agent_irq_count_q    <= 32'd0;
      matrix_irq_count_q   <= 32'd0;
      timer_irq_count_q    <= 32'd0;
      latency_counter_q    <= 32'd0;
      latency_last_q       <= 32'd0;
      latency_min_q        <= 32'hffff_ffff;
      latency_max_q        <= 32'd0;
      latency_count_q      <= 32'd0;
      last_irq_source_q    <= 4'd0;
      last_irq_valid_q     <= 1'b0;
      latency_active_q     <= 1'b0;
      timer_irq_q          <= 1'b0;
      agent_matrix_irq_q   <= 1'b0;
      tool_call_irq_q      <= 1'b0;
      cpu_timer_irq_q      <= 1'b0;
    end else begin
      timer_irq_q        <= timer_irq;
      agent_matrix_irq_q <= agent_matrix_irq;
      tool_call_irq_q    <= tool_call_irq;
      cpu_timer_irq_q    <= cpu_timer_irq;

      if (clear_write) begin
        tool_token_count_q   <= 32'd0;
        tool_match_count_q   <= 32'd0;
        tool_irq_count_q     <= 32'd0;
        matrix_start_count_q <= 32'd0;
        matrix_done_count_q  <= 32'd0;
        agent_irq_count_q    <= 32'd0;
        matrix_irq_count_q   <= 32'd0;
        timer_irq_count_q    <= 32'd0;
        latency_counter_q    <= 32'd0;
        latency_last_q       <= 32'd0;
        latency_min_q        <= 32'hffff_ffff;
        latency_max_q        <= 32'd0;
        latency_count_q      <= 32'd0;
        last_irq_source_q    <= 4'd0;
        last_irq_valid_q     <= 1'b0;
        latency_active_q     <= 1'b0;
      end else begin
        if (tool_token_event) begin
          tool_token_count_q <= tool_token_count_q + 32'd1;
        end
        if (tool_match_event) begin
          tool_match_count_q <= tool_match_count_q + 32'd1;
          latency_active_q   <= 1'b1;
          latency_counter_q  <= 32'd0;
        end else if (latency_active_q && !tool_irq_clear_event) begin
          latency_counter_q <= latency_counter_q + 32'd1;
        end

        if (tool_irq_clear_event && latency_active_q) begin
          latency_active_q  <= 1'b0;
          latency_last_q    <= latency_sample;
          latency_count_q   <= latency_count_q + 32'd1;
          if ((latency_count_q == 32'd0) || (latency_sample < latency_min_q)) begin
            latency_min_q <= latency_sample;
          end
          if (latency_sample > latency_max_q) begin
            latency_max_q <= latency_sample;
          end
        end

        if (matrix_start_event) begin
          matrix_start_count_q <= matrix_start_count_q + 32'd1;
        end
        if (matrix_done_event) begin
          matrix_done_count_q <= matrix_done_count_q + 32'd1;
        end

        if (tool_call_irq_rise) begin
          tool_irq_count_q <= tool_irq_count_q + 32'd1;
        end
        if (agent_matrix_irq_rise) begin
          matrix_irq_count_q <= matrix_irq_count_q + 32'd1;
        end
        if (timer_irq_rise) begin
          timer_irq_count_q <= timer_irq_count_q + 32'd1;
        end
        if (cpu_timer_irq_rise) begin
          agent_irq_count_q <= agent_irq_count_q + 32'd1;
        end
        if (any_irq_rise) begin
          last_irq_source_q <= irq_source_event;
          last_irq_valid_q  <= 1'b1;
        end
      end
    end
  end

endmodule
