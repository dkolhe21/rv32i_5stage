# Glossary of Terms

This document defines the acronyms and specialized terminology used throughout the project documentation, particularly concerning the Sky130 PDK and OpenLane digital flow.

## VLSI & Physical Design

- **GDS / GDSII (Graphic Design System):** The industry-standard binary file format representing planar geometric shapes, text labels, and other information about layout in hierarchical form. It is the final file sent to the foundry for manufacturing.
- **LEF (Library Exchange Format):** An ASCII data format used to describe the physical attributes of a standard cell or macro (like our SRAM). It contains bounding boxes, pin locations, and routing obstructions, but *not* the internal logic.
- **DEF (Design Exchange Format):** An ASCII data format representing the physical layout of an IC in an EDA tool. It contains the exact placement locations of all cells and the routing of all wires.
- **DRC (Design Rule Check):** A verification step that ensures the physical layout satisfies all the manufacturing constraints of the foundry (e.g., minimum wire width, minimum spacing between metal layers).
- **LVS (Layout Versus Schematic):** A verification step that compares the extracted netlist from the physical layout (GDS) against the original synthesized gate-level netlist to ensure they match exactly.
- **STA (Static Timing Analysis):** A method of computing the expected timing of a digital circuit without requiring simulation. It checks for Setup and Hold violations across all logic paths.
- **WNS (Worst Negative Slack):** A timing metric. Positive slack means the chip meets timing requirements; negative slack means it fails.
- **PDK (Process Design Kit):** A set of files provided by a semiconductor foundry (e.g., SkyWater) used by EDA tools to design an IC for a specific manufacturing process.
- **OBS (Obstruction):** In a LEF file, an OBS layer tells the automated router that it cannot place any wires in that specific area on that specific metal layer.

## Architecture & Integration

- **SoC (System on a Chip):** An integrated circuit that integrates all or most components of a computer or other electronic system. (e.g., the Caravel Harness).
- **Wishbone (WB):** An open-source hardware computer bus designed to let the parts of an integrated circuit communicate with each other. It is used in Caravel to connect the Management SoC to our user project.
- **BIST (Built-In Self-Test):** A mechanism that permits a machine to test itself. Often used for SRAM memory validation.
- **JTAG (Joint Test Action Group):** An industry standard for verifying designs and testing printed circuit boards after manufacture.

## Tools

- **OpenLane:** An automated RTL to GDSII flow based on several components including OpenROAD, Yosys, Magic, Netgen, and custom methodology scripts.
- **Yosys:** A framework for Verilog RTL synthesis.
- **OpenROAD:** An automated physical design tool (floorplanning, placement, CTS, routing).
- **Magic:** An open-source VLSI layout tool used primarily for DRC checking and GDSII streaming.
- **Netgen:** A tool for comparing netlists (LVS).
- **Iverilog (Icarus Verilog):** A Verilog simulation and synthesis tool.
