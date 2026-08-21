# Open X2000 host architecture

## Decision

Phase 3 uses the selected target: **complete open X2000 host replacement**.
The target is an embedded appliance, not a general-purpose Linux distribution.
It replaces the Creality Linux/application stack while preserving a
stock-compatible recovery boundary as a design constraint.

```text
X2000 BootROM / stock-compatible lower boot boundary
        |
        v
LTS-oriented Linux kernel + board Device Tree
        |
        v
minimal Buildroot root filesystem
        |
        +-- network and SSH
        +-- upstream Klipper -> /dev/ttyS1 -> Mainline F005
        +-- upstream Moonraker -> open Web UI
        +-- touchscreen UI
        +-- V4L2 camera -> open streamer
        +-- upstream Linux Host MCU -> ADXL345 / Input Shaper
        `-- controlled image-based updates
```

This target does not require preserving Creality UI services, WebRTC,
AI middleware, `cam_app`, or proprietary binary extensions. It requires their
needed printer-facing functions to have open replacements.

## Status of the architecture

- `PROVEN`: a reference-system observation or offline capture directly
  establishes the component/interface.
- `TARGET`: selected architecture, not yet implemented.
- `LIKELY`: an open path is technically indicated but needs Phase-3.2 kernel/DT
  feasibility evidence.
- `UNKNOWN`: required property not established.
- `DEFERRED`: not needed to make the Phase-3.2 decision now.

| Area | Status | Architecture consequence |
| --- | --- | --- |
| Main F005 path | PROVEN | Mainline Klipper communicates with the investigated F005 over `/dev/ttyS1` at 230400. Retain this contract; do not redesign it in Phase 3. |
| X2000 CPU, RAM, eMMC | PROVEN | An X2000 Linux appliance is the hardware target; Phase 3.2 selected the Ingenic Linux 6.6.18 X2000 SDK source basis. |
| Lower boot chain | LIKELY | Preserve the existing pre-p1 loader boundary unless evidence requires replacement. Exact normal BootROM/SPL/U-Boot handoff remains UNKNOWN. |
| LTS kernel + DT | TARGET | Phase 3.2 selected the pinned Ingenic Linux 6.6.18 X2000 SDK mirror as source basis. A project-authored KE DTS and a minimal, attributed patch series remain Phase 3.3 work. |
| Minimal Buildroot root filesystem | TARGET | Immutable system image and narrowly scoped services, with configuration/persistent data separate from it. |
| Network/SSH | TARGET | WLAN is REQUIRED; stock SDIO/firmware details are VENDOR-DEPENDENT. Ethernet is not a requirement without a demonstrated physical path. |
| Display/touch | LIKELY | The NS2009/I2C endpoint and stock framebuffers are observed. The selected SDK plus NebulaOS prior art provide bounded panel and GPL NS2009 routes; project-owned KE DTS and reference acceptance remain required. |
| Camera | LIKELY | The reference camera is USB UVC using `uvcvideo`; standard V4L2 plus an open streamer remains the target, with later reference-board acceptance of the selected SDK USB path. |
| Linux Host MCU / ADXL345 | LIKELY | Standard upstream Linux-MCU + spidev is the target; the observed endpoint is `spi-gpio`, whose GPIO/pinmux/CS details must be proved. |
| BL24C16F | DEFERRED | It is not evidenced as necessary for the required open-host/ADXL path. Preserve rather than modify its data. |
| Update/rollback model | TARGET | After Gate 1, the selected bring-up model uses untouched Stock A (p5/p7), project Slot B (p6/p8), a p1 one-shot selector, and an intended but not yet qualified USB-p1 emergency rollback; A/B read-only qualification is complete, but the A/B ROLLBACK GATE is not satisfied. |
| Stock return | UNKNOWN | Gate 1 requires a separate review against the current evidence; this document does not claim it satisfied. The documented vendor process remains execution-unverified on the reference device. |

## Required design boundaries

The open image must not, without an explicit separately authorized need:

- alter eFuses, RPMB, boot0/boot1, eMMC hardware boot configuration, factory
  identity data, MAC/serial information, or BootROM recovery access;
- consume stock loader/A-B structures merely because they appear unused;
- depend on a non-documented permanent special boot state; or
- claim stock recovery, rollback, or identity preservation has been validated.

The stock GPT/update arrangement is evidence about constraints, not an adopted
open update design. A later implementation may reserve stock structures and use
a separate update strategy, but Phase 3.1 does not select storage ownership.

## Smallest next phases

1. **3.1 Hardware + Boot Contract — complete.** Record only the REQUIRED
   interfaces and compatibility constraints in
   [x2000-hardware-contract.md](x2000-hardware-contract.md).
2. **3.2 Kernel / Device-Tree feasibility — complete.** The bounded result is
   [x2000-kernel-dt-feasibility.md](x2000-kernel-dt-feasibility.md): the pinned
   Ingenic Linux 6.6.18 X2000 SDK mirror is selected over a large upstream-6.12
   forward port. NebulaOS is KE prior art only, not an adopted distribution.
3. **3.3 A/B bring-up qualification.** Prove the selected Slot-B
   kernel/DT/rootfs and one-shot return-to-Stock-A sequence read-only before
   any persistent deployment. The RAM-only prototype remains a deferred
   alternative.
4. **3.4 Minimal Buildroot appliance.** Produce a reproducible immutable base
   with separate persistent data; no installer/update design is implied yet.
5. **3.5 Required peripheral integration.** Integrate display/touch, WLAN,
   camera, and ADXL345/Input Shaper before treating the appliance as feature
   complete.
6. **3.6 Klipper + Moonraker integration.** Add upstream services, open Web UI,
   touchscreen UI, and the camera streamer.
7. **3.7 F005 + complete printer validation.** Validate the already-established
   UART/Mainline-F005 path in the new host context and then the full printer.
8. **3.8 Persistent deployment / update model.** Design and validate persistence,
   image activation, rollback, and configuration migration only after the
   preceding non-persistent result.
9. **3.9 Stock-return compatibility validation.** This remains subject to the
   Gate-1 red-zone boundary and separate authorization.

Camera and ADXL345/Input Shaper are deliberately in the required-peripheral
phase, not optional work after printer validation.
