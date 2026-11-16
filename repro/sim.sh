#!/bin/sh
# Simulation results, one file per run under /tmp.
# Usage: repro/sim.sh [CYCLES]   (default 50000; the traffic test can use fewer)
set -eu
cd "$(dirname "$0")/.."
N=${1:-50000}
BIN=.grail/bin/ddr3
[ -x "$BIN" ] || { echo "build first: repro/build.sh" >&2; exit 1; }
"$BIN" sim 30000            > /tmp/ddr3-sim.log 2>&1
"$BIN" simtrain "$N"        > /tmp/ddr3-simtrain.log 2>&1
"$BIN" mprsim "$N"          > /tmp/ddr3-mprsim.log 2>&1
"$BIN" sweep 30000          > /tmp/ddr3-sweep.log 2>&1
printf '%s\n' "wrote /tmp/ddr3-sim.log /tmp/ddr3-simtrain.log /tmp/ddr3-mprsim.log /tmp/ddr3-sweep.log"
grep -E 'calDone|MPR done|violation|mismatches' /tmp/ddr3-simtrain.log /tmp/ddr3-mprsim.log | head -20
