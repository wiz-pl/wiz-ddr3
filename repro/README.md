# Reproduction and hardware procedure

Everything here is for the Arty A7-35T with the MT41K128M16JT (256 MB) and the
openXC7 flow. Build the driver once with `repro/build.sh` (through `heavy`).

## Simulation (no hardware)

```sh
repro/build.sh
repro/sim.sh 50000
repro/sweep.sh
```

* `ddr3 sim 30000` — the controller against the model: written-pattern
  calibration, traffic, JEDEC checks.
* `ddr3 simtrain 50000` — the same, then the MPR read sweep, then traffic.
  The log has `MPR done=1 fail=0`, `X0/X1` (MPR maps), `XRO/XRA` (DQ activity)
  and `DQS seen high/never low`.
* `ddr3 mprsim 50000` — MPR only: no written pattern, the read path alone.
  Expect `calDone=1`, `calFail=0`, `MPR done=1`, a plausible tap/slip, and no
  JEDEC violation (the MPR reads must not be preceded by ACT/PRE and no REF may
  occur while MPR is on; the pass leaves MPR before service).
* `ddr3 sweep 30000` — the tap/slip table for five modelled devices (default,
  early, late, narrow eye, dead lane 0). Each row is `s0..s7` × 32 taps
  (`#` = the pattern matched at that slip and IDELAY tap). This is the
  read-sampling sweep: a healthy lane shows one contiguous run whose centre is
  the chosen tap; a dead lane shows none and `calFail=1`.

## Bitstreams

```sh
repro/bitstream.sh
```

writes `build/a35t/memtest.bit` (normal), `memtest_train.bit` (normal + MPR)
and `memtest_mpr.bit` (MPR only). The UART is 115200 8N1 on the Arty's FT2232
(`/dev/ttyUSB1` on Linux).

## Board procedure (not run here: hardware access not authorised for this task)

1. Program SRAM only:
   `openFPGALoader -b arty_a7_35t build/a35t/memtest_train.bit`.
2. Open the UART at 115200 and reset the board. The first line is
   `DDR3 cal done=1 fail=0 tap0=.. slip0=.. tap1=.. slip1=.. lat=.. w=..`,
   followed by `M0`/`M1` (written-pattern maps) and `X0`/`X1` (MPR maps),
   `xd`/`xf` (`xd=1`: the MPR sweep ran; `xf=0`: it found a run), `R1`/`R0`
   (DQ bits ever high / never low), `S <or> <and>` (DQS ever high / never low).
3. Then `P0`/`P1`/`P2` lines report the 256 MB passes: `err=` must reach 0 and
   stay 0; `cyc=` should match about 0x1563xxxx (the 3.59 s per two passes at
   100 MHz quoted in FINDINGS.md).
4. For a write-path failure (normal calibration `calFail=1`, `M0/M1` empty but
   `X0/X1` show a run and `xd=1 xf=0`), program `memtest_mpr.bit`. It prints the
   same calibration header with the MPR result in `M0/M1`/`X0/X1`, then a
   `D0..DF` dump: sixteen cycles around a normal write and its read-back (the MPR
   pass has already left MPR, so this is the ordinary DQ/DQS eye). `R1` (recorded
   during the MPR pass) should be all ones on a live lane and `R0` zero;
   `S` should show `1/0`.
   * MPR map with a contiguous 14-tap run → the read path (IDELAY taps, ISERDES,
     DQ pins) is good; the fault is in the write path (DQS/CK/write shift).
   * MPR map empty or only one tap → read sampling; sweep more taps/slips or
     check `dlyLd`/IDELAYCTRL (`rdy`).

Record the header and the D-lines in `/tmp/ddr3-hw.log`; then the simulation can
be compared with the same `tap0/tap1/slip/lat` numbers.

## What has and has not been run

* Simulation: `ddr3 sim`, `simtrain`, `mprsim`, `sweep` (see `/tmp/ddr3-*.log`).
* Hardware: the bitstreams build, but no board was programmed in this task
  (the machine's hardware rules require an explicit authorisation; only the
  iCEstick is attached, and this design targets the Arty A7-35T). The procedure
  above is the remaining step.
