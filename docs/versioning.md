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
Mainline-F005 print without stock Klippy. SDIO WLAN including firmware/NVRAM is an
important integrated candidate, but a later qualified USB-Ethernet adapter may
provide the network path instead.

Moonraker, Mainsail, local display/touch, camera, ADXL/Input Shaper, Bluetooth,
a consumer installer, automatic updates, and hardware-validated stock return are
outside `2026.1`. Network plus SSH is not optional: a printable but unreachable
host fails this scope.

Development builds have no public `version`. They carry `release_target`,
`release_scope`, project commit, source/config/patch identities, and artifact
hashes in their build manifest. Published artifacts additionally carry `version`,
numeric `release_year` and `release_number`, and `release_stage` (`alpha`,
`beta`, `rc`, or `final`). Defining the target does not assign `2026.1.a`.
