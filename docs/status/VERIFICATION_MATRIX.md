# 验证矩阵

最后更新：2026-05-21

状态含义：

- `PASS`：用户已经报告 VCS 运行通过，或者该测试在本轮工程管理文档整理前已经属于通过的回归集合。
- `PENDING`：testbench 已经存在，但还需要用户重新运行 VCS 确认。
- `TODO`：计划中，尚未实现。

## Directed Tests

| 覆盖范围 | Testbench | 在 `sim/` 下运行的命令 | 状态 |
| --- | --- | --- | --- |
| 单周期 RV32I core | `testcases/rv32i_core_tb.sv` | `make sim` | PASS |
| 流水线 hazard/control | `testcases/rv32i_pipe_core_tb.sv` | `make sim TB_FILE=./testcases/rv32i_pipe_core_tb.sv TOP_NAME=rv32i_pipe_core_tb` | PASS |
| 静态分支预测 | `testcases/rv32i_pipe_branch_predict_tb.sv` | `make sim TB_FILE=./testcases/rv32i_pipe_branch_predict_tb.sv TOP_NAME=rv32i_pipe_branch_predict_tb` | PASS |
| Standalone branch predictor | `testcases/rv32i_branch_predictor_tb.sv` | `make sim TB_FILE=./testcases/rv32i_branch_predictor_tb.sv TOP_NAME=rv32i_branch_predictor_tb` | PASS |
| Standalone performance counter | `testcases/rv32i_perf_counter_tb.sv` | `make sim TB_FILE=./testcases/rv32i_perf_counter_tb.sv TOP_NAME=rv32i_perf_counter_tb` | PASS |
| Standalone pipeline control | `testcases/rv32i_pipe_ctrl_tb.sv` | `make sim TB_FILE=./testcases/rv32i_pipe_ctrl_tb.sv TOP_NAME=rv32i_pipe_ctrl_tb` | PASS |
| 动态 BHT/BTB 分支预测 | `testcases/rv32i_pipe_dynamic_branch_predict_tb.sv` | `make sim TB_FILE=./testcases/rv32i_pipe_dynamic_branch_predict_tb.sv TOP_NAME=rv32i_pipe_dynamic_branch_predict_tb` | PASS |
| 参数化 BHT/BTB 分支预测 | `testcases/rv32i_pipe_branch_predict_param_tb.sv` | `make sim TB_FILE=./testcases/rv32i_pipe_branch_predict_param_tb.sv TOP_NAME=rv32i_pipe_branch_predict_param_tb` | PASS |
| RV32M 乘除法扩展 | `testcases/rv32i_pipe_muldiv_tb.sv` | `make sim TB_FILE=./testcases/rv32i_pipe_muldiv_tb.sv TOP_NAME=rv32i_pipe_muldiv_tb` | PASS |
| RV32M decoder 译码边界 | `testcases/rv32i_decoder_muldiv_tb.sv` | `make sim TB_FILE=./testcases/rv32i_decoder_muldiv_tb.sv TOP_NAME=rv32i_decoder_muldiv_tb` | PASS |
| RV32I/RV32M ISA 基础子集 | `testcases/rv32i_pipe_isa_basic_tb.sv` | `make sim TB_FILE=./testcases/rv32i_pipe_isa_basic_tb.sv TOP_NAME=rv32i_pipe_isa_basic_tb` | PASS |
| Agent workload baseline | `testcases/rv32i_agent_workload_tb.sv` | `make sim TB_FILE=./testcases/rv32i_agent_workload_tb.sv TOP_NAME=rv32i_agent_workload_tb` | PASS |
| Agent matrix accelerator SoC | `testcases/rv32i_agent_matrix_accel_soc_tb.sv` | `make sim TB_FILE=./testcases/rv32i_agent_matrix_accel_soc_tb.sv TOP_NAME=rv32i_agent_matrix_accel_soc_tb` | PENDING |
| Agent matrix accelerator SRAM mode | `testcases/rv32i_agent_matrix_accel_sram_soc_tb.sv` | `make sim TB_FILE=./testcases/rv32i_agent_matrix_accel_sram_soc_tb.sv TOP_NAME=rv32i_agent_matrix_accel_sram_soc_tb` | PENDING |
| Trap/CSR | `testcases/rv32i_trap_csr_tb.sv` | `make sim TB_FILE=./testcases/rv32i_trap_csr_tb.sv TOP_NAME=rv32i_trap_csr_tb` | PASS |
| I-cache | `testcases/rv32i_icache_tb.sv` | `make sim TB_FILE=./testcases/rv32i_icache_tb.sv TOP_NAME=rv32i_icache_tb` | PASS |
| D-cache | `testcases/rv32i_dcache_tb.sv` | `make sim TB_FILE=./testcases/rv32i_dcache_tb.sv TOP_NAME=rv32i_dcache_tb` | PASS |
| Memory bus | `testcases/rv32i_mem_bus_tb.sv` | `make sim TB_FILE=./testcases/rv32i_mem_bus_tb.sv TOP_NAME=rv32i_mem_bus_tb` | PASS |
| AHB-Lite memory bus | `testcases/rv32i_mem_bus_ahb_tb.sv` | `make sim TB_FILE=./testcases/rv32i_mem_bus_ahb_tb.sv TOP_NAME=rv32i_mem_bus_ahb_tb` | PASS |
| Pipeline + I-cache | `testcases/rv32i_pipe_icache_tb.sv` | `make sim TB_FILE=./testcases/rv32i_pipe_icache_tb.sv TOP_NAME=rv32i_pipe_icache_tb` | PASS |
| Pipeline + D-cache | `testcases/rv32i_pipe_dcache_tb.sv` | `make sim TB_FILE=./testcases/rv32i_pipe_dcache_tb.sv TOP_NAME=rv32i_pipe_dcache_tb` | PASS |
| Pipeline + cache + bus | `testcases/rv32i_pipe_cached_bus_tb.sv` | `make sim TB_FILE=./testcases/rv32i_pipe_cached_bus_tb.sv TOP_NAME=rv32i_pipe_cached_bus_tb` | PASS |
| Cached system top | `testcases/rv32i_cached_system_top_tb.sv` | `make sim TB_FILE=./testcases/rv32i_cached_system_top_tb.sv TOP_NAME=rv32i_cached_system_top_tb` | PASS |
| Cached system AHB top | `testcases/rv32i_cached_system_ahb_top_tb.sv` | `make sim TB_FILE=./testcases/rv32i_cached_system_ahb_top_tb.sv TOP_NAME=rv32i_cached_system_ahb_top_tb` | PASS |
| Cached AHB master CPU top | `testcases/rv32i_cached_ahb_master_top_tb.sv` | `make sim TB_FILE=./testcases/rv32i_cached_ahb_master_top_tb.sv TOP_NAME=rv32i_cached_ahb_master_top_tb` | PASS |
| AHB matrix SoC top | `testcases/rv32i_ahb_matrix_soc_top_tb.sv` | `make sim TB_FILE=./testcases/rv32i_ahb_matrix_soc_top_tb.sv TOP_NAME=rv32i_ahb_matrix_soc_top_tb` | PASS |
| AHB matrix + APB SoC top | `testcases/rv32i_ahb_matrix_apb_soc_top_tb.sv` | `make sim TB_FILE=./testcases/rv32i_ahb_matrix_apb_soc_top_tb.sv TOP_NAME=rv32i_ahb_matrix_apb_soc_top_tb` | PASS |
| Timer peripheral | `testcases/rv32i_timer_tb.sv` | `make sim TB_FILE=./testcases/rv32i_timer_tb.sv TOP_NAME=rv32i_timer_tb` | PASS |
| Cached timer MMIO | `testcases/rv32i_cached_timer_tb.sv` | `make sim TB_FILE=./testcases/rv32i_cached_timer_tb.sv TOP_NAME=rv32i_cached_timer_tb` | PASS |
| Cached timer interrupt | `testcases/rv32i_cached_timer_irq_tb.sv` | `make sim TB_FILE=./testcases/rv32i_cached_timer_irq_tb.sv TOP_NAME=rv32i_cached_timer_irq_tb` | PASS |
| UART peripheral | `testcases/rv32i_uart_tb.sv` | `make sim TB_FILE=./testcases/rv32i_uart_tb.sv TOP_NAME=rv32i_uart_tb` | PASS |
| Cached UART MMIO | `testcases/rv32i_cached_uart_tb.sv` | `make sim TB_FILE=./testcases/rv32i_cached_uart_tb.sv TOP_NAME=rv32i_cached_uart_tb` | PASS |
| D 侧 load/store access fault | `testcases/rv32i_cached_access_fault_tb.sv` | `make sim TB_FILE=./testcases/rv32i_cached_access_fault_tb.sv TOP_NAME=rv32i_cached_access_fault_tb` | PASS |
| I 侧 instruction access fault | `testcases/rv32i_cached_instr_access_fault_tb.sv` | `make sim TB_FILE=./testcases/rv32i_cached_instr_access_fault_tb.sv TOP_NAME=rv32i_cached_instr_access_fault_tb` | PASS |
| Misaligned address traps | `testcases/rv32i_cached_misaligned_trap_tb.sv` | `make sim TB_FILE=./testcases/rv32i_cached_misaligned_trap_tb.sv TOP_NAME=rv32i_cached_misaligned_trap_tb` | PASS |

## 回归建议

推荐优先使用自动化回归入口：

```bash
cd sim
bash ./regress/run_regression.sh --suite smoke
bash ./regress/run_regression.sh --suite isa --keep-going
bash ./regress/run_regression.sh --suite agent --keep-going
bash ./regress/run_regression.sh --suite core --keep-going
bash ./regress/run_regression.sh --suite cache --keep-going
bash ./regress/run_regression.sh --suite soc --keep-going
```

Windows PowerShell：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\sim\regress\run_regression.ps1 -Suite smoke
```

RTL 接口或 core 控制流改动后，至少运行：

- `rv32i_pipe_core_tb`
- `rv32i_perf_counter_tb`
- `rv32i_pipe_ctrl_tb`
- `rv32i_decoder_muldiv_tb`
- `rv32i_pipe_isa_basic_tb`
- `rv32i_pipe_muldiv_tb`
- `rv32i_branch_predictor_tb`
- `rv32i_pipe_branch_predict_tb`
- `rv32i_pipe_dynamic_branch_predict_tb`
- `rv32i_pipe_branch_predict_param_tb`
- `rv32i_mem_bus_tb`
- `rv32i_mem_bus_ahb_tb`
- `rv32i_icache_tb`
- `rv32i_dcache_tb`
- `rv32i_cached_system_top_tb`
- `rv32i_cached_system_ahb_top_tb`
- `rv32i_cached_ahb_master_top_tb`
- `rv32i_ahb_matrix_soc_top_tb`
- `rv32i_ahb_matrix_apb_soc_top_tb`
- `rv32i_agent_matrix_accel_soc_tb`
- `rv32i_agent_matrix_accel_sram_soc_tb`
- access fault 相关测试。

CSR/trap 改动后，至少运行：

- `rv32i_trap_csr_tb`
- `rv32i_cached_timer_irq_tb`
- `rv32i_cached_access_fault_tb`
- `rv32i_cached_instr_access_fault_tb`
- `rv32i_cached_misaligned_trap_tb`

MMIO 改动后，至少运行：

- timer 相关测试
- cached system top 测试
- `rv32i_uart_tb`
- `rv32i_cached_uart_tb`

## 非仿真质量检查

| 覆盖范围 | 命令 | 当前状态 |
| --- | --- | --- |
| filelist / SDC 基础检查 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\quality\run_quality_checks.ps1 -Suite basic` | PASS |
| lint / synth / timing 命令路径 dry-run | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\quality\run_quality_checks.ps1 -Suite all -DryRun` | PASS |
| Bash 质量检查脚本语法 | `bash -n tools/quality/run_quality_checks.sh` | PASS |
| Verilator lint | `tools/quality/run_quality_checks.* --suite lint` | SKIP：本机未安装 Verilator |
| Yosys synthesis/check | `tools/quality/run_quality_checks.* --suite synth` | SKIP：本机未安装 Yosys |
| OpenSTA timing | `tools/quality/run_quality_checks.* --suite timing` | SKIP：本机未安装 OpenSTA 且尚无 liberty/netlist |

## 最近人工更新

- 2026-05-21：用户确认 Agent workload baseline v0.1 `rv32i_agent_workload_tb` VCS PASS：`cycle=413`、`instret=331`、`stall_cycle=42`、`flush_cycle=18`、`branch_count=47`、`branch_mispredict_count=18`、`btb_hit=25`、`btb_miss=22`、`bht_update=47`。该测试覆盖 agent event loop、tool dispatch、token scan、INT8 dot 和 tiny matvec，并已接入 `agent` regression suite。
- 2026-05-21：新增 Agent matrix accelerator v0.2a SoC directed test：`rv32i_agent_matrix_accel_soc_tb`。该测试加载 `software/bin/agent_matrix_accel.memh`，通过 APB `0x4200_2000` scratchpad 启动 4x4 INT8 matvec，检查 4 个 int32 结果、checksum、IRQ pending/clear、debug status 和无 timer/UART 副作用；等待用户在 VCS 环境确认，当前状态 `PENDING`。
- 2026-05-21：新增 Agent matrix accelerator v0.2b SRAM-mode directed test：`rv32i_agent_matrix_accel_sram_soc_tb`。该测试加载 `software/bin/agent_matrix_accel_sram.memh`，CPU 在 SRAM 写入 matrix/vector，accelerator 作为第二 AHB master 读取 SRAM 并写回 result window，testbench 检查结果、IRQ pending/clear 和 accelerator AHB grant count；等待用户在 VCS 环境确认，当前状态 `PENDING`。
- 2026-05-21：Stage A4 第一版质量检查入口已新增，包含 PowerShell/Bash 脚本、`rv32i_cached_ahb_master_top` 初始 SDC 和 `docs/verification/RV32I_QUALITY_CHECKS.md`。本机已通过 filelist/SDC 基础检查、`all -DryRun` 和 Bash 语法检查；Verilator/Yosys/OpenSTA 真实运行因本机缺工具标记为 `SKIP`。
- 2026-05-21：用户确认 Stage A3 第一版 `rv32i_pipe_isa_basic_tb` VCS PASS：`cycle=476`、`instret=184`、`stall_cycle=190`、`flush_cycle=49`、`branch_count=48`、`branch_mispredict_count=48`。该测试覆盖 RV32I arithmetic/branch/jump/load-store 以及 RV32M mul/div/rem 基础和边界行为，并已接入 `isa/core/full` 回归 suite。
- 2026-05-20：Stage A5 CPU IP 交付文档第一版已补齐，新增 `docs/architecture/RV32I_CPU_IP_DELIVERY.md`，并把 README、接口索引和 AHB 文档入口统一到推荐交付边界 `rv32i_cached_ahb_master_top`。本轮只改文档，不需要新增 VCS 测试。
- 2026-05-20：用户确认 Stage A2 第六轮 full regression PASS，日志目录为 `sim/log/regress/20260520_173852-full`；本轮将剩余 CPU 程序型 directed tests 一次性迁移到软件镜像流：`rv32i_core_tb`、`rv32i_pipe_icache_tb`、`rv32i_pipe_dcache_tb` 和 `rv32i_pipe_cached_bus_tb`。
- 2026-05-20：用户确认 Stage A2 第五轮软件镜像迁移后的 `rv32i_pipe_core_tb` 和 `rv32i_trap_csr_tb` 均 VCS PASS；这两个测试默认加载 `software/bin/pipe_core.memh` 与 `software/bin/trap_csr.memh`。
- 2026-05-20：用户确认 Stage A2 第四轮软件镜像迁移后的 `rv32i_pipe_branch_predict_tb`、`rv32i_pipe_dynamic_branch_predict_tb`、`rv32i_pipe_branch_predict_param_tb` 和 `rv32i_pipe_muldiv_tb` 均 VCS PASS。Linux 回归机暂未配置 `riscv-none-elf-gcc`，因此 `--build-software` 入口会在工具链预检查处停止；不带该选项使用已生成的 MEMH 镜像运行正常。
- 2026-05-20：用户确认 Stage A2 第三轮软件镜像迁移后的 `rv32i_cached_timer_irq_tb`、`rv32i_cached_access_fault_tb`、`rv32i_cached_instr_access_fault_tb` 和 `rv32i_cached_misaligned_trap_tb` 均 VCS PASS。
- 2026-05-20：用户确认 Stage A2 第一轮软件镜像迁移后的 `rv32i_cached_system_top_tb`、`rv32i_cached_system_ahb_top_tb` 和 `rv32i_cached_ahb_master_top_tb` 均 VCS PASS。
- 2026-05-20：用户确认 Stage A2 第二轮软件镜像迁移后的 `mmio` suite VCS PASS，日志目录为 `sim/log/regress/20260520_104357-mmio`；该轮新增回归脚本软件镜像构建/检查入口，并迁移 `rv32i_cached_timer_tb` 和 `rv32i_cached_uart_tb`。
- 2026-05-19：用户确认 Stage A1 自动化回归 `core/cache/soc/full` suite 均 VCS PASS，自动化回归入口第一版收口。
- 2026-05-19：用户确认 Stage A1 自动化回归 `smoke` suite VCS PASS；该 suite 覆盖 `rv32i_core_tb`、`rv32i_pipe_core_tb`、`rv32i_pipe_muldiv_tb` 和 `rv32i_cached_ahb_master_top_tb`，日志目录为 `sim/log/regress/20260519_162217-smoke`。
- 2026-05-19：Stage A1 自动化回归入口第一版已新增，包含 `sim/regress/regression_list.txt`、PowerShell 脚本和 Bash 脚本，支持 `smoke/core/cache/ahb/mmio/soc/full` suite；本地已完成 dry-run 检查，真实 VCS 回归需在仿真环境运行。
- 2026-05-19：用户确认 Phase 6 第一轮 `rv32i_pipe_core` 仿真期 SystemVerilog assertion 加入后 VCS 回归 PASS；覆盖 commit redirect 优先级、流水线清空、memory stall 后端保持、mul/div stall 前端保持和 EX/MEM bubble、分支预测更新合法性、fault/illegal 写回屏蔽。
- 2026-05-19：用户确认 Phase 5 第二轮 `rv32i_pipe_core` stage 清零 task 抽取后 VCS 回归 PASS：core/branch/muldiv/trap/cache 关键回归均通过。
- 2026-05-19：用户确认 Phase 5 第一轮 `rv32i_pipe_core` 时序块拆分后 VCS 回归 PASS：`rv32i_pipe_core_tb`、分支预测、muldiv、trap/cache 关键回归均通过。
- 2026-05-19：用户确认 `rv32i_pipe_ctrl_tb` VCS PASS：pipeline control priority cases passed。
- 2026-05-19：用户确认 pipeline control 抽出后的 `rv32i_pipe_core_tb`、`rv32i_perf_counter_tb`、`rv32i_pipe_branch_predict_tb`、`rv32i_pipe_dynamic_branch_predict_tb`、`rv32i_pipe_branch_predict_param_tb`、`rv32i_pipe_muldiv_tb` 回归 VCS PASS。
- 2026-05-19：用户确认 `rv32i_perf_counter_tb` VCS PASS：standalone performance counter events and reset passed。
- 2026-05-19：用户确认性能计数器抽出后的 `rv32i_pipe_core_tb`、`rv32i_pipe_branch_predict_tb`、`rv32i_pipe_dynamic_branch_predict_tb`、`rv32i_pipe_branch_predict_param_tb` 回归 VCS PASS。
- 2026-05-19：用户确认 `rv32i_decoder_muldiv_tb` VCS PASS：`ENABLE_M` 打开时接受全部 RV32M `funct3`，默认 RV32I decoder 对 M 编码报告 illegal。
- 2026-05-19：用户确认 RV32M decoder 重构后的 `rv32i_pipe_muldiv_tb` 和 `rv32i_pipe_core_tb` 回归 VCS PASS。
- 2026-05-19：用户确认抽出 `rv32i_branch_predictor` 后的分支预测集成回归 VCS PASS：`rv32i_pipe_branch_predict_tb`、`rv32i_pipe_dynamic_branch_predict_tb`、`rv32i_pipe_branch_predict_param_tb`、`rv32i_pipe_core_tb`。
- 2026-05-19：用户确认 `rv32i_branch_predictor_tb` VCS PASS：`btb_hit=1`、`btb_miss=1`、`bht_update=2`。
- 2026-05-19：用户确认 `rv32i_pipe_branch_predict_param_tb` VCS PASS：`cycle=36`、`instret=26`、`branch_count=8`、`branch_mispredict_count=2`、`btb_hit=6`、`btb_miss=2`、`bht_update=8`。
- 2026-05-18：用户确认 `rv32i_pipe_muldiv_tb` VCS PASS：`cycle=212`、`instret=31`、`stall_cycle=177`、`flush_cycle=0`。
- 2026-05-18：用户确认 RV32M 后的 `rv32i_pipe_core_tb` 和 `rv32i_pipe_branch_predict_tb` 回归 VCS PASS。
- 2026-05-18：用户确认 `rv32i_pipe_dynamic_branch_predict_tb` VCS PASS：`branch_count=8`、`branch_mispredict_count=2`、`btb_hit=6`、`btb_miss=2`、`bht_update=8`。
- 2026-05-18：用户确认动态预测后的 `rv32i_pipe_branch_predict_tb` VCS PASS。
- 2026-05-18：用户确认 `rv32i_pipe_branch_predict_tb` 以及静态分支预测后的新版 `rv32i_pipe_core_tb` 均 VCS PASS。
- 2026-05-18：用户确认 `rv32i_ahb_matrix_apb_soc_top_tb` VCS PASS。
- 2026-05-18：用户确认 `rv32i_cached_misaligned_trap_tb` VCS PASS。
- 2026-05-15：用户确认 `$readmemh` 版本 `rv32i_ahb_matrix_soc_top_tb` VCS PASS。
- 2026-05-15：`rv32i_ahb_matrix_soc_top_tb` 已改为从 `software/bin/ahb_matrix_soc.memh` 加载 flash 内容。
- 2026-05-15：用户确认 `rv32i_ahb_matrix_soc_top_tb` VCS PASS。
- 2026-05-15：用户确认 `rv32i_cached_ahb_master_top_tb` VCS PASS。
- 2026-05-15：用户确认 `rv32i_mem_bus_ahb_tb` 和 `rv32i_cached_system_ahb_top_tb` VCS PASS。
- 2026-05-15：用户确认 `rv32i_uart_tb` 和 `rv32i_cached_uart_tb` VCS PASS。
- 2026-05-15：用户确认 `rv32i_mem_bus_tb` 和 `rv32i_cached_instr_access_fault_tb` VCS PASS。
