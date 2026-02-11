#!/usr/bin/env bash
# comfyui-submit.sh — Submit a workflow JSON to ComfyUI API
# Usage: comfyui-submit.sh <workflow.json> [--host HOST] [--port PORT] [--json]
#
# Returns the prompt_id on success, which you pass to comfyui-poll.sh
# to track progress and download results.

set -euo pipefail

# Defaults
HOST="127.0.0.1"
PORT="8188"
JSON_MODE=false
WORKFLOW_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --json) JSON_MODE=true; shift ;;
    --help|-h)
      echo "Usage: comfyui-submit.sh <workflow.json> [--host HOST] [--port PORT] [--json]"
      echo ""
      echo "Submit a ComfyUI workflow JSON for generation."
      echo ""
      echo "Arguments:"
      echo "  workflow.json   Path to the workflow JSON file"
      echo "  --host HOST     ComfyUI host (default: 127.0.0.1)"
      echo "  --port PORT     ComfyUI port (default: 8188)"
      echo "  --json          Output in JSON format"
      exit 0
      ;;
    *)
      if [[ -z "$WORKFLOW_FILE" ]]; then
        WORKFLOW_FILE="$1"
      else
        echo "Error: Unexpected argument: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

# Validate input
if [[ -z "$WORKFLOW_FILE" ]]; then
  echo "Error: No workflow file specified." >&2
  echo "Usage: comfyui-submit.sh <workflow.json> [--host HOST] [--port PORT]" >&2
  exit 1
fi

if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "Error: Workflow file not found: $WORKFLOW_FILE" >&2
  exit 1
fi

BASE_URL="http://${HOST}:${PORT}"

# Check if ComfyUI is reachable
if ! curl -s --connect-timeout 3 "${BASE_URL}/system_stats" >/dev/null 2>&1; then
  if $JSON_MODE; then
    echo '{"status":"error","message":"ComfyUI is not reachable","host":"'"${HOST}"'","port":"'"${PORT}"'"}'
  else
    echo "Error: ComfyUI is not reachable at ${BASE_URL}" >&2
    echo "Make sure ComfyUI is running and the API is enabled." >&2
  fi
  exit 1
fi

# Read and validate workflow JSON
if ! jq empty "$WORKFLOW_FILE" 2>/dev/null; then
  echo "Error: Invalid JSON in workflow file: $WORKFLOW_FILE" >&2
  exit 1
fi

# Wrap workflow in the prompt API format
# ComfyUI /prompt expects: { "prompt": { ...nodes... } }
WORKFLOW_CONTENT=$(cat "$WORKFLOW_FILE")

# Check if the JSON already has a "prompt" key (API format) or is raw nodes
if echo "$WORKFLOW_CONTENT" | jq -e '.prompt' >/dev/null 2>&1; then
  # Already in API format
  PAYLOAD="$WORKFLOW_CONTENT"
else
  # Raw node graph — wrap it
  PAYLOAD=$(jq -n --argjson prompt "$WORKFLOW_CONTENT" '{"prompt": $prompt}')
fi

# Submit to ComfyUI /prompt endpoint
RESPONSE=$(curl -s -X POST "${BASE_URL}/prompt" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" 2>&1)

# Check for errors
if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
  ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error.message // .error // "Unknown error"')
  if $JSON_MODE; then
    echo "$RESPONSE" | jq '{status: "error", message: .error.message, details: .error}'
  else
    echo "Error from ComfyUI: $ERROR_MSG" >&2
  fi
  exit 1
fi

# Extract prompt_id
PROMPT_ID=$(echo "$RESPONSE" | jq -r '.prompt_id // empty')

if [[ -z "$PROMPT_ID" ]]; then
  if $JSON_MODE; then
    echo '{"status":"error","message":"No prompt_id in response","raw_response":'"$RESPONSE"'}'
  else
    echo "Error: ComfyUI did not return a prompt_id." >&2
    echo "Raw response: $RESPONSE" >&2
  fi
  exit 1
fi

# Success
if $JSON_MODE; then
  jq -n \
    --arg status "submitted" \
    --arg prompt_id "$PROMPT_ID" \
    --arg host "$HOST" \
    --arg port "$PORT" \
    --arg workflow "$WORKFLOW_FILE" \
    '{status: $status, prompt_id: $prompt_id, host: $host, port: $port, workflow: $workflow}'
else
  echo "Submitted successfully."
  echo "Prompt ID: $PROMPT_ID"
  echo ""
  echo "Track progress with:"
  echo "  comfyui-poll.sh $PROMPT_ID --host $HOST --port $PORT"
fi
