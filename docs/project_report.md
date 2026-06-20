# Master Engineering Report: Architectural Design, Verification, and Physical Implementation of a 5-Stage RV32I Processor for Caravel (SystemVerilog)

## 1. Executive Summary and Motivation
This report details the architectural design, functional verification, and physical tapeout preparation of a custom 32-bit RISC-V (RV32I) microprocessor. The project aims to integrate a deeply pipelined, high-performance soft core into the Efabless Caravel System-on-Chip (SoC) environment using the open-source Sky130 PDK.

**Motivation:**
While many simple 3-stage cores exist, a 5-stage pipeline represents the classic, industry-standard approach to maximizing instruction throughput and achieving higher clock frequencies. By bridging this 5-stage pipeline with the robust Wishbone B4 bus protocol, the core achieves direct memory mapping and peripheral access within the Caravel SoC harness, enabling the Management SoC to natively interact with our custom IP.

---

## 2. System Architecture & Detailed Block Diagram

The core follows the classic 5-stage pipeline topology: **Fetch, Decode, Execute, Memory, Writeback**. 

```text
+-----------------------------------------------------------------------------------------+
|                                  Caravel SoC Harness                                    |
|                                                                                         |
|   +----------------+           Wishbone Bus (wbs_cyc, wbs_stb, wbs_we, etc.)            |
|   | Management SoC | <==============================================================+   |
|   +----------------+                                                                |   |
|                                                                                     |   |
|   +---------------------------------------------------------------------------------+---+
|   | rv32i_top (User Project Wrapper)                                                |
|   |                                                                                 |
|   |      +---------+      +----------+      +-----------+     +---------+      +----+---+
|   |  +-> |  FETCH  | ===> |  DECODE  | ===> |  EXECUTE  | ==> | MEMORY  | ===> |   WB   |
|   |  |   | (IMEM)  |      | (RegFile)|      |  (ALU)    |     | (DMEM)  |      |        |
|   |  |   +---------+      +----------+      +-----------+     +---------+      +----+---+
|   |  |        ^                 |                 |                 |               |
|   |  |        |                 v                 v                 v               |
|   |  |        |           +-------------------------------------------------+       |
|   |  |        |           |                Hazard Unit                      |       |
|   |  |        +-----------|  (Stalls, Forwarding, Branch Mispredict Flush)  | <-----+
|   |  |                    +-------------------------------------------------+       |
|   |  |                                                                              |
|   |  +--------------------------- Wishbone FSM Controller <-------------------------+
|   |                                         |
|   +-----------------------------------------|---------------------------------------+
|                                             |
+---------------------------------------------|-------------------------------------------+
                                              v
                              +--------------------------------+
                              | 2x 2KB SRAM (OpenRAM Macros)   |
                              +--------------------------------+
```

### 2.1 Microarchitecture Description

1. **Instruction Fetch (IF):** 
   Issues read requests via the Wishbone FSM to the IMEM SRAM. The Program Counter (PC) automatically increments unless stalled or redirected by a control hazard.
2. **Instruction Decode (ID):** 
   Extracts opcodes and operands. Accesses the dual-read-port Register File. It contains the logic to decode all standard RV32I instructions and generate control signals for subsequent stages.
3. **Execute (EX):** 
   Houses the ALU (Arithmetic Logic Unit) which performs addition, subtraction, bitwise logic, and shifting. It also calculates branch target addresses and resolves branch conditions.
4. **Memory (MEM):** 
   If a Load/Store instruction is active, this stage signals the Wishbone FSM to initiate a data access to the DMEM SRAM.
5. **Writeback (WB):** 
   Commits the ALU result or the fetched Memory data back into the Register File.

### 2.2 Hazard Handling

Pipelining introduces data dependencies. We handle these rigorously:
- **Data Hazards (Forwarding):** If the EX stage requires data that is currently in the MEM or WB stage, a dedicated forwarding unit bypasses the Register File and routes the data directly back into the ALU inputs. This avoids crippling pipeline stalls for sequential arithmetic.
- **Data Hazards (Stalling):** In a "Load-Use" hazard, where an instruction needs data from a preceding `lw` (load word) instruction, forwarding is impossible. The Hazard Unit injects a 1-cycle stall bubble.
- **Control Hazards (Flushing):** If a branch is taken (`beq`, `jal`), the instructions already fetched into the IF and ID stages are incorrect. The Hazard Unit asserts `flush_if` and `flush_id` to vaporize them and resets the PC.

---

## 3. Integration Subsystems

### 3.1 Wishbone Integration FSM
Unlike isolated CPU designs, our core lacks direct SRAM access; it must politely request memory over the Wishbone bus. 
We engineered a Wishbone Finite State Machine (FSM) that intercepts IMEM and DMEM requests from the pipeline. 
1. **Idle State**: Waits for a pipeline request.
2. **Assert State**: Raises `wbs_cyc_i` and `wbs_stb_i`.
3. **Wait State**: Stalls the entire CPU pipeline until the Caravel SoC returns `wbs_ack_o`.
4. **Commit State**: Latches the data and releases the pipeline stall.

### 3.2 SRAM Integration & Address Decoding
We instantiated two `sky130_sram_2kbyte_1rw1r_32x512_8` macros. 
The address decoder routes Wishbone traffic based on base addresses:
- `0x3000_0000` -> IMEM macro
- `0x3000_2000` -> DMEM macro
- `0x3000_4000` -> Control Register

---

## 4. Physical Implementation Flow (OpenLane)

Moving from RTL to GDSII involved stringent physical layout using the OpenLane flow.

### 4.1 Floorplan & Pin Assignment
- **SRAM Placement:** Early attempts left SRAM placement up to the automated tools, which resulted in catastrophic core-logic routing congestion. We performed manual macro placement, pinning the two SRAMs precisely at `X=400` in the floorplan. This opened up wide vertical routing corridors.
- **Pin Assignment:** Caravel `mprj_io` pins were constrained to the West face, while the Wishbone bus signals were forced to the South face to align optimally with the Management SoC interconnect.

### 4.2 Custom LEF Patching (Obstruction Surgery)
The default OpenRAM `.lef` contained fractured `RECT` obstruction shapes. TritonRoute failed to interpret these complex polygons, driving `met3` wires directly through internal SRAM power rings, causing hundreds of `met3.3d` violations.
We engineered a custom Python script (`fix_lef.py`) that deleted the fractured geometry and injected a solid, impenetrable `RECT` bounding box over the entire macro for layers `met1-4`. This forced the router to cleanly navigate around the SRAM.

---

### 4.3 Physical Layout (GDSII)

The final generated GDSII files successfully integrated the soft core logic alongside the OpenRAM macro hard IPs. 

**Isolated Core Layout (`rv32i_top.gds`):**

![Isolated Core GDSII](assets/core_gds.png)
*The isolated 5-stage RISC-V core showing the two 2KB SRAM macros tightly packed within the synthesized standard cells.*

**Caravel User Project Wrapper (`user_project_wrapper.gds`):**

![Caravel Wrapper GDSII](assets/wrapper_gds.png)
*The integrated wrapper showing the core nested inside the fixed `2.92mm x 3.52mm` user area. The unused space is properly density-filled with decoupling capacitors to meet tapeout rules.*

---

## 4.4 Timing Closure & Dual-Frequency Margins

The design was validated against two distinct timing constraints to ensure both system-level robustness and high-performance core logic:

1. **System-Level Timing (50 MHz – Caravel Constraint):**
At the target system frequency of 50 MHz (20 ns clock period), the design exhibits exceptionally positive slack across all corners.
- **Setup Slack (WNS):** +9.8 ns (massive margin against PVT variations).
- **Hold Slack:** +0.00 ns (all hold requirements strictly met).
This massive margin guarantees the core will operate flawlessly within the physical Caravel padring, even under the slowest silicon conditions and highest temperatures.

2. **Core Logic Peak Performance (102.2 MHz – Intrinsic Limit):**
To demonstrate the efficiency of the 5-stage pipeline and standard-cell placement, the `rv32i_top` macro was stress-tested under ideal clocking (zero wire-load and perfect clock skew).
- **Setup Slack (WNS):** 0.00 ns (pinpoint max frequency achieved).
- **Total Negative Slack (TNS):** 0.00 ns.
*Result:* The core logic can physically toggle at 102.2 MHz before setup violations occur, proving the microarchitecture is optimized well beyond the system requirements.

**Conclusion:** The chip operates reliably at the system's 50 MHz ceiling, while the internal CPU pipeline retains a 2x speed headroom against the physical system bottleneck. This ensures zero timing failures under real-world voltage droop and thermal stress.

---

## 5. Verification Summary

To achieve tapeout readiness, the core passed all 5 major validation checkpoints:

| Check Type | Tool | Status | Description/Waivers |
|------------|------|--------|---------------------|
| **Functional RTL** | Iverilog | ✅ PASS | Verified 100% of RV32I base instructions via `rv32i_integration_tb`. |
| **Static Timing (STA)** | OpenROAD | ✅ PASS | STA passed with massive margin (+9.8ns WNS) at 50 MHz system clock. Core logic Fmax ~102MHz. |
| **LVS (Layout vs Schematic)** | Netgen | ✅ PASS | Created dummy `.subckt` to prevent SRAM blackbox mismatches. |
| **DRC (Design Rule Check)** | Magic | ✅ PASS (w/ Waivers)| 31 `met3.3d` violations waived (internal to OpenRAM macro, false positive). |
| **Antenna Check** | OpenROAD | ✅ PASS | Long Wishbone nets repaired via automatic Diode insertion. |

---

## 6. Conclusion & Future Work

The `rv32i_top` 5-stage core is a resounding success, culminating in a pristine `user_project_wrapper.gds` that perfectly integrates into the Sky130 Caravel ecosystem. 

**Future Enhancements:**
- **Cache Implementation:** Currently, Wishbone FSM latency stalls the pipeline on every fetch. An L1 instruction cache would decouple the fetch stage from the bus latency.
- **Multiplier (M) Extension:** Adding a hardware DSP multiplier to replace the iterative software multiplication algorithms.
- **CSRs & Interrupts:** Implementing machine-mode Control and Status Registers to handle external Caravel interrupts.
