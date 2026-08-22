# X2000 A/B one-shot bring-up plan

This is the selected architecture for the first open-Linux bring-up. It records
the read-only qualification, the completed bounded p1 selector test, and the
first controlled Slot-B hardware attempt. Phase 3.3b is **IN PROGRESS**.
Persistent or boot-changing hardware operations continue to require explicit
authorization.

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

The completed p1-only test did not boot B. For the later Slot-B test, the
expected return of Stock A SSH after the controlled reboot is the external
observation channel. If the kernel fails before userspace can restore p1, p1
remains B; the USB-p1 rollback is the intended emergency exit and is now
qualified only for the p1 A -> B -> A selector roundtrip.

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
The separate Slot-B artifacts are:

- `kernel-slot-b.uImage`, strictly smaller than 8 MiB;
- `rootfs-slot-b.squashfs`, strictly smaller than 500 MiB.

They are produced by the separately documented `--slot-b-smoke` build mode.
The first controlled hardware deployment wrote these artifact types to p6 and
p8 and verified both by immediate read-back.

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

## Fail-closed deployment writer

`scripts/deploy-x2000-slot-b-smoke` implements the bounded Slot-B deployment
path. Its default mode is read-only. Before `--write`, it requires the active
root to be p7; p1, p6, and p8 to resolve to the expected devices; all expected
sizes to match; p6 and p8 to be unmounted; p1 to contain the exact Stock-A
selector; the local artifacts to match their recorded hashes and fit their
partitions; and the tracked working tree and relevant build inputs to match
the artifact provenance.

In write mode it writes only the exact Slot-B artifact bytes to p6 and p8,
reads the written ranges back, verifies their hashes, and leaves p1 at A. It
does not write the whole disk, p5, p7, p9, p10, GPT, or the bootloader. The
first controlled hardware deployment using this writer completed successfully.

## A/B ROLLBACK GATE

This gate is **SATISFIED for the bounded p1-only selector test**. The separate
authorization and demonstration proved:

1. BootROM USB is reached;
2. RAM U-Boot starts successfully;
3. p1 is read correctly over USB without writing;
4. a controlled p1 `A -> B -> A` round trip is read-back verified;
5. normal Stock A boot is confirmed afterwards; and
6. the executed write path was limited to the 512-byte p1 selector; no
   before/after hash comparison of p5 or p7 was performed.

This additional A/B rollback gate does not replace Gate 1 and did not by
itself authorize p6/p8 deployment. A later separately authorized Phase 3.3b
operation deployed the prepared Slot-B artifacts to p6/p8. Before and after
that deployment, p5 and p7 were hashed and confirmed byte-for-byte unchanged.
The first B boot did not return automatically, and the qualified external
USB-p1 rollback subsequently restored Stock A.

## First controlled Slot-B hardware attempt

The first Phase 3.3b hardware deployment wrote only the prepared Slot-B kernel
to p6 and the Slot-B SquashFS to p8. Both writes passed immediate read-back
verification. Before and after the deployment, the Stock-A p5 and p7 hashes
matched exactly, and p1 remained on the Stock-A selector until the separately
authorized boot test.

For the first controlled B boot, p1 was changed from the exact Stock-A selector
to the exact `ota:kernel2` selector and read back successfully. Stock A did not
return automatically. The device was then placed in Ingenic USB BootROM mode,
RAM U-Boot was loaded through the previously qualified path, p1 was read
externally and confirmed still to contain the exact B selector, and the
qualified `B -> A` selector rollback was performed and read back successfully.
A subsequent normal boot returned to Stock A on `/dev/mmcblk0p7`, and p1 again
matched the exact Stock-A selector.

Offline analysis found a concrete defect in the first smoke RootFS: the early
`S00slot-b-revert` runs before `S10mdev`, while the selector required
`/dev/disk/by-partlabel/ota`. The built SquashFS contains no static
`/dev/disk/...` path, and its `mdev.conf` contains no rule that creates
`by-partlabel` links. Therefore, if the first B boot reached the selector, that
selector necessarily refused before changing p1. The observed retained B
selector is consistent with this failure mode, but the available evidence does
not independently prove that the kernel reached `S00slot-b-revert`.

The selector was subsequently changed so that its real-hardware path validates
the fixed `/dev/mmcblk0p1` and `/dev/mmcblk0p8` A/B contract directly through
sysfs before touching p1. Fixture mode retains its synthetic partlabel check.
The corrected selector passes syntax and fixture tests and has been verified
byte-for-byte inside a rebuilt Slot-B SquashFS. A second hardware boot has not
yet been attempted.

## Status

- Phase 3.3a: **COMPLETE**.
- A/B read-only qualification: **COMPLETE**.
- Phase 3.3b controlled hardware evaluation: **IN PROGRESS**; first p6/p8
  deployment and read-back verification succeeded, the first B boot did not
  return automatically, external USB-p1 rollback succeeded, and a corrected
  selector is awaiting a second controlled hardware attempt.
- A/B ROLLBACK GATE: **SATISFIED for p1-only A -> B -> A**.
- Gate 1: **SATISFIED** by the current evidence review; recovery execution remains
  documented but not personally rehearsed.
- p9/p10: **UNKNOWN / RESERVED**; this plan grants no ownership or role.
