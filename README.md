# iso-builder

Debian `live-build` configuration and GitHub Actions ISO build pipeline for **Zurvan Linux**.

## Current state: M1.1b — full KDE Plasma baseline

The full spec-compliant desktop baseline. Builds Debian Stable (pinned to the
`trixie` codename) `amd64` with the complete KDE Plasma stack, multimedia codecs,
hardware firmware, Flatpak integration, Calamares, and Persian-first localization
baked in.

- **Base:** Debian Stable (pinned to the `trixie` codename), `amd64` + `arm64`; `main` + `contrib` + `non-free` + `non-free-firmware`.
- **Desktop:** KDE Plasma (latest stable), **Wayland session by default** (X11 fallback), SDDM, Plymouth.
- **Fonts/localization:** `fonts-vazirmatn` as system default via `/etc/fonts/local.conf`; `fa_IR.UTF-8` locale (RTL mirroring + Jalali calendar); ISIRI 9147 `ir` keyboard with ZWNJ on `Shift+Space`; `Asia/Tehran` timezone.
- **Firmware:** `firmware-linux{,-nonfree}`, `firmware-iwlwifi/-realtek/-atheros`, `nvidia-detect`.
- **Installer:** Calamares + `calamares-settings-debian` (branding customization is Phase 3).

> **M1.1a** (the minimal CLI proof build that validated the pipeline + loop-device
> behavior on hosted runners) is superseded by this milestone. The build pipeline
> itself is unchanged and proven.

### Debian Stable / Plasma substitutions vs. `package-manifest.md`

The spec was written against package names that drifted in current Debian Stable. Substitutions
are documented inline in each list and summarized here:

| Manifest name | In ISO | Reason |
|---|---|---|
| `plasma-workspace-wayland` | dropped (use `plasma-workspace`) | Folded into `plasma-workspace` in Plasma 6 (verified via madison). |
| `khotkeys` | dropped | Removed in Plasma 6; shortcuts now use KDE's built-in global-accel. |
| `spectacle` | `kde-spectacle` | Renamed in current Debian Stable. |
| `zurvan-dns-bypass` | commented | Custom package, built in Phase 2 (M2.2), published to the Zurvan APT repo. |
| `fonts-vazirmatn` "Vazirmatn UI FD" monospace | not set | The Debian package ships only the proportional Vazirmatn family; the Farsi-Digits monospace variant is bundled from Google Fonts in Phase 2 (branding-assets, M2.1). Flagged spec divergence — `local.conf` leaves monospace at the system default meanwhile. |

## Build matrix

The CI builds both `amd64` and `arm64` ISOs in a single matrix job:

| Arch | Runner | Container | Boot mode |
|---|---|---|---|
| `amd64` | `ubuntu-latest` | `debian:trixie` (pinned) | BIOS (`isolinux` + grub-pc) + UEFI (`grub-efi-amd64`) |
| `arm64` | `ubuntu-24.04-arm` | `debian:trixie` (arm64 manifest) | UEFI only (`grub-efi-arm64`) |

The active arch is controlled by `ZURVAN_ARCH` in the workflow matrix.
`auto/config` passes it to `lb config --architecture ${ARCH}`.

> **arm64 firmware** support is deferred to a future release. The `linux-image-arm64`
> kernel is included, but board-specific firmware (RPi, RK35xx, etc.) would bloat
> the ISO for all users and will be added once the target boards are locked in.

## Repository layout

```
auto/
  config                          # -> lb config (amd64, all archive areas, ISO metadata)
config/
  package-lists/                  # one file per package-manifest.md section (§1–§15)
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
  lint.yml                        # inline shellcheck + yamllint + bash -n
```

`.gitignore` excludes live-build generated control files and build stages
(`chroot/`, `binary/`, `.build/`); only the authored config is committed.

## Build pipeline (`.github/workflows/build-iso.yml`)

- **Host:** `ubuntu-latest` (amd64) or `ubuntu-24.04-arm` (arm64) GitHub-hosted runners.
- **Container:** `debian:trixie` (pinned by digest on amd64), `--privileged` so the
  `lb_binary` stage can mount the squashfs via `losetup`. `/dev/loop-control` +
  `/dev/loopN` are provisioned if missing.
- **Timeout:** 90 minutes for amd64, 120 minutes for arm64 (a full Plasma squashfs
  is materially larger/slower than the M1.1a minimal build).
- **Outputs:** `live-image-<arch>.hybrid.iso` + `SHA256SUMS` are uploaded as
  arch-suffixed workflow artifacts (`zurvan-live-iso-amd64`, `zurvan-live-iso-arm64`)
  on every run. If a `release_tag` input (or a pushed `v*.*.*-pre.*` tag) is
  supplied, the `publish-release` fan-in job aggregates both arch artifacts and
  creates a single GitHub pre-release.

### ISO hosting: Cloudflare R2

A full KDE ISO is ~2.3 GB, above GitHub Releases' **2 GB per-asset cap**, so the
ISO binary is published to a **Cloudflare R2** bucket (zero-egress object storage)
served at **`https://download.zurvanlinux.org/iso/zurvan-<version>-<arch>.iso`**
(the subdomain is bound to the bucket as a Cloudflare custom domain). GitHub
Releases keeps the release notes + `SHA256SUMS` and links to the R2 URL. The
upload uses `rclone` (R2's S3-compatible API), env-configured from secrets.

**Maintainer prerequisites** (block the first release-to-R2; see the project plan):

1. Create the R2 bucket (e.g. `zurvan-iso`) and enable public access.
2. Bind `download.zurvanlinux.org` to the bucket as a Cloudflare custom domain.
3. Create an R2 API token (Object Read & Write); note the Access Key ID, Secret,
   and S3 endpoint (`https://<accountid>.r2.cloudflarestorage.com`).
4. Add `iso-builder` Actions secrets: `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`,
   `R2_ENDPOINT`, `R2_BUCKET`.

Until these exist, a tagged build creates the GitHub Release + artifact but the R2
upload step fails with a clear `::error::` (artifact-only, no-tag runs are unaffected).

### Triggers

- `workflow_dispatch` — manual, optional `release_tag` input.
- `push` to tags matching `v*.*.*-pre.*` — automatic pre-release + R2 publish.

### Run it

From the Actions tab → **Build ISO (live-build)** → **Run workflow**, then
download the artifact. Boot-test locally:

```sh
# amd64 QEMU/KVM:
qemu-system-x86_64 -m 4G -cdrom live-image-amd64.hybrid.iso -boot d
# amd64 UEFI:
qemu-system-x86_64 -m 4G -bios /usr/share/OVMF/OVMF_CODE.fd \
  -cdrom live-image-amd64.hybrid.iso -boot d

# arm64 QEMU (UEFI only — AAVMF is the UEFI firmware for ARM):
qemu-system-aarch64 -m 4G -M virt -cpu cortex-a72 -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
  -drive id=hd,file=live-image-arm64.hybrid.iso,if=none,format=raw \
  -device virtio-blk-device,drive=hd -boot d
```

> If the arm64 image fails to boot, verify the ISO structure with
> `xorriso -indev live-image-arm64.hybrid.iso -report_el_torito as_mkisofs`.

## M1.1b exit criteria (release gate; testing-qa-checklist.md)

Builds must pass in **both** QEMU/KVM and VirtualBox (BIOS + UEFI): reaches the
Plasma desktop, Vazirmatn renders Persian, `us`/`ir` toggle + ZWNJ work,
Asia/Tehran auto-applied, Wi-Fi firmware loads, Flathub visible in Discover,
Calamares launches, `apt update` is clean. Tag `v0.2.0-pre` once verified.

## Bump runbook: new Debian stable release

Zurvan pins the build to a Debian **codename** (`trixie` today) rather than the
rolling `stable` suite — for reproducibility and a stable security-suite path
(`trixie-security`). When Debian releases a new stable (e.g. trixie → forky):

1. Update `--distribution` in `auto/config` to the new codename.
2. Repin the build container in `.github/workflows/build-iso.yml` by resolving the new amd64 manifest digest (`docker pull debian:<codename>` or the registry API) and updating `debian:<codename>@sha256:…`. The arm64 matrix entry uses the unpinned image.
3. Bump the `ZURVAN_CONFIG_REF` env in `.github/workflows/build-iso.yml` (both `build` and `test-installed-upgrade`) to the new `ZurvanLinux/zurvan-config` `main` HEAD SHA.
4. Re-verify every package name in `config/package-lists/` against the new suite via Debian madison — package names drift across Debian + Plasma majors (see the substitution notes in `05-plasma.list.chroot`).
5. Update the "(pinned to the `<codename>` codename)" note in this README.
6. Trigger `build-iso.yml`, boot-test in QEMU/KVM + VirtualBox (BIOS + UEFI),
   and run the full `testing-qa-checklist.md` before tagging a pre-release.

## Out of scope here

`zurvan-dns-bypass` and the Zurvan branding package (Phase 2), the welcome app
and Calamares branding (Phase 3), `download.zurvanlinux.org` ISO hosting (Phase 5).
See the project plan and the spec docs in
[`ZurvanLinux/ZurvanLinux`](https://github.com/ZurvanLinux/ZurvanLinux).
