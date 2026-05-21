# 项目状态

最后更新：2026-05-21

这是后续 Codex 会话的第一入口。继续工作前先读这个文件，再按需读取 `docs/status/INTERFACE_INDEX.md`、`docs/status/VERIFICATION_MATRIX.md`、`docs/roadmap/AI_AGENT_MCU_NPU_SOC_ROADMAP.md` 和 `docs/roadmap/AGENT_SOC_ARCH_V0.md`，避免每次重新扫描大量 RTL。

本仓库是从 `d:\AIoT\cpu_prj` 新开的 AI Agent MCU + NPU SoC 项目。当前 RTL 仍以 RV32IM CPU / AHB-Lite 小 SoC 为可验证起点，后续工作围绕 Agent workload、NPU 功能模型、MMIO matrix accelerator、Agent Accelerator 和 SoC fabric 升级展开。第一版可执行架构边界见 `docs/roadmap/AGENT_SOC_ARCH_V0.md`。

## 当前基线

这是一个用于学习和迭代的 RV32I CPU / 小型 SoC 项目。当前主要系统边界有两类。

传统 cached system top：

```text
rv32i_cached_system_top
  rv32i_pipe_core
  rv32i_icache
  rv32i_dcache
  rv32i_mem_bus
  external ROM / SRAM / MMIO peripherals
```

更推荐作为 CPU 子系统交付边界的是：

```text
rv32i_cached_ahb_master_top
  rv32i_pipe_core
  rv32i_icache
  rv32i_dcache
  rv32i_ahb_master_bus
  external AHB-Lite master interface
```

## 项目大路线

后续大方向分为两层：CPU IP 基线继续沿用 `docs/roadmap/RV32I_PROJECT_ROADMAP.md` 的阶段描述；Agent MCU + NPU SoC 新路线以 `docs/roadmap/AI_AGENT_MCU_NPU_SOC_ROADMAP.md` 和 `docs/roadmap/AGENT_SOC_ARCH_V0.md` 为主。

```text
Stage A：可交付 CPU IP
  先把 rv32i_cached_ahb_master_top 打磨成可集成、可验证、可文档化的 CPU 子系统。

Stage B：可运行 SoC / FPGA demo
  再把 CPU 子系统放入小型 SoC，形成 boot、UART、timer、SRAM/flash 和 FPGA 展示路径。

Stage C：性能优化型 CPU core
  最后基于可测量 workload 做分支、取指、cache、总线和 CPI 优化。
```

当前 CPU IP 基线的 Stage A 已基本收口：A1 自动化回归、A2 汇编/软件镜像测试流、A3 第一版 ISA 基础测试子集、A4 第一版质量检查入口和 A5 CPU IP 交付文档第一版已经完成。新仓库的近期主线转为 Agent SoC v0：建立 agent workload baseline、建立 NPU/Agent Accelerator 功能模型、固定 lint/综合 warning baseline，以及继续补齐更细的 core/限制说明文档。

## 已完成

- RV32I 单周期 baseline core。
- 五级流水线 core，包含 forwarding、load-use stall、memory wait-state、branch/jump flush 和性能计数器。
  - 性能计数器已从 `rv32i_pipe_core` 抽成独立 `rv32i_perf_counter` 模块。
  - `rv32i_perf_counter_tb` 已由用户确认 VCS PASS。
  - 性能计数器抽出后的 `rv32i_pipe_core_tb`、静态/动态/参数化分支预测回归已由用户确认 VCS PASS。
  - `rv32i_pipe_ctrl` 已新增，用于集中管理当前 stall/flush 优先级。
  - `rv32i_pipe_ctrl_tb` 已由用户确认 VCS PASS。
  - pipeline control 抽出后的 core/perf/branch/muldiv 回归已由用户确认 VCS PASS。
  - Phase 5 第一轮已完成：`rv32i_pipe_core` 的 PC/IFID、ID/EX、EX/MEM、MEM/WB 时序更新块已拆分，并由用户确认 VCS 回归 PASS。
  - Phase 5 第二轮已完成：重复的 stage bubble/flush 清零逻辑已抽成本地 task，并由用户确认 VCS 回归 PASS。
  - Phase 6 第一轮已完成：`rv32i_pipe_core` 已加入仿真期 SystemVerilog assertion，覆盖 commit redirect 优先级、流水线清空、memory stall 保持、mul/div stall 前端保持、分支预测更新合法性和 fault/illegal 写回屏蔽，并由用户确认 VCS 回归 PASS。
- 第一版静态分支预测：
  - 对齐的 `JAL` 在 IF 阶段预测 taken。
  - 对齐的 backward B-type branch 在 IF 阶段预测 taken。
  - forward B-type branch 预测 not-taken。
  - `JALR` 仍在 EX 阶段解析。
  - `dbg_branch_count` 和 `dbg_branch_mispredict_count` 已透出。
- 小型动态 BHT/BTB 分支预测：
  - 默认 64 项 direct-mapped BHT，2-bit 饱和计数器。
  - 默认 64 项 direct-mapped BTB，记录分支 PC tag 和目标 PC。
  - BHT/BTB 已从 `rv32i_pipe_core` 抽成独立 `rv32i_branch_predictor` 模块。
  - `BRANCH_PRED_INDEX_BITS` 参数已从 core 透传到 cached/AHB/SoC wrapper，用于调整 BHT/BTB 表项数量。
  - B-type branch 优先使用 BTB+BHT，BTB miss 时回退到静态 backward-taken 规则。
  - `dbg_btb_hit_count`, `dbg_btb_miss_count`, `dbg_bht_update_count` 已透出。
  - `rv32i_pipe_dynamic_branch_predict_tb` 已由用户确认 VCS PASS。
  - `rv32i_pipe_branch_predict_param_tb` 已由用户确认 VCS PASS。
  - `rv32i_branch_predictor_tb` 已由用户确认 VCS PASS。
  - 抽出 `rv32i_branch_predictor` 后的分支预测和 pipeline core 集成回归已由用户确认 VCS PASS。
- RV32M 乘除法扩展：
  - 支持 `mul/mulh/mulhsu/mulhu/div/divu/rem/remu`。
  - M 扩展识别已并入 `rv32i_decoder`，由 `ENABLE_M` 参数控制。
  - `rv32i_pipe_core` 打开 `ENABLE_M` 并只消费 decoder 输出的 `muldiv_valid/muldiv_op`。
  - 单周期 `rv32i_core` 保持 decoder 默认 `ENABLE_M=0`，仍作为 RV32I-only baseline。
  - 新增 EX 阶段 `rv32i_muldiv` 多周期执行单元。
  - M 指令结果复用 ALU writeback/forwarding 路径。
  - `rv32i_pipe_muldiv_tb` 已由用户确认 VCS PASS。
  - `rv32i_decoder_muldiv_tb` 已由用户确认 VCS PASS。
- Stage A3 第一版项目内 ISA 基础测试子集：
  - `software/asm/isa_basic.S`
  - `software/bin/isa_basic.memh`
  - `sim/testcases/rv32i_pipe_isa_basic_tb.sv`
  - 覆盖 RV32I arithmetic/branch/jump/load-store 和 RV32M mul/div/rem 基础行为。
  - 已接入 `isa/core/full` 回归 suite，并由用户确认 VCS PASS。
- Stage A4 第一版质量检查入口：
  - `tools/quality/run_quality_checks.ps1`
  - `tools/quality/run_quality_checks.sh`
  - `project/constraints/rv32i_cached_ahb_master_top.sdc`
  - `docs/verification/RV32I_QUALITY_CHECKS.md`
  - 支持 filelist/SDC 基础检查，并可选接入 Verilator lint、Yosys synthesis/check 和 OpenSTA timing。
- 玄铁式 Agent Core 路线分析：
  - `docs/roadmap/RV32I_XUANTIE_AGENT_ROADMAP.md`
  - 将后续方向从泛化 CPU/SoC demo 收敛为面向 agent runtime 的调度、控制流、内存访问和轻量 AI 加速。
- AI Agent MCU + NPU SoC 新路线承接：
  - `docs/roadmap/AI_AGENT_MCU_NPU_SOC_ROADMAP.md`
  - 将当前 RV32IM/AHB CPU 子系统定位为新 SoC 的控制面 CPU IP 起点，并把后续工作拆为 agent workload baseline、功能模型、MMIO matrix accelerator、NPU 子系统、Agent Accelerator 和 SoC fabric 升级。
- Agent SoC v0 可执行架构：
  - `docs/roadmap/AGENT_SOC_ARCH_V0.md`
  - 固定 v0.1 agent workload baseline、v0.2 MMIO matrix accelerator 和 v0.3 tool-call detector 的模块边界、地址映射和验收标准。
- Agent workload baseline v0.1：
  - `software/asm/agent_workload.S`
  - `software/bin/agent_workload.memh`
  - `sim/testcases/rv32i_agent_workload_tb.sv`
  - `sim/regress/regression_list.txt` 已新增 `agent` suite。
  - 本机已使用 `D:\AIoT\tools\riscv-none-elf-gcc-15.2.0-1` 和 `D:\AIoT\tools\ezwinports-make` 生成 `agent_workload.memh`。
  - 用户已确认 VCS PASS：`cycle=413`、`instret=331`、`stall_cycle=42`、`flush_cycle=18`、`branch_count=47`、`branch_mispredict_count=18`、`btb_hit=25`、`btb_miss=22`、`bht_update=47`。
- Agent matrix accelerator v0.2a：
  - `rtl/accel/rv32i_agent_matrix_accel.v`
  - `filelist/cpu_filelist/accel_rtl.f`
  - APB window：`0x4200_2000`。
  - `rv32i_apb_periph_mux` 已新增 Agent Matrix decode path。
  - `rv32i_ahb_matrix_apb_soc_top` 已实例化 accelerator 并透出 debug result/status/start_count。
  - `software/asm/agent_matrix_accel.S`
  - `software/bin/agent_matrix_accel.memh`
  - `sim/testcases/rv32i_agent_matrix_accel_soc_tb.sv`
  - `sim/regress/regression_list.txt` 已把该 test 接入 `agent` suite。
  - 当前本地已补齐代码和静态入口，VCS 真实结果等待用户确认，验证矩阵状态为 `PENDING`。
- 最小 machine-mode trap/CSR 路径：
  - `mtvec`, `mepc`, `mcause`
  - `mstatus.MIE/MPIE`, `mie.MTIE`, `mip.MTIP`
  - `ecall`, `ebreak`, illegal instruction trap
  - `mret`
  - MEM/WB commit 阶段 precise trap。
- instruction/load/store access fault。
- instruction/load/store misaligned address trap。
- Blocking 2-way I-cache，4-word cache line。
- Blocking 2-way D-cache，4-word cache line，write-through，no-write-allocate，默认 MMIO uncached bypass。
- 内部 blocking memory bus：
  - I-cache 和 D-cache 两个 master。
  - ROM、SRAM、MMIO 三类 slave。
  - D 侧优先仲裁。
  - decode error response。
- AHB-Lite bus path：
  - simple-to-AHB master bridge。
  - AHB-Lite decoder。
  - AHB-to-simple slave bridge。
  - `rv32i_cached_system_ahb_top`。
- 标准 CPU 子系统接口：
  - `rv32i_cached_ahb_master_top`
  - 对外只暴露一个 AHB-Lite master port。
  - 外部 SoC/bus fabric 负责 ROM/SRAM/MMIO decode。
  - CPU IP 交付说明第一版：`docs/architecture/RV32I_CPU_IP_DELIVERY.md`。
- Clean-room AHB-Lite 1-master / 4-slave matrix SoC wrapper：
  - `rv32i_ahb_lite_matrix_1m4s`
  - `rv32i_ahb_matrix_soc_top`
  - flash slot at `0x0800_0000`
  - SRAM slot at `0x2000_0000`
  - AHB peripheral slot at `0x4000_0000`
  - APB peripheral slot at `0x4200_0000`
- AHB-to-APB SoC integration：
  - `rv32i_ahb_to_apb`
  - `rv32i_apb_periph_mux`
  - `rv32i_ahb_matrix_apb_soc_top`
  - APB timer at `0x4200_0000`
  - APB UART at `0x4200_1000`
  - APB Agent Matrix Accelerator at `0x4200_2000`
  - software image `software/bin/ahb_matrix_apb_soc.memh`
- `RESET_PC` 参数，支持 SoC wrapper 从 flash 启动。
- MMIO timer peripheral，包含 `mtime`, `mtimecmp`, `ctrl`, `timer_irq`。
- machine timer interrupt 路径，支持 handler 进入和 `mret` 返回。
- 最小 TX-only UART MMIO peripheral。
- external MMIO peripheral mux，timer at `0x4000_0000`，UART at `0x4000_1000`。
- 论文/PPT 可用的系统结构 SVG：`docs/figures/rv32i_cached_system_architecture.svg`。
- 软件镜像构建流：
  - `software/asm/ahb_matrix_soc.S`
  - `software/asm/ahb_matrix_apb_soc.S`
  - `software/asm/cached_system_smoke.S`
  - `software/asm/cached_ahb_master.S`
  - `software/asm/cached_timer.S`
  - `software/asm/cached_uart.S`
  - `software/asm/cached_timer_irq.S`
  - `software/asm/cached_access_fault.S`
  - `software/asm/cached_instr_access_fault.S`
  - `software/asm/cached_misaligned_trap.S`
  - `software/asm/pipe_branch_predict.S`
  - `software/asm/pipe_dynamic_branch_predict.S`
  - `software/asm/pipe_branch_predict_param.S`
  - `software/asm/pipe_muldiv.S`
  - `software/asm/pipe_core.S`
  - `software/asm/trap_csr.S`
  - `software/asm/core_smoke.S`
  - `software/asm/pipe_icache.S`
  - `software/asm/pipe_dcache.S`
  - `software/asm/pipe_cached_bus.S`
  - `software/asm/isa_basic.S`
  - `software/linker/rv32i_flash.ld`
  - `software/linker/rv32i_rom0.ld`
  - `software/scripts/bin_to_memh.py`
  - `software/bin/ahb_matrix_soc.memh`
  - `software/bin/ahb_matrix_apb_soc.memh`
  - `software/bin/cached_system_smoke.memh`
  - `software/bin/cached_ahb_master.memh`
  - `software/bin/cached_timer.memh`
  - `software/bin/cached_uart.memh`
  - `software/bin/cached_timer_irq.memh`
  - `software/bin/cached_access_fault.memh`
  - `software/bin/cached_instr_access_fault.memh`
  - `software/bin/cached_misaligned_trap.memh`
  - `software/bin/pipe_branch_predict.memh`
  - `software/bin/pipe_dynamic_branch_predict.memh`
  - `software/bin/pipe_branch_predict_param.memh`
  - `software/bin/pipe_muldiv.memh`
  - `software/bin/pipe_core.memh`
  - `software/bin/trap_csr.memh`
  - `software/bin/core_smoke.memh`
  - `software/bin/pipe_icache.memh`
  - `software/bin/pipe_dcache.memh`
  - `software/bin/pipe_cached_bus.memh`
  - `software/bin/isa_basic.memh`
  - `rv32i_ahb_matrix_soc_top_tb` 通过 `$readmemh` 加载 flash 内容。
  - `rv32i_cached_system_top_tb`、`rv32i_cached_system_ahb_top_tb` 和 `rv32i_cached_ahb_master_top_tb` 已改为通过 `$readmemh` 加载 ROM 内容，并已由用户确认 VCS PASS。
  - `rv32i_cached_timer_tb` 和 `rv32i_cached_uart_tb` 已改为通过 `$readmemh` 加载 ROM 内容，并已由用户确认 `mmio` suite VCS PASS。
  - `rv32i_cached_timer_irq_tb`、`rv32i_cached_access_fault_tb`、`rv32i_cached_instr_access_fault_tb` 和 `rv32i_cached_misaligned_trap_tb` 已改为通过 `$readmemh` 加载 ROM 内容，并已由用户确认 VCS PASS。
  - `rv32i_pipe_branch_predict_tb`、`rv32i_pipe_dynamic_branch_predict_tb`、`rv32i_pipe_branch_predict_param_tb` 和 `rv32i_pipe_muldiv_tb` 已改为通过 `$readmemh` 加载指令内容，并已由用户确认 VCS PASS。
  - `rv32i_pipe_core_tb` 和 `rv32i_trap_csr_tb` 已改为通过 `$readmemh` 加载指令内容，并已由用户确认 VCS PASS。
  - `rv32i_core_tb`、`rv32i_pipe_icache_tb`、`rv32i_pipe_dcache_tb` 和 `rv32i_pipe_cached_bus_tb` 已改为通过 `$readmemh` 加载指令内容，并已由用户确认 full regression PASS。
- 本地 Windows RISC-V GNU 工具链流程已经记录并验证：
  - `riscv-none-elf-gcc`
  - `riscv-none-elf-objcopy`
  - GNU Make
  - `make -C software` 可重新生成 MEMH 镜像。
- Stage A1 自动化回归入口第一版：
  - `sim/regress/regression_list.txt`
  - `sim/regress/run_regression.ps1`
  - `sim/regress/run_regression.sh`
  - 支持 `smoke/core/cache/ahb/mmio/soc/full` suite。
  - 支持可选软件镜像构建入口：PowerShell `-BuildSoftware`，Bash `--build-software`。
  - 本地已完成 PowerShell dry-run 和 Bash 语法/dry-run 检查。
  - 用户已在 VCS 环境确认 `smoke` suite PASS。
  - 用户已在 VCS 环境确认 `core/cache/soc/full` suite PASS，Stage A1 收口。

## 验证状态摘要

详细状态见 `docs/status/VERIFICATION_MATRIX.md`。

当前 Phase 6 第一轮 `rv32i_pipe_core` 仿真期 assertion 已加入，并由用户确认 VCS 回归 PASS。Stage A1 自动化回归入口第一版已完成，`smoke/core/cache/soc/full` suite 均已由用户确认 VCS PASS。Stage A2 第一轮已把 cached system / AHB master 相关 directed tests 从手写机器码迁移到软件镜像流，相关 testbench 已由用户确认 VCS PASS。Stage A2 第二轮已迁移 cached timer / UART，并给回归脚本加入软件镜像构建和缺失检查；用户已确认 `mmio` suite VCS PASS。Stage A2 第三轮已迁移 timer IRQ、access fault、instruction access fault 和 misaligned trap 相关 cached directed tests，并已由用户确认 VCS PASS。Stage A2 第四轮已迁移 branch predict 和 RV32M pipeline directed tests，并已由用户确认 VCS PASS。Stage A2 第五轮已迁移 `rv32i_pipe_core_tb` 和 `rv32i_trap_csr_tb` 到软件镜像流，并已由用户确认 VCS PASS。Stage A2 第六轮已把剩余 CPU 程序型 directed tests 一次性迁移到软件镜像流，并已由用户确认 full regression PASS，日志目录为 `sim/log/regress/20260520_173852-full`。Stage A3 第一版项目内 ISA 基础测试子集已新增并接入 `isa/core/full` suite，用户已确认 `rv32i_pipe_isa_basic_tb` VCS PASS：`cycle=476`、`instret=184`、`stall_cycle=190`、`flush_cycle=49`、`branch_count=48`、`branch_mispredict_count=48`。Agent workload baseline v0.1 已由用户确认 VCS PASS：`cycle=413`、`instret=331`、`stall_cycle=42`、`flush_cycle=18`、`branch_count=47`、`branch_mispredict_count=18`。Agent matrix accelerator v0.2a 已完成 APB scratchpad RTL、SoC 接线、软件镜像和 directed test，等待 VCS 确认后再把验证矩阵从 `PENDING` 改为 `PASS`。Stage A4 第一版质量检查入口已新增，PowerShell `basic` suite 已通过 filelist/SDC 检查，`all -DryRun` 已验证命令路径，Bash 脚本已通过语法检查；本机未安装 Verilator/Yosys/OpenSTA，真实 lint/synth/timing 运行当前为工具缺失导致的 `SKIP`。Stage A5 CPU IP 交付文档第一版已补齐，新增 `docs/architecture/RV32I_CPU_IP_DELIVERY.md` 并把 README、接口索引和 AHB 文档入口统一到 `rv32i_cached_ahb_master_top`。Linux 回归机暂未配置 `riscv-none-elf-gcc`，因此 `--build-software` 会停在工具链预检查；使用已生成 MEMH 的普通 `make sim` 路径已确认通过。

## 设计假设

- 流水线 core 已支持 RV32IM 指令子集。
- 32-bit 固定长度指令。
- 不支持 compressed instruction。
- machine mode only。
- 无虚拟内存，无 page fault。
- cache 和 bus 都是 blocking。
- 无 outstanding transaction。
- 暂不支持 burst。
- CPU 子系统推荐通过 AHB-Lite master port 接入外部 SoC。

## 下一步候选

1. 在 VCS 环境运行 `rv32i_agent_matrix_accel_soc_tb`，确认 v0.2a APB scratchpad 加速器 PASS 并记录 cycle/instret。
2. v0.2b：把 Agent Matrix Accelerator 从 APB scratchpad 扩展到 SRAM src/dst/shape/stride 配置路径。
3. 建立 NPU / Agent Accelerator 的软件功能模型和测试向量，不直接跳到完整 32x32 NPU RTL。
4. 扩展 agent workload baseline 的结果记录，按 workload 分段统计 cycle/branch/stall。
5. 在 Linux/CI 或本机安装 Verilator/Yosys 后运行 `tools/quality` 的 `lint/synth/all` suite，形成第一版 warning baseline。
6. 根据后续测试增长继续维护自动化回归 suite。

## 上下文规则

后续 Codex 会话：

1. 先读本文件。
2. 再读 `docs/status/INTERFACE_INDEX.md`。
3. 再按任务读取相关 RTL/testbench。
4. 新增测试在用户给出 VCS PASS 前只能标记为 `PENDING`。
5. 用户确认 PASS 后，再更新 `docs/status/VERIFICATION_MATRIX.md`、本文件，并提交。
