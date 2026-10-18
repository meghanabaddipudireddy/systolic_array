#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-smoke}"
seed="${2:-1}"
case "$mode" in
  smoke) test_name=systolic_smoke_test; expected='UVM_SMOKE_PASS' ;;
  random)
    test_name=systolic_test
    expected='Results: 320 passed, 0 failed'
    if [[ -z "${VERILATOR_SOLVER:-}" ]] && ! command -v z3 >/dev/null; then
      echo "Random mode requires Z3: brew install z3" >&2
      exit 1
    fi
    ;;
  *) echo "Usage: $0 [smoke|random] [seed]" >&2; exit 1 ;;
esac
[[ "$seed" =~ ^[0-9]+$ ]] || { echo "Seed must be an unsigned integer" >&2; exit 1; }
# Cache a pinned open-source UVM release outside the repository.
if [[ -z "${UVM_HOME:-}" ]]; then
  UVM_HOME="${TMPDIR:-/tmp}/systolic-uvm-library"
  if [[ ! -f "$UVM_HOME/src/uvm_pkg.sv" ]]; then
    git clone https://github.com/chipsalliance/uvm-verilator.git "$UVM_HOME"
    git -C "$UVM_HOME" checkout --detach 5d72b6618acfddece7f09382a032ccbc05862fdc
  fi
fi
[[ -f "$UVM_HOME/src/uvm_pkg.sv" ]] || { echo "Missing $UVM_HOME/src/uvm_pkg.sv" >&2; exit 1; }
build_dir="${UVM_BUILD_DIR:-${TMPDIR:-/tmp}/systolic-uvm-build}"
mkdir -p "$build_dir"
build_dir=$(cd "$build_dir" && pwd)
echo "Compiling UVM; log: $build_dir/build.log"
verilator --binary --timing -j 4 -Wno-fatal --top-module systolic_tb \
  +define+UVM_NO_DPI "+incdir+$UVM_HOME/src" +incdir+uvm_testbench \
  --Mdir "$build_dir" "$UVM_HOME/src/uvm_pkg.sv" \
  src/mac_cell.sv src/controller.sv src/top.sv \
  uvm_testbench/systolic_if.sv uvm_testbench/systolic_pkg.sv \
  uvm_testbench/systolic_tb.sv > "$build_dir/build.log" 2>&1 || {
    tail -60 "$build_dir/build.log"; exit 1;
  }
echo "Running $mode test with seed $seed"
"$build_dir/Vsystolic_tb" "+UVM_TESTNAME=$test_name" "+verilator+seed+$seed" 2>&1 | tee "$build_dir/run.log"
rg -q "$expected" "$build_dir/run.log"
if rg -q '(UVM_ERROR|UVM_FATAL).* @' "$build_dir/run.log"; then exit 1; fi
