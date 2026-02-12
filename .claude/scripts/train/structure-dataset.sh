#!/usr/bin/env bash
# structure-dataset.sh — Restructure a flat image directory into Kohya's folder format
# Usage: structure-dataset.sh --input <dir> --output <dir> --name <concept> [OPTIONS]
#
# Creates the {repeats}_{name}/ folder structure that Kohya ss-scripts expect.
# Copies images and their caption .txt files into the structured directory.

set -euo pipefail
shopt -s nullglob

# Defaults
INPUT_DIR=""
OUTPUT_DIR=""
CONCEPT_NAME=""
REPEATS=""
EPOCHS=15
TARGET_STEPS=1500
JSON_MODE=false

usage() {
  cat <<'USAGE'
Usage: structure-dataset.sh --input <flat_dir> --output <kohya_dir> --name <concept> [OPTIONS]

Restructure a flat image directory into Kohya's required folder format.

Required arguments:
  --input <dir>       Path to directory containing images and caption .txt files
  --output <dir>      Path where the structured directory will be created
  --name <concept>    Concept name (used in the folder name, e.g. "mystyle")

Options:
  --repeats <N|auto>  Number of repeats per image (default: auto)
                      "auto" calculates from target-steps, epochs, and image count
  --epochs <N>        Number of training epochs (default: 15, used with --repeats auto)
  --target-steps <N>  Target total training steps (default: 1500, used with --repeats auto)
  --json              Output in JSON format
  --help, -h          Show this help message

How repeats work:
  Kohya calculates total steps as: repeats x image_count x epochs
  With --repeats auto, this script solves for repeats:
    repeats = ceil(target_steps / (image_count x epochs))

Example:
  structure-dataset.sh --input ./raw_photos --output ./dataset --name mystyle --repeats auto

  25 images, 15 epochs, 1500 target steps
  -> repeats = ceil(1500 / (25 x 15)) = 4
  -> Creates dataset/4_mystyle/ with 25 images and captions
USAGE
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT_DIR="$2"; shift 2 ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    --name) CONCEPT_NAME="$2"; shift 2 ;;
    --repeats) REPEATS="$2"; shift 2 ;;
    --epochs) EPOCHS="$2"; shift 2 ;;
    --target-steps) TARGET_STEPS="$2"; shift 2 ;;
    --json) JSON_MODE=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Error: Unknown argument: $1" >&2; echo "Run with --help for usage info." >&2; exit 1 ;;
  esac
done

# --- Validate required arguments ---

if [[ -z "$INPUT_DIR" ]]; then
  echo "Error: --input is required." >&2
  exit 1
fi

if [[ -z "$OUTPUT_DIR" ]]; then
  echo "Error: --output is required." >&2
  exit 1
fi

if [[ -z "$CONCEPT_NAME" ]]; then
  echo "Error: --name is required." >&2
  exit 1
fi

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "Error: Input directory not found: $INPUT_DIR" >&2
  exit 1
fi

# Validate concept name — no spaces or special chars that would break folder names
if [[ ! "$CONCEPT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "Error: Concept name should only contain letters, numbers, hyphens, and underscores." >&2
  echo "  You provided: $CONCEPT_NAME" >&2
  exit 1
fi

# Validate numeric arguments
if [[ -n "$REPEATS" && "$REPEATS" != "auto" ]]; then
  if ! [[ "$REPEATS" =~ ^[0-9]+$ ]] || (( REPEATS < 1 )); then
    echo "Error: --repeats must be a positive number or 'auto'." >&2
    exit 1
  fi
fi

if ! [[ "$EPOCHS" =~ ^[0-9]+$ ]] || (( EPOCHS < 1 )); then
  echo "Error: --epochs must be a positive number." >&2
  exit 1
fi

if ! [[ "$TARGET_STEPS" =~ ^[0-9]+$ ]] || (( TARGET_STEPS < 1 )); then
  echo "Error: --target-steps must be a positive number." >&2
  exit 1
fi

# --- Scan for images ---

IMAGE_EXTENSIONS=("png" "jpg" "jpeg" "webp")
IMAGE_FILES=()

for ext in "${IMAGE_EXTENSIONS[@]}"; do
  for file in "$INPUT_DIR"/*."$ext" "$INPUT_DIR"/*."${ext^^}"; do
    [[ -f "$file" ]] || continue
    IMAGE_FILES+=("$file")
  done
done

IMAGE_COUNT=${#IMAGE_FILES[@]}

if (( IMAGE_COUNT == 0 )); then
  if $JSON_MODE; then
    echo '{"status":"error","message":"No images found in input directory.","image_count":0}'
  else
    echo "Error: No images found in $INPUT_DIR" >&2
    echo "Looked for: .png, .jpg, .jpeg, .webp files" >&2
  fi
  exit 1
fi

# --- Check captions ---

CAPTIONED=0
UNCAPTIONED_FILES=()

for img in "${IMAGE_FILES[@]}"; do
  BASENAME=$(basename "$img")
  NAME_NO_EXT="${BASENAME%.*}"
  CAPTION_FILE="$INPUT_DIR/${NAME_NO_EXT}.txt"
  if [[ -f "$CAPTION_FILE" ]]; then
    CAPTIONED=$((CAPTIONED + 1))
  else
    UNCAPTIONED_FILES+=("$BASENAME")
  fi
done

UNCAPTIONED_COUNT=${#UNCAPTIONED_FILES[@]}
HAS_ANY_CAPTIONS=true
if (( CAPTIONED == 0 )); then
  HAS_ANY_CAPTIONS=false
fi

# --- Calculate repeats ---

if [[ -z "$REPEATS" || "$REPEATS" == "auto" ]]; then
  # repeats = ceil(target_steps / (image_count * epochs))
  DIVISOR=$((IMAGE_COUNT * EPOCHS))
  if (( DIVISOR == 0 )); then
    echo "Error: Cannot calculate repeats — image_count * epochs is zero." >&2
    exit 2
  fi
  REPEATS=$(( (TARGET_STEPS + DIVISOR - 1) / DIVISOR ))
  AUTO_CALCULATED=true
else
  AUTO_CALCULATED=false
fi

# Calculate actual total steps
TOTAL_STEPS=$((REPEATS * IMAGE_COUNT * EPOCHS))

# --- Build the structured directory ---

FOLDER_NAME="${REPEATS}_${CONCEPT_NAME}"
DEST_DIR="$OUTPUT_DIR/$FOLDER_NAME"

if [[ -d "$DEST_DIR" ]]; then
  echo "Error: Destination folder already exists: $DEST_DIR" >&2
  echo "Remove it first or choose a different output path." >&2
  exit 1
fi

mkdir -p "$DEST_DIR"

COPIED_IMAGES=0
COPIED_CAPTIONS=0

for img in "${IMAGE_FILES[@]}"; do
  BASENAME=$(basename "$img")
  NAME_NO_EXT="${BASENAME%.*}"

  # Copy image
  cp "$img" "$DEST_DIR/"
  COPIED_IMAGES=$((COPIED_IMAGES + 1))

  # Copy caption if it exists
  CAPTION_FILE="$INPUT_DIR/${NAME_NO_EXT}.txt"
  if [[ -f "$CAPTION_FILE" ]]; then
    cp "$CAPTION_FILE" "$DEST_DIR/"
    COPIED_CAPTIONS=$((COPIED_CAPTIONS + 1))
  fi
done

# --- Format numbers with commas for readability ---
format_number() {
  local num=$1
  if command -v printf >/dev/null 2>&1; then
    printf "%'d" "$num" 2>/dev/null || echo "$num"
  else
    echo "$num"
  fi
}

FORMATTED_STEPS=$(format_number "$TOTAL_STEPS")

# --- Output ---

if $JSON_MODE; then
  # Build uncaptioned files JSON array
  if (( UNCAPTIONED_COUNT > 0 )); then
    UNCAPTIONED_JSON=$(printf '%s\n' "${UNCAPTIONED_FILES[@]}" | jq -R . | jq -s .)
  else
    UNCAPTIONED_JSON="[]"
  fi

  jq -n \
    --arg status "success" \
    --arg input_dir "$INPUT_DIR" \
    --arg output_dir "$OUTPUT_DIR" \
    --arg folder_name "$FOLDER_NAME" \
    --arg dest_dir "$DEST_DIR" \
    --arg concept "$CONCEPT_NAME" \
    --argjson repeats "$REPEATS" \
    --argjson epochs "$EPOCHS" \
    --argjson target_steps "$TARGET_STEPS" \
    --argjson total_steps "$TOTAL_STEPS" \
    --argjson image_count "$IMAGE_COUNT" \
    --argjson copied_images "$COPIED_IMAGES" \
    --argjson copied_captions "$COPIED_CAPTIONS" \
    --argjson uncaptioned_count "$UNCAPTIONED_COUNT" \
    --argjson uncaptioned_files "$UNCAPTIONED_JSON" \
    --argjson auto_calculated "$AUTO_CALCULATED" \
    --argjson has_any_captions "$HAS_ANY_CAPTIONS" \
    '{
      status: $status,
      input_dir: $input_dir,
      output_dir: $output_dir,
      folder_name: $folder_name,
      dest_dir: $dest_dir,
      concept: $concept,
      repeats: $repeats,
      epochs: $epochs,
      target_steps: $target_steps,
      total_steps: $total_steps,
      image_count: $image_count,
      copied_images: $copied_images,
      copied_captions: $copied_captions,
      auto_calculated: $auto_calculated,
      captions: {
        has_any: $has_any_captions,
        captioned: $copied_captions,
        uncaptioned_count: $uncaptioned_count,
        uncaptioned_files: $uncaptioned_files
      }
    }'
else
  echo "=== Dataset Structured ==="
  echo ""
  echo "Created ${FOLDER_NAME}/ with ${IMAGE_COUNT} images"
  echo "  ${REPEATS} repeats x ${IMAGE_COUNT} images x ${EPOCHS} epochs = ${FORMATTED_STEPS} steps"
  echo ""
  echo "  Source:      $INPUT_DIR"
  echo "  Destination: $DEST_DIR"
  echo "  Images:      $COPIED_IMAGES copied"
  echo "  Captions:    $COPIED_CAPTIONS copied"

  if $AUTO_CALCULATED; then
    echo ""
    echo "Repeats were auto-calculated to hit ~${TARGET_STEPS} target steps."
    if (( TOTAL_STEPS != TARGET_STEPS )); then
      echo "  Actual steps (${FORMATTED_STEPS}) differ slightly because repeats must be a whole number."
    fi
  fi

  # Warnings
  if ! $HAS_ANY_CAPTIONS; then
    echo ""
    echo "Warning: No caption files found at all."
    echo "  Kohya needs a .txt file next to each image for captioned training."
    echo "  Without captions, you can only train with a single trigger word."
  elif (( UNCAPTIONED_COUNT > 0 )); then
    echo ""
    echo "Warning: ${UNCAPTIONED_COUNT} image(s) have no matching caption file:"
    for f in "${UNCAPTIONED_FILES[@]}"; do
      echo "  - $f"
    done
    echo "  These images will use the folder name as their caption during training."
  fi

  echo ""
  echo "Your dataset is ready. Point Kohya's image directory to: $OUTPUT_DIR"
fi
