#!/bin/bash
# Download sherpa-onnx model files (ASR + speaker diarization) from HuggingFace.
# Run this from the project root. Files go to assets/models/{model_id}/
set -euo pipefail

download_model() {
  local model_id="$1"
  local hf_base="$2"
  shift 2
  local files=("$@")
  local assets_dir="assets/models/${model_id}"

  mkdir -p "$assets_dir"

  for file in "${files[@]}"; do
    local url="${hf_base}/${file}"
    local dest="${assets_dir}/${file}"
    if [ -f "$dest" ]; then
      local size=$(stat -f%z "$dest" 2>/dev/null || stat -c%s "$dest" 2>/dev/null)
      if [ "$size" -gt 1024 ]; then
        echo "SKIP $file (already exists, $size bytes)"
        continue
      fi
    fi
    echo "DOWNLOAD $file ..."
    curl -L --retry 3 --retry-delay 5 -o "$dest" "$url"
    echo "OK $file ($(stat -f%z "$dest" 2>/dev/null || stat -c%s "$dest") bytes)"
  done

  echo "Total size for $model_id: $(du -sh "$assets_dir" | cut -f1)"
}

# Streaming ASR (Zipformer2 English).
download_model \
  "sherpa-onnx-streaming-zipformer-en-2023-06-26" \
  "https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/resolve/main" \
  "encoder-epoch-99-avg-1-chunk-16-left-64.int8.onnx" \
  "decoder-epoch-99-avg-1-chunk-16-left-64.int8.onnx" \
  "joiner-epoch-99-avg-1-chunk-16-left-64.int8.onnx" \
  "tokens.txt"

# Speaker diarization: 3D-Speaker embedding extractor (per-utterance
# embedding + online nearest-speaker matching; no separate VAD/segmentation
# model needed since the ASR recognizer's endpoint detection already
# produces segment boundaries).
download_model \
  "speaker-embedding-models" \
  "https://huggingface.co/csukuangfj/speaker-embedding-models/resolve/main" \
  "3dspeaker_speech_campplus_sv_zh_en_16k-common_advanced.onnx"

echo ""
echo "Done. Model files are in assets/models/"
echo "Now rebuild the app: fvm flutter run"
