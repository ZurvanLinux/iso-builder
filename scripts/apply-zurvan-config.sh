#!/bin/sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="${ZURVAN_CONFIG_DIR:-${SCRIPT_DIR}/zurvan-config}"

# 1. Source shell-compatible config files (skip if dir missing)
# shellcheck disable=SC1090
if [ -d "${CONFIG_DIR}" ]; then
    for f in repo-urls branding repo-metadata localization live-session iso-metadata; do
        [ -f "${CONFIG_DIR}/${f}" ] && . "${CONFIG_DIR}/${f}"
    done
    # shellcheck disable=SC1090
    DIST_VER="$(find "${CONFIG_DIR}/versions" -name dist-version 2>/dev/null | head -1 || true)"
    # shellcheck disable=SC1090
    [ -n "${DIST_VER}" ] && . "${DIST_VER}"
fi

# 2. Copy ALL config files into includes.chroot for hooks (clean first)
DEST="${SCRIPT_DIR}/config/includes.chroot/usr/share/zurvan/config"
rm -rf "${DEST}"
mkdir -p "${DEST}"
for f in repo-urls branding repo-metadata localization live-session iso-metadata flathub-apps; do
    [ -f "${CONFIG_DIR}/${f}" ] && cp "${CONFIG_DIR}/${f}" "${DEST}/"
done
[ -n "${DIST_VER:-}" ] && cp "${DIST_VER}" "${DEST}/dist-version"

# 3. Write ISO_* to .zurvan-env (sourced by auto/config and CI)
ENV_FILE="${SCRIPT_DIR}/.zurvan-env"
printf 'ISO_APPLICATION="%s"\n' "${ISO_APPLICATION:-Zurvan Linux}" > "${ENV_FILE}"
printf 'ISO_PUBLISHER="%s"\n' "${ISO_PUBLISHER:-Zurvan Linux - https://zurvanlinux.org}" >> "${ENV_FILE}"
printf 'ISO_VOLUME="%s"\n' "${ISO_VOLUME:-Zurvan Linux}" >> "${ENV_FILE}"