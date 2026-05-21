# 仿真说明

## 当前 AHB Matrix SoC Test

```bash
make sim TB_FILE=./testcases/rv32i_ahb_matrix_soc_top_tb.sv TOP_NAME=rv32i_ahb_matrix_soc_top_tb
```

这个测试从 `0x0800_0000` flash slot 启动，并通过本地 AHB-Lite matrix 访问 flash、SRAM、AHB peripheral 和 APB peripheral slot。

默认 flash image 从 `../software/bin/ahb_matrix_soc.memh` 加载。如需覆盖默认镜像：

```bash
make sim TB_FILE=./testcases/rv32i_ahb_matrix_soc_top_tb.sv TOP_NAME=rv32i_ahb_matrix_soc_top_tb SIM_PLUSARGS="+FLASH_MEMH=../software/bin/ahb_matrix_soc.memh"
```

## 软件镜像加载的 Wrapper Test

Stage A2 开始，更多 directed test 不再直接在 SystemVerilog 里手写机器码，而是从 `software/bin/*.memh` 加载。

```bash
make sim TB_FILE=./testcases/rv32i_cached_system_top_tb.sv TOP_NAME=rv32i_cached_system_top_tb
make sim TB_FILE=./testcases/rv32i_cached_system_ahb_top_tb.sv TOP_NAME=rv32i_cached_system_ahb_top_tb
make sim TB_FILE=./testcases/rv32i_cached_ahb_master_top_tb.sv TOP_NAME=rv32i_cached_ahb_master_top_tb
```

默认软件镜像：

```text
rv32i_cached_system_top_tb      -> ../software/bin/cached_system_smoke.memh
rv32i_cached_system_ahb_top_tb  -> ../software/bin/cached_system_smoke.memh
rv32i_cached_ahb_master_top_tb  -> ../software/bin/cached_ahb_master.memh
rv32i_cached_timer_tb           -> ../software/bin/cached_timer.memh
rv32i_cached_uart_tb            -> ../software/bin/cached_uart.memh
rv32i_cached_timer_irq_tb       -> ../software/bin/cached_timer_irq.memh
rv32i_cached_access_fault_tb    -> ../software/bin/cached_access_fault.memh
rv32i_cached_instr_access_fault_tb
  -> ../software/bin/cached_instr_access_fault.memh
rv32i_cached_misaligned_trap_tb
  -> ../software/bin/cached_misaligned_trap.memh
rv32i_pipe_branch_predict_tb
  -> ../software/bin/pipe_branch_predict.memh
rv32i_pipe_dynamic_branch_predict_tb
  -> ../software/bin/pipe_dynamic_branch_predict.memh
rv32i_pipe_branch_predict_param_tb
  -> ../software/bin/pipe_branch_predict_param.memh
rv32i_pipe_muldiv_tb
  -> ../software/bin/pipe_muldiv.memh
rv32i_pipe_core_tb
  -> ../software/bin/pipe_core.memh
rv32i_trap_csr_tb
  -> ../software/bin/trap_csr.memh
rv32i_core_tb
  -> ../software/bin/core_smoke.memh
rv32i_pipe_icache_tb
  -> ../software/bin/pipe_icache.memh
rv32i_pipe_dcache_tb
  -> ../software/bin/pipe_dcache.memh
rv32i_pipe_cached_bus_tb
  -> ../software/bin/pipe_cached_bus.memh
rv32i_pipe_isa_basic_tb
  -> ../software/bin/isa_basic.memh
```

如需覆盖默认镜像，可以传：

```bash
make sim TB_FILE=./testcases/rv32i_cached_ahb_master_top_tb.sv TOP_NAME=rv32i_cached_ahb_master_top_tb SIM_PLUSARGS="+ROM_MEMH=../software/bin/cached_ahb_master.memh"
```

pipeline core 类 testbench 使用 `+IMEM_MEMH=<path>` 覆盖默认指令镜像。

这个目录是 VCS/Verdi 仿真的统一入口。

## 常用命令

```bash
make help
make com
make sim
make verdi
make clean
```

## 自动化回归

Stage A1 的回归入口位于 `sim/regress/`。它读取 `regress/regression_list.txt`，按 suite 展开测试列表，再调用现有 `make sim TB_FILE=... TOP_NAME=...`。

PowerShell：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\regress\run_regression.ps1 -Suite smoke -DryRun
powershell -NoProfile -ExecutionPolicy Bypass -File .\regress\run_regression.ps1 -Suite smoke
```

Bash：

```bash
bash ./regress/run_regression.sh --suite smoke --dry-run
bash ./regress/run_regression.sh --suite smoke
```

当前 suite：

```text
smoke, core, cache, ahb, mmio, soc, isa, full
```

ISA 基础子集：

```bash
bash ./regress/run_regression.sh --suite isa --dry-run
bash ./regress/run_regression.sh --suite isa
```

单独运行：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_isa_basic_tb.sv TOP_NAME=rv32i_pipe_isa_basic_tb
```

真实运行的日志会保存到：

```text
sim/log/regress/<timestamp>-<suite>/
```

默认 testbench：

```text
sim/testcases/rv32i_core_tb.sv
```

默认运行方式：

```bash
make sim
```

## 单周期 Core Testbench

```text
sim/testcases/rv32i_core_tb.sv
```

覆盖内容：

- R-type 和 I-type ALU 指令
- `lui`、`auipc`
- `jal`、`jalr`
- `beq`、`bne`、`blt`、`bge`、`bltu`、`bgeu`
- `lb`、`lh`、`lw`、`lbu`、`lhu`、`sb`、`sh`、`sw`
- `csrrs rd, cycle, x0`、`ecall`、`ebreak` 的最小 SYSTEM/CSR 路径

## 流水线 Core Testbench

```text
sim/testcases/rv32i_pipe_core_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_core_tb.sv TOP_NAME=rv32i_pipe_core_tb
```

覆盖内容：

- EX/MEM、MEM/WB 到 EX 阶段的 forwarding
- `lw` 后紧跟使用者时的 load-use stall
- 指令存储器和数据存储器 wait-state
- branch/jump redirect 后的 flush
- `instret/stall_cycle/flush_cycle` debug 性能计数器

## Standalone Performance Counter Testbench

```text
sim/testcases/rv32i_perf_counter_tb.sv
```

运行命令：

```bash
make sim TB_FILE=./testcases/rv32i_perf_counter_tb.sv TOP_NAME=rv32i_perf_counter_tb
```

覆盖内容：

- `cycle` 每个有效周期递增。
- `instret/stall/flush/branch/mispredict` event 可同周期独立累加。
- 异步 reset 清零全部计数器。

## Standalone Pipeline Control Testbench

```text
sim/testcases/rv32i_pipe_ctrl_tb.sv
```

运行命令：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_ctrl_tb.sv TOP_NAME=rv32i_pipe_ctrl_tb
```

覆盖内容：

- `commit_redirect` 优先级最高。
- `mem_stall` 保持前端和 EX/MEM、MEM/WB。
- `ex_muldiv_stall` 保持前端，EX/MEM 插入 bubble，MEM/WB drain。
- `load_use_stall`、`if_stall`、`if_discard` 和 `ex_redirect` 对 IF/ID、ID/EX 的控制行为。

## 静态分支预测 Testbench

```text
sim/testcases/rv32i_pipe_branch_predict_tb.sv
```

运行命令：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_branch_predict_tb.sv TOP_NAME=rv32i_pipe_branch_predict_tb
```

## Standalone Branch Predictor Testbench

```text
sim/testcases/rv32i_branch_predictor_tb.sv
```

运行命令：
```bash
make sim TB_FILE=./testcases/rv32i_branch_predictor_tb.sv TOP_NAME=rv32i_branch_predictor_tb
```

覆盖内容：
- 4 项 BHT/BTB 配置下的 IF 查询和 EX 更新。
- forward branch 从 BTB miss 到 trained BTB hit 的过程。
- taken / not-taken 更新对 BHT 计数器的影响。
- `JAL` 立即数预测和 `if_error` 抑制预测。

## 动态 BHT/BTB 分支预测 Testbench

```text
sim/testcases/rv32i_pipe_dynamic_branch_predict_tb.sv
```

运行命令：
```bash
make sim TB_FILE=./testcases/rv32i_pipe_dynamic_branch_predict_tb.sv TOP_NAME=rv32i_pipe_dynamic_branch_predict_tb
```

覆盖内容：
- 固定 PC 的 forward `beq` 重复 taken。
- 第一次 BTB miss 后训练 BHT/BTB。
- 后续同一条 forward branch 通过 BTB+BHT 预测 taken。
- 检查 `dbg_btb_hit_count`、`dbg_btb_miss_count` 和 `dbg_bht_update_count`。

## 参数化 BHT/BTB 分支预测 Testbench

```text
sim/testcases/rv32i_pipe_branch_predict_param_tb.sv
```

运行命令：
```bash
make sim TB_FILE=./testcases/rv32i_pipe_branch_predict_param_tb.sv TOP_NAME=rv32i_pipe_branch_predict_param_tb
```

覆盖内容：
- `BRANCH_PRED_INDEX_BITS=2`，即 4 项 BHT/BTB。
- forward branch 和 backward branch 分布在不同 predictor index。
- 小表项配置下仍能完成 BTB miss、BHT/BTB 训练、后续 BTB hit。
- 检查 `branch_count`、`branch_mispredict_count`、`btb_hit/miss` 和 `bht_update`。

## RV32M 乘除法扩展 Testbench

Decoder 译码边界：

```text
sim/testcases/rv32i_decoder_muldiv_tb.sv
```

运行命令：
```bash
make sim TB_FILE=./testcases/rv32i_decoder_muldiv_tb.sv TOP_NAME=rv32i_decoder_muldiv_tb
```

覆盖内容：
- `ENABLE_M=1` 时识别 8 条 RV32M 乘除法编码。
- 默认 `ENABLE_M=0` 时同样编码仍报告 illegal。
- `muldiv_valid/muldiv_op`、`reg_we`、`wb_sel`、访存/跳转控制信号保持一致。

流水线执行路径：

```text
sim/testcases/rv32i_pipe_muldiv_tb.sv
```

运行命令：
```bash
make sim TB_FILE=./testcases/rv32i_pipe_muldiv_tb.sv TOP_NAME=rv32i_pipe_muldiv_tb
```

覆盖内容：
- `mul/mulh/mulhsu/mulhu`
- `div/divu/rem/remu`
- divide by zero
- `INT_MIN / -1` overflow
- M 指令后紧跟消费者指令的 forwarding
- 多周期执行期间的 pipeline stall

覆盖内容：
- IF 阶段对已对齐 `JAL` 做静态 taken 预测。
- IF 阶段对已对齐 backward B-type branch 做静态 taken 预测。
- EX 阶段只在预测 PC 不匹配时 redirect。
- `dbg_branch_count` 和 `dbg_branch_mispredict_count` 计数器。

## Trap/CSR Testbench

```text
sim/testcases/rv32i_trap_csr_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_trap_csr_tb.sv TOP_NAME=rv32i_trap_csr_tb
```

覆盖内容：

- `csrrw x0, mtvec, x5`
- `ecall` 进入 `mtvec`
- handler 读取 `mcause/mepc`
- `csrrw x0, mepc, x7` 修改返回地址
- `mret` 返回主程序
- trap commit 时较年轻 store 不会提前写 data memory

## I-Cache Testbench

```text
sim/testcases/rv32i_icache_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_icache_tb.sv TOP_NAME=rv32i_icache_tb
```

覆盖内容：

- 2-way set associative
- 4-word cache line
- SRAM-style tag/data 存储
- hit、miss、refill 和 replacement

Pipeline + I-cache：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_icache_tb.sv TOP_NAME=rv32i_pipe_icache_tb
```

## D-Cache Testbench

```text
sim/testcases/rv32i_dcache_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_dcache_tb.sv TOP_NAME=rv32i_dcache_tb
```

覆盖内容：

- 2-way set associative
- 4-word cache line
- data SRAM byte write mask
- load miss refill
- store hit write-through
- store miss no-write-allocate

Pipeline + D-cache：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_dcache_tb.sv TOP_NAME=rv32i_pipe_dcache_tb
```

## Memory Bus Testbench

```text
sim/testcases/rv32i_mem_bus_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_mem_bus_tb.sv TOP_NAME=rv32i_mem_bus_tb
```

覆盖内容：

- I-cache/D-cache 两个 master
- D 优先仲裁
- ROM/SRAM/MMIO 地址 decode
- SRAM byte write strobe
- unmapped 地址的 `dbg_decode_error`

Pipeline + cache + bus 手工集成：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_cached_bus_tb.sv TOP_NAME=rv32i_pipe_cached_bus_tb
```

这个 testbench 直接实例化 core、I-cache、D-cache 和 bus，适合调试中间连接。

## Cached System Top Testbench

```text
sim/testcases/rv32i_cached_system_top_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_cached_system_top_tb.sv TOP_NAME=rv32i_cached_system_top_tb
```

这个 testbench 只实例化 `rv32i_cached_system_top`，在顶层外接 ROM、SRAM、MMIO 模型，验证正式系统 wrapper 的连接关系。

## MMIO Timer Testbench

独立 timer：

```text
sim/testcases/rv32i_timer_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_timer_tb.sv TOP_NAME=rv32i_timer_tb
```

Cached system + timer：

```text
sim/testcases/rv32i_cached_timer_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_cached_timer_tb.sv TOP_NAME=rv32i_cached_timer_tb
```

这个 testbench 验证 CPU 能通过 `0x4000_0000` MMIO 地址访问 `rv32i_timer`，并验证 D-cache 对 MMIO 走 uncached bypass。

Cached system + timer interrupt：

```text
sim/testcases/rv32i_cached_timer_irq_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_cached_timer_irq_tb.sv TOP_NAME=rv32i_cached_timer_irq_tb
```

这个 testbench 验证 `timer_irq` 通过 `mstatus.MIE && mie.MTIE && mip.MTIP` 进入 machine timer interrupt，handler 读取 `mcause/mepc/mstatus/mie/mip`，关闭 `mie.MTIE` 后通过 `mret` 返回主程序。

## MMIO UART Testbench

独立 UART：

```text
sim/testcases/rv32i_uart_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_uart_tb.sv TOP_NAME=rv32i_uart_tb
```

Cached system + UART：

```text
sim/testcases/rv32i_cached_uart_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_cached_uart_tb.sv TOP_NAME=rv32i_cached_uart_tb
```

这个 testbench 在 `rv32i_cached_system_top` 外接 `rv32i_mmio_periph_mux`、`rv32i_timer` 和 `rv32i_uart`。ROM 程序通过 `0x4000_1000` 写出 `UART\n`，并检查 UART MMIO 访问仍然绕过 D-cache。

## AHB-Lite Bus Testbench

独立 AHB-Lite memory bus：

```text
sim/testcases/rv32i_mem_bus_ahb_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_mem_bus_ahb_tb.sv TOP_NAME=rv32i_mem_bus_ahb_tb
```

Cached system + AHB-Lite bus path：

```text
sim/testcases/rv32i_cached_system_ahb_top_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_cached_system_ahb_top_tb.sv TOP_NAME=rv32i_cached_system_ahb_top_tb
```

这两个 testbench 验证 simple I/D request 能通过 `rv32i_mem_bus_ahb` 转成 AHB-Lite address/data phase，再访问 ROM/SRAM/MMIO。当前 AHB 路径是 single-beat、single-outstanding，partial write 会拆成多个 AHB byte transfer。

CPU subsystem AHB master interface：

```bash
make sim TB_FILE=./testcases/rv32i_cached_ahb_master_top_tb.sv TOP_NAME=rv32i_cached_ahb_master_top_tb
```

这个 testbench 使用 `rv32i_cached_ahb_master_top` 作为 DUT。ROM/SRAM/MMIO decoder 和 slave bridge 都放在 DUT 外面，用来验证 CPU subsystem 只通过外部 AHB-Lite master 接口访问系统外设。

## Access Fault Testbench

```text
sim/testcases/rv32i_cached_access_fault_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_cached_access_fault_tb.sv TOP_NAME=rv32i_cached_access_fault_tb
```

这个 testbench 验证 D 侧 unmapped 地址访问会由 bus 返回 `d_error`，经过 D-cache/LSU 形成 precise load/store access fault。handler 读取 `mcause/mepc` 写入 SRAM，修改 `mepc += 4` 后通过 `mret` 跳过 faulting 指令并返回主程序。

默认 ROM image 来自 `../software/bin/cached_access_fault.memh`，源码位于 `software/asm/cached_access_fault.S`。

Instruction access fault：
```text
sim/testcases/rv32i_cached_instr_access_fault_tb.sv
```

运行方式：
```bash
make sim TB_FILE=./testcases/rv32i_cached_instr_access_fault_tb.sv TOP_NAME=rv32i_cached_instr_access_fault_tb
```

这个 testbench 验证 I 侧 unmapped 取指会由 bus 返回 `i_error`，经过 I-cache/core fetch fault 标记形成 precise instruction access fault。handler 读取 `mcause/mepc` 写入 SRAM，修改 `mepc` 到安全返回地址后通过 `mret` 返回主程序。

默认 ROM image 来自 `../software/bin/cached_instr_access_fault.memh`，源码位于 `software/asm/cached_instr_access_fault.S`。

## 注意事项

当前 core 和 cache 仍是教学/学习版本。cache 和 bus 都是 blocking 风格，没有 outstanding 或 burst。I/D 侧 decode error 已经可以返回 core 并形成 instruction/load/store access fault；UART MMIO 已有最小 TX-only 版本，AHB-Lite 总线路径已有第一版，后续还可继续补 AXI-lite adapter 或 UART RX/FIFO/interrupt。
