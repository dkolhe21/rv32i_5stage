//-----------------------------------------------------------------------------
// Package: riscv_pkg
// File:    riscv_pkg.sv
//
// Description:
//   RV32I ISA constants: opcodes, funct3, funct7, ALU operation codes.
//   SystemVerilog package with packed structs for 5-stage pipeline registers.
//   Import via `import riscv_pkg::*;`
//
// Author: Assistant
// Date:   2026-06-09
//-----------------------------------------------------------------------------

package riscv_pkg;

    //=========================================================================
    // RV32I Opcodes (bits [6:0] of instruction)
    //=========================================================================
    parameter logic [6:0] OPC_LUI    = 7'b0110111;
    parameter logic [6:0] OPC_AUIPC  = 7'b0010111;
    parameter logic [6:0] OPC_JAL    = 7'b1101111;
    parameter logic [6:0] OPC_JALR   = 7'b1100111;
    parameter logic [6:0] OPC_BRANCH = 7'b1100011;
    parameter logic [6:0] OPC_LOAD   = 7'b0000011;
    parameter logic [6:0] OPC_STORE  = 7'b0100011;
    parameter logic [6:0] OPC_OP_IMM = 7'b0010011;
    parameter logic [6:0] OPC_OP     = 7'b0110011;

    //=========================================================================
    // funct3 Encodings
    //=========================================================================

    // ALU R-type and I-type (funct3)
    parameter logic [2:0] F3_ADD_SUB = 3'b000;
    parameter logic [2:0] F3_SLL     = 3'b001;
    parameter logic [2:0] F3_SLT     = 3'b010;
    parameter logic [2:0] F3_SLTU    = 3'b011;
    parameter logic [2:0] F3_XOR     = 3'b100;
    parameter logic [2:0] F3_SRL_SRA = 3'b101;
    parameter logic [2:0] F3_OR      = 3'b110;
    parameter logic [2:0] F3_AND     = 3'b111;

    // Branch (funct3)
    parameter logic [2:0] F3_BEQ  = 3'b000;
    parameter logic [2:0] F3_BNE  = 3'b001;
    parameter logic [2:0] F3_BLT  = 3'b100;
    parameter logic [2:0] F3_BGE  = 3'b101;
    parameter logic [2:0] F3_BLTU = 3'b110;
    parameter logic [2:0] F3_BGEU = 3'b111;

    // Load/Store (funct3)
    parameter logic [2:0] F3_LB_SB = 3'b000;
    parameter logic [2:0] F3_LH_SH = 3'b001;
    parameter logic [2:0] F3_LW_SW = 3'b010;
    parameter logic [2:0] F3_LBU   = 3'b100;
    parameter logic [2:0] F3_LHU   = 3'b101;

    //=========================================================================
    // funct7 Encodings
    //=========================================================================
    parameter logic [6:0] F7_NORMAL = 7'b0000000;
    parameter logic [6:0] F7_ALT    = 7'b0100000;

    //=========================================================================
    // ALU Operation Codes (internal, 4-bit)
    //=========================================================================
    typedef enum logic [3:0] {
        ALU_ADD    = 4'd0,
        ALU_SUB    = 4'd1,
        ALU_AND    = 4'd2,
        ALU_OR     = 4'd3,
        ALU_XOR    = 4'd4,
        ALU_SLL    = 4'd5,
        ALU_SRL    = 4'd6,
        ALU_SRA    = 4'd7,
        ALU_SLT    = 4'd8,
        ALU_SLTU   = 4'd9,
        ALU_PASS_B = 4'd10,
        ALU_PASS_A = 4'd11
    } alu_op_t;

    // Writeback Source Selection
    typedef enum logic [1:0] {
        WB_ALU  = 2'd0,
        WB_MEM  = 2'd1,
        WB_PC4  = 2'd2,
        WB_LUI  = 2'd3
    } wb_sel_t;

    // Branch Types
    typedef enum logic [2:0] {
        BR_NONE = 3'd0,
        BR_BEQ  = 3'd1,
        BR_BNE  = 3'd2,
        BR_BLT  = 3'd3,
        BR_BGE  = 3'd4,
        BR_BLTU = 3'd5,
        BR_BGEU = 3'd6
    } branch_op_t;

    //=========================================================================
    // 5-Stage Pipeline Registers (Packed Structs)
    //=========================================================================

    // IF/ID Pipeline Register
    typedef struct packed {
        logic        valid;
        logic [31:0] pc;
        logic [31:0] pc_plus_4;
        logic [31:0] inst;
    } if_id_t;

    // ID/EX Pipeline Register
    typedef struct packed {
        logic        valid;
        logic [31:0] pc;
        logic [31:0] pc_plus_4;
        logic [31:0] rs1_data;
        logic [31:0] rs2_data;
        logic [31:0] imm;
        logic [4:0]  rs1_addr;
        logic [4:0]  rs2_addr;
        logic [4:0]  rd_addr;
        
        // Control signals
        alu_op_t     alu_op;
        logic        alu_src_a; // 0: rs1, 1: pc
        logic        alu_src_b; // 0: rs2, 1: imm
        branch_op_t  branch_op; // BR_NONE if not a branch
        logic        jump;      // JAL or JALR
        logic        jump_reg;  // JALR specifically (for target calculation)
        
        // MEM control
        logic        mem_read;
        logic        mem_write;
        logic [2:0]  mem_size;  // funct3 for load/store
        
        // WB control
        logic        reg_write;
        wb_sel_t     wb_sel;
    } id_ex_t;

    // EX/MEM Pipeline Register
    typedef struct packed {
        logic        valid;
        logic [31:0] alu_result;
        logic [31:0] rs2_data;  // For store
        logic [31:0] pc_plus_4; // For JAL/JALR writeback
        logic [31:0] imm;       // For LUI writeback
        logic [4:0]  rd_addr;
        
        // MEM control
        logic        mem_read;
        logic        mem_write;
        logic [2:0]  mem_size;
        
        // WB control
        logic        reg_write;
        wb_sel_t     wb_sel;
    } ex_mem_t;

    // MEM/WB Pipeline Register
    typedef struct packed {
        logic        valid;
        logic [31:0] alu_result;
        logic [2:0]  mem_size;
        logic [31:0] pc_plus_4;
        logic [31:0] imm;
        logic [4:0]  rd_addr;
        
        // WB control
        logic        reg_write;
        wb_sel_t     wb_sel;
    } mem_wb_t;

endpackage
