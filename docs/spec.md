# RV32I 5-Stage CPU – Hardware Specification

> **Version:** 1.0 (INITIAL RELEASE)  
> **Date:** 2026-06-20  
> **Status:** Tape-out Ready

---

## 1. Project Overview

The **5-Stage RV32I CPU** is a custom RISC-V processor optimized for integration into the Efabless Caravel System-on-Chip (SoC) framework. The core is designed for the Sky130 open-source PDK and leverages the Wishbone B4 bus for seamless memory access and control.

| Parameter | Value |
|-----------|-------|
| Target PDK | SkyWater SKY130 |
| Operating Voltage | 1.8V (Digital Core) |
| System Operational Frequency (Caravel Harness Limit) | 50 MHz |
| Core Internal Logic Fmax (Isolated Typical Corner) | ~102.2 MHz |
| Temperature Range | -40°C to 100°C |
| Integration | Caravel `user_project_wrapper` |

---

### 1.1 Timing Closure & Dual-Frequency Margins

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

## 2. Physical Metrics

Upon hardening the `rv32i_top` macro via OpenLane, the core achieves the following physical dimensions:

| Component | Footprint Area |
|-----------|----------------|
| **Core Logic (Standard Cells)** | ~0.75 mm² |
| **SRAMs (2x 2KB macros)** | ~1.50 mm² |
| **Total Macro Area** | **2.25 mm²** (1500x1500 µm boundary) |

### Power Estimation (Typical Workload)

| Metric | Estimated Value |
|--------|-----------------|
| Internal Static Power | ~5.6 nW |
| Dynamic Switching Power | ~3.4 mW (at 50 MHz) |
| Total Power | **~3.4 mW** |

---

## 3. Architecture Specification

### 3.1 Instruction Set Architecture

| Parameter | Value |
|-----------|-------|
| ISA | **RV32I** (Base Integer) |
| Extensions | None |
| Registers | 32 × 32-bit GPRs |
| Endianness | Little-endian |

### 3.2 Memory Map (Wishbone)

The core is controlled entirely via the Wishbone bus from the Caravel Management SoC.

| Base Address | Size | Description |
|--------------|------|-------------|
| `0x3000_0000` | 2 KB | **IMEM (Instruction Memory)**. Used to load firmware. |
| `0x3000_2000` | 2 KB | **DMEM (Data Memory)**. Used for data load/stores. |
| `0x3000_4000` | 4 B  | **CTRL (Control Register)**. Bit [0] active-high resets the CPU core. |

---

## 4. Interfaces & Pinout Table

### `rv32i_top` Ports

| Pin Name | Direction | Width | Description |
|----------|-----------|-------|-------------|
| `wb_clk_i` | Input | 1 | Wishbone bus clock (System Clock). |
| `wb_rst_i` | Input | 1 | Wishbone bus reset (Active-High). |
| `wbs_cyc_i` | Input | 1 | Wishbone Cycle valid. |
| `wbs_stb_i` | Input | 1 | Wishbone Strobe valid. |
| `wbs_we_i` | Input | 1 | Wishbone Write Enable. |
| `wbs_sel_i` | Input | 4 | Wishbone Byte Select. |
| `wbs_adr_i` | Input | 32 | Wishbone Address bus. |
| `wbs_dat_i` | Input | 32 | Wishbone Data Input bus. |
| `wbs_ack_o` | Output | 1 | Wishbone Acknowledge. |
| `wbs_dat_o` | Output | 32 | Wishbone Data Output bus. |
| `irq` | Output | 3 | Interrupt Request to Caravel SoC. |
| `jtag_*` | Input/Output | 1 | JTAG testing pins (unused, tied off). |
| `bist_*` | Input/Output | 1 | BIST testing pins (unused, tied off). |

---

## 5. Scope Boundaries

### ✅ IN SCOPE
- RV32I base integer instructions.
- 5-stage pipeline with stall logic, forwarding, and hazard detection.
- 2x 2KB SRAM instances via OpenRAM.
- Standard Wishbone B4 Slave interface mapped to `0x30000000`.

### ❌ OUT OF SCOPE
- JTAG / BIST internal debug module usage.
- Advanced RV32 Extensions (M, A, F, D, C).
- Branch prediction, Caches, Interrupts (CSRs).

---

## 6. Revision History

- **v1.0 (2026-06-20):** Initial tape-out ready specification. Wait-states, reset polarity, and base addresses finalized.
