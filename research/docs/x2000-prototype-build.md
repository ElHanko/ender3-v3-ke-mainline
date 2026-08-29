# Phase 3.3a offline prototype build

This is a reproducible build definition, not deployment. It does not access a printer,
write eMMC, alter a bootloader, or satisfy Gate 1.

`research/configs/x2000-prototype/sources.json` pins the public Ingenic source mirror to
`a98c2e1f22e4263ddd4153a4eca4db4dcfd2777b`, release identity
`ingenic-linux-kernel6.6-x2000-v1.0-20250221`: Linux 6.6.18 and vendored Buildroot
2023.08.3. It is a public source mirror, not an official Ingenic GitHub release.
The Ingenic public Gitee release has the same identity.

The build imports only the GPL-2.0-or-later NS2009 source from its pinned NebulaOS
commit, into ignored container storage. It never commits that code. NebulaOS is
patch-level prior art, not the selected distribution or firmware. The Docker base
uses a digest; the source-pinned SDK GCC 7.2 toolchain avoids host package installation.

Run `research/scripts/build-x2000-prototype`. The containers run as the invoking user; the
first fetches the pinned commits and the compiler container uses `--network none`.
Ignored local output has the uImage, project DTB, squashfs rootfs, effective
configs, hashes, and a machine-readable build manifest. Checks cover image, ELF,
object format, uImage, DT, and required configuration. The rootfs is minimal
BusyBox with `/dev`, `/proc`, `/sys`, `/tmp`, and a shell.

The normal invocation keeps the existing SquashFS-rooted development artifact:
`kernel.uImage`, `ender3-v3-ke.dtb`, `rootfs.squashfs`, effective configs,
checksums, and a manifest. The public volatile boot variants are:

```text
research/scripts/build-x2000-prototype --ramboot
research/scripts/build-x2000-prototype --ramboot --provision
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

The generic image has no network credentials and does not start WLAN. The
provisioned development build is available as
`research/scripts/build-x2000-prototype --provision` and requires the two provisioning
inputs below. The Network-Smoke build additionally requires the two WLAN inputs,
for four local inputs in total:

| Local input | Expected content and build treatment |
| --- | --- |
| `local/phase3/provision/wpa_supplicant.conf` | A valid `wpa_supplicant` configuration for the WLAN to be used, including its private network credentials. The build checks only that the file is readable; it copies it unchanged to `/etc/wpa_supplicant/wpa_supplicant.conf` with mode 0600. |
| `local/phase3/provision/authorized_keys` | One or more operator-controlled public-key lines in the Dropbear/OpenSSH `authorized_keys` format. The build checks only that the file is readable; it copies it unchanged to `/root/.ssh/authorized_keys` with mode 0600, with the containing `.ssh` directory at mode 0700. Private keys do not belong in this file. |
| `local/phase3/wifi/brcmfmac43430-sdio.bin` | Exact required WLAN firmware filename and bytes. SHA-256: `60dbb5b77b2c232e513322e0ff4350ab5dab5a9fcad0e26e80a2f089e652d720`. |
| `local/phase3/wifi/brcmfmac43430-sdio.txt` | Exact required WLAN NVRAM filename and bytes. SHA-256: `78fee458ab69c0a66ea462f6d6769e15b36f73582693f4dbb5a0e8e8be3cfb0a`. |

The two provisioning files must not be committed. The two WLAN files must also
remain local-only: `.gitignore` excludes `local/`, and the Network-Smoke build
rejects any WLAN file whose SHA-256 does not match the values above. The
Network-Smoke mode requires all four inputs and is invoked as:

```text
research/scripts/build-x2000-prototype --slot-b-network-smoke
```

The WLAN inputs used for `2026.1.a` have now been matched to a vendor artifact
with documented provenance. The source is the official Creality GitHub release
[`V1.1.0.12`](https://github.com/CrealityOfficial/Ender-3_V3_KE_Klipper/releases/tag/V1.1.0.12),
file `Ender-3_V3_KE_1.1.0.12.ingenic`, SHA-256
`5388b16810e51c8233d6ee978b5b4a09347a4c9a4a516d3c5bf8c686e6783f3c`. Its
`images/rootfs.squashfs` member is 115122176 bytes with SHA-256
`8d64c6c3f7a79efc2750ad4424b5ee5c07b6ba8cd651ed5e31151445c1262958`.

The proven path inside that RootFS is:

| Original vendor path | Network-Smoke name | SHA-256 |
| --- | --- | --- |
| `lib/firmware/wifi_bcm/cyw43438-7.46.58.13.bin` | `brcmfmac43430-sdio.bin` | `60dbb5b77b2c232e513322e0ff4350ab5dab5a9fcad0e26e80a2f089e652d720` |
| `lib/firmware/wifi_bcm/nvram_azw372.txt` | `brcmfmac43430-sdio.txt` | `78fee458ab69c0a66ea462f6d6769e15b36f73582693f4dbb5a0e8e8be3cfb0a` |

The project-specific import is a filename-only mapping; the file bytes are not
modified. A contributor obtains the vendor package independently and places it
at the ignored path `local/phase3/vendor/Ender-3_V3_KE_1.1.0.12.ingenic`, then
can reproduce the import with existing `7z` and `sha256sum` tools:

```sh
(
set -eu

artifact=local/phase3/vendor/Ender-3_V3_KE_1.1.0.12.ingenic
import_work=$(mktemp -d)
trap 'rm -rf "$import_work"' EXIT

test "$(sha256sum "$artifact" | awk '{print $1}')" = \
  5388b16810e51c8233d6ee978b5b4a09347a4c9a4a516d3c5bf8c686e6783f3c
7z e -so "$artifact" images/rootfs.squashfs > "$import_work/rootfs.squashfs"
test "$(stat -c '%s' "$import_work/rootfs.squashfs")" = 115122176
test "$(sha256sum "$import_work/rootfs.squashfs" | awk '{print $1}')" = \
  8d64c6c3f7a79efc2750ad4424b5ee5c07b6ba8cd651ed5e31151445c1262958

install -d -m 0700 local/phase3/wifi
7z e -so "$import_work/rootfs.squashfs" \
  lib/firmware/wifi_bcm/cyw43438-7.46.58.13.bin \
  > local/phase3/wifi/brcmfmac43430-sdio.bin
7z e -so "$import_work/rootfs.squashfs" \
  lib/firmware/wifi_bcm/nvram_azw372.txt \
  > local/phase3/wifi/brcmfmac43430-sdio.txt

test "$(sha256sum local/phase3/wifi/brcmfmac43430-sdio.bin | awk '{print $1}')" = \
  60dbb5b77b2c232e513322e0ff4350ab5dab5a9fcad0e26e80a2f089e652d720
test "$(sha256sum local/phase3/wifi/brcmfmac43430-sdio.txt | awk '{print $1}')" = \
  78fee458ab69c0a66ea462f6d6769e15b36f73582693f4dbb5a0e8e8be3cfb0a
)
```

This establishes provenance, local extraction, and byte integrity, but not
redistribution permission. The vendor package and extracted WLAN files remain
BYOF/local-only material and must not be committed or redistributed unless
file-specific permission is established.

The provisioning files are copied only into a temporary container-work overlay.
The provisioned artifact directory is separately ignored as
`local/phase3/x2000-prototype-provisioned`. It is a `PRIVATE DEVELOPMENT
ARTIFACT`: it intentionally contains local deployment/test-specific WLAN and
SSH authorized-key data and must not be published or distributed as a generic
release artifact. The generic image remains credential-free; its private
manifest records only the neutral boolean `local_provisioning` and never input
contents or input hashes.

The selected A/B bring-up has a separate offline smoke-build mode:

```text
research/scripts/build-x2000-prototype --slot-b-smoke
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

The Network-Smoke is a distinct locally provisioned Slot-B mode:

```text
research/scripts/build-x2000-prototype --slot-b-network-smoke
```

It requires ignored local WLAN/SSH provisioning and WLAN firmware inputs, emits
a separately ignored private development artifact, and must not be published or
distributed. It retains the early p1 B -> A rollback selector, omits the
ordinary smoke test's immediate reboot, and starts only the bounded mdev, WLAN,
DHCP, and Dropbear path. It does not mount p9/p10, use UART1/F005, or start
Klipper, printer peripherals, or OTA/update services. The two WLAN firmware
inputs are checked before the kernel build, embedded through
`CONFIG_EXTRA_FIRMWARE`, and also copied into the private RootFS. The private
manifest records only neutral build-mode booleans and artifact hashes; it does
not record provisioning or firmware input contents or input hashes.

The shared BusyBox `inittab` contains mount commands for proc, sysfs, `/run`,
and `devpts`, then invokes `rcS`; seed state is directed to volatile `/run`.
That static configuration is not equivalent to a runtime guarantee. The
2026-08-23 Slot-B Network-Smoke run observed tmpfs on `/run`, but no mounted
`devpts` filesystem or `/dev/pts`, and no separate tmpfs mount on `/tmp`.
The missing `devpts` mount blocked interactive SSH PTYs in that Network-Smoke
run. The later Production path mounts `devpts` successfully, and a subsequent
read-only hardware qualification proved interactive SSH PTY allocation and
shell operation.

With that local WLAN configuration, `S45network-provisioned` selects the first
wireless interface exposed in sysfs, starts `wpa_supplicant`, then starts `udhcpc`
in the background. Absence of the private configuration or of a wireless interface
returns successfully and does not delay boot or the serial console. This is the
offline definition of the WLAN → DHCP → SSH path. Its bounded hardware
qualification is recorded below; it is not a production-network design.

The project-owned KE DTS uses `10031000.serial` / `/dev/ttyS1` for F005 at 230400,
with no console or getty there; debug is on another UART. It also has the observed
eMMC controller (`13450000.msc`) and NS2009 binding (I2C4, `0x48`).

| Surface | Treatment |
| --- | --- |
| KE DTS, UART1, eMMC, I2C2/I2C4, USB, watchdog | REIMPLEMENT |
| NS2009 GPL driver | REUSE AS PATCH |
| core fixes, `spi-gpio`/ADXL, panel | DEFER |
| SDIO WLAN Network-Smoke | REIMPLEMENT; bounded reference-system validation complete |
| USB UVC camera | NOT NEEDED for offline build |

The reference ADXL endpoint was `spi-gpio` / `spidev2.0`, not hardware SPI. No GPIO
or chip-select is claimed; the disabled node is only a later test target. The
generic and RAM-only variants exclude the SDK WLAN driver and all firmware/NVRAM.
The Slot-B Network-Smoke instead uses the standard `brcmfmac` route with the
four ignored local inputs documented above. Their function is proven for
`2026.1.a`, and their provenance is now documented above; redistribution status
remains open. The generic NS2009 binding does not claim calibration, events, or a
pendown GPIO. Display, UVC, and all other field behavior remain untested.

The release target and scope are defined in [`versioning.md`](../../docs/versioning.md).
`2026.1` requires at least one qualified administrative network path, stable IP
configuration, reliable SSH administration, persistent SSH host identity, and
network/SSH usable after normal reboot, as well as a reliable F005 print. This
historical prototype enabled only SDIO WLAN. The later Production path adds the
hardware-validated AX88179B/CDC-NCM Ethernet-first route with WLAN fallback and
USB-provisioned public-key SSH. Display/touch, Moonraker, camera, and ADXL are
not release critical. Persistent SSH host identity, stable production
configuration and network/SSH behavior outside the qualified Development
USB-adapter Develop-B -> Develop-B reboot remain open.
`2026.1.a` is the documented project/development milestone; the private build
manifests remain provenance records rather than published release artifacts.

## Phase 3.3b hardware status

The selected route was a controlled Slot-B one-shot boot as specified in
[`x2000-ab-bringup-plan.md`](x2000-ab-bringup-plan.md). The original Slot-B
Smoke proved X2000 boot, p8 SquashFS root, early userspace, automatic p1 B -> A
rollback, and return to Stock A. The later locally provisioned Network-Smoke
proved SDIO WLAN enumeration, firmware start, WPA association, DHCP/default
route, ICMP, and non-interactive public-key SSH while the Stock-A rollback was
already armed. Together these results establish `2026.1.a` as the first
functional Open-Host alpha on the investigated reference system. The complete
evidence, its exact scope, and the later resolution and hardware qualification
of the `devpts`/PTY path are recorded in the A/B bring-up plan.

Neither smoke mode qualifies persistent mainline operation, production network
behavior, UART1/F005, Klipper, display, touch events, USB peripherals, or
printer functions. Both leave p9/p10 unmounted and `UNKNOWN / RESERVED`; they
do not start OTA/update services. The automatic one-shot paths remain unchanged
as safety/regression paths. The separate host-side `scripts/x2000-ab` path is hardware-validated for
explicit p1 A -> B and B -> A selector changes on the investigated reference
system. Develop-B -> Develop-B reboot persistence is qualified on the
investigated reference system for the Development USB-adapter path; external p1
rollback remains the recovery path if Mainline becomes unreachable. The RAM-only
artifact remains a deferred alternative and is not the selected first-boot path.

This limitation is specific to the Phase-3.3a smoke artifacts. The later
Phase-3.5 Develop artifact has a separate **QUALIFIED ON DEVICE** Fre3nder-B
Klippy/F005 runtime scope documented in [`x2000-develop-build.md`](x2000-build-history.md).
