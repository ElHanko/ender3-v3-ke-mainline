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

No irreversible modification of the printer should be required before a
validated recovery path has been established.

## Current status

The project is currently in the inventory and recovery-planning phase.

Completed:

- read-only reference-system inventory;
- eMMC and A/B partition-layout analysis;
- stock Klipper, Moonraker, MCU, and Creality-service inventory;
- initial backup and recovery analysis;
- separation of public project documentation from local device information.

Not yet completed:

- complete backup capture;
- offline backup validation;
- verified brick-recovery procedure independent of the running Linux system;
- reconstruction of the exact Creality Klipper delta;
- upstream Klipper migration design;
- installation of mainline Klipper.

The printer must remain unchanged until the first project gate described in
[`docs/roadmap.md`](docs/roadmap.md) has been reached.

## Documentation

Start with:

- [`docs/system-inventory.md`](docs/system-inventory.md) for the reference-system
  inventory;
- [`docs/storage-layout.md`](docs/storage-layout.md) for the eMMC and A/B layout;
- [`docs/klipper-stock.md`](docs/klipper-stock.md) for the currently known
  Creality Klipper differences;
- [`docs/recovery-analysis.md`](docs/recovery-analysis.md) for currently visible
  recovery mechanisms;
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
verified brick recovery
        |
        v
POINT OF RETURN
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

The final architecture will be selected only after recovery has been validated
and the Creality-specific Klipper changes have been understood.

## License

Original project-authored material in this repository is licensed under the
[MIT License](LICENSE), unless a file or directory states otherwise.

Third-party material and source derived from upstream Klipper, Creality's
published Klipper sources, or other projects remain subject to their respective
licenses. See
[`docs/licensing-and-provenance.md`](docs/licensing-and-provenance.md).
