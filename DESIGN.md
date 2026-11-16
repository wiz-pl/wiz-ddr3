# Design: the DDR3 controller

This file is the short in-tree design note. The long version (pinout, toolchain
findings, risk list, timing table) is `/workspace/wiz-notes/ddr3-design.md`; the
bring-up history is `FINDINGS.md`.

## Blocks and clocking

```
                 native port (PortIn/PortOut)            Dfi
  SoC / test  ──────────────────────────────▶ Ctrl ──────────────▶ Phy ──▶ DDR3 pads
                                                   ▲                 │
                                                   └── PhyIn ────────┘
```

* `Ddr3.Ctrl` is one 100 MHz clock domain and contains everything the controller
  does: the JEDEC initialisation FSM, the read/write calibration FSMs, the
  closed-page scheduler and refresh. It has no vendor primitives, so it runs at
  values in Wiz and as an emitted netlist.
* `Ddr3.Phy` is the Artix-7 PHY (LiteDRAM's A7DDRPHY arrangement): 4:1 DDR,
  OSERDESE2 on sys4x (400 MHz) for every output but RESET#/CS#, DQ read through
  IDELAYE2 + ISERDESE2, DQS written only.
* `Ddr3.Board` is the Arty A7-35T top level (PLL wrapper, XDC) and the UART
  memory test.
* `Ddr3.Model` is a behavioural DDR3 that checks the JEDEC timing record and can
  model read latency, bit offset, IDELAY tap windows and MPR mode.

One controller cycle is four memory clocks (DDR3-800, tCK = 2.5 ns). A BL8 burst
is 128 bits: bit `b*16 + j` is beat `b` on DQ `j`. A native burst address is 24
bits: row `[23:10]`, bank `[9:7]`, column `[6:0]`.

## Init and calibration

1. RESET# low, CKE low, CKE high, MRS MR2/MR3/MR1/MR0, ZQCL (JEDEC order).
2. **Written-pattern calibration** (the normal build, `Ctrl.circuit`):
   write one known burst to address 0, then for each IDELAY tap 0..31 read it
   back and compare at each of the eight bit slips. The map is
   `bit s*32 + t` (slip `s`, tap `t`). Each lane takes the slip with the longest
   run of good taps and the middle tap of that run. If it fails, the controller
   tries the nine write shifts (in half memory clocks) and repeats.
3. The results are on `PortOut`: `calDone`, `calFail`, `tap0/1`, `slip0/1`,
   `lat`, `map0/1` and `wshift`. Service starts after `calDone`.

## MPR mode (diagnostic, splits read from write)

DDR3's multipurpose register (MR3 A2 = 1, A1:A0 = 00) returns `01010101` on
every DQ for every read; writes are ignored and a read needs no open page. It is
therefore a read-path test with the write path out of the picture.

`Ctrl.circuitTrain t` runs the normal written-pattern calibration and then an
MPR pass: MRS MR3 = 4, a read-only tap × slip sweep with the MPR word as the
expected data, MRS MR3 back to `t.mr3`. The MPR map lands in `St.xm0/xm1` and
the raw OR/AND of every DQ bit in `St.xro/xra`. The MPR pattern only determines
the slip parity (0101 is unchanged by a two-bit shift), so its map calibrates
the tap window but not the exact slip; the written pattern still picks the final
slip. `Ctrl.circuitMpr t` skips the written pattern entirely (a read-path-only
build); it enters MPR, sweeps, and sets MR3 back to `t.mr3` (clear) before
service, so any normal timing record works.

The board build selects these with `ddr3 gentrain`/`bittrain` and
`ddr3 genmpr`/`bitmpr`; the UART report carries the normal maps `M0/M1`, the MPR
maps `X0/X1`, `xd`/`xf`, the DQ activity `R1/R0` and the DQS probe `S`.

## Public interface

See `docs/soc-interface.md`. The stable interface is `PortIn`, `PortOut`,
`Ctrl.circuit`, the `PhyIn`/`Dfi` bundles and the board top level; diagnostic
additions are separate constructors and do not change those types.
