# Recovery current state

This document records the current recovery state for the single reference printer
used by this project. It is a case study, not a universal recovery specification
for every Ender-3 V3 KE revision.

Reference hardware for the current work:

- Creality Ender-3 V3 KE;
- Creality hardware/OTA identifier `F005`;
- controller-board marking `CREALITY NEBULA V1.0.0.28`, dated `2023.5.25`;
- Ingenic X2000-family host platform;
- nominal 8 GB eMMC with the p1-p10 layout documented in
  [`storage-layout.md`](storage-layout.md).

The project intentionally optimizes for this one known board and firmware history.
Other owners may use the documentation as a technical reference, but must verify
their own board revision, storage layout, firmware artifacts, and recovery behavior
before applying any step.

## Project decision rule

> Is this step necessary, or clearly useful, to recover this reference board from
> a brick back to the official Creality V1.1.0.12 starting state?

Interesting but non-blocking reverse engineering is intentionally deferred.

## Current recovery target

```text
brick / non-booting normal Linux
  -> Ingenic USB Boot mode
  -> official V1.1.0.12 .ingenic recovery
  -> successful stock V1.1.0.12 boot
  -> optional official V1.1.0.12 -> V1.1.0.15 OTA
  -> validated stock operating state
```

## Low-level USB recovery entry

**CONFIRMED-ON-DEVICE:** the Boot/Reset sequence reaches the Ingenic USB recovery
interface on the reference board without writing firmware.

```text
VID:PID  a108:eaef
Product  Ingenic USB BOOT DEVICE
CPU info X2000
```

The official Windows/Creality Cloner remains a reference for the vendor flow,
protocol behavior, and recovery policy. It is not the practical execution route
for this reference setup because of the previously investigated Windows/driver
problem. The planned project route is a KE-specific Linux client; its first
hardware use remains unexecuted.

## KE GINFO and Stage 1

```text
GINFO   0xb2401000
SPL     0xb2401800
Stage 2 0x80100000
```

The final GINFO is 0x180 bytes:

```text
INFO wrapper
GPIO payload without GPIO wrapper header
DDR wrapper
```

A private clean-room generator reproduces the functional GINFO required by the
selected Creality X2000E/LPDDR2 path. Producer byte identity is not claimed.

**OFFLINE-CONFIRMED:** the original 9,720-byte Creality SPL performs CPU/clock,
UART, timer, PLL, and DDR initialization and then returns. No MMC/eMMC storage
controller path, erase operation, or persistent storage write was found in the
SPL itself.

## Stage-2 upload and protocol

Official KE Stage-2:

```text
load/start address  0x80100000
size                424684 bytes
SHA-256             194da4cce4481e2975d2fbf35dd7325df80cfb9a15a673643b2323a39863ab9d
```

Corrected host sequence:

```text
GET_CPU_INFO
-> send GINFO/SPL
-> run Stage 1
-> wait
-> host-side is_adb() check
-> upload uboot.bin
-> cache flush
-> run Stage 2
```

An earlier interpretation that placed `stage2_init()` between SPL and U-Boot was
caused by a misread C++ subobject/vtable offset and has been discarded.

Relevant Stage-2 requests:

| Request | Role |
|---:|---|
| `0x10` | ACK/status |
| `0x11` | module init |
| `0x12` | write |
| `0x13` | read |
| `0x14` | configuration upload |

For MMC reads, the media/operation word at command offset `+0x08` must be
`0x00020000` for the registered MMC module.

The optional read-only LBA-0 preflight was removed from the critical path because
fresh Stage-2 MMC initialization requires configuration and the complete backend
command path was not statically proven non-persistent.

## `read_from_flash.bin`

**OFFLINE-CONFIRMED:** `read_from_flash.bin` is a local host-side `PolicyRead`
output file, not firmware and not executable code for the printer.

## Official V1.1.0.12 recovery package

```text
Ender-3_V3_KE_1.1.0.12.ingenic
size    130364076 bytes
SHA-256 5388b16810e51c8233d6ee978b5b4a09347a4c9a4a516d3c5bf8c686e6783f3c
```

| Payload | Target offset | Size |
|---|---:|---:|
| `u-boot-with-spl-mbr-gpt.bin` | `0x00000000` | 212,296 bytes |
| `zero.bin` | `0x00300000` | 432,824 bytes |
| `xImage` | `0x00b00000` | 4,087,872 bytes |
| `rootfs.squashfs` | `0x01b00000` | 115,122,176 bytes |

Selected MMC policy:

```text
erase_all=1
erase_list="0x0,0x1fffff;0x300000,0xffffffff;"
force_erase=2
```

## Expected post-recovery eMMC state

| Partition | Expected immediate post-Cloner state |
|---|---|
| p1 `ota` | erased, no payload |
| p2 `sn_mac` | preserved by configured erase/write map |
| p3 `rtos` | erased, then `zero.bin` written |
| p4 `rtos2` | erased, no payload |
| p5 `kernel` | erased, then `xImage` written |
| p6 `kernel2` | erased, no payload |
| p7 `rootfs` | erased, then `rootfs.squashfs` written |
| p8 `rootfs2` | erased, no payload |
| p9 `rootfs_data` | erased, no payload |
| p10 `userdata` | partially erased from its start to the 4-GiB address boundary |

For this exact GPT, p2 lies between the configured erase ranges and has no active
write payload. Actual post-flash identity preservation remains a Gate-1 checkpoint.

## First boot

**OFFLINE-CONFIRMED:** V1.1.0.12 invokes `mount_mmc_ext4.sh` for p9 and p10.
On mount failure it runs `mke2fs` for the complete partition.

- p9 is recreated as ext4 and mounted as `/overlay`;
- p10 is recreated as ext4 and mounted as `/usr/data`.

The B-side p4/p6/p8 remains empty until a later OTA transaction fills it.

## Accepted unresolved p1 risk

The recovery erases p1 and writes no replacement selector. The boot payload
contains both A- and B-root boot arguments plus `ota:kernel2`, strongly supporting
the model that `ota:kernel2` selects B and a non-matching selector selects A.

The direct MIPS control flow for an erased/all-`0xff`/invalid selector has not been
fully resolved. This is now an explicitly accepted residual risk and must remain
visible in manual recovery review.

## Backup and offline preflight

Two physically separate copies of the complete raw user-area backup have been
re-read and verified against the same privately recorded SHA-256.

A private offline preflight under `local/` re-verifies the vendor archive, erase
policy, active payloads, SPL/U-Boot identity, GPT geometry, p2 preservation map,
p9/p10 first-boot evidence, and both raw backup copies.

Current result:

```text
READY FOR MANUAL RECOVERY REVIEW
NOT READY TO FLASH
```

No preflight failure remains. Known warnings are the accepted p1 selector risk,
partial physical erase of p10, and empty B slots after recovery.

The private recovery set also includes a current pre-recovery configuration
snapshot. It preserves the active printer and Moonraker configuration, active
includes, Creality user configuration, and calibration-relevant settings such as
bed mesh, input shaper, heater PID, PR-touch/Z compensation, and relevant motion
and macro parameters. Device-specific values remain private.

## Private Linux RAM-only client

A private client is restricted to this reference board and validates the exact
V1.1.0.12 archive, GINFO, original SPL, original Stage 2, active payloads,
write offsets, erase policy, and p2 preservation map before it can open a device.
Its Boot-ROM transport uses system `libusb-1.0` and has 22 passing offline tests.

The intended hardware sequence is deliberately finite:

```text
a108:eaef -> X2000 -> GINFO -> original SPL -> PROGRAM_START1 -> 1100 ms
-> original Stage 2 -> CACHE_FLUSH -> PROGRAM_START2
-> RAM_ONLY_STAGE2_READY -> close -> STOP
```

It sends no Stage-2 request. In particular `CONFIG`, `INIT`, `READ`, `WRITE`,
MMC/eMMC access, erase, and persistent writes are outside RAM-only. The client
has not been run against hardware; SPL and Stage 2 have not been started on the
reference board by this client.

## Current boundary

Static/offline preparation is sufficient for manual recovery review and for a
separately authorized RAM-only hardware validation on this reference board.

The next necessary action is only the hardware RAM-only validation. It requires
explicit user authorization, must stop at `RAM_ONLY_STAGE2_READY`, and must not
continue to `CONFIG`. `CONFIG` and `INIT` remain **UNKNOWN / AUTHORIZATION
REQUIRED**, not classified as persistent. The Linux last safe stop is immediately
before `CONFIG` request `0x14`; destructive recovery is neither ready nor
authorized.

Gate 1 remains open until destructive recovery is demonstrated and the reference
board boots stock V1.1.0.12 with identity preserved or safely restored.
