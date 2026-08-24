# X2000 A/B bring-up and development plan

This is the selected architecture for the first open-Linux bring-up. It records
the read-only qualification, the completed bounded p1 selector test, the Slot-B
deployment, and the verified Slot-B smoke boot. Phase 3.3b is **IN PROGRESS**:
the early-userspace smoke path and a bounded administrative network path are
proven. `2026.1.a` is the first functional alpha of the open X2000 host on the
investigated reference system. Research and feasibility are complete for this
usable Open-Host baseline; development, stabilization, and integration toward
final `2026.1` are now in progress. Printer functionality remains unqualified.
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
- `/run` is a tmpfs runtime mount;
- `/dev`, `/proc`, and `/sys` are runtime mounts;
- p9 and p10 are not mounted;
- `/dev/ttyS1` is not opened;
- no OTA/update service, filesystem repair, `mke2fs`, or swap starts.

The later Network-Smoke runtime established that `/tmp` must not be described
as a separate tmpfs mount: the captured mount table contains no such mount.
The shared overlay's `inittab` requests a `devpts` mount, but the same runtime
had neither `/dev/pts` nor a mounted `devpts` filesystem. Static configuration
is therefore not evidence that either facility is available at runtime.

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

## Verified Slot-B Network-Smoke boot (2026-08-23)

The separately built, locally provisioned Network-Smoke artifacts were deployed
to p6/p8 in a separately authorized operation. Complete kernel and RootFS
read-back verification passed. Stock A remained active during deployment, and
p1 still contained the documented exact Stock-A selector before the boot test.

For the test, p1 was changed from A to B and read-back verified before reboot.
Linux `6.6.18-rt23` then booted from p6 with the following active command line:

```text
console=ttyS4,115200 root=/dev/mmcblk0p8 rootwait rootfstype=squashfs ro
```

The active root was `/dev/root` as a read-only SquashFS. While that Mainline
system was still running from p8, a read of p1 matched the already documented
exact Stock-A selector. This directly proves the intended ordering: the early
userspace selector had already restored B to A, while the Network-Smoke system
continued to run. A previously controlled power-cycle of that armed state had
already returned to Stock A on p7.

The following network path is directly proven on the investigated reference
system for this bounded Network-Smoke build:

- the SDIO WLAN device enumerated and `brcmfmac` identified `BCM43430/1`;
- the firmware started, `wlan0` became `UP`/`LOWER_UP`, and WPA association
  completed;
- DHCP installed a default route and ICMP connectivity worked;
- Dropbear started, accepted the locally provisioned public key, and completed
  non-interactive remote commands.

This establishes a usable Mainline Linux network administration path from Slot
B while the Stock-A rollback is already armed. It does not establish a
persistent network configuration, a stable SSH host identity, or network/SSH
availability after normal production reboots.

The first Network-Smoke run associated and obtained a DHCP lease, but TCP/22
refused connections. Its `udhcpc -b` invocation stayed in the foreground when
the lease arrived immediately, so `S45network-provisioned` did not return and
`rcS` did not reach `S50dropbear`. Commit
`2d46a67bc0ae1b664b33ac520185b159c7ab0081` adds `-q` to that bounded smoke
invocation. A fresh Network-Smoke build from that commit passed the documented
offline artifact checks, and the subsequent hardware run reached Dropbear and
SSH. This `-q` choice is suitable for the smoke only; DHCP lease renewal remains
a production-userspace design task.

The captured runtime mounts were the read-only SquashFS root, `devtmpfs` on
`/dev`, `proc`, `sysfs`, and tmpfs on `/run`. There was no `devpts` mount or
`/dev/pts`, and no separate tmpfs mount on `/tmp`. Public-key authentication
for an interactive SSH connection succeeded, but PTY allocation and the shell
request then failed. Non-interactive `ssh -T` commands worked. The boot log also
reported that it could not open an initial console. Missing runtime `devpts` is
therefore the concrete current PTY blocker; diagnosing why the configured mount
did not appear is the next narrow userspace task.

Boot timing showed the p8 SquashFS root mounted at about 1.554 s, `/sbin/init`
started at about 1.762 s, the SDIO card appeared at about 2.092 s, and the
firmware request followed at about 2.150 s. `brcmfmac` reported a running
`BCM43430/1` firmware at about 2.734 s. The Network-Smoke currently carries
the two WLAN firmware inputs both as kernel built-in firmware and in the RootFS.
The timing proves that the RootFS was available before the request; it does not
identify which copy served it. A later, separately authorized diagnostic may
remove only the built-in copies while retaining the RootFS copies to establish
filesystem firmware loading. That diagnostic is not part of the current result.

Additional direct observations from this bounded run are:

- eMMC enumerated through Ingenic SDHCI in HS200 mode; all p1--p10 partitions
  were visible, and p8 remained a stable RootFS for the observation period;
- the NS2009 touchscreen controller probed and registered an input device, but
  touch events and calibration remain unvalidated;
- DWC2 registered a USB bus and an internal USB 2.0 hub with four ports.
  Missing `vusb_d`/`vusb_a` supplies fell back to dummy regulators; hub
  enumeration nevertheless completed;
- the Ingenic watchdog probed successfully, but reset and timeout behavior were
  not tested.

No kernel panic, Oops, call trace, hung task, RCU stall, or obvious eMMC I/O
error was observed during several minutes of idle operation. The system had a
zero load average and ample free memory during that interval. This is bounded
smoke evidence, not a claim of long-term stability.

The WLAN log still reports a missing `regulatory.db`, no `clm_blob`, and no
`txcap` blob. WLAN nevertheless worked; the driver warns that absent CLM data
can restrict channels. The purpose, provenance, and redistribution status of
these additional optional blobs must be established before any of them is
added. An early attempt also reported a
failure to initialize the non-removable SDIO card, while a later boot detected
the high-speed SDIO card and completed the full WLAN path. This is currently a
non-blocking initial-enumeration observation, not a reason for a speculative
change; repeatability needs evidence if it becomes a reliability issue.

## Next development stage: separate manual Slot-B selection

This is the next development step after the mandatory public-state audit. It is
**not implemented by this document**.

The early automatic p1 B -> A rollback was the correct safety mechanism for the
blind first-boot and smoke phase. The existing one-shot Slot-B Smoke and
Network-Smoke paths remain unchanged as reproducible bring-up, safety, and
regression paths: they restore Stock A before continuing their bounded checks.

Normal development after `2026.1.a` should instead use a deliberately separate,
operator-controlled Slot-B path with this target model:

```text
Stock A
  -> operator-controlled p1 A -> B selection
  -> Mainline Slot B
  -> normal Mainline reboots remain on B
  -> operator-controlled p1 B -> A selection for a return to Stock A
```

This is a deliberate risk change, not an automatic promotion of the smoke
path. A kernel or early-userspace failure during manual B operation will not
automatically fall back to Stock A. If Mainline is no longer reachable, the
already qualified external Ingenic USB / RAM-U-Boot p1 rollback is the recovery
path. Any implementation or hardware test of the separate manual path requires
its own authorization; it must not alter the semantics or historical evidence of
the existing one-shot paths.

## Mandatory next-session start: public-state reproducibility audit

Before any new implementation, hardware test, or other change, a new session
must first audit only the publicly versioned repository state. It must not rely
on chat history, personal memory, ignored `local/` inputs, private notes,
addresses, host names, credentials, or implicit knowledge of earlier attempts.
The question is:

> Can a technically competent new contributor understand how the project
> reached its current technical state and continue safely from the public
> repository alone?

Private credentials do not need to be public. The audit must instead verify
that the repository states which private inputs are required, their expected
format and local location, and that they must not be committed.

At minimum, audit the following:

1. that `2026.1.a` is achieved, its evidence, and the remaining final
   `2026.1` requirements;
2. the selected Mainline kernel, SDK, and Buildroot basis;
3. pinned external sources, commits, and their provenance;
4. reproducible `2026.1.a` Network-Smoke build steps from a fresh clone;
5. required local provisioning inputs;
6. the p6 kernel and p8 RootFS artifacts;
7. partition sizes and A/B semantics;
8. the exact safe one-shot deployment and rollback mechanism;
9. why and when S00 changes p1 from B back to A;
10. the distinction between direct hardware observations and conclusions;
11. the `udhcpc -b` to `-b -q` failure, cause, and correction;
12. proof that Mainline continues from p8 after p1 again contains Stock A;
13. the successful SDIO WLAN -> WPA -> DHCP -> Dropbear -> SSH path;
14. the current `devpts`/PTY and initial-console defects;
15. why WLAN firmware is currently built in and also present in the RootFS, and
    the bounded next diagnostic for distinguishing the two sources;
16. deliberately unvalidated areas and their limits;
17. p9/p10 as `UNKNOWN / RESERVED`;
18. why the next development path is separate manual A/B selection, its
    external-recovery boundary, and concrete next work without reconstructing
    earlier chat context;
19. consistency between the README, roadmap, build documentation, and detailed
    Phase-3.3b evidence; and
20. whether a new contributor can understand, reproduce, and safely continue
    the current work from public state alone.

State the result explicitly at the start of that session as exactly one of:

```text
PUBLIC STATE: REPRODUCIBLE
PUBLIC STATE: INCOMPLETE
```

For `INCOMPLETE`, name the concrete missing information and close that
documentation gap before technical work begins when it matters to safe or
reproducible continuation. This is a proportional audit, not a theoretical
perfection exercise: do not create helpers or documentation bureaucracy for
gaps that do not affect the actual project's reproducibility,
traceability, or safe continuation.

## Status

- Phase 3.3a: **COMPLETE**.
- A/B read-only qualification: **COMPLETE**.
- `2026.1.a`: **ACHIEVED 2026-08-23**; the Slot-B deployment, complete
  read-back, early-userspace smoke boot, automatic p1 rollback, and bounded
  SDIO-WLAN/WPA/DHCP/Dropbear administration path are proven.
- Development toward final `2026.1`: **IN PROGRESS**; display, touch events,
  USB peripherals, F005/Klipper on the new host, printer peripherals,
  persistent mainline operation, and production network behavior remain
  unqualified. The next planned development transition is separate manual
  Slot-B selection; the automatic one-shot paths remain intact.
- A/B ROLLBACK GATE: **SATISFIED for p1-only A -> B -> A**.
- Gate 1: **SATISFIED** by the current evidence review; recovery execution remains
  documented but not personally rehearsed.
- p9/p10: **UNKNOWN / RESERVED**; this plan grants no ownership or role.
