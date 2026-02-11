#!/usr/bin/env bash
# image-info.sh — Read image metadata (dimensions, format, file size, EXIF)
# Usage: image-info.sh <image> [--json]
#
# Works with sips (macOS built-in), ImageMagick (identify), or exiftool

set -euo pipefail

INPUT=""
JSON_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_MODE=true; shift ;;
    --help|-h)
      echo "Usage: image-info.sh <image> [--json]"
      echo ""
      echo "Read image metadata: dimensions, format, color space, file size."
      exit 0
      ;;
    *)
      if [[ -z "$INPUT" ]]; then
        INPUT="$1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$INPUT" ]]; then
  echo "Error: No image file specified." >&2
  exit 1
fi

if [[ ! -f "$INPUT" ]]; then
  echo "Error: File not found: $INPUT" >&2
  exit 1
fi

# Get basic file info
FILENAME=$(basename "$INPUT")
FILE_SIZE=$(stat -f%z "$INPUT" 2>/dev/null || stat --format=%s "$INPUT" 2>/dev/null || echo "unknown")
FILE_EXT="${FILENAME##*.}"

# Try to get image properties
WIDTH="unknown"
HEIGHT="unknown"
FORMAT="unknown"
COLOR_SPACE="unknown"
BIT_DEPTH="unknown"

if command -v sips >/dev/null 2>&1; then
  # macOS sips
  WIDTH=$(sips -g pixelWidth "$INPUT" 2>/dev/null | tail -1 | awk '{print $2}' || echo "unknown")
  HEIGHT=$(sips -g pixelHeight "$INPUT" 2>/dev/null | tail -1 | awk '{print $2}' || echo "unknown")
  FORMAT=$(sips -g format "$INPUT" 2>/dev/null | tail -1 | awk '{print $2}' || echo "$FILE_EXT")
  COLOR_SPACE=$(sips -g space "$INPUT" 2>/dev/null | tail -1 | awk '{print $2}' || echo "unknown")
  BIT_DEPTH=$(sips -g bitsPerSample "$INPUT" 2>/dev/null | tail -1 | awk '{print $2}' || echo "unknown")

elif command -v identify >/dev/null 2>&1; then
  # ImageMagick
  INFO=$(identify -format "%w %h %m %r %z" "$INPUT" 2>/dev/null || echo "")
  if [[ -n "$INFO" ]]; then
    WIDTH=$(echo "$INFO" | awk '{print $1}')
    HEIGHT=$(echo "$INFO" | awk '{print $2}')
    FORMAT=$(echo "$INFO" | awk '{print $3}')
    COLOR_SPACE=$(echo "$INFO" | awk '{print $4}')
    BIT_DEPTH=$(echo "$INFO" | awk '{print $5}')
  fi
fi

# ComfyUI metadata (stored in PNG text chunks)
COMFYUI_PROMPT=""
if command -v exiftool >/dev/null 2>&1; then
  COMFYUI_PROMPT=$(exiftool -s -s -s -Parameters "$INPUT" 2>/dev/null || echo "")
  if [[ -z "$COMFYUI_PROMPT" ]]; then
    COMFYUI_PROMPT=$(exiftool -s -s -s -Comment "$INPUT" 2>/dev/null || echo "")
  fi
fi

# Format file size for humans
format_size() {
  local bytes=$1
  if [[ "$bytes" == "unknown" ]]; then
    echo "unknown"
    return
  fi
  if (( bytes >= 1048576 )); then
    echo "$(( bytes / 1048576 )) MB"
  elif (( bytes >= 1024 )); then
    echo "$(( bytes / 1024 )) KB"
  else
    echo "${bytes} bytes"
  fi
}

HUMAN_SIZE=$(format_size "$FILE_SIZE")

if $JSON_MODE; then
  jq -n \
    --arg filename "$FILENAME" \
    --arg path "$INPUT" \
    --arg width "$WIDTH" \
    --arg height "$HEIGHT" \
    --arg format "$FORMAT" \
    --arg color_space "$COLOR_SPACE" \
    --arg bit_depth "$BIT_DEPTH" \
    --arg file_size "$FILE_SIZE" \
    --arg human_size "$HUMAN_SIZE" \
    --arg comfyui_prompt "$COMFYUI_PROMPT" \
    '{
      filename: $filename,
      path: $path,
      width: $width,
      height: $height,
      format: $format,
      color_space: $color_space,
      bit_depth: $bit_depth,
      file_size_bytes: $file_size,
      file_size: $human_size,
      comfyui_prompt: (if $comfyui_prompt == "" then null else $comfyui_prompt end)
    }'
else
  echo "File: $FILENAME"
  echo "Path: $INPUT"
  echo "Dimensions: ${WIDTH} x ${HEIGHT}"
  echo "Format: $FORMAT"
  echo "Color Space: $COLOR_SPACE"
  echo "Bit Depth: $BIT_DEPTH"
  echo "File Size: $HUMAN_SIZE ($FILE_SIZE bytes)"
  if [[ -n "$COMFYUI_PROMPT" ]]; then
    echo ""
    echo "Embedded Prompt:"
    echo "  $COMFYUI_PROMPT"
  fi
fi
