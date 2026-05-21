module rv32i_mem_bus #(
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
  wire        selected_ready;
  wire [31:0] selected_rdata;
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

  assign selected_ready = (target_q == TARGET_ROM)  ? rom_ready  :
                          (target_q == TARGET_SRAM) ? sram_ready :
                          (target_q == TARGET_MMIO) ? mmio_ready :
                                                       1'b1;
  assign selected_rdata = (target_q == TARGET_ROM)  ? rom_rdata  :
                          (target_q == TARGET_SRAM) ? sram_rdata :
                          (target_q == TARGET_MMIO) ? mmio_rdata :
                                                       32'd0;

  assign active_done = active_q && selected_ready;

  assign i_ready = active_done && (master_q == MASTER_I);
  assign d_ready = active_done && (master_q == MASTER_D);
  assign i_rdata = selected_rdata;
  assign d_rdata = selected_rdata;
  assign i_error = active_done && (master_q == MASTER_I) &&
                   (target_q == TARGET_ERROR);
  assign d_error = active_done && (master_q == MASTER_D) &&
                   (target_q == TARGET_ERROR);

  assign rom_valid = active_q && (target_q == TARGET_ROM);
  assign rom_write = write_q;
  assign rom_addr  = addr_q;
  assign rom_wdata = wdata_q;
  assign rom_wstrb = wstrb_q;

  assign sram_valid = active_q && (target_q == TARGET_SRAM);
  assign sram_write = write_q;
  assign sram_addr  = addr_q;
  assign sram_wdata = wdata_q;
  assign sram_wstrb = wstrb_q;

  assign mmio_valid = active_q && (target_q == TARGET_MMIO);
  assign mmio_write = write_q;
  assign mmio_addr  = addr_q;
  assign mmio_wdata = wdata_q;
  assign mmio_wstrb = wstrb_q;

  assign dbg_active        = active_q;
  assign dbg_grant_is_d    = master_q;
  assign dbg_target        = target_q;
  assign dbg_decode_error  = active_q && (target_q == TARGET_ERROR);
  assign dbg_i_grant_count = i_grant_count_q;
  assign dbg_d_grant_count = d_grant_count_q;

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
      if (selected_ready) begin
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
