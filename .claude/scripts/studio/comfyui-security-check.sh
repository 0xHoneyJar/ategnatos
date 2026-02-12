#!/usr/bin/env bash
# comfyui-security-check.sh — ComfyUI endpoint security validation
# Checks whether a ComfyUI endpoint is local, private network, or public,
# and warns about exposed endpoints without SSH tunnels.
#
# Exit codes:
#   0 = PASS (local endpoint, or allowed remote with SSH tunnel)
#   1 = FAIL (public endpoint without --allow-remote)
#   2 = WARN (private network, or remote without detected tunnel)

set -euo pipefail

# Source shared validation library
# shellcheck disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/../lib/validate-lib.sh"

# Defaults
URL=""
ALLOW_REMOTE=false
JSON_MODE=false

usage() {
  cat <<'USAGE'
Usage: comfyui-security-check.sh --url <endpoint> [--allow-remote] [--json]

Validate the security posture of a ComfyUI endpoint URL.

Options:
  --url <endpoint>   The ComfyUI endpoint URL to check (required)
  --allow-remote     Allow public endpoints (will check for SSH tunnel)
  --json             Output results in JSON format
  --help, -h         Show this help message

Exit codes:
  0  PASS   Local endpoint, or allowed remote with SSH tunnel detected
  1  FAIL   Public endpoint without --allow-remote
  2  WARN   Private network endpoint, or remote without detected tunnel

Examples:
  comfyui-security-check.sh --url http://127.0.0.1:8188
  comfyui-security-check.sh --url http://203.0.113.10:8188 --allow-remote
  comfyui-security-check.sh --url http://192.168.1.50:8188 --json
USAGE
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      if [[ $# -lt 2 ]]; then
        echo "Error: --url requires a value." >&2
        exit 1
      fi
      URL="$2"
      shift 2
      ;;
    --allow-remote)
      ALLOW_REMOTE=true
      shift
      ;;
    --json)
      JSON_MODE=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Error: Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# Require --url
if [[ -z "$URL" ]]; then
  echo "Error: --url is required." >&2
  usage >&2
  exit 1
fi

# Validate URL format using validate-lib
if ! validate_url "$URL"; then
  exit 1
fi

# ──────────────────────────────────────────────
# Extract host from URL
# Strips scheme, then path, then port.
# Handles IPv6 bracket notation like [::1]:8080.
# ──────────────────────────────────────────────
extract_host_and_port() {
  local url="$1"
  local authority

  # Strip scheme (http:// or https://)
  authority="${url#*://}"
  # Strip path and everything after
  authority="${authority%%/*}"

  # Extract host and port depending on format
  if [[ "$authority" == "["* ]]; then
    # IPv6 bracket notation: [::1]:8080 or [::1]
    HOST_PART="${authority%%]*}"
    HOST_PART="${HOST_PART#[}"
    local remainder="${authority#*]}"
    if [[ "$remainder" == ":"* ]]; then
      PORT_PART="${remainder#:}"
    else
      PORT_PART=""
    fi
  elif [[ "$authority" == *":"*":"* ]]; then
    # Bare IPv6 without brackets (no port extraction possible)
    HOST_PART="$authority"
    PORT_PART=""
  else
    # IPv4 or hostname, possibly with :port
    if [[ "$authority" == *":"* ]]; then
      HOST_PART="${authority%:*}"
      PORT_PART="${authority##*:}"
    else
      HOST_PART="$authority"
      PORT_PART=""
    fi
  fi
}

HOST_PART=""
PORT_PART=""
extract_host_and_port "$URL"

# ──────────────────────────────────────────────
# Classify host
# ──────────────────────────────────────────────
CLASSIFICATION=""
case "$HOST_PART" in
  127.0.0.1|localhost|::1)
    CLASSIFICATION="local"
    ;;
  10.*)
    CLASSIFICATION="private"
    ;;
  192.168.*)
    CLASSIFICATION="private"
    ;;
  172.*)
    # Check 172.16.0.0 - 172.31.255.255
    local_second_octet="${HOST_PART#172.}"
    local_second_octet="${local_second_octet%%.*}"
    if [[ "$local_second_octet" =~ ^[0-9]+$ ]] \
       && [[ "$local_second_octet" -ge 16 ]] \
       && [[ "$local_second_octet" -le 31 ]]; then
      CLASSIFICATION="private"
    else
      CLASSIFICATION="public"
    fi
    ;;
  *)
    CLASSIFICATION="public"
    ;;
esac

# ──────────────────────────────────────────────
# Determine result based on classification
# ──────────────────────────────────────────────
STATUS=""
MESSAGE=""
TUNNEL_DETECTED=false
EXIT_CODE=0

case "$CLASSIFICATION" in
  local)
    STATUS="PASS"
    MESSAGE="Endpoint is local ($HOST_PART). Safe to use."
    EXIT_CODE=0
    ;;
  private)
    STATUS="WARN"
    MESSAGE="Endpoint is on a private network ($HOST_PART). Ensure the network is trusted."
    EXIT_CODE=2
    ;;
  public)
    if $ALLOW_REMOTE; then
      # Check for SSH tunnel forwarding to this port
      if [[ -n "$PORT_PART" ]]; then
        # Look for an SSH process that references this port
        if pgrep -fa "ssh" | grep -q "$PORT_PART"; then
          TUNNEL_DETECTED=true
          STATUS="PASS"
          MESSAGE="Public endpoint ($HOST_PART) with SSH tunnel detected on port $PORT_PART."
          EXIT_CODE=0
        else
          STATUS="WARN"
          MESSAGE="Public endpoint ($HOST_PART) allowed via --allow-remote, but no SSH tunnel detected on port $PORT_PART. Traffic may be unencrypted."
          EXIT_CODE=2
        fi
      else
        STATUS="WARN"
        MESSAGE="Public endpoint ($HOST_PART) allowed via --allow-remote, but no port specified to check for SSH tunnel. Traffic may be unencrypted."
        EXIT_CODE=2
      fi
    else
      STATUS="FAIL"
      MESSAGE="Public endpoint ($HOST_PART) is not allowed without --allow-remote. ComfyUI should not be exposed to the public internet."
      EXIT_CODE=1
    fi
    ;;
esac

# ──────────────────────────────────────────────
# Output
# ──────────────────────────────────────────────
if $JSON_MODE; then
  # Build JSON without eval or backtick substitution
  printf '{"status":"%s","host":"%s","classification":"%s","tunnel_detected":%s,"message":"%s"}\n' \
    "$STATUS" \
    "$HOST_PART" \
    "$CLASSIFICATION" \
    "$TUNNEL_DETECTED" \
    "$MESSAGE"
else
  echo "[$STATUS] $MESSAGE"
fi

exit "$EXIT_CODE"
