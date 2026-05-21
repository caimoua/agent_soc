module rv32i_ahb_to_simple (
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

  output wire        valid,
  output wire        write,
  output wire [31:0] addr,
  output wire [31:0] wdata,
  output wire [3:0]  wstrb,
  input  wire        ready,
  input  wire [31:0] rdata,
  input  wire        error
);

  localparam [1:0] HRESP_OKAY  = 2'b00;
  localparam [1:0] HRESP_ERROR = 2'b01;
  localparam [2:0] HSIZE_BYTE  = 3'b000;
  localparam [2:0] HSIZE_HALF  = 3'b001;
  localparam [2:0] HSIZE_WORD  = 3'b010;

  reg        active_q;
  reg [31:0] addr_q;
  reg        write_q;
  reg [2:0]  hsize_q;

  wire       address_valid;

  function [3:0] size_to_wstrb;
    input [2:0] size;
    input [1:0] byte_offset;
    begin
      case (size)
        HSIZE_BYTE: begin
          size_to_wstrb = 4'b0001 << byte_offset;
        end

        HSIZE_HALF: begin
          size_to_wstrb = byte_offset[1] ? 4'b1100 : 4'b0011;
        end

        HSIZE_WORD: begin
          size_to_wstrb = 4'b1111;
        end

        default: begin
          size_to_wstrb = 4'b1111;
        end
      endcase
    end
  endfunction

  assign address_valid = hsel && hready && htrans[1];

  assign valid = active_q;
  assign write = active_q && write_q;
  assign addr  = addr_q;
  assign wdata = hwdata;
  assign wstrb = write ? size_to_wstrb(hsize_q, addr_q[1:0]) : 4'b0000;

  assign hrdata = rdata;
  assign hreadyout = active_q ? ready : 1'b1;
  assign hresp = (active_q && ready && error) ? HRESP_ERROR : HRESP_OKAY;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      active_q <= 1'b0;
      addr_q   <= 32'd0;
      write_q  <= 1'b0;
      hsize_q  <= HSIZE_WORD;
    end else begin
      if (active_q && ready) begin
        active_q <= 1'b0;
      end

      if (address_valid) begin
        active_q <= 1'b1;
        addr_q   <= haddr;
        write_q  <= hwrite;
        hsize_q  <= hsize;
      end
    end
  end

  wire [2:0] unused_hburst = hburst;
  wire [3:0] unused_hprot  = hprot;

endmodule
