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
offline analysis or the failed RAM-only attempt. A validated recovery path has
not been established; any decision to continue with persistent changes is now
explicit **WARNING / RED ZONE** work under the risk boundary below.

## Current status

The project has closed its current recovery investigation at **Phase 1.5**.
Gate 1 / Point of Return is **not satisfied**: the vendor recovery path is
documented but has not been completed on this device, and the private Linux
RAM-only client did not reach Stage 2.

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

Not yet completed:

- destructive end-to-end V1.1.0.12 `.ingenic` recovery on the reference board;
- demonstrated normal V1.1.0.12 boot after that recovery;
- final Gate-1 identity-preservation/restoration validation and complete
  V1.1.0.12 -> V1.1.0.15 return-path demonstration;
- reconstruction of the exact Creality Klipper delta;
- upstream Klipper migration design;
- installation of mainline Klipper.

Recovery research is closed at this boundary. The next project focus is the
offline Creality-delta analysis and upstream-near Klipper/Linux userspace work,
under the red-zone warning above.

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
vendor-documented recovery (not verified on this device)
        |
        v
Gate 1 remains unsatisfied / RED ZONE
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
