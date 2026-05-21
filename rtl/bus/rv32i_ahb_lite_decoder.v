module rv32i_ahb_lite_decoder #(
  parameter [31:0] S0_BASE = 32'h0000_0000,
  parameter [31:0] S0_MASK = 32'hF000_0000,
  parameter [31:0] S1_BASE = 32'h2000_0000,
  parameter [31:0] S1_MASK = 32'hF000_0000,
  parameter [31:0] S2_BASE = 32'h4000_0000,
  parameter [31:0] S2_MASK = 32'hF000_0000
) (
  input  wire        clk,
  input  wire        rst_n,

  input  wire [31:0] m_haddr,
  input  wire [2:0]  m_hburst,
  input  wire [3:0]  m_hprot,
  input  wire [2:0]  m_hsize,
  input  wire [1:0]  m_htrans,
  input  wire [31:0] m_hwdata,
  input  wire        m_hwrite,
  output wire [31:0] m_hrdata,
  output wire        m_hready,
  output wire [1:0]  m_hresp,

  output wire        s0_hsel,
  output wire [31:0] s0_haddr,
  output wire [2:0]  s0_hburst,
  output wire [3:0]  s0_hprot,
  output wire [2:0]  s0_hsize,
  output wire [1:0]  s0_htrans,
  output wire [31:0] s0_hwdata,
  output wire        s0_hwrite,
  output wire        s0_hready,
  input  wire [31:0] s0_hrdata,
  input  wire        s0_hreadyout,
  input  wire [1:0]  s0_hresp,

  output wire        s1_hsel,
  output wire [31:0] s1_haddr,
  output wire [2:0]  s1_hburst,
  output wire [3:0]  s1_hprot,
  output wire [2:0]  s1_hsize,
  output wire [1:0]  s1_htrans,
  output wire [31:0] s1_hwdata,
  output wire        s1_hwrite,
  output wire        s1_hready,
  input  wire [31:0] s1_hrdata,
  input  wire        s1_hreadyout,
  input  wire [1:0]  s1_hresp,

  output wire        s2_hsel,
  output wire [31:0] s2_haddr,
  output wire [2:0]  s2_hburst,
  output wire [3:0]  s2_hprot,
  output wire [2:0]  s2_hsize,
  output wire [1:0]  s2_htrans,
  output wire [31:0] s2_hwdata,
  output wire        s2_hwrite,
  output wire        s2_hready,
  input  wire [31:0] s2_hrdata,
  input  wire        s2_hreadyout,
  input  wire [1:0]  s2_hresp,

  output wire        dbg_decode_error
);

  localparam [1:0] HRESP_OKAY  = 2'b00;
  localparam [1:0] HRESP_ERROR = 2'b01;

  localparam [1:0] TARGET_S0    = 2'd0;
  localparam [1:0] TARGET_S1    = 2'd1;
  localparam [1:0] TARGET_S2    = 2'd2;
  localparam [1:0] TARGET_ERROR = 2'd3;

  reg        data_valid_q;
  reg [1:0]  data_target_q;

  wire        address_valid;
  wire [1:0]  address_target;
  wire [31:0] selected_hrdata;
  wire        selected_hreadyout;
  wire [1:0]  selected_hresp;

  function [1:0] decode_target;
    input [31:0] addr;
    begin
      if ((addr & S0_MASK) == S0_BASE) begin
        decode_target = TARGET_S0;
      end else if ((addr & S1_MASK) == S1_BASE) begin
        decode_target = TARGET_S1;
      end else if ((addr & S2_MASK) == S2_BASE) begin
        decode_target = TARGET_S2;
      end else begin
        decode_target = TARGET_ERROR;
      end
    end
  endfunction

  assign address_valid  = m_htrans[1];
  assign address_target = decode_target(m_haddr);

  assign selected_hrdata = (data_target_q == TARGET_S0) ? s0_hrdata :
                           (data_target_q == TARGET_S1) ? s1_hrdata :
                           (data_target_q == TARGET_S2) ? s2_hrdata :
                                                          32'd0;
  assign selected_hreadyout = !data_valid_q                    ? 1'b1 :
                              (data_target_q == TARGET_S0)    ? s0_hreadyout :
                              (data_target_q == TARGET_S1)    ? s1_hreadyout :
                              (data_target_q == TARGET_S2)    ? s2_hreadyout :
                                                                 1'b1;
  assign selected_hresp = !data_valid_q                    ? HRESP_OKAY :
                          (data_target_q == TARGET_S0)    ? s0_hresp :
                          (data_target_q == TARGET_S1)    ? s1_hresp :
                          (data_target_q == TARGET_S2)    ? s2_hresp :
                                                             HRESP_ERROR;

  assign m_hrdata = selected_hrdata;
  assign m_hready = selected_hreadyout;
  assign m_hresp  = selected_hresp;

  assign s0_hsel = address_valid && m_hready && (address_target == TARGET_S0);
  assign s1_hsel = address_valid && m_hready && (address_target == TARGET_S1);
  assign s2_hsel = address_valid && m_hready && (address_target == TARGET_S2);

  assign s0_haddr   = m_haddr;
  assign s0_hburst  = m_hburst;
  assign s0_hprot   = m_hprot;
  assign s0_hsize   = m_hsize;
  assign s0_htrans  = m_htrans;
  assign s0_hwdata  = m_hwdata;
  assign s0_hwrite  = m_hwrite;
  assign s0_hready  = m_hready;

  assign s1_haddr   = m_haddr;
  assign s1_hburst  = m_hburst;
  assign s1_hprot   = m_hprot;
  assign s1_hsize   = m_hsize;
  assign s1_htrans  = m_htrans;
  assign s1_hwdata  = m_hwdata;
  assign s1_hwrite  = m_hwrite;
  assign s1_hready  = m_hready;

  assign s2_haddr   = m_haddr;
  assign s2_hburst  = m_hburst;
  assign s2_hprot   = m_hprot;
  assign s2_hsize   = m_hsize;
  assign s2_htrans  = m_htrans;
  assign s2_hwdata  = m_hwdata;
  assign s2_hwrite  = m_hwrite;
  assign s2_hready  = m_hready;

  assign dbg_decode_error = data_valid_q && (data_target_q == TARGET_ERROR);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_valid_q  <= 1'b0;
      data_target_q <= TARGET_ERROR;
    end else if (m_hready) begin
      data_valid_q  <= address_valid;
      data_target_q <= address_target;
    end
  end

endmodule
