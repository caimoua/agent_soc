# Tool-call Detector v0.3

最后更新：2026-05-21

本文记录 Agent SoC v0.3 的最小 Tool-call Detector。它用于把 token stream 中的特殊 token 序列匹配从 CPU polling loop 中拿出来，形成后续 function-call / structured-output 硬件路径的起点。

## 1. 模块

```text
rtl/accel/rv32i_tool_call_detector.v
```

集成位置：

```text
rv32i_ahb_matrix_apb_soc_top
  -> rv32i_ahb_to_apb
    -> rv32i_apb_periph_mux
      -> rv32i_tool_call_detector
```

地址窗口：

```text
0x4200_3000 - 0x4200_3FFF
```

## 2. 行为

- Pattern 最多 8 个 16-bit token。
- CPU 写 `TOKEN_IN` 时，detector 将 token 推入 8-entry history。
- 每次 token 写入后，硬件比较最近 `PATTERN_LEN` 个 token 是否等于 pattern。
- 命中后置位 `STATUS.match`、`IRQ_STATUS.pending`，并累加 `MATCH_COUNT`。
- `tool_call_irq` 当前作为 SoC top output 暴露，尚未接入 CPU trap/interrupt 路径。

## 3. 寄存器

Base：`0x4200_3000`

| Offset | Name | 描述 |
| --- | --- | --- |
| `0x000` | `CTRL` | bit0 `enable`, bit1 `clear`, bit2 `irq_en` |
| `0x004` | `STATUS` | bit0 `active`, bit1 `match`, bit2 `overflow`, bit3 `irq_pending` |
| `0x008` | `PATTERN_LEN` | 1 到 8 token，写 0 或大于 8 会 clamp 并置 overflow |
| `0x00c` | `TOKEN_IN` | 写入 16-bit token 并推进 matcher |
| `0x010` | `MATCH_COUNT` | 命中次数 |
| `0x014` | `TOKEN_COUNT` | 已接收 token 数，最多饱和到 8 |
| `0x018` | `IRQ_STATUS` | bit0 `irq_pending` |
| `0x01c` | `IRQ_CLEAR` | 写 bit0=1 清 `irq_pending` |
| `0x020` | `PATTERN0` | token 0/1 packed |
| `0x024` | `PATTERN1` | token 2/3 packed |
| `0x028` | `PATTERN2` | token 4/5 packed |
| `0x02c` | `PATTERN3` | token 6/7 packed |

## 4. 软件镜像

```text
software/asm/tool_call_detector.S
software/bin/tool_call_detector.memh
```

软件配置 pattern：

```text
0x1001, 0x1002, 0x1003, 0x1004
```

然后写入一个包含一次命中的 token stream，检查 `STATUS=0xb`、`MATCH_COUNT=1`、`TOKEN_COUNT=8` 和 IRQ clear 后 `STATUS=0x3`。

## 5. 验证

SoC-level directed test：

```text
sim/testcases/rv32i_tool_call_detector_soc_tb.sv
```

运行命令：

```bash
cd sim
make sim TB_FILE=./testcases/rv32i_tool_call_detector_soc_tb.sv TOP_NAME=rv32i_tool_call_detector_soc_tb
```

当前状态：`PENDING`，等待 VCS 环境确认。
