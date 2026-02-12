#!/usr/bin/env bash
# dry-run.sh — Gate 4: Run 2-5 training steps to verify the pipeline works
# Usage: dry-run.sh --config <path> --backend <kohya|simpletuner|ai-toolkit> [--steps 5] [--json]
#
# Runs a short training (2-5 steps) to catch errors BEFORE committing to a full run.
# This saves you from burning GPU hours on a broken config.
#
# Exit codes:
#   0 — Dry run passed, pipeline is ready
#   1 — Dry run failed (with diagnosis)
#   2 — Unexpected error (script bug or missing dependencies)

set -euo pipefail

# ──────────────────────────────────────────────
# Defaults
# ──────────────────────────────────────────────

CONFIG_PATH=""
BACKEND=""
DRY_RUN_STEPS=5
JSON_MODE=false
# shellcheck disable=SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ──────────────────────────────────────────────
# Usage
# ──────────────────────────────────────────────

usage() {
  cat <<EOF
Usage: dry-run.sh --config <path> --backend <kohya|simpletuner|ai-toolkit> [OPTIONS]

Gate 4: Run a few training steps to verify the full pipeline works
before committing to a real training run.

Required:
  --config PATH       Path to training config file (from generate-config.sh)
  --backend BACKEND   Training backend: kohya, simpletuner, ai-toolkit

Optional:
  --steps N           Number of dry-run steps (2-5, default: 5)
  --json              Output in JSON format (for automation)
  --help              Show this help

What this checks:
  - Model loads without errors
  - Dataset is readable and compatible
  - LoRA network initializes correctly
  - Forward/backward pass completes
  - No VRAM overflow at configured settings

Exit codes:
  0  Dry run passed — safe to start real training
  1  Dry run failed — see diagnosis and suggested fix
  2  Unexpected error — something went wrong in the script itself
EOF
}

# ──────────────────────────────────────────────
# Argument parsing
# ──────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config|-c)  CONFIG_PATH="$2"; shift 2 ;;
    --backend|-b) BACKEND="$2"; shift 2 ;;
    --steps|-s)   DRY_RUN_STEPS="$2"; shift 2 ;;
    --json)       JSON_MODE=true; shift ;;
    --help|-h)    usage; exit 0 ;;
    *)
      echo "Error: Unknown argument: $1" >&2
      echo "Run with --help for usage." >&2
      exit 2
      ;;
  esac
done

# ──────────────────────────────────────────────
# Validate required arguments
# ──────────────────────────────────────────────

if [[ -z "$CONFIG_PATH" ]]; then
  echo "Error: --config is required." >&2
  exit 2
fi

if [[ -z "$BACKEND" ]]; then
  echo "Error: --backend is required." >&2
  exit 2
fi

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Error: Config file not found: $CONFIG_PATH" >&2
  exit 1
fi

# Validate backend name
case "$BACKEND" in
  kohya|simpletuner|ai-toolkit) ;;
  *)
    echo "Error: Unknown backend: $BACKEND (use kohya, simpletuner, or ai-toolkit)" >&2
    exit 2
    ;;
esac

# Clamp steps to 2-5 range
if (( DRY_RUN_STEPS < 2 )); then
  DRY_RUN_STEPS=2
elif (( DRY_RUN_STEPS > 5 )); then
  DRY_RUN_STEPS=5
fi

# ──────────────────────────────────────────────
# Helper: read config values per backend
# ──────────────────────────────────────────────

# Extract a value from the config file. Handles TOML, env, and YAML formats.
read_config_value() {
  local key="$1"
  local fallback="${2:-}"

  case "$BACKEND" in
    kohya)
      # TOML format: key = value  or  key = "value"
      local val
      val=$(grep -E "^${key}\s*=" "$CONFIG_PATH" 2>/dev/null | head -1 | sed 's/.*=\s*//' | tr -d '"' | tr -d "'" | xargs) || true
      echo "${val:-$fallback}"
      ;;
    simpletuner)
      # env format: export KEY=value  or  KEY=value
      local val
      val=$(grep -E "^(export\s+)?${key}=" "$CONFIG_PATH" 2>/dev/null | head -1 | sed 's/.*=//' | tr -d '"' | tr -d "'" | xargs) || true
      echo "${val:-$fallback}"
      ;;
    ai-toolkit)
      # YAML format: key: value (simplified — searches for first match)
      local val
      val=$(grep -E "^\s*${key}:" "$CONFIG_PATH" 2>/dev/null | head -1 | sed 's/.*:\s*//' | tr -d '"' | tr -d "'" | xargs) || true
      echo "${val:-$fallback}"
      ;;
  esac
}

# ──────────────────────────────────────────────
# Read config to understand the training setup
# ──────────────────────────────────────────────

# shellcheck disable=SC2034
case "$BACKEND" in
  kohya)
    MODEL_PATH=$(read_config_value "pretrained_model_name_or_path" "")
    DATASET_PATH=$(read_config_value "train_data_dir" "")
    BATCH_SIZE=$(read_config_value "train_batch_size" "1")
    RESOLUTION=$(read_config_value "resolution" "1024")
    NETWORK_DIM=$(read_config_value "network_dim" "32")
    NETWORK_ALPHA=$(read_config_value "network_alpha" "16")
    ;;
  simpletuner)
    MODEL_PATH=$(read_config_value "MODEL_NAME" "")
    DATASET_PATH=$(read_config_value "INSTANCE_DIR" "")
    BATCH_SIZE=$(read_config_value "TRAIN_BATCH_SIZE" "1")
    RESOLUTION=$(read_config_value "RESOLUTION" "1024")
    NETWORK_DIM=$(read_config_value "LORA_RANK" "32")
    NETWORK_ALPHA=$(read_config_value "LORA_ALPHA" "16")
    ;;
  ai-toolkit)
    MODEL_PATH=$(read_config_value "name_or_path" "")
    DATASET_PATH=$(read_config_value "folder_path" "")
    BATCH_SIZE=$(read_config_value "batch_size" "1")
    RESOLUTION=$(read_config_value "resolution" "1024")
    NETWORK_DIM=$(read_config_value "linear" "32")
    NETWORK_ALPHA=$(read_config_value "linear_alpha" "16")
    ;;
esac

# Quick sanity checks on parsed values
PREFLIGHT_ERRORS=()

if [[ -z "$MODEL_PATH" ]]; then
  PREFLIGHT_ERRORS+=("Could not find model path in config. Check your config file format.")
fi

if [[ -n "$MODEL_PATH" ]] && [[ ! -f "$MODEL_PATH" ]] && [[ ! -d "$MODEL_PATH" ]]; then
  PREFLIGHT_ERRORS+=("Model not found at: $MODEL_PATH")
fi

if [[ -z "$DATASET_PATH" ]]; then
  PREFLIGHT_ERRORS+=("Could not find dataset path in config. Check your config file format.")
fi

if [[ -n "$DATASET_PATH" ]] && [[ ! -d "$DATASET_PATH" ]]; then
  PREFLIGHT_ERRORS+=("Dataset directory not found at: $DATASET_PATH")
fi

# If preflight catches issues, bail out early with clear guidance
if (( ${#PREFLIGHT_ERRORS[@]} > 0 )); then
  if $JSON_MODE; then
    ERRORS_JSON=$(printf '%s\n' "${PREFLIGHT_ERRORS[@]}" | jq -R . | jq -s .)
    jq -n \
      --arg gate "dry_run" \
      --arg status "FAIL" \
      --arg category "config_error" \
      --argjson errors "$ERRORS_JSON" \
      '{gate: $gate, status: $status, category: $category, errors: $errors,
        suggestion: "Check your config file — the paths to your model and dataset need to exist on this machine."}'
  else
    echo "=== Dry Run (Gate 4) ==="
    echo ""
    echo "GATE 4: FAIL — Config has issues that would prevent training."
    echo ""
    echo "Problems found:"
    for err in "${PREFLIGHT_ERRORS[@]}"; do
      echo "  - $err"
    done
    echo ""
    echo "Fix: Check your config file. The paths to your model and dataset"
    echo "     need to exist on this machine."
  fi
  exit 1
fi

# ──────────────────────────────────────────────
# Create a temporary modified config for dry run
# ──────────────────────────────────────────────

# We copy the config and override the step count so we only run a few steps.
# The original config is never modified.

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

TEMP_CONFIG="${TEMP_DIR}/dry_run_config"
LOG_FILE="${TEMP_DIR}/dry_run.log"

case "$BACKEND" in
  kohya)
    TEMP_CONFIG="${TEMP_CONFIG}.toml"
    cp "$CONFIG_PATH" "$TEMP_CONFIG"

    # Remove any existing epoch/step limits and add our step limit
    # Also disable saving checkpoints during dry run (unnecessary)
    if grep -q "max_train_epochs" "$TEMP_CONFIG" 2>/dev/null; then
      sed -i.bak "s/max_train_epochs.*/max_train_steps = ${DRY_RUN_STEPS}/" "$TEMP_CONFIG"
    elif grep -q "max_train_steps" "$TEMP_CONFIG" 2>/dev/null; then
      sed -i.bak "s/max_train_steps.*/max_train_steps = ${DRY_RUN_STEPS}/" "$TEMP_CONFIG"
    else
      # Append to [training] section (or end of file if no section found)
      echo "max_train_steps = ${DRY_RUN_STEPS}" >> "$TEMP_CONFIG"
    fi

    # Disable checkpoint saving during dry run
    sed -i.bak "s/save_every_n_epochs.*/save_every_n_epochs = 999/" "$TEMP_CONFIG" 2>/dev/null || true
    sed -i.bak "s/save_every_n_steps.*/save_every_n_steps = 999/" "$TEMP_CONFIG" 2>/dev/null || true

    # Clean up macOS sed backup files
    rm -f "${TEMP_CONFIG}.bak"
    ;;

  simpletuner)
    TEMP_CONFIG="${TEMP_CONFIG}.env"
    cp "$CONFIG_PATH" "$TEMP_CONFIG"

    # Override step count
    if grep -q "MAX_NUM_STEPS" "$TEMP_CONFIG" 2>/dev/null; then
      sed -i.bak "s/MAX_NUM_STEPS=.*/MAX_NUM_STEPS=${DRY_RUN_STEPS}/" "$TEMP_CONFIG"
    else
      echo "export MAX_NUM_STEPS=${DRY_RUN_STEPS}" >> "$TEMP_CONFIG"
    fi

    # Disable checkpointing during dry run
    sed -i.bak "s/CHECKPOINTING_STEPS=.*/CHECKPOINTING_STEPS=999/" "$TEMP_CONFIG" 2>/dev/null || true

    rm -f "${TEMP_CONFIG}.bak"
    ;;

  ai-toolkit)
    TEMP_CONFIG="${TEMP_CONFIG}.yaml"
    cp "$CONFIG_PATH" "$TEMP_CONFIG"

    # Override step count in YAML
    # Match lines like "steps: 1500" and replace with dry run steps
    if grep -q "steps:" "$TEMP_CONFIG" 2>/dev/null; then
      sed -i.bak "s/\(steps:\s*\).*/\1${DRY_RUN_STEPS}/" "$TEMP_CONFIG"
    else
      echo "    steps: ${DRY_RUN_STEPS}" >> "$TEMP_CONFIG"
    fi

    # Disable save during dry run
    sed -i.bak "s/\(save_every:\s*\).*/\1999/" "$TEMP_CONFIG" 2>/dev/null || true

    rm -f "${TEMP_CONFIG}.bak"
    ;;
esac

# ──────────────────────────────────────────────
# Build the training command
# ──────────────────────────────────────────────

build_dry_run_command() {
  case "$BACKEND" in
    kohya)
      # Kohya uses accelerate + train_network.py (or sdxl_train_network.py)
      # Detect which script is available
      if [[ -f "sdxl_train_network.py" ]]; then
        echo "accelerate launch --num_cpu_threads_per_process 1 sdxl_train_network.py --config_file '${TEMP_CONFIG}'"
      elif [[ -f "train_network.py" ]]; then
        echo "accelerate launch --num_cpu_threads_per_process 1 train_network.py --config_file '${TEMP_CONFIG}'"
      else
        echo "accelerate launch --num_cpu_threads_per_process 1 sdxl_train_network.py --config_file '${TEMP_CONFIG}'"
      fi
      ;;
    simpletuner)
      # SimpleTuner uses its own train.sh which reads from env config
      # We source the modified config then run
      echo "bash -c 'source \"${TEMP_CONFIG}\" && bash train.sh'"
      ;;
    ai-toolkit)
      # ai-toolkit uses run.py with a YAML config
      echo "python run.py '${TEMP_CONFIG}'"
      ;;
  esac
}

TRAIN_CMD=$(build_dry_run_command)

# ──────────────────────────────────────────────
# Run the dry run
# ──────────────────────────────────────────────

if ! $JSON_MODE; then
  echo "=== Dry Run (Gate 4) ==="
  echo ""
  echo "Running $DRY_RUN_STEPS training steps to verify the pipeline..."
  echo ""
  echo "  Backend:    $BACKEND"
  echo "  Config:     $CONFIG_PATH"
  echo "  Model:      $MODEL_PATH"
  echo "  Dataset:    $DATASET_PATH"
  echo "  Batch size: $BATCH_SIZE"
  echo "  Rank:       $NETWORK_DIM"
  echo "  Steps:      $DRY_RUN_STEPS (dry run only)"
  echo ""
fi

# Record start time
START_TIME=$(date +%s)

# Run the training command, capturing all output
# We disable set -e temporarily so we can handle the exit code ourselves
set +e
eval "$TRAIN_CMD" > "$LOG_FILE" 2>&1
TRAIN_EXIT_CODE=$?
set -e

# Record end time
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

# ──────────────────────────────────────────────
# Try to extract VRAM peak from log output
# ──────────────────────────────────────────────

extract_vram_peak() {
  local log="$1"
  local vram_peak=""

  # Different backends/PyTorch versions report VRAM differently
  # Try several common patterns

  # Pattern: "Max memory allocated: X.X GB"
  vram_peak=$(grep -oi "max memory allocated[: ]*[0-9.]*\s*[GM]B" "$log" 2>/dev/null | tail -1 | grep -o '[0-9.]*\s*[GM]B' || true)

  # Pattern: "Peak VRAM: X.X GB" or "VRAM peak: X.X GB"
  if [[ -z "$vram_peak" ]]; then
    vram_peak=$(grep -oi "peak.*vram[: ]*[0-9.]*\s*[GM]B\|vram.*peak[: ]*[0-9.]*\s*[GM]B" "$log" 2>/dev/null | tail -1 | grep -o '[0-9.]*\s*[GM]B' || true)
  fi

  # Pattern: "GPU memory: X.X GB" (from nvidia-smi style output)
  if [[ -z "$vram_peak" ]]; then
    vram_peak=$(grep -oi "gpu memory[: ]*[0-9.]*\s*[GM]B" "$log" 2>/dev/null | tail -1 | grep -o '[0-9.]*\s*[GM]B' || true)
  fi

  # Pattern: torch CUDA memory summary "Allocated: X.X GB"
  if [[ -z "$vram_peak" ]]; then
    vram_peak=$(grep -oi "allocated[: ]*[0-9.]*\s*[GM]iB" "$log" 2>/dev/null | tail -1 | grep -o '[0-9.]*\s*[GM]iB' || true)
  fi

  echo "$vram_peak"
}

VRAM_PEAK=$(extract_vram_peak "$LOG_FILE")

# ──────────────────────────────────────────────
# Categorize errors if training failed
# ──────────────────────────────────────────────

# Returns one of: oom, cuda, missing_file, config_error, unknown
categorize_error() {
  local log="$1"
  local log_content
  log_content=$(cat "$log")

  # OOM errors — out of memory on GPU
  if echo "$log_content" | grep -qi \
    "out of memory\|OutOfMemoryError\|CUDA OOM\|torch.cuda.OutOfMemoryError\|CUBLAS_STATUS_ALLOC_FAILED\|CUDA error: out of memory\|cuDNN error: CUDNN_STATUS_ALLOC_FAILED"; then
    echo "oom"
    return
  fi

  # CUDA errors — driver issues, version mismatches, device problems
  if echo "$log_content" | grep -qi \
    "CUDA error\|CUDA_ERROR\|CUDA driver\|CUDA not available\|NCCL error\|cuDNN error\|no CUDA GPUs are available\|CUDA_HOME\|nvcc\|cuda toolkit\|RuntimeError: CUDA"; then
    echo "cuda"
    return
  fi

  # Missing file errors — model, dataset, or dependency not found
  if echo "$log_content" | grep -qi \
    "FileNotFoundError\|No such file or directory\|not found\|does not exist\|cannot find\|ModuleNotFoundError\|ImportError\|No module named"; then
    echo "missing_file"
    return
  fi

  # Config errors — bad parameters, type mismatches, validation failures
  if echo "$log_content" | grep -qi \
    "ValueError\|KeyError\|TypeError\|config.*error\|invalid.*config\|unknown.*option\|unexpected.*key\|AssertionError\|toml.*error\|yaml.*error\|json.*error\|invalid.*argument\|invalid.*value"; then
    echo "config_error"
    return
  fi

  echo "unknown"
}

# Provide a human-readable fix suggestion for each error category
suggest_fix() {
  local category="$1"
  local log="$2"

  case "$category" in
    oom)
      cat <<'FIXEOF'
Your GPU ran out of memory during the dry run.

How to fix:
  1. Reduce batch size to 1 (if it's not already)
  2. Lower the network rank (e.g., from 64 to 32 or 16)
  3. Reduce training resolution (e.g., from 1024 to 768)
  4. Enable xformers or use --sdpa if your backend supports it
  5. If none of that works, you need a GPU with more VRAM
FIXEOF
      ;;
    cuda)
      cat <<'FIXEOF'
There's a CUDA or GPU driver issue.

How to fix:
  1. Check that your GPU drivers are up to date: nvidia-smi
  2. Make sure PyTorch was installed for your CUDA version:
     python -c "import torch; print(torch.version.cuda)"
  3. If CUDA versions don't match, reinstall PyTorch for your CUDA:
     pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121
  4. On Apple Silicon, make sure you're using the MPS backend (not CUDA)
  5. Run validate-environment.sh to diagnose further
FIXEOF
      ;;
    missing_file)
      # Try to extract the specific missing file/module from the log
      local missing
      missing=$(grep -oi "FileNotFoundError.*\|No such file.*\|ModuleNotFoundError.*\|No module named.*" "$log" 2>/dev/null | head -3)
      cat <<FIXEOF
A required file or Python package is missing.

What's missing:
${missing:-  (could not extract specific file — check the log below)}

How to fix:
  1. If it's a model file: check the model path in your config
  2. If it's a dataset: check the dataset path in your config
  3. If it's a Python module: install it with pip install <module>
  4. If it's a backend script: make sure you're running from the backend's directory
     (e.g., cd into kohya sd-scripts, SimpleTuner, or ai-toolkit before running)
FIXEOF
      ;;
    config_error)
      local config_err
      config_err=$(grep -oi "ValueError.*\|KeyError.*\|TypeError.*\|invalid.*\|unexpected.*\|AssertionError.*" "$log" 2>/dev/null | head -3)
      cat <<FIXEOF
There's a problem with your training configuration.

Details:
${config_err:-  (could not extract specific error — check the log below)}

How to fix:
  1. Double-check all paths in your config file
  2. Make sure numeric values (rank, alpha, batch size) are valid numbers
  3. Check that your config format matches what the backend expects:
     - kohya: TOML format
     - simpletuner: env/shell format
     - ai-toolkit: YAML format
  4. Try regenerating the config with generate-config.sh
FIXEOF
      ;;
    unknown)
      cat <<'FIXEOF'
The dry run failed, but the error doesn't match any known pattern.

How to debug:
  1. Read the full log output below for clues
  2. Search for the error message online — someone has probably hit it before
  3. Try running the training command manually to see the full traceback
  4. Make sure all dependencies are installed: pip install -r requirements.txt
FIXEOF
      ;;
  esac
}

# ──────────────────────────────────────────────
# Report results
# ──────────────────────────────────────────────

if (( TRAIN_EXIT_CODE == 0 )); then
  # ── SUCCESS ──
  if $JSON_MODE; then
    jq -n \
      --arg gate "dry_run" \
      --arg status "PASS" \
      --arg backend "$BACKEND" \
      --arg config "$CONFIG_PATH" \
      --argjson steps "$DRY_RUN_STEPS" \
      --argjson elapsed_seconds "$ELAPSED" \
      --arg vram_peak "${VRAM_PEAK:-not detected}" \
      --arg model "$MODEL_PATH" \
      --arg dataset "$DATASET_PATH" \
      --argjson batch_size "$BATCH_SIZE" \
      --arg rank "$NETWORK_DIM" \
      '{gate: $gate, status: $status, backend: $backend, config: $config,
        steps_completed: $steps, elapsed_seconds: $elapsed_seconds,
        vram_peak: $vram_peak, model: $model, dataset: $dataset,
        batch_size: $batch_size, rank: $rank}'
  else
    echo ""
    echo "--- Result ---"
    echo ""
    echo "GATE 4: PASS — Dry run completed successfully."
    echo ""
    echo "  Steps completed: $DRY_RUN_STEPS"
    echo "  Time taken:      ${ELAPSED}s"
    if [[ -n "$VRAM_PEAK" ]]; then
      echo "  VRAM peak:       $VRAM_PEAK"
    else
      echo "  VRAM peak:       (not detected in output)"
    fi
    echo ""
    echo "The model loads, the dataset is readable, and training runs without errors."
    echo "You're clear to start the full training run."
  fi
  exit 0

else
  # ── FAILURE ──
  ERROR_CATEGORY=$(categorize_error "$LOG_FILE")
  FIX_SUGGESTION=$(suggest_fix "$ERROR_CATEGORY" "$LOG_FILE")

  # Extract the last 30 lines of log for context (avoid dumping thousands of lines)
  LOG_TAIL=$(tail -30 "$LOG_FILE" 2>/dev/null || echo "(could not read log)")

  if $JSON_MODE; then
    # Build JSON with error details
    jq -n \
      --arg gate "dry_run" \
      --arg status "FAIL" \
      --arg backend "$BACKEND" \
      --arg config "$CONFIG_PATH" \
      --argjson steps "$DRY_RUN_STEPS" \
      --argjson elapsed_seconds "$ELAPSED" \
      --argjson exit_code "$TRAIN_EXIT_CODE" \
      --arg category "$ERROR_CATEGORY" \
      --arg suggestion "$FIX_SUGGESTION" \
      --arg vram_peak "${VRAM_PEAK:-not detected}" \
      --arg log_tail "$LOG_TAIL" \
      --arg model "$MODEL_PATH" \
      --arg dataset "$DATASET_PATH" \
      '{gate: $gate, status: $status, backend: $backend, config: $config,
        steps_attempted: $steps, elapsed_seconds: $elapsed_seconds,
        exit_code: $exit_code, error_category: $category,
        suggestion: $suggestion, vram_peak: $vram_peak,
        log_tail: $log_tail, model: $model, dataset: $dataset}'
  else
    echo ""
    echo "--- Result ---"
    echo ""
    echo "GATE 4: FAIL — Dry run did not complete."
    echo ""
    echo "  Error type: $ERROR_CATEGORY"
    echo "  Exit code:  $TRAIN_EXIT_CODE"
    echo "  Time:       ${ELAPSED}s"
    if [[ -n "$VRAM_PEAK" ]]; then
      echo "  VRAM peak:  $VRAM_PEAK"
    fi
    echo ""
    echo "--- What went wrong ---"
    echo ""
    echo "$FIX_SUGGESTION"
    echo ""
    echo "--- Last 30 lines of training output ---"
    echo ""
    echo "$LOG_TAIL"
    echo ""
    echo "Fix the issue above, then run this dry run again."
    echo "Do NOT start real training until the dry run passes."
  fi
  exit 1
fi
