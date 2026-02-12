#!/usr/bin/env bash
# test-secrets-lib.sh — Test secrets management library
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TESTS_DIR")"
source "$TESTS_DIR/lib/test-helpers.sh"

TEMP_DIR=""

setup() {
  TEMP_DIR=$(mktemp -d /tmp/ategnatos-secrets-test-XXXXXX)
  # Unset guard so the library can be re-sourced per test group
  unset _SECRETS_LIB_LOADED 2>/dev/null || true
}

teardown() {
  cd "$PROJECT_DIR"
  [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
  unset MY_TEST_SECRET 2>/dev/null || true
  unset ATEGNATOS_SECRETS_FILE 2>/dev/null || true
  unset _SECRETS_LIB_LOADED 2>/dev/null || true
}
trap teardown EXIT

echo "Testing: secrets-lib.sh"
echo ""

# ==================================================
# load_secret — from environment variable
# ==================================================

echo "--- load_secret (env var) ---"

setup

export ATEGNATOS_SECRETS_FILE="$TEMP_DIR/nonexistent-secrets"
source "$PROJECT_DIR/.claude/scripts/lib/secrets-lib.sh"

test_start "load_secret reads from env var"
export MY_TEST_SECRET="supersecret123"
RESULT=$(load_secret "MY_TEST_SECRET")
assert_eq "supersecret123" "$RESULT" "Should return env var value"

test_start "load_secret with empty name returns 1"
if RESULT=$(load_secret "" 2>/dev/null); then
  test_fail "Should have returned non-zero exit code"
else
  test_pass
fi

# ==================================================
# load_secret — from secrets file
# ==================================================

echo ""
echo "--- load_secret (secrets file) ---"

teardown
setup

SECRETS_FILE="$TEMP_DIR/secrets"
cat > "$SECRETS_FILE" <<'SECRETS'
# Test secrets file
API_KEY=abc123
ANOTHER_KEY=xyz789
MULTI_WORD=hello world with spaces
SECRETS
chmod 600 "$SECRETS_FILE"

export ATEGNATOS_SECRETS_FILE="$SECRETS_FILE"
unset API_KEY 2>/dev/null || true
unset ANOTHER_KEY 2>/dev/null || true
unset MULTI_WORD 2>/dev/null || true

source "$PROJECT_DIR/.claude/scripts/lib/secrets-lib.sh"

test_start "load_secret reads key from file"
RESULT=$(load_secret "API_KEY")
assert_eq "abc123" "$RESULT" "Should return value from secrets file"

test_start "load_secret reads second key from file"
RESULT=$(load_secret "ANOTHER_KEY")
assert_eq "xyz789" "$RESULT" "Should return second key"

test_start "load_secret reads value with spaces"
RESULT=$(load_secret "MULTI_WORD")
assert_eq "hello world with spaces" "$RESULT" "Should preserve spaces in value"

test_start "load_secret returns 1 for nonexistent key"
if RESULT=$(load_secret "NONEXISTENT" 2>/dev/null); then
  test_fail "Should have returned non-zero exit code"
else
  test_pass
fi

test_start "load_secret rejects file with insecure permissions"
teardown
setup
INSECURE_FILE="$TEMP_DIR/insecure-secrets"
echo "LOOSE_KEY=oops" > "$INSECURE_FILE"
chmod 644 "$INSECURE_FILE"

export ATEGNATOS_SECRETS_FILE="$INSECURE_FILE"
unset LOOSE_KEY 2>/dev/null || true
unset _SECRETS_LIB_LOADED 2>/dev/null || true
source "$PROJECT_DIR/.claude/scripts/lib/secrets-lib.sh"

if RESULT=$(load_secret "LOOSE_KEY" 2>/dev/null); then
  test_fail "Should have rejected file with 0644 permissions"
else
  test_pass
fi

test_start "load_secret env var takes priority over file"
teardown
setup
PRIORITY_FILE="$TEMP_DIR/priority-secrets"
echo "PRIO_KEY=from_file" > "$PRIORITY_FILE"
chmod 600 "$PRIORITY_FILE"

export ATEGNATOS_SECRETS_FILE="$PRIORITY_FILE"
export PRIO_KEY="from_env"
unset _SECRETS_LIB_LOADED 2>/dev/null || true
source "$PROJECT_DIR/.claude/scripts/lib/secrets-lib.sh"

RESULT=$(load_secret "PRIO_KEY")
assert_eq "from_env" "$RESULT" "Env var should take priority over file"
unset PRIO_KEY 2>/dev/null || true

# ==================================================
# redact_log
# ==================================================

echo ""
echo "--- redact_log ---"

teardown
setup
export ATEGNATOS_SECRETS_FILE="$TEMP_DIR/nonexistent-secrets"
unset _SECRETS_LIB_LOADED 2>/dev/null || true
source "$PROJECT_DIR/.claude/scripts/lib/secrets-lib.sh"

test_start "redact_log returns empty for empty input"
RESULT=$(redact_log "")
assert_eq "" "$RESULT" "Empty input should produce empty output"

test_start "redact_log masks sk- style API keys"
RESULT=$(redact_log "my key is sk-abcdefghij1234")
assert_contains "$RESULT" 'sk-[*][*][*]1234' "Should mask sk- key keeping last 4"
assert_not_contains "$RESULT" "abcdefghij" "Should not contain original key chars"

test_start "redact_log masks longer sk- keys"
RESULT=$(redact_log "Token: sk-abcdefghijklmnopqrstuvwxyz5678")
assert_contains "$RESULT" 'sk-[*][*][*]5678' "Should mask longer sk- key"

test_start "redact_log masks SSH public keys"
RESULT=$(redact_log "ssh-rsa AAAA1234567890abcdef user@host")
assert_contains "$RESULT" 'ssh-[*][*][*]REDACTED' "Should mask SSH key"
assert_not_contains "$RESULT" "AAAA1234567890" "Should not contain original SSH key content"

test_start "redact_log masks ssh-ecdsa keys"
RESULT=$(redact_log "ssh-ecdsa AAAAabcdefghijklmnop user@host")
assert_contains "$RESULT" 'ssh-[*][*][*]REDACTED' "Should mask ecdsa SSH key"

test_start "redact_log masks long Token values"
RESULT=$(redact_log "Token=abcdefghijklmnopqrstuvwxyz1234567890")
assert_contains "$RESULT" "abcd" "Should keep first 4 chars"
assert_contains "$RESULT" "7890" "Should keep last 4 chars"
assert_contains "$RESULT" '[*][*][*]' "Should contain mask"
assert_not_contains "$RESULT" "klmnopqrstuvwx" "Middle chars should be masked"

test_start "redact_log masks Key= context pattern"
RESULT=$(redact_log "Key=ABCD1234567890abcdef1234567890XY9876")
assert_contains "$RESULT" '[*][*][*]' "Should contain mask for Key= pattern"

test_start "redact_log masks Secret context pattern"
RESULT=$(redact_log "Secret: abcdefghijklmnopqrstuvwxyz12345678")
assert_contains "$RESULT" '[*][*][*]' "Should contain mask for Secret pattern"

test_start "redact_log masks Password context pattern"
RESULT=$(redact_log "password=abcdefghijklmnopqrstuvwxyz12345678")
assert_contains "$RESULT" '[*][*][*]' "Should contain mask for password pattern"

test_start "redact_log leaves non-sensitive text unchanged"
RESULT=$(redact_log "Regular text without secrets")
assert_eq "Regular text without secrets" "$RESULT" "Non-sensitive text should pass through unchanged"

test_start "redact_log leaves short values unchanged"
RESULT=$(redact_log "Token=short")
assert_eq "Token=short" "$RESULT" "Short values should not be masked"

test_start "redact_log handles text with multiple secrets"
RESULT=$(redact_log "key1=sk-abcdefghijklmnop1234 and ssh-rsa AAAAabcdefghij end")
assert_contains "$RESULT" 'sk-[*][*][*]' "Should mask first secret"
assert_contains "$RESULT" 'ssh-[*][*][*]REDACTED' "Should mask second secret"

# ==================================================
# safe_log
# ==================================================

echo ""
echo "--- safe_log ---"

test_start "safe_log writes to stderr"
STDERR_OUTPUT=$(safe_log "hello from safe_log" 2>&1 1>/dev/null) || true
# safe_log writes to stderr, so capture stderr
CAPTURED=$(safe_log "hello from safe_log" 2>&1)
assert_contains "$CAPTURED" "hello from safe_log" "Should output to stderr"

test_start "safe_log redacts secrets in stderr output"
CAPTURED=$(safe_log "my key is sk-abcdefghij9999" 2>&1)
assert_contains "$CAPTURED" 'sk-[*][*][*]9999' "Should redact sk- key in stderr"
assert_not_contains "$CAPTURED" "abcdefghij" "Should not contain raw secret in stderr"

test_start "safe_log does not write to stdout"
STDOUT_OUTPUT=$(safe_log "test output" 2>/dev/null) || true
assert_eq "" "$STDOUT_OUTPUT" "stdout should be empty"

# ==================================================
# Summary
# ==================================================

report_summary
