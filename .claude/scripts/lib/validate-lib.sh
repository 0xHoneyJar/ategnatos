#!/usr/bin/env bash
# validate-lib.sh — Input validation library for shell scripts
# Usage: source this file, then call validate_* functions
#
# Every function returns 0 (valid) or 1 (invalid).
# On invalid input, a human-readable message is written to stderr.
# Requires: jq (only for validate_json_file)

set -euo pipefail

# Guard against double-sourcing
[[ -n "${_VALIDATE_LIB_LOADED:-}" ]] && return 0
_VALIDATE_LIB_LOADED=1

# ──────────────────────────────────────────────
# Hardcoded allowlists — not configurable
# ──────────────────────────────────────────────
readonly _VALID_PROVIDERS="vast runpod lambda local"
readonly _VALID_BACKENDS="kohya simpletuner ai-toolkit"

# ──────────────────────────────────────────────
# _detect_project_root
# Walk up from this script's directory looking for
# CLAUDE.md or .git to identify the project root.
# Falls back to the script's grandparent directory.
# ──────────────────────────────────────────────
_detect_project_root() {
  local dir
  # Start from the directory containing this script
  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/CLAUDE.md" ]] || [[ -d "$dir/.git" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done

  # Fallback: assume this script lives in .claude/scripts/lib/
  (cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
}

# Resolved once at source time
_PROJECT_ROOT="$(_detect_project_root)"

# ──────────────────────────────────────────────
# validate_path <path>
# Rejects:
#   - Empty input
#   - Paths containing null bytes
#   - Paths with ".." components (directory traversal)
#   - Paths that resolve outside the project root
# Uses realpath to resolve symlinks. For paths that
# don't exist yet, resolves the parent directory.
# ──────────────────────────────────────────────
validate_path() {
  local path="${1:-}"

  if [[ -z "$path" ]]; then
    echo "Error: Path must not be empty." >&2
    return 1
  fi

  # Note: bash cannot embed null bytes in strings, so checking
  # for them via pattern matching is not possible ($'\0' expands
  # to empty string). Null-byte injection is effectively blocked
  # by bash itself before the value reaches this function.

  # Reject ".." path components (traversal attack)
  # Match: leading ../, trailing /.., middle /../, or bare ..
  if [[ "$path" == ".." || "$path" == ../* || "$path" == *"/.. " || "$path" == *"/.."* ]]; then
    echo "Error: Path must not contain '..' components: $path" >&2
    return 1
  fi

  # Resolve to an absolute path. If the path exists, resolve it directly.
  # If it doesn't exist yet, resolve the parent directory and append the basename.
  local resolved
  if [[ -e "$path" ]]; then
    resolved="$(realpath "$path" 2>/dev/null)" || {
      echo "Error: Could not resolve path: $path" >&2
      return 1
    }
  else
    local parent basename_part
    parent="$(dirname "$path")"
    basename_part="$(basename "$path")"

    if [[ ! -d "$parent" ]]; then
      echo "Error: Parent directory does not exist: $parent" >&2
      return 1
    fi

    resolved="$(realpath "$parent" 2>/dev/null)/$basename_part" || {
      echo "Error: Could not resolve parent of path: $path" >&2
      return 1
    }
  fi

  # After resolving symlinks, check again for traversal
  # (a symlink could have pointed outside the project)
  if [[ "$resolved" != "$_PROJECT_ROOT"* ]]; then
    echo "Error: Path resolves outside project root: $resolved" >&2
    return 1
  fi

  return 0
}

# ──────────────────────────────────────────────
# validate_url <url>
# Accepts only http:// and https:// URLs.
# Rejects URLs with embedded credentials (user:pass@host).
# Pure bash pattern matching — no external commands.
# ──────────────────────────────────────────────
validate_url() {
  local url="${1:-}"

  if [[ -z "$url" ]]; then
    echo "Error: URL must not be empty." >&2
    return 1
  fi

  # Must start with http:// or https://
  if [[ "$url" != http://* && "$url" != https://* ]]; then
    echo "Error: URL must use http:// or https:// scheme: $url" >&2
    return 1
  fi

  # Extract the authority portion (everything between :// and the next /)
  local authority
  authority="${url#*://}"       # strip scheme
  authority="${authority%%/*}"  # strip path and everything after

  # Reject embedded credentials (user:pass@host or user@host)
  if [[ "$authority" == *@* ]]; then
    echo "Error: URL must not contain credentials (user@host or user:pass@host): $url" >&2
    return 1
  fi

  # Must have at least a hostname after the scheme
  if [[ -z "$authority" ]]; then
    echo "Error: URL has no hostname: $url" >&2
    return 1
  fi

  return 0
}

# ──────────────────────────────────────────────
# validate_url_localhost <url>
# First validates as a URL, then checks that the
# host is 127.0.0.1, localhost, or ::1 (with or
# without a port number).
# ──────────────────────────────────────────────
validate_url_localhost() {
  local url="${1:-}"

  # First pass: must be a valid URL
  validate_url "$url" || return 1

  # Extract the authority and strip any port suffix
  local authority host
  authority="${url#*://}"
  authority="${authority%%/*}"

  # Handle IPv6 bracket notation like [::1]:8080
  if [[ "$authority" == "["* ]]; then
    host="${authority%%]*}"
    host="${host#[}"
  else
    # Strip port (last :digits)
    host="${authority%:*}"
    # If nothing was stripped, host == authority (no port present)
    if [[ "$host" == "$authority" ]]; then
      host="$authority"
    fi
  fi

  case "$host" in
    127.0.0.1|localhost|::1)
      return 0
      ;;
    *)
      echo "Error: URL host must be localhost, 127.0.0.1, or ::1. Got: $host" >&2
      return 1
      ;;
  esac
}

# ──────────────────────────────────────────────
# validate_provider_id <id>
# Checks against hardcoded provider allowlist:
# vast, runpod, lambda, local
# ──────────────────────────────────────────────
validate_provider_id() {
  local id="${1:-}"

  if [[ -z "$id" ]]; then
    echo "Error: Provider ID must not be empty." >&2
    return 1
  fi

  local provider
  for provider in $_VALID_PROVIDERS; do
    if [[ "$id" == "$provider" ]]; then
      return 0
    fi
  done

  echo "Error: Unknown provider '$id'. Valid providers: $_VALID_PROVIDERS" >&2
  return 1
}

# ──────────────────────────────────────────────
# validate_backend_id <id>
# Checks against hardcoded backend allowlist:
# kohya, simpletuner, ai-toolkit
# ──────────────────────────────────────────────
validate_backend_id() {
  local id="${1:-}"

  if [[ -z "$id" ]]; then
    echo "Error: Backend ID must not be empty." >&2
    return 1
  fi

  local backend
  for backend in $_VALID_BACKENDS; do
    if [[ "$id" == "$backend" ]]; then
      return 0
    fi
  done

  echo "Error: Unknown backend '$id'. Valid backends: $_VALID_BACKENDS" >&2
  return 1
}

# ──────────────────────────────────────────────
# validate_positive_int <value>
# Accepts only positive integers (1, 2, 3, ...).
# Rejects: empty, non-numeric, negative, zero,
# decimal values, leading/trailing whitespace.
# ──────────────────────────────────────────────
validate_positive_int() {
  local value="${1:-}"

  if [[ -z "$value" ]]; then
    echo "Error: Value must not be empty." >&2
    return 1
  fi

  # Must consist entirely of digits (no signs, no decimals, no spaces)
  if [[ ! "$value" =~ ^[0-9]+$ ]]; then
    echo "Error: Value must be a positive integer (digits only). Got: $value" >&2
    return 1
  fi

  # Reject zero (including leading-zero representations like "00")
  if [[ "$value" =~ ^0+$ ]]; then
    echo "Error: Value must be greater than zero. Got: $value" >&2
    return 1
  fi

  return 0
}

# ──────────────────────────────────────────────
# validate_json_file <path>
# Validates that:
#   1. The file exists and is readable
#   2. Contents are valid JSON (parsed by jq)
#   3. Contents do not contain eval-able / injection
#      patterns that could be dangerous if the JSON
#      is later interpolated into shell commands
# ──────────────────────────────────────────────

# Patterns that should never appear in trusted JSON values.
# These are checked against the raw file content as a safety net
# against command injection if values are later used in shell contexts.
# shellcheck disable=SC2016 # these are literal patterns to match against file content, not for expansion
_DANGEROUS_PATTERNS=(
  '$('        # command substitution
  '`'         # backtick command substitution
  '$(('       # arithmetic expansion
  'eval '     # explicit eval
  'exec '     # explicit exec
  '; '        # command chaining (semicolon + space)
  '| '        # pipe to another command
  '&& '       # logical AND chaining
  '|| '       # logical OR chaining
)
readonly _DANGEROUS_PATTERNS

validate_json_file() {
  local path="${1:-}"

  if [[ -z "$path" ]]; then
    echo "Error: JSON file path must not be empty." >&2
    return 1
  fi

  if [[ ! -f "$path" ]]; then
    echo "Error: File does not exist: $path" >&2
    return 1
  fi

  if [[ ! -r "$path" ]]; then
    echo "Error: File is not readable: $path" >&2
    return 1
  fi

  # Validate JSON syntax with jq
  if ! jq empty "$path" 2>/dev/null; then
    echo "Error: File is not valid JSON: $path" >&2
    return 1
  fi

  # Scan for dangerous content patterns
  local content
  content="$(<"$path")"

  local pattern
  for pattern in "${_DANGEROUS_PATTERNS[@]}"; do
    if [[ "$content" == *"$pattern"* ]]; then
      echo "Error: JSON file contains potentially dangerous content ('$pattern'): $path" >&2
      return 1
    fi
  done

  return 0
}
