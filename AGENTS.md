# Project scope

This repository documents and develops a possible migration of the Creality
Ender-3 V3 KE from Creality's Klipper fork to current upstream Klipper.

# Safety rules

The physical printer is a production system. Unless a task explicitly authorizes
changes, every access to the printer must be read-only.

By default, do not:

- create, modify, move, or delete files on the printer;
- install or update packages;
- start, stop, or restart services;
- alter mounts or filesystems;
- write to block devices or change partitions;
- change the bootloader or kernel;
- change or flash MCU firmware;
- change printer configuration;
- perform a factory reset or firmware update.

Prefer non-interactive remote access:

```sh
ssh -o BatchMode=yes <printer-host> '<command>'
```

If an investigation would require a write, do not perform it automatically.
Document it as a required next step instead.

## Physical-access constraints

The project must use existing external interfaces wherever possible.

Unless the project scope is explicitly changed by the operator, do not require:

- soldering;
- USB-UART adapters;
- added serial headers or test wires;
- board modifications solely to obtain a debug console.

The currently accepted non-invasive access paths are:

- the normal stock Linux interface, including SSH where available;
- the existing external Ingenic USB / BootROM interface.

A missing serial bootloader console is a project constraint, not a reason to
implicitly introduce hardware modification work.

# Decision discipline and proportionality

Before proposing, implementing, or expanding any task, ask:

> Is this step necessary, or does it materially advance the project goal?

Do not pursue work merely because it would make a helper, test, guard, recovery
procedure, or analysis more complete in theory.

In particular:

- prefer the smallest change or investigation that resolves the current blocker;
- do not chase hypothetical edge cases without concrete evidence that they matter
  to the next project step;
- do not turn temporary diagnostics, guards, or one-off migration helpers into
  projects of their own;
- if a supporting tool starts consuming effort comparable to or greater than the
  migration work it is supposed to enable, stop and re-evaluate whether that tool
  or prerequisite is still justified;
- distinguish clearly between `REQUIRED`, `USEFUL`, and `INTERESTING` work, and
  defer the latter two when they do not materially reduce risk or unblock progress;
- when a diagnostic or validation step repeatedly fails for reasons unrelated to
  the actual migration target, explicitly reconsider whether the remaining
  uncertainty can be accepted instead of automatically adding another attempt;
- prefer evidence-driven fixes for observed failures over generalized hardening.

Safety is important, but 100 percent certainty or risk elimination is not a
project requirement and is generally unattainable. Risk reduction must be
proportionate to the actual hardware risk, expected benefit, and effort required.

Treat the system proportionally: this is a 3D-printer migration project, not an
aerospace or life-safety system. Do not apply aerospace-style process overhead to
ordinary software or diagnostic details unless a concrete printer hazard warrants
it.

This proportionality rule does not override explicit red-zone warnings or the
requirement for separate authorization before persistent or hardware-changing
operations. It exists to prevent unnecessary detail work from blocking the actual
migration.

Offline validation does not constitute hardware authorization.

A successful build, fixture test, image-size check, or simulated storage write
may establish that an implementation is ready for the next gate, but it must
not be used as implicit authorization to perform the corresponding operation
on the physical printer.

## Expensive build and validation cadence

Do not repeatedly run expensive full builds or full validation pipelines after
every small implementation change when faster targeted checks can validate the
changed component.

During iterative development:

- use the smallest relevant validation for the current change, such as syntax
  checks, targeted configuration checks, patch checks, fixture tests, or static
  inspection;
- do not rebuild unchanged components merely to reconfirm results that have
  already been established;
- group related implementation changes before running an expensive end-to-end
  build;
- normally perform one complete build and end-to-end offline validation after
  the current implementation step is functionally complete;
- if that final build exposes a concrete problem, fix that problem with targeted
  checks first and then rerun the full build;
- rerun a full build during implementation only when the changed behavior cannot
  be meaningfully validated without it.

A full build is a validation gate, not the default feedback loop for every edit.

This rule does not permit skipping the final validation required for the current
project step. It requires validation effort to remain proportional to the change
being made.

# Device-specific information

Do not commit information that identifies only one printer, computer, user, or
network. This includes:

- IP and MAC addresses;
- serial numbers and unique device identifiers;
- SSH fingerprints and local SSH aliases;
- personal usernames and home paths;
- concrete filesystem or partition UUIDs;
- current local storage usage;
- individually installed software or printer modifications;
- previous local experiments, helper scripts, and network details.

Store such information only in `docs/local-device.md`, which must remain ignored
by Git. Keep a sanitized template in `docs/local-device.example.md`.

## Hardware research and external references

For Ender-3 V3 KE / Ingenic X2000 hardware enablement, consult relevant
existing public hardware research before repeating board-specific
investigation from scratch.

In particular, NebulaOS / OpenKE should be treated as a primary external
reference for Ender-3 V3 KE hardware work where applicable:

- https://github.com/coreflake1/NebulaOS
- https://github.com/coreflake1/NebulaOS-firmware
- https://github.com/coreflake1/NebulaOS-kernel

External findings are reference evidence, not authority:

1. Prefer findings backed by stock firmware, stock DTB, vendor sources,
   measurements, or real-hardware qualification.
2. Verify applicable findings against this project's pinned kernel,
   drivers, device tree, and observed hardware before adopting them.
3. Do not blindly copy implementation details when versions, drivers,
   bindings, or architecture differ.
4. Clearly distinguish:
   - findings independently observed in this project,
   - findings reproduced from an external source,
   - unverified hypotheses.
5. When a concrete hardware fact, configuration value, pin assignment,
   patch concept, or implementation detail is adopted from another
   project, preserve provenance by citing the specific source in the
   relevant technical documentation or source comment.
6. Prefer the most specific source available: exact file, commit,
   documentation section, stock-derived artifact, or hardware report,
   rather than only the project homepage.

# Secrets

Never store or commit passwords, tokens, API keys, private SSH keys, credentials,
session secrets, or authentication cookies. Secrets must not be placed in
`docs/local-device.md` either.

# Documentation rules

General documentation must either describe a demonstrated general property of the
Ender-3 V3 KE or clearly scope an observation to a reference firmware/system. When
generality is not proven, use wording such as:

> Observed on the reference system running Creality firmware ...

Do not generalize from a single inspected printer to all Ender-3 V3 KE firmware or
hardware revisions.

# Local paths

Do not commit personal local paths. Use placeholders:

- `<project-root>`
- `<printer-host>`
- `<printer-ip>`
- `<local-user>`

Technical paths on the printer, such as `/usr/data`, `/overlay`, `/etc`, and
`/dev/ttyS1`, may be documented normally.

# Git rules

Before every commit, at minimum:

1. run `git status --short`;
2. run `git diff --check`;
3. review the complete diff;
4. verify that `docs/local-device.md` is ignored;
5. scan for secrets and individual device information.
6. verify that new or modified third-party material has documented provenance
   and redistribution status.

Do not create a commit unless the task explicitly requests one.

# Project goal

The project goal is to make the Creality Ender-3 V3 KE reproducibly usable as
an open Klipper platform while preserving a documented and validated path back
to the original Creality firmware.

The project requires the functionality needed to operate the printer, not
necessarily preservation of Creality's implementation.

Creality-specific user interfaces, application services, touchscreen software,
or other proprietary components may be replaced with open alternatives where
appropriate.

The project must prioritize maintainability, reproducibility, recoverability,
and open implementations over compatibility with unnecessary vendor software.

# Project gates

The roadmap in `docs/roadmap.md` defines mandatory project gates.

## Gate precedence

Mandatory roadmap gates cannot be replaced, weakened, or bypassed by a
task-specific safety check or bring-up gate.

Additional gates may impose stricter conditions for a particular operation,
but satisfying such a gate does not satisfy an unmet mandatory roadmap gate.

In particular, an A/B rollback or slot-switching check may be required in
addition to Gate 1, but it does not replace Gate 1.

## Gate 1 - POINT OF RETURN

Before Gate 1 is satisfied, do not perform experimental changes to persistent
printer state, even when the change appears reversible or is confined to an
inactive A/B slot.

This includes, unless Gate 1 has first been satisfied:

- boot-selector or OTA-marker writes;
- writes to inactive kernel or RootFS slots;
- bootloader-environment writes;
- partition or filesystem changes;
- kernel or RootFS deployment;
- MCU firmware changes.

Read-only inspection, offline builds, fixture-based tests, and volatile
experiments that provably do not modify persistent printer state may continue
before Gate 1.

After Gate 1 is satisfied, persistent or hardware-changing work still requires
explicit authorization for the concrete operation.

Gate 1 requires, at minimum:

- a sufficiently complete backup for the known storage architecture;
- offline validation of the backup;
- protected device-specific identity/factory data;
- documented eMMC boot configuration;
- archived original firmware material where available;
- a recovery path that does not depend solely on the normal Linux system
  continuing to boot;
- a documented route back to the original Creality firmware.

A recovery path does not have to be destructively rehearsed on a working
production printer solely to satisfy Gate 1 when an applicable vendor-documented
external recovery procedure exists and all material required to execute that
procedure has been preserved and validated.

An untested recovery procedure must not be described as guaranteed. Its
remaining execution uncertainty must be documented explicitly.

## Recovery red zone

The reference board's previous non-destructive Linux-hosted RAM-only recovery
attempt reached Stage 1 but did not successfully load or start Stage 2.

A Linux-hosted recovery path was therefore not established by this project.
Such a path is not required for Gate 1 when a separate recovery route exists
that does not depend on the normal Linux system continuing to boot.

Creality provides a documented external recovery procedure using its
Windows/Cloner tooling. The project preserves the material required for the
documented recovery route and the backups required by Gate 1.

The complete recovery procedure has not been executed on the reference device.
It must therefore be treated as a documented but execution-unverified recovery
path, not as a guaranteed restore procedure.

Public prior art for the Ingenic BootROM USB interface, including loading SPL
and RAM-resident U-Boot, provides an additional possible recovery mechanism but
is not required to substitute for the documented Creality recovery route.

Any later work that changes the bootloader, partitions, kernel, RootFS, MCU
firmware, boot selector, or other persistent contents is **WARNING / RED ZONE**
work. Gate 1 satisfaction reduces the risk of losing the documented return path;
it does not make such operations risk-free and does not authorize them
implicitly.

## Gate 2 - CREALITY DELTA UNDERSTOOD

Do not begin the final mainline migration design until required
Creality-specific behavior has been classified.

Use the classifications defined in `docs/roadmap.md`:

- `UPSTREAM`
- `KEEP`
- `REIMPLEMENT`
- `DROP`
- `UNKNOWN`

Required printer functionality may be reimplemented openly instead of retaining
the original vendor implementation.

# Copyright, licensing, and provenance

Follow `docs/licensing-and-provenance.md`.

Do not commit or redistribute third-party firmware images, extracted vendor
binaries, device backups, factory identity data, certificates, or other
third-party artifacts unless their redistribution rights have been verified.

Prefer:

- official source links;
- hashes and version identifiers;
- patches against publicly licensed source;
- locally executed extraction/import workflows;
- independently written documentation;
- open reimplementations of required behavior.

Do not assume that the license of Creality's published Klipper source also
covers unrelated binaries or other components contained in Creality firmware
images.

When importing or comparing third-party source, record its exact provenance,
including repository, version or commit, and applicable license.

For Klipper comparisons, always identify the exact comparison basis:

- upstream Klipper revision;
- public Creality revision;
- reference Creality firmware/tree.

Do not call a difference a "Creality modification" unless the comparison basis
supports that conclusion.

Project-authored material is MIT-licensed unless a file or directory states
otherwise. Do not relicense GPL-covered or other third-party material as MIT.
