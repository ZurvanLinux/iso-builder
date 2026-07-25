#!/bin/sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../build.env
. "${SCRIPT_DIR}/build.env"

CONFIG_DIR="${ZURVAN_CONFIG_DIR:-${SCRIPT_DIR}/zurvan-config}"

if [ -d "${CONFIG_DIR}/.git" ]; then
    (cd "${CONFIG_DIR}" && git fetch origin && git checkout "${ZURVAN_CONFIG_REF}")
else
    git clone "https://github.com/${ZURVAN_CONFIG_REPO}" "${CONFIG_DIR}"
    (cd "${CONFIG_DIR}" && git checkout "${ZURVAN_CONFIG_REF}")
fi