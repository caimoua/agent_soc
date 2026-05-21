# RTL 目录

Current AHB matrix SoC wrapper: `top/rv32i_ahb_matrix_soc_top.v`. It keeps `rv32i_cached_ahb_master_top` as the CPU subsystem and connects it to `bus/rv32i_ahb_lite_matrix_1m4s.v`, exposing flash, SRAM, AHB peripheral, and APB peripheral AHB-Lite slave slots.

建议的模块归属：

| 路径 | 内容 |
| --- | --- |
| `core/` | CPU 数据通路、控制逻辑和后续流水线控制 |
| `common/` | ALU、寄存器堆、计数器和通用 RTL |
| `top/` | 顶层 wrapper，例如单周期 SoC top 和 cached system top |
| `bus/` | 内部 memory bus，后续 AHB-lite、AXI-lite 适配模块 |
| `mem/` | 后续 ROM、SRAM、TCM、cache 模块 |
| `periph/` | timer、UART、debug 等 MMIO 外设 |
| `include/` | 共享 Verilog 头文件 |

当前更完整的系统连接放在 `top/rv32i_cached_system_top.v`：它把 pipeline core、I-cache、D-cache 和 memory bus 连接起来，对外暴露 ROM/SRAM/MMIO 接口，并接收外部 `timer_irq` 输入。

第一版 MMIO 外设是 `periph/rv32i_timer.v`。D-cache 默认把 `0x4000_0000` MMIO 区间作为 uncached bypass，避免外设寄存器被缓存。`timer_irq` 已经接入 pipeline CSR/trap 逻辑，可以通过 `mstatus.MIE`、`mie.MTIE` 和 `mip.MTIP` 形成 machine timer interrupt。

当前也新增了最小 TX-only UART：`periph/rv32i_uart.v`。外部 MMIO 端口可通过 `periph/rv32i_mmio_periph_mux.v` 分发到 timer 和 UART，其中 timer 默认在 `0x4000_0000`，UART 默认在 `0x4000_1000`。

AHB-Lite 总线路径放在 `bus/rv32i_mem_bus_ahb.v`，它复用 simple I/D request 边界，在内部通过 `rv32i_simple_to_ahb`、`rv32i_ahb_lite_decoder` 和 `rv32i_ahb_to_simple` 访问 ROM/SRAM/MMIO。对应顶层 wrapper 是 `top/rv32i_cached_system_ahb_top.v`。

更标准的 CPU subsystem 边界是 `top/rv32i_cached_ahb_master_top.v`。它内部保留 core/cache 和 D-priority arbiter，但对外只暴露一个 AHB-Lite master interface，外部 SoC fabric 决定 ROM/SRAM/MMIO/外设地址 decode。
