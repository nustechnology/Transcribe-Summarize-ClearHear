# ClearHear (Transcribe-Summarize-ClearHear)

On-device live captioning for Flutter. Records speech in segments, transcribes locally with **whisper_kit**, and summarizes with **flutter_llama**.

State management: **GetX**.

## Requirements

| Tool | Notes |
|------|-------|
| [FVM](https://fvm.app) | Project pins Flutter in `.fvmrc` (currently **3.44.4**) |
| Xcode + CocoaPods | iOS builds (macOS only) |
| Android SDK | NDK + CMake **3.22+** (Android SDK Manager) |
| Internet | First run only — downloads Whisper `tiny` (~75 MB) |

Microphone permission is declared in `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`.

## First-time setup

From the project root:

```bash
fvm install && fvm use
fvm flutter pub get

# Android — required after every pub get
bash tool/setup_flutter_llama_android.sh
bash tool/patch_whisper_kit_android.sh

# iOS — required after every pub get
bash tool/patch_whisper_kit_ios.sh
cd ios && pod install && cd ..
```

Use `fvm flutter` (not a global Flutter SDK) so the version matches `.fvmrc`.

## Run

```bash
fvm flutter run
```

Use a **full rebuild** after `pub get` or native plugin changes — not hot reload.

## Models

Defaults are in `lib/config/ml_model_config.dart`:

| Feature | Default |
|---------|---------|
| Transcription | Whisper `tiny`, English |
| Summarization | Qwen2.5-0.5B-Instruct (GGUF via `flutter_llama`) |
| Segment pause | 1.2 s silence between utterances |

Whisper downloads automatically on first use, then works offline. Change `whisperModelName` to `base` or `small` for better accuracy at the cost of speed.

The summarization GGUF (`assets/models/qwen2.5-0.5b-instruct-q4_k_m.gguf`) is stored with **Git LFS**. After cloning:

```bash
git lfs install
git lfs pull
ls -lh assets/models/qwen2.5-0.5b-instruct-q4_k_m.gguf   # should be ~469 MB
```

## Captioning flow

1. **Start** — mic streams PCM; segments save as WAV when silence is detected.
2. **Stop** — each segment is transcribed in the background; text appears in the UI.
3. **Summarize** — optional summary via on-device LLM.

Debug logs: `[LiveTranscript]`, `[WhisperKit]`, `[Transcribe]`.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Android: `libwhisper.so` SIGSEGV on transcribe | `bash tool/patch_whisper_kit_android.sh`, then full rebuild |
| Android: `flutter_llama` / CMake / `llama_context_type` errors | `bash tool/setup_flutter_llama_android.sh` after `pub get`, then full rebuild |
| Android: CMake 3.19+ / `SPIRV-Headers` (`ggml-vulkan`) errors | Same script (disables Vulkan, uses CPU backend). Install CMake 3.22+ via Android SDK Manager if prompted |
| iOS: whisper_kit compile / linker / `_ggml_*` errors | `bash tool/patch_whisper_kit_ios.sh`, then `cd ios && pod install` |
| iOS: duplicate `WhisperKitPlugin`, `UnsafeMutablePointer`, `AudioMetadata?`, VAD / vDSP errors | Same patch script as above |
| `version solving failed` / `json_annotation` | Use `fvm flutter pub get` with the Flutter version from `.fvmrc` (currently **3.44.4**) |
| `MissingPluginException` / mic unavailable | Full rebuild (`fvm flutter run`), not hot reload |
| Whisper model download fails | Check network; retry on Wi‑Fi |
| Summary model fails to load (`INIT_FAILED`) | The GGUF in `assets/models/` is tracked by Git LFS. Install [Git LFS](https://git-lfs.com), run `git lfs pull`, confirm the file is ~469 MB (not a 134-byte pointer), then full rebuild |
| ANR / UI freeze during ML | Ensure heavy work stays off the UI thread; rebuild with latest code |

## Project layout

```text
lib/
  config/ml_model_config.dart
  service/                    # Audio, Whisper, Llama
  screen/home/                # Live caption UI
tool/
  setup_flutter_llama_android.sh
  patch_whisper_kit_android.sh
  patch_whisper_kit_ios.sh
```
