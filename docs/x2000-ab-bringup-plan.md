# X2000 A/B one-shot bring-up plan

This is the selected architecture for the first open-Linux bring-up. It records
the read-only qualification, the completed bounded p1 selector test, the Slot-B
deployment, and the verified Slot-B smoke boot. Phase 3.3b is **IN PROGRESS**:
the early-userspace smoke path is proven, while printer functionality remains
unqualified.
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

## Earlier controlled Slot-B hardware attempt

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
The corrected selector passed syntax and fixture tests and was verified
byte-for-byte inside a rebuilt Slot-B SquashFS.

## Verified Slot-B smoke boot

The freshly generated Slot-B build from commit
`47155a3b8bb0cc75facce00191ff36340d222ee3` (`fix: correct KE slot B early
boot`) was validated offline before the hardware test. The manifest's
`project_commit` matches that commit exactly and reports `slot_b_smoke = true`.
The manifest hashes matched for `SHA256SUMS`, `buildroot.config`,
`effective-kernel-config`, `ender3-v3-ke-slot-b.dtb`, `kernel-slot-b.uImage`,
and `rootfs-slot-b.squashfs`. The worktree was clean at validation time.

The built kernel artifact is an uncompressed legacy xImage/uImage containing
Linux `6.6.18-rt23`, with load address and entry point both `0x80f00000`. The
effective configuration enabled the KE-specific `CONFIG_DT_ENDER3_V3_KE`,
`CONFIG_BRCMFMAC`, `CONFIG_BRCMFMAC_SDIO`, and
`CONFIG_TOUCHSCREEN_NS2009` options. The Halley5 reference-board options
`CONFIG_BCMDHD`, `CONFIG_TOUCHSCREEN_GT9XX`,
`CONFIG_HALLEY5_CAMERA_BOARD`, `CONFIG_RD_X2000_HALLEY5_CAMERA_4V3`, and
`CONFIG_INGENIC_ISP_CAMERA_OV2735A` were not enabled. The DT command line was:

```text
console=ttyS4,115200 root=/dev/mmcblk0p8 rootwait rootfstype=squashfs ro
```

The p8 rootfs contained a byte-exact copy of the repository's
`/usr/libexec/slot-b-selector`. Fixture mode continued to use
`${TMPDIR:-/tmp}`; the real-hardware mode used `/run/slot-b-selector.$$`.

The kernel was written to p6 and the rootfs to p8. Both writes passed complete
read-back verification, and remote preflight passed before and after deployment.
Stock A remained in p5/p7 throughout deployment.

On the reference system, the boot test began from Stock A with
`root=/dev/mmcblk0p7`. The exact Stock-A selector in p1 had SHA256
`ba68d7c969bfee94216c94768ec65545cf36cb352303ab55231c78e78b51ce6b`.
It was controlled to the exact Slot-B selector, whose SHA256 was
`29a335bc1f2935f9ee79955da3566d5f70d1b0591421745395fd714c8351bdc4`, and
the B value was confirmed by read-back before reboot.

The successful test, together with the verified Slot-B artifacts and boot configuration,
establishes the following boot and rollback chain:

```text
Stock A
  -> p1 A -> B
  -> SPL loads p6
  -> Linux 6.6.18-rt23 starts
  -> p8 is used as the SquashFS root
  -> early userspace/init is reached
  -> S00slot-b-revert changes p1 B -> A
  -> S01slot-b-smoke-reboot runs
  -> reboot
  -> Stock A starts again
```

After the reboot, `/proc/cmdline` again contained `root=/dev/mmcblk0p7`, p1
again had the exact Stock-A SHA256
`ba68d7c969bfee94216c94768ec65545cf36cb352303ab55231c78e78b51ce6b`, and its
first bytes were again `ota:kernel\n\n`. This is the first real-hardware proof
of the complete Slot-B-to-early-userspace-to-automatic-Stock-A-return chain.

The reached milestone is therefore:

> Mainline Linux 6.6 on the Ender-3 V3 KE successfully boots from Slot B into
> early userspace and performs the verified automatic rollback to Stock A.

This smoke test does **not** prove persistent operation of the mainline
userspace, network operation, display, touch, WLAN, USB, Klipper, motor
control, heaters, temperature sensors, or any other printer peripheral.
Network cannot be assessed from this test because network and Dropbear were
intentionally disabled in the Slot-B smoke rootfs.

Two concrete issues were corrected before this successful test: Halley5
reference-board built-in drivers were disabled for the KE build, and the
real-hardware selector temporary files were moved from `/tmp` to `/run`, which
the inittab mounts as tmpfs before `rcS`. The successful result demonstrates
the current combined state. It does not establish which correction, if either,
caused any particular earlier boot failure.

## Status

- Phase 3.3a: **COMPLETE**.
- A/B read-only qualification: **COMPLETE**.
- Phase 3.3b controlled hardware evaluation: **IN PROGRESS**; the Slot-B
  deployment, complete read-back, early-userspace smoke boot, automatic p1
  rollback, and return to Stock A are proven. Printer peripherals and
  persistent mainline operation remain unqualified.
- A/B ROLLBACK GATE: **SATISFIED for p1-only A -> B -> A**.
- Gate 1: **SATISFIED** by the current evidence review; recovery execution remains
  documented but not personally rehearsed.
- p9/p10: **UNKNOWN / RESERVED**; this plan grants no ownership or role.
