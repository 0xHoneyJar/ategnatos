#!/usr/bin/env bash
# test-helpers.sh — Simple test assertion library for bash scripts
# Usage: source this file in test scripts

[[ -n "${_TEST_HELPERS_LOADED:-}" ]] && return 0
_TEST_HELPERS_LOADED=1

# Counters
_TEST_PASS=0
_TEST_FAIL=0
_TEST_TOTAL=0
_TEST_NAME=""
_TEST_FAILURES=()

# Colors (only if terminal supports it)
if [[ -t 1 ]]; then
  _GREEN='\033[0;32m'
  _RED='\033[0;31m'
  _YELLOW='\033[0;33m'
  _NC='\033[0m'
else
  _GREEN=''
  _RED=''
  _YELLOW=''
  _NC=''
fi

test_start() {
  _TEST_NAME="$1"
  _TEST_TOTAL=$((_TEST_TOTAL + 1))
  printf "  %-60s " "$_TEST_NAME"
}

test_pass() {
  _TEST_PASS=$((_TEST_PASS + 1))
  printf "${_GREEN}PASS${_NC}\n"
}

test_fail() {
  local reason="${1:-}"
  _TEST_FAIL=$((_TEST_FAIL + 1))
  printf "${_RED}FAIL${_NC}\n"
  if [[ -n "$reason" ]]; then
    printf "    ${_RED}→ %s${_NC}\n" "$reason"
  fi
  _TEST_FAILURES+=("$_TEST_NAME: $reason")
}

test_skip() {
  local reason="${1:-}"
  printf "${_YELLOW}SKIP${_NC}"
  if [[ -n "$reason" ]]; then
    printf " (%s)" "$reason"
  fi
  printf "\n"
  # Skips don't count as pass or fail
  _TEST_TOTAL=$((_TEST_TOTAL - 1))
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Expected '$expected', got '$actual'}"
  if [[ "$expected" == "$actual" ]]; then
    test_pass
  else
    test_fail "$message (expected: '$expected', got: '$actual')"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-Expected output to contain '$needle'}"
  if echo "$haystack" | grep -q "$needle"; then
    test_pass
  else
    test_fail "$message"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-Expected output NOT to contain '$needle'}"
  if ! echo "$haystack" | grep -q "$needle"; then
    test_pass
  else
    test_fail "$message"
  fi
}

assert_file_exists() {
  local path="$1"
  local message="${2:-File should exist: $path}"
  if [[ -f "$path" ]]; then
    test_pass
  else
    test_fail "$message"
  fi
}

assert_dir_exists() {
  local path="$1"
  local message="${2:-Directory should exist: $path}"
  if [[ -d "$path" ]]; then
    test_pass
  else
    test_fail "$message"
  fi
}

assert_exit_code() {
  local expected="$1"
  shift
  local actual
  "$@" >/dev/null 2>&1
  actual=$?
  if [[ "$expected" == "$actual" ]]; then
    test_pass
  else
    test_fail "Expected exit code $expected, got $actual"
  fi
}

report_summary() {
  echo ""
  echo "=== Test Summary ==="
  echo "  Total:  $_TEST_TOTAL"
  printf "  Passed: ${_GREEN}%d${_NC}\n" "$_TEST_PASS"
  if (( _TEST_FAIL > 0 )); then
    printf "  Failed: ${_RED}%d${_NC}\n" "$_TEST_FAIL"
    echo ""
    echo "  Failed tests:"
    for f in "${_TEST_FAILURES[@]}"; do
      printf "    ${_RED}✗${_NC} %s\n" "$f"
    done
  else
    printf "  Failed: ${_GREEN}0${_NC}\n"
  fi
  echo ""

  if (( _TEST_FAIL > 0 )); then
    return 1
  fi
  return 0
}
