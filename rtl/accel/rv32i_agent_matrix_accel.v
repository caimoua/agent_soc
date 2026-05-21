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

  output wire        mem_valid,
  output wire        mem_write,
  output wire [31:0] mem_addr,
  output wire [31:0] mem_wdata,
  output wire [3:0]  mem_wstrb,
  input  wire        mem_ready,
  input  wire [31:0] mem_rdata,
  input  wire        mem_error,

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
  localparam [11:0] ADDR_SRC_A      = 12'h008;
  localparam [11:0] ADDR_SRC_B      = 12'h00c;
  localparam [11:0] ADDR_DST        = 12'h010;
  localparam [11:0] ADDR_SHAPE      = 12'h014;
  localparam [11:0] ADDR_STRIDE_A   = 12'h018;
  localparam [11:0] ADDR_STRIDE_B   = 12'h01c;
  localparam [11:0] ADDR_STRIDE_D   = 12'h020;
  localparam [11:0] ADDR_FLAGS      = 12'h024;
  localparam [11:0] ADDR_IRQ_STATUS = 12'h028;
  localparam [11:0] ADDR_IRQ_CLEAR  = 12'h02c;
  localparam [11:0] ADDR_SCRATCH_A  = 12'h100;
  localparam [11:0] ADDR_SCRATCH_B  = 12'h140;
  localparam [11:0] ADDR_RESULT     = 12'h180;

  localparam [2:0] STATE_IDLE    = 3'd0;
  localparam [2:0] STATE_LOAD_A  = 3'd1;
  localparam [2:0] STATE_LOAD_B  = 3'd2;
  localparam [2:0] STATE_COMPUTE = 3'd3;
  localparam [2:0] STATE_STORE   = 3'd4;

  reg        busy_q;
  reg        done_q;
  reg        irq_en_q;
  reg        irq_pending_q;
  reg        error_q;
  reg [31:0] start_count_q;
  reg [31:0] src_a_q;
  reg [31:0] src_b_q;
  reg [31:0] dst_q;
  reg [31:0] stride_a_q;
  reg [31:0] stride_b_q;
  reg [31:0] stride_d_q;
  reg [31:0] flags_q;
  reg [2:0]  state_q;
  reg [1:0]  mem_index_q;
  reg [7:0]  matrix_q [0:15];
  reg [7:0]  vector_q [0:3];
  reg [31:0] result_q [0:3];

  wire [11:0] reg_offset;
  wire        write_fire;
  wire        start_write;
  wire        start_scratch;
  wire        start_sram;
  wire        clear_write;
  wire        irq_clear_write;
  wire [31:0] status_rdata;
  wire [31:0] shape_rdata;
  wire [31:0] irq_status_rdata;
  wire [31:0] mem_index_ext;
  wire [31:0] load_a_addr;
  wire [31:0] store_addr;
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
  assign start_scratch    = start_write && !flags_q[0];
  assign start_sram       = start_write && flags_q[0];
  assign clear_write      = write_fire && (reg_offset == ADDR_CTRL) && wstrb[0] && wdata[2];
  assign irq_clear_write  = write_fire && (reg_offset == ADDR_IRQ_CLEAR) && wstrb[0] && wdata[0];
  assign scratch_a_sel    = (reg_offset[11:4] == ADDR_SCRATCH_A[11:4]);
  assign scratch_b_sel    = (reg_offset[11:4] == ADDR_SCRATCH_B[11:4]);
  assign result_sel       = (reg_offset[11:4] == ADDR_RESULT[11:4]);
  assign scratch_word     = reg_offset[3:2];
  assign result_word      = reg_offset[3:2];

  assign mem_index_ext    = {30'd0, mem_index_q};
  assign load_a_addr      = src_a_q + (stride_a_q * mem_index_ext);
  assign store_addr       = dst_q + (stride_d_q * mem_index_ext);

  assign status_rdata     = {28'd0, error_q, irq_pending_q, done_q, busy_q};
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
                 (reg_offset == ADDR_SRC_A)      ? src_a_q :
                 (reg_offset == ADDR_SRC_B)      ? src_b_q :
                 (reg_offset == ADDR_DST)        ? dst_q :
                 (reg_offset == ADDR_SHAPE)      ? shape_rdata :
                 (reg_offset == ADDR_STRIDE_A)   ? stride_a_q :
                 (reg_offset == ADDR_STRIDE_B)   ? stride_b_q :
                 (reg_offset == ADDR_STRIDE_D)   ? stride_d_q :
                 (reg_offset == ADDR_FLAGS)      ? flags_q :
                 (reg_offset == ADDR_IRQ_STATUS) ? irq_status_rdata :
                 scratch_a_sel                   ? scratch_a_rdata :
                 scratch_b_sel                   ? scratch_b_rdata :
                 result_sel                      ? result_rdata :
                                                   32'd0;

  assign mem_valid = (state_q == STATE_LOAD_A) ||
                     (state_q == STATE_LOAD_B) ||
                     (state_q == STATE_STORE);
  assign mem_write = (state_q == STATE_STORE);
  assign mem_addr  = (state_q == STATE_LOAD_A) ? load_a_addr :
                     (state_q == STATE_LOAD_B) ? src_b_q :
                     (state_q == STATE_STORE)  ? store_addr :
                                                 32'd0;
  assign mem_wdata = (state_q == STATE_STORE) ? result_q[mem_index_q] : 32'd0;
  assign mem_wstrb = (state_q == STATE_STORE) ? 4'b1111 : 4'b0000;

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
      error_q       <= 1'b0;
      start_count_q <= 32'd0;
      src_a_q       <= 32'd0;
      src_b_q       <= 32'd0;
      dst_q         <= 32'd0;
      stride_a_q    <= 32'd4;
      stride_b_q    <= 32'd4;
      stride_d_q    <= 32'd4;
      flags_q       <= 32'd0;
      state_q       <= STATE_IDLE;
      mem_index_q   <= 2'd0;
      for (i = 0; i < 16; i = i + 1) begin
        matrix_q[i] <= 8'd0;
      end
      for (i = 0; i < 4; i = i + 1) begin
        vector_q[i] <= 8'd0;
        result_q[i] <= 32'd0;
      end
    end else begin
      if (state_q == STATE_IDLE) begin
        busy_q <= 1'b0;
      end

      if (clear_write) begin
        done_q        <= 1'b0;
        irq_pending_q <= 1'b0;
        error_q       <= 1'b0;
      end

      if (irq_clear_write) begin
        irq_pending_q <= 1'b0;
      end

      if (write_fire && (reg_offset == ADDR_CTRL)) begin
        if (wstrb[0]) begin
          irq_en_q <= wdata[1];
        end
      end

      if (write_fire && (reg_offset == ADDR_SRC_A)) begin
        src_a_q <= apply_wstrb(src_a_q, wdata, wstrb);
      end
      if (write_fire && (reg_offset == ADDR_SRC_B)) begin
        src_b_q <= apply_wstrb(src_b_q, wdata, wstrb);
      end
      if (write_fire && (reg_offset == ADDR_DST)) begin
        dst_q <= apply_wstrb(dst_q, wdata, wstrb);
      end
      if (write_fire && (reg_offset == ADDR_STRIDE_A)) begin
        stride_a_q <= apply_wstrb(stride_a_q, wdata, wstrb);
      end
      if (write_fire && (reg_offset == ADDR_STRIDE_B)) begin
        stride_b_q <= apply_wstrb(stride_b_q, wdata, wstrb);
      end
      if (write_fire && (reg_offset == ADDR_STRIDE_D)) begin
        stride_d_q <= apply_wstrb(stride_d_q, wdata, wstrb);
      end
      if (write_fire && (reg_offset == ADDR_FLAGS)) begin
        flags_q <= apply_wstrb(flags_q, wdata, wstrb);
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

      if (start_scratch) begin
        busy_q        <= 1'b1;
        done_q        <= 1'b1;
        irq_pending_q <= 1'b1;
        error_q       <= 1'b0;
        start_count_q <= start_count_q + 32'd1;
        result_q[0]   <= dot4(0);
        result_q[1]   <= dot4(1);
        result_q[2]   <= dot4(2);
        result_q[3]   <= dot4(3);
      end

      if (start_sram && (state_q == STATE_IDLE)) begin
        busy_q        <= 1'b1;
        done_q        <= 1'b0;
        irq_pending_q <= 1'b0;
        error_q       <= 1'b0;
        start_count_q <= start_count_q + 32'd1;
        mem_index_q   <= 2'd0;
        state_q       <= STATE_LOAD_A;
      end

      case (state_q)
        STATE_LOAD_A: begin
          if (mem_ready) begin
            if (mem_error) begin
              busy_q        <= 1'b0;
              done_q        <= 1'b1;
              irq_pending_q <= 1'b1;
              error_q       <= 1'b1;
              state_q       <= STATE_IDLE;
            end else begin
              matrix_q[{mem_index_q, 2'b00}] <= mem_rdata[7:0];
              matrix_q[{mem_index_q, 2'b01}] <= mem_rdata[15:8];
              matrix_q[{mem_index_q, 2'b10}] <= mem_rdata[23:16];
              matrix_q[{mem_index_q, 2'b11}] <= mem_rdata[31:24];
              if (mem_index_q == 2'd3) begin
                mem_index_q <= 2'd0;
                state_q     <= STATE_LOAD_B;
              end else begin
                mem_index_q <= mem_index_q + 2'd1;
              end
            end
          end
        end

        STATE_LOAD_B: begin
          if (mem_ready) begin
            if (mem_error) begin
              busy_q        <= 1'b0;
              done_q        <= 1'b1;
              irq_pending_q <= 1'b1;
              error_q       <= 1'b1;
              state_q       <= STATE_IDLE;
            end else begin
              vector_q[0] <= mem_rdata[7:0];
              vector_q[1] <= mem_rdata[15:8];
              vector_q[2] <= mem_rdata[23:16];
              vector_q[3] <= mem_rdata[31:24];
              state_q     <= STATE_COMPUTE;
            end
          end
        end

        STATE_COMPUTE: begin
          result_q[0] <= dot4(0);
          result_q[1] <= dot4(1);
          result_q[2] <= dot4(2);
          result_q[3] <= dot4(3);
          mem_index_q <= 2'd0;
          state_q     <= STATE_STORE;
        end

        STATE_STORE: begin
          if (mem_ready) begin
            if (mem_error) begin
              busy_q        <= 1'b0;
              done_q        <= 1'b1;
              irq_pending_q <= 1'b1;
              error_q       <= 1'b1;
              state_q       <= STATE_IDLE;
            end else if (mem_index_q == 2'd3) begin
              busy_q        <= 1'b0;
              done_q        <= 1'b1;
              irq_pending_q <= 1'b1;
              error_q       <= 1'b0;
              state_q       <= STATE_IDLE;
            end else begin
              mem_index_q <= mem_index_q + 2'd1;
            end
          end
        end

        default: begin
        end
      endcase
    end
  end

endmodule
