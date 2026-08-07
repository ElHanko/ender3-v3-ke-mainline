# Ender-3 V3 KE mainline investigation

This project documents the Creality Ender-3 V3 KE platform and investigates a
possible migration from Creality's Klipper fork to current upstream Klipper.

The current phase is inventory and reverse engineering. Work on a physical printer
is read-only by default; migration, flashing, and recovery procedures are analysis
only until a task explicitly authorizes them.

Start with:

- [`docs/system-inventory.md`](docs/system-inventory.md) for the reference-system
  inventory;
- [`docs/storage-layout.md`](docs/storage-layout.md) for eMMC and A/B layout;
- [`docs/klipper-stock.md`](docs/klipper-stock.md) for the Creality Klipper delta;
- [`docs/recovery-analysis.md`](docs/recovery-analysis.md) and
  [`docs/backup-plan.md`](docs/backup-plan.md) for future safety work.

Agent safety and documentation rules are in [`AGENTS.md`](AGENTS.md). Copy
[`docs/local-device.example.md`](docs/local-device.example.md) to the ignored
`docs/local-device.md` for local printer/workstation identifiers. Never store
secrets in either file.
