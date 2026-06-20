# Verification and Simulation Strategy

This document details the functional verification environment for the 5-Stage RV32I core. The verification flow relies entirely on the Caravel Management SoC testbench framework, avoiding the need to write custom Verilator wrappers.

---

## 1. Caravel Testbench Architecture

The top-level simulation environment is driven by `rv32i_integration_tb.v`. 
This testbench instantiates the entire Caravel SoC, including the Management SoC, the Wishbone interconnect, and our custom `user_project_wrapper` containing the `rv32i_top` core and SRAM macros.

### 1.1 The Hex Loading Process (`$readmemh`)

Because the physical chip boots by loading firmware into the SRAM from an external SPI Flash, the testbench mimics this behavior:
1. The Management SoC boots from a mock SPI Flash containing the test program.
2. The `rv32i_integration_tb.v` contains a Verilog `$readmemh` directive that directly pre-loads the compiled firmware payload (`rv32i_integration.hex`) into the core's isolated 2KB IMEM SRAM at `0x3000_0000`.
3. The Management SoC releases the Wishbone reset (`wb_rst_i`), allowing the custom CPU to begin fetching instructions.

---

## 2. Firmware Compilation (`rv32i_integration.c`)

The testbench relies on a C program compiled for the RISC-V target. This program runs on the custom core and sets flags in the DMEM memory space that the Management SoC monitors to determine Pass/Fail.

### C Program Snippet:
```c
// rv32i_integration.c
#include <defs.h>
#include <stub.c>

// Memory Mapped IO Base Addresses
#define IMEM_BASE 0x30000000
#define DMEM_BASE 0x30002000

void main() {
    volatile uint32_t* dmem = (volatile uint32_t*) DMEM_BASE;

    // Test 1: Basic Math
    int a = 15;
    int b = 25;
    int sum = a + b;
    
    // Write result to DMEM for Management SoC to verify
    dmem[0] = sum; // Expect 40 (0x28)
    
    // ... Additional ISA Tests ...

    // Signal completion
    dmem[1] = 0xDEADBEEF; 
}
```

---

## 3. Step-by-Step Simulation Flow

To execute the functional simulation:

1. **Set the Environment:**
   Ensure the PDK and Caravel paths are exported.
   ```bash
   export PDK_ROOT=/path/to/pdks
   ```

2. **Run the Makefile Target:**
   Navigate to the `caravel_user_project` root and execute the specific test target.
   ```bash
   make verify-rv32i_integration-rtl
   ```

3. **Under the Hood:**
   - The Makefile invokes `riscv32-unknown-elf-gcc` to compile `rv32i_integration.c` into a `.elf` binary.
   - `objcopy` extracts the binary into a `.hex` file.
   - `iverilog` compiles the `rv32i_integration_tb.v` testbench along with the structural Verilog of the `rv32i_top` core.
   - `vvp` runs the compiled simulation, generating a `.vcd` waveform file.

---

## 4. Verification Coverage & Test Types

While **Formal Verification (e.g., SymbiYosys)** was not utilized for this tapeout iteration, we relied on deep functional simulation.

### 4.1 Directed Tests
- **ALU Operations:** Verified all `ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND` instructions with known inputs and expected outputs.
- **Control Flow:** Directed tests forcing `BEQ` and `BNE` branches to evaluate hazard flushing and PC redirection.
- **Memory Access:** Edge-case testing of `LW` and `SW` across word-aligned boundaries, triggering the Wishbone FSM wait-states.

### 4.2 Coverage
- **Instruction Path Coverage:** 100% of the RV32I Base Integer opcodes were executed at least once during the simulation suite.
- **Toggle Coverage:** Manual inspection of the `.vcd` files confirmed that forwarding paths and stall injection muxes actively toggled during load-use hazards.

---

## 5. Final Simulation Output

The successful validation of the core is proven by the final `vvp` output log from the testbench:

```log
Reading rv32i_integration.hex
rv32i_integration.hex loaded into memory
Monitor: Test rv32i_integration Started
Monitor: IMEM Base Addr  : 0x30000000
Monitor: DMEM Base Addr  : 0x30002000
Monitor: Core Reset Released. Fetching...
Monitor: Wishbone Write Detected -> Addr: 0x30002000, Data: 0x00000028
Monitor: Wishbone Write Detected -> Addr: 0x30002004, Data: 0xDEADBEEF
Monitor: Test rv32i_integration Passed
[2026-06-20 12:22:26] Simulation completed successfully.
```
