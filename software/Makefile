TOOLCHAIN_PREFIX ?= riscv-none-elf
RISCV_CC         ?= $(TOOLCHAIN_PREFIX)-gcc
RISCV_OBJCOPY    ?= $(TOOLCHAIN_PREFIX)-objcopy
PYTHON           ?= python

ARCH             ?= rv32i
ABI              ?= ilp32
LINKER_FLASH     ?= linker/rv32i_flash.ld
LINKER_ROM0      ?= linker/rv32i_rom0.ld
BUILD_DIR        ?= build
BIN_DIR          ?= bin

FLASH_PROGRAMS   := ahb_matrix_soc ahb_matrix_apb_soc
ROM0_PROGRAMS    := cached_system_smoke cached_ahb_master cached_uart cached_timer
ROM0_PROGRAMS    += cached_timer_irq cached_access_fault cached_instr_access_fault
ROM0_PROGRAMS    += cached_misaligned_trap
ROM0_PROGRAMS    += pipe_branch_predict pipe_dynamic_branch_predict
ROM0_PROGRAMS    += pipe_branch_predict_param pipe_muldiv
ROM0_PROGRAMS    += pipe_core trap_csr
ROM0_PROGRAMS    += core_smoke pipe_icache pipe_dcache pipe_cached_bus
ROM0_PROGRAMS    += isa_basic
ROM0_PROGRAMS    += agent_workload
PROGRAMS         := $(FLASH_PROGRAMS) $(ROM0_PROGRAMS)

COMMON_FLAGS     := -march=$(ARCH) -mabi=$(ABI) -nostdlib -nostartfiles -ffreestanding
LDFLAGS          = -Wl,-T,$(LINKER_SCRIPT) -Wl,--build-id=none

.PHONY: all clean check-tools
.SECONDARY: $(PROGRAMS:%=$(BUILD_DIR)/%.elf) $(PROGRAMS:%=$(BIN_DIR)/%.bin)

all: $(PROGRAMS:%=$(BIN_DIR)/%.memh)

check-tools:
	@command -v $(RISCV_CC) >/dev/null 2>&1 || { \
	  echo "ERROR: missing $(RISCV_CC). Set PATH, TOOLCHAIN_PREFIX, RISCV_CC, or omit software rebuild when checked-in MEMH images are sufficient."; \
	  exit 127; \
	}
	@command -v $(RISCV_OBJCOPY) >/dev/null 2>&1 || { \
	  echo "ERROR: missing $(RISCV_OBJCOPY). Set PATH, TOOLCHAIN_PREFIX, RISCV_OBJCOPY, or omit software rebuild when checked-in MEMH images are sufficient."; \
	  exit 127; \
	}

$(BUILD_DIR) $(BIN_DIR):
	mkdir -p $@

$(FLASH_PROGRAMS:%=$(BUILD_DIR)/%.elf): LINKER_SCRIPT = $(LINKER_FLASH)
$(ROM0_PROGRAMS:%=$(BUILD_DIR)/%.elf): LINKER_SCRIPT = $(LINKER_ROM0)
$(FLASH_PROGRAMS:%=$(BUILD_DIR)/%.elf): $(LINKER_FLASH)
$(ROM0_PROGRAMS:%=$(BUILD_DIR)/%.elf): $(LINKER_ROM0)
$(BUILD_DIR)/cached_timer_irq.elf: COMMON_FLAGS = -march=rv32i_zicsr -mabi=$(ABI) -nostdlib -nostartfiles -ffreestanding
$(BUILD_DIR)/pipe_muldiv.elf: COMMON_FLAGS = -march=rv32im -mabi=$(ABI) -nostdlib -nostartfiles -ffreestanding
$(BUILD_DIR)/isa_basic.elf: COMMON_FLAGS = -march=rv32im -mabi=$(ABI) -nostdlib -nostartfiles -ffreestanding
$(BUILD_DIR)/agent_workload.elf: COMMON_FLAGS = -march=rv32im -mabi=$(ABI) -nostdlib -nostartfiles -ffreestanding

$(BUILD_DIR)/%.elf: asm/%.S | $(BUILD_DIR) $(BIN_DIR)
	$(RISCV_CC) $(COMMON_FLAGS) $(LDFLAGS) -Wl,-Map,$(BIN_DIR)/$*.map -o $@ $<

$(BIN_DIR)/%.bin: $(BUILD_DIR)/%.elf | $(BIN_DIR)
	$(RISCV_OBJCOPY) -O binary $< $@

$(BIN_DIR)/%.memh: $(BIN_DIR)/%.bin scripts/bin_to_memh.py | $(BIN_DIR)
	$(PYTHON) scripts/bin_to_memh.py $< $@

clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR)/*.bin $(BIN_DIR)/*.elf $(BIN_DIR)/*.map
