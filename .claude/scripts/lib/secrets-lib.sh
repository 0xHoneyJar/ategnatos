#!/usr/bin/env bash
# secrets-lib.sh — Secrets management for Ategnatos shell scripts
# Usage: source this file, then call load_secret, redact_log, safe_log
#
# Loads secrets from environment variables or a local secrets file.
# Provides log redaction to prevent accidental secret leakage.

set -euo pipefail

# Guard against double-sourcing
[[ -n "${_SECRETS_LIB_LOADED:-}" ]] && return 0
_SECRETS_LIB_LOADED=1

# ──────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────

ATEGNATOS_SECRETS_FILE="${ATEGNATOS_SECRETS_FILE:-$HOME/.config/ategnatos/secrets}"

# ──────────────────────────────────────────────
# load_secret <name>
# Load a secret by name. Resolution order:
#   1. Environment variable with that name
#   2. Entry in the secrets file (~/.config/ategnatos/secrets)
# Outputs the secret value to stdout on success.
# ──────────────────────────────────────────────
load_secret() {
  local name="${1:-}"

  if [[ -z "$name" ]]; then
    echo "Error: load_secret requires a secret name." >&2
    return 1
  fi

  # 1. Check environment variable
  if [[ -n "${!name:-}" ]]; then
    echo "${!name}"
    return 0
  fi

  # 2. Check secrets file
  if [[ -f "$ATEGNATOS_SECRETS_FILE" ]]; then
    # Verify file permissions are 0600 (owner read/write only)
    local perms
    perms=$(stat -f '%Lp' "$ATEGNATOS_SECRETS_FILE" 2>/dev/null \
         || stat -c '%a' "$ATEGNATOS_SECRETS_FILE" 2>/dev/null)

    if [[ "$perms" != "600" ]]; then
      echo "Error: Secrets file has insecure permissions ($perms). Expected 0600." >&2
      echo "Fix with: chmod 600 $ATEGNATOS_SECRETS_FILE" >&2
      return 1
    fi

    # Parse KEY=value lines, ignoring comments and blank lines
    local value
    value=$(grep -E "^${name}=" "$ATEGNATOS_SECRETS_FILE" 2>/dev/null | head -1 | sed "s/^${name}=//")

    if [[ -n "$value" ]]; then
      echo "$value"
      return 0
    fi
  fi

  # Not found anywhere
  echo "Error: Secret '$name' not found. Set it as an env var or add to $ATEGNATOS_SECRETS_FILE" >&2
  return 1
}

# ──────────────────────────────────────────────
# redact_log <text>
# Masks sensitive patterns in text to prevent
# accidental secret leakage in logs.
#
# Patterns redacted:
#   - OpenAI/Anthropic style keys: sk-... -> sk-***<last4>
#   - SSH public keys: ssh-xxx AAAA... -> ssh-***REDACTED
#   - Long alphanumeric strings (32+ chars) following
#     key/token/secret/password context -> masked middle
#
# Outputs redacted text to stdout.
# ──────────────────────────────────────────────
redact_log() {
  local text="${1:-}"

  if [[ -z "$text" ]]; then
    echo ""
    return 0
  fi

  echo "$text" | sed -E \
    -e 's/(sk-[A-Za-z0-9]{10,})([A-Za-z0-9]{4})/sk-***\2/g' \
    -e 's/ssh-[a-z]{3,} AAAA[A-Za-z0-9+/=]+/ssh-***REDACTED/g' \
    -e 's/([Kk]ey|[Tt]oken|[Ss]ecret|[Pp]assword)[=:_ ]*([A-Za-z0-9]{4})[A-Za-z0-9]{24,}([A-Za-z0-9]{4})/\1=\2***\3/g'
}

# ──────────────────────────────────────────────
# safe_log <text>
# Convenience wrapper: redacts sensitive content
# and writes the result to stderr.
# ──────────────────────────────────────────────
safe_log() {
  redact_log "$1" >&2
}
