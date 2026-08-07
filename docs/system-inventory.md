# System inventory: Ender-3 V3 KE

- Reference inventory date: 2026-08-07
- Target: `<printer-host>`
- Method: non-interactive SSH, read-only remote commands only

Unless stated otherwise, values in this document were observed on the reference
system running Creality firmware `V1.1.0.15`. They are not asserted for every
Ender-3 V3 KE hardware or firmware revision.

No backup, migration, service action, firmware action, or remote file change was
performed. A sanitized record of the SSH calls is available in
[`ssh-command-log.md`](ssh-command-log.md).

## Evidence labels

- **Confirmed**: directly observed in files, procfs/sysfs, process state, or logs.
- **Inference**: conclusion from confirmed observations, but not directly verified.
- **Open**: not safely answerable with the permitted read-only methods.
- **Risk**: operational or recovery concern found during inventory.

## Important scope finding

**Confirmed:** The active Creality Klipper executable, `klippy.py`, and stock
Klipper start script are byte-identical to the read-only SquashFS copies under
`/rom`. The running process is the Creality installation.

**Confirmed:** The inspected reference device contained modifications in writable
storage. Therefore observations from `/overlay` and `/usr/data` must not
automatically be considered components of the stock Creality firmware. Concrete
local modifications are recorded only in the ignored `local-device.md`.

Any later comparison with a factory image must distinguish the immutable Creality
base from these persistent additions.

## Hardware

| Item | Observation on the V1.1.0.15 reference system |
|---|---|
| Product/platform | Ender-3 V3 KE; Creality hardware ID `F005`; device-tree compatible `ingenic,x2000_module_base`, `ingenic,x2000` |
| SoC/CPU | Ingenic X2000 family; two XBurst II V2 cores; MIPS32r2; MSA; FPU present |
| CPU count | 2 (`processor 0` and `processor 1`) |
| Reported speed indicator | 2390.01 BogoMIPS per core; cpufreq values were not exposed at the usual sysfs path |
| RAM | `MemTotal` 201,744 KiB; kernel command line reserves/declares 256 MiB (`mem=256M@0x0`) |
| Swap | 131,068 KiB configured; backed by `/usr/data/swap` (128 MiB) |
| Internal storage | DG4008 eMMC, nominal 8 GB; details in [`storage-layout.md`](storage-layout.md) |
| Display | 480x272 at 60 Hz; framebuffer devices `fb0`..`fb3`; framebuffer virtual size 480x544 |
| Touch | NS2009 controller on I2C bus 4, address reflected as `4-0048`; `/dev/input/event0` |
| Camera | `/dev/video0`..`video4`; active Creality camera alias `/dev/v4l/by-id/main-video-4 -> ../../video4` |
| Sensors/buses used by Host MCU | `/dev/i2c-2` and `/dev/spidev2.0`; ADXL345 configured on SPI 2.0; BL24C16F EEPROM configured on I2C 2 |
| Wi-Fi | Broadcom/Cypress driver `cywdhd`; SDIO device on `mmc1` |
| Bluetooth | BSA server using `/dev/ttyS3` and Broadcom BCM4343A1 firmware |

The roughly 54 MiB difference between the 256 MiB command-line memory declaration
and Linux `MemTotal` is **inferred** to be kernel/device reserved memory, including
multimedia/framebuffer areas. It was not mapped allocation-by-allocation.

## Operating system and firmware

| Item | Observation on the V1.1.0.15 reference system |
|---|---|
| Architecture | `mips` |
| Kernel | `4.4.94`, SMP, PREEMPT, build `#7`, 2024-08-06 |
| Kernel toolchain | Ingenic GCC 7.2.0 Linux-Release5.1.0 toolchain |
| Userspace | Buildroot `2020.02.1-g1ad352d2bd-dirty` |
| BusyBox | 1.31.1, built 2024-07-17 |
| Creality system firmware | `V1.1.0.15` |
| OTA board/version | board `F005`, OTA `1.1.0.15`, compile time 2024-08-06 09:12:56 |
| Root user | Runtime services and SSH inventory run as root |

Device serial and MAC values reside in persistent/factory data. Concrete values
belong only in the ignored `local-device.md` and must be treated as sensitive
device identity during a future backup.

## Boot and init

**Confirmed:** PID 1 is BusyBox `init` via `/linuxrc`; both `/linuxrc` and
`/sbin/init` resolve to BusyBox. The kernel command line is:

```text
console=ttyS4,115200n8 mem=256M@0x0 mem=0M@0x30000000 lcm_id=0 init=/linuxrc root=/dev/mmcblk0p7 rootwait rootfstype=squashfs ro
```

BusyBox init processes `/etc/inittab`, mounts the basic pseudo-filesystems, enables
swap, and calls `/etc/init.d/rcS`. Before numbered init scripts, `rcS` calls
`/etc/mount_mmc_ext4_overlay.sh start`, which pivots from the read-only SquashFS to
an overlay root. It then runs every `/etc/init.d/S??*` in lexical/numeric order.
There is no `/etc/rcS.d` or `/etc/rc.d` tree.

Relevant observed order:

1. hostname, syslog, kernel log, userdata mount, ubus/device setup
2. display/driver/udev/board initialization
3. `S13mcu_update` MCU handshake/version check and possible boot-time firmware update
4. network, Wi-Fi, NTP, Dropbear
5. optional services supplied from writable storage
6. stock Klipper, Moonraker, Host MCU, and factory-reset check
7. Creality AI middleware, wipe service, WebRTC, swap, mDNS
8. Creality master/audio/Wi-Fi/app/display/upgrade/web servers and monitor

The init scripts themselves contain many write and update operations during normal
boot. They were only read during this inventory; none was invoked by the inventory.

## Active services and interfaces

| Component | Observed reference process/path | Interface |
|---|---|---|
| Stock Klipper | `/usr/share/klippy-env/bin/python /usr/share/klipper/klippy/klippy.py` | `/tmp/klippy_uds` |
| Moonraker | `/usr/data/moonraker/moonraker-env/bin/python .../moonraker.py` | TCP 7125; `/usr/data/printer_data/comms/moonraker.sock` |
| Klipper Host MCU | `/usr/bin/klipper_mcu -r` | `/tmp/klipper_host_mcu -> /dev/pts/0` |
| Printer MCU | Klipper file descriptor to `/dev/ttyS1` | UART, 230400 baud |
| Creality UI stack | `master-server`, `audio-server`, `wifi-server`, `app-server`, `display-server`, `upgrade-server`, `web-server`, `Monitor` | Creality web server on TCP 80; internal sockets/services |
| Camera | `cam_app`, `mjpg_streamer` | MJPEG TCP 8080 |
| WebRTC/AI | `webrtc`, `cx_ai_middleware` | TCP 9999 is present; exact process ownership is an inference |
| SSH | Dropbear | TCP 22 |

Additional services from writable storage were present on the inspected device.
Their concrete names, versions, paths, and ports are local-device information and
must not be attributed to the stock firmware.

## Risks

- **Risk:** Writable-storage exhaustion can break normal writes or future boots.
  Verify sufficient free space before backup, deployment, or migration work.
- **Risk:** Stock init includes automatic MCU version checking and is capable of
  flashing an MCU at boot. The inventory did not trigger it, but this matters when
  testing altered images.
- **Risk:** Root access exposes serial/MAC, WLAN credentials, Moonraker secrets,
  certificates, and device history. Future backup artifacts require access control.
- **Risk:** The system clock starts at 2020-03-01 before network time correction.
  Many mtimes/log entries therefore cannot be treated as reliable chronology.
- **Risk:** Persistent-storage modifications can be mistaken for factory state.
  Compare `/overlay` and `/usr/data` against a trusted stock image before drawing
  stock-firmware conclusions.

## Open questions

- Exact X2000 package/clock rate and the full reserved-memory allocation.
- Boot ROM/U-Boot version and its physical location.
- Which process owns TCP 9999 without using more invasive tracing.
- A clean factory-image comparison is needed to classify every overlay addition.
