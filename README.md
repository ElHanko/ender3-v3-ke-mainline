# Ender-3 V3 KE mainline

This project investigates how to keep the Creality Ender-3 V3 KE usable as an
open and maintainable Klipper platform.

## Project goal

The goal of this project is to make the Creality Ender-3 V3 KE reproducibly
usable as an open Klipper platform while preserving a documented and validated
path back to the original Creality firmware.

The project does not aim to preserve Creality's proprietary software stack
where an open replacement is available.

The priorities are:

1. Establish and validate a complete backup and brick-recovery path.
2. Reverse-engineer and document the hardware and Creality-specific Klipper
   changes required to operate the printer.
3. Determine which vendor-specific components are actually required for printer
   operation.
4. Replace proprietary, obsolete, or unmaintained components with open
   alternatives where practical.
5. Port the printer to current upstream Klipper and Moonraker.
6. Provide reproducible build, installation, validation, recovery, and rollback
   procedures.
7. Avoid redistributing third-party artifacts where redistribution rights are
   unclear.

Preserving the original Creality touchscreen, web interface, application stack,
or other vendor UI components is not a project requirement. Their functionality
may be replaced by open alternatives.

Likewise, the project requires the functionality needed to operate the printer,
not necessarily Creality's implementation of that functionality.

No irreversible modification of the printer was required for the completed
offline analysis or the failed RAM-only attempt. The external recovery route is
documented and offline-material-validated, but its execution has not been
personally rehearsed and is not guaranteed; any decision to continue with
persistent changes is now explicit **WARNING / RED ZONE** work under the risk
boundary below.

## Current status

The project has closed its current recovery investigation at **Phase 1.5**.
Gate 1 / Point of Return is **SATISFIED** by the current evidence review. The
vendor recovery path is documented and Linux-independent, but has not been
personally rehearsed on this device; the private Linux RAM-only client did not
reach Stage 2. Recovery execution remains documented but not personally
rehearsed, and is not guaranteed.

Completed:

- read-only reference-system inventory;
- eMMC and A/B partition-layout analysis;
- stock Klipper, Moonraker, MCU, and Creality-service inventory;
- complete private reference capture and offline backup validation;
- two independently stored and re-read raw eMMC backup copies;
- analysis of the official V1.1.0.12 `.ingenic` recovery package, payload map,
  erase policy, GPT layout, SPL, and Stage-2 loader;
- practical non-writing entry into Ingenic USB Boot mode on the reference board,
  including `a108:eaef` enumeration and `X2000` CPU identification;
- offline recovery preflight for the exact reference-board recovery set;
- a private KE-specific Linux Boot-ROM RAM-only client, with 22 offline tests
  covering archive validation and the fixed transfer sequence;
- one fresh, non-destructive Linux RAM-only hardware attempt: GET_CPU_INFO and
  the complete Stage-1 transfer succeeded, but the first Stage-2 address
  transfer timed out after PROGRAM_START1;
- separation of public project documentation from local device information.

The private offline preflight reached:

```text
READY FOR MANUAL RECOVERY REVIEW
NOT READY TO FLASH
```

The Linux RAM-only attempt did not load or start Stage 2. No CONFIG, INIT, READ,
WRITE, MMC/eMMC, erase, or other persistent operation was executed. The
official Windows/Cloner route remains **VENDOR-DOCUMENTED, BUT NOT PERSONALLY
VERIFIED ON THIS DEVICE**.

The later controlled Mainline F005 MCU flash and staged host/runtime validation
are documented in [`docs/gd32f303-mainline-port.md`](docs/gd32f303-mainline-port.md)
and [`docs/f005-hardware-validation.md`](docs/f005-hardware-validation.md).
They do not change the Gate-1 recovery boundary.

Phase 2 MCU sub-milestone: **OFFLINE MCU PORT VALIDATION COMPLETE**

- the Creality Klipper delta needed for the first mainline MCU milestone was
  classified from the reference configuration, runtime logs, and archived
  F005 material;
- the active probe path is the normal BLTouch/`probe` path, while PR-Touch,
  HX711, dir-Z, filter, soft-homing, and fan-feedback paths are outside the
  first milestone;
- the investigated GD32F303RET6/F005 board has a minimal upstream port based on
  existing STM32F1-compatible and generic Klipper code, without a new full
  `src/gd32/` backend;
- the port was validated by three offline builds (GD32 clean build, STM32F103
  regression, and GD32 clean rebuild) using the documented source patch and
  conservative first-256-KiB flash layout;
- the public source patch and offline Docker build recipe are available under
  [`patches/klipper/`](patches/klipper/) and
  [`build/klipper-f005/`](build/klipper-f005/).

The MCU sub-milestone was followed by one controlled reference-board flash and
identify PASS. The offline host/printer configuration integration and the
subsequent staged hardware validation are documented below; this is not a
recovery or rollback authorization.

Phase 2 host/config sub-milestone: **OFFLINE HOST/CONFIG INTEGRATION COMPLETE**

- two project-authored F005 configuration candidates were accepted by current
  upstream Klippy and the exact GD32 dictionary in offline debugoutput mode;
- the minimal bring-up and first-mainline target are published under
  [`configs/klipper-f005/`](configs/klipper-f005/), with the pin mapping in
  [`docs/f005-pin-matrix.md`](docs/f005-pin-matrix.md);
- the minimal bring-up file remains an offline/no-action parser candidate;
  the mainline file is a validated reference baseline for the investigated
  board, with independent calibration required on other printers;
  [`docs/f005-hardware-validation.md`](docs/f005-hardware-validation.md) records
  the exact scope.

Phase 2 hardware validation: **REFERENCE F005 FIRST PRINT PASS**. The complete
configuration, peripheral bring-up, and one PLA Benchy succeeded on the
investigated reference. Gate 1 is satisfied by the current evidence review;
destructive vendor recovery and return to Stock remain unverified and are not
claimed as guaranteed.

To reproduce that bounded Phase-2 result, use
[`docs/f005-first-print-reproduction.md`](docs/f005-first-print-reproduction.md)
in this order: recovery/risk boundary, F005 hardware applicability, MCU build
and packaging, X2000 `c_helper.so` build, controlled first flash, temporary
Mainline Klippy runtime, Stage A--F validation, and the test-only first-print
transport. The resulting validated baseline is
[`configs/klipper-f005/printer-f005-mainline.cfg`](configs/klipper-f005/printer-f005-mainline.cfg).

Not yet completed:

- destructive end-to-end V1.1.0.12 `.ingenic` recovery on the reference board;
- demonstrated normal V1.1.0.12 boot after that recovery;
- final Gate-1 identity-preservation/restoration validation and complete
  V1.1.0.12 -> V1.1.0.15 return-path demonstration;
- permanent production installation and startup management of Mainline Klipper
  on the X2000 (a temporary Mainline runtime succeeded during Phase 2).

Recovery research is closed at this boundary. The next project focus is
Phase 3 host/print-computer architecture and upstream-near Klipper/Linux
userspace work, under the red-zone warning above.

The recovery path is not guaranteed. Further persistent work is **WARNING / RED
ZONE** work: it may make the printer unbootable, require additional hardware
intervention, or permanently destroy the device. Proceeding with such work
requires an explicit, separately recorded authorization and risk acceptance;
the project documentation does not describe the device as recoverable merely
because backups and offline analysis exist.

## Documentation

Start with:

- [`docs/system-inventory.md`](docs/system-inventory.md) for the reference-system
  inventory;
- [`docs/storage-layout.md`](docs/storage-layout.md) for the eMMC and A/B layout;
- [`docs/klipper-stock.md`](docs/klipper-stock.md) for the currently known
  Creality Klipper differences;
- [`docs/gd32f303-mainline-port.md`](docs/gd32f303-mainline-port.md) for the
  completed Phase 2 MCU port and its offline validation;
- [`docs/f005-mainline-config.md`](docs/f005-mainline-config.md) for the
  F005 configuration basis, reference calibration scope, and hardware boundary;
- [`docs/f005-first-print-reproduction.md`](docs/f005-first-print-reproduction.md)
  for the bounded Phase-2 build-to-first-print reproduction route;
- [`docs/f005-hardware-validation.md`](docs/f005-hardware-validation.md) for
  the staged reference-board validation and complete-print result;
- [`docs/x2000-hardware-contract.md`](docs/x2000-hardware-contract.md) for the
  Phase-3.1 required X2000 hardware, boot, and recovery contract;
- [`docs/x2000-open-host-architecture.md`](docs/x2000-open-host-architecture.md)
  for the selected complete open-host target and its phase sequence;
- [`docs/x2000-kernel-dt-feasibility.md`](docs/x2000-kernel-dt-feasibility.md)
  for the completed Phase-3.2 SDK/Device-Tree basis decision and its provenance;
- [`docs/recovery-analysis.md`](docs/recovery-analysis.md) for currently visible
  recovery mechanisms;
- [`docs/recovery-current-state.md`](docs/recovery-current-state.md) for the
  current reference-board recovery state and accepted residual risks;
- [`docs/backup-plan.md`](docs/backup-plan.md) for backup requirements;
- [`docs/roadmap.md`](docs/roadmap.md) for project gates and sequencing;
- [`docs/licensing-and-provenance.md`](docs/licensing-and-provenance.md) for
  third-party artifact and redistribution policy.

Agent safety and documentation rules are defined in
[`AGENTS.md`](AGENTS.md).

Copy [`docs/local-device.example.md`](docs/local-device.example.md) to the
Git-ignored `docs/local-device.md` for local printer and workstation
information.

Never store secrets in either file.

## Reference system

The initial inventory was performed on a reference Ender-3 V3 KE running
Creality firmware `V1.1.0.15`.

Observations from that system are not automatically assumed to apply to every
hardware or firmware revision.

The inspected reference device also contained modifications in writable
storage. Documentation therefore distinguishes the immutable Creality firmware
base from local additions wherever possible.

## Safety principle

Recovery comes before experimentation.

The project must establish a usable point of return before making experimental
changes to the printer:

```text
reference inventory
        |
        v
complete backup
        |
        v
offline validation
        |
        v
vendor-documented recovery (not personally rehearsed; not guaranteed)
        |
        v
Gate 1 evidence satisfied / persistent work remains RED ZONE
        |
        v
vendor delta analysis
        |
        v
mainline migration
```

## Scope

A successful result may retain the existing Creality host operating system or
replace parts of it, depending on what later analysis shows to be practical.

Possible end states include:

- current upstream Klipper on the existing host system;
- upstream Klipper and Moonraker with an open web and touchscreen stack;
- replacement of Creality-specific printer functions with open
  implementations;
- longer-term replacement of additional unmaintained host components.

The recovery path remains unvalidated. Offline architecture and Creality-delta
work may proceed under the explicit red-zone boundary, while any persistent
deployment decision still requires separate authorization and documented risk
acceptance.

## License

Original project-authored material in this repository is licensed under the
[MIT License](LICENSE), unless a file or directory states otherwise.

Third-party material and source derived from upstream Klipper, Creality's
published Klipper sources, or other projects remain subject to their respective
licenses. See
[`docs/licensing-and-provenance.md`](docs/licensing-and-provenance.md).
