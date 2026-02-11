#!/usr/bin/env bash
# provider-teardown.sh — Tear down a cloud GPU instance
# ALWAYS tear down when training is complete. Every minute costs money.
#
# Usage:
#   provider-teardown.sh --provider vastai --instance 12345
#   provider-teardown.sh --provider runpod --instance pod-abc123
#   provider-teardown.sh --all   # Tear down ALL active instances (emergency)
#
# The script:
#   1. Confirms the instance exists
#   2. Optionally pulls results before teardown
#   3. Destroys the instance
#   4. Updates grimoire/studio.md to mark instance as TERMINATED
#
# COST PROTECTION: This is the most important script in the provider lifecycle.
# A forgotten instance burns money 24/7.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GRIMOIRE_STUDIO=""
PROVIDER=""
INSTANCE_ID=""
PULL_RESULTS=false
RESULTS_PATH=""
TEAR_ALL=false
SKIP_CONFIRM=false
JSON_OUTPUT=false

usage() {
    cat <<'USAGE'
provider-teardown.sh — Tear down a cloud GPU instance

USAGE:
    provider-teardown.sh --provider <name> --instance <id> [OPTIONS]
    provider-teardown.sh --all [--provider <name>]

REQUIRED (unless --all):
    --provider <name>    Cloud provider: vastai, runpod
    --instance <id>      Instance/pod ID to destroy

OPTIONS:
    --pull <remote_path>  Pull results before teardown (scp from instance)
    --to <local_path>     Local destination for pulled results (default: ./results/)
    --all                 Tear down ALL active instances
    --yes                 Skip confirmation
    --json                Output JSON
    --grimoire <path>     Path to studio.md (auto-detected)
    --help                Show this help

EXAMPLES:
    # Standard teardown
    provider-teardown.sh --provider vastai --instance 12345

    # Pull trained LoRA then teardown
    provider-teardown.sh --provider vastai --instance 12345 \
        --pull /workspace/output/ --to ./my-lora/

    # Emergency: destroy everything
    provider-teardown.sh --all --yes

COST PROTECTION:
    Forgetting to teardown costs $0.10-3.00/hr continuously.
    Set a calendar reminder if you walk away from a running instance.
USAGE
    exit 0
}

# --- Argument Parsing ---

while [[ $# -gt 0 ]]; do
    case "$1" in
        --provider) PROVIDER="$2"; shift 2 ;;
        --instance) INSTANCE_ID="$2"; shift 2 ;;
        --pull) PULL_RESULTS=true; RESULTS_PATH="$2"; shift 2 ;;
        --to) LOCAL_DEST="$2"; shift 2 ;;
        --all) TEAR_ALL=true; shift ;;
        --yes) SKIP_CONFIRM=true; shift ;;
        --json) JSON_OUTPUT=true; shift ;;
        --grimoire) GRIMOIRE_STUDIO="$2"; shift 2 ;;
        --help) usage ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

LOCAL_DEST="${LOCAL_DEST:-./results/}"

if ! $TEAR_ALL && [[ -z "$PROVIDER" || -z "$INSTANCE_ID" ]]; then
    echo "Error: --provider and --instance are required (or use --all)" >&2
    exit 1
fi

# --- Auto-detect grimoire ---

if [[ -z "$GRIMOIRE_STUDIO" ]]; then
    dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/grimoire/studio.md" ]]; then
            GRIMOIRE_STUDIO="$dir/grimoire/studio.md"
            break
        fi
        dir="$(dirname "$dir")"
    done
fi

# --- Confirmation ---

confirm_teardown() {
    if $SKIP_CONFIRM; then
        return 0
    fi

    echo ""
    echo "WARNING: This will PERMANENTLY destroy the instance."
    echo "  Provider: $PROVIDER"
    echo "  Instance: $INSTANCE_ID"
    echo ""
    read -rp "Type 'teardown' to confirm: " confirm
    if [[ "$confirm" != "teardown" ]]; then
        echo "Teardown cancelled."
        exit 0
    fi
}

# --- Dispatch to Provider Script ---

dispatch_teardown() {
    local provider_script="${SCRIPT_DIR}/providers/${PROVIDER}-lifecycle.sh"

    if [[ ! -x "$provider_script" ]]; then
        echo "Error: Provider script not found: $provider_script" >&2
        exit 1
    fi

    local args=(teardown --instance "$INSTANCE_ID")
    $SKIP_CONFIRM && args+=(--yes)
    $JSON_OUTPUT && args+=(--json)

    "$provider_script" "${args[@]}"
}

# --- Pull Results ---

pull_results() {
    if ! $PULL_RESULTS; then
        return 0
    fi

    echo "Pulling results before teardown..."

    local provider_script="${SCRIPT_DIR}/providers/${PROVIDER}-lifecycle.sh"
    "$provider_script" pull --instance "$INSTANCE_ID" --remote "$RESULTS_PATH" --local "$LOCAL_DEST"

    echo "Results saved to: $LOCAL_DEST"
}

# --- Update Grimoire ---

update_grimoire() {
    if [[ -z "$GRIMOIRE_STUDIO" || ! -f "$GRIMOIRE_STUDIO" ]]; then
        return 0
    fi

    local timestamp
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # Mark instance as terminated in studio.md
    if command -v sed &>/dev/null; then
        sed -i.bak "s/### Active Instance: ${INSTANCE_ID}/### Terminated Instance: ${INSTANCE_ID} (${timestamp})/" "$GRIMOIRE_STUDIO" 2>/dev/null || true
        sed -i.bak "s/- \*\*Status\*\*: RUNNING/- **Status**: TERMINATED (${timestamp})/" "$GRIMOIRE_STUDIO" 2>/dev/null || true
        rm -f "${GRIMOIRE_STUDIO}.bak"
    fi

    echo "Instance marked as TERMINATED in studio.md"
}

# --- Main ---

if $TEAR_ALL; then
    echo "=== EMERGENCY TEARDOWN: ALL INSTANCES ==="
    echo ""
    echo "This will destroy ALL active cloud GPU instances."

    if ! $SKIP_CONFIRM; then
        read -rp "Type 'teardown all' to confirm: " confirm
        if [[ "$confirm" != "teardown all" ]]; then
            echo "Teardown cancelled."
            exit 0
        fi
    fi

    # Try each provider
    for p in vastai runpod; do
        provider_script="${SCRIPT_DIR}/providers/${p}-lifecycle.sh"
        if [[ -x "$provider_script" ]]; then
            echo ""
            echo "--- Checking $p ---"
            "$provider_script" teardown-all --yes 2>/dev/null || echo "  No active instances on $p (or CLI not configured)"
        fi
    done

    echo ""
    echo "Emergency teardown complete. Check provider dashboards to verify."
    exit 0
fi

echo "=== GPU Instance Teardown ==="
echo "Provider: $PROVIDER"
echo "Instance: $INSTANCE_ID"

# Pull results first if requested
pull_results

# Confirm and destroy
confirm_teardown
dispatch_teardown
update_grimoire

echo ""
echo "Instance $INSTANCE_ID has been destroyed."
echo "No further charges will accrue for this instance."
