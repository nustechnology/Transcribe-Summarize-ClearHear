#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODEL_NAME="sherpa-onnx-streaming-zipformer-ar_en_id_ja_ru_th_vi_zh-2025-02-10"
MODEL_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/${MODEL_NAME}.tar.bz2"
ASSETS_DIR="$ROOT_DIR/assets/${MODEL_NAME}"

if [[ -f "$ASSETS_DIR/tokens.txt" ]]; then
  echo "Sherpa model already present at $ASSETS_DIR"
  exit 0
fi

mkdir -p "$ROOT_DIR/assets"
TMP_ARCHIVE="$(mktemp -t sherpa-model.XXXXXX.tar.bz2)"

cleanup() {
  rm -f "$TMP_ARCHIVE"
}
trap cleanup EXIT

echo "Downloading $MODEL_NAME..."
curl -fL "$MODEL_URL" -o "$TMP_ARCHIVE"

echo "Extracting to assets/..."
tar -xjf "$TMP_ARCHIVE" -C "$ROOT_DIR/assets"

echo "Done. Model files:"
ls -lh "$ASSETS_DIR"
