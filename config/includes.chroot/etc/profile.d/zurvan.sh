# Zurvan Linux environment branding sourced dynamically from /etc/os-release
if [ -f /etc/os-release ]; then
    . /etc/os-release
    export DISTRIB_ID="${ID:-Zurvan}"
    export DISTRIB_RELEASE="${VERSION_ID:-0.1.0}"
    export DISTRIB_CODENAME="${VERSION_CODENAME:-akaran}"
    export DISTRIB_DESCRIPTION="${PRETTY_NAME:-Zurvan Linux}"
fi
