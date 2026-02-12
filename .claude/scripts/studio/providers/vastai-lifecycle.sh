#!/usr/bin/env bash
# vastai-lifecycle.sh — Vast.ai provider lifecycle management
# Called by provider-spinup.sh and provider-teardown.sh
#
# Subcommands:
#   spinup       — Search, select, and rent a GPU instance
#   teardown     — Destroy a specific instance
#   teardown-all — Destroy ALL running instances
#   pull         — Download files from an instance
#   list         — List active instances
#   ssh-info     — Get SSH connection details
#
# Requires: vastai CLI (pip install vastai)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source security libraries
# shellcheck source=../../lib/validate-lib.sh
source "$SCRIPT_DIR/../../lib/validate-lib.sh"
# shellcheck source=../../lib/secrets-lib.sh
source "$SCRIPT_DIR/../../lib/secrets-lib.sh"

SUBCOMMAND="${1:-}"
shift 2>/dev/null || true

GPU=""
BUDGET=""
DISK="50"
TEMPLATE="pytorch/pytorch:2.1.0-cuda12.1-cudnn8-devel"
INSTANCE_ID=""
REMOTE_PATH=""
LOCAL_PATH="./results/"
SKIP_CONFIRM=false
JSON_OUTPUT=false

usage() {
    cat <<'USAGE'
vastai-lifecycle.sh — Vast.ai GPU lifecycle management

SUBCOMMANDS:
    spinup       Search and rent a GPU instance
    teardown     Destroy a specific instance
    teardown-all Destroy all active instances
    pull         Download files from an instance
    list         List active instances
    ssh-info     Get SSH connection details for an instance

SPINUP OPTIONS:
    --gpu <type>       GPU type: RTX_3090, RTX_4090, A100, etc.
    --budget <$/hr>    Maximum hourly rate
    --disk <GB>        Disk space (default: 50)
    --template <img>   Docker image
    --yes              Skip confirmation
    --json             Output JSON

TEARDOWN OPTIONS:
    --instance <id>    Instance ID to destroy
    --yes              Skip confirmation

PULL OPTIONS:
    --instance <id>    Instance ID
    --remote <path>    Remote path to download
    --local <path>     Local destination (default: ./results/)

EXAMPLES:
    vastai-lifecycle.sh spinup --gpu RTX_3090 --budget 0.50
    vastai-lifecycle.sh teardown --instance 12345
    vastai-lifecycle.sh pull --instance 12345 --remote /workspace/output/
    vastai-lifecycle.sh list
USAGE
    exit 0
}

# --- Argument Parsing ---

while [[ $# -gt 0 ]]; do
    case "$1" in
        --gpu) GPU="$2"; shift 2 ;;
        --budget) BUDGET="$2"; shift 2 ;;
        --disk) DISK="$2"; shift 2 ;;
        --template) TEMPLATE="$2"; shift 2 ;;
        --instance) INSTANCE_ID="$2"; shift 2 ;;
        --remote) REMOTE_PATH="$2"; shift 2 ;;
        --local) LOCAL_PATH="$2"; shift 2 ;;
        --yes) SKIP_CONFIRM=true; shift ;;
        --json) JSON_OUTPUT=true; shift ;;
        --help) usage ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# --- CLI Check ---

require_vastai() {
    if ! command -v vastai &>/dev/null; then
        echo "Error: vastai CLI not installed." >&2
        echo "  Install: pip install vastai" >&2
        echo "  Setup:   vastai set api-key YOUR_KEY" >&2
        exit 1
    fi
}

# --- Spinup ---

do_spinup() {
    require_vastai

    if [[ -z "$GPU" ]]; then
        echo "Error: --gpu is required for spinup" >&2
        exit 1
    fi

    echo "Searching for $GPU instances on Vast.ai..."

    # Build search query
    local query="gpu_name=${GPU} num_gpus=1 rentable=true disk_space>=${DISK}.0 reliability>0.95 cuda_vers>=12.0"
    [[ -n "$BUDGET" ]] && query+=" dph<=${BUDGET}"

    # Search
    local results
    results=$(vastai search offers "$query" -o 'dph' --limit 5 2>&1) || {
        echo "Error searching Vast.ai:" >&2
        echo "$results" >&2
        exit 1
    }

    if [[ -z "$results" ]] || echo "$results" | grep -q "No offers"; then
        echo "No matching instances found." >&2
        echo "  Try: Increase budget, choose a different GPU, or check Vast.ai availability" >&2
        exit 1
    fi

    echo ""
    echo "Available instances:"
    echo "$results"
    echo ""

    # Get cheapest offer ID
    local offer_id
    offer_id=$(echo "$results" | tail -n +2 | head -1 | awk '{print $1}')
    local offer_price
    offer_price=$(echo "$results" | tail -n +2 | head -1 | awk '{print $6}')

    echo "Best offer: ID $offer_id at \$${offer_price}/hr"
    echo ""

    # Cost estimation
    echo "Cost estimate:"
    echo "  1 hour:  \$${offer_price}"
    echo "  4 hours: \$(echo "$offer_price * 4" | bc 2>/dev/null || echo "~\$$(( ${offer_price%%.*} * 4 ))")"
    echo "  8 hours: \$(echo "$offer_price * 8" | bc 2>/dev/null || echo "~\$$(( ${offer_price%%.*} * 8 ))")"
    echo ""

    if ! $SKIP_CONFIRM; then
        read -rp "Rent this instance? (y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "Cancelled."
            exit 0
        fi
    fi

    echo "Creating instance..."
    local create_result
    create_result=$(vastai create instance "$offer_id" --image "$TEMPLATE" --disk "$DISK" 2>&1) || {
        echo "Error creating instance:" >&2
        echo "$create_result" >&2
        exit 1
    }

    echo "$create_result"
    echo ""
    echo "Instance is starting. Run 'vastai-lifecycle.sh ssh-info --instance <ID>' for connection details."
    echo "REMINDER: Tear down when done to stop charges."
}

# --- Teardown ---

do_teardown() {
    require_vastai

    if [[ -z "$INSTANCE_ID" ]]; then
        echo "Error: --instance is required for teardown" >&2
        exit 1
    fi

    if ! $SKIP_CONFIRM; then
        read -rp "Destroy instance $INSTANCE_ID? (y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "Cancelled."
            exit 0
        fi
    fi

    echo "Destroying instance $INSTANCE_ID..."
    vastai destroy instance "$INSTANCE_ID"
    echo "Instance $INSTANCE_ID destroyed."
}

# --- Teardown All ---

do_teardown_all() {
    require_vastai

    echo "Finding all active instances..."
    local instances
    instances=$(vastai show instances 2>&1) || {
        echo "No active instances found."
        return 0
    }

    if [[ -z "$instances" ]] || echo "$instances" | grep -qi "no instances"; then
        echo "No active instances."
        return 0
    fi

    echo "$instances"
    echo ""

    # Extract instance IDs
    local ids
    ids=$(echo "$instances" | tail -n +2 | awk '{print $1}')

    if [[ -z "$ids" ]]; then
        echo "No active instances to tear down."
        return 0
    fi

    for id in $ids; do
        echo "Destroying instance $id..."
        vastai destroy instance "$id" 2>/dev/null || echo "  Failed to destroy $id"
    done

    echo "All instances destroyed."
}

# --- Pull ---

do_pull() {
    require_vastai

    if [[ -z "$INSTANCE_ID" || -z "$REMOTE_PATH" ]]; then
        echo "Error: --instance and --remote are required for pull" >&2
        exit 1
    fi

    echo "Getting SSH details for instance $INSTANCE_ID..."
    local ssh_url
    ssh_url=$(vastai ssh-url "$INSTANCE_ID" 2>&1) || {
        echo "Error getting SSH details:" >&2
        echo "$ssh_url" >&2
        exit 1
    }

    # Parse ssh URL (format: ssh -p PORT root@IP)
    local port ip
    port=$(echo "$ssh_url" | sed -n 's/.*-p \([0-9]*\).*/\1/p')
    ip=$(echo "$ssh_url" | sed -n 's/.*@\([^ ]*\)$/\1/p')

    mkdir -p "$LOCAL_PATH"
    echo "Downloading $REMOTE_PATH to $LOCAL_PATH..."
    scp -P "$port" -r "root@${ip}:${REMOTE_PATH}" "$LOCAL_PATH"
    echo "Download complete."
}

# --- List ---

do_list() {
    require_vastai
    vastai show instances
}

# --- SSH Info ---

do_ssh_info() {
    require_vastai

    if [[ -z "$INSTANCE_ID" ]]; then
        echo "Error: --instance is required" >&2
        exit 1
    fi

    vastai ssh-url "$INSTANCE_ID"
}

# --- Dispatch ---

case "$SUBCOMMAND" in
    spinup) do_spinup ;;
    teardown) do_teardown ;;
    teardown-all) do_teardown_all ;;
    pull) do_pull ;;
    list) do_list ;;
    ssh-info) do_ssh_info ;;
    --help|-h|help|"") usage ;;
    *) echo "Unknown subcommand: $SUBCOMMAND" >&2; usage ;;
esac
