#!/usr/bin/env bash
# ==============================================================================
#   TURBO-WIFI : Automated Syntax & Mock Validation Suite
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_SCRIPT="$SCRIPT_DIR/TurboWiFi.command"

echo "=== [TEST 1] Bash Syntax Verification ==="
if [ ! -f "$TARGET_SCRIPT" ]; then
    echo "FAIL: $TARGET_SCRIPT does not exist"
    exit 1
fi

# Run bash syntax parser
bash -n "$TARGET_SCRIPT"
echo "PASS: bash -n syntax check succeeded with zero errors."

echo "=== [TEST 2] Line Ending Verification ==="
if grep -q $'\r' "$TARGET_SCRIPT"; then
    echo "FAIL: Found Windows CRLF carriage returns. Must be strictly Unix LF."
    exit 1
fi
echo "PASS: Unix LF line endings verified."

echo "=== [TEST 3] Architecture & Optimization Invariant Verification ==="
# Check for parallel telemetry jobs
if ! grep -q 'wait' "$TARGET_SCRIPT" || ! grep -q '&' "$TARGET_SCRIPT"; then
    echo "FAIL: Missing parallel async telemetry pattern (& + wait)"
    exit 1
fi
echo "PASS: Async background telemetry jobs verified."

# Check for snapshot store
if ! grep -q 'SNAPSHOT_FILE="/var/tmp/\.turbowifi_snapshot\.env"' "$TARGET_SCRIPT"; then
    echo "FAIL: Missing snapshot destination invariant"
    exit 1
fi
echo "PASS: Snapshot destination invariant verified."

# Check for restore handler
if ! grep -q 'restore_snapshot' "$TARGET_SCRIPT"; then
    echo "FAIL: Missing restore_snapshot function"
    exit 1
fi
echo "PASS: Restore function declaration verified."

# Check for sysctl batching
if ! grep -q 'net\.inet\.tcp\.delayed_ack=0' "$TARGET_SCRIPT" || ! grep -q 'net\.ipv4\.tcp_ecn=1' "$TARGET_SCRIPT"; then
    echo "FAIL: Missing kernel TCP optimization parameters"
    exit 1
fi
echo "PASS: Kernel TCP parameter optimization verified."

# Check for queue backlog scaling & SACK
if ! grep -q 'net\.core\.netdev_max_backlog=16384' "$TARGET_SCRIPT" || ! grep -q 'net\.ipv4\.tcp_sack=1' "$TARGET_SCRIPT"; then
    echo "FAIL: Missing backlog scaling and SACK parameters"
    exit 1
fi
echo "PASS: Kernel backlog scaling and SACK verified."

echo "=== [TEST 4] Mock OS Detection & Function Execution ==="
# Source script functions safely in mock test mode
export TURBOWIFI_SKIP_ELEVATION=1
# shellcheck disable=SC1090
source "$TARGET_SCRIPT"

detect_os
if [ "$OS" != "Linux" ] && [ "$OS" != "Darwin" ]; then
    echo "FAIL: Unexpected OS detection: $OS"
    exit 1
fi
echo "PASS: OS dynamically detected as '$OS'."

# Test snapshot creation in isolated directory
TEST_TMP="/tmp/turbowifi_test_$$"
mkdir -p "$TEST_TMP"
SNAPSHOT_FILE="$TEST_TMP/test_snapshot.env"
WIFI_DEV="test_wifi0"
WIFI_SERVICE="Wi-Fi"

save_snapshot
if [ ! -f "$SNAPSHOT_FILE" ]; then
    echo "FAIL: Snapshot was not generated at $SNAPSHOT_FILE"
    exit 1
fi

if ! grep -q "ORIG_OS=\"$OS\"" "$SNAPSHOT_FILE"; then
    echo "FAIL: Snapshot missing ORIG_OS"
    exit 1
fi
echo "PASS: Snapshot created and verified."

# Test snapshot restore cycle
restore_snapshot >/dev/null 2>&1
if [ -f "$SNAPSHOT_FILE" ]; then
    echo "FAIL: Snapshot was not removed after restore"
    exit 1
fi
echo "PASS: Snapshot restore cycle cleanly executed."

rm -rf "$TEST_TMP"

echo "=== [TEST 5] Audit Engine Invariant Verification ==="
if ! grep -q 'record_audit' "$TARGET_SCRIPT" || ! grep -q 'AUDIT_CATEGORIES=' "$TARGET_SCRIPT"; then
    echo "FAIL: Missing 4-state audit engine declaration"
    exit 1
fi

record_audit "Test Subsystem" "APPLIED" "Optimized successfully" "Old -> New"
if [ "${#AUDIT_CATEGORIES[@]}" -lt 1 ] || [ "${AUDIT_STATUS[0]}" != "APPLIED" ]; then
    echo "FAIL: record_audit did not properly populate audit arrays"
    exit 1
fi
echo "PASS: 4-State Audit Engine records verified."

echo "=== [TEST 6] Cursor Restoration Invariant Verification ==="
if ! grep -q '\\033\[?25h' "$TARGET_SCRIPT"; then
    echo "FAIL: Missing cursor restoration escape sequence"
    exit 1
fi
echo "PASS: Terminal cursor restoration sequence verified."

echo "=== [TEST 7] Braille Pipeline Spinner Buffer Invariant ==="
if [ "${#BRAILLE_FRAMES[@]}" -lt 8 ]; then
    echo "FAIL: BRAILLE_FRAMES array contains fewer than 8 frames"
    exit 1
fi
echo "PASS: Braille pipeline spinner verified with ${#BRAILLE_FRAMES[@]} frames."

echo "=== [TEST 8] Cross-Platform Idempotency & GUID Invariants ==="
WIN_SCRIPT="$SCRIPT_DIR/TurboWiFi.cmd"
if ! grep -q '12bbebe6-58d6-4636-95bb-3217ef867c1a' "$WIN_SCRIPT" || grep -q '12bbe46e-7676-4299-a68f-17c37604e6b2' "$WIN_SCRIPT"; then
    echo "FAIL: Windows Power Management GUID invariant failed"
    exit 1
fi
if ! grep -q 'Get-DnsClientDohServerAddress' "$WIN_SCRIPT" || ! grep -q '/sys/class/net/\*/wireless' "$TARGET_SCRIPT"; then
    echo "FAIL: Missing read-before-write or generic Linux wireless detection"
    exit 1
fi
echo "PASS: Cross-platform idempotency & GUID invariants verified."

echo "================================================="
echo "ALL TESTS PASSED SUCCESSFULLY! (VERDICT: PASS)"
echo "================================================="
exit 0
