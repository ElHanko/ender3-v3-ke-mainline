# Fre3nder roadmap

Fre3nder `2026.1` is functionally achieved on the investigated reference
system. The current work is productive maintenance and qualification of later
features; any persistent or hardware-changing operation remains explicit
WARNING / RED ZONE work under `AGENTS.md`.

## Current product baseline

- Open X2000 host with read-only SquashFS RootFS and A/B-compatible Stock
  return path.
- Upstream Klipper host with the qualified passive F005 UART integration.
- Hardware-validated F005 mainline configuration and complete Fre3nder-B print
  on the investigated reference system.
- Hardware-validated Fre3nder-B persistence, SSH access, and the bounded
  selector tool; no credentials or vendor binaries are embedded in the image.
- Open bidirectional F005 MCU transitions are qualified on the investigated
  reference system.
- Installation of a complete current-main Fre3nder kernel and RootFS pair
  on Slot B is qualified on the investigated reference system. The p6 kernel
  and p8 RootFS were fully read back after writing, Stock p5/p7 remained
  unchanged, and the newly written pair booted successfully with persistence,
  Klipper, and hostname `fre3nder`. The latest tested pair was the untagged
  `2026.1-4-g833cbd4` current-main build, not a new public release.

## Open product work

- runtime and hotplug network failover;
- general persistent user configuration;
- complete display/touch stack and framebuffer-logo handling;
- camera, ADXL/input shaping, and other non-required peripherals;
- uninterrupted software-only Fre3nder-to-Stock handoff;
- move the Fre3nder F005 release from transitional persistent operator staging
  into the RootFS and perform the exact-state MCU update gate during normal
  Fre3nder boot before Klipper startup;
- broader hardware and firmware-revision qualification.

Current qualification boundaries:

- software-only Fre3nder -> Stock: **REQUIRES QUALIFICATION**;
- F005-only open Stock -> Fre3nder and Fre3nder -> Stock transitions:
  **QUALIFIED ON DEVICE**;
- complete current-main Fre3nder kernel-plus-RootFS installation on the
  investigated reference system: **QUALIFIED ON DEVICE**;
- product hostname `fre3nder`: **QUALIFIED ON DEVICE**;
- power-cycle Stock recovery: **QUALIFIED ON DEVICE (2/2)**;
- physical PC22 backlight effect: **REQUIRES QUALIFICATION**;
- complete display/touch stack: **NOT IMPLEMENTED**.

## Mandatory gates

Gate 1, **POINT OF RETURN**, is satisfied by the current evidence review. Its
minimum evidence remains a validated backup, protected device identity and
factory data, documented eMMC boot configuration, archived original firmware
material, a recovery route independent of normal Linux boot, and a documented
route back to Stock. The official recovery route is still execution-unverified
on the reference device; persistent work remains RED ZONE work.

Gate 2, **CREALITY DELTA UNDERSTOOD**, is satisfied for the required first-print
scope. Required behavior is classified as `UPSTREAM`, `KEEP`, `REIMPLEMENT`,
`DROP`, or `UNKNOWN`; the detailed classification and evidence remain in
[`docs/klipper-stock.md`](klipper-stock.md) and the historical gate record.

The detailed historical gate record is preserved in
[`research/docs/roadmap-history.md`](../research/docs/roadmap-history.md).
