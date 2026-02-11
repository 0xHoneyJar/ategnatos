#!/usr/bin/env bash
# comfyui-poll.sh — Poll a ComfyUI prompt for completion and download results
# Usage: comfyui-poll.sh <prompt_id> [--host HOST] [--port PORT] [--output DIR] [--timeout SECS] [--json]
#
# Polls the /history endpoint until the prompt completes, then downloads
# all output images to the specified directory.

set -euo pipefail

# Defaults
HOST="127.0.0.1"
PORT="8188"
OUTPUT_DIR="."
TIMEOUT=600
POLL_INTERVAL=2
JSON_MODE=false
PROMPT_ID=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --output|-o) OUTPUT_DIR="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --json) JSON_MODE=true; shift ;;
    --help|-h)
      echo "Usage: comfyui-poll.sh <prompt_id> [OPTIONS]"
      echo ""
      echo "Poll ComfyUI for completion and download results."
      echo ""
      echo "Arguments:"
      echo "  prompt_id       The prompt ID from comfyui-submit.sh"
      echo "  --host HOST     ComfyUI host (default: 127.0.0.1)"
      echo "  --port PORT     ComfyUI port (default: 8188)"
      echo "  --output DIR    Download results to this directory (default: .)"
      echo "  --timeout SECS  Max wait time in seconds (default: 600)"
      echo "  --json          Output in JSON format"
      exit 0
      ;;
    *)
      if [[ -z "$PROMPT_ID" ]]; then
        PROMPT_ID="$1"
      else
        echo "Error: Unexpected argument: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$PROMPT_ID" ]]; then
  echo "Error: No prompt_id specified." >&2
  echo "Usage: comfyui-poll.sh <prompt_id> [--host HOST] [--port PORT]" >&2
  exit 1
fi

BASE_URL="http://${HOST}:${PORT}"
ELAPSED=0

# Poll loop
while [[ $ELAPSED -lt $TIMEOUT ]]; do
  HISTORY=$(curl -s "${BASE_URL}/history/${PROMPT_ID}" 2>/dev/null)

  # Check if prompt exists in history (it appears when complete)
  if echo "$HISTORY" | jq -e ".\"${PROMPT_ID}\"" >/dev/null 2>&1; then
    ENTRY=$(echo "$HISTORY" | jq ".\"${PROMPT_ID}\"")

    # Check status
    STATUS_CODE=$(echo "$ENTRY" | jq -r '.status.status_str // "unknown"')

    if [[ "$STATUS_CODE" == "error" ]]; then
      ERROR_MSG=$(echo "$ENTRY" | jq -r '.status.messages // empty')
      if $JSON_MODE; then
        jq -n --arg status "error" --arg prompt_id "$PROMPT_ID" --argjson details "$ENTRY" \
          '{status: $status, prompt_id: $prompt_id, details: $details}'
      else
        echo "Generation failed." >&2
        echo "Error: $ERROR_MSG" >&2
      fi
      exit 1
    fi

    if [[ "$STATUS_CODE" == "success" ]] || echo "$ENTRY" | jq -e '.outputs' >/dev/null 2>&1; then
      # Completed — download results
      mkdir -p "$OUTPUT_DIR"

      DOWNLOADED=()

      # Iterate over output nodes
      for NODE_ID in $(echo "$ENTRY" | jq -r '.outputs | keys[]'); do
        IMAGES=$(echo "$ENTRY" | jq -c ".outputs.\"${NODE_ID}\".images // []")

        for i in $(echo "$IMAGES" | jq -r 'to_entries[] | @base64'); do
          IMAGE=$(echo "$i" | base64 -d)
          FILENAME=$(echo "$IMAGE" | jq -r '.filename')
          SUBFOLDER=$(echo "$IMAGE" | jq -r '.subfolder // ""')
          TYPE=$(echo "$IMAGE" | jq -r '.type // "output"')

          # Build download URL
          DOWNLOAD_URL="${BASE_URL}/view?filename=${FILENAME}&type=${TYPE}"
          if [[ -n "$SUBFOLDER" ]]; then
            DOWNLOAD_URL="${DOWNLOAD_URL}&subfolder=${SUBFOLDER}"
          fi

          # Sanitize filename to prevent path traversal
          SAFE_FILENAME=$(basename "$FILENAME")
          OUTPUT_PATH="${OUTPUT_DIR}/${SAFE_FILENAME}"
          curl -s -o "$OUTPUT_PATH" "$DOWNLOAD_URL"
          DOWNLOADED+=("$OUTPUT_PATH")
        done
      done

      if $JSON_MODE; then
        FILES_JSON=$(printf '%s\n' "${DOWNLOADED[@]}" | jq -R . | jq -s .)
        jq -n \
          --arg status "complete" \
          --arg prompt_id "$PROMPT_ID" \
          --argjson files "$FILES_JSON" \
          --arg elapsed "${ELAPSED}s" \
          '{status: $status, prompt_id: $prompt_id, files: $files, elapsed: $elapsed}'
      else
        echo "Generation complete!"
        echo "Downloaded ${#DOWNLOADED[@]} file(s) to ${OUTPUT_DIR}:"
        for f in "${DOWNLOADED[@]}"; do
          echo "  $f"
        done
      fi
      exit 0
    fi
  fi

  # Still running — check queue position
  QUEUE=$(curl -s "${BASE_URL}/queue" 2>/dev/null)
  RUNNING=$(echo "$QUEUE" | jq '.queue_running | length' 2>/dev/null || echo "?")
  PENDING=$(echo "$QUEUE" | jq '.queue_pending | length' 2>/dev/null || echo "?")

  if ! $JSON_MODE; then
    printf "\rWaiting... (%ds elapsed, queue: %s running, %s pending)  " "$ELAPSED" "$RUNNING" "$PENDING"
  fi

  sleep "$POLL_INTERVAL"
  ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

# Timeout
if $JSON_MODE; then
  jq -n --arg status "timeout" --arg prompt_id "$PROMPT_ID" --arg timeout "${TIMEOUT}s" \
    '{status: $status, prompt_id: $prompt_id, timeout: $timeout}'
else
  echo ""
  echo "Timed out after ${TIMEOUT}s waiting for generation to complete." >&2
  echo "The generation may still be running — check ComfyUI directly." >&2
fi
exit 1
