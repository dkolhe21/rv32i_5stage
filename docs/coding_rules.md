# Coding Rules and Guidelines

To ensure the 5-Stage RV32I processor remains robust, readable, and synthesis-friendly, the following strict SystemVerilog/Verilog coding conventions were adhered to.

---

## 1. Naming Conventions

Consistent naming is critical for deciphering large netlists and interfacing with automated tools.

| Signal Type | Convention | Example |
|-------------|------------|---------|
| **Clocks** | Prefix with `clk_` or use exactly `clk`. Wishbone clocks use `wb_clk_i`. | `clk_core`, `wb_clk_i` |
| **Resets** | Suffix with `_n` to explicitly denote active-low. | `rst_n`, `jtag_trst_n` |
| **Inputs** | Suffix with `_i` at the module boundary (especially for bus protocols). | `wbs_cyc_i` |
| **Outputs** | Suffix with `_o` at the module boundary. | `wbs_ack_o` |
| **Buses** | Pluralize or clearly indicate array bounds. Always declare `[MSB:LSB]`. | `wire [31:0] wbs_dat_i;` |
| **Constants/Parameters** | ALL_CAPS with underscores. | `parameter IDLE_STATE = 2'b00;` |

---

## 2. Module Structure

Modules must follow a rigid internal structural hierarchy to prevent spaghetti-code.

1. **Header & Parameters:** Module declaration followed immediately by `#(parameter ...)` if applicable.
2. **Ports:** `input` and `output` declarations grouped logically (e.g., clocks first, Wishbone signals second, internal signals third).
3. **Internal Wires/Regs:** All internal nets declared at the top of the logic block.
4. **Combinational Logic (`assign`):** Continuous assignments.
5. **Sequential Logic (`always`):** Clocked blocks at the bottom.

### Snippet Example:
```verilog
module example_alu #(
    parameter DATA_WIDTH = 32
)(
    input wire clk,
    input wire rst_n,
    input wire [DATA_WIDTH-1:0] op_a,
    output reg [DATA_WIDTH-1:0] result
);

    // Internal Wires
    wire [DATA_WIDTH-1:0] temp_sum;

    // Combinational Logic
    assign temp_sum = op_a + 32'd1;

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'd0;
        end else begin
            result <= temp_sum;
        end
    end
endmodule
```

---

## 3. State Machine Coding Style

Finite State Machines (FSMs), such as our Wishbone Memory Controller, must be coded using the **Two-Block (or Three-Block) methodology**.

1. **State Register (Sequential):** Handles the physical flip-flops `state <= next_state`.
2. **Next State & Output Logic (Combinational):** Calculates the transitions and output signals. 

*Rule: Never mix state transitions and complex combinational output calculations in the same sequential block.*

### Snippet Example:
```verilog
    parameter IDLE = 2'b00, FETCH = 2'b01;
    reg [1:0] state, next_state;

    // 1. Sequential State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    // 2. Combinational Next-State Logic
    always @(*) begin
        // Default assignments to prevent latches
        next_state = state;
        wbs_ack_o = 1'b0;

        case (state)
            IDLE: begin
                if (req_valid) next_state = FETCH;
            end
            FETCH: begin
                wbs_ack_o = 1'b1;
                next_state = IDLE;
            end
        endcase
    end
```

---

## 4. Proper Use of `always` Blocks

- **`always @(posedge clk or negedge rst_n)`**: Strictly for edge-triggered sequential logic. **MUST use non-blocking assignments (`<=`)**.
- **`always @(*)`**: Strictly for combinational logic. **MUST use blocking assignments (`=`)**. Every branch of an `if` or `case` statement must assign all variables to prevent the inference of unintended latches.
- **`always_latch` / `always_comb` / `always_ff`**: Permitted in SystemVerilog, but since our primary macro flows through `sv2v` (which flattens to Verilog-2001 for Yosys), classic `always @(*)` is preferred for tooling compatibility. **NEVER intentionally infer latches**.

---

## 5. Simulation-Only Constructs

Commands like `$display`, `$monitor`, and `$finish` are non-synthesizable. 

- **Rule:** They must be strictly quarantined within testbench files (e.g., `rv32i_integration_tb.v`).
- If debug output is required *inside* an RTL module during simulation, it must be enclosed in `ifndef SYNTHESIS` guards to ensure Yosys ignores it during the OpenLane physical build.

### Snippet Example:
```verilog
`ifndef SYNTHESIS
    always @(posedge clk) begin
        if (invalid_opcode) begin
            $display("ERROR: Invalid Opcode detected at time %0t", $time);
            $finish;
        end
    end
`endif
```
