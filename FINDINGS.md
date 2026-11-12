# Findings: a DDR3 controller in Wiz's HDL on the Arty A7-35T

Recorded as the work goes (agent ddr3, from 2026-11-12). Design notes:
/workspace/wiz-notes/ddr3-design.md.

## Toolchain (openXC7: yosys, nextpnr-xilinx, Project X-Ray)

* **Every primitive of LiteDRAM's A7DDRPHY is supported**: PLLE2, BUFG, OSERDESE2 (8:1 DDR,
  TQ), ISERDESE2 (NETWORKING, IOBDELAY=IFD), IDELAYE2 (VARIABLE/VAR_LOAD), IDELAYCTRL
  (the packer replicates it per clock region), IOBUF/IOBUFDS/OBUFDS with
  SSTL135/DIFF_SSTL135 and IN_TERM UNTUNED_SPLIT_40 (nextpnr pack_io.cc, fasm.cc;
  prjxray-db segbits_riob33.db).
* **No OLOGIC CLKDIV in SING tiles.** prjxray's artix7 database has no
  segbits_rioi3_sing.db: RIOI3_SING has 71 ppips, with no OLOGIC CLKDIV route, against
  163 for RIOI3. An OSERDESE2 can't sit at the top or bottom IOB of a bank. On the Arty,
  cs_n (U8, IOB_X1Y0) and reset_n (K6, IOB_X1Y49) are such pins. nextpnr's own CI records
  the same failure for LiteX DDR on the Arty S7 (.github/workflows/demos.yml,
  litex-ddr-arty-s7). Workaround: both pins are driven from fabric flip-flops through
  plain OBUFs (the D1->OQ bypass is an `always` ppip there); cs_n is tied low.
* **INTERNAL_VREF is ignored** by nextpnr-xilinx (a warning), but it sets
  HCLK_IOI3.VREF.V_675_MV by itself for any bank with an SSTL input, so 0.675 V comes
  out right.
* ISERDESE2's CLKB: nextpnr folds an inverter on CLKB into IS_CLKB_INVERTED and writes no
  bit for it (the silicon inverts). X7.iserdes connects CLKB to CLK with
  IS_CLKB_INVERTED = 1, which comes to the same.
* yosys warns "Replacing floating point parameter ... with string" for PLLE2's
  CLKOUTk_PHASE (written 0.0, 90.0).

## Wiz's HDL (fixed on agent/hdl-prim, PR #240, unless marked open)

* There was no way to instantiate a vendor cell. Added Hw.prim, Hw.clock, Prim
  declarations, and the netlist/Verilog support (docs/libraries.md, H14 P1).
* One clock domain only. The PHY needs four clocks; the design keeps one domain, and the
  other three are clock nets between primitives. A generated wrapper (Clocking,
  Verilog.emitTop) holds the PLL and BUFGs.
* Pads are leaves that only buffers may touch, so a bus of pins can't be one port (cat on
  pads is a kind error). Each pin is its own port: ddr3_a_0 ... (Pads.t), and the XDC
  names them so.
* A structure built inside a step and used twice re-runs its wires. That's harmless with
  hash-consing, but a primitive is never shared, so its cells would be duplicated. Values
  holding primitives have to be let-bound `r` values (auto-share), not structures
  (Phy.io builds all sixteen DQs as one V.ofN value).

## The Wiz language (open)

* No numeric literal patterns in `match` (`| 0 => ...`: "invalid pattern (term.num)").
* A bundle with a field named `code` clashes with deriving Bundle's `S.code` ("'S.code'
  has already been declared").
* Structural recursion: a parameter before the colon must be passed unchanged; a function
  argument that shifts (`fun k => f (k + 1)`) has to move after the colon or become an
  offset.
* `light`'s 2 GB cap is too small to check the controller's modules (the model with its
  23-entry violation list); they need `heavy`.

## The design (risks)

* LiteDRAM's A7 arrangement (DQS on sys4x at 90 degrees, CK = 0xAA) puts DQS's first
  rising edge 0.25 tCK before CK's, which is the edge of JEDEC's tDQSS window
  (+-0.25 tCK). It works on this board under Vivado; there is no ODELAY in HR banks to
  move it.

## Wiz kernel/elaborator bug: auto-share picks an ill-kinded ShareLet instance (PANIC)

* `let b := base` where `base : St HwTy.El` (any bundle at values), with Hdl.Core
  imported, makes `wiz check` PANIC ("vApp: ill-typed application", Wiz.Core.Eval:455).
  Auto-share turns the `let` into `ShareLet.share`, and instance search accepts
  `ShareLet (r a) (r b)` with r := St, a := HwTy.El. That is ill-kinded, and nothing checks
  it. Minimal repro (Prelude only): /workspace/wiz-notes/bugs/autoshare-illkinded-panic.wiz.
  Reported to main.
* Workaround: `let ω b := …`, or no `let` (proofs/SchedProof.wiz projects `(SP.base).f`).
* Also: `SP.base.phase` (a field of a namespaced constant, written with dots) is "unknown
  identifier 'SP'"; `(SP.base).phase` works.

## Status (2026-11-12, stopped by the user: quota)

* D0 done (/workspace/wiz-notes/ddr3-design.md). D1 done: PR #240 (agent/hdl-prim), with
  a later fix: X7.iserdes let-binds its instance (it was built 8 times per DQ, which
  nextpnr rejected: two ISERDESE2 on one bel).
* D2 and D3a pass in compiled simulation (`.grail/bin/ddr3 sim`, `csim`). The controller
  against the behavioural model: 30000 cycles, 2576 ops, 0 mismatches, 38 refreshes, no
  JEDEC violation. Device variants calibrate as expected. The D5 write-back cache: 1135
  ops, 0 mismatches.
* D4 build: `ddr3 bit` synthesises and places (43 OSERDESE2, 16 ISERDESE2/IDELAYE2,
  IDELAYCTRL, PLL wrapper) but **fails timing: 22.5 MHz against 100 MHz**. The critical
  path is a linear chain of multiplexers from `U.select` (256-way map lookup, the UART
  message ROMs). The last commit makes `U.select` a balanced tree (log depth). That is
  **not yet simulated or rebuilt**: rerun `ddr3 sim 30000` and `ddr3 bit` first. Not
  loaded on the board (no board slot requested).
* D3b (proofs/SchedProof.wiz): the machine, monitor, BFS and soundness lemmas are
  written; the kernel check was still running when work stopped. D3c (`ddr3 vsim`, Icarus
  + Micron + unisims) is written but has not been run.
