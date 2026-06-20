//-----------------------------------------------------------------------------
// Module: if_stage
// File:   if_stage.sv
//
// Description:
//   Instruction Fetch stage for 5-stage RV32I pipeline.
//   Maintains the PC, drives the IMEM interface, and registers the 
//   IF/ID pipeline struct.
//
// Author: Assistant
// Date:   2026-06-09
//-----------------------------------------------------------------------------

 

module if_stage (
    input  logic        clk,
    input  logic        rst_n,

    // Pipeline control
    input  logic        stall_if,       // Hold PC and IF/ID
    input  logic        flush_if,       // Clear IF/ID

    // Branch/Jump redirect
    input  logic        branch_taken,   // Branch/jump taken (from EX)
    input  logic [31:0] branch_target,  // Target address (from EX)

    // IMEM interface
    output logic        imem_en,
    output logic [31:0] imem_addr,
    input  logic [31:0] imem_rdata,

    // Output to ID stage
    output riscv_pkg::if_id_t      if_id_out
);

    logic [31:0] pc_q;
    logic [31:0] pc_q_prev;
    logic [31:0] pc_d;

    //--------------------------------------------------------------------------
    // PC Generation
    //--------------------------------------------------------------------------
    assign pc_d = (branch_taken) ? branch_target :
                  (stall_if)     ? pc_q :
                                   pc_q + 32'd4;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            pc_q      <= 32'b0;
            pc_q_prev <= 32'b0;
        end else begin
            if (!stall_if) begin
                pc_q <= pc_d;
                if (branch_taken)
                    pc_q_prev <= branch_target;
                else
                    pc_q_prev <= pc_q;
            end
        end
    end

    //--------------------------------------------------------------------------
    // IMEM Interface
    //--------------------------------------------------------------------------
    assign imem_en   = ~stall_if;
    assign imem_addr = pc_q;

    //--------------------------------------------------------------------------
    // IF/ID Pipeline Register
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            if_id_out <= '0;
        end else if (flush_if) begin
            if_id_out <= '0;
        end else if (!stall_if) begin
            if_id_out.valid     <= 1'b1;
            if_id_out.pc        <= pc_q_prev;
            if_id_out.pc_plus_4 <= pc_q_prev + 32'd4;
            if_id_out.inst      <= imem_rdata;
        end
        // On stall_if, if_id_out retains its previous state automatically
    end

endmodule
