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
recipe. It does not build firmware automatically. The container should be
run without network access for the compilation step, as shown above.

Do not run `flash`, `serialflash`, USB, serial-device, or other hardware
targets as part of this procedure. The output is a local build artifact only;
it is not ready to flash and has not been hardware-validated.
