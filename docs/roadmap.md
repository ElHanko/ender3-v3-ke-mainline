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

- **Phase 1.1 completed for the currently available vendor-documented path:**
  official V1.1.0.12 `.ingenic`, V1.1.0.12 F005 OTA `.img`, and V1.1.0.15 F005
  OTA `.img` files are archived outside Git with provenance, sizes, and SHA-256
  hashes. The local integrity manifest verifies all archived vendor artifacts.
- The V1.1.0.12 recovery package and OTA package remain distinct artifact types;
  content equivalence is not assumed.
- No official matching V1.1.0.15 `.ingenic` recovery image has been located. Gate 1
  does not require one if the V1.1.0.12 brick-recovery followed by direct
  V1.1.0.15 OTA route is actually validated; that recovery route is not yet
  validated on this device.

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

The controlled validation sequence is defined in
[`recovery-validation-plan.md`](recovery-validation-plan.md).

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

- **VENDOR-DOCUMENTED / ENTRY LOCALLY VALIDATED:** Creality publishes a KE-specific
  [Brick Rescue / Wire Brushing procedure](https://wiki.creality.com/en/ender-series/ender-3-v3-ke/quick-start-guide/firmware-open-source/brick-rescue-wire-brushing-process)
  using a Boot/Reset-initiated `Ingenic USB BOOT DEVICE`, the Windows Ingenic
  Cloner utility, and `.ingenic` recovery images. Normal Linux is not required for
  this vendor flow. The reference board has entered that USB mode without
  flashing; it enumerated as `a108:eaef` / `Ingenic USB BOOT DEVICE`, and a
  non-writing CPU-info request returned `X2000`.
- **OFFLINE-CONFIRMED / PRACTICAL ATTEMPT:** a private KE-specific Linux client
  validates the original V1.1.0.12 archive and the fixed Boot-ROM sequence. A
  fresh RAM-only hardware attempt completed GET_CPU_INFO and the complete
  Stage-1 transfer, including GINFO, original SPL, and PROGRAM_START1; the first
  Stage-2 address transfer then timed out. Stage 2 was not loaded or started.
  The official Windows Cloner remains vendor documentation and policy reference,
  not a personally verified recovery path.
- **OFFLINE-CONFIRMED:** the V1.1.0.12 `.ingenic` package selectively provides
  boot/SPL/U-Boot/GPT plus p3 RTOS, p5 kernel, and p7 RootFS. It does not provide
  p1, p2, the B-side p4/p6/p8, p9, p10, boot0, boot1, or RPMB.
- **OFFLINE-CONFIRMED for the configured map:** on the exact reference GPT, the
  erase ranges preserve p2 `sn_mac`, erase p1 and p3-p9, and erase the beginning
  of p10. Active payloads rewrite p3, p5, and p7.
- **OFFLINE-CONFIRMED:** V1.1.0.12 recreates p9 `/overlay` and p10 `/usr/data`
  as ext4 after mount failure.
- **Offline preflight completed:** the private preflight re-validates the exact
  recovery set and both independently stored raw backup copies. Current result:
  `READY FOR MANUAL RECOVERY REVIEW` / `NOT READY TO FLASH`.
- **Accepted residual risk:** p1 is erased and receives no payload. Evidence
  strongly supports A-side boot unless `ota:kernel2` selects B, but the erased
  selector branch has not been formally proven.
- **CONFIRMED-ON-DEVICE:** retained `upgrade-server.log` data records the
  reference device at V1.1.0.12 on 2024-11-22, selecting the official V1.1.0.15
  F005 OTA image from removable media, invoking `local_ota_update.sh` directly on
  it, and subsequently reporting V1.1.0.15. The captured A/B state independently
  matches this direct transition: inactive B remains exact V1.1.0.12 while active
  A is V1.1.0.15.
- **Phase 1.5 closed without success:** the vendor procedure has not been
  executed on the reference device and no complete restore has been demonstrated.
  The private Linux client is retained as unsuccessful/not demonstrated. No
  further recovery research or new recovery-tool development is planned.

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
if an official V1.1.0.15 `.ingenic` becomes available. This is a vendor-documented
model, not a guaranteed or personally demonstrated return path.
Identity/factory restoration is allowed only after the `.ingenic` write coverage
is understood and only at a verified safe stage for the original device. Gate 1
requires a reproducible validated return path, not technical elegance; an open
Ingenic USB client or project-authored `.ingenic` build system is not required.

### Gate 1 - POINT OF RETURN

Status: **not satisfied**

The backup/metadata and offline-preflight sides of Gate 1 are established for the
reference device. A second independent physical copy of the private recovery set
has been created and verified. Non-writing Ingenic USB entry and the Boot-ROM
Stage-1 transport were observed, but the Linux client timed out before Stage 2;
the destructive vendor recovery and first-boot validation remain unverified.

Gate 1 is not satisfied. Any experimental persistent modification is therefore
WARNING / RED ZONE work and requires a separate explicit project decision,
scope, and risk acceptance; this roadmap does not authorize a hardware write.

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

Status: **completed for the required first-print scope; Gate 1 remains unsatisfied**

WARNING / RED ZONE: the recovery path is vendor-documented but not demonstrated
on this device. Further work that changes persistent contents may make the printer
unbootable, require additional hardware intervention, or permanently damage or
destroy it. Backups reduce risk but do not prove restoration. This status does
not authorize any particular hardware write or flash operation.

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

### Completed Phase 2 MCU sub-milestone

The first mainline MCU milestone is complete for the investigated reference
F005/GD32F303RET6 hardware. The comparison basis is recorded as:

```text
A = aktueller Implementations-Upstream:
    0499b30374315f2a9f49fc12808527fc7d0f5cfa
B = public Creality Klipper source and F005 configuration evidence
C = reference-firmware configuration, runtime logs, and archived F005 material
D = historical PR #7027 / b4b0c2ce... material, used only as comparison evidence
U0 = reconstructed best historical public content baseline only:
     9b60daf62dd7c02164c53f2baa72e3e6c8af441f
     v0.11.0-41-g9b60daf62
```

U0 is a content-comparison baseline, not a claim about fork ancestry.

The active probe path is the normal BLTouch/`probe` path. Archived runtime
evidence shows complete 5x5 bed-mesh runs through that path; PR-Touch,
`z_compensate`, HX711, dir-Z, filter, soft-homing, and fan-feedback paths are
not part of the first milestone. Only the main MCU and Host MCU are loaded in
the observed active path; a separate nozzle-MCU instance is not required by
this port scope.

The resulting port is classified as **SMALL MCU PORT**. It changes
`src/stm32/Kconfig`, `src/stm32/Makefile`, `src/stm32/stm32f1.c`, and the
generic linker script `src/generic/armcm_link.lds.S`. Existing STM32F1-
compatible and generic Klipper code supplies the GPIO, ADC, UART, watchdog,
timer/software-PWM, and ARM startup paths; a new full `src/gd32/` backend is
not required. The GD32 clock branch, conservative flash wait-state handling,
first-256-KiB linker boundary, and F005 board-info reservation are documented in
[`gd32f303-mainline-port.md`](gd32f303-mainline-port.md).

The F005-compatible image profile is offline validated: the raw image reserves
board-info offsets `+0x200..+0x21f`, and the packager writes version
`mcu0_004_000`, length, and CRC16. The F005 transport protocol matches the
offline local `mcu_util` analysis and the public compatible implementation; the
Stock updater uses its bootloader startup window, so no Physical-Serial-
Bootloader request is needed for this first path.

The GD32 build, F005 packaging, STM32F103 regression, and a second clean GD32
build passed. The two clean builds were not bit-identical; the first artifacts
were overwritten before a byte-level comparison was retained, so the exact
source of the nondeterminism is not proven. Bit-identical builds are not
required before the first controlled MCU flash. The reproducible source patch
and network-isolated Docker build recipe are published under
[`../patches/klipper/`](../patches/klipper/) and [`../build/klipper-f005/`](../build/klipper-f005/).

The packaged candidate was subsequently flashed once on the investigated
reference F005 board through the original early-boot Creality updater. The
Stock updater reported `update:0` and then `app_run`; the newly flashed MCU
answered the existing `/dev/ttyS1` Klipper protocol with
`gd32f303xe`, `120000000` Hz, and `230400` baud. This establishes the milestone
**MAINLINE F005 MCU FLASH + IDENTIFY: PASS** on that reference
system. It does not validate motion, endstops, TMC communication, ADCs,
heaters, fans, probing, or printer operation.

A subsequent separately authorized passive Mainline Klippy runtime test also
completed with exit code `0`. Using `kinematics: none`, it loaded the real
dictionary, completed ClockSync, passed the reviewed pre-config gate, sent
`allocate_oids count=0` and `finalize_config`, observed
`is_config=1/is_shutdown=0`, reached READY through the pinned `/dev/null` EOF
path, and exited without a firmware restart. This establishes
**MAINLINE KLIPPY ↔ MAINLINE F005 MCU PASSIVE RUNTIME CONFIG/FINALIZE: PASS** on
the investigated reference system. The initial `get_config` response was not
separately logged; reaching the configuration-send line is the evidence that
the code gate allowed continuation.

This passive test validated only communication/configuration. The subsequent
staged reference-board bring-up and complete PLA Benchy are documented in
[`f005-hardware-validation.md`](f005-hardware-validation.md); they establish
the required first-print surface without changing the Gate-1 recovery boundary.

### Completed Phase 2 host/config sub-milestone

Offline host/printer configuration integration is complete for the investigated
F005/GD32F303RET6 reference. The two candidate configurations and sanitized pin
matrix are published in [`../configs/klipper-f005/`](../configs/klipper-f005/)
and [`f005-pin-matrix.md`](f005-pin-matrix.md). Klipper's own
`scripts/test_klippy.py` accepted both candidates with the exact 88-command
GD32 dictionary (`gd32f303xe`, 120 MHz, PA3/PA2 at 230400 baud) in
debugoutput/dictionary mode, without serial, USB, or hardware access.

This proves offline parser and command-surface compatibility for the
configuration candidates. The later staged hardware result and complete print
are recorded in [`f005-hardware-validation.md`](f005-hardware-validation.md).
Host-MCU/ADXL support is deferred and is not required for first mainline
bring-up. Creality-only
PR-Touch, Z compensation, calibration, UI/cloud, and other removed surfaces
remain classified in the host/config document.

The stock dependency graph, first bring-up candidate, and first-mainline
candidate are complete. The staged hardware result closed the required first-
print validation scope; optional Host-MCU/ADXL and PR-Touch/Z-compensation work
is deferred.

### Completed Phase 2 reference hardware validation

The investigated F005/GD32F303RET6 reference passed staged validation of
thermistors, TMC2208 X/Y/Z, X/Y endstops, bounded X/Y/Z motion and direction,
BLTouch/probe and XYZ homing, both heaters and thermistors, fans, filament
sensing, 50 mm hot extrusion, and one complete heated 5x5-mesh PLA Benchy.
The detailed evidence, PID/reference calibration scope, and the one controlled
`Timer too close` retry are recorded in
[`f005-hardware-validation.md`](f005-hardware-validation.md).

The temporary PTY feeder used during the print was test scaffolding only and is
not part of the proposed production architecture.

### Phase 2.12 hardware-communication checkpoint

The first three identify-only attempts produced no successful live MCU
dictionary. That checkpoint was superseded by the separately authorized first
mainline F005 flash/identify and passive runtime results documented above;
detailed attempt records remain private.

Phase 2.12 does not authorize further identify attempts. Any later hardware
work requires a separate, explicit scope and authorization.

Phase 2 is **complete for the required first-print behavior on the investigated
reference**. Gate 1 remains open; Gate 2 is closed below. The next scope is
Phase 3 host/print-computer architecture and userspace integration.

### Gate 2 - CREALITY DELTA UNDERSTOOD

Status: **satisfied for the required first-print scope**

Mainline migration design begins only when all required vendor-specific
functionality is either:

- understood;
- known to exist upstream;
- deliberately dropped;
- or assigned a concrete open reimplementation plan.

The required F005 first-print surface is now classified: ordinary upstream
motion, TMC, endstops, BLTouch/probe, thermistors, heaters, fans, filament
sensing, mesh, and extrusion are `UPSTREAM`/`KEEP`; inactive Creality-only
surfaces are `DROP`; Host-MCU/ADXL and input shaping are deferred; optional
PR-Touch/Z compensation is assigned `REIMPLEMENT` if later needed. No required
first-print behavior remains `UNKNOWN`. This closes Gate 2 without implying
that Gate 1/recovery has been satisfied.

## Phase 3 - Open X2000 host replacement

Status: **Phase 3.1 complete; Gate 1 recovery warning remains active**

Selected target: **complete open X2000 host replacement**. The selected system
is a conservative, LTS-oriented embedded appliance: an open kernel/Device Tree,
minimal Buildroot root filesystem, upstream Klipper and Moonraker, open Web and
touchscreen UI, camera streaming, and a Linux Host MCU for ADXL345/Input
Shaping. The established X2000 -> `/dev/ttyS1` at 230400 -> Mainline F005 path
remains the reference printer-control contract.

The selected target must retain a stock-compatible recovery boundary. Gate 1 is
still **not satisfied**; no Phase-3 design or later implementation may claim a
demonstrated stock return without separate evidence and authorization.

Options A (minimal host change) and B (open applications on the stock host) are
no longer equal long-term objectives. They may be used only as explicitly scoped
diagnostic/intermediate paths where they materially reduce risk.

### Phase 3.1 - Hardware + Boot Contract

Status: **completed**

The required X2000 interfaces, boot/recovery constraints, and resulting target
architecture are recorded in:

- [`x2000-hardware-contract.md`](x2000-hardware-contract.md);
- [`x2000-open-host-architecture.md`](x2000-open-host-architecture.md).

The contract covers stock-recovery compatibility, an LTS-oriented embedded base,
F005 UART, networking, display/touch, camera, ADXL345/vibration sensing/Input
Shaper, and the constraints for a reproducible image/update architecture. It
does not implement a kernel, Device Tree, Buildroot system, bootloader change,
deployment, or update scheme.

### Phase 3.2 - Kernel / Device-Tree feasibility

Compare pinned, maintained LTS candidates against the Phase-3.1 contract.
Establish the smallest viable X2000 kernel/DT basis for CPU/SMP, DRAM, eMMC,
UART, SPI/ADXL345, I2C/touch, SDIO WLAN, display, camera, USB as needed, and
reset/watchdog behavior. Do not select a release merely for recency.

### Further Phase-3 sequence

1. non-persistent boot prototype, if the feasibility result warrants it;
2. minimal Buildroot appliance;
3. required peripheral integration, including camera and ADXL/Input Shaping;
4. upstream Klipper and Moonraker integration;
5. F005 and complete printer validation;
6. persistent deployment/update model; and
7. stock-return compatibility validation.

Persistent deployment or stock-return validation remains red-zone work and
requires separate explicit authorization.


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
