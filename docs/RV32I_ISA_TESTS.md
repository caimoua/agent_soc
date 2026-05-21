# RV32I/RV32M ISA 基础测试说明

最后更新：2026-05-21

本文记录 Stage A3 新增的项目内 ISA 基础测试子集。它不是官方 `riscv-tests` 的完整替代，而是先给当前 core 建立一组稳定、快速、容易调试的 ISA smoke regression。

## 1. 文件

```text
software/asm/isa_basic.S
software/bin/isa_basic.memh
sim/testcases/rv32i_pipe_isa_basic_tb.sv
```

`isa_basic.S` 使用 RISC-V GNU 工具链编译成 `isa_basic.memh`，testbench 通过 `$readmemh` 加载到 instruction memory。

## 2. 覆盖范围

当前第一版覆盖：

- RV32I register-register arithmetic：`add`, `sub`, `slt`, `sltu`, `xor`, `or`, `and`, shifts。
- RV32I immediate arithmetic：`addi`, `slti`, `sltiu`, `xori`, `ori`, `andi`, `slli`, `srli`, `srai`。
- upper immediate / PC-relative：`lui`, `auipc`。
- branch/jump：`beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`, `jal`, `jalr`。
- load/store：`lb`, `lh`, `lw`, `lbu`, `lhu`, `sb`, `sh`, `sw`，包含 byte lane 和符号扩展检查。
- RV32M：`mul`, `mulh`, `mulhsu`, `mulhu`, `div`, `divu`, `rem`, `remu`。
- RV32M 边界：divide by zero、`INT_MIN / -1` overflow。

程序内部会在每个检查点比较实际结果和期望值。失败时写入 `x30` fail code 并执行 `ebreak`；通过时写入：

```text
x31 = 1
x30 = 0
x29 = 0x1a500003
```

testbench 同时检查 data memory signature：

```text
dmem[0] = 0x12345678
dmem[1] = 0x000080ff
dmem[2] = 0x00008001
dmem[3] = 0x0000aa00
```

## 3. 运行方式

单独运行：

```bash
cd sim
make sim TB_FILE=./testcases/rv32i_pipe_isa_basic_tb.sv TOP_NAME=rv32i_pipe_isa_basic_tb
```

也可以通过新加的 `isa` suite 运行：

```bash
cd sim
bash ./regress/run_regression.sh --suite isa --keep-going
```

Windows PowerShell：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\sim\regress\run_regression.ps1 -Suite isa
```

## 4. 软件镜像生成

如果工具链已加入 PATH：

```bash
make -C software bin/isa_basic.memh
```

当前 Windows 本机可用的工具链位置为：

```text
D:\AIoT\tools\riscv-none-elf-gcc-15.2.0-1\xpack-riscv-none-elf-gcc-15.2.0-1\bin
D:\AIoT\tools\ezwinports-make\bin
```

如果没有重新构建工具链，也可以直接使用仓库中的 `software/bin/isa_basic.memh`。

## 5. 当前状态

本地已完成：

- `isa_basic.memh` 生成。
- PowerShell `isa` suite dry-run。
- Bash `isa` suite dry-run。
- `git diff --check`。

用户已在 Linux/VCS 环境确认 `rv32i_pipe_isa_basic_tb` PASS：

```text
cycle=476
instret=184
stall_cycle=190
flush_cycle=49
branch_count=48
branch_mispredict_count=48
```

`rv32i_pipe_isa_basic_tb` 在验证矩阵中已标记为 `PASS`。
