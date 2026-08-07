# Storage layout

See [`system-inventory.md`](system-inventory.md) for platform context and
[`ssh-command-log.md`](ssh-command-log.md) for the evidence-producing commands.
No block-device contents were copied.

Unless stated otherwise, this layout was observed on the reference system running
Creality firmware `V1.1.0.15`. It must be verified before use with another
firmware or hardware revision.

## Storage type

**Confirmed:** Internal non-volatile storage is eMMC, not MTD/NAND exposed through
Linux MTD. `/proc/mtd` contains only its header, `/sys/class/mtd` is empty, and no
`/dev/mtd*` or `/dev/mtdblock*` nodes exist.

The eMMC identifies as:

- type `MMC`, name `DG4008`
- manufacturer ID `0x45`, OEM ID `0x0100`
- 15,273,600 logical sectors at 512 bytes = 7,820,083,200 bytes
  (about 7.28 GiB)
- separate 4 MiB `boot0`, 4 MiB `boot1`, and 4 MiB RPMB areas

Unit-specific eMMC manufacturing and identity fields are kept only in the ignored
`local-device.md`.

BusyBox `fdisk` printed the whole device as `3361M`; this is inconsistent with its
own sector count and `/proc/partitions` and is **inferred** to be a 32-bit size
format/overflow defect. Sector counts are used below.

Both eMMC boot areas report `ro=1` and `force_ro=1`. This protects against normal
writes, but does not identify their contents.

## GPT user-area layout

The reference disk has a protective MBR and GPT. Its concrete disk GUID is kept in
the ignored `local-device.md`. The first usable sector is 34; partitions start at
sector 2048. The last partition reaches the last usable sector 15,271,935.

| Part. | Node | Sectors | Size | GPT name | Observed/inferred role |
|---:|---|---:|---:|---|---|
| 1 | `/dev/mmcblk0p1` | 2048-4095 | 1 MiB | `ota` | **Confirmed:** A/B selection string used by OTA scripts |
| 2 | `/dev/mmcblk0p2` | 4096-6143 | 1 MiB | `sn_mac` | **Confirmed:** device identity/model/board/factory fields |
| 3 | `/dev/mmcblk0p3` | 6144-14335 | 4 MiB | `rtos` | **Confirmed:** RTOS A update target/name |
| 4 | `/dev/mmcblk0p4` | 14336-22527 | 4 MiB | `rtos2` | **Confirmed:** RTOS B update target/name |
| 5 | `/dev/mmcblk0p5` | 22528-38911 | 8 MiB | `kernel` | **Confirmed:** kernel A update target/name; active side inferred from root selection |
| 6 | `/dev/mmcblk0p6` | 38912-55295 | 8 MiB | `kernel2` | **Confirmed:** kernel B update target/name |
| 7 | `/dev/mmcblk0p7` | 55296-1079295 | 500 MiB | `rootfs` | **Confirmed active:** SquashFS root selected by kernel command line |
| 8 | `/dev/mmcblk0p8` | 1079296-2103295 | 500 MiB | `rootfs2` | **Confirmed:** alternate RootFS update target; content not read |
| 9 | `/dev/mmcblk0p9` | 2103296-2717695 | 300 MiB | `rootfs_data` | **Confirmed active:** ext4 writable overlay |
| 10 | `/dev/mmcblk0p10` | 2717696-15271935 | 6130 MiB | `userdata` | **Confirmed active:** ext4 mounted at `/usr/data` |

## Active mount graph

```text
/dev/mmcblk0p7 (SquashFS, read-only)
  -> /rom
     + /dev/mmcblk0p9 (ext4, /overlay)
       -> overlayfs root /

/dev/mmcblk0p10 (ext4)
  -> /usr/data
```

Concrete free-space and usage values are transient, device-specific observations
and are kept only in the ignored `local-device.md`. Verify sufficient free space
on both writable filesystems before backup, deployment, or migration operations.

Only partitions 9 and 10 returned UUIDs through `blkid`. Partition 7's SquashFS
type is nevertheless directly confirmed by both the command line and mount table.
No filesystem claims are made for the inactive/raw partitions because their
contents were not sampled.

## A/B behavior

**Confirmed from OTA scripts:** The `ota` partition contains a short selector of
the form `ota:kernel` or `ota:kernel2`. If it names `kernel2`, the updater targets
the A partitions (`kernel`, `rootfs`, `rtos`); otherwise it targets the B
partitions. After all selected images have been written and verified, the updater
changes the selector to the newly written side.

**Confirmed on the reference system:** The captured boot uses `/dev/mmcblk0p7`, so
RootFS A was active. The exact selector string was not read: Creality's provided
helper reads it using `dd`, which was explicitly prohibited for this inventory.

**Inference:** Kernel A (`p5`) was selected together with RootFS A, because the OTA
logic switches the set as a unit. Direct bootloader evidence was not obtained.

## Bootloader and non-user areas

- `mmcblk0boot0` and `mmcblk0boot1` exist, each 4 MiB and read-only.
- No `/boot`, `/rom/boot`, U-Boot environment configuration, or named bootloader
  file was found.
- No content from boot0/boot1, RPMB, GPT gaps, or raw partitions was read.

**Open:** The bootloader is likely in an eMMC boot area or otherwise outside the
named GPT payload partitions, but its exact location, redundancy, version, and
recovery protocol remain unconfirmed. RPMB may be unreadable through ordinary
block access and must not be assumed backupable.

## Risks and open questions

- **Risk:** A raw read of `/dev/mmcblk0` would not include eMMC boot0, boot1, or
  RPMB; calling it a complete device backup would be incorrect.
- **Risk:** Live raw capture of mounted ext4 partitions can be crash-consistent at
  best and internally inconsistent at worst.
- **Risk:** Restoring the wrong A/B selector with mismatched kernel/rootfs/RTOS
  images can make both sides unbootable.
- **Open:** Contents and health of inactive partitions 4, 6, and 8.
- **Open:** GPT partition GUIDs/attributes were not exposed by the available
  BusyBox `fdisk` output.
- **Open:** eMMC health/lifetime fields and reliable RPMB access.
- **Open:** Bootloader placement and whether boot0 and boot1 contain identical or
  fallback loaders.
