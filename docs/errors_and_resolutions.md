# Errors and Resolutions Log

This document tracks all significant roadblocks encountered across the RTL design, synthesis, routing, and tape-out signoff phases. For each issue, the root cause, solution, and validation mechanism are documented to ensure reproducibility and provide a learning reference for future tapeouts.

---

## 1. RTL Phase

### [2026-06-01 10:15:00] Missing `rv32i_top` Module in Wrapper
- **Cause:** The `rv32i_top` was declared in Verilog, but not properly instantiated within the `user_project_wrapper` template.
- **Solution:** Added the instantiation template linking the Wishbone interface signals to the wrapper's bus ports.
- **Verification:** `iverilog` elaboration passed successfully.

### [2026-06-15 16:12:05] `rst_n` Polarity Mismatch
- **Cause:** The `rv32i_top` macro was designed with an active-low reset `rst_n`. The Caravel wrapper provides an active-high reset `wb_rst_i`. When tied directly, the CPU remained permanently locked in the reset state.
- **Solution:** Handled the polarity inversion internally within the RTL of `rv32i_top` rather than inserting a `sky130_fd_sc_hd__inv` logic cell inside the wrapper, which violated OpenLane wrapper routing constraints.
- **Verification:** Simulated waveform showed CPU successfully leaving reset state at `t=200ns`.

### [2026-06-16 09:20:44] Wishbone `wbs_ack_o` Stuck High
- **Cause:** The Wishbone FSM did not de-assert the acknowledge signal when returning to the `IDLE` state, causing consecutive memory operations to collide and corrupt data.
- **Solution:** Fixed the combinatorial output logic in the FSM to ensure `wbs_ack_o` is strictly bound to `1'b0` during `IDLE` and only asserted `1'b1` during a valid `COMMIT` state.
- **Verification:** Unit tests for sequential Load/Store instructions passed.

---

## 2. Synthesis & Simulation Phase

### [2026-06-10 09:45:11] `iverilog` Bus Explosion Errors
- **Cause:** Attempted to use multidimensional arrays and complex SV `interface` structs for bus connectivity across modules. `iverilog` (and later Yosys) failed to resolve the array boundaries during elaboration.
- **Solution:** Reverted to standard flat Verilog-2001 bus connections (`wire [31:0]`). Used the `sv2v` translator tool to flatten remaining SystemVerilog structs.
- **Verification:** `make verify-rv32i_integration-rtl` compiled without syntax or bounding errors.

### [2026-06-16 14:00:00] Address Decoder Mismatch
- **Cause:** Hardcoded the instruction fetch base address to `0x00000000` in the RTL, but the Caravel Management SoC maps the user project Wishbone space starting at `0x30000000`. The core was receiving `wbs_cyc_i` requests but ignoring them because the address didn't match.
- **Solution:** Corrected the base address decoding logic in `rv32i_top`: 
  ```verilog
  assign imem_en = (wbs_adr_i[31:16] == 16'h3000);
  ```
- **Verification:** Wishbone read requests correctly returned the first instruction of the compiled firmware.

---

## 3. Physical Implementation Phase

### [2026-06-18 16:45:10] LEF Obstruction Fracture Causing `met3.3d` Violations
- **Cause:** The provided OpenRAM `.lef` contained highly fractured `RECT` blocks for internal layer obstructions. TritonRoute failed to interpret these properly and routed signal wires straight through internal SRAM power rings.
- **Solution:** Patched the LEF using a custom Python script (`fix_lef.py`) that replaced the fractured obstructions with solid, singular `RECT` boundaries for `met1` through `met4`.
- **Verification:** Detailed routing completed with 0 DRC violations around the SRAM.

### [2026-06-18 14:15:22] `GRT_OBS` Layer-Hopping Cascade
- **Cause:** Attempted to fix the above SRAM routing issue using `GRT_OBS` in the `config.tcl`. This forced TritonRoute to violently jump from `met3` down to `met2` and up to `met4`, creating a cascade of spacing DRCs.
- **Solution:** Abandoned `GRT_OBS` layer restrictions entirely. Settled on moving the SRAM macro physically to `X=400` in the floorplan and relying purely on the patched solid LEF block.
- **Verification:** OpenROAD log: `Detailed routing completed with 0 errors.`

### [2026-06-19 13:20:15] `mpw_precheck` Path-Space Bug
- **Cause:** Docker container failed with "Directory not found" when executing `mpw_precheck.py` because the host path (`.../5-stagged cpu/...`) contained a space character.
- **Solution:** Modified the Docker invocation to rigidly mount the project root to `/project` and operate exclusively within the container's isolated filesystem path.
- **Verification:** `mpw_precheck` successfully located and parsed the Makefiles.

### [2026-06-19 15:40:00] LVS Blackbox Missing SPICE
- **Cause:** Netgen treated the SRAM instances as empty "blackboxes" because the gate-level netlist lacked the internal OpenRAM definitions.
- **Solution:** Created a dummy `.subckt` file that explicitly defined the pins of the `sky130_sram_2kbyte_1rw1r_32x512_8` macro to satisfy the Netgen parser hierarchy.
- **Verification:** Netgen LVS output: `Circuits match uniquely. Property errors were 0.`

### [2026-06-19 16:30:00] Antenna Violations on Wishbone Nets
- **Cause:** The Wishbone bus nets travelling from the Caravel IO pads (West) to the central core logic were too long, exceeding the antenna rule limits.
- **Solution:** Moved the Wishbone pin assignments to the South face of the wrapper, drastically shortening the wire length. OpenLane's Diode Insertion step resolved any remaining edge cases.
- **Verification:** `check_antennas` reported 0 violations.

---

## 4. Tool & Environment

### [2026-06-19 10:05:00] Docker OOM Kills
- **Cause:** The Linux Out-Of-Memory (OOM) killer terminated the `mpw_precheck` container because Magic consumed >13GB of RAM attempting to flatten the entire hierarchical layout to perform DRC on the SRAMs.
- **Solution:** Avoided memory explosion by reducing routing concurrency (`ROUTING_CORES=2`) and setting `MAGIC_DRC_USE_GDS=0`, forcing Magic to run hierarchically instead of flattening.
- **Verification:** Container survived the `magic_drc` stage.

### [2026-06-19 13:30:00] Makefile Quoting
- **Cause:** Precheck extraction scripts failed due to unquoted variables `$(PDK_ROOT)`.
- **Solution:** Patched the local Makefiles to rigorously quote all directory variables `"${PDK_ROOT}"`.
- **Verification:** `make verify` ran successfully regardless of host directory structure.
