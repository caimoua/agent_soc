# RISC-V GNU Toolchain Setup

This project can run checked-in `software/bin/*.memh` files without a local RISC-V toolchain. Install the toolchain when you want to regenerate memory images from `software/asm/*.S`.

## Windows Recommended Path

Install the xPack RISC-V embedded GCC package through `xpm`:

```powershell
npm install --global xpm@latest
cd D:\AIoT\cpu_prj\software
xpm install @xpack-dev-tools/riscv-none-elf-gcc@latest --global
```

Make sure the xPack binary folder is in `PATH`, then check:

```powershell
riscv-none-elf-gcc --version
riscv-none-elf-objcopy --version
```

The project `software/Makefile` defaults to:

```text
TOOLCHAIN_PREFIX = riscv-none-elf
```

So the normal build command is:

```bash
cd software
make
```

On the current Windows workstation, the verified local installation paths are:

```text
D:\AIoT\tools\riscv-none-elf-gcc-15.2.0-1\xpack-riscv-none-elf-gcc-15.2.0-1\bin
D:\AIoT\tools\ezwinports-make\bin
```

Both paths have been added to the user `PATH`. Open a new PowerShell before relying on the persisted environment.

## Linux / EDA Server Path

Many Linux RISC-V GNU toolchain installs use the `riscv64-unknown-elf` prefix. Use:

```bash
cd software
make TOOLCHAIN_PREFIX=riscv64-unknown-elf
```

## Generated Files

The flow is:

```text
asm/<name>.S
  -> build/<name>.elf
  -> bin/<name>.bin
  -> bin/<name>.memh
```

Only `.memh` files are intended to be committed. ELF, BIN, MAP, and object files are ignored.
