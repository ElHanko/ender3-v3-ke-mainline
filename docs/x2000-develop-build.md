# Phase 3.4 x2000-develop build basis

`x2000-develop-v0` is the first independent build basis after the historical
and reproducible `2026.1.a` prototype. It does not change or replace
`x2000-prototype`, its one-shot rollback semantics, or its evidence chain.

The Develop build is an offline build definition. It does not access a printer,
write a partition, change p1, select an A/B side, deploy an artifact, or
authorize any hardware operation. Manual slot selection is a separate
host-side operator operation described below; it is not part of the build or
the Develop RootFS.

## Current scope

The build uses the pinned public Ingenic X2000 SDK mirror at commit
`a98c2e1f22e4263ddd4153a4eca4db4dcfd2777b`, its Linux 6.6.18 tree with
`localversion-rt` set to `-rt23`, vendored Buildroot 2023.08.3, and the pinned
`mips-gcc720-glibc238` toolchain. The container base and Debian package snapshot
are pinned in `configs/x2000-develop/sources.json`.

The effective preemption model intentionally matches the `2026.1.a` build:

```text
CONFIG_PREEMPT=y
# CONFIG_PREEMPT_RT is not set
```

The kernel release is therefore `6.6.18-rt23`, but this build does not enable
the fully preemptible `CONFIG_PREEMPT_RT` model.

The new KE Device Tree retains the already established CPU/RAM, eMMC, UART,
SDIO WLAN, USB-controller, and watchdog basis. Touch/NS2009, camera, ADXL,
Klipper/F005 services, selector logic, and all smoke-only code are excluded.
Its root command line is:

```text
root=/dev/mmcblk0p8 rootwait rootfstype=squashfs ro
```

The KE WLAN patch copies the power/reset/detect sequence that was hardware
validated on the investigated reference system for `2026.1.a`. Only the
smoke-specific init-function name and comments are generalized. The Develop
build and its administrative userspace path are **NOT YET HARDWARE VALIDATED**.

## WLAN source and license boundary

`configs/x2000-develop/ke-wlan.patch` modifies the pinned Linux SDK's
`ingenic_sdio.c`, `sdhci-ingenic.c`, and `sdhci-ingenic.h`; those files are
governed by the kernel tree's GPL-2.0 `COPYING` terms. The combined patch is
therefore marked `GPL-2.0-only`. Its Device Tree hunk applies to the
project-authored KE DTS copied into the ignored SDK workspace. The patch records
the exact source URL and commit.

The Broadcom/Cypress firmware and NVRAM remain local BYOF inputs with documented
provenance and unresolved redistribution status. Required ignored paths and
hashes are:

| Local input | SHA-256 |
| --- | --- |
| `local/phase3/wifi/brcmfmac43430-sdio.bin` | `60dbb5b77b2c232e513322e0ff4350ab5dab5a9fcad0e26e80a2f089e652d720` |
| `local/phase3/wifi/brcmfmac43430-sdio.txt` | `78fee458ab69c0a66ea462f6d6769e15b36f73582693f4dbb5a0e8e8be3cfb0a` |

The build validates both hashes before use. The files may enter the ignored
local build output but must not be committed or redistributed by this project.
No WLAN credentials are consumed at build time or embedded.

## Build and artifacts

Run exactly:

```text
scripts/build-x2000-develop
```

The fetch container may access the pinned public sources. The compiler container
runs with `--network none`. Work and output remain ignored under:

```text
local/phase3/x2000-develop-work/
local/phase3/x2000-develop/
```

The output contract is:

```text
kernel.uImage
rootfs.squashfs
ender3-v3-ke.dtb
effective-kernel-config
buildroot.config
SHA256SUMS
build-manifest.json
```

`rootfs.squashfs` is the only RootFS image and uses XZ compression. JFFS2,
UBIFS, ext2, and tar RootFS outputs are disabled.

Names are build-neutral. The manifest records p6/p8 only as current deployment
compatibility; neither the build nor its RootFS writes those partitions.
`project_commit` records the checked-out `HEAD`; `project_worktree_status`
records whether Git reported `clean` or `dirty` inputs. A `dirty` artifact must
not be treated as built exclusively from its recorded `HEAD` commit.

## Boot-local administrative path

`CONFIG_BLK_DEV_INITRD=y` with an empty `CONFIG_INITRAMFS_SOURCE` includes only
the kernel tree's default early cpio list: `/dev`, `/dev/console`, and `/root`.
It contains no `/init`; the system therefore continues to mount p8 as its normal
SquashFS RootFS. The p8 RootFS likewise does not add `/init`. This addresses the
previously observed initial-console warning without creating a RAM-root build.

After devtmpfs is available, the BusyBox `inittab` creates `/dev/pts` before
mounting devpts. This addresses the separately observed PTY mount failure.

Develop-v0 contains `wpa_supplicant` with the nl80211 backend, a long-lived
BusyBox `udhcpc`, and Dropbear compiled without server password authentication.
It contains no WLAN credentials, authorized keys, private keys, persistent
Dropbear host keys, selector helper, or p9/p10 logic.

The pinned Buildroot package definitions provide wpa_supplicant 2.10
(BSD-3-Clause), Dropbear 2022.83 (the licenses recorded by Buildroot), and
BusyBox 1.36.1 (GPL-2.0 plus its recorded bzip2 component license). Exact
versions, package-source role, and license identifiers are recorded in the
build manifest; no package source or binary is committed to this repository.

At boot, after mdev, the provisioning script scans USB mass-storage block
devices for a FAT32 (`vfat`) filesystem containing at least one of these files
in its root:

```text
wpa_supplicant.conf
authorized_keys
enable_ssh
```

The USB filesystem is mounted read-only with `nosuid`, `nodev`, and `noexec`.
Recognized entries must be regular files and must not be symlinks. If more than
one volume contains recognized entries, all are refused rather than selecting
one arbitrarily. Valid inputs are copied with restrictive permissions to
`/run/x2000-develop/provisioning/`, and the USB filesystem is unmounted before
network startup. `wpa_supplicant.conf` and `authorized_keys` are each limited
to 64 KiB; `enable_ssh` is valid only as an empty regular file. Nothing is
written to the USB medium, SquashFS, p1, p9, or p10.

When a non-empty `wpa_supplicant.conf` was accepted, the network script selects
the single exposed wireless interface, starts `wpa_supplicant`, and waits at
most 30 seconds for association. Only then does it start BusyBox `udhcpc` as a
long-lived foreground client process managed in the background by the init
script. Its `deconfig`, `bound`, and `renew` actions maintain the interface,
default route, and volatile resolver state; its PID file is under `/run`.

Dropbear starts only when both a syntactically bounded public
`authorized_keys` file and the empty `enable_ssh` marker were accepted. It also
refuses startup unless devpts is mounted. The key is exposed to Dropbear through
a boot-local bind mount over `/root/.ssh`; no key is placed in SquashFS. The SSH
server uses public-key authentication only and explicitly generates an Ed25519
host key under `/run/x2000-develop/dropbear/` for the current boot.

That host key changes after every reboot. This is an intentional Develop-v0
boundary, not a stable SSH identity. A persistent SSH host identity remains a
requirement for final `2026.1`. Persistent general configuration remains
**PLANNED / NOT IMPLEMENTED**.

## Separate manual A/B operator path

The host-side `scripts/x2000-ab` tool implements the deliberately manual slot
selector independently of BUILD and DEPLOY:

```text
scripts/x2000-ab <printer-host> status
scripts/x2000-ab <printer-host> select-a
scripts/x2000-ab <printer-host> select-b
```

The tool uses only the already qualified exact records:

| Classification | First 512 bytes | SHA-256 |
| --- | --- | --- |
| `STOCK_A` | `ota:kernel\n\n` plus 500 NUL bytes | `ba68d7c969bfee94216c94768ec65545cf36cb352303ab55231c78e78b51ce6b` |
| `DEVELOP_B` | `ota:kernel2\n\n` plus 499 NUL bytes | `29a335bc1f2935f9ee79955da3566d5f70d1b0591421745395fd714c8351bdc4` |

`status` is read-only. It reports the active root selected by the single
`root=` kernel argument, verifies that the `ota` partlabel resolves to partition
1 at `/dev/mmcblk0p1`, checks the established 2048-sector p1 size, reads the
first 512 bytes, and reports their SHA-256 classification as `STOCK_A`,
`DEVELOP_B`, or `UNKNOWN`. An unknown selector or unexpected partition layout
is never repaired.

`select-b` is valid only while the active root is Stock p7 and p1 contains the
exact qualified Stock-A record. `select-a` is valid only while the active root
is Develop p8 and p1 contains the exact qualified Develop-B record. For either
operation the tool creates the target 512-byte record locally, verifies its
known SHA-256, rechecks the active-root and p1 identities and sizes on the
target, writes exactly one 512-byte p1 record, runs `sync`, and verifies the
read-back hash. It performs no automatic retry or reboot and never writes p5,
p6, p7, p8, p9, or p10.

Invoking either `select-*` command requests a persistent p1 hardware write.
Every real invocation therefore still requires separate explicit operator
authorization under `AGENTS.md`; the offline implementation and fixture tests
do not grant that authorization.

The retained Prototype smoke systems and Develop intentionally differ:

```text
Prototype Slot B: early userspace automatically restores B -> A
Develop tool policy: no automatic B -> A; B -> B reboot behavior is not yet
                     hardware validated
```

There is no selector daemon, boot-local p1 reset, or automatic Stock fallback
in the Develop RootFS. If B has been selected and Develop becomes unreachable,
the recovery boundary is the already qualified external Ingenic USB /
RAM-U-Boot p1 reset. That qualification covers the bounded p1 selector path; it
does not prove complete Stock-firmware recovery.

Successful offline construction establishes only build reproducibility and
static artifact properties. The resulting Develop kernel, DTB, RootFS, USB
provisioning, WLAN association, DHCP renewal, public-key SSH, volatile host-key,
initial-console, and devpts paths are all **NOT YET HARDWARE VALIDATED**. A later
successful interactive SSH session is a hardware acceptance criterion. The
manual A/B tool is likewise only offline-validated; no printer connection or p1
write was made while implementing it.
