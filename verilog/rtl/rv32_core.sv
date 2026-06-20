//-----------------------------------------------------------------------------
// Module: rv32_core
// File:   rv32_core.sv
//
// Description:
//   5-Stage RV32I CPU Core Top Level.
//   Instantiates the IF, ID, EX, MEM, WB stages, Register File, Hazard Unit,
//   and Forwarding Unit. Defines the pipeline boundary struct connections.
//
// Author: Assistant
// Date:   2026-06-09
//-----------------------------------------------------------------------------

import riscv_pkg::*;

module rv32_core (
    input  logic        clk,
    input  logic        rst_n,

    // IMEM interface
    output logic        imem_en,
    output logic [31:0] imem_addr,
    input  logic [31:0] imem_rdata,

    // DMEM interface
    output logic        dmem_en,
    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_wdata,
    output logic [3:0]  dmem_wmask,
    output logic        dmem_we,
    input  logic [31:0] dmem_rdata,

    // Debug interface
    input  logic        dbg_halt,
    input  logic        dbg_write_en,
    input  logic [4:0]  dbg_reg_addr,
    input  logic [31:0] dbg_write_data,
    output logic [31:0] dbg_read_data
);

    //--------------------------------------------------------------------------
    // Pipeline Registers (Packed Structs)
    //--------------------------------------------------------------------------
    if_id_t  if_id_reg;
    id_ex_t  id_ex_reg;
    ex_mem_t ex_mem_reg;
    mem_wb_t mem_wb_reg;

    //--------------------------------------------------------------------------
    // Inter-stage Signals
    //--------------------------------------------------------------------------
    logic        branch_taken;
    logic [31:0] branch_target;

    logic        stall_if, stall_id, stall_ex, stall_mem;
    logic        flush_if, flush_id, flush_ex, flush_mem;

    logic [4:0]  rs1_addr, rs2_addr;
    logic [31:0] rs1_data, rs2_data;

    logic [4:0]  rd_addr;
    logic [31:0] rd_data;
    logic        rd_write_en;

    logic [1:0]  forward_a;
    logic [1:0]  forward_b;
    logic [31:0] forward_ex_mem_data;
    logic [31:0] forward_mem_wb_data;

    //--------------------------------------------------------------------------
    // Hazard Unit
    //--------------------------------------------------------------------------
    hazard_unit u_hazard_unit (
        .id_ex_mem_read (id_ex_reg.mem_read),
        .id_ex_rd_addr  (id_ex_reg.rd_addr),
        .if_id_rs1_addr (if_id_reg.inst[19:15]),
        .if_id_rs2_addr (if_id_reg.inst[24:20]),
        .branch_taken   (branch_taken),
        .stall_if       (stall_if),
        .stall_id       (stall_id),
        .flush_if       (flush_if),
        .flush_id       (flush_id),
        .flush_ex       (flush_ex)
    );

    // Stalls/Flushes for MEM and WB (not used in base 5-stage, tied to 0)
    assign stall_ex  = dbg_halt; // Halt pipeline for debug
    assign stall_mem = dbg_halt;
    assign flush_mem = 1'b0;

    // Combine dbg_halt with hazard stalls
    logic real_stall_if, real_stall_id;
    assign real_stall_if = stall_if | dbg_halt;
    assign real_stall_id = stall_id | dbg_halt;

    //--------------------------------------------------------------------------
    // Forwarding Unit
    //--------------------------------------------------------------------------
    assign forward_ex_mem_data = ex_mem_reg.alu_result; // Forward ALU result from EX/MEM
    assign forward_mem_wb_data = rd_data;               // Forward fully resolved WB data

    forwarding_unit u_forwarding_unit (
        .id_ex_rs1_addr   (id_ex_reg.rs1_addr),
        .id_ex_rs2_addr   (id_ex_reg.rs2_addr),
        .ex_mem_reg_write (ex_mem_reg.reg_write),
        .ex_mem_rd_addr   (ex_mem_reg.rd_addr),
        .mem_wb_reg_write (mem_wb_reg.reg_write),
        .mem_wb_rd_addr   (mem_wb_reg.rd_addr),
        .forward_a        (forward_a),
        .forward_b        (forward_b)
    );

    //--------------------------------------------------------------------------
    // Register File
    //--------------------------------------------------------------------------
    reg_file u_reg_file (
        .clk         (clk),
        .rst_n       (rst_n),
        .rs1_addr    (rs1_addr),
        .rs1_data    (rs1_data),
        .rs2_addr    (rs2_addr),
        .rs2_data    (rs2_data),
        .rd_addr     (rd_addr),
        .rd_data     (rd_data),
        .rd_write_en (rd_write_en),
        .dbg_addr    (dbg_reg_addr),
        .dbg_wdata   (dbg_write_data),
        .dbg_we      (dbg_write_en),
        .dbg_rdata   (dbg_read_data)
    );

    //--------------------------------------------------------------------------
    // Pipeline Stages
    //--------------------------------------------------------------------------

    // Instruction Fetch Stage
    if_stage u_if_stage (
        .clk           (clk),
        .rst_n         (rst_n),
        .stall_if      (real_stall_if),
        .flush_if      (flush_if),
        .branch_taken  (branch_taken),
        .branch_target (branch_target),
        .imem_en       (imem_en),
        .imem_addr     (imem_addr),
        .imem_rdata    (imem_rdata),
        .if_id_out     (if_id_reg)
    );

    // Instruction Decode Stage
    id_stage u_id_stage (
        .clk           (clk),
        .rst_n         (rst_n),
        .stall_id      (real_stall_id),
        .flush_id      (flush_id),
        .if_id_in      (if_id_reg),
        .rs1_addr      (rs1_addr),
        .rs2_addr      (rs2_addr),
        .rs1_data      (rs1_data),
        .rs2_data      (rs2_data),
        .id_ex_out     (id_ex_reg)
    );

    // Execution Stage
    ex_stage u_ex_stage (
        .clk             (clk),
        .rst_n           (rst_n),
        .stall_ex        (stall_ex),
        .flush_ex        (flush_ex),
        .id_ex_in        (id_ex_reg),
        .forward_a       (forward_a),
        .forward_b       (forward_b),
        .forward_ex_mem  (forward_ex_mem_data),
        .forward_mem_wb  (forward_mem_wb_data),
        .branch_taken    (branch_taken),
        .branch_target   (branch_target),
        .ex_mem_out      (ex_mem_reg)
    );

    // Memory Stage
    mem_stage u_mem_stage (
        .clk        (clk),
        .rst_n      (rst_n),
        .stall_mem  (stall_mem),
        .flush_mem  (flush_mem),
        .ex_mem_in  (ex_mem_reg),
        .dmem_en    (dmem_en),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_wmask (dmem_wmask),
        .dmem_we    (dmem_we),
        .mem_wb_out (mem_wb_reg)
    );

    // Writeback Stage
    wb_stage u_wb_stage (
        .mem_wb_in   (mem_wb_reg),
        .dmem_rdata  (dmem_rdata),
        .rd_addr     (rd_addr),
        .rd_data     (rd_data),
        .rd_write_en (rd_write_en)
    );

endmodule
