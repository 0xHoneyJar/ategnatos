#!/usr/bin/env bash
# resource-lock.sh — Advisory lock library for preventing resource contention
#
# Provides file-based advisory locks so that concurrent Ategnatos processes
# (art generation, training runs, GPU management) do not collide on the
# same resource.
#
# Lock files live in /tmp/ategnatos-lock-<hash>.lock where <hash> is the
# first 8 characters of the SHA-256 of the resource name.
#
# Resource naming convention:
#   comfyui:<host>:<port>      — a ComfyUI server instance
#   gpu:<provider>:<instance_id> — a cloud GPU instance
#   training:<run_id>          — a training run
#
# Usage: source this file, then call lock_acquire / lock_release / lock_check /
#        lock_force_release.
#
# Requires: jq, shasum

set -euo pipefail

# Guard against double-sourcing
[[ -n "${_RESOURCE_LOCK_LOADED:-}" ]] && return 0
_RESOURCE_LOCK_LOADED=1

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/validate-lib.sh"

# ──────────────────────────────────────────────
# _lock_path <resource>
# Compute the lock file path for a given resource.
# /tmp/ategnatos-lock-<first 8 hex chars of sha256>.lock
# ──────────────────────────────────────────────
_lock_path() {
  local resource="${1:?_lock_path: resource argument required}"
  local hash
  hash="$(printf '%s' "$resource" | shasum -a 256 | cut -c1-8)"
  printf '%s' "/tmp/ategnatos-lock-${hash}.lock"
}

# ──────────────────────────────────────────────
# _lock_pid_alive <pid>
# Return 0 if the given PID is running, 1 otherwise.
# ──────────────────────────────────────────────
_lock_pid_alive() {
  local pid="${1:?_lock_pid_alive: pid argument required}"
  kill -0 "$pid" 2>/dev/null
}

# ──────────────────────────────────────────────
# _lock_write <lockfile> <resource> <holder> <pid>
# Write lock content as JSON to the given path.
# ──────────────────────────────────────────────
_lock_write() {
  local lockfile="${1:?}"
  local resource="${2:?}"
  local holder="${3:?}"
  local pid="${4:?}"
  local now
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  jq -n \
    --arg resource "$resource" \
    --arg holder "$holder" \
    --argjson pid "$pid" \
    --arg acquired_at "$now" \
    '{"resource":$resource,"holder":$holder,"pid":$pid,"acquired_at":$acquired_at}' \
    > "$lockfile"
}

# ──────────────────────────────────────────────
# lock_acquire <resource> [--timeout N] [--holder NAME]
#
# Acquire an advisory lock for the given resource.
#   --timeout N   Retry every 1 second up to N seconds (default: 30)
#   --holder NAME Label for the lock holder (default: "unknown")
#
# Exit 0 on success, 1 on failure.
# ──────────────────────────────────────────────
lock_acquire() {
  if [[ $# -lt 1 ]]; then
    echo "Error: lock_acquire requires a resource argument." >&2
    return 1
  fi

  local resource="${1}"
  shift

  local timeout=30
  local holder="unknown"

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --timeout)
        timeout="${2:?Error: --timeout requires a value}"
        shift 2
        ;;
      --holder)
        holder="${2:?Error: --holder requires a value}"
        shift 2
        ;;
      *)
        echo "Error: lock_acquire: unknown option '${1}'" >&2
        return 1
        ;;
    esac
  done

  local lockfile
  lockfile="$(_lock_path "$resource")"
  local my_pid="$$"
  local elapsed=0

  while true; do
    if [[ ! -f "$lockfile" ]]; then
      # No lock exists — acquire it
      _lock_write "$lockfile" "$resource" "$holder" "$my_pid"
      return 0
    fi

    # Lock file exists — inspect it
    local existing_pid
    existing_pid="$(jq -r '.pid' "$lockfile" 2>/dev/null)" || existing_pid=""

    if [[ -z "$existing_pid" ]]; then
      # Corrupt lockfile — remove and acquire
      echo "Warning: Corrupt lockfile at ${lockfile}, removing." >&2
      rm -f "$lockfile"
      _lock_write "$lockfile" "$resource" "$holder" "$my_pid"
      return 0
    fi

    if ! _lock_pid_alive "$existing_pid"; then
      # Stale lock — PID no longer running
      local stale_holder
      stale_holder="$(jq -r '.holder' "$lockfile" 2>/dev/null)" || stale_holder="unknown"
      echo "Warning: Stale lock for '${resource}' held by '${stale_holder}' (PID ${existing_pid}) — auto-releasing." >&2
      rm -f "$lockfile"
      _lock_write "$lockfile" "$resource" "$holder" "$my_pid"
      return 0
    fi

    # Lock is held by a live process
    if [[ "$elapsed" -ge "$timeout" ]]; then
      local live_holder
      live_holder="$(jq -r '.holder' "$lockfile" 2>/dev/null)" || live_holder="unknown"
      echo "Error: Could not acquire lock for '${resource}' within ${timeout}s. Held by '${live_holder}' (PID ${existing_pid})." >&2
      return 1
    fi

    sleep 1
    elapsed=$((elapsed + 1))
  done
}

# ──────────────────────────────────────────────
# lock_release <resource>
#
# Release the advisory lock for the given resource.
# Only the process that acquired the lock (matching PID)
# may release it.
#
# Exit 0 on success, 1 on ownership mismatch.
# If no lock exists, warns and exits 0.
# ──────────────────────────────────────────────
lock_release() {
  if [[ $# -lt 1 ]]; then
    echo "Error: lock_release requires a resource argument." >&2
    return 1
  fi

  local resource="${1}"
  local lockfile
  lockfile="$(_lock_path "$resource")"

  if [[ ! -f "$lockfile" ]]; then
    echo "Warning: No lock found for '${resource}'." >&2
    return 0
  fi

  local lock_pid
  lock_pid="$(jq -r '.pid' "$lockfile" 2>/dev/null)" || lock_pid=""

  if [[ "$lock_pid" == "$$" ]]; then
    rm -f "$lockfile"
    return 0
  fi

  echo "Error: Lock held by PID ${lock_pid}, not current process ($$)." >&2
  return 1
}

# ──────────────────────────────────────────────
# lock_check <resource>
#
# Check the state of a lock for a resource.
#
# If lockfile exists and PID alive: output JSON content, exit 0
# If lockfile exists and PID dead: auto-release, output
#   {"status":"stale_released"}, exit 1
# If no lockfile: output {"status":"unlocked"}, exit 1
# ──────────────────────────────────────────────
lock_check() {
  if [[ $# -lt 1 ]]; then
    echo "Error: lock_check requires a resource argument." >&2
    return 1
  fi

  local resource="${1}"
  local lockfile
  lockfile="$(_lock_path "$resource")"

  if [[ ! -f "$lockfile" ]]; then
    echo '{"status":"unlocked"}'
    return 1
  fi

  local lock_pid
  lock_pid="$(jq -r '.pid' "$lockfile" 2>/dev/null)" || lock_pid=""

  if [[ -n "$lock_pid" ]] && _lock_pid_alive "$lock_pid"; then
    jq '.' "$lockfile"
    return 0
  fi

  # Stale lock — auto-release
  local stale_holder
  stale_holder="$(jq -r '.holder' "$lockfile" 2>/dev/null)" || stale_holder="unknown"
  echo "Warning: Stale lock for '${resource}' held by '${stale_holder}' (PID ${lock_pid:-unknown}) — auto-releasing." >&2
  rm -f "$lockfile"
  echo '{"status":"stale_released"}'
  return 1
}

# ──────────────────────────────────────────────
# lock_force_release <resource>
#
# Forcibly remove the lockfile regardless of ownership.
# Use with caution — this bypasses ownership checks.
#
# Exit 0 always.
# ──────────────────────────────────────────────
lock_force_release() {
  if [[ $# -lt 1 ]]; then
    echo "Error: lock_force_release requires a resource argument." >&2
    return 1
  fi

  local resource="${1}"
  local lockfile
  lockfile="$(_lock_path "$resource")"

  echo "Warning: Force-releasing lock for '${resource}' (${lockfile})." >&2
  rm -f "$lockfile"
  return 0
}
