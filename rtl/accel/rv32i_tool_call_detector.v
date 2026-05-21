module rv32i_tool_call_detector (
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
  output wire [31:0] dbg_match_count,
  output wire [31:0] dbg_token_count,
  output wire [31:0] dbg_last_token
);

  localparam [11:0] ADDR_CTRL        = 12'h000;
  localparam [11:0] ADDR_STATUS      = 12'h004;
  localparam [11:0] ADDR_PATTERN_LEN = 12'h008;
  localparam [11:0] ADDR_TOKEN_IN    = 12'h00c;
  localparam [11:0] ADDR_MATCH_COUNT = 12'h010;
  localparam [11:0] ADDR_TOKEN_COUNT = 12'h014;
  localparam [11:0] ADDR_IRQ_STATUS  = 12'h018;
  localparam [11:0] ADDR_IRQ_CLEAR   = 12'h01c;
  localparam [11:0] ADDR_PATTERN0    = 12'h020;
  localparam [11:0] ADDR_PATTERN1    = 12'h024;
  localparam [11:0] ADDR_PATTERN2    = 12'h028;
  localparam [11:0] ADDR_PATTERN3    = 12'h02c;

  reg        enable_q;
  reg        irq_en_q;
  reg        match_q;
  reg        overflow_q;
  reg        irq_pending_q;
  reg [3:0]  pattern_len_q;
  reg [3:0]  token_count_q;
  reg [15:0] pattern_q [0:7];
  reg [15:0] history_q [0:7];
  reg [15:0] last_token_q;
  reg [31:0] match_count_q;

  wire [11:0] reg_offset;
  wire        write_fire;
  wire        clear_write;
  wire        token_write;
  wire        irq_clear_write;
  wire        pattern_sel;
  wire [1:0]  pattern_word;
  wire [31:0] pattern_rdata;
  wire [31:0] status_rdata;
  wire [3:0]  token_count_next;
  wire        token_match;

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

  function [0:0] suffix_match;
    input [15:0] incoming_token;
    integer match_i;
    integer match_idx;
    reg [15:0] match_candidate;
    begin
      suffix_match = enable_q && (pattern_len_q != 4'd0) &&
                     (token_count_next >= pattern_len_q);
      for (match_i = 0; match_i < 8; match_i = match_i + 1) begin
        if (match_i < pattern_len_q) begin
          match_idx = 8 - pattern_len_q + match_i;
          if (match_idx == 7) begin
            match_candidate = incoming_token;
          end else begin
            match_candidate = history_q[match_idx + 1];
          end
          if (match_candidate != pattern_q[match_i]) begin
            suffix_match = 1'b0;
          end
        end
      end
    end
  endfunction

  assign reg_offset      = addr[11:0];
  assign write_fire      = valid && ready && write;
  assign clear_write     = write_fire && (reg_offset == ADDR_CTRL) && wstrb[0] && wdata[1];
  assign token_write     = write_fire && (reg_offset == ADDR_TOKEN_IN) && (wstrb[0] || wstrb[1]);
  assign irq_clear_write = write_fire && (reg_offset == ADDR_IRQ_CLEAR) && wstrb[0] && wdata[0];
  assign pattern_sel     = (reg_offset[11:4] == ADDR_PATTERN0[11:4]);
  assign pattern_word    = reg_offset[3:2];
  assign token_count_next = (token_count_q == 4'd8) ? 4'd8 : (token_count_q + 4'd1);
  assign token_match     = token_write && suffix_match(wdata[15:0]);

  assign pattern_rdata = {pattern_q[{pattern_word, 1'b1}],
                          pattern_q[{pattern_word, 1'b0}]};
  assign status_rdata  = {28'd0, irq_pending_q, overflow_q, match_q, enable_q};

  assign ready = valid;
  assign rdata = (reg_offset == ADDR_CTRL)        ? {29'd0, irq_en_q, 1'b0, enable_q} :
                 (reg_offset == ADDR_STATUS)      ? status_rdata :
                 (reg_offset == ADDR_PATTERN_LEN) ? {28'd0, pattern_len_q} :
                 (reg_offset == ADDR_TOKEN_IN)    ? {16'd0, last_token_q} :
                 (reg_offset == ADDR_MATCH_COUNT) ? match_count_q :
                 (reg_offset == ADDR_TOKEN_COUNT) ? {28'd0, token_count_q} :
                 (reg_offset == ADDR_IRQ_STATUS)  ? {31'd0, irq_pending_q} :
                 pattern_sel                      ? pattern_rdata :
                                                    32'd0;

  assign irq             = irq_pending_q && irq_en_q;
  assign dbg_status      = status_rdata;
  assign dbg_match_count = match_count_q;
  assign dbg_token_count = {28'd0, token_count_q};
  assign dbg_last_token  = {16'd0, last_token_q};

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      enable_q       <= 1'b0;
      irq_en_q       <= 1'b0;
      match_q        <= 1'b0;
      overflow_q     <= 1'b0;
      irq_pending_q  <= 1'b0;
      pattern_len_q  <= 4'd0;
      token_count_q  <= 4'd0;
      last_token_q   <= 16'd0;
      match_count_q  <= 32'd0;
      for (i = 0; i < 8; i = i + 1) begin
        pattern_q[i] <= 16'd0;
        history_q[i] <= 16'd0;
      end
    end else begin
      if (clear_write) begin
        match_q       <= 1'b0;
        overflow_q    <= 1'b0;
        irq_pending_q <= 1'b0;
        token_count_q <= 4'd0;
        last_token_q  <= 16'd0;
        for (i = 0; i < 8; i = i + 1) begin
          history_q[i] <= 16'd0;
        end
      end

      if (irq_clear_write) begin
        irq_pending_q <= 1'b0;
      end

      if (write_fire && (reg_offset == ADDR_CTRL)) begin
        if (wstrb[0]) begin
          enable_q <= wdata[0];
          irq_en_q <= wdata[2];
        end
      end

      if (write_fire && (reg_offset == ADDR_PATTERN_LEN)) begin
        if (wstrb[0]) begin
          if (wdata[3:0] == 4'd0) begin
            pattern_len_q <= 4'd1;
            overflow_q    <= 1'b1;
          end else if (wdata[3:0] > 4'd8) begin
            pattern_len_q <= 4'd8;
            overflow_q    <= 1'b1;
          end else begin
            pattern_len_q <= wdata[3:0];
          end
        end
      end

      if (write_fire && pattern_sel) begin
        if (wstrb[0]) pattern_q[{pattern_word, 1'b0}][7:0]   <= wdata[7:0];
        if (wstrb[1]) pattern_q[{pattern_word, 1'b0}][15:8]  <= wdata[15:8];
        if (wstrb[2]) pattern_q[{pattern_word, 1'b1}][7:0]   <= wdata[23:16];
        if (wstrb[3]) pattern_q[{pattern_word, 1'b1}][15:8]  <= wdata[31:24];
      end

      if (token_write) begin
        for (i = 0; i < 7; i = i + 1) begin
          history_q[i] <= history_q[i + 1];
        end
        history_q[7]  <= wdata[15:0];
        last_token_q  <= wdata[15:0];
        token_count_q <= token_count_next;

        if (token_match) begin
          match_q       <= 1'b1;
          irq_pending_q <= 1'b1;
          match_count_q <= match_count_q + 32'd1;
        end
      end
    end
  end

endmodule
