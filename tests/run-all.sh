#!/usr/bin/env bash
# run-all.sh — Discover and run all test-*.sh files
# Usage: tests/run-all.sh [test-pattern]

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SUITES=0
FAILED_SUITES=()

# Colors
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  NC='\033[0m'
else
  GREEN=''
  RED=''
  NC=''
fi

PATTERN="${1:-test-*.sh}"

echo "=== Ategnatos Test Runner ==="
echo ""

for test_file in "$TESTS_DIR"/$PATTERN; do
  [[ -f "$test_file" ]] || continue
  TOTAL_SUITES=$((TOTAL_SUITES + 1))
  SUITE_NAME=$(basename "$test_file" .sh)

  echo "--- $SUITE_NAME ---"

  if bash "$test_file"; then
    TOTAL_PASS=$((TOTAL_PASS + 1))
  else
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
    FAILED_SUITES+=("$SUITE_NAME")
  fi

  echo ""
done

echo "==============================="
echo "  Suites run:    $TOTAL_SUITES"
printf "  Suites passed: ${GREEN}%d${NC}\n" "$TOTAL_PASS"
if (( TOTAL_FAIL > 0 )); then
  printf "  Suites failed: ${RED}%d${NC}\n" "$TOTAL_FAIL"
  echo ""
  echo "  Failed suites:"
  for s in "${FAILED_SUITES[@]}"; do
    printf "    ${RED}✗${NC} %s\n" "$s"
  done
  exit 1
else
  printf "  Suites failed: ${GREEN}0${NC}\n"
fi
echo "==============================="
