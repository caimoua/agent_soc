module rv32i_uart (
  input  wire        clk,
  input  wire        rst_n,

  input  wire        valid,
  input  wire        write,
  input  wire [31:0] addr,
  input  wire [31:0] wdata,
  input  wire [3:0]  wstrb,
  output wire        ready,
  output wire [31:0] rdata,

  output wire        tx_valid,
  output wire [7:0]  tx_data,
  output wire [31:0] dbg_tx_count,
  output wire [7:0]  dbg_last_tx
);

  localparam [5:0] ADDR_TXDATA = 6'h00;
  localparam [5:0] ADDR_STATUS = 6'h04;

  reg        tx_valid_q;
  reg [7:0]  tx_data_q;
  reg [31:0] tx_count_q;

  wire [5:0]  reg_offset;
  wire        tx_write;
  wire [31:0] status_rdata;

  assign reg_offset   = addr[5:0];
  assign tx_write     = valid && ready && write &&
                        (reg_offset == ADDR_TXDATA) &&
                        wstrb[0];
  assign status_rdata = 32'h0000_0001; // bit0: TX ready

  assign ready = valid;
  assign rdata = (reg_offset == ADDR_TXDATA) ? {24'd0, tx_data_q} :
                 (reg_offset == ADDR_STATUS) ? status_rdata :
                                                32'd0;

  assign tx_valid    = tx_valid_q;
  assign tx_data     = tx_data_q;
  assign dbg_tx_count = tx_count_q;
  assign dbg_last_tx = tx_data_q;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_valid_q <= 1'b0;
      tx_data_q  <= 8'd0;
      tx_count_q <= 32'd0;
    end else begin
      tx_valid_q <= tx_write;

      if (tx_write) begin
        tx_data_q  <= wdata[7:0];
        tx_count_q <= tx_count_q + 32'd1;
      end
    end
  end

endmodule
