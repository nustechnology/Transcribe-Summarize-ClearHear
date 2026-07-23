#!/usr/bin/env python3
"""Patch flutter_llama Swift bridge for Apple platforms.

flutter_llama 1.1.2 declares C bridge parameters as Swift String, but the C++
functions expect const char*. Passing String directly causes SIGSEGV inside
llama_init_model when NSLog reads the invalid pointer.

Idempotent — safe to run multiple times.
"""
from __future__ import annotations

import pathlib
import sys

MARKER = "PATCHED_FOR_CLEARHEAR_SWIFT_CSTRING"
MARKER_V1 = "PATCHED_FOR_CLEARHEAR_SWIFT_STRING"

OLD_LOAD_CALL = """            let success = llama_init_model(
                modelPath,
                Int32(nThreads),
                Int32(nGpuLayers),
                Int32(contextSize),
                Int32(batchSize),
                useGpu,
                verbose
            )"""

NEW_LOAD_CALL = """            // PATCHED_FOR_CLEARHEAR_SWIFT_CSTRING
            let success = modelPath.withCString { cPath in
                llama_init_model(
                    cPath,
                    Int32(nThreads),
                    Int32(nGpuLayers),
                    Int32(contextSize),
                    Int32(batchSize),
                    useGpu,
                    verbose
                )
            }"""

OLD_GENERATE_CALL = """            let success = llama_generate(
                prompt,
                Float(temperature),
                Float(topP),
                Int32(topK),
                Int32(maxTokens),
                Float(repeatPenalty),
                &outputBuffer,
                Int32(outputBuffer.count),
                &tokensGenerated
            )"""

NEW_GENERATE_CALL = """            let success = prompt.withCString { cPrompt in
                llama_generate(
                    cPrompt,
                    Float(temperature),
                    Float(topP),
                    Int32(topK),
                    Int32(maxTokens),
                    Float(repeatPenalty),
                    &outputBuffer,
                    Int32(outputBuffer.count),
                    &tokensGenerated
                )
            }"""

OLD_STREAM_INIT = """            llama_generate_stream_init(
                prompt,
                Float(temperature),
                Float(topP),
                Int32(topK),
                Int32(maxTokens),
                Float(repeatPenalty)
            )"""

NEW_STREAM_INIT = """            prompt.withCString { cPrompt in
                llama_generate_stream_init(
                    cPrompt,
                    Float(temperature),
                    Float(topP),
                    Int32(topK),
                    Int32(maxTokens),
                    Float(repeatPenalty)
                )
            }"""


def patch_swift(content: str) -> str:
    # Repair files produced by an older version of this patch, which changed
    # only the first `_ prompt: String` declaration.
    stream_declaration = """@_silgen_name("llama_generate_stream_init")
func llama_generate_stream_init(
    _ prompt: String,"""
    fixed_stream_declaration = """@_silgen_name("llama_generate_stream_init")
func llama_generate_stream_init(
    _ prompt: UnsafePointer<CChar>,"""
    if MARKER in content or MARKER_V1 in content:
        if stream_declaration in content:
            content = content.replace(
                stream_declaration,
                fixed_stream_declaration,
                1,
            )
        return content

    replacements = [
        ("_ modelPath: String,", "_ modelPath: UnsafePointer<CChar>,"),
        (
            """@_silgen_name("llama_generate")
func llama_generate(
    _ prompt: String,""",
            """@_silgen_name("llama_generate")
func llama_generate(
    _ prompt: UnsafePointer<CChar>,""",
        ),
        (
            stream_declaration,
            fixed_stream_declaration,
        ),
        (OLD_LOAD_CALL, NEW_LOAD_CALL),
        (OLD_GENERATE_CALL, NEW_GENERATE_CALL),
        (OLD_STREAM_INIT, NEW_STREAM_INIT),
    ]

    for old, new in replacements:
        if old not in content:
            raise RuntimeError(
                "flutter_llama Swift bridge patch failed: expected block not found.\n"
                f"Missing:\n{old[:120]}..."
            )
        content = content.replace(old, new, 1)

    return content


def find_swift_files(project_root: pathlib.Path) -> list[pathlib.Path]:
    candidates: list[pathlib.Path] = []
    seen: set[pathlib.Path] = set()

    def add(path: pathlib.Path) -> None:
        resolved = path.resolve()
        if resolved.is_file() and resolved not in seen:
            seen.add(resolved)
            candidates.append(path)

    for subdir in ("ios", "macos"):
        add(
            project_root
            / subdir
            / ".symlinks"
            / "plugins"
            / "flutter_llama"
            / "ios"
            / "Classes"
            / "FlutterLlamaPlugin.swift"
        )

    pub_cache = pathlib.Path.home() / ".pub-cache" / "hosted" / "pub.dev"
    for swift_path in sorted(pub_cache.glob("flutter_llama-*/ios/Classes/FlutterLlamaPlugin.swift")):
        add(swift_path)

    return candidates


def main() -> int:
    project_root = pathlib.Path(__file__).resolve().parents[1]
    swift_files = find_swift_files(project_root)
    if not swift_files:
        print("No flutter_llama FlutterLlamaPlugin.swift found. Run 'flutter pub get' first.")
        return 1

    patched_any = False
    for swift_path in swift_files:
        original = swift_path.read_text(encoding="utf-8")
        updated = patch_swift(original)
        if updated == original:
            print(f"Already patched: {swift_path}")
            continue

        swift_path.write_text(updated, encoding="utf-8")
        print(f"Patched: {swift_path}")
        patched_any = True

    if not patched_any:
        print("flutter_llama Swift bridge already patched.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
