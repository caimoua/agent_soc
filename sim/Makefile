# Useful variables

REPO_ROOT ?= $(abspath ..)
RTL_DIR ?= $(REPO_ROOT)/rtl
FILELIST_DIR ?= $(REPO_ROOT)/filelist/cpu_filelist

VCS ?= /opt/eda/synopsys/vcs/O-2018.09-SP2/bin/vcs
VERDI ?= verdi

TOP_NAME ?= rv32i_core_tb
TB_FILE ?= ./testcases/rv32i_core_tb.sv
OUTPUT ?= simv
LOG_DIR ?= ./log
FILELIST_TEMPLATE ?= ./filelist.f
GENERATED_FILELIST ?= $(LOG_DIR)/filelist.generated.f
FILELIST ?= $(GENERATED_FILELIST)
SIM_PLUSARGS ?=

COMMON_VCS_OPTIONS = $(VCS) +v2k \
	-sverilog \
	-full64 \
	-debug_access+all \
	-override_timescale=1ns/1ps \
	+vcs+flush+all \
	+lint=TFIPC-L \
	-o $(OUTPUT) \
	-l $(LOG_DIR)/compile.log \
	-f $(FILELIST)

VCS_OPTIONS = $(COMMON_VCS_OPTIONS) $(TB_FILE)

.PHONY: help check_filelist com sim verdi clean

help:
	@echo "Targets:"
	@echo "  make com   - compile $(TB_FILE)"
	@echo "  make sim   - compile and run $(TB_FILE)"
	@echo "  make verdi - open FSDB"
	@echo "  make clean - remove generated simulation artifacts"
	@echo ""
	@echo "Default paths:"
	@echo "  REPO_ROOT=$(REPO_ROOT)"
	@echo "  RTL_DIR=$(RTL_DIR)"
	@echo "  FILELIST_DIR=$(FILELIST_DIR)"
	@echo "  TB_FILE=$(TB_FILE)"
	@echo "  TOP_NAME=$(TOP_NAME)"

$(LOG_DIR):
	mkdir -p $(LOG_DIR)

check_filelist:
	@test -d "$(FILELIST_DIR)" || { \
		echo "ERROR: missing FILELIST_DIR=$(FILELIST_DIR)"; \
		echo "Try: make help"; \
		exit 1; \
	}

$(GENERATED_FILELIST): $(FILELIST_TEMPLATE) | $(LOG_DIR)
	sed 's#../filelist/cpu_filelist#$(FILELIST_DIR)#g' $< > $@

com: check_filelist $(FILELIST) | $(LOG_DIR)
	$(VCS_OPTIONS) -top $(TOP_NAME)

sim: com
	@export TOP_NAME=$(TOP_NAME); \
	./$(OUTPUT) \
	-ucli -i ./scripts/dump_fsdb.tcl \
	$(SIM_PLUSARGS) \
	+fsdb+autoflush \
	-l $(LOG_DIR)/sim.log

verdi: check_filelist $(FILELIST) | $(LOG_DIR)
	$(VERDI) \
	-sv \
	-f $(FILELIST) \
	$(TB_FILE) \
	-top $(TOP_NAME) \
	-ssf ./$(TOP_NAME).fsdb \
	-vcs_assert off \
	-nolog &

clean:
	rm -rf *~ core csrc simv simv.daidir vc_hdrs.h ucli.key urg* *.log novas.* *.fsdb* verdiLog 64* DVEfiles *.vpd ./fsdb $(LOG_DIR)/filelist.generated.f
