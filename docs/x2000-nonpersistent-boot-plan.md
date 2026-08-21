# X2000 non-persistent boot plan

This is an offline plan for the first controlled Phase 3.3b hardware boot. It
does not authorize hardware access. Phase 3.3b remains **NOT STARTED** and
requires explicit authorization.

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
boundaries and are not used for this plan.

The selected volatile source is therefore **serial `loady`**, conditional on the
later console observation. TFTP/DHCP remain proportional alternatives only if a
real USB-Ethernet path is separately qualified. No new transport is designed.

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
filesystem repair, and no update path in the init sequence. The inittab mounts
proc, sysfs, a tmpfs-backed `/run`, and devpts, then invokes the existing `rcS`
script. Dropbear keys, DHCP lease state, and seed state are runtime data under
`/run`; the rootfs contains administrative tools such as
`fsck`, `mke2fs`, and flash utilities, but their presence is not an invocation.

The first boot contract is therefore:

- no eMMC write or environment save;
- no `saveenv`, `env save`, `mmc write`, `mmc erase`, `fatwrite`, `ext4write`,
  OTA, `fsck` repair, `mke2fs`, swap, or persistent log setup;
- no p7/p8 root, p9 overlay, or p10 mount;
- `/run`, `/tmp`, and runtime Dropbear identity remain in RAM.

### F005 no-touch model

The KE DT exposes UART1 as `/dev/ttyS1` at the existing 230400-baud F005
interface. The project rootfs has no getty on UART1 and no UART1 console. The
first Linux check may confirm the node exists through sysfs or device metadata;
it must not open the node, call `stty`, transmit bytes, start Klipper, or run a
serial probe. A debug shell remains on the separate `ttyS4` console.

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
`wpa_supplicant`, BusyBox `udhcpc`, and Dropbear. No redistributable firmware or
board-specific NVRAM is present, and the exact chip/power sequence is not
validated. WLAN/IP/SSH are optional bonus checks after a stable console boot;
they are not the first kernel success criterion. A network failure must not stop
the serial bring-up.

## UNKNOWN

- exact BootROM-to-persistent-U-Boot selection sequence;
- physical mapping of the bootloader console to the proposed debug connector;
- actual autoboot prompt and interrupt timing;
- whether the captured loader's command strings operate on this board as
  expected;
- USB host and USB mass-storage support in the normal loader;
- exact `loady` transfer syntax and file-load address;
- U-Boot relocation and reserved RAM boundaries;
- whether this U-Boot accepts the project gzip uImage and an external FDT in the
  proposed `bootm` form;
- whether the observed U-Boot accepts the built-in KE DT handoff;
- kernel decompression reservations and all SoC/DMA/framebuffer regions;
- stable X2000 Linux boot, SMP, eMMC enumeration, and DT activation;
- actual WLAN firmware/NVRAM, power sequencing, association, DHCP, and SSH;
- any physical F005 behavior (intentionally not tested here).

## HARDWARE VALIDATION REQUIRED

### 3.3b-0 — non-writing bootloader observation

This phase is required before 3.3b-1 because console, autoboot, prompt,
load-address, and DT handoff are not proven offline.

1. Prepare the isolated serial observation path.
2. Power the printer on only after explicit hardware authorization.
3. Observe boot output; do not interrupt blindly.
4. Interrupt the one-second autoboot window only if the expected prompt appears.
5. Record the version/identity and prompt without changing the environment.
6. Use only `help`, `printenv`, and other explicitly read-only commands needed
   to confirm the already evidenced command set.
7. Confirm whether the loader can identify a removable medium. Do not write it.
8. Do not issue `saveenv`, `env save`, `mmc write`, `mmc erase`, `fatwrite`,
   `ext4write`, OTA, or any recovery command.
9. Power-cycle and observe the normal stock boot.

If any expected console, prompt, or command evidence is absent, stop and do not
continue to 3.3b-1.

### 3.3b-1 — conditional RAM-only Linux boot

This phase is only admissible after 3.3b-0 and after a separate offline build
produces a kernel with the preferred built-in gzip initramfs and a correct KE DT
handoff.

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
- the debug console is usable;
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
BootROM Stage-2 recovery investigation, and does not authorize hardware work.
The smallest offline implementation is now present in the public wrapper: it
links the KE DT as the built-in DT and generates the existing
generic/provisioned Buildroot target as a deterministic gzip initramfs. The
next required step is the explicitly authorized, non-writing 3.3b-0
bootloader observation; Phase 3.3b remains **NOT STARTED**.

OpenCV remains `DISABLED / UNNEEDED`; ADXL remains `DEFERRED / NOT REQUIRED FOR
2026.1`; p9/p10 remain `UNKNOWN / RESERVED`; Gate 1 remains **NOT SATISFIED**.
The release model remains `YEAR.RELEASE[.STAGE]`, target `2026.1`, scope
`first-printable-networked-open-host`, with the current work classified as a
development build and no release version or tag.
