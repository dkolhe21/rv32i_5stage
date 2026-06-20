//-----------------------------------------------------------------------------
// Module: ex_stage
// File:   ex_stage.sv
//
// Description:
//   Execution stage for 5-stage RV32I pipeline.
//   Handles ALU operations, branch resolution, data forwarding, 
//   and registers the EX/MEM pipeline struct.
//
// Author: Assistant
// Date:   2026-06-09
//-----------------------------------------------------------------------------

 

module ex_stage (
    input  logic        clk,
    input  logic        rst_n,

    // Pipeline control
    input  logic        stall_ex,
    input  logic        flush_ex,

    // ID/EX pipeline register input
    input  riscv_pkg::id_ex_t      id_ex_in,

    // Forwarding logic
    input  logic [1:0]  forward_a,        // 00: ID/EX, 01: EX/MEM, 10: MEM/WB
    input  logic [1:0]  forward_b,
    input  logic [31:0] forward_ex_mem,
    input  logic [31:0] forward_mem_wb,

    // Branch/Jump resolution to IF/ID and Hazard Unit
    output logic        branch_taken,
    output logic [31:0] branch_target,

    // Output to MEM stage
    output riscv_pkg::ex_mem_t     ex_mem_out
);

    import riscv_pkg::*;

    //--------------------------------------------------------------------------
    // Data Forwarding Multiplexers
    //--------------------------------------------------------------------------
    logic [31:0] op_a_fwd;
    logic [31:0] op_b_fwd;

    always_comb begin
        case (forward_a)
            2'b01:   op_a_fwd = forward_ex_mem;
            2'b10:   op_a_fwd = forward_mem_wb;
            default: op_a_fwd = id_ex_in.rs1_data;
        endcase

        case (forward_b)
            2'b01:   op_b_fwd = forward_ex_mem;
            2'b10:   op_b_fwd = forward_mem_wb;
            default: op_b_fwd = id_ex_in.rs2_data;
        endcase
    end

    //--------------------------------------------------------------------------
    // ALU Input Multiplexers
    //--------------------------------------------------------------------------
    logic [31:0] alu_in_a;
    logic [31:0] alu_in_b;

    assign alu_in_a = (id_ex_in.alu_src_a) ? id_ex_in.pc  : op_a_fwd;
    assign alu_in_b = (id_ex_in.alu_src_b) ? id_ex_in.imm : op_b_fwd;

    //--------------------------------------------------------------------------
    // ALU Instantiation
    //--------------------------------------------------------------------------
    logic [31:0] alu_result;
    logic        zero_flag;

    alu alu_inst (
        .operand_a (alu_in_a),
        .operand_b (alu_in_b),
        .alu_op    (id_ex_in.alu_op),
        .result    (alu_result),
        .zero_flag (zero_flag)
    );

    //--------------------------------------------------------------------------
    // Branch Resolution
    //--------------------------------------------------------------------------
    logic branch_cond_met;

    always_comb begin
        case (id_ex_in.branch_op)
            BR_BEQ:  branch_cond_met = (op_a_fwd == op_b_fwd);
            BR_BNE:  branch_cond_met = (op_a_fwd != op_b_fwd);
            BR_BLT:  branch_cond_met = ($signed(op_a_fwd) < $signed(op_b_fwd));
            BR_BGE:  branch_cond_met = ($signed(op_a_fwd) >= $signed(op_b_fwd));
            BR_BLTU: branch_cond_met = (op_a_fwd < op_b_fwd);
            BR_BGEU: branch_cond_met = (op_a_fwd >= op_b_fwd);
            default: branch_cond_met = 1'b0;
        endcase
    end

    assign branch_taken = id_ex_in.valid && (id_ex_in.jump || (id_ex_in.branch_op != BR_NONE && branch_cond_met));
    
    // Target calculation:
    // JALR uses forwarded register rs1. Others (JAL, Branches) use PC.
    logic [31:0] target_base;
    assign target_base = (id_ex_in.jump_reg) ? op_a_fwd : id_ex_in.pc;
    assign branch_target = {target_base + id_ex_in.imm} & 32'hFFFFFFFE; // LSB forced to 0

    //--------------------------------------------------------------------------
    // EX/MEM Pipeline Register
    //--------------------------------------------------------------------------
    ex_mem_t ex_mem_next;

    always_comb begin
        ex_mem_next = '0;
        if (id_ex_in.valid) begin
            ex_mem_next.valid      = 1'b1;
            ex_mem_next.alu_result = alu_result;
            ex_mem_next.rs2_data   = op_b_fwd;     // Store data needs to be forwarded!
            ex_mem_next.pc_plus_4  = id_ex_in.pc_plus_4;
            ex_mem_next.imm        = id_ex_in.imm;
            ex_mem_next.rd_addr    = id_ex_in.rd_addr;
            
            ex_mem_next.mem_read   = id_ex_in.mem_read;
            ex_mem_next.mem_write  = id_ex_in.mem_write;
            ex_mem_next.mem_size   = id_ex_in.mem_size;
            
            ex_mem_next.reg_write  = id_ex_in.reg_write;
            ex_mem_next.wb_sel     = id_ex_in.wb_sel;
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ex_mem_out <= '0;
        end else if (flush_ex) begin
            ex_mem_out <= '0;
        end else if (!stall_ex) begin
            ex_mem_out <= ex_mem_next;
        end
    end

endmodule
