module rv32i_ahb_to_apb (
  input  wire        clk,
  input  wire        rst_n,

  input  wire        hsel,
  input  wire [31:0] haddr,
  input  wire [2:0]  hburst,
  input  wire [3:0]  hprot,
  input  wire [2:0]  hsize,
  input  wire [1:0]  htrans,
  input  wire [31:0] hwdata,
  input  wire        hwrite,
  input  wire        hready,
  output wire [31:0] hrdata,
  output wire        hreadyout,
  output wire [1:0]  hresp,

  output wire        psel,
  output wire        penable,
  output wire [31:0] paddr,
  output wire        pwrite,
  output wire [31:0] pwdata,
  output wire [3:0]  pstrb,
  output wire [2:0]  pprot,
  input  wire [31:0] prdata,
  input  wire        pready,
  input  wire        pslverr
);

  localparam [1:0] HRESP_OKAY  = 2'b00;
  localparam [1:0] HRESP_ERROR = 2'b01;
  localparam [2:0] HSIZE_BYTE  = 3'b000;
  localparam [2:0] HSIZE_HALF  = 3'b001;
  localparam [2:0] HSIZE_WORD  = 3'b010;

  localparam [1:0] STATE_IDLE   = 2'd0;
  localparam [1:0] STATE_SETUP  = 2'd1;
  localparam [1:0] STATE_ACCESS = 2'd2;

  reg [1:0]  state_q;
  reg [31:0] addr_q;
  reg        write_q;
  reg [2:0]  hsize_q;
  reg [3:0]  hprot_q;
  reg [31:0] wdata_q;

  wire        address_valid;
  wire        access_done;

  function [3:0] size_to_pstrb;
    input [2:0] size;
    input [1:0] byte_offset;
    begin
      case (size)
        HSIZE_BYTE: begin
          size_to_pstrb = 4'b0001 << byte_offset;
        end

        HSIZE_HALF: begin
          size_to_pstrb = byte_offset[1] ? 4'b1100 : 4'b0011;
        end

        HSIZE_WORD: begin
          size_to_pstrb = 4'b1111;
        end

        default: begin
          size_to_pstrb = 4'b1111;
        end
      endcase
    end
  endfunction

  assign address_valid = hsel && hready && htrans[1];
  assign access_done   = (state_q == STATE_ACCESS) && pready;

  assign psel    = (state_q == STATE_SETUP) || (state_q == STATE_ACCESS);
  assign penable = (state_q == STATE_ACCESS);
  assign paddr   = addr_q;
  assign pwrite  = write_q;
  assign pwdata  = (state_q == STATE_SETUP) ? hwdata : wdata_q;
  assign pstrb   = write_q ? size_to_pstrb(hsize_q, addr_q[1:0]) : 4'b0000;
  assign pprot   = hprot_q[2:0];

  assign hrdata    = prdata;
  assign hreadyout = (state_q == STATE_IDLE) ? 1'b1 :
                     (state_q == STATE_ACCESS) ? pready :
                                                  1'b0;
  assign hresp     = (access_done && pslverr) ? HRESP_ERROR : HRESP_OKAY;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q <= STATE_IDLE;
      addr_q  <= 32'd0;
      write_q <= 1'b0;
      hsize_q <= HSIZE_WORD;
      hprot_q <= 4'd0;
      wdata_q <= 32'd0;
    end else begin
      case (state_q)
        STATE_IDLE: begin
          if (address_valid) begin
            state_q <= STATE_SETUP;
            addr_q  <= haddr;
            write_q <= hwrite;
            hsize_q <= hsize;
            hprot_q <= hprot;
          end
        end

        STATE_SETUP: begin
          state_q <= STATE_ACCESS;
          wdata_q <= hwdata;
        end

        STATE_ACCESS: begin
          if (pready) begin
            if (address_valid) begin
              state_q <= STATE_SETUP;
              addr_q  <= haddr;
              write_q <= hwrite;
              hsize_q <= hsize;
              hprot_q <= hprot;
            end else begin
              state_q <= STATE_IDLE;
            end
          end
        end

        default: begin
          state_q <= STATE_IDLE;
        end
      endcase
    end
  end

  wire [2:0] unused_hburst = hburst;

endmodule
