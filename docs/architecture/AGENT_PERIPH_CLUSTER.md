# Agent Peripheral Cluster

最后更新：2026-05-22

`rv32i_agent_periph_cluster` 是 v0.6 结构整理的第一层边界。它不新增 Agent 功能，而是把 v0.2-v0.5 中散在 SoC top 里的 Agent 相关外设收束成一个簇，避免 `rv32i_ahb_matrix_apb_soc_top` 继续变成 demo 线网堆叠。

## RTL Boundary

文件：

```text
rtl/agent/rv32i_agent_periph_cluster.v
```

内部实例：

```text
rv32i_agent_periph_cluster
  rv32i_agent_matrix_accel
  rv32i_tool_call_detector
  rv32i_agent_irq_aggregator
  rv32i_agent_event_counter
```

上游连接：

- `rv32i_apb_periph_mux` 只向 Agent cluster 输出一组 simple/APB-like 访问口：`agent_valid/write/addr/wdata/wstrb/ready/rdata`。
- Agent cluster 内部再 decode `0x4200_2000`、`0x4200_3000` 和 `0x4200_4000`。
- `rv32i_ahb_matrix_apb_soc_top` 保留现有外部 debug/output 端口，现有 testbench 不需要因为 wrapper 抽出而改端口。

下游连接：

- Matrix accelerator 的 SRAM-mode memory master 仍通过 top 中的 `rv32i_simple_to_ahb` 接入 AHB M1。
- Timer 仍在 `rtl/periph/rv32i_timer.v`，其 raw `timer_irq` 输入 Agent cluster 参与 IRQ 聚合和事件计数。
- CPU 当前仍只实现 MTIP/MTIE，所以 cluster 输出的 `cpu_timer_irq = timer_irq | agent_matrix_irq | tool_call_irq` 接入 CPU timer interrupt 路径。

## APB Map

| Window | Module | Purpose |
| --- | --- | --- |
| `0x4200_2000` | `rv32i_agent_matrix_accel` | 4x4 INT8 matvec scratchpad / SRAM-mode accelerator |
| `0x4200_3000` | `rv32i_tool_call_detector` | token pattern detector and tool-call IRQ |
| `0x4200_4000` | `rv32i_agent_event_counter` | Agent event counters and match-to-clear latency |

The APB mux treats these three windows as one Agent region for routing. The cluster keeps the fine-grained decode local so future Agent peripherals can be added without growing the SoC top wiring pattern.

## Debug And Events

The cluster preserves the existing debug surface:

- Matrix status, four result registers, and start counter.
- Tool-call status, match count, token count, and last token.
- Agent IRQ aggregated status.
- Agent event counter status and counters.

Event pulses stay inside the cluster:

- `tool_event_token`
- `tool_event_match`
- `tool_event_irq_clear`
- `matrix_event_start`
- `matrix_event_done`

This makes the event counter a cluster-local observer rather than another top-level wiring dependency.

## Verification Status

This is a structural refactor over previously passing v0.5 logic. The refactor has been confirmed by the `agent` regression suite:

```bash
cd sim
bash ./regress/run_regression.sh --suite agent --keep-going
```

Status: user-confirmed VCS PASS on 2026-05-22. Log directory:

```text
/home2/kairos18/workspace/ai_agent_mcu_npu_soc/sim/log/regress/20260522_105035-agent
```
