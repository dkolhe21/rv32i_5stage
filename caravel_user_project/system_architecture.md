# System Architecture: RV32I 5-Stage Pipelined CPU

## Overview
The `rv32i_top` macro implements a classic 5-stage pipelined RISC-V RV32I architecture, wrapped and integrated within the Efabless Caravel management SoC framework. 

## Core Pipeline Stages
1. **Instruction Fetch (IF)**: Fetches the 32-bit instruction from the Instruction Memory (SRAM).
2. **Instruction Decode (ID)**: Decodes the RV32I opcode, fetches operand values from the register file, and generates control signals.
3. **Execute (EX)**: Performs arithmetic and logical operations via the ALU. Evaluates branch conditions.
4. **Memory (MEM)**: Interfaces with the Data Memory (SRAM) for `load` and `store` instructions.
5. **Writeback (WB)**: Writes the result back to the destination register in the register file.

## Memory Architecture
The design utilizes two discrete 2KByte SRAM macros (`sky130_sram_2kbyte_1rw1r_32x512_8`):
- **Instruction Memory (`u_imem_sram`)**: Used exclusively for holding executable code.
- **Data Memory (`u_dmem_sram`)**: Used for data storage.
Both memories are tightly coupled to the pipeline, providing single-cycle access necessary to maintain a high IPC (Instructions Per Cycle).

## Caravel Integration
The CPU is instantiated inside `user_project_wrapper` and interfaces with the Caravel SoC via:
- **Wishbone Bus**: Allows the Caravel management SoC to read and write to the core's internal registers or memory.
- **Logic Analyzer (LA)**: 128 probe pins connected for observing internal pipeline states and debugging.
- **GPIO**: 38 general-purpose I/O pins available for external signaling.

## Physical Design Architecture
- **Technology**: SkyWater 130nm (`sky130A`) Open Source PDK.
- **Standard Cells**: High-Density (`sky130_fd_sc_hd`) standard cell library.
- **Floorplan**: The macro has a strict core utilization requirement, with the dual SRAMs manually placed at `X=75` to perfectly balance routing channels on the left and right sides to avoid wide-metal `met3.3d` spacing violations.
