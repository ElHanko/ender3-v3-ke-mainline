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
-> one project-initiated mcu_util firmware-update invocation
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

## Stock updater decision evidence

Offline static analysis of the investigated reference Stock RootFS artifacts
established the behavior of the unchanged updater chain. `S13mcu_update` is
byte-identical in the inspected p7 and p8 copies, with SHA-256:

```text
ad4fe0013af6033664ea230f86a746dfe149c742d5abb453d826ba110a69f151
```

The inspected `mcu_util` copies are also byte-identical:

```text
size:   11096 bytes
SHA-256:
d984f1a51ff9149a8971f9a3d3d0db13f81772c8122dd24b53b4d160f223cd03

format:
ELF32 little-endian MIPS32r2, dynamically linked, stripped
```

These are properties of the inspected reference Stock artifacts, not universal
constants for every Ender-3 V3 KE firmware revision.

For `model=F005` and `board=NEBULA V1.0.0.1`, the script selects `/dev/ttyS1`
and `/usr/share/klipper/fw/F005`. It first runs an `mcu_util` handshake and
version query. It then uses the hardware part of the reported identity as a
filename prefix and requires exactly one matching image in that directory.

For the currently qualified Fre3nder/Mainline identity and preserved Stock
image, the relevant values are:

```text
reported:              mcu0_001_G32-mcu0_004_000
hardware prefix:       mcu0_001_G32
installed version:     004
Stock image:           mcu0_001_G32-mcu0_005_000.bin
target version:        005
decision:              005 -ne 004 -> update
```

The comparison is numeric inequality, not an upgrade/downgrade ordering. Thus
`004 -> 005` and `006 -> 005` both request an update, while `005 -> 005` does
not. The logic cannot distinguish a different application from an outdated
Stock application when both report the same hardware prefix and version field.
It does not use a release manifest or SHA-256 to select or verify the image.

This result is conditional on the Creality bootloader being reachable and the
version query returning the known identity. Neither `S13mcu_update` nor
`mcu_util` resets a running MCU application into the bootloader. Therefore the
static analysis establishes the Stock version/image decision but does not yet
qualify the bootloader handoff or a complete automatic Fre3nder-to-Stock
roundtrip.

The inspected `mcu_util` opens the supplied image and uses its length for the
protocol. Host-side, it does not verify SHA-256, a release manifest, expected
application identity, image hardware identity, or upgrade/downgrade direction.
Its `--ignore-hw-ver` and `--ignore-fw-ver` options do not establish that such
host-side protections are normally active.

Static analysis also found bounded internal retries. For some data-confirmation
or missing-ACK failures, `mcu_util` rewinds the image to offset zero and may
restart the complete update workflow, for up to three complete transfer attempts
within one process. Other protocol responses have bounded retries; an explicit
`flash fail` terminates with an error. One process invocation must therefore not
be described as a general guarantee of exactly one complete transfer attempt.

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

## Fre3nder-to-Stock host-reboot handoff analysis

The preferred return path has a separate host-reboot boundary after the
qualified Mainline/Fre3nder `FIRMWARE_RESTART` transition. The following is
**OFFLINE CONFIRMED** for the investigated reference Stock artifacts and the
current Fre3nder host artifacts:

- Stock `rcK` calls init scripts in reverse order with `stop`.
  `S13mcu_update` has no effective MCU `stop` path; `S55klipper_service stop`
  stops Klippy; and `S57klipper_mcu` concerns the Linux Host-MCU, not the F005.
  No inspected Stock init or module-driver script explicitly resets the F005,
  starts its application, or switches its supply.
- The current Fre3nder BusyBox reboot reaches the X2000 machine restart path:

  ```text
  _machine_restart
  -> jz_wdt_restart()
  -> internal X2000 watchdog reset
  ```

  No F005-specific GPIO or regulator access was found in that path. The current
  Fre3nder DTS describes the F005 only through UART1 GPC23/GPC24; it has no
  documented F005 reset GPIO or F005 regulator. The inspected public
  NebulaOS/OpenKE DTS reference likewise describes only these UART pins for this
  path.
- The A/B helper changes only the host selector. It does not access the F005 or
  `/dev/ttyS1`.

Thus no software component is known to intentionally disturb the F005 between:

```text
FIRMWARE_RESTART
-> bootloader verification
-> Stock-A selector
-> host reboot
```

In particular, no known component issues `app_run`, sends another F005 software
reset, actuates a documented F005 reset GPIO, or disables a documented F005
regulator in that interval.

This is not proof that the F005 is electrically independent of an X2000 reset.
It remains **UNKNOWN / REQUIRES QUALIFICATION** whether an undocumented or
electrically coupled reset line exists, whether the X2000 reset or its
BootROM/SPL/U-Boot path indirectly resets the F005, or whether the F005 supply
changes during that sequence.

No reliable dump of the retained 12 KiB Creality F005 bootloader at
`0x08000000..0x08002fff` is available. Its automatic application-start
behavior, timeout, persistent command-wait behavior, and any effect of a prior
handshake on that state are therefore also **UNKNOWN / REQUIRES
QUALIFICATION**. The historical "early bootloader window" does not establish a
specific timeout or automatic application start.

### External NebulaOS on-device cross-check

An independent external reference supports the software-side finding above.
[`coreflake1/NebulaOS-firmware`](https://github.com/coreflake1/NebulaOS-firmware/commit/07d1459f71ef18545dadf5f5f4dcb8093b9853bb) at commit
`07d1459f71ef18545dadf5f5f4dcb8093b9853bb` documents the Stock F005 link as
UART1 (`GPC23/GPC24`, `/dev/ttyS1`) and records searches of Stock
`S13mcu_update`/`mcu_util` for reset, GPIO, boot-select, and power-control
signals. `docs/PRINTER_MAINBOARD_PRECONNECTION_CHECKLIST.md` and
`docs/KNOWN_GOOD_PRODUCTION_BASELINE.md` classify the result as no software
control signal identified; the accompanying
`scripts/build/overlay/etc/init.d/S95mcu-boot-recovery` is a bounded one-shot
mitigation, not evidence of a hidden reset or power API.

The same NebulaOS reference records real F005 observations in which a
firmware-reported `shutdown` state was present after particular X2000 host
reboots and required a later `FIRMWARE_RESTART`. NebulaOS did not determine
whether that state persisted through the reboot or arose during the reboot
sequence itself. It classifies the shutdown as operationally
mitigated while leaving its trigger unresolved. This is **EXTERNAL ON-DEVICE
EVIDENCE / STRONGLY SUPPORTING**, not a qualification on this project's
reference device: an X2000 host reboot is not inherently equivalent to an MCU
power-cycle or guaranteed MCU reset, but the electrical reset/supply coupling
and the behavior of this specific device remain **UNKNOWN / REQUIRES
QUALIFICATION**.

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

### Required: no second updater invocation after a flash failure

Fre3nder orchestration must start at most one deliberate updater invocation for
a transition. If that invocation fails:

- do not start a second updater invocation automatically;
- do not start another updater invocation or otherwise deliberately initiate another erase/write;
- do not guess whether the application is valid;
- do not continue with normal Fre3nder printer operation;
- keep the failure visible to the operator.

The validated recovery procedure used one project-initiated updater invocation
and did not start an external second attempt. That evidence does not prove that
the tool performed exactly one complete internal transfer.

This orchestration-level rule is distinct from tool-internal behavior. The
inspected Stock `mcu_util` has bounded internal retries and can restart a full
transfer within the same process. It therefore cannot guarantee tool-level
exact-once behavior. Before implementing the final Fre3nder updater, the project
must decide whether that bounded Stock-tool behavior is acceptable for the
qualified transition or whether a controllable project-owned/open updater is
required. This decision does not itself require a new updater implementation.

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
start normal printer operation. After a failed updater invocation, Fre3nder must
fail closed and must not start another invocation automatically.

A version number alone must never choose the target image. There must be no
directory scan for an arbitrary firmware image, orchestration-level retry after
a failed invocation, automatic fallback flash, or unrelated printer action. If
a controlled write is eventually implemented, it must pass the exact manifest
image to one deliberate updater invocation and validate the result before
Upstream Klipper starts normally. Any tool-internal retry behavior must be an
explicitly accepted property, not be mislabeled as exact-once.

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

**PREFERRED RELEASE TARGET / DECISION ANALYZED, HANDOFF REQUIRES ONE
NO-WRITE QUALIFICATION:**

```text
Fre3nder B + Fre3nder MCU
-> Fre3nder leaves the F005 in the retained Creality bootloader
-> select and boot unchanged Stock A
-> unchanged Stock S13mcu_update queries the known 004 identity
-> 004 != 005 selects Stock's own F005 image
-> Stock's existing updater machinery can restore the Stock MCU
-> Stock Klipper becomes operational
```

Offline analysis proves the version/image decision for the currently known
`mcu0_001_G32-mcu0_004_000` Fre3nder/Mainline identity: if the bootloader is
reachable and reports that identity, the inspected Stock updater selects
`mcu0_001_G32-mcu0_005_000.bin` because `005 -ne 004`. This does not establish
recognition of every Fre3nder identity or recovery from every foreign MCU state.

The handoff status is:

```text
Fre3nder FIRMWARE_RESTART -> Creality bootloader
    QUALIFIED ON DEVICE

Stock decision 004 != 005 -> Stock image
    OFFLINE CONFIRMED

No known software action disturbs the MCU between
bootloader verification and X2000 reboot
    OFFLINE CONFIRMED

No known software-controlled F005 reset/power path
    OFFLINE CONFIRMED
    EXTERNAL ON-DEVICE SUPPORT: NebulaOS

F005 may be found in a firmware-reported non-clean state after X2000 host reboot
    EXTERNAL ON-DEVICE EVIDENCE FROM NEBULAOS
    RESET/POWER CAUSE UNRESOLVED

MCU still being in the bootloader when Stock S13 runs
after the real X2000 reboot
    UNKNOWN / REQUIRES QUALIFICATION
```

The remaining handoff uncertainty is whether the F005 still answers the
retained Creality bootloader protocol and reports the known Fre3nder identity
when unchanged Stock reaches the `S13mcu_update` point after the X2000 reboot.
NebulaOS independently supports that no software-controlled F005 reset/power
path has been identified. Its on-device reboot observations do not resolve the
electrical reset/power question: the MCU was found in a firmware-reported
shutdown state after some host reboots, but NebulaOS did not establish whether
that state survived the reboot or arose during it.
The dominant remaining question is whether the retained Creality bootloader
remains responsive long enough for Stock `S13mcu_update` to reach it after the X2000 reboot.
This one observation covers possible reset/power effects and a possible bootloader timeout/application
start; they need not be distinguished separately if the end-to-end handoff is
reproducible.

### Bounded later NO-WRITE qualification

The smallest relevant later handoff test is:

```text
already-running Fre3nder/Mainline MCU
-> FIRMWARE_RESTART
-> verify Creality bootloader and known 004 identity
-> select Stock A
-> X2000 reboot
-> at the normal early Stock updater point:
     handshake only
     version query only
-> verify 004 identity is still visible
-> no firmware update
```

After the NebulaOS cross-check, this test primarily answers whether the
retained Creality bootloader remains responsive long enough for Stock
`S13mcu_update` to reach it after the X2000 reboot. A successful result need not
separately identify the underlying reset, power, or bootloader-timing mechanism.

Unchanged normal `S13mcu_update` must not simply run for this test: after a
successful handshake, `004 != 005` would select the Stock firmware write. A
temporary test-only instrumentation must technically prevent that update call
and allow only `mcu_util -c` and `mcu_util -g`. It is not release architecture,
does not add Stock responsibility, and is not a permanent Stock modification.
`NO-WRITE` refers to the handoff test itself; it assumes a Fre3nder/Mainline MCU
application is already running at the beginning. Stock A remains unchanged for
the release path.

## Qualified evidence and its role

The following remains **QUALIFIED ON DEVICE**: a running Mainline/Fre3nder F005
application was reset into the retained Creality bootloader, the preserved
original Stock image was verified, one project-initiated `mcu_util` update
invocation succeeded, and Stock Klipper then reached `Printer is ready`.
No external second update invocation was started. The later static finding that
`mcu_util` contains internal retry paths does not show that such a retry occurred
in that successful run and does not invalidate the qualified result.

This is project-controlled Mainline/Fre3nder -> Stock recovery and regression
evidence. It remains important during development, but it is not the required
final release switching path and does not establish the Stock-owned return path
above.

The existing external Ingenic USB/RAM-U-Boot p1 recovery remains a separate
host-side recovery boundary and must not be conflated with MCU recovery.

## Remaining analysis and qualification

Before claiming complete Stock/Fre3nder dual-mode operation:

1. **Completed offline:** analyze the untouched Stock updater decision,
   including `S13mcu_update` and `mcu_util`, against the known Fre3nder MCU
   identity;
2. **Completed offline:** analyze the X2000/F005 software reset path for the
   Fre3nder-to-Stock handoff;
3. qualify the Fre3nder B -> Stock A bootloader handoff with one bounded
   no-firmware-write hardware test;
4. analyze, implement, and qualify the Fre3nder-owned Stock-MCU -> Fre3nder-MCU
   transition; and
5. qualify a complete Stock -> Fre3nder -> Stock roundtrip.

No additional MCU recovery mechanism is required merely to begin that work.
