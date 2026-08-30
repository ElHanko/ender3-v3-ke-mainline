# Installing and updating Fre3nder

The current RootFS deployment tool is
[`scripts/deploy-x2000-rootfs`](../scripts/deploy-x2000-rootfs). Without
`--write` it performs a read-only preflight. The `--write` mode is an explicit
persistent-operation boundary and requires the operator's separate
authorization and risk acceptance described by `AGENTS.md`.

The tool verifies the artifact, target partitions, selector state, and full
RootFS read-back. It does not authorize unrelated kernel, partition, MCU, or
printer changes. The current build/deployment contract is summarized in
[`docs/x2000-open-host-architecture.md`](x2000-open-host-architecture.md).

The established bounded p1 selector helper is
[`scripts/x2000-ab`](../scripts/x2000-ab). The external BootROM selector
fallback is [`scripts/x2000-usb-selector-to-a`](../scripts/x2000-usb-selector-to-a).
Neither tool is a general recovery guarantee.

## Reference-system deployment qualification

On 2026-08-30 the existing deployment path was exercised successfully with
the untagged current-main build `2026.1-1-gc4c6fa1` from project commit
`c4c6fa18e659a82ada32c708720202a5ad6592ac`.

The deployed `rootfs.squashfs` was 31760384 bytes with SHA-256
`5ac3a01985789476f0db73fbb2091f3b7fbfcce98578392c6c7c1f14abfbddf2`.
The helper booted Stock A, wrote Slot-B p8, performed a full artifact-length
readback with an exact SHA-256 match, selected B, booted the newly written
read-only SquashFS, and finally restored the selector to `STOCK_A`.

Post-boot checks confirmed active p8, read-only SquashFS, both expected
persistence bindings, the expected F005 product files and manifest, absence of
`mcu_util` from the immutable RootFS, and active Klipper. This qualification
applies to the investigated reference system and does not turn the untagged
current-main build into a new public release.
