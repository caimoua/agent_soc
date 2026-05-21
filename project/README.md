# Project 目录

当 CPU 从纯 RTL 仿真继续发展到 FPGA、EDA 或 IDE 工程时，相关工程文件可以放在这里。

当前已有 Stage A4 基础交付检查相关内容：

- `constraints/rv32i_cached_ahb_master_top.sdc`：CPU IP 交付边界的初始 SDC。
- `log/quality/`：质量检查脚本生成的日志目录，已加入 `.gitignore`。

质量检查入口见 `tools/quality/` 和 `docs/RV32I_QUALITY_CHECKS.md`。
