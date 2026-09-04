# Fre3nder 2026.2 requirements (Lastenheft)

## Purpose

Fre3nder `2026.2` is the planned **Usable System** release.

`2026.1` established that the investigated Ender-3 V3 KE can boot and print
reliably on the open Fre3nder X2000/Klipper platform. `2026.2` adds the
persistent runtime, application, API, web-UI, and local display layers required
for normal day-to-day operation without SSH being the primary user interface.

This document defines release requirements. Implementation details may evolve
while preserving these requirements.

## Release boundary

A final `2026.2` must provide:

- reliable persistent user and application state;
- clean volatile runtime storage;
- a managed persistent application layer;
- Moonraker as the supported API layer;
- OctoApp integration;
- a frontend-neutral web-UI mechanism;
- Fluidd as the first qualified reference frontend;
- local display and touch operation of the selected frontend;
- preservation of the established Fre3nder printing and recovery boundaries.

Camera support, ADXL/Input Shaping, seamless Stock handoff, and qualification
of every possible web frontend are not release requirements unless later
evidence makes one of them necessary for the usable-system goal.

## REQ-2026.2-001 - Filesystem and persistence contract

Status: **OFFLINE IMPLEMENTED / PARTIALLY HARDWARE QUALIFIED**

Fre3nder shall use three logical filesystem roles independent of concrete device
names or partition numbers:

- an immutable SquashFS RootFS as the read-only OverlayFS lower layer;
- system persistence whose normal payload consists of the OverlayFS
  `upper` and `work` directories, with only explicitly defined boot-control
  metadata such as the authorized reset marker outside those directories; and
- userdata persistence mounted at `/home`.

The current external Development backend resolves the system-persistence role
from the unique ext4 filesystem labelled `FRE3NDERSYS` and the userdata role
from the unique ext4 filesystem labelled `FRE3NDERHOME`. Future internal
backends may assign these roles to p9 and p10 respectively, but the root setup
shall not depend on those partition numbers.

During a normal boot, `/` shall be the writable OverlayFS, `/rom` shall expose
the unchanged immutable lower filesystem, and `/home` shall expose userdata
persistence. System paths including `/etc`, `/opt`, `/usr`, and `/var` are
therefore retained across a normal reboot but intentionally discarded when
system persistence is reset for a firmware upgrade. Upgrade-persistent user and
desired application state belong under `/home`.

Upgrade-persistent printer configuration and Klipper logs are userdata. The
current Klipper integration uses
`/home/fre3nder/printer_data/config/printer.cfg` as its runtime configuration
source and `/home/fre3nder/printer_data/logs/klippy.log` for its persistent log.
The immutable system supplies
`/usr/share/fre3nder/defaults/printer.cfg` only as an initial default: it may
seed a missing userdata configuration but shall never overwrite an existing
userdata `printer.cfg`.

At minimum:

- `/run` shall provide volatile boot-session runtime state;
- `/tmp` shall provide volatile temporary storage;
- compatibility paths such as `/var/run` and `/var/lock` shall have defined
  writable behavior;
- `/var/tmp`, logs, and caches shall each have an explicit persistence policy;
- `/var/run` and `/var/lock` shall resolve to `/run` locations while `/var`
  itself remains normal system state in the OverlayFS;
- normal services shall not require writes to the SquashFS lower filesystem;
- the writable root shall be activated only after both persistence roles have
  been uniquely identified as ext4 and mounted successfully;
- unavailable, invalid, or ambiguous persistence shall retain the immutable
  root in a degraded diagnostic boot, without a RAM upper or `/home` fallback;
- persistence-dependent services shall not start in that degraded boot; and
- boot shall never run automatic filesystem repair or formatting as a response
  to a persistence error.

System persistence may be reset only when its filesystem is uniquely identified,
successfully mounted, and contains the explicit `RESET_ON_NEXT_BOOT` marker.
The reset discards and recreates only `upper` and `work`; an interrupted reset is
safe to repeat while the marker remains present. A mount or identification error
does not authorize deletion.

Acceptance requires offline validation followed by qualification of normal
reboot persistence, a marker-authorized system reset with `/home` retained, and
degraded boots for missing or invalid system and userdata backends.

### Hardware qualification status

The external Development persistence backend has been partially qualified on
the reference device.

Demonstrated on real hardware:

- successful activation of the writable OverlayFS root using `FRE3NDERSYS`;
- successful direct mounting of `FRE3NDERHOME` at `/home`;
- `/rom` remaining the immutable read-only SquashFS lower filesystem;
- persistence of normal system changes across a Fre3nder-to-Fre3nder reboot;
- persistence of userdata under `/home` across the same reboot;
- reuse of the persistent Dropbear host identity from `/home`;
- fail-closed degraded boot when persistence activation cannot be completed;
- continued diagnostic SSH availability in that degraded state; and
- no fallback to or mounting of Stock p9/p10.

The marker-authorized system-persistence reset with `/home` retained is now
qualified on the reference device. Explicit missing or invalid system- and
userdata-backend cases remain to be qualified before REQ-2026.2-001 is
complete.

## REQ-2026.2-002 - Managed application layer

Status: **PLANNED**

Fre3nder shall provide a generic managed application layer. Reconstructible
application code is installed into the writable system OverlayFS; desired state
that must survive a platform upgrade is stored under a defined Fre3nder-owned
location in `/home`.

Managed applications shall be installable and updateable independently of the
kernel and RootFS.

The application model shall support:

- explicit application identity and version;
- an active application version;
- replacement without modifying the immutable RootFS;
- rollback to a previously retained compatible version;
- separation of application code from persistent configuration and state;
- deterministic service startup through a Fre3nder-controlled system
  interface;
- detection of missing or invalid application payloads.

The mechanism shall be generic and shall not be designed exclusively around
Moonraker.

## REQ-2026.2-003 - Moonraker integration

Status: **PARTIALLY IMPLEMENTED / PARTIALLY HARDWARE QUALIFIED**

Moonraker shall be the supported API and application-management boundary above
Klipper.

Each Fre3nder platform release shall carry a qualified stable Moonraker
baseline, its Python environment, runtime dependencies, and service integration
in the immutable RootFS. Later Moonraker source and environment updates may be
stored by OverlayFS in the writable system upper.

Moonraker shall have persistent configuration and state independent of its
application code and Python environment.

Qualification shall demonstrate:

- clean service start and stop;
- expected dependency and readiness behavior relative to Klipper;
- API availability over the qualified network path;
- persistence of an application update across reboot;
- recovery of the RootFS baseline through a system-overlay reset;
- Moonraker self-update without taking ownership of Fre3nder platform
  components; and
- defined behavior when the Moonraker baseline, environment, or persistent
  state is missing or invalid.

Failure of the Moonraker application layer shall not silently modify or replace
the Fre3nder base platform.

Reference hardware qualifies the pinned Moonraker runtime and dependency set,
real startup, local HTTP API, network discovery, volatile Moonraker UDS,
persistent configuration, ready Klippy connection, and S60 readiness through a
natural boot. The fixed RootFS source and Python-environment construction is
implemented but not yet built or hardware-qualified. Self-update remains
incomplete until its dependency behavior and automatic post-update S61 restart
are integrated and qualified.

## REQ-2026.2-004 - Update ownership boundary

Status: **PARTIALLY IMPLEMENTED / PARTIALLY HARDWARE QUALIFIED**

Fre3nder shall distinguish platform updates from managed-application updates.

The application/update layer may manage approved persistent applications and
web frontends, including Moonraker, OctoApp, Fluidd, and compatible
alternatives.

It shall not independently replace or modify:

- the Fre3nder kernel;
- the immutable Fre3nder RootFS;
- the Fre3nder-controlled Klipper host build;
- X2000 A/B selection or partition contents;
- F005 MCU firmware.

Those components remain under explicit Fre3nder build, deployment, and
qualification control.

A generic user-facing application update action must therefore not imply a
platform, boot-slot, or MCU update.

The default Moonraker configuration disables system updates. Its RootFS source
tree is a Git repository, while Fre3nder Klipper intentionally is not; the
pinned updater therefore does not create a Git deployer for Klipper. S61 has no
platform, boot-slot, MCU, or system-package update operation. Moonraker's own
source/environment self-update and restart lifecycle remains only partially
implemented and is not yet qualified.

## REQ-2026.2-005 - OctoApp integration

Status: **PLANNED**

Fre3nder shall support OctoApp through the local Moonraker API as a managed
application/integration.

The OctoApp integration shall:

- install without rebuilding the RootFS;
- persist across normal reboot;
- start through the managed application/service model;
- communicate with the local Moonraker instance;
- be disableable or removable without changing the Fre3nder base platform;
- support an application-level update path consistent with the update ownership
  boundary.

OctoApp is the second reference application and shall demonstrate that the
managed application model is not specific to Moonraker itself.

## REQ-2026.2-006 - Frontend-neutral UI layer

Status: **PLANNED**

Fre3nder shall provide a persistent frontend-neutral UI layer.

The immutable RootFS shall not hard-code Fluidd as the Fre3nder user
interface.

The system shall support an explicitly selected active frontend and shall allow
a compatible frontend to be replaced without rebuilding the kernel or RootFS.

Frontend application files and user-specific frontend state shall remain
outside the immutable RootFS.

The local display integration shall consume the selected active frontend rather
than containing Fluidd-specific control logic.

## REQ-2026.2-007 - Fluidd reference frontend

Status: **PLANNED**

Fluidd shall be the first web frontend qualified for `2026.2`.

Qualification shall demonstrate:

- installation into the persistent UI/application layer;
- access through the qualified LAN path;
- successful connection to the local Moonraker API;
- printer status and control through Moonraker;
- persistence across reboot;
- independent frontend update or replacement without a RootFS deployment.

Support for alternative compatible frontends is an architectural requirement;
hardware qualification of multiple frontends is not required for `2026.2`.

## REQ-2026.2-008 - Display, touch, and local presentation

Status: **PLANNED**

Fre3nder shall provide an open local display path for the printer's integrated
display.

The implementation shall cover the hardware and system functions required for
normal local operation, including:

- display output;
- touch input;
- backlight control;
- required kernel and Device Tree integration;
- a local presentation or kiosk layer capable of opening the selected active
  frontend.

The display stack shall not couple printer control directly to Fluidd-specific
internals. Printer control shall continue through Moonraker and Klipper.

The system shall remain administratively reachable if the local UI cannot
start.

## REQ-2026.2-009 - Integrated usable-system qualification

Status: **PLANNED**

A final `2026.2` candidate shall be qualified as one integrated system on the
investigated reference device.

The qualification shall demonstrate at minimum:

- normal Fre3nder boot;
- correct immutable/persistent/volatile filesystem behavior;
- retained persistent configuration across reboot;
- healthy Klipper startup and expected F005 communication;
- healthy Moonraker startup and API availability;
- successful operation through the reference web frontend from the LAN;
- successful OctoApp integration;
- successful local display and touch operation;
- successful operation of the selected active frontend on the local display;
- one real print initiated and monitored through the `2026.2` user-facing
  stack;
- normal reboot followed by restoration of the usable state;
- no unintended modification of Stock A, the immutable RootFS, or
  Fre3nder-controlled MCU/platform components by the application update layer.

Completion of this requirement establishes the `2026.2 Usable System`
functional milestone. Creation of the final release tag remains a separate
release action under `docs/versioning.md`.

## Requirement discipline

Each requirement remains `PLANNED` until implementation and the required
validation evidence exist.

Offline tests may establish `OFFLINE CONFIRMED` where appropriate but do not
authorize or imply hardware qualification.

Hardware-changing qualification remains separately authorized under
`AGENTS.md`.

Requirements may be refined when implementation evidence exposes a real
constraint, but release scope shall not expand merely because additional
features would be useful.
