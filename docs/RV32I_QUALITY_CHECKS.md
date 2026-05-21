# RV32I 质量检查流程

最后更新：2026-05-21

本文记录 Stage A4 新增的 lint / 综合 / 时序基础检查入口。目标不是一次性替代完整 ASIC/FPGA sign-off，而是让当前 CPU IP 从“能仿真”继续往“可交付、可集成、可检查”推进。

## 1. 检查边界

默认检查的交付边界是：

```text
rv32i_cached_ahb_master_top
```

它是当前推荐 CPU IP wrapper，对外只暴露 AHB-Lite master、debug/perf 端口、时钟复位和 `timer_irq`。

## 2. 文件

```text
tools/quality/run_quality_checks.ps1
tools/quality/run_quality_checks.sh
project/constraints/rv32i_cached_ahb_master_top.sdc
```

脚本会读取 `sim/filelist.f` 和 `filelist/cpu_filelist/*.f`，统一检查 RTL filelist 中引用的源文件和 include 目录是否存在。

## 3. PowerShell 用法

从仓库根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\quality\run_quality_checks.ps1 -Suite basic
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\quality\run_quality_checks.ps1 -Suite all -DryRun
```

可选 suite：

```text
basic   检查 filelist 和 SDC 是否存在
lint    在 basic 基础上尝试运行 verilator --lint-only
synth   在 basic 基础上尝试生成并运行 Yosys 综合检查脚本
timing  检查 SDC，后续接入 OpenSTA/liberty/netlist
all     依次执行 lint、synth、timing
```

如果没有安装 Verilator / Yosys / OpenSTA，脚本默认给出 `SKIP`，不把缺工具当作设计失败。若希望 CI 中严格要求工具存在，可以加入：

```powershell
-StrictTools
```

## 4. Bash 用法

Linux/VCS 回归机或 WSL 中：

```bash
bash tools/quality/run_quality_checks.sh --suite basic
bash tools/quality/run_quality_checks.sh --suite all --dry-run
```

严格工具模式：

```bash
bash tools/quality/run_quality_checks.sh --suite all --strict-tools
```

## 5. 日志位置

日志默认写入：

```text
project/log/quality/<timestamp>-<suite>/
```

其中：

- `summary.txt`：本次检查摘要。
- `filelist_sources.txt`：展开后的 RTL source 列表。
- `yosys_synth.ys`：综合检查时自动生成的 Yosys 脚本。
- `verilator_lint.log`：Verilator lint 日志，只有实际运行 lint 时生成。
- `yosys_synth.log`：Yosys 综合日志，只有实际运行综合时生成。

`project/log/` 是生成目录，不应提交。

## 6. 当前基线

当前本机已经验证：

- PowerShell `basic` suite 通过 filelist / SDC 检查。
- PowerShell `all -DryRun` 可以生成预期命令路径。
- Bash 脚本通过 `bash -n` 语法检查。

当前本机未安装 Verilator、Yosys、OpenSTA，因此真实 lint / synth / timing 运行状态记录为 `SKIP`，不是 RTL 失败。

## 7. 后续改进

后续可以逐步补：

- 固定 Verilator warning baseline。
- 在 Linux/CI 中安装 Verilator 并把 lint 纳入必跑检查。
- 安装 Yosys 或 FPGA 综合工具，生成可跟踪的 cell/stat 报告。
- 接入具体 FPGA/ASIC library 后，用 OpenSTA 或厂商工具跑真实 timing。
- 对 IF 分支预测路径、mul/div stall 控制、cache/bus ready path 建立固定 timing 观察项。
