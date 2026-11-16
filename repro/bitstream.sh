#!/bin/sh
# The three board builds (needs the flake's yosys/nextpnr/prjxray in the env):
#   memtest        normal (written-pattern calibration + 256 MB passes)
#   memtest_train  normal calibration + the MPR read sweep
#   memtest_mpr    MPR only (read-path test; enters/leaves MPR around the sweep)
set -eu
cd "$(dirname "$0")/.."
[ -x .grail/bin/ddr3 ] || { echo "build first: repro/build.sh" >&2; exit 1; }
nix develop --command .grail/bin/ddr3 bit      > /tmp/ddr3-bit.log 2>&1
nix develop --command .grail/bin/ddr3 bittrain > /tmp/ddr3-bittrain.log 2>&1
nix develop --command .grail/bin/ddr3 bitmpr   > /tmp/ddr3-bitmpr.log 2>&1
ls -l build/a35t/memtest*.bit
