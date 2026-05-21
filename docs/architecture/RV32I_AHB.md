# RV32I AHB-Lite Bus Path 说明

这一阶段新增一条 AHB-Lite 形式的系统总线路径。目标是让当前 simple `valid/ready` 内部总线可以通过标准 AHB address/data phase 访问 ROM、SRAM 和 MMIO，同时不破坏已经通过回归的 `rv32i_mem_bus`。

## 1. 新增模块

```text
rtl/bus/rv32i_simple_to_ahb.v
rtl/bus/rv32i_ahb_to_simple.v
rtl/bus/rv32i_ahb_lite_decoder.v
rtl/bus/rv32i_mem_bus_ahb.v
rtl/top/rv32i_cached_system_ahb_top.v
```

整体连接是：

```text
I-cache / D-cache simple memory ports
  |
  v
rv32i_mem_bus_ahb
  D-priority simple arbiter
  rv32i_simple_to_ahb
  rv32i_ahb_lite_decoder
  rv32i_ahb_to_simple x3
  |
  +-- ROM
  +-- SRAM
  `-- MMIO
```

`rv32i_cached_system_ahb_top` 和原来的 `rv32i_cached_system_top` 对外接口保持一致，只是内部 bus 从 `rv32i_mem_bus` 换成 `rv32i_mem_bus_ahb`。

## 2. 支持的 AHB-Lite 行为

当前实现支持：

- AHB address phase / data phase 分离。
- `HTRANS=NONSEQ/IDLE`。
- `HBURST=SINGLE`。
- `HSIZE=BYTE/WORD`，partial write 会拆成多个 byte transfer。
- `HPROT` 固定为 data/instruction-independent 的普通访问属性。
- `HREADY` wait-state。
- `HRESP=OKAY/ERROR`。
- unmapped 地址通过 AHB decoder 产生 ERROR response，再映射回 `i_error/d_error`。

当前实现不生成：

- INCR/WRAP burst。
- BUSY/SEQ burst continuation。
- SPLIT/RETRY。
- 多个 AHB master 同时访问不同 slave 的 bus matrix 并行路径。

原因是当前 core/cache 边界本身仍然是 blocking、single outstanding。先在这个边界后面接 AHB-Lite，可以保持 core/cache 简洁，也便于逐步验证协议行为。

## 3. byte strobe 处理

原 simple bus 有 `wstrb[3:0]`，AHB 没有 byte strobe，只有 `HSIZE` 和 `HADDR[1:0]`。

因此 `rv32i_simple_to_ahb` 做了转换：

```text
wstrb = 1111  -> 1 个 word transfer
wstrb = 其他  -> 每个置位 byte 拆成 1 个 byte transfer
wstrb = 0000  -> no-op write，直接完成
```

这样可以保留原 simple bus 的任意 byte mask 语义。比如 `wstrb=0101` 会被拆成 byte0 和 byte2 两个 AHB byte write。

## 4. 验证入口

独立 AHB memory bus：

```bash
cd sim
make sim TB_FILE=./testcases/rv32i_mem_bus_ahb_tb.sv TOP_NAME=rv32i_mem_bus_ahb_tb
```

Cached system + AHB bus path：

```bash
cd sim
make sim TB_FILE=./testcases/rv32i_cached_system_ahb_top_tb.sv TOP_NAME=rv32i_cached_system_ahb_top_tb
```

这两个 testbench 已由用户在 VCS 上确认 PASS。

## 5. 和参考工程的关系

参考工程 `D:\AIoT\rtl_riscv_AE350_clone` 里有 AE350/topo 的 AHB busmatrix、decoder 和 default slave。当前项目没有直接拷贝那些 IP，而是借鉴它们的接口结构：

- master 侧使用 `HADDR/HBURST/HPROT/HSIZE/HTRANS/HWRITE/HWDATA/HRDATA/HREADY/HRESP`。
- slave 侧使用 `HSEL/HREADYOUT/HRESP`。
- decoder 记录 data phase 的 slave 选择，再 mux 回 `HRDATA/HREADY/HRESP`。

后续如果要做真正多 master AHB matrix，可以在当前 `rv32i_simple_to_ahb` 后面继续扩展。

## 6. CPU subsystem AHB master top

`rv32i_cached_ahb_master_top` 是当前更推荐的 CPU IP 交付边界。它把 core、I-cache、D-cache 和 AHB master bus 放在 CPU 子系统内部，对外只暴露一个 AHB-Lite master port。

交付级接口、参数、限制和集成检查清单见：

```text
docs/architecture/RV32I_CPU_IP_DELIVERY.md
```

内部结构：

```text
rv32i_pipe_core
  -> rv32i_icache / rv32i_dcache
  -> rv32i_ahb_master_bus
```

外部 memory interface 是一个 AHB-Lite master port：

```text
ahb_haddr
ahb_hburst
ahb_hprot
ahb_hsize
ahb_htrans
ahb_hwdata
ahb_hwrite
ahb_hrdata
ahb_hready
ahb_hresp
```

ROM、SRAM、timer、UART、GPIO 和其他外设都应该在这个 top 外部通过 AHB decoder 或 bus matrix 连接。

验证入口：

```bash
cd sim
make sim TB_FILE=./testcases/rv32i_cached_ahb_master_top_tb.sv TOP_NAME=rv32i_cached_ahb_master_top_tb
```

这个 testbench 把 AHB decoder 和 ROM/SRAM/MMIO slave bridge 放在 CPU 子系统外部，用来证明 CPU 可以作为 AHB-Lite master IP 被外部 SoC 集成。

Stage A2 开始，这个 testbench 的 ROM 程序也改为从软件镜像加载。默认镜像为：

```text
software/bin/cached_ahb_master.memh
```

如果需要替换程序，可以在仿真时传入：

```bash
make sim TB_FILE=./testcases/rv32i_cached_ahb_master_top_tb.sv TOP_NAME=rv32i_cached_ahb_master_top_tb SIM_PLUSARGS="+ROM_MEMH=../software/bin/cached_ahb_master.memh"
```

该迁移后的版本已在 2026-05-20 由用户确认 VCS PASS。

## 7. Clean-room AHB-Lite Matrix SoC Top

下一步 SoC 集成使用项目内 clean-room AHB-Lite matrix，而不是把第三方 AE350/Andes/ARM 源码直接拷进仓库。

新增 RTL：

```text
rtl/bus/rv32i_ahb_lite_matrix_1m4s.v
rtl/top/rv32i_ahb_matrix_soc_top.v
```

`rv32i_ahb_matrix_soc_top` instantiates:

```text
rv32i_cached_ahb_master_top
  -> rv32i_ahb_lite_matrix_1m4s
      -> flash slot
      -> SRAM slot
      -> AHB peripheral slot
      -> APB peripheral slot
```

默认地址映射：

```text
0x0800_0000 - 0x0FFF_FFFF  flash
0x2000_0000 - 0x2FFF_FFFF  SRAM
0x4000_0000 - 0x41FF_FFFF  AHB peripherals
0x4200_0000 - 0x43FF_FFFF  APB peripherals
```

`RESET_PC` defaults to `0x0800_0000` in this SoC top, matching the flash slot. The lower CPU subsystem still defaults to `0x0000_0000`, so older tests keep their original behavior.

Verification entry:

```bash
cd sim
make sim TB_FILE=./testcases/rv32i_ahb_matrix_soc_top_tb.sv TOP_NAME=rv32i_ahb_matrix_soc_top_tb
```

该测试从 `software/bin/ahb_matrix_soc.memh` 加载 flash 程序，该镜像由 `software/asm/ahb_matrix_soc.S` 生成。用户已在 2026-05-15 确认该 MEMH-loader 流程 VCS PASS。
