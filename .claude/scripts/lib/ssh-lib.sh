#!/usr/bin/env bash
# ssh-lib.sh — SSH resilience library for Ategnatos
# Usage: source this file, then call ssh_exec, ssh_tmux_*, ssh_phase_*, ssh_reconnect_status
#
# Provides retry with exponential backoff, tmux session management,
# phase markers for idempotent multi-step workflows, and connectivity checks.

set -euo pipefail

# Guard against double-sourcing
[[ -n "${_SSH_LIB_LOADED:-}" ]] && return 0
_SSH_LIB_LOADED=1

# ──────────────────────────────────────────────
# Dependencies
# ──────────────────────────────────────────────

_SSH_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=validate-lib.sh
source "${_SSH_LIB_DIR}/validate-lib.sh"

# shellcheck source=secrets-lib.sh
source "${_SSH_LIB_DIR}/secrets-lib.sh"

# ──────────────────────────────────────────────
# _ssh_cmd <host> [ssh_args...] [--] <remote_command>
# Internal helper — all SSH invocations go through here.
# Adds standard options to every call.
# ──────────────────────────────────────────────
_ssh_cmd() {
  local host="$1"
  shift

  ssh \
    -o StrictHostKeyChecking=no \
    -o BatchMode=yes \
    "$host" \
    "$@"
}

# ──────────────────────────────────────────────
# ssh_exec <host> <command> [--retries N] [--backoff-base S]
# Execute a command on a remote host via SSH.
# On connection failure, retries with exponential backoff:
#   delay = backoff_base * 2^attempt  (5s, 10s, 20s, ...)
# Returns stdout on success, exits 1 when all retries exhausted.
# ──────────────────────────────────────────────
ssh_exec() {
  if [[ $# -lt 2 ]]; then
    safe_log "Error: ssh_exec requires at least <host> and <command>."
    return 1
  fi

  local host="$1"
  local command="$2"
  shift 2

  # Parse optional flags
  local retries=3
  local backoff_base=5

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --retries)
        retries="$2"
        shift 2
        ;;
      --backoff-base)
        backoff_base="$2"
        shift 2
        ;;
      *)
        safe_log "Warning: ssh_exec ignoring unknown flag: $1"
        shift
        ;;
    esac
  done

  local attempt=0
  local output

  while [[ "$attempt" -lt "$retries" ]]; do
    if output=$(ssh \
      -o StrictHostKeyChecking=no \
      -o BatchMode=yes \
      -o ConnectTimeout=10 \
      "$host" \
      "$command" 2>&1); then
      echo "$output"
      return 0
    fi

    attempt=$((attempt + 1))

    if [[ "$attempt" -lt "$retries" ]]; then
      local delay=$(( backoff_base * (1 << attempt) ))
      safe_log "SSH connection to host failed (attempt $attempt/$retries). Retrying in ${delay}s..."
      sleep "$delay"
    fi
  done

  safe_log "Error: SSH command failed after $retries attempts."
  return 1
}

# ──────────────────────────────────────────────
# ssh_tmux_create <host> <session_name>
# Create a tmux session on the remote host (idempotent).
# Returns 0 if the session exists or was created.
# ──────────────────────────────────────────────
ssh_tmux_create() {
  if [[ $# -lt 2 ]]; then
    safe_log "Error: ssh_tmux_create requires <host> and <session_name>."
    return 1
  fi

  local host="$1"
  local session_name="$2"

  _ssh_cmd "$host" \
    "tmux has-session -t ${session_name} 2>/dev/null || tmux new-session -d -s ${session_name}"
}

# ──────────────────────────────────────────────
# ssh_tmux_send <host> <session_name> <command>
# Send a command to an existing tmux session.
# ──────────────────────────────────────────────
ssh_tmux_send() {
  if [[ $# -lt 3 ]]; then
    safe_log "Error: ssh_tmux_send requires <host>, <session_name>, and <command>."
    return 1
  fi

  local host="$1"
  local session_name="$2"
  local command="$3"

  _ssh_cmd "$host" \
    "tmux send-keys -t ${session_name} '${command}' Enter"
}

# ──────────────────────────────────────────────
# ssh_tmux_attach <host> <session_name>
# Print the command needed to attach to a remote tmux session.
# Does NOT actually attach (requires interactive terminal).
# ──────────────────────────────────────────────
ssh_tmux_attach() {
  if [[ $# -lt 2 ]]; then
    safe_log "Error: ssh_tmux_attach requires <host> and <session_name>."
    return 1
  fi

  local host="$1"
  local session_name="$2"

  echo "ssh -t ${host} 'tmux attach -t ${session_name}'"
}

# ──────────────────────────────────────────────
# ssh_phase_mark <host> <phase_name>
# Write a phase marker on the remote host.
# Used for idempotent multi-step workflows.
# ──────────────────────────────────────────────
ssh_phase_mark() {
  if [[ $# -lt 2 ]]; then
    safe_log "Error: ssh_phase_mark requires <host> and <phase_name>."
    return 1
  fi

  local host="$1"
  local phase_name="$2"

  _ssh_cmd "$host" \
    "mkdir -p ~/.ategnatos-phases && touch ~/.ategnatos-phases/${phase_name}.done"
}

# ──────────────────────────────────────────────
# ssh_phase_check <host> <phase_name>
# Check if a phase marker exists on the remote host.
# Returns 0 if the phase is complete, 1 if not.
# ──────────────────────────────────────────────
ssh_phase_check() {
  if [[ $# -lt 2 ]]; then
    safe_log "Error: ssh_phase_check requires <host> and <phase_name>."
    return 1
  fi

  local host="$1"
  local phase_name="$2"

  _ssh_cmd "$host" \
    "test -f ~/.ategnatos-phases/${phase_name}.done"
}

# ──────────────────────────────────────────────
# ssh_reconnect_status <host>
# Quick connectivity check with latency measurement.
# Outputs JSON: {"host":"...","status":"connected|unreachable","latency_ms":"..."}
# ──────────────────────────────────────────────
ssh_reconnect_status() {
  if [[ $# -lt 1 ]]; then
    safe_log "Error: ssh_reconnect_status requires <host>."
    return 1
  fi

  local host="$1"
  local start_ms end_ms latency_ms

  start_ms=$(date +%s%3N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1000))')

  if ssh \
    -o StrictHostKeyChecking=no \
    -o BatchMode=yes \
    -o ConnectTimeout=5 \
    "$host" \
    "echo ok" >/dev/null 2>&1; then

    end_ms=$(date +%s%3N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1000))')
    latency_ms=$((end_ms - start_ms))

    printf '{"host":"%s","status":"connected","latency_ms":"%s"}\n' "$host" "$latency_ms"
  else
    printf '{"host":"%s","status":"unreachable","latency_ms":"0"}\n' "$host"
  fi
}
