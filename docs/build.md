# Building Fre3nder

All builds are offline-oriented and operate on local source trees and ignored
build output. They do not access or modify a printer.

## X2000 host

Use [`scripts/build-x2000`](../scripts/build-x2000) with the pinned sources and
configuration under [`configs/x2000`](../configs/x2000). The container recipe
is [`build/x2000`](../build/x2000), and the source manifest is
[`configs/x2000/sources.json`](../configs/x2000/sources.json).

The resulting host image uses Linux 6.6.18-rt23, a read-only SquashFS RootFS,
`root=/dev/mmcblk0p8`, upstream Klipper at the pinned revision, and the
project's passive-UART patch. BYOF firmware and credentials remain outside the
repository and are never embedded automatically.

The productive source and configuration layers are separated as follows:

```text
Ingenic SDK
└── Kernel 6.6.18-rt23 source

Upstream Buildroot 2025.02.17
└── internal GCC 13.4.0 / binutils 2.43.1 / glibc toolchain
    ├── Kernel compiler
    ├── RootFS / userspace compiler
    └── F005 X2000 host-helper compiler

Debian ARM bare-metal toolchain
└── F005 / GD32F303 MCU firmware

Fre3nder
├── buildroot.defconfig
├── buildroot.fragment
├── BusyBox fragment
└── RootFS overlays
```

The RootFS build uses the official upstream Buildroot checkout pinned in
[`configs/x2000/sources.json`](../configs/x2000/sources.json). It no longer
depends on the Ingenic Buildroot fork, its
`halley5_linux_minimal_defconfig`, or an external userspace toolchain. The
internal toolchain targets little-endian MIPS32r2/O32 hard-float with FPXX and
NaN2008, using Linux 6.6 headers. The XBurst II target retains upstream
Buildroot's `-ffp-contract=off` XBurst workaround for userspace. The kernel uses the same Buildroot toolchain
family through the underlying `gcc.br_real`, but Kbuild supplies its separate
MIPS32r5/O32/soft-float/legacy-NaN target contract. The userspace wrapper flags
are not applied to the kernel. The Ingenic SDK remains only the separately
pinned source of the vendor kernel. Buildroot package downloads are retained
outside its Git checkout so source-tree cleanup does
not discard the offline-build cache. See
[`buildroot-maintenance.md`](buildroot-maintenance.md) for the LTS update
policy.

The ignored productive tree is organized as follows:

```text
local/production/
├── inputs/wifi/
│   ├── brcmfmac43430-sdio.bin
│   └── brcmfmac43430-sdio.txt
├── work/x2000/
└── artifacts/x2000/
    ├── full/
    ├── kernel-only/
    └── rootfs-only/
```

The default `scripts/build-x2000` invocation writes the full artifact set;
`scripts/build-x2000 --kernel-only` and
`scripts/build-x2000 --rootfs-only` select the corresponding mode-specific
directories. The two WLAN files are BYOF inputs and are checked against the
hashes recorded in [`configs/x2000/sources.json`](../configs/x2000/sources.json).

### Moonraker RootFS baseline

RootFS builds fetch the pinned Moonraker source and hash-pinned
pure-Python wheels before the network-disabled build phase. The RootFS contains
the upstream Git checkout at `/opt/fre3nder/moonraker` and a PEP 405 environment
at `/opt/fre3nder/moonraker-env`. Native Python dependencies come from
Buildroot; pure-Python wheel contents are staged in the environment. No target
source build or boot-time dependency installation is required.

The checkout retains its upstream origin and exact pinned HEAD so Moonraker can
recognize its own source for later stable-channel updates. Fre3nder Klipper is
still installed without Git metadata and remains outside Moonraker's update
ownership.

## F005 MCU

Use [`scripts/build-f005`](../scripts/build-f005) as the standard product
entry point for an F005 MCU build.

`scripts/build-f005 --check` validates the pinned source, productive patches,
configuration, packager, and build-container contract without fetching,
building, or writing artifacts.

A normal `scripts/build-f005` run requires a clean Fre3nder project worktree.
It prepares the pinned upstream Klipper revision, applies the productive F005
MCU and serial-bootloader-request patches, builds the firmware with network
access disabled during compilation, packages the updater-compatible image, and
writes an unqualified candidate set under:

    local/production/artifacts/f005/candidate/

The candidate includes the raw firmware, ELF, Klipper dictionary, resolved
configuration, packaged F005 image, X2000 `c_helper.so`, packaging report,
build manifest, and checksums.

Candidate output is deliberately separate from the currently
hardware-qualified F005 artifact used by the default `deploy-f005` path.
Successful compilation does not promote a candidate to a qualified release.

The underlying container recipe remains
[`build/klipper-f005`](../build/klipper-f005), and
[`scripts/package_f005_firmware.py`](../scripts/package_f005_firmware.py)
provides the F005 board-information packaging step. The F005 build mounts the
existing X2000 Buildroot `host/` output read-only and uses its normal wrapper
for `c_helper.so`; it neither downloads nor builds another MIPS toolchain. The
MCU firmware continues to use the separate `arm-none-eabi` bare-metal
toolchain. Fre3nder therefore has one productive MIPS-Linux toolchain, not one
compiler across all architectures.

The entire `build-f005` path is build-only. It performs no printer, UART,
selector, partition, reboot, flash, or other hardware operation.

The validated source, version, and license basis are recorded in
[`docs/licensing-and-provenance.md`](licensing-and-provenance.md).

For the complete historical first-print reproduction, including the older
staged candidates, see
[`research/docs/f005-first-print-reproduction.md`](../research/docs/f005-first-print-reproduction.md).
