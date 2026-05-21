module rv32i_ahb_lite_matrix_2m4s #(
  parameter [31:0] S0_BASE = 32'h0800_0000,
  parameter [31:0] S0_MASK = 32'hF800_0000,
  parameter [31:0] S1_BASE = 32'h2000_0000,
  parameter [31:0] S1_MASK = 32'hF000_0000,
  parameter [31:0] S2_BASE = 32'h4000_0000,
  parameter [31:0] S2_MASK = 32'hFE00_0000,
  parameter [31:0] S3_BASE = 32'h4200_0000,
  parameter [31:0] S3_MASK = 32'hFE00_0000
) (
  input  wire        clk,
  input  wire        rst_n,

  input  wire [31:0] m0_haddr,
  input  wire [2:0]  m0_hburst,
  input  wire [3:0]  m0_hprot,
  input  wire [2:0]  m0_hsize,
  input  wire [1:0]  m0_htrans,
  input  wire [31:0] m0_hwdata,
  input  wire        m0_hwrite,
  output wire [31:0] m0_hrdata,
  output wire        m0_hready,
  output wire [1:0]  m0_hresp,

  input  wire [31:0] m1_haddr,
  input  wire [2:0]  m1_hburst,
  input  wire [3:0]  m1_hprot,
  input  wire [2:0]  m1_hsize,
  input  wire [1:0]  m1_htrans,
  input  wire [31:0] m1_hwdata,
  input  wire        m1_hwrite,
  output wire [31:0] m1_hrdata,
  output wire        m1_hready,
  output wire [1:0]  m1_hresp,

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

  output wire        s3_hsel,
  output wire [31:0] s3_haddr,
  output wire [2:0]  s3_hburst,
  output wire [3:0]  s3_hprot,
  output wire [2:0]  s3_hsize,
  output wire [1:0]  s3_htrans,
  output wire [31:0] s3_hwdata,
  output wire        s3_hwrite,
  output wire        s3_hready,
  input  wire [31:0] s3_hrdata,
  input  wire        s3_hreadyout,
  input  wire [1:0]  s3_hresp,

  output wire        dbg_decode_error,
  output wire [31:0] dbg_m0_grant_count,
  output wire [31:0] dbg_m1_grant_count
);

  localparam [1:0] HRESP_OKAY    = 2'b00;
  localparam [1:0] HTRANS_IDLE   = 2'b00;
  localparam [1:0] GRANT_NONE    = 2'd0;
  localparam [1:0] GRANT_M0      = 2'd1;
  localparam [1:0] GRANT_M1      = 2'd2;
  localparam [0:0] STATE_IDLE    = 1'b0;
  localparam [0:0] STATE_DATA    = 1'b1;

  reg        state_q;
  reg [1:0]  grant_q;
  reg [31:0] m0_grant_count_q;
  reg [31:0] m1_grant_count_q;

  wire        m0_req;
  wire        m1_req;
  wire [1:0]  idle_grant;
  wire [1:0]  active_grant;
  wire        grant_m0;
  wire        grant_m1;
  wire [31:0] inner_haddr;
  wire [2:0]  inner_hburst;
  wire [3:0]  inner_hprot;
  wire [2:0]  inner_hsize;
  wire [1:0]  inner_htrans;
  wire [31:0] inner_hwdata;
  wire        inner_hwrite;
  wire [31:0] inner_hrdata;
  wire        inner_hready;
  wire [1:0]  inner_hresp;
  wire        address_accepted;
  wire        data_complete;

  assign m0_req = m0_htrans[1];
  assign m1_req = m1_htrans[1];

  assign idle_grant = m1_req ? GRANT_M1 :
                      m0_req ? GRANT_M0 :
                               GRANT_NONE;
  assign active_grant = (state_q == STATE_IDLE) ? idle_grant : grant_q;
  assign grant_m0 = (active_grant == GRANT_M0);
  assign grant_m1 = (active_grant == GRANT_M1);

  assign inner_haddr  = grant_m1 ? m1_haddr  : m0_haddr;
  assign inner_hburst = grant_m1 ? m1_hburst : m0_hburst;
  assign inner_hprot  = grant_m1 ? m1_hprot  : m0_hprot;
  assign inner_hsize  = grant_m1 ? m1_hsize  : m0_hsize;
  assign inner_htrans = (state_q == STATE_IDLE) ?
                        (grant_m1 ? m1_htrans :
                         grant_m0 ? m0_htrans : HTRANS_IDLE) :
                        HTRANS_IDLE;
  assign inner_hwdata = grant_m1 ? m1_hwdata : m0_hwdata;
  assign inner_hwrite = grant_m1 ? m1_hwrite : m0_hwrite;

  assign m0_hrdata = grant_m0 ? inner_hrdata : 32'd0;
  assign m0_hready = grant_m0 ? inner_hready : 1'b0;
  assign m0_hresp  = grant_m0 ? inner_hresp  : HRESP_OKAY;

  assign m1_hrdata = grant_m1 ? inner_hrdata : 32'd0;
  assign m1_hready = grant_m1 ? inner_hready : 1'b0;
  assign m1_hresp  = grant_m1 ? inner_hresp  : HRESP_OKAY;

  assign address_accepted = (state_q == STATE_IDLE) &&
                            (active_grant != GRANT_NONE) &&
                            inner_htrans[1] &&
                            inner_hready;
  assign data_complete = (state_q == STATE_DATA) && inner_hready;

  assign dbg_m0_grant_count = m0_grant_count_q;
  assign dbg_m1_grant_count = m1_grant_count_q;

  rv32i_ahb_lite_matrix_1m4s #(
    .S0_BASE(S0_BASE),
    .S0_MASK(S0_MASK),
    .S1_BASE(S1_BASE),
    .S1_MASK(S1_MASK),
    .S2_BASE(S2_BASE),
    .S2_MASK(S2_MASK),
    .S3_BASE(S3_BASE),
    .S3_MASK(S3_MASK)
  ) u_inner_matrix (
    .clk              (clk),
    .rst_n            (rst_n),
    .m_haddr          (inner_haddr),
    .m_hburst         (inner_hburst),
    .m_hprot          (inner_hprot),
    .m_hsize          (inner_hsize),
    .m_htrans         (inner_htrans),
    .m_hwdata         (inner_hwdata),
    .m_hwrite         (inner_hwrite),
    .m_hrdata         (inner_hrdata),
    .m_hready         (inner_hready),
    .m_hresp          (inner_hresp),
    .s0_hsel          (s0_hsel),
    .s0_haddr         (s0_haddr),
    .s0_hburst        (s0_hburst),
    .s0_hprot         (s0_hprot),
    .s0_hsize         (s0_hsize),
    .s0_htrans        (s0_htrans),
    .s0_hwdata        (s0_hwdata),
    .s0_hwrite        (s0_hwrite),
    .s0_hready        (s0_hready),
    .s0_hrdata        (s0_hrdata),
    .s0_hreadyout     (s0_hreadyout),
    .s0_hresp         (s0_hresp),
    .s1_hsel          (s1_hsel),
    .s1_haddr         (s1_haddr),
    .s1_hburst        (s1_hburst),
    .s1_hprot         (s1_hprot),
    .s1_hsize         (s1_hsize),
    .s1_htrans        (s1_htrans),
    .s1_hwdata        (s1_hwdata),
    .s1_hwrite        (s1_hwrite),
    .s1_hready        (s1_hready),
    .s1_hrdata        (s1_hrdata),
    .s1_hreadyout     (s1_hreadyout),
    .s1_hresp         (s1_hresp),
    .s2_hsel          (s2_hsel),
    .s2_haddr         (s2_haddr),
    .s2_hburst        (s2_hburst),
    .s2_hprot         (s2_hprot),
    .s2_hsize         (s2_hsize),
    .s2_htrans        (s2_htrans),
    .s2_hwdata        (s2_hwdata),
    .s2_hwrite        (s2_hwrite),
    .s2_hready        (s2_hready),
    .s2_hrdata        (s2_hrdata),
    .s2_hreadyout     (s2_hreadyout),
    .s2_hresp         (s2_hresp),
    .s3_hsel          (s3_hsel),
    .s3_haddr         (s3_haddr),
    .s3_hburst        (s3_hburst),
    .s3_hprot         (s3_hprot),
    .s3_hsize         (s3_hsize),
    .s3_htrans        (s3_htrans),
    .s3_hwdata        (s3_hwdata),
    .s3_hwrite        (s3_hwrite),
    .s3_hready        (s3_hready),
    .s3_hrdata        (s3_hrdata),
    .s3_hreadyout     (s3_hreadyout),
    .s3_hresp         (s3_hresp),
    .dbg_decode_error (dbg_decode_error)
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q          <= STATE_IDLE;
      grant_q          <= GRANT_NONE;
      m0_grant_count_q <= 32'd0;
      m1_grant_count_q <= 32'd0;
    end else begin
      case (state_q)
        STATE_IDLE: begin
          grant_q <= idle_grant;
          if (address_accepted) begin
            state_q <= STATE_DATA;
            if (active_grant == GRANT_M0) begin
              m0_grant_count_q <= m0_grant_count_q + 32'd1;
            end else if (active_grant == GRANT_M1) begin
              m1_grant_count_q <= m1_grant_count_q + 32'd1;
            end
          end
        end

        STATE_DATA: begin
          if (data_complete) begin
            state_q <= STATE_IDLE;
            grant_q <= GRANT_NONE;
          end
        end

        default: begin
          state_q <= STATE_IDLE;
          grant_q <= GRANT_NONE;
        end
      endcase
    end
  end

endmodule
