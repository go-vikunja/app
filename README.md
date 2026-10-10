# Rurana

Rurana (name and logo: see [branding/README.md](branding/README.md)) is an unofficial mobile client for self-hosted [Vikunja](https://vikunja.io) servers, for Android and iOS, built with Flutter. The Vikunja project does not make, endorse or support it.

## Status

Steps 1 to 7 of the [roadmap](docs/roadmap.md) are done: server connection and v1/v2 negotiation, browser sign-in (OAuth 2.0 + PKCE) with a session manager, and projects and tasks in a local database per account that an initial sync fills and an incremental sync keeps current, deletions included, so the app works offline and web changes reach the phone for a handful of requests. **Step 11 (outbox engine and the first mutations) is in progress**: marking a task done (with Undo), the favourite star and deleting a task work offline, through an outbox that sends the changes to the server with retries ([D34](docs/decisions.md#d34-outbox-local-first-writes-serial-sender-coalescing-retry-classes-sync-interplay-pending-fields-win-until-sent-pending-deletes-hidden-v1-full-replace-emulation)). Steps 8 to 10 (shell polish, the offline list variants, the full task detail) remain planned and follow. The project applies the owner's decisions of 2026-10-09 (app id, browser sign-in only, the 2.3.0 floor). Name and icon: Rurana with the "checkbox ears" llama (see [branding/README.md](branding/README.md)).

### What you can do now

- **Connect to a server.** The app takes an address, probes `/api/v2/info` (Vikunja 2.4.0 and newer) and `/api/v1/info` in parallel, uses v2 when both answer, and shows the server version, the API mode, the support tier and the detected capabilities. Servers older than 2.3.0 are reported as unsupported, because browser sign-in needs 2.3.0.
- **Sign in** through the system browser. The session is refreshed transparently and survives restarts; sign-out after a confirmation, which also deletes the account's local data.
- **First sync** right after sign-in: a progress screen with the current phase and counts pulls the whole account into the local database. It resumes where it stopped if the app is killed, and shows a Retry when the server is unreachable.
- **Offline:** every screen reads from the local database, so projects and tasks are there without the server. Pull to refresh or "Sync now" in the Account tab runs an incremental sync; while offline, lists show the saved data with an "Offline" notice, and a change made offline is queued and sent once the server answers again (step 11).
- **Stays current:** the app syncs on start, when it comes back to the foreground, every minute while it is open and on pull to refresh. A sync pulls only the tasks changed since the last run (keyed on the server's `updated`), catches tasks deleted on the web by comparing the server's task count with the local one (per project only when they differ), and falls back to a full re-pull once a day; "Full resync" in the Account tab forces one ([D33](docs/decisions.md#d33-incremental-sync-watermark-on-updated-with-a-120-s-overlap-keyset-over-updated-id-delete-detection-by-per-project-count-check-and-id-reconcile-daily-full-resync)).
- **Overview tab:** your open tasks across all projects, grouped into Overdue, Today, Next 7 days, Later and No due date, with identifier, project, relative due date, priority, labels and favourite.
- **Projects tab:** favourites first, then the project tree. A project opens its task list, with a "Show done tasks" toggle.
- **Task detail:** a sheet with title, identifier and project, done state, dates, priority, percent done, labels, assignees, reminders, repeat and the description as plain text.
- **Mark done, favourite, delete (step 11, in progress):** tap the circle on a task row to mark it done (struck through at once, with a haptic and a "Marked done · Undo" snackbar for 3 s) and the star to toggle the favourite, in the rows and in the task detail sheet; Delete sits in the sheet's menu behind a confirmation. Every change is applied to the local database at once and queued in an outbox, so it works offline and survives a restart; a serial sender pushes the queue to the server with retries and refreshes afterwards. A repeating task comes back open with its next dates once the server answers. On a server with only `/api/v1`, an update reads the task first and posts it back whole, so assignees and reminders survive ([D34](docs/decisions.md#d34-outbox-local-first-writes-serial-sender-coalescing-retry-classes-sync-interplay-pending-fields-win-until-sent-pending-deletes-hidden-v1-full-replace-emulation)).
- **Account tab:** who is signed in on which server, when the account was last synced, "Sync now" and "Full resync", a "Sign in again" banner when the session ended, sign out. Since step 11 (in progress): "Pending changes: N" with "Send now" while something is queued, and a "Sync problems" list for changes the server rejected for good (no access, project gone or archived, validation), each with Retry and Discard; rows with unsent changes show a small cloud-off icon. Undo on a repeating task takes the previous occurrence back, dates included.
- English and German, dark mode, large text. A slim progress bar shows a running sync.

Beyond done, favourite and delete, tasks cannot be edited or created yet (step 12). Kanban buckets, comments and attachments are not synced yet.

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
| Name | Rurana (Quechua for "what is to be done"), see [branding/README.md](branding/README.md) |
| Store listing | `Rurana – client for Vikunja` (de: `Rurana – Client für Vikunja`) |
| Icon | The "checkbox ears" llama from [branding/](branding/README.md), generated into the platform projects by `flutter_launcher_icons` |
| Android `applicationId`, iOS bundle id | `dev.coderoftime.vikunja` ([D15](docs/decisions.md#d15-app-id-devcoderoftimevikunja)) |
| Dart package | `vikunja_mobile` (internal only, never shown) |

## Repository layout

| Path | Contents |
|---|---|
| `app/` | Flutter app (feature-first: `lib/features/*`, shared code in `lib/core/`: auth, the Drift database in `db/`, the sync engine in `sync/`, the outbox and its sender in `outbox/`, repositories). `drift_schemas/` holds the schema dumps the migration tests compare against |
| `packages/vikunja_domain/` | Pure Dart domain model: server version, capabilities, support tier, connection result and failures; user, account, tokens, `VikunjaFailure`; projects, views, labels, tasks, reminders, `Page<T>`, `TaskQuery`, `TaskChanges` |
| `packages/vikunja_api/` | Pure Dart API client: address normalisation, `/info` parsing, parallel v2/v1 `/info` probing, error normalisation, OAuth + PKCE token client, authenticated transport, the read client for projects, labels and tasks over v1 and v2, and the write client for task updates and deletes (v2 merge-patch, v1 full-replace emulation). `test/fixtures/` holds real server responses |
| `branding/` | Name, logo and icon sources (SVG) with the rendered PNGs |
| `test_servers/` | Docker Compose stack with one Vikunja 2.7.0 for contract tests and manual sign-in ([D28](docs/decisions.md#d28-test-only-the-latest-vikunja-release)). `seed/e2e-user.env` holds the throwaway sign-in test user |
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

The generated `*.g.dart` and l10n files are committed. CI regenerates them and fails when they differ from the committed ones. After you change ARB files, annotated providers or Drift tables and DAOs, run:

```sh
cd app && flutter gen-l10n && dart run build_runner build
```

`flutter pub get` regenerates the l10n files on its own (`generate: true`), but `build_runner` (riverpod_generator and drift_dev) only runs by hand.

The database schema is versioned ([D31](docs/decisions.md#d31-one-drift-sqlite-file-per-account-shared-across-isolates-deleted-on-sign-out)). `app/drift_schemas/drift_schema_v<N>.json` holds the dump of every schema version (drift_dev's file name), `app/test/core/db/generated/` is generated from the dumps, and `test/core/db/schema_test.dart` checks that the generated schema still matches the code. After a schema change, bump `schemaVersion`, dump the new version from `app/` (so drift's build options apply), regenerate the test helpers and add a migration test:

```sh
cd app && dart run drift_dev schema dump lib/core/db/app_database.dart drift_schemas/drift_schema_v<N>.json   # versions 1 and 2 exist
cd app && dart run drift_dev schema generate drift_schemas/ test/core/db/generated/
```

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

The pure packages also use `flutter test` (see [D9](docs/decisions.md#d9-flutter_test-instead-of-packagetest-in-pure-packages)). The app's tests run on an in-memory SQLite, so they need no server and no device.

Contract tests against the real server:

```sh
tool/contract_tests.sh                # starts test_servers/ if needed, waits, runs the vikunja_api tests tagged contract
tool/contract_tests.sh test/contract/write_contract_test.dart   # only the write ports (task update and delete on v1 and v2)
docker compose -f test_servers/docker-compose.yaml up -d     # or start it by hand
tool/wait_for_test_servers.sh
(cd app && VIKUNJA_CONTRACT=1 flutter test --tags contract)  # the sync engine and the outbox against the live server
(cd app && VIKUNJA_CONTRACT=1 flutter test --tags contract test/contract/outbox_contract_test.dart)   # only the outbox
docker compose -f test_servers/docker-compose.yaml down
```

The `vikunja_api` contract tests cover negotiation, the OAuth flow, the read client and, since step 11, the write client (`packages/vikunja_api/test/contract/write_contract_test.dart`, both adapters): a task seeded with an assignee, two reminders and a label is marked done and must keep all three, which is the v1 full-replace regression; undo, favourite on and off, a title change, a repeating task marked done comes back open with its due date a day later, and a delete followed by a second delete does not throw.

The app's contract tests register a user, seed projects and tasks and run the sync engine into an in-memory database: the initial sync test checks the counts; the incremental sync test (`app/test/contract/incremental_sync_contract_test.dart`) changes the server through the API (creates, edits, deletes, a move, a new and an archived project, label changes), runs one `refresh()` on each API version and checks that the database mirrors the server, that the keyset filter over `(updated, id)` is accepted, and that a sync with nothing new costs exactly 4 requests; the outbox contract test (`app/test/contract/outbox_contract_test.dart`, both API versions) marks a task done, toggles the favourite and deletes a task through the repository, drains the outbox and checks the server and the local row, replays a write whose first attempt failed with a network error, and marks a repeating task done, which must come back open with the server's shifted date. All are tagged `contract` and skipped without `VIKUNJA_CONTRACT=1`.

With the standalone binary (for example colima with Homebrew's docker-compose), use `docker-compose` with the same arguments. The servers listen on `127.0.0.1` only.

Only the latest Vikunja release is tested: one server, 2.7.0 on port 34527 (`/api/v2`, full tier). Older servers down to the 2.3.0 floor stay supported in code and are covered by unit tests with recorded `/info`, error and entity responses ([D28](docs/decisions.md#d28-test-only-the-latest-vikunja-release)). Each contract test file registers one throwaway user and reuses it; the server allows 10 logins or registrations per minute per IP, so leave a minute between repeated runs. The contract tests never touch the fixed sign-in user `taskuna-e2e` of `test_servers/seed/e2e-user.env`.

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

5. The sheet closes, the first-sync screen pulls the account, and the app shows the Overview tab. The Account tab shows initials, display name, `@` username, server host and version, when the account was last synced, and **Sync now**; **Sign out** there, after a confirmation, deletes the local data and returns to onboarding. To see tasks and projects, create some in the web app at `http://localhost:34527` with the same user, then pull to refresh, tap Sync now or wait for the minute timer. Tap a task's circle to mark it done: the web app shows it done after a reload. Turn the network off afterwards: the lists stay, with an "Offline" notice on refresh; a task ticked off offline stays ticked, the Account tab counts the pending change, and it is sent as soon as a sync reaches the server again (within a minute while the app is in front, or on "Send now"). Signing out with changes still queued loses them; the sign-out dialog says so.

Every sign-in starts with an empty browser session and shows the login form ([D23](docs/decisions.md#d23-browser-sign-in-through-flutter_web_auth_2-client-id-and-redirect-uri)). On Android, Chrome before 141 (the emulator image ships 133) gets a regular Custom Tab instead, which can reuse a web login in Chrome; to see the form again there, sign out in Chrome or clear its data for the server.

## Documentation

- [Architecture](docs/architecture.md): what exists after steps 1 to 7, what step 11 is building, and what is planned.
- [Roadmap](docs/roadmap.md): all steps and milestones, with status.
- [Decisions](docs/decisions.md): decision log.
- [Open questions](docs/open-questions.md): the owner's answers of 2026-10-09 and the items still deferred.
- [Research](docs/research/README.md): the research snapshot the architecture is based on.

## License

Not decided yet (deferred); see [Q3](docs/open-questions.md#q3-licence-and-distribution). There is no `LICENSE` file yet. Vikunja itself is AGPL-3.0-or-later.
