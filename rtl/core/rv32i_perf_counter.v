module rv32i_perf_counter (
  input  wire        clk,
  input  wire        rst_n,

  input  wire        instret_event,
  input  wire        stall_event,
  input  wire        flush_event,
  input  wire        branch_event,
  input  wire        branch_mispredict_event,

  output reg  [31:0] cycle_count,
  output reg  [31:0] instret_count,
  output reg  [31:0] stall_cycle_count,
  output reg  [31:0] flush_cycle_count,
  output reg  [31:0] branch_count,
  output reg  [31:0] branch_mispredict_count
);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_count             <= 32'd0;
      instret_count           <= 32'd0;
      stall_cycle_count       <= 32'd0;
      flush_cycle_count       <= 32'd0;
      branch_count            <= 32'd0;
      branch_mispredict_count <= 32'd0;
    end else begin
      cycle_count <= cycle_count + 32'd1;

      if (instret_event) begin
        instret_count <= instret_count + 32'd1;
      end
      if (stall_event) begin
        stall_cycle_count <= stall_cycle_count + 32'd1;
      end
      if (flush_event) begin
        flush_cycle_count <= flush_cycle_count + 32'd1;
      end
      if (branch_event) begin
        branch_count <= branch_count + 32'd1;
      end
      if (branch_mispredict_event) begin
        branch_mispredict_count <= branch_mispredict_count + 32'd1;
      end
    end
  end

endmodule
