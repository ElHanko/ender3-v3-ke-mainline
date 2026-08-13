# GD32F303/F005 mainline MCU port

This case study documents the offline port for the investigated Ender-3 V3 KE
reference system, specifically its F005 board with a GD32F303RET6 main MCU. It
is not a universal claim about every KE hardware revision or every GD32F303
board.

## Scope and result

The comparison and implementation use Klipper upstream commit
`0499b30374315f2a9f49fc12808527fc7d0f5cfa`. The result is a **SMALL MCU PORT**
whose productive change is limited to:

```text
src/stm32/Kconfig
src/stm32/Makefile
src/stm32/stm32f1.c
```

A complete `src/gd32/` backend is unnecessary for this F005 contract. The
required GPIO, ADC, serial, watchdog, generic timer, software-PWM and ARM
startup paths already exist in the STM32F1-compatible and generic upstream
paths. The GD32F303 executes the selected Cortex-M3 Thumb subset on its
Cortex-M4 core, and the relevant register blocks share the offsets used by the
existing STM32F1 code. No GD32 SDK library is required.

## Productive changes

### Kconfig target

The patch adds an explicit `GD32F303xE` target with MCU identity
`gd32f303xe`, 120 MHz clock, 8 MHz external reference, 64 KiB RAM, and the
validated 12 KiB bootloader layout. The application starts at `0x08003000` and
the only offered bootloader offset for this target is the 12 KiB choice.

Unvalidated USB, CAN, main-MCU SPI/I2C, hardware-PWM, and bootloader-request
capabilities are not enabled for this target. The target intentionally reuses
the STM32F1-compatible implementation marker without presenting unrelated
STM32F1 bootloader choices.

### Makefile binding

The target is compiled for the Cortex-M3 Thumb-compatible subset and selects
the existing `STM32F103xE` register header while retaining the external
Klipper identity `gd32f303xe`. This is a narrow compatibility binding; it does
not claim that the physical MCU is an STM32F103.

### Clock initialization

The GD32 branch in `stm32f1.c` implements the F005 120 MHz contract:

- 8 MHz HXTAL divided by two, multiplied by 30;
- the HD/xE PLLM extension bit 27;
- AHB at 120 MHz, APB1 divided by two, APB2 divided by two;
- ADC clock divided by six;
- high LDO setting;
- high-drive enable/ready and high-drive switch/ready handshakes.

Normal GPIO, ADC, UART, watchdog, timer and software-PWM operation stays in
the existing upstream paths.

### GD32 flash fix

The inherited STM32F1 assignment is deliberately skipped for GD32F303:

```c
FLASH->ACR = (2 << FLASH_ACR_LATENCY_Pos) | FLASH_ACR_PRFTBE;
```

GD32 FMC semantics differ: writing `WSCNT` alone does not enable wait states,
and the STM32 prefetch bit maps to a reserved GD32 bit. The official GD32F30x
120 MHz startup leaves the FMC state at reset for the relevant image range.
The patch therefore adds no GD32 FMC or prefetch emulation.

## Conservative flash boundary

The physical GD32F303RET6 has 512 KiB of Flash at
`0x08000000..0x0807ffff`. The first mainline port deliberately exposes only
the documented first-256-KiB region:

```text
application:   0x08003000..0x0803ffff
CONFIG_FLASH_SIZE: 0x3d000
linker end:    0x08040000 (exclusive)
```

The 12 KiB bootloader occupies `0x08000000..0x08002fff`. The `0x3d000` value
is therefore a linker-visible application limit, not a claim that the chip has
only 256 KiB. The upper 256 KiB remains intentionally unused until a separate
GD32 FMC wait-state configuration for that range is documented and validated.

The final offline build starts at `0x08003000` and ends its Flash load data at
`0x08008638`. It leaves `0x379c8` bytes before `0x08040000`.

## Offline validation

The following builds passed in the isolated Debian 13 Docker environment:

1. GD32F303/F005 build;
2. representative STM32F103 regression build;
3. a second clean GD32F303/F005 build.

The GD32 ELF and vector table start at `0x08003000`; all Flash load data stays
below `0x08040000`, and RAM remains within `0x20000000..0x2000ffff`. The GD32
machine code contains no `FMC_WS`/`FMC_WSEN` access. The STM32F103 regression
still contains its existing `FLASH->ACR` assignment. The build image uses no
host ARM-toolchain installation and no hardware or device access.

These are static build results only:

```text
OFFLINE MCU PORT VALIDATION COMPLETE
NOT READY TO FLASH
```

Build instructions and the exact source patch are published separately in
[`build/klipper-f005/README.md`](../build/klipper-f005/README.md) and
[`patches/klipper/0001-gd32f303-f005-mainline.patch`](../patches/klipper/0001-gd32f303-f005-mainline.patch).

No hardware validation has been performed. Gate 1 / Point of Return remains
unsatisfied, and persistent hardware work remains WARNING / RED ZONE.

## References

The hardware and startup conclusions use the following primary sources:

- GigaDevice, *GD32F30x User Manual*, Rev. 3.4; official download catalogue:
  [GD32F30x downloads](https://www.gd32mcu.com/en/download/0?kw=GD32F30x).
- GigaDevice, *GD32F303xx Datasheet*: official download-catalogue entry 3.3;
  the served PDF identifies itself as Rev. 1.4. The catalogue is the provenance
  point for the revision discrepancy.
- GigaDevice, *GD32F30x Firmware Library*, version 3.0.3; official package from
  the same [GD32F30x downloads](https://www.gd32mcu.com/en/download/0?kw=GD32F30x)
  catalogue.
- Klipper upstream, commit
  `0499b30374315f2a9f49fc12808527fc7d0f5cfa`, the implementation comparison
  basis and patch parent.

No manufacturer PDF or firmware-library package is redistributed here.
