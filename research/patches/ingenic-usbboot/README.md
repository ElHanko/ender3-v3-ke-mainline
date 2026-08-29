# Ingenic USB Boot patch provenance

This directory contains the narrow source patch used during the investigated
Ender-3 V3 KE external Ingenic USB research.

Upstream source:

- repository: https://github.com/ballaswag/ingenic-usbboot
- commit: `c65eaa337cc9fb64fd8a2ea22bcf3f9395c9945c`
- upstream `usbboot.c` license: GPL-2.0-or-later

The patch in this directory modifies that GPL-covered source and is distributed
under GPL-2.0-or-later. It does not include or redistribute the upstream loader
binaries.

The public patch is a zero-context representation derived from the preserved
local evidence patch. Applied to the pinned upstream commit with
`git apply --unidiff-zero`, it produces a byte-identical `usbboot.c` to the
preserved evidence patch. The resulting source file has SHA-256
`8368e4e08113680dd1fe5983d7c4e12b6f3572e53930e47189647b9a288b1693`.

This representation avoids carrying whitespace-only context lines from the
preserved evidence patch; it does not change the documented source modification.

## CPUINFO patch

`0001-fix-cpuinfo-libusb-return.patch` changes only
`jz_get_cpu_info()`.

The pinned upstream client treats every non-zero return from the libusb
`VR_GET_CPU_INFO` IN transfer as an error. On the investigated reference
system the successful response length was five bytes containing `X2000`.

The patch therefore:

- treats negative return values as libusb errors;
- rejects an empty response;
- terminates the CPU-info string at the returned byte count.

No loader, MMC read/write, OTA-selector, or RAM-U-Boot code is changed.

The public `scripts/x2000-usb-selector-to-a` helper does not depend on this
patch. At the pinned upstream commit its `--uboot`, `--dump-partition`, and
`--swap-ota` paths do not call `jz_get_cpu_info()`. The helper intentionally
continues to use the upstream checkout's tracked `usbboot` executable.

The historical hardware logs do not record a host-client binary hash for every
operation. Therefore this project does not claim that a newly built patched
client, or the tracked upstream `usbboot` binary, is byte-identical to the host
client used in every historical USB test.

## Fresh checkout for research verification

The ignored research checkout for reproducing this evidence belongs at:

    local/research/ingenic-usbboot-gate/upstream/ingenic-usbboot

From `<project-root>`, prepare that ignored local checkout with:

    mkdir -p local/research/ingenic-usbboot-gate/upstream
    git clone https://github.com/ballaswag/ingenic-usbboot \
      local/research/ingenic-usbboot-gate/upstream/ingenic-usbboot
    git -C local/research/ingenic-usbboot-gate/upstream/ingenic-usbboot \
      checkout --detach c65eaa337cc9fb64fd8a2ea22bcf3f9395c9945c

Verify the exact commit:

    test "$(git -C \
      local/research/ingenic-usbboot-gate/upstream/ingenic-usbboot \
      rev-parse HEAD)" = \
      c65eaa337cc9fb64fd8a2ea22bcf3f9395c9945c

Then verify the corresponding tracked upstream files:

    cd local/research/ingenic-usbboot-gate/upstream/ingenic-usbboot
    printf '%s  %s\n' \
      3dca4b33988f732de006595853df91a2269ce9bdff9c04b5fd797c804bb17a78 usbboot \
      6d2b7450a3e518eca602b642c2e67e665214b078b6defc145e6d58f559cab6c7 spl.bin \
      cb53b5195a6cb97c8e66d31e25a03b4e38a096f59e223699eba606acaa5984bc uboot.bin \
      | sha256sum -c -

This only prepares and verifies local research files. It does not access the
printer or authorize execution of `scripts/x2000-usb-selector-to-a`. The
productive selector helper uses its separately managed productive worktree and
does not depend on this research checkout.

The CPUINFO patch is not applied to this research checkout. The productive
selector helper likewise uses the tracked upstream `usbboot` executable because
its `--uboot`, `--dump-partition`, and `--swap-ota` paths do not call the
patched `jz_get_cpu_info()` function.

## Reproducing the CPUINFO source build

The preserved local reconstruction used this container base image:

    debian:13-slim@sha256:3a39a0592364683e6bab97937b72cad5a8fa6dcbbee90edb3bb48c7f8e94f258

and installed only:

    build-essential
    git
    libusb-1.0-0-dev
    pkg-config

The upstream Makefile then builds the host client with `make`. To reproduce the
documented source modification, start from the same pinned upstream commit and
apply:

    git apply --unidiff-zero \
      <project-root>/research/patches/ingenic-usbboot/0001-fix-cpuinfo-libusb-return.patch
    make

The preserved reconstruction compiled in a network-isolated container after the
build image had been prepared. Its loader inputs were checked before and after
the build and remained unchanged.

The exact Debian package versions installed when that image was originally
prepared were not preserved. Therefore this recipe documents the source,
patch, base-image identity, dependencies, and build command, but does not claim
that a future build will produce a bit-identical `usbboot` executable.

The preserved reconstruction produced a host executable with SHA-256
`a5632cde2429db89696d7879f7bb6062a1fcc2e942ecc2fa7641a4296bd34438`.
That hash identifies the preserved reconstruction only. It is not a required
output hash for future builds and is not claimed to identify the host client
used in every historical hardware operation.

## Preserved upstream identities

For the pinned commit, the locally preserved tracked files used as the source
basis have these identities:

usbboot
  size:    46704 bytes
  SHA-256: 3dca4b33988f732de006595853df91a2269ce9bdff9c04b5fd797c804bb17a78

spl.bin
  size:    10360 bytes
  SHA-256: 6d2b7450a3e518eca602b642c2e67e665214b078b6defc145e6d58f559cab6c7

uboot.bin
  size:    411508 bytes
  SHA-256: cb53b5195a6cb97c8e66d31e25a03b4e38a096f59e223699eba606acaa5984bc

The p1 A/B hardware-validation record establishes use of loaders with the
documented `spl.bin` and `uboot.bin` sizes. It does not establish a per-run
identity for the host `usbboot` executable.
