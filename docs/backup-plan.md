# Backup plan and capture record

A private reference-device backup was captured read-only on 2026-08-08 and
validated offline. The device-specific images, identity data, GUIDs, logs, and
hash manifests remain under the ignored local workspace and are not published.
This document records both the reusable requirements and the status of that
capture.

The concrete geometry and paths below were observed on the reference system
running Creality firmware `V1.1.0.15`. Verify them before applying this plan to a
different device or firmware revision.

## Definition of a complete backup

A single image of `/dev/mmcblk0` is not complete because eMMC boot0, boot1, and
RPMB are outside its user area, while main-MCU firmware is on a different device.
A useful recovery set needs raw media coverage, offline-derived partition-level
artifacts, a file-level persistent-data export, metadata, and independent
verification.

## Reference-device capture status

The first private reference capture completed successfully:

- the 7,820,083,200-byte eMMC user area was streamed exactly once; the SHA-256
  calculated during streaming matched a second SHA-256 calculated from the stored
  file;
- boot0 and boot1 were captured independently at 4 MiB each and are entirely
  zero-filled;
- p1-p10 were derived offline from the single whole-user-area image and hashed;
- the primary GPT header CRC and partition-entry-array CRC validate;
- the captured GPT has no conventional backup-GPT header in the physical tail;
- separate live read-only file exports of `/overlay/upper` and `/usr/data` were
  created, hashed, gzip-tested, and tar-listed successfully;
- p7 and p8 SquashFS images pass full offline archive tests;
- p9 `rootfs_data` passes read-only `e2fsck -fn` with exit code 0;
- p10 `userdata` produces `e2fsck -fn` exit code 4 with inode/block/bitmap
  inconsistencies, consistent with the documented limitation of streaming a
  mounted writable ext4 filesystem; its raw image remains preserved unchanged and
  its successful file-level `/usr/data` export is the complementary recovery
  artifact;
- RPMB was inventoried but not read; no safe authenticated data-backup method was
  established;
- shipped MCU artifacts are covered by the captured filesystems, while physical
  MCU flash readback was not performed.

The p10 result is a documented consistency limitation, not a hash or transport
failure. The raw image is an exact record of the bytes observed during the live
stream, but it must not be described as a clean filesystem snapshot.

## Required artifacts A-K

| Category | Required recovery-set content | Why / caveat |
|---|---|---|
| **A. Raw flash** | Entire 15,273,600-sector `/dev/mmcblk0` user area, read once as one artifact | Preserves every user-area byte: protective MBR, GPT structures present in the user area, LBA 34-2047, all ten partitions, and the entire physical tail after p10; does not include eMMC hardware boot/RPMB areas |
| **B. Individual partitions** | Images of p1-p10 extracted offline from artifact A, plus sizes, start/end sectors, GPT disk/partition GUIDs and attributes, and cryptographic hashes | Enables selective recovery and verification while keeping all partitions tied to the exact same raw capture; separate live partition reads are not a prerequisite |
| **C. Bootloader** | eMMC boot0 and boot1 as separate artifacts; captured EXT_CSD boot-selection/config metadata; user-area pre-p1 boot material | Reference capture completed: boot0/boot1 are all-zero and the persistent boot material is present in the user area before p1 |
| **D. Kernel** | p5 `kernel` and p6 `kernel2` | Preserve both A/B states, even if one appears unused |
| **E. RootFS** | p7 `rootfs` and p8 `rootfs2` | Captured and validated: active p7 is V1.1.0.15; inactive p8 exactly matches the official V1.1.0.12 recovery SquashFS plus zero padding |
| **F. Data partition** | p9 `rootfs_data` raw image plus filesystem metadata | Contains the overlay and all deviations from immutable RootFS |
| **G. `/usr/data`** | p10 raw image and a separate file-level archive preserving ownership, modes, symlinks, xattrs if supported, sparse files, and timestamps | Contains configs, logs, gcode, Moonraker, swap, identity/user data, and any writable-storage additions |
| **H. Klipper/Moonraker** | Immutable `/usr/share/klipper` and `/usr/share/klippy-env` (covered by RootFS), `/usr/data/moonraker`, service overrides, versions/hashes, and any local Klipper trees identified in the private inventory | Required to reproduce the current runtime while keeping stock and local additions distinguishable |
| **I. Configuration** | Current `printer_data/config`, all included config files, Moonraker config, secrets, certificates, database, saved meshes/Z offset/input shaping, and rollback/config backups | Secrets must be encrypted/access-controlled; avoid publishing them in Git |
| **J. MCU firmware** | Distributed F005 images, current MCU/Host-MCU version evidence, `/usr/bin/klipper_mcu`, and—if a safe supported readback is later found—an actual MCU flash dump | The shipped `.bin` is not proof of every byte currently flashed; no safe readback was found |
| **K. Creality recovery/factory data** | p1 `ota`, p2 `sn_mac`, p3/p4 RTOS pair, `/etc/ota_info`, `/etc/ota_bin`, Creality system/device configs, `machine_production_info`, factory test data, upgrade logs/config, and official matching OTA `.img` and recovery `.ingenic` material where available | Device identity and pairing data are unique and sensitive; vendor binaries remain external unless redistribution rights are verified |

RPMB should be inventoried separately. It may be authenticated and not normally
readable/exportable. Failure to capture RPMB must be explicitly stated, not hidden
under “full backup.”

## Why the backup must precede any Cloner test

Offline analysis of the official V1.1.0.12 `.ingenic` package shows that it is a
selective recovery package, not a complete eMMC image. Its active configuration
writes only boot/SPL/U-Boot/GPT, p3 RTOS, p5 kernel, and p7 RootFS.

The same configuration contains the erase settings:

```text
erase_all=1
erase_list="0x0,0x1fffff;0x300000,0xffffffff;"
force_erase=2
```

The exact Cloner runtime interpretation has not been executed. Under the
straightforward inclusive byte-range interpretation, p1 is erased without being
rewritten, p2 `sn_mac` lies outside both ranges, p3-p9 are erased, and the lower
part of p10 is erased. The inactive p4/p6/p8 side and writable p9/p10 data would
therefore not survive as usable filesystems.

Consequently a Cloner trial is authorized only after the complete private capture
set below exists and has passed offline verification. `sn_mac` must be preserved
even though the static configuration suggests p2 is intentionally skipped.

## Capture sequence

The reference-device capture followed this sequence under explicit authorization.
It remains the recommended basis for future compatible-device captures, subject to
fresh geometry and safety checks.

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

## Acceptance criteria for the reference backup

- Every artifact has size, source device/path, timestamp, tool/version, and a
  SHA-256 or stronger hash.
- Offline-extracted partition sizes, offsets, and hashes validate against their
  byte ranges in the whole-user-area image.
- Boot0/boot1 and RPMB status are explicitly accounted for.
- Both A/B sides and selector are present and mutually consistent.
- File-level configs can be inspected without restoring.
- Secrets and unique identity are protected and excluded from public Git history.

A restore rehearsal is a Gate-1 recovery-validation requirement rather than a
condition for the byte-level capture itself to be considered complete. It should
prefer spare/non-production media or a controlled fixture where practical.

## Current blockers and limitations

- The private capture and its offline hash/structure validation are complete, but
  the p10 raw image is not a clean ext4 snapshot because it was streamed while the
  source filesystem was mounted writable. The separate `/usr/data` file archive
  is therefore part of the required recovery set.
- RPMB remains inventory-only; no safe authenticated readback method has been
  established.
- No safe physical main-MCU flash readback method was found; shipped MCU artifacts
  and version evidence are preserved instead.
- Static analysis has identified the Cloner package's write policy and broad erase
  ranges, but exact runtime semantics and p2 `sn_mac` preservation remain
  practically unvalidated.
- The direct V1.1.0.12-to-V1.1.0.15 OTA stage is confirmed by the retained device
  log. The remaining major Gate-1 recovery uncertainty is the destructive
  `.ingenic` brick-recovery stage and the exact safe identity-restoration point.
- A second independent physical copy of the private recovery set should exist
  before any destructive recovery experiment.
