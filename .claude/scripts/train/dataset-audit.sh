#!/usr/bin/env bash
# dataset-audit.sh — Audit a training dataset for quality issues
# Usage: dataset-audit.sh <directory> [--min-res 1024] [--json]
#
# Checks: resolution, format, corruption, aspect ratios, color space
# Requires: sips (macOS built-in) or ImageMagick (identify)

set -euo pipefail
shopt -s nullglob

# Defaults
DATASET_DIR=""
MIN_RES=1024
JSON_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --min-res) MIN_RES="$2"; shift 2 ;;
    --json) JSON_MODE=true; shift ;;
    --help|-h)
      echo "Usage: dataset-audit.sh <directory> [OPTIONS]"
      echo ""
      echo "Audit a training dataset for quality issues."
      echo ""
      echo "Arguments:"
      echo "  directory        Path to image directory"
      echo "  --min-res N      Minimum resolution (default: 1024)"
      echo "  --json           Output in JSON format"
      exit 0
      ;;
    *)
      if [[ -z "$DATASET_DIR" ]]; then
        DATASET_DIR="$1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$DATASET_DIR" ]]; then
  echo "Error: No dataset directory specified." >&2
  exit 1
fi

if [[ ! -d "$DATASET_DIR" ]]; then
  echo "Error: Directory not found: $DATASET_DIR" >&2
  exit 1
fi

# Detect image tool
TOOL=""
if command -v sips >/dev/null 2>&1; then
  TOOL="sips"
elif command -v identify >/dev/null 2>&1; then
  TOOL="imagemagick"
else
  echo "Error: No image tool found. Install ImageMagick or use macOS (sips)." >&2
  exit 1
fi

# Supported extensions
EXTENSIONS=("png" "jpg" "jpeg" "webp" "bmp" "tiff" "tif")

# Counters
TOTAL=0
GOOD=0
LOW_RES=0
CORRUPTED=0
CMYK_COUNT=0
CAPTION_COUNT=0

# Arrays for issues
LOW_RES_FILES=()
CORRUPTED_FILES=()
CMYK_FILES=()
UNCAPTIONED=()
WIDTHS=()
HEIGHTS=()
ASPECTS=()

# Scan files
for ext in "${EXTENSIONS[@]}"; do
  for file in "$DATASET_DIR"/*."$ext" "$DATASET_DIR"/*."${ext^^}"; do
    [[ -f "$file" ]] || continue
    TOTAL=$((TOTAL + 1))

    FILENAME=$(basename "$file")
    NAME_NO_EXT="${FILENAME%.*}"

    # Check for caption file
    if [[ -f "$DATASET_DIR/${NAME_NO_EXT}.txt" ]]; then
      CAPTION_COUNT=$((CAPTION_COUNT + 1))
    else
      UNCAPTIONED+=("$FILENAME")
    fi

    # Get image properties
    WIDTH=0
    HEIGHT=0
    COLOR_SPACE=""
    IS_CORRUPT=false

    if [[ "$TOOL" == "sips" ]]; then
      WIDTH=$(sips -g pixelWidth "$file" 2>/dev/null | tail -1 | awk '{print $2}') || IS_CORRUPT=true
      HEIGHT=$(sips -g pixelHeight "$file" 2>/dev/null | tail -1 | awk '{print $2}') || IS_CORRUPT=true
      COLOR_SPACE=$(sips -g space "$file" 2>/dev/null | tail -1 | awk '{print $2}') || true
    elif [[ "$TOOL" == "imagemagick" ]]; then
      INFO=$(identify -format "%w %h %r" "$file" 2>/dev/null) || IS_CORRUPT=true
      if [[ -n "$INFO" && "$IS_CORRUPT" == "false" ]]; then
        WIDTH=$(echo "$INFO" | awk '{print $1}')
        HEIGHT=$(echo "$INFO" | awk '{print $2}')
        COLOR_SPACE=$(echo "$INFO" | awk '{print $3}')
      fi
    fi

    # Check corruption
    if [[ "$IS_CORRUPT" == "true" ]] || [[ "$WIDTH" == "0" ]] || [[ -z "$WIDTH" ]]; then
      CORRUPTED=$((CORRUPTED + 1))
      CORRUPTED_FILES+=("$FILENAME")
      continue
    fi

    # Track dimensions
    WIDTHS+=("$WIDTH")
    HEIGHTS+=("$HEIGHT")

    # Aspect ratio
    if (( HEIGHT > 0 )); then
      # Store as W:H simplified (approximate)
      ASPECT_RATIO=$(awk "BEGIN {printf \"%.2f\", $WIDTH/$HEIGHT}")
      ASPECTS+=("$ASPECT_RATIO")
    fi

    # Check resolution
    MIN_DIM=$((WIDTH < HEIGHT ? WIDTH : HEIGHT))
    if (( MIN_DIM < MIN_RES )); then
      LOW_RES=$((LOW_RES + 1))
      LOW_RES_FILES+=("$FILENAME (${WIDTH}x${HEIGHT})")
    else
      GOOD=$((GOOD + 1))
    fi

    # Check color space
    if echo "$COLOR_SPACE" | grep -qi "cmyk"; then
      CMYK_COUNT=$((CMYK_COUNT + 1))
      CMYK_FILES+=("$FILENAME")
    fi
  done
done

# Calculate stats
ISSUES=$((LOW_RES + CORRUPTED + CMYK_COUNT))
UNCAPTIONED_COUNT=${#UNCAPTIONED[@]}

if $JSON_MODE; then
  # Build JSON arrays (handle empty arrays correctly)
  array_to_json() {
    if [[ $# -eq 0 ]]; then echo "[]"; else printf '%s\n' "$@" | jq -R . | jq -s .; fi
  }
  LOW_RES_JSON=$(array_to_json "${LOW_RES_FILES[@]+"${LOW_RES_FILES[@]}"}")
  CORRUPTED_JSON=$(array_to_json "${CORRUPTED_FILES[@]+"${CORRUPTED_FILES[@]}"}")
  CMYK_JSON=$(array_to_json "${CMYK_FILES[@]+"${CMYK_FILES[@]}"}")
  UNCAPTIONED_JSON=$(array_to_json "${UNCAPTIONED[@]+"${UNCAPTIONED[@]}"}")

  jq -n \
    --arg dir "$DATASET_DIR" \
    --argjson total "$TOTAL" \
    --argjson good "$GOOD" \
    --argjson low_res "$LOW_RES" \
    --argjson corrupted "$CORRUPTED" \
    --argjson cmyk "$CMYK_COUNT" \
    --argjson captioned "$CAPTION_COUNT" \
    --argjson uncaptioned_count "$UNCAPTIONED_COUNT" \
    --argjson issues "$ISSUES" \
    --argjson min_res "$MIN_RES" \
    --argjson low_res_files "$LOW_RES_JSON" \
    --argjson corrupted_files "$CORRUPTED_JSON" \
    --argjson cmyk_files "$CMYK_JSON" \
    --argjson uncaptioned_files "$UNCAPTIONED_JSON" \
    '{
      directory: $dir,
      total_images: $total,
      passing: $good,
      issues: $issues,
      min_resolution: $min_res,
      below_resolution: {count: $low_res, files: $low_res_files},
      corrupted: {count: $corrupted, files: $corrupted_files},
      cmyk_color_space: {count: $cmyk, files: $cmyk_files},
      captions: {captioned: $captioned, uncaptioned: $uncaptioned_count, uncaptioned_files: $uncaptioned_files}
    }'
else
  echo "=== Dataset Audit Report ==="
  echo ""
  echo "Directory: $DATASET_DIR"
  echo "Total images: $TOTAL"
  echo "Minimum resolution: ${MIN_RES}px"
  echo ""

  if (( TOTAL == 0 )); then
    echo "No images found in directory."
    exit 0
  fi

  echo "--- Results ---"
  echo "Passing: $GOOD"
  echo "Issues: $ISSUES"
  echo ""

  if (( LOW_RES > 0 )); then
    echo "Below ${MIN_RES}px ($LOW_RES images):"
    for f in "${LOW_RES_FILES[@]}"; do
      echo "  - $f"
    done
    echo ""
  fi

  if (( CORRUPTED > 0 )); then
    echo "Corrupted / unreadable ($CORRUPTED images):"
    for f in "${CORRUPTED_FILES[@]}"; do
      echo "  - $f"
    done
    echo ""
  fi

  if (( CMYK_COUNT > 0 )); then
    echo "CMYK color space ($CMYK_COUNT images — should be RGB):"
    for f in "${CMYK_FILES[@]}"; do
      echo "  - $f"
    done
    echo ""
  fi

  echo "--- Captions ---"
  echo "Captioned: $CAPTION_COUNT / $TOTAL"
  if (( UNCAPTIONED_COUNT > 0 )); then
    echo "Missing captions ($UNCAPTIONED_COUNT images):"
    for f in "${UNCAPTIONED[@]}"; do
      echo "  - $f"
    done
  fi
  echo ""

  # Summary
  echo "--- Summary ---"
  if (( ISSUES == 0 && UNCAPTIONED_COUNT == 0 )); then
    echo "All images pass quality checks and have captions."
  else
    if (( LOW_RES > 0 )); then
      echo "- $LOW_RES image(s) are below ${MIN_RES}px — upscale or remove them"
    fi
    if (( CORRUPTED > 0 )); then
      echo "- $CORRUPTED image(s) appear corrupted — remove them"
    fi
    if (( CMYK_COUNT > 0 )); then
      echo "- $CMYK_COUNT image(s) are in CMYK color space — convert to RGB"
    fi
    if (( UNCAPTIONED_COUNT > 0 )); then
      echo "- $UNCAPTIONED_COUNT image(s) have no caption file — create .txt captions"
    fi
  fi
fi
