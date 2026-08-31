# Moonraker runtime bring-up — current state

Status date: 2026-08-31

## Purpose

This document records the current Moonraker runtime bring-up state for Fre3nder
2026.2.

It documents demonstrated behavior and known blockers only. It does not define
the final managed-application packaging model or the final dependency-version
strategy.

The release requirements remain defined by `requirements-2026.2.md`.
In particular, REQ-2026.2-002 and REQ-2026.2-003 are not yet complete: the
generic managed-application layer, Moonraker service integration, application
update, and rollback behavior have not yet been implemented.

## Current architecture under test

The current prototype separates the base Python runtime from temporary
Moonraker bring-up material.

The Fre3nder system provides Python 3.11.6. Additional runtime modules and
libraries used during bring-up are currently staged under:

```text
/opt/fre3nder/prototype-python/
├── python/
├── python/lib-dynload/
└── lib/
```

The prototype Moonraker requirements are staged separately under:

```text
/opt/fre3nder/prototype-moonraker/
```

Temporary pip/build data is deliberately kept outside `/tmp` under:

```text
/home/fre3nder/tmp/moonraker/
├── tmp/
├── pip-cache/
└── ...
```

This layout is prototype-only and is not yet the final managed-application
layout required by REQ-2026.2-002.

## Base Python runtime

The Buildroot configuration now enables the Python functionality required by
the Moonraker investigation, including:

```text
BR2_PACKAGE_PYTHON3_PYEXPAT=y
BR2_PACKAGE_PYTHON3_SQLITE=y
BR2_PACKAGE_PYTHON_PIP=y
BR2_PACKAGE_CA_CERTIFICATES=y
```

A stale incremental CPython build initially left `pyexpat`, `_sqlite3`, `_ssl`,
and related modules disabled despite the Buildroot configuration.

After a targeted `python3-dirclean` followed by a Python rebuild, the target
runtime was validated on hardware with:

* Python 3.11.6;
* SSL using OpenSSL 3.0.12;
* SQLite using SQLite 3.42.0;
* XML/Expat support;
* functional `venv`;
* functional pip.

HTTPS dependency resolution additionally depends on the system clock being
valid. The current `S45fre3nder-time` prototype uses BusyBox `ntpd` after
network configuration and has demonstrated correction of the system clock
without writing the RTC.

## Target resource constraint

The reference X2000 system has approximately 244 MiB RAM and currently has no
swap.

This is sufficient for normal Python execution and pip dependency resolution,
but it is not sufficient for several modern Python source builds.

Target-side source builds therefore cannot be assumed to be a valid deployment
mechanism.

The first reproducible failure was Pillow, where pip source compilation was
terminated by the OOM killer with the Python process using approximately
194 MiB RSS.

A later PyYAML 6.0.3 metadata/build step was likewise terminated while Cython
was processing `yaml/_yaml.pyx`.

These failures established that source compilation of arbitrary Moonraker
dependencies on the printer is not an acceptable baseline.

## Buildroot cross-built runtime packages

The following packages have now been added to the Fre3nder Buildroot
configuration or investigated through its existing package infrastructure.

### Pillow

Configured as:

```text
BR2_PACKAGE_PYTHON_PILLOW=y
```

Buildroot 2023.08.3 provides Pillow 10.0.0, which satisfies the currently pinned
Moonraker requirement:

```text
pillow>=9.5.0,<=12.3.0
```

The package was successfully cross-compiled for MIPS32r2 and transferred to the
prototype runtime.

Hardware validation passed:

* `PIL` import;
* Pillow version 10.0.0;
* native `_imaging` MIPS extension load;
* pip distribution metadata recognition.

No optional image-format libraries have been added beyond those required by the
current Buildroot package. Additional formats shall only be enabled if an
actual Moonraker requirement demonstrates the need.

### PyYAML

Configured as:

```text
BR2_PACKAGE_PYTHON_PYYAML=y
```

Buildroot 2023.08.3 provides PyYAML 6.0.1 and selects libyaml.

The package and libyaml were successfully cross-compiled and transferred to the
prototype runtime.

Hardware validation passed:

* PyYAML 6.0.1 import;
* native MIPS `_yaml` extension load;
* `yaml.__with_libyaml__ == True`;
* `CLoader` availability;
* successful `safe_load()` test;
* pip distribution metadata recognition.

The runtime library dependency is provided by:

```text
libyaml-0.so.2
```

### Tornado

Configured as:

```text
BR2_PACKAGE_PYTHON_TORNADO=y
```

Buildroot 2023.08.3 provides Tornado 6.2, satisfying Moonraker's current
requirement:

```text
tornado>=6.2.0,<=6.5.8
```

The targeted Buildroot cross-build succeeded.

The resulting package contains the native:

```text
tornado/speedups.abi3.so
```

validated offline as a 32-bit little-endian MIPS32r2 shared object.

Its recorded runtime dependencies are limited to the normal target C runtime
and loader.

Transfer and runtime validation on the printer have not yet been performed.

### MarkupSafe

Configured as:

```text
BR2_PACKAGE_PYTHON_MARKUPSAFE=y
```

Buildroot 2023.08.3 provides MarkupSafe 2.1.3, satisfying Jinja2 3.1.6's
`MarkupSafe>=2.0` dependency.

The targeted Buildroot cross-build succeeded.

The resulting native extension:

```text
markupsafe/_speedups.cpython-311-mipsel-linux-gnu.so
```

was validated offline as a 32-bit little-endian MIPS32r2 shared object.

Transfer and runtime validation on the printer have not yet been performed.

## Moonraker requirements investigation

Moonraker is currently pinned to upstream commit:

```text
985c1d0bbeb90bc057d34a232c9dc3b05e0c6c8d
```

Its requirements have been staged unchanged for dependency investigation.

The current prototype pip environment also contains build tooling used only to
advance dependency analysis:

```text
setuptools 84.0.0
Cython 3.3.0
poetry-core 2.4.1
```

All three were available as platform-independent Python wheels and therefore
did not require compilation on the X2000.

They allowed pip to process the metadata for modern source distributions such
as Zeroconf.

These tools are not yet defined as required components of the final Fre3nder
runtime.

## Dependency-resolution status

With:

* the corrected Python runtime;
* Pillow 10.0.0 supplied by the prototype runtime;
* PyYAML 6.0.1 supplied by the prototype runtime;
* current build-backend tooling in the test venv;

the complete pinned Moonraker requirements now resolve successfully using:

```text
pip install --dry-run --no-build-isolation
```

The result is:

```text
PIP_RC=0
```

This demonstrates that the investigated dependency set is resolvable.

It does not demonstrate that a real target-side installation is currently
safe, because pip still selects source distributions for several packages.

At the successful dry-run, source distributions remained for at least:

```text
tornado
streaming-form-data
zeroconf
dbus-fast
MarkupSafe
```

Tornado and MarkupSafe now have successful Buildroot cross-builds as documented
above.

The remaining relevant source-build cases are:

```text
streaming-form-data
zeroconf
dbus-fast
```

## Version and packaging status

The final solution for dependencies whose suitable Moonraker versions are not
provided by Fre3nder's current Buildroot 2023.08.3 package set is deliberately
left open.

Current evidence shows that off-device cross-compilation is technically the
appropriate direction for native dependencies, because:

* native Pillow, PyYAML, Tornado, and MarkupSafe artifacts have already been
  successfully generated with the Fre3nder Buildroot MIPS toolchain;
* target-side Pillow and PyYAML source processing exceeded the practical memory
  budget;
* Moonraker's complete dependency graph can otherwise be resolved.

However, this investigation has not yet selected between:

* project-local Buildroot packages;
* a Fre3nder-owned cross-built wheel set;
* updated package definitions;
* different compatible dependency versions;
* or another reproducible off-device packaging mechanism.

That decision is intentionally deferred.

No requirement currently authorizes silently substituting dependency versions
outside the upstream Moonraker constraints merely because a different version
is convenient to build.

## Current conclusion

The Python runtime itself is no longer the primary Moonraker blocker.

The following have been demonstrated:

* required Python SSL, SQLite, XML/Expat, pip, and venv functionality;
* reliable system-time correction required for HTTPS;
* successful MIPS cross-build and hardware execution of Pillow;
* successful MIPS cross-build and hardware execution of PyYAML/libyaml;
* successful MIPS cross-build of compatible Tornado and MarkupSafe versions;
* successful full Moonraker pip dependency resolution without an OOM event.

The remaining dependency work is primarily a reproducible packaging and version
selection problem for packages not suitably supplied by the current Buildroot
release.

The generic managed-application layer, final Moonraker payload layout, service
integration, update mechanism, and rollback mechanism remain future work under
REQ-2026.2-002 and REQ-2026.2-003.
