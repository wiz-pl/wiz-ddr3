# Interface for the SoC agent

This is the stable contract of `wiz-ddr3`. The SoC imports `wiz-ddr3` master (the
`Ddr3.*` modules) and should not need anything below the native port. The
diagnostic build is additive: `PortIn`, `PortOut`, `Ctrl.circuit`, `PhyIn`, `Dfi`
and the board top level keep their types.

## What to instantiate

| what | module | type |
|---|---|---|
| controller | `Ddr3.Ctrl` | `Ctrl.circuit (t : Timing) : Circuit (PortIn × PhyIn) (PortOut × Dfi)` |
| PHY | `Ddr3.Phy` | `Phy.io (c : PhyClk) (rst : Bit) (rstN : Bit) (d : Dfi) : Ddr3Pads × PhyIn` |
| timing record | `Ddr3.Timing` | `Timing.arty` (board), `Timing.sim` (simulation) |
| board top level | `Ddr3.Board` | `Board.memtestC t ab n`, `Board.memtestTrainC`, `Board.memtestMprC` |

Clocking (from `Ddr3.Board.clocking`): controller 100 MHz, `sys4x` 400 MHz,
`sys4xDqs` 400 MHz at 90°, `ref200` 200 MHz. `rst` is the SERDES reset
(assert for a few cycles after the PLL locks), `rstN` is DDR3 RESET# (comes from
the controller's `Dfi.rstN`, active low), `phy.rdy` is IDELAYCTRL's RDY.

## Native port (`Ddr3.Ctrl.PortIn` / `PortOut`)

```
PortIn  { valid, we, addr : B 24, wdata : B 128, wmask : B 16 }
PortOut { ready, rvalid, rdata : B 128,
          calDone, calFail, tap0, tap1 : B 5, slip0, slip1 : B 3,
          lat : B 5, map0, map1 : B 256, wshift : B 4 }
```

* A request is accepted when `valid && ready`. `we = 1` writes `wdata` with
  `wmask` (bit `b*2 + lane` = 1 means write that byte; `wmask = 0` writes all
  bytes).
* A read is answered later by one cycle of `rvalid` with `rdata`; there is one
  outstanding read at a time. Do not issue a new request until the read returns
  (or the write is accepted).
* Address: 24-bit burst address, row `[23:10]`, bank `[9:7]`, column `[6:0]`;
  one burst is 16 bytes, so `addr` is the burst number (`byte address >> 4`).
* `calDone = 1` means initialisation and calibration finished; service requests
  before that are ignored. `calFail = 1` means calibration found no usable
  window after all write shifts (the taps are left mid-bit for the DQ dump).
* `tap0/1`, `slip0/1`, `lat`, `map0/1`, `wshift` are the calibration result.
  `map0/1` bit `s*32 + t` is "slip `s` matched at IDELAY tap `t`".

## Training sequence to call

The controller runs the whole sequence by itself; the SoC only waits for
`calDone`/`calFail`. The default `Ctrl.circuit` does:

1. JEDEC reset/CKE/MRS/ZQ initialisation.
2. Written-pattern read calibration over tap 0..31 × slip 0..7, with up to nine
   write-shift retries.
3. Service.

Two diagnostic entry points exist, same `Circuit` type:

* `Ctrl.circuitTrain t` — the normal calibration **plus** the MPR read sweep
  (MR3 A2 on/off around it). Adds roughly 2k controller cycles before service.
  The MPR results are internal (`St.xm0/xm1`, `St.xro/xra`, `St.xDone/xFail`)
  and are reported by the board test, not on `PortOut`.
* `Ctrl.circuitMpr t` — MPR sweep only, for a board whose write path is suspect.
  The pass enters MPR (MR3 A2), reads, and sets MR3 back to `t.mr3` before
  service, so a normal timing record works and service is normal memory.
  `PortOut.calDone/tap/slip/lat` carry the MPR result and `map0/map1` the MPR
  maps in this build.

If the SoC wants the extra MPR check, use `Ctrl.circuitTrain` unchanged; if it
wants the plain, fastest bring-up, keep `Ctrl.circuit`. No register or port
change is required either way.

## Diagnostics / test harness

* In simulation: `ddr3 simtrain N` (written pattern, MPR, then traffic),
  `ddr3 mprsim N` (MPR only), `ddr3 sweep N` (the tap/slip table over several
  modelled devices). `ddr3 sim N` is the normal traffic test.
* On the board (Arty A7-35T, UART 115200 8N1): `ddr3 bittrain` / `ddr3 bitmpr`,
  program with `openFPGALoader -b arty_a7_35t build/a35t/memtest_*.bit`.
  Output lines: `DDR3 cal ...`, `M0/M1` (written-pattern maps), `X0/X1` (MPR
  maps), `xd/xf`, `R1/R0` (DQ bits ever high / never low), `S <or> <and>`
  (DQS probe), then the memory passes (`P0..P2 err=...`) or, in the MPR build,
  the `D0..DF` raw DQ/DQS dump.
* The hardware procedure and expected values are in `repro/README.md`.

## Stability

`PortIn`, `PortOut`, `Ctrl.circuit`, `Dfi`, `PhyIn`, `Timing`'s fields and
`Board.memtestC` do not change in this work. New fields on the internal state
`St`/`MSt` and new constructors (`Ctrl.circuitTrain`, `Ctrl.circuitMpr`,
`Board.memtestTrainC`, `Board.memtestMprC`) are additive. Import only upstream
`wiz-ddr3` master in the SoC; do not copy these modules.
