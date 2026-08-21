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

It requires explicit authorization before any printer action. It must assess a controlled
non-persistent boot route: X2000 boot/SMP/256 MiB/debug console; eMMC; UART1/F005;
I2C2/I2C4; `spi-gpio`/ADXL; SDIO WLAN; display; USB/UVC; and watchdog. UART1 work must
verify the 230400 node, observe F005 without a ttyS1 console/getty, then make only the
smallest permitted MCU check. Nothing here authorizes it.
