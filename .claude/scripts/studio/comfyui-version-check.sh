#!/usr/bin/env bash
# comfyui-version-check.sh — Check ComfyUI version against minimum supported version
# Usage: comfyui-version-check.sh --url <endpoint> [--json]
#
# Queries the ComfyUI /system_stats endpoint to get version and commit info,
# then compares against the minimum supported version for Ategnatos.
# Exit codes: 0 = version OK, 1 = too old or unreachable.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=../lib/validate-lib.sh
source "$SCRIPT_DIR/../lib/validate-lib.sh"

# ── Constants ────────────────────────────────────────
MIN_VERSION="0.2.0"  # Minimum ComfyUI version for Ategnatos

# ── Defaults ─────────────────────────────────────────
URL=""
JSON_MODE=false

# ── Argument parsing ─────────────────────────────────
show_help() {
  cat <<'USAGE'
Usage: comfyui-version-check.sh --url <endpoint> [--json]

Check ComfyUI version against the minimum supported version for Ategnatos.

Arguments:
  --url URL          ComfyUI endpoint (e.g. http://127.0.0.1:8188)
  --json             Output results in JSON format
  --help, -h         Show this help message

Exit codes:
  0   Version meets minimum requirement
  1   Version too old, unreachable, or error
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      if [[ $# -lt 2 ]]; then
        echo "Error: --url requires a URL argument." >&2
        exit 1
      fi
      URL="$2"
      shift 2
      ;;
    --json)
      JSON_MODE=true
      shift
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    *)
      echo "Error: Unknown argument: $1" >&2
      echo "Run with --help for usage." >&2
      exit 1
      ;;
  esac
done

# ── Validate required arguments ──────────────────────
if [[ -z "$URL" ]]; then
  echo "Error: --url is required." >&2
  echo "Run with --help for usage." >&2
  exit 1
fi

# ── Input validation ─────────────────────────────────
validate_url "$URL"

# Strip trailing slash for consistent concatenation
URL="${URL%/}"

# ── Version comparison ───────────────────────────────
# Compare two semver-ish version strings (major.minor.patch).
# Returns 0 if $1 >= $2, 1 otherwise.
version_gte() {
  local ver="$1" min="$2"

  # Split on dots
  local ver_major ver_minor ver_patch
  IFS='.' read -r ver_major ver_minor ver_patch <<< "$ver"
  ver_major="${ver_major:-0}"
  ver_minor="${ver_minor:-0}"
  ver_patch="${ver_patch:-0}"

  local min_major min_minor min_patch
  IFS='.' read -r min_major min_minor min_patch <<< "$min"
  min_major="${min_major:-0}"
  min_minor="${min_minor:-0}"
  min_patch="${min_patch:-0}"

  # Strip any non-numeric suffix (e.g., "1.2.3-beta" -> "1.2.3")
  ver_major="${ver_major%%[!0-9]*}"
  ver_minor="${ver_minor%%[!0-9]*}"
  ver_patch="${ver_patch%%[!0-9]*}"
  min_major="${min_major%%[!0-9]*}"
  min_minor="${min_minor%%[!0-9]*}"
  min_patch="${min_patch%%[!0-9]*}"

  # Default empty to 0
  ver_major="${ver_major:-0}"
  ver_minor="${ver_minor:-0}"
  ver_patch="${ver_patch:-0}"
  min_major="${min_major:-0}"
  min_minor="${min_minor:-0}"
  min_patch="${min_patch:-0}"

  if (( ver_major > min_major )); then return 0; fi
  if (( ver_major < min_major )); then return 1; fi
  if (( ver_minor > min_minor )); then return 0; fi
  if (( ver_minor < min_minor )); then return 1; fi
  if (( ver_patch >= min_patch )); then return 0; fi
  return 1
}

# ── Step 1: Query ComfyUI /system_stats ──────────────
SYSTEM_INFO=$(curl -s --connect-timeout 5 --max-time 15 "${URL}/system_stats" 2>&1) || {
  if $JSON_MODE; then
    jq -n \
      --arg url "$URL" \
      --arg min "$MIN_VERSION" \
      '{"status":"FAIL","comfyui_version":"unknown","commit":"unknown","min_required":$min,"message":"Could not reach ComfyUI at \($url)/system_stats"}'
  else
    echo "Error: Could not reach ComfyUI at ${URL}/system_stats" >&2
    echo "Make sure ComfyUI is running and the API is accessible." >&2
  fi
  exit 1
}

# Verify the response is valid JSON
if ! echo "$SYSTEM_INFO" | jq empty 2>/dev/null; then
  if $JSON_MODE; then
    jq -n \
      --arg url "$URL" \
      --arg min "$MIN_VERSION" \
      '{"status":"FAIL","comfyui_version":"unknown","commit":"unknown","min_required":$min,"message":"ComfyUI returned invalid JSON from /system_stats"}'
  else
    echo "Error: ComfyUI returned invalid JSON from /system_stats" >&2
    echo "The endpoint may not be a ComfyUI instance." >&2
  fi
  exit 1
fi

# ── Step 2: Extract version info ─────────────────────
COMFY_VERSION=$(echo "$SYSTEM_INFO" | jq -r '.system.comfyui_version // "unknown"')
COMMIT_HASH=$(echo "$SYSTEM_INFO" | jq -r '.system.commit_hash // .system.git_hash // "unknown"')

# Truncate commit hash to short form if it is long
if [[ "${#COMMIT_HASH}" -gt 7 && "$COMMIT_HASH" != "unknown" ]]; then
  COMMIT_HASH="${COMMIT_HASH:0:7}"
fi

# ── Step 3: Compare versions ────────────────────────
if [[ "$COMFY_VERSION" == "unknown" ]]; then
  STATUS="FAIL"
  MESSAGE="Could not determine ComfyUI version from /system_stats"
elif version_gte "$COMFY_VERSION" "$MIN_VERSION"; then
  STATUS="PASS"
  MESSAGE="ComfyUI ${COMFY_VERSION} meets minimum requirement (${MIN_VERSION})"
else
  STATUS="FAIL"
  MESSAGE="ComfyUI ${COMFY_VERSION} is below minimum required version ${MIN_VERSION}. Please update ComfyUI."
fi

# ── Step 4: Report results ───────────────────────────
if $JSON_MODE; then
  jq -n \
    --arg status "$STATUS" \
    --arg version "$COMFY_VERSION" \
    --arg commit "$COMMIT_HASH" \
    --arg min "$MIN_VERSION" \
    --arg message "$MESSAGE" \
    '{
      status: $status,
      comfyui_version: $version,
      commit: $commit,
      min_required: $min,
      message: $message
    }'
else
  echo "ComfyUI Version Check"
  echo "  Version: ${COMFY_VERSION}"
  echo "  Commit: ${COMMIT_HASH}"
  echo "  Minimum required: ${MIN_VERSION}"
  echo "  Status: ${STATUS}"
  if [[ "$STATUS" == "FAIL" ]]; then
    echo ""
    echo "  ${MESSAGE}"
  fi
fi

# ── Exit code ────────────────────────────────────────
if [[ "$STATUS" == "PASS" ]]; then
  exit 0
else
  exit 1
fi
