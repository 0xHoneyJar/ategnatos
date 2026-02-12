#!/usr/bin/env bash
# test-comfyui-preflight.sh — Test suite for comfyui-preflight.sh
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

PREFLIGHT="$PROJECT_DIR/.claude/scripts/studio/comfyui-preflight.sh"
TEMP_DIR=""

setup() {
  # Create a temp dir inside the project root so validate_path allows it
  TEMP_DIR=$(mktemp -d "$PROJECT_DIR/tests/.tmp-preflight-XXXXXX")

  # Create a valid workflow JSON for tests that need one
  cat > "$TEMP_DIR/valid-workflow.json" <<'EOF'
{
  "1": {"class_type": "KSampler", "inputs": {}},
  "2": {"class_type": "CheckpointLoaderSimple", "inputs": {}},
  "3": {"class_type": "CLIPTextEncode", "inputs": {}}
}
EOF

  # Create an invalid JSON file
  echo '{not valid json content' > "$TEMP_DIR/invalid-workflow.json"
}

teardown() {
  [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}
trap teardown EXIT

echo "Testing: comfyui-preflight.sh"
echo ""

setup

# ===============================================
# Argument validation
# ===============================================

echo "--- argument validation ---"

test_start "Missing --workflow argument exits 1"
expect_rc 1 bash "$PREFLIGHT" --url "http://127.0.0.1:8188"

test_start "Missing --url argument exits 1"
expect_rc 1 bash "$PREFLIGHT" --workflow "$TEMP_DIR/valid-workflow.json"

test_start "Non-existent workflow file exits 1"
expect_rc 1 bash "$PREFLIGHT" --workflow "$TEMP_DIR/no-such-file.json" --url "http://127.0.0.1:8188"

test_start "Invalid JSON workflow file exits 1"
expect_rc 1 bash "$PREFLIGHT" --workflow "$TEMP_DIR/invalid-workflow.json" --url "http://127.0.0.1:8188"

test_start "Invalid URL scheme (ftp://) exits 1"
expect_rc 1 bash "$PREFLIGHT" --workflow "$TEMP_DIR/valid-workflow.json" --url "ftp://bad"

test_start "--help exits 0"
expect_rc 0 bash "$PREFLIGHT" --help

test_start "--help output contains usage information"
output=$(bash "$PREFLIGHT" --help 2>&1)
assert_contains "$output" "Usage"

echo ""

# ===============================================
# Workflow node extraction (jq parsing logic)
# ===============================================

echo "--- workflow node extraction ---"

test_start "jq extracts correct class_types from workflow JSON"
# Parse the test workflow and extract class_type values, same logic as the script
extracted=$(jq -r '.. | .class_type? // empty' "$TEMP_DIR/valid-workflow.json" | sort -u)
# Verify all three expected class_types are present (order may vary by locale)
has_all=true
for ct in KSampler CheckpointLoaderSimple CLIPTextEncode; do
  if ! echo "$extracted" | grep -qx "$ct"; then
    has_all=false
  fi
done
if [[ "$has_all" == true ]]; then
  test_pass
else
  test_fail "Expected KSampler, CheckpointLoaderSimple, CLIPTextEncode; got: $extracted"
fi

test_start "jq extracts correct count of unique class_types"
count=$(jq -r '.. | .class_type? // empty' "$TEMP_DIR/valid-workflow.json" | sort -u | wc -l | tr -d ' ')
assert_eq "3" "$count"

test_start "Empty workflow (no class_type) produces no output"
echo '{"1": {"inputs": {}}, "2": {"inputs": {}}}' > "$TEMP_DIR/empty-workflow.json"
extracted=$(jq -r '.. | .class_type? // empty' "$TEMP_DIR/empty-workflow.json" | sort -u)
if [[ -z "$extracted" ]]; then
  test_pass
else
  test_fail "Expected empty output for workflow without class_types, got: $extracted"
fi

echo ""

# ===============================================

report_summary
