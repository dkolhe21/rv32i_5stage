//-----------------------------------------------------------------------------
// Module: id_stage
// File:   id_stage.sv
//
// Description:
//   Instruction Decode stage for 5-stage RV32I pipeline.
//   Decodes the instruction, reads the register file, generates immediates,
//   and registers the ID/EX pipeline struct.
//
// Author: Assistant
// Date:   2026-06-09
//-----------------------------------------------------------------------------

import riscv_pkg::*;

module id_stage (
    input  logic        clk,
    input  logic        rst_n,

    // Pipeline control
    input  logic        stall_id,
    input  logic        flush_id,

    // IF/ID pipeline register input
    input  if_id_t      if_id_in,

    // Register File interface
    output logic [4:0]  rs1_addr,
    output logic [4:0]  rs2_addr,
    input  logic [31:0] rs1_data,
    input  logic [31:0] rs2_data,

    // Output to EX stage
    output id_ex_t      id_ex_out
);

    //--------------------------------------------------------------------------
    // Combinational Decode Logic
    //--------------------------------------------------------------------------
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [4:0] rd;
    
    assign opcode = if_id_in.inst[6:0];
    assign funct3 = if_id_in.inst[14:12];
    assign funct7 = if_id_in.inst[31:25];
    assign rd     = if_id_in.inst[11:7];
    assign rs1_addr = if_id_in.inst[19:15];
    assign rs2_addr = if_id_in.inst[24:20];

    // Immediate generation
    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
    assign imm_i = {{20{if_id_in.inst[31]}}, if_id_in.inst[31:20]};
    assign imm_s = {{20{if_id_in.inst[31]}}, if_id_in.inst[31:25], if_id_in.inst[11:7]};
    assign imm_b = {{20{if_id_in.inst[31]}}, if_id_in.inst[7], if_id_in.inst[30:25], if_id_in.inst[11:8], 1'b0};
    assign imm_u = {if_id_in.inst[31:12], 12'b0};
    assign imm_j = {{12{if_id_in.inst[31]}}, if_id_in.inst[19:12], if_id_in.inst[20], if_id_in.inst[30:21], 1'b0};

    logic [31:0] imm;
    id_ex_t id_ex_next;

    always_comb begin
        // Default assignments
        id_ex_next = '0;
        id_ex_next.pc = if_id_in.pc;
        id_ex_next.pc_plus_4 = if_id_in.pc_plus_4;
        id_ex_next.rs1_data = rs1_data;
        id_ex_next.rs2_data = rs2_data;
        id_ex_next.rs1_addr = rs1_addr;
        id_ex_next.rs2_addr = rs2_addr;
        id_ex_next.rd_addr  = rd;
        
        imm = 32'b0;
        
        if (if_id_in.valid) begin
            id_ex_next.valid = 1'b1;
            
            case (opcode)
                OPC_LUI: begin
                    imm = imm_u;
                    id_ex_next.reg_write = 1'b1;
                    id_ex_next.wb_sel    = WB_LUI;
                end
                
                OPC_AUIPC: begin
                    imm = imm_u;
                    id_ex_next.alu_op    = ALU_ADD;
                    id_ex_next.alu_src_a = 1'b1; // pc
                    id_ex_next.alu_src_b = 1'b1; // imm
                    id_ex_next.reg_write = 1'b1;
                    id_ex_next.wb_sel    = WB_ALU;
                end
                
                OPC_JAL: begin
                    imm = imm_j;
                    id_ex_next.jump      = 1'b1;
                    id_ex_next.reg_write = 1'b1;
                    id_ex_next.wb_sel    = WB_PC4;
                end
                
                OPC_JALR: begin
                    imm = imm_i;
                    id_ex_next.jump      = 1'b1;
                    id_ex_next.jump_reg  = 1'b1;
                    id_ex_next.reg_write = 1'b1;
                    id_ex_next.wb_sel    = WB_PC4;
                end
                
                OPC_BRANCH: begin
                    imm = imm_b;
                    case (funct3)
                        F3_BEQ:  id_ex_next.branch_op = BR_BEQ;
                        F3_BNE:  id_ex_next.branch_op = BR_BNE;
                        F3_BLT:  id_ex_next.branch_op = BR_BLT;
                        F3_BGE:  id_ex_next.branch_op = BR_BGE;
                        F3_BLTU: id_ex_next.branch_op = BR_BLTU;
                        F3_BGEU: id_ex_next.branch_op = BR_BGEU;
                        default: id_ex_next.branch_op = BR_NONE;
                    endcase
                end
                
                OPC_LOAD: begin
                    imm = imm_i;
                    id_ex_next.alu_op    = ALU_ADD;
                    id_ex_next.alu_src_b = 1'b1; // imm
                    id_ex_next.mem_read  = 1'b1;
                    id_ex_next.mem_size  = funct3;
                    id_ex_next.reg_write = 1'b1;
                    id_ex_next.wb_sel    = WB_MEM;
                end
                
                OPC_STORE: begin
                    imm = imm_s;
                    id_ex_next.alu_op    = ALU_ADD;
                    id_ex_next.alu_src_b = 1'b1; // imm
                    id_ex_next.mem_write = 1'b1;
                    id_ex_next.mem_size  = funct3;
                end
                
                OPC_OP_IMM: begin
                    imm = imm_i;
                    id_ex_next.alu_src_b = 1'b1; // imm
                    id_ex_next.reg_write = 1'b1;
                    id_ex_next.wb_sel    = WB_ALU;
                    
                    case (funct3)
                        F3_ADD_SUB: id_ex_next.alu_op = ALU_ADD;
                        F3_SLT:     id_ex_next.alu_op = ALU_SLT;
                        F3_SLTU:    id_ex_next.alu_op = ALU_SLTU;
                        F3_XOR:     id_ex_next.alu_op = ALU_XOR;
                        F3_OR:      id_ex_next.alu_op = ALU_OR;
                        F3_AND:     id_ex_next.alu_op = ALU_AND;
                        F3_SLL:     id_ex_next.alu_op = ALU_SLL;
                        F3_SRL_SRA: begin
                            if (funct7 == F7_ALT) id_ex_next.alu_op = ALU_SRA;
                            else                  id_ex_next.alu_op = ALU_SRL;
                        end
                        default:    id_ex_next.alu_op = ALU_ADD;
                    endcase
                end
                
                OPC_OP: begin
                    id_ex_next.reg_write = 1'b1;
                    id_ex_next.wb_sel    = WB_ALU;
                    
                    case (funct3)
                        F3_ADD_SUB: begin
                            if (funct7 == F7_ALT) id_ex_next.alu_op = ALU_SUB;
                            else                  id_ex_next.alu_op = ALU_ADD;
                        end
                        F3_SLL:     id_ex_next.alu_op = ALU_SLL;
                        F3_SLT:     id_ex_next.alu_op = ALU_SLT;
                        F3_SLTU:    id_ex_next.alu_op = ALU_SLTU;
                        F3_XOR:     id_ex_next.alu_op = ALU_XOR;
                        F3_SRL_SRA: begin
                            if (funct7 == F7_ALT) id_ex_next.alu_op = ALU_SRA;
                            else                  id_ex_next.alu_op = ALU_SRL;
                        end
                        F3_OR:      id_ex_next.alu_op = ALU_OR;
                        F3_AND:     id_ex_next.alu_op = ALU_AND;
                        default:    id_ex_next.alu_op = ALU_ADD;
                    endcase
                end
                
                default: begin
                    // Invalid/unknown opcode behaves like a bubble
                    id_ex_next = '0; 
                end
            endcase
            
            id_ex_next.imm = imm;
        end
    end

    //--------------------------------------------------------------------------
    // ID/EX Pipeline Register
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            id_ex_out <= '0;
        end else if (flush_id) begin
            id_ex_out <= '0;
        end else if (!stall_id) begin
            id_ex_out <= id_ex_next;
        end
    end

endmodule
