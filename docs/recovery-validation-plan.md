# Phase 1.5 recovery validation plan

This runbook validates the Ender-3 V3 KE point-of-return path before any mainline
migration work begins.

It deliberately separates a reversible recovery-interface check from the
destructive vendor flash test.

## Scope and evidence labels

The reference system is the privately captured Ender-3 V3 KE running Creality
firmware V1.1.0.15.

Use the evidence labels defined in `recovery-analysis.md`:

- `CONFIRMED-ON-DEVICE`
- `OFFLINE-CONFIRMED`
- `VENDOR-DOCUMENTED`
- `COMMUNITY-RESEARCH / NOT KE-VERIFIED`
- `INFERENCE`
- `OPEN`

Device-specific identifiers, hashes of device backups, screenshots containing
identifiers, and local paths remain private.

## Prerequisites already satisfied

Before this runbook begins:

- official V1.1.0.12 `.ingenic` recovery material is archived privately;
- official V1.1.0.12 and V1.1.0.15 F005 OTA images are archived privately;
- vendor artifacts have recorded provenance and hashes;
- a complete reference capture for the known storage architecture exists;
- the capture has passed offline integrity and filesystem validation within the
  documented live-ext4 limits;
- device-specific p2 `sn_mac` and the full eMMC user area are protected;
- a second independent physical copy of the private recovery set exists and has
  been re-read and SHA-256-verified from separate storage;
- the direct V1.1.0.12-to-V1.1.0.15 OTA transition is historically confirmed on
  the reference device.

## Official vendor recovery basis

Creality documents a KE-specific recovery procedure using:

- the screen/host board's MicroUSB connection;
- the board `Boot` and `Reset` buttons;
- enumeration as `Ingenic USB BOOT DEVICE`;
- the official Windows Ingenic Cloner/driver package;
- a `.ingenic` recovery image.

The official sequence enters the recovery state by holding Boot and Reset,
releasing Reset first and then Boot, and later repeats that sequence after
selecting Start in Cloner.

No project step may silently substitute another model's loader or recovery image.

## Stage 1 - Non-writing USB recovery-mode validation

**Purpose:** prove that the vendor-documented low-level recovery interface is
reachable on the reference hardware without flashing anything.

This stage is not a firmware write.

**Status: completed on the reference board.** It enumerated as
`a108:eaef` / `Ingenic USB BOOT DEVICE`; a non-writing CPU-info request returned
`X2000`.

Preparation:

1. Verify the archived Cloner/driver package against the private vendor-artifact
   manifest.
2. Use a native Windows environment where practical.
3. Install only the official Ingenic driver supplied for the recovery tool.
4. Do not load/start a `.ingenic` flash during this stage.
5. Record the Windows/driver/tool versions privately.

Hardware procedure:

1. Power down the printer.
2. Disconnect the screen/host connection from the printer as required by the
   official KE procedure.
3. Expose the screen/host board and connect its MicroUSB data port to the Windows
   computer using a known data-capable cable.
4. Hold `Boot` and `Reset` for approximately three seconds.
5. Release `Reset` first.
6. Release `Boot` second.
7. Confirm that Windows enumerates `Ingenic USB BOOT DEVICE`.

Pass criteria:

- the expected Ingenic USB device appears;
- no flash was started;
- after disconnecting USB, restoring normal wiring, and powering on, the printer
  still boots the unchanged V1.1.0.15 system.

Failure criteria:

- no expected USB device appears after cable/driver checks;
- a different device identity is presented;
- normal boot no longer works after leaving recovery mode.

If this stage fails, stop. Do not proceed to a flash.

## Stage 2 - Destructive-test preflight

This stage prepares the actual vendor recovery test but stops before any write.

**Offline status:** the private preflight currently reports
`READY FOR MANUAL RECOVERY REVIEW` and `NOT READY TO FLASH`. It has re-verified
the exact vendor archive, payloads, erase map, GPT geometry, p2 preservation map,
first-boot p9/p10 recreation evidence, and two independent full raw backup copies.

Accepted warnings for manual review:

- p1 is erased and receives no payload; the expected A-side default for an erased
  selector is strongly supported but not formally proven;
- p10 is partially physically erased before the complete ext4 filesystem is
  recreated on first boot;
- p4/p6/p8 are intentionally empty immediately after recovery.

Required checks:

1. Both private backup copies remain readable.
2. Re-verify the V1.1.0.12 `.ingenic` hash.
3. Re-verify the Cloner package hash.
4. Record the pre-test p2 `sn_mac` hash privately.
5. Record the pre-test selector and partition hashes privately.
6. Confirm the exact reference model/board designation: Ender-3 V3 KE / F005.
7. Load only the official V1.1.0.12 `.ingenic` in Cloner.
8. Record the loaded image/version and Cloner state privately.
9. Stop before `Start`.

A separate explicit authorization is required before proceeding from this point.

## Stage 3 - Vendor V1.1.0.12 `.ingenic` recovery

This is the first intentionally destructive stage.

Use the official Creality procedure without experimental Cloner settings.

Expected from offline analysis, but not guaranteed until tested:

- user-area boot/SPL/U-Boot/GPT are written;
- p3 RTOS is written;
- p5 kernel is written;
- p7 RootFS is written;
- p2 `sn_mac` is intended to remain outside the configured erase ranges;
- p1, the inactive B side, p9, and part of p10 may be erased.

Because first boot can create or modify writable filesystems, post-boot observations
cannot be treated as a perfect sector-by-sector record of the immediate
post-Cloner state.

Record:

- whether Cloner reaches 100%;
- any warnings/errors;
- whether the board indicates successful completion as described by Creality;
- tool and image versions;
- timestamps;
- screenshots/logs, kept private if they contain device identifiers.

Abort/escalation conditions:

- image/hash mismatch;
- unexpected model/configuration;
- Cloner reports an error;
- USB disconnect or host instability during writing;
- any request to change undocumented advanced Cloner options.

## Stage 4 - First boot into recovered V1.1.0.12

After Cloner reports success:

1. Restore the normal screen/host wiring.
2. Boot normally.
3. Confirm the Creality UI starts.
4. Confirm firmware reports V1.1.0.12/F005.
5. Avoid cloud binding and unnecessary personalization before identity checks.
6. If vendor-supported root access is required for read-only validation, enable it
   only after recording the initial boot state.

Read-only checks should then establish:

- p2 `sn_mac` hash versus the protected pre-test value;
- selector value;
- active RTOS/kernel/RootFS side;
- observable p1-p10 state;
- EXT_CSD boot configuration;
- boot0/boot1 state.

The p2 comparison is a hard identity-preservation checkpoint.

If p2 differs unexpectedly, stop before cloud binding or normal use. Do not invent
replacement identity data.

## Stage 5 - Direct V1.1.0.12 to V1.1.0.15 OTA

Only after V1.1.0.12 boots successfully and the identity checkpoint is understood:

1. Use the archived official F005 V1.1.0.15 OTA image.
2. Follow the normal Creality local-USB update path.
3. Allow the updater to complete and reboot.
4. Confirm V1.1.0.15/F005.
5. Confirm the expected A/B selector and active system.
6. Record the resulting state.

This transition is already historically confirmed on the reference device; this
stage demonstrates it as part of the complete recovery chain.

## Stage 6 - Restore protected settings and validate stock operation

Restore only device-specific material that is actually needed and only at a
verified safe stage.

Never restore another printer's identity data.

Validation should cover at minimum:

- normal Creality UI boot;
- host/main-MCU communication;
- temperature sensor visibility;
- network/LAN operation where expected;
- Moonraker/host services required by the stock system;
- retained/restored device identity;
- required printer configuration and calibration;
- normal reboot stability.

A calibration/self-check may be required after firmware recovery according to the
vendor update procedure. Record any values that are regenerated rather than
restored.

## Gate-1 pass criteria

Gate 1 can be described as demonstrated only when:

1. the reference hardware can enter the Linux-independent Ingenic USB recovery
   mode;
2. the official V1.1.0.12 `.ingenic` recovery completes;
3. the recovered system boots V1.1.0.12 without relying on the pre-existing Linux
   installation;
4. device identity is preserved or restored from the protected original data by a
   documented safe method;
5. the official direct V1.1.0.12-to-V1.1.0.15 update completes;
6. the resulting V1.1.0.15 stock system passes the defined functional checks;
7. the complete procedure and remaining limitations are documented reproducibly.

If any item is not demonstrated, Gate 1 remains open and the project must state
the remaining uncertainty explicitly.
