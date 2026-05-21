# RV32I 非对齐地址异常

本文记录当前非对齐地址 trap 的实现方式。

## 支持的 mcause

```text
0  instruction address misaligned
4  load address misaligned
6  store/AMO address misaligned
```

当前 core 不支持 compressed instruction，所以合法取指目标必须 4 字节对齐。

## RTL 行为

- taken branch/JAL/JALR 的目标地址在 EX 阶段检查。
- 如果目标地址不是 4 字节对齐，则抑制 redirect，让 faulting control-flow 指令继续到 commit 阶段产生 trap。
- load/store 的地址对齐在 `rv32i_pipe_lsu` 中检查，检查点位于 D 侧 bus 请求发出之前。
- 非对齐 load/store 不会拉高 `dmem_valid`，因此不会产生 bus decode error，也不会发生部分写入。
- 复用现有 `rv32i_pipe_csr` commit-time trap 路径：保存 `mepc`、写入 `mcause`、跳转到 `mtvec`，并清空 younger 指令。

## 对齐规则

```text
instruction target: addr[1:0] == 2'b00
byte load/store:    always aligned
half load/store:    addr[0] == 1'b0
word load/store:    addr[1:0] == 2'b00
```

## 定向测试

```bash
make sim TB_FILE=./testcases/rv32i_cached_misaligned_trap_tb.sv TOP_NAME=rv32i_cached_misaligned_trap_tb
```

ROM 程序已经迁移到软件镜像流：

```text
software/asm/cached_misaligned_trap.S
software/bin/cached_misaligned_trap.memh
```

testbench 默认从 `../software/bin/cached_misaligned_trap.memh` 加载，也可以通过 `+ROM_MEMH=<path>` 覆盖。

这个测试覆盖：

- `lw` from `0x2000_0002`, expecting `mcause=4`.
- `sw` to `0x2000_001a`, expecting `mcause=6` and no SRAM write.
- `jalr` to target `0x0000_0032`, expecting `mcause=0`.
- 每个 handler 都会保存 `mcause/mepc`，把 `mepc` 加 4 跳过 faulting 指令，然后通过 `mret` 返回。

状态：2026-05-20 软件镜像加载重构后，用户已确认 VCS PASS。
