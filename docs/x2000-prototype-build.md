# Phase 3.3a offline prototype build

This is a reproducible build definition, not deployment. It does not access a printer,
write eMMC, alter a bootloader, or satisfy Gate 1.

`configs/x2000-prototype/sources.json` pins the public Ingenic source mirror to
`a98c2e1f22e4263ddd4153a4eca4db4dcfd2777b`, release identity
`ingenic-linux-kernel6.6-x2000-v1.0-20250221`: Linux 6.6.18 and vendored Buildroot
2023.08.3. It is a public source mirror, not an official Ingenic GitHub release.
The Ingenic public Gitee release has the same identity.

The build imports only the GPL-2.0-or-later NS2009 source from its pinned NebulaOS
commit, into ignored container storage. It never commits that code. NebulaOS is
patch-level prior art, not the selected distribution or firmware. The Docker base
uses a digest; the source-pinned SDK GCC 7.2 toolchain avoids host package installation.

Run `scripts/build-x2000-prototype`. The containers run as the invoking user; the
first fetches the pinned commits and the compiler container uses `--network none`.
Ignored local output has the uImage, project DTB, squashfs rootfs, effective
configs, hashes, and a machine-readable build manifest. Checks cover image, ELF,
object format, uImage, DT, and required configuration. The rootfs is minimal
BusyBox with `/dev`, `/proc`, `/sys`, `/tmp`, and a shell.

The normal invocation keeps the existing SquashFS-rooted development artifact:
`kernel.uImage`, `ender3-v3-ke.dtb`, `rootfs.squashfs`, effective configs,
checksums, and a manifest. The public volatile boot variants are:

```text
scripts/build-x2000-prototype --ramboot
scripts/build-x2000-prototype --ramboot --provision
```

They emit separate ignored directories with `kernel-ramboot.uImage`, the
external KE DTB, the reference SquashFS, effective configs, checksums, and a
manifest. The kernel contains the KE DT and a gzip-compressed Buildroot-target
initramfs whose target mtimes are normalized to Unix epoch 0 and whose `/init`
links to `sbin/init`; no p7/p8/p9/p10 root or mount is part of this path. The
uImage header load value is not a U-Boot file-load
address; the latter remains UNKNOWN until 3.3b-0. The generic RAM artifact is
credential-free. The provisioned RAM artifact is a PRIVATE DEVELOPMENT
ARTIFACT containing local deployment/test-specific WLAN and SSH authorized-key
data and must not be published or distributed as a generic release artifact.

The generic image contains `wpa_supplicant` with the nl80211 driver,
BusyBox `udhcpc`, and Dropbear. Dropbear password authentication is compiled out;
the Buildroot root password login is disabled. Its `/etc/dropbear` location points
at the tmpfs-backed `/run`, so the standard Buildroot start script generates fresh
host keys at each boot with Dropbear's `-R` option. Host identity is therefore
runtime-generated and currently ephemeral across reboot. This is accepted only for
the non-persistent Phase 3.3b
bring-up; persistent SSH host identity is REQUIRED before final 2026.1. The later
persistence solution depends on the unresolved persistent-data architecture and
does not assign p9/p10, which remain `UNKNOWN / RESERVED`. No host key is embedded.
The serial shell remains available.

The generic image has no network credentials and does not start WLAN. An explicit
local development build is available only as
`scripts/build-x2000-prototype --provision`. It requires the ignored private inputs
`local/phase3/provision/wpa_supplicant.conf` and
`local/phase3/provision/authorized_keys`. They are copied only into a temporary
container-work overlay, respectively to
`/etc/wpa_supplicant/wpa_supplicant.conf` and `/root/.ssh/authorized_keys` with
mode 0600; the containing `.ssh` directory has mode 0700. Its artifact directory is
separately ignored as `local/phase3/x2000-prototype-provisioned`. It is a `PRIVATE
DEVELOPMENT ARTIFACT`: it intentionally contains local deployment/test-specific
WLAN and SSH authorized-key data and must not be published or distributed as a
generic release artifact. The generic image remains credential-free; its private
manifest records only the neutral boolean `local_provisioning` and never input
contents or input hashes.

The selected A/B bring-up also has a separate offline smoke-build mode:

```text
scripts/build-x2000-prototype --slot-b-smoke
```

It emits the ignored `local/phase3/x2000-slot-b-smoke/` directory with
`kernel-slot-b.uImage`, `rootfs-slot-b.squashfs`,
`ender3-v3-ke-slot-b.dtb`, `effective-kernel-config`, `buildroot.config`,
`SHA256SUMS`, and `build-manifest.json`. The kernel has no integrated
Buildroot initramfs and fails closed unless it is smaller than p6's 8 MiB;
the SquashFS fails closed unless it is smaller than p8's 500 MiB. Its generated
DT uses the explicit p8 command line:

```text
console=ttyS4,115200 root=/dev/mmcblk0p8 rootwait rootfstype=squashfs ro
```

The pinned MIPS setup code consumes the DT `chosen/bootargs` when
`CONFIG_MIPS_CMDLINE_FROM_DTB=y`; it does not require Stock's `lcm_id` or
split `mem=` arguments for this path. The project-owned DT already declares
the intended 256 MiB memory region, so `mem=256M@0x0` would be redundant and
`mem=0M@0x30000000` is deliberately not carried over.

The smoke rootfs runs a project-owned early selector safety step before
optional services. It validates B, changes p1 exactly once to the A format,
syncs, reads back 512 bytes, and only then permits the bounded read-only smoke
checks and controlled reboot. Fixture tests exercise the same selector helper;
no real `/dev/mmc*` device is used by them. Generic and RAM-only invocations
retain their existing artifact names and semantics.

BusyBox init mounts proc, sysfs, `/run`, and `/dev/pts`, then invokes the existing
`rcS` sequence. Its scripts start the provisioned WLAN path when configuration
is present and start Dropbear; seed state is directed to volatile `/run`.

With that local WLAN configuration, `S45network-provisioned` selects the first
wireless interface exposed in sysfs, starts `wpa_supplicant`, then starts `udhcpc`
in the background. Absence of the private configuration or of a wireless interface
returns successfully and does not delay boot or the serial console. This is the
offline-prepared WLAN → DHCP → SSH path, not a hardware validation; the actual
interface name, firmware/NVRAM, power sequencing, association, DHCP lease, and SSH
reachability remain Phase-3.3b checks.

The project-owned KE DTS uses `10031000.serial` / `/dev/ttyS1` for F005 at 230400,
with no console or getty there; debug is on another UART. It also has the observed
eMMC controller (`13450000.msc`) and NS2009 binding (I2C4, `0x48`).

| Surface | Treatment |
| --- | --- |
| KE DTS, UART1, eMMC, I2C2/I2C4, USB, watchdog | REIMPLEMENT |
| NS2009 GPL driver | REUSE AS PATCH |
| core fixes, `spi-gpio`/ADXL, panel, SDIO WLAN | DEFER |
| USB UVC camera | NOT NEEDED for offline build |

The reference ADXL endpoint was `spi-gpio` / `spidev2.0`, not hardware SPI. No GPIO
or chip-select is claimed; the disabled node is only a later test target. The SDK WLAN
driver and all firmware/NVRAM are excluded. The kernel fragment prepares
`brcmfmac`, SDIO, and firmware-loader support. Based on the detected SDIO chip,
brcmfmac requests `/lib/firmware/brcmfmac*-sdio.bin`, the matching `.txt` NVRAM,
and for some chips a `.clm_blob`; no exact chip or file is asserted yet. A future
route must separately provide redistributable firmware/NVRAM, never a personal
MAC/NVRAM file. WLAN power sequencing is a Phase-3.3b qualification item. The generic NS2009 binding
does not claim calibration, events, or a pendown GPIO. Display, UVC, WLAN, and
all field behavior remain untested.

The release target and scope are defined in [`versioning.md`](versioning.md).
`2026.1` requires at least one qualified administrative network path, stable IP
configuration, reliable SSH administration, persistent SSH host identity, and
network/SSH usable after normal reboot, as well as a reliable F005 print. SDIO WLAN
is the prepared integrated candidate; a later identified USB-Ethernet adapter may
also qualify, but no speculative USB-network driver is enabled. Display/touch,
Moonraker, camera, and ADXL are not release critical. The current offline state is
`NETWORK USERSPACE PREPARED`; it is not `NETWORK HARDWARE VALIDATED` and does not
satisfy the `2026.1` network requirement. The current development manifest sets no
public version.

## Phase 3.3b is not started

It requires Gate 1 and explicit authorization before any printer action. The selected route is a
controlled Slot-B one-shot boot as specified in
[`x2000-ab-bringup-plan.md`](x2000-ab-bringup-plan.md): X2000 boot/SMP/256 MiB/debug
console; eMMC; UART1/F005; I2C2/I2C4; `spi-gpio`/ADXL; SDIO WLAN; display; USB/UVC;
and watchdog. The first Slot-B rootfs must not mount p9/p10, open UART1, or start
OTA/update services. UART1 work must verify the 230400 node, observe F005 without a
ttyS1 console/getty, then make only the smallest permitted MCU check. The RAM-only
artifact remains a deferred alternative and is not the selected first-boot path.
Nothing here authorizes it.
