# F005 MCU firmware switching

This document records the validated F005/GD32F303 firmware-return mechanism and
the design contract for a later controlled Stock <-> Fre3nder MCU switch.

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

Therefore a future symmetric Stock <-> Fre3nder switch must not be declared
complete until the Stock -> bootloader direction has also been validated on the
reference device.

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

The normal switching mechanism must not depend on RTS/DTR manipulation, baud
searching, USB DFU, CAN bootloaders, SWD, or a power-cycle-only entry path.

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
- do not continue with a host-slot switch;
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

It is a recovery convenience, not a requirement for the normal switching
architecture.

## Final Stock <-> Fre3nder switching model

The final user-facing operation should switch the X2000 host software and the
F005 MCU as one coordinated mode change.

It should not expose an independent "flash MCU" toggle during ordinary use.

The intended logical modes are:

```text
STOCK
  Stock X2000 host
  Stock F005 MCU

FRE3NDER
  Fre3nder X2000 host
  Fre3nder F005 MCU
```

A mixed host/MCU combination may occur temporarily during the controlled
transition, but it is not a normal operating mode.

## Common preflight

Before either direction, the switching tool should verify at minimum:

1. the requested target mode is explicit;
2. the target host slot/artifact is present and validated;
3. the target MCU image exists;
4. target MCU size and SHA-256 match the release manifest;
5. the expected current MCU/application identity is known;
6. no print is active;
7. heaters are not intentionally active;
8. exactly the expected Klipper process owns `/dev/ttyS1`;
9. the host recovery path remains available.

A version mismatch alone must never trigger an automatic cross-mode firmware
change.

## Fre3nder -> Stock

This direction is qualified on the reference device.

The intended sequence is:

```text
preflight Stock host target
-> verify preserved Stock MCU image
-> request FIRMWARE_RESTART from Fre3nder Klipper
-> stop/release Fre3nder Klipper
-> verify /dev/ttyS1 is free
-> Creality bootloader handshake
-> verify expected Fre3nder source identity
-> exactly one Stock MCU flash
-> require successful mcu_util completion/app_run
-> select Stock host slot
-> reboot immediately into Stock
-> verify Stock Klipper and Stock MCU
-> require Printer is ready
```

The MCU flash should precede the host-slot selector write.

Reason: if the MCU flash fails, the host remains on the currently selected and
recoverable Fre3nder side and no second persistent transition is started.

If the MCU flash succeeds but the later host selector operation fails, SSH and
the current host remain available for recovery even though Klipper may no
longer match the newly flashed MCU.

## Stock -> Fre3nder

The intended symmetric sequence is:

```text
preflight Fre3nder host target
-> verify Fre3nder MCU release image
-> enter Creality bootloader from Stock Klipper
-> stop/release Stock Klipper
-> verify /dev/ttyS1 is free
-> Creality bootloader handshake
-> verify expected Stock source identity
-> exactly one Fre3nder MCU flash
-> require successful mcu_util completion/app_run
-> select Fre3nder host slot
-> reboot immediately into Fre3nder
-> verify Fre3nder Klipper and Fre3nder MCU identity
```

The original historical Stock -> Mainline flash proves that the Stock image can
be replaced through the Creality bootloader, but the exact
Stock-`FIRMWARE_RESTART` -> bootloader entry used by this symmetric design still
requires one practical qualification before this complete sequence may be
marked validated.

Until then, this direction is a design target rather than a qualified
production switching procedure.

## Host A/B relationship

On the investigated system the current conceptual pairing is:

```text
Stock A:
  p5 kernel
  p7 RootFS
  Stock F005 MCU

Fre3nder B:
  p6 kernel
  p8 RootFS
  Fre3nder F005 MCU
```

The MCU itself is not A/B. Only one application image is active behind the
preserved Creality bootloader.

Therefore host A/B switching alone is insufficient for a complete mode change.
The selected host and the flashed MCU application must be treated as one
logical target state.

The existing external Ingenic USB/RAM-U-Boot p1 recovery remains a separate
host-side recovery boundary and must not be conflated with MCU recovery.

## Stock updater policy

During development the Stock MCU updater may need to remain disabled so that a
Stock host can intentionally run while a Fre3nder MCU is being investigated.

That is a development exception, not necessarily the final mode policy.

For the final product design:

- an explicit Stock mode should contain a Stock MCU before normal Stock startup;
- an explicit Fre3nder mode should contain a Fre3nder MCU before normal
  Fre3nder startup;
- the mode-switch tool, not Stock version-comparison heuristics, should own the
  deliberate cross-mode firmware transition.

The Stock updater's "version differs -> update" behavior must not be reused as
the Fre3nder mode-selection mechanism.

## Future switching tool

A later implementation should be a small bounded state machine rather than a
general firmware manager.

Conceptually:

```text
preflight
-> enter bootloader
-> identify source
-> verify target
-> flash exactly once
-> switch host target
-> reboot
-> validate target
```

Useful properties:

- explicit `stock` or `fre3nder` target;
- dry-run/preflight mode;
- exact source and target identities;
- exact image SHA-256 from a release manifest;
- no directory scanning for an arbitrary firmware file;
- no automatic firmware retry;
- no automatic fallback flash;
- no unrelated printer hardware actions;
- clear persistent or operator-visible result reporting.

The normal tool should use the already validated stable interfaces rather than
embedding development-specific USB paths or device-specific identifiers.

## Remaining qualification before implementation

Before claiming a complete symmetric Stock <-> Fre3nder production switch:

1. qualify Stock Klipper `FIRMWARE_RESTART` -> Creality bootloader entry on the
   reference device without writing firmware;
2. retain the proven Fre3nder -> Stock procedure as a regression test;
3. implement the switching state machine against explicit release manifests;
4. integrate it with the host A/B selector;
5. validate one complete Stock -> Fre3nder -> Stock roundtrip.

No additional MCU recovery mechanism is required merely to begin that work.
