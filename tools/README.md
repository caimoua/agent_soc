# Tools 目录

本地辅助脚本放在这里。生成文件尽量放到 `sim/log`、`software/bin` 或 `project/log`，避免和源码混在一起。

当前辅助脚本：

- `quality/run_quality_checks.ps1`
- `quality/run_quality_checks.sh`

这两个脚本用于 Stage A4 的 filelist、lint、综合和时序基础检查入口。说明见 `docs/verification/RV32I_QUALITY_CHECKS.md`。
