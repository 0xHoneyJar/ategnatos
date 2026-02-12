#!/usr/bin/env bash
# test-cost-guard.sh — Test suite for cost-guard.sh
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

TEMP_DIR=""
TEST_TIMER_RESOURCE="test:timer:$$:$(date +%s)"
TEST_TIMER_OVERDUE="test:timer:overdue:$$"
CREATED_TIMER_FILES=()

setup() {
  # Create a temp project directory with a grimoire/cost-config.json
  TEMP_DIR=$(mktemp -d /tmp/ategnatos-cost-test-XXXXXX)
  mkdir -p "$TEMP_DIR/grimoire"

  cat > "$TEMP_DIR/grimoire/cost-config.json" <<'EOF'
{"max_hourly_rate":2.00,"max_total_cost":10.00,"max_runtime_minutes":60,"auto_teardown_minutes":5,"require_confirm":true}
EOF

  # Source the library under test
  # We cd into the temp dir so _cost_detect_project_root can find the config
  cd "$TEMP_DIR"
  source "$PROJECT_DIR/.claude/scripts/lib/cost-guard.sh"

  # Reset globals to force re-loading from our test config
  _COST_MAX_HOURLY=""
  _COST_MAX_TOTAL=""
  _COST_MAX_RUNTIME_MIN=""
  _COST_AUTO_TEARDOWN_MIN=""
  _COST_REQUIRE_CONFIRM=""

  # Load the test config
  cost_load_config
}

teardown() {
  # Remove any timer files we created
  for tf in "${CREATED_TIMER_FILES[@]}"; do
    rm -f "$tf"
  done
  # Also clean up by glob as a safety net
  rm -f /tmp/ategnatos-cost-timer-*.json 2>/dev/null || true
  # Remove temp directory
  [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
  # Return to original directory
  cd "$PROJECT_DIR"
}
trap teardown EXIT

echo "Testing: cost-guard.sh"
echo ""

setup

# ===============================================
# cost_load_config
# ===============================================

echo "--- cost_load_config ---"

test_start "cost_load_config reads max_total_cost correctly"
assert_eq "10.00" "$_COST_MAX_TOTAL"

test_start "cost_load_config reads max_hourly_rate correctly"
assert_eq "2.00" "$_COST_MAX_HOURLY"

test_start "cost_load_config reads max_runtime_minutes correctly"
assert_eq "60" "$_COST_MAX_RUNTIME_MIN"

test_start "cost_load_config reads auto_teardown_minutes correctly"
assert_eq "5" "$_COST_AUTO_TEARDOWN_MIN"

echo ""

# ===============================================
# cost_check
# ===============================================

echo "--- cost_check ---"

test_start "cost_check under budget exits 0"
expect_rc 0 cost_check --operation train --estimated 5.00

test_start "cost_check over budget exits 1"
expect_rc 1 cost_check --operation train --estimated 15.00

test_start "cost_check at exact budget exits 0"
expect_rc 0 cost_check --operation generate --estimated 10.00

echo ""

# ===============================================
# cost_start_timer / cost_report / cost_stop_timer
# ===============================================

echo "--- cost timers ---"

test_start "cost_start_timer creates timer file"
cost_start_timer --resource "$TEST_TIMER_RESOURCE" --rate 1.50 >/dev/null 2>&1
timer_path="$(_cost_timer_path "$TEST_TIMER_RESOURCE")"
CREATED_TIMER_FILES+=("$timer_path")
if [[ -f "$timer_path" ]]; then
  test_pass
else
  test_fail "Timer file not found at $timer_path"
fi

test_start "cost_report shows active timer"
output=$(cost_report 2>&1)
assert_contains "$output" "$TEST_TIMER_RESOURCE"

test_start "cost_stop_timer removes timer and reports"
output=$(cost_stop_timer --resource "$TEST_TIMER_RESOURCE" 2>&1)
if [[ ! -f "$timer_path" ]]; then
  # Timer file removed; check output mentions the resource
  assert_contains "$output" "Timer stopped"
else
  test_fail "Timer file still exists after cost_stop_timer"
fi

echo ""

# ===============================================
# cost_teardown_overdue
# ===============================================

echo "--- cost_teardown_overdue ---"

test_start "cost_teardown_overdue with no timers exits 0"
expect_rc 0 cost_teardown_overdue

test_start "cost_teardown_overdue with expired timer exits 1"
# Create a timer file with started_at far in the past (1 hour ago = 3600 seconds)
# auto_teardown_minutes is 5 in our config, so 1 hour is well past overdue
overdue_timer_path="$(_cost_timer_path "$TEST_TIMER_OVERDUE")"
CREATED_TIMER_FILES+=("$overdue_timer_path")

past_timestamp=$(( $(date +%s) - 3600 ))
jq -n \
  --arg resource "$TEST_TIMER_OVERDUE" \
  --argjson rate 2.00 \
  --argjson started_at "$past_timestamp" \
  --argjson max_minutes 60 \
  '{resource: $resource, rate: $rate, started_at: $started_at, max_minutes: $max_minutes}' \
  > "$overdue_timer_path"

expect_rc 1 cost_teardown_overdue

# Clean up the overdue timer
rm -f "$overdue_timer_path"

echo ""

# ===============================================

report_summary
