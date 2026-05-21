# 自动化回归

本目录提供 Stage A1 的自动化回归入口。脚本不重新定义编译规则，只读取 `regression_list.txt`，然后逐个调用 `sim/Makefile` 中已有的 `make sim TB_FILE=... TOP_NAME=...`。

## 回归集合

当前支持：

- `smoke`：最小冒烟集合，覆盖单周期 core、流水线 core、RV32M 和推荐 AHB master top。
- `core`：core、decoder、pipeline control、performance counter、branch predictor、trap 和 RV32M。
- `cache`：I-cache、D-cache、memory bus、cached top、access fault。
- `ahb`：AHB-Lite bus path 和 AHB master top。
- `mmio`：timer、UART 和相关 cached/MMIO 测试。
- `soc`：推荐 CPU subsystem 和 AHB matrix SoC 顶层。
- `isa`：项目内 ISA 基础子集。
- `agent`：Agent workload baseline 和后续 Agent/NPU 相关 directed tests。
- `full`：当前已收口的 directed tests；PENDING 测试先放在独立 suite，PASS 后再并入。

## Windows / PowerShell

在仓库根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\sim\regress\run_regression.ps1 -Suite smoke -DryRun
powershell -NoProfile -ExecutionPolicy Bypass -File .\sim\regress\run_regression.ps1 -Suite smoke
```

常用参数：

```powershell
-Suite core
-Suite cache
-Suite soc
-Suite isa
-Suite agent
-Suite full
-BuildSoftware
-KeepGoing
-DryRun
```

## Linux / Bash

在 `sim/` 目录运行：

```bash
bash ./regress/run_regression.sh --suite smoke --dry-run
bash ./regress/run_regression.sh --suite smoke
bash ./regress/run_regression.sh --suite mmio --build-software
```

也可以从仓库根目录运行：

```bash
bash sim/regress/run_regression.sh --suite full --keep-going
```

## 日志

每次真实运行会创建：

```text
sim/log/regress/<timestamp>-<suite>/
```

每个 test 会保存：

- `<test>.run.log`：脚本捕获的完整 stdout/stderr。
- `<test>.compile.log`：该 test 的 VCS compile log。
- `<test>.sim.log`：该 test 的 VCS simulation log。
- `software_build.log`：使用 `-BuildSoftware` 或 `--build-software` 时保存软件镜像构建日志。

## 软件镜像

回归脚本默认使用仓库中已提交的 `software/bin/*.memh`。如果需要在回归前重新从 `software/asm/*.S` 生成镜像：

PowerShell：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\sim\regress\run_regression.ps1 -Suite mmio -BuildSoftware
```

Bash：

```bash
bash sim/regress/run_regression.sh --suite mmio --build-software
```

真实运行时脚本会检查关键 `.memh` 是否存在；缺失时会提示先使用软件构建入口或手动运行 `make -C software`。

## 清单格式

`regression_list.txt` 每行格式为：

```text
name|tb_file|top_name|suites|sim_plusargs
```

其中 `suites` 用逗号分隔，`sim_plusargs` 可留空。
