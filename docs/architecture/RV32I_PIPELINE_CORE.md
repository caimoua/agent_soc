# RV32I 五级流水线 Core 说明

## 1. 当前目标

这次新增的是 `rv32i_pipe_core.v`，它是单周期 `rv32i_core.v` 的五级流水线版本雏形。

当前目标不是一次性做完整高性能流水线，而是先完成最小可跑通骨架：

```text
IF -> ID -> EX -> MEM -> WB
```

当前版本已经完成六个步骤：

1. 搭好五级流水线骨架，具备 IF/ID、ID/EX、EX/MEM、MEM/WB 四组流水寄存器。
2. 加入 EX 阶段 forwarding，可以处理大部分 ALU 类背靠背数据相关。
3. 加入 load-use stall，可以处理 `lw/lb/lh/lbu/lhu` 后面紧跟使用结果的情况。
4. 加入 branch/jump flush，可以在跳转成立时清掉错误路径上的年轻指令。
5. 加入 debug 性能计数器，可以观察退休指令数、stall 次数和 flush 次数。
6. 加入指令/数据存储器等待停顿，可以在 `imem_ready=0` 或 `dmem_ready=0` 时暂停对应流水推进，等待取指或访存完成。

这样做的好处是：

- 保留 `rv32i_core.v` 作为稳定的单周期 baseline。
- 新增 `rv32i_pipe_core.v` 专门用于流水线迭代。
- 先确认流水寄存器、写回时序和 PC 顺序推进是正确的。
- 再加入 forwarding，处理常见数据冒险。
- 后续继续加入异常、trap 机制和更完整的总线封装。

## 2. 五级流水线每一级做什么

### IF：取指

IF 阶段保存当前 PC，并向 instruction memory 发出取指地址：

```text
imem_addr = pc_q
pc_q      = pc_q + 4
```

正常情况下 PC 每拍顺序加 4。遇到 load-use hazard 时，PC 会冻结一拍，让前面的 load 先往后走。遇到指令存储器 wait-state 时，PC 和 IF/ID 保持不动，同时往 ID/EX 插入 bubble，等 `imem_ready=1` 后再继续取指。遇到数据存储器 wait-state 时，流水线会一直冻结到 `dmem_ready=1`。遇到 branch/jump redirect 时，PC 会改成 EX 阶段算出的目标地址。

取到的指令和 PC 会进入 `IF/ID` 流水寄存器：

```verilog
if_id_valid_q
if_id_pc_q
if_id_pc4_q
if_id_instr_q
```

### ID：译码和读寄存器

ID 阶段复用已有模块：

```text
rv32i_decoder
rv32i_imm_gen
rv32i_regfile read port
```

它从 `if_id_instr_q` 中解析：

- `rs1/rs2/rd`
- ALU 控制信号
- 写回选择 `wb_sel`
- load/store 控制信号
- CSR/SYSTEM 控制信号
- 立即数
- 寄存器读数据

这些内容会进入 `ID/EX` 流水寄存器。

### EX：执行

EX 阶段做 ALU 运算。现在 ALU 的 `rs1/rs2` 会先经过 forwarding 选择，所以真正输入 ALU 的不是最初 ID 阶段读出来的旧值，而是 `forward_rs1_data/forward_rs2_data`：

```verilog
ex_alu_src_b = id_ex_alu_src_imm_q ? id_ex_imm_i_q : forward_rs2_data;
```

也就是说：

- R-type 使用 `rs2_data`
- I-type 使用 `imm_i`

store 地址在 EX 阶段计算：

```verilog
ex_mem_addr = id_ex_mem_write_q ? (forward_rs1_data + id_ex_imm_s_q)
                                : ex_alu_result;
```

CSR 读数据也在 EX 阶段取样：

```verilog
ex_csr_rdata = (id_ex_csr_addr_q == `RV32I_CSR_CYCLE) ? perf_cycle_count : 32'd0;
```

EX 阶段的结果进入 `EX/MEM` 流水寄存器。

branch/jump 也在 EX 阶段解析：

```text
JAL    -> pc + imm_j
JALR   -> (rs1 + imm_i) & ~1
BRANCH -> taken 时 pc + imm_b，否则继续顺序执行
```

一旦 EX 阶段发现需要 redirect，就会 flush IF/ID 和 ID/EX 中已经误取的年轻指令。

### MEM：访存

MEM 阶段负责 data memory 访问。

store 使用：

- `dmem_addr`
- `dmem_wdata`
- `dmem_wstrb`

load 使用：

- `dmem_rdata`
- `mem_size`
- `mem_unsigned`

当前 load/store 的 byte、halfword、word 对齐和符号扩展逻辑基本沿用了单周期版本。

如果 `dmem_ready=1`，MEM 阶段结果进入 `MEM/WB` 流水寄存器。如果 `dmem_ready=0`，说明外部 memory 暂时没有接受这次访问，流水线会保持当前状态，直到 ready 回来。

### WB：写回

WB 阶段根据 `wb_sel` 选择写回数据：

```text
WB_ALU    -> ALU 结果
WB_LUI    -> imm_u
WB_AUIPC  -> pc + imm_u
WB_PC4    -> pc + 4
WB_MEM    -> load data
WB_CSR    -> CSR read data
```

当前 `AUIPC` 在 WB 阶段使用：

```verilog
(mem_wb_pc4_q - 32'd4) + mem_wb_imm_u_q
```

原因是 `mem_wb_pc4_q` 保存的是这条指令的 `pc + 4`，所以减 4 可以还原这条指令自己的 PC。

最终写寄存器的条件是：

```verilog
wb_reg_we = mem_wb_valid_q && mem_wb_reg_we_q && !mem_wb_illegal_q;
```

这样只有有效、合法、需要写回的指令才会修改寄存器堆。

## 3. 四组流水寄存器

五级流水线的关键是这四组寄存器：

```text
IF/ID
ID/EX
EX/MEM
MEM/WB
```

它们的作用是把每一级的“数据”和“控制信号”都保存下来，下一拍交给下一级。

### IF/ID 保存

```text
valid
pc
pc + 4
instr
```

### ID/EX 保存

```text
valid
pc
pc + 4
rs1/rs2/rd 地址
rs1/rs2 读数据
imm_i / imm_s / imm_u
ALU 控制
写回控制
访存控制
CSR/SYSTEM 控制
illegal 标志
```

### EX/MEM 保存

```text
valid
pc + 4
rd 地址
ALU 结果
store 数据
memory 地址
imm_u
CSR 读数据
写回控制
访存控制
CSR/SYSTEM 控制
illegal 标志
```

### MEM/WB 保存

```text
valid
pc + 4
rd 地址
ALU 结果
load 数据
imm_u
CSR 读数据
写回控制
CSR/SYSTEM 控制
illegal 标志
```

## 4. Forwarding 怎么实现

流水线里，多条指令同时处在不同阶段。如果后一条指令马上使用前一条指令的结果，就会出现数据冒险。

例如：

```asm
addi x1, x0, 5
add  x3, x1, x2
```

第二条 `add` 在 ID 阶段读 `x1` 的时候，第一条 `addi` 还没有到 WB 阶段写回，所以它会读到旧值。

forwarding 的思路是：EX 阶段真正使用操作数之前，再看后面的流水级有没有更新的结果。如果有，就直接从后面的流水级旁路回来。

当前实现了两路旁路来源：

```text
EX/MEM -> EX
MEM/WB -> EX
```

另外还补了一条很小但很重要的同拍旁路：

```text
WB -> ID
```

它解决的是“WB 阶段这一拍正在写寄存器，而 ID 阶段这一拍正好读同一个寄存器”的情况。

例如：

```asm
addi x1, x0, 5
addi x2, x0, 7
add  x3, x1, x2
sub  x4, x3, x1
```

`sub` 进入 ID 的那一拍，`addi x1` 可能正好在 WB 写回。如果寄存器堆没有建模成“前半拍写、后半拍读”的 write-first 行为，ID 阶段直接读 regfile 可能仍然读到旧的 `x1`。所以当前在 ID 阶段加入：

```verilog
assign id_rs1_data_bypass = (wb_reg_we &&
                             (mem_wb_rd_addr_q != 5'd0) &&
                             (mem_wb_rd_addr_q == id_rs1_addr)) ? wb_wdata :
                                                                   id_rs1_data;
```

`rs2` 同理。这样 ID/EX 捕获的源操作数会优先使用这一拍 WB 正在写回的新值。

### EX/MEM forwarding

如果上一条指令已经在 EX/MEM 阶段，而且它要写回的 `rd` 正好等于当前 EX 阶段指令的 `rs1` 或 `rs2`，就可以从 EX/MEM 直接拿结果。

判断条件是：

```text
ex_mem_valid_q == 1
ex_mem_reg_we_q == 1
ex_mem_illegal_q == 0
ex_mem_rd_addr_q != x0
ex_mem_rd_addr_q == id_ex_rs1_addr_q 或 id_ex_rs2_addr_q
ex_mem_wb_sel_q != WB_MEM
```

最后一个条件很重要：load 指令不能从 EX/MEM 转发。因为 load 数据要到 MEM 阶段读完 memory 才知道，EX/MEM 这时还没有真正的 load data。

EX/MEM 能转发的数据由 `ex_mem_forward_data` 选择：

```text
LUI      -> imm_u
AUIPC    -> pc + imm_u
JAL/JALR -> pc + 4
CSR      -> csr_rdata
ALU      -> alu_result
```

### MEM/WB forwarding

如果结果已经到了 MEM/WB 阶段，说明最终写回数据已经由 `wb_wdata` 算好了，所以 MEM/WB forwarding 可以直接转发 `wb_wdata`。

判断条件是：

```text
mem_wb_valid_q == 1
mem_wb_reg_we_q == 1
mem_wb_illegal_q == 0
mem_wb_rd_addr_q != x0
mem_wb_rd_addr_q == id_ex_rs1_addr_q 或 id_ex_rs2_addr_q
```

### 为什么 EX/MEM 优先级更高

如果连续两条指令都写同一个寄存器：

```asm
addi x9, x0, 1
addi x9, x9, 2
add  x10, x9, x0
```

第三条 `add` 应该看到最新的 `x9 = 3`，而不是更早的 `x9 = 1`。最新结果在 EX/MEM，因此选择优先级是：

```text
EX/MEM 优先
MEM/WB 次之
原始 regfile 读数最后
```

最终 EX 阶段看到的操作数是：

```text
forward_rs1_data
forward_rs2_data
```

ALU 使用 forwarding 后的 `rs1` 和 `rs2/imm`。store 地址使用 forwarding 后的 `rs1`，store 写数据也使用 forwarding 后的 `rs2`。

## 5. Load-use stall 怎么实现

forwarding 不能解决所有数据冒险。最典型的例子是：

```asm
lw   x13, 0(x0)
add  x14, x13, x2
```

`add` 紧跟在 `lw` 后面使用 `x13`。问题在于：

```text
lw 的数据要到 MEM 阶段读完 data memory 才知道
add 在 EX 阶段开头就要使用 x13
```

所以这时单靠 EX/MEM forwarding 不够，因为 load 指令在 EX/MEM 阶段还没有真正的 load data。解决方法是停一拍：

```text
PC     保持不变
IF/ID  保持不变，也就是 add 继续留在 ID 阶段
ID/EX  插入 bubble，让 EX 阶段空转一拍
load   继续从 EX 前进到 MEM
```

下一拍 `add` 再进入 EX 时，`lw` 已经到了 MEM/WB，load data 可以通过 MEM/WB forwarding 送回 EX。

当前 RTL 的检测条件可以理解成：

```text
如果 ID/EX 里是一条有效 load 指令
并且它会写 rd
并且 rd 不是 x0
并且 IF/ID 里的当前指令真的要读 rs1 或 rs2
并且 rs1/rs2 等于这条 load 的 rd
那么产生 load_use_stall
```

对应代码核心是：

```verilog
assign load_use_stall = if_id_valid_q &&
                        id_ex_valid_q &&
                        id_ex_mem_valid_q &&
                        !id_ex_mem_write_q &&
                        id_ex_reg_we_q &&
                        !id_ex_illegal_q &&
                        (id_ex_rd_addr_q != 5'd0) &&
                        ((id_uses_rs1 && (id_ex_rd_addr_q == id_rs1_addr)) ||
                         (id_uses_rs2 && (id_ex_rd_addr_q == id_rs2_addr)));
```

这里 `id_uses_rs1/id_uses_rs2` 是为了避免对不使用源寄存器的指令误判。例如 `lui` 没有 `rs1/rs2`，即使指令编码里的某些 bit 恰好等于前面 load 的 `rd`，也不应该产生 stall。

stall 发生时，前端这样处理：

```text
PC 和 IF/ID 不更新
ID/EX 写入一条无效 bubble
EX/MEM 和 MEM/WB 继续正常前进
```

这个操作本质上是在 load 和使用者之间自动插入一个空拍。

## 6. Memory wait-state stall 怎么实现

load-use stall 解决的是“前一条 load 的数据还没到，后一条指令已经要用”的数据冒险。memory wait-state stall 解决的是另一个问题：指令存储器或数据存储器还没有准备好，CPU 不能假装已经拿到了指令或数据。

指令存储器接口现在也有 ready：

```text
imem_valid  CPU 发起取指
imem_ready  指令存储器本拍返回的 imem_rdata 有效
```

当 `imem_ready=0` 时，RTL 产生：

```verilog
assign if_stall = imem_valid && !imem_ready;
```

这个 stall 只卡住前端：

```text
PC 和 IF/ID 保持不变
ID/EX 写入 bubble
EX/MEM 和 MEM/WB 继续往后走
```

这样做的效果是：取指没 ready 时，前端不会把无效 `imem_rdata` 当成真指令送进流水线；后端已有的老指令仍然可以继续退休。

当前 data memory 接口有一个握手信号：

```text
dmem_valid  CPU 发起一次访存
dmem_ready  memory 接受这次访存，load 数据也在这一拍有效
```

当 MEM 阶段有一条有效访存指令，并且 `dmem_ready=0` 时，RTL 产生：

```verilog
assign mem_stall = mem_access_valid && !dmem_ready;
```

这个 stall 是 blocking 的，也就是整条流水线冻结：

```text
PC      保持不变
IF/ID   保持不变
ID/EX   保持不变
EX/MEM  保持不变
MEM/WB  保持不变
```

为什么要连 `EX/MEM` 都冻结？因为当前正在 MEM 阶段等待的那条 load/store 就保存在 `EX/MEM` 里。如果不冻结，下一条指令会覆盖这组访存地址、写数据和控制信号，原来的 memory transaction 就丢了。

为什么 `MEM/WB` 也保持？这是为了让 stalled EX 阶段仍然可以看到 MEM/WB forwarding 的数据。比如 MEM 阶段被一个 load 卡住时，EX 阶段可能正好有一条年轻指令需要从 MEM/WB 旁路一个更老的结果；如果 stall 期间把 MEM/WB 清掉，这条旁路数据就消失了。

访存完成时，也就是 `dmem_ready=1` 的那一拍：

```text
load  数据从 dmem_rdata 进入 MEM/WB
store 被外部 memory 接受
流水线恢复推进
```

当前实现的是最保守、最容易验证的 blocking memory stall。它不支持多个 outstanding transaction，也没有 store buffer 或 non-blocking cache。优点是行为非常清楚：只要 data memory 没 ready，流水线就原地等。

## 7. Branch/jump flush 怎么实现

当前流水线默认按顺序取指，也就是先假设下一条 PC 是 `pc + 4`。但是遇到下面这些控制流指令时，真实下一条 PC 可能不是顺序地址：

```asm
jal
jalr
beq/bne/blt/bge/bltu/bgeu
```

这一版把控制流解析放在 EX 阶段。原因是 EX 阶段已经能拿到 forwarding 后的 `rs1/rs2`，可以正确判断 branch 条件，也可以正确计算 `jalr` 目标地址。

核心信号是：

```verilog
assign ex_redirect = id_ex_valid_q &&
                     !id_ex_illegal_q &&
                     ((id_ex_pc_sel_q == `RV32I_PC_JAL) ||
                      (id_ex_pc_sel_q == `RV32I_PC_JALR) ||
                      ((id_ex_pc_sel_q == `RV32I_PC_BRANCH) && ex_branch_taken));
```

含义是：

```text
当前 EX 阶段这条指令有效
并且不是非法指令
并且它是 JAL/JALR，或者它是 taken branch
那么需要 redirect
```

目标地址由指令类型决定：

```verilog
assign ex_redirect_pc = (id_ex_pc_sel_q == `RV32I_PC_JAL)  ? (id_ex_pc_q + id_ex_imm_j_q) :
                        (id_ex_pc_sel_q == `RV32I_PC_JALR) ? ((forward_rs1_data + id_ex_imm_i_q) & ~32'd1) :
                                                             (id_ex_pc_q + id_ex_imm_b_q);
```

redirect 发生时，流水线做三件事：

```text
PC      <= ex_redirect_pc
IF/ID   <= bubble
ID/EX   <= bubble
```

为什么要清 IF/ID 和 ID/EX？因为当 branch/jump 在 EX 阶段才知道目标时，后面两条顺序路径指令可能已经分别进入 ID 和 IF 了。它们属于错误路径，不能继续执行，更不能写寄存器或写内存。

当前 EX 阶段这条 branch/jump 本身不会被清掉，它会继续进入 EX/MEM。对于 `jal/jalr`，这样才能正常把 `pc + 4` 写回 `rd`。

not-taken branch 不需要 flush，因为默认取指本来就是顺序 `pc + 4`。

## 8. 性能计数器

当前流水线 core 的 debug 性能计数器已经抽成独立模块：

```text
rtl/core/rv32i_perf_counter.v
```

`rv32i_pipe_core` 只负责生成事件脉冲，`rv32i_perf_counter` 负责寄存和累加计数值。当前主要 debug 计数器包括：

```text
dbg_cycle        core 运行周期数
dbg_instret      退休指令数
dbg_stall_cycle  流水线停顿周期数，包括 load-use、memory wait-state、mul/div wait 和 fetch discard
dbg_flush_cycle  控制流预测错误或 redirect 统计次数
dbg_branch_count B-type branch 解析/训练次数
dbg_branch_mispredict_count B-type branch 预测错误次数
```

`dbg_instret` 统计真正进入 WB/commit 位置的有效合法指令。错误路径上被 flush 掉的指令不会进入退休点，所以不会被计入。

当前 `rv32i_pipe_core` 生成的 `instret_event` 条件可以理解为：

```verilog
ex_mem_valid_q &&
!ex_mem_illegal_q &&
!ex_mem_instr_addr_misaligned_q &&
!ex_mem_instr_fault_q &&
!mem_stall &&
!mem_load_addr_misaligned &&
!mem_load_fault &&
!mem_store_addr_misaligned &&
!mem_store_fault &&
!commit_redirect
```

这里用 `EX/MEM` 当前拍进入 `MEM/WB` 的指令来计数。加上 `!mem_stall` 是因为 memory wait-state 期间 `EX/MEM` 会保持不变，同一条访存指令不能被重复计入退休数。这样计数器和 `dbg_ebreak/dbg_ecall` 这类 WB 阶段事件在同一拍对齐，testbench 可以在看到 `ebreak` 时直接检查 `instret`。

`dbg_stall_cycle` 统计所有会让流水线停止推进的周期：

```verilog
load_use_stall || mem_stall || ex_muldiv_stall || if_stall || if_discard_q
```

其中 `load_use_stall` 来自数据相关，`if_stall` 来自指令存储器没有 ready，`mem_stall` 来自数据存储器没有 ready，`ex_muldiv_stall` 来自 RV32M 多周期执行单元等待结果，`if_discard_q` 来自 redirect 后丢弃旧取指响应的等待周期。

`dbg_flush_cycle` 统计控制流 redirect：

```verilog
ex_redirect && !mem_stall && !commit_redirect
```

加上 `!mem_stall` 是为了避免同一条 EX 阶段 redirect 指令在 memory stall 期间被重复统计。加上 `!commit_redirect` 是为了让 commit 阶段 trap/interrupt/mret redirect 保持更高优先级。

`dbg_branch_count` 和 `dbg_branch_mispredict_count` 来自 B-type branch 的 EX 阶段更新事件：

```text
branch_event = ex_branch_update
branch_mispredict_event = ex_branch_update && ex_prediction_mismatch
```

这三个计数器的意义不只是“多几个 debug 信号”，而是让流水线行为可以量化。例如：

```text
CPI = cycle / instret
```

如果 `stall_cycle` 或 `flush_cycle` 很高，就说明程序被 load-use、memory wait-state 或控制冒险拖慢了。后面做分支预测、cache 或总线优化时，这些计数器可以直接用来做对比。

## 9. 当前 Testbench

新增 testbench：

```text
sim/testcases/rv32i_pipe_core_tb.sv
```

当前程序已经不再依赖 `nop` 避开 ALU 数据冒险，而是直接验证 forwarding、load-use stall、指令/数据存储器等待停顿和 branch/jump flush：

```asm
addi  x1, x0, 5
addi  x2, x0, 7
add   x3, x1, x2
sub   x4, x3, x1
add   x5, x4, x3
xori  x6, x5, 15
or    x7, x6, x5
and   x8, x7, x6
sw    x8, 0(x0)
addi  x9, x0, 1
addi  x9, x9, 2
add   x10, x9, x0
lui   x11, 0x12345
auipc x12, 0x1
lw    x13, 0(x0)
add   x14, x13, x2
lw    x15, 0(x0)
add   x16, x2, x15
lw    x17, 0(x0)
sw    x17, 4(x0)
lw    x18, 0(x0)
sw    x2, 0(x18)
addi  x19, x0, 0
beq   x1, x2, +8
addi  x19, x19, 1
bne   x1, x2, +8
addi  x19, x19, 1024
addi  x19, x19, 2
jal   x20, +8
addi  x19, x19, 1024
addi  x19, x19, 4
addi  x21, x0, 0x88
jalr  x22, x21, 0
addi  x19, x19, 1024
addi  x19, x19, 8
ebreak
```

期望结果：

```text
x1 = 5
x2 = 7
x3 = 12
x4 = 7
x5 = 19
x6 = 28
x7 = 31
x8 = 28
x9 = 3
x10 = 3
x11 = 0x12345000
x12 = 0x00001034
dmem[0] = 28
x13 = 28
x14 = 35
x15 = 28
x16 = 35
x17 = 28
x18 = 28
dmem[1] = 28
dmem[7] = 7
x19 = 15
x20 = 0x00000074
x21 = 0x00000088
x22 = 0x00000084
instret = 33
stall_cycle = 16
flush_cycle = 2
```

`x12` 的值来自 `auipc x12, 0x1`：

```text
imem[13] 的 PC = 13 * 4 = 0x34
imm_u = 0x00001000
x12 = 0x00000034 + 0x00001000 = 0x00001034
```

其中 `x19` 是 control-flow score。正确路径只会加：

```text
1 + 2 + 4 + 8 = 15
```

错误路径上的指令会加 `1024`。如果 flush 没有生效，`x19` 就会立刻不等于 15。

程序末尾用 `ebreak` 作为结束标记。testbench 等到 `ebreak` 退休后再检查计数器，因此 `instret` 不会继续把后面的默认 NOP 算进去。

`instret = 33` 的含义是：从 `imem[0]` 到 `ebreak` 一共有 36 条静态指令，其中 3 条错误路径指令被 flush，不会退休，所以真正退休：

```text
36 - 3 = 33
```

`stall_cycle = 16` 由四部分组成：

```text
4 个 load-use stall
3 个指令存储器 wait-state stall
7 个数据存储器 wait-state stall
2 个 redirect 后 discard 旧取指响应的 stall
```

四个直接 load-use 场景是：

```text
lw -> add 使用 rs1
lw -> add 使用 rs2
lw -> sw  使用 store data rs2
lw -> sw  使用 store address rs1
```

testbench 里的指令存储器模型会在三个正确路径取指地址上各等待一拍：

```text
PC = 0x10
PC = 0x38
PC = 0x88
```

所以指令存储器 wait-state 贡献 3 个 stall 周期。

testbench 里的数据存储器模型会让每次 load/store 先等待一拍再拉高 `dmem_ready`，而这段程序一共有 7 次有效数据存储器访问：

```text
sw x8, 0(x0)
lw x13, 0(x0)
lw x15, 0(x0)
lw x17, 0(x0)
sw x17, 4(x0)
lw x18, 0(x0)
sw x2, 0(x18)
```

所以数据存储器 wait-state 贡献 7 个 stall 周期。当前分支预测打开后，redirect 后还会通过 `if_discard_q` 丢弃旧取指响应，贡献 2 个 stall 周期。总 stall 周期数是：

```text
4 + 3 + 7 + 2 = 16
```

`flush_cycle = 2` 对应两次预测错误 redirect：

```text
bne taken
jalr
```

`jal` 目标已对齐，会在 IF 阶段被预测 taken，因此不会再计入 `flush_cycle`。

## 10. 模块拆分进展

随着流水线功能变多，`rv32i_pipe_core.v` 不能一直无限长下去。现在已经开始按职责拆模块：

```text
rv32i_pipe_core.v
  五级流水主体：
  IF/ID、ID/EX、EX/MEM、MEM/WB 流水寄存器
  forwarding、load-use stall、flush 优先级
  PC 更新、writeback、性能事件生成

rv32i_perf_counter.v
  性能计数器：
  cycle/instret/stall/flush/branch/mispredict

rv32i_pipe_csr.v
  machine CSR 和 trap：
  mtvec/mepc/mcause
  CSR 读写
  ecall/ebreak/illegal trap
  mret 返回
  commit redirect

rv32i_pipe_lsu.v
  load/store unit：
  dmem_valid/write/addr/wdata/wstrb
  byte/halfword/word store byte enable
  lb/lh/lw/lbu/lhu 的符号扩展或零扩展
  指令/数据存储器等待停顿

rv32i_pipe_hazard.v
  hazard/forwarding unit：
  load-use stall 判断
  ID 阶段 WB bypass
  EX 阶段 EX/MEM forwarding
  EX 阶段 MEM/WB forwarding
```

其中 LSU 的输入来自 `EX/MEM` 流水寄存器：

```text
ex_mem_mem_valid_q
ex_mem_mem_write_q
ex_mem_mem_size_q
ex_mem_mem_unsigned_q
ex_mem_mem_addr_q
ex_mem_store_data_q
```

LSU 输出给主流水核两个关键信号：

```text
mem_stall      // dmem_valid=1 且 dmem_ready=0 时拉高，冻结流水线
mem_load_data  // load 指令最终写回寄存器堆的数据
```

同时 LSU 直接驱动 data memory 端口：

```text
dmem_valid
dmem_write
dmem_addr
dmem_wdata
dmem_wstrb
```

这样拆完以后，主 core 里不再需要关心 byte lane 怎么选、`lb/lbu/lh/lhu` 怎么扩展、`sb/sh/sw` 的 `wstrb` 怎么生成；主 core 只需要知道“MEM 阶段是否要停”和“load 回来的数据是多少”。

hazard 拆出后，主 core 里也不再直接写大段 forwarding 判断。`rv32i_pipe_hazard.v` 的输出边界是：

```text
load_use_stall       // 需要在 load 和使用者之间插入一个 bubble
id_rs1_data_bypass   // ID 阶段读 rs1 后，如果 WB 同拍写同一个寄存器，就旁路 WB 数据
id_rs2_data_bypass   // ID 阶段读 rs2 后，如果 WB 同拍写同一个寄存器，就旁路 WB 数据
forward_rs1_data     // EX 阶段实际使用的 rs1 数据
forward_rs2_data     // EX 阶段实际使用的 rs2 数据
```

这里的 `forward_rs1_data/forward_rs2_data` 会优先选择 EX/MEM，再选择 MEM/WB，最后才使用 ID/EX 里原本缓存的寄存器读值。

## 11. 当前限制

这一版流水线还没有实现：

- 多 outstanding 访存、store buffer 或 non-blocking cache
- I-cache/D-cache miss refill 状态机

所以它现在能处理 ALU 类背靠背相关、load-use stall、指令/数据存储器等待停顿、基本控制流 flush，以及最小 trap/CSR 路径。后续还没有处理多 outstanding 访存、cache refill 等更完整的系统行为。

trap/CSR 的详细说明单独放在：

```text
docs/architecture/RV32I_TRAP_CSR.md
```

## 12. 下一步怎么迭代

建议下一步按这个顺序做：

1. 可以继续把 branch/jump redirect 目标计算拆成 `rv32i_pipe_branch.v`，或者先保持在主 core 里。
2. 加 branch/taken 计数器，或者进一步做简单分支预测器。
3. 做简单 I-cache/TCM wrapper，让 cache miss 通过 `imem_ready=0` 暂停前端。

这个顺序很适合学习和面试讲解：每一步都解决一个明确的流水线问题。
