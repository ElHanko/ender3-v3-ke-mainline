# Backup plan (analysis only)

No backup was performed. This is a requirements and sequencing plan derived only
from the read-only inventory.

The concrete geometry and paths below were observed on the reference system
running Creality firmware `V1.1.0.15`. Verify them before applying this plan to a
different device or firmware revision.

## Definition of a complete backup

A single image of `/dev/mmcblk0` is not complete because eMMC boot0, boot1, and
RPMB are outside its user area, while main-MCU firmware is on a different device.
A useful recovery set needs raw media coverage, partition-level artifacts, a
file-level persistent-data export, metadata, and independent verification.

## Required artifacts A-K

| Category | What must later be captured | Why / caveat |
|---|---|---|
| **A. Raw flash** | Entire 15,273,600-sector `/dev/mmcblk0` user area, including protective MBR, primary/backup GPT, gaps, and all ten partitions | Preserves exact layout and unnamed sectors; does not include eMMC hardware boot/RPMB areas |
| **B. Individual partitions** | Separate images of p1-p10 plus sizes, start/end sectors, GPT disk/partition GUIDs and attributes, cryptographic hashes | Enables selective recovery and verification; must remain tied to the same capture set |
| **C. Bootloader** | eMMC boot0 and boot1 as separate artifacts; the captured eMMC EXT_CSD boot-selection/config metadata; bootloader version/config if discoverable | `PARTITION_CONFIG=0x00` selects no standard eMMC boot source, but location remains unconfirmed; never assume `/dev/mmcblk0` or boot0/boot1 alone includes the active bootloader |
| **D. Kernel** | p5 `kernel` and p6 `kernel2` | Preserve both A/B states, even if one appears unused |
| **E. RootFS** | p7 `rootfs` and p8 `rootfs2` | p7 is the active SquashFS; p8 contents/health are unknown |
| **F. Data partition** | p9 `rootfs_data` raw image plus filesystem metadata | Contains the overlay and all deviations from immutable RootFS |
| **G. `/usr/data`** | p10 raw image and a separate file-level archive preserving ownership, modes, symlinks, xattrs if supported, sparse files, and timestamps | Contains configs, logs, gcode, Moonraker, swap, identity/user data, and any writable-storage additions |
| **H. Klipper/Moonraker** | Immutable `/usr/share/klipper` and `/usr/share/klippy-env` (covered by RootFS), `/usr/data/moonraker`, service overrides, versions/hashes, and any local Klipper trees identified in the private inventory | Required to reproduce the current runtime while keeping stock and local additions distinguishable |
| **I. Configuration** | Current `printer_data/config`, all included config files, Moonraker config, secrets, certificates, database, saved meshes/Z offset/input shaping, and rollback/config backups | Secrets must be encrypted/access-controlled; avoid publishing them in Git |
| **J. MCU firmware** | Distributed F005 images, current MCU/Host-MCU version evidence, `/usr/bin/klipper_mcu`, and—if a safe supported readback is later found—an actual MCU flash dump | The shipped `.bin` is not proof of every byte currently flashed; no safe readback was found |
| **K. Creality recovery/factory data** | p1 `ota`, p2 `sn_mac`, p3/p4 RTOS pair, `/etc/ota_info`, `/etc/ota_bin`, Creality system/device configs, `machine_production_info`, factory test data, upgrade logs/config, official matching `.img` package | Device identity and pairing data are unique and sensitive |

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
4. **Capture user area and partitions:** produce both whole-user-area and p1-p10
   artifacts. Hash while streaming to the local PC and hash stored results again.
5. **Capture persistent files:** create a file-level `/overlay/upper` and
   `/usr/data` export to complement raw ext4 images.
6. **Capture MCU evidence/images:** preserve shipped images and versions; do not
   attempt MCU readback until the protocol and safety are understood.
7. **Cross-check:** partition images must match the corresponding byte ranges of
   the whole-user-area image; record every mismatch.
8. **Offline validation:** parse GPT, mount filesystem images read-only on the PC,
   validate SquashFS, list archives, and verify every hash.
9. **Recovery rehearsal:** restore only to spare media/hardware or a controlled
   fixture before relying on the set for the production printer.

## Consistency strategy

**Risk:** p9 and p10 are mounted read-write and actively changed by logs, databases,
camera history, and services. A live stream may contain an inconsistent ext4 image.

The preferred later strategy is an offline/pre-Linux capture through a verified
bootloader/ROM/recovery environment that does not mount the source media writable.
No such method has yet been established. Stopping services, remounting, freezing
filesystems, or booting alternate media would change system state and therefore
was not attempted.

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

## Acceptance criteria for a future backup

- Every artifact has size, source device/path, timestamp, tool/version, and a
  SHA-256 or stronger hash.
- Whole-disk and partition byte ranges cross-validate.
- Boot0/boot1 and RPMB status are explicitly accounted for.
- Both A/B sides and selector are present and mutually consistent.
- File-level configs can be inspected without restoring.
- Secrets and unique identity are encrypted and excluded from public Git history.
- A documented restore test succeeds on non-production media/hardware.

## Current blockers

- Bootloader location and recovery interface remain unknown even though the
  reference EXT_CSD boot configuration and health indicators were captured.
- Inactive A/B contents were not sampled.
- No safe MCU flash readback method was found.
- The reference system contained writable-storage modifications, so “factory
  state” additionally needs a trusted official V1.1.0.15/F005 image for comparison.
