# ClearHear (Transcribe-Summarize-ClearHear)

On-device live captioning for Flutter. Records conversation in speech segments, then transcribes each segment locally with **whisper_kit** (whisper.cpp). Summarization via `flutter_llama` is prepared but currently disabled in `pubspec.yaml`.

State management: **GetX**.

## Requirements

| Tool | Version / notes |
|------|-----------------|
| [FVM](https://fvm.app) | Recommended — project pins Flutter in `.fvmrc` |
| Flutter | Must match `.fvmrc` (currently **3.44.4**); `fvm install` / `fvm use` apply that pin |
| Dart | Bundled with the FVM Flutter SDK above — do not pair a separate global `dart` with this project |
| Xcode | iOS builds (macOS only) |
| CocoaPods | `pod install` in `ios/` |
| Internet | **First run only** — downloads Whisper `tiny` model (~75 MB) |

### Platform targets

| Platform | Status |
|----------|--------|
| Android | Supported |
| iOS | Supported (requires iOS patch below) |
| macOS | Experimental (`whisper_kit`) |

Microphone permission is already declared in `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`.

## First-time setup

From the project root:

```bash
# 1. Install the Flutter version from .fvmrc
fvm install
fvm use

# 2. Dependencies
fvm flutter pub get

# 3. Android — sync flutter_llama llama.cpp headers (run after every pub get)
bash tool/setup_flutter_llama_android.sh

# 4. iOS only — fix whisper_kit Swift compile errors (run after every pub get)
bash tool/patch_whisper_kit_ios.sh

# 5. iOS only — CocoaPods
cd ios && pod install && cd ..
```

Always prefix Flutter commands with `fvm` (or use `fvm flutter` as your default) so the SDK matches `.fvmrc`. A global `flutter` outside that pin (e.g. an older install while `.fvmrc` specifies **3.44.4**) can cause dependency resolution failures.

## Run the app

```bash
fvm flutter run
```

Use a **full rebuild** after adding native plugins or running `pub get` — avoid hot reload for mic / ML changes.

```bash
# Example: run on a connected device
fvm flutter run -d <device_id>

# List devices
fvm flutter devices
```

## Whisper model

No manual model download script is required. On first transcription, `whisper_kit` downloads **Whisper tiny** to app storage (Hugging Face). After that, transcription works offline.

Defaults live in `lib/config/ml_model_config.dart`:

- Model: `tiny` (fastest, ~75 MB)
- Language: `auto`
- Segment pause: `1.2` s silence between utterances

To use a larger model (better accuracy, slower), change `whisperModelName` to `base` or `small` in that file.

> **Note:** `whisper_kit` is constrained to **^0.3.0** in `pubspec.yaml`. Version **0.3.1** only requires Dart `>=3.3.0` (already satisfied by the Flutter SDK in `.fvmrc`), so SDK version is not the upgrade blocker — iOS builds depend on `tool/patch_whisper_kit_ios.sh`, which targets the 0.3.x plugin sources. Re-run and update that patch before bumping the package.

## Captioning flow

1. **Start captioning** — mic streams PCM; segments are saved as WAV when silence is detected.
2. **Stop** — each segment is transcribed with Whisper in the background; results are written to the debug log (not the UI).
3. Watch logs: `[LiveTranscript]`, `[WhisperKit]`, `[Transcribe]`.

## Optional: summarization (flutter_llama)

Summarization is commented out in `pubspec.yaml`. To enable later:

1. Uncomment `flutter_llama` in `pubspec.yaml`.
2. Run `bash tool/setup_flutter_llama_android.sh` after `pub get` (syncs llama.cpp headers for Android).
3. Add the summary GGUF model per `MlModelConfig` in `lib/config/ml_model_config.dart`.

## Troubleshooting

| Issue | What to do |
|-------|------------|
| Android: `flutter_llama` CMake / `llama_context_type` errors | Run `bash tool/setup_flutter_llama_android.sh` after `pub get`, then rebuild. |
| Android: CMake 3.19+ / `SPIRV-Headers` (`ggml-vulkan`) errors | Run `bash tool/setup_flutter_llama_android.sh` after `pub get` (disables Vulkan, uses CPU backend). Install CMake 3.22+ via Android SDK Manager if prompted. |
| `version solving failed` / `json_annotation` | Run `fvm flutter pub get` with the Flutter version from `.fvmrc` (currently **3.44.4**), not a global SDK. |
| iOS: undefined symbol `_ggml_*` | Run `bash tool/patch_whisper_kit_ios.sh`, then `cd ios && pod install`. |
| iOS: duplicate interface for `WhisperKitPlugin` | Run `bash tool/patch_whisper_kit_ios.sh` after `pub get`. |
| iOS: `UnsafeMutablePointer<CChar>?` must be unwrapped | Run `bash tool/patch_whisper_kit_ios.sh` after `pub get`. |
| iOS: `AudioMetadata?` / `async` in `EnhancedAudioManager` | Same patch script as above. |
| iOS: `VoiceActivityDetector` (`self`, vDSP, FFT) | Same patch script as above. |
| `MissingPluginException` / mic unavailable | Stop the app and run a full rebuild (`fvm flutter run`), not hot reload. |
| Whisper model download fails | Check network; retry on Wi‑Fi. |
| ANR / UI freeze during ML | Ensure heavy work stays off the UI thread; rebuild with latest code. |

## Project layout (app code)

```text
lib/
  config/ml_model_config.dart   # Audio + Whisper settings
  service/
    audio_recorder_service.dart   # Mic PCM stream
    conversation_segment_capture.dart
    live_transcript_service.dart  # Record segments → Whisper
    whisper_kit_service.dart
  screen/home/                    # Live caption UI
tool/
  setup_flutter_llama_android.sh  # Required Android patch for flutter_llama 1.1.2
  patch_whisper_kit_ios.sh        # Required iOS patch for whisper_kit 0.3.0
```

## GetX patterns

| Component | Purpose |
|-----------|---------|
| `GetMaterialApp` | App root with GetX routing |
| `GetPage` + `AppPages` | Route declarations |
| `Bindings` | Inject controllers per route |
| `GetxController` + `.obs` | Reactive state |
| `GetView<T>` | Screen bound to a controller |
| `Obx()` | Rebuild when observables change |

## Adding a new screen

1. Create `lib/screen/<name>/` with `bindings/`, `controllers/`, and `<name>_widget.dart`
2. Add a route constant in `AppRoutes` inside `arch/route/app_route.dart`
3. Register a `GetPage` in `AppPages.routes` in the same file
