# F005 mainline host/config milestone

**OFFLINE HOST/CONFIG INTEGRATION COMPLETE**
**PRIMARY MCU PASSIVE RUNTIME CONFIG/FINALIZE: PASS**
**NOT READY FOR PRINTING**

This document describes the investigated F005/GD32F303RET6 reference only. It
does not claim support for every Ender-3 V3 KE revision. The fixed upstream
basis is Klipper commit
`0499b30374315f2a9f49fc12808527fc7d0f5cfa`, together with the small GD32F303
port documented in [`gd32f303-mainline-port.md`](gd32f303-mainline-port.md).

## Offline result

Two project-authored candidates are published under
[`configs/klipper-f005/`](../configs/klipper-f005/): a minimal first-bring-up
configuration and a first-mainline target configuration. Both were run through
Klipper's own `scripts/test_klippy.py` in debugoutput/dictionary mode with the
exact dictionary from the final GD32F303 build. The dictionary identifies the
MCU as `gd32f303xe`, uses a 120 MHz clock, and models PA3/PA2 at 230400 baud;
Klippy loaded 88 commands.

The offline run reported no unknown sections, options, or pins and no missing
MCU commands. It used no serial, USB, printer, or other hardware device and
executed no G-code. “Accepted by current upstream Klippy and the built MCU
dictionary” means only that the configuration parses and its command surface
is present. It is not electrical or mechanical validation and is not a flash
authorization.

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

The BLTouch uses sensor PC14, control PC13, and offsets X=0/Y=27. `z_offset: 0`
in both candidates is a neutral value required for parsing, not a transferred
calibration; it must be measured on the actual printer before homing or
printing. The bed uses PB2/PC4 and the hotend PA1/PC5. The vendor
`temp_offset_flag` is intentionally omitted, so bed-temperature accuracy and
all heater behavior remain hardware-open; no heater test is part of this
milestone.

Private PID values, pressure-advance values, saved mesh, input-shaper values,
and other device-specific calibration are intentionally not published.

The first minimal bring-up is deliberately limited to primary-MCU
communication configuration, printer limits, the three rails, and BLTouch
object loading. It excludes host-MCU/ADXL, heaters, fans, filament, TMC, mesh,
`safe_z_home`, macros, and any motion, homing, probing, or calibration actions.
The required rail/endstop and `probe:z_virtual_endstop` definitions are present
for configuration loading; no action is issued by this file. The target
candidate is still only a configuration surface, not a known-working printer
configuration.

The mainline candidate currently uses `control: watermark` for both heaters.
This is an offline-validation candidate value after private PID/calibration
values were removed; it is not a hardware-validated heater-control decision and
must be validated and recalibrated before any heating test.

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

Any separately approved hardware work would need to establish, in order,
passive thermistor plausibility, endstop and BLTouch polarity/behavior, TMC
communication, bounded movement and homing,
Z-offset calibration, fan polarity, and only later heater behavior and bed
temperature accuracy. UART behavior, ADC readings, endstop polarity, BLTouch
behavior, TMC communication, direction/movement, homing, fan polarity, and
heating are therefore not claims made by these files.

This milestone does not satisfy Gate 1 or Gate 2 and does not make flashing
safe. No vendor firmware, binary, saved device calibration, private path, or
device identity data is redistributed.
