# Agent Matrix Accelerator v0.2a

最后更新：2026-05-21

本文记录第一版 Agent Matrix Accelerator 的 RTL 边界、寄存器和验证入口。它是 Agent SoC v0 的第一个最小 AI 加速闭环，目标是先跑通 CPU -> APB -> accelerator -> polling/result 的硬件路径。

## 1. 模块

```text
rtl/accel/rv32i_agent_matrix_accel.v
```

当前版本是 APB scratchpad 外设，不是 DMA master。CPU 负责把输入数据写入 accelerator 内部 scratchpad，再写 `CTRL.start` 启动计算。

集成位置：

```text
rv32i_ahb_matrix_apb_soc_top
  -> rv32i_ahb_to_apb
    -> rv32i_apb_periph_mux
      -> rv32i_agent_matrix_accel
```

地址窗口：

```text
0x4200_2000 - 0x4200_2FFF
```

## 2. 计算规模

当前固定为：

```text
4x4 signed int8 matrix * 4x1 signed int8 vector -> 4x1 signed int32 result
```

这不是最终 NPU 阵列，只是 v0.2a 的最小闭环。v0.2b 再扩展到 SRAM source/destination、shape、stride 和更真实的数据搬运路径。

## 3. 寄存器

Base：`0x4200_2000`

| Offset | Name | 描述 |
| --- | --- | --- |
| `0x000` | `CTRL` | bit0 `start`, bit1 `irq_en`, bit2 `clear` |
| `0x004` | `STATUS` | bit0 `busy`, bit1 `done`, bit2 `irq_pending` |
| `0x014` | `SHAPE` | 固定返回 `0x0004_0104`，即 `M=4, N=1, K=4` |
| `0x028` | `IRQ_STATUS` | bit0 `irq_pending` |
| `0x02c` | `IRQ_CLEAR` | 写 bit0=1 清 `irq_pending` |
| `0x100` - `0x10c` | `SCRATCH_A` | 4 个 word，每 word 打包一行 4 个 int8 |
| `0x140` | `SCRATCH_B` | 1 个 word，打包 4 个 int8 vector 元素 |
| `0x180` - `0x18c` | `RESULT` | 4 个 signed int32 result |

`CTRL.clear` 会同时清 `done` 和 `irq_pending`。`IRQ_CLEAR` 只清 `irq_pending`，保留 `done`，方便软件先确认计算完成再单独清中断状态。`agent_matrix_irq` 当前从 SoC top 暴露为 output，但尚未接入 CPU trap/interrupt 路径。

## 4. 软件镜像

```text
software/asm/agent_matrix_accel.S
software/bin/agent_matrix_accel.memh
```

软件流程：

1. 写入 4 行 matrix 到 `SCRATCH_A`。
2. 写入 vector 到 `SCRATCH_B`。
3. 写 `CTRL.start`。
4. polling `STATUS.done`。
5. 读取 4 个 result 并与 golden result 比较。
6. 检查 `IRQ_STATUS`，写 `IRQ_CLEAR`，再次确认 pending 已清。
7. 写寄存器签名并以 `ebreak` 结束。

Golden result：

```text
[-3, 20, -4, 82], checksum = 95
```

## 5. 验证

SoC-level directed test：

```text
sim/testcases/rv32i_agent_matrix_accel_soc_tb.sv
```

运行命令：

```bash
cd sim
make sim TB_FILE=./testcases/rv32i_agent_matrix_accel_soc_tb.sv TOP_NAME=rv32i_agent_matrix_accel_soc_tb
```

当前状态：`PENDING`，等待 VCS 环境确认。确认 PASS 后需要更新：

- `docs/status/VERIFICATION_MATRIX.md`
- `docs/status/PROJECT_STATUS.md`
- `docs/roadmap/AGENT_SOC_ARCH_V0.md`
