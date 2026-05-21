# Agent IRQ Aggregator v0.4

最后更新：2026-05-21

本文记录 Agent SoC v0.4 的最小外设中断闭环。当前 CPU CSR 只实现 `mstatus.MIE`、`mie.MTIE` 和 `mip.MTIP`，尚未实现独立 MEI/PLIC/CLIC。因此 v0.4 先把 Agent 外设 IRQ 聚合到现有 machine timer interrupt 输入，让软件 handler 能从外设 `IRQ_STATUS` 识别真实来源。

## 1. 模块

```text
rtl/accel/rv32i_agent_irq_aggregator.v
```

集成位置：

```text
rv32i_ahb_matrix_apb_soc_top
  rv32i_timer.timer_irq
  rv32i_agent_matrix_accel.irq
  rv32i_tool_call_detector.irq
    -> rv32i_agent_irq_aggregator
      -> rv32i_ahb_matrix_soc_top.timer_irq
        -> rv32i_pipe_csr MTIP path
```

## 2. 行为

```verilog
cpu_timer_irq = timer_irq | agent_matrix_irq | tool_call_irq;
```

这意味着 CPU 看到的 `mcause` 仍是：

```text
0x80000007  machine timer interrupt
```

软件 handler 需要读取各 Agent 外设的 `IRQ_STATUS` 来区分来源，并在 `mret` 前清除对应 pending bit。这个方案不是最终中断架构，只是 v0 阶段为了快速跑通 tool-call/function-call 中断闭环的过渡层。

## 3. Debug 状态

`rv32i_ahb_matrix_apb_soc_top` 透出：

```text
cpu_timer_irq
dbg_agent_irq_status
```

`dbg_agent_irq_status` bit 定义：

| Bit | 含义 |
| --- | --- |
| 0 | raw `timer_irq` |
| 1 | raw `agent_matrix_irq` |
| 2 | raw `tool_call_irq` |
| 3 | aggregated `cpu_timer_irq` |

## 4. 软件镜像

```text
software/asm/tool_call_detector_irq.S
software/bin/tool_call_detector_irq.memh
```

该程序：

1. 设置 `mtvec = 0x08000140`。
2. 打开 `mstatus.MIE` 和 `mie.MTIE`。
3. 配置 Tool-call Detector pattern 和 `irq_en`。
4. 写入包含一次命中的 token stream。
5. handler 读取 `mcause/mepc/mstatus/mie/mip` 和 Tool-call Detector `IRQ_STATUS`，清 pending 后 `mret` 返回主程序。

## 5. 验证

SoC-level directed test：

```text
sim/testcases/rv32i_tool_call_detector_irq_soc_tb.sv
```

运行命令：

```bash
cd sim
make sim TB_FILE=./testcases/rv32i_tool_call_detector_irq_soc_tb.sv TOP_NAME=rv32i_tool_call_detector_irq_soc_tb
```

当前状态：`PENDING`，等待 VCS 环境确认。

验收点：

- `mcause == 0x80000007`。
- handler 中 `mip.MTIP == 1`。
- Tool-call Detector `IRQ_STATUS == 1` before clear。
- handler 清 pending 后 `tool_call_irq == 0` 且 `cpu_timer_irq == 0`。
- `mret` 返回主程序并到达 `ebreak`。
