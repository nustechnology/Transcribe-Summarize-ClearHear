#!/usr/bin/env python3
"""Patches flutter_llama's vendored llama.cpp headers for Android after flutter pub get.

flutter_llama 1.1.2 ships newer src/ than its public headers, which breaks NDK builds.
Idempotent — safe to run multiple times.
"""
from __future__ import annotations

import os
import pathlib
import shutil
import sys
import urllib.error
import urllib.request


def main() -> int:
    pub_cache = pathlib.Path(os.environ.get("PUB_CACHE", pathlib.Path.home() / ".pub-cache"))
    upstream_base = os.environ.get(
        "LLAMA_UPSTREAM_BASE",
        "https://raw.githubusercontent.com/ggml-org/llama.cpp/master",
    ).rstrip("/")
    marker = "PATCHED_CLEARHEAR_ANDROID_LLAMA_H"

    plugin_roots = sorted(pub_cache.glob("hosted/pub.dev/flutter_llama-*/llama.cpp"))
    if not plugin_roots:
        print("No flutter_llama llama.cpp tree found in pub-cache. Run 'flutter pub get' first.")
        return 0

    def fetch(path: str) -> str:
        url = f"{upstream_base}/{path}"
        try:
            return urllib.request.urlopen(url, timeout=60).read().decode("utf-8")
        except urllib.error.HTTPError as exc:
            raise RuntimeError(f"Failed to fetch {url}: {exc}") from exc

    def upstream_path(header_name: str, target_dir_name: str) -> str:
        if header_name.startswith("llama"):
            return f"include/{header_name}"
        if target_dir_name == "include":
            return f"ggml/include/{header_name}"
        return f"ggml/include/{header_name}"

    for root in plugin_roots:
        for rel_dir in ("include", "ggml/include"):
            target_dir = root / rel_dir
            if not target_dir.is_dir():
                continue

            for header in sorted(target_dir.glob("*.h")):
                rel_path = upstream_path(header.name, rel_dir)
                upstream = fetch(rel_path)
                if header.name == "llama.h":
                    upstream = f"// {marker}\n{upstream}"
                header.write_text(upstream, encoding="utf-8")
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
