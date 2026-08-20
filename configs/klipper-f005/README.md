# F005 host/config candidates

**MAINLINE REFERENCE HARDWARE VALIDATION COMPLETE**

These are project-authored configurations for the investigated
F005/GD32F303RET6 reference only. `printer-f005-mainline.cfg` is now a
hardware-validated reference baseline; it is not a universal calibration or a
recovery guarantee.

- `printer-f005-bringup.cfg` is the minimal first communication candidate:
  primary MCU, Cartesian rails, and the normal BLTouch object. It intentionally
  contains no motion, homing, heater, fan, TMC, or filament test workflow.
- `f005-runtime-passive.cfg` is the smaller no-pin/no-output Runtime gate used
  before the staged configurations.
- `printer-f005-mainline.cfg` is the validated first-mainline reference. It adds
  the stock-derived TMC2208 software UARTs, extruder, heaters and ordinary
  thermistors, fans, filament switch, safe Z homing, and 5x5 bed mesh.
- `stages/` contains the deliberately narrower Stage A--E reference
  configurations used by the published first-print reproduction runbook.

Both files were accepted by current upstream Klippy in dictionary/debugoutput
mode using the exact dictionary from the validated GD32F303 build. The full
mainline configuration was then exercised on the investigated reference through
the staged hardware bring-up and one complete PLA Benchy; details and scope are
in [`docs/f005-hardware-validation.md`](../../docs/f005-hardware-validation.md).
The bring-up file remains an offline/no-action parser candidate. The mainline
file's `z_offset` and PID values are reference calibration values, not universal
defaults; every other printer must calibrate independently.

The host MCU (`/tmp/klipper_host_mcu`) and ADXL345 (`spidev2.0`) are deferred
and are not required for first mainline bring-up. No vendor binaries, private
or unpublished device-calibration dumps, saved mesh, input-shaper values, or
Creality-only modules are included. The published reference `z_offset` and PID
values above are intentionally included and must not be copied blindly to a
different printer.

The fixed Klipper comparison basis is
`0499b30374315f2a9f49fc12808527fc7d0f5cfa`; the MCU port is documented in
[`docs/gd32f303-mainline-port.md`](../../docs/gd32f303-mainline-port.md).

Host-MCU/ADXL and input-shaper support remain deferred because they were not
needed for the validated first print. Creality PR-Touch/Z compensation remain
optional future reimplementation work.
