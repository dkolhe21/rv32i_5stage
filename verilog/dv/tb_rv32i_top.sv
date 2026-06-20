//-----------------------------------------------------------------------------
// Module: tb_rv32i_top
// File:   tb_rv32i_top.sv
//
// Description:
//   Basic testbench for the 5-stage RV32I top level.
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

module tb_rv32i_top;

    logic clk;
    logic rst_n;

    // Wishbone
    logic        wb_clk_i;
    logic        wb_rst_i;
    logic        wbs_stb_i;
    logic        wbs_cyc_i;
    logic        wbs_we_i;
    logic [3:0]  wbs_sel_i;
    logic [31:0] wbs_dat_i;
    logic [31:0] wbs_adr_i;
    logic        wbs_ack_o;
    logic [31:0] wbs_dat_o;

    // JTAG / BIST
    logic jtag_tck, jtag_tms, jtag_tdi, jtag_tdo, jtag_trst_n;
    logic bist_mode_ext, bist_done_ext, bist_pass_ext;

    rv32i_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .wb_clk_i(wb_clk_i),
        .wb_rst_i(wb_rst_i),
        .wbs_stb_i(wbs_stb_i),
        .wbs_cyc_i(wbs_cyc_i),
        .wbs_we_i(wbs_we_i),
        .wbs_sel_i(wbs_sel_i),
        .wbs_dat_i(wbs_dat_i),
        .wbs_adr_i(wbs_adr_i),
        .wbs_ack_o(wbs_ack_o),
        .wbs_dat_o(wbs_dat_o),
        .jtag_tck(jtag_tck),
        .jtag_tms(jtag_tms),
        .jtag_tdi(jtag_tdi),
        .jtag_tdo(jtag_tdo),
        .jtag_trst_n(jtag_trst_n),
        .bist_mode_ext(bist_mode_ext),
        .bist_done_ext(bist_done_ext),
        .bist_pass_ext(bist_pass_ext)
    );

    // Clock generation
    initial begin
        clk = 0;
        wb_clk_i = 0;
        forever #5 clk = ~clk;
    end

    // Test sequence
    initial begin
        $dumpfile("tb_rv32i_top.vcd");
        $dumpvars(0, tb_rv32i_top);

        // Initialize inputs
        rst_n = 0;
        wb_rst_i = 1;
        wbs_stb_i = 0;
        wbs_cyc_i = 0;
        wbs_we_i = 0;
        wbs_sel_i = 0;
        wbs_dat_i = 0;
        wbs_adr_i = 0;
        jtag_tck = 0;
        jtag_tms = 0;
        jtag_tdi = 0;
        jtag_trst_n = 0;
        bist_mode_ext = 0;

        // Load a simple program into IMEM (ADDI x1, x0, 5; ADDI x2, x0, 10; ADD x3, x1, x2)
        // 0x00500093 : addi x1, x0, 5
        // 0x00a00113 : addi x2, x0, 10
        // 0x002081b3 : add x3, x1, x2
        // 0x0000006f : j 0 (infinite loop)
        dut.u_imem_sram.mem[0] = 32'h00500093;
        dut.u_imem_sram.mem[1] = 32'h00a00113;
        dut.u_imem_sram.mem[2] = 32'h002081b3;
        dut.u_imem_sram.mem[3] = 32'h0000006f;

        // Release reset
        #20 rst_n = 1;
        wb_rst_i = 0;

        // Run for a few cycles
        #200;

        // Check result
        if (dut.u_rv32_core.u_reg_file.regs[3] == 32'd15) begin
            $display("TEST PASSED: x3 = 15");
        end else begin
            $display("TEST FAILED: x3 = %d", dut.u_rv32_core.u_reg_file.regs[3]);
        end

        $finish;
    end

endmodule
