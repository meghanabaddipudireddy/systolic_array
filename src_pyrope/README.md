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

## Files to commit

The Pyrope source and simulation support files belong in the repository:

- `src_pyrope/top.prp`: updated syntax accepted by the installed LiveHD build.
- `tests/Makefile`: compiles Pyrope and runs the original cocotb tests.
- `tests/pyrope_wrapper.sv`: converts packed ports to the original array interface.
- `generated/.gitignore`: excludes generated Verilog, build files, and results.

The existing `tests/test_systolic.py` remains unchanged. To commit the pipeline:

```bash
git add src_pyrope/top.prp tests/Makefile tests/pyrope_wrapper.sv generated/.gitignore
git commit -m "Compile Pyrope with LiveHD and run existing cocotb tests"
git push origin main
```

Keep `.venv/`, `__pycache__/`, and generated build outputs out of the commit.
This README can remain a local, untracked file; the command above does not stage it.
Other users should set `LHD=/absolute/path/to/lhd` to their own LiveHD build.

## Validation status

Validated on 2026-11-11 with the existing local LiveHD build, cocotb 2.1.0,
and Verilator 5.052: compilation produced zero errors or warnings, and all
14 original tests in `tests/test_systolic.py` passed against generated Verilog.
The cases cover matrix products, 64-bit overflow, reset/start behavior, and
completion after exactly ten compute cycles. This is simulation validation,
not a formal equivalence proof against the reference SystemVerilog.
