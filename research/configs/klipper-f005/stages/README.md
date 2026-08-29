# Phase-2 staged reference configurations

These project-authored files reconstruct the smallest Stage A--E configuration
surface used for the validated F005/GD32F303RET6 reference bring-up. They are
not a universal printer configuration and each later stage assumes that the
previous stage passed.

Use them only with the procedure in
[`docs/f005-first-print-reproduction.md`](../../../docs/f005-first-print-reproduction.md).
Stage F uses the validated
[`printer-f005-mainline.cfg`](../../../../configs/klipper-f005/printer-f005-mainline.cfg) baseline instead.

`stage-d-fans-heaters.cfg` intentionally records the historical staged
`watermark` candidate. It is not the final heater-control choice; the validated
Stage-F baseline uses the reference PID values in
`../../../../configs/klipper-f005/printer-f005-mainline.cfg`.
