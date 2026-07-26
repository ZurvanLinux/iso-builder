#!/bin/sh
# Zurvan OS — first-login wallpaper enforcer
# Sets the Zurvan wallpaper on the live Plasma desktops via the plasmashell
# D-Bus API (enumerates desktops() at runtime, so it does not depend on
# containment/activity IDs or clobber the default panel/widgets).
# Self-disables after a successful apply so it never overrides user changes.
set -u

WP="file:///usr/share/wallpapers/Zurvan/contents/images/1920x1080.png"
LOG_TAG="zurvan-apply-wallpaper"

# Pick the Qt6 qdbus binary
if command -v qdbus6 >/dev/null 2>&1; then
    QDBUS=qdbus6
elif command -v qdbus >/dev/null 2>&1; then
    QDBUS=qdbus
else
    logger -t "$LOG_TAG" "no qdbus found; skipping"
    exit 0
fi

# Wait for plasmashell to expose its D-Bus interface (max ~60s)
ready=0
i=0
while [ "$i" -lt 60 ]; do
    if "$QDBUS" org.kde.plasmashell >/dev/null 2>&1; then
        ready=1
        break
    fi
    i=$((i + 1))
    sleep 1
done
if [ "$ready" -ne 1 ]; then
    logger -t "$LOG_TAG" "plasmashell D-Bus never appeared; skipping"
    exit 0
fi

SCRIPT='var d=desktops();for(var i=0;i<d.length;i++){d[i].wallpaperPlugin="org.kde.image";d[i].currentConfigGroup=Array("Wallpaper","org.kde.image","General");d[i].writeConfig("Image","'"$WP"'");d[i].reloadConfig();}'

if "$QDBUS" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$SCRIPT" >/dev/null 2>&1; then
    logger -t "$LOG_TAG" "wallpaper applied ($WP)"
    # One-shot: stop running on future logins so user wallpaper choices survive.
    rm -f "${XDG_CONFIG_HOME:-"$HOME/.config"}/autostart/zurvan-apply-wallpaper.desktop"
else
    logger -t "$LOG_TAG" "evaluateScript failed; will retry next login"
fi

exit 0
