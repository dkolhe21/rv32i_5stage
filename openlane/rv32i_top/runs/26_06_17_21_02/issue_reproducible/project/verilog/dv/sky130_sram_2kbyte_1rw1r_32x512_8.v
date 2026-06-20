//-----------------------------------------------------------------------------
// Module: sky130_sram_2kbyte_1rw1r_32x512_8
// File:   sky130_sram_2kbyte_1rw1r_32x512_8.v
//
// Description:
//   Behavioral simulation model for the 2KB SRAM macro.
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

module sky130_sram_2kbyte_1rw1r_32x512_8 (
`ifdef USE_POWER_PINS
    inout vccd1,
    inout vssd1,
`endif
    // Port 0: Read/Write
    input  wire        clk0,
    input  wire        csb0,    // active low chip select
    input  wire        web0,    // active low write enable
    input  wire [3:0]  wmask0,  // byte write mask
    input  wire [8:0]  addr0,
    input  wire [31:0] din0,
    output reg  [31:0] dout0,
    
    // Port 1: Read only (unused in our design but required for port match)
    input  wire        clk1,
    input  wire        csb1,
    input  wire [8:0]  addr1,
    output reg  [31:0] dout1
);

    reg [31:0] mem [0:511];

    always @(posedge clk0) begin
        if (!csb0) begin
            if (!web0) begin
                if (wmask0[0]) mem[addr0][7:0]   <= din0[7:0];
                if (wmask0[1]) mem[addr0][15:8]  <= din0[15:8];
                if (wmask0[2]) mem[addr0][23:16] <= din0[23:16];
                if (wmask0[3]) mem[addr0][31:24] <= din0[31:24];
            end
            dout0 <= mem[addr0];
        end
    end

    always @(posedge clk1) begin
        if (!csb1) begin
            dout1 <= mem[addr1];
        end
    end

endmodule
