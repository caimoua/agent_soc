# RV32I D-Cache 说明

这一阶段开始把流水线 core 的数据访存路径缓存化。`rv32i_pipe_core` 本身已经有 `dmem_valid/dmem_ready` 握手，所以 D-cache 可以直接插在 core 和后端 data memory 之间：

```text
rv32i_pipe_core
  dmem_valid/write/addr/wdata/wstrb
  dmem_ready/rdata
      |
      v
rv32i_dcache
      |
      v
后端 data memory / SRAM / bus
```

当前版本优先做一版保守、容易验证的 blocking D-cache：

```text
2-way set associative
4-word cache line
SRAM-style tag/data storage
data SRAM byte write mask
load miss 整条 line refill
store hit write-through
store miss no-write-allocate
simple pseudo-LRU replacement bit
MMIO uncached bypass
hit/miss debug counter
```

## 1. 文件

```text
rtl/mem/rv32i_dcache.v
rtl/mem/rv32i_sram_1r1w.v
sim/testcases/rv32i_dcache_tb.sv
sim/testcases/rv32i_pipe_dcache_tb.sv
filelist/cpu_filelist/mem_rtl.f
```

## 2. 为什么 D-cache 比 I-cache 多一层策略

I-cache 只读指令，所以 miss 后把 line 填回来就可以。D-cache 要处理 load 和 store，因此必须决定 store 怎么办。

常见写策略有：

- `write-through`：store 同时写 cache 和后端 memory
- `write-back`：store 先只写 cache，line 被替换时再写回后端 memory
- `write-allocate`：store miss 时先把 line 读进 cache，再执行 store
- `no-write-allocate`：store miss 时不分配 cache line，直接写后端 memory

当前选择：

```text
write-through + no-write-allocate
```

原因是简单可靠：

- 不需要 dirty bit
- 不需要 write-back FSM
- store miss 不需要先 refill 再写
- 后端 memory 始终保持最新数据
- 很适合第一版 blocking D-cache

代价是 store 性能一般，因为 store hit 也要等后端 memory 接受写请求。

## 3. 地址拆分

D-cache 和 I-cache 一样，每条 line 是 4 word，也就是 16 byte：

```text
31                 INDEX_BITS+4 INDEX_BITS+3      4 3     2 1 0
+------------------------------+-------------------+-------+---+
|              tag             |       index       | word  |byte|
+------------------------------+-------------------+-------+---+
```

代码里：

```verilog
assign cpu_index       = cpu_addr[INDEX_BITS+3:4];
assign cpu_tag         = cpu_addr[31:INDEX_BITS+4];
assign cpu_word_offset = cpu_addr[3:2];
```

`byte offset` 没有直接给 cache line 选择用，因为 `rv32i_pipe_lsu` 已经把 byte/halfword store 转成了 `wstrb` 和对齐后的 `wdata`。D-cache 会把 32-bit word 内的 `cpu_wstrb[3:0]` 扩展成 128-bit cache line 对应的 `data_wstrb[15:0]`，再交给 data SRAM 的 byte write mask。

## 4. Hit 路径

当前 tag/data 放在同步 SRAM 模型里，所以访问分成两拍：

```text
IDLE:
  latch CPU 请求
  用 index 同时读 way0/way1 的 tag SRAM 和 data SRAM

LOOKUP:
  比较 tag
  如果 load hit，返回对应 32-bit word
  如果 store hit，准备更新 cache line，并进入写穿状态
  如果 miss，进入 load refill 或 store direct
```

hit 判断：

```verilog
way0_valid[index] && way0_tag[index] == tag
way1_valid[index] && way1_tag[index] == tag
```

load hit 时：

```text
cpu_ready = 1
cpu_rdata = 命中的 32-bit word
```

store hit 时不会立刻 `ready`，因为当前策略是 write-through。它要等后端 memory 的写请求被接受以后，才对 CPU 侧返回 ready。

## 5. Load Miss Refill

load miss 时，D-cache 会选择一个 victim way，然后从后端 memory 取回整条 4-word line：

```text
base + 0
base + 4
base + 8
base + 12
```

最后一个 word 回来后：

```text
data_sram[index] = {word3, word2, word1, word0}
tag_sram[index]  = refill_tag
valid[index]     = 1
```

然后回到 `IDLE`。因为 CPU 侧的 `dmem_valid` 会被流水线保持住，D-cache 会重新 lookup 同一个地址，这次就会 hit，并把数据返回给 core。

## 6. Store Hit Write-Through

store hit 分两件事：

1. 更新 cache 里的对应 byte lane
2. 同时把 store 请求写到后端 memory

现在 cache line 更新不再先读出旧 line、组合合并、再整条写回，而是更接近真实 SRAM macro 的写法：

```text
cpu_wdata[31:0]   -> 扩展成 128-bit data_wdata
cpu_wstrb[3:0]    -> 按 word_offset 扩展成 16-bit data_wstrb
data SRAM         -> 只更新 data_wstrb 置 1 的 byte lane
```

例如 store 命中 line 内第 1 个 word，也就是 `word_offset=1`：

```text
cpu_wstrb = 4'b1111
data_wstrb = 16'b0000_0000_1111_0000
```

如果是 `sb`，`cpu_wstrb` 只有一个 bit 为 1，那么扩展到 16-bit 后也只会更新整条 cache line 里的一个 byte。这样避免了 D-cache 顶层自己做 read-modify-write，边界更像工业实现里的“控制逻辑 + SRAM byte mask”。

因为是 write-through，所以 store hit 完成条件是：

```text
后端 mem_ready = 1
```

只有后端 memory 接受了写请求，D-cache 才对 CPU 侧拉高 `cpu_ready`。

## 7. Store Miss No-Write-Allocate

store miss 时，当前版本不 refill，不分配 cache line。

流程是：

```text
store miss
  -> 直接把 cpu_addr/cpu_wdata/cpu_wstrb 发给后端 memory
  -> 等 mem_ready
  -> cpu_ready = 1
  -> 回到 IDLE
```

这样做很简单，而且后端 memory 一定是最新的。后续如果同一个地址被 load，D-cache 会正常发生 load miss，然后从后端 memory 把新数据 refill 回 cache。

## 8. MMIO Uncached Bypass

当前 D-cache 默认把 `0x4000_0000 - 0x4FFF_FFFF` 当成 uncached MMIO 区间：

```verilog
parameter [31:0] UNCACHED_BASE = 32'h4000_0000
parameter [31:0] UNCACHED_MASK = 32'hF000_0000
```

访问这个区间时，D-cache 不做 tag/data SRAM lookup，也不 refill cache line：

```text
load  -> 直接发后端读请求，mem_ready 后返回 mem_rdata
store -> 直接发后端写请求，mem_ready 后返回 cpu_ready
```

这样做是为了避免把 MMIO 外设寄存器缓存起来。比如 timer 的 `mtime` 每拍都可能变化，如果第一次读取后被 D-cache 缓存，第二次读就可能命中旧值。

uncached MMIO 访问不会增加 D-cache hit/miss 计数。

## 9. Replacement 策略

当前 replacement 和 I-cache 一样：

```verilog
assign victim_way = !way0_valid[index] ? 1'b0 :
                    !way1_valid[index] ? 1'b1 :
                                         replace_way_q[index];
```

规则：

- way0 无效，优先填 way0
- way1 无效，优先填 way1
- 两个 way 都有效，用 `replace_way_q[index]`
- 命中或 refill 某一路以后，下次倾向替换另一路

这是 pseudo-LRU，不是完整 LRU。

## 10. Testbench

独立 D-cache testbench：

```bash
cd /home2/kairos18/workspace/cpu_prj/sim
make sim TB_FILE=./testcases/rv32i_dcache_tb.sv TOP_NAME=rv32i_dcache_tb
```

覆盖点：

- load miss 后 refill 整条 line
- 同一条 line 内后续 load hit
- store hit 更新 cache，并 write-through 到后端 memory
- store miss no-write-allocate，直接写后端 memory
- store miss 后再 load，能从后端 memory refill 到新数据

流水线 + D-cache 集成 testbench：

```bash
cd /home2/kairos18/workspace/cpu_prj/sim
make sim TB_FILE=./testcases/rv32i_pipe_dcache_tb.sv TOP_NAME=rv32i_pipe_dcache_tb
```

覆盖点：

- `rv32i_pipe_core -> rv32i_dcache -> data memory`
- load miss 会通过 `dmem_ready=0` 冻结流水线
- store hit 会 write-through
- store miss 会 no-write-allocate
- 后续 load 能读回正确数据

## 11. 当前限制

当前 D-cache 仍然是第一版 blocking cache：

- 没有 dirty bit
- 没有 write-back
- 没有 write buffer / store buffer
- 没有 non-blocking miss
- 没有 cache flush/invalidate
- 没有非对齐访存异常
- D 侧 `mem_error` 已可返回给 core，形成 load/store access fault

下一步如果继续增强 D-cache，最自然的是加 store buffer，减少 store hit 等后端 memory 的停顿。再往后才是 write-back、dirty bit 和更完整的 bus 协议。
