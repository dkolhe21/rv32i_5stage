# RV32I Core: Verification & Test Methodology

This document outlines the rigorous verification methodology used to validate the 5-stage RISC-V core prior to tapeout. Due to the unforgiving nature of physical silicon, the design was validated through multiple layers of abstraction: from standalone unit tests to full System-on-Chip (SoC) bare-metal execution.

---

## 1. Verification Methodology

Our validation strategy employs a **Bottom-Up** verification methodology, utilizing industry-standard open-source EDA tools.

### Tools Used
* **Simulator:** Icarus Verilog (`iverilog`) for functional RTL and Gate-Level Simulation (GLS).
* **Waveform Viewer:** GTKWave for analyzing `.vcd` (Value Change Dump) traces and debugging pipeline stalls/flushes.
* **Compiler Chain:** `riscv64-unknown-elf-gcc` for compiling bare-metal C and Assembly test vectors.
* **Harness:** Efabless Caravel Management SoC Testbench architecture.

### Simulation Phases
1. **Standalone RTL Simulation:** Verifying the core logic in isolation using behavioral memory models.
2. **Integration RTL Simulation:** Simulating the core embedded inside the Caravel wrapper, validating the Wishbone interconnect and Padframe GPIO routing.
3. **Gate-Level Simulation (GLS):** Simulating the synthesized netlist with Standard Delay Format (SDF) back-annotation to ensure the physical logic gates meet timing constraints.

---

## 2. Testbench Architecture

The project relies on three primary testbenches, each targeting a specific layer of the architectural stack.

### 2.1 Core-Level Unit Test (`tb_rv32i_top.v`)
**Location:** `/verilog/dv/tb_rv32i_top.v`

This is a lightweight, high-speed testbench designed to test the microarchitecture in isolation.
* **Harness:** Instantiates `rv32i_top` directly.
* **Memory:** Uses a simulated behavioral SRAM block instead of the physical OpenRAM macros.
* **Purpose:** Validates internal pipeline forwarding, hazard detection, and basic ALU execution without the overhead of the Caravel Management SoC.
* **Validation:** Fails the simulation if the core asserts an invalid memory address or executes an illegal instruction.

### 2.2 Caravel SoC Integration Test (`rv32i_integration`)
**Location:** `/caravel_user_project/verilog/dv/rv32i_integration/`

This is the most critical testbench. It simulates the *entire* physical chip exactly as it will behave when manufactured.
* **Harness:** Instantiates the full Caravel SoC, including the Management CPU, SPI Flash, Padframe, and our `user_project_wrapper`.
* **Execution Flow:**
  1. The simulation begins with the Caravel Management SoC booting from an emulated SPI Flash.
  2. The Management SoC configures the GPIO pad routing.
  3. The Management SoC releases the reset line (`wb_rst_i = 0`) to our user wrapper.
  4. Our RV32I core wakes up and begins fetching instructions from the internal 2KB SRAM macros over the Wishbone bus.
* **Validation:** The test program running on our core writes a specific "Magic Number" (e.g., `0xAB45`) to the Caravel Logic Analyzer (LA) probes. The Verilog testbench continuously monitors the LA probes and prints `SUCCESS` when the correct hex value is detected.

### 2.3 RISC-V ISA Compliance Suite (`compliance`)
**Location:** `/caravel_user_project/verilog/dv/compliance/`

To guarantee that our Instruction Set Architecture (ISA) decoder is flawless, the core is tested against standardized RISC-V compliance vectors.
* **Purpose:** Runs thousands of edge-case instruction combinations (e.g., adding negative immediates, extreme shift amounts, unaligned jumps).
* **Validation:** Ensures the final state of the Register File exactly matches the official RISC-V foundation golden reference models.

---

## 3. What We Tested (Test Coverage)

The test vectors (written in C and Assembly) comprehensively exercise the following hardware features:

### 3.1 Arithmetic & Logic Unit (ALU)
* Validated `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLL` (Shift Left), `SRL` (Shift Right Logical), and `SRA` (Shift Right Arithmetic).
* Tested with maximum 32-bit values, negative two's complement numbers, and zero-value bypasses.

### 3.2 Pipeline Hazard & Dependency Resolution
Because this is a pipelined processor, instructions execute simultaneously. We specifically tested data hazards:
* **EX-to-EX Forwarding:** E.g., `ADD x1, x2, x3` immediately followed by `SUB x4, x1, x5`. The ALU output is forwarded directly to the next instruction without waiting for the Writeback stage.
* **MEM-to-EX Forwarding:** Bypassing data loaded from memory directly into the ALU.
* **Load-Use Stalls:** E.g., `LW x1, 0(x2)` followed by `ADD x3, x1, x4`. The Hazard Unit correctly freezes the Fetch and Decode stages for 1 cycle to allow the memory read to complete.

### 3.3 Control Flow & Branch Prediction
* **Branch Execution:** `BEQ`, `BNE`, `BLT`, `BGE`. Tested edge cases where branches are taken and untaken.
* **Pipeline Flushing:** Verified that when a branch is taken, the Hazard Unit successfully flushes (inserts NOPs into) the instructions erroneously loaded in the Fetch and Decode stages.
* **Jumps:** `JAL` (Jump and Link) and `JALR` (Jump and Link Register), ensuring the return address is correctly written to the link register.

### 3.4 Memory Subsystem (Wishbone Bus)
* **Handshake Protocol:** Verified that `wbs_cyc_i` and `wbs_stb_i` are successfully driven by the core, and the core gracefully stalls the pipeline until `wbs_ack_o` is received from the SRAM.
* **Load/Store Alignment:** Verified `LW` (Load Word) and `SW` (Store Word) across word-aligned boundaries.

### 3.5 System Boot & Reset Sequences
* Verified that when the Caravel SoC holds the reset line high (`wb_rst_i = 1`), the core flushes all pipeline registers, zeroes the Program Counter, and ignores all Wishbone memory requests.

---

## 4. Final Tapeout Sign-off

The core successfully passed all phases of verification:
1. **[PASS]** Functional RTL Simulation (Zero `X` states during execution).
2. **[PASS]** Gate-Level Simulation (Zero timing violations under Slow/Fast physical corners).
3. **[PASS]** Caravel Integration (Successfully communicated with Management SoC and external pins).

With this rigorous methodology complete, the architecture was certified ready for physical GDSII layout and silicon manufacturing.
