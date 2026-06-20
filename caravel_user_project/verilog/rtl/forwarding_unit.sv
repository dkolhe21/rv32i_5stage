//-----------------------------------------------------------------------------
// Module: forwarding_unit
// File:   forwarding_unit.sv
//
// Description:
//   Data Hazard Forwarding Unit for 5-stage RV32I pipeline.
//   Bypasses RAW hazards by forwarding data from EX/MEM and MEM/WB 
//   stages directly into the EX stage ALU inputs.
//
// Author: Assistant
// Date:   2026-06-09
//-----------------------------------------------------------------------------

module forwarding_unit (
    input  logic [4:0] id_ex_rs1_addr,
    input  logic [4:0] id_ex_rs2_addr,

    input  logic       ex_mem_reg_write,
    input  logic [4:0] ex_mem_rd_addr,

    input  logic       mem_wb_reg_write,
    input  logic [4:0] mem_wb_rd_addr,

    output logic [1:0] forward_a,
    output logic [1:0] forward_b
);

    // Forwarding to ALU input A (rs1)
    always_comb begin
        if (ex_mem_reg_write && (ex_mem_rd_addr != 5'b0) && (ex_mem_rd_addr == id_ex_rs1_addr)) begin
            forward_a = 2'b01; // Forward from EX/MEM
        end else if (mem_wb_reg_write && (mem_wb_rd_addr != 5'b0) && (mem_wb_rd_addr == id_ex_rs1_addr)) begin
            forward_a = 2'b10; // Forward from MEM/WB
        end else begin
            forward_a = 2'b00; // No forwarding
        end
    end

    // Forwarding to ALU input B (rs2)
    always_comb begin
        if (ex_mem_reg_write && (ex_mem_rd_addr != 5'b0) && (ex_mem_rd_addr == id_ex_rs2_addr)) begin
            forward_b = 2'b01; // Forward from EX/MEM
        end else if (mem_wb_reg_write && (mem_wb_rd_addr != 5'b0) && (mem_wb_rd_addr == id_ex_rs2_addr)) begin
            forward_b = 2'b10; // Forward from MEM/WB
        end else begin
            forward_b = 2'b00; // No forwarding
        end
    end

endmodule
