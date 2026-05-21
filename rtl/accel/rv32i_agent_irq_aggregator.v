module rv32i_agent_irq_aggregator (
  input  wire        timer_irq,
  input  wire        agent_matrix_irq,
  input  wire        tool_call_irq,
  output wire        cpu_timer_irq,
  output wire [31:0] dbg_status
);

  assign cpu_timer_irq = timer_irq | agent_matrix_irq | tool_call_irq;

  assign dbg_status = {
    28'd0,
    cpu_timer_irq,
    tool_call_irq,
    agent_matrix_irq,
    timer_irq
  };

endmodule
