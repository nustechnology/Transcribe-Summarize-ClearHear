# AGENTS.md

Rules for AI coding agents and human contributors. **Follow strictly.** Do not improvise architecture.

---

## Purpose

This document defines non-negotiable conventions for **Transcribe-Summarize-ClearHear**. AI agents must read this file before making changes. When in doubt, match existing patterns in `lib/` and ask rather than invent new layers or shortcuts.

**Forbidden without explicit approval:** logic in widgets, direct API calls from UI/controllers, `Navigator` usage, new state-management libraries, secrets in source control.

---

## Tech Stack

| Layer | Choice |
|---|---|
| Framework | Flutter **3.32.5** (via FVM) |
| Language | Dart `>=3.3.3 <4.0.0` |
| State / DI / Routing | **GetX** (`get: ^4.6.6`) |
| HTTP | **Dio** (centralized in `lib/arch/network/`) |
| i18n | GetX translations (`lib/lang/`) |
| Linting | `flutter_lints` (`analysis_options.yaml`) |
| Local ML / audio | `whisper_ggml`, `flutter_llama`, `record` (via `lib/service/`) |

**Commands:** always prefix with `fvm` — e.g. `fvm flutter pub get`, `fvm flutter run`, `fvm flutter test`.

---

## Folder Structure

Feature-based modules under `lib/screen/`. Shared infrastructure under `lib/arch/`.

```
lib/
├── main.dart
├── arch/
│   ├── route/
│   │   └── app_route.dart          # AppRoutes + AppPages
│   └── network/
│       ├── dio_client.dart         # Singleton Dio, interceptors
│       ├── api_endpoints.dart      # Path constants
│       └── api_exception.dart      # Typed errors
├── config/                         # App-wide config (no secrets)
├── constants/                      # Magic numbers, durations, keys
├── lang/
│   ├── string_keys.dart
│   └── translation.dart
├── style/
│   └── theme.dart
├── service/                        # Platform / SDK / low-level I/O
├── repository/                     # Data orchestration, caching, mapping
└── screen/
    └── <feature>/
        ├── bindings/
        │   └── <feature>_binding.dart
        ├── controllers/
        │   └── <feature>_controller.dart
        ├── models/                 # Feature DTOs / view models (optional)
        └── <feature>_widget.dart   # UI only (GetView)
```

**Adding a feature:** create the folder above → add route constant → register `GetPage` + `Binding` in `app_route.dart`.

---

## Architecture Flow

Unidirectional data flow only:

```
UI (GetView) → Controller (GetxController) → Repository → Service → API / Platform
```

| Layer | Responsibility | May call |
|---|---|---|
| **UI** (`*_widget.dart`) | Layout, theming, user events → controller methods | Controller only |
| **Controller** | UI state (`.obs`), orchestration, error → user messages | Repository (or Service for legacy local-only features) |
| **Repository** | Business rules, mapping, cache, combine data sources | Service(s) |
| **Service** | Dio calls, file I/O, ML SDK, device APIs | External systems |
| **API** | HTTP via Dio | — |

- Controllers **must not** import Dio or construct HTTP requests.
- Widgets **must not** call repositories, services, or APIs.
- Repositories **must not** import `flutter/material.dart`.

**Legacy note:** existing local-only flows (Whisper, Llama, recorder) may call `lib/service/` directly from controllers until migrated. New remote data **must** go through Repository → Service → Dio.

---

## State Management (GetX)

### Controllers

- Extend `GetxController`.
- Expose reactive state with `.obs` or `Rx<T>`.
- Lifecycle: `onInit`, `onReady`, `onClose` — dispose streams/subscriptions in `onClose`.
- Keep controllers thin: no widget-building, no `BuildContext`, no layout math.
- Max ~200 lines; split if larger.

```dart
class HomeController extends GetxController {
  HomeController({required HomeRepository homeRepository})
      : _homeRepository = homeRepository;

  final HomeRepository _homeRepository;

  final isLoading = false.obs;
  final items = <Item>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadItems();
  }

  Future<void> loadItems() async {
    isLoading.value = true;
    try {
      items.value = await _homeRepository.fetchItems();
    } catch (e) {
      // map to StringKeys / user-facing message
    } finally {
      isLoading.value = false;
    }
  }
}
```

### UI

- Screens extend `GetView<TController>` (not `StatelessWidget` + manual `Get.find`).
- Use `Obx` / `GetX` only around subtrees that depend on observables.
- Pass user actions to controller methods: `onPressed: controller.submit`.
- No `setState`, no `StatefulWidget` for business state (local animation-only `StatefulWidget` is OK).

### Bindings

- One `Bindings` class per route (or parent shell that owns child tabs).
- Register with `Get.lazyPut` by default; use `Get.put` only when immediate init is required.
- Inject dependencies via constructors — not `Get.find` inside controllers.

```dart
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeRepository>(() => HomeRepository(Get.find()));
    Get.lazyPut<HomeController>(() => HomeController(homeRepository: Get.find()));
  }
}
```

---

## Naming Conventions

| Item | Convention | Example |
|---|---|---|
| Files | `snake_case` | `home_controller.dart` |
| Screen UI | `<feature>_widget.dart` | `home_widget.dart` |
| Screen class | `<Feature>View` | `HomeView` |
| Controller | `<Feature>Controller` | `HomeController` |
| Binding | `<Feature>Binding` | `HomeBinding` |
| Repository | `<Feature>Repository` | `HistoryRepository` |
| Service | `<Feature>Service` or `<Capability>Service` | `WhisperService` |
| Models | `PascalCase` noun | `TranscriptEntry` |
| Route constants | `camelCase` in `AppRoutes` | `AppRoutes.live` |
| Private fields | `_camelCase` | `_repository` |
| Observables | descriptive `camelCase` | `isCaptioning`, `transcript` |
| String keys | `camelCase` in `StringKeys` | `StringKeys.homeProcessing` |

---

## Routing

- **GetX only.** `GetMaterialApp` + `GetPage` + `AppPages.routes`.
- **Never** use `Navigator.push`, `Navigator.pop`, `MaterialPageRoute`, or `go_router`.
- Navigation: `Get.toNamed()`, `Get.offNamed()`, `Get.back()`, `Get.offAllNamed()`.
- Route paths live in `AppRoutes` (`lib/arch/route/app_route.dart`).
- Every `GetPage` that needs a controller **must** declare a `binding`.
- Nested tabs/shells use `children:` on parent `GetPage` (see `MainShell`).

```dart
abstract class AppRoutes {
  static const main = '/';
  static const live = '/live';
}

class AppPages {
  static const initial = AppRoutes.main;

  static final routes = [
    GetPage(
      name: AppRoutes.main,
      page: () => const MainShell(),
      binding: MainBinding(),
      children: [
        GetPage(
          name: AppRoutes.live,
          page: () => const HomeView(),
          binding: HomeBinding(),
        ),
      ],
    ),
  ];
}
```

---

## API Integration (Dio)

All HTTP traffic goes through `lib/arch/network/dio_client.dart`.

- Single configured `Dio` instance (base URL, timeouts, headers).
- Interceptors: auth token, logging (debug only), error normalization.
- Endpoints as constants in `api_endpoints.dart` — no hardcoded URL strings in services.
- Services return typed models or `Result`/`Either`-style outcomes — not raw `Response`.
- Map `DioException` to `ApiException` in one place.

```dart
class HistoryService {
  HistoryService(this._dio);
  final Dio _dio;

  Future<List<TranscriptDto>> fetchAll() async {
    final response = await _dio.get(ApiEndpoints.transcripts);
    return (response.data as List)
        .map((e) => TranscriptDto.fromJson(e))
        .toList();
  }
}
```

---

## Dependency Injection

- **GetX Bindings only** — no `get_it`, `provider`, or manual service locators outside GetX.
- Register in order: Service → Repository → Controller.
- Prefer constructor injection; `Get.find<T>()` only inside bindings/factories.
- `fenix: true` for controllers that may be recreated after disposal (use sparingly).
- Do not call `Get.put` globally in `main.dart` except app-wide singletons (e.g. `DioClient`).

---

## Git Workflow

- **Rebase-based** integration. Branch from `main`, rebase before opening PR.
- **1 PR = 1 feature = 1 commit** after squash merge.
- Branch names: `feature/<short-description>`, `fix/<short-description>`.
- PR must pass `fvm flutter analyze` and `fvm flutter test`.
- No drive-by refactors or unrelated file changes in a PR.

---

## Code Quality

- **DRY:** extract shared logic to repositories, services, or `lib/constants/`.
- **No fat controllers:** if a controller grows business logic, move it to a repository.
- **Constants:** no magic numbers/strings in UI or controllers — use `constants/`, `StringKeys`, or `config/`.
- **Imports:** use `package:` imports for all project files within `lib/`; avoid relative imports (`./` and `../`) except where required by the language (e.g. `part` / `part of`). Keep imports sorted and grouped, remove unused imports, and avoid wildcard imports.
- **Errors:** catch at repository/service boundary; controllers set user-visible `statusMessage` via i18n keys.
- **Logging:** `debugPrint` with `[Feature]` prefix in debug builds only; never log secrets.
- Run `fvm flutter analyze` before committing.

---

## Testing

| Type | Target | Location |
|---|---|---|
| Unit | Controllers, repositories, services, parsers | `test/unit/` |
| Widget | `GetView` screens (mock controller via GetX test utils) | `test/widget/` |

**Guidelines:**

- Controllers: mock repositories; verify state transitions and method calls.
- Repositories: mock services; verify mapping and error handling.
- Widgets: pump with `GetMaterialApp`, register test doubles via `Get.put` before `pumpWidget`.
- Name tests: `'<unit> <condition> <expected>'`.
- Do not test Flutter framework behavior or trivial getters.

```dart
test('loadItems sets isLoading false after success', () async {
  final repo = MockHomeRepository();
  when(() => repo.fetchItems()).thenAnswer((_) async => [item]);
  final controller = HomeController(homeRepository: repo);

  await controller.loadItems();

  expect(controller.isLoading.value, false);
  expect(controller.items, [item]);
});
```

---

## Environment & Secrets

- Secrets and environment-specific values live in **`.env`** (or CI secrets) — **never** committed.
- Provide `.env.example` with keys only, no real values.
- Load via `flutter_dotenv` or build-time `--dart-define` (team picks one; stay consistent).
- `android/key.properties` and signing keys are local-only (see `key.properties.example`).
- API keys, tokens, and model URLs must not appear in source, logs, or screenshots.

---

## Performance

- **Narrow `Obx` scope** — wrap the smallest subtree that reads `.value`; avoid wrapping entire `Scaffold`.
- **Lazy loading:** `Get.lazyPut` for controllers and heavy services; defer ML model load until needed.
- **Lists:** use `ListView.builder` for long transcripts/history.
- **Const constructors** where possible for static widgets.
- **Avoid** `Obx` inside `itemBuilder` without keys; prefer `GetBuilder` or pass reactive values explicitly when list items are many.
- Dispose recorders, streams, and isolates in `onClose`.
- Profile before optimizing; do not add caching layers without a measured need.

---

## AI Agent Rules

AI agents (Cursor, Copilot, Claude, etc.) **must**:

1. Read this file and scan `lib/arch/route/app_route.dart` plus one existing feature before editing.
2. Mirror naming and folder layout exactly.
3. Place new code in the correct layer — never shortcut to UI or controller for API/IO.
4. Add/update `Binding` when adding a controller or route.
5. Add `StringKeys` + translation JSON entries for new user-visible strings.
6. Keep imports clean and ordered; avoid unused imports, wildcard imports, and unnecessary package imports.
7. Keep diffs minimal — no unrelated formatting, dependency bumps, or refactors.
7. Not add new packages without team approval (state `// TODO: approved dependency` in PR description).
8. Not delete or weaken tests; add tests for new controller/repository logic.
9. Run `fvm flutter analyze` after changes and fix issues.
10. When unsure between two patterns, **choose the stricter separation** (extra repository layer over fat controller).

**AI agents must not:**

- Put `async` business logic, API calls, or `Dio` in widgets.
- Use `Navigator`, `setState` for app state, `Provider`, `Riverpod`, or `Bloc`.
- Create `lib/features/`, `lib/modules/`, or alternate roots — use `lib/screen/<feature>/`.
- Hardcode user-facing strings in widgets.
- Commit `.env`, API keys, or credentials.
- Generate "example" or placeholder files unless requested.

---

## Quick Checklist (new screen)

- [ ] `lib/screen/<feature>/` with `bindings/`, `controllers/`, `<feature>_widget.dart`
- [ ] `GetView` + `Obx` scoped correctly
- [ ] Controller delegates data work to repository/service
- [ ] `Binding` registers dependencies with `Get.lazyPut`
- [ ] Route in `AppRoutes` + `GetPage` in `AppPages`
- [ ] Strings in `StringKeys` + `assets/i18n/*.json`
- [ ] `fvm flutter analyze` clean
- [ ] Unit test for non-trivial controller logic
