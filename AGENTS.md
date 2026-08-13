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

## Gate 1 - POINT OF RETURN

Before Gate 1 is satisfied, do not perform experimental or irreversible changes
to the physical printer.

Gate 1 requires, at minimum:

- a sufficiently complete backup for the known storage architecture;
- offline validation of the backup;
- protected device-specific identity/factory data;
- documented eMMC boot configuration;
- archived original firmware material where available;
- a recovery path that does not depend solely on the normal Linux system
  continuing to boot;
- a documented route back to the original Creality firmware.

A backup without a usable restore path does not satisfy Gate 1.

If the recovery procedure has not actually been demonstrated, do not describe
it as guaranteed. Record the remaining uncertainty.

## Recovery red zone

The reference board's non-destructive Linux RAM-only recovery attempt did not
reach Stage 2, and no complete vendor restore has been demonstrated. Gate 1 is
therefore not satisfied. Any later work that changes the bootloader, partitions,
kernel, RootFS, MCU firmware, or other persistent contents is **WARNING / RED
ZONE** work: it may leave the device unbootable, require additional hardware
intervention, or permanently damage the device. The vendor Windows/Cloner path
is vendor-documented but not personally verified on this device. This warning
does not itself authorize a persistent operation; each such operation still
requires explicit scope and authorization.

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
