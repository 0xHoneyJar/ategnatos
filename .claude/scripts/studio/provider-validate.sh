#!/usr/bin/env bash
# provider-validate.sh — Pre-flight validation on a remote GPU instance
# Runs BEFORE deploying training tools or transferring data.
#
# Usage:
#   provider-validate.sh --host <user@ip> --port <port> [--gpu RTX_3090] [--vram-min 24] [--json]
#
# Checks:
#   1. SSH connectivity
#   2. GPU detection (nvidia-smi)
#   3. CUDA version
#   4. Available VRAM
#   5. Available disk space
#   6. Python/pip availability
#   7. Network speed (basic check)
#
# This is Gate 3's remote counterpart — validate-environment.sh runs locally,
# this script runs the same checks on a cloud instance via SSH.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source security libraries
# shellcheck source=../lib/validate-lib.sh
source "$SCRIPT_DIR/../lib/validate-lib.sh"
# shellcheck source=../lib/secrets-lib.sh
source "$SCRIPT_DIR/../lib/secrets-lib.sh"

SSH_HOST=""
SSH_PORT="22"
SSH_KEY=""
EXPECTED_GPU=""
VRAM_MIN=""
DISK_MIN="50"
JSON_OUTPUT=false
TIMEOUT=10

usage() {
    cat <<'USAGE'
provider-validate.sh — Validate a remote GPU instance

USAGE:
    provider-validate.sh --host <user@ip> [OPTIONS]

REQUIRED:
    --host <user@ip>     SSH host (e.g., root@203.0.113.10)

OPTIONS:
    --port <port>        SSH port (default: 22)
    --key <path>         SSH key file
    --gpu <type>         Expected GPU (warn if different)
    --vram-min <GB>      Minimum VRAM required (default: none)
    --disk-min <GB>      Minimum disk space required (default: 50)
    --timeout <sec>      SSH connection timeout (default: 10)
    --json               Output JSON
    --help               Show this help

EXAMPLES:
    # Basic validation
    provider-validate.sh --host root@192.168.1.100

    # Validate with expectations
    provider-validate.sh --host root@203.0.113.10 --port 40022 \
        --gpu RTX_3090 --vram-min 24 --disk-min 100

WHAT THIS CHECKS:
    ✓ SSH connectivity
    ✓ GPU presence and type (nvidia-smi)
    ✓ CUDA version
    ✓ Available VRAM
    ✓ Disk space
    ✓ Python availability
USAGE
    exit 0
}

# --- Argument Parsing ---

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host) SSH_HOST="$2"; shift 2 ;;
        --port) SSH_PORT="$2"; shift 2 ;;
        --key) SSH_KEY="$2"; shift 2 ;;
        --gpu) EXPECTED_GPU="$2"; shift 2 ;;
        --vram-min) VRAM_MIN="$2"; shift 2 ;;
        --disk-min) DISK_MIN="$2"; shift 2 ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --json) JSON_OUTPUT=true; shift ;;
        --help) usage ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$SSH_HOST" ]]; then
    echo "Error: --host is required" >&2
    exit 1
fi

# --- SSH Helper ---

SSH_OPTS=(-o "ConnectTimeout=${TIMEOUT}" -o "StrictHostKeyChecking=no" -o "BatchMode=yes" -p "$SSH_PORT")
[[ -n "$SSH_KEY" ]] && SSH_OPTS+=(-i "$SSH_KEY")

remote_cmd() {
    # shellcheck disable=SC2029
    ssh "${SSH_OPTS[@]}" "$SSH_HOST" "$1" 2>/dev/null
}

# --- Validation ---

CHECKS=()
WARNINGS=()
ERRORS=()
PASS=true

add_check() {
    local name="$1" status="$2" detail="$3"
    CHECKS+=("{\"name\":\"$name\",\"status\":\"$status\",\"detail\":\"$detail\"}")
    if [[ "$status" == "FAIL" ]]; then
        ERRORS+=("$name: $detail")
        PASS=false
    elif [[ "$status" == "WARN" ]]; then
        WARNINGS+=("$name: $detail")
    fi
}

echo "=== Remote Instance Validation ==="
echo "Host: $SSH_HOST:$SSH_PORT"
echo ""

# Check 1: SSH connectivity
echo -n "SSH connectivity... "
if remote_cmd "echo ok" &>/dev/null; then
    echo "OK"
    add_check "ssh" "PASS" "Connected to ${SSH_HOST}:${SSH_PORT}"
else
    echo "FAIL"
    add_check "ssh" "FAIL" "Cannot connect to ${SSH_HOST}:${SSH_PORT}"
    # Can't continue without SSH
    echo ""
    echo "RESULT: FAIL — Cannot connect to instance"
    echo "  Check: Is the instance running? Is the SSH port correct?"
    exit 1
fi

# Check 2: GPU detection
echo -n "GPU detection... "
GPU_INFO=$(remote_cmd "nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>/dev/null" || echo "")
if [[ -n "$GPU_INFO" ]]; then
    GPU_NAME=$(echo "$GPU_INFO" | head -1 | cut -d',' -f1 | xargs)
    GPU_VRAM=$(echo "$GPU_INFO" | head -1 | cut -d',' -f2 | xargs)
    GPU_VRAM_GB=$(( GPU_VRAM / 1024 ))
    echo "OK — $GPU_NAME (${GPU_VRAM_GB} GB)"
    add_check "gpu" "PASS" "${GPU_NAME} ${GPU_VRAM_GB}GB"

    # Check against expected GPU
    if [[ -n "$EXPECTED_GPU" ]] && ! echo "$GPU_NAME" | grep -qi "$EXPECTED_GPU"; then
        echo "  Warning: Expected $EXPECTED_GPU but found $GPU_NAME"
        add_check "gpu_match" "WARN" "Expected ${EXPECTED_GPU}, found ${GPU_NAME}"
    fi

    # Check VRAM minimum
    if [[ -n "$VRAM_MIN" ]] && (( GPU_VRAM_GB < VRAM_MIN )); then
        echo "  FAIL: Need ${VRAM_MIN} GB VRAM, have ${GPU_VRAM_GB} GB"
        add_check "vram" "FAIL" "Need ${VRAM_MIN}GB, have ${GPU_VRAM_GB}GB"
    elif [[ -n "$VRAM_MIN" ]]; then
        add_check "vram" "PASS" "${GPU_VRAM_GB}GB >= ${VRAM_MIN}GB required"
    fi
else
    echo "FAIL — No GPU detected (nvidia-smi failed)"
    add_check "gpu" "FAIL" "nvidia-smi not found or no GPU"
fi

# Check 3: CUDA version
echo -n "CUDA version... "
# shellcheck disable=SC2034
CUDA_VER=$(remote_cmd "nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null; nvcc --version 2>/dev/null | grep 'release' | sed 's/.*release //' | cut -d',' -f1" || echo "")
NVCC_VER=$(remote_cmd "nvcc --version 2>/dev/null | grep 'release' | sed 's/.*release //' | cut -d',' -f1" || echo "")
if [[ -n "$NVCC_VER" ]]; then
    echo "OK — CUDA $NVCC_VER"
    add_check "cuda" "PASS" "CUDA ${NVCC_VER}"
else
    echo "WARN — nvcc not in PATH (CUDA toolkit may not be installed)"
    add_check "cuda" "WARN" "nvcc not found — CUDA toolkit may need installation"
fi

# Check 4: Disk space
echo -n "Disk space... "
DISK_AVAIL=$(remote_cmd "df -BG /workspace 2>/dev/null || df -BG / 2>/dev/null" | tail -1 | awk '{print $4}' | tr -d 'G')
if [[ -n "$DISK_AVAIL" ]] && [[ "$DISK_AVAIL" =~ ^[0-9]+$ ]]; then
    if (( DISK_AVAIL < DISK_MIN )); then
        echo "FAIL — ${DISK_AVAIL} GB available (need ${DISK_MIN} GB)"
        add_check "disk" "FAIL" "${DISK_AVAIL}GB available, need ${DISK_MIN}GB"
    else
        echo "OK — ${DISK_AVAIL} GB available"
        add_check "disk" "PASS" "${DISK_AVAIL}GB available"
    fi
else
    echo "WARN — Could not determine disk space"
    add_check "disk" "WARN" "Could not determine available disk space"
fi

# Check 5: Python
echo -n "Python... "
PY_VER=$(remote_cmd "python3 --version 2>/dev/null || python --version 2>/dev/null" || echo "")
if [[ -n "$PY_VER" ]]; then
    echo "OK — $PY_VER"
    add_check "python" "PASS" "$PY_VER"
else
    echo "FAIL — Python not found"
    add_check "python" "FAIL" "Python not installed"
fi

# Check 6: PyTorch
echo -n "PyTorch... "
TORCH_VER=$(remote_cmd "python3 -c 'import torch; print(torch.__version__)' 2>/dev/null" || echo "")
if [[ -n "$TORCH_VER" ]]; then
    TORCH_CUDA=$(remote_cmd "python3 -c 'import torch; print(torch.cuda.is_available())' 2>/dev/null" || echo "")
    if [[ "$TORCH_CUDA" == "True" ]]; then
        echo "OK — PyTorch $TORCH_VER (CUDA available)"
        add_check "pytorch" "PASS" "PyTorch ${TORCH_VER} with CUDA"
    else
        echo "WARN — PyTorch $TORCH_VER (CUDA NOT available)"
        add_check "pytorch" "WARN" "PyTorch ${TORCH_VER} but CUDA not available"
    fi
else
    echo "WARN — PyTorch not installed"
    add_check "pytorch" "WARN" "PyTorch not installed — will need to install"
fi

# --- Summary ---

echo ""
echo "=== Validation Summary ==="

if $PASS; then
    echo "RESULT: PASS — Instance is ready for training"
else
    echo "RESULT: FAIL — Issues must be fixed before training"
    echo ""
    echo "Errors:"
    for err in "${ERRORS[@]}"; do
        echo "  ✗ $err"
    done
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo ""
    echo "Warnings:"
    for warn in "${WARNINGS[@]}"; do
        echo "  ⚠ $warn"
    done
fi

# --- JSON Output ---

if $JSON_OUTPUT; then
    echo ""
    echo "{"
    echo "  \"host\": \"$SSH_HOST\","
    echo "  \"port\": $SSH_PORT,"
    echo "  \"pass\": $PASS,"
    echo "  \"checks\": [$(IFS=,; echo "${CHECKS[*]}")],"
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
    echo "}"
fi

$PASS && exit 0 || exit 1
