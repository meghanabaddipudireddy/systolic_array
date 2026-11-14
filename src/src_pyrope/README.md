# Pyrope systolic array

`top.prp` translates the current `src/top.sv`, `src/controller.sv`, and
`src/mac_cell.sv` into one integrated Pyrope module. The SystemVerilog sources
remain the reference implementation. Cells are explicitly expanded so this
version does not depend on a particular Pyrope module-import mechanism or
loop-elaboration syntax.

The source uses the typed Pyrope syntax supported by the installed LiveHD:

- `pub mod top(...) -> (...)` declares typed input and output ports.
- `reg name:U32:[clock_pin=clk] = nil` declares a register with no power-on value.
- Register reads observe the current Q value; writes commit on the clock edge.
- Explicit masks preserve the counter width and 64-bit accumulator wraparound.

## Interface and behavior

Inputs: `clk`, active-high synchronous `rst`, `start`, four unsigned 32-bit
`a_in` elements, and four unsigned 32-bit `b_in` elements.
Outputs: `done` and a 4x4 array `y_out` of unsigned 64-bit results.
LiveHD emits packed Verilog vectors: input element i occupies bits 32*i +: 32;
output (i,j) occupies bits 64*(4*i+j) +: 64. `tests/pyrope_wrapper.sv` restores
unpacked array ports so the original cocotb testbench can run unchanged.

At the edge accepting `start`, the controller moves from IDLE to COMPUTE.
Starting on the next edge, stream A column k and B row k for k=0,1,2,3.
Then drive zeros for six more compute edges. `done` asserts after compute
edge 10, and stays high for one clock. Start during COMPUTE is ignored;
start held high is accepted again when the controller returns to IDLE.

Reset clears the state, counter, cell accumulators, and forwarded operands.
Skew registers keep shifting even during reset and idle, matching the RTL.
Drive zeros for at least three reset clocks to flush them. Each independent
matrix multiplication requires reset to clear previous accumulator values.
Overflow wraps modulo 2^64; there is no overflow flag or saturation.

## Compile and run the original cocotb tests

The pipeline is:

```text
src_pyrope/top.prp → LiveHD → generated/top.v
                              + tests/pyrope_wrapper.sv
                              → Verilator + tests/test_systolic.py
```

Use a built LiveHD `lhd` binary, Verilator, GNU Make, and a Python environment
with cocotb installed. From the repository root:

```bash
source .venv/bin/activate
make -C tests
```

The Makefile uses the existing sibling build at
`../livehd/bazel-bin/lhd/lhd`. To select another build:

```bash
make -C tests LHD=/absolute/path/to/lhd
```

To compile without simulation:

```bash
make -C tests compile
```

Generated Verilog, LiveHD work files, simulation build files, and `results.xml`
are written under `generated/` and ignored by Git. The Makefile recompiles
when `top.prp` or the selected LiveHD binary changes.

## Two SRAMs controlled by cocotb

`top.prp` and the original cocotb testbench are unchanged. The additional
`src_pyrope/sram_top.prp` contains only two SRAM instances and a connection to
the compiled `top.prp` array. There is no added feeder, address counter,
arbitration, or controller RTL. All memory controls, reset, and start timing
come from `tests/test_sram_pyrope.py`.

```text
cocotb → activation SRAM controls → activation SRAM → a_in ┐
                                                        ├→ existing top.prp
cocotb → weight SRAM controls     → weight SRAM     → b_in ┘
```

Both instances use the same OpenRAM `sram_128x16` definition: one read/write
port, 128 bits per word, 16 words (256 bytes), and full-word writes. They have
independent storage, addresses, chip selects, and write enables. These sizes
are the initial integration configuration, not a physical macro feasibility claim.

Each 128-bit word supplies four unsigned 32-bit lanes. At arithmetic slot k:

| Memory | Address | Lane i (bits 32*i +: 32) |
| --- | --- | --- |
| Activation | a_base + k | A[i][k] |
| Weight | b_base + k | B[k][i] |

Thus activations are stored by column, weights by row. No extra skewing is
applied: the existing array already provides it. The tests reserve address 15
in each SRAM for a zero word and use it during reset flushing and drain cycles.
That reservation is a testbench convention, not new hardware logic.

Initialize the pinned OpenRAM source, activate the existing environment, and run:

```bash
git submodule update --init openram
source .venv/bin/activate
make -C tests -f Makefile.sram
```

`LHD=/absolute/path/to/lhd` also works with this Makefile. To compile only:

```bash
make -C tests -f Makefile.sram compile
```

The build invokes the pinned OpenRAM Verilog writer through
`openram_config/generate_model.py`, creates a declaration for LiveHD to import,
compiles the existing array, and links the Pyrope connections. Verilator uses
OpenRAM's generated behavioral model, **not** LiveHD's empty SRAM declaration.
Outputs remain under `generated/` and are ignored by Git.

### Read/write and array timing

The generated model captures `csb`, `web`, address, and input data on a rising
edge. `csb=0, web=0` writes; `csb=0, web=1` reads; `csb=1` disables the operation.
Writes happen on the falling edge, and reads return after falling edge plus
the model's `DELAY` (3 ns by default). Output is invalidated after each rising
edge, so disabled cycles and write cycles must not be treated as valid reads.

The testbench uses a 20 ns clock. It first reads zeros and resets/flushes the
array's delay chains for four clocks. On the edge accepting `start`, it issues
the first SRAM read. The resulting word is ready before the next rising edge,
when the array samples compute slot 0. Reads for slots 1–3 follow every cycle;
the six remaining compute slots read the reserved zero word. Completion is
checked after exactly ten compute slots.

The testbench must keep the memories reading valid operands during computation.
There is no hardware protection against writes or badly timed addresses during
compute. SRAM contents are not reset by the array's `rst` signal.

### Behavioral simulation versus physical generation

The lightweight model-generation script uses OpenRAM's actual Verilog emitter
with the configured dimensions and port metadata. It bypasses physical SRAM
construction. Its bundled `scn4m_subm` technology default supplies model power-pin
names only; it does not select your fabrication target. No GDS, LEF, SPICE,
Liberty, DRC/LVS result, or characterized access time is produced by this step.
The behavioral `DELAY` is not evidence of achievable hardware frequency.

For full generation, first configure an OpenRAM technology/PDK and external
tools using the pinned [OpenRAM setup guide](../openram/docs/source/basic_setup.md).
Then, from the repository root in that environment:

```bash
export OPENRAM_HOME="$PWD/openram/compiler"
export OPENRAM_TECH_NAME=YOUR_CONFIGURED_TECHNOLOGY
python openram/sram_compiler.py openram_config/sram_128x16.py
```

The full compiler output goes to `generated/openram/macro/`. Its feasibility
and physical verification have not been tested. To rerun the same cocotb tests
with the model from a successful full generation, use a separate simulation build:

```bash
make -C tests -f Makefile.sram \
  SRAM_MODEL="$PWD/generated/openram/macro/sram_128x16.v" \
  SIM_BUILD="$PWD/generated/sram_macro_sim_build"
```

The two SRAM tests check all addresses, independent controls, disabled writes,
write/readback and overwrite behavior, captured request inputs, read latency,
back-to-back reads, and retention across array reset. Integration runs cover
identity, zero, distinct, sparse, random full-width, and overflow matrices,
operand values at the sampling edges, rereads, and reuse without reloading.

## Validation status

Validated on 2026-11-11 with the existing local LiveHD build, cocotb 2.1.0,
and Verilator 5.052: compilation produced zero errors or warnings, and all
14 original tests in `tests/test_systolic.py` passed against generated Verilog.
The cases cover matrix products, 64-bit overflow, reset/start behavior, and
completion after exactly ten compute cycles. This is simulation validation,
not a formal equivalence proof against the reference SystemVerilog.

On 2026-11-14, both SRAM test functions passed against the pinned OpenRAM
behavioral emitter (commit `2f7b3866418ac1ce17ad959207a1489033d8c577`), including
28 matrix runs with SRAM-fed operands. All 14 original array tests also passed.
Physical macro generation and silicon timing remain unvalidated.

## References

- [SRAM-Integrated Systolic Array Accelerator on FPGA — wesleejacop](https://github.com/wesleejacop/SRAM-Integrated-Systolic-Array-Accelerator-on-FPGA)
  was used as a reference for connecting activation and weight memories to a
  systolic array and considering operand formatting and timing. That project
  uses a 3×3 weight-stationary architecture; this implementation retains the
  existing 4×4 output-stationary Pyrope array, with SRAM controls driven by cocotb.
- [OpenRAM — VLSIDA](https://github.com/VLSIDA/OpenRAM) provides the SRAM compiler
  and behavioral Verilog model generator used here. See also the
  [OpenRAM website](https://openram.org/).
