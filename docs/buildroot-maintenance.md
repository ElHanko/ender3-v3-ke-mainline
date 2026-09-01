# Buildroot maintenance policy

The productive X2000 RootFS follows only the Buildroot `2025.02.x` LTS line.
Routine updates move between patch releases in that line, for example from
`2025.02.17` to `2025.02.18`. Quarterly stable releases such as `2026.05` or
`2026.08` are not automatic update targets.

A move to a new LTS line, such as `2027.02`, is a separate migration requiring
its own qualification. Buildroot may remove support for old external
toolchains, rename Kconfig symbols, change Python major/minor versions, alter
BusyBox, Dropbear, or wpa_supplicant behavior, or make the local XBurst2 patch
conflict or become unnecessary.

## External package patches

`BR2_GLOBAL_PATCH_DIR` is set to the project's `patches/` directory. Buildroot
therefore applies package-specific patches from
`patches/<package-name>/`, after its own package patches. The Greenlet 3.1.1
patch in `patches/python-greenlet/` is a GCC 7-only compatibility patch. It is
required because pinned Klipper `0499b30374315f2a9f49fc12808527fc7d0f5cfa`
requires Greenlet 3.1.1 when Python is at least 3.12, and the pinned Buildroot
line provides Python 3.12.14. Do not downgrade Greenlet or change Klipper's
requirement to avoid this compiler issue.

Reassess and remove the patch when the external toolchain is upgraded, or when
a Greenlet update makes it unnecessary. It is derived from MIT-licensed
Greenlet source and is intentionally separate from the GPL-licensed Buildroot
XBurst2 patch.

## Routine 2025.02.x update

For every patch release update:

1. Determine the latest `2025.02.x` LTS release from the official Buildroot
   site and resolve its official tag to the underlying commit.
2. Review `CHANGES` between the current and proposed patch release, with
   particular attention to `arch/mips`, external toolchains, Python, BusyBox,
   Dropbear, wpa_supplicant, libffi, and SquashFS.
3. Update the Buildroot version and exact commit in the build logic and
   `configs/x2000/sources.json`.
4. Run `git apply --check` for the XBurst2 patch against the new commit.
5. Check whether upstream Buildroot now supports XBurst2. If it does, remove
   the local patch instead of carrying it forward artificially.
6. Regenerate the effective Buildroot configuration from clean output.
7. Confirm the existing ABI assertions: mipsel, o32, compiler target
   mips32r2, FP64, and NaN2008.
8. Confirm the Greenlet package remains at 3.1.1 and that its GCC 7
   compatibility patch applies and builds.
9. Run `scripts/build-x2000 --rootfs-only` from clean output and execute the
   package-version, Python, ELF, and ABI checks.
10. Run exactly one complete X2000 build after the RootFS-only validation.
11. Record the change as build-validated only after those builds pass.
    Hardware validation remains a separate status and must not be inferred
    from build success.

Check for a new `2025.02.x` patch release before every Fre3nder release and at
least monthly. Prefer timely updates when a relevant security fix is available.

## Migrating to a new LTS line

A later move such as `2025.02.x` to `2027.02.x` is not a routine update. Before
that migration, reassess at minimum:

- whether Buildroot still supports the GCC 7 external toolchain;
- whether kernel headers 5.10 and the glibc toolchain remain accepted;
- whether all used Kconfig symbols still exist;
- whether the XBurst2 patch is still necessary and applies cleanly;
- whether the Greenlet 3.1.1 GCC 7 compatibility patch is still necessary;
- which Python version is provided and whether all Klipper Python dependencies
  build;
- whether `c_helper.so` remains ABI-compatible; and
- whether init, BusyBox, networking, and Dropbear behavior changes.
