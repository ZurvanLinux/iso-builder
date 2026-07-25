#!/bin/sh
# Zurvan Linux — first-boot Flatpak app installer
# Runs once at first boot via flathub-install.service, then self-disables.
set -eu

if ! command -v flatpak >/dev/null 2>&1; then
    echo "flatpak not installed; skipping Flathub setup" >&2
    exit 0
fi

flatpak remote-add --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo || true

APPS_FILE="/usr/share/zurvan/config/flathub-apps"
if [ -f "$APPS_FILE" ]; then
    FLATHUB_APPS=$(grep -v '^#' "$APPS_FILE" | grep -v '^$')
else
    FLATHUB_APPS='
com.visualstudio.code
com.obsproject.Studio
org.gahshomar.Gahshomar
com.leinardi.gst
'
fi

for app in ${FLATHUB_APPS}; do
    echo "Installing ${app} from Flathub..."
    flatpak install --noninteractive flathub "${app}" \
        || echo "WARNING: failed to install ${app}" >&2
done

flatpak update --noninteractive || true

echo "Disabling flathub-install.service (run-once complete)."
systemctl disable flathub-install.service 2>/dev/null || true
