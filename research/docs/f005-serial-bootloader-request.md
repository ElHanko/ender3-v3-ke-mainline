# F005 serial bootloader request research

## 1. Starting problem

This report covers the investigated F005/GD32F303RET6 reference and Klipper
upstream commit `0499b30374315f2a9f49fc12808527fc7d0f5cfa`. It implements and
verifies only the missing firmware-side serial bootloader request. It does not
change the qualified Fre3nder `2026.1` firmware, configuration, build chain, or
MCU artifact.

The productive F005 port adds `STM32_FLASH_START_3000`, but deliberately changes
the upstream STM32 capability selection to:

```text
select HAVE_BOOTLOADER_REQUEST if !MACH_GD32F303
```

Consequently `CONFIG_HAVE_BOOTLOADER_REQUEST=0` in the qualified F005 build.
Even if only that gate were changed, the pinned
`src/stm32/stm32f1.c::bootloader_request()` handles only the existing 2 KiB and
8 KiB cases. A 12 KiB selection falls through without resetting. The prior
claim that the current Fre3nder F005 build already supports the physical-serial
request is therefore **WIDERLEGT**.

This mission adds the missing behavior as a separate GPLv3 Research patch:

```text
F005 SERIAL BOOTLOADER REQUEST: OFFLINE IMPLEMENTED
REAL HARDWARE EFFECT: REQUIRES QUALIFICATION
```

## 2. Pinned upstream mechanism

### Recognition

`src/generic/serial_irq.c` stores received UART bytes in a 192-byte buffer.
`console_task()` passes that buffer to `command_find_block()`. When parsing
reports an invalid protocol block (`ret < 0`), exactly 32 bytes are to be
discarded, and the bytes exactly match the following block, Klipper calls the
platform `bootloader_request()`:

```text
20 1c 20 52 65 71 75 65 73 74 20 53 65 72 69 61
6c 20 42 6f 6f 74 6c 6f 61 64 65 72 21 21 20 7e
```

That is:

```text
<SPACE><FS><SPACE>Request Serial Bootloader!!<SPACE>~
```

The final `0x7e` is Klipper's normal sync byte. The block is deliberately not a
valid MCU-protocol message. `docs/Bootloader_Entry.md` recommends an additional
leading sync byte when earlier traffic may otherwise share the same receive
block. The matcher itself compares the exact 32-byte block shown above.

### Compile-time conditions

For the physical-UART path to exist in the resulting F005 firmware:

1. the target must build `src/generic/serial_irq.c` through `CONFIG_SERIAL=y`;
2. `CONFIG_HAVE_BOOTLOADER_REQUEST` must be true;
3. the board implementation must provide `bootloader_request()`; and
4. that function must have defined behavior for the selected bootloader layout.

The F005 configuration already satisfies the serial side with USART2 and
230400 baud. The Research patch supplies conditions 2 and 4. The existing
STM32F1-compatible implementation supplies condition 3.

### Offset and clone comparison

The pinned upstream STM32 Kconfig has no 12 KiB / `0x3000` choice. Its STM32F1
and N32G45x clone targets offer other established offsets, while
`stm32f1.c::bootloader_request()` has special behavior only for the 2 KiB HID
and 8 KiB stm32duino layouts. No pinned upstream clone target supplies an
equivalent 12 KiB reset branch.

The public Creality Klipper repository at commit
`a63fb1a71672b91b505e0bda68fae2ede49f1168` contains 12 KiB selections in its
STM32 and separate GD32 Kconfig trees. In the inspected GD32 path, however,
`GD32_SELECT` does not select its serial-bootloader side-channel capability and
the GD32 platform files do not implement `bootloader_request()`. This is useful
layout correspondence, not an implementation basis for the new path.

NebulaOS-klipper-mcu commit
`2c9bab5be07deef4c8df6d7db3b614d748a18065` independently adds a 12 KiB
STM32F1-compatible branch that performs a plain system reset. That is
**EXTERNAL SOURCE BEHAVIOR** under GPLv3. Fre3nder's small behavior change was
written against its own pinned upstream and existing port; the coincident
conditional and reset primitive are the smallest expressions of the shared
Klipper Kconfig/CMSIS interfaces.

### Action after recognition

There is no acknowledgement of the physical-serial request. `console_task()`
calls `bootloader_request()` directly. The STM32F1 implementation first calls
`try_request_canboot()`. That generic helper inspects the vectors at
`CONFIG_FLASH_BOOT_ADDRESS` for the Katapult signature and, when present,
writes Katapult's request signature before resetting. If that signature does
not match, it returns to the platform function.

The new 12 KiB branch then calls `NVIC_SystemReset()`. It does not jump directly
to `0x08000000` or `0x08003000`, and it does not write a Creality-specific magic
value. The Cortex-M reset makes the retained bootloader at the boot flash base
responsible for deciding what happens next. This is the same reset primitive
used by Klipper's ordinary ARM `reset` command, whose F005 behavior was already
qualified separately. That prior result supports the design but does not
qualify this new parser-triggered route.

### Shutdown behavior

The physical-serial block is not a normal declared MCU command and has no
`HF_IN_SHUTDOWN` flag. That flag is not needed for this path: the scheduler
continues to run tasks after shutdown, UART receive wakes tasks, and
`console_task()` checks the special invalid block independently of normal
command dispatch. Source behavior therefore indicates that the exact request
can reach `bootloader_request()` while Klipper is in its shutdown state. This
is **SOURCE BEHAVIOR ONLY** until tested on the reference MCU.

## 3. F005 flash layout

The following layout is **OFFLINE CONFIRMED** for the investigated F005 target:

```text
physical Flash base:       0x08000000
retained bootloader:       0x08000000..0x08002fff
bootloader size:           0x3000 = 12 KiB
application start:         0x08003000
qualified application end: below 0x08040000
linker application size:   0x3d000
```

The evidence is cumulative:

- the project F005 Kconfig exposes only `STM32_FLASH_START_3000` for
  `MACH_GD32F303` and derives `FLASH_APPLICATION_ADDRESS=0x08003000`;
- the productive config resolves that exact selection and address;
- the generic ARM linker locates `.vector_table` first at the application
  address;
- the retained Stock F005 application begins with stack pointer `0x20010000`
  and Thumb reset vector `0x080033e1`, and carries `mcu0_005_000` at relative
  offset `+0x200`;
- the qualified Fre3nder artifact has `VectorTable=0x08003000`, a Thumb reset
  handler inside the application, and validated F005 metadata at `+0x200`;
- the separately authorized on-device reset, bootloader handshake, identity,
  application start, and firmware switching results establish that a Creality
  bootloader is retained below that application.

No public dump of the bootloader's complete 12 KiB is available. Its internal
timeout, no-host behavior, error recovery, and application-selection logic
remain **BINARY CORRESPONDENCE UNKNOWN / REQUIRES QUALIFICATION**. The confirmed
layout does not claim those unknown behaviors.

## 4. Research implementation

[`research/patches/klipper/f005-serial-bootloader-request.patch`](../patches/klipper/f005-serial-bootloader-request.patch)
applies after the productive F005 port patch to the pinned upstream commit. It
makes only two small Klipper source changes:

1. restore the upstream STM32 `select HAVE_BOOTLOADER_REQUEST` for the now
   sufficiently implemented GD32F303 target; and
2. add a `CONFIG_STM32_FLASH_START_3000` branch in
   `stm32f1.c::bootloader_request()` that calls `NVIC_SystemReset()`.

This is a small generic extension of the existing STM32F1 offset dispatch. The
12 KiB Kconfig choice is currently exposed only for `MACH_GD32F303`, so no other
target gains that selection. There is no Fre3nder runtime include, no vendor
component, no direct vector jump, no new host command, and no production-to-
Research dependency.

The patch modifies GPLv3 Klipper source and is itself GPLv3 material. Its exact
comparison basis and prerequisite patch are recorded in its header. The design
was compared with the independently audited NebulaOS implementation recorded in
[`f005-open-mcu-flasher.md`](f005-open-mcu-flasher.md), but no NebulaOS source
text was copied. The reset choice also follows the pinned Klipper source and
Fre3nder's already qualified ordinary `command_reset()` behavior.

[`research/tests/test-f005-serial-bootloader-request`](../tests/test-f005-serial-bootloader-request)
exports the exact pinned commit into a temporary directory, applies the
productive F005 patch and then this Research patch, verifies the source matcher
and reset branch, rejects an inconsistent application address in its config
gate, resolves Kconfig, and requires the expected request and layout defines.
It performs no serial or device access.

## 5. Offline tests

The following checks passed on 2026-08-30. `<project-root>` and `<workdir>` are
placeholders; no personal path is part of the procedure.

### Patch and configuration

```sh
research/tests/test-f005-serial-bootloader-request
```

Result:

```text
F005 serial bootloader request patch checks: PASS
```

The script proves that both patches apply in order to commit
`0499b30374315f2a9f49fc12808527fc7d0f5cfa`. The resolved F005 output contains:

```text
CONFIG_HAVE_BOOTLOADER_REQUEST=y
CONFIG_MACH_GD32F303=y
CONFIG_STM32_FLASH_START_3000=y
CONFIG_FLASH_BOOT_ADDRESS=0x8000000
CONFIG_FLASH_APPLICATION_ADDRESS=0x8003000
CONFIG_FLASH_SIZE=0x3d000
CONFIG_SERIAL_BAUD=230400
```

### F005 build

An exact upstream export with the productive F005 patch and the Research patch
was compiled in the existing F005 build container with networking disabled:

```sh
docker run --rm --network none \
  -v <workdir>/patched:/work/klipper:rw \
  -v <project-root>/build/klipper-f005/f005-gd32f303.config:/config/f005.config:ro \
  -w /work/klipper ender3-ke-klipper-build:f005 \
  sh -lc 'cp /config/f005.config .config; make olddefconfig; make'
```

Result: `klipper.elf` and `klipper.bin` built successfully. No flash or serial
target was invoked.

### Other-target regression and negative boundary

The upstream `test/configs/stm32f103-serial.config` was built once after only
the productive F005 patch and once after both patches. Both resolved to the
same configuration:

```text
CONFIG_MACH_STM32F103=y
CONFIG_STM32_FLASH_START_2000=y
CONFIG_FLASH_APPLICATION_ADDRESS=0x8002000
CONFIG_HAVE_BOOTLOADER_REQUEST=y
```

The extracted 96-byte `.text.bootloader_request` machine-code sections were
byte-identical, with SHA-256:

```text
4fb6d98da84a270600fcbfbef7e7e5bfe35e23b0623fc6574aa4cbba163f2551
```

Thus the new 12 KiB source branch is eliminated when its Kconfig selection is
false, and the relevant established STM32F103 behavior is unchanged. For the
F005 target, the Kconfig choice exposes only the 12 KiB option; the test gate
also rejects an input that claims a different application address. This is the
negative boundary: a non-`3000` target does not acquire the new reset branch,
and an inconsistent F005 layout is not accepted as a valid test input.

### Existing tests and validator

The existing relevant offline tests and the new open-flasher fake tests were
also run. The newly built raw F005 binary was packaged with the existing
project packager and accepted by the open F005 validator with exact identity,
size, SHA-256, metadata CRC, stack pointer, and reset-vector checks. Exact
commands and results are retained in the mission report rather than making a
timestamp-bearing Research build a production artifact.

## 6. Binary and ELF evidence

The patched F005 build provides the following direct evidence:

- `CONFIG_HAVE_BOOTLOADER_REQUEST=1` is present in generated `autoconf.h`;
- the literal `Request Serial Bootloader!! ~` is present in `klipper.bin`;
- `bootloader_request` is present in `stm32f1.o`;
- its disassembly calls `try_request_canboot()` and then emits the CMSIS
  `NVIC_SystemReset()` sequence (barriers, AIRCR write with the reset key, and
  the non-returning wait loop);
- the ELF `.text` section and `VectorTable` begin at `0x08003000`;
- the initial stack pointer is `0x20010000`;
- the reset vector remains a Thumb address inside the application range;
- all Flash load data remains below the conservative `0x08040000` boundary;
- the packaged image passes the existing F005 CRC/length/identity validator.

The build proves that the parser and reset implementation are linked into the
configured firmware. It does not prove that the exact UART block will be
received intact on the X2000 path, that the physical MCU will reset as expected,
or that the retained bootloader will remain available for the host handshake.

## 7. Safety status

```text
NO HARDWARE ACTION PERFORMED
BOOTLOADER REQUEST IS STATE-CHANGING
```

Application start is also state-changing. Neither action is an identify-only
or read-only operation. A future host interface must not hide
`request_bootloader` behind a read-only label merely because no flash erase is
requested.

Source behavior and bounded inference for important states:

| Situation | Expected effect and boundary |
| --- | --- |
| Normal idle | The exact serial block causes an immediate system reset with no protocol ACK. Whether all physical outputs enter a safe state through reset and bootloader startup is `REQUIRES QUALIFICATION`. |
| Active print | The same parser path is available; queued motion and closed-loop host control would be interrupted abruptly. This use is prohibited by the future gate. |
| Heater active | Host temperature control is lost at reset. GPIO/reset/bootloader output behavior is not proven safe. Heaters must be intentionally off before a real request. |
| MCU shutdown state | Scheduler and serial source paths indicate the special block remains actionable. This is `SOURCE BEHAVIOR ONLY`. |
| Wrong configured offset | The selection gates code; it does not choose the reset vector. A reset always returns to the boot flash mapping. A wrong layout can therefore start unintended or invalid code and must fail offline gates. |
| No valid bootloader | Reset may lead to a fault, reset loop, or inaccessible MCU. Exact behavior is unknown; recovery would be required. |
| Bootloader starts without host handshake | Timeout, automatic application start, or indefinite command wait are unknown because the retained bootloader has not been dumped. Do not assume a 15-second window for this device. |

## 8. End-to-end status

The future chain has individually bounded evidence:

| Step | Status |
| --- | --- |
| 1. Running patched Fre3nder Klipper at 230400 | Patched build `OFFLINE CONFIRMED`; real patched firmware `REQUIRES QUALIFICATION` |
| 2. Send exact serial bootloader request | Host implementation `OFFLINE IMPLEMENTED`; MCU parser/source `OFFLINE CONFIRMED`; real delivery/effect `REQUIRES QUALIFICATION` |
| 3. MCU resets into retained Creality bootloader | Reset source `OFFLINE CONFIRMED`; actual transition by this trigger `REQUIRES QUALIFICATION` |
| 4. Host switches to 115200 | Open flasher `OFFLINE IMPLEMENTED`; real timing `REQUIRES QUALIFICATION` |
| 5. `0x75` handshake | Protocol `OFFLINE CONFIRMED`; open implementation `OFFLINE IMPLEMENTED`; real open-tool use `REQUIRES QUALIFICATION` |
| 6. Identity | Parser/fake transport `OFFLINE IMPLEMENTED`; known identity correspondence `OFFLINE CONFIRMED`; real open-tool response `REQUIRES QUALIFICATION` |
| 7. Sector size | Wire path `OFFLINE IMPLEMENTED`; real returned multiplier `REQUIRES QUALIFICATION` |
| 8. Optional flash | Fake transfer and validation `OFFLINE IMPLEMENTED`; real write remains `RED ZONE / REQUIRES QUALIFICATION` |
| 9. Application start | Wire path `OFFLINE IMPLEMENTED`; real effect `REQUIRES QUALIFICATION` |
| 10. Klipper re-identification | Existing firmware path previously qualified by other reset routes; complete new chain `REQUIRES QUALIFICATION` |

Overall:

```text
F005 BOOTLOADER REQUEST SOURCE: OFFLINE CONFIRMED
F005 BOOTLOADER REQUEST PATCH: OFFLINE IMPLEMENTED
F005 PATCHED MCU BUILD: OFFLINE CONFIRMED
REAL BOOTLOADER ENTRY: REQUIRES QUALIFICATION
REAL APP START: REQUIRES QUALIFICATION
SOFTWARE-ONLY FRE3NDER -> STOCK: REQUIRES QUALIFICATION
```

## 9. Next hardware gate

No part of this section is authorization. Each state-changing step needs an
explicit later authorization and a verified recovery expectation.

1. **Gate 1 — no-write precondition:** verify the exact running MCU identity,
   no active print, heaters intentionally off, UART ownership, qualified host
   recovery path, exact patched artifact, and preserved Stock image. Recovery
   expectation: no state has changed.
2. **Gate 2 — patched-candidate installation:** because the current qualified
   MCU does not contain this code, install the exact validated Research image
   through a separately authorized, already qualified updater route. This is an
   MCU flash and remains RED ZONE. First require normal Klipper identity and an
   idle/heaters-off state without exercising the new request. Recovery
   expectation: use the preserved Stock image and qualified recovery boundary.
3. **Gate 3 — bootloader entry:** release normal UART ownership and send the
   exact request once at 230400. This is state-changing. Recovery expectation:
   the retained bootloader answers at 115200 or the existing power-cycle Stock
   recovery boundary is used; do not start another flash.
4. **Gate 4 — no-flash bootloader queries:** perform only handshake, exact
   identity, and sector-size query. Recovery expectation: no erase/write has
   begun; an unexpected response stops the test.
5. **Gate 5 — unchanged application start:** send `app_start`, also explicitly
   state-changing, then independently require the same Klipper identity and
   readiness at 230400. Recovery expectation: use the already preserved exact
   image and qualified recovery procedure if the application does not return.
6. **Gate 6 — open-flasher exact-image write:** only after another explicit RED-ZONE
   authorization, validate exact source identity, allowlist, manifest identity,
   size, SHA-256, image CRC, recovery path, and UART ownership. Start one open
   updater invocation with no retry, then independently identify and qualify
   the result.

The gates deliberately separate parser-triggered reset, open-protocol read
queries, application start, and flash so that no test introduces several new
hardware assumptions at once.

## 10. Production readiness

Before the Research patch and open flasher may replace proprietary `mcu_util`
in production, the project still needs:

- real qualification of the exact patched F005 firmware and physical-serial
  request from idle with heaters off;
- open-tool handshake, identity, sector-size, and unchanged-app-start
  qualification;
- an explicit decision and qualification for the optional leading sync byte
  and UART handoff timing;
- one separately authorized exact-image flash plus independent post-flash MCU
  and printer validation;
- bounded, fail-closed handling for timeout, checksum error, flash error,
  unknown status, partial transfer, and failed app start without automatic
  retry;
- productive release-manifest integration, UART/print/heater ownership gates,
  and review of the shared non-A/B MCU recovery boundary;
- qualification of the still-open complete Fre3nder-to-Stock host handoff;
- review and deliberate promotion of the GPLv3 patch into the productive patch
  series.

Until those gates pass, the qualified `2026.1` baseline and its existing MCU
lifecycle remain unchanged.
