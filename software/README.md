# Software 目录

## 汇编到 MEMH 流程

新的 directed test 程序应该优先写在 `asm/*.S` 里，再生成给 SystemVerilog `$readmemh` 使用的 memory image。

```bash
cd software
make
```

默认目标会构建：

```text
asm/ahb_matrix_soc.S
  -> build/ahb_matrix_soc.elf
  -> bin/ahb_matrix_soc.bin
  -> bin/ahb_matrix_soc.memh
```

当前默认构建的 directed software image 包括：

```text
ahb_matrix_soc
ahb_matrix_apb_soc
cached_system_smoke
cached_ahb_master
cached_timer
cached_uart
cached_timer_irq
cached_access_fault
cached_instr_access_fault
cached_misaligned_trap
pipe_branch_predict
pipe_dynamic_branch_predict
pipe_branch_predict_param
pipe_muldiv
pipe_core
trap_csr
core_smoke
pipe_icache
pipe_dcache
pipe_cached_bus
isa_basic
agent_workload
```

`ahb_matrix_*` 程序使用 `linker/rv32i_flash.ld`，从 `0x0800_0000` flash slot 启动。`cached_*` 程序使用 `linker/rv32i_rom0.ld`，从 `0x0000_0000` ROM slot 启动，供 cached system wrapper 类 testbench 加载。

`cached_timer_irq` 使用 CSR 汇编助记符，Makefile 会对该目标单独使用 `-march=rv32i_zicsr`。`pipe_muldiv`、`isa_basic` 和 `agent_workload` 使用 RV32M 助记符，Makefile 会对这些目标单独使用 `-march=rv32im`。其他 trap/fault/CSR 测试为了保持 RV32I-only 编译路径，CSR/MRET 指令仍用 `.word` 写入。

默认工具链前缀是 `riscv-none-elf`，对应 xPack RISC-V embedded GCC。可以按本机安装情况覆盖：

```bash
make TOOLCHAIN_PREFIX=riscv64-unknown-elf
```

`bin/*.memh` 可以提交，用来保证仿真环境没有本地 RISC-V 工具链时仍能跑现有 test。`build/`、`bin/*.elf`、`bin/*.bin` 和 map 文件不提交。

更多安装说明见 `docs/tooling/RISCV_TOOLCHAIN.md`。

这个目录用于放 CPU 测试程序。

计划结构：

- `asm/`：手写汇编 directed test
- `c/`：小型 C 程序
- `linker/`：linker script
- `scripts/`：ELF、HEX、MEM 转换脚本
- `bin/`：生成的二进制文件或 memory image
