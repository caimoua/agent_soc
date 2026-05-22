# Agent Event Counter v0.5

最后更新：2026-05-22

本文记录 Agent SoC v0.5 的最小事件/性能计数窗口。它不是最终性能监控单元，而是给当前 demo 链路加一个硬件观测面，方便后续把 demo 收束成真正的 SoC 骨架。

## 1. 模块

```text
rtl/accel/rv32i_agent_event_counter.v
```

集成位置：

```text
rv32i_ahb_matrix_apb_soc_top
  -> rv32i_ahb_to_apb
    -> rv32i_apb_periph_mux
      -> rv32i_agent_event_counter @ 0x4200_4000
```

事件来源：

```text
rv32i_tool_call_detector
  event_token
  event_match
  event_irq_clear

rv32i_agent_matrix_accel
  event_start
  event_done

rv32i_agent_irq_aggregator path
  timer_irq
  agent_matrix_irq
  tool_call_irq
  cpu_timer_irq
```

## 2. 地址窗口

Base：`0x4200_4000`

| Offset | Name | 描述 |
| --- | --- | --- |
| `0x000` | `CTRL` | 写 bit0=1 清全部计数器 |
| `0x004` | `STATUS` | bit0 latency active, bit1 last IRQ valid, bit[7:4] last IRQ source |
| `0x008` | `TOOL_TOKEN_COUNT` | Tool-call Detector 接收 token 次数 |
| `0x00c` | `TOOL_MATCH_COUNT` | Tool-call pattern 命中次数 |
| `0x010` | `TOOL_IRQ_COUNT` | `tool_call_irq` 上升沿次数 |
| `0x014` | `MATRIX_START_COUNT` | Matrix accelerator start 次数 |
| `0x018` | `MATRIX_DONE_COUNT` | Matrix accelerator done 次数 |
| `0x01c` | `AGENT_IRQ_COUNT` | 聚合后 `cpu_timer_irq` 上升沿次数 |
| `0x020` | `LAST_IRQ_SOURCE` | bit0 timer, bit1 matrix, bit2 tool-call, bit3 cpu aggregated |
| `0x024` | `LATENCY_LAST` | 最近一次 tool match 到 IRQ clear 的周期数 |
| `0x028` | `LATENCY_MIN` | 最小 match-to-clear latency |
| `0x02c` | `LATENCY_MAX` | 最大 match-to-clear latency |
| `0x030` | `LATENCY_COUNT` | 已完成 latency sample 次数 |
| `0x034` | `MATRIX_IRQ_COUNT` | `agent_matrix_irq` 上升沿次数 |
| `0x038` | `TIMER_IRQ_COUNT` | raw `timer_irq` 上升沿次数 |

## 3. 软件镜像

```text
software/asm/agent_event_counter.S
software/bin/agent_event_counter.memh
```

该程序先清空 event counters，然后：

1. 启动一次 APB scratchpad matrix accelerator，并打开 matrix IRQ。
2. 清除 matrix IRQ pending。
3. 配置 Tool-call Detector，写入 8 个 token，触发一次 pattern match 和 tool IRQ。
4. 延迟若干周期后清除 tool IRQ pending。
5. 读取 `0x4200_4000` event counter window 并检查计数值。

预期计数：

| Counter | 期望 |
| --- | --- |
| `TOOL_TOKEN_COUNT` | 8 |
| `TOOL_MATCH_COUNT` | 1 |
| `TOOL_IRQ_COUNT` | 1 |
| `MATRIX_START_COUNT` | 1 |
| `MATRIX_DONE_COUNT` | 1 |
| `AGENT_IRQ_COUNT` | 2 |
| `LAST_IRQ_SOURCE` | `0x0000_000c` |
| `LATENCY_COUNT` | 1 |
| `MATRIX_IRQ_COUNT` | 1 |
| `TIMER_IRQ_COUNT` | 0 |

## 4. 验证

SoC-level directed test：

```text
sim/testcases/rv32i_agent_event_counter_soc_tb.sv
```

运行命令：

```bash
cd sim
make sim TB_FILE=./testcases/rv32i_agent_event_counter_soc_tb.sv TOP_NAME=rv32i_agent_event_counter_soc_tb
```

当前状态：`PENDING`，等待 VCS 环境确认。
