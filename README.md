# Rurana

Rurana (name and logo: see [branding/README.md](branding/README.md)) is an unofficial mobile client for self-hosted [Vikunja](https://vikunja.io) servers, for Android and iOS, built with Flutter. The Vikunja project does not make, endorse or support it.

## Status

Steps 1, 2+3, 4 to 7, 11, 12a, 12b, 13 and 15 of the [roadmap](docs/roadmap.md) are done: server connection and v1/v2 negotiation, browser sign-in (OAuth 2.0 + PKCE) with a session manager, projects and tasks in a local database per account that an initial sync fills and an incremental sync keeps current, deletions included, so the app works offline and web changes reach the phone for a handful of requests, the first writes: marking a task done (with Undo), the favourite star and deleting a task work offline, through an outbox that sends the changes to the server with retries ([D34](docs/decisions.md#d34-outbox-local-first-writes-serial-sender-coalescing-retry-classes-sync-interplay-pending-fields-win-until-sent-pending-deletes-hidden-v1-full-replace-emulation)), and task editing: a full-screen edit page for title, project, dates, priority, percent done, colour and repeat, a "New task" sheet, and creates through the same outbox under a temporary id that is swapped for the server's once the create is sent ([D35](docs/decisions.md#d35-creates-through-the-outbox-temporary-negative-ids-with-remap-createupdatedelete-coalescing-lost-response-recovery-by-title-within-a-1-h-window)), plus labels and assignees on the edit page, saved through the same outbox (only the labels and people added or removed, sent through the server's label and assignee endpoints), and a reminders editor ([D36](docs/decisions.md#d36-labels-and-assignees-as-id-set-deltas-in-the-task-update-sent-through-their-endpoints-after-a-read-before-write-diff-reminders-as-the-whole-list-label-creation-online-only)). Step 4 added several accounts: an account switcher behind an avatar button on the Overview and Projects tabs and an Accounts section in the Account tab, adding an account on the same or another server, a switch that closes the previous account's screens, removing any account, and the queued changes of the accounts not shown still sent while the app is open ([D37](docs/decisions.md#d37-account-switcher-a-sheet-from-an-avatar-button-and-an-accounts-section-a-switch-resets-the-navigation-the-most-recently-active-account-follows-a-removal-inactive-outboxes-drain-in-the-foreground)). Step 13 added Quick Add Magic and the composer: the title field of the "New task" sheet understands the web's quick-add syntax for labels, project, people, priority, dates and repeats, shows what it understood while you type, and creates the task with all of it through the outbox, offline too ([D38](docs/decisions.md#d38-quick-add-the-web-grammar-in-vikunja_logic-with-d19s-fixes-weekday-and-ordinal-dates-at-the-default-time-and-an-unknown-project-kept-in-the-title-a-live-composer-labels-created-online-and-assignees-looked-up-on-submit-the-task-through-the-outbox)). Step 15 added local reminder and due-date notifications with Done and Snooze: the app schedules OS notifications from its local database for the reminders and due dates of the open tasks you created or are assigned to, in every signed-in account, with Done and Snooze right in the notification and a tap that opens the task ([D17](docs/decisions.md#d17-notification-policy), [D39](docs/decisions.md#d39-local-notifications-a-scheduler-per-signed-in-account-plans-from-the-local-database-and-diffs-against-a-rolling-window-with-stable-keys-exact-alarms-when-allowed-done-through-the-outbox-from-a-background-isolate-without-a-token-refresh-snooze-local-only-permissions-asked-once-after-the-first-sync)). **Step 16 (background sync, activity notifications and a notifications inbox) is in progress**: the app syncs every signed-in account in the background as far as the OS allows, which keeps their sessions alive and refills the scheduled notifications while the app is closed, and it shows the server's notifications (comments, assignments, mentions) in an inbox and as notifications ([D22](docs/decisions.md#d22-session-keep-alive-through-background-sync), [D40](docs/decisions.md#d40-background-sync-one-periodic-job-for-every-signed-in-account-with-a-deadline-skipped-while-the-app-is-in-front-the-incremental-run-as-the-session-keep-alive-a-one-off-drain-after-a-background-done-server-notifications-synced-into-a-local-inbox-on-their-own-cadence-new-unread-ones-as-activity-notifications-the-first-run-silent)). Steps 8 to 10 (shell polish, the offline list variants, the full task detail) remain planned. The project applies the owner's decisions of 2026-10-09 (app id, browser sign-in only, the 2.3.0 floor). Name and icon: Rurana with the "checkbox ears" llama (see [branding/README.md](branding/README.md)).

### What you can do now

- **Connect to a server.** The app takes an address, probes `/api/v2/info` (Vikunja 2.4.0 and newer) and `/api/v1/info` in parallel, uses v2 when both answer, and shows the server version, the API mode, the support tier and the detected capabilities. Servers older than 2.3.0 are reported as unsupported, because browser sign-in needs 2.3.0.
- **Sign in** through the system browser. The session is refreshed transparently and survives restarts; sign-out after a confirmation, which also deletes the account's local data.
- **First sync** right after sign-in: a progress screen with the current phase and counts pulls the whole account into the local database. It resumes where it stopped if the app is killed, and shows a Retry when the server is unreachable.
- **Offline:** every screen reads from the local database, so projects and tasks are there without the server. Pull to refresh or "Sync now" in the Account tab runs an incremental sync; while offline, lists show the saved data with an "Offline" notice, and a change made offline is queued and sent once the server answers again (step 11).
- **Stays current:** the app syncs on start, when it comes back to the foreground, every minute while it is open and on pull to refresh (and in the background since step 16, below). A sync pulls only the tasks changed since the last run (keyed on the server's `updated`), catches tasks deleted on the web by comparing the server's task count with the local one (per project only when they differ), and falls back to a full re-pull once a day; "Full resync" in the Account tab forces one ([D33](docs/decisions.md#d33-incremental-sync-watermark-on-updated-with-a-120-s-overlap-keyset-over-updated-id-delete-detection-by-per-project-count-check-and-id-reconcile-daily-full-resync)).
- **Overview tab:** your open tasks across all projects, grouped into Overdue, Today, Next 7 days, Later and No due date, with identifier, project, relative due date, priority, labels and favourite.
- **Projects tab:** favourites first, then the project tree. A project opens its task list, with a "Show done tasks" toggle.
- **Task detail:** a sheet with title, identifier and project, done state, dates, priority, percent done, labels, assignees, reminders, repeat and the description as plain text.
- **Mark done, favourite, delete:** tap the circle on a task row to mark it done (struck through at once, with a haptic and a "Marked done · Undo" snackbar for 3 s) and the star to toggle the favourite, in the rows and in the task detail sheet; Delete sits in the sheet's menu behind a confirmation. Every change is applied to the local database at once and queued in an outbox, so it works offline and survives a restart; a serial sender pushes the queue to the server with retries and refreshes afterwards. A repeating task comes back open with its next dates once the server answers. On a server with only `/api/v1`, an update reads the task first and posts it back whole, so assignees and reminders survive ([D34](docs/decisions.md#d34-outbox-local-first-writes-serial-sender-coalescing-retry-classes-sync-interplay-pending-fields-win-until-sent-pending-deletes-hidden-v1-full-replace-emulation)).
- **Create a task (step 12a):** the "New task" button on the Overview and the + button on a project's list open a sheet: a title, the project (the current one, else your Inbox), Today / Tomorrow / Next week chips or a picked date, and Add. The task is in the list at once, offline too, under a temporary id; "More options" opens the full edit page on it. The create is queued like every other write, and once it is sent the task takes the server's id and identifier. An edit before the send goes out with the create in one request, a delete before the send costs none, and a create whose answer was lost on the way back is looked up on the server before it is sent again, so it is not duplicated ([D35](docs/decisions.md#d35-creates-through-the-outbox-temporary-negative-ids-with-remap-createupdatedelete-coalescing-lost-response-recovery-by-title-within-a-1-h-window)).
- **Edit a task (step 12a):** Edit in the task detail sheet (or a tap on the title) opens a full-screen page: title, project (a change moves the task, which gets a new identifier), due, start and end date with time (with the web's shortcut chips Today, Tomorrow, Next Monday, This weekend, Later this week, Next week, Next weekend, End of month, In a month), priority, percent done, colour and repeat (every so many hours, days or weeks, monthly, or from the completion date). Save sends only what changed, offline too; leaving with unsaved changes asks first.
- **Labels and assignees (step 12b):** the edit page shows the task's labels as chips in their colour and its assignees with initials and name, each with a remove button. "Add label" opens a picker with search and multi-select; when no label has the typed title it offers "Create label "…"", which needs a connection and picks a colour from the web's palette. "Assign" searches the people with access to the project on the server; offline it offers the people from your synced tasks. The changes are saved through the outbox like every other edit, offline too and on a task whose create is still queued (they are sent right after it). Only the labels and people you added or removed are sent, after a look at the task on the server, so a label someone added on the web meanwhile stays and a resend changes nothing twice ([D36](docs/decisions.md#d36-labels-and-assignees-as-id-set-deltas-in-the-task-update-sent-through-their-endpoints-after-a-read-before-write-diff-reminders-as-the-whole-list-label-creation-online-only)).
- **Reminders (step 12b):** the edit page lists the reminders in the detail sheet's wording, each with edit and remove. "Add reminder" offers on the due date and 2 hours, 1 day, 3 days, 1 week or 30 days before it (relative to the start or end date when there is no due date), a custom amount of minutes, hours, days or weeks before or after the due, start or end date, and a date and time. A relative reminder shows when it will be due, or that its date is not set. Undo on a repeating task now restores its reminders together with the dates.
- **Quick add (step 13):** type the whole task into the title of the "New task" sheet, the way the web's Quick Add Magic reads it: `Reifen wechseln *Auto +Privat @anna !3 tomorrow at 9:00 every week` creates "Reifen wechseln" in the project Privat with the label Auto, assigned to anna, priority 3, due tomorrow at 9:00 and repeating every week. The field highlights what it recognised and shows it as chips below, each with a remove button; while you type a `*`, `+` or `@` word it suggests labels, projects and people, a toolbar inserts the prefixes and a priority, and a help sheet explains the syntax. If you chose the Todoist mode in the web's settings, the prefixes are `@` for labels, `#` for projects and `+` for people; if you turned quick add off there, the field is plain. The keywords are English, as on the web. A few web quirks are fixed: `todays`, `next weekend` and `12 decorations` stay text, `every 2 months` and `yearly` repeat, a weekday or a date like `21st` gets the default time instead of the current minute, and a `+project` that matches no project stays in the title with a warning chip. It works offline: the task is queued with its labels, people and dates; a label that does not exist yet is created at submit, which needs a connection (otherwise the task is created without it and the snackbar says so), and `@names` are looked up on the server, offline among the people you already know. Several pasted lines add one task each. Your default project and default reminders from the web's settings apply. A long press on the app icon offers "New task", which opens the composer ([D38](docs/decisions.md#d38-quick-add-the-web-grammar-in-vikunja_logic-with-d19s-fixes-weekday-and-ordinal-dates-at-the-default-time-and-an-unknown-project-kept-in-the-title-a-live-composer-labels-created-online-and-assignees-looked-up-on-submit-the-task-through-the-outbox)).
- **Account tab:** who is signed in on which server, when the account was last synced, "Sync now" and "Full resync", a "Sign in again" banner when the session ended, sign out. Since step 11: "Pending changes: N" with "Send now" while something is queued, and a "Sync problems" list for changes the server rejected for good (no access, project gone or archived, validation), each with Retry and Discard; rows with unsent changes show a small cloud-off icon. Undo on a repeating task takes the previous occurrence back, dates included.
- **Several accounts (step 4):** the avatar button in the app bar of the Overview and Projects tabs opens the account switcher: every account with its name, `@username` and server, the current one first and marked, a "Sign in again" badge when its session ended and "N unsent" while changes wait. A tap switches: every open screen closes and each tab starts over, and an account that has synced before opens without the first-sync screen. "Add account" opens the Connect screen with the servers you already use as one-tap chips; the server's login page always asks for credentials, so another user on the same server works too, and signing in to an account you already have just switches to it. The Account tab lists the other accounts, each with a tap to switch and "Remove…", and "Add account". Removing an account deletes its local data (the dialog says when unsent changes would be lost); removing the one you are looking at switches to the account you used before it, and removing the last one returns to onboarding. Changes queued in an account you are not looking at are still sent while the app is open ([D37](docs/decisions.md#d37-account-switcher-a-sheet-from-an-avatar-button-and-an-accounts-section-a-switch-resets-the-navigation-the-most-recently-active-account-follows-a-removal-inactive-outboxes-drain-in-the-foreground)).
- **Reminders and due-date notifications (step 15):** the phone notifies you at each reminder of an open task you created or are assigned to, and at the exact due time, in every account you are signed in to. The notifications are scheduled from the local database while the app runs (the server never pushes reminders), so they fire without a connection; the app keeps the next 100 (Android) or 60 (iOS) scheduled and refills them whenever something changes. Each notification has **Done**, which marks the task done through the outbox even while the app is closed (sent at once when the session allows it, otherwise with the next sync), and **Snooze 10 min** and **Snooze 1 h**, which only move the notification on this phone; a tap opens the task, switching the account first when needed. After the first sync the app asks once for the notification permission and, on Android 14 and newer, for exact alarms; "Not now" leaves notifications off. The Account tab gets a Notifications section: switches for reminders and due dates per account, a note when notifications are off at the OS level or reminders may be late without exact alarms (each with a button to the system setting), how many are scheduled, and a test notification ([D39](docs/decisions.md#d39-local-notifications-a-scheduler-per-signed-in-account-plans-from-the-local-database-and-diffs-against-a-rolling-window-with-stable-keys-exact-alarms-when-allowed-done-through-the-outbox-from-a-background-isolate-without-a-token-refresh-snooze-local-only-permissions-asked-once-after-the-first-sync)). Android permissions:
  - `POST_NOTIFICATIONS` (Android 13+): showing notifications at all; the setup screen asks for it.
  - `SCHEDULE_EXACT_ALARM`: firing at the exact minute; Android 14+ denies it to a new install until you allow it on the system page the setup screen and the Account tab link to; without it reminders use inexact alarms and can be minutes late. The app never declares `USE_EXACT_ALARM`, which Play reserves for alarm and calendar apps.
  - `RECEIVE_BOOT_COMPLETED`: re-registering the scheduled notifications after a reboot, which would otherwise be lost.

  iOS asks for the notification permission on the same screen and needs nothing else.
- **Background sync and activity (step 16, in progress):** the app syncs while it is closed. One background job covers every account you are signed in to: it runs the same incremental sync as the foreground, sends changes still queued, fetches the server's notifications and refills the scheduled reminders, account by account, the one synced longest ago first. On Android it runs about every 30 minutes when the phone is online, later when the phone is idle or the app is rarely used; on iOS the system decides when, and maybe never (never after you swipe the app away), so open the app to be sure. It does nothing while the app is in front, which syncs on its own. Each run also keeps the account signed in: the server ends a session after 72 hours without a refresh, and every run refreshes it; if a session has ended anyway, a "Sign in again to *server*" notification opens the account's Account tab. A Done from a notification that could not be sent at once (the stored session had expired) goes out within minutes on Android instead of at the next app open. The server's notifications for you (someone commented on, assigned you to, mentioned you on, created or deleted a task, created a project, added you to a team) are kept on the phone: a bell on the Overview shows how many are unread and opens the inbox, grouped by Today, Yesterday and Earlier, where a tap marks one read and opens its task, "Mark all as read" clears them, and pull to refresh fetches new ones; it works offline, and reads are sent with the next sync. New ones also arrive as notifications ("Anna commented: …", "Anna assigned you"), not for the account you are looking at while the app is open, and never for reminders, which the phone already showed itself; the first sync of an account shows no notifications for older activity. The Account tab gets an "Activity" switch per account and shows when the background sync last ran ([D40](docs/decisions.md#d40-background-sync-one-periodic-job-for-every-signed-in-account-with-a-deadline-skipped-while-the-app-is-in-front-the-incremental-run-as-the-session-keep-alive-a-one-off-drain-after-a-background-done-server-notifications-synced-into-a-local-inbox-on-their-own-cadence-new-unread-ones-as-activity-notifications-the-first-run-silent)). Platform setup:
  - Android: WorkManager through the `workmanager` plugin, whose manifest entries are merged from the library; no foreground service and no request to ignore battery optimisation. The battery savers of some manufacturers stop background work anyway ([dontkillmyapp.com](https://dontkillmyapp.com)).
  - iOS: the background mode "Background fetch" and the task identifier `dev.coderoftime.vikunja.sync` in `Info.plist`, registered in `AppDelegate.swift`. Background App Refresh has to be on for the app (Settings → General → Background App Refresh), and Low Power Mode pauses it.
- English and German, dark mode, large text. A slim progress bar shows a running sync.

The description cannot be edited yet (step 25), and labels can be created only while online; offline label creation and label management come with step 28. Kanban buckets, comments and attachments are not synced yet.

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
| `app/` | Flutter app (feature-first: `lib/features/*`, shared code in `lib/core/`: auth, the Drift database in `db/`, the sync engine in `sync/`, the outbox and its sender in `outbox/`, repositories, the notification scheduler and its background action handler in `notifications/` (step 15), the background job in `background/` and the activity sync in `activity/` (step 16, in progress); the inbox in `lib/features/inbox/` (step 16, in progress)). `drift_schemas/` holds the schema dumps the migration tests compare against |
| `packages/vikunja_domain/` | Pure Dart domain model: server version, capabilities, support tier, connection result and failures; user, account, tokens, `VikunjaFailure`; projects, views, labels, tasks, reminders, `Page<T>`, `TaskQuery`, `TaskChanges`, `NewTask`, `IdSetChange`, `NewLabel`; (step 13) the user's settings `UserSettings` with `QuickAddMagicMode`; (step 16, in progress) the server notification `ServerNotification` |
| `packages/vikunja_api/` | Pure Dart API client: address normalisation, `/info` parsing, parallel v2/v1 `/info` probing, error normalisation, OAuth + PKCE token client, authenticated transport, the read client for projects, labels, tasks and (step 12b) the people of a project over v1 and v2, and the write client for task creates (step 12a), updates and deletes (v2 merge-patch, v1 full-replace emulation; since step 12b label and assignee changes through their endpoints) and label creates (step 12b); (step 13) the user's settings read with the current user; (step 16, in progress) the server notifications, listed and marked read over v1 and v2. `test/fixtures/` holds real server responses |
| `packages/vikunja_logic/` | Pure Dart client logic ported from the behaviour of the web frontend, pinned by its test vectors (step 13): the Quick Add Magic parser (prefixes, labels, project, people, priority, repeats, dates and times) and the day intervals and default time of the date shortcuts; later positions, filters and checklists |
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
cd app && dart run drift_dev schema dump lib/core/db/app_database.dart drift_schemas/drift_schema_v<N>.json   # versions 1 to 4 exist; step 16 adds 5
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
(cd packages/vikunja_logic && flutter test)
(cd packages/vikunja_api && flutter test --exclude-tags contract)
```

The pure packages also use `flutter test` (see [D9](docs/decisions.md#d9-flutter_test-instead-of-packagetest-in-pure-packages)). The app's tests run on an in-memory SQLite, so they need no server and no device.

Contract tests against the real server:

```sh
tool/contract_tests.sh                # starts test_servers/ if needed, waits, runs the vikunja_api tests tagged contract
tool/contract_tests.sh test/contract/write_contract_test.dart   # only the write ports (task create, update and delete on v1 and v2)
docker compose -f test_servers/docker-compose.yaml up -d     # or start it by hand
tool/wait_for_test_servers.sh
(cd app && VIKUNJA_CONTRACT=1 flutter test --tags contract)  # the sync engine and the outbox against the live server
(cd app && VIKUNJA_CONTRACT=1 flutter test --tags contract test/contract/outbox_contract_test.dart)   # only the outbox
docker compose -f test_servers/docker-compose.yaml down
```

The `vikunja_api` contract tests cover negotiation, the OAuth flow, the read client and, since step 11, the write client (`packages/vikunja_api/test/contract/write_contract_test.dart`, both adapters): a task seeded with an assignee, two reminders and a label is marked done and must keep all three, which is the v1 full-replace regression; undo, favourite on and off, a title change, a repeating task marked done comes back open with its due date a day later, and a delete followed by a second delete does not throw. Step 12a added a create with every core field, which the server must echo back with an identifier `<PREFIX>-n`, a move to another project with the new identifier, a repeat changed and removed, an empty title refused, and a repeat beyond ten years refused. Step 12b added a label create, labels added and removed (each twice, without a failure), the user and a second user shared into the project assigned and unassigned, a user without access refused with 7003, a missing label with 8002 and another user's label as forbidden, absolute and relative reminders set and cleared, a create with reminders, the v1 regression that a label or reminder change keeps the assignees, and the project user search. Step 13 added the user settings (`packages/vikunja_api/test/contract/user_settings_contract_test.dart`): a new user has the defaults and the Inbox as default project, and what the web saved (set through `PUT /user/settings/general` on a throwaway user) is read back on both API versions.

The app's contract tests register a user, seed projects and tasks and run the sync engine into an in-memory database: the initial sync test checks the counts; the incremental sync test (`app/test/contract/incremental_sync_contract_test.dart`) changes the server through the API (creates, edits, deletes, a move, a new and an archived project, label changes), runs one `refresh()` on each API version and checks that the database mirrors the server, that the keyset filter over `(updated, id)` is accepted, and that a sync with nothing new costs exactly 5 requests (the user with its settings, the projects, the labels, the empty delta page and the count probe); the outbox contract test (`app/test/contract/outbox_contract_test.dart`, both API versions) marks a task done, toggles the favourite and deletes a task through the repository, drains the outbox and checks the server and the local row, replays a write whose first attempt failed with a network error, and marks a repeating task done, which must come back open with the server's shifted date; step 12a added a task created offline that the drain puts on the server with the right fields while the local row takes the server id, a create with an edit before the send as one request, a create with a delete before the send as none, a move between projects and a repeat removal; step 12b added a task created offline with a reminder that gets a label and its creator as assignee before the send and arrives with all three, a label removed and added again, and a repeating task with an absolute reminder marked done and undone, whose reminder must be back at the original time; step 13 added the quick-add contract test (`app/test/contract/quick_add_contract_test.dart`, both API versions): one line with labels (one of them new), a project, an assignee, a priority, a due date and a repeat reaches the server with all of it, a name known nowhere on the device is found by the server's user search, and a line entered offline is created at once and sent with its label after the reconnect. All are tagged `contract` and skipped without `VIKUNJA_CONTRACT=1`.

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

Browser sign-in is tested by hand against the Docker test servers, with a fixed test user. Its username and password are in [`test_servers/seed/e2e-user.env`](test_servers/seed/e2e-user.env); a second user for the multi-account flows is in [`test_servers/seed/e2e-user-2.env`](test_servers/seed/e2e-user-2.env) (create it with `E2E_USER_ENV=test_servers/seed/e2e-user-2.env tool/seed_e2e_user.sh`). They are throwaway values for these local servers only.

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

5. The sheet closes, the first-sync screen pulls the account, and the app shows the Overview tab. The Account tab shows initials, display name, `@` username, server host and version, when the account was last synced, and **Sync now**; **Sign out** there, after a confirmation, deletes the local data and returns to onboarding. To see tasks and projects, create some in the web app at `http://localhost:34527` with the same user, then pull to refresh, tap Sync now or wait for the minute timer. Tap a task's circle to mark it done: the web app shows it done after a reload. "New task" on the Overview creates one; Edit in its detail sheet changes the rest. Turn the network off afterwards: the lists stay, with an "Offline" notice on refresh; a task ticked off, created or edited offline stays that way, the Account tab counts the pending changes, and they are sent as soon as a sync reaches the server again (within a minute while the app is in front, or on "Send now"); a task created offline shows its identifier once the create went out. Signing out with changes still queued loses them; the sign-out dialog says so.

Every sign-in starts with an empty browser session and shows the login form ([D23](docs/decisions.md#d23-browser-sign-in-through-flutter_web_auth_2-client-id-and-redirect-uri)). On Android, Chrome before 141 (the emulator image ships 133) gets a regular Custom Tab instead, which can reuse a web login in Chrome; to see the form again there, sign out in Chrome or clear its data for the server.

## Documentation

- [Architecture](docs/architecture.md): what exists after steps 1, 2+3, 4 to 7, 11, 12a, 12b, 13 and 15, what step 16 is building, and what is planned.
- [Roadmap](docs/roadmap.md): all steps and milestones, with status.
- [Decisions](docs/decisions.md): decision log.
- [Open questions](docs/open-questions.md): the owner's answers of 2026-10-09 and the items still deferred.
- [Research](docs/research/README.md): the research snapshot the architecture is based on.

## License

Not decided yet (deferred); see [Q3](docs/open-questions.md#q3-licence-and-distribution). There is no `LICENSE` file yet. Vikunja itself is AGPL-3.0-or-later.
