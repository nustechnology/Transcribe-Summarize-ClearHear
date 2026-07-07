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
import urllib.error
import urllib.request


def main() -> int:
    pub_cache = pathlib.Path(os.environ.get("PUB_CACHE", pathlib.Path.home() / ".pub-cache"))
    project_root = pathlib.Path(__file__).resolve().parents[1]
    third_party_llama = project_root / "third_party" / "llama.cpp"
    upstream_base = os.environ.get(
        "LLAMA_UPSTREAM_BASE",
        "https://raw.githubusercontent.com/ggml-org/llama.cpp/master",
    ).rstrip("/")
    marker = "PATCHED_CLEARHEAR_ANDROID_LLAMA_H"

    plugin_dirs = sorted(pub_cache.glob("hosted/pub.dev/flutter_llama-*"))
    if not plugin_dirs:
        print("No flutter_llama package found in pub-cache. Run 'flutter pub get' first.")
        return 0

    # flutter_llama expects <plugin>/llama.cpp to exist, but pub.dev can ship it
    # as a missing/broken symlink. Ensure a local copy is always available.
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
        if not plugin_llama.exists():
            os.symlink(third_party_llama, plugin_llama, target_is_directory=True)
            print(f"Linked: {plugin_llama} -> {third_party_llama}")
        plugin_roots.append(plugin_llama)

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
