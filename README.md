# 5-Stage RV32I CPU for Caravel

Welcome to the central repository for the custom 5-Stage RV32I Processor. This repository contains the RTL, physical layout, and comprehensive documentation for integrating a pipelined RISC-V soft core into the Efabless Caravel SoC using the Sky130 PDK.

```mermaid
%%{init: { 'theme': 'dark', 'themeVariables': { 'primaryColor': '#1a1a2e', 'primaryTextColor': '#e0e0e0', 'primaryBorderColor': '#4a90e2', 'lineColor': '#a0a0a0', 'secondaryColor': '#16213e', 'tertiaryColor': '#0f3460' } } }%%
flowchart TB
    subgraph Caravel["Caravel SoC Harness"]
        MgmtSoC["Management SoC"]
        
        subgraph Wrapper["rv32i_top (User Project Wrapper)"]
            direction LR
            subgraph Pipeline["5-Stage Pipeline"]
                direction LR
                IF["IF (IMEM)"] --> ID["ID (RegFile)"] --> EX["EX (ALU)"] --> MEM["MEM (DMEM)"] --> WB["WB"]
            end
            
            Hazard["Hazard Unit<br>(Stall/Forward/Flush)"]
            WbFSM["Wishbone FSM Controller"]
            
            %% Control & Data Flow inside Wrapper
            Hazard -->|Flush| IF
            EX -.->|Forward| Hazard
            WB -.->|Forward| Hazard
            IF -->|Fetch| WbFSM
            MEM -->|Data| WbFSM
            
            SRAM["2x 2KB SRAM<br>(OpenRAM Macros)"]
            WbFSM <-->|Address / Data| SRAM
        end

        %% External Connections
        MgmtSoC <==>|Wishbone Bus| WbFSM
    end

    %% Colour Definitions (Dark Mode Optimized)
    classDef mgmt fill:#ff8f00,color:#000,stroke:#fff;
    classDef pipe fill:#0d47a1,color:#fff,stroke:#42a5f5;
    classDef hazard fill:#b71c1c,color:#fff,stroke:#ef5350;
    classDef sram fill:#4a148c,color:#fff,stroke:#ab47bc;
    classDef fsm fill:#004d40,color:#fff,stroke:#26a69a;
    classDef harness fill:#1e1e1e,color:#fff,stroke:#4a90e2,stroke-width:2px;
    classDef wrapper fill:#0d2b45,color:#fff,stroke:#00bcd4,stroke-width:2px;

    class MgmtSoC mgmt;
    class IF,ID,EX,MEM,WB pipe;
    class Hazard hazard;
    class SRAM sram;
    class WbFSM fsm;
    class Caravel harness;
    class Wrapper wrapper;
```

## Physical Layout (GDSII)

**Isolated Core Layout (`rv32i_top.gds`):**

![Isolated Core GDSII](docs/assets/core_gds.png)
*The isolated 5-stage RISC-V core showing the two 2KB SRAM macros tightly packed within the synthesized standard cells.*

**Caravel User Project Wrapper (`user_project_wrapper.gds`):**

![Caravel Wrapper GDSII](docs/assets/wrapper_gds.png)
*The integrated wrapper showing the core nested inside the fixed `2.92mm x 3.52mm` user area. The unused space is properly density-filled with decoupling capacitors to meet tapeout rules.*

---

## RTL Simulation Execution

![Caravel Integration Waveforms](docs/assets/waveform.png)
*GTKWave trace showing the RV32I pipeline actively fetching, decoding, and executing instructions, interacting flawlessly with the Wishbone Memory bus.*

---
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
