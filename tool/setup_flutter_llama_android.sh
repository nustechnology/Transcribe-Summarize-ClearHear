#!/usr/bin/env bash
# Patches flutter_llama's vendored llama.cpp headers for Android after `flutter pub get`.
# flutter_llama 1.1.2 ships newer src/ than its public headers, which breaks NDK builds.
# Idempotent — safe to run multiple times.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "${SCRIPT_DIR}/setup_flutter_llama_android.py" "$@"
