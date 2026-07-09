#!/usr/bin/env python3
"""Patches flutter_llama's vendored llama.cpp headers for Android after flutter pub get.

flutter_llama 1.1.2 ships newer src/ than its public headers, which breaks NDK builds.
Idempotent — safe to run multiple times.
"""
from __future__ import annotations

import os
import pathlib
import shutil
import subprocess
import sys


def ensure_llama_tree(source: pathlib.Path, destination: pathlib.Path) -> None:
    if destination.is_symlink():
        destination.unlink()
    if destination.exists():
        return
    print(f"Bootstrapping {destination} from {source} ...")
    shutil.copytree(source, destination, symlinks=True)


def main() -> int:
    pub_cache = pathlib.Path(os.environ.get("PUB_CACHE", pathlib.Path.home() / ".pub-cache"))
    project_root = pathlib.Path(__file__).resolve().parents[1]
    third_party_llama = project_root / "third_party" / "llama.cpp"
    marker = "PATCHED_CLEARHEAR_ANDROID_LLAMA_H"
    cmake_marker = "PATCHED_CLEARHEAR_DISABLE_VULKAN"
    # flutter_llama pins CMake 3.18.1; synced llama.cpp needs 3.19+.
    cmake_version_old = "version = '3.18.1'"
    cmake_version_new = "version = '3.22.1'"
    cmake_gpu_block = """# GPU Acceleration for Android devices
# Vulkan for modern devices (Android 7.0+)
# OpenCL as fallback for older devices
# CPU backend with NEON as last resort

# Try to enable Vulkan (best performance on modern devices)
find_library(vulkan-lib vulkan)
if(vulkan-lib)
    set(GGML_VULKAN ON CACHE BOOL "" FORCE)
    message(STATUS "🚀 Vulkan GPU acceleration ENABLED")
    message(STATUS "   Supported: Adreno 5xx+, Mali-G71+, Samsung Exynos 9+")
    message(STATUS "   Expected: 4-8x faster than CPU")
else()
    # Try OpenCL as fallback
    find_library(opencl-lib OpenCL)
    if(opencl-lib)
        set(GGML_OPENCL ON CACHE BOOL "" FORCE)
        message(STATUS "⚡ OpenCL GPU acceleration ENABLED (fallback)")
        message(STATUS "   Supported: Most Android devices with GPU")
        message(STATUS "   Expected: 2-5x faster than CPU")
    else()
        message(STATUS "⚡ Using optimized CPU backend with ARM NEON")
        message(STATUS "   GPU libraries not found, falling back to CPU")
    endif()
endif()"""
    cmake_cpu_block = f"""# {cmake_marker}
# Upstream llama.cpp Vulkan builds need host SPIRV-Headers (not in the Android SDK).
# Use the ARM NEON CPU backend until GPU build deps are vendored.
message(STATUS "⚡ Using optimized CPU backend with ARM NEON")
message(STATUS "   Vulkan/OpenCL disabled for Android NDK compatibility")"""

    plugin_dirs = sorted(pub_cache.glob("hosted/pub.dev/flutter_llama-*"))
    if not plugin_dirs:
        print("No flutter_llama package found in pub-cache. Run 'flutter pub get' first.")
        return 0

    # flutter_llama expects <plugin>/llama.cpp to exist, but pub.dev can ship it
    # as a missing/broken symlink. Keep a local upstream checkout for header sync.
    if not third_party_llama.exists():
        third_party_llama.parent.mkdir(parents=True, exist_ok=True)
        clone_cmd = [
            "git",
            "clone",
            "--depth",
            "1",
            "https://github.com/ggml-org/llama.cpp.git",
            str(third_party_llama),
        ]
        print(f"Bootstrapping llama.cpp at {third_party_llama} ...")
        try:
            subprocess.run(clone_cmd, check=True)
        except (subprocess.CalledProcessError, FileNotFoundError) as exc:
            raise RuntimeError(
                "Check network access and that git is installed, then rerun "
                "tool/setup_flutter_llama_android.py."
            ) from exc

    plugin_roots: list[pathlib.Path] = []
    for plugin_dir in plugin_dirs:
        plugin_llama = plugin_dir / "llama.cpp"
        if plugin_llama.is_symlink() and not plugin_llama.exists():
            plugin_llama.unlink()
        ensure_llama_tree(third_party_llama, plugin_llama)
        plugin_roots.append(plugin_llama)

        android_build_gradle = plugin_dir / "android" / "build.gradle"
        if android_build_gradle.is_file():
            gradle_text = android_build_gradle.read_text(encoding="utf-8")
            if cmake_version_old in gradle_text:
                android_build_gradle.write_text(
                    gradle_text.replace(cmake_version_old, cmake_version_new, 1),
                    encoding="utf-8",
                )
                print(
                    f"Patched: {android_build_gradle} "
                    f"(cmake {cmake_version_old} -> {cmake_version_new})"
                )
            elif cmake_version_new not in gradle_text:
                print(
                    f"WARNING: cmake version pin not found in {android_build_gradle}; "
                    f"CMake {cmake_version_new} override was NOT applied."
                )

        cmake_lists = plugin_dir / "android" / "src" / "main" / "cpp" / "CMakeLists.txt"
        if cmake_lists.is_file():
            cmake_text = cmake_lists.read_text(encoding="utf-8")
            if cmake_marker not in cmake_text:
                if cmake_gpu_block not in cmake_text:
                    print(
                        f"WARNING: GPU CMake anchor not found in {cmake_lists}; "
                        "Vulkan disable patch was NOT applied."
                    )
                else:
                    cmake_lists.write_text(
                        cmake_text.replace(cmake_gpu_block, cmake_cpu_block, 1),
                        encoding="utf-8",
                    )
                    print(f"Patched: {cmake_lists} (CPU-only backend)")

    def read_upstream(path: str) -> str:
        local_path = third_party_llama / path
        if not local_path.is_file():
            raise RuntimeError(
                f"Missing upstream file: {local_path}\n"
                f"Remove {third_party_llama} and rerun this script to re-clone llama.cpp."
            )
        return local_path.read_text(encoding="utf-8")

    for root in plugin_roots:
        include_dir = root / "include"
        ggml_include_dir = root / "ggml" / "include"

        if include_dir.is_dir():
            for header in sorted(include_dir.glob("*.h")):
                if not header.name.startswith("llama"):
                    continue
                rel_path = f"include/{header.name}"
                upstream = read_upstream(rel_path)
                if header.name == "llama.h":
                    upstream = "\n".join(
                        line for line in upstream.splitlines() if line != f"// {marker}"
                    )
                    if marker not in upstream:
                        upstream = f"// {marker}\n{upstream}"
                header.write_text(upstream, encoding="utf-8")
                print(f"Synced: {header} <- {rel_path}")

            for duplicate in sorted(include_dir.glob("*.h")):
                if duplicate.name.startswith("llama"):
                    continue
                duplicate.unlink()
                print(f"Removed duplicate header: {duplicate}")

        if ggml_include_dir.is_dir():
            for header in sorted(ggml_include_dir.glob("*.h")):
                rel_path = f"ggml/include/{header.name}"
                header.write_text(read_upstream(rel_path), encoding="utf-8")
                print(f"Synced: {header} <- {rel_path}")

        context_cpp = root / "src" / "llama-context.cpp"
        if context_cpp.exists():
            text = context_cpp.read_text(encoding="utf-8")
            updated = text
            if "PATCHED_CLEARHEAR_ANDROID_CONTEXT_DEFAULTS" not in text:
                updated = updated.replace(
                    "        /*.sampler                     =*/ nullptr,\n"
                    "        /*.n_sampler                   =*/ 0,",
                    "        // PATCHED_CLEARHEAR_ANDROID_CONTEXT_DEFAULTS\n"
                    "        /*.samplers                    =*/ nullptr,\n"
                    "        /*.n_samplers                  =*/ 0,",
                    1,
                )
                if updated == text:
                    print(
                        f"WARNING: anchor not found in {context_cpp}; "
                        "llama-context.cpp patch was NOT applied."
                    )
            if updated != text:
                context_cpp.write_text(updated, encoding="utf-8")
                print(f"Patched: {context_cpp}")

        cxx_dir = root.parent / "android" / ".cxx"
        if cxx_dir.exists():
            shutil.rmtree(cxx_dir, ignore_errors=True)
            print(f"Cleared CMake cache: {cxx_dir}")

    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
