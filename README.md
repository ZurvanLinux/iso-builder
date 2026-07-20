# iso-builder

Debian `live-build` configuration and GitHub Actions ISO build pipeline for **Zurvan Linux**.

## Current state: M1.1a (minimal proof build)

This milestone produces a **CLI-only** ISO. Its sole purpose is to validate that
`lb build` runs successfully inside the privileged GitHub Actions container —
probing loop-device availability and disk pressure **before** the full KDE
baseline (M1.1b) is committed.

- Base: Debian 13 (`trixie`), `amd64` only.
- No desktop environment, no custom configuration (those land in M1.1b).
- Only the `main` archive area is enabled (contrib/non-free/non-free-firmware
  are added in M1.1b per `technical-spec-architecture.md` §2.2).

## Repository layout

```
auto/                      # live-build entry points (run lb config/build/clean)
  config                   #   -> lb config (distribution, mirrors, ISO metadata)
  build                    #   -> lb build
  clean                    #   -> lb clean
config/
  package-lists/
    zurvan-minimal.list.chroot   # M1.1a package set (live-boot, kernel, CLI utils)
.github/workflows/
  build-iso.yml            # privileged debian:trixie container build + release
```

`.gitignore` excludes live-build generated control files and build stages
(`chroot/`, `binary/`, `.build/`); only the authored config is committed.

## Build pipeline (`.github/workflows/build-iso.yml`)

- **Host:** `ubuntu-latest` GitHub-hosted runner.
- **Container:** `debian:trixie` (pinned by digest), `--privileged` so the
  `lb_binary` stage can mount the squashfs via `losetup`. The workflow provisions
  `/dev/loop-control` and `/dev/loopN` nodes if missing.
- **Outputs:** the `live-image-amd64.hybrid.iso` + `SHA256SUMS` are uploaded as a
  workflow artifact (`zurvan-minimal-iso`) on every run. If a `release_tag` input
  (or a pushed `v0.1.0-pre.*` tag) is supplied, a GitHub **pre-release** is
  created with the ISO and checksum attached.

### Triggers

- `workflow_dispatch` — manual, optional `release_tag` input.
- `push` to tags matching `v0.1.0-pre.*` — automatic pre-release.

### Run it

From the Actions tab → **Build ISO (live-build)** → **Run workflow**, then
download the `zurvan-minimal-iso` artifact. Boot-test locally:

```sh
qemu-system-x86_64 -m 2G -cdrom live-image-amd64.hybrid.iso -boot d
```

**M1.1a exit criterion:** the ISO reaches a login prompt in QEMU.

## What is explicitly out of scope here

Desktop environment, fonts/localization config, firmware, Calamares, the Zurvan
APT repo wiring, and branding — all M1.1b and later. See the project plan and
the spec docs in [`ZurvanLinux/ZurvanLinux`](https://github.com/ZurvanLinux/ZurvanLinux).
