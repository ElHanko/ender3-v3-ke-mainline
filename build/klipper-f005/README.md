# Offline GD32F303/F005 Klipper build

This build recipe targets the investigated Ender-3 V3 KE F005 board with
GD32F303RET6. It is a validated containerized source-build recipe, not a
flashing or hardware procedure. The Debian base image and package versions are
not pinned to a snapshot, so this is not a bit-for-bit hermetic environment.

The recipe is based on upstream Klipper commit
`0499b30374315f2a9f49fc12808527fc7d0f5cfa` and the public patch in
`patches/klipper/0001-gd32f303-f005-mainline.patch`.

## Build

From the project root, with the upstream Klipper checkout at `klipper/`:

```sh
git -C klipper checkout 0499b30374315f2a9f49fc12808527fc7d0f5cfa
git -C klipper apply ../patches/klipper/0001-gd32f303-f005-mainline.patch
docker build --tag ender3-ke-klipper-build:f005 build/klipper-f005
docker run --rm --network none \
  --user "$(id -u):$(id -g)" \
  -v "$PWD/klipper:/work/klipper:rw" \
  -v "$PWD/build/klipper-f005/f005-gd32f303.config:/config/f005-gd32f303.config:ro" \
  -w /work/klipper \
  ender3-ke-klipper-build:f005 \
  sh -lc 'cp /config/f005-gd32f303.config .config && make olddefconfig && make'
```

The normal build produces the raw `klipper/out/klipper.bin`. After that build,
create the F005-updater candidate image offline:

```sh
python3 scripts/package_f005_firmware.py \
  klipper/out/klipper.bin klipper/out/klipper-f005-mainline.bin
```

`klipper.bin` is the raw Klipper build. `klipper-f005-mainline.bin` is the
separately packaged candidate image for the investigated F005 updater; the
packager writes the board-info version, length, and CRC16 fields.

The configuration is mounted read-only and copied to `.config` inside the
checkout before running `make olddefconfig`. The expected resolved values
include:

```text
CONFIG_MCU="gd32f303xe"
CONFIG_MACH_GD32F303=y
CONFIG_MACH_STM32F1=y
CONFIG_CLOCK_FREQ=120000000
CONFIG_CLOCK_REF_FREQ=8000000
CONFIG_FLASH_APPLICATION_ADDRESS=0x8003000
CONFIG_FLASH_SIZE=0x3d000
CONFIG_RAM_START=0x20000000
CONFIG_RAM_SIZE=0x10000
CONFIG_STM32_FLASH_START_3000=y
CONFIG_STM32_SERIAL_USART2=y
CONFIG_SERIAL_BAUD=230400
```

The image build installs only the compiler/build packages needed for this
recipe. It does not build firmware automatically. The container should be run
without network access for the compilation step, as shown above.

## Host c_helper for X2000

The same image also contains the MIPS Linux toolchain needed to cross-build
Klipper's host-side `c_helper.so` for the X2000. It is the community-hosted
`mips-gcc720-glibc229` distribution from the
[`ballaswag/k1-discovery` 1.0.0 release](https://github.com/ballaswag/k1-discovery/releases/tag/1.0.0),
whose archive SHA256 is pinned in the Dockerfile. The compiler identifies
itself as the Ingenic GCC 7.2 / glibc 2.29 family. This verifies the usable
ABI input, but does not establish that the GitHub archive is a cryptographic
original Ingenic release artifact.

With a prepared Klipper source checkout and an existing writable output
directory, build the host artifact offline:

```sh
docker run --rm --network none \
  --user "$(id -u):$(id -g)" \
  -v "$PWD/klipper:/source:ro" \
  -v "$PWD/out:/output:rw" \
  ender3-ke-klipper-build:f005 \
  build-x2000-chelper /source /output/c_helper.so
```

`build-x2000-chelper` uses the same `klippy/chelper` C source list and compiler
options as the selected Klipper source's `klippy/chelper/__init__.py`. The
result is a host artifact, not MCU firmware. Its static ABI validation is a
prerequisite for use with the stock X2000 userspace; no runtime validation is
part of this build procedure.

Do not run `flash`, `serialflash`, USB, serial-device, or other hardware
targets as part of this procedure. The recipe itself is build-only. The
documented packaged candidate produced from this source was separately
validated on the investigated reference F005 board by one controlled MCU flash,
an identify-only protocol check, and a passive Klippy configuration/finalize
test; arbitrary rebuilds are not thereby hardware-validated.
