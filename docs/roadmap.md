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

- **Partially progressed:** Creality's official
  [V1.1.0.12 release](https://github.com/CrealityOfficial/Ender-3_V3_KE_Klipper/releases/tag/V1.1.0.12)
  provides `Ender-3_V3_KE_1.1.0.12.ingenic` (130,364,076 bytes) for the
  vendor brick/wire-recovery flow and
  `Ender-3_V3_KE_F005_ota_img_V1.1.0.12.img` (118,559,722 bytes) for the
  F005 OTA/normal update path. These are distinct artifact types; content
  equivalence is not assumed.
- **Phase 1.1 remains open:** The reference system runs V1.1.0.15. An official
  matching V1.1.0.15 `.ingenic` recovery image has not been located, archived,
  hashed, or validated, and the supported relationship between a V1.1.0.12
  recovery and V1.1.0.15 remains unknown.

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
- **Phase 1.2 remains open:** GPT type GUIDs/attributes, entry-array geometry,
  CRCs and primary/backup consistency; boot0/boot1 contents; A/B selection and
  inactive-side state; and bootloader location/version have not been completed.
  Creality documents an independent Ingenic USB recovery interface, but its exact
  protocol, write coverage, and operation on the reference device remain open.

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

The future `/dev/mmcblk0` user area should be captured once as one raw artifact.
Partition artifacts p1-p10 should then be extracted offline from that same image,
not produced by additional live partition reads. This preserves one capture basis
for the partitions, GPT areas, LBA 34-2047, and the entire physical tail.

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
- **RESEARCH:** The exact regions written by Cloner, bootloader/GPT and identity
  handling, signature constraints, and a safe open KE-specific USB client/loader
  remain unknown. Related X2000E work for other Creality hardware is community
  research, not KE verification.
- **Phase 1.5 remains open:** The vendor procedure has not been executed on the
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

This model is **not locally validated**, does not make V1.1.0.12 mandatory, and
may be shortened if an official V1.1.0.15 `.ingenic` becomes available.
Identity/factory restoration is allowed only after the `.ingenic` write coverage
is understood and only at a verified safe stage for the original device. Gate 1
requires a reproducible validated return path, not technical elegance; an open
Ingenic USB client or project-authored `.ingenic` build system is not required.

### Gate 1 - POINT OF RETURN

Status: **not satisfied**

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
