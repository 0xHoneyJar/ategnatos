#!/usr/bin/env bash
# test-resource-lock.sh — Test suite for resource-lock.sh
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TESTS_DIR")"
source "$TESTS_DIR/lib/test-helpers.sh"

# Helper: capture exit code of a function that may fail.
# Under set -e, we cannot rely on assert_exit_code for non-zero returns
# because the command aborts before $? is captured.
# Usage: expect_rc <expected> <cmd> [args...]
expect_rc() {
  local expected="$1"
  shift
  local rc=0
  "$@" >/dev/null 2>&1 || rc=$?
  if [[ "$expected" == "$rc" ]]; then
    test_pass
  else
    test_fail "Expected exit code $expected, got $rc"
  fi
}

# Unique test resource names to avoid collisions with real locks
TEST_RESOURCE="test:lock:$$:$(date +%s)"
TEST_RESOURCE_STALE="test:stale:resource"

# Track lockfiles we create so teardown can clean them all
CREATED_LOCKFILES=()

setup() {
  source "$PROJECT_DIR/.claude/scripts/lib/resource-lock.sh"
}

teardown() {
  # Remove any lockfiles that may have been created during tests
  for lf in "${CREATED_LOCKFILES[@]}"; do
    rm -f "$lf"
  done
  # Also clean up by resource name as a safety net
  local path
  path="$(_lock_path "$TEST_RESOURCE" 2>/dev/null)" && rm -f "$path"
  path="$(_lock_path "$TEST_RESOURCE_STALE" 2>/dev/null)" && rm -f "$path"
  # Clean up any leftover test lockfiles
  rm -f /tmp/ategnatos-lock-*-test-*.lock 2>/dev/null || true
}
trap teardown EXIT

echo "Testing: resource-lock.sh"
echo ""

setup

# ===============================================
# lock_check / lock_acquire / lock_release
# ===============================================

echo "--- lock lifecycle ---"

test_start "lock_check on unlocked resource exits 1"
expect_rc 1 lock_check "$TEST_RESOURCE"

test_start "lock_check on unlocked resource outputs 'unlocked'"
output=$(lock_check "$TEST_RESOURCE" 2>/dev/null || true)
assert_contains "$output" "unlocked"

test_start "lock_acquire succeeds on unlocked resource"
CREATED_LOCKFILES+=("$(_lock_path "$TEST_RESOURCE")")
expect_rc 0 lock_acquire "$TEST_RESOURCE" --holder "test-suite" --timeout 1

test_start "lock_check on locked resource exits 0"
expect_rc 0 lock_check "$TEST_RESOURCE"

test_start "lock_check on locked resource shows holder and PID"
output=$(lock_check "$TEST_RESOURCE" 2>/dev/null || true)
assert_contains "$output" "test-suite"

test_start "lock_release succeeds for owning PID"
expect_rc 0 lock_release "$TEST_RESOURCE"

test_start "lock_check after release exits 1 (unlocked)"
expect_rc 1 lock_check "$TEST_RESOURCE"

test_start "lock_check after release outputs 'unlocked'"
output=$(lock_check "$TEST_RESOURCE" 2>/dev/null || true)
assert_contains "$output" "unlocked"

echo ""

# ===============================================
# lock_force_release
# ===============================================

echo "--- lock_force_release ---"

# Acquire a lock first so we can force-release it
lock_acquire "$TEST_RESOURCE" --holder "force-test" --timeout 1 >/dev/null 2>&1

test_start "lock_force_release removes lock"
expect_rc 0 lock_force_release "$TEST_RESOURCE"

test_start "lock_check after force_release exits 1 (unlocked)"
expect_rc 1 lock_check "$TEST_RESOURCE"

echo ""

# ===============================================
# Stale PID auto-release
# ===============================================

echo "--- stale PID auto-release ---"

# Create a fake lockfile with a PID that does not exist (99999)
# Use the lock path function to get the correct file location
STALE_LOCK_PATH="$(_lock_path "$TEST_RESOURCE_STALE")"
CREATED_LOCKFILES+=("$STALE_LOCK_PATH")

echo '{"resource":"test:stale:resource","holder":"dead-process","pid":99999,"acquired_at":"2026-01-01T00:00:00Z"}' > "$STALE_LOCK_PATH"

test_start "lock_check detects stale PID and auto-releases"
# lock_check on a stale lock: outputs stale_released, exits 1
output=$(lock_check "$TEST_RESOURCE_STALE" 2>/dev/null || true)
assert_contains "$output" "stale_released"

test_start "lock_acquire succeeds after stale auto-release"
expect_rc 0 lock_acquire "$TEST_RESOURCE_STALE" --holder "fresh" --timeout 1

# Clean up the stale test lock
lock_release "$TEST_RESOURCE_STALE" >/dev/null 2>&1 || true

echo ""

# ===============================================

report_summary
