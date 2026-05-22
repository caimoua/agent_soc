# 目录地图

最后更新：2026-05-22

本仓库从 `d:\AIoT\cpu_prj` 分叉而来，现在按 AI Agent MCU + NPU SoC 方向继续演进。目录分层的目标是让 CPU IP、SoC fabric、Agent 外设原型、软件镜像和验证入口各自有清楚的位置。

```text
ai_agent_mcu_npu_soc/
  rtl/
    core/       RV32I/RV32M pipeline core、decoder、CSR、hazard/control
    common/     ALU、regfile、计数器和共享 RTL
    mem/        I-cache、D-cache 和 memory model / SRAM-style 模块
    bus/        simple bus、AHB-Lite bridge、AHB matrix、AHB-to-APB
    periph/     通用 MMIO 外设：timer、UART、APB mux
    accel/      Agent/NPU 方向的叶子加速器原型
    agent/      Agent peripheral cluster 和后续 Agent 子系统骨架
    top/        CPU subsystem 和 SoC top wrappers
    include/    共享 Verilog 头文件

  filelist/
    cpu_filelist/
      common_rtl.f
      core_rtl.f
      mem_rtl.f
      bus_rtl.f
      periph_rtl.f
      accel_rtl.f
      agent_rtl.f
      top_rtl.f

  sim/
    Makefile
    filelist.f
    regress/
    scripts/
    testcases/

  software/
    asm/        directed test / smoke program 汇编源
    c/          后续 C runtime / driver 原型
    linker/
    scripts/
    bin/        生成的 MEMH 镜像

  docs/
    status/        项目状态、接口索引、验证矩阵、目录地图
    roadmap/       长期路线和阶段计划
    architecture/  RTL/SoC/Agent 模块设计说明
    verification/  ISA 测试和质量检查说明
    tooling/       工具链安装和使用说明
    adr/           架构决策记录
    figures/       图表和可视化资产

  project/     FPGA/EDA 工程占位
  ref/         参考资料笔记和小示例
  tools/       本地辅助脚本
```

生成文件优先放在 `sim/log/`、`sim/csrc/`、`sim/simv.daidir/`、波形文件和 `software/bin/`。源码主要放在 `rtl/`、`sim/testcases/`、`software/asm/`、`software/c/` 和 `docs/`。
