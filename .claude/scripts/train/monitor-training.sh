#!/usr/bin/env bash
# monitor-training.sh — Monitor training progress from log output
# Usage: monitor-training.sh --log PATH [--json]
#
# Parses training logs for progress, loss values, and anomalies.

set -euo pipefail

LOG_FILE=""
JSON_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log|-l) LOG_FILE="$2"; shift 2 ;;
    --json) JSON_MODE=true; shift ;;
    --help|-h)
      echo "Usage: monitor-training.sh --log PATH [--json]"
      echo ""
      echo "Monitor training progress from log file."
      echo ""
      echo "Arguments:"
      echo "  --log PATH    Path to training log file"
      echo "  --json        Output in JSON format"
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

# Progress percentage
PROGRESS="unknown"
if [[ "$TOTAL_STEPS" != "0" ]] && [[ "$STEPS" != "0" ]]; then
  PROGRESS=$(echo "$STEPS * 100 / $TOTAL_STEPS" | bc -l 2>/dev/null | xargs printf "%.0f" 2>/dev/null || echo "unknown")
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
    '{step: $step, total_steps: $total_steps, epoch: $epoch, progress: $progress,
      latest_loss: $latest_loss, first_loss: $first_loss, loss_samples: $loss_count,
      vram: {used_mb: $vram_used, total_mb: $vram_total},
      anomaly: $anomaly}'
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
  if [[ -n "$ANOMALY" ]]; then
    echo ""
    echo "Warning: $ANOMALY"
  fi
fi
