# Developer guide

How to set up, build and test the app, and where everything is. [CONTRIBUTING.md](../CONTRIBUTING.md) has the rules for contributions; this guide has the commands. In these docs, "the owner" is the app's main maintainer, a role rather than a person.

## App identity

| | |
|---|---|
| Name | Vikunja; "the app" where a text also names a server, and "Vikunja app" before a version ([Languages](decisions.md#languages)) |
| Store listing | `Vikunja` in both stores and languages ([Releases](decisions.md#releases), [store-listing.md](store-listing.md)) |
| Icon | Vikunja's logo, the llama on the blue disc, from [branding/](../branding/README.md) ([Identity and scope](decisions.md#identity-and-scope)): adaptive and themed icons on Android, light, dark and tinted icons on iOS 18, generated into the platform projects by `flutter_launcher_icons` |
| Android `applicationId`, iOS bundle id | `io.vikunja.app`; the sign-in scheme and OAuth client id `vikunja-io.vikunja.app` ([Identity and scope](decisions.md#identity-and-scope)) |
| User-Agent | `Vikunja-App/<version>[+<build>] (<system> <version>)`, which the sessions page shows as "Vikunja app" ([Identity and scope](decisions.md#identity-and-scope)) |
| Dart package | `vikunja_mobile` (internal only, never shown) |

## Repository layout

| Path | Contents |
|---|---|
| `app/` | The Flutter app, feature-first: `lib/features/*`, with shared code in `lib/core/`: auth, the Drift database in `db/`, the sync engine in `sync/`, the outbox and its sender in `outbox/`, repositories, the notification scheduler and its background action handler in `notifications/`, the background job in `background/`, the activity sync in `activity/`, the avatar and attachment image caches in `avatar/` and `attachments/`, the deep-link relay in `links/`, and the home-screen widgets' snapshots, publisher and tap import in `widgets/`. The Android widgets (Glance, Kotlin) are in `android/app/src/main/kotlin/io/vikunja/app/widgets/`, the iOS widget extension (Swift) in `ios/VikunjaWidgets/`. `drift_schemas/` holds the schema dumps the migration tests compare against |
| `packages/vikunja_domain/` | Pure Dart domain model: the server version, capabilities, support tier and connection result; users, accounts, tokens and `VikunjaFailure`; projects, views, labels, tasks, reminders, relations, user settings, server notifications and task details |
| `packages/vikunja_api/` | Pure Dart API client over `/api/v1` and `/api/v2`: address normalisation, the parallel `/info` probes, error normalisation, the OAuth 2.0 + PKCE token client, the authenticated transport, and the read and write clients. `test/fixtures/` holds real server responses |
| `packages/vikunja_logic/` | Pure Dart client logic ported from the behaviour of the web frontend and pinned by its test vectors: the Quick Add Magic parser, the server's date math and the web's date ranges, the list views' subtask trees and sorts, the filter engine, the rich-text parser of the web editor's format, task links, deep links and the attachment rules |
| `plugins/vikunja_widgets/` | In-repo Flutter plugin of the home-screen widgets (Dart, Kotlin and Swift): the snapshot files, the Android widgets' configs, redraws and "Add widget", the iOS App Group container. A workspace member, not a pure-Dart package |
| `plugins/vikunja_storage_flush/` | In-repo Flutter plugin, Android only (Dart and Kotlin): waits until secure storage's pending writes are on disk after a token write ([Sessions](decisions.md#sessions)). A workspace member, not a pure-Dart package |
| `branding/` | Vikunja's logo as the source and the scripts that derive the icon PNGs and the two Google Play graphics from it; the terms for the name and the logo are in [NOTICE.md](../NOTICE.md#name-and-logo) |
| `fastlane/` | The store listings' texts and screenshots in fastlane's layout, copied into the consoles by hand; fastlane itself is not used ([store-listing.md](store-listing.md)) |
| `test_servers/` | Docker Compose stack with one Vikunja 2.8.0, pinned by its digest (the service `vikunja`; another release through `VIKUNJA_APP_TEST_VIKUNJA_IMAGE`, another database path through `VIKUNJA_APP_TEST_DATABASE_PATH`), for the contract tests and manual sign-in ([Servers](decisions.md#servers)). `seed/e2e-user.env` holds the throwaway sign-in test user; the opt-in profile `tls` adds the TLS test servers ([test_servers/tls/README.md](../test_servers/tls/README.md)) |
| `tool/` | Scripts for CI and local work: the format and pure-Dart checks; `check_exported_components.py`, which checks the exported Android components of the release build against its allowlist; `add_widget_extension.rb`, which adds the iOS widget extension to the Xcode project and keeps its file list in sync; `add_runner_tests.rb`, which sets up the target `RunnerTests` of the native iOS tests and its shared scheme and keeps the Runner target's Swift files in sync; `gen_tls_test_certs.sh`, `tls_e2e.py` and `wait_for_test_servers.sh --tls` for the TLS test servers; `build_android_notices.py`, which writes the Android libraries' notices for the licence page (`app/assets/legal/android.md`) from the Gradle lockfile, with the licence texts in `android_notices/` and those of the embedded Cronet AARs in `android_notices/cronet/`; `check_store_metadata.py`, which checks the store listings; `seed_demo_data.py`, which fills a test account with demo data in German or English; `store_screenshots.sh`, which takes the store screenshots on an emulator or a simulator; `l10n_progress.py`, which prints how much of the English each ARB file translates. `tool/e2e/` holds the update test from the old app and the smoke test of a fresh install on an emulator ([below](#update-and-smoke-tests-on-an-emulator)). `tool/ci/` holds the scripts of the CI jobs, their pins (`pins.sh`), the release version (`release_version.py`), the desugar_jdk_libs source (`desugar_source.py`), the release's build, signing and publish steps (`release_build.sh`, `release_sign.sh`, `release_publish.sh` with `play_upload.py`, `key_properties.py` and `release_certificates.txt`), the local dry run `release.sh`, the iOS release from a Mac (`ios_release.sh`) with the checks of its required-reason APIs (`required_reason_apis.py`) and licence notices (`ios_notices.py`), and their Python tests |
| `docs/` | Architecture, decisions, roadmap, open questions, the threat model, the release checklist, the store listings, research |
| `.github/workflows/` | GitHub Actions: `ci.yaml` with the jobs `checks`, `editor`, `contract`, `android`, `osv` and `ios` (GitHub's macOS runner with Xcode 27); `release.yaml` for `v*` tags, which builds unsigned, then signs and publishes in go-vikunja/app after a reviewer's approval, which a beta before the first final release may go without ([releasing.md](releasing.md)); `upstream.yaml`, weekly, which fails when Flutter or Cronet is newer than the pins; `contract-matrix.yaml`, the contract tests against every supported minor line of Vikunja, nightly in go-vikunja/app, on `v*` tags and by hand ([contract tests](#contract-tests)); `crowdin.yaml`, nightly and by hand on `main` of go-vikunja/app, which uploads the English source to Crowdin and opens a pull request with the approved translations ([releasing.md](releasing.md#once-in-go-vikunjaapp)). Each job runs a script of `tool/ci/` |
| `.github/dependabot.yml` | Weekly pull requests for the GitHub Actions, pinned by SHA |
| `.github/ISSUE_TEMPLATE/`, `.github/PULL_REQUEST_TEMPLATE.md` | The issue forms for bugs and features (blank issues off; links to the forum, Matrix, the security policy and Crowdin) and the pull request template |
| `crowdin.yml` | What the workflow "Crowdin" syncs with Vikunja's Crowdin project through Crowdin's CLI: the English ARB file as the source, the name of each language's file, only approved translations; no token ([Languages](decisions.md#languages)) |
| `LICENSE`, `NOTICE.md`, `CONTRIBUTING.md`, `SECURITY.md` | The MIT License; the copyright, the name-and-logo terms, the earlier history and the third-party notices; how to contribute; how to report a security problem |
| `osv-scanner.toml` | Advisories accepted after review, each with a reason and an expiry |
| `app/android/app/gradle.lockfile` | The locked Android runtime dependencies, for the scan |
| `app/android/gradle/verification-metadata.xml` | The SHA-256 of every file the Android build fetches, which Gradle checks ([releasing.md](releasing.md#gradle-dependency-verification)) |

The repository is a Dart [pub workspace](https://dart.dev/tools/pub/workspaces). The root `pubspec.yaml` lists `app`, the packages and the plugins, and they share one `pubspec.lock`.

## Prerequisites

- **Flutter 3.47.9 (Dart 3.13.7)**, exactly. CI pins this version (`tool/ci/pins.sh`).
- **Android:** the Android SDK (`flutter doctor` shows what is missing), an emulator or a device, and JDK 17 or newer. CI uses the JDK 21 of GitHub's runner image.
- **iOS (macOS only):** Xcode with an iOS simulator runtime. `xcode-select` must point at Xcode, not at the Command Line Tools:

  ```sh
  xcode-select -p   # must print /Applications/Xcode.app/Contents/Developer
  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
  ```

  Setting `DEVELOPER_DIR` is not enough. The Dart native-asset build hooks (for example `objective_c`, used by `cupertino_http`) ignore it, and iOS builds fail.
- **Docker** for the test servers. Docker Desktop works, and so does [colima](https://github.com/abiosoft/colima) with the docker CLI. Either `docker compose` or the standalone `docker-compose` works.
- **curl and jq** for the scripts in `tool/`, and **python3** (standard library only) for its Python scripts.

## Common commands

Run all of these from the repository root unless a `cd` says otherwise.

```sh
flutter pub get                       # at the ROOT only: once per checkout, after a pull, after pubspec or ARB changes
flutter analyze                       # analyzes app/ and packages/
tool/check_format.sh                  # format check as in CI; --fix formats in place
tool/check_pure_dart_packages.sh      # packages/*/lib must not depend on Flutter (needs jq)
```

### Generated code

The generated `*.g.dart` files are committed. CI regenerates them and fails when they differ from the committed ones. After you change annotated providers or Drift tables and DAOs, run:

```sh
cd app && dart run build_runner build
```

The l10n code in `app/lib/l10n/generated/` is not committed ([Languages](decisions.md#languages)): `flutter pub get` at the root writes it (`generate: true`), and so do `flutter build` and `flutter run`. Run `flutter pub get` after a pull or an ARB change, since `flutter analyze` and `flutter test` do not write it and an incremental `flutter build` or `flutter run` misses a new ARB file. `python3 -I tool/l10n_progress.py` shows how much of the English each language translates.

The database schema is versioned ([Sync](decisions.md#sync)). `app/drift_schemas/drift_schema_v<N>.json` holds the dump of every schema version (drift_dev's file name); today those are `drift_schema_v1.json` and `drift_schema_v2.json`. `app/test/core/db/generated/` is generated from the dumps, and `test/core/db/schema_test.dart` checks that the generated schema of the latest version still matches the code. After a schema change, bump `schemaVersion`, dump the new version from `app/` (so drift's build options apply), regenerate the test helpers and add a migration test:

```sh
cd app && dart run drift_dev schema dump lib/core/db/app_database.dart drift_schemas/drift_schema_v<N>.json
cd app && dart run drift_dev schema generate drift_schemas/ test/core/db/generated/
```

The launcher icons are generated from `branding/png/` and committed too. After you change the branding PNGs (`branding/build-icons.sh`), run:

```sh
cd app && dart run flutter_launcher_icons
```

flutter_launcher_icons 0.14.4 rewrites `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` to `AppIcon` in `app/ios/Runner.xcodeproj/project.pbxproj`; set it back to `YES` afterwards, and remove the `scale` key it writes into the three universal 1024 × 1024 entries of the iOS `AppIcon.appiconset/Contents.json` (`app/test/app/xcode_project_test.dart` checks both).

The iOS widget extension is a target of `app/ios/Runner.xcodeproj` that `tool/add_widget_extension.rb` adds and keeps in sync. After you add or remove a Swift file or a language in `app/ios/VikunjaWidgets/`, run it again (it needs the xcodeproj gem, which comes with CocoaPods); with nothing to change it says the target is up to date:

```sh
ruby tool/add_widget_extension.rb
```

The native iOS tests are the target `RunnerTests` of the same project, a test bundle without a host app that compiles the Swift files it tests itself, with the shared scheme `RunnerTests`. `tool/add_runner_tests.rb` sets them up and keeps the Runner target's Swift files in sync with `app/ios/Runner`. Run it after `add_widget_extension.rb` whenever you add or remove a Swift file in `app/ios/Runner` or `app/ios/RunnerTests`, or change which files the tests compile; with nothing to change it says so:

```sh
ruby tool/add_runner_tests.rb
```

The in-app logo (`app/assets/branding/logo.png`) and the status bar icon (`ic_notification.png`) are separate exports of `branding/png/`; see [branding/README.md](../branding/README.md#using-the-assets-in-the-app).

### Tests

```sh
(cd app && flutter test)
(cd app && flutter test test/a11y)   # only the accessibility sweep (phones and tablets), the 3.12× text check and the static rules, about a minute and a half
(cd packages/vikunja_domain && flutter test)
(cd packages/vikunja_logic && flutter test)
(cd packages/vikunja_api && flutter test --exclude-tags contract)
(cd plugins/vikunja_widgets && flutter test)
(cd plugins/vikunja_storage_flush && flutter test)
(cd app/android && ./gradlew :app:testDebugUnitTest -x compileFlutterBuildDebug)   # the Kotlin code, on the JVM
```

On a Mac, the XCTests of the native iOS code (`app/ios/RunnerTests`: the photo location removal and the widgets' Done queue) run on a simulator, after an iOS build has generated `app/ios/Flutter/ephemeral` (for example `cd app && flutter build ios --no-codesign`), as the project needs the Swift package it holds; `xcrun simctl list devices available` names the simulators:

```sh
xcodebuild test -project app/ios/Runner.xcodeproj -scheme RunnerTests -destination 'platform=iOS Simulator,name=<an iPhone>' CODE_SIGNING_ALLOWED=NO
```

The pure packages also use `flutter test` (see [Stack and structure](decisions.md#stack-and-structure)). The app's tests run on an in-memory SQLite, so they need no server and no device.

### Security checks and Android dependencies

Security checks that CI runs besides the tests (all of them, with the manual ones, are in the threat model's [sign-off checklist](threat-model.md#8-security-checklist-for-sign-off)):

```sh
(cd app && flutter build apk --release)
python3 -I tool/check_exported_components.py --self-test
python3 -I tool/check_exported_components.py        # the merged release manifest: fails on a new or changed exported component
(cd app/editor && npm audit --package-lock-only --audit-level=high)
flutter pub outdated --no-dev-dependencies          # informational
```

The OSV scan runs in the job `osv`, also weekly; locally, `tool/ci/osv.sh` does the same (with `osv-scanner` from PATH, else the pinned release, downloaded and checked). The Android dependencies are locked in `app/android/app/gradle.lockfile`, and Gradle checks every file it fetches against `app/android/gradle/verification-metadata.xml`: after a plugin, Flutter or Android dependency change the build fails until both are written again; then read the diff and commit them ([releasing.md](releasing.md#gradle-dependency-verification)):

```sh
(cd app && flutter build apk --config-only)          # creates app/android/gradlew if it is missing
(cd app/android && ./gradlew --write-verification-metadata sha256 --write-locks :app:dependencies \
  :app:assembleRelease :app:bundleRelease :app:assembleDebug :app:assembleProfile :app:testDebugUnitTest)
```

`app/android/settings.gradle.kts` changes one plugin's build ([Diagnostics](decisions.md#diagnostics)): sentry_flutter's build script puts the Android Gradle plugin 7.4.2 on its own classpath, which would fetch that plugin and its tools and need them in the verification metadata. A `gradle.beforeProject` hook removes `com.android.tools.build:gradle` from that classpath for the project `sentry_flutter` only, so that it builds with the app's 9.1.0, as every plugin does. The hook matches the group and the name, not the version, so a raise of sentry_flutter keeps it working.

The licence page lists the Android libraries from that lockfile; CI fails until their notices are written again too, then commit `app/assets/legal/android.md`. A library of a new Maven group needs its licence in the script's table first; a Google Play services library is refused. The code that Sentry's Java SDK vendors comes from a copy of the notices file in its jar, checked by its SHA-256 per version ([releasing.md](releasing.md#crash-reports)). After the Cronet version changed (`cronet-bundled` in `app/android/app/build.gradle.kts`, a build of a Chrome stable release; [releasing.md](releasing.md#raising-cronet)), write the lock and build the release APK once, so that Gradle has the new AARs, then copy their licence files with `--refresh-cronet` (it checks the AARs against Google's Maven and refuses a Chromium build that is not a Chrome stable release) and commit `tool/android_notices/cronet/` too:

```sh
python3 -I tool/build_android_notices.py           # --check only compares, --self-test tests the script
python3 -I tool/build_android_notices.py --refresh-cronet
```

### CI scripts

CI runs on GitHub Actions ([Releases](decisions.md#releases)). `.github/workflows/` only says when each job runs; each job runs one script of `tool/ci/`, and every script runs the same way on a Mac, with the Flutter on PATH (a version other than the pinned one is only a warning there):

```sh
tool/ci/checks.sh                   # generated code, format, pure-Dart packages, the Android notices, analyze, the Python tests of tool/ci/, ShellCheck, the self-test of tool/e2e/ui.py
tool/ci/test.sh                     # the tests of the app, the packages and the plugins, without the contract tests
tool/ci/editor.sh                   # npm audit of the shipped packages, the editor's tests and the committed page
tool/ci/android.sh                  # the release APK with the debug key, the exported components, the Kotlin tests
tool/ci/osv.sh                      # the vulnerability scan of the three lockfiles; the editor's test-only packages warn only
tool/ci/contract.sh                 # the test servers in your Docker, then the contract tests of vikunja_api and the app
tool/ci/ios.sh                      # on a Mac: the unsigned iOS build, its licence notices and required-reason APIs, then the XCTests on a simulator
tool/ci/upstream.sh                 # whether Flutter's stable release or Google Maven's cronet-bundled is newer than the pins
tool/ci/crowdin_sync.sh --dry-run download   # what the workflow "Crowdin" would do; only a run on main of go-vikunja/app talks to Crowdin
```

### Store listings and releases

The store listings link the app's pages on vikunja.io ([Releases](decisions.md#releases), [store-listing.md](store-listing.md)):

```sh
python3 -I tool/check_store_metadata.py          # the store texts' limits and rules, US spelling, the URLs, the email and the copyright; --strict before submitting
python3 -I tool/seed_demo_data.py --lang en      # demo data on the local test server, in English (German by default); --reset swaps the language
tool/store_screenshots.sh --list                 # the screenshot motifs; the script takes them on an emulator or a booted simulator only
```

The graphics for Google Play come from `branding/build-store-graphics.sh` (ImageMagick 7), and `tool/store_screenshots.sh` needs ImageMagick 7 too. [store-listing.md](store-listing.md) has the screenshot session.

Android releases come only from the workflow "Release" of a `v*` tag in go-vikunja/app, whose job `publish` signs and publishes after a reviewer's approval; `tool/ci/release.sh --dry-run` runs the same steps locally with throwaway keys and publishes nothing. The iOS build of the same tag goes to TestFlight from a Mac through `tool/ci/ios_release.sh`, whose `--dry-run` builds it unsigned with the same checks. [releasing.md](releasing.md) has the release checklist.

## Contract tests

The contract tests run against a real Vikunja server from `test_servers/`:

```sh
tool/contract_tests.sh                # starts test_servers/ if needed, waits, runs the vikunja_api tests tagged contract
tool/contract_tests.sh test/contract/write_contract_test.dart   # only the write ports (task create, update and delete on v1 and v2)
docker compose -f test_servers/docker-compose.yaml up -d     # or start it by hand
tool/wait_for_test_servers.sh
(cd app && VIKUNJA_CONTRACT=1 TZ=Europe/Berlin flutter test --tags contract --concurrency=1 test/contract)  # the sync engine and the outbox against the live server
(cd app && VIKUNJA_CONTRACT=1 flutter test --tags contract test/contract/outbox_contract_test.dart)   # only the outbox
(cd app && VIKUNJA_CONTRACT=1 VIKUNJA_CONTRACT_PORT=34551 flutter test --tags contract test/contract/outbox_contract_test.dart)   # the same against a server on another port
(cd packages/vikunja_api && VIKUNJA_CONTRACT=1 VIKUNJA_CONTRACT_PORT=34551 flutter test --tags contract test/contract/write_contract_test.dart)   # vikunja_api's take the port too
docker compose -f test_servers/docker-compose.yaml down
VIKUNJA_APP_TEST_VIKUNJA_IMAGE=vikunja/vikunja:2.7.1 tool/ci/contract.sh   # both sets against another release, on a new, empty server
VIKUNJA_APP_TEST_VIKUNJA_IMAGE=vikunja/vikunja:2.3.0 VIKUNJA_APP_TEST_DATABASE_PATH='/tmp/vikunja.db?_busy_timeout=30000&_x=' tool/ci/contract.sh   # 2.3.0, without immediate transactions
```

With the standalone binary (for example colima with Homebrew's docker-compose), use `docker-compose` with the same arguments. The servers listen on `127.0.0.1` only.

The app's contract files run one at a time, as they have not been tried in parallel, and in Europe/Berlin, as the task-list test compares Upcoming with the server's filter strings in that zone. Naming `test/contract` (`tool/contract_tests.sh` does so when given no test file) spares compiling the other test files only to skip them. `tool/ci/contract.sh` runs both sets as CI does, in about 10 to 11 minutes on a Mac, and fails once both have run, naming the sets that failed.

With `VIKUNJA_APP_TEST_VIKUNJA_IMAGE` set to another release's image, `tool/ci/contract.sh` starts the server on 34527 again with it, empty, and the `vikunja_api` tests expect the version of its tag; an image without a release tag is refused. `tool/contract_tests.sh` runs `up -d` too, which recreates a running server whose image or settings differ from the variables and leaves one that matches them. `VIKUNJA_APP_TEST_DATABASE_PATH` replaces the server's database path; with it set, `tool/ci/contract.sh` runs the `vikunja_api` files one at a time, as parallel writes fail without immediate transactions. 2.3.0 needs the path above, as it exits under immediate transactions at a comment's notifications; 2.4.0 to 2.6.0 exit that way only at a data export, which the tests skip before 2.7, and run with the default. Afterwards `docker compose -f test_servers/docker-compose.yaml up -d`, without the variables, brings the latest release and the default path back, also empty, so seed the sign-in test users again (`tool/seed_e2e_user.sh` and `E2E_USER_ENV=test_servers/seed/e2e-user-2.env tool/seed_e2e_user.sh`).

The `vikunja_api` contract tests cover, on both API versions, the negotiation, the OAuth flow, the read client and the write client (task creates, updates, moves, repeats, deletes, labels, assignees and reminders, with the v1 full-replace regressions), the user settings, the server notifications, labels, teams and sharing, and the link-share sign-ins. The app's contract tests register their own users, seed projects and tasks and run the app's code against the server: the initial and incremental sync (the database must mirror the server, and a sync with nothing new costs exactly 5 requests), the outbox (writes, replays after a lost answer, repeating tasks, creates and edits made offline), quick add, the activity sync, the stored project permission, the timeline and the table, link-share guests and the parity suite. All are tagged `contract` and skipped without `VIKUNJA_CONTRACT=1`.

CI's job `contract` tests the latest Vikunja release on every push and pull request: one server, 2.8.0 on port 34527 (`/api/v2`, full tier). The workflow "Contract matrix" (`.github/workflows/contract-matrix.yaml`) runs `tool/ci/contract.sh` against the newest release of each minor line from the 2.3.0 floor, 2.3.0, 2.4.0, 2.5.0, 2.6.0, 2.7.1 and 2.8.0, each pinned by its digest: every night in go-vikunja/app, on every `v*` tag and by hand under Actions. Its run on a tag replaces the local run against the previous minor version before a release ([releasing.md](releasing.md#cutting-a-release)). The tests take the release from the image's tag and assert what differs between releases from its first release, skipping it or asserting the old way before ([Servers](decisions.md#servers) lists those the app answers for; the others are gated in the tests themselves): `vikunja_api`'s helpers `contractServerHasV2`, `skipWithout` and `contractApiVersions` skip the v2 groups on 2.3, and `seedRequest` and the app's `Seeder` send seeding written for v2 to v1 there. A new contract test that meets such a difference gates it the same way, or the matrix fails on the older releases ([Servers](decisions.md#servers)). Older servers are also covered by unit tests with recorded `/info`, error and entity responses. Each contract test file registers its own throwaway users. Vikunja allows 10 sign-ins, registrations, link-share sign-ins and WebSocket upgrades per minute per IP and cannot turn that limit off, so the test server raises it to 1000; it also opens its SQLite with immediate transactions, so that parallel test files wait for each other's writes instead of failing with "database is locked" (both in `test_servers/docker-compose.yaml`; the database path can be replaced, above). The contract tests never touch the fixed sign-in user of `test_servers/seed/e2e-user.env`.

The connection settings have opt-in test servers of their own: the compose profile `tls` puts a second 2.8.0 (`vikunja-tls`) behind Caddy on 34528 (a self-signed certificate), 34529 (a client certificate required) and 34530 (an access-header gate like Cloudflare Access), with 34531 in plain HTTP for seeding. CI, a plain `up -d` and `tool/contract_tests.sh` never start it. [test_servers/tls/README.md](../test_servers/tls/README.md) has the certificate script, the start, seed and stop commands, the emulator steps and the test matrix; with the profile up, `(cd app && VIKUNJA_APP_TLS_DOCKER=1 flutter test --tags tls-docker)` runs the Docker tests.

## Running the app

On an Android emulator:

```sh
cd app
flutter devices                       # find the emulator id, e.g. emulator-5554
flutter run -d emulator-5554
```

Forward the emulator's `localhost:34527` to the host once per emulator start, then enter `http://localhost:34527` as the server address (the same address works on the iOS simulator):

```sh
adb reverse tcp:34527 tcp:34527
```

The app uses a server over plain `http://` only after you confirm it; the permission is kept for that server address and can be revoked under Connection in the Account tab.

**Crash reports** ([Diagnostics](decisions.md#diagnostics)) are only in a build made with a Sentry DSN, which the release builds take from a repository variable ([releasing.md](releasing.md#crash-reports)). Without it there is no question, no switch and no running SDK. To try them, pass a DSN as a define:

```sh
cd app
flutter run -d emulator-5554 --dart-define=VIKUNJA_APP_SENTRY_DSN=https://public@example.invalid/1   # the question and the switch; nothing reaches Sentry
VIKUNJA_APP_UNSIGNED=true flutter build apk --release --dart-define=VIKUNJA_APP_SENTRY_DSN=…
```

A DSN whose host does not exist, like the one above, shows the question after the first sign-in, the switch at the end of Account › App lock and privacy and the Account tab's "Crash reports: On" or "Off", and sends nothing. With the project's real DSN the build sends to the old app's Sentry project under its own release, so use it only for a build that should. Never commit a DSN: pass it on the command line or from your shell's environment; the build's copies, in `app/ios/Flutter/Generated.xcconfig` and `flutter_export_environment.sh`, are ignored by git. The question comes only once per installation, as the answer is a device setting (`crash_reports.consent`); clear the app's data to see it again. The tests run without a DSN; a test of a build with crash reports overrides the providers with `crashReportOverrides()` of `app/test/helpers/crash_report_fakes.dart`, whose `testCrashReportsDsn` names no real project, and a fake SDK.

## Sign in on a device (end to end)

Browser sign-in is tested by hand against the Docker test servers, with a fixed test user. Its username and password are in [`test_servers/seed/e2e-user.env`](../test_servers/seed/e2e-user.env); a second user for the multi-account flows is in [`test_servers/seed/e2e-user-2.env`](../test_servers/seed/e2e-user-2.env) (create it with `E2E_USER_ENV=test_servers/seed/e2e-user-2.env tool/seed_e2e_user.sh`). They are throwaway values for these local servers only.

Both the Android emulator (after `adb reverse tcp:34527 tcp:34527`) and the iOS simulator use `http://localhost:34527`. The server's `publicurl` is `http://localhost:34527/`, so its web login page also loads in the emulator's browser.

The app's minimum is iOS 15.0. Below iOS 17.4, flutter_web_auth_2 falls back to the older ASWebAuthenticationSession initializer, which handles the app's custom callback scheme ([Accounts and sign-in](decisions.md#accounts-and-sign-in)).

1. Start the test servers and create the user:

   ```sh
   docker compose -f test_servers/docker-compose.yaml up -d   # or docker-compose
   tool/wait_for_test_servers.sh
   tool/seed_e2e_user.sh                 # creates the user on 34527
   ```

   The script is idempotent: for a user that already exists it checks the password with one login. The server keeps its data in a tmpfs, so run it again after the server restarts. It counts against the test server's sign-in limit of 1000 requests per minute per IP.

2. Run the app (`cd app`, then `flutter run -d emulator-5554` or `flutter run -d "iPhone 16 Pro"`), enter `http://localhost:34527` and confirm the unencrypted connection.
3. Tap **Continue to sign-in**.
   - Android: a Custom Tab (or Chrome's Auth Tab) opens the Vikunja login page. On a new emulator, Chrome may show its first-run screens first.
   - iOS: a sign-in sheet opens the Vikunja login page. The session is ephemeral, so iOS asks no "Wants to Use … to Sign In" question.
4. Sign in with the username and password from the env file. To enter the password without printing it, copy it to the clipboard and paste it into the field (the emulator and the simulator share the host clipboard), or type it into the focused field on the emulator:

   ```sh
   # copy to the macOS clipboard; after pasting, empty it with: pbcopy </dev/null
   sed -n 's/^E2E_PASSWORD=//p' test_servers/seed/e2e-user.env | tr -d '\n' | pbcopy
   # or type into the focused field of one emulator, named by its serial from `adb devices`
   adb -s emulator-5554 shell input text "$(sed -n 's/^E2E_PASSWORD=//p' test_servers/seed/e2e-user.env)"
   ```

   The second puts the password on the command line, where `ps` on the Mac and on the emulator shows it while it runs: acceptable only for this throwaway local test password.

5. The sheet closes, the first-sync screen pulls the account, and the app shows the Overview tab. The Account tab shows initials, display name, `@` username, server host and version, when the account was last synced, and **Sync now**; **Sign out** there, after a confirmation, deletes the local data and returns to onboarding. To see tasks and projects, create some in the web app at `http://localhost:34527` with the same user, then pull to refresh, tap Sync now or wait for the minute timer. Tap a task's circle to mark it done: the web app shows it done after a reload. "New task" on the Overview creates one; Edit in its detail sheet changes the rest. Turn the network off afterwards: the lists stay, with an "Offline" notice on refresh; a task checked off, created or edited offline stays that way, the Account tab counts the pending changes, and they are sent as soon as a sync reaches the server again (within a minute while the app is in front, or on "Send now"). Signing out with changes still queued loses them; the sign-out dialog says so.

The server overview also shows **Create account** and **Forgot password?**, because the test server allows registration and has local accounts; it sends no mail, so a new account works at once and a reset mail never arrives. To try a guest, create a link share of a project in the app (Share in the project's menu) or on the web, then paste the link into "Open a shared link" on the Connect screen, or share it to the app from the emulator's browser; the test server's links point to `http://localhost:34527`, so the unencrypted-connection question comes first.

Every sign-in starts with an empty browser session and shows the login form ([Accounts and sign-in](decisions.md#accounts-and-sign-in)). On Android, Chrome before 141 (the emulator image ships 133) gets a regular Custom Tab instead, which can reuse a web login in Chrome; to see the form again there, sign out in Chrome or clear its data for the server.

## Update and smoke tests on an emulator

`tool/e2e/update_test.sh` checks the update over the old app on Android: the first start after it, the first sync and a new start ([The previous app](decisions.md#the-previous-app); [threat model 8.2](threat-model.md#82-manual-on-the-android-emulator), item 13). `tool/e2e/smoke_test.sh` checks a fresh install: Connect, the sign-in through the browser, the first sync and a new start. They run before a release ([releasing.md](releasing.md#cutting-a-release)) and after a change to the update from the old app (`app/lib/core/previous_app/`), onboarding, sign-in or the first sync, never in CI: you do every sign-in, and they ask you about what a screen dump cannot show.

```sh
tool/e2e/smoke_test.sh emulator-5554 <new.apk> <output folder>
tool/e2e/update_test.sh emulator-5554 <old.apk> <new.apk> <output folder>      # over http on the Docker test server: sign in again
tool/e2e/update_test.sh --server https://try.vikunja.io emulator-5554 <old.apk> <new.apk> <output folder>   # over https, a throwaway account: stay signed in
```

- **The emulator:** only the AVDs `Vikunja_Screens` and `Vikunja_Tablet`, the project's own emulators ([store-listing.md](store-listing.md#screenshots)), never your own or a physical device, as the scripts uninstall `io.vikunja.app` with its data; they refuse any other serial before they install anything, and ask before they wipe. Start the emulator yourself; the scripts never start or stop one. They ignore `ANDROID_SERIAL`, send every command to the adb transport they checked at the start, and check it and the AVD's name again after each of your answers and before each install, so they stop when another emulator has taken over the serial.
- **The server:** `--server` defaults to `http://localhost:34527`, the Docker test server, for which the scripts set `adb reverse`. Start it and seed both sign-in users and the demo data first; the first sync must show one of the demo's open tasks, or the tasks named with `--task`:

  ```sh
  docker compose -f test_servers/docker-compose.yaml up -d && tool/wait_for_test_servers.sh
  tool/seed_e2e_user.sh && E2E_USER_ENV=test_servers/seed/e2e-user-2.env tool/seed_e2e_user.sh
  python3 -I tool/seed_demo_data.py
  ```

  On a new emulator, go through Chrome's first-run screens once.
- **The APKs:** one package, a higher version code for the new one and one signing certificate for both, or `adb install -r` fails; the update test checks all three first. The old app is built from its last commit, `cdbc6e3`, in a clone of go-vikunja/app, as 0.1.8-beta with version code 490; its release build wants an `android/key.properties` (its `storeFile` relative to `android/app`), and any key does, as both APKs are signed again. This app is built unsigned, with a higher version code such as the 1000001 of `v1.0.0-beta.1`:

  ```sh
  git clone https://github.com/go-vikunja/app.git <the old app's clone> && git -C <the old app's clone> switch --detach cdbc6e3
  (cd <the old app's clone> && flutter build apk --release --target-platform android-arm64 --build-number=490 --build-name=0.1.8-beta)
  (cd app && VIKUNJA_APP_UNSIGNED=true flutter build apk --release --target-platform android-arm64 --build-number=1000001)
  ```

  Then align both with the build-tools' `zipalign -P 16 4` and sign them with `apksigner sign` and one throwaway key (`keytool -genkeypair`), its passwords passed from the environment or a private file (`--ks-pass env:…`), never on the command line; `apksigner verify --print-certs` shows that key as the only signer.
- **The run:** each check prints PASS, FAIL or SKIP; a script exits 1 when a check failed and 2 when the test could not run. The output folder gets the log, the screen dumps, the screenshots and, from the update test, a recording of the first start, which stops once a browser has the focus or Connect takes input, so it never holds a sign-in. For a sign-in the scripts print only the clipboard route for the E2E user's password, as [above](#sign-in-on-a-device-end-to-end). They read the screen by the app's own English and German texts from the ARB files (`tool/e2e/ui.py`), so a text they look for that is renamed or gone stops them early, naming its key; `python3 -I tool/e2e/ui.py --self-test` checks the matching and runs in `tool/ci/checks.sh`.
- **Crash reports** ([Diagnostics](decisions.md#diagnostics)): a build with a DSN asks about them once, over the shell after the first sync, and the dialog's barrier hides the screen below from the dump. The scripts decline: `decline_crash_reports` in `tool/e2e/lib.sh` finds No thanks with `ui.py point`, taps it with `adb shell input tap` and prints PASS once the question is gone, so a build with a DSN, a release candidate's included, sends nothing during the tests. In a build without a DSN each check of the shell spends about 4 s looking for the question.
- **Needs:** macOS's bash 3.2 or newer, `adb` and the build-tools of the Android SDK, python3 and curl; with ImageMagick 7 (`magick`) the scripts judge the dark theme from a screenshot themselves, else they ask.

## Documentation

- [Architecture](architecture.md): an overview of the current design for new maintainers.
- [Threat model](threat-model.md): assets, trust boundaries, entry points, mitigations with their tests, residual risks with their decisions, and the security sign-off checklist.
- [Releasing](releasing.md): the release checklist: what Vikunja's maintainers set up once in go-vikunja/app, the website and the store consoles, the version and the tag, what the release workflow publishes to Google Play, dl.vikunja.io and GitHub, the staged rollout, retries and the dry run, and the iOS build's way to TestFlight.
- [Beta](beta.md): how a beta runs, from the steps before the first tag to the testers, the feedback and the final release.
- [Store listings](store-listing.md): what both stores' listings say, every form of the Play Console and App Store Connect with its answer and why, the graphics and the screenshot session.
- [Drafts for vikunja.io](vikunja-io-drafts.md): the privacy section "Mobile app", the help page `/help/mobile` and the imprint's scope sentence.
- [Glossary](glossary.md): the terms and the style of the app's texts in English and German, which every string follows.
- [Accessibility checklist](accessibility-checklist.md): the manual pass with TalkBack, Switch Access and VoiceOver that goes with the automated accessibility sweep.
- [Roadmap](roadmap.md): what is left before and after 1.0.
- [Decisions](decisions.md): the decision log.
- [Open questions](open-questions.md): the answered questions and those still open or deferred.
- [Research](research/README.md): the research the architecture is based on.
