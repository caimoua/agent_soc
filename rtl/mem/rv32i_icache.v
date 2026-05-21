module rv32i_icache #(
  parameter INDEX_BITS = 3
) (
  input  wire        clk,
  input  wire        rst_n,

  input  wire        cpu_valid,
  input  wire [31:0] cpu_addr,
  output wire        cpu_ready,
  output wire [31:0] cpu_rdata,
  output wire        cpu_error,

  output wire        mem_valid,
  output wire [31:0] mem_addr,
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

  localparam STATE_IDLE   = 2'd0;
  localparam STATE_LOOKUP = 2'd1;
  localparam STATE_REFILL = 2'd2;

  reg [1:0]            state_q;
  reg [31:0]           lookup_addr_q;
  reg [INDEX_BITS-1:0] lookup_index_q;
  reg [TAG_BITS-1:0]   lookup_tag_q;
  reg [1:0]            lookup_word_q;

  reg [31:0]           refill_base_q;
  reg [INDEX_BITS-1:0] refill_index_q;
  reg [TAG_BITS-1:0]   refill_tag_q;
  reg                  refill_way_q;
  reg [1:0]            refill_word_q;
  reg [127:0]          refill_line_q;

  reg                  way0_valid [0:LINE_NUM-1];
  reg                  way1_valid [0:LINE_NUM-1];
  reg                  replace_way_q [0:LINE_NUM-1];
  reg [31:0]           hit_count_q;
  reg [31:0]           miss_count_q;

  wire [INDEX_BITS-1:0] cpu_index;
  wire [TAG_BITS-1:0]   cpu_tag;
  wire [1:0]            cpu_word_offset;

  wire [TAG_BITS-1:0]   way0_tag_rdata;
  wire [TAG_BITS-1:0]   way1_tag_rdata;
  wire [127:0]          way0_data_rdata;
  wire [127:0]          way1_data_rdata;

  wire                  way0_hit;
  wire                  way1_hit;
  wire                  cache_hit;
  wire                  victim_way;
  wire [31:0]           way0_word_rdata;
  wire [31:0]           way1_word_rdata;
  wire                  tag_data_ren;
  wire                  mem_response_error;

  wire                  way0_tag_we;
  wire                  way1_tag_we;
  wire                  way0_data_we;
  wire                  way1_data_we;

  integer i;

  assign cpu_index       = cpu_addr[INDEX_BITS+3:4];
  assign cpu_tag         = cpu_addr[31:INDEX_BITS+4];
  assign cpu_word_offset = cpu_addr[3:2];

  assign tag_data_ren = (state_q == STATE_IDLE) && cpu_valid;

  assign way0_hit = (state_q == STATE_LOOKUP) &&
                    way0_valid[lookup_index_q] &&
                    (way0_tag_rdata == lookup_tag_q);
  assign way1_hit = (state_q == STATE_LOOKUP) &&
                    way1_valid[lookup_index_q] &&
                    (way1_tag_rdata == lookup_tag_q);
  assign cache_hit = way0_hit || way1_hit;

  assign way0_word_rdata = (lookup_word_q == 2'd0) ? way0_data_rdata[31:0] :
                           (lookup_word_q == 2'd1) ? way0_data_rdata[63:32] :
                           (lookup_word_q == 2'd2) ? way0_data_rdata[95:64] :
                                                      way0_data_rdata[127:96];
  assign way1_word_rdata = (lookup_word_q == 2'd0) ? way1_data_rdata[31:0] :
                           (lookup_word_q == 2'd1) ? way1_data_rdata[63:32] :
                           (lookup_word_q == 2'd2) ? way1_data_rdata[95:64] :
                                                      way1_data_rdata[127:96];

  assign victim_way = !way0_valid[lookup_index_q] ? 1'b0 :
                      !way1_valid[lookup_index_q] ? 1'b1 :
                                                     replace_way_q[lookup_index_q];

  assign mem_response_error = (state_q == STATE_REFILL) && mem_ready && mem_error;

  assign cpu_ready = !cpu_valid ||
                     mem_response_error ||
                     ((state_q == STATE_LOOKUP) && cache_hit);
  assign cpu_rdata = way0_hit ? way0_word_rdata :
                     way1_hit ? way1_word_rdata :
                                32'd0;
  assign cpu_error = mem_response_error;

  assign mem_valid = (state_q == STATE_REFILL);
  assign mem_addr  = refill_base_q + {28'd0, refill_word_q, 2'b00};

  assign dbg_hit        = (state_q == STATE_LOOKUP) && cache_hit;
  assign dbg_miss       = (state_q == STATE_LOOKUP) && !cache_hit;
  assign dbg_hit_count  = hit_count_q;
  assign dbg_miss_count = miss_count_q;

  assign way0_tag_we  = (state_q == STATE_REFILL) && mem_ready && !mem_error && (refill_word_q == 2'd3) && !refill_way_q;
  assign way1_tag_we  = (state_q == STATE_REFILL) && mem_ready && !mem_error && (refill_word_q == 2'd3) &&  refill_way_q;
  assign way0_data_we = way0_tag_we;
  assign way1_data_we = way1_tag_we;

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
    .DATA_WIDTH(128)
  ) u_way0_data_sram (
    .clk    (clk),
    .r_en   (tag_data_ren),
    .r_addr (cpu_index),
    .r_data (way0_data_rdata),
    .w_en   (way0_data_we),
    .w_addr (refill_index_q),
    .w_data ({mem_rdata, refill_line_q[95:0]}),
    .w_strb ({LINE_STRB_BITS{1'b1}})
  );

  rv32i_sram_1r1w #(
    .ADDR_WIDTH(INDEX_BITS),
    .DATA_WIDTH(128)
  ) u_way1_data_sram (
    .clk    (clk),
    .r_en   (tag_data_ren),
    .r_addr (cpu_index),
    .r_data (way1_data_rdata),
    .w_en   (way1_data_we),
    .w_addr (refill_index_q),
    .w_data ({mem_rdata, refill_line_q[95:0]}),
    .w_strb ({LINE_STRB_BITS{1'b1}})
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q        <= STATE_IDLE;
      lookup_addr_q  <= 32'd0;
      lookup_index_q <= {INDEX_BITS{1'b0}};
      lookup_tag_q   <= {TAG_BITS{1'b0}};
      lookup_word_q  <= 2'd0;

      refill_base_q  <= 32'd0;
      refill_index_q <= {INDEX_BITS{1'b0}};
      refill_tag_q   <= {TAG_BITS{1'b0}};
      refill_way_q   <= 1'b0;
      refill_word_q  <= 2'd0;
      refill_line_q  <= 128'd0;

      hit_count_q    <= 32'd0;
      miss_count_q   <= 32'd0;

      for (i = 0; i < LINE_NUM; i = i + 1) begin
        way0_valid[i]    <= 1'b0;
        way1_valid[i]    <= 1'b0;
        replace_way_q[i] <= 1'b0;
      end
    end else begin
      case (state_q)
        STATE_IDLE: begin
          if (cpu_valid) begin
            lookup_addr_q  <= cpu_addr;
            lookup_index_q <= cpu_index;
            lookup_tag_q   <= cpu_tag;
            lookup_word_q  <= cpu_word_offset;
            state_q        <= STATE_LOOKUP;
          end
        end

        STATE_LOOKUP: begin
          if (cache_hit) begin
            hit_count_q <= hit_count_q + 32'd1;
            if (way0_hit) begin
              replace_way_q[lookup_index_q] <= 1'b1;
            end else begin
              replace_way_q[lookup_index_q] <= 1'b0;
            end
            state_q <= STATE_IDLE;
          end else begin
            refill_base_q  <= {lookup_addr_q[31:4], 4'b0000};
            refill_index_q <= lookup_index_q;
            refill_tag_q   <= lookup_tag_q;
            refill_way_q   <= victim_way;
            refill_word_q  <= 2'd0;
            refill_line_q  <= 128'd0;
            miss_count_q   <= miss_count_q + 32'd1;
            state_q        <= STATE_REFILL;
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

        default: begin
          state_q <= STATE_IDLE;
        end
      endcase
    end
  end

endmodule
