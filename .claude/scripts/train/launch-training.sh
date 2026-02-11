#!/usr/bin/env bash
# launch-training.sh — Start LoRA training with OOM recovery
# Usage: launch-training.sh --backend BACKEND --config PATH [--max-retries N] [--json]
#
# Launches training and automatically halves batch size on OOM errors.

set -euo pipefail

BACKEND=""
CONFIG_PATH=""
MAX_RETRIES=3
JSON_MODE=false
CURRENT_RETRY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backend|-b) BACKEND="$2"; shift 2 ;;
    --config|-c) CONFIG_PATH="$2"; shift 2 ;;
    --max-retries) MAX_RETRIES="$2"; shift 2 ;;
    --json) JSON_MODE=true; shift ;;
    --help|-h)
      echo "Usage: launch-training.sh --backend BACKEND --config PATH [OPTIONS]"
      echo ""
      echo "Start LoRA training with automatic OOM recovery."
      echo ""
      echo "Arguments:"
      echo "  --backend BACKEND   Training backend: kohya, simpletuner, ai-toolkit"
      echo "  --config PATH       Path to config file (from generate-config.sh)"
      echo "  --max-retries N     Max OOM recovery attempts (default: 3)"
      echo "  --json              Output in JSON format"
      exit 0
      ;;
    *) echo "Error: Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$BACKEND" ]] || [[ -z "$CONFIG_PATH" ]]; then
  echo "Error: --backend and --config are required." >&2
  exit 1
fi

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Error: Config file not found: $CONFIG_PATH" >&2
  exit 1
fi

# Build the training command based on backend
build_command() {
  case "$BACKEND" in
    kohya)
      echo "accelerate launch --num_cpu_threads_per_process 1 sdxl_train_network.py --config_file '$CONFIG_PATH'"
      ;;
    simpletuner)
      echo "bash train.sh"
      ;;
    ai-toolkit)
      echo "python run.py '$CONFIG_PATH'"
      ;;
    *)
      echo "Error: Unknown backend: $BACKEND" >&2
      exit 1
      ;;
  esac
}

# Check if an error is OOM
is_oom_error() {
  local output=$1
  echo "$output" | grep -qi "out of memory\|CUDA OOM\|OutOfMemoryError\|torch.cuda.OutOfMemoryError\|CUBLAS_STATUS_ALLOC_FAILED" && return 0
  return 1
}

# Attempt training
TRAIN_CMD=$(build_command)
LOG_FILE="${CONFIG_PATH%.toml}_training.log"
LOG_FILE="${LOG_FILE%.env}_training.log"
LOG_FILE="${LOG_FILE%.yaml}_training.log"

if ! $JSON_MODE; then
  echo "=== Starting Training ==="
  echo ""
  echo "Backend: $BACKEND"
  echo "Config: $CONFIG_PATH"
  echo "Log: $LOG_FILE"
  echo "OOM retries: up to $MAX_RETRIES"
  echo ""
fi

while (( CURRENT_RETRY <= MAX_RETRIES )); do
  if ! $JSON_MODE; then
    if (( CURRENT_RETRY > 0 )); then
      echo "Retry $CURRENT_RETRY/$MAX_RETRIES (batch size halved)..."
    else
      echo "Launching training..."
    fi
  fi

  # Run training, capture output
  set +e
  eval "$TRAIN_CMD" 2>&1 | tee "$LOG_FILE"
  EXIT_CODE=${PIPESTATUS[0]}
  set -e

  if (( EXIT_CODE == 0 )); then
    # Success
    if $JSON_MODE; then
      jq -n \
        --arg status "complete" \
        --arg backend "$BACKEND" \
        --arg config "$CONFIG_PATH" \
        --argjson retries "$CURRENT_RETRY" \
        --arg log "$LOG_FILE" \
        '{status: $status, backend: $backend, config: $config, oom_retries: $retries, log: $log}'
    else
      echo ""
      echo "Training completed successfully!"
      if (( CURRENT_RETRY > 0 )); then
        echo "(Recovered from $CURRENT_RETRY OOM error(s) by reducing batch size)"
      fi
    fi
    exit 0
  fi

  # Check if OOM
  if is_oom_error "$(cat "$LOG_FILE")"; then
    CURRENT_RETRY=$((CURRENT_RETRY + 1))

    if (( CURRENT_RETRY > MAX_RETRIES )); then
      if $JSON_MODE; then
        jq -n \
          --arg status "failed" \
          --arg reason "OOM after $MAX_RETRIES retries" \
          --arg config "$CONFIG_PATH" \
          '{status: $status, reason: $reason, config: $config,
            suggestion: "Reduce resolution, rank, or use a GPU with more VRAM"}'
      else
        echo ""
        echo "Training failed: Out of memory after $MAX_RETRIES retries."
        echo ""
        echo "Suggestions:"
        echo "  - Reduce training resolution"
        echo "  - Reduce network rank"
        echo "  - Use a GPU with more VRAM"
      fi
      exit 1
    fi

    if ! $JSON_MODE; then
      echo ""
      echo "Out of memory detected. Halving batch size and retrying..."
      echo "(This is automatic — no action needed from you)"
      echo ""
    fi

    # Halve batch size in config
    case "$BACKEND" in
      kohya)
        CURRENT_BS=$(grep "train_batch_size" "$CONFIG_PATH" | grep -o '[0-9]*')
        NEW_BS=$(( CURRENT_BS > 1 ? CURRENT_BS / 2 : 1 ))
        sed -i.bak "s/train_batch_size = .*/train_batch_size = $NEW_BS/" "$CONFIG_PATH"
        ;;
      simpletuner)
        CURRENT_BS=$(grep "TRAIN_BATCH_SIZE" "$CONFIG_PATH" | grep -o '[0-9]*')
        NEW_BS=$(( CURRENT_BS > 1 ? CURRENT_BS / 2 : 1 ))
        sed -i.bak "s/TRAIN_BATCH_SIZE=.*/TRAIN_BATCH_SIZE=$NEW_BS/" "$CONFIG_PATH"
        ;;
      ai-toolkit)
        CURRENT_BS=$(grep "batch_size:" "$CONFIG_PATH" | head -1 | grep -o '[0-9]*')
        NEW_BS=$(( CURRENT_BS > 1 ? CURRENT_BS / 2 : 1 ))
        sed -i.bak "s/batch_size: .*/batch_size: $NEW_BS/" "$CONFIG_PATH"
        ;;
    esac

    if (( NEW_BS == CURRENT_BS )); then
      # Already at batch size 1, can't reduce further
      if ! $JSON_MODE; then
        echo "Already at minimum batch size (1). Cannot reduce further."
        echo "Try reducing resolution or network rank."
      fi
      exit 1
    fi
  else
    # Non-OOM error
    if $JSON_MODE; then
      jq -n \
        --arg status "failed" \
        --arg reason "Training error (not OOM)" \
        --argjson exit_code "$EXIT_CODE" \
        --arg log "$LOG_FILE" \
        '{status: $status, reason: $reason, exit_code: $exit_code, log: $log}'
    else
      echo ""
      echo "Training failed with exit code $EXIT_CODE."
      echo "Check the log for details: $LOG_FILE"
    fi
    exit "$EXIT_CODE"
  fi
done
