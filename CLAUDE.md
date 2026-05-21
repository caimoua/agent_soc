# CLAUDE.md

这个文件用于给 Claude Code 或其他代码助手提供本仓库的工作上下文。

## 项目定位

这是一个面向学习和面试准备的 RISC-V RV32I CPU 微架构项目。当前方向是从单周期基线开始，逐步演进到五级流水线，并加入 forwarding、hazard handling、性能计数器，以及可选的 cache 和总线接口。

目标工具链：Linux 服务器上的 Synopsys VCS + Verdi。

## 构建与仿真

所有仿真都从 `sim/` 目录启动。

```bash
cd sim
make help       # 查看 target 和当前路径配置
make com        # 只编译，使用 VCS +v2k -sverilog -full64
make sim        # 编译并运行，通过 UCLI dump FSDB
make verdi      # 用 Verdi 打开波形
make clean      # 删除 simv、log、FSDB 和生成文件
```

`make sim` 是默认的“构建并测试”入口。可以通过 `TOP_NAME=...` 和 `TB_FILE=...` 覆盖默认 testbench。

## RTL 如何被包含

`sim/filelist.f` 是模板。Makefile 会生成 `sim/log/filelist.generated.f`，把 `../filelist/cpu_filelist` 替换成绝对路径 `FILELIST_DIR`，再通过 `-f` 传给 VCS。

实际 filelist 位于 `filelist/cpu_filelist/`：

| Filelist | 内容 |
| --- | --- |
| `common_rtl.f` | `rv32i_alu.v`、`rv32i_regfile.v` |
| `core_rtl.f` | `rv32i_imm_gen.v`、`rv32i_decoder.v`、`rv32i_core.v`、`rv32i_pipe_core.v` |
| `top_rtl.f` | `rv32i_soc_top.v` |

每个 `.f` 都设置了 `+incdir+../rtl/include`，因此可以找到 `rv32i_defs.vh`。

## 当前架构

当前状态：单周期 RV32I 教学基线，并已新增第一版五级流水线 core。

单周期 `rv32i_core.v` 保留为 golden baseline；流水线 `rv32i_pipe_core.v` 已加入 EX/MEM、MEM/WB 到 EX 阶段的 forwarding、`lw` 后紧跟使用结果时的一拍 load-use stall、指令/数据存储器等待停顿、branch/jump redirect 后的错误路径 flush，以及 `instret/stall_cycle/flush_cycle` debug 性能计数器。

已实现内容：

- 取指、译码、寄存器读取、ALU 执行、写回
- `lui`、`auipc`
- `jal`、`jalr`
- `beq`、`bne`、`blt`、`bge`、`bltu`、`bgeu`
- `lb`、`lh`、`lw`、`lbu`、`lhu`、`sb`、`sh`、`sw`
- `csrrs rd, cycle, x0`、`ecall`、`ebreak` 的最小 SYSTEM/CSR 路径
- 简单 data memory 接口，流水线 core 已支持 `dmem_ready` 拉低时的 blocking memory stall

### 模块层级

```text
rv32i_soc_top                          (rtl/top/)
  `-- rv32i_core                       (rtl/core/)
        |-- rv32i_decoder              (rtl/core/，opcode/funct 到控制信号)
        |-- rv32i_imm_gen              (rtl/core/，生成 5 类立即数)
        |-- rv32i_regfile              (rtl/common/，32x32b，x0 固定为 0)
        `-- rv32i_alu                  (rtl/common/，add/sub/and/or/xor/sll/srl/sra/slt/sltu)
```

### Include 规则

`rv32i_defs.vh` 位于 `rtl/include/`，定义 opcode 宏、ALU op 宏、writeback 选择宏和 PC 选择宏。使用这些宏的文件需要在开头写：

```verilog
`include "rv32i_defs.vh"
```

filelist 通过 `+incdir+` 提供 include 路径。

### Core 接口

`rv32i_core` 有分离的 I-mem 和 D-mem 端口：

- I-mem：`valid/addr/rdata`
- D-mem：`valid/write/addr/wdata/wstrb/ready/rdata`
- debug：PC、cycle、`dbg_reg_addr/dbg_reg_rdata` 寄存器调试读口、`illegal_instr`、`ecall`、`ebreak`

当前 D-mem 实现了 byte、halfword、word 访问语义；单周期 core 仍按单周期 memory 使用，流水线 core 已支持指令/数据存储器等待停顿。当前 SYSTEM/CSR 只实现 `cycle` 只读 CSR 和 `ecall/ebreak` 事件观测，后续会再补非对齐异常、trap 和更完整的 cache/bus handshake。

最小 trap/CSR 新阶段的设计文档是 `docs/RV32I_TRAP_CSR.md`。该阶段目标是加入 `mtvec/mepc/mcause`、`ecall/ebreak/illegal` trap、`mret` 返回，并把 trap 放到 MEM/WB commit 阶段处理以保证 precise exception。

### Testbench

`rv32i_core_tb.sv` 是 directed self-checking testbench。它初始化 256 word 的 instruction memory 和 data memory，驱动时钟与复位，然后用 `$fatal` 检查寄存器、分支和 memory 结果；成功时打印 `[PASS] rv32i_core_tb`。

`rv32i_pipe_core_tb.sv` 是流水线 directed testbench，用连续相关 ALU 指令、load-use 指令、带 wait-state 的指令/数据存储器和控制流指令验证 IF/ID、ID/EX、EX/MEM、MEM/WB 流水寄存器、WB 写回路径、forwarding、load-use stall、存储器等待停顿、branch/jump flush 和 debug 性能计数器。运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_core_tb.sv TOP_NAME=rv32i_pipe_core_tb
```

### 汇编测试

`software/asm/arith_basic.S` 目前对应早期硬编码测试。后续计划是把 `.S` 汇编成 hex/mem，再加载到 testbench 的 IMEM 中。

## 迭代路线

1. 阶段 1：完成单周期 RV32I core，覆盖基础整数指令、load/store、branch、jump、LUI/AUIPC。
2. 阶段 2：重构为五级流水线，加入 IF/ID、ID/EX、EX/MEM、MEM/WB 寄存器，forwarding、load-use stall、指令/数据存储器等待停顿、branch/jump flush、valid/kill bit 和性能计数器。
3. 阶段 3：加入最小 trap/CSR 机制，包括 `mtvec/mepc/mcause`、`ecall/ebreak/illegal` trap、`mret` 和 precise exception。
4. 阶段 4：选择两个微架构扩展优先推进，例如 branch predictor、I-cache、D-cache、AHB-lite/AXI-lite、interrupt/CSR、RV32M。
5. 阶段 5：整理面试材料，包括 block diagram、pipeline timing、hazard table、CPI 数据、波形截图和简洁 README。

## 可移植性说明

RTL 本身不绑定工具。当前 Makefile 默认使用 VCS 路径 `/opt/eda/synopsys/vcs/O-2018.09-SP2/bin/vcs`。如果换机器开发，从 Linux 仿真工作区路径运行 `make sim`，或在命令行覆盖 `VCS`/`VERDI`。
