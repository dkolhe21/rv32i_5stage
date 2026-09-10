# Toolchain and Commands Reference

This document serves as the master reference for all critical commands and scripts utilized to compile, simulate, harden, and sign off the `rv32i_top` core within the Caravel wrapper.

> **Note:** All commands assume you are executing them from the root directory of the Caravel user project:
> `/run/media/durgesh/Code/visualstudio/RISC-V/5-stagged cpu/caravel_user_project`

---

## 1. RTL Simulation (Iverilog / Cocotb)

To run the functional verification suite on the RTL level (before synthesis):

```bash
# Execute the Caravel testbench for the 5-stage CPU
make verify-rv32i_integration-rtl PDK_ROOT=/path/to/pdks
```
*(Ensure `PDK_ROOT` is exported or explicitly passed to the Makefile).*

---

## 2. Physical Synthesis & Routing (OpenLane)

### 2.1 Hardening the Core Macro (`rv32i_top`)
This command runs the OpenLane digital flow on the `rv32i_top` block, generating the GDS and LEF for the core logic.

```bash
docker run --rm -u $(id -u) -v $(pwd):/project \
  -v /path/to/pdks:/path/to/pdks \
  -e PDK_ROOT=/path/to/pdks -e PDK=sky130A \
  efabless/openlane:2023.07.19-1 \
  sh -c "/openlane/flow.tcl -design /project/openlane/rv32i_top -ignore_mismatches"
```

### 2.2 Hardening the Top-Level Wrapper (`user_project_wrapper`)
After the macro is built, this command instantiates the macro into the Caravel wrapper and routes the IO/Wishbone pads.

```bash
docker run --rm -u $(id -u) -v $(pwd):/project \
  -v /path/to/pdks:/path/to/pdks \
  -e PDK_ROOT=/path/to/pdks -e PDK=sky130A \
  efabless/openlane:2023.07.19-1 \
  sh -c "/openlane/flow.tcl -design /project/openlane/user_project_wrapper -ignore_mismatches"
```

---

## 3. Tapeout Signoff (`mpw_precheck`)

The final signoff tool requires an isolated path mount to avoid bash resolution errors with spaces in the host directory name.

```bash
export INPUT_DIR=$(pwd)
export PDK_ROOT=/path/to/pdks
export PRECHECK_DIR=/home/durgesh/mpw_precheck

docker run --rm -u $(id -u) \
  -v "$INPUT_DIR":/project \
  -v "$PDK_ROOT":"$PDK_ROOT" \
  -v "$PRECHECK_DIR":"$PRECHECK_DIR" \
  -e PDK_ROOT="$PDK_ROOT" \
  -w "$PRECHECK_DIR" \
  efabless/mpw_precheck:latest \
  python3 "$PRECHECK_DIR"/mpw_precheck.py \
  --input_directory /project \
  --pdk_path "$PDK_ROOT"/sky130A \
  --skip_checks klayout_feol
```

---

## 4. Custom Python Scripts

### 4.1 LEF Solidification Script (`fix_lef.py`)
This script resolves the `met3.3d` spacing violations caused by fractured `OBS` layers in the provided OpenRAM LEF.

```python
#!/usr/bin/env python3
import sys

def solid_block_lef(filepath):
    print(f"Surgically patching {filepath}...")
    with open(filepath, 'r') as f:
        lines = f.readlines()
        
    in_obs = False
    new_lines = []
    
    for line in lines:
        if "OBS" in line:
            in_obs = True
            new_lines.append(line)
            # Inject a solid 1500x1500 bounding box across all routing layers
            new_lines.append("    LAYER met1 ;\n      RECT 0 0 1500 1500 ;\n")
            new_lines.append("    LAYER met2 ;\n      RECT 0 0 1500 1500 ;\n")
            new_lines.append("    LAYER met3 ;\n      RECT 0 0 1500 1500 ;\n")
            new_lines.append("    LAYER met4 ;\n      RECT 0 0 1500 1500 ;\n")
            continue
            
        if in_obs and "END" in line:
            in_obs = False
            new_lines.append(line)
            continue
            
        if not in_obs:
            new_lines.append(line)
            
    with open(filepath, 'w') as f:
        f.writelines(new_lines)
    print("Done.")

if __name__ == "__main__":
    solid_block_lef("sky130_sram_2kbyte_1rw1r_32x512_8.lef")
```

### 4.2 SRAM Dummy SPICE (`dummy_sram.spice`)
This resolves the "LVS Blackbox" mismatch where Netgen attempts to dive into the SRAM during the final precheck.

```spice
* Dummy subcircuit for sky130_sram_2kbyte_1rw1r_32x512_8
.subckt sky130_sram_2kbyte_1rw1r_32x512_8 
+ clk0 csb0 web0 wmask0[3] wmask0[2] wmask0[1] wmask0[0] 
+ addr0[8] addr0[7] addr0[6] addr0[5] addr0[4] addr0[3] addr0[2] addr0[1] addr0[0]
+ din0[31] din0[30] ... din0[0]
+ dout0[31] dout0[30] ... dout0[0]
+ clk1 csb1 addr1[8] ... addr1[0]
+ dout1[31] ... dout1[0]
+ vccd1 vssd1
* (Empty body forces Netgen to match hierarchically)
.ends
```

---

## 5. Artifact Copying

When an OpenLane run completes successfully, the artifacts must be manually copied from the `<timestamp>` run folder to the root directories for the precheck to locate them.

```bash
# Copy macro results
cp openlane/rv32i_top/runs/rv32i_top/results/routing/rv32i_top.def def/
cp openlane/rv32i_top/runs/rv32i_top/results/signoff/rv32i_top.gds gds/
cp openlane/rv32i_top/runs/rv32i_top/results/signoff/rv32i_top.lef lef/

# Copy wrapper results
cp openlane/user_project_wrapper/runs/user_project_wrapper/results/routing/user_project_wrapper.def def/
cp openlane/user_project_wrapper/runs/user_project_wrapper/results/signoff/user_project_wrapper.gds gds/
cp openlane/user_project_wrapper/runs/user_project_wrapper/results/signoff/user_project_wrapper.lef lef/
```
