#!/usr/bin/env bash
# test-scripts-help.sh — Verify all scripts respond to --help without errors
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TESTS_DIR")"
source "$TESTS_DIR/lib/test-helpers.sh"

echo "Testing: All scripts respond to --help"
echo ""

# Find all .sh scripts in .claude/scripts/
SCRIPTS_DIR="$PROJECT_DIR/.claude/scripts"
FOUND=0
TESTED=0

for script in $(find "$SCRIPTS_DIR" -name '*.sh' -type f | sort); do
  FOUND=$((FOUND + 1))
  REL_PATH="${script#$PROJECT_DIR/}"
  BASENAME=$(basename "$script")

  # Skip libraries (sourced, not executed)
  case "$BASENAME" in
    *-lib.sh|*_lib.sh) continue ;;
    compat-lib.sh) continue ;;
  esac

  TESTED=$((TESTED + 1))
  test_start "$REL_PATH --help"

  # First check bash syntax
  if ! bash -n "$script" 2>/dev/null; then
    test_fail "Syntax error in script"
    continue
  fi

  # Run --help and check exit code
  OUTPUT=$(bash "$script" --help 2>&1) || EXIT_CODE=$?
  EXIT_CODE=${EXIT_CODE:-0}

  if [[ $EXIT_CODE -eq 0 ]]; then
    # Check that output contains something useful
    if echo "$OUTPUT" | grep -qi "usage\|Usage\|USAGE\|help\|Help"; then
      test_pass
    else
      test_fail "Exit 0 but no usage information in output"
    fi
  else
    test_fail "Exit code $EXIT_CODE"
  fi
done

echo ""
echo "Found $FOUND scripts, tested $TESTED (skipped $((FOUND - TESTED)) libraries)"

report_summary
