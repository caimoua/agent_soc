# RV32I 内部 Memory Bus 说明

这一阶段开始把 I-cache、D-cache 后面的存储系统边界搭起来。前面 cache testbench 里，I-cache 直接接 instruction memory，D-cache 直接接 data memory；这样能验证 cache 自己，但还不像一个小 SoC。

现在新增 `rv32i_mem_bus`，把取指和数据访存统一接到一条内部 memory bus 上：

```text
rv32i_pipe_core
  |                    |
  v                    v
rv32i_icache       rv32i_dcache
  |                    |
  +--------+  +--------+
           v  v
      rv32i_mem_bus
           |
    +------+------+------+
    |      |      |
   ROM    SRAM   MMIO
```

这一步的重点不是性能，而是建立清晰边界：

- cache/core 内部继续使用简单 `valid/ready` 请求接口
- 总线层负责 I/D 仲裁
- 总线层负责地址 decode
- 后端可以逐步替换成 ROM、SRAM、MMIO、AHB-lite wrapper 或 AXI-lite wrapper

## 1. 为什么先不用 AHB/AXI

不是不用 AHB/AXI，而是现在先不把标准协议直接塞进 core/cache 里面。

AHB/AXI 会带来很多协议细节：

- 地址阶段和数据阶段
- response/error
- burst
- outstanding transaction
- AXI 的 `AW/W/B/AR/R` 多通道
- slave decode 和 arbitration
- protocol timing 约束

而我们现在的 cache 都是 blocking cache，一次只处理一个 miss。直接上 AXI/AHB 会让调试重心从“CPU 结构”偏到“协议细节”。

当前选择的路线是：

```text
core/cache 简单内部接口
  -> rv32i_mem_bus
  -> 后续 simple-bus-to-AHB-lite / simple-bus-to-AXI-lite adapter
```

这种分层更接近工程习惯：内部微架构用更轻的请求接口，芯片边界或系统互连处再转成标准总线。

## 2. 文件

```text
rtl/bus/rv32i_mem_bus.v
filelist/cpu_filelist/bus_rtl.f
sim/testcases/rv32i_mem_bus_tb.sv
sim/testcases/rv32i_pipe_cached_bus_tb.sv
sim/testcases/rv32i_cached_system_top_tb.sv
docs/architecture/RV32I_MEM_BUS.md
docs/architecture/RV32I_CACHED_SYSTEM_TOP.md
```

`sim/filelist.f` 已经加入 `bus_rtl.f`，所以仿真会自动编译 `rtl/bus` 下的总线模块。

## 3. Master 侧接口

当前有两个 master：

```text
I master：来自 I-cache refill 端口，只读
D master：来自 D-cache 后端端口，可读可写
```

I-cache 侧接口：

```verilog
i_valid
i_addr
i_ready
i_rdata
i_error
```

D-cache 侧接口：

```verilog
d_valid
d_write
d_addr
d_wdata
d_wstrb
d_ready
d_rdata
d_error
```

语义仍然是我们前面一直用的 blocking `valid/ready`：

- master 拉高 `valid`，并保持地址和控制信号稳定
- bus 完成访问时拉高对应 master 的 `ready`
- read 数据通过 `rdata` 同拍返回
- write 数据通过 `wdata/wstrb` 传给后端 slave

## 4. Slave 侧接口

当前 bus 后面预留三个 slave：

```text
ROM
SRAM
MMIO
```

每个 slave 都用同一套简单接口：

```verilog
*_valid
*_write
*_addr
*_wdata
*_wstrb
*_ready
*_rdata
```

虽然 ROM 正常只读，但接口仍然保留 `write/wdata/wstrb`，这样 bus 的 slave 端口形状统一。真正的 ROM wrapper 可以选择忽略写请求，或者后续返回 bus error。

## 5. 地址映射

当前默认 memory map 用高 4 bit 做粗粒度 decode：

```text
0x0000_0000 - 0x0FFF_FFFF  ROM
0x2000_0000 - 0x2FFF_FFFF  SRAM
0x4000_0000 - 0x4FFF_FFFF  MMIO
其他地址                    decode error，读返回 0
```

RTL 里用参数控制：

```verilog
ROM_BASE  = 32'h0000_0000
ROM_MASK  = 32'hF000_0000
SRAM_BASE = 32'h2000_0000
SRAM_MASK = 32'hF000_0000
MMIO_BASE = 32'h4000_0000
MMIO_MASK = 32'hF000_0000
```

判断方式是：

```text
(addr & MASK) == BASE
```

后续如果想把 ROM/SRAM/MMIO 改成更小范围，只需要改 `BASE/MASK` 参数，或者把 decode 逻辑换成更细的地址比较。

## 6. 仲裁策略

当前第一版仲裁很保守：

```text
D-cache 优先
I-cache 次优先
一次只接受一个请求
请求完成前锁住 grant
```

也就是说，如果 I-cache 和 D-cache 同时请求后端 bus：

```text
D-cache 先走
I-cache 等 D-cache 完成后再走
```

这样做的原因是：D-cache 往往对应流水线中已经执行到 MEM 阶段的 load/store。如果 D-cache 被长期压住，整个流水线更容易卡住。I-cache 当然也重要，但第一版先用最简单、可预测的 D 优先策略。

## 7. 为什么要锁住 grant

`rv32i_mem_bus` 不是纯组合 mux，而是会把当前请求 latch 住：

```text
IDLE:
  选择 D 或 I 请求
  latch master / addr / write / wdata / wstrb / target

BUSY:
  持续驱动选中的 slave
  等 slave ready
  给对应 master ready
  回到 IDLE
```

这样做比简单组合优先级更稳。假设 I-cache 先发起了一个 ROM 请求，但 ROM 还没 ready；如果下一拍 D-cache 又来了请求，bus 不会突然把已经发出去的 ROM 请求切掉，而是会等当前 grant 完成。

这就是 blocking bus 的基本形态：

- 没有 outstanding
- 没有 pipelined request
- 没有 burst
- 但每个事务边界清楚

## 8. Decode Error

当前 D 侧 unmapped 地址已经同时具备 debug 和 error response 行为：

```text
target = TARGET_ERROR
ready  = 1
rdata  = 0
i_error/d_error = 1
dbg_decode_error = 1
```

I-cache 会把 `i_error` 返回给 core fetch fault 标记，pipeline 在 commit 边界形成 precise instruction access fault；D-cache 会把 `d_error` 返回给 LSU，形成 precise load/store access fault：

```text
instruction access fault mcause = 1
load access fault  mcause = 5
store access fault mcause = 7
```

## 9. 独立 Bus Testbench

```text
sim/testcases/rv32i_mem_bus_tb.sv
```

运行方式：

```bash
cd /home2/kairos18/workspace/cpu_prj/sim
make sim TB_FILE=./testcases/rv32i_mem_bus_tb.sv TOP_NAME=rv32i_mem_bus_tb
```

覆盖点：

- I 侧读 ROM
- D 侧读 SRAM
- D 侧按 `wstrb` 写 SRAM byte lane
- D 侧访问 MMIO
- I/D 同时请求时 D 优先
- unmapped 地址触发 `dbg_decode_error`，I/D 侧分别返回 `i_error` / `d_error`
- grant 计数器递增

## 10. Pipeline + Cache + Bus 集成 Testbench

```text
sim/testcases/rv32i_pipe_cached_bus_tb.sv
```

运行方式：

```bash
cd /home2/kairos18/workspace/cpu_prj/sim
make sim TB_FILE=./testcases/rv32i_pipe_cached_bus_tb.sv TOP_NAME=rv32i_pipe_cached_bus_tb
```

连接关系：

```text
rv32i_pipe_core
  imem -> rv32i_icache -> rv32i_mem_bus I master -> ROM
  dmem -> rv32i_dcache -> rv32i_mem_bus D master -> SRAM
```

测试程序放在 ROM，从 `0x0000_0000` 开始取指；数据放在 SRAM，从 `0x2000_0000` 开始访问。程序大致是：

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

这个 testbench 验证：

- pipeline 可以通过 I-cache 从 ROM 取指
- D-cache 可以通过 bus 从 SRAM refill
- store 可以通过 D-cache 和 bus 写回 SRAM
- I-cache 和 D-cache 都会产生 bus grant
- I-cache 和 D-cache 都能看到 miss/refill 行为

## 11. Cached System Top Testbench

```text
sim/testcases/rv32i_cached_system_top_tb.sv
```

运行方式：

```bash
cd /home2/kairos18/workspace/cpu_prj/sim
make sim TB_FILE=./testcases/rv32i_cached_system_top_tb.sv TOP_NAME=rv32i_cached_system_top_tb
```

这个 testbench 不再手工实例化 core/cache/bus，而是只实例化 `rv32i_cached_system_top`。它用于验证正式系统顶层 wrapper 的端口和连接关系。说明见 `docs/architecture/RV32I_CACHED_SYSTEM_TOP.md`。

## 12. 当前限制

当前 `rv32i_mem_bus` 仍然是第一版内部总线：

- 只有两个 master：I-cache、D-cache
- 只有三个固定 slave 类型：ROM、SRAM、MMIO
- 仲裁固定 D 优先
- 不支持 burst
- 不支持 outstanding
- I/D 侧支持 `i_error` / `d_error` 返回给 core，形成 instruction/load/store access fault
- 不支持地址阶段和数据阶段分离
- 没有 wait-state timeout

后续自然演进方向：

1. 继续扩展 AHB-Lite bus path 的更多外设集成测试，或按需做真正的多 master AHB matrix。
2. 再考虑 `simple_bus_to_axi_lite`。
3. 继续扩展 MMIO 外设或接入更完整的 SoC interconnect。
