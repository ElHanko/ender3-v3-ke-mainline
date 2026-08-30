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

Status: **PLANNED**

Fre3nder shall define a clear contract between immutable system content,
persistent state, and volatile runtime state.

The immutable SquashFS RootFS shall remain read-only during normal operation.

Persistent configuration, application payloads, application state, user data,
and system-owned persistent data shall have explicit locations under
`/persist`.

Volatile runtime state shall not be stored in persistent application or user
directories merely because the RootFS is read-only.

At minimum:

- `/run` shall provide volatile boot-session runtime state;
- `/tmp` shall provide volatile temporary storage;
- compatibility paths such as `/var/run` and `/var/lock` shall have defined
  writable behavior;
- `/var/tmp`, logs, and caches shall each have an explicit persistence policy;
- normal services shall not require writes to the SquashFS RootFS;
- startup behavior with unavailable or invalid persistence shall be defined and
  fail predictably rather than silently using the immutable RootFS as writable
  storage.

Acceptance requires offline validation followed by qualification across a
normal Fre3nder reboot.

## REQ-2026.2-002 - Managed application layer

Status: **PLANNED**

Fre3nder shall provide a generic persistent application layer rooted under
`/persist/apps`.

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

Status: **PLANNED**

Moonraker shall be the supported API and application-management boundary above
Klipper.

The Moonraker application payload shall live in the persistent managed
application layer rather than being permanently embedded as application code in
the immutable RootFS.

Fre3nder may provide the system launcher, runtime dependencies, compatibility
metadata, and service integration required to start Moonraker.

Moonraker shall have persistent configuration and state independent of its
application payload.

Qualification shall demonstrate:

- clean service start and stop;
- expected dependency and readiness behavior relative to Klipper;
- API availability over the qualified network path;
- persistence across reboot;
- application update;
- rollback;
- defined behavior when the active Moonraker payload is missing or invalid.

Failure of the Moonraker application layer shall not silently modify or replace
the Fre3nder base platform.

## REQ-2026.2-004 - Update ownership boundary

Status: **PLANNED**

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
