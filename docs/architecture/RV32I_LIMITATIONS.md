# RV32I CPU IP Limitations

最后更新：2026-05-21

本文记录当前 CPU/SoC 基线的已知限制，避免 Agent SoC 路线推进时误把现有能力当成完整 MCU/NPU 平台。

## ISA

- 当前主流水 CPU 支持 RV32IM 子集。
- 暂不支持 compressed instruction。
- 暂不支持 atomics。
- 暂不支持 bitmanip。
- 暂不支持自定义 dot / matrix 指令。

## Privilege And Trap

- 当前是简化 machine mode 设计。
- 暂不支持 user mode。
- 暂不支持 PMP。
- 暂不支持 MMU 和 page fault。
- 当前中断路径以 machine timer interrupt 为主，还没有 CLIC/PLIC。

## Cache And Memory

- I-cache 和 D-cache 都是 blocking cache。
- 当前没有 cache miss outstanding transaction。
- 当前没有 refill burst。
- D-cache 是 write-through、no-write-allocate。
- 当前没有 cache coherency 机制。

## Bus And SoC

- 推荐 CPU 交付边界是 `rv32i_cached_ahb_master_top`。
- 当前 AHB-Lite master 是 single outstanding。
- 当前 SoC fabric 仍是小型 AHB-Lite / APB 结构；已新增保守的 2-master 前端用于 accelerator SRAM-mode，但还不是完整 AXI4 / burst-capable fabric。
- 当前没有 AXI4 crossbar。
- 当前没有 DMA master。
- 当前没有 QSPI/PSRAM/HyperRAM 控制器 RTL。

## Agent SoC Gap

当前仓库还没有这些目标模块：

- NPU systolic array。
- NPU tensor sequencer / microcode SRAM。
- NPU local buffer。
- Agent Matrix Accelerator 目前有 APB scratchpad v0.2a 和 SRAM-mode v0.2b 原型，但还不是完整 NPU，也没有 burst DMA、tiling sequencer 或大阵列。
- Tool-call Detector。
- Token Sampler。
- KV-cache Manager。
- Grammar FSM。
- Embedding Lookup helper。

这些模块的第一版落地顺序见 `docs/roadmap/AGENT_SOC_ARCH_V0.md`。
