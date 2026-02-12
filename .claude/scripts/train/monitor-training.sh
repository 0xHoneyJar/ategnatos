#!/usr/bin/env bash
# monitor-training.sh — Monitor training progress from log output
# Usage: monitor-training.sh --log PATH [--json] [--training-dir PATH]
#        [--state-file PATH] [--backend <kohya|simpletuner|ai-toolkit>]
#
# Parses training logs for progress, loss values, and anomalies.
# Optionally monitors disk space, validates checkpoints, and manages training state.

set -euo pipefail

LOG_FILE=""
JSON_MODE=false
TRAINING_DIR=""
STATE_FILE=""
BACKEND=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log|-l) LOG_FILE="$2"; shift 2 ;;
    --json) JSON_MODE=true; shift ;;
    --training-dir) TRAINING_DIR="$2"; shift 2 ;;
    --state-file) STATE_FILE="$2"; shift 2 ;;
    --backend) BACKEND="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: monitor-training.sh --log PATH [--json] [--training-dir PATH]"
      echo "       [--state-file PATH] [--backend <kohya|simpletuner|ai-toolkit>]"
      echo ""
      echo "Monitor training progress from log file."
      echo ""
      echo "Arguments:"
      echo "  --log PATH           Path to training log file"
      echo "  --json               Output in JSON format"
      echo "  --training-dir PATH  Directory containing training output (for disk/checkpoint checks)"
      echo "  --state-file PATH    Path to training-state.json (default: grimoire/training/training-state.json)"
      echo "  --backend TYPE       Backend type for resume commands (kohya|simpletuner|ai-toolkit)"
      exit 0
      ;;
    *) echo "Error: Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$LOG_FILE" ]]; then
  echo "Error: --log is required." >&2
  exit 1
fi

if [[ ! -f "$LOG_FILE" ]]; then
  echo "Error: Log file not found: $LOG_FILE" >&2
  exit 1
fi

# Parse log for key metrics
# Different backends output different formats, but all include loss values

# Get latest loss values
LOSSES=$(grep -oP 'loss[=: ]+\K[0-9]+\.[0-9]+' "$LOG_FILE" 2>/dev/null || \
         grep -oE 'loss: [0-9]+\.[0-9]+' "$LOG_FILE" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' || \
         echo "")

# Get step/epoch progress
STEPS=$(grep -oP 'step[s]?[=: ]+\K[0-9]+' "$LOG_FILE" 2>/dev/null | tail -1 || echo "0")
EPOCH=$(grep -oP 'epoch[s]?[=: ]+\K[0-9]+' "$LOG_FILE" 2>/dev/null | tail -1 || echo "0")
TOTAL_STEPS=$(grep -oP 'total[_ ]steps[=: ]+\K[0-9]+' "$LOG_FILE" 2>/dev/null | tail -1 || echo "0")

# VRAM usage (from nvidia-smi if available)
VRAM_USED=""
if command -v nvidia-smi >/dev/null 2>&1; then
  VRAM_USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | head -1 | xargs)
  VRAM_TOTAL=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | xargs)
fi

# Analyze loss trend
LOSS_ARRAY=()
while IFS= read -r line; do
  [[ -n "$line" ]] && LOSS_ARRAY+=("$line")
done <<< "$LOSSES"

LOSS_COUNT=${#LOSS_ARRAY[@]}
LATEST_LOSS="${LOSS_ARRAY[LOSS_COUNT-1]:-unknown}"
FIRST_LOSS="${LOSS_ARRAY[0]:-unknown}"

# Detect anomalies
ANOMALY=""
if (( LOSS_COUNT >= 10 )); then
  # Check last 5 losses for plateau (all within 5% of each other)
  RECENT_START=$((LOSS_COUNT - 5))
  PLATEAU=true
  for (( i=RECENT_START; i<LOSS_COUNT-1; i++ )); do
    DIFF=$(echo "${LOSS_ARRAY[i]} - ${LOSS_ARRAY[i+1]}" | bc -l 2>/dev/null || echo "0")
    ABS_DIFF=${DIFF#-}
    if (( $(echo "$ABS_DIFF > 0.01" | bc -l 2>/dev/null || echo "0") )); then
      PLATEAU=false
      break
    fi
  done
  if $PLATEAU; then
    ANOMALY="Loss has plateaued — training may have converged. Consider stopping early."
  fi

  # Check for loss increase (divergence)
  if [[ "$LATEST_LOSS" != "unknown" ]] && [[ "$FIRST_LOSS" != "unknown" ]]; then
    if (( $(echo "$LATEST_LOSS > $FIRST_LOSS * 1.5" | bc -l 2>/dev/null || echo "0") )); then
      ANOMALY="Loss is increasing — training may be diverging. Consider reducing learning rate."
    fi
  fi
fi

# --- Disk space monitoring ---
DISK_PCT=""
DISK_WARNING=""
if [[ -n "$TRAINING_DIR" ]] && [[ -d "$TRAINING_DIR" ]]; then
  DISK_PCT=$(df "$TRAINING_DIR" 2>/dev/null | awk 'NR==2 {gsub(/%/,""); print $5}')
  if [[ -n "$DISK_PCT" ]]; then
    if (( DISK_PCT >= 95 )); then
      DISK_WARNING="CRITICAL: Disk ${DISK_PCT}% full. Training may crash."
    elif (( DISK_PCT >= 90 )); then
      DISK_WARNING="WARNING: Disk ${DISK_PCT}% full. Consider cleaning up."
    fi
  fi
fi

# --- Checkpoint integrity validation ---
LATEST_CHECKPOINT=""
CKPT_SIZE="0"
CKPT_WARNING=""
CKPT_STATUS=""
if [[ -n "$TRAINING_DIR" ]] && [[ -d "$TRAINING_DIR" ]]; then
  LATEST_CHECKPOINT=$(find "$TRAINING_DIR" -name "*.safetensors" -o -name "*.ckpt" -o -name "*.pt" 2>/dev/null | sort | tail -1)
  if [[ -n "$LATEST_CHECKPOINT" ]]; then
    CKPT_SIZE=$(stat -f%z "$LATEST_CHECKPOINT" 2>/dev/null || stat -c%s "$LATEST_CHECKPOINT" 2>/dev/null || echo "0")
    if [[ "$CKPT_SIZE" -eq 0 ]]; then
      CKPT_WARNING="Latest checkpoint is empty (0 bytes) — may be corrupted"
    fi
    # Check if file is still being written (modified in last 30 seconds)
    CKPT_MTIME=$(stat -f%m "$LATEST_CHECKPOINT" 2>/dev/null || stat -c%Y "$LATEST_CHECKPOINT" 2>/dev/null || echo "0")
    NOW=$(date +%s)
    if (( NOW - CKPT_MTIME < 30 )); then
      CKPT_STATUS="writing"
    else
      CKPT_STATUS="complete"
    fi
  fi
fi

# --- Resume command ---
RESUME_CMD=""
if [[ -n "$LATEST_CHECKPOINT" ]]; then
  case "${BACKEND:-}" in
    kohya) RESUME_CMD="accelerate launch ... --network_weights $LATEST_CHECKPOINT" ;;
    simpletuner) RESUME_CMD="--resume_from_checkpoint $LATEST_CHECKPOINT" ;;
    ai-toolkit) RESUME_CMD="Restart with same config (auto-resumes from last checkpoint)" ;;
  esac
fi

# Progress percentage
PROGRESS="unknown"
if [[ "$TOTAL_STEPS" != "0" ]] && [[ "$STEPS" != "0" ]]; then
  PROGRESS=$(echo "$STEPS * 100 / $TOTAL_STEPS" | bc -l 2>/dev/null | xargs printf "%.0f" 2>/dev/null || echo "unknown")
fi

# --- Training state file management ---
if [[ -n "$STATE_FILE" ]]; then
  mkdir -p "$(dirname "$STATE_FILE")"
  # Read existing run_id and started_at if file exists, otherwise generate new ones
  EXISTING_RUN_ID=""
  EXISTING_STARTED_AT=""
  if [[ -f "$STATE_FILE" ]]; then
    EXISTING_RUN_ID=$(jq -r '.run_id // empty' "$STATE_FILE" 2>/dev/null || true)
    EXISTING_STARTED_AT=$(jq -r '.started_at // empty' "$STATE_FILE" 2>/dev/null || true)
  fi
  STATE_RUN_ID="${EXISTING_RUN_ID:-train-$(date +%Y%m%d-%H%M%S)}"
  STATE_STARTED_AT="${EXISTING_STARTED_AT:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
  jq -n \
    --arg run_id "$STATE_RUN_ID" \
    --arg backend "${BACKEND:-unknown}" \
    --arg status "running" \
    --arg started_at "$STATE_STARTED_AT" \
    --arg last_checkpoint "${LATEST_CHECKPOINT:-}" \
    --arg last_checkpoint_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson total_steps "${TOTAL_STEPS:-0}" \
    --argjson completed_steps "${STEPS:-0}" \
    '{run_id: $run_id, backend: $backend, status: $status, started_at: $started_at,
      last_checkpoint: $last_checkpoint, last_checkpoint_at: $last_checkpoint_at,
      total_steps: ($total_steps | tonumber), completed_steps: ($completed_steps | tonumber)}' \
    > "$STATE_FILE"
fi

if $JSON_MODE; then
  jq -n \
    --arg step "$STEPS" \
    --arg total_steps "$TOTAL_STEPS" \
    --arg epoch "$EPOCH" \
    --arg progress "${PROGRESS}%" \
    --arg latest_loss "$LATEST_LOSS" \
    --arg first_loss "$FIRST_LOSS" \
    --argjson loss_count "$LOSS_COUNT" \
    --arg vram_used "${VRAM_USED:-unknown}" \
    --arg vram_total "${VRAM_TOTAL:-unknown}" \
    --arg anomaly "${ANOMALY:-none}" \
    --arg disk_pct "${DISK_PCT:-unknown}" \
    --arg disk_warning "${DISK_WARNING:-none}" \
    --arg latest_checkpoint "${LATEST_CHECKPOINT:-none}" \
    --arg ckpt_size "${CKPT_SIZE:-0}" \
    --arg ckpt_status "${CKPT_STATUS:-none}" \
    --arg ckpt_warning "${CKPT_WARNING:-none}" \
    --arg resume_cmd "${RESUME_CMD:-none}" \
    '{step: $step, total_steps: $total_steps, epoch: $epoch, progress: $progress,
      latest_loss: $latest_loss, first_loss: $first_loss, loss_samples: $loss_count,
      vram: {used_mb: $vram_used, total_mb: $vram_total},
      disk: {usage_pct: $disk_pct, warning: $disk_warning},
      checkpoint: {path: $latest_checkpoint, size_bytes: $ckpt_size, status: $ckpt_status, warning: $ckpt_warning},
      anomaly: $anomaly,
      resume_command: $resume_cmd}'
else
  echo "=== Training Progress ==="
  echo ""
  if [[ "$PROGRESS" != "unknown" ]]; then
    echo "Progress: ${PROGRESS}% (step $STEPS / $TOTAL_STEPS)"
  else
    echo "Step: $STEPS  Epoch: $EPOCH"
  fi
  echo ""
  if [[ "$LATEST_LOSS" != "unknown" ]]; then
    echo "Loss: $LATEST_LOSS (started at: $FIRST_LOSS, samples: $LOSS_COUNT)"
  fi
  if [[ -n "$VRAM_USED" ]]; then
    echo "VRAM: ${VRAM_USED} MB / ${VRAM_TOTAL} MB"
  fi
  if [[ -n "$DISK_PCT" ]]; then
    echo "Disk: ${DISK_PCT}% used"
  fi
  if [[ -n "$LATEST_CHECKPOINT" ]]; then
    echo ""
    echo "--- Checkpoint ---"
    echo "Latest: $LATEST_CHECKPOINT"
    echo "Size: $CKPT_SIZE bytes  Status: ${CKPT_STATUS:-unknown}"
  fi
  if [[ -n "$CKPT_WARNING" ]]; then
    echo "Checkpoint warning: $CKPT_WARNING"
  fi
  if [[ -n "$DISK_WARNING" ]]; then
    echo ""
    echo "$DISK_WARNING"
  fi
  if [[ -n "$ANOMALY" ]]; then
    echo ""
    echo "Warning: $ANOMALY"
  fi
  if [[ -n "$RESUME_CMD" ]]; then
    echo ""
    echo "Resume: $RESUME_CMD"
  fi
fi
