# ----------------------------------------------------------------------
#
# File: chimera.mk
#
# Created: 26.06.2024        
# 
# Copyright (C) 2024, ETH Zurich and University of Bologna.
#
# Author: Moritz Scherer, ETH Zurich
#
# ----------------------------------------------------------------------
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the License); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an AS IS BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# SCHEREMO: This is a test config; change to something reasonable!

CLINTCORES = 46 
PLICCORES = 92
PLIC_NUM_INTRS = 92

.PHONY: update_plic
update_plic: $(CHS_ROOT)/hw/rv_plic.cfg.hjson
	sed -i 's/src: .*/src: $(PLIC_NUM_INTRS),/' $<
	sed -i 's/target: .*/target: $(PLICCORES),/' $<

.PHONY: chs-hw-init
chs-hw-init: update_plic
	make -B chs-hw-all CHS_XLEN=$(CHS_XLEN)

.PHONY: snitch-hw-init
snitch-hw-init:
	make -C $(SNITCH_ROOT)/target/snitch_cluster bin/snitch_cluster.vsim

.PHONY: $(CHIM_SW_DIR)/include/regs/soc_ctrl.h
$(CHIM_SW_DIR)/include/regs/soc_ctrl.h: $(CHIM_ROOT)/hw/regs/chimera_regs.hjson
	python $(CHIM_ROOT)/utils/reggen/regtool.py -D $<  > $@

.PHONY: $(CHIM_SW_DIR)/hw/regs/pcr.md
$(CHIM_HW_DIR)/regs/pcr.md: $(CHIM_ROOT)/hw/regs/chimera_regs.hjson
	python $(CHIM_ROOT)/utils/reggen/regtool.py -d $<  > $@


.PHONY: snitch_bootrom
CHIM_BROM_SRCS = $(wildcard $(CHIM_ROOT)/hw/bootrom/snitch/*.S $(CHIM_ROOT)/hw/bootrom/snitch/*.c) $(CHIM_SW_LIBS)
CHIM_BROM_FLAGS = $(CHS_SW_LDFLAGS) -Os -fno-zero-initialized-in-bss -flto -fwhole-program -march=rv32im

CHIM_BOOTROM_ALL += $(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.sv $(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.dump

snitch_bootrom: $(CHIM_BOOTROM_ALL)

$(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.elf: $(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.ld $(CHIM_BROM_SRCS)
	$(CHS_SW_CC) -I$(CHIM_SW_DIR)/include/regs $(CHS_SW_INCLUDES) -T$< $(CHIM_BROM_FLAGS) -o $@ $(CHIM_BROM_SRCS)

$(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.bin: $(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.elf
	$(CHS_SW_OBJCOPY) -O binary $< $@

$(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.sv: $(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.bin $(CHS_ROOT)/util/gen_bootrom.py
	$(CHS_ROOT)/util/gen_bootrom.py --sv-module snitch_bootrom $< > $@

.PHONY: regenerate_soc_regs
regenerate_soc_regs: $(CHIM_ROOT)/hw/regs/chimera_reg_pkg.sv $(CHIM_ROOT)/hw/regs/chimera_reg_top.sv $(CHIM_SW_DIR)/include/regs/soc_ctrl.h $(CHIM_HW_DIR)/regs/pcr.md

.PHONY: $(CHIM_ROOT)/hw/regs/chimera_reg_pkg.sv hw/regs/chimera_reg_top.sv
$(CHIM_ROOT)/hw/regs/chimera_reg_pkg.sv $(CHIM_ROOT)/hw/regs/chimera_reg_top.sv: $(CHIM_ROOT)/hw/regs/chimera_regs.hjson
	python $(CHIM_ROOT)/utils/reggen/regtool.py -r $< --outdir $(dir $@)

-include $(CHIM_ROOT)/bender.mk

-include $(CHIM_ROOT)/sim.mk
-include $(CHIM_ROOT)/sw/sw.mk
