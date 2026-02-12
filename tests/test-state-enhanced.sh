#!/usr/bin/env bash
# test-state-enhanced.sh — Test suite for enhanced state-lib.sh features
# Tests: state_check, state_backup, state_schema_version, modified state_sync
# Sprint 2, Cycle 3
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TESTS_DIR")"
source "$TESTS_DIR/lib/test-helpers.sh"

TEMP_DIR=""

# Helper: capture exit code of a command that may fail.
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

setup() {
  TEMP_DIR=$(mktemp -d /tmp/ategnatos-state-enhanced-XXXXXX)
  # Override STATE_DIR and grimoire paths for isolation
  export STATE_DIR="$TEMP_DIR/.state"
  mkdir -p "$TEMP_DIR/grimoire"
  cd "$TEMP_DIR"
  # Source the library under test
  source "$PROJECT_DIR/.claude/scripts/lib/state-lib.sh"
}

teardown() {
  cd "$PROJECT_DIR"
  [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}
trap teardown EXIT

echo "Testing: state-lib.sh (enhanced features)"
echo ""

# Detect Apple jq bug: some jq builds return 0 for invalid JSON via
# jq empty, which causes state_set to misroute string values.
# Workaround: wrap plain strings in JSON quotes so they parse correctly
# through state_set's detection logic.
_apple_jq_broken=false
if echo "not json" | jq empty 2>/dev/null; then
  _apple_jq_broken=true
fi

# Helper: call state_set with a string value, working around Apple jq
state_set_str() {
  local scope="$1" path="$2" value="$3"
  if $_apple_jq_broken; then
    # Pass as valid JSON string so jq's first branch works
    state_set "$scope" "$path" "\"$value\""
  else
    state_set "$scope" "$path" "$value"
  fi
}

setup

# ═══════════════════════════════════════════════
# state_init — schema version and metadata fields
# ═══════════════════════════════════════════════

echo "--- state_init metadata ---"

test_start "state_init includes _schema_version"
state_init "studio" >/dev/null
version=$(jq -r '._schema_version' "$STATE_DIR/studio.json")
assert_eq "1.0" "$version"

test_start "state_init includes _generated_at as null"
gen=$(jq -r '._generated_at' "$STATE_DIR/studio.json")
assert_eq "null" "$gen"

echo ""

# ═══════════════════════════════════════════════
# state_sync — header, hash, backup, timestamp
# ═══════════════════════════════════════════════

echo "--- state_sync ---"

test_start "state_sync generates header with GENERATED marker"
state_set_str "studio" ".environment.gpu" "RTX 4090"
state_sync "studio" >/dev/null
header=$(head -1 grimoire/studio.md)
if echo "$header" | grep -q "GENERATED"; then
  test_pass
else
  test_fail "First line does not contain GENERATED marker: $header"
fi

test_start "state_sync header contains hash"
header=$(head -1 grimoire/studio.md)
if echo "$header" | grep -qE 'hash: [a-f0-9]{8}'; then
  test_pass
else
  test_fail "Header does not contain hash pattern: $header"
fi

test_start "state_sync updates _generated_at"
gen=$(jq -r '._generated_at' "$STATE_DIR/studio.json")
if [[ "$gen" != "null" && -n "$gen" ]]; then
  test_pass
else
  test_fail "_generated_at is still null or empty after sync"
fi

test_start "state_sync creates .bak of previous MD"
# First sync already happened above; sync again to trigger backup
state_sync "studio" >/dev/null
if [[ -f "grimoire/studio.md.bak" ]]; then
  test_pass
else
  test_fail "grimoire/studio.md.bak not found after second sync"
fi

echo ""

# ═══════════════════════════════════════════════
# state_check — clean, drift, missing
# ═══════════════════════════════════════════════

echo "--- state_check ---"

test_start "state_check passes after clean sync (exit 0)"
# Re-sync to ensure hash is fresh
state_sync "studio" >/dev/null
rc=0
state_check "studio" >/dev/null 2>&1 || rc=$?
assert_eq "0" "$rc"

test_start "state_check detects drift after JSON change (exit 1)"
# Modify the JSON after sync so its hash no longer matches the MD header
state_set_str "studio" ".environment.gpu" "RTX 5090"
rc=0
state_check "studio" >/dev/null 2>&1 || rc=$?
assert_eq "1" "$rc"

test_start "state_check returns 2 for missing files"
rc=0
state_check "nonexistent" >/dev/null 2>&1 || rc=$?
assert_eq "2" "$rc"

echo ""

# ═══════════════════════════════════════════════
# state_backup
# ═══════════════════════════════════════════════

echo "--- state_backup ---"

test_start "state_backup creates .bak files"
state_backup "studio" >/dev/null
bak_files=$(ls "$STATE_DIR"/studio.json.*.bak 2>/dev/null | head -1)
if [[ -n "$bak_files" ]]; then
  test_pass
else
  test_fail "No .bak files found in $STATE_DIR"
fi

echo ""

# ═══════════════════════════════════════════════
# state_schema_version
# ═══════════════════════════════════════════════

echo "--- state_schema_version ---"

test_start "state_schema_version returns 1.0"
version=$(state_schema_version "studio")
assert_eq "1.0" "$version"

echo ""

# ═══════════════════════════════════════════════

report_summary
