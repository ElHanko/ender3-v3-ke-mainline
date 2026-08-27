# F005/GD32F303 reference hardware validation

This report records one controlled validation sequence on the investigated
Ender-3 V3 KE F005 board with GD32F303RET6, using upstream Klipper commit
`0499b30374315f2a9f49fc12808527fc7d0f5cfa` and the project F005 port. It is a
reference-system result, not a guarantee for other KE revisions or a substitute
for independent calibration.

## MCU and host contract

The Mainline MCU identified as `gd32f303xe` at 120 MHz over `/dev/ttyS1` at
230400 baud. The intended architecture is:

```text
X2000 host / print computer
    -> UART 230400
Mainline F005 / GD32F303 MCU
    -> validated printer hardware
```

Only the main MCU and the existing host runtime were required. A separate
nozzle-MCU instance, Creality PR-Touch modules, or the private PTY feeder are
not part of the production architecture. The feeder was temporary test
scaffolding and accepted only a sanitized G-code stream after removing
unsupported slicer/UI commands (`EXCLUDE_OBJECT_*`,
`SET_GCODE_VARIABLE MACRO=PRINTER_PARAM`, `ACCEL_TO_DECEL`, and `M73`).

## Staged results

The following results are from the single staged bring-up sequence. Commands
were issued only within their stated gate.

| Stage | Result | Observed scope |
| --- | --- | --- |
| A | PASS | PC5 hotend and PC4 bed thermistors returned plausible passive readings. |
| B | PASS | TMC2208 X/Y/Z communication; IFCNT reached 6; X/Y endstops; bounded X/Y/Z motion and direction; positive Z moved physically upward. |
| C | PASS | BLTouch deploy, retract, query, deliberate manual trigger, XYZ homing, and `PROBE_CALIBRATE`. |
| D | PASS | Part fan, hotend heater/sensor, bed heater/sensor, temperature-controlled hotend fan, and mainboard-fan command path. |
| E | PASS | Filament detected, `M109 S240`, and 50 mm controlled hot extrusion. |
| F | PASS after one controlled retry | Full configuration, G28, heated 5x5 mesh, and complete PLA Benchy. |

Stage C produced a reference `PROBE_CALIBRATE` result of 1.800 mm while the
session's homing origin was `-0.100`. In the pinned upstream Klipper semantics,
`Z_OFFSET_APPLY_PROBE` computes the permanent value as
`z_offset - homing_origin.z`; the corresponding value in the public reference
configuration is therefore `z_offset: 1.900`. This is not a universal value:
every other printer must perform its own probe calibration.

The validated reference bed-mesh settings are speed 350, bounds
`5,10` to `215,215`, 5x5 points, fade start 1, fade end 10, fade target 0, and
horizontal move height 8. The observed contact values ranged from -0.1625 to
+0.3200; these are measurements from this run, not a universal mesh.

The reference PID baseline used by the successful run is:

```text
extruder:   Kp=20.584  Ki=1.737  Kd=60.981
heater_bed: Kp=70.652  Ki=1.798  Kd=694.157
```

These values are derived from known F005/Creality configuration evidence and
were exercised during the run. They are reference values only; PID refinement
and recalibration remain appropriate if hardware or sensor conditions differ.

## Complete print

One complete PLA Benchy was printed with bed 55 °C and hotend 220 °C. The
archived run started at `2026-08-20 21:50:25` local time and completed at
`22:38:46` (about 48 minutes 21 seconds), processing more than 128,000
G-code commands. It included G28 and a heated 5x5 bed mesh. Heaters, fans,
extrusion, motion, and the filament path all operated during the print. The
end commands set both heater targets to zero.

The hotend briefly overshot to approximately 224.5 °C before settling. No MCU
shutdown, communication failure, lost step, layer shift, or command error was
observed during the successful print. The result was a complete, usable
Benchy. The overshoot is a future PID-refinement item, not a Phase-2 blocker.

## One startup shutdown and retry

During the first full-configuration finalization, Klipper reported one
`Timer too close` MCU shutdown. The archived host evidence contains no concrete
overload diagnosis. The shutdown was cleared by exactly one controlled MCU
reset, followed by one deliberate manual retry; the retry completed the full
validation and print successfully. This event is retained as an observed
runtime fact, not hidden as a clean first attempt and not treated as an
unresolved project blocker.

## Scope and boundaries

This demonstrates the required first-print hardware surface on the investigated
reference: the upstream MCU port, the primary UART, thermistors, TMC2208
software UART, endstops, motion, BLTouch/probe, homing, mesh, heaters, fans,
filament sensing, extrusion, and a complete print.

The following remain outside this milestone: Host-MCU/ADXL and input shaping,
Creality PR-Touch and `z_compensate`, automatic nozzle/pressure calibration,
vendor UI/cloud integration, and any persistent recovery or rollback claim.
PR-Touch/Z compensation are optional future open reimplementation work, not
required for the validated first print.

Gate 1 / Point of Return is **SATISFIED** by the current evidence review. The
vendor recovery path is documented and the Boot-ROM entry is known, but
destructive recovery and a complete return to Stock have not been personally
rehearsed on this device. The recovery route is not guaranteed, and this report
does not authorize persistent work.

For the Stock F005 MCU specifically, the software return to the retained
Creality bootloader is now **QUALIFIED ON DEVICE**. On 2026-08-27 an authorized
no-write test used `FIRMWARE_RESTART`, released `/dev/ttyS1`, successfully
completed the Creality bootloader handshake and version query, then used
`mcu_util -s` to return to the unchanged Mainline application. Stock Klipper
subsequently reconnected and reproduced the same known `read_swap_prtouch`
protocol error. No erase or firmware upload occurred.

The complete result is therefore **MAINLINE F005 MCU -> ORIGINAL STOCK F005
MCU FIRMWARE RETURN: QUALIFIED ON DEVICE**. On 2026-08-27 the preserved Stock
image was written exactly once through the qualified bootloader path.
`mcu_util` returned success and `app_run`; Stock Klipper then loaded the
original 116-command MCU firmware and reached `Printer is ready`.
