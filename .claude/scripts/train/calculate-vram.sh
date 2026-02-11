#!/usr/bin/env bash
# calculate-vram.sh — Estimate VRAM requirements for training
# Usage: calculate-vram.sh --model TYPE --rank N --batch-size N --resolution N [--json]
#
# Provides estimated VRAM usage with 20% safety margin.

set -euo pipefail

MODEL_TYPE=""
RANK=32
BATCH_SIZE=1
RESOLUTION=1024
OPTIMIZER="prodigy"
JSON_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model|-m) MODEL_TYPE="$2"; shift 2 ;;
    --rank|-r) RANK="$2"; shift 2 ;;
    --batch-size|-b) BATCH_SIZE="$2"; shift 2 ;;
    --resolution) RESOLUTION="$2"; shift 2 ;;
    --optimizer) OPTIMIZER="$2"; shift 2 ;;
    --json) JSON_MODE=true; shift ;;
    --help|-h)
      echo "Usage: calculate-vram.sh --model TYPE --rank N --batch-size N --resolution N [--json]"
      echo ""
      echo "Estimate VRAM requirements for LoRA training."
      echo ""
      echo "Arguments:"
      echo "  --model TYPE      Model type: sdxl, pony, flux"
      echo "  --rank N          Network rank/dim (default: 32)"
      echo "  --batch-size N    Training batch size (default: 1)"
      echo "  --resolution N    Training resolution (default: 1024)"
      echo "  --optimizer OPT   Optimizer: prodigy, adamw, lion (default: prodigy)"
      echo "  --json            Output in JSON format"
      exit 0
      ;;
    *) echo "Error: Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$MODEL_TYPE" ]]; then
  echo "Error: --model is required (sdxl, pony, flux)" >&2
  exit 1
fi

# Base VRAM estimates (GB) at batch_size=1, resolution=1024, rank=32
# These are empirical estimates from community benchmarks
case "$MODEL_TYPE" in
  sdxl|pony)
    BASE_MODEL_VRAM=6.5    # Model loaded in VRAM
    BASE_TRAINING_VRAM=3.0 # Training overhead (gradients, optimizer state)
    ;;
  flux)
    BASE_MODEL_VRAM=10.0
    BASE_TRAINING_VRAM=4.0
    ;;
  *)
    echo "Error: Unknown model type: $MODEL_TYPE (use sdxl, pony, or flux)" >&2
    exit 1
    ;;
esac

# Adjust for rank (linear scaling, roughly)
RANK_FACTOR=$(echo "$RANK / 32" | bc -l)
RANK_OVERHEAD=$(echo "$RANK_FACTOR * 0.5" | bc -l)

# Adjust for batch size (roughly linear for latent batch)
BATCH_OVERHEAD=$(echo "($BATCH_SIZE - 1) * 1.5" | bc -l)

# Adjust for resolution (quadratic scaling relative to 1024)
RES_FACTOR=$(echo "($RESOLUTION * $RESOLUTION) / (1024 * 1024)" | bc -l)
RES_OVERHEAD=$(echo "($RES_FACTOR - 1) * 2.0" | bc -l)
if (( $(echo "$RES_OVERHEAD < 0" | bc -l) )); then
  RES_OVERHEAD=0
fi

# Optimizer overhead
case "$OPTIMIZER" in
  prodigy) OPT_OVERHEAD=0.5 ;;
  adamw) OPT_OVERHEAD=0.3 ;;
  lion) OPT_OVERHEAD=0.1 ;;
  *) OPT_OVERHEAD=0.3 ;;
esac

# xformers savings (assume enabled)
XFORMERS_SAVINGS=1.5

# Total estimate
RAW_TOTAL=$(echo "$BASE_MODEL_VRAM + $BASE_TRAINING_VRAM + $RANK_OVERHEAD + $BATCH_OVERHEAD + $RES_OVERHEAD + $OPT_OVERHEAD - $XFORMERS_SAVINGS" | bc -l)

# Ensure minimum sanity
if (( $(echo "$RAW_TOTAL < $BASE_MODEL_VRAM" | bc -l) )); then
  RAW_TOTAL=$BASE_MODEL_VRAM
fi

# 20% safety margin
SAFE_TOTAL=$(echo "$RAW_TOTAL * 1.2" | bc -l)

# Round to 1 decimal
RAW_ROUNDED=$(printf "%.1f" "$RAW_TOTAL")
SAFE_ROUNDED=$(printf "%.1f" "$SAFE_TOTAL")

# GPU recommendations
recommend_gpu() {
  local vram=$1
  if (( $(echo "$vram <= 10" | bc -l) )); then
    echo "RTX 3080 (10 GB), RTX 4070 Ti (12 GB)"
  elif (( $(echo "$vram <= 16" | bc -l) )); then
    echo "RTX 4080 (16 GB), Tesla T4 (16 GB)"
  elif (( $(echo "$vram <= 24" | bc -l) )); then
    echo "RTX 3090 (24 GB), RTX 4090 (24 GB), A5000 (24 GB)"
  elif (( $(echo "$vram <= 48" | bc -l) )); then
    echo "A6000 (48 GB), A100 40GB"
  else
    echo "A100 80GB, H100 (80 GB)"
  fi
}

GPU_REC=$(recommend_gpu "$SAFE_ROUNDED")

if $JSON_MODE; then
  jq -n \
    --arg model "$MODEL_TYPE" \
    --argjson rank "$RANK" \
    --argjson batch_size "$BATCH_SIZE" \
    --argjson resolution "$RESOLUTION" \
    --arg optimizer "$OPTIMIZER" \
    --arg estimated_vram "${RAW_ROUNDED} GB" \
    --arg with_safety_margin "${SAFE_ROUNDED} GB" \
    --arg recommended_gpus "$GPU_REC" \
    '{model: $model, rank: $rank, batch_size: $batch_size, resolution: $resolution,
      optimizer: $optimizer, estimated_vram: $estimated_vram,
      with_safety_margin: $with_safety_margin, recommended_gpus: $recommended_gpus}'
else
  echo "=== VRAM Estimate ==="
  echo ""
  echo "Configuration:"
  echo "  Model: $MODEL_TYPE"
  echo "  Rank: $RANK"
  echo "  Batch size: $BATCH_SIZE"
  echo "  Resolution: ${RESOLUTION}x${RESOLUTION}"
  echo "  Optimizer: $OPTIMIZER"
  echo ""
  echo "Estimated VRAM: ${RAW_ROUNDED} GB"
  echo "With 20% safety margin: ${SAFE_ROUNDED} GB"
  echo ""
  echo "Recommended GPU: $GPU_REC"
  echo ""
  if (( $(echo "$SAFE_ROUNDED > 24" | bc -l) )); then
    echo "Warning: This configuration requires a high-end GPU."
    echo "Consider reducing batch size or rank to fit on consumer hardware."
  fi
fi
