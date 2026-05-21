# AI Agent MCU + NPU SoC Roadmap

最后更新：2026-05-21

本文承接新的项目方向：从当前 RV32IM CPU / 小型 AHB SoC 原型，逐步演进为面向本地 AI Agent 推理的 RISC-V MCU + NPU SoC。

一句话定位：

```text
面向低功耗边缘 Agent 的 RISC-V MCU 控制核 + Transformer NPU + Agent 专用协处理簇。
```

## 1. 当前项目位置

当前仓库已经具备一个可继续演进的 CPU/SoC 基线：

- RV32IM 五级流水 CPU core。
- BHT/BTB 分支预测。
- machine-mode CSR/trap/timer interrupt。
- blocking I-cache / D-cache。
- AHB-Lite master CPU 子系统边界：`rv32i_cached_ahb_master_top`。
- AHB matrix + APB bridge SoC wrapper。
- timer / UART MMIO 外设。
- 汇编软件镜像构建流和自动化回归入口。
- Stage A4 质量检查入口。

这说明当前项目适合作为新 SoC 的 **控制面 CPU IP 起点**，但还不是完整 Agent MCU + NPU SoC。

## 2. 新路线目标

目标 SoC 面向 0.1B 到 1B 参数级别的小型 Transformer / Agent 模型，优先服务如下场景：

- 智能家居中控。
- 机器人控制。
- 穿戴式本地 Agent。
- 车载语音助手。
- 工业 HMI。

核心目标：

- 10 到 30 tokens/s 以上的可交互响应速度。
- W4A8 / W8A8 混合量化。
- 芯片级功耗小于 2W，常规 Agent 工作状态尽量落在数百 mW。
- 首版优先低成本 FPGA / MPW 验证路径。
- 软件和硬件围绕 Agent loop、tool call、KV cache、structured output 做协同设计。

## 3. 架构目标

目标系统由四个主要部分组成：

```text
RISC-V MCU
  RV32IMAC
  CLIC or low-latency interrupt path
  I-cache / D-cache
  Agent runtime / RTOS control plane

NPU
  systolic array
  local buffer
  DMA / tensor sequencer
  transformer operators: MMA, RMSNorm, RoPE, Softmax, activation

Agent Accelerator
  KV-cache manager
  token sampler
  grammar FSM
  tool-call detector
  embedding lookup / prompt cache helpers

SoC fabric
  SRAM pool
  flash / QSPI
  optional PSRAM / HyperRAM
  APB peripherals: timer, UART, I2C, SPI, I2S, PDM, DVP, GPIO, PWM
```

## 4. 与当前 RTL 的差距

当前项目能复用的部分：

- CPU 微架构和验证资产。
- AHB-Lite CPU 交付边界。
- cache / trap / timer / UART / APB 的基本 SoC 骨架。
- 软件镜像和回归脚本。
- 性能计数器思路。

需要新增或重构的部分：

- RV32IMAC：当前支持 RV32IM，不支持 compressed 和 atomics。
- User mode / RTOS 隔离：当前是 machine mode only。
- CLIC 或更低延迟中断：当前只有最小 machine timer interrupt。
- AXI4 或更宽 SoC fabric：当前是 blocking AHB-Lite，single outstanding。
- NPU RTL、DMA、local buffer、tensor sequencer。
- Agent Accelerator RTL。
- 大容量 SRAM/PSRAM/Flash 控制器模型。
- 真实软件 runtime：tokenizer、agent loop、ML graph executor、NPU driver。
- 模型量化和功能模拟器。

## 5. 推荐阶段

### Stage 0：保住 CPU IP 基线

目标：不要在切换大路线时破坏现有 CPU 子系统。

近期必须保持：

- `rv32i_cached_ahb_master_top` 作为稳定 CPU IP 边界。
- `smoke/core/cache/ahb/mmio/soc/isa/full` 回归继续可运行。
- 设计假设清楚标注：RV32IM、machine-only、blocking cache/bus、无 burst、无 outstanding。

### Stage 1：软件功能模型和 Agent workload baseline

目标：先在软件层面证明 Agent 推理 pipeline 可行，并形成 CPU-only 性能基线。

建议新增方向：

```text
software/asm/agent_event_loop.S
software/asm/agent_tool_dispatch.S
software/asm/agent_token_scan.S
software/asm/agent_int8_matvec.S
sim/testcases/rv32i_agent_workload_tb.sv
```

并行建立独立软件模型：

```text
model/
  npu_functional_sim/
  quant/
  microcode/
  agent_loop/
```

首版不追求周期级准确，先验证：

- INT8 matmul / matvec。
- RMSNorm / Softmax / RoPE。
- token sampling。
- tool-call token 检测。
- KV cache ring / sliding window 策略。

### Stage 2：Agent-oriented CPU 增强

目标：让控制核更适合 Agent runtime，而不是急着把 NPU 全部 RTL 化。

优先级：

- Return Address Stack。
- 更细 stall reason counter。
- JALR / indirect branch target cache。
- bitmanip 子集。
- atomics 或轻量同步原语。
- 更强中断控制路径，为 tool-call IRQ / NPU done IRQ 做准备。

每项优化都必须绑定 agent workload before/after 数据。

### Stage 3：最小 Agent Matrix / NPU 原型

目标：先做可验证小阵列，不直接跳到完整 32x32 NPU。

建议从 MMIO accelerator 起步：

```text
rv32i_agent_matrix_accel
  control/status registers
  src/dst/shape/stride registers
  int8 4x4 or 8x8 MAC array
  local scratchpad
  done/irq
```

验收标准：

- CPU 配置 accelerator。
- accelerator 从 SRAM 读写数据。
- polling 和 interrupt 两条完成路径。
- 与 CPU-only int8 matvec 对比性能。

### Stage 4：NPU 子系统

目标：扩展到 Transformer 友好的 NPU。

模块拆分：

- systolic array。
- tensor sequencer / microcode SRAM。
- activation engine。
- 2D DMA。
- local buffer。
- NPU register block。

首版建议先实现功能闭环，再提升规模：

```text
8x8 array -> 16x16 array -> 32x32 array
```

这样可以用同一套软件模型和测试向量递进验证。

### Stage 5：Agent Accelerator

目标：把 Agent 专用的 token-level 逻辑硬件化。

推荐顺序：

1. Tool-call detector：模式匹配成功后发 IRQ。
2. Token sampler：Top-K / Top-P 的硬件 baseline。
3. KV-cache manager：ring buffer + eviction + INT8/INT4 pack。
4. Grammar FSM：可配置 token mask 生成。
5. Embedding lookup / prompt cache helper。

这些模块都应优先做成 MMIO block，降低和 CPU pipeline 的耦合。

### Stage 6：SoC fabric 与存储体系升级

目标：从当前小 AHB SoC 升级到适合 NPU 的 SoC fabric。

迁移路径：

- 先保留 AHB CPU master，在 SoC 层通过 bridge 接入更宽 fabric。
- 新增 SRAM pool 模型和地址空间规划。
- 新增 NPU local buffer。
- 新增 QSPI flash / optional PSRAM 行为模型。
- 评估 AHB-Lite 是否够用；NPU/DMA 侧更可能需要 AXI4 或至少 burst-capable fabric。

### Stage 7：FPGA demo

目标：形成可展示系统。

最小 demo：

```text
boot
UART banner
agent workload baseline
NPU/MMIO accelerator run
tool-call IRQ
performance counter print
```

后续 demo：

- tiny intent classifier。
- tiny retrieval scorer。
- voice command front-end stub。
- structured output / function-call parser。

## 6. 近期执行建议

近期不要直接开完整 32x32 NPU RTL。更稳的顺序是：

1. 保持当前 CPU IP 回归稳定。
2. 建立 `agent_event_loop`、`agent_token_scan`、`agent_int8_matvec` 的 CPU-only baseline。
3. 建立 NPU / Agent Accelerator 的软件功能模型和测试向量。
4. 做第一个 MMIO matrix accelerator 原型。
5. 再根据 benchmark 数据决定 CPU custom ISA、NPU 阵列规模和 SoC fabric 升级。

这条路径能让每一阶段都有可运行软件、可验证 RTL 和可展示数据，而不是把项目一次性推到不可收敛的大 SoC 状态。

## 7. 架构风险

关键风险：

- 片上 SRAM 远小于 0.2B 到 1B 模型的真实 KV/cache/weight 需求。
- Flash/PSRAM 带宽可能比 NPU 峰值算力更早成为瓶颈。
- 完整 AXI4 + NPU + DMA + cache coherency 对当前项目跨度较大。
- RV32IMAC / CLIC / U-mode / atomics 同时推进会稀释验证精力。
- 32x32 systolic array 对 FPGA 资源和时序压力较大。

缓解策略：

- 先用功能模型和小阵列验证数据流。
- 先做 MMIO accelerator，减少 CPU pipeline 改动。
- 地址空间和寄存器接口先文档化，再写 RTL。
- 每个新增硬件模块都配 directed test 和软件镜像。
- 性能目标用 benchmark 逐步收敛，不直接承诺峰值 token/s。
