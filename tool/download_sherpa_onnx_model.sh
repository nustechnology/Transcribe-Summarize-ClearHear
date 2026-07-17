#!/bin/bash
# Download sherpa-onnx Zipformer2 English streaming model files from HuggingFace.
# Run this from the project root. Files go to assets/models/sherpa-onnx-{model_id}/
set -euo pipefail

MODEL_ID="sherpa-onnx-streaming-zipformer-en-2023-06-26"
HF_BASE="https://huggingface.co/csukuangfj/${MODEL_ID}/resolve/main"
ASSETS_DIR="assets/models/${MODEL_ID}"

FILES=(
  "encoder-epoch-99-avg-1-chunk-16-left-64.int8.onnx"
  "decoder-epoch-99-avg-1-chunk-16-left-64.int8.onnx"
  "joiner-epoch-99-avg-1-chunk-16-left-64.int8.onnx"
  "tokens.txt"
)

mkdir -p "$ASSETS_DIR"

for file in "${FILES[@]}"; do
  url="${HF_BASE}/${file}"
  dest="${ASSETS_DIR}/${file}"
  if [ -f "$dest" ]; then
    size=$(stat -f%z "$dest" 2>/dev/null || stat -c%s "$dest" 2>/dev/null)
    if [ "$size" -gt 1024 ]; then
      echo "SKIP $file (already exists, $size bytes)"
      continue
    fi
  fi
  echo "DOWNLOAD $file ..."
  curl -L --retry 3 --retry-delay 5 -o "$dest" "$url"
  echo "OK $file ($(stat -f%z "$dest" 2>/dev/null || stat -c%s "$dest") bytes)"
done

echo ""
echo "Done. Total size: $(du -sh "$ASSETS_DIR" | cut -f1)"
echo "Model files are in $ASSETS_DIR/"
echo "Now rebuild the app: fvm flutter run"
