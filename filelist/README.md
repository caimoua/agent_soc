# Filelist 目录

`sim/Makefile` 使用 `sim/filelist.f` 作为模板，并把其中的：

```text
../filelist/cpu_filelist
```

替换成 `FILELIST_DIR`。

默认值：

```text
FILELIST_DIR=$(REPO_ROOT)/filelist/cpu_filelist
```

当前分组 filelist：

- `cpu_filelist/common_rtl.f`
- `cpu_filelist/core_rtl.f`
- `cpu_filelist/mem_rtl.f`
- `cpu_filelist/bus_rtl.f`
- `cpu_filelist/periph_rtl.f`
- `cpu_filelist/accel_rtl.f`
- `cpu_filelist/top_rtl.f`
