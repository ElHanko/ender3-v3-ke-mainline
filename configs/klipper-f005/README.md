# F005 host/config candidates

**OFFLINE VALIDATION CANDIDATE**
**NOT HARDWARE VALIDATED**
**NOT READY FOR PRINTING**
**NOT READY TO FLASH**

These are project-authored configuration candidates for the investigated
F005/GD32F303RET6 reference only. They are not a known-working `printer.cfg`.

- `printer-f005-bringup.cfg` is the minimal first communication candidate:
  primary MCU, Cartesian rails, and the normal BLTouch object. It intentionally
  contains no motion, homing, heater, fan, TMC, or filament test workflow.
- `printer-f005-mainline.cfg` is the first-mainline target candidate. It adds
  the stock-derived TMC2208 software UARTs, extruder, heaters and ordinary
  thermistors, fans, filament switch, safe Z homing, and 5x5 bed mesh.

Both files were accepted by current upstream Klippy in dictionary/debugoutput
mode using the exact dictionary from the validated GD32F303 build. That test
establishes parser and command-surface compatibility only; it does not prove
UART, pin polarity, movement, probing, heating, temperature accuracy, or fan
behavior. The `z_offset: 0` values are neutral parse placeholders and must be
calibrated on the actual printer before homing or printing.

The host MCU (`/tmp/klipper_host_mcu`) and ADXL345 (`spidev2.0`) are deferred
and are not required for first mainline bring-up. No vendor binaries,
calibration values, saved mesh, or Creality-only modules are included.

The fixed Klipper comparison basis is
`0499b30374315f2a9f49fc12808527fc7d0f5cfa`; the MCU port is documented in
[`docs/gd32f303-mainline-port.md`](../../docs/gd32f303-mainline-port.md).
