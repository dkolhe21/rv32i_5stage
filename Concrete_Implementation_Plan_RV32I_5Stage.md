# Concrete Implementation Plan: 5-Stage Pipelined RV32I Processor

## 1. Target Specifications & Physical Constraints

| Parameter | Target Value | Worst-Case (SS/125°C) | Unit |
|-----------|-------------|----------------------|------|
| **Target Fmax** | 135 | ≥ 100 | MHz |
| **Core Voltage** | 1.8 | 1.62 – 1.98 | V |
| **Target Die Size (core only)** | 0.45 | ≤ 0.60 | mm² |
| **Total Caravel Die** | 2.30 × 2.30 | — | mm |
| **Standard Cell Utilization** | 65 | ≤ 75 | % |
| **Power Budget (active)** | 8 | ≤ 12 | mW @ 135 MHz |
| **Power Budget (static)** | 250 | ≤ 400 | µW |
| **Process Node** | SkyWater 130nm (SKY130A) | — | — |
| **Temperature Range** | –40 to +125 | — | °C |

### 1.1 Clock & Reset Strategy
- **Core Clock**: Single domain, `clk_i` driven by on-chip PLL or external XTAL (16 MHz → PLL ×8.4375 = 135 MHz).
- **Reset**: Active-low asynchronous assert, synchronous de-assert (`rst_ni`). Minimum reset pulse: 16 clock cycles.
- **JTAG/Debug**: Optional RISC-V Debug Module (0.13.2) with 4-entry ABSTRACTCS; **not** in MVP scope.

---

## 2. ALU Implementation: Concrete Instruction Set & Datapath

### 2.1 ALU Instruction Matrix (RV32I Base Integer)

The ALU implements **25 distinct RV32I instructions** (all R-type and I-type arithmetic/logical operations, plus branch comparisons).

| # | Instruction | Type | Opcode | Funct3 | Funct7 | ALU Op | Description |
|---|-------------|------|--------|--------|--------|--------|-------------|
| 1 | `ADD` | R | 0110011 | 000 | 0000000 | ADD | `rd = rs1 + rs2` |
| 2 | `SUB` | R | 0110011 | 000 | 0100000 | SUB | `rd = rs1 - rs2` |
| 3 | `SLL` | R | 0110011 | 001 | 0000000 | SLL | `rd = rs1 << rs2[4:0]` |
| 4 | `SLT` | R | 0110011 | 010 | 0000000 | SLT | `rd = (rs1 < rs2) ? 1 : 0` (signed) |
| 5 | `SLTU` | R | 0110011 | 011 | 0000000 | SLTU | `rd = (rs1 < rs2) ? 1 : 0` (unsigned) |
| 6 | `XOR` | R | 0110011 | 100 | 0000000 | XOR | `rd = rs1 ^ rs2` |
| 7 | `SRL` | R | 0110011 | 101 | 0000000 | SRL | `rd = rs1 >> rs2[4:0]` (logical) |
| 8 | `SRA` | R | 0110011 | 101 | 0100000 | SRA | `rd = rs1 >> rs2[4:0]` (arithmetic) |
| 9 | `OR` | R | 0110011 | 110 | 0000000 | OR | `rd = rs1 | rs2` |
| 10 | `AND` | R | 0110011 | 111 | 0000000 | AND | `rd = rs1 & rs2` |
| 11 | `ADDI` | I | 0010011 | 000 | — | ADD | `rd = rs1 + imm` |
| 12 | `SLTI` | I | 0010011 | 010 | — | SLT | `rd = (rs1 < imm) ? 1 : 0` |
| 13 | `SLTIU` | I | 0010011 | 011 | — | SLTU | `rd = (rs1 < imm) ? 1 : 0` |
| 14 | `XORI` | I | 0010011 | 100 | — | XOR | `rd = rs1 ^ imm` |
| 15 | `ORI` | I | 0010011 | 110 | — | OR | `rd = rs1 | imm` |
| 16 | `ANDI` | I | 0010011 | 111 | — | AND | `rd = rs1 & imm` |
| 17 | `SLLI` | I | 0010011 | 001 | 0000000 | SLL | `rd = rs1 << shamt` |
| 18 | `SRLI` | I | 0010011 | 101 | 0000000 | SRL | `rd = rs1 >> shamt` |
| 19 | `SRAI` | I | 0010011 | 101 | 0100000 | SRA | `rd = rs1 >> shamt` (arith) |
| 20 | `LUI` | U | 0110111 | — | — | PASS_B | `rd = imm << 12` |
| 21 | `AUIPC` | U | 0010111 | — | — | ADD | `rd = PC + (imm << 12)` |
| 22 | `BEQ` | B | 1100011 | 000 | — | SUB | `taken = (rs1 == rs2)` |
| 23 | `BNE` | B | 1100011 | 001 | — | SUB | `taken = (rs1 != rs2)` |
| 24 | `BLT` | B | 1100011 | 100 | — | SLT | `taken = (rs1 < rs2)` signed |
| 25 | `BGE` | B | 1100011 | 101 | — | SLT | `taken = (rs1 >= rs2)` signed |
| 26 | `BLTU` | B | 1100011 | 110 | — | SLTU | `taken = (rs1 < rs2)` unsigned |
| 27 | `BGEU` | B | 1100011 | 111 | — | SLTU | `taken = (rs1 >= rs2)` unsigned |

### 2.2 ALU Datapath Microarchitecture

```
ALU_WIDTH = 32 bits
ALU_OP_WIDTH = 4 bits  (encodes 10 operations: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND, PASS_B)

Critical Path Budget:
  - Input mux (forwarding):  0.35 ns
  - ALU core operation:     1.85 ns
  - Branch comparator:      0.40 ns
  - Output setup:           0.15 ns
  -----------------------------------
  Total combinational:      2.75 ns  →  364 MHz theoretical max
  With 30% margin + routing: 3.70 ns  →  270 MHz (well above 135 MHz target)
```

**ALU Internal Structure:**
- **Adder/Subtractor**: 32-bit Kogge-Stone parallel prefix adder (log₂(32) = 5 stages, ~2.5× faster than ripple-carry).
- **Shifter**: 32-bit barrel shifter, 5-stage logarithmic (mux-based), supports both logical and arithmetic right shift via sign-extension mux.
- **Comparator**: Reuses adder subtraction result + overflow logic for SLT/SLTU; branch comparison done in parallel with ALU result.
- **Logical Unit**: Independent 32-bit AND/OR/XOR array (1 gate delay).

---

## 3. Pipeline Stage Breakdown & Timing

### 3.1 Stage Latency Budget (Target: 135 MHz = 7.41 ns cycle)

| Stage | Logic Delay | Setup | Margin | Total | Description |
|-------|-------------|-------|--------|-------|-------------|
| **IF** | 2.1 ns | 0.3 ns | 0.5 ns | 2.9 ns | PC + IMEM read (SRAM macro) |
| **ID** | 2.4 ns | 0.3 ns | 0.4 ns | 3.1 ns | Decode + Regfile read (2 ports) |
| **EX** | 2.75 ns | 0.3 ns | 0.35 ns | 3.4 ns | ALU + branch eval + forwarding mux |
| **MEM** | 2.0 ns | 0.3 ns | 0.5 ns | 2.8 ns | DMEM address + byte-mask gen |
| **WB** | 1.2 ns | 0.3 ns | 0.6 ns | 2.1 ns | Sign-extend + Regfile write |

*Critical path is EX stage at 3.4 ns; target cycle is 7.41 ns → **46% utilization**, safe for PVT variation.*

### 3.2 Pipeline Register Specifications

All inter-stage registers are **positive-edge triggered, active-low async reset**.

| Register | Width (bits) | Fields | Reset Value |
|----------|-------------|--------|-------------|
| `IF/ID` | 96 | `pc[31:0]`, `instr[31:0]`, `valid`, `pred_taken` | `'0` (valid=0) |
| `ID/EX` | 168 | `pc[31:0]`, `rs1_data[31:0]`, `rs2_data[31:0]`, `imm[31:0]`, `rd_addr[4:0]`, `alu_op[3:0]`, `ctrl[15:0]`, `valid` | `'0` |
| `EX/MEM`| 128 | `pc[31:0]`, `alu_result[31:0]`, `rs2_data[31:0]`, `rd_addr[4:0]`, `ctrl[10:0]`, `valid` | `'0` |
| `MEM/WB`| 96 | `pc[31:0]`, `wb_data[31:0]`, `rd_addr[4:0]`, `reg_write`, `valid` | `'0` |

**Total pipeline register overhead: 488 bits = 61 bytes = ~488 D-flip-flops**.

### 3.3 Forwarding & Hazard Unit Implementation

**Forwarding Unit (`forwarding_unit.sv`):**
- **Inputs**: `id_ex_rs1[4:0]`, `id_ex_rs2[4:0]`, `ex_mem_rd[4:0]`, `ex_mem_regwrite`, `mem_wb_rd[4:0]`, `mem_wb_regwrite`
- **Outputs**: `forward_a[1:0]`, `forward_b[1:0]` (2-bit mux select each)
- **Priority**: EX/MEM (most recent) > MEM/WB > Register File
- **Latency**: Pure combinational, < 0.4 ns (2-level logic)

**Hazard Detection Unit (`hazard_unit.sv`):**
- **Load-Use Detection**: `id_ex_memread && ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2))`
- **Stall Injection**: `pc_write = 0`, `if_id_write = 0`, `id_ex_flush = 1` (inject bubble)
- **Branch Mispredict Penalty**: Exactly **2 cycles** (flush IF/ID and ID/EX)
- **Jump Penalty**: Exactly **2 cycles** (same as branch-taken)

---

## 4. Memory Subsystem & SoC Integration

### 4.1 Memory Map

| Region | Start Address | End Address | Size | Access | Physical Macro |
|--------|--------------|-------------|------|--------|----------------|
| **Instruction Memory** | 0x0000_0000 | 0x0000_1FFF | 8 KB | RX | `sky130_sram_2kbyte_1rw1r_32x512_8` × 1 |
| **Data Memory** | 0x0000_2000 | 0x0000_3FFF | 8 KB | RW | `sky130_sram_2kbyte_1rw1r_32x512_8` × 1 |
| **Bootloader ROM** | 0x0001_0000 | 0x0001_0FFF | 4 KB | R | Synthesized logic (optional) |
| **MMIO / Caravel** | 0x1000_0000 | 0x1000_00FF | 256 B | RW | Wishbone bridge |

### 4.2 SRAM Macro Configuration

```
Macro: sky130_sram_2kbyte_1rw1r_32x512_8
  - Organization: 512 words × 32 bits = 2,048 bytes
  - Ports: 1 RW (synchronous), 1 R (async read for debug/loader)
  - Cycle time: 6.5 ns (153 MHz max) → compatible with 135 MHz target
  - Read latency: 1 cycle (synchronous)
  - Write mask: 4-bit byte-wise (bits [3:0])
  - Area: ~0.08 mm² per macro
```

**IMEM**: 4 macros = 8 KB (stacked 512×32 → 2048×32)
**DMEM**: 4 macros = 8 KB
**Total SRAM Area**: ~0.64 mm² (dominates core area)

### 4.3 Wishbone Bus Interface (Classic, Wishbone B4)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `wb_clk_i` | 1 | Input | Bus clock (same as core clock) |
| `wb_rst_i` | 1 | Input | Bus reset |
| `wb_adr_i` | 32 | Input | Byte address |
| `wb_dat_i` | 32 | Input | Write data |
| `wb_dat_o` | 32 | Output | Read data |
| `wb_we_i` | 1 | Input | Write enable |
| `wb_sel_i` | 4 | Input | Byte select |
| `wb_stb_i` | 1 | Input | Strobe (transaction valid) |
| `wb_cyc_i` | 1 | Input | Cycle (burst indicator) |
| `wb_ack_o` | 1 | Output | Acknowledge (1-cycle latency for SRAM) |

**Arbitration**: 3-way round-robin arbiter
1. CPU data access (highest priority on DMEM conflict)
2. CPU instruction fetch
3. Caravel Wishbone loader (lowest, only active during boot)

---

## 5. Verification & Simulation Plan

### 5.1 Simulation Environment

| Tool | Version | Purpose |
|------|---------|---------|
| **Verilator** | 5.024+ | Cycle-accurate RTL simulation, CI regression |
| **Icarus Verilog** | 12.0 | Quick smoke tests, gate-level sims |
| **GTKWave** | 3.3.115 | Waveform debug |
| **Cocotb** | 1.8+ | Python testbench framework |
| **RISC-V ISA Sim (Spike)** | 1.1.0+ | Golden reference model |
| **Yosys** | 0.37+ | Synthesis, formal equiv check |
| **SymbiYosys** | latest | Formal property checking |

### 5.2 Testbench Architecture

```
tb_top.sv
├── Clock/Reset Generator (135 MHz, jitter ±50 ps)
├── DUT (rv32i_core)
├── Memory Model (8 KB IMEM + 8 KB DMEM, cycle-accurate SRAM timing)
├── Wishbone Master BFM (for Caravel loader simulation)
├── RVFI Monitor (RISC-V Formal Interface, 64-bit retired insn trace)
├── Spike DPI Bridge (lock-step comparison)
└── Coverage Collector (SystemVerilog covergroups)
```

### 5.3 Test Suites & Coverage Targets

| Test Suite | Test Count | Target Coverage | Description |
|------------|-----------|-----------------|-------------|
| **ISA Compliance (riscv-tests)** | 55 tests | 100% pass | rv32ui-p-* (unit), rv32ui-v-* (virtual) |
| **Directed ALU** | 48 tests | 100% toggle | Corner cases: overflow, zero, sign, max/min |
| **Directed Branch** | 32 tests | 100% FSM | All 6 branch types, forward/backward, ±4 KB offset |
| **Directed Load/Store** | 40 tests | 100% byte-mask | LB/LH/LW/LBU/LHU, SB/SH/SW, unaligned (trap) |
| **Hazard/Forwarding** | 24 tests | 100% path | RAW distance 1, 2, 3; load-use; branch-after-load |
| **Random Instruction (RISC-V DV)** | 10,000+ | >95% line | Constrained random, Spike lock-step compare |
| **Stress Tests** | 8 tests | — | Dhrystone, Coremark, factorial(1000), memcpy(4 KB) |
| **Formal (SVA)** | 12 properties | 100% proof | No deadlock, no X-propagation, ALU correctness |

### 5.4 Coverage Metrics (MVP Signoff Criteria)

| Metric | Target | Tool |
|--------|--------|------|
| **Code Coverage** | ≥ 95% line, 90% branch, 85% expression | Verilator + coverage |
| **Functional Coverage** | 100% of coverpoints | SystemVerilog covergroups |
| **Toggle Coverage** | ≥ 90% (datapath), 100% (control) | Verilator |
| **FSM Coverage** | 100% states, 100% transitions | Verilator |
| **Assertion Coverage** | 100% SVA pass | SymbiYosys |

### 5.5 Formal Verification Properties (SVA)

```systemverilog
// P1: No instruction retires with X data
assert property (@(posedge clk) rvfi_valid -> !$isunknown(rvfi_rd_wdata));

// P2: PC monotonicity (no jumps/branches = PC+4)
assert property (@(posedge clk) 
    (rvfi_valid && !insn_is_branch && !insn_is_jump) 
    |-> (rvfi_pc_wdata == rvfi_pc_rdata + 4));

// P3: Register x0 is always zero after writeback
assert property (@(posedge clk) 
    (reg_write && rd_addr == 5'd0) |-> (rd_data == 32'd0));

// P4: Load-use stall correctness
assert property (@(posedge clk) 
    (load_use_hazard) |-> ##1 (id_ex_valid == 1'b0));

// P5: Branch mispredict flush
assert property (@(posedge clk) 
    (branch_taken_mispredict) |-> ##1 (if_id_valid == 1'b0));
```

### 5.6 Regression & CI Pipeline

```yaml
# .github/workflows/rtl-ci.yml
Stages:
  1. Lint (Verilator --lint-only + svlint)     →  < 2 min
  2. Unit Sim (directed tests, Verilator)      →  < 5 min  (55 tests)
  3. Random Sim (RISC-V DV, 1k seeds)          →  < 30 min
  4. Formal (SymbiYosys, 12 properties)          →  < 20 min
  5. Synthesis Check (Yosys, area/timing est.) →  < 10 min
  6. Coverage Merge & Report                   →  automated
```

---

## 6. Physical Implementation Milestones (OpenLane Flow)

| Milestone | Target Date | Success Criteria |
|-----------|-------------|------------------|
| **RTL Freeze** | Week 4 | All tests pass, coverage ≥ 95% |
| **Synthesis** | Week 5 | Timing clean at 135 MHz, area < 0.60 mm² |
| **Floorplan** | Week 6 | Macro placement legal, core utilization 65% |
| **Placement** | Week 7 | No congestion > 85%, setup slack > 0.5 ns |
| **CTS** | Week 8 | Clock skew < 200 ps, max transition < 400 ps |
| **Routing** | Week 9 | 0 DRC violations, 0 antenna violations |
| **Signoff** | Week 10 | Magic DRC clean, Netgen LVS clean, STA closed |

### 6.1 Synthesis Constraints (SDC)

```tcl
create_clock -name clk -period 7.41 [get_ports clk_i]      ;# 135 MHz
set_clock_uncertainty 0.15 [get_clocks clk]                  ;# 150 ps jitter
set_clock_transition 0.10 [get_clocks clk]                   ;# 100 ps transition
set_input_delay 1.0 -clock clk [all_inputs]                    ;# 1 ns input delay
set_output_delay 1.0 -clock clk [all_outputs]                ;# 1 ns output delay
set_max_fanout 20 [all_design]                               ;# Fanout limit
set_max_transition 0.4 [all_design]                          ;# 400 ps max transition
```

---

## 7. Deliverables Checklist

- [ ] **RTL Source**: SystemVerilog (`*.sv`) — synthesizable, lint-clean
- [ ] **Testbench**: Cocotb + Verilator environment with Makefile
- [ ] **Test Vectors**: 55 riscv-tests + 120 directed tests + 10k random tests
- [ ] **Documentation**: This implementation plan + updated architectural spec
- [ ] **Synthesis Scripts**: Yosys/OpenLane TCL scripts, SDC constraints
- [ ] **GDSII**: Final layout, DRC/LVS clean
- [ ] **Timing Reports**: Setup/hold slack at TT/FF/SS corners
- [ ] **Power Report**: Dynamic + static at 135 MHz, 1.8V, 25°C and 125°C
- [ ] **Firmware Examples**: Blink LED, UART echo, Dhrystone benchmark

---

*Document Version: 1.0 — Concrete Implementation Plan*
*Target Tape-out: Compatible with Caravel User Project Template (mpw-9 or later)*
