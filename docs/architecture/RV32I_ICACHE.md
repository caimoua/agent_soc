# RV32I I-Cache 说明

这一阶段开始把流水线 core 外面的取指存储层搭起来。`rv32i_pipe_core` 已经支持 `imem_ready`，所以取指没返回时可以停住前端。`rv32i_icache` 就放在 core 和后端 instruction memory 之间，命中时通过同步 SRAM 查表后返回指令，未命中时拉低 ready，完成 refill 后再让流水线继续。

当前版本已经从最初的 1-word direct-mapped cache 升级为：

```text
2-way set associative
4-word cache line
blocking refill FSM
simple pseudo-LRU replacement bit
SRAM-style tag/data storage
hit/miss debug counter
```

这已经比最小 cache 更接近真实 L1 I-cache 的基本形态。

## 1. 文件

```text
rtl/mem/rv32i_sram_1r1w.v
rtl/mem/rv32i_icache.v
sim/testcases/rv32i_icache_tb.sv
sim/testcases/rv32i_pipe_icache_tb.sv
filelist/cpu_filelist/mem_rtl.f
```

`sim/filelist.f` 已加入 `mem_rtl.f`，所以仿真会自动编译 `rtl/mem` 下的 cache/memory 模块。

## 2. 模块位置

连接关系：

```text
rv32i_pipe_core
  imem_valid
  imem_addr
  imem_ready
  imem_rdata
      |
      v
rv32i_icache
      |
      v
后端 instruction memory / TCM / bus
```

CPU 侧接口：

```verilog
cpu_valid
cpu_addr
cpu_ready
cpu_rdata
```

后端 memory 侧接口：

```verilog
mem_valid
mem_addr
mem_ready
mem_rdata
```

现在后端仍是 testbench 里的数组 memory。以后可以替换成 TCM、ROM、AHB/AXI wrapper 或真正的 refill bus。

## 3. Cache 结构

当前 cache 是 2-way set associative：

```text
set[index]
  way0: valid + tag + data[0..3]
  way1: valid + tag + data[0..3]
```

每条 line 有 4 个 word：

```text
word0  word1  word2  word3
 32b    32b    32b    32b
```

RTL 中每条 data line 仍然是 128-bit，但是现在不再直接写成 cache 顶层里的大寄存器数组，而是通过 `rv32i_sram_1r1w` 仿真模型来承载 tag/data：

```verilog
rv32i_sram_1r1w u_way0_tag_sram
rv32i_sram_1r1w u_way1_tag_sram
rv32i_sram_1r1w u_way0_data_sram
rv32i_sram_1r1w u_way1_data_sram
```

这样做的好处是，cache 控制逻辑和 SRAM 存储体之间的边界更清楚。以后如果换成工艺库 SRAM macro，优先替换 `rv32i_sram_1r1w` 这一层，而不是把 cache 主逻辑整体重写。

`rv32i_sram_1r1w` 现在带有 `w_strb` 写掩码接口。I-cache 是只读 cache，refill 时仍然整条写入 tag/data SRAM，所以这里给 tag/data 的写掩码都是全 1；这个接口主要是为了 D-cache 的 byte/halfword/word store，以及后续替换成真实 SRAM macro 时保持边界一致。

当前分工是：

- `tag_sram`：保存每个 set、每个 way 对应的 tag
- `data_sram`：保存每个 set、每个 way 对应的 128-bit cache line
- `way*_valid`：仍然保留在 cache 顶层，用触发器保存，因为 valid bit 需要 reset 清零
- `replace_way_q`：仍然保留在 cache 顶层，用作简单 replacement bit

同一个 set 里有两个 way，所以两个地址即使 index 相同，只要 tag 不同，也可以同时存在于 way0 和 way1。

## 4. 地址拆分

当前每条 line 是 4 word，也就是 16 byte，所以 offset 是 4 bit：

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

含义：

- `tag`：判断这个 set 里的某个 way 是否来自目标主存区域
- `index`：选择 cache 的哪一个 set
- `word_offset`：选择当前 line 内的第几个 32-bit 指令
- `byte offset`：最低两位；RV32I 正常 32-bit 取指时为 `00`

如果 `INDEX_BITS=3`，cache 有 8 个 set。地址拆分就是：

```text
tag    = addr[31:7]
index  = addr[6:4]
word   = addr[3:2]
byte   = addr[1:0]
```

## 5. Hit 路径

因为 tag/data 已经放进同步 SRAM，所以一次访问分成两个小步骤：

```text
IDLE:
  收到 cpu_valid，拿 cpu_addr 拆出 index/tag/word_offset
  用 index 去读两个 way 的 tag SRAM 和 data SRAM

LOOKUP:
  SRAM 读数据已经出来
  比较 way0/way1 的 tag
  命中则返回对应 word
  未命中则进入 refill
```

比较两个 way 的逻辑是：

```verilog
way0_valid[index] && way0_tag[index] == cpu_tag
way1_valid[index] && way1_tag[index] == cpu_tag
```

任意一个 way 命中，就是 hit：

```verilog
cache_hit = way0_hit || way1_hit;
```

hit 后用 `word_offset` 从 128-bit line 里选一个 32-bit word：

```verilog
cpu_rdata = way0_hit ? way0_rdata :
            way1_hit ? way1_rdata :
                       32'd0;
```

对流水线 core 来说：

```verilog
cpu_ready = 1
cpu_rdata = 取到的指令
```

于是 IF 阶段可以正常进入 IF/ID。注意：和最早的寄存器数组组合读版本相比，现在同步 SRAM 版本的 hit 也会多一个 lookup 拍。这是刻意做的，因为真实 SRAM macro 通常也是时钟读，不是任意地址组合读。

## 6. Miss 和 Refill FSM

如果两个 way 都没命中，就是 miss。

miss 时 cache 会记录：

```verilog
refill_base_q
refill_index_q
refill_tag_q
refill_way_q
refill_word_q
```

其中 `refill_base_q` 是 16-byte 对齐的 line base：

```verilog
refill_base_q <= {cpu_addr[31:4], 4'b0000};
```

然后 cache 拉高后端请求：

```verilog
mem_valid = 1
mem_addr  = refill_base_q + refill_word_q * 4
```

`refill_word_q` 从 0 到 3，依次取回：

```text
base + 0
base + 4
base + 8
base + 12
```

每次 `mem_ready=1`，就把 `mem_rdata` 写入目标 way 的对应 word 位置。

最后一个 word 回来后：

```verilog
way_valid[index] = 1
way_tag[index]   = refill_tag_q
data_sram[index] = {word3, word2, word1, word0}
```

最后一个 word 回来后，cache 把完整 128-bit line 写入目标 way 的 data SRAM，并把 tag 写入 tag SRAM。随后 CPU 还在请求同一个 PC，cache 会重新发起一次 SRAM lookup；lookup 命中后 `cpu_ready` 拉高，流水线继续。

## 7. Replacement 策略

当前使用一个简单 replacement bit：

```verilog
replace_way_q[index]
```

规则：

- way0 无效时，优先填 way0
- way1 无效时，优先填 way1
- 两个 way 都有效时，用 `replace_way_q[index]` 选择替换哪一路
- 命中 way0 后，下次倾向替换 way1
- 命中 way1 后，下次倾向替换 way0
- refill way0 后，下次倾向替换 way1
- refill way1 后，下次倾向替换 way0

这不是完整 LRU，但已经具备 pseudo-LRU 的基本味道，适合作为第一版 2-way cache replacement。

## 8. 独立 I-Cache Testbench

```text
sim/testcases/rv32i_icache_tb.sv
```

运行：

```bash
cd /home2/kairos18/workspace/cpu_prj/sim
make sim TB_FILE=./testcases/rv32i_icache_tb.sv TOP_NAME=rv32i_icache_tb
```

覆盖点：

- 访问 `0x00` miss，refill 一整条 4-word line
- 访问 `0x04` 和 `0x0c` 命中同一条 line，验证空间局部性
- 访问 `0x40`，和 `0x00` 同 index 但不同 tag，填入另一个 way
- 再访问 `0x00`，确认 way0 仍然保留
- 访问 `0x80`，触发第三个同 index tag，验证 replacement
- 再访问被替换的地址，验证重新 refill

预期输出：

```text
[PASS] rv32i_icache_tb
  hit_count=8 miss_count=4
  2-way 4-word-line I-cache hit, miss, refill and replacement passed
```

## 9. Pipeline + I-Cache 集成 Testbench

```text
sim/testcases/rv32i_pipe_icache_tb.sv
```

运行：

```bash
cd /home2/kairos18/workspace/cpu_prj/sim
make sim TB_FILE=./testcases/rv32i_pipe_icache_tb.sv TOP_NAME=rv32i_pipe_icache_tb
```

连接关系：

```text
rv32i_pipe_core -> rv32i_icache -> testbench instruction memory
```

验证点：

- pipeline core 的 `imem_valid/imem_addr` 接到 I-cache CPU 侧
- I-cache 的 `cpu_ready/cpu_rdata` 返回给 pipeline core
- I-cache miss 时，pipeline core 通过 `imem_ready=0` 停住 IF 阶段
- refill 完成后，pipeline core 继续执行
- 通过 `ebreak` 结束，并检查 x1、x2、x3、x4 和 `instret`

预期输出类似：

```text
[PASS] rv32i_pipe_icache_tb
  pc=0x... cycle=... instret=5 stall_cycle=...
  icache_hit_count=... icache_miss_count=...
  rv32i_pipe_core fetch through 2-way 4-word-line rv32i_icache passed
```

相比 1-word line 版本，4-word line 会让顺序取指的 miss 数下降。比如 PC 连续访问 `0x00/0x04/0x08/0x0c` 时，第一次 miss 后会 refill 整条 line，后面几个 word 可以 hit。

## 10. 当前限制

当前 I-cache 仍然是 blocking cache：

- miss 时前端必须等待
- 没有 non-blocking miss
- 没有 MSHR
- 没有 burst bus 协议，只是用简单 `mem_valid/mem_ready`
- 没有 flush/invalidate
- 没有取指 bus error 或权限异常
- 没有 prefetch

但它现在已经有比较完整的 L1 I-cache 基本骨架：set/way、tag compare、line refill、replacement 和流水线前端握手。后续可以继续往 bus wrapper、TCM、flush/invalidate 或简单 prefetch 方向扩展。
