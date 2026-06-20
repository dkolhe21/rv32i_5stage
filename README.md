# 5-Stage RV32I CPU for Caravel

Welcome to the central repository for the custom 5-Stage RV32I Processor. This repository contains the RTL, physical layout, and comprehensive documentation for integrating a pipelined RISC-V soft core into the Efabless Caravel SoC using the Sky130 PDK.

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

## Quick Start
To immediately run the functional RTL simulation and verify that the core executes instructions over the Wishbone bus:
```bash
cd caravel_user_project
make verify-rv32i_integration-rtl PDK_ROOT=/path/to/pdks
```

## Documentation Directory

The project is thoroughly documented. Please refer to the `docs/` folder for all engineering manuals:

- 📖 **[Hardware Specification (spec.md)](./docs/spec.md)** - ISA, frequencies, power, and memory maps.
- 🚀 **[Project Report (project_report.md)](./docs/project_report.md)** - Deep architectural explanations and tapeout summary.
- 🔌 **[Interface Definition (interface.md)](./docs/interface.md)** - Wishbone timing diagrams and pinouts.
- 🛠️ **[Commands Reference (commands_reference.md)](./docs/commands_reference.md)** - OpenLane and Precheck docker commands.
- 🧪 **[Simulation Setup (verification.md)](./docs/verification.md)** - Testbench architectures and coverage metrics.
- 🐛 **[Errors & Resolutions (errors_and_resolutions.md)](./docs/errors_and_resolutions.md)** - The full problem log and how routing DRCs were solved.
- 📜 **[Coding Rules (coding_rules.md)](./docs/coding_rules.md)** - SystemVerilog conventions for synthesis.
- 📅 **[Timeline (timeline.md)](./docs/timeline.md)** - Tapeout milestones.
- 📖 **[Glossary (glossary.md)](./docs/glossary.md)** - VLSI terminology definitions.
