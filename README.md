# Taskuna

Taskuna (name and logo: see [branding/README.md](branding/README.md)) is an unofficial mobile client for self-hosted [Vikunja](https://vikunja.io) servers, for Android and iOS, built with Flutter. The Vikunja project does not make, endorse or support it.

## Status

Step 1 of the [roadmap](docs/roadmap.md), server connection and v1/v2 negotiation, is done. **Step 2+3, the HTTP core, browser sign-in (OAuth 2.0 + PKCE) and the session manager, is in progress**; see [architecture §5](docs/architecture.md#5-auth-and-session-in-progress-step-23). The project applies the owner's decisions of 2026-10-09 (app id, browser sign-in only, and the 2.3.0 floor that follows from them) and proposes a name and icon (see [branding/README.md](branding/README.md)).

Step 1 built the first feature: the app takes a server address and finds the Vikunja server behind it. It probes `/api/v2/info` (Vikunja 2.4.0 and newer) and `/api/v1/info` in parallel, and uses v2 when both answer. Then it shows:
- the server version;
- the API mode;
- the support tier;
- the detected capabilities.

Servers older than 2.3.0 are reported as unsupported, because browser sign-in needs 2.3.0. Step 2+3 adds sign-in through the system browser, a signed-in home placeholder and sign-out. Local data and task screens are not built yet.

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
| `test_servers/` | Docker Compose stack with Vikunja 1.0.0, 2.0.0, 2.3.0, 2.4.0 and 2.7.0 for contract tests, plus a second 2.7.0 for sign-in on the Android emulator. `seed/e2e-user.env` holds the throwaway sign-in test user |
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
- **curl and jq** for the scripts in `tool/`.

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

Only the latest Vikunja release is tested: one server, 2.7.0 on port 34527 (`/api/v2`, full tier). Older servers down to the 2.3.0 floor stay supported in code and are covered by unit tests with recorded `/info` and error responses ([D28](docs/decisions.md#d28-test-only-the-latest-vikunja-release)).

Run the app on an Android emulator:

```sh
cd app
flutter devices                       # find the emulator id, e.g. emulator-5554
flutter run -d emulator-5554
```

Forward the emulator's `localhost:34527` to the host once per emulator start, then enter `http://localhost:34527` as the server address (the same address works on the iOS simulator):

```sh
adb reverse tcp:34527 tcp:34527
```

The app uses a server over plain `http://` only after you confirm it.

## Sign in on a device (end to end)

Browser sign-in is tested by hand against the Docker test servers, with a fixed test user. Its username and password are in [`test_servers/seed/e2e-user.env`](test_servers/seed/e2e-user.env). They are throwaway values for these local servers only.

Both the Android emulator (after `adb reverse tcp:34527 tcp:34527`) and the iOS simulator use `http://localhost:34527`. The server's `publicurl` is `http://localhost:34527/`, so its web login page also loads in the emulator's browser.

The app's minimum is iOS 15.0. Below iOS 17.4, flutter_web_auth_2 falls back to the older ASWebAuthenticationSession initializer, which handles the app's custom callback scheme ([D23](docs/decisions.md#d23-browser-sign-in-through-flutter_web_auth_2-client-id-and-redirect-uri)).

1. Start the test servers and create the user:

   ```sh
   docker compose -f test_servers/docker-compose.yaml up -d   # or docker-compose
   tool/wait_for_test_servers.sh
   tool/seed_e2e_user.sh                 # creates the user on 34527
   ```

   The script is idempotent: for a user that already exists it checks the password with one login. The server keeps its data in a tmpfs, so run it again after the server restarts. It counts against the server's login limit of 10 requests per minute per IP.

2. Run the app (`cd app`, then `flutter run -d emulator-5554` or `flutter run -d "iPhone 16 Pro"`), enter `http://localhost:34527` and confirm the unencrypted connection.
3. Tap **Continue to sign-in**.
   - Android: a Custom Tab (or Chrome's Auth Tab) opens the Vikunja login page. On a new emulator, Chrome may show its first-run screens first.
   - iOS: a sign-in sheet opens the Vikunja login page. The session is ephemeral, so iOS asks no "Wants to Use … to Sign In" question.
4. Sign in with the username and password from the env file. To enter the password without printing it, copy it to the clipboard and paste it into the field (the emulator and the simulator share the host clipboard), or type it into the focused field on the emulator:

   ```sh
   # copy to the macOS clipboard
   sed -n 's/^E2E_PASSWORD=//p' test_servers/seed/e2e-user.env | tr -d '\n' | pbcopy
   # or type into the focused field on the emulator
   adb shell input text "$(sed -n 's/^E2E_PASSWORD=//p' test_servers/seed/e2e-user.env)"
   ```

5. The sheet closes and the app shows the signed-in home: initials, display name, `@` username, server host and version. **Sign out**, after a confirmation, returns to onboarding.

Every sign-in starts with an empty browser session and shows the login form ([D23](docs/decisions.md#d23-browser-sign-in-through-flutter_web_auth_2-client-id-and-redirect-uri)). On Android, Chrome before 141 (the emulator image ships 133) gets a regular Custom Tab instead, which can reuse a web login in Chrome; to see the form again there, sign out in Chrome or clear its data for the server.

## Documentation

- [Architecture](docs/architecture.md): what exists after step 1, what step 2+3 is building, and what is planned.
- [Roadmap](docs/roadmap.md): all steps and milestones, with status.
- [Decisions](docs/decisions.md): decision log.
- [Open questions](docs/open-questions.md): the owner's answers of 2026-10-09 and the items still deferred.
- [Research](docs/research/README.md): the research snapshot the architecture is based on.

## License

Not decided yet (deferred); see [Q3](docs/open-questions.md#q3-licence-and-distribution). There is no `LICENSE` file yet. Vikunja itself is AGPL-3.0-or-later.
