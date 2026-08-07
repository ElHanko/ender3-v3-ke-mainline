# Licensing and provenance policy

This project combines original documentation and tooling with analysis of
third-party open-source and vendor software.

The repository must remain reproducible without unnecessarily redistributing
third-party firmware, proprietary binaries, or device-specific data.

This document is a project policy, not legal advice.

## General rule

Do not commit or redistribute a third-party artifact unless its origin and
redistribution rights are understood.

When redistribution rights are unclear, prefer:

- an official source link;
- version and filename;
- cryptographic hashes;
- documentation describing the artifact;
- a locally executed import/extraction process;
- patches against publicly licensed source;
- an independently written implementation of required behavior.

## Upstream Klipper

Policy:

- preserve upstream license and copyright notices;
- record exact upstream revisions used for comparisons and builds;
- publish modifications according to the applicable upstream license;
- prefer patches or clearly maintained source history.

## Public Creality Klipper source

Creality publishes Ender-3 V3 KE Klipper source under the GPL.

Policy:

- preserve applicable copyright and license notices;
- document the exact source revision used;
- keep vendor modifications distinguishable from project-written changes;
- comply with applicable GPL requirements when distributing derived source.

The license of the public Klipper source repository must not automatically be
assumed to apply to unrelated files contained in complete Creality firmware
images.

## Creality firmware packages

Examples include official firmware images and OTA bundles.

Policy:

- do not commit them unless redistribution permission has been verified;
- link users to the official source where possible;
- record filename, version, source, size, and cryptographic hash;
- allow project tooling to consume user-supplied firmware files locally.

The preferred workflow is "bring your own firmware": users obtain vendor
firmware from its original source and project tooling processes the local file.

## Extracted vendor binaries

Examples may include:

- Creality application servers;
- display binaries;
- upgrade binaries;
- vendor-specific shared libraries;
- compiled Python extension modules.

Policy:

- do not commit extracted binaries where redistribution rights are unclear;
- record names, hashes, architecture, dependencies, and interfaces where useful;
- associate them with their source firmware through provenance metadata;
- prefer replacement with open components where practical.

## Vendor-specific binary Klipper extensions

Vendor-specific binary modules may be technically important even when their
redistribution status is unclear.

Policy:

- do not publish a binary merely because it was found in a firmware image;
- document how it is loaded and which interfaces it exposes;
- identify corresponding publicly available source where it exists;
- distinguish observed behavior from copied implementation;
- prefer an open implementation of required functionality where feasible.

## Device backups

Examples include:

- complete eMMC images;
- boot0 and boot1 captures;
- partition images;
- `/overlay` archives;
- `/usr/data` archives.

Policy:

- never commit device backups;
- treat them as private recovery material;
- store hashes and non-identifying technical metadata separately where useful;
- protect backup media because it may contain credentials, certificates,
  network settings, print history, and other private data.

## Factory and identity data

Examples include:

- serial numbers;
- MAC addresses;
- factory identity partitions;
- pairing information;
- certificates;
- device-specific keys.

Policy:

- never publish concrete values;
- do not copy identity data between printers;
- keep values only in private local documentation or protected backups where required for recovery.

## Credentials and secrets

Never commit:

- passwords;
- private SSH keys;
- API keys;
- authentication tokens;
- cookies;
- private certificates or keys;
- Wi-Fi credentials;
- cloud credentials.

This prohibition also applies to Git-ignored documentation.

## Provenance records

Every externally sourced artifact used for analysis should, where practical,
have provenance information containing:

- artifact name;
- source project or vendor;
- source URL or repository;
- version;
- commit hash where applicable;
- retrieval date;
- cryptographic hash;
- applicable license or redistribution status;
- notes about modifications.

A future machine-readable manifest may be added for this purpose.

## Source comparison

When comparing Klipper trees, always record all three identities where applicable:

```text
upstream revision
public Creality revision
reference firmware version / extracted tree
```

Do not describe a difference as a Creality modification unless the comparison
basis supports that conclusion.

A difference may instead result from:

- different upstream ages;
- vendor patches;
- backported upstream commits;
- later unpublished vendor changes;
- build-generated files;
- local modifications on the inspected printer.

## Clean replacement strategy

The project goal is functional hardware support, not preservation of proprietary
implementations.

Where vendor-specific functionality is required but suitable redistributable
source is unavailable, prefer:

1. document externally observable behavior and interfaces;
2. determine the actual hardware requirement;
3. check whether modern upstream Klipper already provides an equivalent;
4. design an open implementation where necessary;
5. validate it against the hardware without copying proprietary code.

## Project-authored material

The license for project-authored code and documentation should be selected
explicitly before the project reaches a distributable implementation phase.

Until a repository `LICENSE` file is deliberately added, do not assume that
project-authored material has been placed under a particular open-source
license merely because it interacts with GPL-covered software.

Any source file derived from or incorporating GPL-covered source must continue
to satisfy the applicable GPL requirements independently of the eventual
license chosen for original project material.

## Trademarks

Product and company names may be used descriptively to identify compatibility
and source material.

This project is independent and should not imply endorsement by or affiliation
with Creality or the Klipper project.
