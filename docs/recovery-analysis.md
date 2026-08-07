# Recovery analysis

This document describes mechanisms visible on the device. None was executed.
Restoration and flashing are outside the inventory authorization.

Unless stated otherwise, these mechanisms were observed on the reference system
running Creality firmware `V1.1.0.15`. Their behavior must be verified on other
firmware revisions before use.

## Confirmed mechanisms

### 1. A/B system OTA

The GPT provides paired `rtos`/`rtos2`, `kernel`/`kernel2`, and
`rootfs`/`rootfs2` partitions. `/etc/ota_bin` contains local and network OTA
implementations.

The updater:

1. reads a short selector from partition `ota`;
2. selects the inactive RTOS, kernel, and RootFS partitions;
3. validates image metadata/size and per-piece MD5 values;
4. streams each image directly to its target block device;
5. changes the `ota` selector only after the selected images succeed.

This is a transactional A/B update design at the system-image level. It reduces
risk from a failed write before selector change, but it does not itself prove an
automatic boot-attempt counter or automatic rollback after a bad-but-successfully
written image.

The captured reference boot used RootFS A (`/dev/mmcblk0p7`). Exact contents and
bootability of side B were not tested.

### 2. Local and network update entry points

- `/etc/ota_bin/local_ota_update.sh` accepts a Creality `.img` bundle, extracts it
  under `/usr/data/creality`, and uses the same A/B writer.
- `/etc/ota_bin/network_ota_update.sh` implements network acquisition.
- `upgrade-server` is part of the Creality application stack and references
  `/etc/ota_bin`, `/usr/data/creality/upgrade`, and removable-media paths.
- The UI/runtime logs identify firmware `V1.1.0.15`, hardware `F005`.

**Inference:** A valid Creality firmware `.img` on removable media can be submitted
through the Creality update flow while Linux and the UI stack still run. A
documented pre-Linux USB recovery mode was not found.

### 3. Factory reset

`S58factoryreset` recognizes a `factory_reset` flag on mounted USB media and also
has an explicit reset action. Its implementation deletes most of `/overlay/upper`
and `/usr/data`, while deliberately retaining selected identity/network/root-opt-in
data, then reboots.

This is **not** a firmware recovery and **not** a restoration of erased A/B images.
It is a destructive userdata/overlay reset. It was not invoked.

### 4. MCU recovery/update

At normal boot `S13mcu_update` talks to the main MCU using `mcu_util` on
`/dev/ttyS1`, checks its version, optionally uploads the matching image, and starts
the MCU application. The matching F005 main-MCU image is present in the immutable
RootFS.

The Creality `upgrade-server` also contains SWD update references for auxiliary
MCUs. No SWD operation was performed and no safe standalone recovery procedure was
established.

## Bootloader status

**Confirmed:** eMMC exposes 4 MiB boot0 and boot1 hardware areas, both protected by
the kernel's force-read-only setting. There are no `/boot` files, no U-Boot
environment config, and no bootloader version in the inspected runtime files.

**Inference:** A first-stage/second-stage bootloader is likely stored in one or
both eMMC boot hardware areas. This is not verified and must not be used as a
restore assumption.

**Open:**

- bootloader type/version and exact byte location;
- which eMMC boot partition is enabled in EXT_CSD;
- whether boot0/boot1 are redundant;
- serial console accessibility on ttyS4 and available bootloader commands;
- USB boot/ROM-loader procedure for Ingenic X2000 on this board;
- board test points, pinout, and whether external eMMC programming is feasible;
- automatic rollback/boot-attempt semantics.

Answering several of these would require raw-device reads, boot interruption,
hardware access, or writes. They remain intentionally open.

## Brick scenarios and visible options

| Failure | Visible recovery prospect | Confidence |
|---|---|---|
| Broken writable overlay/config | Factory reset or file-level repair while Linux/SSH works | High mechanism confidence; destructive and untested |
| Broken active RootFS/kernel, inactive side valid | Change/boot alternate A/B side | Medium; layout/update logic confirmed, bootloader control unknown |
| Linux boots, firmware image needs reinstall | Creality local/network OTA via `upgrade-server` | High mechanism confidence; not tested |
| Main MCU firmware mismatch/corruption | Boot-time `mcu_util` upload from stock F005 image | Medium; update path confirmed, failure-mode recovery untested |
| Both kernel/RootFS sides broken | Boot ROM/bootloader, serial, USB loader, or external eMMC access | Low; no usable procedure established |
| Bootloader/eMMC boot areas corrupted | SoC ROM loader or external programmer | Low; hardware research required |
| Identity partition (`sn_mac`) lost | Restore device-specific partition from prior backup | High need; no generic replacement should be assumed |

## Recovery prerequisites to establish later

1. Obtain and archive the exact official `F005` firmware package matching
   V1.1.0.15, with external provenance and hashes.
2. Determine the eMMC boot configuration and bootloader location/version without
   changing it.
3. Identify and bench-test the serial/USB ROM recovery path on non-production
   hardware or with a recoverable setup.
4. Verify the inactive A/B side and selector semantics without risking the
   production printer.
5. Create and validate a complete backup as specified in
   [`backup-plan.md`](backup-plan.md) before any migration.

## Risks

- **Risk:** Factory reset is destructive and preserves only a hard-coded subset of
  data; it is not a substitute for a backup.
- **Risk:** A/B recovery fails if both sides, the selector, GPT, or bootloader are
  damaged.
- **Risk:** Restoring another printer's `sn_mac`, certificates, or Creality
  userdata could duplicate identity or break cloud/device pairing.
- **Risk:** MCU images must match the exact board and MCU; filenames for other
  models are present beside F005 images.
- **Risk:** Changing `force_ro`, boot partitions, A/B selector, or SWD state is a
  high-consequence operation and was not authorized.
