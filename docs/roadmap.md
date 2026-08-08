# Project roadmap

This project follows gated phases. The gates exist to prevent experimental work
from making the printer unrecoverable and to avoid designing a migration before
the vendor-specific behavior is understood.

## Target

Make the Creality Ender-3 V3 KE reproducibly usable as an open Klipper platform
while preserving a documented and validated path back to the original Creality
firmware.

## Phase 0 - Reference inventory

Status: **completed**

Objectives:

- identify the host hardware and operating system;
- document storage and partition layout;
- identify active Klipper and Moonraker components;
- document the main MCU and Host MCU connections;
- identify Creality-specific modules and services;
- identify visible update and recovery mechanisms;
- record open questions without modifying the printer.

Relevant documents:

- `system-inventory.md`
- `storage-layout.md`
- `klipper-stock.md`
- `recovery-analysis.md`
- `backup-plan.md`

No destructive or state-changing tests are part of this phase.

## Phase 1 - Establish the point of return

Status: **in progress**

This phase has priority over all migration work.

### 1.1 Archive official recovery material

Obtain the exact official Creality firmware package corresponding to the
reference system where available.

Record:

- source;
- original filename;
- firmware version;
- board/hardware designation;
- download date;
- file size;
- cryptographic hash.

Third-party firmware packages must not be committed to this repository unless
their redistribution rights have been explicitly verified.

Progress:

- **Phase 1.1 completed for the currently available accepted recovery path:**
  official V1.1.0.12 `.ingenic`, V1.1.0.12 F005 OTA `.img`, and V1.1.0.15 F005
  OTA `.img` files are archived outside Git with provenance, sizes, and SHA-256
  hashes. The local integrity manifest verifies all archived vendor artifacts.
- The V1.1.0.12 recovery package and OTA package remain distinct artifact types;
  content equivalence is not assumed.
- No official matching V1.1.0.15 `.ingenic` recovery image has been located. Gate 1
  does not require one if the accepted V1.1.0.12 brick-recovery followed by direct
  V1.1.0.15 OTA route is validated.

### 1.2 Complete storage and boot metadata

Determine, using read-only methods where possible:

- complete eMMC geometry;
- GPT layout and attributes;
- eMMC CID/CSD information required for recovery;
- EXT_CSD and active boot-area configuration;
- boot0 and boot1 contents;
- A/B selection state;
- inactive RTOS, kernel, and RootFS state;
- bootloader location and version where discoverable;
- available serial, USB, SoC-ROM, or other recovery interfaces.

Do not change eMMC boot configuration during discovery.

Progress:

- **P1.2-02a completed:** The reference eMMC EXT_CSD was read successfully through
  read-only access to an existing kernel debugfs file. Its revision, user-area sector
  count, boot/RPMB sizes, standard boot selection, boot capabilities, reset field,
  health indicators, and relevant partitioning/reliability/write-protection
  register values are documented in [`storage-layout.md`](storage-layout.md).
- **P1.2-02b completed:** BusyBox `fdisk` read the reference user-area GPT without
  writes. The protective MBR, 512-byte block geometry, p1-p10 boundaries,
  contiguous partition layout, LBA 34-2047 pre-p1 alignment region, and physical
  tail after p10 are documented and cross-checked against sysfs. No sectors or
  partition/gap contents were read. BusyBox acceptance is not a full CRC or
  primary/backup-GPT verification.
- **Offline recovery-package analysis:** the official V1.1.0.12 `.ingenic`
  contains a user-area boot payload with SPL/U-Boot, protective MBR, primary GPT,
  and pre-p1 boot code. This establishes the vendor recovery layout but does not
  prove byte-for-byte identity with the running V1.1.0.15 reference device.
- **Private reference capture completed:** the whole eMMC user area, boot0, and
  boot1 were captured read-only. The primary GPT header and entry-array CRCs
  validate; the live layout has no conventional backup-GPT header in the physical
  tail. boot0/boot1 are entirely zero-filled.
- **A/B state confirmed:** p1 contains `ota:kernel`, active A carries V1.1.0.15,
  while inactive B retains exact V1.1.0.12 recovery RTOS/kernel/RootFS payloads
  followed only by zero padding.
- **Boot material confirmed:** the persistent loader material is in the user area
  before p1. Compared with the V1.1.0.12 recovery boot payload, differences are
  limited to GPT identifiers/derived CRCs and two copies of the embedded build
  timestamp; the rest of the compared boot payload matches.
- **Phase 1.2 completed for Gate-1 metadata scope.** Exact X2000 ROM sequencing,
  serial-console behavior, and low-level recovery commands remain research items
  but no longer block the backup definition.

### 1.3 Create a complete backup set

The recovery set should account for:

- complete eMMC user area;
- boot0;
- boot1;
- GPT and partition metadata;
- both A/B RTOS images;
- both A/B kernel images;
- both A/B RootFS images;
- OTA selector;
- device-specific factory/identity partition;
- writable overlay;
- `/usr/data`;
- Klipper and Moonraker configuration;
- shipped MCU firmware artifacts;
- relevant system and recovery metadata.

RPMB must be documented separately. If it cannot be backed up through a safe
supported mechanism, that limitation must be explicit.

A raw `/dev/mmcblk0` image alone must never be described as a complete eMMC
backup because it excludes hardware boot areas and RPMB.

**Status: completed for the reference device.** The `/dev/mmcblk0` user area was
captured once as one raw artifact; p1-p10 were extracted offline from that same
image. boot0 and boot1 were captured separately, persistent file exports were
created, and private metadata/manifests preserve the reference state.

RPMB remains explicitly inventory-only because no safe authenticated readback
method was established. Physical main-MCU flash readback also remains unavailable;
shipped MCU artifacts and version evidence are preserved instead. These documented
limitations do not masquerade as captured data.

### 1.4 Validate the backup offline

Validation should include:

- cryptographic hashes;
- exact expected sizes;
- GPT parsing;
- partition-boundary validation;
- extraction of partition images from the whole-device image;
- read-only filesystem validation;
- SquashFS inspection;
- file-level archive inspection;
- cross-validation between whole-device and partition data;
- documentation of consistency limitations for live ext4 captures.

Backup artifacts are private device data and must not be committed to Git.

**Status: completed with a documented live-ext4 limitation.** All raw/partition,
structural, metadata, and file-archive hashes verify. Both SquashFS sides pass full
offline tests, the file-level archives are readable, and p9 passes read-only
`e2fsck -fn`. p10 returns filesystem-consistency errors under `e2fsck -fn`, as
anticipated for a long live stream of a mounted writable filesystem; the original
raw image is preserved unchanged and the separate readable `/usr/data` archive is
part of the recovery set.

### 1.5 Establish brick recovery

A recovery method must be identified that does not depend solely on the normal
Creality Linux system continuing to boot.

Candidate mechanisms may include:

- bootloader console;
- SoC ROM USB loader;
- temporary SPL/U-Boot loading;
- serial recovery;
- board-specific service interfaces;
- external eMMC access or programming.

The selected path must be documented sufficiently to restore the original
software stack after a failed migration.

Progress:

- **VENDOR-DOCUMENTED / NOT LOCALLY VALIDATED:** Creality publishes a KE-specific
  [Brick Rescue / Wire Brushing procedure](https://wiki.creality.com/en/ender-series/ender-3-v3-ke/quick-start-guide/firmware-open-source/brick-rescue-wire-brushing-process)
  using a Boot/Reset-initiated `Ingenic USB BOOT DEVICE`, the Windows Ingenic
  Cloner utility, and `.ingenic` recovery images. Normal Linux is not required for
  this vendor flow.
- **OFFLINE-CONFIRMED:** the V1.1.0.12 `.ingenic` package selectively provides
  boot/SPL/U-Boot/GPT plus p3 RTOS, p5 kernel, and p7 RootFS. It does not provide
  p1, p2, the B-side p4/p6/p8, p9, p10, boot0, boot1, or RPMB.
- **INFERENCE from static Cloner configuration:** the selected erase ranges are
  broad enough to remove p1, the B side, p9, and part of p10 while apparently
  preserving p2 `sn_mac`. Exact runtime erase semantics and p2 preservation remain
  unvalidated.
- **CONFIRMED-ON-DEVICE:** retained `upgrade-server.log` data records the
  reference device at V1.1.0.12 on 2024-11-22, selecting the official V1.1.0.15
  F005 OTA image from removable media, invoking `local_ota_update.sh` directly on
  it, and subsequently reporting V1.1.0.15. The captured A/B state independently
  matches this direct transition: inactive B remains exact V1.1.0.12 while active
  A is V1.1.0.15.
- **Phase 1.5 remains open:** the vendor procedure has not been executed on the
  reference device and no complete restore has been demonstrated. External eMMC
  programming remains a possible final fallback, but is no longer the only known
  Linux-independent recovery candidate.

Gate 1 does not require a one-step or bit-exact restore directly to the most
recently used firmware. A reproducibly validated multi-stage route to a known
working starting state is acceptable. One candidate model is:

```text
brick
  -> official V1.1.0.12 .ingenic brick recovery
  -> successful normal boot
  -> official update to V1.1.0.15
  -> restore protected device-specific data and settings
  -> known working starting state
```

The full model is **not yet locally validated** because the destructive
`.ingenic` brick-recovery stage has not been exercised. The subsequent direct
V1.1.0.12-to-V1.1.0.15 OTA stage is, however, confirmed by retained reference
device evidence. The model does not make V1.1.0.12 mandatory and may be shortened
if an official V1.1.0.15 `.ingenic` becomes available.
Identity/factory restoration is allowed only after the `.ingenic` write coverage
is understood and only at a verified safe stage for the original device. Gate 1
requires a reproducible validated return path, not technical elegance; an open
Ingenic USB client or project-authored `.ingenic` build system is not required.

### Gate 1 - POINT OF RETURN

Status: **not satisfied**

The backup/metadata side of Gate 1 is now established for the reference device.
The remaining major blocker is practical validation of a Linux-independent brick
recovery/restore path, including confirmation of Cloner runtime erase behavior and
the safe point for restoring device-specific identity data. A second independent
physical copy of the private recovery set should exist before that destructive
test.

Experimental modification of the printer is allowed only after this gate has
been satisfied.

Gate 1 requires:

- a complete backup set appropriate for the known storage architecture;
- verified hashes and offline readability;
- original firmware material archived where available;
- device identity/factory data protected;
- eMMC boot configuration documented;
- a recovery path that remains usable when normal Linux no longer boots;
- a documented procedure for returning to the original Creality firmware.

A backup without a usable restore path does not satisfy Gate 1.

Where a full destructive restore test on the production printer would itself be
unreasonable, the remaining uncertainty must be documented explicitly. The
project must not claim a stronger recovery guarantee than has actually been
demonstrated.

## Phase 2 - Reconstruct the Creality Klipper delta

Status: **blocked by Gate 1**

The public Creality source tree does not necessarily correspond to the firmware
running on the reference system.

The analysis therefore uses three references:

```text
A = upstream Klipper
B = publicly released Creality Ender-3 V3 KE Klipper source
C = Klipper tree shipped with the reference Creality firmware
```

Required comparisons:

```text
A <-> B
What did Creality change in the publicly released fork?

B <-> C
What changed between the published Creality source and the firmware currently
shipped on the printer?

A <-> C
What actually differs between the reference firmware and upstream Klipper?
```

The exact upstream revisions used for comparisons must always be recorded.

### Classification

Every discovered vendor-specific change should be classified as one of:

- `UPSTREAM` - equivalent functionality now exists upstream;
- `KEEP` - required hardware support and suitable for continued use;
- `REIMPLEMENT` - required function that should be replaced by an open implementation;
- `DROP` - vendor-specific functionality not needed for the open platform;
- `UNKNOWN` - insufficiently understood.

Areas of particular interest include:

- PR-Touch;
- Z compensation;
- load/pressure sensing;
- EEPROM access;
- Host MCU changes;
- MCU protocol changes;
- motion and homing changes;
- config extensions;
- binary Python wrappers;
- firmware update coupling;
- Creality application-stack integration.

### Gate 2 - CREALITY DELTA UNDERSTOOD

Mainline migration design begins only when all required vendor-specific
functionality is either:

- understood;
- known to exist upstream;
- deliberately dropped;
- or assigned a concrete open reimplementation plan.

## Phase 3 - Mainline architecture

Status: **blocked by Gate 2**

Evaluate at least:

### Option A - Minimal host change

Keep the Creality host operating system while replacing the Klipper runtime with
current upstream Klipper.

### Option B - Open application stack

Keep the underlying host system but replace vendor application components with:

- upstream Klipper;
- upstream Moonraker;
- Mainsail or Fluidd;
- an open touchscreen solution where desired.

### Option C - More complete host replacement

Investigate replacement of the obsolete vendor Buildroot/kernel stack if and
when sufficient hardware and boot knowledge exists.

This is a long-term option, not an initial requirement.

## Phase 4 - Implementation

Develop all migration work reproducibly.

Prefer:

- source patches;
- documented build environments;
- scripts;
- deterministic configuration generation;
- explicit version pinning;
- automated validation.

Do not rely on undocumented manual edits to the production printer.

## Phase 5 - Controlled deployment

Deployment should proceed incrementally.

Suggested validation order:

1. host software starts without controlling heaters or motion;
2. Moonraker/API communication;
3. MCU connection;
4. temperature sensing;
5. fan outputs;
6. endstops and probe inputs;
7. low-risk motion;
8. homing;
9. bed probing;
10. heater safety;
11. extrusion;
12. calibration;
13. test print.

Rollback must remain available throughout testing.

## Phase 6 - Reproducible release

A successful project release should allow another Ender-3 V3 KE owner to:

1. inventory their printer;
2. verify hardware/firmware compatibility;
3. create and validate their own backup;
4. establish their own recovery path;
5. obtain required third-party artifacts from their original sources;
6. build the open software stack;
7. migrate in documented stages;
8. validate printer operation;
9. return to stock firmware if necessary.

No project release should require downloading another user's device backup or
factory identity data.
