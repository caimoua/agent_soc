# Agent SoC Architecture v0

最后更新：2026-05-22

本文把新仓库的第一版可执行方案固定下来。它不是最终芯片规格，而是把长期的 AI Agent MCU + NPU SoC 目标收敛成可以开始写软件、RTL 和测试的 v0 架构。

## 1. 定位

v0 的目标是先建立一条可测量、可回归、可逐步加速的 Agent SoC 路径：

```text
当前 RV32IM CPU / AHB-Lite SoC
  -> Agent workload baseline
  -> MMIO matrix accelerator
  -> Tool-call detector
  -> 更完整的 NPU / Agent Accelerator
```

当前仓库不直接跳到完整 32x32 NPU、AXI4 crossbar、PSRAM、CLIC 和 RV32IMAC。v0 先用最小硬件闭环把软件、MMIO、性能计数、测试方法建立起来。

## 2. v0 原则

- 保留 `rv32i_cached_ahb_master_top` 作为稳定 CPU IP 边界。
- 第一阶段以 CPU-only workload 为准，先知道瓶颈在哪里。
- 第一个加速器采用 MMIO block，尽量不改 CPU pipeline。
- 第一版 SoC fabric 保持 AHB-Lite + APB，等 DMA/NPU 需求明确后再升级。
- 每个新增模块都需要软件镜像、testbench、回归入口和性能记录。
- 所有“性能提升”都必须绑定 before/after 数据，而不是只描述新增功能。

## 3. 系统基线

当前可复用基线：

```text
rv32i_ahb_matrix_apb_soc_top
  rv32i_cached_ahb_master_top
    rv32i_pipe_core
    rv32i_icache
    rv32i_dcache
    rv32i_ahb_master_bus
  rv32i_ahb_lite_matrix_1m4s
  rv32i_ahb_to_apb
  rv32i_apb_periph_mux
    rv32i_timer
    rv32i_uart
    rv32i_agent_matrix_accel
    rv32i_tool_call_detector
    rv32i_agent_event_counter
  rv32i_agent_irq_aggregator
```

v0 新增模块优先挂在 APB 外设空间，避免一开始就重构总线。

## 4. v0 地址空间

当前地址空间保持不变：

| 地址范围 | 用途 | 当前状态 |
| --- | --- | --- |
| `0x0800_0000` | flash / boot image | 已有 |
| `0x2000_0000` | SRAM | 已有 |
| `0x4000_0000` | AHB peripheral slot | 已有 |
| `0x4200_0000` | APB timer | 已有 |
| `0x4200_1000` | APB UART | 已有 |

v0 预留新增 APB 外设：

| 地址范围 | 用途 | 目标阶段 |
| --- | --- | --- |
| `0x4200_2000` | Agent Matrix Accelerator | v0.2a/v0.2b 已接入并由 VCS 确认 |
| `0x4200_3000` | Tool-call Detector | v0.3 已接入并由 VCS 确认 |
| `0x4200_4000` | Agent Event Counter | v0.5 已接入并由 VCS 确认 |

长期 SoC 目标中的 `0xE000_0000` NPU 控制空间和 `0xF000_0000` Agent Accelerator 控制空间暂时只保留在北极星路线里，v0 不急着切换到该地址图。

## 5. v0.1：Agent Workload Baseline

v0.1 的任务是回答一个问题：

```text
当前 RV32IM CPU 跑 agent 控制流、token 扫描和 int8 baseline 到底慢在哪里？
```

### 5.1 软件工作负载

建议新增汇编软件镜像：

```text
software/asm/agent_workload.S
software/bin/agent_workload.memh
```

第一版先把多个 routine 放在同一个 `agent_workload.S`，便于一个 testbench 统一输出性能计数。后续如果文件过大，再拆成：

```text
software/asm/agent_event_loop.S
software/asm/agent_tool_dispatch.S
software/asm/agent_token_scan.S
software/asm/agent_int8_matvec.S
```

### 5.2 workload 定义

`agent_event_loop`

- 模拟一个固定长度 task queue。
- 每个 task 包含 `type`, `arg0`, `arg1`, `state`。
- CPU 循环取 task、dispatch、更新状态、写回结果。
- 重点测分支、load/store、队列访问和状态机开销。

`agent_tool_dispatch`

- 使用 jump table 或 branch chain 模拟工具分发。
- 工具类型建议先固定 4 类：`none`, `gpio`, `timer`, `uart`。
- 重点测间接跳转或多分支 dispatch 的预测效果。

`agent_token_scan`

- 在 token buffer 中查找特殊 token 序列。
- 第一版模式可以是 4 个 16-bit token：`<tool_call>` 的抽象 ID 序列。
- 重点测顺序扫描、短模式匹配、分支和 load stall。

`agent_int8_matvec`

- CPU-only INT8 dot / matvec baseline。
- 第一版建议固定维度：`16x16` 或 `32x16`。
- 输入为 int8，累加为 int32，结果写回 SRAM。
- 重点测 RV32IM 标量实现的计算成本，为 v0.2 加速器提供对照。

### 5.3 testbench

建议新增：

```text
sim/testcases/rv32i_agent_workload_tb.sv
```

该 testbench 基于现有 cached/AHB top 的风格，加载 `software/bin/agent_workload.memh`，运行完成后输出：

```text
cycle
instret
stall_cycle
flush_cycle
branch_count
branch_mispredict_count
btb_hit_count
btb_miss_count
bht_update_count
icache_hit/miss
dcache_hit/miss
bus grant / decode error
```

### 5.4 v0.1 验收标准

- `agent_workload.S` 能稳定构建成 `.memh`。
- `rv32i_agent_workload_tb.sv` 能跑完并检测 PASS 标志。
- 回归脚本新增 `agent` suite。
- 文档记录第一组性能数据。
- 不改动 CPU pipeline 的功能逻辑。

### 5.5 v0.1 首次基线结果

2026-05-21，用户在 VCS 环境确认 `rv32i_agent_workload_tb` PASS：

| 指标 | 数值 |
| --- | --- |
| `cycle` | 413 |
| `instret` | 331 |
| `stall_cycle` | 42 |
| `flush_cycle` | 18 |
| `branch_count` | 47 |
| `branch_mispredict_count` | 18 |
| `btb_hit_count` | 25 |
| `btb_miss_count` | 22 |
| `bht_update_count` | 47 |

覆盖的 CPU-only workload：

- agent event loop。
- tool dispatch。
- token pattern scan。
- INT8 dot product。
- tiny INT8 matvec。

这组数据作为 v0.2 matrix accelerator 的第一版对照基线。

## 6. v0.2：Agent Matrix Accelerator

v0.2 的任务是做第一个最小 AI 加速闭环，而不是追求最终 NPU 性能。

推荐模块名：

```text
rv32i_agent_matrix_accel
```

### 6.1 第一版规模

第一版使用 `4x4` INT8 MAC 单元：

- 输入：signed int8。
- 累加：signed int32。
- 输出：int32 或右移裁剪后的 int8。
- 固定小矩阵先跑通，后续再扩成 `8x8`。

### 6.2 集成方式

v0.2 分两步：

```text
v0.2a: APB register + scratchpad path
  CPU 通过 APB 写入小块输入数据
  accelerator 在内部 scratchpad 计算
  CPU polling done bit

v0.2b: SRAM read/write path
  CPU 配置 src/dst/shape/stride
  accelerator 读写 SRAM
  done/irq 通知 CPU
```

v0.2a 更适合作为第一块 RTL，因为当前 SoC 只有一个 CPU AHB master。v0.2b 需要引入第二 master 或 DMA/bridge 能力，风险更高，可以在 v0.2a 通过后展开。

### 6.3 寄存器草案

Base：`0x4200_2000`

| Offset | Name | 描述 |
| --- | --- | --- |
| `0x00` | `CTRL` | bit0 start, bit1 irq_en, bit2 clear |
| `0x04` | `STATUS` | bit0 busy, bit1 done, bit2 irq_pending, bit3 error |
| `0x08` | `SRC_A` | v0.2b SRAM source A base |
| `0x0c` | `SRC_B` | v0.2b SRAM source B base |
| `0x10` | `DST` | v0.2b SRAM destination base |
| `0x14` | `SHAPE` | `[7:0] M`, `[15:8] N`, `[23:16] K` |
| `0x18` | `STRIDE_A` | v0.2b source A stride |
| `0x1c` | `STRIDE_B` | v0.2b source B stride |
| `0x20` | `STRIDE_D` | v0.2b destination stride |
| `0x24` | `FLAGS` | signed/unsigned, output shift, clamp enable |
| `0x28` | `IRQ_STATUS` | done irq pending |
| `0x2c` | `IRQ_CLEAR` | write 1 to clear |
| `0x100` | `SCRATCH_A` | v0.2a matrix A scratchpad window |
| `0x140` | `SCRATCH_B` | v0.2a vector B scratchpad window |
| `0x180` | `RESULT` | v0.2a int32 result window |

### 6.4 当前 v0.2 实现

当前代码已经落地 APB scratchpad 版本和 SRAM-mode 版本：

```text
rtl/accel/rv32i_agent_matrix_accel.v
rtl/bus/rv32i_ahb_lite_matrix_2m4s.v
software/asm/agent_matrix_accel.S
software/bin/agent_matrix_accel.memh
software/asm/agent_matrix_accel_sram.S
software/bin/agent_matrix_accel_sram.memh
sim/testcases/rv32i_agent_matrix_accel_soc_tb.sv
sim/testcases/rv32i_agent_matrix_accel_sram_soc_tb.sv
```

集成路径：

```text
rv32i_ahb_matrix_apb_soc_top
  -> rv32i_ahb_to_apb
    -> rv32i_apb_periph_mux
      -> rv32i_agent_matrix_accel @ 0x4200_2000
        -> rv32i_simple_to_ahb
          -> rv32i_ahb_lite_matrix_2m4s M1
```

第一版固定计算：

```text
4x4 signed int8 matrix * 4x1 signed int8 vector -> 4x1 signed int32 result
```

软件 smoke 程序会写入 4 行 matrix 和 1 个 vector，启动 accelerator，polling `STATUS.done`，检查 4 个结果和 checksum，然后测试 `IRQ_STATUS/IRQ_CLEAR`。scratchpad test 只通过 APB window 搬数据；SRAM-mode test 由 CPU 写 SRAM input，再由 accelerator 作为第二 AHB master 读 SRAM、写 SRAM result。用户已通过 `agent` regression 确认这两个 SoC tests PASS。

### 6.5 v0.2 验收标准

- CPU 能通过 MMIO 启动一次 matrix / matvec 计算。
- testbench 能比较硬件结果和软件 golden result。
- polling done path 必须通过。
- IRQ path 可以作为 v0.2b 或 v0.3 验收项。
- 输出 CPU-only 和 accelerator 两组 cycle 对比。

## 7. v0.3：Tool-call Detector

v0.3 的任务是做第一个真正带 Agent 特征的硬件块。

推荐模块名：

```text
rv32i_tool_call_detector
```

### 7.1 功能

- CPU 配置 token pattern。
- CPU 或后续 sampler 将 token 逐个写入 `TOKEN_IN`。
- detector 维护匹配状态。
- pattern 命中后置位 `MATCH`，可选发 IRQ。

### 7.2 寄存器草案

Base：`0x4200_3000`

| Offset | Name | 描述 |
| --- | --- | --- |
| `0x00` | `CTRL` | enable, clear, irq_en |
| `0x04` | `STATUS` | active, match, overflow |
| `0x08` | `PATTERN_LEN` | 1 到 8 token |
| `0x0c` | `TOKEN_IN` | 写入一个 token 并推进 FSM |
| `0x10` | `MATCH_COUNT` | 命中次数 |
| `0x20` | `PATTERN0` | token 0/1 packed |
| `0x24` | `PATTERN1` | token 2/3 packed |
| `0x28` | `PATTERN2` | token 4/5 packed |
| `0x2c` | `PATTERN3` | token 6/7 packed |

### 7.3 v0.3 验收标准

- CPU-only token scan 与 hardware detector 有同一组输入 token。
- detector 命中位置与软件 golden 一致。
- polling path 通过。
- irq path 通过后，接入 timer IRQ 之外的第二类外设中断设计讨论。

### 7.4 当前 v0.3 实现

当前代码已经落地 Tool-call Detector polling 路径：

```text
rtl/accel/rv32i_tool_call_detector.v
software/asm/tool_call_detector.S
software/bin/tool_call_detector.memh
sim/testcases/rv32i_tool_call_detector_soc_tb.sv
```

用户已通过 `agent` regression 确认 polling/IRQ pending/IRQ clear directed test PASS。

## 8. v0.4：Agent IRQ Aggregator

v0.4 的任务是先把 Agent 外设的 IRQ 接入 CPU trap/interrupt 闭环，不在这一轮重构 CSR 为完整 MEI/PLIC/CLIC。

当前 CPU 只实现 MTIP/MTIE，因此 v0.4 使用过渡式聚合：

```text
timer_irq | agent_matrix_irq | tool_call_irq -> cpu_timer_irq -> CPU MTIP
```

CPU handler 看到的 `mcause` 仍是：

```text
0x80000007
```

真实来源由 handler 读取外设 `IRQ_STATUS` 判断。这个方案让 tool-call 命中可以立刻打断 CPU 主循环，同时保留后续升级独立 external interrupt / CLIC 的空间。

### 8.1 当前 v0.4 实现

```text
rtl/accel/rv32i_agent_irq_aggregator.v
software/asm/tool_call_detector_irq.S
software/bin/tool_call_detector_irq.memh
sim/testcases/rv32i_tool_call_detector_irq_soc_tb.sv
docs/architecture/AGENT_IRQ_AGGREGATOR.md
```

`rv32i_ahb_matrix_apb_soc_top` 新增输出：

```text
cpu_timer_irq
dbg_agent_irq_status
```

### 8.2 v0.4 验收标准

- Tool-call Detector 命中后 `tool_call_irq` 拉高。
- IRQ aggregator 拉高 `cpu_timer_irq`。
- CPU 进入 handler，`mcause=0x80000007`，`mip.MTIP=1`。
- handler 读取 Tool-call Detector `IRQ_STATUS=1`，清 pending 后 `tool_call_irq/cpu_timer_irq` 归零。
- `mret` 返回主程序并到达 PASS 标志。

当前状态：directed test 已接入 `agent` suite，并已由用户通过 VCS 确认 PASS，日志目录为 `/home2/kairos18/workspace/ai_agent_mcu_npu_soc/sim/log/regress/20260522_095831-agent`。

## 9. v0.5：Agent Event Counter

v0.5 的任务是给当前 demo 链路加硬件观测面。它记录 Tool-call Detector、Matrix Accelerator 和 IRQ aggregator 的关键事件，让后续整理 SoC 骨架和推进 NPU 功能模型时有可读计数。

当前实现：

```text
rtl/accel/rv32i_agent_event_counter.v
software/asm/agent_event_counter.S
software/bin/agent_event_counter.memh
sim/testcases/rv32i_agent_event_counter_soc_tb.sv
docs/architecture/AGENT_EVENT_COUNTER.md
```

APB window：

```text
0x4200_4000
```

第一版计数：

- Tool token / match / IRQ count。
- Matrix start / done / IRQ count。
- Aggregated CPU IRQ count。
- Last IRQ source。
- Tool match 到 IRQ clear 的 latency last/min/max/count。

当前状态：directed test 已接入 `agent` suite，并已由用户通过 VCS 确认 PASS，日志目录为 `/home2/kairos18/workspace/ai_agent_mcu_npu_soc/sim/log/regress/20260522_102533-agent`。

## 10. 结构整理方向

v0.5 PASS 后，当前仓库需要从 demo 形态整理为骨架形态。整理目标不是重写逻辑，而是把边界命名和目录职责固定下来：

```text
CPU subsystem
SoC fabric
Agent peripheral cluster
Software smoke programs
Verification suites
Docs/status handoff
```

短期要做：

- 明确 `rv32i_ahb_matrix_apb_soc_top` 是 demo top 还是 v0 SoC top：v0.6 先把它定义为 v0 SoC demo top，Agent 叶子模块通过 `rv32i_agent_periph_cluster` 收束。
- 把 Agent peripheral 的 APB map 单独成文：第一版见 `docs/architecture/AGENT_PERIPH_CLUSTER.md`。
- 把 demo software 与后续 runtime/driver 目录分开。
- 把 directed tests 按 CPU / SoC / Agent peripheral 分组。
- 为下一阶段 NPU functional model 预留 `model/` 和 golden vector 入口。

v0.6 第一刀：

```text
rtl/agent/rv32i_agent_periph_cluster.v
filelist/cpu_filelist/agent_rtl.f
docs/architecture/AGENT_PERIPH_CLUSTER.md
```

状态：结构整理已完成，并已由用户通过 `agent` regression 确认 PASS，日志目录为 `/home2/kairos18/workspace/ai_agent_mcu_npu_soc/sim/log/regress/20260522_105035-agent`。

## 11. 功能模型目录

v0.1 开始建议新增：

```text
model/
  README.md
  agent_loop/
  npu_functional_sim/
  tests/
```

第一版功能模型不要求周期准确，只需要产出 RTL testbench 可复用的输入/输出向量。

推荐先覆盖：

- int8 dot / matvec golden。
- token pattern scan golden。
- 简化 KV ring buffer 地址生成。
- 后续再扩 RMSNorm / Softmax / RoPE。

## 12. 回归和文档

新增测试在用户用 VCS 确认前，`docs/status/VERIFICATION_MATRIX.md` 只能标记为 `PENDING`。

推荐新增 suite：

```text
agent
```

第一批测试：

```text
rv32i_agent_workload_tb
rv32i_agent_matrix_accel_tb
rv32i_tool_call_detector_tb
```

其中后两个等 RTL 存在后再加入。

## 13. 近期执行顺序

第一步：

```text
docs/roadmap/AGENT_SOC_ARCH_V0.md
```

第二步：

```text
software/asm/agent_workload.S
software/bin/agent_workload.memh
sim/testcases/rv32i_agent_workload_tb.sv
```

第三步：

```text
sim/regress/regression_list.txt 增加 agent suite
docs/status/VERIFICATION_MATRIX.md 标记 PENDING
docs/status/PROJECT_STATUS.md 记录 v0.1 进展
```

第四步：

```text
model/agent_loop 或 model/npu_functional_sim 建立 golden vectors
```

第五步：

```text
rv32i_agent_matrix_accel APB scratchpad 版本
```

这样我们会先有 CPU baseline，再有硬件加速对照，项目节奏比较稳。
