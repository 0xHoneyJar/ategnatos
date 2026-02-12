#!/usr/bin/env bash
# comfyui-preflight.sh — Pre-flight check: validate all workflow nodes are installed in ComfyUI
# Usage: comfyui-preflight.sh --workflow <path.json> --url <endpoint> [--json]
#
# Queries the ComfyUI /object_info endpoint to discover installed node types,
# then compares against every class_type referenced in the workflow JSON.
# Reports missing nodes with install instructions when available.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=../lib/validate-lib.sh
source "$SCRIPT_DIR/../lib/validate-lib.sh"

# ── Defaults ──────────────────────────────────────────
WORKFLOW_FILE=""
URL=""
JSON_MODE=false

# ── Node registry path (optional) ────────────────────
NODE_REGISTRY="$SCRIPT_DIR/../../skills/studio/resources/comfyui/node-registry.md"

# ── Argument parsing ─────────────────────────────────
show_help() {
  cat <<'USAGE'
Usage: comfyui-preflight.sh --workflow <path.json> --url <endpoint> [--json]

Pre-flight check that validates all workflow nodes are installed in ComfyUI.

Arguments:
  --workflow PATH    Path to the ComfyUI workflow JSON file
  --url URL          ComfyUI endpoint (e.g. http://127.0.0.1:8188)
  --json             Output results in JSON format
  --help, -h         Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workflow)
      if [[ $# -lt 2 ]]; then
        echo "Error: --workflow requires a path argument." >&2
        exit 1
      fi
      WORKFLOW_FILE="$2"
      shift 2
      ;;
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
if [[ -z "$WORKFLOW_FILE" ]]; then
  echo "Error: --workflow is required." >&2
  echo "Run with --help for usage." >&2
  exit 1
fi

if [[ -z "$URL" ]]; then
  echo "Error: --url is required." >&2
  echo "Run with --help for usage." >&2
  exit 1
fi

# ── Input validation ─────────────────────────────────
# Validate workflow file path (project-root containment check)
validate_path "$WORKFLOW_FILE"

# Validate workflow file is readable, valid JSON, and safe
validate_json_file "$WORKFLOW_FILE"

# Validate URL scheme and format
validate_url "$URL"

# Strip trailing slash from URL for consistent concatenation
URL="${URL%/}"

# ── Step 1: Query ComfyUI /object_info ───────────────
OBJECT_INFO=$(curl -s --connect-timeout 5 --max-time 30 "${URL}/object_info" 2>&1) || {
  if $JSON_MODE; then
    jq -n \
      --arg url "$URL" \
      '{"status":"ERROR","message":"Could not reach ComfyUI","url":$url}'
  else
    echo "Error: Could not reach ComfyUI at ${URL}/object_info" >&2
    echo "Make sure ComfyUI is running and the API is accessible." >&2
  fi
  exit 1
}

# Verify the response is valid JSON (guards against HTML error pages, etc.)
if ! echo "$OBJECT_INFO" | jq empty 2>/dev/null; then
  if $JSON_MODE; then
    jq -n \
      --arg url "$URL" \
      '{"status":"ERROR","message":"ComfyUI returned invalid JSON from /object_info","url":$url}'
  else
    echo "Error: ComfyUI returned invalid JSON from /object_info" >&2
    echo "The endpoint may not be a ComfyUI instance." >&2
  fi
  exit 1
fi

# Extract installed node class names into a sorted temp file
INSTALLED_FILE=$(mktemp)
trap 'rm -f "$INSTALLED_FILE"' EXIT

echo "$OBJECT_INFO" | jq -r 'keys[]' | sort -u > "$INSTALLED_FILE"

INSTALLED_COUNT=$(wc -l < "$INSTALLED_FILE" | tr -d ' ')

if [[ "$INSTALLED_COUNT" -eq 0 ]]; then
  if $JSON_MODE; then
    jq -n '{"status":"ERROR","message":"ComfyUI /object_info returned no node types"}'
  else
    echo "Error: ComfyUI /object_info returned no node types." >&2
    echo "The instance may still be loading." >&2
  fi
  exit 1
fi

# ── Step 2: Parse workflow JSON for class_type values ─
WORKFLOW_NODES=$(jq -r '.. | .class_type? // empty' "$WORKFLOW_FILE" | sort -u)

if [[ -z "$WORKFLOW_NODES" ]]; then
  if $JSON_MODE; then
    jq -n \
      --arg wf "$WORKFLOW_FILE" \
      '{"status":"ERROR","message":"No class_type entries found in workflow","workflow":$wf}'
  else
    echo "Error: No class_type entries found in workflow: $WORKFLOW_FILE" >&2
    echo "This may not be a valid ComfyUI workflow JSON." >&2
  fi
  exit 1
fi

TOTAL_NODES=$(echo "$WORKFLOW_NODES" | wc -l | tr -d ' ')

# ── Step 3: Compare — find missing nodes ─────────────
MISSING_NODES=()
while IFS= read -r node; do
  if ! grep -qxF "$node" "$INSTALLED_FILE"; then
    MISSING_NODES+=("$node")
  fi
done <<< "$WORKFLOW_NODES"

MISSING_COUNT=${#MISSING_NODES[@]}
INSTALLED_MATCH=$((TOTAL_NODES - MISSING_COUNT))

# ── Step 4: Look up install instructions ─────────────
# Build JSON array of missing nodes with install info
MISSING_JSON_ARRAY="[]"
MISSING_WITH_INSTALL="[]"

if [[ "$MISSING_COUNT" -gt 0 ]]; then
  # Build plain missing array
  MISSING_JSON_ARRAY=$(printf '%s\n' "${MISSING_NODES[@]}" | jq -R . | jq -s .)

  # Try to look up install instructions from node-registry.md
  if [[ -f "$NODE_REGISTRY" ]]; then
    MISSING_WITH_INSTALL="[]"
    for node in "${MISSING_NODES[@]}"; do
      # Parse the markdown table: expected format is
      # | NodeClassName | PackageName | install command |
      # Use grep to find the row, then extract fields
      REGISTRY_LINE=$(grep -i "| *${node} *|" "$NODE_REGISTRY" 2>/dev/null || true)

      if [[ -n "$REGISTRY_LINE" ]]; then
        # Extract package name (column 2) and install command (column 3)
        PACKAGE=$(echo "$REGISTRY_LINE" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')
        INSTALL_CMD=$(echo "$REGISTRY_LINE" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $4); print $4}')

        MISSING_WITH_INSTALL=$(echo "$MISSING_WITH_INSTALL" | jq \
          --arg node "$node" \
          --arg package "$PACKAGE" \
          --arg install "$INSTALL_CMD" \
          '. + [{"node": $node, "package": $package, "install": $install}]')
      else
        MISSING_WITH_INSTALL=$(echo "$MISSING_WITH_INSTALL" | jq \
          --arg node "$node" \
          '. + [{"node": $node, "package": "unknown", "install": ""}]')
      fi
    done
  else
    # No registry file — report all as unknown
    for node in "${MISSING_NODES[@]}"; do
      MISSING_WITH_INSTALL=$(echo "$MISSING_WITH_INSTALL" | jq \
        --arg node "$node" \
        '. + [{"node": $node, "package": "unknown", "install": ""}]')
    done
  fi
fi

# ── Step 5: Report results ───────────────────────────
if [[ "$MISSING_COUNT" -eq 0 ]]; then
  # All nodes present
  if $JSON_MODE; then
    jq -n \
      --arg status "PASS" \
      --argjson total "$TOTAL_NODES" \
      --argjson installed "$TOTAL_NODES" \
      '{
        status: $status,
        total_nodes: $total,
        installed: $installed,
        missing: [],
        missing_with_install: []
      }'
  else
    echo "All ${TOTAL_NODES} nodes available. Workflow is ready to run."
  fi
  exit 0
else
  # Missing nodes detected
  if $JSON_MODE; then
    jq -n \
      --arg status "FAIL" \
      --argjson total "$TOTAL_NODES" \
      --argjson installed "$INSTALLED_MATCH" \
      --argjson missing "$MISSING_JSON_ARRAY" \
      --argjson missing_with_install "$MISSING_WITH_INSTALL" \
      '{
        status: $status,
        total_nodes: $total,
        installed: $installed,
        missing: $missing,
        missing_with_install: $missing_with_install
      }'
  else
    echo "PREFLIGHT FAILED: ${MISSING_COUNT} of ${TOTAL_NODES} node types are missing."
    echo ""
    echo "Missing nodes:"
    for node in "${MISSING_NODES[@]}"; do
      # Try to find install info
      INSTALL_INFO=""
      if [[ -f "$NODE_REGISTRY" ]]; then
        REGISTRY_LINE=$(grep -i "| *${node} *|" "$NODE_REGISTRY" 2>/dev/null || true)
        if [[ -n "$REGISTRY_LINE" ]]; then
          PACKAGE=$(echo "$REGISTRY_LINE" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')
          INSTALL_CMD=$(echo "$REGISTRY_LINE" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $4); print $4}')
          if [[ -n "$PACKAGE" ]]; then
            INSTALL_INFO=" (package: ${PACKAGE})"
          fi
          if [[ -n "$INSTALL_CMD" ]]; then
            INSTALL_INFO="${INSTALL_INFO}  Install: ${INSTALL_CMD}"
          fi
        fi
      fi
      echo "  - ${node}${INSTALL_INFO}"
    done
    echo ""
    echo "Install the missing custom nodes and restart ComfyUI before running this workflow."
  fi
  exit 1
fi
