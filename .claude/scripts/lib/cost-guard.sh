#!/usr/bin/env bash
# cost-guard.sh — Cost enforcement library for GPU billing protection
# Usage: source this file, then call cost_* functions
#
# Provides timer-based cost tracking, budget checks, and teardown reminders.
# Requires: jq, sha256sum or shasum

set -euo pipefail

# Guard against double-sourcing
[[ -n "${_COST_GUARD_LOADED:-}" ]] && return 0
_COST_GUARD_LOADED=1

# Source validate-lib.sh from the same directory
# shellcheck source=validate-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/validate-lib.sh"

# ──────────────────────────────────────────────
# Globals — populated by cost_load_config
# ──────────────────────────────────────────────
_COST_MAX_HOURLY=""
_COST_MAX_TOTAL=""
_COST_MAX_RUNTIME_MIN=""
_COST_AUTO_TEARDOWN_MIN=""
_COST_REQUIRE_CONFIRM=""

# ──────────────────────────────────────────────
# _cost_detect_project_root
# Walk up from CWD looking for grimoire/cost-config.json.
# Falls back to _PROJECT_ROOT from validate-lib.sh.
# ──────────────────────────────────────────────
_cost_detect_project_root() {
  local dir
  dir="$(pwd)"

  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/grimoire/cost-config.json" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done

  # Fallback: use the project root from validate-lib.sh
  echo "${_PROJECT_ROOT:-}"
}

# ──────────────────────────────────────────────
# _cost_hash_id <resource_id>
# Produce first 8 chars of SHA-256 hash for a resource ID.
# Works on both Linux (sha256sum) and macOS (shasum).
# ──────────────────────────────────────────────
_cost_hash_id() {
  local resource_id="${1:?Error: resource ID required}"
  local hash

  if command -v sha256sum >/dev/null 2>&1; then
    hash="$(printf '%s' "$resource_id" | sha256sum | cut -c1-8)"
  elif command -v shasum >/dev/null 2>&1; then
    hash="$(printf '%s' "$resource_id" | shasum -a 256 | cut -c1-8)"
  else
    echo "Error: Neither sha256sum nor shasum found." >&2
    return 1
  fi

  echo "$hash"
}

# ──────────────────────────────────────────────
# _cost_timer_path <resource_id>
# Return the path to a timer JSON file for a resource.
# ──────────────────────────────────────────────
_cost_timer_path() {
  local resource_id="${1:?Error: resource ID required}"
  local hash
  hash="$(_cost_hash_id "$resource_id")"
  echo "/tmp/ategnatos-cost-timer-${hash}.json"
}

# ──────────────────────────────────────────────
# cost_load_config
# Find cost-config.json by walking up from CWD.
# Parse with jq and store in global variables.
# Uses sensible defaults if no config file is found.
# ──────────────────────────────────────────────
cost_load_config() {
  local root
  root="$(_cost_detect_project_root)"
  local config_path="${root}/grimoire/cost-config.json"

  if [[ -f "$config_path" ]]; then
    # Validate the JSON before reading it
    if ! jq empty "$config_path" 2>/dev/null; then
      echo "Warning: cost-config.json is not valid JSON. Using defaults." >&2
      _cost_apply_defaults
      return 0
    fi

    _COST_MAX_HOURLY="$(jq -r '.max_hourly_rate // 3.00' "$config_path")"
    _COST_MAX_TOTAL="$(jq -r '.max_total_cost // 50.00' "$config_path")"
    _COST_MAX_RUNTIME_MIN="$(jq -r '.max_runtime_minutes // 480' "$config_path")"
    _COST_AUTO_TEARDOWN_MIN="$(jq -r '.auto_teardown_minutes // 60' "$config_path")"
    _COST_REQUIRE_CONFIRM="$(jq -r '.require_confirm // true' "$config_path")"
  else
    echo "Info: No cost-config.json found. Using defaults." >&2
    _cost_apply_defaults
  fi
}

# ──────────────────────────────────────────────
# _cost_apply_defaults
# Set all config globals to their default values.
# ──────────────────────────────────────────────
_cost_apply_defaults() {
  _COST_MAX_HOURLY="3.00"
  _COST_MAX_TOTAL="50.00"
  _COST_MAX_RUNTIME_MIN="480"
  _COST_AUTO_TEARDOWN_MIN="60"
  _COST_REQUIRE_CONFIRM="true"
}

# ──────────────────────────────────────────────
# cost_check --operation <type> --estimated <amount>
# Compare an estimated cost against the max_total_cost budget.
# Exit 0 if under budget, exit 1 if over.
# ──────────────────────────────────────────────
cost_check() {
  local operation=""
  local estimated=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --operation)
        operation="${2:?Error: --operation requires a value}"
        shift 2
        ;;
      --estimated)
        estimated="${2:?Error: --estimated requires a value}"
        shift 2
        ;;
      *)
        echo "Error: Unknown flag: $1" >&2
        return 1
        ;;
    esac
  done

  if [[ -z "$operation" ]]; then
    echo "Error: --operation is required (train, generate, instance)." >&2
    return 1
  fi

  if [[ -z "$estimated" ]]; then
    echo "Error: --estimated is required (dollar amount)." >&2
    return 1
  fi

  # Load config if not already loaded
  if [[ -z "$_COST_MAX_TOTAL" ]]; then
    cost_load_config
  fi

  # Compare using awk for floating-point comparison
  local over_budget
  over_budget="$(awk -v est="$estimated" -v max="$_COST_MAX_TOTAL" \
    'BEGIN { print (est > max) ? "yes" : "no" }')"

  if [[ "$over_budget" == "yes" ]]; then
    echo "WARNING: Estimated cost \$${estimated} for '${operation}' exceeds budget limit of \$${_COST_MAX_TOTAL}." >&2
    echo "Operation blocked. Adjust your configuration or cost-config.json to proceed." >&2
    return 1
  fi

  # Also check hourly rate if applicable
  echo "OK: Estimated cost \$${estimated} for '${operation}' is within budget (\$${_COST_MAX_TOTAL} max)."
  return 0
}

# ──────────────────────────────────────────────
# cost_start_timer --resource <id> --rate <$/hr> [--max-minutes <N>]
# Create a timer JSON file tracking a billable resource.
# ──────────────────────────────────────────────
cost_start_timer() {
  local resource=""
  local rate=""
  local max_minutes=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --resource)
        resource="${2:?Error: --resource requires a value}"
        shift 2
        ;;
      --rate)
        rate="${2:?Error: --rate requires a value}"
        shift 2
        ;;
      --max-minutes)
        max_minutes="${2:?Error: --max-minutes requires a value}"
        shift 2
        ;;
      *)
        echo "Error: Unknown flag: $1" >&2
        return 1
        ;;
    esac
  done

  if [[ -z "$resource" ]]; then
    echo "Error: --resource is required." >&2
    return 1
  fi

  if [[ -z "$rate" ]]; then
    echo "Error: --rate is required (dollars per hour)." >&2
    return 1
  fi

  # Load config if not already loaded (for max_minutes default)
  if [[ -z "$_COST_MAX_RUNTIME_MIN" ]]; then
    cost_load_config
  fi

  if [[ -z "$max_minutes" ]]; then
    max_minutes="$_COST_MAX_RUNTIME_MIN"
  fi

  local timer_path
  timer_path="$(_cost_timer_path "$resource")"
  local now
  now="$(date +%s)"

  jq -n \
    --arg resource "$resource" \
    --argjson rate "$rate" \
    --argjson started_at "$now" \
    --argjson max_minutes "$max_minutes" \
    '{resource: $resource, rate: $rate, started_at: $started_at, max_minutes: $max_minutes}' \
    > "$timer_path"

  echo "Timer started for '${resource}' at \$${rate}/hr (max ${max_minutes} min)."
  echo "Timer file: ${timer_path}"
}

# ──────────────────────────────────────────────
# cost_stop_timer --resource <id>
# Read timer file, compute elapsed time and cost,
# remove the timer file, and print a summary.
# ──────────────────────────────────────────────
cost_stop_timer() {
  local resource=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --resource)
        resource="${2:?Error: --resource requires a value}"
        shift 2
        ;;
      *)
        echo "Error: Unknown flag: $1" >&2
        return 1
        ;;
    esac
  done

  if [[ -z "$resource" ]]; then
    echo "Error: --resource is required." >&2
    return 1
  fi

  local timer_path
  timer_path="$(_cost_timer_path "$resource")"

  if [[ ! -f "$timer_path" ]]; then
    echo "Error: No active timer found for '${resource}'." >&2
    return 1
  fi

  local started_at rate now elapsed_seconds
  started_at="$(jq -r '.started_at' "$timer_path")"
  rate="$(jq -r '.rate' "$timer_path")"
  now="$(date +%s)"
  elapsed_seconds=$((now - started_at))

  local elapsed_minutes total_cost
  elapsed_minutes="$(awk -v s="$elapsed_seconds" 'BEGIN { printf "%.1f", s / 60 }')"
  total_cost="$(awk -v s="$elapsed_seconds" -v r="$rate" 'BEGIN { printf "%.2f", (s / 3600) * r }')"

  rm -f "$timer_path"

  echo "Timer stopped for '${resource}'."
  echo "  Elapsed: ${elapsed_minutes} minutes"
  echo "  Rate:    \$${rate}/hr"
  echo "  Total:   \$${total_cost}"
}

# ──────────────────────────────────────────────
# cost_teardown_overdue
# Scan all active timers and report any that have
# exceeded auto_teardown_minutes.
# Exit 0 if none overdue, exit 1 if any found.
# ──────────────────────────────────────────────
cost_teardown_overdue() {
  # Load config if not already loaded
  if [[ -z "$_COST_AUTO_TEARDOWN_MIN" ]]; then
    cost_load_config
  fi

  local now overdue_count timer_file
  now="$(date +%s)"
  overdue_count=0

  for timer_file in /tmp/ategnatos-cost-timer-*.json; do
    # Handle case where glob matches nothing
    [[ -f "$timer_file" ]] || continue

    local resource started_at rate max_minutes elapsed_seconds elapsed_minutes
    resource="$(jq -r '.resource' "$timer_file")"
    started_at="$(jq -r '.started_at' "$timer_file")"
    rate="$(jq -r '.rate' "$timer_file")"
    max_minutes="$(jq -r '.max_minutes // 0' "$timer_file")"
    elapsed_seconds=$((now - started_at))
    elapsed_minutes="$(awk -v s="$elapsed_seconds" 'BEGIN { printf "%.1f", s / 60 }')"

    local teardown_seconds
    teardown_seconds=$((_COST_AUTO_TEARDOWN_MIN * 60))

    if [[ "$elapsed_seconds" -gt "$teardown_seconds" ]]; then
      local estimated_cost
      estimated_cost="$(awk -v s="$elapsed_seconds" -v r="$rate" 'BEGIN { printf "%.2f", (s / 3600) * r }')"

      echo "OVERDUE: '${resource}' has been running for ${elapsed_minutes} min (limit: ${_COST_AUTO_TEARDOWN_MIN} min)."
      echo "  Estimated cost so far: \$${estimated_cost}"
      echo "  Consider tearing down this resource."
      overdue_count=$((overdue_count + 1))
    fi
  done

  if [[ "$overdue_count" -eq 0 ]]; then
    echo "No overdue resources found."
    return 0
  else
    echo ""
    echo "${overdue_count} resource(s) overdue for teardown."
    return 1
  fi
}

# ──────────────────────────────────────────────
# cost_report
# List all active timers with elapsed time and
# running cost. If none, report that.
# ──────────────────────────────────────────────
cost_report() {
  local now active_count timer_file
  now="$(date +%s)"
  active_count=0

  for timer_file in /tmp/ategnatos-cost-timer-*.json; do
    # Handle case where glob matches nothing
    [[ -f "$timer_file" ]] || continue

    local resource started_at rate elapsed_seconds elapsed_minutes running_cost
    resource="$(jq -r '.resource' "$timer_file")"
    started_at="$(jq -r '.started_at' "$timer_file")"
    rate="$(jq -r '.rate' "$timer_file")"
    elapsed_seconds=$((now - started_at))
    elapsed_minutes="$(awk -v s="$elapsed_seconds" 'BEGIN { printf "%.1f", s / 60 }')"
    running_cost="$(awk -v s="$elapsed_seconds" -v r="$rate" 'BEGIN { printf "%.2f", (s / 3600) * r }')"

    if [[ "$active_count" -eq 0 ]]; then
      echo "Active cost timers:"
      echo "─────────────────────────────────────────"
    fi

    echo "  ${resource}"
    echo "    Rate:    \$${rate}/hr"
    echo "    Elapsed: ${elapsed_minutes} min"
    echo "    Cost:    \$${running_cost}"
    echo ""
    active_count=$((active_count + 1))
  done

  if [[ "$active_count" -eq 0 ]]; then
    echo "No active cost timers."
  else
    echo "${active_count} active timer(s)."
  fi
}
