# X2000 non-persistent boot plan

This is the retained offline plan for the investigated RAM-only alternative.
It does not authorize hardware access. It is not the selected main path for
the first open-Linux boot; the selected A/B one-shot plan is documented in
[`x2000-ab-bringup-plan.md`](x2000-ab-bringup-plan.md). The selected A/B path
now establishes the bounded `2026.1.a` Open-Host baseline; the RAM-only
alternative described in this document remains **NOT STARTED** and requires
explicit authorization.

This deferred RAM-only plan is not the Phase-3.5 qualification path. Phase 3.5
uses Fre3nder B from p8 with persistent p9/p10 mounts and separately qualifies
the bounded upstream Klippy/F005 runtime; none of that changes this plan's
**NOT IMPLEMENTED** status.

The plan must not write eMMC, mount p7-p10, save an environment, access F005,
or use the closed BootROM recovery client. A power-cycle must be followed by an
observation of the unchanged stock boot path.

## PROVEN

### Stock loader evidence

The private read-only reference capture contains the persistent pre-p1 loader
material. Offline strings inspection of that captured boot payload identifies:

- `U-Boot SPL 2013.07 (Oct 09 2023 - 16:41:52)`;
- `U-Boot 2013.07 (Oct 09 2023 - 16:41:52)`;
- `bootdelay=1`;
- `baudrate=115200`;
- `Hit any key to stop autoboot`;
- `console=ttyS4,115200n8` in both captured stock boot argument strings.

The vendor V1.1.0.12 recovery package separately contains an X2000 recovery
Stage-2 U-Boot with the embedded identity
`U-Boot 2013.07-00067-gc97f831 (Sep 01 2021 - 11:25:03)`. That is recovery
evidence, not proof that it is the normal persistent loader.

The public source basis is pinned to Ingenic SDK mirror commit
`a98c2e1f22e4263ddd4153a4eca4db4dcfd2777b`, as recorded by the prototype
manifest. Its U-Boot blobs were not hydrated for this offline review; the
identities and command evidence above come from the captured/vendor binaries,
not from an unverified source reconstruction.

### Commands present in the captured persistent loader

The following command names and help text are present in the captured loader
binary, so they are **PROVEN PRESENT**, but their operation has not been run on
the printer:

| Command or family | Offline status | First-test use |
| --- | --- | --- |
| `help` | PROVEN PRESENT | read-only command discovery |
| `printenv`, `setenv`, `saveenv`, `env` | PROVEN PRESENT | `printenv` only; never save |
| `mmc`, `mmc rescan`, `mmc part`, `mmc dev`, `mmc list` | PROVEN PRESENT | read-only identification only |
| `fatload`, `ext4load` | PROVEN PRESENT | not selected until a medium is proven |
| `bootm` | PROVEN PRESENT | legacy uImage handoff candidate |
| `loady`, `loadb`, `loads` | PROVEN PRESENT | serial-load candidates |
| `dhcp`, `tftpboot` | PROVEN PRESENT | only after a separate network path is qualified |
| `md` | PROVEN PRESENT | read-only inspection only |

No exact `loadx`, `bootz`, `iminfo`, or `fdt` command/help entry was found in
that binary. The `usb` strings that are present refer to the Ingenic USB
burner/gadget path; no usable `usb start` or USB mass-storage command was found.

### USB mass storage decision

The preferred USB-stick candidate is **NO for a usable stock-U-Boot
USB-Mass-Storage path**. The captured loader has no host `usb start`/storage
command evidence. BootROM USB device recovery and Linux USB roles are separate
boundaries; the independent BootROM RAM-stage prior art is reviewed below.

The previous volatile-source candidate was **serial `loady`**, but that route is
not practically available under the project's no-solder constraint:
there is no existing external bootloader console and no additional USB-UART
debug connection. TFTP/DHCP remain proportional alternatives only if a real
USB-Ethernet path is separately qualified; they do not provide a proven
bootloader handoff. No new transport is designed.

### Public X2000 USB RAM-stage prior art

The following external work is **PRIOR ART** only. It is not an adopted project
implementation and does not authorize reuse or redistribution of bundled
binaries. The review used these exact public revisions:

- [`coreflake1/NebulaOS-firmware`](https://github.com/coreflake1/NebulaOS-firmware/commit/e66eb2707cb4d55fb52acada1bfbc9ad1e30c77a)
  at `e66eb2707cb4d55fb52acada1bfbc9ad1e30c77a`;
- [`coreflake1/NebulaOS`](https://github.com/coreflake1/NebulaOS/commit/11a5e6560be57a7ca40177b11be9c32d5d2ea82e)
  at `11a5e6560be57a7ca40177b11be9c32d5d2ea82e`;
- [`ballaswag/ingenic-usbboot`](https://github.com/ballaswag/ingenic-usbboot/commit/c65eaa337cc9fb64fd8a2ea22bcf3f9395c9945c)
  at `c65eaa337cc9fb64fd8a2ea22bcf3f9395c9945c`;
- [`ballaswag/k1-discovery`](https://github.com/ballaswag/k1-discovery/commit/01d2a8465621d8914f939a50557b48c0a67aea8d)
  at `01d2a8465621d8914f939a50557b48c0a67aea8d`;
- [`u-boot/u-boot`](https://github.com/u-boot/u-boot/tree/v2013.07) at tag
  `v2013.07` for the generic MIPS relocation and compiled-autoboot behavior.

NebulaOS's normal installation is persistent: stock Linux writes p6 and p8,
then stock tooling writes the p1 OTA marker before reboot. That path is not a
Phase-3.3b candidate. Its KE recovery documentation separately reports using
`ingenic-usbboot --uboot` before later MMC/OTA operations.

The inspected `ingenic-usbboot` source provides this X2000 profile and flow:

| Finding | Classification |
| --- | --- |
| USB ID `a108:eaef`; Stage 1 load `0xb2401000`, execute `0xb2401800`; Stage 2 load/execute `0x80100000` | PROVEN FROM SOURCE |
| `--uboot` loads `spl.bin`, waits one second, loads `uboot.bin`, flushes caches, and starts Stage 2 | PROVEN FROM SOURCE |
| generic address, length, download, Stage-1/Stage-2 start, cache-flush, and separate `--stage1`/`--stage2` operations | PROVEN FROM SOURCE |
| the host-side Stage-1/Stage-2 download sequence does not call `enable_mmc` or issue an MMC read/write request; those calls occur only in separate later partition operations | PROVEN FROM SOURCE |
| successful use of `--uboot` as the prerequisite to KE USB recovery | REPORTED ON KE BY NEBULAOS |
| BootROM -> compatible SPL -> arbitrary valid RAM Stage 2 is a credible independent architecture | INFERRED |
| maximum reliable Stage-2 payload size | UNKNOWN |

The source sends the complete Stage-1 or Stage-2 file with one libusb bulk
transfer after a 32-bit `SET_DATA_LENGTH`; it has no explicit 424,684-byte cap
and no chunking for this path. The known 424,684-byte Creality recovery Stage 2
is therefore an observed image size, not a transfer limit. The host code uses a
signed `int` length, but the reliable libusb/BootROM maximum remains UNKNOWN.
This establishes that MMC is not required by the USB download sequence; it does
not establish whether a particular Stage-2 binary probes MMC after execution.

The earlier project attempt still failed at the first Stage-2
`SET_DATA_ADDRESS` request after Stage 1. The public prior art uses the same
X2000 address and execution model, and NebulaOS reports it on the KE; the local
timeout proves that one client attempt failed, not that the architecture is
impossible. This review does not reopen or debug that client.

The host tool source carries a GPL-2.0-or-later notice. Its bundled `spl.bin`
and `uboot.bin` are device-specific binaries, while the repository supplies no
corresponding source, reproducible build recipe, or binary redistribution basis
for them. `k1-discovery` points to the Ingenic X2000 SDK and an LPDDR2 U-Boot
configuration as build prior art, but an exact open, reproducible, KE-qualified
Stage-1/Stage-2 source basis is still required for this project.

Upstream U-Boot v2013.07 MIPS source relocates U-Boot near the top of detected
RAM before entering its command loop and can then execute a compiled default
`bootcmd` without interactive input. The prior-art binary contains the matching
relocation diagnostics, but its exact KE relocation address, malloc reservation,
and complete RAM map are not proven. A project-owned U-Boot could therefore be
autonomous without UART, but it is **NOT YET SAFE** to boot the project kernel:
the initial Stage-2 address `0x80100000` lies inside the kernel decompression
range beginning at `0x80010000`. The existing `0x81000000` file-buffer candidate
is above that range, but remains unapproved until the Stage-2 relocation and all
reservations are derived from the selected build.

A combined `[loader][padding][kernel-ramboot.uImage]` transfer is architecturally
plausible if the loader relocates safely and the embedded kernel begins at a
verified file-buffer address. Its larger one-shot transfer size and exact layout
are not yet proven. A minimal non-relocating loader at `0x80100000` would itself
be overwritten by kernel decompression and is not a safe shortcut.

The current kernel configuration includes DWC2 dual-role, USB gadget, configfs,
and NCM support, but the rootfs does not instantiate a USB network gadget. WLAN
also lacks qualified firmware/NVRAM. The first no-UART Linux boot therefore has
no presently qualified success/failure channel; USB networking is only an
offline candidate, not an implemented or validated path.

### Kernel image format

The stock `xImage` is a legacy U-Boot `uImage` containing an uncompressed
Linux 4.4.94 kernel. The project `kernel.uImage` is also a legacy U-Boot
`uImage`, with gzip-compressed Linux 6.6.18 data.

The project header reports:

```text
Load address: 0x80010000
Entry point:  0x80a03890
```

The project ELF has the same entry point and a load segment beginning at
`0x80010000`; this supports interpreting the header load value as the kernel's
decompression/load destination. It does **not** establish the address where
U-Boot must copy the image file. The file-load address remains UNKNOWN.

The closed recovery address `0x80100000` is a BootROM Stage-2 address. It is not
treated as free RAM for this boot plan.

### Current Device Tree and command-line configuration

The effective project kernel configuration contains:

```text
CONFIG_BUILTIN_DTB=y
CONFIG_MIPS_NO_APPENDED_DTB=y
CONFIG_MIPS_CMDLINE_FROM_DTB=y
# CONFIG_MIPS_CMDLINE_FROM_BOOTLOADER is not set
```

The project DTS supplies `chosen/bootargs = "console=ttyS4,115200"`, enables
UART1 for F005 without making it a console, and declares 256 MiB of RAM.

The current RAM-boot artifact links the project KE DT into the Ingenic DT
choice and places its DTB object before the built-in DT object list. Offline
inspection shows the KE built-in DT symbols and the `creality,ender-3-v3-ke`
compatible, with no linked `ingenic,halley5` DT. The external
`ender3-v3-ke.dtb` is also emitted and contains the KE compatible,
`10031000.serial`, `13450000.msc`, and `nsiway,ns2009`; it is retained for
inspection and for a later handoff decision, not because the current kernel
requires an external DTB.

The selected command-line source is the DT. The first RAM boot must not append
`root=/dev/mmcblk0p7`, `root=/dev/mmcblk0p8`, a p9 overlay, or any stock data
mount.

### eMMC no-write model

The first Linux system may enumerate the eMMC/MMC controller. Static review of
the current rootfs shows no automatic p7/p8/p9/p10 mount, no OTA service, no
filesystem repair, and no update path in the init sequence. The shared `inittab`
contains mount commands for proc, sysfs, tmpfs-backed `/run`, and `devpts`, then
invokes `rcS`. The later selected Slot-B Network-Smoke observed `/run` as tmpfs,
but did not have mounted `devpts` or `/dev/pts` and did not have a separate
`/tmp` tmpfs. Those runtime observations do not validate this deferred RAM-only
path, but they show that the static `inittab` entries must not be treated as a
runtime guarantee. Dropbear keys, DHCP lease state, and seed state are runtime
data under `/run`; the rootfs contains administrative tools such as
`fsck`, `mke2fs`, and flash utilities, but their presence is not an invocation.

The first boot contract is therefore:

- no eMMC write or environment save;
- no `saveenv`, `env save`, `mmc write`, `mmc erase`, `fatwrite`, `ext4write`,
  OTA, `fsck` repair, `mke2fs`, swap, or persistent log setup;
- no p7/p8 root, p9 overlay, or p10 mount;
- `/run` and runtime Dropbear identity remain in RAM; any writable `/tmp` use
  must be explicitly verified by the selected runtime.

### F005 no-touch model

The KE DT exposes UART1 as `/dev/ttyS1` at the existing 230400-baud F005
interface. The project rootfs has no getty on UART1 and no UART1 console. The
first Linux check may confirm the node exists through sysfs or device metadata;
it must not open the node, call `stty`, transmit bytes, start Klipper, or run a
serial probe. The stock debug shell remains assigned to the separate `ttyS4`
console, but that console is not an available no-solder interface.

## LIKELY

### Console and autoboot

The captured loader's `bootdelay=1` and stop-autoboot string make a one-second
key interruption **LIKELY**. The physical UART carrying the loader console is
also **LIKELY** to be the stock `ttyS4`/115200 debug path because both the
loader and stock Linux arguments identify 115200, but the physical identity,
prompt, and exact key timing remain unobserved.

### RAM layout candidate

The proven RAM declaration is physical `0x00000000-0x0fffffff` (256 MiB), with
the MIPS KSEG0 alias beginning at `0x80000000`. The following is a non-overlap
candidate, not a claimed final load map:

| Object | Candidate KSEG0 range | Basis |
| --- | --- | --- |
| decompressed kernel | `0x80010000-0x80ef7650` | ELF load segment |
| kernel file buffer | `0x81000000-0x81cff99e` | generic RAM-boot uImage size 13,629,855 bytes |
| generic gzip initramfs | `0x82000000-0x826f6179` | current offline compressed-size candidate |
| provisioned gzip initramfs | `0x82000000-0x827239d6` | current private-build compressed-size candidate |
| external KE DTB | `0x82a00000-0x82a06d1a` | DTB size 27,930 bytes |

The ranges do not overlap when only one initramfs variant is selected. Exact
U-Boot relocation, DRAM reservations, DMA/framebuffer reservations, and a safe
file-load address are UNKNOWN; these candidates must not be used before the
3.3b-0 console check.

### RootFS handoff

The existing `rootfs.squashfs` is a valid immutable Buildroot artifact, but it
is not a Linux initrd. Loading a SquashFS file into RAM does not by itself make
it `/dev/ram0`, and adding a loop/block-root handoff would unnecessarily widen
the first-test risk. The preferred first-test form is therefore a **built-in
gzip-compressed initramfs** consumed by the kernel, while keeping SquashFS as
the later immutable appliance artifact. The public `--ramboot` path generates
the CPIO with the pinned kernel's `usr/gen_initramfs.sh` from the Buildroot
target after normalizing target mtimes to Unix epoch 0, verifies two
consecutive outputs byte-for-byte, and links it with
`CONFIG_INITRAMFS_COMPRESSION_GZIP=y`. The target supplies `/init -> sbin/init`.

As an offline size check, the current target trees produced:

- generic `newc` CPIO: 19,601,920 bytes; deterministic gzip: 7,284,302 bytes;
- provisioned `newc` CPIO: 19,602,944 bytes; deterministic gzip: 7,285,139 bytes.

The provisioned archive contains the intentionally local WLAN and SSH key
material and remains a private development artifact. The generic archive has
no such private inputs. No archive was added to Git.

The normal public build still emits `kernel.uImage` and `rootfs.squashfs` as
before. The `--ramboot` variants emit separate ignored artifact directories
with `kernel-ramboot.uImage`, the external KE DTB, the SquashFS reference
rootfs, effective configs, checksums, and a manifest. The generic variant is
credential-free. The `--provision` variant intentionally embeds local WLAN and
SSH authorized-key data in its private development artifact and must not be
published or distributed as a generic release artifact.

### Network as an optional first-boot path

The kernel prepares SDIO, `brcmfmac`, and the firmware loader. The rootfs has
`wpa_supplicant`, BusyBox `udhcpc`, and Dropbear. At the time this deferred
RAM-only plan was written, no firmware/NVRAM or power sequence was qualified.
The later selected Slot-B Network-Smoke has since directly validated its own
locally provisioned firmware/NVRAM, power, WLAN/IP/SSH path on the investigated
reference system. That result does not validate the separate RAM-only artifact,
which remains unbooted; its firmware and observation path must be qualified
independently before WLAN can be its success channel.

## UNKNOWN

- exact BootROM-to-persistent-U-Boot selection sequence;
- physical mapping of the bootloader console to the proposed debug connector;
- actual autoboot prompt and interrupt timing;
- whether the captured loader's command strings operate on this board as
  expected;
- USB host and USB mass-storage support in the normal loader;
- exact `loady` transfer syntax and file-load address;
- exact open, reproducible, redistributable, and KE-compatible Stage-1/SPL
  source and DDR/GINFO configuration;
- reliable maximum size of one BootROM Stage-2 bulk transfer;
- exact project-owned U-Boot relocation address, malloc reservation, and all
  reserved RAM boundaries;
- safe kernel file-buffer address and combined-loader layout;
- autonomous Stage-2 boot command or handoff without persistent environment;
- qualified no-UART success/failure observation channel;
- whether this U-Boot accepts the project gzip uImage and an external FDT in the
  proposed `bootm` form;
- whether the observed U-Boot accepts the built-in KE DT handoff;
- kernel decompression reservations and all SoC/DMA/framebuffer regions;
- stable X2000 Linux boot, SMP, eMMC enumeration, and DT activation;
- actual WLAN firmware/NVRAM, power sequencing, association, DHCP, and SSH for
  this deferred RAM-only artifact;
- any physical F005 behavior (intentionally not tested here).

## HARDWARE VALIDATION REQUIRED

No USB RAM-stage hardware procedure is ready or authorized. The serial steps
below are retained only as the earlier conditional plan; they are unavailable
under the no-solder constraint. A USB RAM-stage test requires a separate review
after the remaining offline requirements are closed.

### 3.3b-0 — non-writing bootloader observation

This phase would be required before 3.3b-1 because console, autoboot, prompt,
load-address, and DT handoff are not proven offline. Under the current no-solder
constraint it is **technically useful but practically unavailable**: no existing
external bootloader console and no additional USB-UART/debug connection are in
scope. It remains **NOT STARTED** and requires explicit authorization if an
existing-interface route is later proven.

### 3.3b-1 — conditional RAM-only Linux boot

This serial variant is only admissible after 3.3b-0 and after a separate offline
build produces a kernel with the preferred built-in gzip initramfs and a correct
KE DT handoff. It is not the selected no-solder route.

1. Prepare a serial-transfer set containing the project `kernel-ramboot.uImage`;
   the current artifact uses its built-in KE DT, so no external DTB is required
   for this handoff.
2. Use the observed `loady` command with a file address confirmed in 3.3b-0.
3. Verify the transferred sizes before booting; stop on any mismatch.
4. Use `bootm` with the kernel address and, only if required, the verified DTB
   address. Do not use a stock root argument.
5. Expect `ttyS4` at 115200 and the project Linux 6.6 console.
6. Check kernel version, active compatible strings, two CPUs, approximate RAM,
   and the presence of the MMC host.
7. Confirm there are no mounted p7-p10 filesystems and no write activity.
8. Confirm `/dev/ttyS1` exists without opening or configuring it.
9. Optionally attempt WLAN/IP/SSH with the private provisioned artifact only
   after the console and no-write checks pass.
10. Stop the test or power-cycle; then observe an unchanged stock boot.

No command in this sequence authorizes persistent state changes. If an external
raw initramfs is selected later instead of the preferred built-in form, it must
be wrapped in a loader-compatible legacy ramdisk image and receive a separate
review; that is not selected by this plan.

### STOP conditions

Stop without improvisation on any of the following:

- no expected prompt or autoboot interruption;
- loader identity materially differs from the analyzed binary;
- required command is absent or behaves unexpectedly;
- USB medium is not unambiguously identified;
- file size, address, checksum, or DT identity is unexpected;
- any overlap, corruption, bootm, decompression, or transfer error;
- any required persistent write or environment save;
- any stock p7/p8 root, p9/p10 mount, automount, fsck repair, or mke2fs;
- `ttyS1` appears as console/getty or receives traffic;
- boot loop, watchdog reset loop, unstable kernel, or unknown persistence state.

### First-boot success criteria

The first RAM-only kernel bring-up is successful only when all of these hold:

- project Linux 6.6 starts;
- the KE DT is active;
- an explicitly qualified no-UART observation channel is usable;
- two CPUs and approximately 256 MiB are detected;
- eMMC/MMC is detected without a persistent write;
- no p7-p10 filesystem is mounted or modified;
- `/dev/ttyS1` exists and is unused;
- the system remains stable for basic diagnosis;
- a power-cycle returns to the unchanged stock boot path.

WLAN, IP, and SSH are bonus checks for this first kernel boot but remain
REQUIRED for final `2026.1`. Persistent SSH host identity is also REQUIRED
before that release; the current Dropbear identity is runtime-generated and
ephemeral through `/run`.

## Decision and next step

The offline plan does not select USB mass storage, does not reopen the failed
private recovery client investigation, and does not authorize hardware work.
The public prior art changes the independent no-solder RAM-stage assessment from
**BLOCKED** to **MAYBE**: an X2000 BootROM -> SPL -> RAM U-Boot path is credible
and reported on the KE, but the bundled binaries are not project components and
the selected project-owned path is not yet safe.

The smallest next step for this deferred alternative is a bounded offline
feasibility proof for an exact open KE-compatible SPL and autonomous Stage 2.
It must derive the actual relocation
and reserved-memory map, prove a non-overlapping kernel file buffer (with
`0x81000000` only a candidate), account for the combined transfer size, and
define a no-UART observation channel. No implementation or hardware phase for
this deferred RAM-only alternative is started here. Phase 3.3b on the selected
A/B path is **IN PROGRESS**; each additional persistent or boot-changing
hardware operation still requires explicit authorization. The verified Slot-B
smoke result is recorded in
[`x2000-ab-bringup-plan.md`](x2000-ab-bringup-plan.md); it does not qualify this
deferred RAM-only alternative.

The selected A/B path completed its read-only qualification and bounded p1
A -> B -> A rollback gate. A later separately authorized Phase 3.3b operation
deployed the prepared Slot-B kernel/rootfs to p6/p8 with read-back verification
while p5/p7 remained byte-for-byte unchanged. A subsequent Slot-B smoke boot
reached early userspace, ran the automatic p1 B -> A selector rollback, and
returned to Stock A from p7 after reboot. A later separate Slot-B Network-Smoke
additionally qualified its bounded SDIO WLAN/WPA/DHCP/non-interactive-SSH path
while the rollback was armed. Neither result validates this deferred RAM-only
alternative. The complete vendor recovery procedure remains documented but not
personally rehearsed. The original smoke test did not qualify network, display,
touch, WLAN, USB, Klipper, or printer peripherals; network and Dropbear were
intentionally disabled in that rootfs. OpenCV
remains `DISABLED / UNNEEDED`; ADXL remains `DEFERRED / NOT REQUIRED FOR
2026.1`; p9/p10 remain `UNKNOWN / RESERVED`; Gate 1 remains **SATISFIED**.
The release model remains `YEAR.RELEASE[.STAGE]`, target final `2026.1`, scope
`first-printable-networked-open-host`. `2026.1.a` is the documented current
development milestone, not a Git tag or published release. Separate manual
Slot-B selection through the host-side `scripts/x2000-ab` tool is
hardware-validated for explicit p1 A -> B and B -> A selector changes; it does
not alter this deferred RAM-only alternative or the retained one-shot safety
paths.
