#!/usr/bin/env bash
# validate-environment.sh — Gate 3: Validate training environment before GPU spend
# Usage: validate-environment.sh [--backend BACKEND] [--vram-need N] [--json]
#
# Checks: GPU, CUDA, PyTorch, backend installation, VRAM, disk space
# Idempotent — safe to re-run after SSH drops.

set -euo pipefail

BACKEND=""
VRAM_NEED=0
JSON_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backend|-b) BACKEND="$2"; shift 2 ;;
    --vram-need) VRAM_NEED="$2"; shift 2 ;;
    --json) JSON_MODE=true; shift ;;
    --help|-h)
      echo "Usage: validate-environment.sh [--backend BACKEND] [--vram-need N] [--json]"
      echo ""
      echo "Validate training environment (Gate 3)."
      echo ""
      echo "Arguments:"
      echo "  --backend BACKEND   Training backend to check: kohya, simpletuner, ai-toolkit"
      echo "  --vram-need N       Required VRAM in GB (from calculate-vram.sh)"
      echo "  --json              Output in JSON format"
      exit 0
      ;;
    *) echo "Error: Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# Results tracking
CHECKS=()
FAILURES=()
WARNINGS=()

add_check() {
  local name=$1 status=$2 detail=$3
  CHECKS+=("${name}|${status}|${detail}")
  if [[ "$status" == "FAIL" ]]; then
    FAILURES+=("$name: $detail")
  elif [[ "$status" == "WARN" ]]; then
    WARNINGS+=("$name: $detail")
  fi
}

# === GPU Detection ===
if command -v nvidia-smi >/dev/null 2>&1; then
  GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 | xargs)
  GPU_VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | xargs)
  GPU_VRAM_GB=$(echo "$GPU_VRAM / 1024" | bc -l 2>/dev/null | xargs printf "%.1f")
  # Collected for environment reporting
  # shellcheck disable=SC2034
  CUDA_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 | xargs)
  CUDA_RT=$(nvcc --version 2>/dev/null | grep "release" | sed 's/.*release //' | sed 's/,.*//' || echo "not found")
  add_check "GPU" "PASS" "$GPU_NAME (${GPU_VRAM_GB} GB)"
  add_check "CUDA Runtime" "$([ "$CUDA_RT" != "not found" ] && echo PASS || echo WARN)" "$CUDA_RT"
elif system_profiler SPDisplaysDataType 2>/dev/null | grep -q "Apple M"; then
  GPU_NAME="Apple Silicon (MPS)"
  GPU_VRAM_GB=$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.1f", $1/1073741824}')
  add_check "GPU" "PASS" "$GPU_NAME (${GPU_VRAM_GB} GB unified)"
  add_check "CUDA Runtime" "WARN" "Not applicable — Apple Silicon uses MPS backend"
else
  add_check "GPU" "FAIL" "No GPU detected. Training requires a GPU."
fi

# === VRAM Check ===
if [[ "$VRAM_NEED" != "0" ]] && [[ -n "${GPU_VRAM_GB:-}" ]]; then
  if (( $(echo "$GPU_VRAM_GB >= $VRAM_NEED" | bc -l) )); then
    add_check "VRAM" "PASS" "${GPU_VRAM_GB} GB available, ${VRAM_NEED} GB needed"
  else
    add_check "VRAM" "FAIL" "${GPU_VRAM_GB} GB available but ${VRAM_NEED} GB needed. Reduce batch size or rank."
  fi
fi

# === Python ===
if command -v python3 >/dev/null 2>&1; then
  PY_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
  add_check "Python" "PASS" "$PY_VERSION"
else
  add_check "Python" "FAIL" "Python 3 not found. Install Python 3.10+."
fi

# === PyTorch ===
if python3 -c "import torch; print(torch.__version__)" >/dev/null 2>&1; then
  TORCH_VERSION=$(python3 -c "import torch; print(torch.__version__)" 2>/dev/null)
  TORCH_CUDA=$(python3 -c "import torch; print(torch.cuda.is_available())" 2>/dev/null || echo "False")
  TORCH_MPS=$(python3 -c "import torch; print(torch.backends.mps.is_available())" 2>/dev/null || echo "False")

  if [[ "$TORCH_CUDA" == "True" ]]; then
    TORCH_CUDA_VER=$(python3 -c "import torch; print(torch.version.cuda)" 2>/dev/null || echo "unknown")
    add_check "PyTorch" "PASS" "${TORCH_VERSION} (CUDA ${TORCH_CUDA_VER})"
  elif [[ "$TORCH_MPS" == "True" ]]; then
    add_check "PyTorch" "PASS" "${TORCH_VERSION} (MPS backend)"
  else
    add_check "PyTorch" "WARN" "${TORCH_VERSION} (no GPU backend detected)"
  fi
else
  add_check "PyTorch" "FAIL" "PyTorch not installed. Install with: pip install torch torchvision"
fi

# === Training Backend ===
if [[ -n "$BACKEND" ]]; then
  case "$BACKEND" in
    kohya)
      if python3 -c "import library.train_util" 2>/dev/null || [[ -f "sdxl_train_network.py" ]]; then
        add_check "Backend (kohya)" "PASS" "sd-scripts found"
      else
        add_check "Backend (kohya)" "FAIL" "Kohya sd-scripts not found. Clone: git clone https://github.com/kohya-ss/sd-scripts"
      fi
      if command -v accelerate >/dev/null 2>&1; then
        add_check "Accelerate" "PASS" "$(accelerate --version 2>/dev/null || echo 'installed')"
      else
        add_check "Accelerate" "FAIL" "accelerate not found. Install: pip install accelerate && accelerate config"
      fi
      ;;
    simpletuner)
      if [[ -f "train.sh" ]] || [[ -f "train.py" ]]; then
        add_check "Backend (SimpleTuner)" "PASS" "SimpleTuner found"
      else
        add_check "Backend (SimpleTuner)" "FAIL" "SimpleTuner not found. Clone: git clone https://github.com/bghira/SimpleTuner"
      fi
      ;;
    ai-toolkit)
      if [[ -f "run.py" ]] || python3 -c "import toolkit" 2>/dev/null; then
        add_check "Backend (ai-toolkit)" "PASS" "ai-toolkit found"
      else
        add_check "Backend (ai-toolkit)" "FAIL" "ai-toolkit not found. Clone: git clone https://github.com/ostris/ai-toolkit"
      fi
      ;;
  esac
fi

# === Disk Space ===
AVAILABLE_GB=$(df -BG . 2>/dev/null | tail -1 | awk '{print $4}' | tr -d 'G' || df -g . 2>/dev/null | tail -1 | awk '{print $4}' || echo "0")
if (( AVAILABLE_GB >= 20 )); then
  add_check "Disk Space" "PASS" "${AVAILABLE_GB} GB available"
elif (( AVAILABLE_GB >= 10 )); then
  add_check "Disk Space" "WARN" "${AVAILABLE_GB} GB available (20+ GB recommended)"
else
  add_check "Disk Space" "FAIL" "${AVAILABLE_GB} GB available (need at least 10 GB for model + checkpoints)"
fi

# === Output ===
TOTAL_CHECKS=${#CHECKS[@]}
FAIL_COUNT=${#FAILURES[@]}
WARN_COUNT=${#WARNINGS[@]}
PASS_COUNT=$((TOTAL_CHECKS - FAIL_COUNT - WARN_COUNT))

if $JSON_MODE; then
  CHECKS_JSON=$(printf '%s\n' "${CHECKS[@]}" | while IFS='|' read -r name status detail; do
    jq -n --arg name "$name" --arg status "$status" --arg detail "$detail" \
      '{name: $name, status: $status, detail: $detail}'
  done | jq -s .)

  GATE_STATUS="PASS"
  if (( FAIL_COUNT > 0 )); then GATE_STATUS="FAIL"; fi

  jq -n \
    --arg gate_status "$GATE_STATUS" \
    --argjson total "$TOTAL_CHECKS" \
    --argjson pass "$PASS_COUNT" \
    --argjson fail "$FAIL_COUNT" \
    --argjson warn "$WARN_COUNT" \
    --argjson checks "$CHECKS_JSON" \
    '{gate: "environment", status: $gate_status, total: $total, pass: $pass, fail: $fail, warn: $warn, checks: $checks}'
else
  echo "=== Environment Validation (Gate 3) ==="
  echo ""

  for check in "${CHECKS[@]}"; do
    IFS='|' read -r name status detail <<< "$check"
    case "$status" in
      PASS) printf "  [PASS] %-20s %s\n" "$name" "$detail" ;;
      WARN) printf "  [WARN] %-20s %s\n" "$name" "$detail" ;;
      FAIL) printf "  [FAIL] %-20s %s\n" "$name" "$detail" ;;
    esac
  done

  echo ""
  echo "--- Result ---"
  echo "Passed: $PASS_COUNT / $TOTAL_CHECKS"

  if (( WARN_COUNT > 0 )); then
    echo "Warnings: $WARN_COUNT"
  fi

  if (( FAIL_COUNT > 0 )); then
    echo ""
    echo "GATE 3: FAIL — Cannot proceed to training."
    echo ""
    echo "Fix these issues:"
    for f in "${FAILURES[@]}"; do
      echo "  - $f"
    done
  else
    echo ""
    echo "GATE 3: PASS — Environment ready for training."
  fi
fi

exit "$FAIL_COUNT"
