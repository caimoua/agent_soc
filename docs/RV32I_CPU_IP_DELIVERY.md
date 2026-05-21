# RV32I CPU IP 交付说明

最后更新：2026-05-20

本文说明当前项目推荐交付给外部 SoC 集成的 CPU 子系统边界。目标是让后来的人不用重新阅读完整 RTL，也能知道应该实例化哪个 top、怎么接总线、当前支持什么、还有哪些限制。

## 1. 推荐交付边界

推荐使用：

```text
rtl/top/rv32i_cached_ahb_master_top.v
```

结构如下：

```text
rv32i_cached_ahb_master_top
  rv32i_pipe_core
  rv32i_icache
  rv32i_dcache
  rv32i_ahb_master_bus
  external AHB-Lite master interface
```

这个 top 是当前最接近标准 CPU IP 的边界。它内部保留 core、I-cache、D-cache 和 I/D 仲裁逻辑，对外只暴露一个 AHB-Lite master port。ROM、SRAM、timer、UART、GPIO、APB bridge、default error slave 等都应该放在外部 SoC 或 bus fabric 里。

旧的 `rv32i_cached_system_top` 和 `rv32i_cached_system_ahb_top` 仍保留用于回归和对照，但不作为后续主要交付边界。

## 2. 参数

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `ICACHE_INDEX_BITS` | `2` | I-cache index 位宽。当前 I-cache 为 blocking 2-way set associative，cache line 固定为 4 个 word。 |
| `DCACHE_INDEX_BITS` | `2` | D-cache index 位宽。当前 D-cache 为 blocking 2-way，write-through，no-write-allocate。 |
| `RESET_PC` | `32'h0000_0000` | 复位后第一条取指地址。外部 SoC 的 boot ROM/flash 映射和 linker script 需要与它一致。 |
| `BRANCH_PRED_INDEX_BITS` | `6` | BHT/BTB index 位宽，默认对应 64 项 direct-mapped BHT/BTB。 |

## 3. 时钟、复位和中断

| 端口 | 方向 | 说明 |
| --- | --- | --- |
| `clk` | input | CPU 子系统主时钟。 |
| `rst_n` | input | 低有效异步复位。 |
| `timer_irq` | input | machine timer interrupt 输入，进入 core 的 CSR/trap 路径。 |

当前设计假设 `timer_irq` 与 `clk` 同步。如果真实 SoC 中 timer 来自其他时钟域，应在外部先做同步。

## 4. AHB-Lite Master 接口

| 端口 | 方向 | 说明 |
| --- | --- | --- |
| `ahb_haddr[31:0]` | output | AHB 地址。 |
| `ahb_hburst[2:0]` | output | 当前固定生成 `SINGLE`。 |
| `ahb_hprot[3:0]` | output | 当前为固定普通访问属性。 |
| `ahb_hsize[2:0]` | output | 当前生成 word 或 byte transfer。 |
| `ahb_htrans[1:0]` | output | 当前使用 `NONSEQ` 和 `IDLE`。 |
| `ahb_hwdata[31:0]` | output | 写数据。 |
| `ahb_hwrite` | output | 写访问标志。 |
| `ahb_hrdata[31:0]` | input | 读数据。 |
| `ahb_hready` | input | AHB wait-state/完成握手。 |
| `ahb_hresp[1:0]` | input | AHB response，`ERROR` 会回传为 core 侧 access fault。 |

当前 AHB 行为是 blocking、single outstanding。I-cache 和 D-cache 可能同时有请求时，由 `rv32i_ahb_master_bus` 做仲裁，D 侧优先。subword store 会根据 `wstrb` 拆成多个 AHB byte write。

## 5. 外部 SoC 需要提供什么

外部 SoC 或 bus fabric 至少需要提供：

- AHB-Lite decoder 或 matrix。
- boot ROM/flash，映射到 `RESET_PC` 指向的地址。
- SRAM 或数据存储区。
- 需要的 MMIO 外设，例如 timer、UART、GPIO。
- unmapped 地址的 default error response。
- 若使用 timer interrupt，需要把 timer 的中断输出连接到 `timer_irq`。

推荐在外部 SoC 中让 unmapped 访问返回 AHB `ERROR`，这样 CPU 可以触发 instruction/load/store access fault，而不是卡死在等待状态。

## 6. Debug 和性能输出

`rv32i_cached_ahb_master_top` 保留了一组调试和性能观测端口，方便仿真、论文数据和后续性能优化：

| 端口类别 | 信号 |
| --- | --- |
| PC/退休/停顿 | `dbg_pc`, `dbg_cycle`, `dbg_instret`, `dbg_stall_cycle`, `dbg_flush_cycle` |
| 分支预测 | `dbg_branch_count`, `dbg_branch_mispredict_count`, `dbg_btb_hit_count`, `dbg_btb_miss_count`, `dbg_bht_update_count` |
| 寄存器调试读 | `dbg_reg_addr`, `dbg_reg_rdata` |
| system 指令事件 | `dbg_illegal_instr`, `dbg_ecall`, `dbg_ebreak` |
| cache 统计 | `dbg_icache_hit_count`, `dbg_icache_miss_count`, `dbg_dcache_hit_count`, `dbg_dcache_miss_count` |
| bus 统计 | `dbg_bus_i_grant_count`, `dbg_bus_d_grant_count`, `dbg_bus_error` |

这些信号目前主要用于仿真和 bring-up，不建议直接作为软件可见寄存器接口。若后续需要软件读取性能计数器，可以再加 CSR 或 MMIO 形式的性能寄存器。

## 7. 当前支持能力

- RV32IM 指令子集。
- 五级流水线。
- forwarding、load-use stall、memory wait-state、branch/jump flush。
- 静态 fallback + 小型动态 BHT/BTB 分支预测。
- blocking 2-way I-cache。
- blocking 2-way D-cache，write-through，no-write-allocate，默认 MMIO uncached bypass。
- `mtvec`, `mepc`, `mcause`, `mstatus.MIE/MPIE`, `mie.MTIE`, `mip.MTIP`, `cycle`。
- `ecall`, `ebreak`, illegal instruction trap。
- instruction/load/store access fault。
- instruction/load/store misaligned address trap。
- machine timer interrupt。
- `mret`。
- AHB-Lite single outstanding master transaction。

## 8. 当前限制

- 不支持 compressed instruction。
- 不支持 privilege modes beyond machine mode。
- 不支持 MMU、virtual memory、page fault。
- 不支持 A extension/atomic memory operation。
- 不支持多个 outstanding transaction。
- 不生成 AHB burst。
- 不支持 cache coherence。
- 不包含完整 CLINT/PLIC 平台。
- `timer_irq` 默认按同步输入处理。
- I-cache/D-cache/cache bus 都是 blocking 设计，目标是清晰可验证，不是当前阶段的最高性能实现。

## 9. 集成检查清单

1. 选择 `rv32i_cached_ahb_master_top` 作为 CPU 子系统实例。
2. 确认 `RESET_PC` 与 boot memory 映射、linker script 一致。
3. 在外部接 AHB decoder/matrix。
4. 给 boot ROM/flash、SRAM、MMIO 外设分配地址。
5. 对 unmapped 地址返回 AHB `ERROR`。
6. 如果使用 timer interrupt，把外部 timer 中断连接到 `timer_irq`。
7. 根据目标容量调整 `ICACHE_INDEX_BITS`、`DCACHE_INDEX_BITS`、`BRANCH_PRED_INDEX_BITS`。
8. 先运行 `rv32i_cached_ahb_master_top_tb`，再运行 full regression。

## 10. 验证入口

CPU IP 交付边界测试：

```bash
cd sim
make sim TB_FILE=./testcases/rv32i_cached_ahb_master_top_tb.sv TOP_NAME=rv32i_cached_ahb_master_top_tb
```

推荐回归：

```bash
cd sim
bash ./regress/run_regression.sh --suite smoke --keep-going
bash ./regress/run_regression.sh --suite full --keep-going
```

如果需要重新生成软件镜像：

```bash
make -C software
```

Linux 回归机需要能找到 `riscv-none-elf-gcc` 和 `riscv-none-elf-objcopy`。如果机器上没有工具链，可使用仓库中已经生成的 `software/bin/*.memh` 直接运行普通仿真。

## 11. 最小连接示意

```text
rv32i_cached_ahb_master_top
  AHB-Lite master
    |
    v
external AHB decoder/matrix
  +-- boot ROM/flash
  +-- SRAM
  +-- AHB peripherals
  `-- AHB-to-APB bridge
        +-- timer
        `-- UART
```

当前仓库里的 `rv32i_ahb_matrix_soc_top` 和 `rv32i_ahb_matrix_apb_soc_top` 可以作为外部 SoC 集成示例，但 CPU IP 交付时优先交付 `rv32i_cached_ahb_master_top`。
