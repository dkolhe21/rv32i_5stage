//-----------------------------------------------------------------------------
// Module: rv32i_top
// File:   rv32i_top.sv
//
// Description:
//   Top-level for 5-Stage RV32I CPU with Wishbone firmware loader.
//   3-way arbitration: CPU IMEM (port0), CPU DMEM (port0), Caravel WB (port1).
//   Wishbone: 2-cycle registered transaction (decode + access).
//-----------------------------------------------------------------------------

module rv32i_top (
`ifdef USE_POWER_PINS
    inout wire vccd1, inout wire vssd1,
    inout wire vccd2, inout wire vssd2,
    inout wire vdda1, inout wire vssa1,
    inout wire vdda2, inout wire vssa2,
`endif
    // Clock and Reset
    input  logic        clk,
    input  logic        rst,

    // Wishbone Slave Interface (Caravel Management SoC -> CPU)
    input  logic        wb_clk_i,
    input  logic        wb_rst_i,
    input  logic        wbs_cyc_i,
    input  logic        wbs_stb_i,
    input  logic        wbs_we_i,
    input  logic [3:0]  wbs_sel_i,
    input  logic [31:0] wbs_adr_i,
    input  logic [31:0] wbs_dat_i,
    output logic        wbs_ack_o,
    output logic [31:0] wbs_dat_o,

    // IRQ
    output logic [2:0]  irq,

    // JTAG & BIST (Stubbed out to match Caravel interface)
    input  logic        jtag_tck,
    input  logic        jtag_tms,
    input  logic        jtag_tdi,
    output logic        jtag_tdo,
    input  logic        jtag_trst_n,
    input  logic        bist_mode_ext,
    output logic        bist_done_ext,
    output logic        bist_pass_ext,

    // Caravel wrapper tie-offs
    output logic [37:0]  io_out,
    output logic [37:0]  io_oeb,
    output logic [127:0] la_data_out
);

    //==========================================================================
    // Tie-offs
    //==========================================================================
    assign irq           = 3'b0;
    assign jtag_tdo      = 1'b0;
    assign bist_done_ext = 1'b1;
    assign bist_pass_ext = 1'b1;
    assign io_out        = 38'b0;
    assign io_oeb        = 38'h3FFFFFFFFF; // All 1s for High-Z
    assign la_data_out   = 128'b0;

    //==========================================================================
    // Address Map
    //==========================================================================
    localparam logic [31:0] IMEM_BASE = 32'h0000_0000;
    localparam logic [31:0] IMEM_MASK = 32'h0000_1FFF;  // 8 KB
    localparam logic [31:0] DMEM_BASE = 32'h0000_2000;
    localparam logic [31:0] DMEM_MASK = 32'h0000_1FFF;  // 8 KB
    localparam logic [31:0] CTRL_BASE = 32'h1000_0000;

    //==========================================================================
    // Core ↔ Memory Wires
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
    logic [31:0] wb_imem_rdata, wb_dmem_rdata;

    //==========================================================================
    // Soft Reset Register (Wishbone-mapped at CTRL_BASE)
    //==========================================================================
    logic cpu_reset_n;
    logic [31:0] ctrl_reg;

    //==========================================================================
    // Registered Wishbone Decode (Cycle 0: Decode, Cycle 1: Access)
    //==========================================================================
    typedef enum logic [1:0] {WB_IDLE, WB_DECODE, WB_ACCESS, WB_ACK} wb_state_t;
    wb_state_t wb_state, wb_state_next;

    logic        wb_req_valid;
    logic        wb_req_is_imem, wb_req_is_dmem, wb_req_is_ctrl;
    logic [31:0] wb_req_addr;
    logic        wb_req_we;
    logic [3:0]  wb_req_sel;
    logic [31:0] wb_req_dat;

    // Combinational decode (registered next cycle)
    assign wb_req_valid = wbs_cyc_i & wbs_stb_i;

    always_ff @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            wb_state      <= WB_IDLE;
            wb_req_is_imem <= 1'b0;
            wb_req_is_dmem <= 1'b0;
            wb_req_is_ctrl <= 1'b0;
            wb_req_addr   <= 32'b0;
            wb_req_we     <= 1'b0;
            wb_req_sel    <= 4'b0;
            wb_req_dat    <= 32'b0;
            wbs_ack_o     <= 1'b0;
            wbs_dat_o     <= 32'b0;
            ctrl_reg      <= 32'h0000_0000;  // CPU held in reset by default
        end else begin
            wb_state <= wb_state_next;

            case (wb_state)
                WB_IDLE: if (wb_req_valid) begin
                    wb_req_addr <= wbs_adr_i;
                    wb_req_we   <= wbs_we_i;
                    wb_req_sel  <= wbs_sel_i;
                    wb_req_dat  <= wbs_dat_i;
                    wb_req_is_imem <= (wbs_adr_i & ~IMEM_MASK) == IMEM_BASE;
                    wb_req_is_dmem <= (wbs_adr_i & ~DMEM_MASK) == DMEM_BASE;
                    wb_req_is_ctrl <= (wbs_adr_i == CTRL_BASE);
                end

                WB_ACCESS: begin
                    if (wb_req_is_ctrl && wb_req_we) begin
                        ctrl_reg <= wb_req_dat;  // Bit 0 = cpu_reset_n
                    end
                end

                WB_ACK: begin
                    wbs_ack_o <= 1'b1;
                    if (wb_req_is_imem) wbs_dat_o <= wb_imem_rdata;
                    else if (wb_req_is_dmem) wbs_dat_o <= wb_dmem_rdata;
                    else if (wb_req_is_ctrl) wbs_dat_o <= ctrl_reg;
                    else wbs_dat_o <= 32'hDEAD_BEEF;
                end

                default: begin
                    wbs_ack_o <= 1'b0;
                end
            endcase
        end
    end

    // State machine
    always_comb begin
        wb_state_next = wb_state;
        case (wb_state)
            WB_IDLE:   if (wb_req_valid) wb_state_next = WB_DECODE;
            WB_DECODE: wb_state_next = WB_ACCESS;
            WB_ACCESS: wb_state_next = WB_ACK;
            WB_ACK:    wb_state_next = WB_IDLE;
            default:   wb_state_next = WB_IDLE;
        endcase
    end

    assign cpu_reset_n = ctrl_reg[0] & ~rst; // Used rst instead of wb_rst_i  // Both WB and external reset must be de-asserted

    //==========================================================================
    // 3-Way Arbitration: CPU vs. Wishbone
    //==========================================================================
    // Priority: Wishbone (when active) > CPU
    // IMEM: Port 0 = CPU fetch, Port 1 = WB loader (read-only)
    // DMEM: Port 0 = CPU access, Port 1 = WB debug (read/write)

    logic wb_active;
    assign wb_active = (wb_state == WB_ACCESS);

    // IMEM Arbitration
    // Port 0 (1RW): Wishbone loader
    // Port 1 (1R) : CPU instruction fetch
    logic        imem_csb0, imem_csb1;
    logic        imem_web0;
    logic [3:0]  imem_wmask0;
    logic [8:0]  imem_addr0, imem_addr1;
    logic [31:0] imem_din0;
    logic [31:0] imem_dout0, imem_dout1;

    assign imem_csb0   = ~(wb_active & wb_req_is_imem);
    assign imem_web0   = ~wb_req_we;
    assign imem_wmask0 = wb_req_sel;
    assign imem_addr0  = wb_req_addr[10:2];
    assign imem_din0   = wb_req_dat;
    assign wb_imem_rdata = imem_dout0;

    assign imem_csb1   = ~core_imem_en;
    assign imem_addr1  = core_imem_addr[10:2];
    assign core_imem_rdata = imem_dout1;

    // DMEM Arbitration
    // Port 0 (1RW): Multiplexed CPU and Wishbone
    // Port 1 (1R) : Tied off
    logic        dmem_csb0, dmem_csb1;
    logic        dmem_web0;
    logic [3:0]  dmem_wmask0;
    logic [8:0]  dmem_addr0, dmem_addr1;
    logic [31:0] dmem_din0;
    logic [31:0] dmem_dout0, dmem_dout1;

    assign dmem_csb0   = (wb_active & wb_req_is_dmem) ? 1'b0 : ~core_dmem_en;
    assign dmem_web0   = (wb_active & wb_req_is_dmem) ? ~wb_req_we : ~core_dmem_we;
    assign dmem_wmask0 = (wb_active & wb_req_is_dmem) ? wb_req_sel : core_dmem_wmask;
    assign dmem_addr0  = (wb_active & wb_req_is_dmem) ? wb_req_addr[10:2] : core_dmem_addr[10:2];
    assign dmem_din0   = (wb_active & wb_req_is_dmem) ? wb_req_dat : core_dmem_wdata;
    
    assign core_dmem_rdata = dmem_dout0;
    assign wb_dmem_rdata   = dmem_dout0;

    assign dmem_csb1   = 1'b1;
    assign dmem_addr1  = 9'b0;

    //==========================================================================
    // RV32I 5-Stage Core
    //==========================================================================
    rv32_core u_rv32_core (
        .clk            (clk),
        .rst_n          (cpu_reset_n),
        .imem_en        (core_imem_en),
        .imem_addr      (core_imem_addr),
        .imem_rdata     (core_imem_rdata),
        .dmem_en        (core_dmem_en),
        .dmem_addr      (core_dmem_addr),
        .dmem_wdata     (core_dmem_wdata),
        .dmem_wmask     (core_dmem_wmask),
        .dmem_we        (core_dmem_we),
        .dmem_rdata     (core_dmem_rdata),
        .dbg_halt       (1'b0),
        .dbg_write_en   (1'b0),
        .dbg_reg_addr   (5'b0),
        .dbg_write_data (32'b0),
        /* verilator lint_off PINCONNECTEMPTY */
        .dbg_read_data  ()
        /* verilator lint_on PINCONNECTEMPTY */
    );

    //==========================================================================
    // SRAM Macros (2KB each, 1RW + 1R)
    //==========================================================================
    sky130_sram_2kbyte_1rw1r_32x512_8 u_imem_sram (
    `ifdef USE_POWER_PINS
        .vccd1 (vccd1), .vssd1 (vssd1),
    `endif
        .clk0   (clk),
        .csb0   (imem_csb0),
        .web0   (imem_web0),
        .wmask0 (imem_wmask0),
        .addr0  (imem_addr0),
        .din0   (imem_din0),
        .dout0  (imem_dout0),
        .clk1   (clk),
        .csb1   (imem_csb1),
        .addr1  (imem_addr1),
        .dout1  (imem_dout1)
    );

    sky130_sram_2kbyte_1rw1r_32x512_8 u_dmem_sram (
    `ifdef USE_POWER_PINS
        .vccd1 (vccd1), .vssd1 (vssd1),
    `endif
        .clk0   (clk),
        .csb0   (dmem_csb0),
        .web0   (dmem_web0),
        .wmask0 (dmem_wmask0),
        .addr0  (dmem_addr0),
        .din0   (dmem_din0),
        .dout0  (dmem_dout0),
        .clk1   (clk),
        .csb1   (dmem_csb1),
        .addr1  (dmem_addr1),
        .dout1  (dmem_dout1)
    );

endmodule
