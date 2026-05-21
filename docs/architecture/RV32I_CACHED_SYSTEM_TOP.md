# RV32I Cached System Top 说明

这一阶段把 `rv32i_pipe_cached_bus_tb` 里面手工搭出来的连接关系，提升成一个正式 RTL 顶层：

```text
rv32i_cached_system_top
  |
  +-- rv32i_pipe_core
  +-- rv32i_icache
  +-- rv32i_dcache
  +-- rv32i_mem_bus
        |
        +-- 外部 ROM 接口
        +-- 外部 SRAM 接口
        +-- 外部 MMIO 接口
  |
  +-- timer_irq 输入到 pipeline CSR/trap
```

这样做以后，testbench 不再直接知道 core、cache、bus 之间的内部线怎么接。testbench 只需要像 SoC 顶层一样，给这个系统顶层接 ROM、SRAM、MMIO 模型。

## 1. 为什么要加这个顶层

前一版 `rv32i_pipe_cached_bus_tb` 是一个集成验证环境：

```text
testbench 里面实例化：
  rv32i_pipe_core
  rv32i_icache
  rv32i_dcache
  rv32i_mem_bus
  ROM/SRAM/MMIO model
```

这能验证功能，但它还不是一个可以复用的 RTL 系统边界。真实工程里通常不会让每个 testbench 都重新手写一遍 core/cache/bus 连接，而是会做一个顶层 wrapper，把稳定结构固定下来。

所以现在新增：

```text
rtl/top/rv32i_cached_system_top.v
```

它代表当前 RV32I 系统的第一版“带缓存系统顶层”。

## 2. 顶层内部连接

内部连接关系是：

```text
rv32i_pipe_core
  imem -> rv32i_icache -> rv32i_mem_bus I master
  dmem -> rv32i_dcache -> rv32i_mem_bus D master

rv32i_mem_bus
  ROM  slave  -> 外部 ROM wrapper/model
  SRAM slave  -> 外部 SRAM wrapper/model
  MMIO slave  -> 外部 MMIO wrapper/model
```

也就是说：

- core 仍然只看见 `imem_*` 和 `dmem_*`
- I-cache 负责取指 miss/refill
- D-cache 负责 load/store miss/refill/write-through
- bus 负责 I/D 仲裁和地址 decode
- ROM/SRAM/MMIO 仍放在顶层外面，方便以后替换成真实 macro、AHB/AXI adapter 或 SoC 互连

## 3. 为什么不把 cache/bus 塞进 core

不建议把 cache 和 bus 直接写进 `rv32i_pipe_core`，原因是职责会混在一起：

- `rv32i_pipe_core` 负责流水线、hazard、trap/CSR、load/store 请求
- `rv32i_icache` 负责指令缓存
- `rv32i_dcache` 负责数据缓存
- `rv32i_mem_bus` 负责仲裁和地址空间
- `rv32i_cached_system_top` 负责把它们接起来

这样分层以后，后续替换总线协议时，不需要改 core；替换 cache 参数时，也不需要改流水线。

## 4. 顶层端口

`rv32i_cached_system_top` 对外保留三类存储接口。

Interrupt 输入：

```verilog
timer_irq
```

这根线通常来自外部 MMIO timer。进入 core 后，它通过 `mstatus.MIE && mie.MTIE && mip.MTIP` 触发 machine timer interrupt。

ROM 接口：

```verilog
rom_valid
rom_write
rom_addr
rom_wdata
rom_wstrb
rom_ready
rom_rdata
```

SRAM 接口：

```verilog
sram_valid
sram_write
sram_addr
sram_wdata
sram_wstrb
sram_ready
sram_rdata
```

MMIO 接口：

```verilog
mmio_valid
mmio_write
mmio_addr
mmio_wdata
mmio_wstrb
mmio_ready
mmio_rdata
```

三类接口形状保持一致，是为了让 bus 的 slave 侧更统一。ROM 正常不会被写，如果后续要严谨一些，可以在 ROM wrapper 里对写 ROM 返回错误，再把错误变成 access fault trap。

## 5. 地址空间

地址 decode 仍由 `rv32i_mem_bus` 决定：

```text
0x0000_0000 - 0x0FFF_FFFF  ROM
0x2000_0000 - 0x2FFF_FFFF  SRAM
0x4000_0000 - 0x4FFF_FFFF  MMIO
其他地址                    decode error
```

所以测试程序从 ROM 的 `0x0000_0000` 开始取指，数据访问用 `0x2000_0000` 作为 SRAM 基地址。

## 6. 新增 Testbench

新增：

```text
sim/testcases/rv32i_cached_system_top_tb.sv
```

这个 testbench 只实例化一个系统顶层：

```text
rv32i_cached_system_top
```

然后在外面接三个简单模型：

- ROM model：保存指令，只读
- SRAM model：保存数据，支持 byte write strobe
- MMIO model：当前返回 0，本测试不期望访问 MMIO

测试程序和前面的 `rv32i_pipe_cached_bus_tb` 一样：

```asm
lui  x1, 0x20000
lw   x2, 4(x1)
add  x3, x2, x2
addi x4, x0, 0xAA
sw   x4, 8(x1)
lw   x5, 8(x1)
add  x6, x3, x5
ebreak
```

期望结果：

```text
x1 = 0x20000000
x2 = 7
x3 = 14
x4 = 170
x5 = 170
x6 = 184
sram[2] = 170
instret = 8
I-cache/D-cache 都产生过 miss
I-cache/D-cache 都获得过 bus grant
```

运行方式：

```bash
cd /home2/kairos18/workspace/cpu_prj/sim
make sim TB_FILE=./testcases/rv32i_cached_system_top_tb.sv TOP_NAME=rv32i_cached_system_top_tb
```

## 7. 当前意义

做到这里以后，项目已经有了三个层次：

```text
单独模块验证：
  rv32i_icache_tb
  rv32i_dcache_tb
  rv32i_mem_bus_tb

手工集成验证：
  rv32i_pipe_cached_bus_tb

系统顶层验证：
  rv32i_cached_system_top_tb
```

`rv32i_pipe_cached_bus_tb` 仍然有价值，因为它能看到更多中间线，适合调试 cache/bus 连接；`rv32i_cached_system_top_tb` 更接近 SoC 顶层验证，适合后续作为系统回归入口。

## 8. 下一步

当前已经做了第一版 MMIO 外设 `rv32i_timer`。timer 通过 `rv32i_cached_system_top` 的 MMIO 端口外接，CPU 用普通 `lw/sw` 访问 `0x4000_0000` 地址空间。

说明见：

```text
docs/architecture/RV32I_TIMER.md
```

`timer_irq` 也已经通过 `rv32i_cached_system_top` 输入 core，并接入 pipeline 的 trap/CSR 框架，形成 machine timer interrupt。对应验证入口是：

```text
sim/testcases/rv32i_cached_timer_irq_tb.sv
```

D 侧 bus decode error 已经接入 pipeline trap/CSR，可形成 load/store access fault。对应验证入口是：

```text
sim/testcases/rv32i_cached_access_fault_tb.sv
```

I 侧 bus decode error 也已经接入 pipeline trap/CSR，可形成 instruction access fault。对应验证入口是：
```text
sim/testcases/rv32i_cached_instr_access_fault_tb.sv
```

当前也已经新增最小 TX-only UART MMIO 外设。`rv32i_cached_system_top` 的外部 MMIO 端口可以先接 `rv32i_mmio_periph_mux`，再分发到 timer 和 UART：

```text
0x4000_0000 -> rv32i_timer
0x4000_1000 -> rv32i_uart
```

说明见：

```text
docs/architecture/RV32I_UART.md
```

对应验证入口是：

```text
sim/testcases/rv32i_uart_tb.sv
sim/testcases/rv32i_cached_uart_tb.sv
```

后续更自然的方向是继续补 AHB-lite/AXI-lite adapter，或者扩展 UART RX/FIFO/interrupt。
