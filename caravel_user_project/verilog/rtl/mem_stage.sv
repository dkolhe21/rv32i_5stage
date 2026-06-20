//-----------------------------------------------------------------------------
// Module: mem_stage
// File:   mem_stage.sv
//
// Description:
//   Memory Access stage for 5-stage RV32I pipeline.
//   Drives DMEM interface and registers the MEM/WB pipeline struct.
//   Handles store data byte alignment and masks.
//
// Author: Assistant
// Date:   2026-06-09
//-----------------------------------------------------------------------------

 

module mem_stage (
    input  logic        clk,
    input  logic        rst_n,

    // Pipeline control
    input  logic        stall_mem,
    input  logic        flush_mem, // Typically unused in simple 5-stage, but good for completeness

    // EX/MEM pipeline register input
    input  riscv_pkg::ex_mem_t     ex_mem_in,

    // DMEM interface
    output logic        dmem_en,
    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_wdata,
    output logic [3:0]  dmem_wmask,
    output logic        dmem_we,

    // Output to WB stage
    output riscv_pkg::mem_wb_t     mem_wb_out
);

    import riscv_pkg::*;

    //--------------------------------------------------------------------------
    // DMEM Control
    //--------------------------------------------------------------------------
    assign dmem_en   = ex_mem_in.valid && (ex_mem_in.mem_read || ex_mem_in.mem_write) && !stall_mem;
    assign dmem_addr = ex_mem_in.alu_result;
    assign dmem_we   = ex_mem_in.mem_write;

    //--------------------------------------------------------------------------
    // Store Data Alignment
    //--------------------------------------------------------------------------
    logic [1:0] byte_offset;
    assign byte_offset = ex_mem_in.alu_result[1:0];

    logic [31:0] store_data;
    logic [3:0]  store_mask;

    always_comb begin
        store_data = 32'b0;
        store_mask = 4'b0000;

        if (ex_mem_in.valid && ex_mem_in.mem_write) begin
            case (ex_mem_in.mem_size)
                3'b000: begin  // SB
                    case (byte_offset)
                        2'b00: begin store_data = {24'b0, ex_mem_in.rs2_data[7:0]};       store_mask = 4'b0001; end
                        2'b01: begin store_data = {16'b0, ex_mem_in.rs2_data[7:0], 8'b0}; store_mask = 4'b0010; end
                        2'b10: begin store_data = {8'b0, ex_mem_in.rs2_data[7:0], 16'b0}; store_mask = 4'b0100; end
                        2'b11: begin store_data = {ex_mem_in.rs2_data[7:0], 24'b0};       store_mask = 4'b1000; end
                    endcase
                end
                3'b001: begin  // SH
                    case (byte_offset[1])
                        1'b0: begin store_data = {16'b0, ex_mem_in.rs2_data[15:0]};        store_mask = 4'b0011; end
                        1'b1: begin store_data = {ex_mem_in.rs2_data[15:0], 16'b0};        store_mask = 4'b1100; end
                    endcase
                end
                3'b010: begin  // SW
                    store_data = ex_mem_in.rs2_data;
                    store_mask = 4'b1111;
                end
                default: begin
                    store_data = 32'b0;
                    store_mask = 4'b0000;
                end
            endcase
        end
    end

    assign dmem_wdata = store_data;
    assign dmem_wmask = store_mask;

    //--------------------------------------------------------------------------
    // MEM/WB Pipeline Register
    //--------------------------------------------------------------------------
    riscv_pkg::mem_wb_t mem_wb_next;

    always_comb begin
        mem_wb_next = '0;
        if (ex_mem_in.valid) begin
            mem_wb_next.valid      = 1'b1;
            mem_wb_next.alu_result = ex_mem_in.alu_result;
            mem_wb_next.mem_size   = ex_mem_in.mem_size;
            mem_wb_next.pc_plus_4  = ex_mem_in.pc_plus_4;
            mem_wb_next.imm        = ex_mem_in.imm;
            mem_wb_next.rd_addr    = ex_mem_in.rd_addr;
            mem_wb_next.reg_write  = ex_mem_in.reg_write;
            mem_wb_next.wb_sel     = ex_mem_in.wb_sel;
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            mem_wb_out <= '0;
        end else if (flush_mem) begin
            mem_wb_out <= '0;
        end else if (!stall_mem) begin
            mem_wb_out <= mem_wb_next;
        end
    end

endmodule
