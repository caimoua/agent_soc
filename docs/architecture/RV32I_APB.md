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
        -> rv32i_agent_matrix_accel
        -> rv32i_tool_call_detector
```

## Modules

- `rtl/bus/rv32i_ahb_to_apb.v`
  - AHB-Lite slave to APB4-style master bridge.
  - Single-beat, single-outstanding.
  - Drives APB setup/access phases.
  - Converts AHB `HSIZE/HADDR` into APB `PSTRB`.
  - Converts APB `PSLVERR` into AHB `HRESP=ERROR`.
- `rtl/periph/rv32i_apb_periph_mux.v`
  - Decodes APB timer, UART, Agent Matrix Accelerator, and Tool-call Detector windows.
  - Unmatched APB accesses complete with `PSLVERR=1`.
- `rtl/top/rv32i_ahb_matrix_apb_soc_top.v`
  - Keeps flash/SRAM/AHB-peripheral AHB slots external.
  - Instantiates internal APB timer, UART, and Agent Matrix Accelerator.
  - Routes timer interrupt into the CPU subsystem.
- `rtl/accel/rv32i_agent_matrix_accel.v`
  - APB scratchpad INT8 `4x4` matrix by `4x1` vector accelerator.
  - SRAM-mode register path can read matrix/vector from SRAM and write result back through the accelerator AHB master.
  - Generates 4 signed int32 results and a done/IRQ-pending status.
- `rtl/accel/rv32i_tool_call_detector.v`
  - APB token pattern detector.
  - Matches up to 8 packed 16-bit tokens and exposes match count/status/IRQ pending.

## Memory Map

```text
0x0800_0000 - 0x0FFF_FFFF  flash AHB slot
0x2000_0000 - 0x2FFF_FFFF  SRAM AHB slot
0x4000_0000 - 0x41FF_FFFF  AHB peripheral slot
0x4200_0000 - 0x4200_0FFF  APB timer
0x4200_1000 - 0x4200_1FFF  APB UART
0x4200_2000 - 0x4200_2FFF  APB Agent Matrix Accelerator
0x4200_3000 - 0x4200_3FFF  APB Tool-call Detector
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

Agent Matrix Accelerator smoke image:

```text
software/asm/agent_matrix_accel.S
software/bin/agent_matrix_accel.memh
software/asm/agent_matrix_accel_sram.S
software/bin/agent_matrix_accel_sram.memh
```

Run from `sim/`:

```bash
make sim TB_FILE=./testcases/rv32i_agent_matrix_accel_soc_tb.sv TOP_NAME=rv32i_agent_matrix_accel_soc_tb
make sim TB_FILE=./testcases/rv32i_agent_matrix_accel_sram_soc_tb.sv TOP_NAME=rv32i_agent_matrix_accel_sram_soc_tb
```

This test boots from flash, writes APB scratchpad matrix/vector data at `0x4200_2000`, starts the accelerator, polls done, checks four int32 results and IRQ pending/clear behavior, then stops on `ebreak`.

The SRAM-mode test programs `SRC_A/SRC_B/DST/STRIDE/FLAGS`, then validates that the accelerator receives AHB M1 grants, reads SRAM input, and writes the result window back to SRAM.

Status: pending VCS confirmation.
