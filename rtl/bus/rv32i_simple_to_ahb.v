module rv32i_simple_to_ahb (
  input  wire        clk,
  input  wire        rst_n,

  input  wire        valid,
  input  wire        write,
  input  wire [31:0] addr,
  input  wire [31:0] wdata,
  input  wire [3:0]  wstrb,
  output wire        ready,
  output wire [31:0] rdata,
  output wire        error,

  output wire [31:0] haddr,
  output wire [2:0]  hburst,
  output wire [3:0]  hprot,
  output wire [2:0]  hsize,
  output wire [1:0]  htrans,
  output wire [31:0] hwdata,
  output wire        hwrite,
  input  wire [31:0] hrdata,
  input  wire        hready,
  input  wire [1:0]  hresp
);

  localparam [1:0] HTRANS_IDLE   = 2'b00;
  localparam [1:0] HTRANS_NONSEQ = 2'b10;
  localparam [2:0] HSIZE_BYTE    = 3'b000;
  localparam [2:0] HSIZE_WORD    = 3'b010;
  localparam [2:0] HBURST_SINGLE = 3'b000;
  localparam [1:0] HRESP_OKAY    = 2'b00;

  localparam [1:0] STATE_IDLE = 2'd0;
  localparam [1:0] STATE_ADDR = 2'd1;
  localparam [1:0] STATE_DATA = 2'd2;
  localparam [1:0] STATE_DONE = 2'd3;

  reg [1:0]  state_q;
  reg [31:0] req_addr_q;
  reg        req_write_q;
  reg [31:0] req_wdata_q;
  reg [3:0]  pending_wstrb_q;
  reg [1:0]  byte_lane_q;
  reg        error_q;

  wire        transfer_done;
  wire        write_word;
  wire        write_byte;
  wire [1:0]  first_byte_lane;
  wire [3:0]  completed_byte_mask;
  wire [3:0]  remaining_after_done;
  wire        has_more_writes;
  wire [1:0]  next_byte_lane;

  function [1:0] first_set_lane;
    input [3:0] mask;
    begin
      if (mask[0]) begin
        first_set_lane = 2'd0;
      end else if (mask[1]) begin
        first_set_lane = 2'd1;
      end else if (mask[2]) begin
        first_set_lane = 2'd2;
      end else begin
        first_set_lane = 2'd3;
      end
    end
  endfunction

  assign transfer_done = (state_q == STATE_DATA) && hready;
  assign write_word    = req_write_q && (pending_wstrb_q == 4'b1111);
  assign write_byte    = req_write_q && !write_word;
  assign first_byte_lane = first_set_lane(wstrb);
  assign completed_byte_mask = write_byte ? (4'b0001 << byte_lane_q) : 4'b0000;
  assign remaining_after_done = pending_wstrb_q & ~completed_byte_mask;
  assign has_more_writes = req_write_q &&
                           write_byte &&
                           (remaining_after_done != 4'b0000) &&
                           (hresp == HRESP_OKAY);
  assign next_byte_lane = first_set_lane(remaining_after_done);

  assign ready = (state_q == STATE_DONE) ||
                 (transfer_done && !has_more_writes);
  assign rdata = hrdata;
  assign error = (state_q != STATE_DONE) &&
                 ready &&
                 (error_q || (hresp != HRESP_OKAY));

  assign haddr  = write_byte ? {req_addr_q[31:2], byte_lane_q} :
                               {req_addr_q[31:2], 2'b00};
  assign hburst = HBURST_SINGLE;
  assign hprot  = 4'b0011;
  assign hsize  = write_byte ? HSIZE_BYTE : HSIZE_WORD;
  assign htrans = (state_q == STATE_ADDR) ? HTRANS_NONSEQ : HTRANS_IDLE;
  assign hwdata = req_wdata_q;
  assign hwrite = req_write_q;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q         <= STATE_IDLE;
      req_addr_q      <= 32'd0;
      req_write_q     <= 1'b0;
      req_wdata_q     <= 32'd0;
      pending_wstrb_q <= 4'b0000;
      byte_lane_q     <= 2'd0;
      error_q         <= 1'b0;
    end else begin
      case (state_q)
        STATE_IDLE: begin
          error_q <= 1'b0;
          if (valid) begin
            state_q         <= (write && (wstrb == 4'b0000)) ? STATE_DONE : STATE_ADDR;
            req_addr_q      <= addr;
            req_write_q     <= write;
            req_wdata_q     <= wdata;
            pending_wstrb_q <= write ? wstrb : 4'b0000;
            byte_lane_q     <= first_byte_lane;
          end
        end

        STATE_ADDR: begin
          if (hready) begin
            state_q <= STATE_DATA;
          end
        end

        STATE_DATA: begin
          if (hready) begin
            error_q <= error_q || (hresp != HRESP_OKAY);
            if (has_more_writes) begin
              state_q         <= STATE_ADDR;
              pending_wstrb_q <= remaining_after_done;
              byte_lane_q     <= next_byte_lane;
            end else begin
              state_q         <= STATE_IDLE;
              pending_wstrb_q <= 4'b0000;
            end
          end
        end

        STATE_DONE: begin
          state_q <= STATE_IDLE;
        end

        default: begin
          state_q <= STATE_IDLE;
        end
      endcase
    end
  end

endmodule
