# X2000 A/B one-shot bring-up plan

This is the selected architecture for the first open-Linux bring-up. It is a
read-only qualification plan; it does not authorize a partition write,
selector change, reboot, USB boot, or deployment. Phase 3.3b remains **NOT
STARTED**.

## Selected boundary

Stock A remains the recovery baseline:

```text
Stock A (p5 kernel, p7 rootfs)
        |
        | later, only after Gate 1 and the A/B ROLLBACK GATE are satisfied
        v
p1 = ota:kernel2  ->  Slot B (p6 kernel2, p8 rootfs2)
                               |
                               | early userspace restores p1 to A
                               v
                         controlled reboot -> Stock A
```

The first test must not confirm B again. The expected return of Stock A SSH
after the controlled reboot is the external observation channel. If the kernel
fails before userspace can restore p1, p1 remains B; the planned USB-p1 rollback
is the intended emergency exit. USB-p1 rollback is not yet qualified.

The RAM-only `kernel-ramboot.uImage` path remains an investigated and deferred
alternative. It is not the selected main path and is not a prerequisite for
the first open-Linux boot.

## Read-only qualification record

The fresh reference-system read-only qualification is **COMPLETE**. It was
performed without changing the device. The observed active Stock A root is p7;
p6 and p8 are unmounted. p9 and p10 are mounted only by the Stock system and
remain outside this project's ownership.

| Check | Required result |
| --- | --- |
| active command line | `root=/dev/mmcblk0p7` |
| p1 selector | exact `ota:kernel` record |
| p6/p8 mounts | neither mounted |
| labels | `ota`, `kernel`, `kernel2`, `rootfs`, `rootfs2`, `rootfs_data`, `userdata` map to p1, p5, p6, p7, p8, p9, p10 |
| sizes | p1 1 MiB; p5/p6 8 MiB; p7/p8 500 MiB; p9 300 MiB; p10 approximately 6130 MiB |
| p1 prefix | `ota:kernel` followed by two newline bytes and NUL padding in the inspected 512-byte record |
| B-side content | compare p6 and p8 read-only with uniquely assigned private references; report only `MATCH`, `NO MATCH`, or `UNKNOWN` |

The confirmed partlabel mapping is p1 `ota`, p5 `kernel`, p6 `kernel2`, p7
`rootfs`, p8 `rootfs2`, p9 `rootfs_data`, and p10 `userdata`. Confirmed sizes
are p1 1 MiB, p5/p6 8 MiB, p7/p8 500 MiB, p9 300 MiB, and p10 6,427,770,880
bytes. The first 512 bytes of p1 are exactly `ota:kernel\n\n` followed by NUL
padding. No device-specific address, fingerprint, or private hash is recorded.

No live identifier, address, fingerprint, or private hash is part of this
public document.

## Stock selector semantics

The inspected Stock `ota_local_method.sh` reads the `ota` partition through
the direct `mmc_read_str` helper. A record beginning with `ota:kernel2` makes
the current update targets the A names (`kernel`, `rootfs`, `rtos`); otherwise
the default targets are the B names (`kernel2`, `rootfs2`, `rtos2`). Its
`local_set_next_boot_device` function writes the opposite selector as
`ota:kernel` or `ota:kernel2` through `mmc_write_str`.

The direct helper resolves a partition label to a real eMMC block device,
reads 256 bytes from p1, and writes the selector string to that device. The
Stock selector operation itself does not imply a p6/p8 image write, a p9/p10
mount, a GPT change, or a bootloader write. The offline OTA call-path evidence
shows the normal updater writing and verifying the selected kernel/rootfs/RTOS
side before changing p1; that persistent update transaction is not the selected
bring-up operation and remains unexercised here.

## Slot-B artifact contract

The existing generic and RAM-only build semantics remain unchanged. The
13,629,855-byte `kernel-ramboot.uImage` is larger than the 8 MiB p6 partition
and contains a built-in initramfs; it must never be treated as a p6 image.
The planned separate artifacts are:

- `kernel-slot-b.uImage`, strictly smaller than 8 MiB;
- `rootfs-slot-b.squashfs`, strictly smaller than 500 MiB.

They are planned only; no Slot-B artifact is built by this document.

The Slot-B DT command line must be explicit and must not inherit Stock A's
`root=/dev/mmcblk0p7`:

```text
console=ttyS4,115200 root=/dev/mmcblk0p8 rootwait rootfstype=squashfs ro
```

The pinned Linux 6.6 source currently supplies the console through the KE DT.
The selected Slot-B DT/build must verify whether any additional required
argument is needed; no additional argument is assumed here.

## First-B rootfs contract

The first Slot-B smoke rootfs is immutable and deliberately isolated:

- p8 is the read-only root;
- `/run` and `/tmp` are tmpfs;
- `/dev`, `/proc`, and `/sys` are runtime mounts;
- p9 and p10 are not mounted;
- `/dev/ttyS1` is not opened;
- no OTA/update service, filesystem repair, `mke2fs`, or swap starts.

## Fail-closed write design (future only)

No writer is implemented now. A later writer must refuse to operate unless
the active root is p7; p6 and p8 are the exact labelled real block devices;
all expected sizes match; both targets are unmounted; p1 is exactly
`ota:kernel`; and the kernel/rootfs fit their partitions. It may then write
only the exact image bytes to p6 and p8, read back and verify those bytes, and
leave p1 at A. It must never write the whole disk, p5, p7, p9, p10, GPT, or
the bootloader.

## A/B ROLLBACK GATE

This gate is **NOT SATISFIED**. Before any p6/p8 write or selector test, a
separate authorization and demonstration must prove:

1. BootROM USB is reached;
2. RAM U-Boot starts successfully;
3. p1 is read correctly over USB without writing;
4. a controlled p1 `A -> B -> A` round trip is read-back verified;
5. normal Stock A boot is confirmed afterwards; and
6. p5 and p7 remain unchanged.

This additional A/B rollback gate does not replace Gate 1; it remains a separate
required condition. Until both boundaries are satisfied, no persistent write is
authorized and p6/p8 remain untouched by this project.

## Status

- Phase 3.3a: **COMPLETE**.
- A/B read-only qualification: **COMPLETE**.
- Phase 3.3b persistent deployment: **NOT STARTED**.
- A/B ROLLBACK GATE: **NOT SATISFIED**.
- Gate 1: **SATISFIED** by the current evidence review; recovery execution remains
  documented but not personally rehearsed.
- p9/p10: **UNKNOWN / RESERVED**; this plan grants no ownership or role.
