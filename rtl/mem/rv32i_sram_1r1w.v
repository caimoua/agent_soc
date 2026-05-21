module rv32i_sram_1r1w #(
  parameter ADDR_WIDTH = 4,
  parameter DATA_WIDTH = 32,
  parameter BYTE_WRITE = 0,
  parameter STRB_WIDTH = (DATA_WIDTH + 7) / 8
) (
  input  wire                  clk,

  input  wire                  r_en,
  input  wire [ADDR_WIDTH-1:0] r_addr,
  output reg  [DATA_WIDTH-1:0] r_data,

  input  wire                  w_en,
  input  wire [ADDR_WIDTH-1:0] w_addr,
  input  wire [DATA_WIDTH-1:0] w_data,
  input  wire [STRB_WIDTH-1:0] w_strb
);

  localparam DEPTH = (1 << ADDR_WIDTH);

  reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

  generate
    if (BYTE_WRITE) begin : gen_byte_write
      integer byte_idx;

      always @(posedge clk) begin
        if (r_en) begin
          r_data <= mem[r_addr];
        end

        if (w_en) begin
          for (byte_idx = 0; byte_idx < STRB_WIDTH; byte_idx = byte_idx + 1) begin
            if (w_strb[byte_idx]) begin
              mem[w_addr][byte_idx*8 +: 8] <= w_data[byte_idx*8 +: 8];
            end
          end
        end
      end
    end else begin : gen_full_write
      always @(posedge clk) begin
        if (r_en) begin
          r_data <= mem[r_addr];
        end

        if (w_en) begin
          mem[w_addr] <= w_data;
        end
      end
    end
  endgenerate

endmodule
