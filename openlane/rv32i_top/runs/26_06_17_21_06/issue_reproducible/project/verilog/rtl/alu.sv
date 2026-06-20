//-----------------------------------------------------------------------------
// Module: alu
// File:   alu.sv
//
// Description:
//   RV32I Arithmetic Logic Unit. Pure combinational — no clock.
//
// Author: Assistant
// Date:   2026-06-09
//-----------------------------------------------------------------------------

import riscv_pkg::*;

module alu (
    input  logic [31:0] operand_a,
    input  logic [31:0] operand_b,
    input  alu_op_t     alu_op,
    output logic [31:0] result,
    output logic        zero_flag
);

    always_comb begin
        result = 32'b0;

        case (alu_op)
            ALU_ADD:    result = operand_a + operand_b;
            ALU_SUB:    result = operand_a - operand_b;
            ALU_AND:    result = operand_a & operand_b;
            ALU_OR:     result = operand_a | operand_b;
            ALU_XOR:    result = operand_a ^ operand_b;
            ALU_SLL:    result = operand_a << operand_b[4:0];
            ALU_SRL:    result = operand_a >> operand_b[4:0];
            ALU_SRA:    result = $signed(operand_a) >>> operand_b[4:0];
            ALU_SLT:    result = {31'b0, ($signed(operand_a) < $signed(operand_b))};
            ALU_SLTU:   result = {31'b0, (operand_a < operand_b)};
            ALU_PASS_B: result = operand_b;
            ALU_PASS_A: result = operand_a;
            default:    result = 32'b0;
        endcase
    end

    assign zero_flag = (result == 32'b0);

endmodule
