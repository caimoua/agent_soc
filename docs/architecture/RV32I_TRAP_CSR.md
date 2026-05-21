# RV32I 最小 Trap/CSR 机制说明

## 1. 为什么进入这个阶段

前面已经完成了单周期 core 和基础五级流水线 core。流水线现在已经能处理：

- forwarding
- load-use stall
- 指令/数据存储器等待停顿
- branch/jump flush
- 基础性能计数器

这一阶段要让 CPU 更像真正的处理器，所以加入 trap/exception 机制。

在上一版最小 SYSTEM/CSR 路径里，`ecall`、`ebreak` 和 `illegal_instr` 只是 debug 事件。它们会被 testbench 观察到，但不会真正改变 PC，也不会保存异常现场。本阶段最小 trap 机制要解决的问题是：

```text
当 CPU 遇到异常或系统事件时
保存发生异常的 PC 和原因
跳到 trap handler
清掉错误路径上的年轻指令
handler 处理完后通过 mret 返回
```

这一步的关键词是：**precise exception，精确异常**。

## 2. 当前目标和非目标

当前目标是做一个教学版 machine-mode trap 机制，先不做完整特权架构。

本阶段目标：

- 支持 `ecall` 进入 trap。
- 支持 `ebreak` 进入 trap。
- 支持非法指令进入 trap。
- 支持 `mret` 从 trap handler 返回。
- 新增最小 machine CSR：`mtvec`、`mepc`、`mcause`。
- 让 trap 在 commit/WB 阶段发生，保证精确异常。
- trap 或 `mret` 发生时 flush 年轻指令。

本阶段当时暂时不做：

- 中断 interrupt。
- `mstatus` 的完整 privilege 状态保存和恢复。
- `mie/mip`。
- 用户态、监督态。
- vectored trap mode。
- 非对齐 load/store 异常。
- page fault、access fault。

也就是说，这一阶段仍然只有一个简化的 machine mode。trap 只是一个明确的控制流机制和 CSR 状态保存机制。后续 `timer_irq` 接入和最小 `mstatus/mie/mip` 已记录在 `docs/architecture/RV32I_TIMER.md`。I/D 侧 access fault 也已接入同一套 commit trap 框架：instruction access fault 的验证入口是 `sim/testcases/rv32i_cached_instr_access_fault_tb.sv`，load/store access fault 的验证入口是 `sim/testcases/rv32i_cached_access_fault_tb.sv`。这两个 cached fault test 当前默认分别加载 `software/bin/cached_instr_access_fault.memh` 和 `software/bin/cached_access_fault.memh`。

## 3. precise exception 是什么

精确异常的含义是：当某条指令发生异常时，硬件表现得像下面这样：

```text
异常指令之前的所有指令都已经完成
异常指令之后的所有指令都还没有产生架构副作用
异常指令自己的 PC 被保存到 mepc
异常原因被保存到 mcause
PC 跳到 mtvec
```

在单周期 CPU 里这件事比较简单，因为每次只执行一条指令。

在五级流水线里，多条指令同时在不同阶段：

```text
IF -> ID -> EX -> MEM -> WB
```

如果在 ID 或 EX 一发现 `ecall` 就立刻跳转，会有两个问题：

1. 前面更老的指令可能还没写回，异常过早发生。
2. 后面更年轻的指令可能已经在流水线里，必须被清掉。

所以最稳妥的做法是：**trap 在 commit 点发生**。

当前流水线的 commit 点就是 `MEM/WB` 阶段。只有到达 `MEM/WB` 的指令，才允许真正改变架构状态，或者真正触发 trap。

## 4. 本阶段需要的 CSR

最小实现只需要三个 machine CSR：

```text
mtvec   0x305   trap handler 入口地址
mepc    0x341   trap 发生时的指令 PC
mcause  0x342   trap 原因
```

另外保留已有的只读 CSR：

```text
cycle   0xc00   周期计数器
```

### mtvec

`mtvec` 保存 trap handler 的入口地址。第一版只支持 direct mode：

```text
trap_pc = mtvec[31:2] << 2
```

也就是低 2 bit 先忽略，PC 对齐到 4 字节边界。

### mepc

`mepc` 保存发生 trap 的那条指令的 PC。

对于 32-bit RV32I 指令，如果 handler 想跳过 `ecall/ebreak/illegal`，软件需要：

```asm
csrrs t0, mepc, x0
addi  t0, t0, 4
csrrw x0, mepc, t0
mret
```

原因是标准语义里 `mret` 会跳到 `mepc`，不会自动 `mepc + 4`。

### mcause

本阶段先支持三个 cause：

```text
2   illegal instruction
3   breakpoint，也就是 ebreak
11  environment call from machine mode，也就是 ecall
```

当前只做同步异常，所以 `mcause[31]` 暂时为 0。

## 5. 需要扩展哪些 SYSTEM 指令

当前 decoder 已经识别：

```asm
ecall
ebreak
csrrs rd, cycle, x0
```

本阶段扩展为：

```asm
ecall
ebreak
mret
csrrw rd, csr, rs1
csrrs rd, csr, rs1
```

暂时不做立即数 CSR 指令：

```asm
csrrwi
csrrsi
csrrci
```

暂时也可以不做 `csrrc`，因为最小 trap handler 不需要清 bit。

### CSRRS

`csrrs rd, csr, rs1` 的标准语义是：

```text
old = CSR[csr]
x[rd] = old
if rs1 != x0:
  CSR[csr] = old | x[rs1]
```

如果 `rs1=x0`，它就是纯读 CSR，不修改 CSR。

常见伪指令：

```asm
csrr rd, csr
```

本质上就是：

```asm
csrrs rd, csr, x0
```

### CSRRW

`csrrw rd, csr, rs1` 的标准语义是：

```text
old = CSR[csr]
x[rd] = old
CSR[csr] = x[rs1]
```

如果 `rd=x0`，就只写 CSR，不关心旧值。

常见伪指令：

```asm
csrw csr, rs1
```

本质上就是：

```asm
csrrw x0, csr, rs1
```

这条指令对设置 `mtvec`、修改 `mepc` 很有用。

### MRET

`mret` 的编码是：

```text
0x30200073
```

它的作用是：

```text
PC <= mepc
flush 年轻指令
```

完整 RISC-V 里 `mret` 还会恢复 privilege 和 interrupt enable 状态。后续 timer interrupt 阶段已经补了最小 `mstatus.MIE/MPIE` 保存和恢复，但仍不实现完整 privilege mode。

## 6. trap 什么时候发生

trap 必须在 commit 点发生。当前设计建议定义：

```verilog
commit_valid = mem_wb_valid_q;
commit_pc    = mem_wb_pc4_q - 32'd4;
```

因为当前 `MEM/WB` 里保存的是 `pc + 4`，所以在只支持 32-bit 指令的情况下，可以用：

```verilog
commit_pc = mem_wb_pc4_q - 32'd4;
```

后续如果支持 C 扩展压缩指令，就应该专门在流水寄存器里保存原始 PC，而不是用 `pc4 - 4`。

commit 阶段如果看到：

```text
mem_wb_illegal_q
mem_wb_system_ecall_q
mem_wb_system_ebreak_q
```

就产生 trap。

trap 发生时：

```text
mepc   <= commit_pc
mcause <= cause
pc     <= mtvec
flush IF/ID、ID/EX、EX/MEM、MEM/WB
```

这里把 `MEM/WB` 也清掉，是为了让这个 trap 事件只发生一次。否则如果 `MEM/WB` 保持不变，下一拍还会再次看到同一个 trap。

## 7. trap 和已有 stall/flush 的优先级

当前流水线已经有：

- load-use stall
- 指令/数据存储器等待停顿
- branch/jump flush

trap 加进来以后，推荐优先级是：

```text
reset
commit trap / commit mret
指令/数据存储器等待停顿
EX branch/jump redirect
load-use stall
normal pipeline advance
```

原因如下。

### trap 优先于 memory stall

如果 `MEM/WB` 有一条老指令要进入 trap，同时 `EX/MEM` 有一条更年轻的 load/store 正在等 memory，那么应该优先处理老指令的 trap，并杀掉年轻指令。

否则 younger store 可能在异常之后还写 memory，破坏 precise exception。

因此本次 RTL 里，data memory 请求被 commit trap 屏蔽：

```verilog
dmem_valid = mem_access_valid && !commit_redirect;
```

其中 `commit_redirect` 包括 trap 和 `mret`。

### trap 优先于 EX redirect

如果老指令在 WB 进入 trap，而年轻的 branch/jump 在 EX 想 redirect，必须优先老指令的 trap。

因为 precise exception 要求异常点之前的状态完整，异常点之后的年轻指令不能影响控制流。

### mret 也属于 commit redirect

`mret` 到达 commit 点时，它和 trap 一样会改变 PC，并清掉年轻指令。

区别是：

```text
trap -> PC <= mtvec
mret -> PC <= mepc
```

## 8. CSR 写入放在哪一级

第一版建议把 CSR 写入也放在 commit/WB 阶段。

原因是 CSR 也是架构状态。如果一条 CSR 写指令在 EX 阶段就修改了 `mtvec/mepc/mcause`，但后面发现它其实处于错误路径，那 CSR 状态就被错误修改了。

所以推荐规则是：

```text
CSR read data 可以在 EX 阶段取样
CSR write side effect 在 MEM/WB commit 阶段发生
```

这和寄存器写回类似：真正改变架构状态的动作尽量集中在 commit 点。

## 9. RTL 修改方案

本次 RTL 按下面顺序修改。

### 第一步：扩展宏定义

在 `rv32i_defs.vh` 中增加：

```verilog
`define RV32I_CSR_MTVEC   12'h305
`define RV32I_CSR_MEPC    12'h341
`define RV32I_CSR_MCAUSE  12'h342

`define RV32I_SYS_NONE    2'd0
`define RV32I_SYS_ECALL   2'd1
`define RV32I_SYS_EBREAK  2'd2
`define RV32I_SYS_MRET    2'd3

`define RV32I_CSR_OP_NONE 2'd0
`define RV32I_CSR_OP_RW   2'd1
`define RV32I_CSR_OP_RS   2'd2
```

### 第二步：扩展 decoder

把当前的 `system_ecall/system_ebreak` 扩展成：

```text
system_op
csr_op
csr_addr
```

并支持：

```text
ecall
ebreak
mret
csrrw
csrrs
```

### 第三步：扩展流水寄存器

把这些信息一路从 ID 带到 MEM/WB：

```text
pc 或 pc4
system_op
csr_op
csr_addr
csr_wdata
csr_rdata
illegal
```

当前已经有一部分字段，主要需要补 `mret` 和 CSR 写操作相关字段。

### 第四步：新增 CSR 寄存器

在 core 内部增加：

```verilog
reg [31:0] csr_mtvec_q;
reg [31:0] csr_mepc_q;
reg [31:0] csr_mcause_q;
```

reset 后可以设置：

```text
mtvec  = 0x00000100
mepc   = 0
mcause = 0
```

### 第五步：commit trap/mret redirect

在 MEM/WB 阶段生成：

```text
commit_trap
commit_mret
commit_redirect
commit_redirect_pc
```

trap 写：

```text
mepc   <= commit_pc
mcause <= cause
pc     <= mtvec
```

mret 写：

```text
pc <= mepc
```

### 第六步：更新 flush/stall 优先级

把 always block 的控制优先级调整成：

```text
commit_redirect
mem_stall
ex_redirect
load_use_stall
normal advance
```

commit redirect 发生时，要清掉所有流水级中年轻指令，避免它们写寄存器或写 memory。

## 10. Testbench 验证实现

本次新建了一个 directed test：

```text
sim/testcases/rv32i_trap_csr_tb.sv
```

没有直接塞进 `rv32i_pipe_core_tb.sv`，是为了把 trap/CSR 行为和普通流水线 hazard 回归分开，后续定位问题会更清楚。

第一版测试可以这样组织。

### 测试 1：ecall trap

主程序：

```asm
addi  x5, x0, trap_handler
csrrw x0, mtvec, x5
ecall
addi  x10, x0, 1      // ecall 返回后应该执行
ebreak                // 作为仿真结束事件或下一次 trap
```

trap handler：

```asm
csrrs x6, mcause, x0  // 期望 11
csrrs x7, mepc, x0    // 期望 ecall 的 PC
addi  x7, x7, 4
csrrw x0, mepc, x7
mret
```

检查：

```text
mcause = 11
mepc 原始值 = ecall_pc
mret 后回到 ecall_pc + 4
ecall 后面的 addi 正常执行
```

### 测试 2：ebreak trap

类似 `ecall`，但：

```text
mcause = 3
```

### 测试 3：illegal instruction trap

在 instruction memory 中放一条非法编码：

```text
32'h00000000
```

期望：

```text
mcause = 2
mepc = illegal instruction PC
错误路径指令不产生副作用
```

### 测试 4：trap 优先级

构造一个场景，让 trap 提交时年轻指令已经在前面流水级中。

例如：

```asm
ecall
sw x1, 0(x0)      // younger wrong-path store，不应该真正写 memory
```

如果 trap flush 正确，`sw` 不应该修改 data memory。

这个测试非常重要，因为它直接证明 precise exception。

## 11. 和当前 SYSTEM_CSR_MINIMAL 的关系

`docs/architecture/SYSTEM_CSR_MINIMAL.md` 记录的是早期最小 SYSTEM/CSR debug 版本：

```text
ecall/ebreak 只产生 debug pulse
csrrs rd, cycle, x0 只读 cycle
不会改变 PC
不会写 mepc/mcause
不会跳 mtvec
```

本阶段 `RV32I_TRAP_CSR.md` 是下一层升级：

```text
ecall/ebreak/illegal 真正进入 trap
mret 真正返回
mtvec/mepc/mcause 成为架构状态
CSR 写入在 commit 阶段发生
```

所以两个文档不是冲突关系，而是演进关系。

## 12. 本次 RTL 修改说明

这一轮已经把最小 trap/CSR 机制真正落到了 pipeline core 上。原来的 `ecall/ebreak/illegal` 只是 debug 事件，现在它们会在 commit 点进入 trap；handler 可以读 `mcause/mepc`，修改 `mepc`，再用 `mret` 返回。

本次改动的核心原则是：

```text
译码阶段只识别指令和产生控制信息
EX 阶段可以读取 CSR 旧值
MEM/WB commit 阶段才真正修改 CSR 或触发 trap
trap/mret 一旦 commit，就清掉所有年轻指令
```

### 12.1 修改了哪些文件

| 文件 | 修改内容 |
| --- | --- |
| `rtl/include/rv32i_defs.vh` | 新增 CSR 地址、SYSTEM op、CSR op、trap cause 编码 |
| `rtl/core/rv32i_decoder.v` | 新增 `mret/csrrw/csrrs` 译码，扩展 SYSTEM 控制输出 |
| `rtl/core/rv32i_core.v` | 适配 decoder 新端口，保持单周期 baseline 可编译 |
| `rtl/core/rv32i_pipe_csr.v` | 独立承载 machine CSR 状态、trap/mret commit redirect、CSR commit 写入 |
| `rtl/core/rv32i_pipe_lsu.v` | 独立承载 load/store 端口生成、load 数据扩展、store byte enable 和 memory wait-state |
| `rtl/core/rv32i_pipe_hazard.v` | 独立承载 load-use stall、ID 阶段 WB bypass、EX 阶段 forwarding |
| `rtl/core/rv32i_pipe_core.v` | 接入 CSR/trap 模块，保留流水寄存器、hazard/flush/memory/writeback 主数据通路 |
| `filelist/cpu_filelist/core_rtl.f` | 加入 `rv32i_pipe_csr.v`、`rv32i_pipe_lsu.v` 和 `rv32i_pipe_hazard.v` |
| `sim/testcases/rv32i_trap_csr_tb.sv` | 新增 trap/CSR directed testbench |
| `sim/README.md` | 增加 trap/CSR testbench 的运行命令 |

### 12.2 宏定义怎么改

在 `rtl/include/rv32i_defs.vh` 里新增了三类定义。

第一类是 CSR 地址：

```verilog
`define RV32I_CSR_MTVEC   12'h305
`define RV32I_CSR_MEPC    12'h341
`define RV32I_CSR_MCAUSE  12'h342
`define RV32I_CSR_CYCLE   12'hc00
```

第二类是 SYSTEM 指令类型：

```verilog
`define RV32I_SYS_NONE    2'd0
`define RV32I_SYS_ECALL   2'd1
`define RV32I_SYS_EBREAK  2'd2
`define RV32I_SYS_MRET    2'd3
```

第三类是 CSR 操作和 trap cause：

```verilog
`define RV32I_CSR_OP_NONE 2'd0
`define RV32I_CSR_OP_RW   2'd1
`define RV32I_CSR_OP_RS   2'd2

`define RV32I_TRAP_CAUSE_ILLEGAL 32'd2
`define RV32I_TRAP_CAUSE_EBREAK  32'd3
`define RV32I_TRAP_CAUSE_ECALL   32'd11
```

这样 decoder 和 pipeline core 不需要到处写裸数字，后面看波形也更容易对应。

### 12.3 Decoder 怎么改

`rv32i_decoder.v` 新增了三个输出：

```verilog
output reg [1:0] csr_op,
output reg [1:0] system_op,
output reg       system_mret,
```

原来只有 `system_ecall/system_ebreak`。现在 decoder 会同时告诉后级：

```text
这是不是 SYSTEM 指令
这是 ecall、ebreak 还是 mret
这是 CSR 读写还是普通 SYSTEM 事件
CSR 地址是多少
```

`funct3 == 3'b000` 时识别三条特殊 SYSTEM 指令：

```text
0x00000073 -> ecall
0x00100073 -> ebreak
0x30200073 -> mret
```

`funct3 == 3'b001` 时识别 `csrrw`：

```text
old = CSR[csr]
rd  = old
CSR[csr] = rs1
```

当前允许写的 CSR 是：

```text
mtvec
mepc
mcause
```

`funct3 == 3'b010` 时识别 `csrrs`：

```text
old = CSR[csr]
rd  = old
if rs1 != x0:
  CSR[csr] = old | rs1
```

这里保留了原来的 `csrrs rd, cycle, x0`。`cycle` 是只读 CSR，所以当前只允许 `rs1=x0` 纯读；如果想写 `cycle`，decoder 会判成非法指令。

### 12.4 CSR 状态和流水寄存器怎么分工

现在 CSR 架构状态已经从主流水核里拆出来，集中放在：

```text
rtl/core/rv32i_pipe_csr.v
```

这个模块最初保存三个 machine CSR 状态寄存器，后续 timer interrupt 阶段又补了最小 interrupt CSR 状态：

```verilog
reg [31:0] csr_mtvec_q;
reg [31:0] csr_mepc_q;
reg [31:0] csr_mcause_q;
reg [31:0] csr_mstatus_q;  // only MIE/MPIE are implemented
reg [31:0] csr_mie_q;      // only MTIE is implemented
```

`mip.MTIP` 当前不单独保存，由外部 `timer_irq` 输入实时反映。

reset 后：

```text
mtvec  = 0x00000100
mepc   = 0
mcause = 0
mstatus = 0
mie     = 0
```

`rv32i_pipe_core.v` 不再直接维护这些 CSR 状态，它只负责把流水线里的信息送给 CSR 模块。

CSR 和 SYSTEM 信息仍然会被一路放进主流水寄存器：

```text
ID/EX:
  id_ex_csr_addr_q
  id_ex_csr_op_q
  id_ex_system_ecall_q
  id_ex_system_ebreak_q
  id_ex_system_mret_q

EX/MEM:
  ex_mem_csr_rdata_q
  ex_mem_csr_wdata_q
  ex_mem_csr_addr_q
  ex_mem_csr_op_q
  ex_mem_csr_write_q
  ex_mem_system_ecall_q
  ex_mem_system_ebreak_q
  ex_mem_system_mret_q

MEM/WB:
  mem_wb_csr_rdata_q
  mem_wb_csr_wdata_q
  mem_wb_csr_addr_q
  mem_wb_csr_op_q
  mem_wb_csr_write_q
  mem_wb_system_ecall_q
  mem_wb_system_ebreak_q
  mem_wb_system_mret_q
```

这和普通指令把 `rd/wb_sel/alu_result` 一路带到 WB 是同一个思想：控制信息必须跟着那条指令走，直到 commit 点才能真正产生架构副作用。

### 12.5 CSR 读写怎么实现

CSR 读发生在 EX 阶段，但读逻辑在 `rv32i_pipe_csr.v` 里：

```verilog
assign ex_csr_rdata = (ex_csr_addr == `RV32I_CSR_MSTATUS) ? csr_mstatus_q :
                      (ex_csr_addr == `RV32I_CSR_MIE)     ? csr_mie_q :
                      (ex_csr_addr == `RV32I_CSR_MIP)     ? csr_mip_value :
                      (ex_csr_addr == `RV32I_CSR_CYCLE)   ? cycle_value :
                      (ex_csr_addr == `RV32I_CSR_MTVEC)  ? csr_mtvec_q :
                      (ex_csr_addr == `RV32I_CSR_MEPC)   ? csr_mepc_q :
                      (ex_csr_addr == `RV32I_CSR_MCAUSE) ? csr_mcause_q :
                                                           32'd0;
```

主流水核实例化时把 `id_ex_csr_addr_q` 接到 `ex_csr_addr`，把 `rv32i_perf_counter` 输出的 `perf_cycle_count` 接到 `cycle_value`。原因是 CSR 读值要作为 `rd` 的写回数据，所以需要进入后面的 EX/MEM、MEM/WB。

CSR 写不在 EX 做，而是在 MEM/WB commit 点做：

```verilog
assign commit_csr_write = commit_valid &&
                          !commit_illegal &&
                          commit_csr_write_req &&
                          !commit_redirect;
```

写入数据按 `csrrw/csrrs` 区分：

```verilog
assign commit_csr_write_data =
  (commit_csr_op == `RV32I_CSR_OP_RW) ? commit_csr_wdata :
  (commit_csr_op == `RV32I_CSR_OP_RS) ? (commit_csr_rdata | commit_csr_wdata) :
                                        commit_csr_rdata;
```

这体现了一个很重要的原则：CSR 也是架构状态，不能在错误路径上提前修改。

### 12.6 Trap 是怎么触发的

trap 只在 MEM/WB commit 点触发：

```verilog
assign commit_trap = commit_valid &&
                     (commit_illegal ||
                      commit_ecall ||
                      commit_ebreak);
```

同步异常 trap 的 PC 来自当前 commit 指令：

```verilog
assign commit_pc = commit_pc4 - 32'd4;
```

当前只支持 32-bit 指令，所以可以用 `pc4 - 4` 还原原始 PC。后续如果支持压缩指令，应该直接在流水寄存器里保存原始 PC。

trap cause 选择：

```verilog
assign commit_trap_cause = commit_illegal ? `RV32I_TRAP_CAUSE_ILLEGAL :
                           commit_ebreak  ? `RV32I_TRAP_CAUSE_EBREAK :
                                            `RV32I_TRAP_CAUSE_ECALL;
```

trap 发生时：

```verilog
csr_mepc_q   <= commit_pc;
csr_mcause_q <= commit_trap_cause;
commit_redirect_pc = csr_mtvec_q & ~32'd3;
```

也就是：

```text
mepc   保存异常指令 PC
mcause 保存异常原因
core 收到 commit_redirect 后让 PC 跳到 mtvec
```

timer interrupt 阶段复用了这条 redirect 机制，但 `mcause=0x80000007`，`mepc` 保存当前普通指令提交后的下一条 PC。详细说明见 `docs/architecture/RV32I_TIMER.md`。

### 12.7 MRET 是怎么返回的

`mret` 也在 MEM/WB commit 点处理：

```verilog
assign commit_mret_taken = commit_valid &&
                           !commit_illegal &&
                           commit_mret;
```

`mret` 的 redirect PC 是：

```verilog
assign commit_redirect_pc = commit_trap ? (csr_mtvec_q & ~32'd3) :
                                          (csr_mepc_q & ~32'd3);
```

所以 handler 里如果想跳过 `ecall` 或非法指令，需要软件自己执行：

```asm
csrrs x7, mepc, x0
addi  x7, x7, 4
csrrw x0, mepc, x7
mret
```

硬件的 `mret` 不会自动 `mepc + 4`。

### 12.8 Flush 和 stall 优先级怎么改

这次最关键的控制优先级是：

```text
reset
commit_redirect
mem_stall
ex_redirect
load_use_stall
normal advance
```

其中：

```text
commit_redirect = commit_trap || commit_mret_taken
```

也就是说，只要老指令在 commit 点触发 trap 或 mret，就优先处理它，不能让更年轻的 memory stall、branch redirect 或 load-use stall 抢优先级。

commit redirect 发生时会清空：

```text
IF/ID
ID/EX
EX/MEM
MEM/WB
```

清掉 `MEM/WB` 是为了避免同一个 trap 在下一拍再次触发。

### 12.9 为什么要屏蔽年轻 store

精确异常最怕的一件事是：老指令已经 trap 了，年轻 store 还把 memory 改了。

所以这次把 data memory 请求改成：

```verilog
assign dmem_valid = mem_access_valid && !commit_redirect;
```

当 commit 点发生 trap 或 mret 时，即使 EX/MEM 里有年轻 load/store，也不会真正向 data memory 发起有效请求。

这就是 testbench 里 `pre_store=0` 的来源：`ecall` 后面的 `sw x1, 20(x0)` 在 trap 当拍被杀掉，handler 先读 memory，看到的还是 0。

### 12.10 Testbench 怎么验证

新增 testbench：

```text
sim/testcases/rv32i_trap_csr_tb.sv
```

主程序大致是：

```asm
addi  x1, x0, 99
addi  x5, x0, 0x140
csrrw x0, mtvec, x5
ecall
sw    x1, 20(x0)
addi  x10, x0, 1
32'h00000000          // illegal instruction
addi  x11, x0, 1
ebreak
```

trap handler 放在 `0x140`，故意不用默认 `0x100`，这样可以证明 `csrrw x0, mtvec, x5` 真的写成功。

handler 大致是：

```asm
csrrs x6, mcause, x0
csrrs x7, mepc, x0
slli  x8, x6, 2
lw    x9, 20(x0)
sw    x6, 40(x8)
sw    x7, 80(x8)
sw    x9, 120(x8)
addi  x7, x7, 4
csrrw x0, mepc, x7
mret
```

这里用 `x8 = mcause << 2` 做偏移，把不同 trap 的结果存到不同 memory 位置：

```text
ecall  cause=11:
  dmem[21] = mcause = 11
  dmem[31] = mepc   = 0x0000000c
  dmem[41] = trap 前读取 dmem[5] 的值 = 0

illegal cause=2:
  dmem[12] = mcause = 2
  dmem[22] = mepc   = 0x00000018
  dmem[32] = trap 前读取 dmem[5] 的值 = 99
```

仿真结果：

```text
[PASS] rv32i_trap_csr_tb
  pc=0x00000140 cycle=49 instret=28
  stall_cycle=0 flush_cycle=0
  ecall: mcause=11 mepc=0x0000000c pre_store=0x00000000
  illegal: mcause=2 mepc=0x00000018 pre_store=0x00000063
  mret resumed main after ECALL and illegal traps
```

这说明：

- `ecall` 正确进入 trap，`mcause=11`。
- `ecall` 的 `mepc=0x0c`，也就是 `ecall` 自己的 PC。
- `ecall` 后面的年轻 store 没有在 trap 前写 memory，所以 `pre_store=0`。
- handler 修改 `mepc=mepc+4` 后，`mret` 回到主程序继续执行。
- 返回后 `sw x1, 20(x0)` 正常执行，所以后续 illegal trap 里读到 `pre_store=0x63`。
- illegal instruction 正确进入 trap，`mcause=2`，`mepc=0x18`。
- 最后的 `ebreak` 也会进入 trap，所以最终 PC 停在 `mtvec=0x140`。

### 12.11 原流水线回归结果

原来的流水线 testbench 也通过：

```text
[PASS] rv32i_pipe_core_tb
  pc=0x00000100 cycle=57 instret=33
  stall_cycle=14 flush_cycle=3
  forwarding, load-use stall, instruction/data memory wait-state, control flush and perf counters passed
```

这里最终 `pc=0x100` 是正常的。因为原 testbench 最后用 `ebreak` 作为结束标记；现在 `ebreak` 已经是真 trap，会跳到默认 `mtvec=0x100`。

### 12.12 这次为什么把 CSR/trap 拆出去

`rv32i_pipe_core.v` 在加入 trap/CSR 后一度超过 700 行，如果继续把所有功能都塞在一个文件里，读代码会很吃力。工业级 CPU 一般也会按职责拆模块：流水控制、执行单元、CSR/异常、LSU、取指、分支预测、性能计数器通常都有清晰边界。

第一刀先拆 CSR/trap。原因是它有独立的架构状态，也有清楚的输入输出边界。

第二刀已经继续拆出 LSU，也就是 load/store unit。原因是 load/store 的 byte lane、符号扩展、`dmem_valid/wstrb` 和 memory wait-state 逻辑本身也很独立，不应该一直压在主流水核里。

第三刀继续拆出 hazard/forwarding unit。原因是 forwarding、WB bypass、load-use stall 都是在回答同一个问题：当前这条指令应该用哪里来的操作数，以及流水线要不要停一拍。

拆分后的读代码顺序可以这样看：

```text
rv32i_pipe_core.v
  负责五级流水主体：
  IF/ID、ID/EX、EX/MEM、MEM/WB 流水寄存器
  forwarding、load-use stall、指令/数据存储器等待停顿
  branch/jump flush
  writeback 和性能计数

rv32i_pipe_csr.v
  负责 CSR/trap 架构状态：
  mtvec/mepc/mcause
  cycle CSR 读通路
  csrrw/csrrs commit 写入
  ecall/ebreak/illegal trap
  mret 返回
  commit redirect PC
  debug trap 脉冲

rv32i_pipe_lsu.v
  负责 load/store：
  dmem_valid/write/addr/wdata/wstrb
  lb/lh/lw/lbu/lhu 的 load 数据扩展
  sb/sh/sw 的 store 数据复制和 byte enable
  dmem_ready=0 时产生 mem_stall

rv32i_pipe_hazard.v
  负责 hazard 和 forwarding：
  load-use stall
  ID 阶段 WB bypass
  EX/MEM 到 EX 的 forwarding
  MEM/WB 到 EX 的 forwarding
```

主 core 和 CSR 模块之间主要靠两类信号连接：

```text
EX 阶段 CSR 读：
  core -> csr: id_ex_csr_addr_q
  csr  -> core: ex_csr_rdata

MEM/WB commit 阶段：
  core -> csr: mem_wb_valid_q、mem_wb_pc4_q、illegal/ecall/ebreak/mret、CSR 写请求
  csr  -> core: commit_redirect、commit_redirect_pc、debug trap pulse
```

这样拆完以后，主流水核读起来更像“数据怎么在流水线里走”，CSR 文件读起来更像“异常和 CSR 架构状态怎么更新”，LSU 文件读起来更像“访存端口怎么形成、load/store 数据怎么对齐”，hazard 文件读起来更像“什么时候停、什么时候旁路、操作数从哪里来”。

后面如果继续拆，比较自然的方向是：

- 把 branch/jump redirect 目标计算拆成 `rv32i_pipe_branch.v`。
- 把性能计数器拆成 `rv32i_pipe_perf.v`。

## 13. 后续扩展

本阶段完成后，可以继续扩展：

- external interrupt。
- 非对齐访问异常。
- CSR 指令完整支持 `csrrc/csrrwi/csrrsi/csrrci`。
- trap 相关性能计数器。

到这一步，CPU 就不仅能执行普通程序，还具备了最基础的异常处理框架。这个点很适合放进项目汇报和面试讲解里。
