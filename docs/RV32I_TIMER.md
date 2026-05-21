# RV32I MMIO Timer 说明

这一阶段新增一个最小 memory-mapped timer 外设：

```text
rtl/periph/rv32i_timer.v
```

第一步已经验证 CPU 可以通过 MMIO 地址空间，用普通 `lw/sw` 访问一个真实外设。现在第二步已经把 `timer_irq` 接入 pipeline 的 trap/CSR 框架，形成最小 machine timer interrupt。

## 1. 当前系统位置

连接关系是：

```text
rv32i_pipe_core
  dmem
   |
rv32i_dcache
  uncached MMIO bypass
   |
rv32i_mem_bus
   |
MMIO port
   |
rv32i_timer
  |
timer_irq
  |
rv32i_pipe_core CSR/trap
```

I-cache 仍然从 ROM 取指；D-cache 负责数据访问。访问 SRAM 时仍走 cache；访问 `0x4000_0000` MMIO 区间时，D-cache 会直接 bypass，不做 cache lookup、refill 或 line allocation。`timer_irq` 则通过 `rv32i_cached_system_top` 输入 core。

## 2. 为什么 MMIO 要 bypass D-cache

timer 这类外设和普通内存不一样。

普通内存的数据相对稳定，cache 可以把一整条 line 拿进来，后面反复命中。

MMIO 寄存器可能每拍都在变，比如 `mtime`：

```text
第一次读 mtime = 10
第二次读 mtime = 20
```

如果 D-cache 把第一次读到的 `mtime` 缓存起来，第二次读就可能直接命中旧值，这对外设是错的。

所以这次给 `rv32i_dcache` 增加了 uncached 地址窗口：

```verilog
parameter [31:0] UNCACHED_BASE = 32'h4000_0000
parameter [31:0] UNCACHED_MASK = 32'hF000_0000
```

默认把 `0x4000_0000 - 0x4FFF_FFFF` 作为 uncached MMIO 区间。

命中这个区间时：

- load：直接向后端 bus 发一个读请求，返回 `mem_rdata`
- store：直接向后端 bus 发一个写请求，带 `wdata/wstrb`
- 不读取 tag/data SRAM
- 不产生 D-cache hit/miss 计数
- 不 refill cache line

## 3. Timer 寄存器

当前 timer 的寄存器映射如下：

```text
offset  名称          访问    说明
0x00    mtime_lo      R/W     64-bit mtime 低 32 位
0x04    mtime_hi      R/W     64-bit mtime 高 32 位
0x08    mtimecmp_lo   R/W     64-bit mtimecmp 低 32 位
0x0c    mtimecmp_hi   R/W     64-bit mtimecmp 高 32 位
0x10    ctrl/status   R/W     控制和状态
```

`ctrl/status` 当前定义：

```text
bit 0   enable      写 1 后 mtime 每拍加 1
bit 1   irq_enable  写 1 后允许 timer_irq 输出
bit 2   clear       写 1 清零 mtime，这一位不保存
bit 31  irq_pending 只读，mtime >= mtimecmp 且 irq_enable=1 时为 1
```

读 `ctrl/status` 时：

```text
{irq_pending, 29'd0, irq_enable, enable}
```

写寄存器时支持 `wstrb`，所以 byte lane 写是有效的。

## 4. timer_irq

当前输出条件很简单：

```verilog
timer_irq = irq_enable && (mtime >= mtimecmp)
```

`timer_irq` 现在已经进入 core，并通过 CSR/trap 框架产生 machine timer interrupt：

```text
mcause = 0x80000007
pc     = mtvec
mepc   = 下一条要执行的 PC
```

当前实现采用 commit 边界上的 precise interrupt：当 `timer_irq` 为 1，且 `mstatus.MIE && mie.MTIE` 为 1 时，core 在当前普通指令提交后进入 trap。`mepc` 保存下一条应该继续执行的 PC，handler 用 `mret` 返回。

新增最小 interrupt CSR：

```text
mstatus  0x300   仅实现 MIE(bit3)、MPIE(bit7)
mie      0x304   仅实现 MTIE(bit7)
mip      0x344   仅实现只读 MTIP(bit7)，由 timer_irq 反映
```

## 5. 独立 Timer Testbench

新增：

```text
sim/testcases/rv32i_timer_tb.sv
```

运行方式：

```bash
cd /home2/kairos18/workspace/cpu_prj/sim
make sim TB_FILE=./testcases/rv32i_timer_tb.sv TOP_NAME=rv32i_timer_tb
```

覆盖内容：

- reset 后 `ctrl=0`
- 写 `mtimecmp`
- 写 `ctrl=3` 启动计数并打开 `irq_enable`
- 等待 `timer_irq` 变高
- 读取 `ctrl/status`，检查 bit31 irq pending
- 写 `ctrl` bit2 清零 `mtime`
- 检查 byte write strobe

## 6. Cached System + Timer Testbench

新增：

```text
sim/testcases/rv32i_cached_timer_tb.sv
```

运行方式：

```bash
cd /home2/kairos18/workspace/cpu_prj/sim
make sim TB_FILE=./testcases/rv32i_cached_timer_tb.sv TOP_NAME=rv32i_cached_timer_tb
```

这个 testbench 的程序从 ROM 取指，通过 `0x4000_0000` 访问 timer。Stage A2 后，程序位于：

```text
software/asm/cached_timer.S
software/bin/cached_timer.memh
```

testbench 默认从 `../software/bin/cached_timer.memh` 加载，也可以通过 `+ROM_MEMH=<path>` 覆盖。

程序行为：

```asm
lui  x1, 0x40000
addi x2, x0, 10
sw   x2, 8(x1)       # mtimecmp_lo = 10
sw   x0, 12(x1)      # mtimecmp_hi = 0
addi x3, x0, 3
sw   x3, 16(x1)      # enable | irq_enable
lw   x6, 8(x1)       # 读回 mtimecmp_lo
nop
...
lw   x4, 0(x1)       # 读取 mtime_lo
lw   x5, 16(x1)      # 读取 ctrl/status
ebreak
```

期望结果：

```text
x1 = 0x40000000
x2 = 10
x3 = 3
x6 = 10
x4 >= 10
x5[31] = 1
x5[1:0] = 2'b11
timer_irq = 1
D-cache miss_count = 0
```

这里 `D-cache miss_count = 0` 很重要，说明 MMIO 访问没有被当成 cacheable load/store。

## 7. Cached System + Timer Interrupt Testbench

新增：

```text
sim/testcases/rv32i_cached_timer_irq_tb.sv
```

运行方式：

```bash
cd /home2/kairos18/workspace/cpu_prj/sim
make sim TB_FILE=./testcases/rv32i_cached_timer_irq_tb.sv TOP_NAME=rv32i_cached_timer_irq_tb
```

ROM 程序已经迁移到软件镜像流：

```text
software/asm/cached_timer_irq.S
software/bin/cached_timer_irq.memh
```

testbench 默认从 `../software/bin/cached_timer_irq.memh` 加载，也可以通过 `+ROM_MEMH=<path>` 覆盖。

这个 testbench 在 cached system top 外接 `rv32i_timer`，然后让 CPU：

1. 设置 `mtvec=0x140`。
2. 设置 `mstatus.MIE=1` 和 `mie.MTIE=1`。
3. 通过 MMIO 配置 `mtimecmp=10` 并启动 timer。
4. 等待 `timer_irq` 触发 machine timer interrupt。
5. handler 读取 `mcause/mepc/mstatus/mie/mip` 并写入 SRAM。
6. handler 写 `mie=0` 关闭 MTIE，再执行 `mret`。
7. 主程序继续执行到 `ebreak`。

期望结果：

```text
mcause  = 0x80000007
mstatus = 0x00000080   // handler 中 MIE=0, MPIE=1
mie     = 0x00000080   // handler 关闭 MTIE 前读到 MTIE=1
mip     = 0x00000080   // MTIP 由 timer_irq 反映
x31     = 1            // handler 确实执行
x21     = 0x55         // mret 后回到主程序
```

## 8. 当前限制

当前 timer 仍是第一版：

- 没有 `mtime/mtimecmp` 原子访问保护
- timer 外设本身没有额外 bus error；I/D 侧 unmapped decode error 已可形成 instruction/load/store access fault
- 没有多 timer channel
- 没有低功耗 clock gate
- 没有完整 privilege mode，也没有 nested interrupt

这些都可以后续再做。当前阶段已经把 MMIO 外设访问链路和最小 machine timer interrupt 跑通。

## 9. 下一步

后续可以继续增强：

1. handler 里更新 `mtimecmp`，形成周期性 tick。
2. 和 UART 一起通过 MMIO 子外设 mux 做更多集成测试。
3. 在 AHB-Lite bus path 上补更多 MMIO 外设集成测试，或继续做 `simple_bus_to_axi_lite`。
