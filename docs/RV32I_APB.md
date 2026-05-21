# RV32I AHB-to-APB SoC Integration

This note records the APB peripheral subsystem added below the AHB-Lite matrix.

## Purpose

The CPU subsystem exposes one AHB-Lite master port. The SoC fabric uses AHB-Lite for flash, SRAM, and high-speed peripherals, then uses APB for simple register peripherals.

Current path:

```text
rv32i_cached_ahb_master_top
  -> rv32i_ahb_lite_matrix_1m4s
    -> flash AHB slot
    -> SRAM AHB slot
    -> AHB peripheral slot
    -> rv32i_ahb_to_apb
      -> rv32i_apb_periph_mux
        -> rv32i_timer
        -> rv32i_uart
```

## Modules

- `rtl/bus/rv32i_ahb_to_apb.v`
  - AHB-Lite slave to APB4-style master bridge.
  - Single-beat, single-outstanding.
  - Drives APB setup/access phases.
  - Converts AHB `HSIZE/HADDR` into APB `PSTRB`.
  - Converts APB `PSLVERR` into AHB `HRESP=ERROR`.
- `rtl/periph/rv32i_apb_periph_mux.v`
  - Decodes APB timer and UART windows.
  - Unmatched APB accesses complete with `PSLVERR=1`.
- `rtl/top/rv32i_ahb_matrix_apb_soc_top.v`
  - Keeps flash/SRAM/AHB-peripheral AHB slots external.
  - Instantiates internal APB timer and UART.
  - Routes timer interrupt into the CPU subsystem.

## Memory Map

```text
0x0800_0000 - 0x0FFF_FFFF  flash AHB slot
0x2000_0000 - 0x2FFF_FFFF  SRAM AHB slot
0x4000_0000 - 0x41FF_FFFF  AHB peripheral slot
0x4200_0000 - 0x4200_0FFF  APB timer
0x4200_1000 - 0x4200_1FFF  APB UART
```

## Directed Test

Software image:

```text
software/asm/ahb_matrix_apb_soc.S
software/bin/ahb_matrix_apb_soc.memh
```

Run from `sim/`:

```bash
make sim TB_FILE=./testcases/rv32i_ahb_matrix_apb_soc_top_tb.sv TOP_NAME=rv32i_ahb_matrix_apb_soc_top_tb
```

The test boots from flash, accesses SRAM, writes/reads the external AHB peripheral slot, writes/reads APB timer `mtimecmp_lo`, and writes/reads APB UART TX/status.

Status: user-confirmed VCS PASS on 2026-05-18.
