#!/usr/bin/env bash
# test-dataset-pipeline.sh — Test dataset-audit.sh and structure-dataset.sh
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TESTS_DIR")"
source "$TESTS_DIR/lib/test-helpers.sh"

SCRIPTS="$PROJECT_DIR/.claude/scripts/train"
FIXTURES="$TESTS_DIR/fixtures/sample-images"
TEMP_DIR=""

# Setup
setup() {
  TEMP_DIR=$(mktemp -d /tmp/ategnatos-test-XXXXXX)
  # Create minimal test images using sips or touch
  mkdir -p "$TEMP_DIR/dataset"
  for i in 1 2 3 4 5; do
    # Create 1x1 PNG files (minimal valid PNG)
    printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x04\x00\x00\x00\x04\x00\x08\x02\x00\x00\x00\x26\x93\x09\x29\x00\x00\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB\x60\x82' > "$TEMP_DIR/dataset/img_${i}.png" 2>/dev/null || touch "$TEMP_DIR/dataset/img_${i}.png"
    echo "test caption for image $i" > "$TEMP_DIR/dataset/img_${i}.txt"
  done
  # One uncaptioned image
  printf '\x89PNG\r\n\x1a\n' > "$TEMP_DIR/dataset/no_caption.png" 2>/dev/null || touch "$TEMP_DIR/dataset/no_caption.png"
}

# Teardown
teardown() {
  [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}
trap teardown EXIT

echo "Testing: Dataset Pipeline"
echo ""

setup

# --- dataset-audit.sh tests ---

test_start "dataset-audit.sh --help exits 0"
bash "$SCRIPTS/dataset-audit.sh" --help >/dev/null 2>&1
assert_eq "0" "$?" "Should exit 0"

test_start "dataset-audit.sh detects images"
OUTPUT=$(bash "$SCRIPTS/dataset-audit.sh" "$TEMP_DIR/dataset" 2>&1) || true
assert_contains "$OUTPUT" "Total images:" "Should report total images"

test_start "dataset-audit.sh detects uncaptioned images"
OUTPUT=$(bash "$SCRIPTS/dataset-audit.sh" "$TEMP_DIR/dataset" 2>&1) || true
assert_contains "$OUTPUT" "no_caption" "Should flag uncaptioned image"

test_start "dataset-audit.sh JSON mode works"
OUTPUT=$(bash "$SCRIPTS/dataset-audit.sh" "$TEMP_DIR/dataset" --json 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
  test_pass
else
  test_fail "JSON output is not valid JSON"
fi

test_start "dataset-audit.sh detects flat format"
OUTPUT=$(bash "$SCRIPTS/dataset-audit.sh" "$TEMP_DIR/dataset" --json 2>&1) || true
FORMAT=$(echo "$OUTPUT" | jq -r '.dataset_format // empty' 2>/dev/null)
assert_eq "flat" "$FORMAT" "Should detect flat format"

# --- structure-dataset.sh tests ---

test_start "structure-dataset.sh --help exits 0"
bash "$SCRIPTS/structure-dataset.sh" --help >/dev/null 2>&1
assert_eq "0" "$?" "Should exit 0"

test_start "structure-dataset.sh creates Kohya folder"
bash "$SCRIPTS/structure-dataset.sh" \
  --input "$TEMP_DIR/dataset" \
  --output "$TEMP_DIR/structured" \
  --name teststyle \
  --repeats 3 >/dev/null 2>&1
assert_dir_exists "$TEMP_DIR/structured/3_teststyle" "Should create 3_teststyle/"

test_start "structure-dataset.sh copies images"
COPIED=$(ls "$TEMP_DIR/structured/3_teststyle/"*.png 2>/dev/null | wc -l | tr -d ' ')
# Should have 6 images (5 captioned + 1 uncaptioned)
assert_eq "6" "$COPIED" "Should copy all 6 images"

test_start "structure-dataset.sh copies captions"
CAPTIONS=$(ls "$TEMP_DIR/structured/3_teststyle/"*.txt 2>/dev/null | wc -l | tr -d ' ')
assert_eq "5" "$CAPTIONS" "Should copy 5 caption files"

test_start "structure-dataset.sh auto-repeats calculation"
OUTPUT=$(bash "$SCRIPTS/structure-dataset.sh" \
  --input "$TEMP_DIR/dataset" \
  --output "$TEMP_DIR/structured_auto" \
  --name autotest \
  --repeats auto \
  --epochs 15 \
  --target-steps 1500 2>&1) || true
assert_contains "$OUTPUT" "auto-calculated" "Should mention auto-calculation"

test_start "structure-dataset.sh JSON mode"
OUTPUT=$(bash "$SCRIPTS/structure-dataset.sh" \
  --input "$TEMP_DIR/dataset" \
  --output "$TEMP_DIR/structured_json" \
  --name jsontest \
  --repeats 2 \
  --json 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
  test_pass
else
  test_fail "JSON output is not valid JSON"
fi

report_summary
