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
            gradle_patched = False

            # flutter_llama 1.1.2 defaults to arm64-v8a only, but devices may be 32-bit.
            # Expand ABI list to include armeabi-v7a so native libs are built for both.
            abi_single = "abiFilters 'arm64-v8a'"
            abi_both = "abiFilters 'arm64-v8a', 'armeabi-v7a'"
            if abi_single in gradle_text and abi_both not in gradle_text:
                gradle_text = gradle_text.replace(abi_single, abi_both, 1)
                gradle_patched = True
                print(
                    f"Patched: {android_build_gradle} "
                    f"(abiFilters arm64-v8a -> arm64-v8a + armeabi-v7a)"
                )

            if cmake_version_old in gradle_text:
                gradle_text = gradle_text.replace(cmake_version_old, cmake_version_new, 1)
                gradle_patched = True
                print(
                    f"Patched: {android_build_gradle} "
                    f"(cmake {cmake_version_old} -> {cmake_version_new})"
                )
            elif cmake_version_new not in gradle_text:
                print(
                    f"WARNING: cmake version pin not found in {android_build_gradle}; "
                    f"CMake {cmake_version_new} override was NOT applied."
                )

            if gradle_patched:
                android_build_gradle.write_text(gradle_text, encoding="utf-8")

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

        # Prevent the companion object from silently swallowing native-load errors.
        # Without this, library-load failures produce a cryptic UnsatisfiedLinkError
        # much later (e.g. on the summary screen) instead of failing fast at startup.
        plugin_kt = (
            plugin_dir
            / "android"
            / "src"
            / "main"
            / "kotlin"
            / "net"
            / "nativemind"
            / "flutter_llama"
            / "FlutterLlamaPlugin.kt"
        )
        kt_marker = "PATCHED_CLEARHEAR_FAILFAST_COMPANION"
        if plugin_kt.is_file():
            kt_text = plugin_kt.read_text(encoding="utf-8")
            if kt_marker not in kt_text:
                kt_old = (
                    '            } catch (e: UnsatisfiedLinkError) {\n'
                    '                Log.e(TAG, "Failed to load native libraries: ${e.message}")\n'
                    '            }'
                )
                kt_new = (
                    '            // {kt_marker}\n'
                    '            }} catch (e: UnsatisfiedLinkError) {{\n'
                    '                Log.e(TAG, "Failed to load native libraries: ${{e.message}}", e)\n'
                    '                throw RuntimeException(\n'
                    '                    "FlutterLlamaPlugin cannot load native libraries "\n'
                    '                        + "(device ABI: ${{android.os.Build.SUPPORTED_ABIS.joinToString()}}). "\n'
                    '                        + "Required: arm64-v8a or armeabi-v7a.",\n'
                    '                    e,\n'
                    '                )\n'
                    '            }}'.format(kt_marker=kt_marker)
                )
                if kt_old in kt_text:
                    plugin_kt.write_text(kt_text.replace(kt_old, kt_new, 1), encoding="utf-8")
                    print(f"Patched: {plugin_kt} (fail-fast companion init)")
                else:
                    print(
                        f"WARNING: companion-init anchor not found in {plugin_kt}; "
                        "fail-fast patch was NOT applied."
                    )

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

        # sgemm.cpp uses ARM FP16 intrinsics (vld1q_f16) that only exist on
        # AArch64.  Without the guard the project fails to compile for armeabi-v7a.
        sgemm_cpp = root / "ggml" / "src" / "ggml-cpu" / "llamafile" / "sgemm.cpp"
        sgemm_marker = "PATCHED_CLEARHEAR_ARM_FP16_GUARD"
        sgemm_marker_v2 = "PATCHED_CLEARHEAR_ARM_FP16_GUARD_V2"
        sgemm_marker_v3 = "PATCHED_CLEARHEAR_ARM_FP16_GUARD_V3"
        if sgemm_cpp.is_file():
            sgemm_text = sgemm_cpp.read_text(encoding="utf-8")

            upgrade_applied = False
            # v1 -> v3: replace too-strict __ARM_FEATURE_FP16_VECTOR_ARITHMETIC with __aarch64__
            if sgemm_marker in sgemm_text and sgemm_marker_v2 not in sgemm_text and sgemm_marker_v3 not in sgemm_text:
                sgemm_text = sgemm_text.replace(
                    '#if !defined(_MSC_VER) && defined(__ARM_FEATURE_FP16_VECTOR_ARITHMETIC) '
                    f'// {sgemm_marker}\n',
                    '#if !defined(_MSC_VER) && defined(__aarch64__) '
                    f'// {sgemm_marker_v2}\n',
                    1,
                )
                upgrade_applied = True
                print(f"Upgraded: {sgemm_cpp} (FP16 guard v1 -> v2)")

            if sgemm_marker_v3 not in sgemm_text:
                if sgemm_marker_v2 in sgemm_text:
                    # v2 -> v3: add armeabi-v7a fallback with GGML_CPU_FP16_TO_FP32
                    sgemm_v2_old = (
                        '#if !defined(_MSC_VER) && defined(__aarch64__) '
                        f'// {sgemm_marker_v2}\n'
                        'template <> inline float16x8_t load(const ggml_fp16_t *p) {\n'
                        '    return vld1q_f16((const float16_t *)p);\n'
                        '}\n'
                        'template <> inline float32x4_t load(const ggml_fp16_t *p) {\n'
                        '    return vcvt_f32_f16(vld1_f16((const float16_t *)p));\n'
                        '}\n'
                        '#endif // _MSC_VER\n'
                    )
                    sgemm_v2_new = (
                        '#if !defined(_MSC_VER) && defined(__aarch64__) '
                        f'// {sgemm_marker_v3}\n'
                        'template <> inline float16x8_t load(const ggml_fp16_t *p) {\n'
                        '    return vld1q_f16((const float16_t *)p);\n'
                        '}\n'
                        'template <> inline float32x4_t load(const ggml_fp16_t *p) {\n'
                        '    return vcvt_f32_f16(vld1_f16((const float16_t *)p));\n'
                        '}\n'
                        '#elif !defined(_MSC_VER) && defined(__ARM_NEON) && !defined(__aarch64__)\n'
                        'template <> inline float32x4_t load(const ggml_fp16_t *p) {\n'
                        '    float tmp[4];\n'
                        '    for (int i = 0; i < 4; i++) {\n'
                        '        tmp[i] = GGML_CPU_FP16_TO_FP32(p[i]);\n'
                        '    }\n'
                        '    return vld1q_f32(tmp);\n'
                        '}\n'
                        '#endif // _MSC_VER\n'
                    )
                    if sgemm_v2_old in sgemm_text:
                        sgemm_text = sgemm_text.replace(sgemm_v2_old, sgemm_v2_new, 1)
                        upgrade_applied = True
                        print(f"Upgraded: {sgemm_cpp} (FP16 guard v2 -> v3)")
                    else:
                        print(f"WARNING: v2 anchor not found in {sgemm_cpp}; v2->v3 upgrade skipped")
                elif sgemm_marker not in sgemm_text:
                    # fresh patch v3 from original
                    sgemm_orig_old = (
                        '#if !defined(_MSC_VER)\n'
                        '// FIXME: this should check for __ARM_FEATURE_FP16_VECTOR_ARITHMETIC\n'
                        'template <> inline float16x8_t load(const ggml_fp16_t *p) {\n'
                        '    return vld1q_f16((const float16_t *)p);\n'
                        '}\n'
                        'template <> inline float32x4_t load(const ggml_fp16_t *p) {\n'
                        '    return vcvt_f32_f16(vld1_f16((const float16_t *)p));\n'
                        '}\n'
                        '#endif // _MSC_VER\n'
                    )
                    sgemm_orig_new = (
                        '// PATCHED_CLEARHEAR_ARM_FP16_ORIG_FIXME_ADDRESSED\n'
                        '#if !defined(_MSC_VER) && defined(__aarch64__) '
                        f'// {sgemm_marker_v3}\n'
                        'template <> inline float16x8_t load(const ggml_fp16_t *p) {\n'
                        '    return vld1q_f16((const float16_t *)p);\n'
                        '}\n'
                        'template <> inline float32x4_t load(const ggml_fp16_t *p) {\n'
                        '    return vcvt_f32_f16(vld1_f16((const float16_t *)p));\n'
                        '}\n'
                        '#elif !defined(_MSC_VER) && defined(__ARM_NEON) && !defined(__aarch64__)\n'
                        'template <> inline float32x4_t load(const ggml_fp16_t *p) {\n'
                        '    float tmp[4];\n'
                        '    for (int i = 0; i < 4; i++) {\n'
                        '        tmp[i] = GGML_CPU_FP16_TO_FP32(p[i]);\n'
                        '    }\n'
                        '    return vld1q_f32(tmp);\n'
                        '}\n'
                        '#endif // _MSC_VER\n'
                    )
                    if sgemm_orig_old in sgemm_text:
                        sgemm_text = sgemm_text.replace(sgemm_orig_old, sgemm_orig_new, 1)
                        upgrade_applied = True
                        print(f"Patched: {sgemm_cpp} (armeabi-v7a FP16 guard v3)")
                    else:
                        print(
                            f"WARNING: sgemm anchor not found in {sgemm_cpp}; "
                            "armeabi-v7a FP16 guard was NOT applied."
                        )

            if upgrade_applied:
                sgemm_cpp.write_text(sgemm_text, encoding="utf-8")

        cxx_dir = root.parent / "android" / ".cxx"
        if cxx_dir.exists():
            shutil.rmtree(cxx_dir, ignore_errors=True)
            print(f"Cleared CMake cache: {cxx_dir}")

    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
