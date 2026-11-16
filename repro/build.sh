#!/bin/sh
# Build the flow driver (.grail/bin/ddr3) with the pinned toolchain.
# Heavy (a compile): run it through /workspace/wiz-tools/heavy in the agent setup.
set -eu
cd "$(dirname "$0")/.."
exec nix develop --command grail build ddr3
