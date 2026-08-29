# Public release versioning

This project does not use SemVer. Public releases use `YEAR.RELEASE[.STAGE]`.
`YEAR` is the calendar-year line and `RELEASE` is its numeric public counter,
restarting at 1 each year. The only optional stages are `a` (alpha), `b` (beta),
and `rc` (release candidate); no suffix is a final release. There are no extra
components such as `a1`, `rc2`, or patch-level versions. The canonical spelling
uses a four-digit nonzero year and a positive release number without leading
zeroes.

The repository-root [`VERSION`](../VERSION) file is the canonical source of the
project version. Release tags use exactly that version number, without a `v`
prefix. The first final release version is `2026.1`. Setting or changing
`VERSION` does not by itself create a Git tag or GitHub release.

Build manifests record the canonical `version`, numeric `release_year` and
`release_number`, the normalized `release_stage` (`alpha`, `beta`, `rc`, or
`final`), and `release_scope`. Built RootFS images expose the same canonical
project version in `/usr/share/fre3nder/VERSION`.

Within a release line, the structured order is alpha, beta, release candidate,
then final. Year and release number are numeric; consumers must not compare
version strings lexicographically.

The first release target is `2026.1`, scope ID
`first-printable-networked-open-host`, titled **First printable networked
open-host release**. A final `2026.1` means this scope is complete, not that the
whole roadmap or Gate 1 is complete. It requires reliable open-host boot,
required SMP/CPU and filesystem operation, at least one qualified administrative
network path, stable IP configuration, reliable SSH administration, persistent SSH
host identity, and network/SSH usable after normal reboot, and a reliable real
Mainline-F005 print without stock Klippy. The current hardware-validated
Production path uses an external AX88179B/CDC-NCM Ethernet adapter first and
provisioned SDIO WLAN as boot-time fallback.

Moonraker, Mainsail, local display/touch, camera, ADXL/Input Shaper, Bluetooth,
a consumer installer, automatic updates, and hardware-validated stock return are
outside `2026.1`. Network plus SSH is not optional: a printable but unreachable
host fails this scope.

## Current functional milestone

**`2026.1.a` achieved: 2026-08-23.** This is the historical first functional alpha of the
open X2000 host on the investigated reference system. It directly proves Linux
6.6.18-rt23 booting from Slot B (p6/p8), a read-only SquashFS RootFS on p8,
working userspace and eMMC, SDIO WLAN (`BCM43430/1`), WPA, DHCP, Dropbear,
public-key SSH, non-interactive remote commands, and the early p1 B -> A
rollback while Mainline continues from p8. The detailed evidence is in
[`x2000-ab-bringup-plan.md`](../research/docs/x2000-ab-bringup-plan.md).

The subsequent Production candidate also proves USB provisioning,
Ethernet-first/WLAN-fallback operation, volatile Dropbear host-key generation,
and public-key SSH on the investigated reference system. A subsequent read-only
qualification additionally proves interactive SSH PTY allocation and shell
operation. A later Development candidate qualifies the `/persist/system` and
`/persist/userdata` mounts, persistent Dropbear host identity across a normal
Develop-B -> Develop-B reboot, and SSH administration becoming available again
after that reboot on the investigated reference system. The same persistent key
was verified as both Dropbear's configured key and the key presented over SSH.

**`2026.1 FUNCTIONALLY ACHIEVED: 2026-08-29.`** The complete Fre3nder-B print
without Stock Klippy finished successfully on the investigated reference device.
It ran with the then-unmodified 1.900 image configuration plus temporary
`SET_GCODE_OFFSET Z=-0.280`, establishing the effective 2.180 probe offset;
the separate tracked configuration now records `z_offset: 2.180`, **QUALIFIED
ON DEVICE** for that reference device. The complete Stock/Fre3nder roundtrip is
not a 2026.1 release blocker: the software-only Fre3nder-to-Stock handoff still
**REQUIRES QUALIFICATION**, while manual power-cycle recovery is qualified on
the reference device. General persistent configuration and runtime/hotplug
network failover likewise remain later work. Persistent SSH identity and normal
reboot with SSH are qualified only on the investigated Development USB-adapter
Develop-B -> Develop-B path.

This functionally achieved milestone is a documented project/development
milestone. It did not create a Git tag, GitHub release, or a published
distribution artifact. During release preparation, build manifests carry the
structured version fields documented above together with project commit,
source/config/patch identities, and artifact hashes.

## Project name

The public project identity is:

**Fre3nder**

*An open software platform for the Ender-3 V3 KE.*

Fre3nder is an independent open-source project and is not affiliated with or
endorsed by Creality. Ender and Ender-3 are trademarks of their respective
owner.

The canonical repository name is `fre3nder`. Historical technical identifiers
may retain former development names where required to preserve provenance or
recorded evidence. The project name does not alter the `2026.1` release
criteria.
