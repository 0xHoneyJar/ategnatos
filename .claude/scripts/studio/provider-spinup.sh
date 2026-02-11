#!/usr/bin/env bash
# provider-spinup.sh — Spin up a cloud GPU instance
# Generic dispatcher that routes to provider-specific lifecycle scripts.
#
# Usage:
#   provider-spinup.sh --provider vastai --gpu RTX_3090 [--budget 0.50] [--disk 50] [--json]
#   provider-spinup.sh --provider runpod --gpu A100 [--template pytorch2] [--json]
#
# The script:
#   1. Validates the provider CLI is installed and authenticated
#   2. Estimates cost based on GPU selection
#   3. Presents cost confirmation before any spend
#   4. Dispatches to provider-specific lifecycle script
#   5. Records the instance in grimoire/studio.md
#
# Requires: Provider CLI tool (vastai, runpodctl) + jq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GRIMOIRE_STUDIO=""
PROVIDER=""
GPU=""
BUDGET=""
DISK="50"
TEMPLATE="pytorch2"
JSON_OUTPUT=false
SKIP_CONFIRM=false

usage() {
    cat <<'USAGE'
provider-spinup.sh — Spin up a cloud GPU instance

USAGE:
    provider-spinup.sh --provider <name> --gpu <type> [OPTIONS]

REQUIRED:
    --provider <name>    Cloud provider: vastai, runpod, lambda
    --gpu <type>         GPU type: RTX_3090, RTX_4090, A100, H100, etc.

OPTIONS:
    --budget <$/hr>      Max hourly rate (default: no limit)
    --disk <GB>          Disk space in GB (default: 50)
    --template <name>    Docker template (default: pytorch2)
    --grimoire <path>    Path to studio.md (auto-detected)
    --yes                Skip cost confirmation
    --json               Output JSON instead of human-readable
    --help               Show this help

EXAMPLES:
    # Cheapest RTX 3090 on Vast.ai
    provider-spinup.sh --provider vastai --gpu RTX_3090 --budget 0.50

    # A100 on RunPod with extra disk
    provider-spinup.sh --provider runpod --gpu A100 --disk 100

    # Skip confirmation (for automated workflows)
    provider-spinup.sh --provider vastai --gpu RTX_4090 --yes

COST PROTECTION:
    This script ALWAYS shows estimated cost before spending money.
    Use --yes to skip confirmation (not recommended for interactive use).
USAGE
    exit 0
}

# --- Argument Parsing ---

while [[ $# -gt 0 ]]; do
    case "$1" in
        --provider) PROVIDER="$2"; shift 2 ;;
        --gpu) GPU="$2"; shift 2 ;;
        --budget) BUDGET="$2"; shift 2 ;;
        --disk) DISK="$2"; shift 2 ;;
        --template) TEMPLATE="$2"; shift 2 ;;
        --grimoire) GRIMOIRE_STUDIO="$2"; shift 2 ;;
        --yes) SKIP_CONFIRM=true; shift ;;
        --json) JSON_OUTPUT=true; shift ;;
        --help) usage ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$PROVIDER" ]]; then
    echo "Error: --provider is required (vastai, runpod, lambda)" >&2
    exit 1
fi

if [[ -z "$GPU" ]]; then
    echo "Error: --gpu is required (RTX_3090, RTX_4090, A100, H100, etc.)" >&2
    exit 1
fi

# --- Auto-detect grimoire ---

if [[ -z "$GRIMOIRE_STUDIO" ]]; then
    # Walk up to find project root
    dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/grimoire/studio.md" ]]; then
            GRIMOIRE_STUDIO="$dir/grimoire/studio.md"
            break
        fi
        dir="$(dirname "$dir")"
    done
fi

# --- Provider CLI Check ---

check_provider_cli() {
    case "$PROVIDER" in
        vastai)
            if ! command -v vastai &>/dev/null; then
                echo "Error: vastai CLI not installed." >&2
                echo "  Install: pip install vastai" >&2
                echo "  Setup:   vastai set api-key YOUR_KEY" >&2
                exit 1
            fi
            ;;
        runpod)
            if ! command -v runpodctl &>/dev/null; then
                echo "Error: runpodctl CLI not installed." >&2
                echo "  Install: pip install runpodctl" >&2
                exit 1
            fi
            ;;
        lambda)
            echo "Error: Lambda Cloud does not have a CLI. Use the web dashboard at lambdalabs.com." >&2
            echo "  After launching an instance manually, use provider-validate.sh to verify it." >&2
            exit 1
            ;;
        *)
            echo "Error: Unknown provider '$PROVIDER'. Supported: vastai, runpod, lambda" >&2
            exit 1
            ;;
    esac
}

# --- Dispatch to Provider Script ---

dispatch_provider() {
    local provider_script="${SCRIPT_DIR}/providers/${PROVIDER}-lifecycle.sh"

    if [[ ! -x "$provider_script" ]]; then
        echo "Error: Provider script not found or not executable: $provider_script" >&2
        exit 1
    fi

    local args=(
        spinup
        --gpu "$GPU"
        --disk "$DISK"
        --template "$TEMPLATE"
    )

    [[ -n "$BUDGET" ]] && args+=(--budget "$BUDGET")
    $SKIP_CONFIRM && args+=(--yes)
    $JSON_OUTPUT && args+=(--json)

    "$provider_script" "${args[@]}"
}

# --- Record Instance ---

record_instance() {
    local instance_id="$1"
    local provider="$2"
    local gpu="$3"
    local cost_hr="$4"
    local ssh_cmd="$5"

    if [[ -z "$GRIMOIRE_STUDIO" ]]; then
        echo "Warning: Could not find grimoire/studio.md — instance not recorded" >&2
        return
    fi

    local timestamp
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # Append to Active Instances section
    cat >> "$GRIMOIRE_STUDIO" <<INSTANCE

### Active Instance: ${instance_id}
- **Provider**: ${provider}
- **GPU**: ${gpu}
- **Cost**: \$${cost_hr}/hr
- **Started**: ${timestamp}
- **SSH**: \`${ssh_cmd}\`
- **Status**: RUNNING
INSTANCE

    echo "Instance recorded in studio.md"
}

# --- Main ---

check_provider_cli

echo "=== GPU Instance Spin-Up ==="
echo "Provider: $PROVIDER"
echo "GPU: $GPU"
echo "Disk: ${DISK} GB"
[[ -n "$BUDGET" ]] && echo "Budget: \$${BUDGET}/hr max"
echo ""

# Dispatch to provider-specific script
# The provider script handles: search, cost display, confirmation, creation
dispatch_provider

echo ""
echo "REMINDER: This instance costs money every minute it runs."
echo "When done, run: provider-teardown.sh --provider $PROVIDER --instance <ID>"
