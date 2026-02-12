#!/usr/bin/env bash
# eval-grid.sh — Generate evaluation grid for a trained LoRA
# Submits test prompts at multiple LoRA weights to ComfyUI for side-by-side comparison.
#
# Usage:
#   eval-grid.sh --lora PATH --model PATH --prompt "a cat" [OPTIONS]
#   eval-grid.sh --lora PATH --model PATH --prompt-file prompts.txt [OPTIONS]
#
# Generates images at weights 0.3, 0.5, 0.7, 0.9, 1.0 (configurable)
# Outputs to a structured directory for easy comparison.
#
# Requires: ComfyUI running + jq + comfyui-submit.sh + comfyui-poll.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STUDIO_SCRIPTS="$(cd "$SCRIPT_DIR/../studio" 2>/dev/null && pwd || echo "")"

LORA_PATH=""
MODEL_PATH=""
PROMPT=""
PROMPT_FILE=""
NEGATIVE="worst quality, low quality, blurry, deformed"
TRIGGER_WORD=""
OUTPUT_DIR="./eval-grid"
WEIGHTS=(0.3 0.5 0.7 0.9 1.0)
STEPS=30
CFG=7
WIDTH=1024
HEIGHT=1024
SEED=""
COMFYUI_URL="http://127.0.0.1:8188"
COMFYUI_HOST="127.0.0.1"
COMFYUI_PORT="8188"
JSON_MODE=false
# shellcheck disable=SC2034
CHECKPOINT_DIR=""

usage() {
    cat <<'USAGE'
eval-grid.sh — Generate LoRA evaluation grid

USAGE:
    eval-grid.sh --lora <path> --model <path> --prompt "<text>" [OPTIONS]

REQUIRED:
    --lora <path>         Path to LoRA .safetensors file
    --model <path>        Path to base model .safetensors file
    --prompt "<text>"     Test prompt (or use --prompt-file)

OPTIONS:
    --prompt-file <path>  File with one prompt per line (instead of --prompt)
    --negative "<text>"   Negative prompt (default: quality negatives)
    --trigger <word>      Trigger word (auto-prepended to prompts)
    --output <dir>        Output directory (default: ./eval-grid)
    --weights <list>      Comma-separated weights (default: 0.3,0.5,0.7,0.9,1.0)
    --steps <n>           Sampling steps (default: 30)
    --cfg <n>             CFG scale (default: 7)
    --width <n>           Image width (default: 1024)
    --height <n>          Image height (default: 1024)
    --seed <n>            Fixed seed for reproducibility (default: random)
    --url <url>           ComfyUI URL (default: http://127.0.0.1:8188)
    --checkpoints <dir>   Directory of checkpoints to compare
    --json                Output JSON summary
    --help                Show this help

EXAMPLES:
    # Basic evaluation
    eval-grid.sh --lora ./my_style.safetensors --model ./ponyV6.safetensors \
        --prompt "mystyle, a portrait of a woman" --trigger mystyle

    # Compare across checkpoints
    eval-grid.sh --lora ./my_style.safetensors --model ./ponyV6.safetensors \
        --prompt "mystyle, landscape" --checkpoints ./checkpoints/

    # Multiple test prompts
    eval-grid.sh --lora ./my_style.safetensors --model ./ponyV6.safetensors \
        --prompt-file test_prompts.txt

WHAT THIS DOES:
    Generates images at different LoRA strengths so you can find the
    sweet spot — where the style is strong enough to show but not so
    strong it distorts the image.
USAGE
    exit 0
}

# --- Argument Parsing ---

while [[ $# -gt 0 ]]; do
    case "$1" in
        --lora) LORA_PATH="$2"; shift 2 ;;
        --model) MODEL_PATH="$2"; shift 2 ;;
        --prompt) PROMPT="$2"; shift 2 ;;
        --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
        --negative) NEGATIVE="$2"; shift 2 ;;
        --trigger) TRIGGER_WORD="$2"; shift 2 ;;
        --output) OUTPUT_DIR="$2"; shift 2 ;;
        --weights) IFS=',' read -ra WEIGHTS <<< "$2"; shift 2 ;;
        --steps) STEPS="$2"; shift 2 ;;
        --cfg) CFG="$2"; shift 2 ;;
        --width) WIDTH="$2"; shift 2 ;;
        --height) HEIGHT="$2"; shift 2 ;;
        --seed) SEED="$2"; shift 2 ;;
        --url) COMFYUI_URL="$2"
               COMFYUI_HOST=$(echo "$2" | sed 's|https\{0,1\}://||' | cut -d: -f1)
               COMFYUI_PORT=$(echo "$2" | sed 's|https\{0,1\}://||' | cut -d: -f2)
               shift 2 ;;
        --checkpoints) CHECKPOINT_DIR="$2"; shift 2 ;;
        --json) JSON_MODE=true; shift ;;
        --help) usage ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# --- Validation ---

if [[ -z "$LORA_PATH" ]]; then
    echo "Error: --lora is required" >&2
    exit 1
fi

if [[ -z "$MODEL_PATH" ]]; then
    echo "Error: --model is required" >&2
    exit 1
fi

if [[ -z "$PROMPT" && -z "$PROMPT_FILE" ]]; then
    echo "Error: --prompt or --prompt-file is required" >&2
    exit 1
fi

if [[ ! -f "$LORA_PATH" ]]; then
    echo "Error: LoRA file not found: $LORA_PATH" >&2
    exit 1
fi

# --- Build Prompt List ---

PROMPTS=()
if [[ -n "$PROMPT" ]]; then
    PROMPTS+=("$PROMPT")
fi

if [[ -n "$PROMPT_FILE" && -f "$PROMPT_FILE" ]]; then
    while IFS= read -r line; do
        [[ -n "$line" && ! "$line" =~ ^# ]] && PROMPTS+=("$line")
    done < "$PROMPT_FILE"
fi

# Prepend trigger word if specified
if [[ -n "$TRIGGER_WORD" ]]; then
    TRIGGERED_PROMPTS=()
    for p in "${PROMPTS[@]}"; do
        if [[ "$p" != *"$TRIGGER_WORD"* ]]; then
            TRIGGERED_PROMPTS+=("${TRIGGER_WORD}, ${p}")
        else
            TRIGGERED_PROMPTS+=("$p")
        fi
    done
    PROMPTS=("${TRIGGERED_PROMPTS[@]}")
fi

# --- Seed ---

if [[ -z "$SEED" ]]; then
    SEED=$((RANDOM * RANDOM))
fi

# --- Output Setup ---

mkdir -p "$OUTPUT_DIR"
LORA_NAME=$(basename "$LORA_PATH" .safetensors)

echo "=== LoRA Evaluation Grid ==="
echo ""
echo "LoRA: $LORA_NAME"
echo "Model: $(basename "$MODEL_PATH")"
echo "Weights: ${WEIGHTS[*]}"
echo "Prompts: ${#PROMPTS[@]}"
echo "Seed: $SEED (fixed across all generations for fair comparison)"
echo "Output: $OUTPUT_DIR"
echo ""

# --- Check ComfyUI ---

check_comfyui() {
    if curl -s --connect-timeout 3 "$COMFYUI_URL/system_stats" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# --- Generate Workflow JSON ---
# Builds a ComfyUI API workflow with LoRA at specified weight

build_workflow() {
    local prompt_text="$1"
    local weight="$2"
    local output_prefix="$3"

    # This generates a minimal ComfyUI API workflow
    # The actual template comes from studio resources, but we build inline
    # for the eval grid to be self-contained
    jq -n \
        --arg model "$MODEL_PATH" \
        --arg lora "$LORA_PATH" \
        --arg prompt "$prompt_text" \
        --arg negative "$NEGATIVE" \
        --argjson weight "$weight" \
        --argjson steps "$STEPS" \
        --argjson cfg "$CFG" \
        --argjson width "$WIDTH" \
        --argjson height "$HEIGHT" \
        --argjson seed "$SEED" \
        --arg prefix "$output_prefix" \
        '{
            "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": $model}},
            "10": {"class_type": "LoraLoader", "inputs": {"model": ["4", 0], "clip": ["4", 1], "lora_name": $lora, "strength_model": $weight, "strength_clip": $weight}},
            "6": {"class_type": "CLIPTextEncode", "inputs": {"text": $prompt, "clip": ["10", 1]}},
            "7": {"class_type": "CLIPTextEncode", "inputs": {"text": $negative, "clip": ["10", 1]}},
            "3": {"class_type": "KSampler", "inputs": {"model": ["10", 0], "positive": ["6", 0], "negative": ["7", 0], "latent_image": ["5", 0], "seed": $seed, "steps": $steps, "cfg": $cfg, "sampler_name": "euler", "scheduler": "karras", "denoise": 1}},
            "5": {"class_type": "EmptyLatentImage", "inputs": {"width": $width, "height": $height, "batch_size": 1}},
            "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
            "9": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": $prefix}}
        }'
}

# --- Main Generation Loop ---

RESULTS=()
TOTAL_IMAGES=$(( ${#PROMPTS[@]} * ${#WEIGHTS[@]} ))
CURRENT=0

if check_comfyui; then
    echo "ComfyUI detected at $COMFYUI_URL — generating images..."
    echo ""

    for pi in "${!PROMPTS[@]}"; do
        prompt="${PROMPTS[$pi]}"
        prompt_label="prompt_$((pi + 1))"

        for weight in "${WEIGHTS[@]}"; do
            CURRENT=$((CURRENT + 1))
            weight_label=$(echo "$weight" | tr '.' '_')
            prefix="${LORA_NAME}_${prompt_label}_w${weight_label}"
            out_dir="${OUTPUT_DIR}/${prompt_label}"
            mkdir -p "$out_dir"

            echo "[$CURRENT/$TOTAL_IMAGES] Weight $weight — ${prompt:0:50}..."

            # Build and submit workflow
            WORKFLOW=$(build_workflow "$prompt" "$weight" "$prefix")
            WORKFLOW_FILE=$(mktemp "${TMPDIR:-/tmp}/eval_workflow_XXXXXX.json")
            echo "$WORKFLOW" > "$WORKFLOW_FILE"

            if [[ -n "$STUDIO_SCRIPTS" && -x "$STUDIO_SCRIPTS/comfyui-submit.sh" ]]; then
                PROMPT_ID=$("$STUDIO_SCRIPTS/comfyui-submit.sh" "$WORKFLOW_FILE" --host "$COMFYUI_HOST" --port "$COMFYUI_PORT" --json 2>/dev/null | jq -r '.prompt_id // empty') || true

                if [[ -n "$PROMPT_ID" ]]; then
                    "$STUDIO_SCRIPTS/comfyui-poll.sh" "$PROMPT_ID" --host "$COMFYUI_HOST" --port "$COMFYUI_PORT" --output "$out_dir" --timeout 120 2>/dev/null || true
                    RESULTS+=("{\"prompt\":\"${prompt:0:50}\",\"weight\":$weight,\"status\":\"generated\",\"dir\":\"$out_dir\"}")
                else
                    echo "  Warning: Submit failed for weight $weight"
                    RESULTS+=("{\"prompt\":\"${prompt:0:50}\",\"weight\":$weight,\"status\":\"failed\"}")
                fi
            else
                echo "  Warning: comfyui-submit.sh not found — saving workflow only"
                cp "$WORKFLOW_FILE" "${out_dir}/${prefix}.json"
                RESULTS+=("{\"prompt\":\"${prompt:0:50}\",\"weight\":$weight,\"status\":\"workflow_saved\"}")
            fi

            rm -f "$WORKFLOW_FILE"
        done
    done

    echo ""
    echo "Evaluation grid complete: $OUTPUT_DIR"
else
    echo "ComfyUI not running at $COMFYUI_URL"
    echo ""
    echo "Saving workflow JSONs for manual execution..."

    for pi in "${!PROMPTS[@]}"; do
        prompt="${PROMPTS[$pi]}"
        prompt_label="prompt_$((pi + 1))"
        out_dir="${OUTPUT_DIR}/${prompt_label}"
        mkdir -p "$out_dir"

        for weight in "${WEIGHTS[@]}"; do
            CURRENT=$((CURRENT + 1))
            weight_label=$(echo "$weight" | tr '.' '_')
            prefix="${LORA_NAME}_${prompt_label}_w${weight_label}"

            WORKFLOW=$(build_workflow "$prompt" "$weight" "$prefix")
            echo "$WORKFLOW" > "${out_dir}/${prefix}.json"

            RESULTS+=("{\"prompt\":\"${prompt:0:50}\",\"weight\":$weight,\"status\":\"workflow_saved\",\"file\":\"${out_dir}/${prefix}.json\"}")
        done
    done

    echo "Saved $TOTAL_IMAGES workflow JSONs to $OUTPUT_DIR"
    echo ""
    echo "To generate: Start ComfyUI, then re-run this command."
    echo "Or load the .json files manually in ComfyUI."
fi

# --- Summary ---

if $JSON_MODE; then
    jq -n \
        --arg lora "$LORA_NAME" \
        --arg model "$(basename "$MODEL_PATH")" \
        --argjson seed "$SEED" \
        --argjson total "$TOTAL_IMAGES" \
        --argjson results "$(printf '%s\n' "${RESULTS[@]}" | jq -s .)" \
        '{lora: $lora, model: $model, seed: $seed, total_images: $total, results: $results}'
else
    echo ""
    echo "=== Evaluation Summary ==="
    echo "Total images: $TOTAL_IMAGES"
    echo "Weights tested: ${WEIGHTS[*]}"
    echo "Seed: $SEED"
    echo ""
    echo "What to look for:"
    echo "  - At which weight does the style appear clearly?"
    echo "  - At which weight does the image start to distort?"
    echo "  - The sweet spot is usually where the style is visible but faces/details are still clean."
    echo ""
    echo "Common findings:"
    echo "  0.3-0.5: Subtle influence — good for blending"
    echo "  0.5-0.7: Style visible — usually the sweet spot"
    echo "  0.7-0.9: Strong style — may affect composition/faces"
    echo "  1.0:     Full strength — often too strong for production"
fi
