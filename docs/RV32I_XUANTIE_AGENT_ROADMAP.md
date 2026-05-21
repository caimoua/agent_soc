# 面向 Agent 的玄铁式 CPU 路线分析

最后更新：2026-05-21

本文用于重新定义本项目后续方向：不再只把目标停留在“做一个能跑的 RISC-V 教学核”，而是把当前 CPU IP 继续推进为一个**面向本地 agent runtime 的轻量级 RISC-V 处理器子系统**。

一句话定位：

```text
面向边缘 AI agent 调度、工具调用和轻量推理控制流的 RISC-V Agent Core。
```

它不是直接复刻玄铁 C907/C908/C910，而是学习玄铁的产品路线：处理器 IP 产品化、AIoT 场景增强、软硬协同、性能可度量。

## 1. 玄铁路线观察

平头哥官网把玄铁处理器 IP 定位为“智能、安全、端云一体芯片架构的基石”，应用覆盖计算视觉、数据存储、工业互联、网络通信、智能家居、生物识别和信息安全等领域；公开页面还提到玄铁处理器 IP 累计授权芯片出货超过 30 亿颗。

公开资料里，玄铁路线有几个明显特点：

- **IP 家族化**：不是只做一个 CPU，而是围绕不同场景形成 E/C/R 等不同处理器系列。
- **AIoT 场景增强**：C908 这类面向 AIoT 的核强调高效流水线、分支预测、预取、向量/点积和 INT4 等 AI 相关能力。
- **矩阵扩展方向**：C907 相关资料提到 XuanTie Matrix Extension / MME，把矩阵计算从普通向量计算中解耦出来，使用独立矩阵寄存器和矩阵计算单元。
- **软硬件全栈**：玄铁不是只给 RTL，还强调工具链、神经网络部署工具、性能分析、调试和软件库。
- **可产品化交付**：文档、接口、调试、验证、benchmark 和生态比单个 RTL 模块更重要。

可参考资料：

- 平头哥产品概览：https://www.t-head.cn/product/overview
- XuanTie C908 AIoT 处理器介绍：https://riscv.org/blog/xuantie-c908-high-performance-risc-v-processor-catered-to-aiot-industry-chang-liu-alibaba-cloud/
- XuanTie Matrix Multiply Extension：https://riscv.org/blog/xuantie-matrix-multiply-extension-instructions/
- XuanTie C907 with Matrix Extension：https://riscv.org/blog/enhancing-the-future-of-ai-ml-with-attached-matrix-extension/

## 2. 我们不应该直接做什么

短期不建议直接做：

- 完整 RVV。
- 完整 Matrix ISA。
- 多核 cache coherency。
- Linux-capable RV64GC + MMU。
- 乱序、多发射、高频深流水。

这些方向当然更接近高端玄铁产品，但跨度太大，会把当前项目拖进长期不可验证状态。

更现实的路线是：

```text
先做一个可观测、可验证、可调度 agent workload 的 RV32IM Agent Core，
再逐步加入 agent runtime 需要的微架构增强和小型 AI 加速能力。
```

## 3. Agent workload 对 CPU 的真实要求

这里的 agent 不是单纯“大矩阵乘法”。大矩阵乘法最终应该交给 NPU / Matrix Engine。CPU 的关键价值在于 agent runtime 的控制面：

```text
任务调度
事件循环
工具调用
中断和定时器
消息队列
内存对象和状态机
token / 字符串 / JSON 解析
小模型推理的控制流
NPU/DMA 配置和同步
```

这些 workload 有几个特点：

- **分支密集**：状态机、if/else、函数调用、间接跳转多。
- **小粒度任务多**：agent 会频繁在 plan、act、observe、tool result 之间切换。
- **内存访问不规则**：队列、链表、hash table、token buffer、KV metadata 容易造成 cache miss。
- **I/O 和中断敏感**：工具调用、串口/网络/传感器事件会要求低延迟响应。
- **算子和调度混合**：既有 int8 dot/matvec 这类计算，也有大量控制流 glue code。

因此，面向 agent 的 CPU 不应该只追求一个峰值 TOPS，而应该同时重视：

- branch prediction 和 return address stack。
- 低延迟 interrupt / timer。
- 快速上下文切换。
- 队列/锁/原子操作。
- cache miss 和 load stall 可观测性。
- 小型 int8 / bit manipulation / saturating arithmetic 指令。
- NPU/MMIO/DMA 的配置效率。

## 4. 当前项目基础

当前项目已经具备一个不错的起点：

- RV32IM 五级流水 core。
- forwarding、load-use stall、memory wait-state、branch/jump flush。
- 静态 + BHT/BTB 动态分支预测。
- 计数器：cycle、instret、stall、flush、branch、mispredict、BTB/BHT、cache hit/miss、bus grant。
- I-cache / D-cache。
- AHB-Lite master 交付边界：`rv32i_cached_ahb_master_top`。
- timer / UART / APB / AHB matrix 小型 SoC 验证。
- 软件镜像构建流和回归入口。
- A4 质量检查入口。

和玄铁式产品路线相比，主要差距是：

- 还没有 agent workload benchmark。
- 还没有 C runtime / SDK 风格的软件层。
- 还没有 RISC-V Bitmanip / Atomics / PMP / PLIC/CLIC。
- 分支预测还没有 RAS 和 indirect branch 优化。
- cache / bus 仍是 blocking，没有 prefetch、write buffer、DMA。
- 没有面向 AI 的 dot-product / matrix / NPU 加速单元。
- 没有系统化性能报告和 before/after 数据。

## 5. 新路线：Agent Core Roadmap

后续建议把路线改成下面六个阶段。

### Stage B：Agent workload baseline

目标：先建立 CPU-only baseline，知道 agent 类负载到底慢在哪里。

建议新增软件镜像：

```text
software/asm/agent_event_loop.S
software/asm/agent_tool_dispatch.S
software/asm/agent_token_scan.S
software/asm/agent_int8_matvec.S
```

第一版可以先用汇编，等 C runtime 稳定后再迁移到 C。

建议新增 testbench：

```text
sim/testcases/rv32i_agent_workload_tb.sv
```

输出指标：

```text
cycle
instret
stall_cycle
flush_cycle
branch_count
branch_mispredict_count
btb_hit/miss
icache/dcache hit/miss
bus_i/d grant
```

验收标准：

- 能跑一个最小 agent loop：任务队列取任务、dispatch、模拟工具调用、写回结果。
- 能跑一个 token scan / simple parser。
- 能跑一个 int8 dot/matvec CPU baseline。
- 文档记录 cycle 和 CPI。

### Stage C：Agent-oriented CPU microarchitecture

目标：优化 agent runtime 的控制流和调度开销。

优先方向：

- Return Address Stack：优化大量函数调用 / 返回。
- Indirect branch / JALR target cache：优化 dispatch table 和解释器风格跳转。
- 更细 stall reason counter：区分 load-use、I-cache miss、D-cache miss、bus wait、muldiv wait。
- Bitmanip 子集：优先 `clz/ctz/cpop/andn/orn/xnor/rol/ror`，服务 tokenizer、hash、bitmap、队列。
- Atomics 或轻量同步原语：服务 task queue、lock-free ring buffer。
- 更强 timer / interrupt controller：为 agent 调度 tick、超时、工具事件准备。

验收标准：

- 每个优化都有 before/after 数据。
- 不只说“加了功能”，而是说明 agent workload 的 cycle / CPI / miss / mispredict 变化。

### Stage D：Agent custom ISA

目标：加入小而明确的 AI / runtime 辅助指令，不直接上完整 RVV。

候选 custom 指令：

```text
dot4.s8      4 路 int8 dot product
dot4.u8      4 路 uint8 dot product
mac4.s8      4 路 int8 multiply-accumulate
satadd       饱和加法
clip         clamp 到 int8 / int4 范围
relu         简单激活
pack/unpack  byte/halfword 打包拆包
```

这些指令既能服务 tiny inference，也能服务 agent runtime 里的 token/vector scoring。

验收标准：

- CPU-only int8 matvec 和 custom ISA 版本形成性能对比。
- decoder、EX 单元、hazard、forwarding、testbench、软件宏都完整。

### Stage E：Agent Matrix Engine

目标：参考玄铁 MME 的“矩阵计算从普通向量中解耦”的思路，但做一个小型可实现版本。

第一版不要直接做完整矩阵 ISA，而是做 MMIO accelerator：

```text
rv32i_agent_matrix_accel
  control/status register
  source/destination base address
  M/N/K shape register
  int8 4x4 MAC array
  local scratchpad
  done/irq
```

推荐 memory map：

```text
0x4300_0000 AGENT_ACC_CTRL
0x4300_0004 AGENT_ACC_STATUS
0x4300_0008 AGENT_ACC_SRC_A
0x4300_000c AGENT_ACC_SRC_B
0x4300_0010 AGENT_ACC_DST
0x4300_0014 AGENT_ACC_SHAPE
0x4300_0018 AGENT_ACC_STRIDE
0x4300_001c AGENT_ACC_IRQ_EN
```

验收标准：

- CPU 配置 accelerator。
- accelerator 从 SRAM 读矩阵/向量。
- 完成后写回 SRAM。
- CPU 通过 polling 或 interrupt 获取完成事件。
- 和 CPU-only / custom instruction 版本比较性能。

### Stage F：Agent SoC demo

目标：形成一个能展示的完整 demo，而不只是 RTL 单元测试。

demo 形态：

```text
boot
初始化 runtime
加载小型 agent task graph
运行 scheduler
调用 tokenizer/parser
调用 int8 scoring/matvec
通过 UART 输出 plan/action/result
打印性能计数器
```

可选 demo：

- 规则型 agent：根据输入命令选择工具。
- Tiny intent classifier：int8 MLP 判断用户意图。
- Tiny retrieval scorer：对几个候选 action 做向量打分。

验收标准：

- UART 可见 agent 执行过程。
- 有 CPU-only、custom ISA、Matrix Engine 三组性能数据。
- 有论文/PPT 图：CPU、cache、AHB、APB、Agent Matrix Engine、runtime flow。

## 6. 我们的“新颖点”

这个方向的新颖点不是“又做了一个 NPU”，而是：

```text
面向 agent runtime 的 CPU + AI 协同设计。
```

传统小 CPU 项目往往只证明 ISA 能跑。传统 NPU 项目往往只关注矩阵乘法。本项目可以强调：

- agent 调度是控制密集型 workload，需要 CPU 微架构支持。
- 小模型推理是计算密集型 workload，需要 dot/matrix 加速。
- 两者通过统一的 AHB/SoC、timer/interrupt、perf counter 连接起来。
- 每个阶段都有可运行软件和可测量数据。

最后项目可以包装成：

```text
XuanTie-inspired RISC-V Agent Core
```

或者中文：

```text
面向本地 AI Agent 调度与轻量推理的 RISC-V 处理器核心
```

## 7. 最近两步建议

第一步，不急着加新硬件，先做 workload：

```text
Stage B1：agent event loop + tool dispatch 软件基准
```

第二步，再做第一个和 agent 高相关的小优化：

```text
Stage C1：Return Address Stack + 更细 stall reason counter
```

这样后面做 custom dot4 或 Matrix Engine 时，我们会有完整对照：

```text
CPU baseline
控制流优化后 CPU
custom ISA
MMIO Matrix Engine
```

这条路线更像玄铁产品线的思路：先有稳定处理器 IP，再围绕目标场景逐步增强，并且每一步都有软件、验证和性能数据支撑。
