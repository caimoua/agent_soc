module rv32i_ahb_master_bus (
  input  wire        clk,
  input  wire        rst_n,

  input  wire        i_valid,
  input  wire [31:0] i_addr,
  output wire        i_ready,
  output wire [31:0] i_rdata,
  output wire        i_error,

  input  wire        d_valid,
  input  wire        d_write,
  input  wire [31:0] d_addr,
  input  wire [31:0] d_wdata,
  input  wire [3:0]  d_wstrb,
  output wire        d_ready,
  output wire [31:0] d_rdata,
  output wire        d_error,

  output wire [31:0] ahb_haddr,
  output wire [2:0]  ahb_hburst,
  output wire [3:0]  ahb_hprot,
  output wire [2:0]  ahb_hsize,
  output wire [1:0]  ahb_htrans,
  output wire [31:0] ahb_hwdata,
  output wire        ahb_hwrite,
  input  wire [31:0] ahb_hrdata,
  input  wire        ahb_hready,
  input  wire [1:0]  ahb_hresp,

  output wire        dbg_active,
  output wire        dbg_grant_is_d,
  output wire        dbg_bus_error,
  output wire [31:0] dbg_i_grant_count,
  output wire [31:0] dbg_d_grant_count
);

  localparam MASTER_I = 1'b0;
  localparam MASTER_D = 1'b1;

  reg        active_q;
  reg        master_q;
  reg [31:0] addr_q;
  reg        write_q;
  reg [31:0] wdata_q;
  reg [3:0]  wstrb_q;
  reg [31:0] i_grant_count_q;
  reg [31:0] d_grant_count_q;

  wire [31:0] req_addr;
  wire        req_write;
  wire [31:0] req_wdata;
  wire [3:0]  req_wstrb;

  wire        simple_ready;
  wire [31:0] simple_rdata;
  wire        simple_error;
  wire        active_done;

  assign req_addr  = d_valid ? d_addr   : i_addr;
  assign req_write = d_valid ? d_write  : 1'b0;
  assign req_wdata = d_valid ? d_wdata  : 32'd0;
  assign req_wstrb = d_valid ? d_wstrb  : 4'b0000;

  assign active_done = active_q && simple_ready;

  assign i_ready = active_done && (master_q == MASTER_I);
  assign d_ready = active_done && (master_q == MASTER_D);
  assign i_rdata = simple_rdata;
  assign d_rdata = simple_rdata;
  assign i_error = active_done && (master_q == MASTER_I) && simple_error;
  assign d_error = active_done && (master_q == MASTER_D) && simple_error;

  assign dbg_active        = active_q;
  assign dbg_grant_is_d    = master_q;
  assign dbg_bus_error     = active_done && simple_error;
  assign dbg_i_grant_count = i_grant_count_q;
  assign dbg_d_grant_count = d_grant_count_q;

  rv32i_simple_to_ahb u_simple_to_ahb (
    .clk    (clk),
    .rst_n  (rst_n),
    .valid  (active_q),
    .write  (write_q),
    .addr   (addr_q),
    .wdata  (wdata_q),
    .wstrb  (wstrb_q),
    .ready  (simple_ready),
    .rdata  (simple_rdata),
    .error  (simple_error),
    .haddr  (ahb_haddr),
    .hburst (ahb_hburst),
    .hprot  (ahb_hprot),
    .hsize  (ahb_hsize),
    .htrans (ahb_htrans),
    .hwdata (ahb_hwdata),
    .hwrite (ahb_hwrite),
    .hrdata (ahb_hrdata),
    .hready (ahb_hready),
    .hresp  (ahb_hresp)
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      active_q        <= 1'b0;
      master_q        <= MASTER_I;
      addr_q          <= 32'd0;
      write_q         <= 1'b0;
      wdata_q         <= 32'd0;
      wstrb_q         <= 4'b0000;
      i_grant_count_q <= 32'd0;
      d_grant_count_q <= 32'd0;
    end else if (active_q) begin
      if (simple_ready) begin
        active_q <= 1'b0;
      end
    end else if (d_valid || i_valid) begin
      active_q <= 1'b1;
      master_q <= d_valid ? MASTER_D : MASTER_I;
      addr_q   <= req_addr;
      write_q  <= req_write;
      wdata_q  <= req_wdata;
      wstrb_q  <= req_wstrb;

      if (d_valid) begin
        d_grant_count_q <= d_grant_count_q + 32'd1;
      end else begin
        i_grant_count_q <= i_grant_count_q + 32'd1;
      end
    end
  end

endmodule
