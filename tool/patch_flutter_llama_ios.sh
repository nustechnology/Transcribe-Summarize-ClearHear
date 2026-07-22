#!/usr/bin/env bash
# Patches flutter_llama Swift C-string bridge after `flutter pub get`.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "${SCRIPT_DIR}/patch_flutter_llama_ios.py" "$@"
