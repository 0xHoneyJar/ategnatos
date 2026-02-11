#!/usr/bin/env bash
# detect-comfyui.sh — Check for running ComfyUI instance
# Exit codes: 0 = ComfyUI found, 1 = not found, 2 = unexpected error
# Usage: detect-comfyui.sh [--json] [--port PORT]

set -euo pipefail

JSON_MODE=false
CUSTOM_PORT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_MODE=true; shift ;;
        --port) CUSTOM_PORT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

check_port() {
    local port=$1
    local url="http://127.0.0.1:${port}/system_stats"

    # Use curl with short timeout to check if ComfyUI API responds
    local response
    if response=$(curl -s --connect-timeout 2 --max-time 5 "$url" 2>/dev/null); then
        # Verify it's actually ComfyUI by checking for expected JSON fields
        if echo "$response" | grep -q "comfyui_version\|vram_total\|system"; then
            echo "$port"
            return 0
        fi
    fi
    return 1
}

# Ports to check (common ComfyUI defaults)
if [[ -n "$CUSTOM_PORT" ]]; then
    PORTS=("$CUSTOM_PORT")
else
    PORTS=(8188 8189 8190 3000)
fi

FOUND_PORT=""
for port in "${PORTS[@]}"; do
    if FOUND_PORT=$(check_port "$port"); then
        break
    fi
done

if [[ -n "$FOUND_PORT" ]]; then
    local_url="http://127.0.0.1:${FOUND_PORT}"

    if $JSON_MODE; then
        cat <<ENDJSON
{
  "found": true,
  "endpoint": "${local_url}",
  "port": ${FOUND_PORT},
  "api_url": "${local_url}/api",
  "ws_url": "ws://127.0.0.1:${FOUND_PORT}/ws"
}
ENDJSON
    else
        echo "ComfyUI detected at ${local_url}"
        echo "API endpoint: ${local_url}/api"
        echo ""
        echo "The /art command can submit generation requests directly to this instance."
    fi
    exit 0
else
    if $JSON_MODE; then
        echo '{"found": false, "checked_ports": ['"$(IFS=,; echo "${PORTS[*]}")"']}'
    else
        echo "No running ComfyUI instance found."
        echo "Checked ports: ${PORTS[*]}"
        echo ""
        echo "This is fine — /art can still help you craft prompts to use manually."
        echo "To use automatic generation, start ComfyUI and run /studio again."
    fi
    exit 1
fi
