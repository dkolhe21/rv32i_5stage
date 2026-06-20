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
    inout [`MPRJ_IO_PADS-10:0] analog_io,

    // Independent clock (on independent integer divider)
    input   user_clock2,

    // User maskable interrupt signals
    output [2:0] user_irq
);

    //--------------------------------------------------------------------------
    // Tie-offs for unused Caravel signals
    //--------------------------------------------------------------------------
    // Tie-offs for unused Caravel signals are driven by rv32i_top.
    // user_irq driven by rv32i_top.irq below

    //--------------------------------------------------------------------------
    // Instantiation of 5-Stage RV32I Core Top
    //--------------------------------------------------------------------------
    rv32i_top mprj (
`ifdef USE_POWER_PINS
        // No power pins on RTL simulation model of rv32i_top
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

        // JTAG — tied to 0 using wb_rst_i or vssd1... wait, we need to tie to 0. 
        // In verilog, if we pass 1'b0, Yosys will insert a tie cell if SYNTH_ELABORATE_ONLY is 0.
        // Wait, Caravel IOs are already wired. We shouldn't use 1'b0 here either!
        // But wait! jtag_tck etc are Inputs to the macro. If we pass 1'b0, Yosys instantiates a conb_1.
        // We MUST NOT pass 1'b0. We should add inputs to rv32i_top for these? No, they ALREADY are inputs.
        // We can wire them to wb_rst_i (if it's acceptable for JTAG to toggle on reset), but the best is to wire them to a known low signal like `la_data_in[0]`.
        // Actually, la_data_in is an input. We can just wire them to la_data_in[127:123]!
        .jtag_tck   (la_data_in[127]),
        .jtag_tms   (la_data_in[126]),
        .jtag_tdi   (la_data_in[125]),
        .jtag_tdo   (),
        .jtag_trst_n(la_data_in[124]),

        // BIST
        .bist_mode_ext(la_data_in[123]),
        .bist_done_ext(),
        .bist_pass_ext(),

        // IRQ — route to Caravel user_irq
        // irq
        .irq(user_irq)

        // Tie-offs and unused bindings removed for simulation
    );

endmodule

`default_nettype wire
