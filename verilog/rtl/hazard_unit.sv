//-----------------------------------------------------------------------------
// Module: hazard_unit
// File:   hazard_unit.sv
//
// Description:
//   Hazard Detection Unit for 5-stage RV32I pipeline.
//   Handles Load-Use stalls and Branch/Jump flushes.
//
// Author: Assistant
// Date:   2026-06-09
//-----------------------------------------------------------------------------

module hazard_unit (
    // Load-Use hazard detection inputs
    input  logic       id_ex_mem_read,
    input  logic [4:0] id_ex_rd_addr,
    input  logic [4:0] if_id_rs1_addr,
    input  logic [4:0] if_id_rs2_addr,
    
    // Control hazard detection inputs
    input  logic       branch_taken,

    // Pipeline control outputs
    output logic       stall_if,
    output logic       stall_id,
    output logic       flush_if,
    output logic       flush_id,
    output logic       flush_ex
);

    logic load_use_hazard;

    always_comb begin
        // Detect Load-Use Hazard
        // If the instruction in ID/EX is a load, and its destination matches 
        // either rs1 or rs2 of the instruction currently in decode (IF/ID).
        if (id_ex_mem_read && (id_ex_rd_addr != 5'b0) && 
           ((id_ex_rd_addr == if_id_rs1_addr) || (id_ex_rd_addr == if_id_rs2_addr))) begin
            load_use_hazard = 1'b1;
        end else begin
            load_use_hazard = 1'b0;
        end
    end

    always_comb begin
        // Defaults
        stall_if = 1'b0;
        stall_id = 1'b0;
        flush_if = 1'b0;
        flush_id = 1'b0;
        flush_ex = 1'b0;

        if (branch_taken) begin
            // Branch taken in EX stage (2-cycle penalty)
            // Flush the instructions in IF and ID that were fetched sequentially
            flush_if = 1'b1;
            flush_id = 1'b1;
        end else if (load_use_hazard) begin
            // Stall IF and ID to let the load progress to MEM stage
            // Insert a bubble into EX stage
            stall_if = 1'b1;
            stall_id = 1'b1;
            flush_ex = 1'b1;
        end
    end

endmodule
