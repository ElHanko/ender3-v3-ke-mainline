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
├── Kernel 6.6.18-rt23
└── mips-gcc720-glibc238 (kernel compiler only)

Upstream Buildroot 2025.02.17
└── internal GCC 13.4.0 / binutils 2.43.1 / glibc toolchain

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
legacy NaN, using Linux 6.6 headers. Upstream Buildroot's XBurst wrapper adds
`-ffp-contract=off`. The Ingenic SDK remains the separately pinned source of
the kernel and its compiler; that compiler is not used for the RootFS.
Buildroot package
downloads are retained outside its Git checkout so source-tree cleanup does
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
configuration, packaged F005 image, packaging report, build manifest, and
checksums.

Candidate output is deliberately separate from the currently
hardware-qualified F005 artifact used by the default `deploy-f005` path.
Successful compilation does not promote a candidate to a qualified release.

The underlying container recipe remains
[`build/klipper-f005`](../build/klipper-f005), and
[`scripts/package_f005_firmware.py`](../scripts/package_f005_firmware.py)
provides the F005 board-information packaging step. X2000 `c_helper.so` is
built productively by the X2000 Buildroot flow with its internal userspace
toolchain. The F005 container's older Ingenic-toolchain helper remains only for
the separate historical Stock-X2000 reproduction documented in
`research/docs/f005-first-print-reproduction.md`; it is not a Fre3nder RootFS
input.

The entire `build-f005` path is build-only. It performs no printer, UART,
selector, partition, reboot, flash, or other hardware operation.

The validated source, version, and license basis are recorded in
[`docs/licensing-and-provenance.md`](licensing-and-provenance.md).

For the complete historical first-print reproduction, including the older
staged candidates, see
[`research/docs/f005-first-print-reproduction.md`](../research/docs/f005-first-print-reproduction.md).
