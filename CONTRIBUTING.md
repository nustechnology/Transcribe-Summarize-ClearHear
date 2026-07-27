# Contributing to ClearHear

Thanks for helping improve ClearHear. This guide covers local setup, coding
conventions, and how we accept changes.

## Before you start

1. Read the [README](README.md) for architecture and first-time setup.
2. Follow the [Code of Conduct](CODE_OF_CONDUCT.md).
3. For security issues, use [SECURITY.md](SECURITY.md) — do **not** open a
   public issue for vulnerabilities.

## Development setup

Use **FVM** so the Flutter SDK matches `.fvmrc` (currently **3.44.4**):

```bash
fvm install && fvm use
fvm flutter pub get
git lfs install && git lfs pull
bash tool/download_sherpa_onnx_model.sh
bash tool/setup_flutter_llama_android.sh   # Android — rerun after every pub get
bash tool/patch_flutter_llama_ios.sh       # iOS — rerun after every pub get
cd ios && pod install && cd ..             # iOS
```

CI runs plain `flutter` pinned to the same version; locally prefer `fvm flutter`.

After `pub get` or native plugin changes, do a **full rebuild** — hot reload is
unreliable for this project.

## What CI expects

On pull requests and pushes to `main`, CI runs:

- `flutter pub get --enforce-lockfile`
- `flutter analyze`
- `flutter test`

So:

- Keep `pubspec.lock` in sync with `pubspec.yaml`.
- Tests must **not** depend on microphone, sherpa-onnx, llama, or downloaded
  ONNX/GGUF files. Inject fakes at the repository / controller boundary (see
  `test/service/crash_recovery_service_test.dart` and
  `test/screen/home/home_controller_save_test.dart`).

## Coding conventions

- **Architecture:** View → Controller (GetX) → Service / Repository →
  `DatabaseService` / native. Prefer existing patterns over new layers.
- **i18n:** Every user-facing string goes through GetX translations:
  1. add a key to `lib/lang/string_keys.dart`
  2. add the same key to **both** `assets/i18n/en_us.json` and
     `assets/i18n/vi_vn.json`
  3. use `StringKeys.someKey.tr`
- **Toasts:** `AppToast.success/error/warning/info` — never `Get.snackbar`.
- **Logging:** `AppLogger.info/warning/error` with a `tag:` — never `print`.
- **Colors:** prefer `AppColors` / `AppTheme` in `lib/style/theme.dart`.
- **Shared widgets:** check `lib/shared/widgets/` before inventing new ones.

Draft sessions and crash recovery are easy to break — read the README notes on
`savePendingSession` and `CrashRecoveryService` before changing save paths.

## Commits and pull requests

- Commit subjects: `type(scope): summary`  
  Examples: `fix(home): …`, `feat(session): …`, `docs(readme): …`
- Prefer **one logical change per PR**. This repo typically **squashes** PRs to
  a single commit on merge.
- Open a PR against `main` with:
  - a short **Summary** of what and why
  - a **Test plan** checklist (what you ran / how to verify)
- Ensure `fvm flutter analyze` and `fvm flutter test` pass locally before
  requesting review.

## Scope of contributions

Especially welcome:

- Bug fixes with regression tests
- Accessibility and i18n improvements
- Documentation and setup script fixes
- Performance / battery improvements that keep work off the UI thread

Please open an issue first for large refactors, new ML backends, or changes
that would require network APIs (ClearHear is intentionally on-device).
