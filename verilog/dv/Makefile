# Makefile for 5-Stage RV32I Core Simulation

RTL_DIR = ../rtl
DV_DIR = .

SRCS = \
	$(RTL_DIR)/riscv_pkg.sv \
	$(RTL_DIR)/alu.sv \
	$(RTL_DIR)/if_stage.sv \
	$(RTL_DIR)/id_stage.sv \
	$(RTL_DIR)/ex_stage.sv \
	$(RTL_DIR)/mem_stage.sv \
	$(RTL_DIR)/wb_stage.sv \
	$(RTL_DIR)/forwarding_unit.sv \
	$(RTL_DIR)/hazard_unit.sv \
	$(RTL_DIR)/reg_file.sv \
	$(RTL_DIR)/rv32_core.sv \
	$(RTL_DIR)/rv32i_top.sv \
	$(DV_DIR)/sky130_sram_2kbyte_1rw1r_32x512_8.v \
	$(DV_DIR)/tb_rv32i_top.sv

.PHONY: all sim clean

all: sim

sim:
	iverilog -g2012 -o sim.vvp -I$(RTL_DIR) $(SRCS)
	vvp sim.vvp

clean:
	rm -f sim.vvp tb_rv32i_top.vcd
