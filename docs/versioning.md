# Public release versioning

This project does not use SemVer. Public releases use `YEAR.RELEASE[.STAGE]`.
`YEAR` is the calendar-year line and `RELEASE` is its numeric public counter,
restarting at 1 each year. The only optional stages are `a` (alpha), `b` (beta),
and `rc` (release candidate); no suffix is a final release. There are no extra
components such as `a1`, `rc2`, or patch-level versions.

Within a release line, the structured order is alpha, beta, release candidate,
then final. Year and release number are numeric; consumers must not compare
version strings lexicographically.

The first planned target is `2026.1`, scope ID
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

## Current development milestone

**`2026.1.a` achieved: 2026-08-23.** This is the first functional alpha of the
open X2000 host on the investigated reference system. It directly proves Linux
6.6.18-rt23 booting from Slot B (p6/p8), a read-only SquashFS RootFS on p8,
working userspace and eMMC, SDIO WLAN (`BCM43430/1`), WPA, DHCP, Dropbear,
public-key SSH, non-interactive remote commands, and the early p1 B -> A
rollback while Mainline continues from p8. The detailed evidence is in
[`x2000-ab-bringup-plan.md`](x2000-ab-bringup-plan.md).

The subsequent Production candidate also proves USB provisioning,
Ethernet-first/WLAN-fallback operation, volatile Dropbear host-key generation,
and public-key SSH on the investigated reference system. It does not change the
remaining final-release requirements below.

`2026.1.a` does not mean that final `2026.1` requirements are met. In
particular, reliable normal SSH administration including PTYs, a final network
lifecycle and stable reachability, persistent SSH host identity, reliable normal
Mainline reboot, Mainline F005/Klipper integration on the new host, and a real
print without Stock Klippy remain required for final `2026.1`.

This alpha is a documented project/development version. It does not create a
Git tag, GitHub release, or a published distribution artifact. Development
build manifests continue to carry `release_target`, `release_scope`, project
commit, source/config/patch identities, and artifact hashes; a later published
artifact additionally carries `version`, numeric `release_year` and
`release_number`, and `release_stage` (`alpha`, `beta`, `rc`, or `final`).

## Project name

The public project identity is:

**Fre3nder**

*An open software platform for the Ender-3 V3 KE.*

Fre3nder is an independent open-source project and is not affiliated with or
endorsed by Creality. Ender and Ender-3 are trademarks of their respective
owner.

The current repository directory and historical technical identifiers may
retain `ender3-v3-ke-mainline`. The project name does not alter the `2026.1`
release criteria.
