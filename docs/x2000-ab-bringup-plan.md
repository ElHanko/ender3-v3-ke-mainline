# X2000 A/B bring-up and development plan

This is the selected architecture for the first open-Linux bring-up. It records
the read-only qualification, the completed bounded p1 selector test, the Slot-B
deployment, and the verified Slot-B smoke boot. The early-userspace smoke path,
bounded administrative network path, and complete Fre3nder-B print are proven
on the investigated reference system. The project status is **`2026.1
FUNCTIONALLY ACHIEVED`**. The Fre3nder-B Klippy/MCU runtime,
Stock-to-Fre3nder MCU transition, and bootloader-release legs are **QUALIFIED
ON DEVICE**. The historical Phase-2 complete Mainline print and the separate
2026-08-29 Fre3nder-B end-to-end print are **QUALIFIED ON DEVICE**. The complete
software-only Stock handoff **REQUIRES
QUALIFICATION**, while the manual power-cycle Stock recovery is qualified on the
reference device.
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

The host-side `scripts/x2000-usb-selector-to-a` helper preserves that established
emergency operation in the repository. It requires exactly one Ingenic BootROM
device, loads the conserved RAM U-Boot, reads and classifies the exact 512-byte
p1 selector, refuses unknown selector contents, and permits only the known
Develop-B -> Stock-A change after explicit operator confirmation. It then reads
p1 back and requires the exact known Stock-A hash. The helper performs no reboot
and does not write p5, p6, p7, or p8. Running it remains a persistent hardware
operation and therefore requires explicit authorization.

The RAM-only `kernel-ramboot.uImage` path remains an investigated and deferred
alternative. It is not the selected main path and is not a prerequisite for
the first open-Linux boot.

## Read-only qualification record

The fresh reference-system read-only qualification is **COMPLETE**. It was
performed without changing the device. The observed active Stock A root is p7;
p6 and p8 are unmounted. In that Stock-A snapshot, p9 and p10 were mounted only
by Stock. That observation did not assign them to the project; the later
Phase-3.5 shared-role boundary for p9 is documented below.

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
reported that it could not open an initial console. At that point `/dev/pts`
was not mounted, so missing runtime `devpts` was the concrete blocker for that
Network-Smoke PTY attempt.

The later hardware-validated Production RootFS creates `/dev/pts` and mounts
`devpts` before `rcS`. S50 additionally refuses to start Dropbear unless
`/proc/mounts` shows that `devpts` is mounted at `/dev/pts`. The validated
Production run reached S50, started Dropbear, and completed public-key SSH
login, so the runtime `devpts` mount is now proven for that Production path.
A subsequent read-only Production-path qualification forced PTY allocation
with SSH. The system was running from p8, Dropbear reported `active`, `devpts`
was mounted at `/dev/pts`, and the interactive remote shell reported
`/dev/pts/0` from `tty`. The session completed normally. Interactive SSH PTY
allocation and shell operation are therefore hardware-validated on the
investigated reference system. This does not by itself qualify persistent SSH
host identity, normal B -> B reboot persistence, or SSH availability after such
a reboot.

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

### USB host power-path qualification

A follow-up hardware comparison used the same current Develop test kernel
(`6.6.18-rt23`, DWC2 host active, `dr_mode = "otg"`). The board-level GPC9
`drvvbus` and GPD17 VBUS-detect assignments were already present in that
kernel. The GPC9 mapping is external [NebulaOS/OpenKE stock-DTB
prior art](x2000-kernel-dt-feasibility.md); the power-supply result below is an
independent observation on the investigated reference system.

With the pad powered only through its internal Micro-USB connection, Linux
started DWC2 and exposed the root hub `1d6b:0002`, but no downstream USB child
appeared. Neither a USB mass-storage device nor an ASIX AX88179B adapter was
enumerated, and changing the attached device produced no new USB kernel event.

With the same kernel and the pad powered normally through the printer, the
root hub `1d6b:0002`, internal USB 2.0 hub `05e3:0610`, ASIX AX88179B
`0b95:1790`, and USB mass-storage device `090c:1000` all enumerated. The log
also showed `usb-storage` binding and creation of a SCSI host.

This establishes the following bounded result on the investigated system:

- the current Develop kernel can operate the real USB host bus and enumerate
  downstream devices;
- the earlier “root hub only” state depended on how the pad was powered;
- Micro-USB-only power can bring up the SoC and DWC2 root hub while leaving the
  downstream hub/VBUS path unavailable, which can misleadingly resemble a
  kernel, PHY, or Device Tree failure;
- normal USB-host tests must therefore power the pad through the printer.

This does **not** prove that the GPC9 change caused the successful enumeration.
The predecessor kernel was not retested under the same normal printer-power
condition, so GPC9 causality remains **NOT PROVEN**. The result proves the
current kernel plus its existing GPC9/GPD17 configuration under the stated
power condition, not a regression comparison.

For the symptom “only `1d6b:0002`, no children, no hotplug event”, check the
pad's power source first. Do not classify that symptom as a USB-PHY or Device
Tree failure until the test has been repeated with normal printer power.

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

## Current development stage: separate manual Slot-B selection

The host-side `scripts/x2000-ab` tool implements this path independently of
the Develop build, Develop RootFS, and Prototype deployment path. It is
hardware-validated on the investigated reference system for explicit p1 A -> B
and B -> A selector changes. A normal Develop-B -> Develop-B reboot is also
qualified on the investigated reference system, with p8, the valid `DEVELOP_B`
selector, active S09/S10 persistence, persistent Dropbear host identity, and
SSH administration available again afterward.

The early automatic p1 B -> A rollback was the correct safety mechanism for the
blind first-boot and smoke phase. The existing one-shot Slot-B Smoke and
Network-Smoke paths remain unchanged as reproducible bring-up, safety, and
regression paths: they restore Stock A before continuing their bounded checks.

Normal development after `2026.1.a` uses a deliberately separate,
operator-controlled Slot-B path with this model:

```text
Stock A
  -> operator-controlled p1 A -> B selection
  -> Mainline Slot B
  -> qualified: normal Develop-B reboots remain on B
  -> operator-controlled p1 B -> A selection for a return to Stock A
```

This is a deliberate risk change, not an automatic promotion of the smoke
path. A kernel or early-userspace failure during manual B operation will not
automatically fall back to Stock A. If Mainline is no longer reachable, the
already qualified external Ingenic USB / RAM-U-Boot p1 rollback is the recovery
boundary. That evidence qualifies the bounded p1 reset, not complete Stock
recovery. Every real `select-a` or `select-b` invocation remains a separately
authorized persistent hardware operation. The tool performs no reboot and does
not alter the semantics or historical evidence of the existing one-shot paths.

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
14. the historical `devpts`/initial-console defect, the later Production
    evidence that `devpts` is mounted before S50, and the subsequent
    hardware-validation of interactive SSH PTY allocation and shell operation;
15. why WLAN firmware is currently built in and also present in the RootFS, and
    the bounded next diagnostic for distinguishing the two sources;
16. deliberately unvalidated areas and their limits;
17. the limited Phase-3.5 p9/p10 persistence role versus Stock-A ownership;
18. why the development path uses separate manual A/B selection, its
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

### Production USB-provisioning result

**Hardware-validated on the investigated reference system:** USB mass storage
enumeration and explicit read-only VFAT mounting; USB public-key provisioning;
USB WPA association and WLAN DHCP; Ethernet-first selection; and DHCP on both
the Ethernet and WLAN paths. The exact Production RootFS then booted on Develop
B and completed S20 provisioning, S40 networking, and S50 public-key SSH with
the USB-provisioned key. BusyBox `blkid` on that system did not report a VFAT
`TYPE`, so production qualification uses the successful explicit mount.

The validated boot policy selects exactly one suitable non-WLAN Ethernet
interface, waits five seconds for carrier and 15 seconds for DHCP, and leaves
WLAN down after Ethernet success. When Ethernet is unavailable, it brings that
interface down and uses provisioned WLAN. Selection occurs once at boot; runtime
and hotplug failover are not implemented. The Production RootFS embeds no
SSH/WLAN credentials and uses only the S20 -> S40 -> S50 Production path. Stock
A and external BootROM recovery remain outside that RootFS.

- Phase 3.3a: **COMPLETE**.
- A/B read-only qualification: **COMPLETE**.
- `2026.1.a`: **ACHIEVED 2026-08-23**; the Slot-B deployment, complete
  read-back, early-userspace smoke boot, automatic p1 rollback, and bounded
  SDIO-WLAN/WPA/DHCP/Dropbear administration path are proven.
- `2026.1`: **FUNCTIONALLY ACHIEVED 2026-08-29**; display, touch events,
  camera, ADXL/Input Shaping, other USB peripheral classes, general persistent
  configuration, and runtime network failover remain later work and **REQUIRE
  QUALIFICATION** where pursued. The
  Phase-3.5 Fre3nder-B upstream Klippy/MCU runtime leg is **QUALIFIED ON DEVICE** for
  exact identity/dictionary, complete configuration, stable ClockSync, and
  heater/ADC telemetry. The historical Phase-2 print and the 2026-08-29
  Fre3nder-B end-to-end print are **QUALIFIED ON DEVICE**. The separate manual
  `scripts/x2000-ab` selector is
  hardware-validated for explicit p1 A -> B and B -> A changes; the normal
  Develop-B -> Develop-B path is qualified for persistent SSH identity and SSH
  administration after reboot on the investigated reference system. The
  automatic one-shot paths remain intact.
- A/B ROLLBACK GATE: **SATISFIED for p1-only A -> B -> A**.
- Gate 1: **SATISFIED** by the current evidence review; recovery execution remains
  documented but not personally rehearsed.
- Development persistence sources: **QUALIFIED ON DEVICE**;
  `FRE3NDERDATA:/p9` supplies `/persist/system` and `FRE3NDERDATA:/p10`
  supplies `/persist/userdata`. On the investigated reference system p9 also
  backs Stock A's writable OverlayFS state. Fre3nder ownership is limited to
  its designated namespace exposed below `/persist/system/fre3nder/`; it must
  not mutate Stock overlay paths such as `/upper/etc/...`. This is not a
  general persistent-configuration contract.

### Phase 3.5 Fre3nder host and MCU qualification

The investigated reference system booted Fre3nder B from p8 and ran the pinned
upstream Klippy through `/dev/ttyS1` at 230400 baud. S60 recognized the exact
Fre3nder-F005 identity; the MCU reported version
`?-20260820_092609-29ca4e70a84f`; Klippy loaded the 88-command dictionary and
complete `printer.cfg`, and reported
`Configured MCU 'mcu' (1024 moves)` with stable ClockSync/UART and heater/ADC
telemetry. The writable `/run/fre3nder-klipper/printer` input PTY was present
and Klippy owned `/dev/ttyS1`. This runtime is **QUALIFIED ON DEVICE**. The
`/proc/<pid>/cmdline` stale-PID ownership hardening is separately **OFFLINE
CONFIRMED** by local fixtures.

Two startup races are qualified procedural observations, not an undefined
defect: SSH was reachable before S60 had finalized its MCU status, and `S60
start` could report `active` before the PTY and complete configuration were
immediately observable. Neither SSH availability nor `active` alone is a
runtime-readiness gate. The required combined observation is S60 `active`, the
expected Klippy process, the PTY, Klippy ownership of `/dev/ttyS1`, a fresh log
with the expected MCU identity, and successful complete configuration. This
gate is **QUALIFIED ON DEVICE**.

The exact supported Stock-MCU -> Fre3nder-MCU transition is separately
**QUALIFIED ON DEVICE**: exact Stock identity, dictionary-derived exact
`reset`, successful `mcu_util -c`, `-g`, and `-u -f` steps without orchestration
retry or delay, updater return code 0 with `app_run`, and an independent exact
Fre3nder identity check. This is an MCU transition result, not the complete
coordinated host roundtrip.

The first 2026-08-29 Fre3nder-B print attempt remains a controlled historical
abort; its proposed dragged-filament explanation is an **INFERENCE**. The repeat
used the then-unmodified image `z_offset: 1.900` with session-only
`SET_GCODE_OFFSET Z=-0.280`, after the exact pinned-Klipper semantics had been
checked, and completed successfully. It established the effective 2.180 probe
offset and the **FRE3NDER-B END-TO-END PRINT: QUALIFIED ON DEVICE**. The tracked
configuration was subsequently updated to `z_offset: 2.180`; 1.900 is
**WIDERLEGT as the current reference value**.

The same qualification established `FIRMWARE_RESTART` -> actual UART release
-> immediate `mcu_util -c`/`-g` and exact bootloader identity
`mcu0_001_G32-mcu0_004_000`. Actual UART release, not process exit or a
particular log line, is the qualified bootloader-window trigger. The complete
software-only Fre3nder -> Stock attempt then booted Stock A on p7 with its
selector, original `S13mcu_update`, and hash-valid Stock image correct, but
Moonraker shut down and Stock Klipper reported `Lost communication with MCU
'mcu'` with repeated connection timeouts. The single uninterrupted
Fre3nder -> Stock-A -> Stock-MCU -> ready handoff therefore **REQUIRES
QUALIFICATION**. Automatic MCU shutdown clearing is **NOT IMPLEMENTED**; the
original shutdown reason after an X2000 host reboot also **REQUIRES
QUALIFICATION**.

### Stock-A overlay cleanup

An old development overlay on the investigated Stock-A state contained a
whiteout for `/etc/init.d/S13mcu_update`, a disabled `K13mcu_update.disabled`,
and a `K12mcu_mainline_once.done` marker. These three development artifacts
were deliberately removed from writable p9. A fresh Stock boot then exposed the
original immutable `/rom/etc/init.d/S13mcu_update` with SHA-256
`ad4fe0013af6033664ea230f86a746dfe149c742d5abb453d826ba110a69f151` and no
remaining artifacts. This is **QUALIFIED ON DEVICE** as a targeted repair of
that old historical bring-up residue; it is not the intended persistence design.
It does not establish direct editing of a mounted OverlayFS upper directory as
a general recovery procedure.

### Stock-A power-cycle fallback

The Stock-A selector was already armed before the final full power-cycle; no
new selector write is implied at this point. That power-cycle boot reached the
unchanged Stock path: active p7, original S13,
exact Stock image SHA-256
`0b8ecfad8e65e90a3cfc08dd8534dd568e341c160897e6050eadcbf1eb917d4a`, Moonraker
ready, Stock Klippy configured, and the host MCU configured. This complete
power-cycle recovery was observed twice on the investigated reference device:
**POWER-CYCLE STOCK RECOVERY: QUALIFIED ON DEVICE (2/2)**. It is the current
recovery boundary for development, does not qualify the software-only handoff,
and is not a guarantee for other devices.
