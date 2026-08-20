# F005 mainline pin matrix

This matrix is a sanitized, project-authored summary for the investigated
F005/GD32F303RET6 reference. It records configuration evidence and the staged
hardware validation in [`f005-hardware-validation.md`](f005-hardware-validation.md).
Statuses apply only to that reference board; they are not universal support
claims.

| Function | F005 pin | Mainline candidate | Evidence/source class | Hardware validation status |
| --- | --- | --- | --- | --- |
| X step | PC2 | PC2 | Reference F005 configuration | Validated in bounded motion on reference |
| X dir | !PB9 | !PB9 | Reference F005 configuration | Validated in bounded motion on reference |
| X enable | !PC3 | !PC3 | Reference F005 configuration | Validated; shared active-low enable |
| X endstop | !PA5 | !PA5 | Reference F005 configuration | Validated on reference |
| Y step | PB8 | PB8 | Reference F005 configuration | Validated in bounded motion on reference |
| Y dir | PB7 | PB7 | Reference F005 configuration | Validated in bounded motion on reference |
| Y enable | !PC3 | !PC3 | Reference F005 configuration | Validated; shared active-low enable |
| Y endstop | !PA6 | !PA6 | Reference F005 configuration | Validated on reference |
| Z step | PB6 | PB6 | Reference F005 configuration | Validated in bounded motion on reference |
| Z dir | !PB5 | !PB5 | Reference F005 configuration | Validated; positive Z moved upward |
| Z enable | !PC3 | !PC3 | Reference F005 configuration | Validated; shared active-low enable |
| Z endstop/probe | `probe:z_virtual_endstop` | `probe:z_virtual_endstop` | Reference F005 configuration | BLTouch and XYZ homing validated on reference |
| Extruder step | PB4 | PB4 | Reference F005 configuration | Validated by controlled extrusion on reference |
| Extruder dir | PB3 | PB3 | Reference F005 configuration | Validated by controlled extrusion on reference |
| Extruder enable | !PC3 | !PC3 | Reference F005 configuration | Validated; shared active-low enable |
| TMC UART X | PB12 | PB12 | Reference F005 configuration; dictionary command surface | TMC2208 communication validated; IFCNT 6 |
| TMC UART Y | PB13 | PB13 | Reference F005 configuration; dictionary command surface | TMC2208 communication validated; IFCNT 6 |
| TMC UART Z | PB14 | PB14 | Reference F005 configuration; dictionary command surface | TMC2208 communication validated; IFCNT 6 |
| Hotend heater | PA1 | PA1 | Reference F005 configuration | Heater path validated in bring-up and print |
| Hotend thermistor | PC5 | PC5 | Reference F005 configuration; upstream EPCOS support | Passive reading and heated control validated |
| Bed heater | PB2 | PB2 | Reference F005 configuration | Heater path validated in bring-up and print |
| Bed thermistor | PC4 | PC4 | Reference F005 configuration; upstream EPCOS support | Passive reading and heated control validated |
| BLTouch sensor | PC14 | PC14 | Reference F005 configuration; normal upstream probe | Deploy/retract/query/trigger validated on reference |
| BLTouch control | PC13 | PC13 | Reference F005 configuration; normal upstream probe | Homing/probing validated; reference Z offset is 1.900 |
| Filament sensor | !PC15 | !PC15 | Reference F005 configuration; upstream switch object | Filament detected during controlled extrusion/print |
| Part cooling fan | PA0 | PA0 | Reference F005 configuration; upstream `[fan]` | Command path validated during print |
| Hotend fan | PC1 | PC1 | Reference F005 configuration; upstream `[heater_fan]` | Temperature-controlled path validated |
| Mainboard fan | !PB1 | !PB1 | Reference F005 configuration; upstream `[output_pin]` | Command path validated on reference |

The public reference configuration records `z_offset: 1.900` and the reference
PID baselines because they were exercised in the controlled bring-up and print.
The value is not universal; independent calibration remains required. Mesh
measurements, input-shaper values, private paths, and device identity are not
included.
