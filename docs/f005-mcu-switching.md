# F005 MCU firmware switching

This document records the validated F005/GD32F303 firmware-return mechanism and
the target contract for later Stock/Fre3nder dual-mode operation.

It is a design and evidence document. It does not itself authorize an MCU flash.

## Current evidence

The investigated reference board uses the Creality serial bootloader below the
application image.

The validated memory contract is:

```text
0x08000000..0x08002fff  Creality bootloader, 12 KiB
0x08003000..            MCU application
```

The Fre3nder/Mainline application must not overwrite the first 12 KiB.

On 2026-08-27 the following no-write transition was validated on-device:

```text
running Mainline F005 application
-> Klipper FIRMWARE_RESTART
-> normal MCU "reset" command
-> NVIC_SystemReset()
-> Creality serial bootloader
-> mcu_util handshake
-> mcu_util version query
-> mcu_util app_start
-> unchanged Mainline application
```

The bootloader reported the Mainline application identity:

```text
mcu0_001_G32-mcu0_004_000
```

The complete Mainline-to-Stock return was then validated separately:

```text
running Mainline F005 application
-> FIRMWARE_RESTART
-> Creality serial bootloader
-> verify current application identity
-> verify preserved Stock image
-> exactly one mcu_util firmware write
-> app_run
-> Stock Klipper startup
-> original Stock MCU identified
-> Printer is ready
```

The preserved Stock image used for that validation was:

```text
path:
  /usr/share/klipper/fw/F005/mcu0_001_G32-mcu0_005_000.bin

size:
  31436 bytes

SHA-256:
  0b8ecfad8e65e90a3cfc08dd8534dd568e341c160897e6050eadcbf1eb917d4a
```

After restoration Stock Klipper loaded the original 116-command MCU firmware
and reached `Printer is ready`.

Therefore:

**MAINLINE/FRE3NDER F005 MCU -> ORIGINAL STOCK F005 MCU FIRMWARE RETURN:
QUALIFIED ON DEVICE.**

## Important qualification boundary

The original Stock -> Mainline first flash did not use the later
`FIRMWARE_RESTART` switching sequence. It used the Creality bootloader's early
startup window through a temporary one-shot Stock-host arrangement.

External implementations indicate that Stock Klipper `FIRMWARE_RESTART` can be
used to reach the same Creality bootloader, but that exact Stock-host ->
bootloader transition has not yet been practically qualified by this project.

Therefore the Stock-MCU -> Creality-bootloader path from a started Fre3nder host
remains to be analyzed and qualified; it is not established by the historical
first flash.

## Fre3nder MCU requirements

A production Fre3nder F005 MCU build must preserve the following properties.

### Required: preserve the Creality bootloader

The application must continue to start at:

```text
0x08003000
```

The first 12 KiB at `0x08000000..0x08002fff` belong to the existing Creality
bootloader and must never be part of the Fre3nder application image.

A future linker, packaging, or flash-layout change must not silently move the
application below `0x08003000`.

### Required: retain the normal Klipper reset command

The validated return path depends on the ordinary Klipper MCU `reset` command
performing a Cortex-M system reset.

The Fre3nder MCU must retain a reset implementation equivalent to:

```text
reset command
-> NVIC_SystemReset()
```

It must remain usable from Klipper's normal firmware-restart path, including
the shutdown-safe behavior provided by Klipper's reset command.

### Required: use command restart from the host

The Fre3nder Klipper configuration should retain:

```ini
[mcu]
serial: /dev/ttyS1
baud: 230400
restart_method: command
```

The qualified project-controlled Mainline -> Stock return does not depend on
RTS/DTR manipulation, baud searching, USB DFU, CAN bootloaders, SWD, or a
power-cycle-only entry path. It does not determine the still-unanalyzed
Stock-MCU -> bootloader entry from a started Fre3nder host.

### Required: preserve explicit F005 packaging metadata

A Fre3nder MCU image must continue to carry valid F005 application metadata and
CRC/length fields expected by the Creality bootloader and updater protocol.

The application identity must be distinguishable from the Stock identity.

The current validated Mainline candidate uses:

```text
mcu0_001_G32-mcu0_004_000
```

and the preserved Stock application uses:

```text
mcu0_001_G32-mcu0_005_000
```

These concrete version numbers are evidence from the current candidate, not a
permanent release-numbering contract.

Future switching logic must use an explicit release manifest and expected
identity rather than assuming that a numerically higher MCU version is always
the desired target.

### Required: no automatic retry after a flash failure

A firmware write must be attempted exactly once.

If `mcu_util -u -f` fails:

- do not retry automatically;
- do not issue another erase/write;
- do not guess whether the application is valid;
- do not continue with normal Fre3nder printer operation;
- keep the failure visible to the operator.

The validated recovery procedure deliberately used this fail-closed behavior.

### Recommended: serial bootloader request as an additional path

The current Mainline candidate does not enable Klipper's generic
`HAVE_BOOTLOADER_REQUEST` path for GD32F303 and does not contain a
`STM32_FLASH_START_3000` branch in `bootloader_request()`.

This did not prevent the validated return to Stock because the normal Klipper
`reset` command was sufficient.

A later Fre3nder MCU may add a 12 KiB bootloader-request implementation:

```text
serial bootloader request
-> NVIC_SystemReset()
-> Creality bootloader
```

That would provide an additional convenient bootloader-entry mechanism when a
raw serial connection to the Fre3nder application is available.

It is a recovery convenience, not a determination of the still-unanalyzed
release transition.

## Stock/Fre3nder dual-mode target

**DESIGN TARGET — not yet fully qualified.** The X2000 host uses A/B dualboot,
while the F005 remains a shared, non-A/B resource with exactly one active
application behind the retained Creality bootloader.

```text
STOCK
  unchanged Creality Stock host (Stock A: p5 kernel, p7 RootFS)
  Stock Klipper
  Stock F005 MCU

FRE3NDER
  project-owned Fre3nder host (Fre3nder B: p6 kernel, p8 RootFS)
  Upstream Klipper
  Fre3nder/Mainline F005 MCU
```

A mixed host/MCU combination may occur during a controlled transition, but is
not a normal operating state. Stock A is the preserved vendor fallback domain;
Fre3nder B is the project-owned integration domain.

The normal Fre3nder release must not patch or extend the Stock RootFS. In
particular, it must not require Fre3nder init scripts, Stock-Klipper changes,
changes to `S13mcu_update` or `mcu_util`, a Fre3nder mode switcher in Stock A,
or other Fre3nder files or hooks in p7. This is a design target, not evidence
that every return path has already been qualified.

## Fre3nder-owned MCU lifecycle

Fre3nder B is responsible for establishing the MCU state required before
Upstream Klipper takes normal printer ownership. A later release implementation
must use an explicit Fre3nder MCU release manifest with the expected identity,
size, and SHA-256. It must identify the installed application and apply this
fail-closed policy:

```text
known expected Fre3nder MCU
  -> no flash required

known supported Stock MCU
  -> controlled transition may be allowed

unknown MCU identity
  -> fail closed
  -> do not guess or flash
  -> do not start normal printer operation
```

### Fre3nder-side safety contract

Before Fre3nder initiates an MCU write, it must verify all of the following:

1. the current MCU/application identity is known and matches an expected
   Fre3nder or supported Stock source identity;
2. the exact target image matches the Fre3nder release manifest, including its
   expected identity, size, and SHA-256;
3. no print is active and heaters are not intentionally active;
4. `/dev/ttyS1` is controlled and free of unexpected owners before the
   bootloader or flash tool takes it over; and
5. the qualified host-recovery path remains available.

An unknown source identity fails closed: Fre3nder must not guess, flash, or
start normal printer operation. A failed write must not be retried
automatically.

A version number alone must never choose the target image. There must be no
directory scan for an arbitrary firmware image, automatic retry after a failed
write, automatic fallback flash, or unrelated printer action. If a controlled
write is eventually implemented, it must use the exact manifest image once and
validate the result before Upstream Klipper starts normally.

**TO BE ANALYZED:** the exact mechanism for a Fre3nder host started with a
known Stock MCU to enter the Creality bootloader, verify the source, install the
exact Fre3nder image once, and validate it. The historical Stock -> Mainline
first flash does not by itself qualify that release path.

## Target transitions

### Stock -> Fre3nder

**DESIGN TARGET / TO BE QUALIFIED:**

```text
Stock A + Stock MCU
-> select and boot Fre3nder B
-> Fre3nder establishes and validates the expected Fre3nder MCU state
-> Upstream Klipper becomes operational
```

The transition belongs to Fre3nder B, not to a Stock-side Fre3nder extension.

### Fre3nder -> Stock

**PREFERRED RELEASE TARGET / TO BE ANALYZED AND QUALIFIED:**

```text
Fre3nder B + Fre3nder MCU
-> select and boot unchanged Stock A
-> Stock's existing updater machinery should restore or ensure the Stock MCU
-> Stock Klipper becomes operational
```

The project makes no current claim that Stock `S13mcu_update` or `mcu_util`
recognizes every Fre3nder MCU, performs this restore automatically, or can
recover from every foreign MCU state. Whether the untouched Stock updater
provides this return path is the next analysis subject.

## Qualified evidence and its role

The following remains **QUALIFIED ON DEVICE**: a running Mainline/Fre3nder F005
application was reset into the retained Creality bootloader, the preserved
original Stock image was verified and written exactly once, and Stock Klipper
then reached `Printer is ready`.

This is project-controlled Mainline/Fre3nder -> Stock recovery and regression
evidence. It remains important during development, but it is not the required
final release switching path and does not establish the Stock-owned return path
above.

The existing external Ingenic USB/RAM-U-Boot p1 recovery remains a separate
host-side recovery boundary and must not be conflated with MCU recovery.

## Remaining analysis and qualification

Before claiming complete Stock/Fre3nder dual-mode operation:

1. analyze the untouched Stock updater chain, including `S13mcu_update` and
   `mcu_util`, against a known Fre3nder MCU without assuming its behavior;
2. analyze and qualify the Fre3nder-owned Stock-MCU -> Creality-bootloader
   transition without writing firmware first;
3. implement a bounded Fre3nder MCU lifecycle using explicit release manifests;
4. qualify Fre3nder B -> Stock A return through the untouched Stock path; and
5. qualify a complete Stock -> Fre3nder -> Stock roundtrip.

No additional MCU recovery mechanism is required merely to begin that work.
