# F005 mainline pin matrix

This matrix is a sanitized, project-authored summary for the investigated
F005/GD32F303RET6 reference. It records configuration evidence, not electrical
validation. “Communication configuration only” means that loading a Klipper
dictionary does not test the physical pin.

| Function | F005 pin | Mainline candidate | Evidence/source class | Hardware validation status |
| --- | --- | --- | --- | --- |
| X step | PC2 | PC2 | Reference F005 configuration | Not validated; no motion in first test |
| X dir | !PB9 | !PB9 | Reference F005 configuration | Not validated; no motion in first test |
| X enable | !PC3 | !PC3 | Reference F005 configuration | Not validated; shared active-low enable |
| X endstop | !PA5 | !PA5 | Reference F005 configuration | Manual endstop validation pending |
| Y step | PB8 | PB8 | Reference F005 configuration | Not validated; no motion in first test |
| Y dir | PB7 | PB7 | Reference F005 configuration | Not validated; no motion in first test |
| Y enable | !PC3 | !PC3 | Reference F005 configuration | Not validated; shared active-low enable |
| Y endstop | !PA6 | !PA6 | Reference F005 configuration | Manual endstop validation pending |
| Z step | PB6 | PB6 | Reference F005 configuration | Not validated; no motion in first test |
| Z dir | !PB5 | !PB5 | Reference F005 configuration | Not validated; no motion in first test |
| Z enable | !PC3 | !PC3 | Reference F005 configuration | Not validated; shared active-low enable |
| Z endstop/probe | `probe:z_virtual_endstop` | `probe:z_virtual_endstop` | Reference F005 configuration | BLTouch and homing validation pending |
| Extruder step | PB4 | PB4 | Reference F005 configuration | Not validated; no extrusion command |
| Extruder dir | PB3 | PB3 | Reference F005 configuration | Not validated; no extrusion command |
| Extruder enable | !PC3 | !PC3 | Reference F005 configuration | Not validated; shared active-low enable |
| TMC UART X | PB12 | PB12 | Reference F005 configuration; dictionary command surface | TMC communication pending |
| TMC UART Y | PB13 | PB13 | Reference F005 configuration; dictionary command surface | TMC communication pending |
| TMC UART Z | PB14 | PB14 | Reference F005 configuration; dictionary command surface | TMC communication pending |
| Hotend heater | PA1 | PA1 | Reference F005 configuration | No heater test; behavior pending |
| Hotend thermistor | PC5 | PC5 | Reference F005 configuration; upstream EPCOS support | Ambient ADC plausibility pending |
| Bed heater | PB2 | PB2 | Reference F005 configuration | No heater test; behavior pending |
| Bed thermistor | PC4 | PC4 | Reference F005 configuration; upstream EPCOS support | Ambient ADC plausibility and accuracy pending |
| BLTouch sensor | PC14 | PC14 | Reference F005 configuration; normal upstream probe | Polarity/behavior pending |
| BLTouch control | PC13 | PC13 | Reference F005 configuration; normal upstream probe | Polarity/behavior pending; Z offset must be calibrated |
| Filament sensor | !PC15 | !PC15 | Reference F005 configuration; upstream switch object | Manual input validation pending |
| Part cooling fan | PA0 | PA0 | Reference F005 configuration; upstream `[fan]` | No fan test; polarity/behavior pending |
| Hotend fan | PC1 | PC1 | Reference F005 configuration; upstream `[heater_fan]` | No fan test; polarity/behavior pending |
| Mainboard fan | !PB1 | !PB1 | Reference F005 configuration; upstream `[output_pin]` | No fan test; automatic policy not inferred |

No saved Z offset, bed mesh, input-shaper value, PID value, private path, or
device identity is included. The public configuration's `z_offset: 0` is a
neutral parse placeholder and is not a calibration.
