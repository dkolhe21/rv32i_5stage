# Interface Definition

The `rv32i_top` core utilizes the Wishbone B4 protocol to communicate with the overarching Caravel Management SoC. Additionally, it features dedicated SRAM ports for dual 2KB macros and maps status/debugging signals directly to the Caravel Logic Analyzer (LA) probes and Multi-Project IO (`mprj_io`) pads.

---

## 1. Wishbone B4 Signals

The Wishbone interface operates in Classic Standard mode, acting as a Slave to the Management SoC's Master controller.

| Signal | Width | Dir | Description |
|--------|-------|-----|-------------|
| `wb_clk_i` | 1 | IN | System Clock. All transactions are synchronous to the rising edge. |
| `wb_rst_i` | 1 | IN | Active-High Reset. Synchronously resets the core FSM. |
| `wbs_cyc_i` | 1 | IN | Cycle valid. Asserted when a valid bus cycle is in progress. |
| `wbs_stb_i` | 1 | IN | Strobe valid. Asserts that the slave is selected for the current cycle. |
| `wbs_we_i` | 1 | IN | Write Enable. `1` = Write cycle, `0` = Read cycle. |
| `wbs_adr_i` | 32 | IN | Address Bus. Word-aligned address. |
| `wbs_dat_i` | 32 | IN | Data Input. Data from the Master to be written into the Slave. |
| `wbs_sel_i` | 4 | IN | Byte Select. Indicates which bytes of the 32-bit data bus are valid. |
| `wbs_ack_o` | 1 | OUT | Acknowledge. Asserted by the Slave to indicate successful transaction completion. |
| `wbs_dat_o` | 32 | OUT | Data Output. Data read from the Slave back to the Master. |

### 1.1 Timing Diagram: Wishbone Read Cycle

<svg width="600" height="250" xmlns="http://www.w3.org/2000/svg" font-family="monospace" font-size="14" style="background-color: white; padding: 10px; border-radius: 5px;">
  <text x="10" y="20" font-weight="bold">Wishbone Read Cycle</text>
  <text x="10" y="55">wb_clk_i</text>
  <path d="M 100 50 h 20 v -15 h 20 v 15 h 20 v -15 h 20 v 15 h 20 v -15 h 20 v 15 h 20 v -15 h 20 v 15 h 20 v -15 h 20 v 15 " fill="none" stroke="black" stroke-width="2"/>
  <text x="10" y="85">wbs_adr_i</text>
  <path d="M 100 80 h 35 l 5 -10 h 155 l 5 10 h 100" fill="none" stroke="black" stroke-width="2"/>
  <path d="M 100 65 h 35 l 5 10 h 155 l 5 -10 h 100" fill="none" stroke="black" stroke-width="2"/>
  <text x="210" y="78" text-anchor="middle">ADR1</text>
  <text x="10" y="115">wbs_cyc_i</text>
  <path d="M 100 110 h 40 v -15 h 155 v 15 h 105" fill="none" stroke="black" stroke-width="2"/>
  <text x="10" y="145">wbs_stb_i</text>
  <path d="M 100 140 h 40 v -15 h 155 v 15 h 105" fill="none" stroke="black" stroke-width="2"/>
  <text x="10" y="175">wbs_we_i</text>
  <path d="M 100 170 h 300" fill="none" stroke="black" stroke-width="2"/>
  <text x="10" y="205">wbs_ack_o</text>
  <path d="M 100 200 h 160 v -15 h 35 v 15 h 105" fill="none" stroke="black" stroke-width="2"/>
  <text x="10" y="235">wbs_dat_o</text>
  <path d="M 100 230 h 155 l 5 -10 h 35 l 5 10 h 100" fill="none" stroke="black" stroke-width="2"/>
  <path d="M 100 215 h 155 l 5 10 h 35 l 5 -10 h 100" fill="none" stroke="black" stroke-width="2"/>
  <text x="180" y="228" text-anchor="middle">DAT1</text>
</svg>

### 1.2 Timing Diagram: Wishbone Write Cycle

<svg width="600" height="250" xmlns="http://www.w3.org/2000/svg" font-family="monospace" font-size="14" style="background-color: white; padding: 10px; border-radius: 5px;">
  <text x="10" y="20" font-weight="bold">Wishbone Write Cycle</text>
  <text x="10" y="55">wb_clk_i</text>
  <path d="M 100 50 h 20 v -15 h 20 v 15 h 20 v -15 h 20 v 15 h 20 v -15 h 20 v 15 h 20 v -15 h 20 v 15 h 20 v -15 h 20 v 15 " fill="none" stroke="black" stroke-width="2"/>
  <text x="10" y="85">wbs_adr_i</text>
  <path d="M 100 80 h 35 l 5 -10 h 155 l 5 10 h 100" fill="none" stroke="black" stroke-width="2"/>
  <path d="M 100 65 h 35 l 5 10 h 155 l 5 -10 h 100" fill="none" stroke="black" stroke-width="2"/>
  <text x="210" y="78" text-anchor="middle">ADR1</text>
  <text x="10" y="115">wbs_dat_i</text>
  <path d="M 100 110 h 35 l 5 -10 h 155 l 5 10 h 100" fill="none" stroke="black" stroke-width="2"/>
  <path d="M 100 95 h 35 l 5 10 h 155 l 5 -10 h 100" fill="none" stroke="black" stroke-width="2"/>
  <text x="210" y="108" text-anchor="middle">DAT1</text>
  <text x="10" y="145">wbs_cyc_i</text>
  <path d="M 100 140 h 40 v -15 h 155 v 15 h 105" fill="none" stroke="black" stroke-width="2"/>
  <text x="10" y="175">wbs_stb_i</text>
  <path d="M 100 170 h 40 v -15 h 155 v 15 h 105" fill="none" stroke="black" stroke-width="2"/>
  <text x="10" y="205">wbs_we_i</text>
  <path d="M 100 200 h 40 v -15 h 155 v 15 h 105" fill="none" stroke="black" stroke-width="2"/>
  <text x="10" y="235">wbs_ack_o</text>
  <path d="M 100 230 h 160 v -15 h 35 v 15 h 105" fill="none" stroke="black" stroke-width="2"/>
</svg>

---

## 2. Caravel Wrapper Signals Mapping

The `user_project_wrapper` maps the internal `rv32i_top` signals to the physical pads of the Caravel SoC.

### Multi-Project IO (`mprj_io`)
The GPIO pads are utilized for external debug and status flagging.

| `mprj_io` Pin | Core Signal | Function |
|---------------|-------------|----------|
| `mprj_io[0]` | `jtag_tck` | JTAG Test Clock (Tied off currently). |
| `mprj_io[1]` | `jtag_tms` | JTAG Test Mode Select. |
| `mprj_io[2]` | `jtag_tdi` | JTAG Test Data In. |
| `mprj_io[3]` | `jtag_tdo` | JTAG Test Data Out. |
| `mprj_io[4]` | `jtag_trst_n`| JTAG Reset (Active-Low). |
| `mprj_io[5]` | `bist_mode_ext`| External BIST Trigger. |
| `mprj_io[6]` | `bist_done_ext`| BIST Completion Flag. |
| `mprj_io[14:12]`| `irq[2:0]` | Interrupt Request lines routed back to Management SoC. |

### Logic Analyzer Probes (`la_data_in` / `la_data_out`)
The Caravel harness provides 128 Logic Analyzer channels for deep silicon debugging.
- `la_data_out[31:0]` is mapped to the Core's Program Counter (PC) to trace instruction execution in real-time.
- `la_data_out[63:32]` is mapped to the current ALU result to monitor execution math.
- `la_oen` is configured to enable output from the core to the Management SoC for these ranges.

---

## 3. SRAM Macro Ports

The core integrates two identical `sky130_sram_2kbyte_1rw1r_32x512_8` macros.
They have a dual-port configuration: Port 0 is Read/Write, Port 1 is Read-Only.

| SRAM Port | Width | Dir | Function |
|-----------|-------|-----|----------|
| `clk0` | 1 | IN | Clock for Port 0. |
| `csb0` | 1 | IN | Active-Low Chip Select for Port 0. |
| `web0` | 1 | IN | Active-Low Write Enable for Port 0. |
| `wmask0` | 4 | IN | Byte Write Mask for Port 0. |
| `addr0` | 9 | IN | 9-bit Word Address for Port 0 (512 depth). |
| `din0` | 32 | IN | 32-bit Data Input for Port 0. |
| `dout0` | 32 | OUT | 32-bit Data Output for Port 0. |
| `clk1` | 1 | IN | Clock for Port 1. |
| `csb1` | 1 | IN | Active-Low Chip Select for Port 1. |
| `addr1` | 9 | IN | 9-bit Word Address for Port 1. |
| `dout1` | 32 | OUT | 32-bit Data Output for Port 1. |
