# RV32I MMIO UART 说明

这一阶段新增一个最小 TX-only UART MMIO 外设：

```text
rtl/periph/rv32i_uart.v
rtl/periph/rv32i_mmio_periph_mux.v
```

目标不是做完整串口波特率发生器，而是先把第二个真实 MMIO 外设接入系统，验证 CPU 可以通过同一条 MMIO 总线访问 timer 和 UART。

## 1. 系统连接

当前 `rv32i_cached_system_top` 仍然只暴露一组外部 MMIO 端口。timer 和 UART 通过一个外部 MMIO 子外设 mux 分开：

```text
rv32i_cached_system_top
  MMIO port
    |
    v
rv32i_mmio_periph_mux
  |-- 0x4000_0000 -> rv32i_timer
  `-- 0x4000_1000 -> rv32i_uart
```

这样做的好处是 `rv32i_cached_system_top` 不需要因为新增外设而改接口；后续加 GPIO、PLIC 或 AHB/AXI adapter 时，也可以复用同样思路。

## 2. UART 寄存器

UART base address：

```text
0x4000_1000
```

寄存器映射：

```text
offset  name    behavior
0x00    TXDATA  写 byte0 发送 1 个字节；读取得到上一次发送的字节
0x04    STATUS  bit0 tx_ready，当前恒为 1
```

`TXDATA` 写入规则：

- `valid && ready && write && addr[5:0] == 0 && wstrb[0]` 时发送。
- `tx_valid` 拉高 1 个周期。
- `tx_data` 输出 `wdata[7:0]`。
- `dbg_tx_count` 加 1。
- `dbg_last_tx` 保存最近一次发送的字节。

当前 `ready = valid`，表示这个 UART 模型没有 wait state。

## 3. 为什么先做 TX-only

TX-only 足够验证 MMIO 外设链路：

- CPU 通过普通 `sb/lw` 访问 `0x4000_1000`。
- D-cache 对 MMIO 区域走 uncached bypass。
- memory bus 把访问送到外部 MMIO 端口。
- MMIO mux 进一步 decode 到 UART。
- UART 产生可观测的 `tx_valid/tx_data`。

完整 UART 的 RX FIFO、TX FIFO、baud rate、interrupt、line status 可以后续再加。

## 4. 验证入口

独立 UART 外设：

```bash
cd sim
make sim TB_FILE=./testcases/rv32i_uart_tb.sv TOP_NAME=rv32i_uart_tb
```

Cached system + UART MMIO：

```bash
cd sim
make sim TB_FILE=./testcases/rv32i_cached_uart_tb.sv TOP_NAME=rv32i_cached_uart_tb
```

`rv32i_cached_uart_tb` 中 ROM 程序位于：

```text
software/asm/cached_uart.S
software/bin/cached_uart.memh
```

testbench 默认从 `../software/bin/cached_uart.memh` 加载，也可以通过 `+ROM_MEMH=<path>` 覆盖。

程序会：

1. 用 `lui x1, 0x40001` 设置 UART base。
2. 读取 `STATUS`，检查 `tx_ready=1`。
3. 依次用 `sb` 写出 `UART\n`。
4. 读回 `TXDATA`，检查最后一个字节是换行。
5. 检查 D-cache miss 计数仍为 0，证明 UART MMIO 没有被缓存。

## 5. 当前限制

- 没有真实 serial line、baud rate 或 shift register。
- 没有 RX 路径。
- 没有 FIFO。
- 没有 UART interrupt。
- 子外设 mux 的 unmapped 子地址只通过 `dbg_decode_error` 暴露，不会回传成 bus access fault。

这个版本的定位是“能被 CPU 正确访问、能稳定观测 TX 字节”的最小 MMIO UART。
