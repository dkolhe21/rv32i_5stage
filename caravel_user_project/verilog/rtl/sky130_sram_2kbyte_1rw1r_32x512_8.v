/// sta-blackbox
// Blackbox stub for OpenLane synthesis — no timing constructs
// The full behavioral model from the PDK is used for simulation only

module sky130_sram_2kbyte_1rw1r_32x512_8(
`ifdef USE_POWER_PINS
    vccd1,
    vssd1,
`endif
    clk0, csb0, web0, wmask0, addr0, din0, dout0,
    clk1, csb1, addr1, dout1
);

  parameter NUM_WMASKS = 4 ;
  parameter DATA_WIDTH = 32 ;
  parameter ADDR_WIDTH = 9 ;
  parameter RAM_DEPTH = 1 << ADDR_WIDTH;

`ifdef USE_POWER_PINS
    inout vccd1;
    inout vssd1;
`endif
  input  clk0;
  input  csb0;
  input  web0;
  input [NUM_WMASKS-1:0] wmask0;
  input [ADDR_WIDTH-1:0] addr0;
  input [DATA_WIDTH-1:0] din0;
  output [DATA_WIDTH-1:0] dout0;

  input  clk1;
  input  csb1;
  input [ADDR_WIDTH-1:0] addr1;
  output [DATA_WIDTH-1:0] dout1;

endmodule
