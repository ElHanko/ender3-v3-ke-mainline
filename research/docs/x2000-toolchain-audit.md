# X2000 toolchain audit

## Scope and current decision

This audit originally compared the toolchain selected by the pinned X2000 SDK
commit `a98c2e1f22e4263ddd4153a4eca4db4dcfd2777b` with the smallest plausible
source-built GNU alternative while preserving the old FP64/NaN-2008 ABI. The
production migration later removed that ABI-preservation requirement.

**Current decision: migrate the X2000 userspace to upstream Buildroot's internal
toolchain with its XBurst MIPS32r2/O32/hard-float/FPXX/legacy-NaN contract.**
The vendor compiler's `-mfix-t40-x2000` behavior remains distinct from
Buildroot's `-ffp-contract=off` workaround for the historical FP64 tests below.
That no longer blocks migration: the installed vendor headers scope their
double-multiply workaround to hard-float FP64, while the selected upstream
contract uses FPXX and does not try to preserve the old ABI.

No Ingenic toolchain patch was copied or adopted. For the historical ABI/ISA
comparison: **No Ingenic toolchain patches required.** For the old X2000 FP64
workaround, the relationship between the tested mechanisms is
**`DISTINCT FOR OBSERVED CASES`**. Whether equivalent protection is required for
correct runtime behaviour on the X2000 remains `UNKNOWN`; no hardware
qualification or authoritative erratum evidence establishes that conclusion.

## Existing toolchain and target contract

The production path selects the SDK prebuilt
`prebuilts/toolchains/mips-gcc720-glibc238` (about 520 MiB in the inspected
checkout).

| Property | Existing value |
| --- | --- |
| GCC | 7.2.0; `Ingenic MIPS LINUX Tools R5.2.2 Default_xburst2_glibc2.38 Fix utmp64 2024.04-16 03:27:42` |
| binutils | 2.27 |
| libc | glibc 2.38; libc ABI note Linux 4.5.0 |
| target / sysroot | `mips-linux-gnu`; relocatable bundled sysroot |
| multilib | default plus `soft-float;@msoft-float` |
| architecture / ISA | little-endian MIPS32r2 |
| ABI | O32, GP32, 32-bit `long` |
| floating point | hard float, double precision, FP64 register mode |
| NaN encoding | IEEE 754-2008 (`nan2008`) |
| loader | `/lib/ld-linux-mipsn8.so.1` |
| notable defaults | `-mabicalls`, `-mplt`, `-mllsc`, `-mfix-t40-x2000`; MXU, MXA and MSA disabled |

The compiler specs select the `ld-linux-mipsn8.so.1` loader for O32 plus
NaN-2008. The sysroot supplies `libc.so.6`, `libgcc_s.so.1`, the loader and the
usual glibc libraries. Although GCC's configure line mentions a glibc 2.29
baseline, the shipped library and its version definitions identify glibc 2.38;
the inspected binary, not the configure string, is authoritative here.

Representative binaries from the previously qualified Buildroot 2023.08.3
RootFS all have ELF32, little-endian, O32, MIPS32r2, NaN-2008 and hard-float
FP64 attributes:

| Existing artifact | Dynamic contract |
| --- | --- |
| BusyBox | loader `ld-linux-mipsn8.so.1`; `libresolv`, `libc`, loader; symbols through `GLIBC_2.38` |
| Klipper `c_helper.so` | `libc`, loader; symbols through `GLIBC_2.34` |
| MarkupSafe `_speedups` | `libc`; symbols through `GLIBC_2.2` |

This establishes the smallest observed Fre3nder userspace contract: ELF32,
little-endian MIPS32r2, O32, hard-float FP64, NaN-2008, glibc 2.38 and
`/lib/ld-linux-mipsn8.so.1`. It does not establish MIPS32r5, MSA, MXA or MXU as
product requirements.

The kernel is a separate contract. Its effective command records already use
`-march=mips32r5 -mabi=32 -msoft-float -mnan=legacy`, as selected by the existing
kernel configuration. That is not evidence for changing the userspace ISA and
was not changed or tested as part of this audit.

## Actual vendor dependencies

Searches across the production build inputs and the active SDK/Buildroot paths
found no Fre3nder use of Ingenic builtins, MXU/MXA/MSA instructions, proprietary
assembler directives, or explicit Ingenic-only linker flags. The SDK kernel has
MXU state-support code, but the effective product configuration does not turn
that into a userspace compiler requirement. The Buildroot `xburst2` selection
also sets `BR2_GCC_TARGET_ARCH="mips32r2"`; its name alone does not cause an
XBurst compiler extension to be used.

One vendor dependency cannot be dismissed: GCC reports
`-mfix-t40-x2000 [enabled]` without an explicit build flag. For the trivial
integer executable and shared library, toggling the option produced identical
binaries. For the production Klipper source set it did not:

| Old GCC 7.2 `c_helper.so` variant | File size | `mfc1 zero,$f31` in disassembly |
| --- | ---: | ---: |
| default vendor fix | 64,616 bytes | 1,194 |
| explicit `-mno-fix-t40-x2000` | 52,696 bytes | 0 |

The default build also inserts repeated stack loads/stores around floating-point
sequences. This is executable code, not a build ID or section-order difference.
It proves that the feature is used by a real Fre3nder artifact, but not by itself
why the feature exists or whether the X2000 requires it at runtime. No hardware
test was performed.

### Controlled FP64 characterization

A follow-up offline test compared four relevant compiler cases while preserving
the established MIPS32r2/O32/hard-FP64/NaN-2008 userspace contract:

- **A:** Ingenic GCC 7.2 with its default `-mfix-t40-x2000`;
- **B:** the same compiler with `-mno-fix-t40-x2000`;
- **C:** the Buildroot GCC 12.3 candidate with normal generic MIPS32r2 codegen;
- **D:** the same GCC 12.3 candidate with `-ffp-contract=off`, the option that
  Buildroot's older `BR2_mips_xburst` wrapper adds for its documented XBurst
  fused-MADD workaround.

The small test exercised a double multiply, dependent double multiplies, a
multiply-add and dependent multiply-add operations.

Cases C and D produced byte-identical assembly for that controlled source.
Their Klipper `c_helper.so` files differed as complete ELF files, but their
`.text` sections were byte-identical: both were 40,912 bytes with SHA-256
`7d7b7b9ce08cded1f1a26f59363922070a38291ed6281d520cc68fa938eb3e54`.
Both disassemblies contained 94 `mul.d`, 135 `madd.d`, 7 `msub.d`, and zero
`mfc1 zero,$f31` instructions. Thus `-ffp-contract=off` had no observable
code-generation effect in either tested workload.

Case A was materially different from B. In the controlled test the vendor fix:

- inserted paired `mfc1 $0,$f31` sequences together with additional integer
  load/store synchronization sequences;
- replaced a simple `mul.d` with an unfused `madd.d` form using a zero-valued
  accumulator;
- similarly converted dependent double multiplications to zero-accumulating
  `madd.d` operations.

The installed vendor headers describe the affected condition as a double
floating-point multiply bug and define it for 32-bit hard-float FP64 operation
through `TARGET_X2000_FPU_BUG` / `TARGET_INGENIC_MUL_FIX`; that condition also
enables `ISA_HAS_UNFUSED_MADD4`. This is consistent with the observed
transformation, but the headers do not contain the backend implementation that
inserts the complete synchronization sequence.

The evidence therefore supports **`DISTINCT FOR OBSERVED CASES`**, not
equivalence between Buildroot's `-ffp-contract=off` handling and Ingenic's
`-mfix-t40-x2000`.

## Vendor source and provenance

The pinned SDK contains this toolchain only as a binary directory. No adjacent
source archive, patch series, build configuration, license file or exact source
revision was found. GCC's configure record points at an opaque vendor build
location and is insufficient to reconstruct the sources.

The installed GCC plugin headers expose the option, target predicates and
generated instruction availability (`madd4df` among them), but no `mips.c`,
`mips.md` or generated `insn-*.c` backend implementation is shipped. The exact
logic responsible for the observed `t40 001` / `t40 002` synchronization
sequences therefore cannot be reconstructed from this prebuilt installation.

Ingenic's [toolchain release page](https://www.ingenic.com.cn/news/nid-2.html)
documents a nearby R5.2.1.sr03 family using GCC 7.2, binutils 2.27 and glibc
2.38, as well as newer X2000-capable releases. It does not identify the exact
R5.2.2 “Fix utmp64” prebuilt or publish the `-mfix-t40-x2000` implementation used
here. The exact GCC, binutils and glibc vendor deltas and their redistribution
status therefore remain `UNKNOWN`. No public source located with proportional
search effort supplied an exact matching patch.

### Official R6.2.1 control reference

Ingenic's [R6.2.1 announcement](https://www.ingenic.com.cn/news-detail/nid-348.html)
officially publishes the XBurst2 Linux toolchain R6.2.1 as
`mips-xburst2-linux-toolchain-r6.2.1.tar.bz2`, with the release identity
`Ingenic Linux-Release6.2.1-Default_xburst2_mxu3_glibc2.38` and build timestamp
2023-10-20. Its announcement specifies GCC 12.1.0, binutils 2.39, glibc 2.38,
and applicability to X2000 and T40 among other XBurst2 parts. It also identifies
the official FTP URL:

```text
ftp://ftp.ingenic.com.cn/Ingenic-MIPS-Toolchain/releases/
ingenic-mips-toolchain-r6.2.1/mips-xburst2-linux-toolchain-r6.2.1.tar.bz2
```

No existing local or research copy was present. The official server could not
provide the archive during this audit: FTP accepted a connection but rejected
anonymous login with `500 OOPS: cannot change directory:/var/ftp/ingenic`; HTTP
and HTTPS returned `403` (the HTTPS certificate was also expired). No
third-party mirror was used, because without an official hash it would not be an
unambiguous control reference.

Consequently the R6.2.1 compiler's `-v`, `-dumpmachine`, `-dumpspecs`,
`-Q --help=target`, and code generation were **not assessed**. The release-page
list of supported GCC options contains MSA, MXA and MXU3 options, but does not
establish either the presence or absence of an unlisted `-mfix-t40-x2000`
default. It is not evidence for a code-generation conclusion.

| Property | Ingenic GCC 7.2 | Ingenic GCC 12.1 R6.2.1 | Buildroot GCC 12.3 |
| --- | --- | --- | --- |
| `-mfix-t40-x2000` known | yes | not assessed | no |
| Default active | yes | not assessed | no |
| observed workaround | FP64 MUL rewrite plus synchronization sequences | not assessed | none observed; `-ffp-contract=off` unchanged |
| `c_helper.so` `mfc1 zero,$f31` | 1,194 | not assessed | 0 |

## Upstream candidate

The pinned SDK's Buildroot 2023.08.3 tree can build its own normal GNU toolchain;
no Buildroot release change or crosstool-NG layer is needed. The isolated
configuration changed only the toolchain provider and values needed to preserve
the observed contract:

```text
BR2_TOOLCHAIN_BUILDROOT=y
BR2_TOOLCHAIN_BUILDROOT_GLIBC=y
BR2_TOOLCHAIN_BUILDROOT_CXX=y
BR2_KERNEL_HEADERS_5_10=y
BR2_GCC_TARGET_ARCH="mips32r2"
BR2_GCC_TARGET_ABI="32"
BR2_GCC_TARGET_NAN="2008"
BR2_GCC_TARGET_FP32_MODE="64"
```

This selects GCC 12.3.0, binutils 2.40 and Linux 5.10.200 headers. Buildroot's
native 2023.08.3 recipe selects glibc 2.37, which would be an unrelated libc
downgrade and would not satisfy the established glibc 2.38 contract. The
experiment therefore applied only the later official Buildroot glibc update
[commit 34f8d874](https://gitlab.com/buildroot.org/buildroot/-/commit/34f8d874eeffb8309a174d3423d8f350d68ab3eb)
to select `2.38-13-g92201f16cbcfd9eafe314ef6654be2ea7ba25675`, archive SHA-256
`06d73b1804767f83885ab03641e2a7bf8d73f0a6cf8caee4032d8d1cc2e76cce`.
That temporary audit-workspace change is an upstream Buildroot change, not an
Ingenic patch, and was not added to the repository.

All sources were fetched first with Buildroot's recorded hashes. The toolchain
was then built successfully in the normal X2000 build container with networking
disabled. No Ingenic compiler, binutils or libc sources or patches participated
in that build.

## Targeted offline comparison

The old compiler and the source-built candidate compiled the same trivial C
program, shared library and Klipper `c_helper.so` source set. The new results
were inspected with `file`, `readelf` and the MIPS `objdump`.

| Property | Existing GCC 7.2 | Buildroot GCC 12.3 candidate |
| --- | --- | --- |
| ELF / endian | ELF32 / little | ELF32 / little |
| ISA / ABI | MIPS32r2 / O32 | MIPS32r2 / O32 |
| FP / NaN | hard FP64 / NaN-2008 | hard FP64 / NaN-2008 |
| loader | `ld-linux-mipsn8.so.1` | `ld-linux-mipsn8.so.1` |
| libc | glibc 2.38 | glibc 2.38 |
| libc ABI note | Linux 4.5.0 | Linux 5.10.0 |
| trivial executable | `libc`; symbols through `GLIBC_2.34` | same; PIE is enabled by the Buildroot wrapper |
| trivial shared library | `libc`; symbols through `GLIBC_2.2` | same |
| `c_helper.so` | `libc`; symbols through `GLIBC_2.34` | `libc` and loader; symbols through `GLIBC_2.34` |
| MIPS attributes | MIPS32r2, O32, hard FP64, NaN-2008 | same |
| T40/X2000 fix | enabled and changes FP-heavy code | unavailable upstream |

The candidate satisfies the inspectable ABI/ISA contract. Bit identity is not
required, and the PIE/default-link differences are not a demonstrated problem.

The initial GCC 12.3 candidate was the generic MIPS32r2 comparison. A follow-up
test then added `-ffp-contract=off` directly, without changing the Fre3nder ABI
or switching the product configuration to Buildroot's distinct `BR2_mips_xburst`
target. That option produced byte-identical controlled FP assembly and
byte-identical Klipper `.text` compared with the generic GCC 12.3 case. It
therefore does not reproduce the observed Ingenic X2000 FP64 workaround.

MarkupSafe was not rebuilt because `c_helper.so` and the controlled FP64 cases
already exercise the material native floating-point distinction; another
package build would not resolve the missing vendor backend semantics.

## Historical validation status

- **Static analysis:** complete for compiler defaults/specs, SDK usage, existing
  BusyBox, `c_helper.so` and MarkupSafe ELF metadata, and candidate configuration.
- **Targeted offline validation:** source download/hash verification, a complete
  Buildroot-internal toolchain build under `--network none`, old/new builds of
  the requested test artifacts, controlled FP64 A/B/C/D comparisons, and exact
  `.text` comparison of the GCC 12.3 generic and `-ffp-contract=off`
  `c_helper.so` variants succeeded.
- **Official R6.2.1 control comparison:** not run because the only official
  download endpoint was unavailable as documented above. This is no longer the
  primary missing step: the current blocker is the unavailable authoritative or
  reproducible implementation semantics of the X2000 FP64 workaround.
- **Full offline X2000 build:** not run as part of the historical audit.
- **Hardware qualification:** not performed and not implied by these results.

## Upstream Buildroot 2025.02 migration validation

Pristine upstream Buildroot 2025.02.17 at commit
`d0820dd09916edcefc44e525355afbea30d5bee4` built the selected internal
toolchain successfully. The effective contract is GCC 13.4.0, binutils 2.43.1,
glibc, Linux 6.6 headers, little-endian MIPS32r2, O32, hard-float, FPXX and
legacy NaN. Buildroot's upstream XBurst wrapper supplied
`-ffp-contract=off`; `gcc -###` also showed `-march=mips32r2`, `-mabi=32`,
`-mfpxx`, and `-mnan=legacy`.

A targeted executable used `/lib/ld.so.1`. A targeted build of the pinned
Klipper `c_helper.so` produced an ELF32 little-endian MIPS32r2/O32 shared
object with the FPXX hard-float attribute and legacy NaN. Its dynamic entries
require `libc.so.6` and `ld.so.1`. These are offline build results only.

The earlier successful Buildroot 2025.02 full build with the external Ingenic
toolchain remains a control baseline; it is not evidence for this new internal
toolchain. The new contract has now passed `scripts/build-x2000 --rootfs-only`
with `ROOTFS_BUILD_RC=0` and a valid `rootfs.squashfs`. The saved effective
configuration confirms the internal Buildroot toolchain; it has no active
external-toolchain or local `xburst2` target selection.

A complete scan of that RootFS inspected 99 ELF files. All were ELF32,
little-endian MIPS32r2/O32 binaries with the FPXX hard-float attribute. No
`nan2008`, FP64 ABI, or `ld-linux-mipsn8.so.1` reference was found. Dynamic
programs use `/lib/ld.so.1`; ordinary shared objects have no `PT_INTERP`.
The directly executable glibc `libc.so.6` is the sole shared-object exception
and also names `/lib/ld.so.1`. The scan included 62 Python C extensions;
`c_helper.so` satisfies the same contract and requires `libc.so.6` and
`ld.so.1`.

The first complete offline X2000 product build has also passed with
`FULL_BUILD_RC=0`. Its build manifest, effective Buildroot and kernel
configurations, DTB, kernel image, and RootFS all passed their recorded
integrity checks. This establishes reproducible offline build validation of the
new userspace contract. It does not establish boot, peripheral, printing, or
any other hardware behavior, and it does not authorize deployment or hardware
testing.

The F005 build container remains a separate Ingenic-toolchain consumer solely
for reproducing the historical `c_helper.so` used with the Stock X2000
userspace. It is not an input to the Fre3nder RootFS. Replacing or retiring that
Stock-ABI reproduction helper is **`REQUIRED` before claiming repository-wide
elimination of Ingenic userspace toolchains**, but it is not a blocker for the
new Fre3nder userspace contract and should not be folded into the RootFS
migration without a separately defined reproduction requirement.
