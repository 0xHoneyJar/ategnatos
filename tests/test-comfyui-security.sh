#!/usr/bin/env bash
# test-comfyui-security.sh — Test suite for comfyui-security-check.sh
# Sprint 2, Cycle 3
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TESTS_DIR")"
source "$TESTS_DIR/lib/test-helpers.sh"

SCRIPT="$PROJECT_DIR/.claude/scripts/studio/comfyui-security-check.sh"

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

echo "Testing: comfyui-security-check.sh"
echo ""

# ═══════════════════════════════════════════════
# Localhost variants (all should PASS = exit 0)
# ═══════════════════════════════════════════════

echo "--- localhost endpoints ---"

test_start "localhost 127.0.0.1 passes (exit 0)"
expect_rc 0 "$SCRIPT" --url "http://127.0.0.1:8188"

test_start "localhost by name passes (exit 0)"
expect_rc 0 "$SCRIPT" --url "http://localhost:8188"

test_start "IPv6 localhost passes (exit 0)"
expect_rc 0 "$SCRIPT" --url "http://[::1]:8188"

echo ""

# ═══════════════════════════════════════════════
# Public and private IPs
# ═══════════════════════════════════════════════

echo "--- public / private endpoints ---"

test_start "public IP fails (exit 1)"
expect_rc 1 "$SCRIPT" --url "http://203.0.113.5:8188"

test_start "private IP warns (exit 2)"
expect_rc 2 "$SCRIPT" --url "http://192.168.1.100:8188"

echo ""

# ═══════════════════════════════════════════════
# --allow-remote flag
# ═══════════════════════════════════════════════

echo "--- --allow-remote ---"

test_start "--allow-remote with public IP does not fail with exit 1"
rc=0
"$SCRIPT" --url "http://203.0.113.5:8188" --allow-remote >/dev/null 2>&1 || rc=$?
# Should be 0 (tunnel found) or 2 (no tunnel), but NOT 1 (blocked)
if [[ "$rc" -eq 0 || "$rc" -eq 2 ]]; then
  test_pass
else
  test_fail "Expected exit code 0 or 2, got $rc"
fi

echo ""

# ═══════════════════════════════════════════════
# JSON output mode
# ═══════════════════════════════════════════════

echo "--- JSON output ---"

test_start "JSON output is valid JSON"
if command -v jq >/dev/null 2>&1; then
  output=$("$SCRIPT" --url "http://127.0.0.1:8188" --json 2>&1)
  if echo "$output" | jq empty 2>/dev/null; then
    test_pass
  else
    test_fail "Output is not valid JSON: $output"
  fi
else
  test_skip "jq not available"
fi

echo ""

# ═══════════════════════════════════════════════
# Invalid inputs
# ═══════════════════════════════════════════════

echo "--- invalid inputs ---"

test_start "invalid URL scheme rejected (exit 1)"
expect_rc 1 "$SCRIPT" --url "ftp://badscheme"

test_start "empty URL rejected (exit 1)"
expect_rc 1 "$SCRIPT"

echo ""

# ═══════════════════════════════════════════════

report_summary
