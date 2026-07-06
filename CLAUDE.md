# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

ClearHear is an offline, on-device live captioning app (Flutter). Microphone audio is transcribed in real time with **sherpa-onnx** (streaming Zipformer2), speakers are labeled live per-utterance with a sherpa-onnx embedding model (`SpeakerDiarizationService`), and sessions are summarized locally with **flutter_llama** (Qwen2.5-0.5B GGUF). There is no backend and no API calls — everything runs on-device. The only network access is a fallback in `SherpaOnnxService` and `SpeakerDiarizationService` that downloads their ONNX models from HuggingFace when they are missing from `assets/`. State management is **GetX**.

## Commands

For local development use `fvm flutter` so the SDK matches `.fvmrc` (currently 3.44.4). CI runs plain `flutter` pinned to that same version.

```bash
# First-time setup
fvm install && fvm use
fvm flutter pub get
git lfs install && git lfs pull            # summary GGUF (~469 MB) is stored in Git LFS
bash tool/download_sherpa_onnx_model.sh    # ASR (~72 MB) + speaker-embedding (~27 MB) models — git-ignored
bash tool/setup_flutter_llama_android.sh   # Android only — rerun after EVERY pub get
cd ios && pod install && cd ..             # iOS

# Develop
fvm flutter run
fvm flutter analyze
fvm flutter test
fvm flutter test test/service/crash_recovery_service_test.dart      # single file
fvm flutter test --plain-name "recovers each crashed draft"          # single test by name

# Release
fvm flutter build apk --release            # add --split-per-abi for smaller downloads
fvm flutter build ipa --release --export-options-plist=ios/ExportOptions-adhoc.plist
```

CI (`.github/workflows/flutter-ci.yml`) runs `flutter pub get --enforce-lockfile`, `flutter analyze`, and `flutter test` on pull requests **and** pushes to `main` — so `pubspec.lock` must stay in sync, and tests must not depend on native ASR/LLM or downloaded models.

Use a **full rebuild** after `pub get` or native plugin changes; hot reload is not reliable for this project.

## Architecture

Layering: **View → Controller (GetX) → Service / Repository → DatabaseService / Native**.

- **Routing/DI** — `MainShell` hosts nested tab routes (`lib/arch/route/app_route.dart`); each screen has its own `bindings/` file. `MainBinding` registers the shared services/repositories plus a **permanent** `HomeController`.
- **Repositories** (`lib/arch/repository/`) — `SessionRepository`, `SegmentRepository`, `SettingsRepository` are interface + `impl/` pairs over a single `DatabaseService`. `HistoryRepository` and `SessionDetailRepository` are plain classes that **compose** those repositories and never touch the database directly (`SessionDetailRepository` also wraps `TranscriptExportService`).
- **`SessionSummaryService` is the one exception**: it bypasses repositories and queries `DatabaseService` directly, because it runs as an independent background job chain.

### Live captioning is streaming, not batch

`HomeController.startCaptioning()` → `LiveTranscriptService.start()` → `AudioRecorderService` streams raw PCM chunks straight into `SherpaOnnxService`. Each chunk is decoded immediately (`onPartialText`), and a segment is finalized when sherpa-onnx's **endpoint detection** sees trailing silence (`onSegmentFinalized`). The `.wav` file the recorder writes is an artifact only — it is deleted and never used for ASR. An Android foreground service (`ForegroundServiceHandler` → `TranscriptionForegroundService.kt`, MethodChannel `clearhear/foreground_service`) keeps capture alive in the background.

### Speaker labels

While captioning, each finalized ASR segment's audio is turned into an embedding by `SpeakerDiarizationService` and matched (cosine similarity, computed in Dart — not via sherpa-onnx's own manager) against speakers already seen in the same session; an unmatched voice registers a new "Speaker N". Labels appear live via `onPartialSpeakerLabel` and are stored per row in `segments.speaker_label`.

### Draft sessions and crash recovery (easy to break)

Segments are persisted **incrementally while recording** into a draft session (`is_saved = 0`) via `_persistSegmentToDraft`. Two paths then finalize that draft, and both must yield exactly **one** row:

- **Normal save** — `savePendingSession()` promotes the existing draft in place with `markSessionSaved(...)`. It must **not** create a second session and copy segments; doing so reintroduces a duplicate-session bug when the app is killed mid-save. `_saveAsNewSession` is only a fallback for when no draft exists.
- **Crash recovery** — `CrashRecoveryService.recoverUnsavedSessions()` runs at startup (from `MainController`), promotes leftover drafts that have segments, deletes empty ones, and cleans orphan recordings.

History and search only show saved rows (`is_saved = 1`).

### Summarization

`SessionSummaryService.queue(sessionId)` runs jobs one at a time on a single `_jobChain`, tracks `sessions.summary_status`, and broadcasts changes through its `updates` stream. `LlamaService` loads the bundled GGUF.

### Data

SQLite via `sqflite` (`lib/service/database_service.dart`) — WAL, `foreign_keys = ON`, migrations in `_onUpgrade`. `segment_search` is an **FTS4 mirror of `segments.text` kept in sync by triggers**; never write to it directly.

## UI conventions

The app ships **two locales** (`en_US`, `vi_VN`). Every user-facing string goes through GetX translations — there are no hardcoded literals in widgets:

1. add the constant to `lib/lang/string_keys.dart`,
2. add the same key to **both** `assets/i18n/en_us.json` **and** `assets/i18n/vi_vn.json`,
3. use it as `StringKeys.someKey.tr`.

Skipping step 2 for `vi_vn.json` does not fail the build — the Vietnamese UI just renders the raw key.

Also reuse rather than re-invent:

- **Toasts/banners** — `AppToast.success/error/warning/info` (`lib/util/toast/`). Never `Get.snackbar`; there are zero calls to it.
- **Logging** — `AppLogger.info/warning/error` with a `tag:` (`lib/util/logger/`). Never `print`; there are zero calls to it.
- **Colors** — prefer `AppColors` / `AppTheme` in `lib/style/theme.dart`; add new colors there rather than hardcoding `Color(0x...)` (a handful of local one-off colors still exist in some widgets).
- **Shared widgets** — `lib/shared/widgets/` (`AppDialog`, `AppLoading`, `AppTitlebar`, `HighlightedText`, `InlineEditableTitle`) before writing a new one.

## ML models

Configured in `lib/config/ml_model_config.dart`. Three models: the streaming Zipformer ASR (ONNX, ~72 MB), the 3D-Speaker embedding extractor (ONNX, ~27 MB), and the Qwen summary (GGUF, ~469 MB via Git LFS). `SherpaOnnxService` and `SpeakerDiarizationService` copy their ONNX files from `assets/models/...` into app support storage on first launch, falling back to a HuggingFace download when the assets are missing (the asset dirs are git-ignored). A GGUF that is only a few hundred bytes means Git LFS was not pulled.

## Conventions

- Commit subjects follow `type(scope): summary` (e.g. `fix(home): ...`, `feat(session): ...`); PRs are squashed to a **single commit**, so amend + `push --force-with-lease` rather than stacking commits.
- Tests use hand-written fakes implementing the repository interfaces (see `test/service/crash_recovery_service_test.dart`, `test/screen/home/home_controller_save_test.dart`); keep native ASR/LLM/mic out of tests by injecting fakes into `HomeController`.
