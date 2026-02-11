#!/usr/bin/env bash
# export-asset.sh — Export an image with optional resize and format conversion
# Usage: export-asset.sh <input> [--output DIR] [--name NAME] [--format FORMAT] [--width W] [--height H] [--quality Q] [--json]
#
# Requires: sips (macOS built-in) or ImageMagick (convert)

set -euo pipefail

# Defaults
INPUT=""
OUTPUT_DIR="exports"
NAME=""
FORMAT=""
WIDTH=""
HEIGHT=""
QUALITY="90"
JSON_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output|-o) OUTPUT_DIR="$2"; shift 2 ;;
    --name|-n) NAME="$2"; shift 2 ;;
    --format|-f) FORMAT="$2"; shift 2 ;;
    --width|-w) WIDTH="$2"; shift 2 ;;
    --height) HEIGHT="$2"; shift 2 ;;
    --quality|-q) QUALITY="$2"; shift 2 ;;
    --json) JSON_MODE=true; shift ;;
    --help|-h)
      echo "Usage: export-asset.sh <input> [OPTIONS]"
      echo ""
      echo "Export an image with optional resize and format conversion."
      echo ""
      echo "Arguments:"
      echo "  input            Path to source image"
      echo "  --output DIR     Output directory (default: exports)"
      echo "  --name NAME      Output filename (without extension)"
      echo "  --format FORMAT  Output format: png, webp, jpeg (default: same as input)"
      echo "  --width W        Resize width (maintains aspect ratio if height omitted)"
      echo "  --height H       Resize height (maintains aspect ratio if width omitted)"
      echo "  --quality Q      JPEG/WebP quality 1-100 (default: 90)"
      echo "  --json           Output in JSON format"
      exit 0
      ;;
    *)
      if [[ -z "$INPUT" ]]; then
        INPUT="$1"
      else
        echo "Error: Unexpected argument: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

# Validate
if [[ -z "$INPUT" ]]; then
  echo "Error: No input file specified." >&2
  exit 1
fi

if [[ ! -f "$INPUT" ]]; then
  echo "Error: Input file not found: $INPUT" >&2
  exit 1
fi

# Determine output filename
INPUT_BASENAME=$(basename "$INPUT")
INPUT_EXT="${INPUT_BASENAME##*.}"
INPUT_NAME="${INPUT_BASENAME%.*}"

if [[ -z "$NAME" ]]; then
  NAME="$INPUT_NAME"
fi

if [[ -z "$FORMAT" ]]; then
  FORMAT="$INPUT_EXT"
fi

# Normalize format
FORMAT=$(echo "$FORMAT" | tr '[:upper:]' '[:lower:]')
case "$FORMAT" in
  jpg) FORMAT="jpeg" ;;
esac

OUTPUT_FILE="${OUTPUT_DIR}/${NAME}.${FORMAT}"
if [[ "$FORMAT" == "jpeg" ]]; then
  OUTPUT_FILE="${OUTPUT_DIR}/${NAME}.jpg"
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Detect available tool
TOOL=""
if command -v convert >/dev/null 2>&1; then
  TOOL="imagemagick"
elif command -v sips >/dev/null 2>&1; then
  TOOL="sips"
else
  echo "Error: No image processing tool found." >&2
  echo "Install ImageMagick (brew install imagemagick) or use macOS with sips." >&2
  exit 1
fi

# Export with the available tool
if [[ "$TOOL" == "imagemagick" ]]; then
  ARGS=("$INPUT")

  if [[ -n "$WIDTH" && -n "$HEIGHT" ]]; then
    ARGS+=(-resize "${WIDTH}x${HEIGHT}")
  elif [[ -n "$WIDTH" ]]; then
    ARGS+=(-resize "${WIDTH}x")
  elif [[ -n "$HEIGHT" ]]; then
    ARGS+=(-resize "x${HEIGHT}")
  fi

  if [[ "$FORMAT" == "jpeg" || "$FORMAT" == "webp" ]]; then
    ARGS+=(-quality "$QUALITY")
  fi

  ARGS+=("$OUTPUT_FILE")
  convert "${ARGS[@]}"

elif [[ "$TOOL" == "sips" ]]; then
  # sips works by copying and transforming
  cp "$INPUT" "$OUTPUT_FILE"

  if [[ -n "$WIDTH" && -n "$HEIGHT" ]]; then
    sips --resampleHeightWidth "$HEIGHT" "$WIDTH" "$OUTPUT_FILE" >/dev/null 2>&1
  elif [[ -n "$WIDTH" ]]; then
    sips --resampleWidth "$WIDTH" "$OUTPUT_FILE" >/dev/null 2>&1
  elif [[ -n "$HEIGHT" ]]; then
    sips --resampleHeight "$HEIGHT" "$OUTPUT_FILE" >/dev/null 2>&1
  fi

  # Format conversion with sips
  case "$FORMAT" in
    png) sips -s format png "$OUTPUT_FILE" --out "$OUTPUT_FILE" >/dev/null 2>&1 ;;
    jpeg) sips -s format jpeg -s formatOptions "$QUALITY" "$OUTPUT_FILE" --out "$OUTPUT_FILE" >/dev/null 2>&1 ;;
    webp)
      # sips doesn't support webp natively — fall back to warning
      if [[ "$INPUT_EXT" != "webp" ]]; then
        echo "Warning: sips cannot convert to WebP. Install ImageMagick for WebP support." >&2
        echo "Keeping original format." >&2
      fi
      ;;
  esac
fi

# Get output file info
if [[ -f "$OUTPUT_FILE" ]]; then
  FILE_SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat --format=%s "$OUTPUT_FILE" 2>/dev/null || echo "unknown")

  if $JSON_MODE; then
    jq -n \
      --arg status "exported" \
      --arg input "$INPUT" \
      --arg output "$OUTPUT_FILE" \
      --arg format "$FORMAT" \
      --arg size "$FILE_SIZE" \
      --arg tool "$TOOL" \
      '{status: $status, input: $input, output: $output, format: $format, size_bytes: $size, tool: $tool}'
  else
    echo "Exported: $OUTPUT_FILE"
    echo "Format: $FORMAT"
    echo "Size: $FILE_SIZE bytes"
    if [[ -n "$WIDTH" || -n "$HEIGHT" ]]; then
      echo "Resized: ${WIDTH:-auto}x${HEIGHT:-auto}"
    fi
  fi
else
  echo "Error: Export failed — output file not created." >&2
  exit 1
fi
