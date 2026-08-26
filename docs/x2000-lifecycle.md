# X2000 prototype lifecycle contract

This defines future work only. Gate 1 is satisfied by the current evidence
review; vendor recovery remains documented but not personally rehearsed and is
not guaranteed. Persistent or hardware-changing work is red-zone and requires
explicit authorization.

## BUILD

`scripts/build-x2000-prototype` produces pinned kernel, project DTB, minimal squashfs,
effective configs, and hashes in ignored local storage. The generic image has no
credentials. Its explicit `--provision` form uses only ignored local inputs and
writes a separately ignored private development artifact; it is still a BUILD
operation, not an installation. No device is a build target.

## INSTALL and UPDATE (future contracts)

An authorized installer must identify the target from the approved local record, verify
backup/hashes and the exact inactive target, preserve boot and identity data, stop on
mismatch, write only the approved inactive slot, read it back, hash it, and make one
bounded boot attempt. An update must verify authenticated manifest, provenance,
compatibility, and hashes; stage kernel/rootfs together; preserve the active slot; and
roll back after failed health confirmation.

The A/B compatibility intent is kernels p5/p6 and rootfs p7/p8; this is not a
new GPT proposal. p9/p10 are `UNKNOWN / RESERVED`. The later writable-overlay
and persistent-data design must not assign them until separate evidence and a
separate decision exist. Phase 3.3a grants no partition ownership.

## BACK TO STOCK and USB boundary

Return to stock must use validated material/method for the exact device without publishing
firmware, identity data, credentials, or private paths. Until it is demonstrated, it is a
route with uncertainty, not a guarantee.

Linux USB roles exist only where the appliance needs them. BootROM USB recovery is independent
and must not depend on Linux USB host support. The later Develop Production path
selects the hardware-validated external AX88179B/CDC-NCM adapter as its
Ethernet-first administrative path, with SDIO WLAN as boot-time fallback. This
does not change the historical prototype's lifecycle contract.
