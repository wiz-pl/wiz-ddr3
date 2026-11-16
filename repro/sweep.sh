#!/bin/sh
# The tap/slip sweep table: the same calibration with the modelled device's read
# latency, bit offset and good-tap windows moved. Prints, per device, the chosen
# (slip, tap, latency), the traffic mismatches and the two 8x32 maps ('#' good).
set -eu
cd "$(dirname "$0")/.."
BIN=.grail/bin/ddr3
[ -x "$BIN" ] || { echo "build first: repro/build.sh" >&2; exit 1; }
exec "$BIN" sweep "${1:-30000}"
