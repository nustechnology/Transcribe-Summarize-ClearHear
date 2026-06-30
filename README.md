# Transcribe-Summarize-ClearHear

A Flutter app using **GetX** for state management, routing, and dependency injection.

## Requirements

- Flutter SDK (via FVM: `3.32.5`)
- Dart >= 3.3.3

## Setup

```bash
fvm flutter pub get
```

## Run the app

```bash
fvm flutter run
```

## GetX patterns in use

| Component | Purpose |
|---|---|
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
