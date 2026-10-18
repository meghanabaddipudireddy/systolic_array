# UVM simulation with Vivado XSim

Run from the repository root in a shell with Vivado on PATH:

```sh
xvlog -sv -L uvm -f uvm_testbench/files.f
xelab -L uvm systolic_tb -s systolic_uvm_sim
xsim systolic_uvm_sim -runall
```

For a Vivado GUI project:

- Keep `src/*.sv` as Design Sources.
- Add `systolic_if.sv`, `systolic_pkg.sv`, and `systolic_tb.sv` as Simulation Sources.
- Add the `uvm_testbench` directory to the simulation include directories.
- The remaining class files are included by `systolic_pkg.sv`; do not also compile them separately. If already added, disable them for compilation in the simulation fileset.
- Compile the interface before the package, and the package before the testbench.
- Set the simulation top to `systolic_tb`.
- Do not add `tests/systolic_tb.sv` to this simulation: it is a separate non-UVM testbench with the same module name.

Enable UVM in the Vivado Tcl console:

```tcl
set_property xsim.compile.xvlog.more_options {-L uvm} [get_filesets sim_1]
set_property xsim.elaborate.xelab.more_options {-L uvm} [get_filesets sim_1]
set_property top systolic_tb [get_filesets sim_1]
update_compile_order -fileset sim_1
```

These option assignments replace existing extra options; preserve any other options your project needs.

The XSim commands have not been executed here because Vivado is not installed on this machine.

## Transaction timing

The driver owns reset at startup and before each independent multiplication.
It holds zeros for four reset cycles to clear accumulators and flush the skew
registers, then pulses start while inputs remain zero. Starting on the following
cycle, it streams four A columns/B rows on falling edges and sends zeros until
done. The input monitor samples on rising edges beginning one cycle after start;
the output monitor captures done before the driver starts the next reset.

## Mac end-to-end UVM smoke test

```sh
./tests/run_uvm.sh
```

Requires Verilator and a C++ toolchain. On the first run the script downloads a
pinned CHIPS Alliance UVM library into a temporary cache; Git and network access
are required for this step. Set `UVM_HOME` to use an existing library directory
containing `src/uvm_pkg.sv` instead. Build and simulation logs are kept under
`$TMPDIR/systolic-uvm-build` (or `UVM_BUILD_DIR` if set).

The test runs actual UVM components with three deterministic transactions:
the matrix containing 1 through 16 multiplied by itself, by identity, and by
zero. Success requires exactly 48 matching element comparisons, empty input
and output queues, and no UVM errors. A global simulation timeout catches hangs.
It does not require an SMT randomization solver and does not validate the
20-transaction constrained-random sequence or guarantee Vivado compatibility.

For XSim, compile with the file list above and select the same test using:

```sh
xsim systolic_uvm_sim -testplusarg UVM_TESTNAME=systolic_smoke_test -runall
```

### Verified result

The Mac smoke test passes with Verilator 5.052 and the pinned UVM library:
three matrices, 48 matching output elements, zero UVM errors or fatals.
The constrained-random sequence also passes with seed 1: 20 matrices, 320
matching outputs, zero UVM errors or fatals. Vivado has not been run here.

## Randomized sequence on Mac

```sh
./tests/run_uvm.sh random 1
```

Runs 20 constrained-random matrix pairs with values from 0 to 15. The second
argument is the Verilator seed; change it for another reproducible run:

```sh
./tests/run_uvm.sh random 42
```

Requires Z3 (`brew install z3`) or a compatible solver configured with
`VERILATOR_SOLVER`. Random mode requires the scoreboard to report exactly
320 passing element comparisons and no errors. Running without arguments still
selects the three-matrix smoke test.
