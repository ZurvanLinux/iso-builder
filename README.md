# iso-builder

Debian `live-build` configuration and GitHub Actions ISO build pipeline for **Zurvan Linux**.

## Current state: M1.1b — full KDE Plasma 6.7 baseline

The full spec-compliant desktop baseline. Builds Debian 13 (`trixie`) `amd64` with
the complete KDE Plasma 6.7 stack, multimedia codecs, hardware firmware, Flatpak
integration, Calamares, and Persian-first localization baked in.

- **Base:** Debian 13 (`trixie`), `amd64` only; `main` + `contrib` + `non-free` + `non-free-firmware`.
- **Desktop:** KDE Plasma 6.7, **Wayland session by default** (X11 fallback), SDDM, Plymouth.
- **Fonts/localization:** `fonts-vazirmatn` as system default via `/etc/fonts/local.conf`; `fa_IR.UTF-8` locale (RTL mirroring + Jalali calendar); ISIRI 9147 `ir` keyboard with ZWNJ on `Shift+Space`; `Asia/Tehran` timezone.
- **Firmware:** `firmware-linux{,-nonfree}`, `firmware-iwlwifi/-realtek/-atheros`, `nvidia-detect`.
- **Installer:** Calamares + `calamares-settings-debian` (branding customization is Phase 3).

> **M1.1a** (the minimal CLI proof build that validated the pipeline + loop-device
> behavior on hosted runners) is superseded by this milestone. The build pipeline
> itself is unchanged and proven.

### Debian 13 / Plasma 6 substitutions vs. `package-manifest.md`

The spec was written against package names that drifted in Debian 13. Substitutions
are documented inline in each list and summarized here:

| Manifest name | In ISO | Reason |
|---|---|---|
| `plasma-workspace-wayland` | dropped (use `plasma-workspace`) | Folded into `plasma-workspace` in Plasma 6 (verified via madison). |
| `khotkeys` | dropped | Removed in Plasma 6; shortcuts now use KDE's built-in global-accel. |
| `spectacle` | `kde-spectacle` | Renamed in Debian 13. |
| `zurvan-dns-bypass` | commented | Custom package, built in Phase 2 (M2.2), published to the Zurvan APT repo. |
| `fonts-vazirmatn` "Vazirmatn UI FD" monospace | not set | The Debian package ships only the proportional Vazirmatn family; the Farsi-Digits monospace variant is bundled from Google Fonts in Phase 2 (branding-assets, M2.1). Flagged spec divergence — `local.conf` leaves monospace at the system default meanwhile. |

## Repository layout

```
auto/
  config                          # -> lb config (trixie/amd64, all archive areas, ISO metadata)
config/
  package-lists/                  # one file per package-manifest.md section (§1-§10 + firmware)
  includes.chroot/                # files overlaid into the chroot at / 
    etc/apt/sources.list.d/zurvan.list   # Zurvan apt repo (commented until P0)
    etc/fonts/local.conf                 # Vazirmatn default
    etc/default/keyboard                 # us,ir + ISIRI 9147 + ZWNJ on Shift+Space + toggles
    etc/default/locale                   # fa_IR.UTF-8
    etc/timezone                         # Asia/Tehran
    etc/xdg/kdeglobals                   # Breeze Dark scheme (Zurvan Dark/teal = Phase 2)
    etc/skel/.config/kdeglobals          # same, for new users
    etc/sddm.conf.d/99-zurvan.conf       # Wayland default session + autologin
  hooks/normal/
    zurvan-locale.hook.chroot           # locale-gen + timezone symlink + /etc/default/locale
.github/workflows/
  build-iso.yml                   # privileged debian:trixie container build + release
  lint.yml                        # calls the org reusable shellcheck/yamllint workflow
```

`.gitignore` excludes live-build generated control files and build stages
(`chroot/`, `binary/`, `.build/`); only the authored config is committed.

## Build pipeline (`.github/workflows/build-iso.yml`)

- **Host:** `ubuntu-latest` GitHub-hosted runner.
- **Container:** `debian:trixie` (pinned by digest), `--privileged` so the
  `lb_binary` stage can mount the squashfs via `losetup`. `/dev/loop-control` +
  `/dev/loopN` are provisioned if missing.
- **Timeout:** 90 minutes (a full Plasma squashfs is materially larger/slower than the
  M1.1a minimal build).
- **Outputs:** `live-image-amd64.hybrid.iso` + `SHA256SUMS` are uploaded as a
  workflow artifact (`zurvan-minimal-iso`) on every run. If a `release_tag` input
  (or a pushed `v0.1.0-pre.*` / `v0.2.0-pre.*` tag) is supplied, a GitHub
  **pre-release** is created. (Note: GitHub caps a single release asset at 2 GB; a
  full KDE ISO may exceed that — verify before tagging.)

### Triggers

- `workflow_dispatch` — manual, optional `release_tag` input.
- `push` to tags matching `v0.1.0-pre.*` and `v0.2.0-pre.*` — automatic pre-release.

### Run it

From the Actions tab → **Build ISO (live-build)** → **Run workflow**, then
download the artifact. Boot-test locally:

```sh
qemu-system-x86_64 -m 4G -cdrom live-image-amd64.hybrid.iso -boot d
# UEFI:
qemu-system-x86_64 -m 4G -bios /usr/share/OVMF/OVMF_CODE.fd \
  -cdrom live-image-amd64.hybrid.iso -boot d
```

### M1.1b exit criteria (release gate; testing-qa-checklist.md)

Builds must pass in **both** QEMU/KVM and VirtualBox (BIOS + UEFI): reaches the
Plasma desktop, Vazirmatn renders Persian, `us`/`ir` toggle + ZWNJ work,
Asia/Tehran auto-applied, Wi-Fi firmware loads, Flathub visible in Discover,
Calamares launches, `apt update` is clean. Tag `v0.2.0-pre` once verified.

## Out of scope here

`zurvan-dns-bypass` and the Zurvan branding package (Phase 2), the welcome app
and Calamares branding (Phase 3), `download.zurvanlinux.org` ISO hosting (Phase 5).
See the project plan and the spec docs in
[`ZurvanLinux/ZurvanLinux`](https://github.com/ZurvanLinux/ZurvanLinux).
