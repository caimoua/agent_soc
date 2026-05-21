module rv32i_mem_bus_ahb #(
  parameter [31:0] ROM_BASE  = 32'h0000_0000,
  parameter [31:0] ROM_MASK  = 32'hF000_0000,
  parameter [31:0] SRAM_BASE = 32'h2000_0000,
  parameter [31:0] SRAM_MASK = 32'hF000_0000,
  parameter [31:0] MMIO_BASE = 32'h4000_0000,
  parameter [31:0] MMIO_MASK = 32'hF000_0000
) (
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

  output wire        rom_valid,
  output wire        rom_write,
  output wire [31:0] rom_addr,
  output wire [31:0] rom_wdata,
  output wire [3:0]  rom_wstrb,
  input  wire        rom_ready,
  input  wire [31:0] rom_rdata,

  output wire        sram_valid,
  output wire        sram_write,
  output wire [31:0] sram_addr,
  output wire [31:0] sram_wdata,
  output wire [3:0]  sram_wstrb,
  input  wire        sram_ready,
  input  wire [31:0] sram_rdata,

  output wire        mmio_valid,
  output wire        mmio_write,
  output wire [31:0] mmio_addr,
  output wire [31:0] mmio_wdata,
  output wire [3:0]  mmio_wstrb,
  input  wire        mmio_ready,
  input  wire [31:0] mmio_rdata,

  output wire        dbg_active,
  output wire        dbg_grant_is_d,
  output wire [1:0]  dbg_target,
  output wire        dbg_decode_error,
  output wire [31:0] dbg_i_grant_count,
  output wire [31:0] dbg_d_grant_count
);

  localparam MASTER_I = 1'b0;
  localparam MASTER_D = 1'b1;

  localparam TARGET_ROM   = 2'd0;
  localparam TARGET_SRAM  = 2'd1;
  localparam TARGET_MMIO  = 2'd2;
  localparam TARGET_ERROR = 2'd3;

  reg        active_q;
  reg        master_q;
  reg [1:0]  target_q;
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

  wire [31:0] m_haddr;
  wire [2:0]  m_hburst;
  wire [3:0]  m_hprot;
  wire [2:0]  m_hsize;
  wire [1:0]  m_htrans;
  wire [31:0] m_hwdata;
  wire        m_hwrite;
  wire [31:0] m_hrdata;
  wire        m_hready;
  wire [1:0]  m_hresp;

  wire        rom_hsel;
  wire [31:0] rom_haddr;
  wire [2:0]  rom_hburst;
  wire [3:0]  rom_hprot;
  wire [2:0]  rom_hsize;
  wire [1:0]  rom_htrans;
  wire [31:0] rom_hwdata;
  wire        rom_hwrite;
  wire        rom_hready;
  wire [31:0] rom_hrdata;
  wire        rom_hreadyout;
  wire [1:0]  rom_hresp;

  wire        sram_hsel;
  wire [31:0] sram_haddr;
  wire [2:0]  sram_hburst;
  wire [3:0]  sram_hprot;
  wire [2:0]  sram_hsize;
  wire [1:0]  sram_htrans;
  wire [31:0] sram_hwdata;
  wire        sram_hwrite;
  wire        sram_hready;
  wire [31:0] sram_hrdata;
  wire        sram_hreadyout;
  wire [1:0]  sram_hresp;

  wire        mmio_hsel;
  wire [31:0] mmio_haddr;
  wire [2:0]  mmio_hburst;
  wire [3:0]  mmio_hprot;
  wire [2:0]  mmio_hsize;
  wire [1:0]  mmio_htrans;
  wire [31:0] mmio_hwdata;
  wire        mmio_hwrite;
  wire        mmio_hready;
  wire [31:0] mmio_hrdata;
  wire        mmio_hreadyout;
  wire [1:0]  mmio_hresp;

  wire        ahb_decode_error;
  wire        active_done;

  function [1:0] decode_target;
    input [31:0] addr;
    begin
      if ((addr & ROM_MASK) == ROM_BASE) begin
        decode_target = TARGET_ROM;
      end else if ((addr & SRAM_MASK) == SRAM_BASE) begin
        decode_target = TARGET_SRAM;
      end else if ((addr & MMIO_MASK) == MMIO_BASE) begin
        decode_target = TARGET_MMIO;
      end else begin
        decode_target = TARGET_ERROR;
      end
    end
  endfunction

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
  assign dbg_target        = target_q;
  assign dbg_decode_error  = ahb_decode_error;
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
    .haddr  (m_haddr),
    .hburst (m_hburst),
    .hprot  (m_hprot),
    .hsize  (m_hsize),
    .htrans (m_htrans),
    .hwdata (m_hwdata),
    .hwrite (m_hwrite),
    .hrdata (m_hrdata),
    .hready (m_hready),
    .hresp  (m_hresp)
  );

  rv32i_ahb_lite_decoder #(
    .S0_BASE (ROM_BASE),
    .S0_MASK (ROM_MASK),
    .S1_BASE (SRAM_BASE),
    .S1_MASK (SRAM_MASK),
    .S2_BASE (MMIO_BASE),
    .S2_MASK (MMIO_MASK)
  ) u_ahb_decoder (
    .clk              (clk),
    .rst_n            (rst_n),
    .m_haddr          (m_haddr),
    .m_hburst         (m_hburst),
    .m_hprot          (m_hprot),
    .m_hsize          (m_hsize),
    .m_htrans         (m_htrans),
    .m_hwdata         (m_hwdata),
    .m_hwrite         (m_hwrite),
    .m_hrdata         (m_hrdata),
    .m_hready         (m_hready),
    .m_hresp          (m_hresp),
    .s0_hsel          (rom_hsel),
    .s0_haddr         (rom_haddr),
    .s0_hburst        (rom_hburst),
    .s0_hprot         (rom_hprot),
    .s0_hsize         (rom_hsize),
    .s0_htrans        (rom_htrans),
    .s0_hwdata        (rom_hwdata),
    .s0_hwrite        (rom_hwrite),
    .s0_hready        (rom_hready),
    .s0_hrdata        (rom_hrdata),
    .s0_hreadyout     (rom_hreadyout),
    .s0_hresp         (rom_hresp),
    .s1_hsel          (sram_hsel),
    .s1_haddr         (sram_haddr),
    .s1_hburst        (sram_hburst),
    .s1_hprot         (sram_hprot),
    .s1_hsize         (sram_hsize),
    .s1_htrans        (sram_htrans),
    .s1_hwdata        (sram_hwdata),
    .s1_hwrite        (sram_hwrite),
    .s1_hready        (sram_hready),
    .s1_hrdata        (sram_hrdata),
    .s1_hreadyout     (sram_hreadyout),
    .s1_hresp         (sram_hresp),
    .s2_hsel          (mmio_hsel),
    .s2_haddr         (mmio_haddr),
    .s2_hburst        (mmio_hburst),
    .s2_hprot         (mmio_hprot),
    .s2_hsize         (mmio_hsize),
    .s2_htrans        (mmio_htrans),
    .s2_hwdata        (mmio_hwdata),
    .s2_hwrite        (mmio_hwrite),
    .s2_hready        (mmio_hready),
    .s2_hrdata        (mmio_hrdata),
    .s2_hreadyout     (mmio_hreadyout),
    .s2_hresp         (mmio_hresp),
    .dbg_decode_error (ahb_decode_error)
  );

  rv32i_ahb_to_simple u_rom_ahb_to_simple (
    .clk       (clk),
    .rst_n     (rst_n),
    .hsel      (rom_hsel),
    .haddr     (rom_haddr),
    .hburst    (rom_hburst),
    .hprot     (rom_hprot),
    .hsize     (rom_hsize),
    .htrans    (rom_htrans),
    .hwdata    (rom_hwdata),
    .hwrite    (rom_hwrite),
    .hready    (rom_hready),
    .hrdata    (rom_hrdata),
    .hreadyout (rom_hreadyout),
    .hresp     (rom_hresp),
    .valid     (rom_valid),
    .write     (rom_write),
    .addr      (rom_addr),
    .wdata     (rom_wdata),
    .wstrb     (rom_wstrb),
    .ready     (rom_ready),
    .rdata     (rom_rdata),
    .error     (1'b0)
  );

  rv32i_ahb_to_simple u_sram_ahb_to_simple (
    .clk       (clk),
    .rst_n     (rst_n),
    .hsel      (sram_hsel),
    .haddr     (sram_haddr),
    .hburst    (sram_hburst),
    .hprot     (sram_hprot),
    .hsize     (sram_hsize),
    .htrans    (sram_htrans),
    .hwdata    (sram_hwdata),
    .hwrite    (sram_hwrite),
    .hready    (sram_hready),
    .hrdata    (sram_hrdata),
    .hreadyout (sram_hreadyout),
    .hresp     (sram_hresp),
    .valid     (sram_valid),
    .write     (sram_write),
    .addr      (sram_addr),
    .wdata     (sram_wdata),
    .wstrb     (sram_wstrb),
    .ready     (sram_ready),
    .rdata     (sram_rdata),
    .error     (1'b0)
  );

  rv32i_ahb_to_simple u_mmio_ahb_to_simple (
    .clk       (clk),
    .rst_n     (rst_n),
    .hsel      (mmio_hsel),
    .haddr     (mmio_haddr),
    .hburst    (mmio_hburst),
    .hprot     (mmio_hprot),
    .hsize     (mmio_hsize),
    .htrans    (mmio_htrans),
    .hwdata    (mmio_hwdata),
    .hwrite    (mmio_hwrite),
    .hready    (mmio_hready),
    .hrdata    (mmio_hrdata),
    .hreadyout (mmio_hreadyout),
    .hresp     (mmio_hresp),
    .valid     (mmio_valid),
    .write     (mmio_write),
    .addr      (mmio_addr),
    .wdata     (mmio_wdata),
    .wstrb     (mmio_wstrb),
    .ready     (mmio_ready),
    .rdata     (mmio_rdata),
    .error     (1'b0)
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      active_q        <= 1'b0;
      master_q        <= MASTER_I;
      target_q        <= TARGET_ERROR;
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
      target_q <= decode_target(req_addr);
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
