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

Do not create a commit unless the task explicitly requests one.
