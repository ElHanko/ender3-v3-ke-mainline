# Developing Fre3nder

Use the pinned source manifests and the build recipes in
[`docs/build.md`](build.md). Productive code and configuration live in
`build/`, `configs/`, `patches/`, `scripts/`, and `tests/`; research and new
hardware investigation live under [`research/`](../research/).

The repository provides offline fixture checks for the Klipper integration,
service lifecycle, persistence, storage, network, deployment, and selector
contracts. Run the relevant scripts from the repository root; they use ignored
local inputs where a source checkout or BYOF artifact is required.

Changes to productive paths must not introduce a dependency on `research/`.
Preserve qualification labels, provenance, hashes, and the distinction between
reference-device observations and general support claims.

Versioning rules are in [`docs/versioning.md`](versioning.md). The complete
historical development record remains available in
[`research/docs/`](../research/docs/).
