#!/usr/bin/env bash
# Patches whisper_kit 0.3.0 native sources in pub-cache after `flutter pub get`.
# Idempotent — safe to run multiple times.
set -euo pipefail

PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"

python3 - "$PUB_CACHE" <<'PY'
import pathlib
import sys

pub_cache = pathlib.Path(sys.argv[1])
paths = sorted(pub_cache.glob("hosted/pub.dev/whisper_kit-*/src/main.cpp"))

if not paths:
    print("No whisper_kit src/main.cpp found in pub-cache. Run 'flutter pub get' first.")
    sys.exit(1)

MARKER = "// PATCHED_CLEARHEAR_ANDROID_NULL_CTX"
INIT_SNIPPET = f"""    // whisper init
    struct whisper_context *ctx = whisper_init_from_file(params.model.c_str());
    {MARKER}
    if (ctx == nullptr)
    {{
        jsonResult["@type"] = "error";
        jsonResult["message"] = "failed to initialize whisper context (model missing or invalid)";
        return jsonResult;
    }}"""

OLD_INIT = """    // whisper init
    struct whisper_context *ctx = whisper_init_from_file(params.model.c_str());"""

WAV_FAIL_SNIPPET = """        if (!drwav_init_file(&wav, fname_inp.c_str(), NULL))
        {
            whisper_free(ctx);
            jsonResult["@type"] = "error";
            jsonResult["message"] = " failed to open WAV file ";
            return jsonResult;
        }"""

OLD_WAV_FAIL = """        if (!drwav_init_file(&wav, fname_inp.c_str(), NULL))
        {
            jsonResult["@type"] = "error";
            jsonResult["message"] = " failed to open WAV file ";
            return jsonResult;
        }"""

CHANNEL_FAIL_OLD = """        if (wav.channels != 1 && wav.channels != 2)
        {
            jsonResult["@type"] = "error";
            jsonResult["message"] = "must be mono or stereo";
            return jsonResult;
        }"""

CHANNEL_FAIL_NEW = """        if (wav.channels != 1 && wav.channels != 2)
        {
            drwav_uninit(&wav);
            whisper_free(ctx);
            jsonResult["@type"] = "error";
            jsonResult["message"] = "must be mono or stereo";
            return jsonResult;
        }"""

RATE_FAIL_OLD = """        if (wav.sampleRate != WHISPER_SAMPLE_RATE)
        {
            jsonResult["@type"] = "error";
            jsonResult["message"] = "WAV file  must be 16 kHz";
            return jsonResult;
        }"""

RATE_FAIL_NEW = """        if (wav.sampleRate != WHISPER_SAMPLE_RATE)
        {
            drwav_uninit(&wav);
            whisper_free(ctx);
            jsonResult["@type"] = "error";
            jsonResult["message"] = "WAV file  must be 16 kHz";
            return jsonResult;
        }"""

BITS_FAIL_OLD = """        if (wav.bitsPerSample != 16)
        {
            jsonResult["@type"] = "error";
            jsonResult["message"] = "WAV file  must be 16 bit";
            return jsonResult;
        }"""

BITS_FAIL_NEW = """        if (wav.bitsPerSample != 16)
        {
            drwav_uninit(&wav);
            whisper_free(ctx);
            jsonResult["@type"] = "error";
            jsonResult["message"] = "WAV file  must be 16 bit";
            return jsonResult;
        }"""

WHISPER_FAIL_OLD = """        if (whisper_full(ctx, wparams, pcmf32.data(), pcmf32.size()) != 0)
        {
            jsonResult["@type"] = "error";
            jsonResult["message"] = "failed to process audio";
            return jsonResult;
        }"""

WHISPER_FAIL_NEW = """        if (pcmf32.empty())
        {
            whisper_free(ctx);
            jsonResult["@type"] = "error";
            jsonResult["message"] = "audio is empty";
            return jsonResult;
        }

        if (whisper_full(ctx, wparams, pcmf32.data(), pcmf32.size()) != 0)
        {
            whisper_free(ctx);
            jsonResult["@type"] = "error";
            jsonResult["message"] = "failed to process audio";
            return jsonResult;
        }"""


def patch(path: pathlib.Path) -> None:
    text = path.read_text(encoding="utf-8")
    if MARKER in text:
        print(f"Already patched: {path}")
        return

    if OLD_INIT not in text:
        print(f"ERROR: unexpected layout, cannot patch: {path}", file=sys.stderr)
        sys.exit(1)

    for old, new in (
        (OLD_INIT, INIT_SNIPPET),
        (OLD_WAV_FAIL, WAV_FAIL_SNIPPET),
        (CHANNEL_FAIL_OLD, CHANNEL_FAIL_NEW),
        (RATE_FAIL_OLD, RATE_FAIL_NEW),
        (BITS_FAIL_OLD, BITS_FAIL_NEW),
        (WHISPER_FAIL_OLD, WHISPER_FAIL_NEW),
    ):
        if old not in text:
            print(f"ERROR: expected snippet not found, cannot patch: {path}", file=sys.stderr)
            sys.exit(1)
        text = text.replace(old, new, 1)
    path.write_text(text, encoding="utf-8")
    print(f"Patched: {path}")


for path in paths:
    patch(path)
PY

echo "whisper_kit Android patch complete."
