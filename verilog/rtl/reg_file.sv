//-----------------------------------------------------------------------------
// Module: reg_file
// File:   reg_file.sv
//
// Description:
//   32x32-bit register file for RV32I.
//   - Two combinational read ports (rs1, rs2)
//   - One synchronous write port (rd)
//   - x0 hardwired to zero
//   - Debug port for JTAG register access (takes priority over pipeline write)
//
// Author: Assistant
// Date:   2026-06-09
//-----------------------------------------------------------------------------

module reg_file (
    input  logic        clk,
    input  logic        rst_n,

    // Read port 1
    input  logic [4:0]  rs1_addr,
    output logic [31:0] rs1_data,

    // Read port 2
    input  logic [4:0]  rs2_addr,
    output logic [31:0] rs2_data,

    // Write port (from MEM/WB pipeline register)
    input  logic [4:0]  rd_addr,
    input  logic [31:0] rd_data,
    input  logic        rd_write_en,

    // Debug port (from JTAG debug module)
    input  logic [4:0]  dbg_addr,
    input  logic [31:0] dbg_wdata,
    input  logic        dbg_we,
    output logic [31:0] dbg_rdata
);

    //--------------------------------------------------------------------------
    // Register storage (x0 through x31)
    //--------------------------------------------------------------------------
    logic [31:0] regs [1:31];  // x1 to x31 (x0 is implicit zero)

    //--------------------------------------------------------------------------
    // Read ports (combinational) — x0 always returns 0
    //--------------------------------------------------------------------------
    assign rs1_data  = (rs1_addr == 5'b0) ? 32'b0 : regs[rs1_addr];
    assign rs2_data  = (rs2_addr == 5'b0) ? 32'b0 : regs[rs2_addr];
    assign dbg_rdata = (dbg_addr == 5'b0) ? 32'b0 : regs[dbg_addr];

    //--------------------------------------------------------------------------
    // Write port (synchronous, posedge clk)
    // Debug write takes priority over pipeline write
    //--------------------------------------------------------------------------
    integer i;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (i = 1; i < 32; i = i + 1) begin
                regs[i] <= 32'b0;
            end
        end else begin
            // Debug write has priority
            if (dbg_we && (dbg_addr != 5'b0)) begin
                regs[dbg_addr] <= dbg_wdata;
            end else if (rd_write_en && (rd_addr != 5'b0)) begin
                regs[rd_addr] <= rd_data;
            end
        end
    end

endmodule
