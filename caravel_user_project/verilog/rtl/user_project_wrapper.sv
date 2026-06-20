// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_project_wrapper
 *
 * This wrapper instantiates the 5-stage RISC-V core (rv32i_top) 
 * within the Caravel SoC environment.
 *
 *-------------------------------------------------------------
 */

module user_project_wrapper #(
    parameter BITS = 32
) (
`ifdef USE_POWER_PINS
    inout vdda1,  // User area 1 AVDD
    inout vdda2,  // User area 2 AVDD
    inout vssa1,  // User area 1 AVSS
    inout vssa2,  // User area 2 AVSS
    inout vccd1,  // User area 1 VCCD
    inout vccd2,  // User area 2 VCCD
    inout vssd1,  // User area 1 VSS
    inout vssd2,  // User area 2 VSS
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // Analog (direct connection to GPIO pad---use with caution)
    // Note that analog I/O is not available on the 7 lowest-numbered
    // GPIO pads, and so the analog_io indexing is offset from the
    // GPIO indexing by 7 (also upper 2 GPIOs do not have analog_io).
    inout [`MPRJ_IO_PADS-10:0] analog_io,

    // Independent clock (on independent integer divider)
    input   user_clock2,

    // User maskable interrupt signals
    output [2:0] user_irq
);

    //--------------------------------------------------------------------------
    // Tie-offs for unused Caravel signals
    //--------------------------------------------------------------------------
    assign io_out[`MPRJ_IO_PADS-1:8] = 0;
    assign io_oeb[`MPRJ_IO_PADS-1:8] = {(`MPRJ_IO_PADS-8){1'b1}}; // High-Z
    assign la_data_out = 128'b0;
    assign user_irq    = 3'b0;

    //--------------------------------------------------------------------------
    // Instantiation of 5-Stage RV32I Core Top
    //--------------------------------------------------------------------------
    // We map the first 8 GPIOs to specific debug/JTAG functions,
    // and route Wishbone directly into our core.
    
    rv32i_top u_rv32i_top (
`ifdef USE_POWER_PINS
        .vccd1(vccd1),
        .vssd1(vssd1),
        .vccd2(vccd2),
        .vssd2(vssd2),
        .vdda1(vdda1),
        .vssa1(vssa1),
        .vdda2(vdda2),
        .vssa2(vssa2),
`endif
        .clk      (wb_clk_i),
        .rst_n    (~wb_rst_i),

        // Wishbone Interface
        .wb_clk_i (wb_clk_i),
        .wb_rst_i (wb_rst_i),
        .wbs_stb_i(wbs_stb_i),
        .wbs_cyc_i(wbs_cyc_i),
        .wbs_we_i (wbs_we_i),
        .wbs_sel_i(wbs_sel_i),
        .wbs_dat_i(wbs_dat_i),
        .wbs_adr_i(wbs_adr_i),
        .wbs_ack_o(wbs_ack_o),
        .wbs_dat_o(wbs_dat_o),

        // JTAG Interface (mapped to io_in[4:0] and io_out[3])
        .jtag_tck   (io_in[0]),
        .jtag_tms   (io_in[1]),
        .jtag_tdi   (io_in[2]),
        .jtag_tdo   (io_out[3]),
        .jtag_trst_n(io_in[4]),

        // BIST Interface
        .bist_mode_ext(io_in[5]),
        .bist_done_ext(io_out[6]),
        .bist_pass_ext(io_out[7])
    );

    // Set OEB for the output pins
    assign io_oeb[3] = 1'b0; // TDO is output
    assign io_oeb[6] = 1'b0; // BIST Done is output
    assign io_oeb[7] = 1'b0; // BIST Pass is output

    // Set OEB for the input pins
    assign io_oeb[0] = 1'b1;
    assign io_oeb[1] = 1'b1;
    assign io_oeb[2] = 1'b1;
    assign io_oeb[4] = 1'b1;
    assign io_oeb[5] = 1'b1;

endmodule

`default_nettype wire
