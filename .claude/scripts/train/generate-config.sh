#!/usr/bin/env bash
# generate-config.sh — Generate a training config from parameters
# Usage: generate-config.sh --backend BACKEND --model PATH --dataset PATH --output DIR [OPTIONS] [--json]
#
# Generates a config file for the specified training backend (kohya, simpletuner, ai-toolkit)

set -euo pipefail

# Defaults
BACKEND=""
MODEL_PATH=""
DATASET_PATH=""
OUTPUT_DIR=""
LORA_NAME="my_lora"
PRESET="standard"
EPOCHS=""
LR=""
BATCH_SIZE=""
RANK=""
ALPHA=""
RESOLUTION=1024
OPTIMIZER=""
CLIP_SKIP=1
NOISE_OFFSET=0.1
SAVE_EVERY=""
JSON_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backend|-b) BACKEND="$2"; shift 2 ;;
    --model|-m) MODEL_PATH="$2"; shift 2 ;;
    --dataset|-d) DATASET_PATH="$2"; shift 2 ;;
    --output|-o) OUTPUT_DIR="$2"; shift 2 ;;
    --name|-n) LORA_NAME="$2"; shift 2 ;;
    --preset|-p) PRESET="$2"; shift 2 ;;
    --epochs) EPOCHS="$2"; shift 2 ;;
    --lr) LR="$2"; shift 2 ;;
    --batch-size) BATCH_SIZE="$2"; shift 2 ;;
    --rank) RANK="$2"; shift 2 ;;
    --alpha) ALPHA="$2"; shift 2 ;;
    --resolution) RESOLUTION="$2"; shift 2 ;;
    --optimizer) OPTIMIZER="$2"; shift 2 ;;
    --clip-skip) CLIP_SKIP="$2"; shift 2 ;;
    --json) JSON_MODE=true; shift ;;
    --help|-h)
      echo "Usage: generate-config.sh --backend BACKEND --model PATH --dataset PATH --output DIR [OPTIONS]"
      echo ""
      echo "Generate a training configuration file."
      echo ""
      echo "Required:"
      echo "  --backend BACKEND   Training backend: kohya, simpletuner, ai-toolkit"
      echo "  --model PATH        Path to base model .safetensors"
      echo "  --dataset PATH      Path to dataset directory"
      echo "  --output DIR        Output directory for trained LoRA"
      echo ""
      echo "Optional:"
      echo "  --name NAME         LoRA name (default: my_lora)"
      echo "  --preset PRESET     quick, standard, thorough (default: standard)"
      echo "  --epochs N          Override preset epochs"
      echo "  --lr RATE           Override learning rate"
      echo "  --batch-size N      Override batch size"
      echo "  --rank N            Network rank/dim (default: 32)"
      echo "  --alpha N           Network alpha (default: 16)"
      echo "  --resolution N      Training resolution (default: 1024)"
      echo "  --optimizer OPT     Optimizer: prodigy, adamw, lion (default: prodigy)"
      echo "  --clip-skip N       CLIP skip layers (default: 1, use 2 for Pony)"
      echo "  --json              Output config as JSON"
      exit 0
      ;;
    *) echo "Error: Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# Validate required args
for arg_name in BACKEND MODEL_PATH DATASET_PATH OUTPUT_DIR; do
  if [[ -z "${!arg_name}" ]]; then
    echo "Error: --${arg_name,,} is required." >&2
    exit 1
  fi
done

# Apply preset defaults
case "$PRESET" in
  quick)
    : "${EPOCHS:=5}"; : "${LR:=1.0}"; RANK=${RANK:-16}; ALPHA=${ALPHA:-16}
    OPTIMIZER=${OPTIMIZER:-prodigy}; : "${SAVE_EVERY:=2}"
    ;;
  standard)
    : "${EPOCHS:=15}"; : "${LR:=1.0}"; RANK=${RANK:-32}; ALPHA=${ALPHA:-16}
    OPTIMIZER=${OPTIMIZER:-prodigy}; : "${SAVE_EVERY:=3}"
    ;;
  thorough)
    : "${EPOCHS:=25}"; : "${LR:=5e-5}"; RANK=${RANK:-64}; ALPHA=${ALPHA:-32}
    OPTIMIZER=${OPTIMIZER:-adamw}; : "${SAVE_EVERY:=5}"
    ;;
  *)
    echo "Error: Unknown preset: $PRESET (use quick, standard, or thorough)" >&2
    exit 1
    ;;
esac

: "${BATCH_SIZE:=1}"

# Count dataset images
IMAGE_COUNT=$(find "$DATASET_PATH" -maxdepth 1 \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) 2>/dev/null | wc -l | tr -d ' ')
TOTAL_STEPS=$(( IMAGE_COUNT * EPOCHS / BATCH_SIZE ))

CONFIG_FILE="${OUTPUT_DIR}/${LORA_NAME}_config"

mkdir -p "$OUTPUT_DIR"

case "$BACKEND" in
  kohya)
    CONFIG_FILE="${CONFIG_FILE}.toml"
    cat > "$CONFIG_FILE" << TOMLEOF
[model]
pretrained_model_name_or_path = "${MODEL_PATH}"

[output]
output_dir = "${OUTPUT_DIR}"
output_name = "${LORA_NAME}"
logging_dir = "${OUTPUT_DIR}/logs"

[dataset]
train_data_dir = "${DATASET_PATH}"
resolution = "${RESOLUTION},${RESOLUTION}"

[training]
max_train_epochs = ${EPOCHS}
train_batch_size = ${BATCH_SIZE}
learning_rate = ${LR}
optimizer_type = "${OPTIMIZER}"
mixed_precision = "bf16"
clip_skip = ${CLIP_SKIP}
noise_offset = ${NOISE_OFFSET}

[network]
network_module = "networks.lora"
network_dim = ${RANK}
network_alpha = ${ALPHA}

[saving]
save_every_n_epochs = ${SAVE_EVERY}
save_model_as = "safetensors"
TOMLEOF
    ;;

  simpletuner)
    CONFIG_FILE="${CONFIG_FILE}.env"
    cat > "$CONFIG_FILE" << ENVEOF
export MODEL_NAME="${MODEL_PATH}"
export OUTPUT_DIR="${OUTPUT_DIR}"
export INSTANCE_DIR="${DATASET_PATH}"
export RESOLUTION=${RESOLUTION}
export TRAIN_BATCH_SIZE=${BATCH_SIZE}
export MAX_NUM_STEPS=${TOTAL_STEPS}
export LEARNING_RATE=${LR}
export OPTIMIZER="${OPTIMIZER}"
export LORA_RANK=${RANK}
export LORA_ALPHA=${ALPHA}
export MIXED_PRECISION="bf16"
export CHECKPOINTING_STEPS=$(( TOTAL_STEPS / ( (EPOCHS / SAVE_EVERY) > 0 ? (EPOCHS / SAVE_EVERY) : 1 ) ))
export NOISE_OFFSET=${NOISE_OFFSET}
ENVEOF
    ;;

  ai-toolkit)
    CONFIG_FILE="${CONFIG_FILE}.yaml"
    cat > "$CONFIG_FILE" << YAMLEOF
job: train
config:
  name: "${LORA_NAME}"
  process:
    - type: sd_trainer
      training_folder: "${OUTPUT_DIR}"
      device: cuda:0
      network:
        type: lora
        linear: ${RANK}
        linear_alpha: ${ALPHA}
      save:
        dtype: float16
        save_every: $(( TOTAL_STEPS / ( (EPOCHS / SAVE_EVERY) > 0 ? (EPOCHS / SAVE_EVERY) : 1 ) ))
      datasets:
        - folder_path: "${DATASET_PATH}"
          caption_ext: txt
          resolution: ${RESOLUTION}
          batch_size: ${BATCH_SIZE}
      train:
        batch_size: ${BATCH_SIZE}
        steps: ${TOTAL_STEPS}
        lr: ${LR}
        optimizer: ${OPTIMIZER}
        noise_offset: ${NOISE_OFFSET}
        dtype: bf16
      model:
        name_or_path: "${MODEL_PATH}"
        is_xl: true
YAMLEOF
    ;;

  *)
    echo "Error: Unknown backend: $BACKEND (use kohya, simpletuner, or ai-toolkit)" >&2
    exit 1
    ;;
esac

if $JSON_MODE; then
  jq -n \
    --arg status "generated" \
    --arg backend "$BACKEND" \
    --arg config_file "$CONFIG_FILE" \
    --arg preset "$PRESET" \
    --argjson epochs "$EPOCHS" \
    --arg lr "$LR" \
    --argjson batch_size "$BATCH_SIZE" \
    --argjson rank "$RANK" \
    --argjson alpha "$ALPHA" \
    --argjson resolution "$RESOLUTION" \
    --arg optimizer "$OPTIMIZER" \
    --argjson images "$IMAGE_COUNT" \
    --argjson total_steps "$TOTAL_STEPS" \
    '{status: $status, backend: $backend, config_file: $config_file, preset: $preset,
      parameters: {epochs: $epochs, learning_rate: $lr, batch_size: $batch_size,
      rank: $rank, alpha: $alpha, resolution: $resolution, optimizer: $optimizer},
      dataset: {images: $images, total_steps: $total_steps}}'
else
  echo "Config generated: $CONFIG_FILE"
  echo ""
  echo "Backend: $BACKEND"
  echo "Preset: $PRESET"
  echo "Model: $MODEL_PATH"
  echo "Dataset: $DATASET_PATH ($IMAGE_COUNT images)"
  echo ""
  echo "Parameters:"
  echo "  Epochs: $EPOCHS"
  echo "  Learning rate: $LR"
  echo "  Batch size: $BATCH_SIZE"
  echo "  Network rank: $RANK"
  echo "  Network alpha: $ALPHA"
  echo "  Resolution: ${RESOLUTION}x${RESOLUTION}"
  echo "  Optimizer: $OPTIMIZER"
  echo "  Total steps: $TOTAL_STEPS"
  echo "  Save every: $SAVE_EVERY epochs"
fi
