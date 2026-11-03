# Test suite

```bash
make test
```

```bash
make coverage
```

`make coverage` prints per-area line coverage, excluding generated code
(`lib/l10n/gen/**`, `*.g.dart`), and fails below the 80% threshold. CI runs the
same check (`.github/workflows/test.yml`).

## How the layers divide the work

Every behaviour is tested **once**, at the lowest layer that owns it. A test at a
higher layer replaces everything below it with a fake, so nothing is re-verified
on the way up. That is the rule that keeps the suite fast and keeps one
behaviour change from breaking a dozen tests.

| Layer | Directory | Owns | Substitutes |
|---|---|---|---|
| Pure logic | `test/core/utils`, `test/domain` | Date/priority/version/URL helpers, entity getters and `copyWith` | nothing |
| Transport | `test/core/network` | Base-URL normalisation, verbs, response→`Response` mapping, auth headers, token refresh, the file lock | a mock `http.Client` |
| Serialisation | `test/data/models` | Every DTO's `fromJson` / `toJSON` / `toDomain` / `fromDomain` | nothing |
| REST contract | `test/data/data_sources` | Verb, path, query parameters, request body, which mapper runs | `RecordingClient` |
| Repositories | `test/data/repositories` | Domain↔DTO conversion and delegation only | `RecordingClient`, stub data sources |
| Controllers | `test/presentation/manager` | State transitions, error branches, what gets persisted | fake repositories |
| UI | `test/presentation/pages`, `test/presentation/widgets` | What renders, and every tap/type/drag/swipe a user can perform | fake controllers |

Concretely, this means:

- A **data-source** test never asserts a DTO field — `test/data/models` did that.
- A **repository** test never asserts a URL — `test/data/data_sources` did that.
- A **controller** test never asserts JSON or HTTP — it drives fake repositories.
- A **page** test never asserts business logic — it drives fake controllers and
  checks only that the right method was called, the right route was pushed, or
  the right snackbar appeared.

Two helpers exist purely to enforce this: `DtoResponseMapper` gets its own test
(`test/core/utils/mapping_extensions_test.dart`) covering the success/error/
exception branches, and `PaginationMixin` gets its own
(`test/presentation/manager/pagination_mixin_test.dart`) covering the page
arithmetic — so the three controllers that mix it in test only their own wiring.

## Helpers

Everything shared lives in `test/helpers/`:

| File | Purpose |
|---|---|
| `builders.dart` | Entity builders (`buildTask`, `buildProject`, …) |
| `json_fixtures.dart` | API payloads in the shape the backend sends |
| `fake_repositories.dart` | A fake per domain repository, recording calls |
| `fake_controllers.dart` | A fake per Riverpod controller, plus pending/failing variants |
| `recording_client.dart` | A `Client` that records calls instead of making them |
| `mock_http_overrides.dart` | `dart:io` `HttpClient` stub, incl. `mockNetworkImages()` |
| `plugin_mocks.dart` | Method-channel stubs for secure storage, home widget, permissions, package info, url_launcher |
| `controller_harness.dart` | `ProviderContainer` wired to the fakes, plus `keepAlive` |
| `test_app.dart` | `pumpApp`, the l10n accessor, and interaction helpers |

Useful details:

- `keepAlive(container, provider)` must be called **after** the repository stubs
  are set — Riverpod builds the notifier on first listen.
- `pumpApp(..., inScaffold: true)` for widgets that need a `Material` ancestor.
- `pumpApp` renders at `phoneSurface` (400x800), not the 800x600 `flutter_test`
  default, so a layout that overflows on a real phone also overflows here. A
  test that pumps its own tree calls `useSurfaceSize` for the same effect. Never
  call `setSurfaceSize`: it changes the layout constraints but leaves
  `MediaQuery` reporting the old size, so a widget measuring itself against
  `MediaQuery` overflows for a reason no device can reproduce. Two cases opt out,
  each for a stated reason: `tallPhoneSurface` for long pages whose rows would
  otherwise stay unbuilt below the fold, and the kanban drag tests, which need
  two fixed 300px columns on screen at once.

## What is deliberately not covered

- `lib/main.dart` — app bootstrap (Sentry, Workmanager, `runApp`).
- `lib/core/background_work.dart` — `@pragma('vm:entry-point')` isolate entries.
- The home-screen widget's refresh and completion entry points in
  `widget_controller.dart` (`updateWidget`, `updateWidgetForId`,
  `completeTask`). Each builds its own `Client` from secure storage, and that
  client is a native one on macOS and Android, so a host test cannot intercept
  it. The pure parts (`convertTask`, the payload encoding) and the platform
  redraw request are covered.
- The certificate callback `IgnoreCertHttpOverrides` installs: `dart:io` only
  exposes it as a setter, so checking it would take a TLS handshake against a
  self-signed server. The flag it reads is covered.
- `OAuthService.authorize`'s deep-link callback — needs a real browser round
  trip. The launch, PKCE challenge and failure paths *are* covered through
  `test/presentation/pages/login/login_page_test.dart`.
- `CommentEditPage` / `EditDescription` bodies — both embed an `HtmlEditor`,
  which needs a `flutter_inappwebview` platform implementation that does not
  exist in a widget test. Their navigation is covered; their save logic is
  covered through `TaskCommentsController`.
