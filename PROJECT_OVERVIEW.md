# CPU_PRJ 项目概览

生成日期：2026-05-11

这个项目会逐步发展成一个 RISC-V CPU 微架构练习平台。目录组织参考了已有的 M55 项目，但第一版保持更小、更容易推理，方便后续迭代和面试讲解。

## 1. 项目目标

第一阶段的目标不是做一个工业级 CPU，而是做一个自己能讲清楚、能仿真验证、能逐步演进的 CPU 项目：

- RV32I 指令译码和数据通路
- 单周期基线 CPU
- 五级流水线
- forwarding、stall、flush 等冒险处理
- 简单性能计数器
- 可选的 I-cache、D-cache、分支预测器、AHB/AXI-lite 接口

## 2. 目录说明

| 路径 | 用途 |
| --- | --- |
| `rtl/core/` | CPU 核心前端、译码、执行、访存、写回和流水线逻辑 |
| `rtl/common/` | ALU、寄存器堆、计数器、仲裁器等共享模块 |
| `rtl/top/` | 仿真或简单 SoC 集成用顶层 wrapper |
| `rtl/bus/` | 后续 AHB-lite、AXI-lite 或本地总线适配模块 |
| `rtl/mem/` | 后续 SRAM、ROM、cache、TCM 和存储器 wrapper |
| `rtl/periph/` | 后续 UART、timer、debug 等小外设 |
| `rtl/include/` | Verilog 头文件和共享参数 |
| `filelist/cpu_filelist/` | 按子系统拆分的 RTL filelist |
| `sim/` | VCS/Verdi 仿真入口，风格接近 `M55_PRJ/sim` |
| `sim/testcases/` | testbench 和 directed simulation 测试 |
| `sim/scripts/` | FSDB dump 和仿真辅助脚本 |
| `software/asm/` | 手写汇编测试 |
| `software/c/` | 后续 C 测试 |
| `software/linker/` | 后续 linker script |
| `software/scripts/` | 后续二进制、hex、mem 文件生成脚本 |
| `docs/` | 架构计划、笔记、调试记录和面试总结 |
| `project/` | EDA 或 FPGA 工程文件 |
| `ref/` | 参考资料笔记和小型外部示例 |
| `tools/` | 本地辅助脚本 |

## 3. 当前 RTL 基线

当前 RTL 是一个小型单周期 RV32I 基线。它已经具备取指、译码、寄存器读取、ALU 执行、branch/jump PC 选择、简单 data memory 访问和寄存器写回。

同时已新增五级流水线 core：`rtl/core/rv32i_pipe_core.v`。该版本保留单周期 core 作为 baseline，已验证 IF/ID、ID/EX、EX/MEM、MEM/WB 流水寄存器、写回路径、EX/MEM 和 MEM/WB 到 EX 阶段的 forwarding、`lw` 后紧跟使用结果时的一拍 load-use stall、指令/数据存储器等待停顿、branch/jump redirect 后的错误路径 flush，以及 `instret/stall_cycle/flush_cycle` debug 性能计数器；详细说明见 `docs/architecture/RV32I_PIPELINE_CORE.md`。

当前由 `sim/testcases/rv32i_core_tb.sv` 验证的内容：

- R-type：`add`、`sub`、`sll`、`slt`、`sltu`、`xor`、`srl`、`sra`、`or`、`and`
- I-type ALU：`addi`、`slti`、`sltiu`、`xori`、`ori`、`andi`、`slli`、`srli`、`srai`
- U-type：`lui`、`auipc`
- Jump：`jal`、`jalr`
- Branch：`beq`、`bne`、`blt`、`bge`、`bltu`、`bgeu`
- Memory：`lb`、`lh`、`lw`、`lbu`、`lhu`、`sb`、`sh`、`sw`
- SYSTEM/CSR：`csrrs rd, cycle, x0`、`ecall`、`ebreak` 的最小路径

memory 接口目前仍是教学版：单周期 directed test 中默认 `ready` 恒为 1；流水线 directed test 已加入指令存储器和数据存储器的一拍 wait-state，用来验证 blocking fetch/memory stall。当前已实现 byte、halfword、word 级 load/store，暂未处理非对齐访问异常。

单周期 core 的最小 SYSTEM/CSR 路径当前只实现 `cycle` CSR 只读写回和 `ecall/ebreak` debug 事件；详细说明见 `docs/architecture/SYSTEM_CSR_MINIMAL.md`。

pipeline core 已完成第一版最小 machine trap/CSR 机制，CSR/trap 状态已拆到 `rtl/core/rv32i_pipe_csr.v`，LSU 已拆到 `rtl/core/rv32i_pipe_lsu.v`，hazard/forwarding 已拆到 `rtl/core/rv32i_pipe_hazard.v`，支持 `mtvec/mepc/mcause`、`ecall/ebreak/illegal` trap、`mret` 返回和 commit 阶段 precise exception；设计与实现说明见 `docs/architecture/RV32I_TRAP_CSR.md`。

## 4. 仿真入口

在 Linux 仿真工作区运行：

```bash
cd /home2/kairos18/workspace/cpu_prj/sim
make sim
```

如果在其他路径，进入对应的 `cpu_prj/sim` 目录即可：

```bash
cd /path/to/cpu_prj/sim
make sim
```

常用 target：

```bash
make help
make com
make sim
make verdi
make clean
```

## 5. 迭代路线

短期路线：

1. 完成并验证单周期 RV32I core。
2. 重构为五级流水线。
3. 加入冒险处理和性能计数器。
4. 扩展异常/中断能力，例如非对齐访问异常、timer interrupt 和 `mstatus/mie/mip`。
5. 加入 cache 或分支预测。
6. 做一个小型总线式 SoC wrapper。

详细计划见 `docs/roadmap/RV32I_CPU_PLAN.md`。
