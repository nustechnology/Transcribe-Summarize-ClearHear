#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_CONFIG="$ROOT_DIR/.dart_tool/package_config.json"
VENDOR_DIR="$ROOT_DIR/third_party/llama.cpp"
CMAKE_VERSION="3.22.1"
NDK_VERSION="29.0.13113456"

if [[ ! -f "$PACKAGE_CONFIG" ]]; then
  echo "Run 'flutter pub get' before building Android."
  exit 1
fi

FLUTTER_LLAMA_PATH="$(
  python3 - <<'PY' "$PACKAGE_CONFIG"
import json
import sys
from pathlib import Path

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)

for package in data.get("packages", []):
    if package.get("name") == "flutter_llama":
        uri = package.get("rootUri", "")
        if uri.startswith("file://"):
            print(uri.replace("file://", ""))
        else:
            print((Path(sys.argv[1]).parent / uri).resolve())
        break
PY
)"

if [[ -z "$FLUTTER_LLAMA_PATH" || ! -d "$FLUTTER_LLAMA_PATH" ]]; then
  echo "flutter_llama not in dependencies; skipping Android llama.cpp setup."
  exit 0
fi

if [[ ! -f "$VENDOR_DIR/CMakeLists.txt" ]]; then
  echo "Fetching llama.cpp into third_party/..."
  mkdir -p "$(dirname "$VENDOR_DIR")"
  git clone --depth 1 https://github.com/ggml-org/llama.cpp.git "$VENDOR_DIR"
fi

PLUGIN_LLAMA_DIR="$FLUTTER_LLAMA_PATH/llama.cpp"
rm -rf "$PLUGIN_LLAMA_DIR"
ln -sf "$VENDOR_DIR" "$PLUGIN_LLAMA_DIR"
echo "llama.cpp linked for flutter_llama at: $PLUGIN_LLAMA_DIR"

BUILD_GRADLE="$FLUTTER_LLAMA_PATH/android/build.gradle"
if [[ ! -f "$BUILD_GRADLE" ]]; then
  echo "flutter_llama android/build.gradle not found."
  exit 1
fi

python3 - <<'PY' "$BUILD_GRADLE" "$CMAKE_VERSION" "$NDK_VERSION"
import pathlib
import re
import sys

build_gradle = pathlib.Path(sys.argv[1])
cmake_version = sys.argv[2]
ndk_version = sys.argv[3]
text = build_gradle.read_text(encoding="utf-8")

text = re.sub(
    r"version = '3\.18\.1'",
    f"version = '{cmake_version}'",
    text,
)

if "ndkVersion" not in text:
    text = text.replace(
        "compileSdk = 36",
        f'compileSdk = 36\n\n    ndkVersion = "{ndk_version}"',
        1,
    )

if "GGML_VULKAN=OFF" not in text:
    text = text.replace(
        "'-DCMAKE_BUILD_TYPE=Release'",
        "'-DCMAKE_BUILD_TYPE=Release',\n"
        "                          '-DGGML_VULKAN=OFF'",
        1,
    )

build_gradle.write_text(text, encoding="utf-8")
print(f"Patched flutter_llama Android build: CMake {cmake_version}, NDK {ndk_version}")
PY

CMAKE_LISTS="$FLUTTER_LLAMA_PATH/android/src/main/cpp/CMakeLists.txt"
python3 - <<'PY' "$CMAKE_LISTS"
import pathlib
import re
import sys

cmake_lists = pathlib.Path(sys.argv[1])
text = cmake_lists.read_text(encoding="utf-8")

cpu_only_block = """# GPU backends disabled: Vulkan needs SPIRV-Headers unavailable in NDK cross-compile.
set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
set(GGML_OPENCL OFF CACHE BOOL "" FORCE)
message(STATUS "Using optimized CPU backend with ARM NEON (GPU disabled for Android build)")
"""

pattern = re.compile(
    r"# GPU Acceleration for Android devices.*?message\(STATUS \"   Works on: All ARM64 Android devices\"\)\n",
    re.DOTALL,
)
if pattern.search(text):
    text = pattern.sub(cpu_only_block, text, count=1)
else:
    print("CMakeLists.txt GPU block not found; skipping CMake patch.")

text = re.sub(
    r"\n# Link GPU libraries if found\nif\(vulkan-lib\).*?endif\(\)\n",
    "\n",
    text,
    count=1,
    flags=re.DOTALL,
)

cmake_lists.write_text(text, encoding="utf-8")
print("Patched flutter_llama CMakeLists.txt to use CPU-only backend.")
PY

rm -rf "$FLUTTER_LLAMA_PATH/android/.cxx"
echo "Cleared flutter_llama CMake cache."
