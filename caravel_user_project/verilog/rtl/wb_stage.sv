//-----------------------------------------------------------------------------
// Module: wb_stage
// File:   wb_stage.sv
//
// Description:
//   Writeback stage for 5-stage RV32I pipeline.
//   Aligns and sign-extends data loaded from DMEM.
//   Selects final writeback value and drives register file write port.
//
// Author: Assistant
// Date:   2026-06-09
//-----------------------------------------------------------------------------

 

module wb_stage (
    // MEM/WB pipeline register input
    input  riscv_pkg::mem_wb_t     mem_wb_in,
    
    // DMEM read data (available combinationally relative to this stage)
    input  logic [31:0] dmem_rdata,

    // Outputs to Register File
    output logic [4:0]  rd_addr,
    output logic [31:0] rd_data,
    output logic        rd_write_en
);

    import riscv_pkg::*;

    //--------------------------------------------------------------------------
    // Load Data Alignment and Sign Extension
    //--------------------------------------------------------------------------
    logic [1:0]  byte_offset;
    logic [31:0] load_data;

    assign byte_offset = mem_wb_in.alu_result[1:0];

    always_comb begin
        load_data = dmem_rdata;

        case (mem_wb_in.mem_size)
            3'b000: begin  // LB (signed byte)
                case (byte_offset)
                    2'b00: load_data = {{24{dmem_rdata[7]}},  dmem_rdata[7:0]};
                    2'b01: load_data = {{24{dmem_rdata[15]}}, dmem_rdata[15:8]};
                    2'b10: load_data = {{24{dmem_rdata[23]}}, dmem_rdata[23:16]};
                    2'b11: load_data = {{24{dmem_rdata[31]}}, dmem_rdata[31:24]};
                endcase
            end
            3'b001: begin  // LH (signed halfword)
                case (byte_offset[1])
                    1'b0: load_data = {{16{dmem_rdata[15]}}, dmem_rdata[15:0]};
                    1'b1: load_data = {{16{dmem_rdata[31]}}, dmem_rdata[31:16]};
                endcase
            end
            3'b010: begin  // LW (full word)
                load_data = dmem_rdata;
            end
            3'b100: begin  // LBU (unsigned byte)
                case (byte_offset)
                    2'b00: load_data = {24'b0, dmem_rdata[7:0]};
                    2'b01: load_data = {24'b0, dmem_rdata[15:8]};
                    2'b10: load_data = {24'b0, dmem_rdata[23:16]};
                    2'b11: load_data = {24'b0, dmem_rdata[31:24]};
                endcase
            end
            3'b101: begin  // LHU (unsigned halfword)
                case (byte_offset[1])
                    1'b0: load_data = {16'b0, dmem_rdata[15:0]};
                    1'b1: load_data = {16'b0, dmem_rdata[31:16]};
                endcase
            end
            default: begin
                load_data = dmem_rdata;
            end
        endcase
    end

    //--------------------------------------------------------------------------
    // Writeback Selection Mux
    //--------------------------------------------------------------------------
    logic [31:0] wb_data;

    always_comb begin
        case (mem_wb_in.wb_sel)
            WB_ALU:  wb_data = mem_wb_in.alu_result;
            WB_MEM:  wb_data = load_data;
            WB_PC4:  wb_data = mem_wb_in.pc_plus_4;
            WB_LUI:  wb_data = mem_wb_in.imm;
            default: wb_data = mem_wb_in.alu_result;
        endcase
    end

    //--------------------------------------------------------------------------
    // Output Assignments
    //--------------------------------------------------------------------------
    assign rd_addr     = mem_wb_in.rd_addr;
    assign rd_data     = wb_data;
    assign rd_write_en = mem_wb_in.valid && mem_wb_in.reg_write && (mem_wb_in.rd_addr != 5'b0);

endmodule
