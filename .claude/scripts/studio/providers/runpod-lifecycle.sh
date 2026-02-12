#!/usr/bin/env bash
# runpod-lifecycle.sh — RunPod provider lifecycle management
# Called by provider-spinup.sh and provider-teardown.sh
#
# Subcommands:
#   spinup       — Create a pod with specified GPU
#   teardown     — Stop and remove a specific pod
#   teardown-all — Stop all running pods
#   pull         — Download files from a pod
#   list         — List active pods
#   ssh-info     — Get SSH connection details
#
# Requires: runpodctl CLI (pip install runpodctl)

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
TEMPLATE="runpod/pytorch:2.1.0-py3.10-cuda12.1.0-devel-ubuntu22.04"
CLOUD_TYPE="COMMUNITY"
INSTANCE_ID=""
REMOTE_PATH=""
LOCAL_PATH="./results/"
SKIP_CONFIRM=false
JSON_OUTPUT=false

usage() {
    cat <<'USAGE'
runpod-lifecycle.sh — RunPod GPU lifecycle management

SUBCOMMANDS:
    spinup       Create a pod with specified GPU
    teardown     Stop and remove a specific pod
    teardown-all Stop all running pods
    pull         Download files from a pod
    list         List active pods
    ssh-info     Get SSH connection details for a pod

SPINUP OPTIONS:
    --gpu <type>       GPU type: RTX_4090, A100_80GB, etc.
    --budget <$/hr>    Maximum hourly rate
    --disk <GB>        Disk space (default: 50)
    --template <img>   Docker image
    --cloud <type>     COMMUNITY or SECURE (default: COMMUNITY)
    --yes              Skip confirmation
    --json             Output JSON

TEARDOWN OPTIONS:
    --instance <id>    Pod ID to stop and remove
    --yes              Skip confirmation

PULL OPTIONS:
    --instance <id>    Pod ID
    --remote <path>    Remote path to download
    --local <path>     Local destination (default: ./results/)

EXAMPLES:
    runpod-lifecycle.sh spinup --gpu RTX_4090 --budget 0.50
    runpod-lifecycle.sh teardown --instance pod-abc123
    runpod-lifecycle.sh pull --instance pod-abc123 --remote /workspace/output/
    runpod-lifecycle.sh list
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
        --cloud) CLOUD_TYPE="$2"; shift 2 ;;
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

require_runpod() {
    if ! command -v runpodctl &>/dev/null; then
        echo "Error: runpodctl CLI not installed." >&2
        echo "  Install: pip install runpodctl" >&2
        echo "  Then configure API key via RunPod dashboard" >&2
        exit 1
    fi
}

# --- GPU Type Mapping ---
# RunPod uses specific GPU IDs different from common names

map_gpu_id() {
    local input="$1"
    case "${input^^}" in
        RTX_3090|RTX3090)       echo "NVIDIA GeForce RTX 3090" ;;
        RTX_4090|RTX4090)       echo "NVIDIA GeForce RTX 4090" ;;
        A100|A100_80GB)         echo "NVIDIA A100 80GB PCIe" ;;
        A100_40GB)              echo "NVIDIA A100-SXM4-40GB" ;;
        A6000)                  echo "NVIDIA RTX A6000" ;;
        H100|H100_80GB)         echo "NVIDIA H100 80GB HBM3" ;;
        *)                      echo "$input" ;;
    esac
}

# --- Spinup ---

do_spinup() {
    require_runpod

    if [[ -z "$GPU" ]]; then
        echo "Error: --gpu is required for spinup" >&2
        exit 1
    fi

    local gpu_full
    gpu_full=$(map_gpu_id "$GPU")

    echo "Creating RunPod pod..."
    echo "  GPU: $gpu_full"
    echo "  Cloud: $CLOUD_TYPE"
    echo "  Disk: ${DISK} GB"
    echo "  Template: $TEMPLATE"
    echo ""

    # RunPod pricing varies; show estimates
    echo "Typical pricing for $GPU:"
    case "${GPU^^}" in
        RTX_3090|RTX3090)   echo "  Community: ~\$0.20-0.30/hr  Secure: ~\$0.40-0.50/hr" ;;
        RTX_4090|RTX4090)   echo "  Community: ~\$0.35-0.50/hr  Secure: ~\$0.60-0.80/hr" ;;
        A100*)              echo "  Community: ~\$0.80-1.20/hr  Secure: ~\$1.50-2.50/hr" ;;
        H100*)              echo "  Secure: ~\$2.50-3.50/hr" ;;
        *)                  echo "  Check runpod.io for current pricing" ;;
    esac
    echo ""

    if ! $SKIP_CONFIRM; then
        read -rp "Create this pod? (y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "Cancelled."
            exit 0
        fi
    fi

    echo "Creating pod..."
    local result
    result=$(runpodctl create pod \
        --name "ategnatos-training" \
        --gpuType "$gpu_full" \
        --gpuCount 1 \
        --volumeSize "$DISK" \
        --containerDiskSize 20 \
        --imageName "$TEMPLATE" \
        --cloudType "$CLOUD_TYPE" \
        2>&1) || {
        echo "Error creating pod:" >&2
        echo "$result" >&2
        exit 1
    }

    echo "$result"
    echo ""
    echo "Pod is starting. Check status with: runpod-lifecycle.sh list"
    echo "REMINDER: Stop the pod when done to avoid ongoing charges."
}

# --- Teardown ---

do_teardown() {
    require_runpod

    if [[ -z "$INSTANCE_ID" ]]; then
        echo "Error: --instance is required for teardown" >&2
        exit 1
    fi

    if ! $SKIP_CONFIRM; then
        read -rp "Stop and remove pod $INSTANCE_ID? (y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "Cancelled."
            exit 0
        fi
    fi

    echo "Stopping pod $INSTANCE_ID..."
    runpodctl stop pod "$INSTANCE_ID" 2>/dev/null || true

    echo "Removing pod $INSTANCE_ID..."
    runpodctl remove pod "$INSTANCE_ID"
    echo "Pod $INSTANCE_ID removed."
}

# --- Teardown All ---

do_teardown_all() {
    require_runpod

    echo "Finding all active pods..."
    local pods
    pods=$(runpodctl get pod 2>&1) || {
        echo "No active pods found."
        return 0
    }

    echo "$pods"
    echo ""

    # Extract pod IDs (RunPod format varies)
    local ids
    ids=$(echo "$pods" | tail -n +2 | awk '{print $1}' | grep -v '^$')

    if [[ -z "$ids" ]]; then
        echo "No active pods to tear down."
        return 0
    fi

    for id in $ids; do
        echo "Stopping and removing pod $id..."
        runpodctl stop pod "$id" 2>/dev/null || true
        runpodctl remove pod "$id" 2>/dev/null || echo "  Failed to remove $id"
    done

    echo "All pods removed."
}

# --- Pull ---

do_pull() {
    require_runpod

    if [[ -z "$INSTANCE_ID" || -z "$REMOTE_PATH" ]]; then
        echo "Error: --instance and --remote are required for pull" >&2
        exit 1
    fi

    mkdir -p "$LOCAL_PATH"
    echo "Downloading files from pod $INSTANCE_ID..."

    # RunPod supports direct file transfer via runpodctl
    runpodctl receive "$INSTANCE_ID" --path "$REMOTE_PATH" --dest "$LOCAL_PATH" 2>/dev/null || {
        # Fallback to SSH-based transfer
        echo "Direct transfer failed, trying SSH..."
        local ssh_info
        ssh_info=$(runpodctl ssh --pod "$INSTANCE_ID" --command "echo connected" 2>&1)
        echo "Use SSH to transfer files manually:"
        echo "  runpodctl ssh --pod $INSTANCE_ID"
        echo "  Then: scp files from the pod"
        exit 1
    }

    echo "Download complete: $LOCAL_PATH"
}

# --- List ---

do_list() {
    require_runpod
    echo "Active RunPod pods:"
    runpodctl get pod
}

# --- SSH Info ---

do_ssh_info() {
    require_runpod

    if [[ -z "$INSTANCE_ID" ]]; then
        echo "Error: --instance is required" >&2
        exit 1
    fi

    echo "SSH into pod:"
    echo "  runpodctl ssh --pod $INSTANCE_ID"
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
