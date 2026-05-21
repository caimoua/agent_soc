# 目录地图

这个项目的组织方式参考 M55 项目，但规模更小，便于逐步学习 CPU 微架构。

```text
cpu_prj/
  rtl/
    core/       CPU core 微架构
    common/     ALU、regfile、计数器和共享 RTL
    top/        仿真或 SoC 顶层 wrapper，例如 rv32i_cached_system_top
    bus/        内部 memory bus、后续 AHB/AXI adapter
    mem/        后续 memory 和 cache 模块
    periph/     timer、UART、debug 等 MMIO 外设
    include/    共享 Verilog 头文件
  filelist/
    cpu_filelist/
  sim/
    Makefile
    filelist.f
    scripts/
    testcases/
  software/
    asm/
    c/
    linker/
    scripts/
    bin/
  docs/
  project/
  ref/
  tools/
```

生成文件统一放在 `sim/log`、`sim/csrc`、`sim/simv.daidir` 和波形文件中。源码主要放在 `rtl`、`sim/testcases`、`software` 和 `docs`。
