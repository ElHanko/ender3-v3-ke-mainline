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
