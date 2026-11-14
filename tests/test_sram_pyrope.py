"""Cocotb owns every SRAM control and the array's reset/start timing."""
import random

import cocotb
from cocotb.triggers import Timer

MASK64 = (1 << 64) - 1
ZERO_ADDR = 15


def pack(values):
    return sum(value << (32 * i) for i, value in enumerate(values))


async def tick(dut, *, after_rise=None, **signals):
    # 20 ns clock. OpenRAM captures at rising, operates at falling, then
    # returns data after DELAY=3 ns. Return 4 ns after the falling edge.
    for name, value in signals.items():
        getattr(dut, name).value = value
    await Timer(6, unit="ns")
    dut.clk.value = 1
    await Timer(2, unit="ns")
    early = (dut.a_dout.value, dut.b_dout.value)
    if after_rise:
        for name, value in after_rise.items():
            getattr(dut, name).value = value
    await Timer(8, unit="ns")
    dut.clk.value = 0
    await Timer(4, unit="ns")
    return early


async def initialize(dut):
    for name in ("clk", "rst", "start", "a_csb", "a_web", "a_addr", "a_din",
                 "b_csb", "b_web", "b_addr", "b_din"):
        getattr(dut, name).value = 0
    await tick(dut, rst=1, a_csb=1, b_csb=1, a_web=1, b_web=1)
    await tick(dut)


async def write_pair(dut, a_addr, a, b_addr, b):
    await tick(dut, a_csb=0, b_csb=0, a_web=0, b_web=0,
               a_addr=a_addr, b_addr=b_addr, a_din=a, b_din=b)


async def read_pair(dut, a_addr, b_addr):
    await tick(dut, a_csb=0, b_csb=0, a_web=1, b_web=1,
               a_addr=a_addr, b_addr=b_addr)
    return int(dut.a_dout.value), int(dut.b_dout.value)


@cocotb.test()
async def memory_read_write_controls_addresses_and_latency(dut):
    await initialize(dut)
    rng = random.Random(217)
    a_words = [rng.getrandbits(128) for _ in range(16)]
    b_words = [rng.getrandbits(128) for _ in range(16)]
    for addr in range(16):
        await write_pair(dut, addr, a_words[addr], 15-addr, b_words[15-addr])
    for addr in reversed(range(16)):
        assert await read_pair(dut, addr, 15-addr) == (a_words[addr], b_words[15-addr])
    # csb=1 inhibits writes, including at both address boundaries.
    for addr in (0, 7, 15):
        await tick(dut, a_csb=1, b_csb=1, a_web=0, b_web=0,
                   a_addr=addr, b_addr=addr, a_din=0, b_din=0)
        assert await read_pair(dut, addr, addr) == (a_words[addr], b_words[addr])
    # web=1 reads even when din changes: no accidental write-through.
    await tick(dut, a_web=1, b_web=1, a_addr=3, b_addr=8, a_din=0, b_din=0)
    assert await read_pair(dut, 3, 8) == (a_words[3], b_words[8])
    # Each SRAM has independent chip select and write enable.
    await tick(dut, a_web=0, b_web=1, a_addr=4, b_addr=9, a_din=7, b_din=11)
    a_words[4] = 7
    assert await read_pair(dut, 4, 9) == (7, b_words[9])
    await tick(dut, a_csb=1, b_csb=0, a_web=0, b_web=0,
               a_addr=4, b_addr=9, a_din=13, b_din=19)
    b_words[9] = 19
    assert await read_pair(dut, 4, 9) == (7, 19)
    # Controls, address and write data are captured on the rising edge.
    await tick(dut, a_csb=0, b_csb=0, a_web=0, b_web=0,
               a_addr=1, b_addr=2, a_din=123, b_din=456,
               after_rise={"a_addr": 10, "b_addr": 11, "a_din": 999, "b_din": 999})
    a_words[1], b_words[2] = 123, 456
    assert await read_pair(dut, 1, 2) == (123, 456)
    assert await read_pair(dut, 10, 11) == (a_words[10], b_words[11])
    early = await tick(dut, a_addr=0, b_addr=15, after_rise={"a_addr": 5, "b_addr": 6})
    for sampled, expected in zip(early, (a_words[0], b_words[15])):
        assert not sampled.is_resolvable or int(sampled) != expected, "read arrived before falling edge"
    assert (int(dut.a_dout.value), int(dut.b_dout.value)) == (a_words[0], b_words[15])
    # Back-to-back reads, all addresses, also prove reads were nondestructive.
    for addr in range(16):
        assert await read_pair(dut, addr, addr) == (a_words[addr], b_words[addr])
    # Reset belongs to the array; it must not clear either SRAM.
    await tick(dut, rst=0)
    await tick(dut, rst=1)
    assert await read_pair(dut, 0, 15) == (a_words[0], b_words[15])


async def load(dut, a, b, a_base, b_base):
    await tick(dut, rst=1, start=0, a_csb=1, b_csb=1)
    await write_pair(dut, ZERO_ADDR, 0, ZERO_ADDR, 0)
    for k in range(4):
        await write_pair(dut, a_base+k, pack([a[i][k] for i in range(4)]),
                         b_base+k, pack(b[k]))


async def run_product(dut, a, b, a_base, b_base):
    # Prime a zero read, then flush the unreset skew registers for four edges.
    await read_pair(dut, ZERO_ADDR, ZERO_ADDR)
    for _ in range(4):
        await tick(dut, rst=1, start=0)
    # Prefetch word 0 on the edge accepting start. It arrives at falling+3 ns,
    # before the next rising edge, when compute slot 0 samples it.
    await tick(dut, rst=0, start=1, a_addr=a_base, b_addr=b_base)
    assert int(dut.done.value) == 0
    for slot in range(10):
        expected_a = pack([a[i][slot] for i in range(4)]) if slot < 4 else 0
        expected_b = pack(b[slot]) if slot < 4 else 0
        assert int(dut.a_dout.value) == expected_a, f"activation sample slot {slot}"
        assert int(dut.b_dout.value) == expected_b, f"weight sample slot {slot}"
        next_a = a_base+slot+1 if slot < 3 else ZERO_ADDR
        next_b = b_base+slot+1 if slot < 3 else ZERO_ADDR
        await tick(dut, start=0, a_addr=next_a, b_addr=next_b)
        assert int(dut.done.value) == int(slot == 9), f"completion at slot {slot}"
    packed = int(dut.y_out.value)
    for i in range(4):
        for j in range(4):
            expected = sum(a[i][k] * b[k][j] for k in range(4)) & MASK64
            actual = (packed >> (64*(4*i+j))) & MASK64
            assert actual == expected, f"C[{i}][{j}]: expected {expected}, got {actual}"
    await tick(dut)
    assert int(dut.done.value) == 0


@cocotb.test()
async def sram_to_array_data_alignment_products_and_rereads(dut):
    await initialize(dut)
    base = [[4*i+j+1 for j in range(4)] for i in range(4)]
    identity = [[int(i == j) for j in range(4)] for i in range(4)]
    rng = random.Random(147)
    cases = [(base, identity), (base, [[0]*4 for _ in range(4)]), (base, base)]
    # Sparse matrices expose transposition, lane swapping, and cycle shifts.
    for k in range(4):
        a, b = [[0]*4 for _ in range(4)], [[0]*4 for _ in range(4)]
        a[(k+1) % 4][k] = 17
        b[k][(k+2) % 4] = 23
        cases.append((a, b))
    cases += [([[rng.getrandbits(32) for _ in range(4)] for _ in range(4)],
               [[rng.getrandbits(32) for _ in range(4)] for _ in range(4)]) for _ in range(6)]
    cases.append(([[(1 << 32)-1]*4 for _ in range(4)], [[(1 << 32)-1]*4 for _ in range(4)]))
    for n, (a, b) in enumerate(cases):
        a_base, b_base = (0, 8) if n % 2 == 0 else (8, 0)
        await load(dut, a, b, a_base, b_base)
        await run_product(dut, a, b, a_base, b_base)
        for k in range(4):
            assert await read_pair(dut, a_base+k, b_base+k) == (
                pack([a[i][k] for i in range(4)]), pack(b[k]))
        # Reuse SRAM contents; no reload. Reset/zero flushing remain testbench duties.
        await tick(dut, rst=1)
        await run_product(dut, a, b, a_base, b_base)
