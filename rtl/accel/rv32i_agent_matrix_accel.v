module rv32i_agent_matrix_accel (
  input  wire        clk,
  input  wire        rst_n,

  input  wire        valid,
  input  wire        write,
  input  wire [31:0] addr,
  input  wire [31:0] wdata,
  input  wire [3:0]  wstrb,
  output wire        ready,
  output wire [31:0] rdata,

  output wire        irq,
  output wire [31:0] dbg_status,
  output wire [31:0] dbg_result0,
  output wire [31:0] dbg_result1,
  output wire [31:0] dbg_result2,
  output wire [31:0] dbg_result3,
  output wire [31:0] dbg_start_count
);

  localparam [11:0] ADDR_CTRL       = 12'h000;
  localparam [11:0] ADDR_STATUS     = 12'h004;
  localparam [11:0] ADDR_SHAPE      = 12'h014;
  localparam [11:0] ADDR_IRQ_STATUS = 12'h028;
  localparam [11:0] ADDR_IRQ_CLEAR  = 12'h02c;
  localparam [11:0] ADDR_SCRATCH_A  = 12'h100;
  localparam [11:0] ADDR_SCRATCH_B  = 12'h140;
  localparam [11:0] ADDR_RESULT     = 12'h180;

  reg        busy_q;
  reg        done_q;
  reg        irq_en_q;
  reg        irq_pending_q;
  reg [31:0] start_count_q;
  reg [7:0]  matrix_q [0:15];
  reg [7:0]  vector_q [0:3];
  reg [31:0] result_q [0:3];

  wire [11:0] reg_offset;
  wire        write_fire;
  wire        start_write;
  wire        clear_write;
  wire        irq_clear_write;
  wire [31:0] status_rdata;
  wire [31:0] shape_rdata;
  wire [31:0] irq_status_rdata;
  wire        scratch_a_sel;
  wire        scratch_b_sel;
  wire        result_sel;
  wire [1:0]  scratch_word;
  wire [1:0]  result_word;
  wire [31:0] scratch_a_rdata;
  wire [31:0] scratch_b_rdata;
  wire [31:0] result_rdata;

  integer i;

  function [31:0] apply_wstrb;
    input [31:0] old_value;
    input [31:0] new_value;
    input [3:0]  byte_en;
    begin
      apply_wstrb = old_value;
      if (byte_en[0]) apply_wstrb[7:0]   = new_value[7:0];
      if (byte_en[1]) apply_wstrb[15:8]  = new_value[15:8];
      if (byte_en[2]) apply_wstrb[23:16] = new_value[23:16];
      if (byte_en[3]) apply_wstrb[31:24] = new_value[31:24];
    end
  endfunction

  function signed [31:0] sx8;
    input [7:0] value;
    begin
      sx8 = {{24{value[7]}}, value};
    end
  endfunction

  function signed [31:0] dot4;
    input integer row;
    begin
      dot4 = (sx8(matrix_q[(row * 4) + 0]) * sx8(vector_q[0])) +
             (sx8(matrix_q[(row * 4) + 1]) * sx8(vector_q[1])) +
             (sx8(matrix_q[(row * 4) + 2]) * sx8(vector_q[2])) +
             (sx8(matrix_q[(row * 4) + 3]) * sx8(vector_q[3]));
    end
  endfunction

  assign reg_offset       = addr[11:0];
  assign write_fire       = valid && ready && write;
  assign start_write      = write_fire && (reg_offset == ADDR_CTRL) && wstrb[0] && wdata[0];
  assign clear_write      = write_fire && (reg_offset == ADDR_CTRL) && wstrb[0] && wdata[2];
  assign irq_clear_write  = write_fire && (reg_offset == ADDR_IRQ_CLEAR) && wstrb[0] && wdata[0];
  assign scratch_a_sel    = (reg_offset[11:4] == ADDR_SCRATCH_A[11:4]);
  assign scratch_b_sel    = (reg_offset[11:4] == ADDR_SCRATCH_B[11:4]);
  assign result_sel       = (reg_offset[11:4] == ADDR_RESULT[11:4]);
  assign scratch_word     = reg_offset[3:2];
  assign result_word      = reg_offset[3:2];

  assign status_rdata     = {29'd0, irq_pending_q, done_q, busy_q};
  assign shape_rdata      = 32'h0004_0104; // M=4, N=1, K=4
  assign irq_status_rdata = {31'd0, irq_pending_q};
  assign scratch_a_rdata  = {matrix_q[{scratch_word, 2'b11}],
                             matrix_q[{scratch_word, 2'b10}],
                             matrix_q[{scratch_word, 2'b01}],
                             matrix_q[{scratch_word, 2'b00}]};
  assign scratch_b_rdata  = (scratch_word == 2'd0) ?
                            {vector_q[3], vector_q[2], vector_q[1], vector_q[0]} :
                            32'd0;
  assign result_rdata     = result_q[result_word];

  assign ready = valid;
  assign rdata = (reg_offset == ADDR_CTRL)       ? {30'd0, irq_en_q, 1'b0} :
                 (reg_offset == ADDR_STATUS)     ? status_rdata :
                 (reg_offset == ADDR_SHAPE)      ? shape_rdata :
                 (reg_offset == ADDR_IRQ_STATUS) ? irq_status_rdata :
                 scratch_a_sel                   ? scratch_a_rdata :
                 scratch_b_sel                   ? scratch_b_rdata :
                 result_sel                      ? result_rdata :
                                                   32'd0;

  assign irq             = irq_pending_q && irq_en_q;
  assign dbg_status      = status_rdata;
  assign dbg_result0     = result_q[0];
  assign dbg_result1     = result_q[1];
  assign dbg_result2     = result_q[2];
  assign dbg_result3     = result_q[3];
  assign dbg_start_count = start_count_q;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      busy_q        <= 1'b0;
      done_q        <= 1'b0;
      irq_en_q      <= 1'b0;
      irq_pending_q <= 1'b0;
      start_count_q <= 32'd0;
      for (i = 0; i < 16; i = i + 1) begin
        matrix_q[i] <= 8'd0;
      end
      for (i = 0; i < 4; i = i + 1) begin
        vector_q[i] <= 8'd0;
        result_q[i] <= 32'd0;
      end
    end else begin
      busy_q <= 1'b0;

      if (clear_write) begin
        done_q        <= 1'b0;
        irq_pending_q <= 1'b0;
      end

      if (irq_clear_write) begin
        irq_pending_q <= 1'b0;
      end

      if (write_fire && (reg_offset == ADDR_CTRL)) begin
        if (wstrb[0]) begin
          irq_en_q <= wdata[1];
        end
      end

      if (write_fire && scratch_a_sel) begin
        if (wstrb[0]) matrix_q[{scratch_word, 2'b00}] <= wdata[7:0];
        if (wstrb[1]) matrix_q[{scratch_word, 2'b01}] <= wdata[15:8];
        if (wstrb[2]) matrix_q[{scratch_word, 2'b10}] <= wdata[23:16];
        if (wstrb[3]) matrix_q[{scratch_word, 2'b11}] <= wdata[31:24];
      end

      if (write_fire && scratch_b_sel && (scratch_word == 2'd0)) begin
        if (wstrb[0]) vector_q[0] <= wdata[7:0];
        if (wstrb[1]) vector_q[1] <= wdata[15:8];
        if (wstrb[2]) vector_q[2] <= wdata[23:16];
        if (wstrb[3]) vector_q[3] <= wdata[31:24];
      end

      if (write_fire && result_sel) begin
        result_q[result_word] <= apply_wstrb(result_q[result_word], wdata, wstrb);
      end

      if (start_write) begin
        busy_q        <= 1'b1;
        done_q        <= 1'b1;
        irq_pending_q <= 1'b1;
        start_count_q <= start_count_q + 32'd1;
        result_q[0]   <= dot4(0);
        result_q[1]   <= dot4(1);
        result_q[2]   <= dot4(2);
        result_q[3]   <= dot4(3);
      end
    end
  end

endmodule
