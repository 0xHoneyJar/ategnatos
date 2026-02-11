#!/usr/bin/env bash
# detect-gpu.sh — Detect local GPU, CUDA version, driver, VRAM
# Exit codes: 0 = GPU found, 1 = no GPU detected, 2 = unexpected error
# Usage: detect-gpu.sh [--json]

set -euo pipefail

JSON_MODE=false
[[ "${1:-}" == "--json" ]] && JSON_MODE=true

detect_nvidia() {
    if ! command -v nvidia-smi &>/dev/null; then
        return 1
    fi

    local gpu_name driver_version vram_total vram_free
    gpu_name=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader,nounits 2>/dev/null | head -1) || return 1
    driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1) || driver_version="unknown"
    vram_total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1) || vram_total="unknown"
    vram_free=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits 2>/dev/null | head -1) || vram_free="unknown"

    # Get CUDA version from nvidia-smi header
    local cuda_ver
    cuda_ver=$(nvidia-smi 2>/dev/null | grep "CUDA Version" | sed 's/.*CUDA Version: \([0-9.]*\).*/\1/') || cuda_ver="unknown"

    if $JSON_MODE; then
        cat <<ENDJSON
{
  "platform": "nvidia",
  "gpu_name": "${gpu_name}",
  "cuda_version": "${cuda_ver}",
  "driver_version": "${driver_version}",
  "vram_total_mb": ${vram_total:-0},
  "vram_free_mb": ${vram_free:-0},
  "vram_total_gb": $(echo "scale=1; ${vram_total:-0} / 1024" | bc 2>/dev/null || echo "0")
}
ENDJSON
    else
        local vram_gb
        vram_gb=$(echo "scale=0; ${vram_total:-0} / 1024" | bc 2>/dev/null || echo "?")
        echo "GPU: ${gpu_name}"
        echo "CUDA: ${cuda_ver}"
        echo "Driver: ${driver_version}"
        echo "VRAM: ${vram_gb}GB total (${vram_total}MB), ${vram_free}MB free"
    fi
    return 0
}

detect_apple_silicon() {
    if [[ "$(uname)" != "Darwin" ]]; then
        return 1
    fi

    local chip_info
    chip_info=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Chip" | head -1) || return 1

    # Check if it's Apple Silicon (M-series)
    if ! echo "$chip_info" | grep -qi "Apple M"; then
        return 1
    fi

    local chip_name memory_gb gpu_cores
    chip_name=$(echo "$chip_info" | sed 's/.*: //')
    memory_gb=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Memory" | head -1 | sed 's/.*: //' | sed 's/ GB//')
    gpu_cores=$(system_profiler SPDisplaysDataType 2>/dev/null | grep "Total Number of Cores" | head -1 | sed 's/.*: //') || gpu_cores="unknown"

    if $JSON_MODE; then
        cat <<ENDJSON
{
  "platform": "apple_silicon",
  "gpu_name": "${chip_name}",
  "cuda_version": "n/a (MPS)",
  "driver_version": "n/a",
  "unified_memory_gb": ${memory_gb:-0},
  "gpu_cores": ${gpu_cores:-0},
  "compute_backend": "MPS"
}
ENDJSON
    else
        echo "GPU: ${chip_name} (Apple Silicon)"
        echo "Compute: MPS (Metal Performance Shaders)"
        echo "Unified Memory: ${memory_gb}GB (shared between CPU and GPU)"
        echo "GPU Cores: ${gpu_cores}"
        echo ""
        echo "Note: Apple Silicon uses MPS instead of CUDA. Most training tools"
        echo "support MPS, but some features may be slower than NVIDIA CUDA."
    fi
    return 0
}

# Try NVIDIA first, then Apple Silicon
if detect_nvidia; then
    exit 0
elif detect_apple_silicon; then
    exit 0
else
    if $JSON_MODE; then
        echo '{"platform": "none", "error": "No GPU detected"}'
    else
        echo "No GPU detected on this machine."
        echo ""
        echo "This is fine — you can still use cloud GPU services (Vast.ai, RunPod, Lambda)"
        echo "for training and generation. Run /studio to set up a cloud provider."
    fi
    exit 1
fi
