# F005 mainline host/config milestone

**HOST/CONFIG AND FIRST-PRINT VALIDATION COMPLETE**
**PRIMARY MCU PASSIVE RUNTIME CONFIG/FINALIZE: PASS**
**REFERENCE F005 PRINT: PASS**

This document describes the investigated F005/GD32F303RET6 reference only. It
does not claim support for every Ender-3 V3 KE revision. The fixed upstream
basis is Klipper commit
`0499b30374315f2a9f49fc12808527fc7d0f5cfa`, together with the small GD32F303
port documented in [`gd32f303-mainline-port.md`](gd32f303-mainline-port.md).

## Offline and hardware result

The current project-authored mainline configuration is published under
[`configs/klipper-f005/`](../configs/klipper-f005/). The historical minimal
first-bring-up candidate and staged candidates remain under
[`research/configs/klipper-f005/`](../research/configs/klipper-f005/) and were
used for the earlier offline validation. The current configuration was run
through Klipper's own `scripts/test_klippy.py` in debugoutput/dictionary mode
with the exact dictionary from the final GD32F303 build. The dictionary
identifies the MCU as `gd32f303xe`, uses a 120 MHz clock, and models PA3/PA2 at
230400 baud; Klippy loaded 88 commands.

The offline run reported no unknown sections, options, or pins and no missing
MCU commands. The complete mainline configuration was subsequently validated
on the investigated reference through the staged bring-up and one complete
PLA Benchy. The evidence and exact validation boundary are in
[`f005-hardware-validation.md`](f005-hardware-validation.md).

## Passive MCU runtime result

After the separate controlled F005 MCU flash and identify validation, a single
passive Mainline Klippy runtime test completed on the investigated reference
system with exit code `0`. It used `kinematics: none` at `/dev/ttyS1`, 230400
baud, loaded the real `gd32f303xe` dictionary, completed ClockSync, and sent
`allocate_oids count=0` followed by `finalize_config`. The MCU then reported
`is_config=1` and `is_shutdown=0`, and Klippy exited cleanly through the
`/dev/null` EOF path without a firmware restart.

The initial `get_config` response was not separately printed. The reviewed
private gate requires `is_config=0` and `is_shutdown=0` before configuration
send; reaching the configuration-send line proves that this gate allowed the
observed run. The pinned code registers `/dev/null` input only after READY, so
the clean EOF exit also establishes that READY was reached.

This establishes **MAINLINE KLIPPY ↔ MAINLINE F005 MCU PASSIVE RUNTIME
CONFIG/FINALIZE: PASS**. It does not validate printer peripherals or printing.

## First-mainline hardware surface

The first-mainline target retains the ordinary upstream paths for Cartesian
X/Y/Z, the extruder, TMC2208 software UART, physical X/Y endstops, BLTouch and
`probe:z_virtual_endstop`, `safe_z_home`, 5x5 `bed_mesh`, hotend and bed heaters
with EPCOS 100K B57560G104F thermistors, part/hotend/mainboard fans, and the
filament switch. The pin mapping is listed in
[`f005-pin-matrix.md`](f005-pin-matrix.md).

The BLTouch uses sensor PC14, control PC13, and offsets X=0/Y=27. The tracked
`z_offset: 2.180` is **QUALIFIED ON DEVICE** for this reference device by the
2026-08-29 cold paper test and successful Fre3nder-B repeat print. The
historical Phase-2 print value was 1.900, calculated from a 1.800
`PROBE_CALIBRATE` result and `homing_origin.z=-0.100`; it is **WIDERLEGT as the
current reference value**. Other printers must calibrate independently. The bed
uses PB2/PC4 and the hotend PA1/PC5. The vendor `temp_offset_flag` is
intentionally omitted.

The reference PID baselines are now published in the mainline configuration
because they were exercised during the controlled bring-up and print:
extruder Kp 20.584 / Ki 1.737 / Kd 60.981 and bed Kp 70.652 / Ki 1.798 /
Kd 694.157. They are reference values, not universal calibration. Pressure
advance and input-shaper values remain intentionally absent.

The minimal bring-up remains deliberately limited to primary-MCU
communication configuration, printer limits, the three rails, and BLTouch
object loading. It excludes host-MCU/ADXL, heaters, fans, filament, TMC, mesh,
`safe_z_home`, macros, and any motion, homing, probing, or calibration actions.
The required rail/endstop and `probe:z_virtual_endstop` definitions are present
for configuration loading; no action is issued by this file. It remains a
deliberately limited no-action bring-up surface. The separate full mainline
reference configuration is hardware validated on the investigated board.

The mainline reference uses PID control with the values listed above. Heater
behavior was exercised in the controlled bring-up and complete print; PID
refinement remains a future calibration task and these values must not be
treated as universal.

## Removed or deferred Creality surface

The first mainline milestone does not carry `prtouch_v2`, `z_compensate`,
`bl24c16f`, `hx711s`, `dirzctl`, `filter`, `soft_homing`, or `fan_feedback`.
Creality custom macro/tool/metadata integration, UI/cloud coupling, the
nozzle-MCU path, `temperature_sensor mcu_temp`, `temp_offset_flag`, saved
calibration, and macros dependent on those objects are also omitted. PR-Touch
and Z compensation remain optional future open reimplementation work, not a
first-mainline dependency.

The stock host side uses `[mcu rpi] serial: /tmp/klipper_host_mcu` and an
ADXL345 on `spidev2.0`. This is **DEFERRED - NOT REQUIRED FOR FIRST MAINLINE
BRING-UP**; it is neither ported nor hardware validated here.

## What remains open

The staged reference validation established passive thermistors, TMC2208
communication, X/Y endstops, X/Y/Z motion and direction, BLTouch deploy/retract
and probing, XYZ homing, both heaters and thermistors, fans, filament sensing,
50 mm hot extrusion, and a complete heated 5x5-mesh PLA Benchy. Exact scope,
one recoverable Timer-too-close startup shutdown, and remaining calibration
limits are recorded in [`f005-hardware-validation.md`](f005-hardware-validation.md).

This milestone alone does not establish Gate 1 and does not make persistent
recovery or flashing safe. Gate 1 is separately satisfied by the current
evidence review; recovery execution remains documented but not personally
rehearsed. Gate 2 is addressed for the required first-print behavior by
using upstream/keep/drop/deferred classifications; optional Creality
PR-Touch/Z-compensation remains future reimplementation work. No vendor
firmware, binary, private path, or device identity data is redistributed.
