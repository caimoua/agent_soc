# RV32I 工程化重构计划

最后更新：2026-05-19

本文记录当前 RV32I/RV32IM core 从“功能型原型代码”继续走向“更可维护工程代码”的重构路线。目标不是推翻已有实现，而是在保持 directed tests 持续通过的前提下，小步拆分 `rv32i_pipe_core`，降低后续扩展和调试成本。

## 总体判断

当前代码适合作为学习型、原型级 CPU core：

- 功能覆盖较完整，已经包含五级流水、hazard、cache、trap/CSR、中断、AHB-Lite、MMIO timer/UART、RV32M、静态和动态分支预测。
- 接口命名和流水线寄存器命名比较清楚。
- 已有较多 directed test 和项目状态文档，适合继续迭代。

但从严谨工程代码、可维护 IP、团队协作项目的标准看，还需要继续重构：

- `rv32i_pipe_core` 顶层承担过多功能。
- 主要时序 always 块过大。
- stall/flush 优先级和流水线寄存器更新仍和 core 顶层耦合较深。
- 缺少 assertion 和更细粒度模块级验证。

## 当前主要问题

### 1. `rv32i_pipe_core` 顶层过重

当前 core 顶层同时负责：

- PC 更新和 IF 取指
- BHT/BTB 分支预测
- 所有流水线寄存器
- M 扩展识别和乘除法单元调度
- ALU 输入选择和分支比较
- CSR/trap 调用
- LSU 调用
- 性能事件生成
- stall/flush 控制

短期内这很直观，但随着功能继续增加，review、调试和局部修改都会变难。

### 2. 大 always 块可维护性不足

现在主要时序逻辑集中在一个较大的 `always @(posedge clk or negedge rst_n)` 中。它同时处理 reset、BHT/BTB 更新、性能计数器、PC/IFID、IDEX、EXMEM、MEMWB。

后续更工程化的方向是拆成：

```text
PC / IFID always
IDEX always
EXMEM always
MEMWB always
performance counter always
branch predictor update always
```

### 3. 分支预测器已完成第一步抽离

当前动态预测器思路合理：

- direct-mapped BHT
- direct-mapped BTB
- 2-bit 饱和计数器
- IF 阶段预测
- EX 阶段更新
- `BRANCH_PRED_INDEX_BITS` 可配置

BHT/BTB 已抽成独立 `rv32i_branch_predictor`。后续如果继续工程化，可以再把 fetch token、预测统计和 pipeline control 边界整理得更薄。

### 4. RV32M 识别正在并入 decoder

重构前 M 扩展识别由 core 顶层额外判断：

```text
opcode == OP && funct7 == 0000001
```

然后在 core 中修正 `reg_we`、`wb_sel`、`illegal`。Phase 2 已把这部分并入 `rv32i_decoder`，由 decoder 统一输出：

```text
id_muldiv_valid
id_muldiv_op
id_reg_we
id_wb_sel
id_illegal
```

### 5. IF/memory 协议假设需要继续明确

当前 core/cache/bus 是 blocking、单 outstanding 风格。`if_discard_q` 可以处理 redirect 后旧取指返回，但它仍依赖顺序返回的简单存储模型。

短期目标不是改成复杂 outstanding fetch，而是在文档中明确：

- 无 outstanding transaction
- 无 burst
- redirect 后通过 discard 处理旧响应
- CPU 子系统通过 blocking cache/AHB-Lite master 接入系统

### 6. assertion 不足

现有验证主要依赖 directed test 和波形。后续应逐步补充断言，例如：

```systemverilog
ex_muldiv_stall 时 ID/EX 保持稳定
mem_stall 时 EX/MEM 保持稳定
commit_redirect 优先于 ex_redirect
flush 后 wrong-path 不写回
branch update 只发生在有效 B-type branch 上
```

## 推荐实施顺序

每一步都应保持“小步改动、小步验证”的节奏。新增 testbench 在用户给出 VCS PASS 前只标记为 `PENDING`。

### Phase 1：抽出分支预测器

新增：

```text
rtl/core/rv32i_branch_predictor.v
```

目标：

- 从 `rv32i_pipe_core` 移出 BHT、BTB、预测 PC 选择、BHT/BTB 更新、BTB/BHT debug 计数器。
- 保持 `BRANCH_PRED_INDEX_BITS` 参数。
- 保持默认 64 项行为不变。
- 保持现有 `JAL`、B-type branch、`JALR` 行为不变。

建议接口：

```text
IF 查询：
if_pc
if_instr
if_error
if_predicted_pc
if_predict_taken
if_btb_hit

EX 更新：
ex_update_valid
ex_pc
ex_taken
ex_target_pc
ex_fetch_btb_hit

Debug：
dbg_btb_hit_count
dbg_btb_miss_count
dbg_bht_update_count
```

验证重点：

```bash
make sim TB_FILE=./testcases/rv32i_branch_predictor_tb.sv TOP_NAME=rv32i_branch_predictor_tb
make sim TB_FILE=./testcases/rv32i_pipe_branch_predict_tb.sv TOP_NAME=rv32i_pipe_branch_predict_tb
make sim TB_FILE=./testcases/rv32i_pipe_dynamic_branch_predict_tb.sv TOP_NAME=rv32i_pipe_dynamic_branch_predict_tb
make sim TB_FILE=./testcases/rv32i_pipe_branch_predict_param_tb.sv TOP_NAME=rv32i_pipe_branch_predict_param_tb
make sim TB_FILE=./testcases/rv32i_pipe_core_tb.sv TOP_NAME=rv32i_pipe_core_tb
```

当前状态：

- `rv32i_branch_predictor.v` 已新增。
- `rv32i_pipe_core` 已改为实例化该模块。
- `rv32i_branch_predictor_tb` 已由用户确认 VCS PASS。
- 分支预测相关集成回归已由用户确认 VCS PASS。

### Phase 2：RV32M 识别并入 decoder

目标：

- `rv32i_decoder` 直接识别 M 扩展。
- core 顶层不再修正 decoder 的 illegal/reg_we/wb_sel。
- `rv32i_pipe_core` 只消费 decoder 输出的 `id_muldiv_valid` 和 `id_muldiv_op`。

验证重点：

```bash
make sim TB_FILE=./testcases/rv32i_decoder_muldiv_tb.sv TOP_NAME=rv32i_decoder_muldiv_tb
make sim TB_FILE=./testcases/rv32i_pipe_muldiv_tb.sv TOP_NAME=rv32i_pipe_muldiv_tb
make sim TB_FILE=./testcases/rv32i_pipe_core_tb.sv TOP_NAME=rv32i_pipe_core_tb
```

当前状态：

- `rv32i_decoder` 已新增 `ENABLE_M` 参数和 `muldiv_valid/muldiv_op` 输出。
- `rv32i_pipe_core` 已打开 `ENABLE_M=1`，并移除 core 顶层对 M 指令的 illegal/reg_we/wb_sel 补丁逻辑。
- 单周期 `rv32i_core` 使用默认 `ENABLE_M=0`，继续保持 RV32I-only baseline。
- `rv32i_decoder_muldiv_tb` 已由用户确认 VCS PASS。
- `rv32i_pipe_muldiv_tb` 和 `rv32i_pipe_core_tb` 已由用户确认 VCS 回归 PASS。

### Phase 3：抽出性能计数器

新增：

```text
rtl/core/rv32i_perf_counter.v
```

目标：

- 从 core 顶层移出 cycle、instret、stall、flush、branch、mispredict 计数器。
- core 顶层只提供事件脉冲。

建议输入：

```text
instret_event
stall_event
flush_event
branch_event
mispredict_event
```

验证重点：

```bash
make sim TB_FILE=./testcases/rv32i_perf_counter_tb.sv TOP_NAME=rv32i_perf_counter_tb
make sim TB_FILE=./testcases/rv32i_pipe_core_tb.sv TOP_NAME=rv32i_pipe_core_tb
make sim TB_FILE=./testcases/rv32i_pipe_branch_predict_tb.sv TOP_NAME=rv32i_pipe_branch_predict_tb
make sim TB_FILE=./testcases/rv32i_pipe_dynamic_branch_predict_tb.sv TOP_NAME=rv32i_pipe_dynamic_branch_predict_tb
make sim TB_FILE=./testcases/rv32i_pipe_branch_predict_param_tb.sv TOP_NAME=rv32i_pipe_branch_predict_param_tb
```

当前状态：

- `rv32i_perf_counter.v` 已新增。
- `rv32i_pipe_core` 已改为生成性能事件脉冲，并实例化 `rv32i_perf_counter`。
- `rv32i_perf_counter_tb` 已由用户确认 VCS PASS。
- 性能计数器抽出后的 `rv32i_pipe_core_tb`、静态/动态/参数化分支预测回归已由用户确认 VCS PASS。

### Phase 4：建立统一 pipeline control

新增：

```text
rtl/core/rv32i_pipe_ctrl.v
```

目标：

- 显式管理 `commit_redirect`、`ex_redirect`、`mem_stall`、`ex_muldiv_stall`、`load_use_stall`、`if_stall`、`if_discard` 的优先级。
- 输出统一的 advance/bubble/flush 控制信号。

当前输出：

```text
commit_flush
front_advance
if_discard_flush
if_redirect_flush
if_normal_load
id_ex_advance
id_ex_bubble
ex_mem_advance
ex_mem_bubble
perf_stall_event
perf_flush_event
```

当前状态：

- `rv32i_pipe_ctrl.v` 已新增。
- `rv32i_pipe_core` 已改为实例化 `rv32i_pipe_ctrl`，流水线寄存器内容和数据通路暂未拆分。
- `rv32i_pipe_ctrl_tb` 已由用户确认 VCS PASS。
- pipeline control 抽出后的 core/perf/branch/muldiv 回归已由用户确认 VCS PASS。

### Phase 5：拆流水线寄存器 always 块

目标：

- 将 `rv32i_pipe_core` 的大 always 块拆成多个 stage 级 always。
- 每一级只管理自己的 pipeline register。
- 依赖 Phase 4 的统一控制信号降低改动风险。

当前状态：

- PC/IFID、ID/EX、EX/MEM、MEM/WB 已拆成独立时序块。
- 每个时序块只写自己所属的 pipeline register，避免多 always 驱动同一个寄存器。
- 行为目标保持不变：commit redirect 清空全线，mem stall 保持 EX/MEM 和 MEM/WB，mul/div stall 让 EX/MEM 插入 bubble 且 MEM/WB drain。
- 该结构性改动已由用户确认 VCS 回归 PASS。
- 重复的 stage bubble/flush 清零逻辑已抽成 `clear_if_id`、`clear_id_ex`、`clear_ex_mem`、`clear_mem_wb` 本地 task，并由用户确认 VCS 回归 PASS。

### Phase 6：补 assertion 和组合场景测试

目标：

- 为 stall/flush/redirect/writeback 加防呆断言。
- 增加更复杂组合场景 directed test。

优先覆盖：

- `mem_stall + ex_muldiv_stall`
- `ex_redirect + commit_redirect`
- `load-use stall + branch`
- `mret/trap redirect + wrong-path writeback`
- `muldiv_stall` 后紧跟 forwarding

当前状态：

- 第一轮 assertion 已加入 `rv32i_pipe_core`，并用 `SYNTHESIS` / `RV32I_DISABLE_ASSERT` 宏保护，避免影响综合交付。
- 已覆盖 commit redirect 优先级、redirect 后流水线 valid 清空、memory stall 后端保持、mul/div stall 前端保持并向 EX/MEM 插入 bubble、分支预测更新合法性、fault/illegal 写回屏蔽。
- 该轮改动已由用户确认 VCS 回归 PASS。

## 执行规则

每个 phase 都按同一流程推进：

1. 小范围 RTL 修改。
2. 更新 filelist。
3. 新增或更新 directed test。
4. 更新 `docs/status/VERIFICATION_MATRIX.md`，新测试先标 `PENDING`。
5. 更新相关专题文档和 `docs/status/PROJECT_STATUS.md`。
6. 用户运行 VCS 并给出 PASS log。
7. 再把矩阵改为 `PASS`，commit 并 push。

## 当前建议

当前 Phase 6 第一轮：`rv32i_pipe_core` 仿真期 assertion 已加入，并由用户确认 VCS 回归 PASS。

原因：

- Phase 1 的 `rv32i_branch_predictor` 已抽出并通过用户 VCS 回归确认。
- Phase 2 的 M 扩展识别已并入 decoder，`rv32i_pipe_core` 顶层补丁逻辑已减少。
- Phase 5 第二轮已经把重复清零逻辑集中到本地 task 并完成回归。
- Phase 6 第一轮已经补入低侵入的仿真防呆 assertion，不改变综合数据通路；下一步可以补组合场景 directed test，或开始抽薄 IF/fetch token 语义。
