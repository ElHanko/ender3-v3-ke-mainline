# Backup plan (analysis only)

No backup was performed. This is a requirements and sequencing plan derived only
from the read-only inventory.

The concrete geometry and paths below were observed on the reference system
running Creality firmware `V1.1.0.15`. Verify them before applying this plan to a
different device or firmware revision.

## Definition of a complete backup

A single image of `/dev/mmcblk0` is not complete because eMMC boot0, boot1, and
RPMB are outside its user area, while main-MCU firmware is on a different device.
A useful recovery set needs raw media coverage, offline-derived partition-level
artifacts, a file-level persistent-data export, metadata, and independent
verification.

## Required artifacts A-K

| Category | What must later be captured | Why / caveat |
|---|---|---|
| **A. Raw flash** | Entire 15,273,600-sector `/dev/mmcblk0` user area, read once as one artifact | Preserves every user-area byte: protective MBR, GPT structures present in the user area, LBA 34-2047, all ten partitions, and the entire physical tail after p10; does not include eMMC hardware boot/RPMB areas |
| **B. Individual partitions** | Images of p1-p10 extracted offline from artifact A, plus sizes, start/end sectors, GPT disk/partition GUIDs and attributes, and cryptographic hashes | Enables selective recovery and verification while keeping all partitions tied to the exact same raw capture; separate live partition reads are not a prerequisite |
| **C. Bootloader** | eMMC boot0 and boot1 as separate artifacts; the captured eMMC EXT_CSD boot-selection/config metadata; bootloader version/config if discoverable | `PARTITION_CONFIG=0x00` selects no standard eMMC boot source, but location remains unconfirmed; never assume `/dev/mmcblk0` or boot0/boot1 alone includes the active bootloader |
| **D. Kernel** | p5 `kernel` and p6 `kernel2` | Preserve both A/B states, even if one appears unused |
| **E. RootFS** | p7 `rootfs` and p8 `rootfs2` | p7 is the active SquashFS; p8 contents/health are unknown |
| **F. Data partition** | p9 `rootfs_data` raw image plus filesystem metadata | Contains the overlay and all deviations from immutable RootFS |
| **G. `/usr/data`** | p10 raw image and a separate file-level archive preserving ownership, modes, symlinks, xattrs if supported, sparse files, and timestamps | Contains configs, logs, gcode, Moonraker, swap, identity/user data, and any writable-storage additions |
| **H. Klipper/Moonraker** | Immutable `/usr/share/klipper` and `/usr/share/klippy-env` (covered by RootFS), `/usr/data/moonraker`, service overrides, versions/hashes, and any local Klipper trees identified in the private inventory | Required to reproduce the current runtime while keeping stock and local additions distinguishable |
| **I. Configuration** | Current `printer_data/config`, all included config files, Moonraker config, secrets, certificates, database, saved meshes/Z offset/input shaping, and rollback/config backups | Secrets must be encrypted/access-controlled; avoid publishing them in Git |
| **J. MCU firmware** | Distributed F005 images, current MCU/Host-MCU version evidence, `/usr/bin/klipper_mcu`, and—if a safe supported readback is later found—an actual MCU flash dump | The shipped `.bin` is not proof of every byte currently flashed; no safe readback was found |
| **K. Creality recovery/factory data** | p1 `ota`, p2 `sn_mac`, p3/p4 RTOS pair, `/etc/ota_info`, `/etc/ota_bin`, Creality system/device configs, `machine_production_info`, factory test data, upgrade logs/config, and official matching OTA `.img` and recovery `.ingenic` material where available | Device identity and pairing data are unique and sensitive; vendor binaries remain external unless redistribution rights are verified |

RPMB should be inventoried separately. It may be authenticated and not normally
readable/exportable. Failure to capture RPMB must be explicitly stated, not hidden
under “full backup.”

## Recommended future capture sequence

This sequence requires a new authorization; it is not approved by the inventory.

1. **Prepare external destination:** enough local disk space, encrypted storage,
   manifest format, hash algorithm, and immutable capture log.
2. **Record metadata first:** GPT including partition GUIDs/attributes, eMMC CID/CSD
   and EXT_CSD, boot-area sizes/selection, mounts, versions, and device identity in
   a protected manifest.
3. **Capture eMMC boot areas:** boot0 and boot1 independently without changing
   `force_ro`; investigate RPMB through supported tooling only.
4. **Capture the user area once:** stream all 15,273,600 sectors of
   `/dev/mmcblk0` exactly once to the whole-user-area artifact. Hash while
   streaming to the local PC and hash the stored result again. Do not add
   separate live reads of p1-p10 merely to obtain partition artifacts.
5. **Capture persistent files:** create a file-level `/overlay/upper` and
   `/usr/data` export to complement raw ext4 images.
6. **Capture MCU evidence/images:** preserve shipped images and versions; do not
   attempt MCU readback until the protocol and safety are understood.
7. **Derive and cross-check offline:** parse the captured GPT and extract p1-p10
   from the corresponding byte ranges of the stored whole-user-area image. Record
   extraction offsets, exact sizes, and hashes. Because these artifacts derive
   from the same raw image, byte equality is constructionally testable without a
   second live block-device read.
8. **Offline validation:** parse GPT, mount filesystem images read-only on the PC,
   validate SquashFS, list archives, and verify every hash.
9. **Recovery rehearsal:** restore only to spare media/hardware or a controlled
   fixture before relying on the set for the production printer.

## Consistency strategy

**Risk:** p9 and p10 are mounted read-write and actively changed by logs, databases,
camera history, and services. A live stream may contain an inconsistent ext4 image.

Reading the user area only once prevents additional time skew between a whole-area
capture and separately captured p9/p10 images. It does not make a live raw stream
application-consistent: either filesystem can still change while its sectors are
being read.

The preferred later strategy is an offline/pre-Linux capture through a verified
bootloader/ROM/recovery environment that does not mount the source media writable.
No read-capable KE-specific method has yet been established; the official
Cloner procedure documents flashing, not backup capture. Stopping services,
remounting, freezing filesystems, or booting alternate media would change system
state and therefore was not attempted.

If a live capture is ever authorized as an interim measure, document it as
best-effort, capture file-level data separately, minimize printer activity, and
never claim application-consistent Moonraker databases/logs without validation.

## Restore ordering (future)

1. Verify target identity and exact eMMC geometry.
2. Restore bootloader/boot configuration only when proven necessary and correct.
3. Restore GPT and system A/B partitions as one matched set.
4. Restore the `ota` selector consistent with that matched set.
5. Restore unique `sn_mac` data only to its original device.
6. Restore overlay and userdata, then validate filesystems offline.
7. Restore/update MCU only through the verified board-specific procedure.
8. First boot with serial console/recovery access ready; validate before heaters or
   motion are enabled.

## Accepted recovery outcome

Gate 1 does not require the backup set to support a single-step, bit-exact restore
straight to the last installed firmware version. It may support a reproducible,
validated sequence such as official V1.1.0.12 `.ingenic` brick recovery, normal
boot, official update to V1.1.0.15, and restoration of protected device-specific
data and settings to reach a known working starting state.

That sequence is currently a recovery model, not a locally validated procedure,
and V1.1.0.12 is not mandated as the final route. A matching official V1.1.0.15
`.ingenic` image could remove the intermediate update. Identity/factory data must
not be restored until the `.ingenic` write coverage is understood; restoration is
permitted only to the original device and at a stage proven safe for the actual
procedure.

The acceptance criterion is a reproducibly validated return path, not a one-step
restore or a project-authored recovery stack. An open Ingenic USB client and an
independent `.ingenic` build system may remain useful research goals, but are not
prerequisites for Gate 1.

## Acceptance criteria for a future backup

- Every artifact has size, source device/path, timestamp, tool/version, and a
  SHA-256 or stronger hash.
- Offline-extracted partition sizes, offsets, and hashes validate against their
  byte ranges in the whole-user-area image.
- Boot0/boot1 and RPMB status are explicitly accounted for.
- Both A/B sides and selector are present and mutually consistent.
- File-level configs can be inspected without restoring.
- Secrets and unique identity are encrypted and excluded from public Git history.
- A documented restore test succeeds on non-production media/hardware.

## Current blockers

- Bootloader location remains unknown even though the reference EXT_CSD boot
  configuration and health indicators were captured. Creality documents a
  Linux-independent Ingenic USB recovery interface, but its exact write coverage
  and operation on the reference device remain unvalidated.
- Inactive A/B contents were not sampled.
- No safe MCU flash readback method was found.
- The reference system contained writable-storage modifications, so “factory
  state” additionally needs a trusted official V1.1.0.15/F005 image for comparison.
- No official, archived, and verified V1.1.0.15 `.ingenic` recovery set has yet
  been established for the V1.1.0.15 reference system.
