#!/bin/sh
# Zurvan Linux — first-boot KDE Persian translation installer
# Runs once at first boot via zurvan-install-kde-translations.service, then self-disables.
set -eu

MARKER="/var/lib/zurvan/kde-translations-installed"

if [ -f "${MARKER}" ]; then
    echo "KDE translations already installed; skipping." >&2
    exit 0
fi

if ! command -v check-language-support >/dev/null 2>&1; then
    echo "check-language-support not found; skipping KDE translation install." >&2
    exit 0
fi

mkdir -p /var/lib/zurvan

MISSING=$(check-language-support fa 2>&1 || true)

if [ -z "${MISSING}" ]; then
    echo "All KDE Persian translation packages are installed." >&2
    touch "${MARKER}"
    exit 0
fi

echo "Missing KDE Persian translation packages detected:"
echo "${MISSING}"

echo "Installing missing KDE Persian translation packages..."
echo "${MISSING}" | xargs -r apt-get install -y || true

touch "${MARKER}"

echo "Disabling zurvan-install-kde-translations.service (run-once complete)."
systemctl disable zurvan-install-kde-translations.service 2>/dev/null || true