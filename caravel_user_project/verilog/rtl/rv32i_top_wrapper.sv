// Wrapper to compile all SystemVerilog files as a single compilation unit for Yosys

`include "riscv_pkg.sv"
`include "alu.sv"
`include "if_stage.sv"
`include "id_stage.sv"
`include "ex_stage.sv"
`include "mem_stage.sv"
`include "wb_stage.sv"
`include "forwarding_unit.sv"
`include "hazard_unit.sv"
`include "reg_file.sv"
`include "rv32_core.sv"
`include "rv32i_top.sv"
