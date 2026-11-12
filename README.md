# wiz-ddr3

A DDR3 controller written in [Wiz](https://github.com/wiz-pl/wiz)'s hardware description
library, for the Digilent Arty A7-35T (XC7A35T-1CSG324C, one MT41K128M16JT-125: 256 MB
of DDR3L, x16), built with the open openXC7 flow. It needs Wiz with vendor primitives
(branch `agent/hdl-prim`, PR #240).

```
src/Ddr3/Timing.wiz   the timing record (MT41K128M16 at DDR3-800, 100 MHz, 4:1) and geometry
src/Ddr3/Ctrl.wiz     the controller: init FSM, read calibration, closed-page scheduler,
                      refresh, native port (valid/ready, 128-bit bursts, byte masks)
src/Ddr3/Phy.wiz      the Artix-7 PHY: OSERDESE2, ISERDESE2, IDELAYE2, IDELAYCTRL, I/O buffers
src/Ddr3/Model.wiz    a behavioural DDR3 device that checks every JEDEC timing constraint
src/Ddr3/Tb.wiz       the controller against the model, in lockstep with a reference memory
src/Ddr3/Memtest.wiz  the board design: memory test over all 256 MB, report over the UART
src/Ddr3/Board.wiz    the Arty's pins (XDC) and the PLL wrapper
app/ddr3.wiz          the flow driver: sim, gen, bit
```

Design notes: /workspace/wiz-notes/ddr3-design.md (the pinout, the PHY, the timings, the
calibration). Findings: FINDINGS.md.

## Configuration

LiteDRAM's A7DDRPHY arrangement: controller 100 MHz, 4:1, DDR3-800 (CL 6, CWL 5),
DLL on. Every DDR3 output but RESET# and CS# goes through an OSERDESE2 on sys4x (400 MHz).
DQS (sys4x at 90°) is written only. DQ is read through IDELAYE2 and ISERDESE2, and
calibration chooses an IDELAY tap and a bit slip per byte lane. Commands are issued in
phase 3 of a controller cycle, which puts write data at the start of the cycle after next.

## Micron's model

Micron's DDR3 Verilog model may be used for local simulation only (its licence forbids
redistribution). Put it in `micron/` (ignored by git) and never commit it.
