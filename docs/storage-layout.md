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

## EXT CSD metadata

**Confirmed on the reference system:** P1.2-02a read the complete 512-byte
EXT_CSD with read-only access to the kernel debugfs file at
`/sys/kernel/debug/mmc0/mmc0:0001/ext_csd`. The read returned successfully. No
`mmc` utility, block-device read, mount operation, or configuration change was
used. The full raw value is intentionally not reproduced in this public document.

| Field | Observed value | Interpretation |
|---|---:|---|
| `EXT_CSD_REV` | `0x08` | EXT_CSD revision 1.8 / eMMC 5.1 |
| `SEC_COUNT` | `0x00e90e80` | 15,273,600 sectors; confirms the 7,820,083,200-byte user area |
| `BOOT_SIZE_MULTI` | `0x20` | boot0 and boot1 are 4 MiB each |
| `RPMB_SIZE_MULT` | `0x20` | RPMB is 4 MiB |
| `PARTITION_CONFIG` | `0x00` | `BOOT_PARTITION_ENABLE=0`, `PARTITION_ACCESS=0`, `BOOT_ACK=0` |
| `BOOT_BUS_CONDITIONS` | `0x00` | Stored boot-bus configuration is x1, single-data-rate, backward-compatible mode |
| `BOOT_INFO` | `0x07` | The eMMC reports support for alternative boot, DDR boot, and high-speed boot |
| `RST_n_FUNCTION` | `0x00` | The eMMC hardware-reset function is in its temporary disabled/default state |

`PARTITION_CONFIG=0x00` means that the standard eMMC boot operation from boot0,
boot1, or the user area is not currently enabled. This does **not** show that
boot0/boot1 contain no relevant data, nor does it exclude an SoC-specific or
alternative boot mechanism. `BOOT_INFO=0x07` reports capabilities only; it does
not show that the reference system uses any of those boot modes.

Observed health indicators:

| Field | Value | Conservative interpretation |
|---|---:|---|
| `PRE_EOL_INFO` | `0x01` | Normal |
| `DEVICE_LIFE_TIME_EST_TYP_A` | `0x02` | Estimated 10-20% lifetime usage |
| `DEVICE_LIFE_TIME_EST_TYP_B` | `0x01` | Estimated 0-10% lifetime usage |

These are coarse eMMC/JEDEC indicators, not exact wear measurements.

Relevant partitioning, reliability, and write-protection register values were:

| Field | Observed value |
|---|---:|
| `PARTITIONING_SUPPORT` | `0x07` |
| `PARTITION_SETTING_COMPLETED` | `0x00` |
| `PARTITIONS_ATTRIBUTE` | `0x00` |
| `GP_SIZE_MULT_1` through `GP_SIZE_MULT_4` | all zero |
| `ENH_START_ADDR` / `ENH_SIZE_MULT` | both zero |
| `WR_REL_PARAM` | `0x15` |
| `WR_REL_SET` | `0x1f` |
| `USER_WP` | `0x00` |
| `BOOT_WP` | `0x00` |
| `BOOT_WP_STATUS` | `0x00` |
| `BOOT_CONFIG_PROT` | `0x00` |

These are observed register values only. Their functional effect was not tested.
In particular, `PARTITION_SETTING_COMPLETED=0x00` must not be treated as an
invitation to complete or modify the eMMC partition configuration. Changing this
or any other EXT_CSD configuration field is not part of the project.

## GPT user-area layout

**Confirmed on the reference system:** P1.2-02b used the installed BusyBox 1.31.1
`fdisk` as the only available suitable GPT reader. The read-only command
`fdisk -u -l /dev/mmcblk0` returned zero and reported `Found valid GPT with
protective MBR; using GPT`. No raw sectors, partition contents, or gap contents
were read.

The logical and physical block sizes are both 512 bytes. The user area has
15,273,600 sectors, covers physical LBA 0-15,273,599, and is 7,820,083,200 bytes.
The first usable LBA is 34 and the last usable LBA is 15,271,935. The concrete
disk GUID and unique partition GUIDs are not reproduced in this public document.

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

The partition starts and sector counts were independently cross-checked through
kernel sysfs. Partitions p1 through p10 are contiguous; there are no gaps between
them.

### Sectors outside p1-p10

| Region | LBA range | Sectors | Bytes | Status |
|---|---:|---:|---:|---|
| GPT prefix | 0-33 | 34 | 17,408 | Contains at least the protective MBR, primary GPT header, and primary partition-entry array; not free space |
| Usable pre-p1 alignment region | 34-2047 | 2,014 | 1,031,168 | About 0.983 MiB; content not read |
| Gaps between p1-p10 | none | 0 | 0 | All ten partitions are contiguous |
| Usable space after p10 | none | 0 | 0 | p10 ends at the last usable LBA |
| Physical tail after p10 | 15,271,936-15,273,599 | 1,664 | 851,968 | 832 KiB; must contain backup-GPT structures and/or otherwise unallocated tail sectors; content not read |

The p1 start at LBA 2048 is consistent with ordinary 1 MiB alignment. The
LBA 34-2047 region is also large enough in principle to hold loader data, but
there is no positive evidence that it does. It must not be described as either a
loader region or known-empty space. Likewise, the physical tail must not be
described as free or as a loader region.

### GPT verification boundary

BusyBox `fdisk` accepted the GPT and protective MBR, exposed a partition table,
and the resulting partition geometry matched sysfs. This establishes useful
parser-level and geometry evidence, not a complete GPT integrity check.

The available output did **not** establish:

- the exact backup-GPT-header LBA;
- the exact starts and sizes of both partition-entry arrays or the entry size;
- header or partition-entry-array CRC values;
- consistency between primary and backup GPT structures;
- type GUIDs or GPT attributes for p1-p10.

Consequently, `Found valid GPT` must not be cited as proof that both GPT copies
and all CRCs are valid.

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
- EXT_CSD reports no standard eMMC boot source selected in `PARTITION_CONFIG`.
- No `/boot`, `/rom/boot`, U-Boot environment configuration, or named bootloader
  file was found.
- No content from boot0/boot1, RPMB, GPT gaps, or raw partitions was read.

**Open:** The bootloader location, redundancy, version, and recovery protocol
remain unconfirmed. `PARTITION_CONFIG=0x00` weakens the earlier hypothesis that
the active bootloader is probably loaded through the standard eMMC boot0/boot1
operation. Possible locations or mechanisms include the user area, pre-partition
gaps, relevant but currently unselected boot-area contents, or an alternative
SoC-specific boot path. None is established. RPMB may be unreadable through
ordinary block access and must not be assumed backupable.

The newly bounded LBA 34-2047 alignment region is a future research target only.
Its size and the vendor-documented Ingenic USB recovery path make its role worth
determining, but neither result locates a loader there.

## Risks and open questions

- **Risk:** A raw read of `/dev/mmcblk0` would not include eMMC boot0, boot1, or
  RPMB; calling it a complete device backup would be incorrect.
- **Risk:** Live raw capture of mounted ext4 partitions can be crash-consistent at
  best and internally inconsistent at worst.
- **Risk:** Restoring the wrong A/B selector with mismatched kernel/rootfs/RTOS
  images can make both sides unbootable.
- **Open:** Contents and health of inactive partitions 4, 6, and 8.
- **Open:** GPT type GUIDs/attributes, entry-array geometry, CRCs, and
  primary/backup consistency were not exposed or verified by the available
  BusyBox `fdisk` output.
- **Open:** Reliable RPMB access and whether RPMB is provisioned or used.
- **Open:** Bootloader placement and whether boot0 and boot1 contain identical or
  fallback loaders.
