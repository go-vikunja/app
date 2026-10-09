# Taskuna

Taskuna (name and logo: see [branding/README.md](branding/README.md)) is an unofficial mobile client for self-hosted [Vikunja](https://vikunja.io) servers, for Android and iOS, built with Flutter. The Vikunja project does not make, endorse or support it.

## Status

The project is at **step 1 of the [roadmap](docs/roadmap.md): server connection and v1/v2 negotiation, in review.** It applies the owner's decisions of 2026-10-09 (app id, browser sign-in only, and the 2.3.0 floor that follows from them) and proposes a name and icon (see [branding/README.md](branding/README.md)).

The app does one thing so far. It takes a server address and finds the Vikunja server behind it. It probes `/api/v2/info` (Vikunja 2.4.0 and newer) and `/api/v1/info` in parallel, and uses v2 when both answer. Then it shows:
- the server version;
- the API mode;
- the support tier;
- the detected capabilities.

Servers older than 2.3.0 are reported as unsupported, because browser sign-in needs 2.3.0. Sign-in, local data and task screens are not built yet.

## Goals

- **Full account access.** Projects; list, kanban, table and timeline views; task detail and editing; Quick Add Magic; filters and saved filters; comments; attachments; labels; teams; sharing.
- **Offline-first.** A local database is the source of truth for the UI. Writes go through an outbox. Sync runs in the foreground and in the background, and the background runs keep the session alive.
- **Mobile features.**
  - Local notifications with Mark done and Snooze for tasks you created or are assigned to: reminders, and due dates at the exact due time.
  - Home-screen widgets (Android Glance, iOS WidgetKit).
  - Share target and app shortcuts.
- **One app for many server versions.** It supports Vikunja 2.3.0 and newer, and treats 2.4.0+ as the first-class target. It speaks `/api/v1` and `/api/v2`, and gates features on detected capabilities, never on version strings alone.
- **Browser sign-in only** (OAuth 2.0 + PKCE). The server's web login handles local, LDAP, OIDC and TOTP accounts. Password and API-token login are not planned for now.
- **Several accounts** with an account switcher, from the first release.
- **English and German.**

Not planned for now: the admin panel, an MCP page, time tracking (licensed), push through a push service, and crash reporting ([D20](docs/decisions.md#d20-scope-cuts-and-desktop-adaptations)).

## App identity

| | |
|---|---|
| Name | Taskuna (proposed, pending owner approval), see [branding/README.md](branding/README.md) |
| Store listing | `Taskuna – client for Vikunja` (de: `Taskuna – Client für Vikunja`) |
| Icon | The "check-llama" from [branding/](branding/README.md), generated into the platform projects by `flutter_launcher_icons` |
| Android `applicationId`, iOS bundle id | `dev.coderoftime.vikunja` ([D15](docs/decisions.md#d15-app-id-devcoderoftimevikunja)) |
| Dart package | `vikunja_mobile` (internal only, never shown) |

## Repository layout

| Path | Contents |
|---|---|
| `app/` | Flutter app (feature-first: `lib/features/*`, shared code in `lib/core/`) |
| `packages/vikunja_domain/` | Pure Dart domain model. Today: server version, capabilities, support tier, connection result, connection failures |
| `packages/vikunja_api/` | Pure Dart API client. Today: address normalisation, `/info` parsing, parallel v2/v1 `/info` probing. `test/fixtures/` holds real `/info` responses |
| `branding/` | Name, logo and icon sources (SVG) with the rendered PNGs |
| `test_servers/` | Docker Compose stack with Vikunja 1.0.0, 2.0.0, 2.3.0, 2.4.0 and 2.7.0 for contract tests |
| `tool/` | Scripts used by CI and for local work |
| `docs/` | Architecture, roadmap, decisions, open questions, research |
| `.github/workflows/ci.yaml` | CI: analyze and test, generated-code check, contract tests, Android and iOS release builds |

The repository is a Dart [pub workspace](https://dart.dev/tools/pub/workspaces). The root `pubspec.yaml` lists `app` and the packages, and they share one `pubspec.lock`.

## Prerequisites

- **Flutter 3.47.5 (Dart 3.13.4)**, exactly. CI pins this version.
- **Android:** the Android SDK (`flutter doctor` shows what is missing), an emulator or a device, and JDK 17 or newer. CI uses Temurin 17.
- **iOS (macOS only):** Xcode with an iOS simulator runtime. `xcode-select` must point at Xcode, not at the Command Line Tools:

  ```sh
  xcode-select -p   # must print /Applications/Xcode.app/Contents/Developer
  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
  ```

  Setting `DEVELOPER_DIR` is not enough. The Dart native-asset build hooks (for example `objective_c`, used by `cupertino_http`) ignore it, and iOS builds fail.
- **Docker** for the test servers. Docker Desktop works, and so does [colima](https://github.com/abiosoft/colima) with the docker CLI. Either `docker compose` or the standalone `docker-compose` works.

## Common commands

Run all of these from the repository root unless a `cd` says otherwise.

```sh
flutter pub get                       # once per checkout and after pubspec changes, at the ROOT only
flutter analyze                       # analyzes app/ and packages/
tool/check_format.sh                  # format check as in CI; --fix formats in place
tool/check_pure_dart_packages.sh      # packages/*/lib must not depend on Flutter (needs jq)
```

The generated `*.g.dart` and l10n files are committed. CI regenerates them and fails when they differ from the committed ones. After you change ARB files or annotated providers, run:

```sh
cd app && flutter gen-l10n && dart run build_runner build
```

`flutter pub get` regenerates the l10n files on its own (`generate: true`), but `build_runner` only runs by hand.

The launcher icons are generated from `branding/png/` and committed too. After you change the branding PNGs (`branding/render.sh`), run:

```sh
cd app && dart run flutter_launcher_icons
```

flutter_launcher_icons 0.14.4 rewrites `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` to `AppIcon` in `app/ios/Runner.xcodeproj/project.pbxproj`; set it back to `YES` afterwards (`app/test/app/xcode_project_test.dart` checks this).

The connect screen logo (`app/assets/branding/`) is a separate export of `branding/png/logo-mark-1024.png`; see [branding/README.md](branding/README.md#using-the-assets-in-the-app).

Tests:

```sh
(cd app && flutter test)
(cd packages/vikunja_domain && flutter test)
(cd packages/vikunja_api && flutter test --exclude-tags contract)
```

The pure packages also use `flutter test` (see [D9](docs/decisions.md#d9-flutter_test-instead-of-packagetest-in-pure-packages)).

Contract tests against real servers:

```sh
tool/contract_tests.sh                # starts test_servers/ if needed, waits, runs --tags contract
docker compose -f test_servers/docker-compose.yaml up -d     # or start them by hand
tool/wait_for_test_servers.sh
docker compose -f test_servers/docker-compose.yaml down
```

With the standalone binary (for example colima with Homebrew's docker-compose), use `docker-compose` with the same arguments. The servers listen on `127.0.0.1` only.

| Port | Vikunja | Expected result |
|---|---|---|
| 34510 | 1.0.0 | unsupported (below the 2.3.0 floor) |
| 34520 | 2.0.0 | unsupported (below the 2.3.0 floor) |
| 34523 | 2.3.0 | `/api/v1` only, OAuth tier |
| 34524 | 2.4.0 | `/api/v2`, full tier |
| 34527 | 2.7.0 | `/api/v2`, full tier |

Run the app on an Android emulator:

```sh
cd app
flutter devices                       # find the emulator id, e.g. emulator-5554
flutter run -d emulator-5554
```

Enter `http://10.0.2.2:34527` as the server address. `10.0.2.2` is the emulator's alias for the host, where the 2.7.0 test server runs. On the iOS simulator, use `http://localhost:34527`. The app uses a server over plain `http://` only after you confirm it.

## Documentation

- [Architecture](docs/architecture.md): what exists after step 1 and what is planned.
- [Roadmap](docs/roadmap.md): all steps and milestones, with status.
- [Decisions](docs/decisions.md): decision log.
- [Open questions](docs/open-questions.md): the owner's answers of 2026-10-09 and the items still deferred.
- [Research](docs/research/README.md): the research snapshot the architecture is based on.

## License

Not decided yet (deferred); see [Q3](docs/open-questions.md#q3-licence-and-distribution). There is no `LICENSE` file yet. Vikunja itself is AGPL-3.0-or-later.
