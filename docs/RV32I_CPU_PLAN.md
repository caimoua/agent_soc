# RV32I CPU 迭代计划

## 阶段 0：项目骨架

交付内容：

- 稳定的目录结构
- VCS 仿真入口
- 可编译的 core 基线
- 基础 testbench

状态：已完成第一版。

## 阶段 1：单周期 RV32I Core

当前状态：

- 已实现单周期取指、译码、寄存器读取、ALU 执行、branch/jump PC 更新、简单 data memory 访问和写回。
- directed simulation 已覆盖算术/逻辑指令、U-type、JAL/JALR、branch、byte/halfword/word 级 load/store，以及最小 SYSTEM/CSR 路径。

目标指令：

- `addi`、`add`、`sub`
- `and`、`or`、`xor`
- `sll`、`srl`、`sra`
- `lb`、`lh`、`lw`、`lbu`、`lhu`
- `sb`、`sh`、`sw`
- `beq`、`bne`、`blt`、`bge`、`bltu`、`bgeu`
- `jal`、`jalr`
- `lui`、`auipc`
- `csrrs rd, cycle, x0`、`ecall`、`ebreak` 的最小实现

核心模块：

- PC 更新逻辑
- 指令译码器
- 立即数生成器
- 寄存器堆
- ALU
- load/store 单元
- 最小 CSR 读路径
- 写回选择 mux

验证方式：

- directed assembly 测试
- 波形检查
- testbench 中的寄存器和 memory 自检查

当前 directed test 覆盖示例：

```asm
addi x1, x0, 5
addi x2, x0, 7
add  x3, x1, x2
sub  x4, x3, x1
...
beq  x1, x1, target
bne  x1, x2, target
sw   x24, 4(x0)
lw   x24, 4(x0)
sb   x29, 8(x0)
lb   x30, 8(x0)
lbu  x31, 11(x0)
sh   x29, 14(x0)
lh   x29, 14(x0)
lhu  x24, 14(x0)
sw   x25, 16(x0)
csrrs x25, cycle, x0
ecall
ebreak
```

期望结果：

```text
branch_score(x24) = 63
dmem[1] = 0x12345678
load_x24 = 0x12345678
dmem[2] = 0xff0000ff
dmem[3] = 0xffff0000
lb/lbu/lh/lhu sign-extension and zero-extension checks pass
cycle_csr(x25) is non-zero
ecall_pc = 0x00000124
ebreak_pc = 0x00000128
```

最小 SYSTEM/CSR 路径的详细说明见 `docs/SYSTEM_CSR_MINIMAL.md`。

## 阶段 2：五级流水线

当前状态：

- 已新增 `rtl/core/rv32i_pipe_core.v`，保留单周期 `rv32i_core.v` 作为 baseline。
- 已新增 `sim/testcases/rv32i_pipe_core_tb.sv`，用于验证流水线 forwarding、load-use stall、指令/数据存储器等待停顿、branch/jump flush 和 debug 性能计数器。
- 第一版流水线已经具备 IF/ID、ID/EX、EX/MEM、MEM/WB 四组流水寄存器。
- EX/MEM 和 MEM/WB 到 EX 阶段的 forwarding 已加入。
- load-use stall、指令/数据存储器等待停顿、branch/jump flush 已加入。
- 已加入 `instret/stall_cycle/flush_cycle` debug 性能计数器。

流水线结构：

```text
IF -> ID -> EX -> MEM -> WB
```

关键逻辑：

- IF/ID、ID/EX、EX/MEM、MEM/WB 流水线寄存器
- EX/MEM 和 MEM/WB 到前级的 forwarding
- load-use stall
- 指令/数据存储器等待停顿
- branch/jump flush
- valid/kill bit

性能计数器：

- cycle count
- retired instruction count
- stall count
- flush count
- branch count（后续可选）
- taken branch count（后续可选）

第一版流水线说明见 `docs/RV32I_PIPELINE_CORE.md`。

## 阶段 3：最小 Trap/CSR 机制

当前状态：

- 已新建设计文档 `docs/RV32I_TRAP_CSR.md`。
- 已在 `rtl/core/rv32i_pipe_core.v` 中完成第一版最小 trap/CSR RTL。
- `ecall/ebreak/illegal_instr` 已从 debug 事件升级为真正的 trap redirect。
- trap 已放到 MEM/WB commit 阶段处理，保证 precise exception。
- 已新增 `sim/testcases/rv32i_trap_csr_tb.sv`，并通过 directed simulation。

本阶段目标：

- 新增 `mtvec/mepc/mcause` 三个 machine CSR。
- 支持 `ecall`、`ebreak`、非法指令进入 trap。
- 支持 `mret` 从 trap handler 返回。
- 支持最小 `csrrw/csrrs` CSR 读写路径。
- trap/mret 发生时 flush 年轻指令。
- trap 优先于 memory stall、EX branch/jump redirect 和 load-use stall。

关键概念：

- precise exception
- commit 阶段架构状态更新
- trap handler
- CSR read/write side effect
- younger instruction flush

详细说明见 `docs/RV32I_TRAP_CSR.md`。

已通过的 directed simulation：

```text
[PASS] rv32i_trap_csr_tb
  pc=0x00000140 cycle=49 instret=28
  stall_cycle=0 flush_cycle=0
  ecall: mcause=11 mepc=0x0000000c pre_store=0x00000000
  illegal: mcause=2 mepc=0x00000018 pre_store=0x00000063
  mret resumed main after ECALL and illegal traps
```

原流水线回归也通过：

```text
[PASS] rv32i_pipe_core_tb
  pc=0x00000100 cycle=57 instret=33
  stall_cycle=14 flush_cycle=3
  forwarding, load-use stall, instruction/data memory wait-state, control flush and perf counters passed
```

## 阶段 4：微架构扩展

优先选择其中两个方向：

- 简单分支预测器
- I-cache
- D-cache
- AHB-lite 或 AXI-lite 接口
- interrupt 和最小 CSR 路径
- RV32M 乘除法扩展

当前已经开始阶段 4 的第一步：新增 `rtl/mem/rv32i_icache.v`，实现一个 blocking 2-way set associative I-cache。当前每条 cache line 保存 4 个 32-bit word，支持 tag/index/valid、双 way tag compare、hit、miss、4-word refill 和简单 replacement bit。tag/data 存储已经改成通过 `rtl/mem/rv32i_sram_1r1w.v` 仿真模型访问，为以后替换 SRAM macro 留出边界。说明文档见 `docs/RV32I_ICACHE.md`，独立 directed testbench 为 `sim/testcases/rv32i_icache_tb.sv`，流水线接入 I-cache 的集成 testbench 为 `sim/testcases/rv32i_pipe_icache_tb.sv`。

后续 I-cache 方向继续演进：

1. 给 I-cache 增加 flush/invalidate 控制。
2. 增加 instruction TCM 或 bus wrapper。
3. 进一步考虑简单 prefetch。
4. 再考虑 D-cache 或更完整的总线协议。

当前已经继续开始 D-cache：新增 `rtl/mem/rv32i_dcache.v`，采用 blocking 2-way set associative、4-word line、SRAM-style tag/data 存储。data SRAM 已经使用 byte write mask，store hit 时由 `cpu_wstrb` 扩展成 cache line 级写掩码，更接近真实 SRAM macro 的使用方式。第一版写策略选择 `write-through + no-write-allocate`：load miss 会 refill 整条 line；store hit 会更新 cache 并写穿后端 memory；store miss 不分配 line，直接写后端 memory。说明文档见 `docs/RV32I_DCACHE.md`，独立 directed testbench 为 `sim/testcases/rv32i_dcache_tb.sv`，流水线接入 D-cache 的集成 testbench 为 `sim/testcases/rv32i_pipe_dcache_tb.sv`。

当前已经开始搭建内部 memory bus：新增 `rtl/bus/rv32i_mem_bus.v`，采用 blocking、单 outstanding、D-cache 优先的仲裁方式，把 I-cache/D-cache 两个 master 统一接到 ROM/SRAM/MMIO 三类 slave。默认地址映射为 `0x0000_0000` ROM、`0x2000_0000` SRAM、`0x4000_0000` MMIO。说明文档见 `docs/RV32I_MEM_BUS.md`，独立 directed testbench 为 `sim/testcases/rv32i_mem_bus_tb.sv`，pipeline+I-cache+D-cache+bus 集成 testbench 为 `sim/testcases/rv32i_pipe_cached_bus_tb.sv`。

当前已经新增 cached system top：`rtl/top/rv32i_cached_system_top.v`，把 `rv32i_pipe_core`、`rv32i_icache`、`rv32i_dcache` 和 `rv32i_mem_bus` 固化成正式顶层 wrapper。顶层对外暴露 ROM/SRAM/MMIO 三类接口，便于后续替换成真实 memory wrapper、MMIO 外设或 AHB/AXI adapter。说明文档见 `docs/RV32I_CACHED_SYSTEM_TOP.md`，顶层集成 testbench 为 `sim/testcases/rv32i_cached_system_top_tb.sv`。

当前已经新增最小 MMIO timer：`rtl/periph/rv32i_timer.v`，支持 `mtime/mtimecmp/ctrl` 寄存器和 `timer_irq` 输出。D-cache 已增加默认 `0x4000_0000` uncached bypass，避免 MMIO load 被缓存。`timer_irq` 已经接入 pipeline trap/CSR，CSR 侧新增最小 `mstatus/mie/mip`，可触发 machine timer interrupt 并通过 `mret` 返回。说明文档见 `docs/RV32I_TIMER.md`，独立 testbench 为 `sim/testcases/rv32i_timer_tb.sv`，MMIO 访问集成 testbench 为 `sim/testcases/rv32i_cached_timer_tb.sv`，timer interrupt 集成 testbench 为 `sim/testcases/rv32i_cached_timer_irq_tb.sv`。

D 侧 bus decode error 已接入 pipeline trap/CSR：unmapped load/store 会形成 precise load/store access fault，`mcause` 分别为 5/7，handler 可修改 `mepc` 后 `mret` 返回。验证入口为 `sim/testcases/rv32i_cached_access_fault_tb.sv`。

I 侧 bus decode error 也已接入 pipeline trap/CSR：unmapped instruction fetch 会形成 precise instruction access fault，`mcause=1`，handler 可修改 `mepc` 后 `mret` 返回。验证入口为 `sim/testcases/rv32i_cached_instr_access_fault_tb.sv`。

当前已经新增最小 TX-only UART MMIO：`rtl/periph/rv32i_uart.v`，并新增 `rtl/periph/rv32i_mmio_periph_mux.v`，把 `0x4000_0000` 分给 timer、`0x4000_1000` 分给 UART。说明文档见 `docs/RV32I_UART.md`，独立 testbench 为 `sim/testcases/rv32i_uart_tb.sv`，cached system 集成 testbench 为 `sim/testcases/rv32i_cached_uart_tb.sv`。这两个 UART testbench 已经通过 VCS。

当前已经新增第一版 AHB-Lite 总线路径：`rtl/bus/rv32i_simple_to_ahb.v`、`rtl/bus/rv32i_ahb_to_simple.v`、`rtl/bus/rv32i_ahb_lite_decoder.v`、`rtl/bus/rv32i_mem_bus_ahb.v`，并新增 `rtl/top/rv32i_cached_system_ahb_top.v`。说明文档见 `docs/RV32I_AHB.md`，独立 testbench 为 `sim/testcases/rv32i_mem_bus_ahb_tb.sv`，cached system 集成 testbench 为 `sim/testcases/rv32i_cached_system_ahb_top_tb.sv`。这两个 AHB testbench 已由用户在 VCS 上确认 PASS。

进一步新增 `rtl/bus/rv32i_ahb_master_bus.v` 和 `rtl/top/rv32i_cached_ahb_master_top.v`，把 CPU subsystem 边界调整为对外暴露单个 AHB-Lite master 接口。`sim/testcases/rv32i_cached_ahb_master_top_tb.sv` 把 AHB decoder 和 ROM/SRAM/MMIO slave 放在 DUT 外部，用来验证更标准的 SoC 集成方式。该 testbench 已由用户在 VCS 上确认 PASS。

## 阶段 5：面试材料整理

输出材料：

- CPU block diagram
- pipeline timing 示例
- hazard table
- CPI 测量表
- regression summary
- 波形截图
- 精简 README
