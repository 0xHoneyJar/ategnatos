#!/usr/bin/env bash
# test-validate-lib.sh — Test suite for validate-lib.sh
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TESTS_DIR")"
source "$TESTS_DIR/lib/test-helpers.sh"

TEMP_DIR=""
TEMP_JSON_DIR=""

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

setup() {
  # Create a temp dir inside the project root so validate_path
  # can resolve it within _PROJECT_ROOT
  TEMP_DIR=$(mktemp -d "$PROJECT_DIR/tests/.tmp-validate-XXXXXX")

  # Create a separate temp dir for JSON test files (can be anywhere)
  TEMP_JSON_DIR=$(mktemp -d /tmp/ategnatos-validate-json-XXXXXX)

  # Source the library under test
  # This sets _PROJECT_ROOT by walking up from the lib's BASH_SOURCE
  source "$PROJECT_DIR/.claude/scripts/lib/validate-lib.sh"
}

teardown() {
  [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
  [[ -n "$TEMP_JSON_DIR" && -d "$TEMP_JSON_DIR" ]] && rm -rf "$TEMP_JSON_DIR"
}
trap teardown EXIT

echo "Testing: validate-lib.sh"
echo ""

setup

# ═══════════════════════════════════════════════
# validate_path
# ═══════════════════════════════════════════════

echo "--- validate_path ---"

test_start "validate_path: empty path returns 1"
expect_rc 1 validate_path ""

test_start "validate_path: path with '..' returns 1"
expect_rc 1 validate_path "$TEMP_DIR/../../../etc/passwd"

test_start "validate_path: path inside project root returns 0"
expect_rc 0 validate_path "$PROJECT_DIR/CLAUDE.md"

test_start "validate_path: path outside project root returns 1"
expect_rc 1 validate_path "/tmp/outside-project-file"

test_start "validate_path: non-existent parent dir returns 1"
expect_rc 1 validate_path "$PROJECT_DIR/no-such-parent-dir/file.txt"

test_start "validate_path: valid non-existent file (parent exists) returns 0"
expect_rc 0 validate_path "$TEMP_DIR/new-file-that-does-not-exist.txt"

test_start "validate_path: existing directory returns 0"
expect_rc 0 validate_path "$TEMP_DIR"

test_start "validate_path: bare '..' returns 1"
expect_rc 1 validate_path ".."

echo ""

# ═══════════════════════════════════════════════
# validate_url
# ═══════════════════════════════════════════════

echo "--- validate_url ---"

test_start "validate_url: empty returns 1"
expect_rc 1 validate_url ""

test_start "validate_url: https://example.com returns 0"
expect_rc 0 validate_url "https://example.com"

test_start "validate_url: http://example.com returns 0"
expect_rc 0 validate_url "http://example.com"

test_start "validate_url: ftp://example.com returns 1"
expect_rc 1 validate_url "ftp://example.com"

test_start "validate_url: https://user:pass@host.com returns 1"
expect_rc 1 validate_url "https://user:pass@host.com"

test_start "validate_url: https://user@host.com returns 1"
expect_rc 1 validate_url "https://user@host.com"

test_start "validate_url: https:// (no host) returns 1"
expect_rc 1 validate_url "https://"

test_start "validate_url: https://example.com/path returns 0"
expect_rc 0 validate_url "https://example.com/path/to/resource"

echo ""

# ═══════════════════════════════════════════════
# validate_url_localhost
# ═══════════════════════════════════════════════

echo "--- validate_url_localhost ---"

test_start "validate_url_localhost: http://localhost:8188 returns 0"
expect_rc 0 validate_url_localhost "http://localhost:8188"

test_start "validate_url_localhost: http://127.0.0.1:8188 returns 0"
expect_rc 0 validate_url_localhost "http://127.0.0.1:8188"

test_start "validate_url_localhost: http://[::1]:8188 returns 0"
expect_rc 0 validate_url_localhost "http://[::1]:8188"

test_start "validate_url_localhost: https://example.com returns 1"
expect_rc 1 validate_url_localhost "https://example.com"

test_start "validate_url_localhost: http://localhost (no port) returns 0"
expect_rc 0 validate_url_localhost "http://localhost"

test_start "validate_url_localhost: http://192.168.1.1:8188 returns 1"
expect_rc 1 validate_url_localhost "http://192.168.1.1:8188"

echo ""

# ═══════════════════════════════════════════════
# validate_provider_id
# ═══════════════════════════════════════════════

echo "--- validate_provider_id ---"

test_start "validate_provider_id: 'vast' returns 0"
expect_rc 0 validate_provider_id "vast"

test_start "validate_provider_id: 'runpod' returns 0"
expect_rc 0 validate_provider_id "runpod"

test_start "validate_provider_id: 'lambda' returns 0"
expect_rc 0 validate_provider_id "lambda"

test_start "validate_provider_id: 'local' returns 0"
expect_rc 0 validate_provider_id "local"

test_start "validate_provider_id: 'aws' returns 1"
expect_rc 1 validate_provider_id "aws"

test_start "validate_provider_id: empty returns 1"
expect_rc 1 validate_provider_id ""

test_start "validate_provider_id: 'VAST' (wrong case) returns 1"
expect_rc 1 validate_provider_id "VAST"

echo ""

# ═══════════════════════════════════════════════
# validate_backend_id
# ═══════════════════════════════════════════════

echo "--- validate_backend_id ---"

test_start "validate_backend_id: 'kohya' returns 0"
expect_rc 0 validate_backend_id "kohya"

test_start "validate_backend_id: 'simpletuner' returns 0"
expect_rc 0 validate_backend_id "simpletuner"

test_start "validate_backend_id: 'ai-toolkit' returns 0"
expect_rc 0 validate_backend_id "ai-toolkit"

test_start "validate_backend_id: 'dreambooth' returns 1"
expect_rc 1 validate_backend_id "dreambooth"

test_start "validate_backend_id: empty returns 1"
expect_rc 1 validate_backend_id ""

echo ""

# ═══════════════════════════════════════════════
# validate_positive_int
# ═══════════════════════════════════════════════

echo "--- validate_positive_int ---"

test_start "validate_positive_int: '42' returns 0"
expect_rc 0 validate_positive_int "42"

test_start "validate_positive_int: '1' returns 0"
expect_rc 0 validate_positive_int "1"

test_start "validate_positive_int: '0' returns 1"
expect_rc 1 validate_positive_int "0"

test_start "validate_positive_int: '-1' returns 1"
expect_rc 1 validate_positive_int "-1"

test_start "validate_positive_int: 'abc' returns 1"
expect_rc 1 validate_positive_int "abc"

test_start "validate_positive_int: empty returns 1"
expect_rc 1 validate_positive_int ""

test_start "validate_positive_int: '3.14' returns 1"
expect_rc 1 validate_positive_int "3.14"

test_start "validate_positive_int: '00' (leading zeros only) returns 1"
expect_rc 1 validate_positive_int "00"

echo ""

# ═══════════════════════════════════════════════
# validate_json_file
# ═══════════════════════════════════════════════

echo "--- validate_json_file ---"

# Check for jq — skip JSON tests if not available
if command -v jq >/dev/null 2>&1; then

  # Detect whether jq properly returns non-zero on invalid JSON.
  # Some jq builds (e.g., apple-gcff5336) always return 0.
  _jq_reports_errors=true
  echo '{invalid' > "$TEMP_JSON_DIR/jq-probe.json"
  if jq empty "$TEMP_JSON_DIR/jq-probe.json" 2>/dev/null; then
    _jq_reports_errors=false
  fi
  rm -f "$TEMP_JSON_DIR/jq-probe.json"

  # Create test fixtures in temp dir
  echo '{"name": "test", "value": 42}' > "$TEMP_JSON_DIR/valid.json"
  echo '{bad json content' > "$TEMP_JSON_DIR/invalid.json"
  # shellcheck disable=SC2016
  echo '{"cmd": "$(rm -rf /)"}' > "$TEMP_JSON_DIR/injection-subst.json"
  echo '{"cmd": "`rm -rf /`"}' > "$TEMP_JSON_DIR/injection-backtick.json"

  test_start "validate_json_file: valid JSON file returns 0"
  expect_rc 0 validate_json_file "$TEMP_JSON_DIR/valid.json"

  test_start "validate_json_file: invalid JSON file returns 1"
  if [[ "$_jq_reports_errors" == true ]]; then
    expect_rc 1 validate_json_file "$TEMP_JSON_DIR/invalid.json"
  else
    test_skip "jq build does not return non-zero for invalid JSON"
  fi

  test_start "validate_json_file: non-existent file returns 1"
  expect_rc 1 validate_json_file "$TEMP_JSON_DIR/no-such-file.json"

  # shellcheck disable=SC2016
  test_start 'validate_json_file: JSON with $( command substitution returns 1'
  expect_rc 1 validate_json_file "$TEMP_JSON_DIR/injection-subst.json"

  test_start "validate_json_file: JSON with backtick returns 1"
  expect_rc 1 validate_json_file "$TEMP_JSON_DIR/injection-backtick.json"

  test_start "validate_json_file: empty path returns 1"
  expect_rc 1 validate_json_file ""

  # Test with a valid but complex JSON file
  cat > "$TEMP_JSON_DIR/complex.json" <<'JSONEOF'
{
  "training": {
    "epochs": 10,
    "batch_size": 4,
    "learning_rate": 0.0001,
    "tags": ["style", "character", "background"]
  }
}
JSONEOF

  test_start "validate_json_file: complex valid JSON returns 0"
  expect_rc 0 validate_json_file "$TEMP_JSON_DIR/complex.json"

else
  test_start "validate_json_file: (all tests)"
  test_skip "jq not available"
fi

echo ""

# ═══════════════════════════════════════════════
# Error message content tests
# ═══════════════════════════════════════════════

echo "--- error messages ---"

test_start "validate_path: empty path error mentions 'empty'"
output=$(validate_path "" 2>&1 || true)
assert_contains "$output" "empty"

test_start "validate_url: bad scheme error mentions 'http'"
output=$(validate_url "ftp://example.com" 2>&1 || true)
assert_contains "$output" "http"

test_start "validate_url: credentials error mentions 'credentials'"
output=$(validate_url "https://user:pass@host.com" 2>&1 || true)
assert_contains "$output" "credentials"

test_start "validate_provider_id: unknown provider lists valid ones"
output=$(validate_provider_id "aws" 2>&1 || true)
assert_contains "$output" "vast"

test_start "validate_backend_id: unknown backend lists valid ones"
output=$(validate_backend_id "dreambooth" 2>&1 || true)
assert_contains "$output" "kohya"

echo ""

# ═══════════════════════════════════════════════

report_summary
