# OpenLane Configuration for rv32i_top (5-Stage RISC-V)

set ::env(DESIGN_NAME) "rv32i_top"

set ::env(VERILOG_FILES) "\
    $::env(DESIGN_DIR)/../../verilog/rtl/riscv_pkg.sv \
    $::env(DESIGN_DIR)/../../verilog/rtl/alu.sv \
    $::env(DESIGN_DIR)/../../verilog/rtl/if_stage.sv \
    $::env(DESIGN_DIR)/../../verilog/rtl/id_stage.sv \
    $::env(DESIGN_DIR)/../../verilog/rtl/ex_stage.sv \
    $::env(DESIGN_DIR)/../../verilog/rtl/mem_stage.sv \
    $::env(DESIGN_DIR)/../../verilog/rtl/wb_stage.sv \
    $::env(DESIGN_DIR)/../../verilog/rtl/forwarding_unit.sv \
    $::env(DESIGN_DIR)/../../verilog/rtl/hazard_unit.sv \
    $::env(DESIGN_DIR)/../../verilog/rtl/reg_file.sv \
    $::env(DESIGN_DIR)/../../verilog/rtl/rv32_core.sv \
    $::env(DESIGN_DIR)/../../verilog/rtl/rv32i_top.sv"

# Clock configuration
set ::env(CLOCK_PORT) "clk"
set ::env(CLOCK_PERIOD) "10.0"

# Die Area (adjust based on cell count and SRAM macros)
set ::env(DIE_AREA) "0 0 1500 1500"

# Target density
set ::env(FP_CORE_UTIL) 35
set ::env(PL_TARGET_DENSITY) 0.40

# SRAM Macros (Blackboxing for synthesis/PD)
set ::env(VERILOG_FILES_BLACKBOX) "\
    $::env(DESIGN_DIR)/../../verilog/dv/sky130_sram_2kbyte_1rw1r_32x512_8.v"

set ::env(EXTRA_LEFS) ""
set ::env(EXTRA_GDS_FILES) ""

# Power configuration
set ::env(VDD_NETS) [list {vccd1} {vccd2} {vdda1} {vdda2}]
set ::env(GND_NETS) [list {vssd1} {vssd2} {vssa1} {vssa2}]

set ::env(DIODE_INSERTION_STRATEGY) 4
set ::env(RUN_MAGIC) 1
set ::env(RUN_LVS) 1
