#!/bin/sh
set -e
CHROOT="${CHROOT:-/tmp/zurvan-upgrade-chroot}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

run_tc() {
    name="$1"
    shift
    echo "=== RUN $name ==="
    if "$@"; then
        echo "PASS $name"
        PASS=$((PASS + 1))
    else
        echo "FAIL $name"
        FAIL=$((FAIL + 1))
        return 1
    fi
}

for tc in "$SCRIPT_DIR"/tc-*.sh; do
    name="$(basename "$tc")"
    if ! run_tc "$name" sh "$tc"; then
        :
    fi
done

echo "=== SUMMARY ==="
echo "PASS: $PASS, FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
