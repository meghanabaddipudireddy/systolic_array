

from pathlib import Path
from tempfile import TemporaryDirectory

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, ReadOnly, RisingEdge
from cocotb.utils import get_sim_time

SIZE = 4
EXPECTED_COMPUTE_CYCLES = 10
CLOCK_PERIOD_NS = 10
INPUT_MAX = (1 << 32) - 1
OUTPUT_MASK = (1 << 64) - 1
BASE = [
    [1, 2, 3, 4],
    [5, 6, 7, 8],
    [9, 10, 11, 12],
    [13, 14, 15, 16],
]
IDENTITY = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
ZEROS = [[0] * SIZE for _ in range(SIZE)]
ONES = [[1] * SIZE for _ in range(SIZE)]


def matrix_product(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(SIZE))
             for j in range(SIZE)] for i in range(SIZE)]


def drive_inputs(dut, a_values, b_values):
    for i in range(SIZE):
        dut.a_in[i].value = a_values[i]
        dut.b_in[i].value = b_values[i]


async def run_case(dut, name, a, b):
    await FallingEdge(dut.clk)
    dut.rst.value = 1
    dut.start.value = 0
    drive_inputs(dut, [0] * SIZE, [0] * SIZE)
    # Reset clears accumulators. Zeros flush the unreset skew registers.
    for _ in range(4):
        await FallingEdge(dut.clk)
    dut.rst.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    await ReadOnly()
    accepted_at_ps = get_sim_time(unit="ps")
    accepted_at = accepted_at_ps / 1000
    assert int(dut.done.value) == 0, f"{name}: done asserted on start acceptance"
    dut._log.info("%s: start accepted at %.3f ns; compute cycle 0, done=0",
                  name, accepted_at)
    await FallingEdge(dut.clk)
    dut.start.value = 0

    # Supply A column k and B row k; top performs skewing internally.
    # After four input cycles, drive zeros while the array drains.
    for cycle in range(EXPECTED_COMPUTE_CYCLES):
        drive_inputs(dut,
                     [a[i][cycle] for i in range(SIZE)] if cycle < SIZE else [0] * SIZE,
                     b[cycle] if cycle < SIZE else [0] * SIZE)
        await RisingEdge(dut.clk)
        await ReadOnly()
        compute_cycle = cycle + 1
        elapsed_ps = get_sim_time(unit="ps") - accepted_at_ps
        elapsed_ns = elapsed_ps / 1000
        expected_done = int(compute_cycle == EXPECTED_COMPUTE_CYCLES)
        actual_done = int(dut.done.value)
        dut._log.info(
            "%s: compute cycle %2d/%d | elapsed=%3.0f ns | done=%d expected=%d",
            name, compute_cycle, EXPECTED_COMPUTE_CYCLES, elapsed_ns,
            actual_done, expected_done,
        )
        assert actual_done == expected_done, (
            f"{name}: compute cycle {compute_cycle}: done={actual_done}, "
            f"expected {expected_done}; completion must occur exactly on cycle "
            f"{EXPECTED_COMPUTE_CYCLES}"
        )
        assert elapsed_ps == compute_cycle * CLOCK_PERIOD_NS * 1000
        if compute_cycle < EXPECTED_COMPUTE_CYCLES:
            await FallingEdge(dut.clk)
    dut._log.info("%s: TIMING PASS — done after exactly %d compute cycles (%.0f ns)",
                  name, EXPECTED_COMPUTE_CYCLES, elapsed_ns)

    full_precision = matrix_product(a, b)
    if name.startswith("overflow"):
        assert all(value > OUTPUT_MASK for row in full_precision for value in row)
    # The RTL has no saturation or overflow flag: each sum wraps modulo 2**64.
    expected = [[value & OUTPUT_MASK for value in row] for row in full_precision]
    actual = [[int(dut.y_out[i][j].value) for j in range(SIZE)]
              for i in range(SIZE)]
    def format_matrix(matrix):
        return "\n".join("  [" + ", ".join(f"{value:20d}" for value in row) + "]"
                         for row in matrix)

    dut._log.info("\n%s\nA:\n%s\n× B:\n%s\nExpected C (64-bit):\n%s\nActual C:\n%s",
                  name, format_matrix(a), format_matrix(b),
                  format_matrix(expected), format_matrix(actual))
    if name.startswith("overflow"):
        dut._log.info("Full precision product before 64-bit wraparound:\n%s",
                      format_matrix(full_precision))
    for i in range(SIZE):
        for j in range(SIZE):
            assert actual[i][j] == expected[i][j], (
                f"{name}: C[{i}][{j}] expected {expected[i][j]}, "
                f"got {actual[i][j]}; A={a}, B={b}"
            )

    await RisingEdge(dut.clk)
    await ReadOnly()
    assert int(dut.done.value) == 0, f"{name}: done lasted more than one cycle"


@cocotb.test()
async def cycles_test(dut):
    """Verify done stays low for cycles 1–9 and asserts on compute cycle 10."""
    initialize(dut)
    await run_case(dut, "cycles_test", BASE, IDENTITY)


@cocotb.test()
async def test_identity(dut):
    initialize(dut)
    a = BASE
    b = IDENTITY
    await run_case(dut, "identity", a, b)


@cocotb.test()
async def test_zeros(dut):
    initialize(dut)
    a = BASE
    b = ZEROS
    await run_case(dut, "zeros", a, b)


@cocotb.test()
async def test_ones(dut):
    initialize(dut)
    a = BASE
    b = ONES
    await run_case(dut, "ones", a, b)


@cocotb.test()
async def test_random_1(dut):
    initialize(dut)
    a = [
        [3, 10, 3, 7],
        [13, 15, 14, 7],
        [0, 2, 3, 9],
        [3, 14, 0, 15],
    ]
    b = [
        [10, 6, 12, 8],
        [11, 11, 12, 2],
        [10, 2, 9, 9],
        [14, 4, 9, 0],
    ]
    await run_case(dut, "random_1", a, b)


@cocotb.test()
async def test_random_2(dut):
    initialize(dut)
    a = [
        [11, 11, 14, 13],
        [2, 12, 15, 3],
        [13, 15, 12, 8],
        [13, 15, 0, 7],
    ]
    b = [
        [4, 1, 3, 13],
        [15, 4, 15, 7],
        [3, 14, 15, 8],
        [12, 9, 15, 12],
    ]
    await run_case(dut, "random_2", a, b)


@cocotb.test()
async def test_random_3(dut):
    initialize(dut)
    a = [
        [13, 6, 9, 8],
        [0, 1, 4, 14],
        [15, 11, 6, 8],
        [15, 14, 15, 13],
    ]
    b = [
        [1, 9, 10, 14],
        [3, 14, 8, 14],
        [5, 13, 15, 2],
        [8, 15, 11, 3],
    ]
    await run_case(dut, "random_3", a, b)


@cocotb.test()
async def test_overflow_max(dut):
    initialize(dut)
    a = [
        [4294967295, 4294967295, 4294967295, 4294967295],
        [4294967295, 4294967295, 4294967295, 4294967295],
        [4294967295, 4294967295, 4294967295, 4294967295],
        [4294967295, 4294967295, 4294967295, 4294967295],
    ]
    b = [
        [4294967295, 4294967295, 4294967295, 4294967295],
        [4294967295, 4294967295, 4294967295, 4294967295],
        [4294967295, 4294967295, 4294967295, 4294967295],
        [4294967295, 4294967295, 4294967295, 4294967295],
    ]
    await run_case(dut, "overflow_max", a, b)


@cocotb.test()
async def test_overflow_power_of_two(dut):
    initialize(dut)
    a = [
        [2147483648, 2147483648, 2147483648, 2147483648],
        [2147483648, 2147483648, 2147483648, 2147483648],
        [2147483648, 2147483648, 2147483648, 2147483648],
        [2147483648, 2147483648, 2147483648, 2147483648],
    ]
    b = [
        [2147483648, 2147483648, 2147483648, 2147483648],
        [2147483648, 2147483648, 2147483648, 2147483648],
        [2147483648, 2147483648, 2147483648, 2147483648],
        [2147483648, 2147483648, 2147483648, 2147483648],
    ]
    await run_case(dut, "overflow_power_of_two", a, b)


@cocotb.test()
async def test_overflow_random_1(dut):
    initialize(dut)
    a = [
        [3639097038, 4104508779, 3535528338, 4186293486],
        [3251360142, 3419156099, 3221684968, 4190235211],
        [3399607415, 3648127398, 3753452691, 3480682110],
        [3317130105, 3797903079, 3988415372, 3553571993],
    ]
    b = [
        [3232244418, 3894338613, 4277763628, 3510844969],
        [3699959000, 4236949866, 3503010274, 3845456345],
        [3402544412, 4118398902, 3565083798, 3511879074],
        [3878364767, 4106072805, 4059618782, 3540204750],
    ]
    await run_case(dut, "overflow_random_1", a, b)


@cocotb.test()
async def test_overflow_random_2(dut):
    initialize(dut)
    a = [
        [3643629302, 4028692615, 3251573437, 3449146375],
        [4057343882, 3378922353, 3331553232, 3966440610],
        [3980152217, 3276609591, 3276163016, 4243480128],
        [3925084827, 3873355521, 4187894587, 3921396941],
    ]
    b = [
        [3481871676, 4289748221, 4223204426, 3587873089],
        [3551702984, 3665723771, 4152390626, 3943679487],
        [4206528021, 3722290325, 3370493779, 4078408757],
        [3294567811, 3641045500, 3593521638, 3318370314],
    ]
    await run_case(dut, "overflow_random_2", a, b)


def read_outputs(dut):
    return [[int(dut.y_out[i][j].value) for j in range(SIZE)] for i in range(SIZE)]


async def step(dut, *, rst=0, start=0, a=None, b=None):
    """Drive on falling edges and sample after the next rising edge settles."""
    await FallingEdge(dut.clk)
    dut.rst.value = rst
    dut.start.value = start
    drive_inputs(dut, a if a is not None else [0] * SIZE,
                 b if b is not None else [0] * SIZE)
    await RisingEdge(dut.clk)
    await ReadOnly()


async def reset_dut(dut):
    for _ in range(4):
        await step(dut, rst=1)
        assert read_outputs(dut) == ZEROS, "reset did not clear outputs"
        assert int(dut.done.value) == 0, "done asserted during reset"


def initialize(dut):
    dut.rst.value = 1
    dut.start.value = 0
    drive_inputs(dut, [0] * SIZE, [0] * SIZE)
    cocotb.start_soon(Clock(dut.clk, CLOCK_PERIOD_NS, unit="ns").start())


@cocotb.test()
async def test_idle_without_start(dut):
    """Nonzero inputs must not trigger work; completed results stay stable."""
    initialize(dut)
    await reset_dut(dut)
    for _ in range(15):
        await step(dut, a=[7, 8, 9, 10], b=[11, 12, 13, 14])
        assert read_outputs(dut) == ZEROS, "computed without start"
        assert int(dut.done.value) == 0, "done asserted without start"
    await run_case(dut, "idle_setup", BASE, IDENTITY)
    for _ in range(15):
        await step(dut, a=[INPUT_MAX] * SIZE, b=[INPUT_MAX] * SIZE)
        assert read_outputs(dut) == BASE, "idle changed completed outputs"
        assert int(dut.done.value) == 0, "idle unexpectedly restarted"


@cocotb.test()
async def test_reset_during_compute(dut):
    """Synchronous reset aborts work, wins over start, and permits recovery."""
    initialize(dut)
    await reset_dut(dut)
    await step(dut, start=1)
    for _ in range(3):
        await step(dut, a=[3] * SIZE, b=[4] * SIZE)
    assert any(value for row in read_outputs(dut) for value in row), "no work before reset"
    await step(dut, rst=1, start=1)
    assert read_outputs(dut) == ZEROS, "reset did not clear partial results"
    assert int(dut.done.value) == 0, "reset did not cancel completion"
    for _ in range(15):
        await step(dut)
        assert read_outputs(dut) == ZEROS, "aborted operation resumed"
        assert int(dut.done.value) == 0, "aborted operation completed"
    await run_case(dut, "reset_recovery", BASE, IDENTITY)
    # Also clear completed, nonzero results.
    await reset_dut(dut)


@cocotb.test()
async def test_start_behavior(dut):
    """Busy start is ignored; held start is accepted again on returning to IDLE."""
    initialize(dut)
    await reset_dut(dut)
    await step(dut, start=1)
    # A second pulse during COMPUTE must not restart the ten-cycle counter.
    for cycle in range(10):
        await step(dut, start=int(cycle == 3))
        assert int(dut.done.value) == int(cycle == 9), "busy start changed completion timing"
    for _ in range(12):
        await step(dut)
        assert int(dut.done.value) == 0, "busy start queued another operation"

    await reset_dut(dut)
    await step(dut, start=1)
    for cycle in range(10):
        await step(dut, start=1)
        assert int(dut.done.value) == int(cycle == 9), "held start changed completion timing"
    await step(dut, start=1)  # DONE -> IDLE
    assert int(dut.done.value) == 0
    await step(dut, start=1)  # IDLE -> COMPUTE: level-sensitive start
    assert int(dut.done.value) == 0
    for cycle in range(10):
        await step(dut)
        assert int(dut.done.value) == int(cycle == 9), "held start did not trigger a second operation"


if __name__ == "__main__":
    from cocotb_tools.runner import get_runner

    source_dir = Path(__file__).resolve().parent
    with TemporaryDirectory(prefix="systolic-cocotb-") as build_dir:
        runner = get_runner("verilator")
        runner.build(
            sources=[source_dir / filename for filename in
                     ("mac_cell.sv", "controller.sv", "top.sv")],
            hdl_toplevel="top",
            build_dir=build_dir,
            build_args=["-Wno-fatal"],
            timescale=("1ns", "1ps"),
        )
        runner.test(hdl_toplevel="top", test_module="test_systolic",
                    test_dir=source_dir, results_xml=Path(build_dir) / "results.xml")
