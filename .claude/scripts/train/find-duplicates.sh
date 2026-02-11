#!/usr/bin/env bash
# find-duplicates.sh — Detect near-duplicate images in a training dataset
# Usage: find-duplicates.sh <directory> [--threshold 6] [--json]
#
# Uses perceptual hashing (dHash) to find visually similar images.
# Requires: Python 3 with Pillow (pip install Pillow)

set -euo pipefail

# Defaults
DATASET_DIR=""
THRESHOLD=6
JSON_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --threshold|-t) THRESHOLD="$2"; shift 2 ;;
    --json) JSON_MODE=true; shift ;;
    --help|-h)
      echo "Usage: find-duplicates.sh <directory> [OPTIONS]"
      echo ""
      echo "Detect near-duplicate images using perceptual hashing."
      echo ""
      echo "Arguments:"
      echo "  directory        Path to image directory"
      echo "  --threshold N    Hamming distance threshold (default: 6, lower = stricter)"
      echo "  --json           Output in JSON format"
      echo ""
      echo "Requires: Python 3 with Pillow (pip install Pillow)"
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

# Check Python and Pillow
if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: Python 3 not found. Install Python 3 to use duplicate detection." >&2
  exit 1
fi

if ! python3 -c "from PIL import Image" 2>/dev/null; then
  echo "Error: Pillow not installed." >&2
  echo "Install with: pip install Pillow" >&2
  echo "  or: pip3 install Pillow" >&2
  exit 1
fi

# Run Python duplicate detection
python3 - "$DATASET_DIR" "$THRESHOLD" "$JSON_MODE" << 'PYEOF'
import sys
import os
import json
from PIL import Image

def dhash(image_path, hash_size=8):
    """Compute difference hash (dHash) for an image."""
    try:
        img = Image.open(image_path).convert('L').resize((hash_size + 1, hash_size), Image.Resampling.LANCZOS)
        pixels = list(img.getdata())
        width = hash_size + 1
        hash_bits = []
        for row in range(hash_size):
            for col in range(hash_size):
                left = pixels[row * width + col]
                right = pixels[row * width + col + 1]
                hash_bits.append(1 if left > right else 0)
        return int(''.join(str(b) for b in hash_bits), 2)
    except Exception:
        return None

def hamming_distance(hash1, hash2):
    """Count the number of differing bits between two hashes."""
    return bin(hash1 ^ hash2).count('1')

def main():
    dataset_dir = sys.argv[1]
    threshold = int(sys.argv[2])
    json_mode = sys.argv[3].lower() == 'true'

    extensions = {'.png', '.jpg', '.jpeg', '.webp', '.bmp', '.tiff', '.tif'}

    # Collect images
    images = []
    for f in sorted(os.listdir(dataset_dir)):
        ext = os.path.splitext(f)[1].lower()
        if ext in extensions:
            images.append(f)

    if not images:
        if json_mode:
            print(json.dumps({"total_images": 0, "duplicates": [], "message": "No images found"}))
        else:
            print("No images found in directory.")
        return

    # Compute hashes
    hashes = {}
    failed = []
    for img_name in images:
        img_path = os.path.join(dataset_dir, img_name)
        h = dhash(img_path)
        if h is not None:
            hashes[img_name] = h
        else:
            failed.append(img_name)

    # Find duplicates
    duplicates = []
    names = list(hashes.keys())
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            dist = hamming_distance(hashes[names[i]], hashes[names[j]])
            if dist <= threshold:
                similarity = round((1 - dist / 64) * 100, 1)
                duplicates.append({
                    "file_a": names[i],
                    "file_b": names[j],
                    "hamming_distance": dist,
                    "similarity_percent": similarity
                })

    # Sort by similarity (highest first)
    duplicates.sort(key=lambda x: x["similarity_percent"], reverse=True)

    if json_mode:
        result = {
            "total_images": len(images),
            "hashed": len(hashes),
            "failed": failed,
            "threshold": threshold,
            "duplicate_pairs": len(duplicates),
            "duplicates": duplicates
        }
        print(json.dumps(result, indent=2))
    else:
        print(f"=== Duplicate Detection Report ===")
        print(f"")
        print(f"Images scanned: {len(images)}")
        print(f"Successfully hashed: {len(hashes)}")
        if failed:
            print(f"Failed to hash: {len(failed)}")
            for f in failed:
                print(f"  - {f}")
        print(f"Threshold: Hamming distance <= {threshold}")
        print(f"")

        if not duplicates:
            print("No duplicates found.")
        else:
            print(f"Found {len(duplicates)} near-duplicate pair(s):")
            print(f"")
            for d in duplicates:
                print(f"  {d['file_a']}  <->  {d['file_b']}")
                print(f"    Similarity: {d['similarity_percent']}% (distance: {d['hamming_distance']})")
                print(f"")

            print("Why this matters:")
            print("  Training on duplicates makes the model memorize those")
            print("  specific images instead of learning your general style.")
            print("  Keep one from each pair, remove the other.")

if __name__ == "__main__":
    main()
PYEOF
