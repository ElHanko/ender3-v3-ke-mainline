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
| LTS kernel + DT | PROVEN | The pinned Ingenic Linux 6.6.18 X2000 SDK mirror, project KE DTS, and minimal patch series boot the bounded `2026.1.a` Slot-B baseline. Long-term maintenance and peripheral completion remain separate work. |
| Minimal Buildroot root filesystem | PROVEN | The bounded `2026.1.a` system runs its immutable Buildroot SquashFS RootFS from p8. Persistent-data architecture and production services remain separate work. |
| Network/SSH | PROVEN | The bounded Slot-B Network-Smoke directly proved SDIO WLAN, WPA, DHCP, ICMP, and non-interactive public-key SSH on the investigated reference system while rollback to Stock A was already armed. Persistent host identity, normal-reboot behavior, lease renewal, and interactive PTYs remain open. Ethernet is not a requirement without a demonstrated physical path. |
| Display/touch | LIKELY | The NS2009/I2C endpoint and stock framebuffers are observed. The selected SDK plus NebulaOS prior art provide bounded panel and GPL NS2009 routes; project-owned KE DTS and reference acceptance remain required. |
| Camera | LIKELY | The reference camera is USB UVC using `uvcvideo`; standard V4L2 plus an open streamer remains the target, with later reference-board acceptance of the selected SDK USB path. |
| Linux Host MCU / ADXL345 | LIKELY | Standard upstream Linux-MCU + spidev is the target; the observed endpoint is `spi-gpio`, whose GPIO/pinmux/CS details must be proved. |
| BL24C16F | DEFERRED | It is not evidenced as necessary for the required open-host/ADXL path. Preserve rather than modify its data. |
| Update/rollback model | PROVEN | The automatic p1 one-shot model proved bounded Slot-B boot and Stock-A return for `2026.1.a`; it remains the safety/regression path. The next separate development path is operator-controlled A/B selection so Mainline can remain on B across normal reboots. That path is not yet implemented and deliberately relies on the qualified external Ingenic USB / RAM-U-Boot p1 rollback if Mainline becomes unreachable. Persistent updates remain unqualified. |
| Stock return | DOCUMENTED / NOT PERSONALLY REHEARSED | Gate 1 is satisfied by the current evidence review. The documented vendor process remains execution-unverified and is not a guaranteed restore on the reference device. |

## Provisioning and administrative access

Provisioning and privileged administration are separate concerns.

The target release image must not contain user-specific WLAN credentials,
authorized SSH keys, or administrative passwords. Device-specific configuration
is supplied after installation rather than compiled into a per-user image.

The intended long-term Fre3nder provisioning model is:

1. normal network configuration is performed locally through the touchscreen UI;
2. WLAN setup is normal device configuration and does not imply privileged
   administrative access;
3. root/SSH administration is disabled until explicitly enabled by the user;
4. enabling root/SSH requires a clear warning and explicit local confirmation;
5. SSH administration uses public-key authentication rather than remote password
   authentication; and
6. authorized public keys are imported separately from the SSH enable/disable
   state.

A FAT32 USB provisioning medium is an acceptable headless and development path.
It may provide files such as `wpa_supplicant.conf` and `authorized_keys` without
embedding those private inputs in the built image. This path is also intended to
remain useful for development, recovery, and headless administration after a
touchscreen provisioning UI exists.

Until a persistent-data architecture is deliberately assigned, USB provisioning
must not silently claim Raspberry-Pi-style first-boot persistence. With the
current immutable p8 SquashFS design, credentials may instead be copied into
volatile storage such as `/run` for the current boot. A later persistent
configuration layer may store WLAN configuration, the SSH-enabled state, and
authorized keys as separate state.

The touchscreen provisioning UI is a later product-level target and is not a
requirement for final `2026.1`; the headless administrative network path remains
the qualified requirement for that release.

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
3. **3.3 A/B bring-up qualification — complete for `2026.1.a`.** The selected
   Slot-B kernel/DT/rootfs, bounded network administration path, and one-shot
   return-to-Stock-A sequence are proven. The RAM-only prototype remains a
   deferred alternative.
4. **Next development step — separate manual Slot-B selection.** After the
   public-state audit, design a deliberately separate operator-controlled path
   that keeps Mainline on B across normal reboots. Preserve the one-shot paths
   unchanged; treat loss of Mainline reachability as an external-p1-rollback
   recovery case. This is not yet implemented.
5. **3.4 Minimal Buildroot appliance.** Produce a reproducible immutable base
   and complete the production network/SSH lifecycle required for `2026.1`,
   including only the persistent configuration needed for stable network
   operation and SSH host identity. No deployment/update model is implied yet.
6. **3.5 Klipper host integration.** Add the upstream Klipper host service
   required for Mainline-F005 printer integration. Moonraker and user-facing UI
   remain later work.
7. **3.6 F005 + complete printer validation.** Validate the already-established
   UART/Mainline-F005 path in the new host context and then complete a real
   Mainline-F005 print without Stock Klippy.
8. **3.7 Remaining peripheral and product integration.** Integrate display/touch,
   camera, ADXL345/Input Shaper, Moonraker, the open Web UI, touchscreen UI, and
   camera streamer. SDIO WLAN itself is already proven by `2026.1.a`; production
   network lifecycle work belongs to the appliance/network path above rather
   than to remaining peripheral bring-up.
9. **3.8 Persistent deployment / update model.** Design and validate persistence,
   image activation, rollback, and configuration migration only after the
   preceding non-persistent result.
10. **3.9 Stock-return compatibility validation.** This remains subject to the
   Gate-1 red-zone boundary and separate authorization.

Display/touch, camera, ADXL345/Input Shaper, Moonraker, and the user-facing
UI stack remain later feature/product-integration work and are not prerequisites
for the first printable networked open-host release `2026.1`.
