#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/systolic-test.XXXXXX")
trap 'rm -rf "$build_dir"' EXIT
verilator --binary --timing -Wno-fatal --top-module systolic_tb \
  --Mdir "$build_dir" src/mac_cell.sv src/controller.sv src/top.sv \
  tests/systolic_tb.sv > "$build_dir/build.log" 2>&1 || {
    cat "$build_dir/build.log"
    exit 1
  }
"$build_dir/Vsystolic_tb"
