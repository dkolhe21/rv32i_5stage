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

module alu (
    input  logic [31:0] operand_a,
    input  logic [31:0] operand_b,
    input  riscv_pkg::alu_op_t alu_op,
    output logic [31:0] result,
    output logic        zero_flag
);

    always_comb begin
        result = 32'b0;

        case (alu_op)
            riscv_pkg::ALU_ADD:    result = operand_a + operand_b;
            riscv_pkg::ALU_SUB:    result = operand_a - operand_b;
            riscv_pkg::ALU_AND:    result = operand_a & operand_b;
            riscv_pkg::ALU_OR:     result = operand_a | operand_b;
            riscv_pkg::ALU_XOR:    result = operand_a ^ operand_b;
            riscv_pkg::ALU_SLL:    result = operand_a << operand_b[4:0];
            riscv_pkg::ALU_SRL:    result = operand_a >> operand_b[4:0];
            riscv_pkg::ALU_SRA:    result = $signed(operand_a) >>> operand_b[4:0];
            riscv_pkg::ALU_SLT:    result = {31'b0, ($signed(operand_a) < $signed(operand_b))};
            riscv_pkg::ALU_SLTU:   result = {31'b0, (operand_a < operand_b)};
            riscv_pkg::ALU_PASS_B: result = operand_b;
            riscv_pkg::ALU_PASS_A: result = operand_a;
            default:    result = 32'b0;
        endcase
    end

    assign zero_flag = (result == 32'b0);

endmodule
