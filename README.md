# 4x4 Systolic Array AI Accelerator — SystemVerilog Implementation

A parameterized 4x4 output-stationary systolic array for matrix multiplication, implemented in pure RTL SystemVerilog. Designed as an AI hardware accelerator targeting the same architectural principles used in commercial ML inference chips (Google TPU, MIT Eyeriss).

---

## Architecture

### Why a Systolic Array

Matrix multiply is the core operation in neural network inference — every layer is essentially C = A × B. A naive software implementation computes each output element sequentially. A systolic array computes all 16 output elements simultaneously in a pipelined, rhythmic dataflow — each clock cycle, every MAC unit does useful work.

---

### Output-Stationary Dataflow

The array uses **output-stationary** dataflow — each MAC unit holds its partial sum (accumulator) in place and accumulates over multiple cycles while data flows through it.

```
Each MAC unit computes:
    y = y + w_in × x_in    (accumulate in place)
    x_out = x_in            (activation passes right to next cell)
    w_out = w_in            (weight passes down to next cell)
```

Matrix A (activations) flows **horizontally** left to right through each row.
Matrix B (weights) flows **vertically** top to bottom through each column.
Matrix C (results) accumulates **in place** at each MAC unit position (i,j).

After the computation completes, MAC unit at position (i,j) holds C[i][j] — the dot product of row i of A with column j of B.

---

### Data Skewing

Without skewing, all inputs would enter the array simultaneously and the wrong data would meet at each cell. The correct element of A[i][k] must meet B[k][j] at MAC unit (i,j) at exactly the right cycle.

Since data travels one cell per cycle through the array, row i of A must be delayed by i cycles before entering, and column j of B must be delayed by j cycles:

```
Cycle:    0    1    2    3    4    5    6
Row 0:   A00  A01  A02  A03   0    0    0
Row 1:    0   A10  A11  A12  A13   0    0
Row 2:    0    0   A20  A21  A22  A23   0
Row 3:    0    0    0   A30  A31  A32  A33
```

Same staggering applies to B columns. This ensures A[i][k] and B[k][j] always arrive at MAC unit (i,j) simultaneously.

The skewing is implemented as shift register chains at the array input boundaries — row i of A delayed by i flip-flop stages, column j of B delayed by j flip-flop stages.

Total computation time: 4 + 3 = **7 cycles** (4 cycles for all inputs to enter + 3 cycles for the last inputs to propagate to the far corner).

---

### 4x4 Array Structure

```
         b_in[0]  b_in[1]  b_in[2]  b_in[3]
            ↓        ↓        ↓        ↓
a_in[0] → MAC(0,0) → MAC(0,1) → MAC(0,2) → MAC(0,3)
            ↓        ↓        ↓        ↓
a_in[1] → MAC(1,0) → MAC(1,1) → MAC(1,2) → MAC(1,3)
            ↓        ↓        ↓        ↓
a_in[2] → MAC(2,0) → MAC(2,1) → MAC(2,2) → MAC(2,3)
            ↓        ↓        ↓        ↓
a_in[3] → MAC(3,0) → MAC(3,1) → MAC(3,2) → MAC(3,3)
```

Activations (A) enter from the left, weights (B) enter from the top. Each arrow represents a registered wire — data moves exactly one cell per clock cycle. The 16 accumulated results are read from each MAC unit's output after `done` asserts.

---

## Module Hierarchy

```
top
├── controller        — Moore FSM sequencing computation
├── mac_cell × 16    — instantiated via generate loop in 4x4 grid
└── skewing logic    — shift register chains at input boundaries
```

---

## Module Descriptions

### mac_cell

The fundamental compute unit. Every clock cycle when enabled:

```systemverilog
y     <= y + (w_in * x_in);   // multiply-accumulate
x_out <= x_in;                 // pass activation to next cell right
w_out <= w_in;                 // pass weight to next cell below
```

Inputs are 32-bit. The accumulator `y` is 64-bit to hold the full precision result without overflow (32-bit × 32-bit = 64-bit, accumulated 4 times).

The `mac_en` signal gates accumulation — the MAC only computes when the controller is in the COMPUTE state, preventing spurious accumulation during IDLE or after DONE.

---

### controller

A 3-state Moore FSM that sequences the computation:

```
IDLE    → outputs: done=0, mac_en=0
          transition: start=1 → COMPUTE

COMPUTE → outputs: done=0, mac_en=1
          transition: count==6 → DONE, else stay + count++

DONE    → outputs: done=1, mac_en=0
          transition: always → IDLE
```

**Why Moore:** outputs (`done`, `mac_en`) depend only on the current state, not on input signals. This guarantees glitch-free outputs — `done` asserts cleanly for exactly one cycle when the state register transitions to DONE, not combinationally from a counter comparison.

A 3-bit counter in the top module counts cycles during COMPUTE and asserts `count_done` when it reaches 6. The controller transitions to DONE on that signal.

DONE lasts exactly one cycle — long enough for downstream logic to latch results — then returns to IDLE ready for the next matrix multiply.

---

### top

Wires everything together:

- Declares `x_wire[4][5]` — horizontal wires carrying activations between columns
- Declares `w_wire[5][4]` — vertical wires carrying weights between rows
- Implements skewing shift registers for A rows and B columns
- Connects skewed inputs to array boundary (`x_wire[i][0]`, `w_wire[0][j]`)
- Instantiates 16 MAC cells via nested generate loops
- Instantiates controller and connects `mac_en`, `done`, `count_done`

The generate loop connects cells automatically:
- `x_wire[i][j]` → `mac[i][j].x_in`, `mac[i][j].x_out` → `x_wire[i][j+1]`
- `w_wire[i][j]` → `mac[i][j].w_in`, `mac[i][j].w_out` → `w_wire[i+1][j]`

---

## Key Design Decisions

**Output-stationary over weight-stationary:** output-stationary keeps partial sums in the MAC unit accumulators, minimizing memory traffic for the output matrix. Weight-stationary would require loading weights every computation cycle. For inference workloads where the same weights are reused across many input vectors, weight-stationary has advantages — but output-stationary is simpler to implement correctly and sufficient for demonstrating the architecture.

**64-bit accumulator:** 32-bit × 32-bit multiplication produces a 64-bit result. Accumulating 4 such products can grow further. Using a 64-bit accumulator prevents overflow at the cost of wider wires and slightly more area. In a production design you'd choose accumulator width based on the value range of your data.

**Moore FSM for controller:** a Mealy FSM would allow `done` to fire one cycle earlier by making it combinationally dependent on the counter. However `done` is read by external logic and a combinational glitch on the counter could cause false `done` assertions. The Moore FSM adds one cycle of latency in exchange for a clean, registered output — the right tradeoff for a control signal.

**Skewing in top module, not controller:** the skewing logic is purely structural — shift registers with fixed depths. Putting it in the top module keeps the controller FSM clean and focused on sequencing. The skewing doesn't need to know about FSM states; it just delays signals by a fixed number of cycles unconditionally.

**Generate loop for MAC instantiation:** 16 MAC cells instantiated via a nested generate loop rather than explicitly. This makes the design trivially parameterizable — changing the array size would only require changing the loop bounds and wire dimensions, not rewriting 16 instantiations.

---

## Verification — UVM Testbench

The testbench uses the Universal Verification Methodology (UVM) — a standardized, component-based verification framework. Instead of a single monolithic testbench, UVM breaks verification into reusable components each with a specific job. This enables constrained-random testing, automatic result checking, and coverage-driven verification.

### Why UVM over a basic testbench

A directed testbench only checks the specific cases you thought to write. A UVM testbench with constrained-random sequences generates hundreds of random matrix pairs automatically, and the scoreboard checks every single one against a software reference model — covering cases a directed test would never reach.

### UVM Component Structure

```
systolic_test
└── systolic_env
    ├── systolic_agent
    │   ├── uvm_sequencer       — manages transaction handoff
    │   ├── systolic_driver     — drives a_in, b_in, start onto DUT
    │   └── systolic_monitor_in — watches inputs, captures A and B matrices
    ├── systolic_monitor_out    — watches done and y_out, captures results
    └── systolic_scoreboard     — computes expected C=A×B, compares to actual
```

### Component Descriptions

**systolic_transaction** — the data object passed between components. Holds one 4x4 matrix A, one 4x4 matrix B, and the result C. A and B are declared `rand` so UVM can randomize them automatically using constraints that keep values in a safe range (0-15) to prevent accumulator overflow.

**systolic_sequence** — generates a stream of randomized transactions. Calls `randomize()` on each transaction, then hands it to the driver via `start_item` / `finish_item`. Configurable number of transactions — default 20 random matrix multiplies per test run.

**systolic_driver** — receives transactions from the sequence and drives them onto the DUT pins cycle by cycle. Feeds A rows left-to-right and B columns top-to-bottom with proper timing, pulses `start`, then waits for `done` before accepting the next transaction.

**systolic_monitor_in** — watches `a_in`, `b_in`, and `start` on the DUT interface. When `start` pulses, captures the 4x4 input matrices over 4 cycles and sends a transaction to the scoreboard via an analysis port.

**systolic_monitor_out** — watches `done` and `y_out`. When `done` pulses, captures all 16 result values and sends a transaction to the scoreboard.

**systolic_scoreboard** — the verification intelligence. Maintains two queues — one for input transactions, one for output transactions. When both arrive, it computes the expected result C = A × B in software using three nested loops, then compares each of the 16 elements against the actual DUT output. Any mismatch is reported with the exact element index and expected vs actual values. Reports total pass/fail count at the end of simulation.

**systolic_agent** — bundles the driver, sequencer, and input monitor. Exposes the input monitor's analysis port upward to the environment.

**systolic_env** — bundles the agent, output monitor, and scoreboard. Connects analysis ports: input monitor → scoreboard, output monitor → scoreboard.

**systolic_test** — top level. Creates the environment, raises a UVM objection to keep simulation alive, starts the sequence on the agent's sequencer, drops the objection when done.

### How the scoreboard verifies

```
Input monitor captures A, B → scoreboard queue
Output monitor captures C   → scoreboard queue

Scoreboard computes expected:
    for i in 0..3:
        for j in 0..3:
            expected[i][j] = sum(A[i][k] * B[k][j] for k in 0..3)

Compares expected[i][j] vs actual C[i][j] for all 16 elements
Reports pass or fail per element
```

This reference model works for any valid 4x4 matrix input — no hardcoded expected values, fully automated checking.

---

## File Structure

```
systolic-array/
├── src/
│   ├── mac_cell.sv      — MAC unit
│   ├── controller.sv    — Moore FSM controller
│   └── top.sv           — array top level with skewing and wiring
├── uvm_testbench/
│   └── systolic_agent.sv   
│   └── systolic_driver.sv
│   └── systolic_env.sv
│   └── systolic_monitor_in.sv
│   └── systolic_monitor_out.sv
│   └── systolic_scoreboard.sv
│   └── systolic_sequence.sv
│   └── systolic_tb.sv
│   └── systolic_test.sv
│   └── systolic_transaction.sv   
└── README.md
```

---

## Planned Additions

- BRAM interface for weight storage
- Post-synthesis PPA analysis: fmax, DSP utilization, power estimate
