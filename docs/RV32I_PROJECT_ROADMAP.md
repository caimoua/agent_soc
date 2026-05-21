# RV32I 项目路线图

最后更新：2026-05-21

本文记录项目后续的大方向。当前策略是先把已有 CPU 做成可交付 IP，再把它推进为面向本地 AI agent 调度与轻量推理的处理器子系统。玄铁式 agent 路线分析见 `docs/RV32I_XUANTIE_AGENT_ROADMAP.md`。新的 MCU + NPU + Agent Accelerator SoC 北极星路线见 `docs/AI_AGENT_MCU_NPU_SOC_ROADMAP.md`。

## 路线总览

```text
Stage A：可交付 CPU IP
  目标：让 rv32i_cached_ahb_master_top 成为别人可以集成、可以验证、可以阅读文档的 CPU 子系统。

Stage B：可运行 SoC / FPGA demo
  目标：用该 CPU 子系统组成一个小型 SoC，能从软件镜像启动，通过 UART/timer 等外设展示运行结果。

Stage C：性能优化型 CPU core
  目标：在可测量基线上优化分支、取指、cache、总线和 CPI。
```

推荐顺序固定为 A -> B -> C。除非某个功能阻塞当前阶段，否则不优先扩展零散外设或微架构功能。

## Agent Core 定位

项目中长期定位调整为：

```text
面向本地 AI Agent 调度与轻量推理的 RISC-V Agent Core
```

这里的 agent workload 不只是矩阵乘法，还包括任务调度、事件循环、工具调用、消息队列、token/string/JSON 解析、小模型控制流和 NPU/DMA 配置同步。后续不再只围绕“CPU 功能完整性”堆功能，而是围绕 agent runtime 建立 workload、性能基线和软硬协同优化。SoC 级目标会逐步扩展到 NPU、Agent Accelerator、SRAM/Flash/PSRAM 存储体系和更适合 DMA/NPU 的系统互连。

新方向参考玄铁产品路线的几个特点：

- 处理器 IP 产品化，而不是单个教学 RTL。
- 面向 AIoT/agent 场景做 ISA 和微架构增强。
- CPU 控制流优化与矩阵/点积加速协同。
- 每个优化都保留软件镜像、回归测试和性能数据。

## Stage A：可交付 CPU IP

### 目标形态

交付边界以 `rv32i_cached_ahb_master_top` 为主：

```text
rv32i_cached_ahb_master_top
  rv32i_pipe_core
  rv32i_icache
  rv32i_dcache
  rv32i_ahb_master_bus
  external AHB-Lite master interface
```

它应该像一个可复用 IP：

- 对外接口清楚，只暴露标准 AHB-Lite master 和必要 debug/perf 信号。
- 内部支持 RV32IM、五级流水、cache、trap/interrupt、access fault、misaligned trap。
- 有自动化回归入口。
- 有软件构建入口。
- 有接口文档、验证矩阵、设计假设和限制说明。
- 有 assertion 和 directed tests 保护关键控制流。

### A1：自动化回归

目标：

- 建立一条一键回归命令，统一运行核心 directed tests。
- 区分 smoke、core、cache、SoC、full regression。
- 回归结果可以输出简单日志摘要。

建议产物：

```text
sim/regress/
  regression_list.mk 或 regression_list.txt
  run_regression.ps1
  run_regression.sh
```

优先覆盖：

- `rv32i_pipe_core_tb`
- branch predictor 相关测试
- RV32M 测试
- trap/CSR 测试
- cache/bus 测试
- cached AHB master top 测试

验收标准：

- 能用一个命令跑完核心回归。
- 失败时能快速定位到具体 testbench。
- 文档里记录命令和推荐使用方式。

当前状态：

- 已新增 `sim/regress/regression_list.txt`。
- 已新增 PowerShell 入口 `sim/regress/run_regression.ps1`。
- 已新增 Bash 入口 `sim/regress/run_regression.sh`。
- 已支持 `smoke/core/cache/ahb/mmio/soc/full` suite。
- 已完成本地 dry-run 检查。
- `smoke` suite 已由用户在 VCS 环境确认 PASS。
- `core/cache/soc/full` suite 已由用户在 VCS 环境确认 PASS，Stage A1 收口。

### A2：汇编/C 测试流

目标：

- 减少手写机器码。
- 用 RISC-V GNU 工具链生成 `.memh`。
- directed testbench 尽量加载软件镜像。

建议产物：

```text
software/asm/
software/c/
software/linker/
software/scripts/
software/bin/
```

优先做：

- 把一个现有手写机器码 test 改成汇编镜像版本。
- 保留原 test 作为对照，直到新流程稳定。
- 增加一个最小 C 程序，验证启动、SRAM、UART 输出。

验收标准：

- `make -C software` 能稳定生成 `.memh`。
- 至少一个 core/cache/SoC testbench 从 `.memh` 加载程序。
- README 写清楚工具链路径和构建命令。

当前状态：

- `software/asm/`、`software/linker/`、`software/scripts/` 和 `software/bin/` 已建立。
- CPU 程序型 directed tests 已迁移到 `$readmemh` 软件镜像流。
- 用户已确认 Stage A2 第六轮 full regression PASS，日志目录为 `sim/log/regress/20260520_173852-full`。

### A3：RISC-V ISA 基础测试

目标：

- 引入更系统的 ISA 级验证，不只依赖手写 directed test。
- 先覆盖 RV32I，再覆盖 RV32M 的关键行为。

建议范围：

- 算术逻辑
- branch/jump
- load/store
- CSR/trap 的项目内自定义测试
- RV32M mul/div/rem 边界

验收标准：

- 可以把 ISA test 编译成当前 memory map 可加载的镜像。
- 至少形成一组稳定 smoke ISA regression。

当前状态：

- 已新增 `software/asm/isa_basic.S` 和 `software/bin/isa_basic.memh`。
- 已新增 `sim/testcases/rv32i_pipe_isa_basic_tb.sv`。
- 已新增 `isa` regression suite，并把该测试接入 `isa/core/full`。
- 用户已在 VCS 环境确认 `rv32i_pipe_isa_basic_tb` PASS。

### A4：lint / 综合 / 时序基础检查

目标：

- 证明这个设计不只是能仿真，也具备基本综合交付能力。

优先检查：

- 语法和 lint warning。
- 综合是否能通过。
- latch、多驱动、未连接端口、位宽截断。
- 关键路径大致分布，尤其是 IF 分支预测路径、mul/div stall 控制、cache/bus ready path。

验收标准：

- 有一份基础综合脚本或说明。
- 有一份当前 warning 清单。
- 明确哪些 warning 可接受，哪些需要修。

当前状态：

- 已新增 `tools/quality/run_quality_checks.ps1` 和 `tools/quality/run_quality_checks.sh`。
- 已新增 `project/constraints/rv32i_cached_ahb_master_top.sdc`。
- 已新增 `docs/RV32I_QUALITY_CHECKS.md`。
- PowerShell `basic` suite 已通过 filelist / SDC 检查。
- PowerShell `all -DryRun` 已验证 lint / synth / timing 命令路径。
- Bash 脚本已通过语法检查。
- 当前本机缺少 Verilator、Yosys 和 OpenSTA，真实 lint / synth / timing 运行状态为工具缺失导致的 `SKIP`。

### A5：IP 交付文档

目标：

- 让后来的人不用读完整代码也能集成。

建议文档：

- `docs/PROJECT_STATUS.md`
- `docs/INTERFACE_INDEX.md`
- `docs/VERIFICATION_MATRIX.md`
- `docs/RV32I_CPU_IP_DELIVERY.md`
- `docs/RV32I_PIPE_CORE.md`
- `docs/RV32I_LIMITATIONS.md`

验收标准：

- 写清楚支持的 ISA、异常、中断、cache、bus、memory map 假设。
- 写清楚不支持 compressed、privilege mode、MMU、outstanding transaction、burst。
- 写清楚推荐 top 和不推荐直接作为交付边界的 legacy top。

当前状态：

- `docs/RV32I_CPU_IP_DELIVERY.md` 已新增，第一版聚焦 `rv32i_cached_ahb_master_top` 的参数、AHB-Lite master 端口、外部 SoC 职责、debug/perf 端口、支持能力和限制。
- `docs/INTERFACE_INDEX.md`、`docs/RV32I_AHB.md`、`README.md` 和 `docs/PROJECT_STATUS.md` 已指向该交付边界。

## Stage B：可运行 SoC / FPGA demo

### 目标形态

用 Stage A 的 CPU IP 组成一个最小可运行平台：

```text
CPU subsystem
  AHB-Lite master
AHB matrix
  flash / ROM
  SRAM
  APB bridge
    timer
    UART
    GPIO
```

### B1：稳定 SoC memory map

目标：

- 固定 boot address、flash、SRAM、APB base。
- 软件 linker script 和 RTL decode 保持一致。

建议：

- flash：`0x0800_0000`
- SRAM：`0x2000_0000`
- APB timer：`0x4200_0000`
- APB UART：`0x4200_1000`

### B2：启动和 UART demo

目标：

- 从 flash/ROM 启动。
- 初始化 SRAM。
- UART 打印字符串。
- timer interrupt 可选打开。

验收标准：

- 仿真中可看到 UART 输出。
- 文档记录软件构建、加载和仿真命令。

### B3：FPGA 准备

目标：

- 把 SoC 放到 FPGA 工程中，接时钟、复位、UART pin。

优先做：

- FPGA top wrapper。
- block RAM 初始化。
- UART TX 输出。
- 简单 LED/GPIO。

验收标准：

- 板上能看到 UART 输出或 LED 状态变化。

## Stage C：性能优化型 CPU core

### 目标形态

在已有可运行平台上做可量化优化，而不是凭感觉改微架构。

### C1：性能基线

目标：

- 固定一组 benchmark。
- 输出 cycle、instret、stall、flush、branch/mispredict、cache miss。

候选：

- 简化 CoreMark-like loop。
- Dhrystone-like integer workload。
- memcpy/memset。
- branch-heavy loop。

### C2：取指和分支优化

候选方向：

- 更清晰的 fetch token。
- IF 阶段时序优化。
- 更大的 BHT/BTB。
- return address stack。
- JAL/JALR 预测增强。

### C3：cache 和 memory 优化

候选方向：

- I-cache prefetch。
- D-cache write buffer。
- refill burst。
- AHB/AXI burst。
- 更细 stall reason counter。

### C4：结果展示

目标：

- 每个优化都有 before/after 数据。
- 不只说“加了功能”，还要说“CPI 从多少变到多少，miss/mispredict 如何变化”。

## 当前执行建议

当前仍处于 Stage A。

A1 自动化回归、A2 汇编软件镜像流、A3 第一版项目内 ISA 基础测试子集、A4 第一版质量检查入口和 A5 CPU IP 交付文档第一版已经收口。下一步建议把重点转向更系统的验证和交付质量。

Stage A / Agent SoC 路线的推荐近期顺序：

1. 建立 agent event loop、tool dispatch、token scan 和 int8 matvec 的 CPU-only workload baseline。
2. 建立 NPU / Agent Accelerator 的软件功能模型和测试向量。
3. 在 Linux/CI 或本机安装 Verilator/Yosys 后运行 Stage A4 的 `lint/synth/all` suite，形成第一版 warning baseline。
4. 继续补 `docs/RV32I_PIPE_CORE.md` 和 `docs/RV32I_LIMITATIONS.md`。
5. 根据后续测试增长继续维护自动化回归 suite。
6. 在 benchmark 和功能模型稳定后，再展开 MMIO matrix accelerator、NPU 子系统和 SoC fabric 升级。
