# Contributing to Zurvan Linux iso-builder

## Development setup

### Prerequisites

- **Local builds (amd64):** Debian/Ubuntu host with `live-build`, `debootstrap`, `squashfs-tools`, `xorriso`
- **arm64 builds:** macOS with [Multipass](https://multipass.run) + Docker (uses a remote ARM64 VM)
- **CI:** GitHub Actions runners (amd64 + arm64)

### Build

```bash
# arm64 (via Multipass — works from any host)
make build-arm64

# amd64 (native host only)
make build-amd64

# Or run lb config + lb build manually
make config ARCH=arm64
sudo lb build
```

All configuration is centralized in [`build.env`](build.env). Override any value:

```bash
ARCH=amd64 make build
DEBIAN_CODENAME=forchy make build
```

### Lint

```bash
make lint
```

Runs `shellcheck` + `bash -n` on every shell script and hook.

### Test

```bash
make test
```

Runs the upgrade-path test suite in a debootstrap chroot.

## Code style

- Shell scripts: POSIX `sh` where possible, `set -e` at top
- Hooks: named `NN-description.hook.chroot` or `NN-description.hook.binary` (sorted alphabetically by live-build)
- Package lists: named `NN-category.list.chroot`
- No binary blobs in the repo — all firmware/modules come from Debian packages
- All configurable values live in `build.env` — no hardcoded mirrors, codenames, or digests in scripts

## Pull request checklist

- [ ] `make lint` passes
- [ ] `make test` passes
- [ ] No hardcoded values (use `build.env`)
- [ ] No committed binary blobs (firmware, kernel modules, .deb files)
- [ ] CI workflow changes mirror any `build.env` changes (container image digests)
- [ ] Hook ordering is correct (two-digit numeric prefix)

## Release workflow

1. Tag: `git tag v0.1.0-pre.N`
2. Push tag: `git push origin v0.1.0-pre.N`
3. CI builds both architectures, uploads ISO to Cloudflare R2, creates a GitHub pre-release
4. Verify the download URL: `https://download.zurvanlinux.org/iso/zurvan-0.1.0-pre.N-{amd64,arm64}.iso`
