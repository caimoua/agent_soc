# 接口索引

最后更新：2026-05-21

本文记录稳定模块边界，后续工作不需要每次重新扫描大量 RTL。

## 顶层系统

### `rv32i_cached_system_top`

文件：`rtl/top/rv32i_cached_system_top.v`

用途：可复用 cached system wrapper。

外部接口：

- `timer_irq`：外部 timer interrupt 输入 core CSR/trap。
- ROM passthrough：`rom_valid`, `rom_write`, `rom_addr`, `rom_wdata`, `rom_wstrb`, `rom_ready`, `rom_rdata`
- SRAM passthrough：`sram_valid`, `sram_write`, `sram_addr`, `sram_wdata`, `sram_wstrb`, `sram_ready`, `sram_rdata`
- MMIO passthrough：`mmio_valid`, `mmio_write`, `mmio_addr`, `mmio_wdata`, `mmio_wstrb`, `mmio_ready`, `mmio_rdata`
- Debug 输出：
  - core 性能计数器
  - branch / mispredict / BTB / BHT 计数器
  - cache hit/miss 计数器
  - bus grant 计数器
  - bus decode error

内部连接：

```text
core imem -> I-cache -> bus I master
core dmem -> D-cache -> bus D master
bus ROM/SRAM/MMIO -> external ports
bus i_error -> I-cache mem_error -> core imem_error
bus d_error -> D-cache mem_error -> core dmem_error
timer_irq -> core CSR/trap
MMIO external port -> optional timer/UART peripheral mux
```

### `rv32i_cached_ahb_master_top`

文件：`rtl/top/rv32i_cached_ahb_master_top.v`

用途：推荐的 CPU 子系统边界。内部包含 core、I-cache、D-cache 和 simple-to-AHB master bus，对外只暴露一个 AHB-Lite master interface。

交付说明：详见 `docs/architecture/RV32I_CPU_IP_DELIVERY.md`。

质量检查：Stage A4 默认以该模块作为 lint / synthesis / timing 基础检查 top，入口见 `docs/verification/RV32I_QUALITY_CHECKS.md`。

主要参数：

- `ICACHE_INDEX_BITS`：I-cache index 位宽，默认 2。
- `DCACHE_INDEX_BITS`：D-cache index 位宽，默认 2。
- `RESET_PC`：复位取指地址，默认 `32'h0000_0000`。
- `BRANCH_PRED_INDEX_BITS`：BHT/BTB index 位宽，默认 6。

时钟、复位和中断：

- `clk`
- `rst_n`：低有效异步复位。
- `timer_irq`：machine timer interrupt 输入。当前假设与 `clk` 同步。

外部 AHB-Lite master port：

- Outputs：`ahb_haddr`, `ahb_hburst`, `ahb_hprot`, `ahb_hsize`, `ahb_htrans`, `ahb_hwdata`, `ahb_hwrite`
- Inputs：`ahb_hrdata`, `ahb_hready`, `ahb_hresp`

AHB 行为：

- blocking、single outstanding。
- I-cache / D-cache 请求在 `rv32i_ahb_master_bus` 内仲裁，D 侧优先。
- `HBURST=SINGLE`，`HTRANS=NONSEQ/IDLE`。
- subword store 会按 byte 拆分为多个 AHB byte write。
- 外部 bus fabric 负责 ROM/SRAM/MMIO decode 和 default error response。

Debug 输出：

- core 性能计数器：`dbg_pc`, `dbg_cycle`, `dbg_instret`, `dbg_stall_cycle`, `dbg_flush_cycle`
- 分支预测计数器：`dbg_branch_count`, `dbg_branch_mispredict_count`, `dbg_btb_hit_count`, `dbg_btb_miss_count`, `dbg_bht_update_count`
- cache hit/miss 计数器。
- bus grant/error 计数器。
- debug regfile read port 和 system instruction event。

### `rv32i_ahb_matrix_soc_top`

文件：`rtl/top/rv32i_ahb_matrix_soc_top.v`

用途：clean-room AHB-Lite 1-master / 4-slave matrix SoC wrapper。

slot：

- flash：`0x0800_0000`
- SRAM：`0x2000_0000`
- AHB peripheral：`0x4000_0000`
- APB peripheral：`0x4200_0000`

### `rv32i_ahb_matrix_apb_soc_top`

文件：`rtl/top/rv32i_ahb_matrix_apb_soc_top.v`

用途：在 AHB matrix SoC 的 APB slot 后面接 AHB-to-APB bridge、APB mux、timer、UART 和 Agent Matrix Accelerator。

APB 外设：

- timer：`0x4200_0000`
- UART：`0x4200_1000`
- Agent Matrix Accelerator：`0x4200_2000`

新增中断/状态输出：

- `timer_irq`：已接入 CPU machine timer interrupt，同时作为 top-level debug/output。
- `agent_matrix_irq`：v0.2a 先作为 top-level output 暴露，尚未接入 CPU trap/interrupt 路径。

## Core

### `rv32i_pipe_core`

文件：`rtl/core/rv32i_pipe_core.v`

用途：五级流水 RV32IM core。

主要参数：

- `RESET_PC`：复位取指地址。
- `BRANCH_PRED_INDEX_BITS`：BHT/BTB index 位宽，默认 6，对应 64 项 direct-mapped BHT/BTB。

Instruction-side interface：

- Outputs：`imem_valid`, `imem_addr`
- Inputs：`imem_ready`, `imem_rdata`, `imem_error`
- `imem_error` 会作为 instruction access fault token 流入流水线，并在 commit 阶段精确提交。

Data-side interface：

- Outputs：`dmem_valid`, `dmem_write`, `dmem_addr`, `dmem_wdata`, `dmem_wstrb`
- Inputs：`dmem_ready`, `dmem_rdata`, `dmem_error`
- `dmem_error` 由 LSU 转换为 load/store access fault。
- load/store address misaligned 在 LSU 发出 D-bus 请求前检测。

Interrupt input：

- `timer_irq`

Debug interface：

- `dbg_pc`
- `dbg_cycle`
- `dbg_instret`
- `dbg_stall_cycle`
- `dbg_flush_cycle`
- `dbg_branch_count`
- `dbg_branch_mispredict_count`
- `dbg_btb_hit_count`
- `dbg_btb_miss_count`
- `dbg_bht_update_count`
- `dbg_reg_addr`, `dbg_reg_rdata`
- `dbg_illegal_instr`, `dbg_ecall`, `dbg_ebreak`

分支预测：

- `JAL`：若目标地址对齐，在 IF 阶段直接预测 taken。
- B-type branch：优先查 BTB，BTB 命中且 BHT 计数器最高位为 1 时预测 taken。
- B-type branch：BTB 未命中时回退到静态规则，backward branch 预测 taken，forward branch 预测 not-taken。
- `JALR`：仍在 EX 阶段解析。
- EX 阶段发现预测 PC 与真实下一条 PC 不一致时产生 `ex_redirect` 并 flush 前端。
- `BRANCH_PRED_INDEX_BITS` 已从 cached/AHB/SoC wrapper 透传，便于在不同集成层级调整 BHT/BTB 表项数量。

RV32M：

- `rv32i_pipe_core` 实例化 `rv32i_decoder #(.ENABLE_M(1))`。
- `opcode=0110011` 且 `funct7=0000001` 的 M 扩展指令由 decoder 输出 `muldiv_valid/muldiv_op`。
- `rv32i_muldiv` 位于 EX 阶段。
- M 指令等待 `rv32i_muldiv.ready`，等待期间 IF 和 ID/EX 保持，EX/MEM 插入 bubble，MEM/WB drain。
- M 指令结果复用 `RV32I_WB_ALU` writeback/forwarding 路径。

流水线寄存器组织：

- PC/IFID、ID/EX、EX/MEM、MEM/WB 的时序更新已经拆成独立 `always @(posedge clk or negedge rst_n)` 块。
- `rv32i_pipe_ctrl` 统一产生 advance/bubble/flush 控制，stage 寄存器块只根据这些命名控制信号更新。
- `mem_stall` 时 EX/MEM 和 MEM/WB 保持；`ex_muldiv_stall` 时 EX/MEM 插入 bubble，MEM/WB 从旧 EX/MEM drain。
- stage bubble/flush 的清零赋值集中在 `clear_if_id`、`clear_id_ex`、`clear_ex_mem`、`clear_mem_wb` 本地 task 中。

仿真断言：

- `rv32i_pipe_core` 末尾包含仿真期 SystemVerilog assertion，默认在非综合仿真中启用。
- 可通过定义 `SYNTHESIS` 或 `RV32I_DISABLE_ASSERT` 关闭。
- 当前覆盖 commit redirect 优先级、redirect 后流水线清空、memory stall 后端保持、mul/div stall 前端保持并向 EX/MEM 插入 bubble、分支预测更新合法性、fault/illegal 写回屏蔽。

关键内部模块：

- `rv32i_branch_predictor`
- `rv32i_pipe_hazard`
- `rv32i_pipe_lsu`
- `rv32i_pipe_csr`
- `rv32i_muldiv`
- `rv32i_pipe_ctrl`
- `rv32i_perf_counter`
- `rv32i_regfile`
- `rv32i_decoder`
- `rv32i_imm_gen`
- `rv32i_alu`

### `rv32i_branch_predictor`

文件：`rtl/core/rv32i_branch_predictor.v`

用途：封装 IF 阶段预测和 EX 阶段训练的分支预测器。

主要参数：

- `INDEX_BITS`：BHT/BTB index 位宽，默认 6，对应 64 项 direct-mapped BHT/BTB。

IF 查询接口：

- Inputs：`if_pc`, `if_instr`, `if_error`
- Outputs：`if_predicted_pc`, `if_predict_taken`, `if_is_branch`, `if_btb_hit`

EX 更新接口：

- Inputs：`ex_update_valid`, `ex_pc`, `ex_taken`, `ex_target_pc`, `ex_fetch_btb_hit`

Debug 输出：

- `dbg_btb_hit_count`
- `dbg_btb_miss_count`
- `dbg_bht_update_count`

行为：

- `JAL` 仍在 IF 阶段直接从立即数生成 taken 预测，不依赖 BTB。
- B-type branch 优先走 BTB+BHT。
- BTB miss 的 B-type branch 回退到静态 backward-taken 规则。
- BHT/BTB 只在 EX 阶段对有效 B-type branch 更新。

### `rv32i_decoder`

文件：`rtl/core/rv32i_decoder.v`

用途：统一生成 RV32I/RV32M 指令控制信号。

主要参数：

- `ENABLE_M`：默认 0。为 0 时 M 扩展编码仍报告 illegal；为 1 时识别 `mul/mulh/mulhsu/mulhu/div/divu/rem/remu`。

M 扩展输出：

- `muldiv_valid`：当前指令为已启用的 RV32M 乘除法指令。
- `muldiv_op`：直接使用 `funct3` 编码，对应 `RV32I_MULDIV_*`。

当前使用方式：

- 单周期 `rv32i_core` 使用默认 `ENABLE_M=0`，保持 RV32I-only baseline。
- 流水线 `rv32i_pipe_core` 使用 `ENABLE_M=1`，并把 `muldiv_valid/muldiv_op` 送入 ID/EX。

### `rv32i_perf_counter`

文件：`rtl/core/rv32i_perf_counter.v`

用途：独立保存 core debug 性能计数器，`rv32i_pipe_core` 只生成事件脉冲。

事件输入：

- `instret_event`：一条有效指令进入退休统计点。
- `stall_event`：本周期发生 load-use、memory wait-state、mul/div wait 或 fetch discard 等停顿。
- `flush_event`：本周期发生预测错误/控制流重定向统计事件。
- `branch_event`：一条有效 B-type branch 在 EX 阶段被解析并更新 predictor。
- `branch_mispredict_event`：该 B-type branch 发生预测错误。

计数器输出：

- `cycle_count`
- `instret_count`
- `stall_cycle_count`
- `flush_cycle_count`
- `branch_count`
- `branch_mispredict_count`

### `rv32i_pipe_ctrl`

文件：`rtl/core/rv32i_pipe_ctrl.v`

用途：集中保存当前流水线 stall/flush 优先级判断，`rv32i_pipe_core` 只消费命名后的控制输出。

输入：

- `commit_redirect`
- `ex_redirect`
- `mem_stall`
- `ex_muldiv_stall`
- `load_use_stall`
- `if_stall`
- `if_discard`

主要输出：

- `commit_flush`：commit 阶段 trap/mret/interrupt redirect 优先级最高。
- `front_advance`：IF/ID 和 ID/EX 前端可推进。
- `if_discard_flush`：redirect 后丢弃旧取指返回。
- `if_redirect_flush`：EX 阶段控制流修正前端。
- `if_normal_load`：正常取指进入 IF/ID。
- `id_ex_advance` / `id_ex_bubble`：控制 ID/EX 推进或插入 bubble。
- `ex_mem_advance` / `ex_mem_bubble`：控制 EX/MEM 推进，乘除法等待时 EX/MEM 插入 bubble 且 MEM/WB drain。
- `perf_stall_event` / `perf_flush_event`：提供给 `rv32i_perf_counter` 的控制事件。

## CSR / Trap

### `rv32i_pipe_csr`

文件：`rtl/core/rv32i_pipe_csr.v`

用途：保存架构 CSR 状态，并在 commit 阶段生成 trap/interrupt redirect。

已实现 CSR：

- `mstatus`：只实现 MIE/MPIE
- `mie`：只实现 MTIE
- `mtvec`
- `mepc`
- `mcause`
- `mip`：MTIP 由 `timer_irq` 派生
- `cycle`

commit exception inputs：

- `commit_illegal`
- `commit_ecall`
- `commit_ebreak`
- `commit_instr_addr_misaligned`
- `commit_instr_fault`
- `commit_load_addr_misaligned`
- `commit_load_fault`
- `commit_store_addr_misaligned`
- `commit_store_fault`

支持的 `mcause`：

```text
0             instruction address misaligned
1             instruction access fault
2             illegal instruction
3             breakpoint
4             load address misaligned
5             load access fault
6             store/AMO address misaligned
7             store/AMO access fault
11            environment call from machine mode
0x80000007    machine timer interrupt
```

## Cache

### `rv32i_icache`

文件：`rtl/mem/rv32i_icache.v`

用途：blocking instruction cache。

- 2-way set associative。
- 4-word cache line。
- CPU side：`cpu_valid`, `cpu_addr`, `cpu_ready`, `cpu_rdata`, `cpu_error`
- Memory side：`mem_valid`, `mem_addr`, `mem_ready`, `mem_rdata`, `mem_error`
- `mem_error` 会终止 refill 并返回给 core。

### `rv32i_dcache`

文件：`rtl/mem/rv32i_dcache.v`

用途：blocking data cache。

- 2-way set associative。
- 4-word cache line。
- write-through。
- no-write-allocate。
- 默认 MMIO uncached bypass。
- CPU side：`cpu_valid`, `cpu_write`, `cpu_addr`, `cpu_wdata`, `cpu_wstrb`, `cpu_ready`, `cpu_rdata`, `cpu_error`
- Memory side：`mem_valid`, `mem_write`, `mem_addr`, `mem_wdata`, `mem_wstrb`, `mem_ready`, `mem_rdata`, `mem_error`

## Bus / SoC

### `rv32i_mem_bus`

文件：`rtl/bus/rv32i_mem_bus.v`

用途：内部 simple blocking memory bus。

- I master：来自 I-cache。
- D master：来自 D-cache。
- slaves：ROM、SRAM、MMIO。
- arbitration：D 侧优先。
- unmapped 地址返回 decode error。

### `rv32i_ahb_master_bus`

文件：`rtl/bus/rv32i_ahb_master_bus.v`

用途：把 core/cache 的 simple blocking memory request 转成单 outstanding AHB-Lite master transaction。

### `rv32i_ahb_lite_matrix_1m4s`

文件：`rtl/bus/rv32i_ahb_lite_matrix_1m4s.v`

用途：clean-room 1-master / 4-slave AHB-Lite matrix/decode。

## MMIO 外设

### `rv32i_timer`

文件：`rtl/periph/rv32i_timer.v`

base：`0x4000_0000` 或 APB SoC 中的 `0x4200_0000`。

寄存器：

- `mtime_lo`
- `mtime_hi`
- `mtimecmp_lo`
- `mtimecmp_hi`
- `ctrl`

### `rv32i_uart`

文件：`rtl/periph/rv32i_uart.v`

base：`0x4000_1000` 或 APB SoC 中的 `0x4200_1000`。

当前是最小 TX-only UART，用于 MMIO 输出验证。

### `rv32i_agent_matrix_accel`

文件：`rtl/accel/rv32i_agent_matrix_accel.v`

base：APB SoC 中的 `0x4200_2000`。

用途：Agent SoC v0.2a 的最小 INT8 matvec 加速器。CPU 通过 APB scratchpad 写入固定 `4x4` signed int8 matrix 和 `4x1` signed int8 vector，写 `CTRL.start` 后模块生成 4 个 signed int32 result，CPU 通过 polling `STATUS.done` 读取结果。

寄存器：

- `0x000 CTRL`：bit0 `start`，bit1 `irq_en`，bit2 `clear`。
- `0x004 STATUS`：bit0 `busy`，bit1 `done`，bit2 `irq_pending`。
- `0x014 SHAPE`：固定返回 `M=4, N=1, K=4`。
- `0x028 IRQ_STATUS`：bit0 `irq_pending`。
- `0x02c IRQ_CLEAR`：写 1 清 `irq_pending`。
- `0x100` - `0x10c`：matrix A scratchpad，4 个 word，每 word 打包 4 个 int8。
- `0x140`：vector B scratchpad，1 个 word 打包 4 个 int8。
- `0x180` - `0x18c`：4 个 int32 result。

Debug 输出：

- `dbg_status`
- `dbg_result0` - `dbg_result3`
- `dbg_start_count`
