#!/usr/bin/env bash
# test-state-lib.sh — Test state management library
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TESTS_DIR")"
source "$TESTS_DIR/lib/test-helpers.sh"

TEMP_DIR=""

setup() {
  TEMP_DIR=$(mktemp -d /tmp/ategnatos-state-test-XXXXXX)
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

echo "Testing: state-lib.sh"
echo ""

setup

# --- state_init ---

test_start "state_init creates JSON file"
RESULT=$(state_init "studio")
assert_file_exists "$STATE_DIR/studio.json" "Should create studio.json"

test_start "state_init creates valid JSON"
if jq empty "$STATE_DIR/studio.json" 2>/dev/null; then
  test_pass
else
  test_fail "Generated JSON is invalid"
fi

test_start "state_init studio has expected structure"
HAS_ENV=$(jq 'has("environment")' "$STATE_DIR/studio.json")
HAS_MODELS=$(jq 'has("models")' "$STATE_DIR/studio.json")
if [[ "$HAS_ENV" == "true" && "$HAS_MODELS" == "true" ]]; then
  test_pass
else
  test_fail "Missing expected keys"
fi

# --- state_set / state_get ---

test_start "state_set writes string value"
state_set "studio" ".environment.gpu" "RTX 4090"
RESULT=$(state_get "studio" ".environment.gpu")
assert_eq "RTX 4090" "$RESULT" "Should read back written value"

test_start "state_set writes numeric value"
state_set "studio" ".environment.vram_gb" "24"
RESULT=$(state_get "studio" ".environment.vram_gb")
assert_eq "24" "$RESULT" "Should read back numeric value"

# --- state_append ---

test_start "state_append adds object to array"
state_append "studio" ".models" '{"name":"Pony V6","type":"checkpoint","base":"SDXL","good_for":"stylized","location":"/models/pony.safetensors","settings":"CFG 7"}'
RESULT=$(state_get "studio" ".models | length")
assert_eq "1" "$RESULT" "Should have 1 model"

test_start "state_append adds second object"
state_append "studio" ".models" '{"name":"Flux Dev","type":"checkpoint","base":"Flux","good_for":"photorealistic","location":"/models/flux.safetensors","settings":"CFG 1"}'
RESULT=$(state_get "studio" ".models | length")
assert_eq "2" "$RESULT" "Should have 2 models"

test_start "state_get retrieves nested value"
RESULT=$(state_get "studio" ".models[0].name")
assert_eq "Pony V6" "$RESULT" "Should get first model name"

# --- state_remove ---

test_start "state_remove deletes by key match"
state_remove "studio" ".models" "name" "Pony V6"
RESULT=$(state_get "studio" ".models | length")
assert_eq "1" "$RESULT" "Should have 1 model after removal"

test_start "state_remove keeps non-matching items"
RESULT=$(state_get "studio" ".models[0].name")
assert_eq "Flux Dev" "$RESULT" "Should keep Flux Dev"

# --- state_sync ---

test_start "state_sync generates markdown"
# Set up some data first
state_set "studio" ".environment.comfyui" "http://localhost:8188"
state_append "studio" ".loras" '{"name":"mystyle","trigger":"mystyle","weight_range":"0.5-0.7","trained_on":"Pony V6","location":"/loras/mystyle.safetensors"}'

mkdir -p grimoire
RESULT=$(state_sync "studio")
assert_file_exists "grimoire/studio.md" "Should create studio.md"

test_start "state_sync markdown contains GPU info"
CONTENT=$(cat grimoire/studio.md)
assert_contains "$CONTENT" "RTX 4090" "Should contain GPU name"

test_start "state_sync markdown contains model table"
assert_contains "$CONTENT" "Flux Dev" "Should contain model name"

test_start "state_sync markdown contains LoRA table"
assert_contains "$CONTENT" "mystyle" "Should contain LoRA name"

# --- state_migrate ---

test_start "state_migrate parses markdown back to JSON"
# Remove the JSON so we test migration from scratch
rm "$STATE_DIR/studio.json"
RESULT=$(state_migrate "studio")
assert_file_exists "$STATE_DIR/studio.json" "Should create JSON from markdown"

test_start "state_migrate preserves GPU info"
RESULT=$(state_get "studio" ".environment.gpu")
assert_eq "RTX 4090" "$RESULT" "Should preserve GPU name"

test_start "state_migrate preserves models"
RESULT=$(state_get "studio" ".models | length")
# Should have at least 1 model (Flux Dev)
if [[ "$RESULT" -ge 1 ]]; then
  test_pass
else
  test_fail "Expected at least 1 model, got $RESULT"
fi

report_summary
