# Basic timing constraints for the CPU IP delivery boundary.
#
# This is an initial, technology-neutral SDC used by Stage A4 quality checks.
# A real ASIC/FPGA flow should replace the delay numbers with board/library
# specific constraints.

create_clock -name clk -period 10.000 [get_ports clk]

set_input_delay  -clock clk 2.000 [get_ports {
  timer_irq
  ahb_hrdata[*]
  ahb_hready
  ahb_hresp[*]
  dbg_reg_addr[*]
}]

set_output_delay -clock clk 2.000 [get_ports {
  ahb_haddr[*]
  ahb_hburst[*]
  ahb_hprot[*]
  ahb_hsize[*]
  ahb_htrans[*]
  ahb_hwdata[*]
  ahb_hwrite
  dbg_pc[*]
  dbg_cycle[*]
  dbg_instret[*]
  dbg_stall_cycle[*]
  dbg_flush_cycle[*]
  dbg_branch_count[*]
  dbg_branch_mispredict_count[*]
  dbg_btb_hit_count[*]
  dbg_btb_miss_count[*]
  dbg_bht_update_count[*]
  dbg_reg_rdata[*]
  dbg_illegal_instr
  dbg_ecall
  dbg_ebreak
  dbg_icache_hit_count[*]
  dbg_icache_miss_count[*]
  dbg_dcache_hit_count[*]
  dbg_dcache_miss_count[*]
  dbg_bus_i_grant_count[*]
  dbg_bus_d_grant_count[*]
  dbg_bus_error
}]

set_false_path -from [get_ports rst_n]
