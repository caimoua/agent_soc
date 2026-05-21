# 最小 SYSTEM/CSR 路径实现说明

## 1. 这次实现了什么

这次做的是 RV32I 里的最小 `SYSTEM` 指令路径，不是完整特权架构。

当前支持三类行为：

- `csrrs rd, cycle, x0`：读取只读 CSR `cycle`，把当前 cycle counter 写入通用寄存器 `rd`。
- `ecall`：译码为合法指令，并在 core debug 口输出一个 `dbg_ecall` 事件脉冲。
- `ebreak`：译码为合法指令，并在 core debug 口输出一个 `dbg_ebreak` 事件脉冲。

当前暂不实现 trap 跳转、`mtvec`、`mepc`、`mcause`、`mstatus`、异常返回 `mret`、CSR 写操作和 privilege mode。这是有意收敛范围：先把 `SYSTEM` 指令从“非法指令”路径中分出来，建立 CSR 读通路和事件观测点，后续再扩展成真正的异常/中断路径。

## 2. 指令编码

`SYSTEM` 指令的 opcode 是：

```verilog
`define RV32I_OPCODE_SYSTEM 7'b1110011
```

这版用到的三条指令编码如下：

```text
ecall                 = 0x00000073
ebreak                = 0x00100073
csrrs x25, cycle, x0  = 0xc0002cf3
```

`ecall` 和 `ebreak` 都属于 `funct3 = 3'b000` 的 SYSTEM 子类。它们不写通用寄存器，只产生事件。

`csrrs x25, cycle, x0` 属于 CSR 读写类指令：

```text
csr[11:0] = 0xc00       // cycle CSR
rs1       = x0          // 不修改 CSR，只读
funct3    = 3'b010      // CSRRS
rd        = x25         // 读出的 CSR 写回 x25
opcode    = 7'b1110011
```

这里选择 `CSRRS` 而不是额外自定义指令，是因为标准 RISC-V 里常见的伪指令 `csrr rd, csr` 本质上会汇编成：

```asm
csrrs rd, csr, x0
```

意思是读取 CSR，同时因为 `rs1 = x0`，所以不对 CSR 做 set bit 写修改。

## 3. 公共定义

在 `rtl/include/rv32i_defs.vh` 中新增了两个定义：

```verilog
`define RV32I_WB_CSR    3'b101
`define RV32I_CSR_CYCLE 12'hc00
```

`RV32I_WB_CSR` 是写回 mux 的新选择项，表示写回数据来自 CSR 读数据。

`RV32I_CSR_CYCLE` 是当前唯一支持的 CSR 地址。RISC-V 标准里 `cycle` CSR 地址是 `0xc00`，它表示 cycle counter。

## 4. Decoder 怎么改

`rv32i_decoder` 新增三个输出：

```verilog
output reg  [11:0] csr_addr,
output reg         system_ecall,
output reg         system_ebreak,
```

它们的含义是：

- `csr_addr`：告诉 core 当前 CSR 指令要读哪个 CSR。
- `system_ecall`：当前指令是合法 `ecall`。
- `system_ebreak`：当前指令是合法 `ebreak`。

在默认值里，这三个信号都清零：

```verilog
csr_addr      = 12'd0;
system_ecall  = 1'b0;
system_ebreak = 1'b0;
```

这样可以避免组合逻辑 latch，也保证非 SYSTEM 指令不会误触发事件。

新增的 SYSTEM 译码逻辑可以理解成两层判断：

```text
opcode == SYSTEM
  funct3 == 000:
    0x00000073 -> ecall
    0x00100073 -> ebreak
    else       -> illegal

  funct3 == 010:
    csr == cycle && rs1 == x0 -> csrrs rd, cycle, x0
    else                     -> illegal

  other funct3:
    illegal
```

这里的收敛点很重要：当前只允许 `rs1 = x0` 的 `CSRRS`。原因是 `CSRRS` 正常语义是“读 CSR，然后把 rs1 中为 1 的 bit set 到 CSR 里”。如果 `rs1 != x0`，就涉及 CSR 写修改；这版暂时没有 CSR 写端口，所以先把这种情况判为非法。

## 5. Core 数据通路怎么改

`rv32i_core` 新增两个 debug 输出：

```verilog
output wire dbg_ecall,
output wire dbg_ebreak
```

它们由 decoder 事件信号直接生成：

```verilog
assign dbg_ecall  = system_ecall && !illegal_instr;
assign dbg_ebreak = system_ebreak && !illegal_instr;
```

也就是说，只有被 decoder 认为是合法 SYSTEM 指令时，testbench 才能看到事件脉冲。

CSR 读数据目前只有 `cycle`：

```verilog
assign csr_rdata = (csr_addr == `RV32I_CSR_CYCLE) ? cycle_q : 32'd0;
```

然后在写回 mux 中增加一项：

```verilog
(wb_sel == `RV32I_WB_CSR) ? csr_rdata : ...
```

因此 `csrrs x25, cycle, x0` 的执行路径是：

```text
imem_rdata
  -> decoder 识别 SYSTEM/CSRRS/cycle
  -> wb_sel = RV32I_WB_CSR
  -> csr_addr = 0xc00
  -> csr_rdata = cycle_q
  -> regfile 写回 x25
```

`ecall` 和 `ebreak` 当前不会改变 PC。它们和普通非跳转指令一样，下一拍执行 `pc + 4`。这不是完整架构行为，只是这版最小路径的选择：先把事件识别和观测做出来，后续有 trap CSR 和 trap PC 之后，再让它们跳转到 trap handler。

## 6. Testbench 怎么验证

在 `sim/testcases/rv32i_core_tb.sv` 中，在现有 load/store 测试后加入这几条指令：

```verilog
imem[71]= 32'h0190_2823;   // sw    x25, 16(x0)
imem[72]= 32'hc000_2cf3;   // csrrs x25, cycle, x0
imem[73]= 32'h0000_0073;   // ecall
imem[74]= 32'h0010_0073;   // ebreak
```

第一条 `sw x25, 16(x0)` 是为了保存前面 JAL landing 测试的 `x25 = 0xDE`。后面的 CSR 测试会复用并覆盖 `x25`，所以先把旧结果写到 `dmem[4]`，最后检查 `dmem[4] == 0x000000DE`。

验证点有三个：

1. `csrrs x25, cycle, x0` 写回的 x25 必须非 0。
2. x25 中读出的 cycle 必须小于最终 `dbg_cycle`，说明它确实是在程序中间读到的计数值。
3. `ecall` 和 `ebreak` 必须分别在期望 PC 上出现。

期望 PC 是：

```text
imem[72] -> PC = 72 * 4 = 0x120
imem[73] -> PC = 73 * 4 = 0x124
imem[74] -> PC = 74 * 4 = 0x128
```

所以 testbench 检查：

```verilog
ecall_pc  == 32'h0000_0124
ebreak_pc == 32'h0000_0128
```

如果这两条 SYSTEM 指令仍然被 decoder 当作非法指令，`illegal_seen` 会先触发 `$fatal`。如果它们没有产生事件，`ecall_seen/ebreak_seen` 检查会失败。

## 7. 当前限制

当前实现只是最小路径，限制如下：

- `ecall` 不会进入 trap handler。
- `ebreak` 不会进入 debug mode。
- 没有 `mepc/mcause/mtvec/mstatus` 等机器态 CSR。
- 没有 `mret`。
- 没有 CSR 写操作。
- 只支持 `cycle` 一个只读 CSR。
- `csrrw/csrrc/csrrwi/csrrsi/csrrci` 仍然判为非法。

这些限制不是问题，反而是一个清晰的阶段边界。现在已经有了 SYSTEM opcode 入口、CSR 地址译码、CSR 读数据写回、事件输出。下一步要做完整异常/中断时，可以沿着这条路径继续扩展。

## 8. 后续可以怎么扩展

建议后续按这个顺序扩展：

1. 增加 `instret` CSR，用 retired instruction counter 驱动。
2. 增加 `mcycle/minstret` 机器态 CSR 别名。
3. 增加 `mtvec`、`mepc`、`mcause`，让 `ecall/ebreak/illegal_instr` 进入 trap。
4. 增加 `mret`，从 trap handler 返回。
5. 给流水线版本加入 exception flush，保证异常发生时 younger instruction 不提交。

到了流水线阶段，`SYSTEM/CSR` 就不只是一个译码功能，而会和 commit、flush、异常优先级、性能计数器联系起来。这个点很适合写进项目报告或面试材料里。
