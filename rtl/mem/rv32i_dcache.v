module rv32i_dcache #(
  parameter INDEX_BITS = 3,
  parameter [31:0] UNCACHED_BASE = 32'h4000_0000,
  parameter [31:0] UNCACHED_MASK = 32'hF000_0000
) (
  input  wire        clk,
  input  wire        rst_n,

  input  wire        cpu_valid,
  input  wire        cpu_write,
  input  wire [31:0] cpu_addr,
  input  wire [31:0] cpu_wdata,
  input  wire [3:0]  cpu_wstrb,
  output wire        cpu_ready,
  output wire [31:0] cpu_rdata,
  output wire        cpu_error,

  output wire        mem_valid,
  output wire        mem_write,
  output wire [31:0] mem_addr,
  output wire [31:0] mem_wdata,
  output wire [3:0]  mem_wstrb,
  input  wire        mem_ready,
  input  wire [31:0] mem_rdata,
  input  wire        mem_error,

  output wire        dbg_hit,
  output wire        dbg_miss,
  output wire [31:0] dbg_hit_count,
  output wire [31:0] dbg_miss_count
);

  localparam LINE_NUM = (1 << INDEX_BITS);
  localparam TAG_BITS = 32 - INDEX_BITS - 4;
  localparam TAG_STRB_BITS = (TAG_BITS + 7) / 8;
  localparam LINE_STRB_BITS = 16;

  localparam STATE_IDLE         = 3'd0;
  localparam STATE_LOOKUP       = 3'd1;
  localparam STATE_REFILL       = 3'd2;
  localparam STATE_STORE_HIT    = 3'd3;
  localparam STATE_STORE_DIRECT = 3'd4;
  localparam STATE_LOAD_DIRECT  = 3'd5;

  reg [2:0]            state_q;
  reg [31:0]           req_addr_q;
  reg                  req_write_q;
  reg [31:0]           req_wdata_q;
  reg [3:0]            req_wstrb_q;
  reg [INDEX_BITS-1:0] req_index_q;
  reg [TAG_BITS-1:0]   req_tag_q;
  reg [1:0]            req_word_q;

  reg [31:0]           refill_base_q;
  reg [INDEX_BITS-1:0] refill_index_q;
  reg [TAG_BITS-1:0]   refill_tag_q;
  reg                  refill_way_q;
  reg [1:0]            refill_word_q;
  reg [127:0]          refill_line_q;

  reg                  store_hit_way_q;
  reg                  way0_valid [0:LINE_NUM-1];
  reg                  way1_valid [0:LINE_NUM-1];
  reg                  replace_way_q [0:LINE_NUM-1];
  reg [31:0]           hit_count_q;
  reg [31:0]           miss_count_q;

  wire [INDEX_BITS-1:0] cpu_index;
  wire [TAG_BITS-1:0]   cpu_tag;
  wire [1:0]            cpu_word_offset;
  wire                  cpu_uncached;

  wire [TAG_BITS-1:0]   way0_tag_rdata;
  wire [TAG_BITS-1:0]   way1_tag_rdata;
  wire [127:0]          way0_data_rdata;
  wire [127:0]          way1_data_rdata;

  wire                  way0_hit;
  wire                  way1_hit;
  wire                  cache_hit;
  wire                  victim_way;
  wire                  tag_data_ren;
  wire                  mem_response_error;

  wire [127:0]          hit_line;
  wire [31:0]           hit_word;
  wire [127:0]          store_line_wdata;
  wire [15:0]           store_line_wstrb;

  wire                  way0_tag_we;
  wire                  way1_tag_we;
  wire                  way0_data_we;
  wire                  way1_data_we;
  wire [INDEX_BITS-1:0] data_waddr;
  wire [127:0]          data_wdata;
  wire [15:0]           data_wstrb;

  integer i;

  function [31:0] select_word;
    input [127:0] line;
    input [1:0]   word_offset;
    begin
      case (word_offset)
        2'd0: select_word = line[31:0];
        2'd1: select_word = line[63:32];
        2'd2: select_word = line[95:64];
        default: select_word = line[127:96];
      endcase
    end
  endfunction

  function [127:0] expand_line_wdata;
    input [1:0]  word_offset;
    input [31:0] word_data;
    begin
      case (word_offset)
        2'd0: expand_line_wdata = {96'd0, word_data};
        2'd1: expand_line_wdata = {64'd0, word_data, 32'd0};
        2'd2: expand_line_wdata = {32'd0, word_data, 64'd0};
        default: expand_line_wdata = {word_data, 96'd0};
      endcase
    end
  endfunction

  function [15:0] expand_line_wstrb;
    input [1:0]   word_offset;
    input [3:0]   word_wstrb;
    begin
      case (word_offset)
        2'd0: expand_line_wstrb = {12'd0, word_wstrb};
        2'd1: expand_line_wstrb = {8'd0, word_wstrb, 4'd0};
        2'd2: expand_line_wstrb = {4'd0, word_wstrb, 8'd0};
        default: expand_line_wstrb = {word_wstrb, 12'd0};
      endcase
    end
  endfunction

  assign cpu_index       = cpu_addr[INDEX_BITS+3:4];
  assign cpu_tag         = cpu_addr[31:INDEX_BITS+4];
  assign cpu_word_offset = cpu_addr[3:2];
  assign cpu_uncached    = ((cpu_addr & UNCACHED_MASK) == UNCACHED_BASE);

  assign tag_data_ren = (state_q == STATE_IDLE) && cpu_valid && !cpu_uncached;

  assign way0_hit = (state_q == STATE_LOOKUP) &&
                    way0_valid[req_index_q] &&
                    (way0_tag_rdata == req_tag_q);
  assign way1_hit = (state_q == STATE_LOOKUP) &&
                    way1_valid[req_index_q] &&
                    (way1_tag_rdata == req_tag_q);
  assign cache_hit = way0_hit || way1_hit;

  assign victim_way = !way0_valid[req_index_q] ? 1'b0 :
                      !way1_valid[req_index_q] ? 1'b1 :
                                                   replace_way_q[req_index_q];

  assign hit_line       = way0_hit ? way0_data_rdata : way1_data_rdata;
  assign hit_word       = select_word(hit_line, req_word_q);
  assign store_line_wdata = expand_line_wdata(req_word_q, req_wdata_q);
  assign store_line_wstrb = expand_line_wstrb(req_word_q, req_wstrb_q);

  assign mem_response_error = mem_ready && mem_error &&
                              ((state_q == STATE_REFILL) ||
                               (state_q == STATE_STORE_HIT) ||
                               (state_q == STATE_STORE_DIRECT) ||
                               (state_q == STATE_LOAD_DIRECT));

  assign cpu_ready = !cpu_valid ||
                     ((state_q == STATE_LOOKUP) && cache_hit && !req_write_q) ||
                     ((state_q == STATE_REFILL) && mem_response_error) ||
                     ((state_q == STATE_STORE_HIT) && mem_ready) ||
                     ((state_q == STATE_STORE_DIRECT) && mem_ready) ||
                     ((state_q == STATE_LOAD_DIRECT) && mem_ready);
  assign cpu_rdata = ((state_q == STATE_LOOKUP) && cache_hit && !req_write_q) ? hit_word :
                     ((state_q == STATE_LOAD_DIRECT) && mem_ready)             ? mem_rdata :
                                                                                 32'd0;
  assign cpu_error = mem_response_error;

  assign mem_valid = (state_q == STATE_REFILL) ||
                     (state_q == STATE_STORE_HIT) ||
                     (state_q == STATE_STORE_DIRECT) ||
                     (state_q == STATE_LOAD_DIRECT);
  assign mem_write = (state_q == STATE_STORE_HIT) ||
                     (state_q == STATE_STORE_DIRECT);
  assign mem_addr  = (state_q == STATE_REFILL) ? (refill_base_q + {28'd0, refill_word_q, 2'b00}) :
                                                 req_addr_q;
  assign mem_wdata = req_wdata_q;
  assign mem_wstrb = mem_write ? req_wstrb_q : 4'b0000;

  assign dbg_hit        = (state_q == STATE_LOOKUP) && cache_hit;
  assign dbg_miss       = (state_q == STATE_LOOKUP) && !cache_hit;
  assign dbg_hit_count  = hit_count_q;
  assign dbg_miss_count = miss_count_q;

  assign way0_tag_we = (state_q == STATE_REFILL) && mem_ready && !mem_error && (refill_word_q == 2'd3) && !refill_way_q;
  assign way1_tag_we = (state_q == STATE_REFILL) && mem_ready && !mem_error && (refill_word_q == 2'd3) &&  refill_way_q;
  assign way0_data_we = ((state_q == STATE_REFILL) && mem_ready && !mem_error && (refill_word_q == 2'd3) && !refill_way_q) ||
                        ((state_q == STATE_STORE_HIT) && mem_ready && !mem_error && !store_hit_way_q);
  assign way1_data_we = ((state_q == STATE_REFILL) && mem_ready && !mem_error && (refill_word_q == 2'd3) &&  refill_way_q) ||
                        ((state_q == STATE_STORE_HIT) && mem_ready && !mem_error &&  store_hit_way_q);
  assign data_waddr = (state_q == STATE_STORE_HIT) ? req_index_q : refill_index_q;
  assign data_wdata = (state_q == STATE_STORE_HIT) ? store_line_wdata : {mem_rdata, refill_line_q[95:0]};
  assign data_wstrb = (state_q == STATE_STORE_HIT) ? store_line_wstrb : {LINE_STRB_BITS{1'b1}};

  rv32i_sram_1r1w #(
    .ADDR_WIDTH(INDEX_BITS),
    .DATA_WIDTH(TAG_BITS)
  ) u_way0_tag_sram (
    .clk    (clk),
    .r_en   (tag_data_ren),
    .r_addr (cpu_index),
    .r_data (way0_tag_rdata),
    .w_en   (way0_tag_we),
    .w_addr (refill_index_q),
    .w_data (refill_tag_q),
    .w_strb ({TAG_STRB_BITS{1'b1}})
  );

  rv32i_sram_1r1w #(
    .ADDR_WIDTH(INDEX_BITS),
    .DATA_WIDTH(TAG_BITS)
  ) u_way1_tag_sram (
    .clk    (clk),
    .r_en   (tag_data_ren),
    .r_addr (cpu_index),
    .r_data (way1_tag_rdata),
    .w_en   (way1_tag_we),
    .w_addr (refill_index_q),
    .w_data (refill_tag_q),
    .w_strb ({TAG_STRB_BITS{1'b1}})
  );

  rv32i_sram_1r1w #(
    .ADDR_WIDTH(INDEX_BITS),
    .DATA_WIDTH(128),
    .BYTE_WRITE(1)
  ) u_way0_data_sram (
    .clk    (clk),
    .r_en   (tag_data_ren),
    .r_addr (cpu_index),
    .r_data (way0_data_rdata),
    .w_en   (way0_data_we),
    .w_addr (data_waddr),
    .w_data (data_wdata),
    .w_strb (data_wstrb)
  );

  rv32i_sram_1r1w #(
    .ADDR_WIDTH(INDEX_BITS),
    .DATA_WIDTH(128),
    .BYTE_WRITE(1)
  ) u_way1_data_sram (
    .clk    (clk),
    .r_en   (tag_data_ren),
    .r_addr (cpu_index),
    .r_data (way1_data_rdata),
    .w_en   (way1_data_we),
    .w_addr (data_waddr),
    .w_data (data_wdata),
    .w_strb (data_wstrb)
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q         <= STATE_IDLE;
      req_addr_q      <= 32'd0;
      req_write_q     <= 1'b0;
      req_wdata_q     <= 32'd0;
      req_wstrb_q     <= 4'b0000;
      req_index_q     <= {INDEX_BITS{1'b0}};
      req_tag_q       <= {TAG_BITS{1'b0}};
      req_word_q      <= 2'd0;

      refill_base_q   <= 32'd0;
      refill_index_q  <= {INDEX_BITS{1'b0}};
      refill_tag_q    <= {TAG_BITS{1'b0}};
      refill_way_q    <= 1'b0;
      refill_word_q   <= 2'd0;
      refill_line_q   <= 128'd0;

      store_hit_way_q <= 1'b0;

      hit_count_q     <= 32'd0;
      miss_count_q    <= 32'd0;

      for (i = 0; i < LINE_NUM; i = i + 1) begin
        way0_valid[i]    <= 1'b0;
        way1_valid[i]    <= 1'b0;
        replace_way_q[i] <= 1'b0;
      end
    end else begin
      case (state_q)
        STATE_IDLE: begin
          if (cpu_valid) begin
            req_addr_q  <= cpu_addr;
            req_write_q <= cpu_write;
            req_wdata_q <= cpu_wdata;
            req_wstrb_q <= cpu_wstrb;
            req_index_q <= cpu_index;
            req_tag_q   <= cpu_tag;
            req_word_q  <= cpu_word_offset;
            if (cpu_uncached) begin
              state_q <= cpu_write ? STATE_STORE_DIRECT : STATE_LOAD_DIRECT;
            end else begin
              state_q <= STATE_LOOKUP;
            end
          end
        end

        STATE_LOOKUP: begin
          if (cache_hit) begin
            hit_count_q <= hit_count_q + 32'd1;
            if (way0_hit) begin
              replace_way_q[req_index_q] <= 1'b1;
            end else begin
              replace_way_q[req_index_q] <= 1'b0;
            end

            if (req_write_q) begin
              store_hit_way_q <= way1_hit;
              state_q         <= STATE_STORE_HIT;
            end else begin
              state_q <= STATE_IDLE;
            end
          end else begin
            miss_count_q <= miss_count_q + 32'd1;
            if (req_write_q) begin
              state_q <= STATE_STORE_DIRECT;
            end else begin
              refill_base_q  <= {req_addr_q[31:4], 4'b0000};
              refill_index_q <= req_index_q;
              refill_tag_q   <= req_tag_q;
              refill_way_q   <= victim_way;
              refill_word_q  <= 2'd0;
              refill_line_q  <= 128'd0;
              state_q        <= STATE_REFILL;
            end
          end
        end

        STATE_REFILL: begin
          if (mem_ready) begin
            if (mem_error) begin
              state_q <= STATE_IDLE;
            end else begin
              case (refill_word_q)
                2'd0: refill_line_q[31:0]    <= mem_rdata;
                2'd1: refill_line_q[63:32]   <= mem_rdata;
                2'd2: refill_line_q[95:64]   <= mem_rdata;
                default: refill_line_q[127:96] <= mem_rdata;
              endcase

              if (refill_word_q == 2'd3) begin
                if (!refill_way_q) begin
                  way0_valid[refill_index_q]    <= 1'b1;
                  replace_way_q[refill_index_q] <= 1'b1;
                end else begin
                  way1_valid[refill_index_q]    <= 1'b1;
                  replace_way_q[refill_index_q] <= 1'b0;
                end
                state_q <= STATE_IDLE;
              end else begin
                refill_word_q <= refill_word_q + 2'd1;
              end
            end
          end
        end

        STATE_STORE_HIT: begin
          if (mem_ready) begin
            state_q <= STATE_IDLE;
          end
        end

        STATE_STORE_DIRECT: begin
          if (mem_ready) begin
            state_q <= STATE_IDLE;
          end
        end

        STATE_LOAD_DIRECT: begin
          if (mem_ready) begin
            state_q <= STATE_IDLE;
          end
        end

        default: begin
          state_q <= STATE_IDLE;
        end
      endcase
    end
  end

endmodule
