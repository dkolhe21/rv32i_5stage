//-----------------------------------------------------------------------------
// Module: rv32i_top
// File:   rv32i_top.sv
//
// Description:
//   Top-level module for the 5-Stage RV32I CPU.
//   Wires together the 5-stage rv32_core and the SRAM macros, and 
//   provides a Wishbone slave interface for Caravel integration.
//
// Author: Assistant
// Date:   2026-06-09
//-----------------------------------------------------------------------------

module rv32i_top (
`ifdef USE_POWER_PINS
    inout wire vccd1,
    inout wire vssd1,
    inout wire vccd2,
    inout wire vssd2,
    inout wire vdda1,
    inout wire vssa1,
    inout wire vdda2,
    inout wire vssa2,
`endif
    input  logic        clk,
    input  logic        rst_n,

    //--------------------------------------------------------------------------
    // Wishbone Slave Interface
    //--------------------------------------------------------------------------
    input  logic        wb_clk_i,
    input  logic        wb_rst_i,
    input  logic        wbs_stb_i,
    input  logic        wbs_cyc_i,
    input  logic        wbs_we_i,
    input  logic [3:0]  wbs_sel_i,
    input  logic [31:0] wbs_dat_i,
    input  logic [31:0] wbs_adr_i,
    output logic        wbs_ack_o,
    output logic [31:0] wbs_dat_o,

    // JTAG and BIST (Stubs for future integration)
    input  logic        jtag_tck,
    input  logic        jtag_tms,
    input  logic        jtag_tdi,
    output logic        jtag_tdo,
    input  logic        jtag_trst_n,

    input  logic        bist_mode_ext,
    output logic        bist_done_ext,
    output logic        bist_pass_ext
);

    //==========================================================================
    // Internal wires: Core ↔ Memories
    //==========================================================================
    logic        core_imem_en;
    logic [31:0] core_imem_addr;
    logic [31:0] core_imem_rdata;

    logic        core_dmem_en;
    logic [31:0] core_dmem_addr;
    logic [31:0] core_dmem_wdata;
    logic [3:0]  core_dmem_wmask;
    logic        core_dmem_we;
    logic [31:0] core_dmem_rdata;

    // Tie off JTAG/BIST for now
    assign jtag_tdo      = 1'b0;
    assign bist_done_ext = 1'b1;
    assign bist_pass_ext = 1'b1;

    //==========================================================================
    // Wishbone Decoder & Acknowledge
    //==========================================================================
    logic wb_valid;
    assign wb_valid = wbs_cyc_i & wbs_stb_i;

    logic wb_ack_q;
    always_ff @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            wb_ack_q <= 1'b0;
        end else begin
            if (wb_valid && !wb_ack_q)
                wb_ack_q <= 1'b1;
            else
                wb_ack_q <= 1'b0;
        end
    end
    assign wbs_ack_o = wb_ack_q;

    //==========================================================================
    // RV32I 5-Stage Core
    //==========================================================================
    rv32_core u_rv32_core (
        .clk            (clk),
        .rst_n          (rst_n),
        // IMEM interface
        .imem_en        (core_imem_en),
        .imem_addr      (core_imem_addr),
        .imem_rdata     (core_imem_rdata),
        // DMEM interface
        .dmem_en        (core_dmem_en),
        .dmem_addr      (core_dmem_addr),
        .dmem_wdata     (core_dmem_wdata),
        .dmem_wmask     (core_dmem_wmask),
        .dmem_we        (core_dmem_we),
        .dmem_rdata     (core_dmem_rdata),
        // Debug interface (tied off)
        .dbg_halt       (1'b0),
        .dbg_write_en   (1'b0),
        .dbg_reg_addr   (5'b0),
        .dbg_write_data (32'b0),
        .dbg_read_data  ()
    );

    //==========================================================================
    // SRAM Macros (Direct Instantiation as requested: 2KB OpenRAM)
    //==========================================================================
    
    // Instruction Memory SRAM
    sky130_sram_2kbyte_1rw1r_32x512_8 u_imem_sram (
`ifdef USE_POWER_PINS
        .vccd1 (vccd1),
        .vssd1 (vssd1),
`endif
        .clk0   (clk),
        .csb0   (~core_imem_en),
        .web0   (1'b1),          // Read only for IMEM
        .wmask0 (4'b0000),
        .addr0  (core_imem_addr[10:2]),
        .din0   (32'b0),
        .dout0  (core_imem_rdata),
        
        // Port 1 tied off
        .clk1   (1'b0),
        .csb1   (1'b1),
        .addr1  (9'b0),
        .dout1  ()
    );

    // Data Memory SRAM
    sky130_sram_2kbyte_1rw1r_32x512_8 u_dmem_sram (
`ifdef USE_POWER_PINS
        .vccd1 (vccd1),
        .vssd1 (vssd1),
`endif
        .clk0   (clk),
        .csb0   (~core_dmem_en),
        .web0   (~core_dmem_we),
        .wmask0 (core_dmem_wmask),
        .addr0  (core_dmem_addr[10:2]),
        .din0   (core_dmem_wdata),
        .dout0  (core_dmem_rdata),
        
        // Port 1 tied off
        .clk1   (1'b0),
        .csb1   (1'b1),
        .addr1  (9'b0),
        .dout1  ()
    );

endmodule
