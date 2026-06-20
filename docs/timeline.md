# Project Timeline and Milestones

This document logs the major milestones achieved during the lifecycle of the 5-Stage RV32I tape-out project.

| Date | Phase | Milestone | Description |
|------|-------|-----------|-------------|
| **2026-06-01** | Architecture | Pipeline Complete | The 5-stage hazard-resistant pipeline architecture was finalized. Load-use stalling and data forwarding paths were successfully implemented. |
| **2026-06-05** | Architecture | Wishbone FSM Complete | The `wbs_ack_o` wait-state FSM was integrated, allowing the core to securely access external memory across the Wishbone interconnect. |
| **2026-06-10** | RTL Signoff | Verilog Translation | Migrated the pure SystemVerilog codebase to standard Verilog-2001 using `sv2v` to satisfy OpenLane/Yosys synthesis compatibility requirements. |
| **2026-06-12** | Verification | First Simulation Pass | The `iverilog` testbench successfully compiled the C-firmware, pushed it into the IMEM, and the core executed it flawlessly, setting the success flag in DMEM. |
| **2026-06-16** | Physical | Macro Clean (`rv32i_top`) | The core logic block successfully navigated the OpenLane digital flow, passing STA (102.2 MHz typical), DRC, and LVS. |
| **2026-06-18** | Physical | SRAM Integration Clean | Resolved catastrophic `met3` routing congestion by explicitly floorplanning the SRAMs to `X=400` and deploying a custom LEF obstruction patch. |
| **2026-06-19** | Physical | Wrapper Clean | The `user_project_wrapper` successfully routed all Wishbone IO to the Caravel pads, resolving all Antenna violations. |
| **2026-06-20** | Signoff | **MPW Precheck Pass** | The unified GDSII passed the rigorous Efabless precheck pipeline with 0 errors, validating the design for foundry manufacturing. |
