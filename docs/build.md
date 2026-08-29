# Building Fre3nder

All builds are offline-oriented and operate on local source trees and ignored
build output. They do not access or modify a printer.

## X2000 host

Use [`scripts/build-x2000`](../scripts/build-x2000) with the pinned sources and
configuration under [`configs/x2000`](../configs/x2000). The container recipe
is [`build/x2000`](../build/x2000), and the source manifest is
[`configs/x2000/sources.json`](../configs/x2000/sources.json).

The resulting host image uses Linux 6.6.18-rt23, a read-only SquashFS RootFS,
`root=/dev/mmcblk0p8`, upstream Klipper at the pinned revision, and the
project's passive-UART patch. BYOF firmware and credentials remain outside the
repository and are never embedded automatically.

The ignored productive tree is organized as follows:

```text
local/production/
├── inputs/wifi/
│   ├── brcmfmac43430-sdio.bin
│   └── brcmfmac43430-sdio.txt
├── work/x2000/
└── artifacts/x2000/
    ├── full/
    ├── kernel-only/
    └── rootfs-only/
```

The default `scripts/build-x2000` invocation writes the full artifact set;
`scripts/build-x2000 --kernel-only` and
`scripts/build-x2000 --rootfs-only` select the corresponding mode-specific
directories. The two WLAN files are BYOF inputs and are checked against the
hashes recorded in [`configs/x2000/sources.json`](../configs/x2000/sources.json).

## F005 MCU and host helper

The containerized MCU recipe is [`build/klipper-f005`](../build/klipper-f005).
It builds raw Klipper firmware and can package the F005 candidate with
[`scripts/package_f005_firmware.py`](../scripts/package_f005_firmware.py).
The recipe also builds the X2000 `c_helper.so` from the selected Klipper
source. It is a build procedure only; flashing and serial targets are outside
its scope.

The validated source, version, and license basis are recorded in
[`docs/licensing-and-provenance.md`](licensing-and-provenance.md).

For the complete historical first-print reproduction, including the older
staged candidates, see
[`research/docs/f005-first-print-reproduction.md`](../research/docs/f005-first-print-reproduction.md).
