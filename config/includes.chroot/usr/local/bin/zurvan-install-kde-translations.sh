#!/bin/sh
# Zurvan Linux — first-boot KDE Persian translation installer
# Runs once at first boot via zurvan-install-kde-translations.service, then self-disables.
set -eu

MARKER="/var/lib/zurvan/kde-translations-installed"

if [ -f "${MARKER}" ]; then
    echo "KDE translations already installed; skipping." >&2
    exit 0
fi

mkdir -p /var/lib/zurvan

# --- KDE Persian translation packages ---
if command -v check-language-support >/dev/null 2>&1; then
    MISSING=$(check-language-support fa 2>&1 || true)

    if [ -n "${MISSING}" ]; then
        echo "Missing KDE Persian translation packages detected:"
        echo "${MISSING}"
        echo "Installing missing KDE Persian translation packages..."
        echo "${MISSING}" | xargs -r apt-get install -y || true
    else
        echo "All KDE Persian translation packages are installed." >&2
    fi
else
    echo "check-language-support not found; skipping KDE translation install." >&2
fi

# --- Shamsi Calendar plasmoid (Persian/Jalali calendar widget) ---
if command -v kpackagetool6 >/dev/null 2>&1; then
    PLASMOID_URL="https://github.com/amirnajaffi/shamsi-calendar-plasmoid/releases/latest/download/shamsi-calendar-plasmoid-3.0.5.plasmoid"
    PLASMOID_FILE="/tmp/shamsi-calendar-plasmoid.plasmoid"

    if [ ! -f "${PLASMOID_FILE}" ]; then
        echo "Downloading Shamsi Calendar plasmoid..."
        curl -fsSL "${PLASMOID_URL}" -o "${PLASMOID_FILE}" 2>/dev/null || true
    fi

    if [ -f "${PLASMOID_FILE}" ]; then
        echo "Installing Shamsi Calendar plasmoid..."
        kpackagetool6 -t Plasma/Applet --install "${PLASMOID_FILE}" 2>/dev/null || true
        rm -f "${PLASMOID_FILE}"
    fi
else
    echo "kpackagetool6 not found; skipping Shamsi Calendar plasmoid install." >&2
fi

touch "${MARKER}"

echo "Disabling zurvan-install-kde-translations.service (run-once complete)."
systemctl disable zurvan-install-kde-translations.service 2>/dev/null || true