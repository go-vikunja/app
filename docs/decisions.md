# Decision log

Each entry has a number, a status and the step that took it. It says what was decided and why, as it holds today, with the gaps still open under "Limits" and "Open". How it is built is in the code. How each entry came about is in the git history of this file; the full text from before the log was shortened is in `git show 41e9fc9:docs/decisions.md` ([D115]). An entry that a later one replaced keeps its number and points to its replacement. "The owner" is the app's main maintainer, a role rather than a person ([D83]); "(owner)" marks a point the owner decided, which is not reversed without asking. The background for most entries is in [research/synthesis.md](research/synthesis.md) §2–3.

## Overview

- **Stack and structure:** [D1] pub workspace · [D2] material_ui and cupertino_ui · [D3] Riverpod · [D4] go_router · [D5] dio and Cronet · [D9] flutter_test in the packages · [D12] hand-written API adapters · [D27] paging and the query builder · [D29] repository interfaces · [D103] test hygiene · [D108] the task sheet and project screen in parts · [D110] state machines and checked layers
- **Servers:** [D6] v1/v2 negotiation · [D13] support floor 2.3.0 · [D28] contract tests · [D78] Vikunja 2.8.0 · [D80] reminders follow subscriptions · [D81] 2.8.0 details · [D111] contract matrix and older servers · replaced: [D7], [D11]
- **Connection, sign-in, sessions:** [D8] cleartext only after consent · [D14] browser sign-in only · [D16] several accounts · [D22] session keep-alive · [D23] the browser session · [D24] tokens in secure storage · [D25] the account registry · [D26] refresh concurrency · [D37] the account switcher · [D59] sessions kept, why one ended · [D62] onboarding, link-share guests · [D65] connection settings per server
- **Local data and sync:** [D31] one database per account · [D32] full sync · [D33] incremental sync · [D34] the outbox · [D35] creates under negative ids · [D36] labels, assignees, reminders · [D46] realtime · [D99] battery and data · [D104] large accounts · [D109] offline details
- **Tasks, lists, projects:** [D19] [D38] [D102] quick add · [D41] relations and subtasks · [D43] task lists · [D44] task detail · [D47] [D48] Kanban · [D49] manual order · [D50] projects and views · [D51] filters and search · [D61] Table and Gantt · [D79] trash and Undo · [D84] editing in the task detail · [D106] swipes, selection, Reschedule · replaced: [D30]
- **Descriptions, comments, attachments:** [D18] [D52] the description editor · [D53] attachments, share target · [D57] comments and reactions · [D58] server HTML within budgets · [D101] images in the editor
- **Account, teams, sharing:** [D54] account settings · [D55] security settings · [D60] labels, teams, shares
- **Notifications and widgets:** [D17] notification policy · [D39] local notifications · [D40] background sync, inbox · [D63] home-screen widgets
- **Look, accessibility, languages:** [D20] scope cuts, support details · [D21] [D71] English and German · [D45] app shell · [D56] design · [D68] screen readers · [D69] large screens · [D70] the task pane · [D75] the owner's UI review · [D82] projects list–detail · [D100] small things · [D112] accessibility pass
- **Security and privacy:** [D64] app lock · [D66] threat model · [D92] security fixes · [D113] opt-in crash reports
- **Identity, release, the official app:** [D15] app id and name · [D42] app icon · [D72] first release · [D73] CI from local scripts · [D74] iOS phase · [D76] store listings and policies · [D77] beta preparation · [D83] successor of the official app · [D85] update from the old app · [D86] GitHub Actions · [D87] MIT and the move · [D88] Crowdin · [D89] the official store listing · [D67] notices, the licence and About pages, no F-Droid · replaced: [D10]
- **Code review fixes:** [D90] before beta.1 · [D91] the description editor, leaving pages for a switch · [D93] quick fixes · [D94] outbox retries, notifications, the diagnostics log, session reminders · [D95] small things users notice · [D96] robustness · [D97] security and release · [D98] the limits' review · [D107] the make-up reviews · [D116] [D117] the UI/UX review
- **The repository:** [D105] architecture overview · [D114] cleanup before the move · [D115] this log shortened

## D1: Flutter pub workspace with pure-Dart packages

*Accepted 2026-10-09 (step 1).*

- Flutter 3.47.9 / Dart 3.13.7, pinned in CI (`tool/ci/pins.sh`) and used locally, so that what the release job builds is what was tested ([D73], [D77]).
  - 3.47.9 carries the fix of the Dart security advisory GHSA-frr6-h895-5pxp, which concerns the servers the app reaches through `dart:io` ([D65]).
- The repository is one pub workspace with a single `pubspec.lock`: `app`, `packages/vikunja_domain`, `packages/vikunja_api`, `packages/vikunja_logic`, `plugins/vikunja_storage_flush` ([D59]) and `plugins/vikunja_widgets` ([D63]). `flutter pub get` runs only at the root.
- `packages/*/lib` stays free of Flutter (no `package:flutter*`, `material_ui`, `cupertino_ui` or `dart:ui`), checked in CI by `tool/check_pure_dart_packages.sh` (why: this code must also run on the plain Dart VM).
- Lints: very_good_analysis 11 with `public_member_api_docs` off.
- Code uses the Dart 3.13 constructor syntax (`new(...)`, `factory name(...)`), enforced by the lint `unnecessary_type_name_in_constructor`.

## D2: material_ui and cupertino_ui instead of the SDK's libraries

*Accepted 2026-10-09 (step 1).*

- The app's code imports `package:material_ui/material_ui.dart` (1.6.x) and `package:cupertino_ui/cupertino_ui.dart` (1.1.x), never `package:flutter/material.dart` or `cupertino.dart` (why: the SDK's Material library is being decoupled and deprecated, so there is no migration later).
- Localisation delegates come from material_ui.
- Third-party widgets built on the legacy libraries may need wrappers.

Limits:
- Some dependencies import the legacy libraries internally: the WebView plugin (`webview_flutter` and its WebKit package, [D52]) and `flutter_riverpod` the Material library, `webview_flutter` and `flutter_web_auth_2` 5.x the Cupertino library.

## D3: Riverpod 3 with code generation

*Accepted 2026-10-09 (step 1).*

- flutter_riverpod 3 with riverpod_annotation and riverpod_generator for dependency injection and state; a headless `ProviderContainer` serves the non-UI isolates (why: background tasks, notification actions and widget callbacks build the same object graph without a widget tree).
- The generated `*.g.dart` files are committed and excluded from analysis and from the format check. CI regenerates them and fails when the result differs; after changing annotated providers or Drift tables, run `cd app && dart run build_runner build`.
- The l10n code in `app/lib/l10n/generated/` is excluded the same way but not committed ([D88]): `flutter pub get` at the root writes it, and so do `flutter build` and `flutter run`.
- riverpod_lint is not enabled (it would be a new dependency).

## D4: go_router

*Accepted 2026-10-09 (step 1).*

- go_router 18 for every route: owned by flutter.dev, works with material_ui, and has `StatefulShellRoute` for the shell's per-tab stacks.
- Routes are declared centrally in `app/lib/app/router/app_router.dart`.
- No go_router_builder (typed routes) for now; it can be added when the routes justify it.

## D5: dio with native_dio_adapter and embedded Cronet

*Accepted 2026-10-09 (step 1), the owner's decision where marked.*

- dio 5 everywhere; the packages receive a configured `Dio` and never pick a transport (why: interceptors for auth, retry and redacted logging).
- The app injects `NativeAdapter` from native_dio_adapter: Cronet on Android, NSURLSession on iOS (why: on Android `dart:io` ignores user-installed CAs and system proxies, dart-lang/sdk#50435).
- Pinned, CA-trusted and client-certificate servers go through a `dart:io` client of their own inside the same adapter of both base `Dio`s ([D65]).
- **Embedded Cronet:** Android ships embedded Cronet, never Play services' Cronet, and no other Play services library (owner; [D67]). Why ([D87]): Cronet then works on every device without Play services, user CAs and system proxies included, the app holds no proprietary code, and F-Droid stays possible.
  - `org.chromium.net:cronet-bundled` 500.1.0 (Chromium 155.0.8059.16) with cronet_http 1.10.0. `app/android/app/build.gradle.kts` excludes `play-services-cronet` and the empty transitional Cronet artifacts from every configuration, so every build is embedded. The bundled provider is always chosen; native_dio_adapter's `dart:io` fallback stays only as a safety net.
  - **No HTTP flags and no telemetry:** the manifest declares the disabled, unexported placeholder service `android.net.http.MetaDataHolder` with `android.net.http.ReadHttpFlags` and `android.net.http.EnableTelemetry` set to `false` (why: otherwise Cronet applies a flags file from a system-image package, which can change its features and settings or swap in the platform's `HttpEngine`).
  - The app declares `ACCESS_NETWORK_STATE` itself, which Cronet's network change notifier needs; the AARs declare no permissions.
  - Cronet's security fixes come only with an app update. The owner reviews it at each Chrome stable release whose fixes touch `net/`, BoringSSL or QUICHE and at each dependency update, and a newer `cronet-bundled` is looked for before each release. Raising it is a version in `build.gradle.kts`, the locks, a release build and `tool/build_android_notices.py --refresh-cronet`, which refuses a build that is not a Chrome stable release ([releasing.md](releasing.md#raising-cronet)).
- Build workarounds: `android.uniquePackageNames=false` (cronet_http's namespace clash under AGP 9, dart-lang/http#1932) and `android.builtInKotlin=false` (cronet_http still applies the Kotlin Gradle Plugin).

Limits:
- Chromium's network stack updates only with an app update, never with Play services on the device, and the bundled build lags the newest Chrome stable release by the weeks Google takes to publish it ([threat model](threat-model.md) R34).
- The protobuf copy shaded into `cronet` is named by no lockfile, so no scan sees it. The AARs' `.asc` signatures are not verified; the checks rest on Google's published SHA-256s.
- Three `java.time.Duration` setters of `DnsOptions` do not resolve after core library desugaring; cronet_http's client never calls them.

## D6: v1/v2 negotiation with capability gating

*Accepted 2026-10-09 (step 1).*

- `/api/v2/info` and `/api/v1/info` are probed in parallel. A probe counts only for a 200 with a JSON body that has a string `version`; every API version whose probe counts is recorded, and when both count the v2 `/info` is used (why: `/api/v2` exists only from 2.4.0 and proxies can hide it).
- At most one redirect is followed per connection attempt, and only when the resolved `Location` keeps the `/api/v1/info` or `/api/v2/info` path under another origin or sub-path, or is a same-host `http` → `https` redirect; the derived root is probed like any other candidate.
  - An `https` → `http` downgrade is never accepted. Any other redirect off the host, or to a login-like path, counts as behind a login proxy.
- Capabilities are derived from the reachable API versions, version thresholds, the `/info` flags and `enabled_pro_features`. Features check capabilities, never version strings alone (why: development builds report `dev` or `unstable`, and admins and licences switch features). The adapter choice per API group follows the v2 capability.
- The server's `/info` is read at sign-in and again while signed in ([D78]).

## D7: Support floor 2.0.0

*Superseded by [D13].*

## D8: Cleartext only after the user's consent

*Accepted 2026-10-09 (step 1).*

- The OS configuration allows cleartext, so that home-LAN servers on plain `http://` can be reached at all: on Android a network security config with `cleartextTrafficPermitted="true"` that trusts system and user CAs, on iOS `NSAllowsArbitraryLoads` plus `NSLocalNetworkUsageDescription`.
- Only the `http` and `https` schemes are accepted.
- The connector tries `https` first, and `http` only when the user typed no scheme and every `https` candidate failed at the connection level (DNS, refused, timeout, or a TLS handshake failure). A rejected certificate does not count: a TLS server answered, so the user is pointed at the certificate, never at cleartext.
- An `http` server is used only after the user confirms the "Unencrypted connection" question, and is marked as unencrypted afterwards.
  - The consent is recorded per server address, can be revoked and is enforced in the transport for requests and the socket; the `/info` probe before the consent is the only exception ([D65]).
  - The question comes once per origin: an address, an invite or a shared link on an `http` origin that has the consent goes on without it, until the consent is revoked ([D95]).
  - An address typed without a scheme that reached `http` only because every `https` candidate failed gets a question of its own, "No encrypted connection": the host did not answer over `https`, and someone on the network may be blocking it. It comes every time, also for an origin that has the consent; a typed `http://`, invites and shared links keep "Unencrypted connection" and the once-per-origin rule (why: with port 443 blocked, "Unencrypted connection" reads as if the server used `http`; code review S3, [D97]).
  - After the update from the old app, its session is not kept for an `http` server, nor for one below the support floor ([D13]): the token is not sent, and the Connect screen asks as usual when the user continues ([D85]; why: the old app never asked; the alternative is keeping the session over `http` without asking, as the old app used it).
- The OS permissions stay broad because they cannot be narrowed to hosts typed at runtime (iOS ATS exceptions and Android's per-domain cleartext rules are build-time only); the in-app consent is the actual control.
  - `NSAllowsLocalNetworking` (or `NSAllowsArbitraryLoadsInWebContent` / `NSAllowsArbitraryLoadsForMedia`) is never added: iOS would then ignore `NSAllowsArbitraryLoads` and block confirmed `http` connections to fully qualified hosts (split-DNS LAN names, Tailscale `*.ts.net`, VPN hosts).

Limits:
- App Review may ask about `NSAllowsArbitraryLoads`; the review notes carry its justification ([D76]).
- `NSAllowsArbitraryLoads` also removes ATS's TLS 1.2 and forward-secrecy minimums for `https`; system certificate validation still applies.

## D9: flutter_test instead of package:test in pure packages

*Accepted 2026-10-09 (step 1).*

- The pure packages use `flutter_test` as their dev dependency and run their tests with `flutter test`, never `dart test` (why: in the shared workspace resolution `package:test` conflicts with the `test_api` version that `flutter_test` pins).
- Only `test/` touches Flutter; `lib/` stays pure Dart ([D1]).
- Contract tests run with `flutter test --tags contract` ([D28]).

## D10: Placeholder application ids

*Superseded by [D15].*

## D11: Docker contract matrix 1.0 / 2.0 / 2.3 / 2.4 / 2.7

*Superseded by [D28].*

Its rule that contract tests are tagged `contract`, need `VIKUNJA_CONTRACT=1` and run in a CI job of their own is kept in [D28].

## D12: Hand-written API adapters over one shared DTO set

*Accepted 2026-10-09 (step 1).*

- The v1 and v2 adapters of `vikunja_api` are hand-written over one shared codec layer (`lib/src/dto/`), because both versions share the server models; there is no code generation (why: v1 has no usable spec, and the app needs only a fraction of the operations).
- swagger_parser + retrofit stay the fallback if v2 grows faster than the adapters can follow.

Limits:
- Planned, not built: committing the OpenAPI 3.0 spec of the pinned test server image and a contract test that every DTO field exists in it and every write field is writable, so that spec drift is caught.

## D13: Support floor 2.3.0

*Accepted 2026-10-09 (step 1 review), the owner's decision.*

- Vikunja 2.3.0 and newer are supported; 2.4.0 and newer with a reachable `/api/v2` are first-class (why: browser sign-in, the only sign-in method ([D14]), needs the server's OAuth 2.0 + PKCE endpoints, which exist from 2.3.0).
- Tiers: `unsupported` (before 2.3.0, or an unreadable version without `/api/v2`), `oauth` (`/api/v1` only), `full` (`/api/v2` reachable); no legacy tier for 0.24–1.x. The v1 adapter stays for 2.3.x and for proxies that hide `/api/v2`. An unsupported server is no connection failure: its overview shows a blocking banner (browser sign-in needs 2.3.0) and nothing to sign in with.
- **Tested live:** the workflow "Contract matrix" runs both contract suites every night in go-vikunja/app and on every tag against the newest release of each minor line from the floor: 2.3.0, 2.4.0, 2.5.0, 2.6.0, 2.7.1, 2.8.0 (Docker Hub has no later patch of 2.4–2.6) ([D28]). The floor stays at 2.3.0 (owner, 2026-11-20; [D111]).
- **What older servers do differently, and the app's answer:**
  - 2.4.x on v2 validates a merge-patch merged into the object with the user's subscription (`entity` a string), so every PATCH or full PUT of a task or project the user follows (directly, as an assignee or through its project) fails with 422 (2.5.0+ accept them); the app adds `"subscription": null` to v2 task and project patches on 2.4.x only, which the server answers with 200 and the follow kept ([D111]).
  - 2.3.0–2.5.x list the shared project with `max_permission` 0 (read) for every link-share guest, on v1 and v2 (2.6.0+: none); the app reads the shared project itself ([D62]).
  - 2.3.0–2.6.x answer a deleted link share's token on v1 with a 500 without a code (2.7: 400 code 13003; v2: 401); a token renewal tells a gone share from a server error ([D62]).
  - 2.3.x has no task-by-index route (404 without a code, like an unknown project on v1); the app uses a filtered read ([D44]).
  - 2.3.x stores project identifiers as typed, unique only in exact case and across all users (3007), so `ab` and `AB` can coexist; 2.4.0+ upper-case them and refuse another case with 3007. An identifier names the exact match, else the only case-insensitive one ([D44], [D38]).
  - 2.3.0–2.5.x refuse to unfollow a task or subproject a followed project covers (403); the app shows such a follow as fixed ([D41]).
  - 2.3.x–2.4.x store a done or default column the server no longer has as sent (2.5.0+: none); the app reads the board before relying on one ([D48]).
  - An unknown version (only possible with `/api/v2`) counts as new for the subscription patch, the by-index route and the unfollow, and as old for the guest's permission and the column check.
- **Other differences** the contract tests gate by version ([D28]), by first release:
  - 2.5: a board view created without a mode gets `manual` with a default and a done column; the table's order of tasks tying on `done`.
  - 2.6: the creator follows the task; the unfollow opt-out; 412 code 3016 for un-archiving a child of an archived project (2.5: 200, stays archived); 3014 for an unknown view; team names hidden from non-members; a guest's project list without `max_permission`; `created_by` in filters.
  - 2.7: `iat` in link-share tokens; 2005 for an unknown invite; v2's 307 for a task by index after a move; link shares created by admins only, a second delete answering 3006; 3017 for an archived or missing default project; out-of-range week starts refused on v1; the socket closed at logout; the user settings' merge-patch (405 on 2.4–2.6).
  - 2.3.0 to 2.7.1: a member with write permission may not list a project's link shares (403).
  - 2.3 only: no `/api/v2`, no default saved filter, no `enabled_pro_features` or `concurrent_writes` in `/info`, any week start accepted, team members in another order, the board read on v1 from the view's tasks, subtasks listed flat.

Limits:
- Differences that change only an order or what a view shows stay, and their tests skip: on 2.4.0 the table's order of tasks tying on `done`; on 2.3.0 a subtask the Gantt chart leaves out and the List view's nesting (owner, 2026-11-20, [D111]).
- A stored server version stays until `/info` is read again ([D78]): an account stored as 2.3 after an upgrade keeps the filtered read by index, which does not follow v2's 307 for a moved task.

## D14: Browser sign-in only

*Accepted 2026-10-09 (step 1 review), the owner's decision.*

- The only way to sign in is OAuth 2.0 + PKCE in the system browser ([D23]) (why: Vikunja plans to remove username and password login, and on 2.3.0 and newer the web's login page covers local, LDAP, every OIDC provider and TOTP).
- The app never handles an account password or a TOTP code: no native password + TOTP form, no API-token login, no OIDC in an embedded WebView.
  - Creating an account goes through the browser's sign-in page, a password reset and an invite through the web's own pages in the external browser; link-share guests are a separate account kind ([D62]).
  - After the update from the old app, the app may keep the old app's session once with the refresh token the old app got through its own browser sign-in; it handles no password for it ([D85]).
  - Two-factor setup and everything else that needs the password stay on the web ([D54], [D55]).
- The redirect scheme `vikunja-io.vikunja.app` starts with `vikunja-` and is neither the desktop app's `vikunja-desktop` nor the old app's `vikunja-flutter` ([D23]).

Limits:
- OAuth sessions are always short: the server creates every OAuth session without "stay signed in" (`oauth2server/token.go` in 2.8.0), so the server's session lifetime without a refresh ends it, 72 h by default (`service.jwtttl`, which neither `/info` nor the token answer reports), and there is no 30-day "stay signed in" ([D22]). A long session for OAuth clients needs a server change.

## D15: App id `io.vikunja.app` and the name Vikunja

*Accepted 2026-10-09 (step 1 review), the owner's decision; the official app's id and name since 2026-11-13 ([D83]), accepted 2026-11-14 (step 38a); the check for the former website of step 38f, accepted 2026-11-17; the former name gone from the docs on 2026-11-20, and from the tests, tools, test data and test certificates the same day, when the owner also dropped the tests that checked for the old names, the old ids and the AGPL.*

- Android `applicationId` and iOS bundle id: `io.vikunja.app`, the official Vikunja app's (owner), so that the app reaches the old app's installs on Play as an update ([D83]). On iOS nothing is registered yet, so the bundle id is the same (owner). The id is permanent once signing keys or store listings exist.
- Derived: `io.vikunja.app.widgets` for the widgets and the iOS widget extension, and the App Group `group.io.vikunja.app`, the only id the extension needs, as no keychain group exists ([D24], [D63]). The launcher component stays the old app's `io.vikunja.app/.MainActivity`, so launcher icons placed for it survive the update ([D85]).
- The app scheme and the OAuth `client_id` are one value, `vikunja-io.vikunja.app`, since the owner named one value for both, as the old app used `vikunja-flutter` for both. Vikunja requires the scheme's prefix; the app id as the client id would work as well, as the server only compares the value between the authorize and the token call ([D23]).
- `User-Agent`: `Vikunja-App/<version>[+<build>] (<system> <version>)` (why: `Vikunja/…` could read as the server's own requests; [D55]).
- The app is called **Vikunja** (owner, [D83]), with the icon of [D42], in both stores and languages ([D76]). The name and the logo belong to the Vikunja project and are not under the app's MIT licence; a fork that distributes its own build uses its own name and logo ([D87]).
  - Texts say "Vikunja" where the app names itself on the device (launcher, notifications, widgets), "the app" where the same sentence names a server, syncing, the licence or the handling of data ("This app needs Vikunja 2.3 or newer"), and "Vikunja app {version}" before a version (why: there "Vikunja" reads as the server, and "Vikunja 1.0.0" as a server version). [glossary.md](glossary.md) has the rule for both languages.
- No file of the repository names the app's former development name, nor the name proposed before it, in its text or its path; the git history keeps them (owner, 2026-11-20). The README presents the app as the official Vikunja app, without its history.
- `app/test/app/app_identity_test.dart` pins these ids and the name. It does not check the sources for the old ids, the AGPL or the former names: the owner dropped those checks on 2026-11-20, as the files no longer name them.

Limits:
- No `applicationIdSuffix` for debug builds (why: two installs would share the sign-in scheme, and the browser could hand the sign-in to the wrong one). So a debug build cannot be installed beside the Play app, which has another key; old development builds under `dev.coderoftime.*` stay installed beside it until uninstalled.
- `io.vikunja.app` may already be taken at Apple: the old app's fastlane configuration named it with a former contributor's team, which uploaded TestFlight builds, and App Store Connect refuses an id another team used. To check with the Vikunja maintainers before the first iOS upload ([D83]).
- Until the Apple account is settled, no build for a physical device with automatic signing under the owner's team: Xcode would register `io.vikunja.app`, `io.vikunja.app.widgets` and `group.io.vikunja.app` in that team, and no other team could use them. Simulator builds register nothing.

## D16: Multi-account in the first release

*Accepted 2026-10-09 (step 1 review), the owner's decision.*

- The first release adds, switches and removes accounts ([D37]).
- An account is a server plus a user, or a link-share guest ([D62]). Each has its own tokens, database, outbox and sync state; the UI shows one active account at a time. Per-account providers are keyed by the account id.
- Background sync and reminders cover every signed-in account, not only the active one ([D39], [D40]).
- Removing an account signs it out, wipes its secure entries, deletes its database and cancels its notifications. This holds across a crash or a failed wipe: the registry lists the account as still to delete until its data is gone, and the next start finishes it ([D96]). Signing the same account in again right after waits until every part of the app that still holds its old database has let go of it ([D31]).
- Notification payloads and widget data carry the account id, so a tap opens the right account; it switches without asking only with the install's key ([D66]).

## D17: Notification policy

*Accepted 2026-11-10 (steps 1 and 37g), the owner's decision.*

- Only undone tasks notify. Which ones:
  - On Vikunja 2.8.0 and later: the tasks the user follows, for reminders and due dates alike, as the server sends its reminders; unfollowing a task silences it on the phone too (owner, [D80]).
  - On older servers and for link-share guests: the tasks where the user is the creator or an assignee; tasks visible only through shared projects or subscriptions get none (owner).
- Reminders fire at their reminder time; a task with a due date also notifies at the exact due time (owner). A reminder at the due time itself rings once, as the due notification, while due dates notify ([D39]).
- Android schedules both as exact alarms. The onboarding after the first sign-in asks for the notification permission and for exact-alarm access (`SCHEDULE_EXACT_ALARM`, which the user grants on Android's "Alarms & reminders" page and which is denied by default on Android 14+); iOS asks for the notification permission at the same point (owner).
- Without exact-alarm access Android falls back to inexact alarms, which Android 12 and later may deliver up to an hour late, later still in Doze or battery saver; the notification settings say so and link to the system setting ([D39]). One that Android deferred past its time is kept for up to 3 h instead of being cancelled ([D94]).
- Each signed-in user account also gets a reminder to open the app about 12 h before its session would end, while the notification permission is granted ([D94]).
- No daily overdue digest for now (owner); one could be added as a setting without changing the scheduler.

## D18: Descriptions edited with TipTap in a WebView, shown natively

*Accepted 2026-10-09 (step 1 review), the owner's decision.*

- Descriptions are edited with TipTap in a WebView: a bundled editor page whose own TipTap configuration produces the web's HTML, no remote loads, HTML in and out through a JavaScript channel ([D52], locked down per [D66]) (why: descriptions are HTML written by the web's TipTap editor; Markdown editing would be lossy and is not possible on v1 servers).
- Read-only rendering is native ([D44]).

Limits:
- The WebView plugin and the bundled JavaScript build make the app larger.
- The JavaScript channel has no native origin or frame check; the per-load token and the page's CSP stand in for it ([D66], [threat model](threat-model.md) R30).

## D19: Quick add keeps the web grammar and fixes four parser bugs

*Accepted 2026-10-09 (step 1 review), the owner's decision.*

- Quick Add Magic keeps the web's grammar but fixes four parser bugs, items 1–4 of the quirk register in [research/client-logic.md](research/client-logic.md) §20 (the code cites them as "D19 item n" or `D19-n`):
  1. `every N months` (N ≠ 1), `every year`, `yearly`, `biannually` and similar produce a repeat instead of none.
  2. Capitalised `Daily` and `Every Day` mean daily, as in lower case, not hourly.
  3. `today`, `tomorrow` and `next week` need a word boundary, so `todays` and `next weekend` stay text.
  4. Day-and-month dates need whole words, so `12 decorations` stays text.
- The fixes are documented in `packages/vikunja_logic` as deliberate deviations from the web.
- The other quirks are decided in [D38].

## D20: Scope cuts and mobile forms of desktop features

*Accepted 2026-10-09 (step 1 review), the owner's decision.*

- **Adaptations:** Gantt is a read-only timeline and the table a detailed list ([D61]); keyboard shortcuts on every platform, ⌘ on Apple and Ctrl elsewhere (owner), with the iPad key menu (step 36d, after the first release); home-screen widgets and app shortcuts replace the desktop quick-entry window ([D63]); no seasonal logo and no PWA banners.
- **Dropped:** the MCP information page and the admin panel (owner); the power-user features of step 33, webhooks, bot users, project backgrounds and imports from other services, which stay in the web (owner, 2026-11-12). The server overview lists neither the admin panel nor time tracking, even for a licensed server.
- **Time tracking** (step 34) comes in release 1.4 (owner), tested against a licence or a test instance from the Vikunja maintainers; the app parses `enabled_pro_features`, so it can be gated by the server.
- **Deferred, not planned for now** (owner): push on Android through a Vikunja webhook, ntfy and UnifiedPush; a diagnostics export with a stored log buffer, bound by the threat model's rules for such a buffer ([D66]). The device keeps a redacted log of warnings and errors, which ends the support details, but no export of its own ([D94]).
- **Crash reports** are not deferred: the owner asked for them on 2026-11-21; opt-in crash reports go to Vikunja's Sentry ([D113]).
- **Support details** (owner, 2026-11-12): the row "Support details" on the About page (also signed out and for guests) builds a snapshot of the app's state when tapped, kept only while the page is open and shown in a block that cannot be selected, shows it first and lets it leave only through the share sheet (why no Copy button: the share sheet offers Copy on both platforms). One exception (owner, 2026-11-18): the release error screen's "Copy support details" copies them, servers hidden, to the clipboard without the preview ([D94]).
  - They hold the versions, the permissions, the background state, and per account its server's version, tier and features, the last syncs, the queue's counts by kind and state with their failure kinds, and the last session end, as plain English lines in every app language, so reports compare ([D71]). They end with the diagnostics log of the last 7 days, account ids and hosts replaced the same way while task, sync run and saved filter ids stay, and the page says so ([D94]); in a build with crash reports the page says what goes with each crash report the user allows ([D113]).
  - Nothing in them is sent automatically and no SDK is involved; only the last session end is stored, as a tiny record of its reason, the part of the app and the time (owner): per account under `support.lastSessionEnd.<account>` in the preferences, never with the server's code and message, kept across a new sign-in (why: it answers why the account was signed out), forgotten at sign-out.
  - They also show the session-end record of [D59] (its cause, the server's code, the part of the app, the time, the lost renewal and what became of the session), never its token fingerprints (owner, 2026-11-20).
  - Servers show as `<server-N>` unless the user turns on "Show server addresses", off at every opening and remembered nowhere; an address then shows without user info, query, fragment or share hash.
  - **Never in it:** tokens, link-share hashes, passwords, failure messages, user, display and share names, e-mail addresses, ids of accounts, users, shares and projects, titles, payloads, user settings, the server's notices and frontend address; hosts only with the switch on. A server version keeps letters, digits and `.+_-`, at most 40 characters, and the redaction of [D66] runs over the whole text last.
- No third-party SDK that sends data apart from Sentry's for the opt-in crash reports ([D113]), so the privacy manifests and store data declarations stay simple. Release builds log nothing to the console; the log kept on the device reaches the developer only when the user shares or copies the support details ([D94]) or with each crash report the user allows.

Limits:
- Not in the details: an account marked at start because its stored tokens are missing (a restore without the Keychain or Keystore); a per-account result of the last background turn.
- Opening the page opens every registered account's database until sign-out.
- The iOS background values are checked only in the device test ([beta.md](beta.md#the-ios-device-test)), and the page with TalkBack and VoiceOver not yet ([checklist](accessibility-checklist.md#27-checks-of-step-37l)).

## D21: Languages English and German

*Accepted 2026-10-09 (step 1 review), the owner's decision.*

- The first release ships English and German; the web's 32 locales are not imported. More languages ship through Vikunja's Crowdin project once at least half translated ([D88]). How English and German are written, error texts included, is [D71]'s.
- Every string is in `app_en.arb` (definition of done), and new and changed keys get a description ([D68]). German comes through Crowdin and must be complete before a release, not in every commit ([D88]).

## D22: Session keep-alive through background sync

*Accepted 2026-10-09 (step 1 review), the owner's decision.*

- OAuth sessions end after 72 h without a refresh (`service.jwtttl`, sliding), and browser sign-in gives no 30-day session ([D14]); the background sync keeps every signed-in account's session alive ([D40]).
  - Each background run's incremental sync starts with `GET /user`; access tokens live 600 s and runs are at least 15 min apart, so that request refreshes the token and slides the 72 h window. Where the run first sends the account's queued changes, their first request does it.
  - Android runs it as WorkManager periodic work every 30 min while the battery is not low, which only defers the runs ([D95]); iOS through BGTaskScheduler, when the OS chooses.
- Opening or resuming the app checks the active session with `GET /user`; a check that refreshes an expiring token moves the window too.
- Refreshes from several isolates follow [D26].
- A session that ends puts the account into `needsReauth`: its local data stays, its outbox pauses, and a "Sign in again" notification appears. Its reason, the part of the app and the time are kept for the support details ([D20]).
- A lost race, unreadable storage and a missing connection do not end a session; why one ended is told in the banner and on the Account tab, and stored tokens another part of the app has made work again are tried once more ([D59]).

Limits:
- On iOS a session still expires when the app is neither opened nor woken for 72 h, as the OS may run the background job rarely or never ([D40]). The app warns while the device keeps the background sync from running (Background App Refresh off or restricted on iOS, a background restriction on Android), and each user account gets a reminder to open the app 12 h before its session would end ([D94]). On Android a force stop drops the background job and that reminder until the app is started again.

## D23: Browser sign-in through flutter_web_auth_2 in an ephemeral session

*Accepted 2026-10-09 (step 2+3).*

- `client_id` `vikunja-io.vikunja.app`, the scheme's value ([D15]); redirect URI `vikunja-io.vikunja.app://oauth/callback`. Vikunja has no client registry: the `client_id` only has to match between the authorize and the token call (else 400 code 17001), and the redirect scheme must start with `vikunja-` (else 17002).
- The browser leg runs through flutter_web_auth_2 5.1.0 behind the `WebAuthenticator` interface: ASWebAuthenticationSession on iOS, a Chrome Auth Tab where supported, else a Custom Tab, on Android.
- The browser session is ephemeral (why: Vikunja has no consent screen and its callback carries no RFC 9207 `iss`, so with a reused web login a malicious server could send the sheet to another server's authorize page and receive a code without the user noticing).
- Authorize URL: `{frontend_url}oauth/authorize`, or the server root + `/` when `/info` has no `frontend_url` or an `http://` one for an `https://` server. PKCE S256 with a 32-byte random verifier and a 16-byte random state, fresh per attempt.
- **The warning:** a sign-in page on another origin than the server root (scheme, host and port; the host in punycode, without a trailing dot, [D97]) is named before the browser opens ("Sign in at {host}?": the server gets access to the account signed in there; continue only if the host belongs to the server), in the dialog of [D65]'s hint, which takes the page from the same function. Why: without `iss`, a server whose `frontend_url` names another server's genuine sign-in page receives the code and the verifier for the account signed in there and can redeem both at that server, while nothing on the page looks wrong.
  - No sign-in path can omit the question; only "Sign in again" skips asking, when the account last signed in at the same confirmed origin, kept per account in the preference `auth.confirmed_sign_in_hosts` ([D25]) only after a sign-in that returned the account, and forgotten at sign-out and removal; an unreadable map counts as nothing confirmed. The old app's session kept after the update ([D85]) records no confirmed host, so a later "Sign in again" on another host asks once.
  - Link-share guests sign in through the API and never open the browser ([D62]).
- The code is exchanged at the token endpoint of `/api/v2` when reachable, else of `/api/v1`. The token client never follows redirects, nor does any request that carries an access token.
- The callback must match the redirect URI and the state. "Sign in again" accepts only the account's own user; another user is refused before anything is stored, and its new session is logged out best effort. Android exports the callback activity only for the scheme, host `oauth` and path `/callback`.
- The iOS deployment target stays 15.0: below iOS 17.4 the plugin falls back to the older ASWebAuthenticationSession initializer, which handles the custom scheme; only `https` callbacks need 17.4.

Limits:
- Every sign-in shows the Vikunja login form; OIDC and SSO users sign in at their identity provider each time.
- Browsers the plugin treats as lacking ephemeral support (Chrome and Edge before 141, Samsung Internet before 28, Firefox before 143) get a Custom Tab that can reuse a web login; browsers it does not know are taken to support it. Signing out of the app does not end a web login.
- The browser leg does not use a server's connection settings (pin, CA, client certificate, access headers); the app says so first ([D65]).
- The mix-up is not closed; that needs a server change (RFC 9207 `iss`, or a consent screen naming the client). Whether a named host belongs to the server is left to the user (a look-alike host passes), and a server whose own `/oauth/authorize` redirects elsewhere is not asked about. Without a consent screen any app with a `vikunja-…` scheme can get a token for a user signed in to the web in the system browser.
- The plugin's 5.x line predates its UIScene and Kotlin migrations (Flutter warns its Kotlin Gradle setup will stop building): the move to 6.0 is due once stable; a replacement would be our own platform channel behind `WebAuthenticator`, as a new decision.
- The fallback below iOS 17.4 is checked only in the plugin's source; it waits for a device test on iOS 15–17.3.
- iOS logs that ASWebAuthenticationSession support for `http://` pages is deprecated; plain-`http://` servers may lose browser sign-in in a future iOS release.

## D24: Tokens in secure storage, readable after the first unlock

*Accepted 2026-10-09 (step 2+3).*

- flutter_secure_storage 11.x with a refresh and an access token entry per account (why: the refresh token is the most sensitive secret the app holds, and secrets live only in the Keychain or the Keystore).
  - iOS: `KeychainAccessibility.first_unlock_this_device`, `synchronizable: false`.
  - Android: the plugin's v11 defaults (AES-GCM with a key wrapped by an Android Keystore RSA key) with `resetOnError: false`, and every token write flushed to disk before the app goes on ([D59]).
- First-unlock accessibility, because background sync, notification actions and the widget worker must use the tokens while the device is locked. Before the first unlock after a restart nothing can refresh; background runs treat the locked Keychain like a network error: keep everything, retry later. The app lock does not change this: it is a gate over the UI only ([D64]).
- The access token is stored as well, so another isolate can adopt a refresh result instead of refreshing again ([D26]).
- The other secrets use the same store and accessibility: link-share tokens and hashes ([D62]), access header values and client certificates ([D65]).
- No other place holds secrets: not the preferences, not the database, not logs. The log redaction covers `Bearer`, `access_token`, `refresh_token`, `code=` and `state=`, among others.
- Android keeps the entries out of backups and device-to-device transfer (owner, [D66]); on iOS the `ThisDeviceOnly` items never reach another device and never sync through iCloud Keychain.
- Widgets and extensions get no keychain access group and no token ([D63]).
- **After a reinstall:** iOS keeps Keychain items when the app is deleted, but not its preferences, so the first UI start that finds neither the install marker nor a registry wipes secure storage once. A locked Keychain leaves the marker unset, so the next start tries again; a registry without the marker is an update from an older build and is left alone.
  - On Android the same start is the first after the update from the old app ([D85]): the import reads the old entries it needs before the wipe, which then deletes them all. The session try runs only once the wipe has succeeded.

Limits:
- Changing the accessibility class later means rewriting the existing items.
- An iOS backup brings the tokens back only to the same device, from an encrypted backup ([D66]); elsewhere the restored accounts need a new sign-in.
- Deleting the app never logs its sessions out on the server; they end without a refresh after the server's session lifetime, 72 h by default.
- Builds of the old app from before February 2026 wrote their entries with flutter_secure_storage 9, which version 11 cannot decrypt: after the update their users get the note without a prefill and sign in again ([D85]). Their entries are only counted, and the wipe deletes them.

## D25: Account registry in SharedPreferences, without secrets

*Accepted 2026-10-09 (step 2+3).*

- The registry is JSON in `SharedPreferencesAsync` under `auth.account_registry` (why: the UI and background isolates need the accounts, the active one and each server before any database is open): the accounts (kind, server root, user id, username, display name, whether a sign-in is needed, and for a link-share guest the share, project and share name, [D62]), the active account and the activation order, most recent first ([D37]), and each account's last server connection (root, API versions, `/info`).
- `SharedPreferencesAsync`, not the cached legacy API: every read goes to the platform store, so a background isolate never works on a stale in-memory copy.
- Every write runs under a lock that every isolate of the process honours, so no isolate writes back what another removed meanwhile; reads stay without it. A holder whose isolate has ended is found by a ping after 1 s and taken over, and after 10 s a writer goes on without the lock, logged. The registry also lists the accounts signed out whose local data is not deleted yet, until it is deleted or the account signs in again; a registered account never counts as one still to delete ([D96]).
- Account id: the first 32 hex characters of `sha256("${serverRoot}|${userId}")`, for a guest of `sha256("${serverRoot}|share|${shareId}")`. The same user on the same server is always the same account; signing in again replaces its session, and the old session is logged out best effort.
- The registry holds no tokens or other secrets ([D24]), nor does `auth.confirmed_sign_in_hosts` beside it ([D23]). The update from the old app ([D85]) keeps one entry without secrets beside it, `previous_app.import` (the old app's server addresses and the number of its placed widgets), until an account is registered; its light or dark goes straight into the device's theme ([D45]).
- The registry and secure storage can disagree after a crash or a restore: an account without tokens is handled like one that needs a sign-in. Storage that cannot be read (before the first unlock, or a passing Keystore failure) does not count as missing tokens; only reads that keep failing at app starts for 24 h do, and any good read ends such a run of failures; a guest marked for unreadable storage is unmarked once its link reads ([D59]).
- An entry that cannot be decoded is left out of the state but written back unchanged; a readable entry with the same id replaces it. A registry that cannot be decoded at all is copied to `auth.account_registry.unreadable` before it is first overwritten.

Limits:
- The id depends on the normalised server root: the same server reached through two addresses (a LAN IP and a domain) gives two accounts, and an `http` account is never upgraded to `https` ([D65]).

## D26: Refresh concurrency: single-flight, re-read and adopt, write-ahead, epoch

*Accepted 2026-10-09 (step 2+3).*

- Why: Vikunja rotates the refresh token on every refresh without a grace period; reusing a rotated token gives 401 code 16002 and the session cannot be recovered, and the loser of a concurrent rotation gets 16004.
- The session manager is the only code that refreshes; `vikunja_api` sees it only through `AccessTokenSource`.
- **Single-flight:** one refresh per account and isolate at a time.
- **Re-read and adopt:** before a refresh and on every session-ended answer the stored tokens are re-read, and tokens another isolate stored meanwhile are adopted instead. 16002 and 16004 re-read with growing delays (up to 8 s apart) for about 16 s, and after a race with nothing newer only defer the refresh ([D59]); 16003 and 412, which concern the session of the token sent, re-read once.
- **Write-ahead:** the rotated tokens are persisted before the new access token is used (why: until then storage holds the invalidated refresh token, and a sibling isolate refreshing with it would end the session). If the write fails they are used from memory and written before the next token request, never over newer tokens in storage, so older tokens never land last; a read that finds no tokens still ends the session. Only the error type is logged.
- **Epoch, as retirement:** sign-out, account removal and a new sign-in retire the account's session manager for good (a new sign-in gets a new one), so a refresh that finishes afterwards is discarded. Sign-out retires first and wipes storage afterwards. A retired manager hands out no token, also none from a refresh still running when it was retired: not when the rotated tokens' write had begun (they still land in storage), not when that write fails afterwards, and not the old access token after a refresh that failed for now (owner, 2026-11-20, [D110]). It writes nothing more, and retiring waits only for a storage write already started, never for a refresh on the network.
- Expiry is judged with the per-account server clock offset stored in preferences, so a cold start or a new isolate need not wait for a response. The refresh request is not tied to UI cancellation and has a generous timeout.
- **Failure classes:** network errors keep the tokens; 5xx is retried once after 2 s, after re-reading storage (a SQLite server answers the loser of a race with 500 instead of 16004); 429 waits for `Retry-After`, at most 10 min; a session-ended answer (16002 without a sign of a race, 16003, 412 code 1020 or 1040) marks the account `needsReauth` and keeps its local data; unreadable storage, a missing or unreadable registry connection and, from 2.7.0 on, a 401 without a code keep the tokens for a later try ([D59]).
- No cross-isolate lock: `RandomAccessFile.lock` takes POSIX record locks, which belong to the whole process, so it cannot keep two isolates apart. Re-read and adopt is the only cross-isolate mechanism.
- Short-lived isolates (a notification action) never refresh: they use a stored access token while it is valid, else fail the request as a rejected token, leaving the rotation to the app ([D39]). Background runs do refresh, only while the answer can still arrive before the run's container goes (why: a rotation whose answer is never stored ends the session) ([D40], [D59]).

Limits:
- Without a lock two isolates can send the same refresh token at once; the loser adopts the winner's tokens once written, so the adoption re-reads must outlast the winner's write-ahead.
- A response lost after the server rotated (the process killed, the network dropping) ends that session; the record of the end names that refresh ([D59]).
- Tokens not yet stored live only in that isolate's memory: while secure storage keeps failing, an isolate that ends loses the rotation.
- Retirement is per isolate: a sibling isolate can still write tokens back after a sign-out elsewhere; [D40] narrows this but does not close it.

## D27: Paging and the query builder beside the read adapters

*Accepted 2026-10-09 (step 2+3).*

- `Page<T>` (v1's pagination headers, v2's `{items,total,…}` envelopes; `total` only on v2) and the query builder `TaskQuery` (filter, sort and paging parameters) are in `vikunja_domain` and serve the read adapters of `vikunja_api` ([D12]).
- **The rule for whole lists:** every list the app reads whole outside the sync skips ids already seen, stops at the server's page count or at a page without a new id, and stops after 200 pages (10,000 items at 50 a page) with a warning in the diagnostics log ([D96]).
  - The sync keeps its own walks on purpose: the keyset walks over tasks ([D32], [D33]), and for projects, labels and the downloaded lists a walk that starts over when the server's counts change between two pages, fails as unexpected after three walks and never cuts, so a purge never deletes what was not read.
  - Reads of a bounded window keep their own ends: the inbox's pages ([D40]), a board column's pages loaded before, the outbox's search for a create whose answer was lost, and the comment pages loaded or up to the end of a thread.
  - One loop is outside the rule ([D110]): the outbox's search for a label by its title reads until the server says there is no more, without skipping ids already seen and without a cap.

## D28: Contract tests against the latest Vikunja release only

*Accepted 2026-10-09, the owner's decision.*

- `test_servers/docker-compose.yaml` runs one `vikunja/vikunja` image of the latest release, now 2.8.0, pinned by its tag and the digest of its multi-platform index ([D97]); CI checks that the compose file, the contract helpers' default and the matrix's last entry agree. `VIKUNJA_APP_TEST_VIKUNJA_IMAGE` runs another release, recreating the server empty; the opt-in `tls` profile runs the same release ([D65]).
  - The service `vikunja` on port 34527 is published on `127.0.0.1` only, in CI too, because it allows open registration with a public JWT secret.
- The servers raise Vikunja's sign-in limit, which cannot be turned off, from 10 to 1000 a minute per IP, and open SQLite with immediate transactions through the database path (`/tmp/vikunja.db?_txlock=immediate&_busy_timeout=30000&_x=`), so that parallel writes wait instead of failing with "database is locked". The path relies on the server appending its own options after a `?`: after a bump, the startup line "Using SQLite database at:" must show it, and a contract run must log no "database is locked".
  - Releases before 2.7 stop under immediate transactions, their event listeners waiting on their own transaction (2.3.0 at a comment's notifications; 2.4.0 to 2.6.0 about 30 s after a data export request, which the tests skip before 2.7). So 2.3.0 runs without them (`VIKUNJA_APP_TEST_DATABASE_PATH=/tmp/vikunja.db?_busy_timeout=30000&_x=`), and `tool/ci/contract.sh` then runs `vikunja_api`'s files one at a time (why: parallel writes fail without immediate transactions).
- Contract tests are tagged `contract`, need `VIKUNJA_CONTRACT=1` and run in a CI job of their own ([D73]). The job `contract` of [D86] runs `tool/ci/contract.sh` against the latest release on every push and pull request; the script runs both suites before it fails and names those that failed. CI stays on the latest release (owner).
- **The contract matrix** ([D111]): the workflow "Contract matrix" ([D86]) runs the same script against the newest release of each minor line from the floor (2.3.0, 2.4.0, 2.5.0, 2.6.0, 2.7.1, 2.8.0), pinned by tag and digest, every night in go-vikunja/app, on every `v*` tag and by hand, beside CI rather than in it. Before a release is approved, what fails in the tag's run is fixed or recorded here ([releasing.md](releasing.md#cutting-a-release)).
- **Version-aware tests:** a behaviour that differs between releases is asserted from its first release and skipped, or asserted the old way, before it ([D13] lists them), as are 2.8.0's features (the trash, the title and reminder limits, reminders that follow subscriptions, the legal links). On 2.3 both suites skip the v2 groups and send v2 seeding the v1 way. Unit tests with responses recorded from older images cover older servers too.

Limits:
- Only the newest release of each minor line runs, the older ones only at night and on tags, so a regression only an older server shows is seen the next night. The matrix is no required check and does not hold the publish job; a red entry holds a release only through the release's reviewer ([D86]), who approves once its failures are fixed or recorded here.
- The matrix has not run on GitHub yet: the nightly run is off outside go-vikunja/app, and until the import ([D87]) it runs only on a tag or by hand.
- 2.3.0 runs without immediate transactions: a contract test once got a 500, probably a "database is locked" race (`parity: an upload to a task that is gone`).
- Not tested before 2.7: the data export, skipped by release though the transaction mode is what stops the server. No contract test covers bulk task creation (2.5) or the pending e-mail address (2.6).

## D29: Screens read and write through repository interfaces

*Accepted 2026-10-10 (step 5).*

- Screens depend only on the repository interfaces in `app/lib/core/repositories/` and on the domain types; they never see `Page`, the ports or DTOs (why: an implementation can change without touching a screen, and widget tests use fakes).
- The contract: streams of the current local state plus explicit refresh calls. A failed first load is the stream's error; a failed refresh throws the failure and leaves the stale data in the stream.
- The local implementations serve from the account's database ([D31]), which the sync fills through the same read ports ([D32], [D33]); the online-only areas (account security, sharing, teams, the trash) have online implementations.
- The read client and the repositories are Riverpod providers keyed by the account id and disposed on sign-out.
- A single lookup reads the database, not the last list a screen watched ([D96]).

## D30: Kanban board reads deferred to step 20

*Superseded by [D47].*

## D31: One Drift SQLite file per account, shared across isolates

*Accepted 2026-10-10 (step 6).*

- drift with sqlite3 through its build hook, no `sqlite3_flutter_libs`: Android uses the prebuilt SQLite with verified hashes, iOS the system's, which needs no privacy manifest ([D74]).
- One database per account at `<application support>/accounts/<accountId>/vikunja.db`, in WAL mode and shared by every isolate of the process through one connection and one stream-update bus. So no account column is needed, and an account switch never shows another account's rows.
  - Never in the iOS App Group container; the widget extension never opens it ([D63]).
  - Not encrypted: it holds no secrets, and an encrypted database would need its key in every background isolate. It stays out of backups and device transfer (owner, [D66]).
- **Schema rules:** ids are the server's, and unsent creates use temporary negative ids ([D35]); every row keeps the server's `created` and `updated`, which the delta sync keys on ([D33]); dates are nullable UTC epoch milliseconds. Tasks carry the sync run that last returned them, so a full run's purge survives a restart ([D96]). No foreign key on a task's project (a task can arrive before its project) or on a relation's other task (it may be one the user cannot read). Pseudo projects (Favorites `-1`, saved filters `≤ -2`) are not stored as projects ([D43], [D51]).
- Every schema change bumps the version and adds a dump to `app/drift_schemas/` and a migration test.
- **Closing and deleting:** sign-out and account removal delete the database file with its `-wal`, `-shm` and `-journal` companions after the tokens and the registry entry ([D26]), even while a client in another isolate (a background run, a notification's or widget's Done) keeps the database alive; the account is then remembered as a leftover. An account that needs a sign-in keeps its data. A wipe that a crash cut short or that failed runs again at the next start ([D96]).
- **Signing straight back in:** the account gets the same id, so its new database would attach to the old isolate by its port name and work on the deleted files. So a sign-in first waits for each leftover's isolate to go (at most 30 s, else it fails and asks to try again) and deletes its files once more. A user's sign-in waits for every leftover before the browser opens, because the account is known only when the browser returns; a guest and "Sign in again" wait for their own account ([D62]) (why: an entry kept from before a sign-out would be registered again onto a database still closing). Leftovers are kept in memory, as a restart ends the old database isolate.

Limits:
- A client in another isolate keeps the old database isolate alive past the sign-out and works on the deleted files until it lets go; signing that account in again waits for it, at most 30 s.
- A user's sign-in waits for any account still closing, not only its own.
- An Android build needs the sqlite3 build hook to fetch its prebuilt library (honours `HTTPS_PROXY`).

## D32: Full sync by keyset paging with per-page checkpoints

*Accepted 2026-10-10 (step 6).*

- The sync engine, one per account, is headless: no `BuildContext` and no Riverpod inside; the read client, the database, a clock and a `GET /user` source are injected. Runs are serialised per account; a call during a run joins it, except a refresh the user starts, the outbox sender's after it sent and a few writes', which start a run of their own after it (owner, 2026-11-18, [D97]).
- The full run (the first sync and [D33]'s full resync) goes in phases: the account (`GET /user` with settings and profile); all projects with `is_archived=true`, purging those not returned; all labels; the tasks, open then done, by keyset; the same keyset per archived project and its descendants (why: `GET /tasks` leaves out the tasks of archived projects); finishing (the Overview's saved filter when the device cannot evaluate it, [D43], then the purge of tasks not seen).
- Keyset paging, because page numbers are neither resumable nor stable while data changes: `filter=done = false && id > <lastId>` (or `done = true`), `sort_by=id&order_by=asc`, `per_page` = `max_items_per_page`, `page: 1` on every request, following the page size the server returns (it caps `per_page` silently).
  - Every page must be strictly ascending by id and start above the cursor, otherwise the run fails before the page is stored (why: a cursor that skipped ids would make the purge delete them silently).
- After every page the engine checkpoints the run, its phase, counts and cursor; an interrupted run resumes from its checkpoint.
- Purging happens only in finishing, by the run id on the rows, so an interrupted run never deletes; rows that other writes stored during the run (stamped `<run>+`) stay ([D96]).
- Before the purge a catch-up pass over `GET /tasks` with `updated >= <newest task updated − 120 s>` marks its rows with the run id, so a task reopened after the open pass passed its id and completed again after the done pass is not purged. The bound is a server time, the newest `updated` with `filter=updated <= '<device clock + 1 h>'`, read before the task phase and kept in the checkpoint (why: a row a fast server clock once wrote would put the pass above every real change); it is also the run's watermark ([D33]).
- A failed request ends the run; rows from earlier runs stay readable, and the caller of a refresh gets the failure ([D29]). A stored state that cannot be read fails the run and is read again on the next call, so the first-sync screen's Retry covers a damaged file.
- Until the first run has completed the app shows a blocking first-sync screen (cancel signs out), afterwards only a quiet indicator. An account that has synced opens the shell at once; a network failure with cached rows is an "offline" notice, not an error.

Limits:
- A full run costs about `tasks / max_items_per_page` requests plus the project, label and archived-project pages.
- Comments, attachments and the boards' buckets and positions are not part of the sync; they are read online on demand ([D44], [D47]).

## D33: Incremental sync from an `updated` watermark, deletes found by counts

*Accepted 2026-10-10 (step 7).*

- The incremental run is the normal refresh; the full run is [D32]'s. Runs are serialised per account and hold the account's lease ([D40]); a full resync asked for during an incremental run follows it.
- After a write of the app, an outbox send, a project move and a change the realtime socket announced, the refresh starts after the call, so a run already in flight cannot undo it ([D50]). Every refresh the user starts (pull to refresh, the Refresh menus, Retry, "Sync now", the offline banner's tap) waits for a run under way and starts one of its own (owner, 2026-11-18, [D97]); the automatic ones (timer, resume, start, background runs, the screens' quiet refreshes) join it.
- **Watermark:** a server time, the newest task `updated` the run itself read on its delta pages, never the newest in the database (why: outbox answers, restores and creates write rows with a fresh `updated` during a run, and a watermark above them would skip what others changed meanwhile). An incremental run never lowers it; a full run sets it to the newest `updated` the server had when its task phase began ([D32]), not to what its catch-up pass reads (why: that pass walks by id, so a later page can lie above an edit it already passed). A value more than 1 h ahead of the device clock is left out, so a fast server clock cannot push every delta into the future.
- **The incremental run** reads the user ([D38]), all project and label pages diffed locally, the task delta and the archived projects, checks the counts, and writes the watermark with the last sync time in one transaction. A failure keeps the old watermark and rows; nothing is purged by a partial result.
  - **Projects:** one no longer listed is purged with its tasks; a new or un-archived one, or one the app stored from a write's answer, is pulled whole, as its tasks may be older than the watermark ([D109]). Only rows that differ by value are written (a favourite toggle bumps no `updated`), so a run that finds nothing new writes none of them and leaves the database's watchers alone.
  - **Task delta:** a keyset over `(updated, id)` from the watermark minus 120 s; a page out of order fails the run before it is stored. Vikunja compares a date filter value as if it sat just above its second (`>=` behaves like `>`, `=` never matches), so the keyset uses `updated > '<U − 1 s>'` for `updated >= '<U>'`. The 120 s overlap covers the second granularity and the server's asynchronous `updated` bumps for comments, attachments, relations and assignees.
  - **Archived projects:** `GET /tasks` leaves out their tasks (except the user's favourites), so a changed one gets the same delta on `GET /projects/{id}/tasks`.
  - **Delete detection** by counts, because a deleted task leaves no trace and `projects.updated` has second precision: the server's count (`total` on v2, the page count on v1) against the local count of the same scope ([D51]), the tasks outside archived projects and their subprojects plus the favourites anywhere, done ones included, as 2.8.0 counts on v1 and v2 (leaving out trashed tasks and projects and projects the user lost access to); queued deletes count, unsent creates do not ([D34], [D35]). On a mismatch each differing live project is reconciled by a keyset read and a purge ([D96]). A mismatch the walk cannot explain is not walked again while the totals stay (why: it cannot locate a difference among an archived project's favourites, and would cost one request per project every 60 s).
  - A 404 or 403 with a Vikunja code on a project's requests (3001; 3018 in 2.8.0's trash; 7003 for lost access) purges the project with its tasks; a missing route does not.
- **Daily full resync:** in the app a refresh runs the full resync instead when the last one is older than 24 h or missing (why: it catches what bumps no `updated`, such as position and bucket moves, and a count that matched by coincidence). Headless engines stay incremental once a run has completed ([D40]).
- **Triggers:** the first frame and an account switch; in the foreground a run 60 s after the last one ended and on resume, backing off up to 5 min after failures ([D99]), none while paused or hidden; the user's refreshes and the Account tab's "Full resync", disabled during a run and while a sign-in is needed; the background runs ([D40]) and the realtime socket ([D46]), which never replaces the 60 s timer.
- **Budget:** a run that finds nothing new costs 5 requests for a small account, far below the server's optional limit of 100 per minute.

Limits:
- Until the next full resync the delta misses pure position and bucket moves and other changes that bump no `updated`, and a task deleted on the server right before its project was archived stays; if it was a favourite, the walk runs once, then the kept totals stop it (so does a favourite toggle refused with 3008 because the project was archived meanwhile, until it is discarded).
- On v1 a project deleted while the list is paged, without changing the page count, can shift another project out of that run's walk; that one is purged and comes back on the next run.
- An automatic refresh during a run joins it, so a change the server got after that run read its delta arrives with the next run ([D97]).
- A server clock that steps back by more than the overlap (119 s in effect) hides the edits stamped in that gap from the delta until the daily full resync; creates and deletes still show in the count probe.

## D34: Outbox: local-first task writes, one serial sender, coalescing, retry classes

*Accepted 2026-10-10 (step 11).*

- **Local-first:** a task write changes the local row and queues the server call in one transaction; it never throws for network reasons and shows at once, offline too (why: the lists work offline, and notification actions and widgets need the same queue). Label creates, updates and deletes go through the same queue ([D36], [D109]).
- No 3-way merge: the server offers no precondition (it ignores `If-Match` and never answers a conflict with 412), and v2 merges per field on its own.
- **Ops:** task create ([D35]), update, delete, and attachment upload in a lane of its own ([D53]). An update carries only the changed fields ([D36], [D41], [D47], [D49], [D53]).
- **Write ports:** v2 sends a merge-patch with only the set fields (a cleared date as `0001-01-01T00:00:00Z`, `hex_color` without `#`, never a key the server does not know, which is a 422) and re-reads the task after a 304. v1's `POST /tasks/{id}` is a full replace, so v1 emulates the patch: `GET`, overlay, `POST` the whole object back with `assignees` and `reminders` exactly as read and never `labels`. A delete counts a gone task (4002, or 4040 in the trash) as success.
- **Coalescing:** an update merges into the task's newest pending update, the later value winning per field, and an op that fails for good while a newer op of the task is queued folds into it, so a task never has two ops that could go out in either order and a Retry never overwrites a newer edit. Two updates are not folded when either may have reached the server (why: its next attempt may leave out the body it sent once, and an edit folded into it would go with that body). **A delete is queued like any other op, on every server,** and can be taken back while queued ([D79]).
- **The sender**, one per account and headless, sends one op at a time, oldest first, each claimed `sending` in a transaction before it goes, so only one isolate sends it; the oldest op blocks the queue during its backoff, a failed one does not, and an op `sending` elsewhere stops every queue until it is 5 min old. An op another process left `sending` goes back at the first drain after a restart, as every isolate of the app runs in one process ([D94]).
  - On success the server's task replaces the row, except the fields a newer op holds pending. After sending, the sender asks for a sync run that starts after the sends, so server-computed fields arrive and a run that read the server before them cannot store the old row over the answer (owner, 2026-11-18, [D97]); a background run syncs right after by itself ([D40]).
- **A repeating task's Done is applied once** (why: the server moves a repeating task's dates and reminders on every Done it gets, so a resent Done moves them twice). Every attempt after the first reads the task again, and the Done counts as landed when `done_at` has moved and the dates too or the base had none (why: the server stamps `done_at` and moves the dates for each Done, while a date edited on the web leaves `done_at` alone), and then its body is not sent again, as its dates or reminders would undo the server's move; a Done the web already made for the shown occurrence is dropped ([D96]).
- **Retry classes:** only the sender retries writes, and a paused sender resumes with the next sign-in, so a session's end never loses an edit.
  - A network failure, a rate limit, a lost refresh race, a token still rejected after the refresh, a 2xx that is not JSON (a captive portal, [D96]): retried with a jittered exponential backoff from 2 s, at most 15 min; a `Retry-After` above zero wins, capped the same.
  - A 5xx, a 404 without a Vikunja code, an unexpected 3xx, and for a create or an upload an unreadable answer or an exception: the same, but the 16th in a row (an upload's 4th) fails the op, a create or upload keeping its mark that it may have reached the server ([D94]).
  - A session that ended: paused until the account is signed in again ([D22]).
  - A 404 with a Vikunja code, 403, 3008, a validation failure, any other unexpected answer: failed at once, a sync problem.
- **Sync problems** are listed on the Account tab with Retry and Discard. Discard reads the task from the server first; a read that fails changes nothing, so an edit is never lost offline. "Pending changes: N" comes with "Send now"; a row with unsent changes shows a cloud-off icon.
- **Sync interplay:** the sync overlays pending changes on incoming tasks, keeps a pending delete hidden, never purges a row with a queued op and never touches the outbox ([D33]).
- **UI:** a done shows "Marked as done · Undo" for 3 s (persisting under a screen reader), and a done row stays in place until its 3 s are up and its snackbar has gone, so a second tap never pulls a row away under the finger. Such a row of a task created on the device follows the task to its server id, so no second row appears, it keeps its place and reopening it hides the Undo; each snackbar's close touches only its own row (owner, 2026-11-20, [D110]).
  - Undo is a second write (`done: false`, for a repeating task also its previous dates and reminders, [D36]), whether the done is queued, in flight or answered ([D95]). Confirmations come only once the change is stored ([D96]).
- The sign-out and account-removal dialogs say how many queued changes the wipe would lose; that wipe is the only way an edit is lost.

Limits:
- Writes are at least once: an op whose answer could not be applied locally, or a kill between the server's apply and the local one, is sent again. The Done check misses a task the device does not know as repeating yet, a board move into the done column without `done` (which the board turns into a plain Done, [D47]) and a Done queued behind another change of the task ([D96]); it rests on the server stamping `done_at` on each Done, as 2.3.0 to 2.8.0 do.
- A failed op that may have reached the server, retried after a newer edit was sent, can overwrite that edit's fields of the same name when its own body never arrived.
- Last write wins per field: a field the web changed while the phone's value waited loses to the phone; the description is the exception ([D52]).
- Undo on a repeating task leaves `done_at` stamped and the server's checklist reset in the description in place.
- A repeating task marked done offline with the "from completion" mode counts from the send, not the tap.
- A failed update with a delete queued behind it is dropped, so an Undo brings the task back without that edit.
- A 5xx outage of more than about one to two hours turns the queued ops into sync problems one after another ([D94]).

## D35: Task creates through the outbox under temporary negative ids

*Accepted 2026-10-11 (step 12a).*

- **Temporary ids:** a create stores the row under a negative id, never reused, and queues the create in the same transaction (why: the server assigns ids and has no idempotency key). The row is an ordinary task for every screen; the sync never overwrites or purges it, the count probe leaves it out ([D33]), and negative ids never reach the server. Labels created on the device work the same way ([D36]).
- **Coalescing:** while the create has not left the device, edits fold into it; once it may be on the server, edits queue behind it, and nothing is sent under a temporary id before its create is through. A delete of a create that never left the device drops it without a request, unless an Undo took it back ([D79]).
- **Sending:** v2 `POST`, v1 `PUT /projects/{id}/tasks`; a date only when set (the server stores the zero date for an omitted one) and the project only in the path (a `project_id` in a v1 body would override it); `done`, assignees, `bucket_id` and labels follow as an update after the remap ([D36]).
- **Remap** on success, in one transaction: the queued ops and the row move to the server id, and the pair goes into `task_id_remaps`, never pruned, so screens, later edits and relation refs follow it ([D41]).
- **Lost response:** a create that may have reached the server without an answer ([D94]) records `sent_at`. Its next attempt first lists the project's tasks created since `sent_at − 1 h` and adopts the newest with the sent title that this account's user created (for a guest the share's pseudo user `-shareId`, [D62]) and no other create of this device adopted; only when none is found is it sent again (why: a blind resend makes a duplicate). Another member's task is never adopted, because the queued ops would follow it there; the creator is checked whenever the user id is known, as for uploads ([D53]).
- **A rejected create** (4001 or 4029, a validation failure, no access, project gone or archived) is a sync problem naming the title; the ops behind it wait, and Discard drops it with its row without a server read.
- **Edits:** a repeat of zero in the default mode removes the repeat. After a move both adapters read the task back, because the server's answer still carries the old project's identifier.
- **Editing rules from the web** (`vikunja_logic`): the web's date shortcuts, except that `today` stays after 21:00 and then takes 23:59 ([D106]); a date-only pick takes the user's `default_due_time` (only as two-digit `HH:MM`, as the web reads it), else the next of 9, 12, 15, 18 and 21 ([D38], [D98]); a time today that has passed becomes 23:59 ([D102] point 9); repeats in hours, days or weeks with the modes default, monthly and from completion date, refused when negative or over the server's 10 years (87600 hours, 3650 days, 521 weeks, [D96]); priority 0–5; percent done in 10 % steps; colours from [D81].
- **UI:** a full-screen edit page saves only the diff, asks before leaving unsaved changes and stays open when the device could not store the change ([D96]). The task detail edits the due date, priority, reminders and labels in place ([D84]). The New task sheet is [D75]'s, and the project a new task goes into is [D38]'s.

Limits:
- The lost-response match can still adopt the user's own task of the same title that another device or the web created in that project within that hour; the phone's own is then never sent. Description and due date are no tie-break, because the server normalises both. The lookup also runs when the first attempt never left the device, as every network failure records `sent_at`.
- The window has no upper end: a retry after a long time offline reads every task created in the project since `sent_at − 1 h`.

## D36: Labels, assignees and reminders in the task update; labels created through the outbox

*Accepted 2026-10-11 (step 12b).*

- **Id-set deltas:** labels and assignees change as ids added and removed (the later change wins per id) inside the ordinary update op, so [D34]'s queueing and folding and [D35]'s remap apply unchanged.
- **Read-before-write diff:** the update sends the body, then reads the task and sends only the label and assignee requests that differ (why not the bulk endpoints or the v1 body: they replace the whole set, so a label added on the web meanwhile would be dropped). A label add answered 8001, an assignee add answered 4021 and a label remove answered 403 for a label no longer attached count as done, so a resend is harmless.
- **Failures:** 8002 (label gone), 1005 (user gone), 7003 (user without access to the project) and a 403 without a code (a label the user cannot see) are permanent sync problems; Discard restores the server's labels, assignees and reminders. A 404 other than a gone task's never removes the task.
- **Reminders** go as the task's whole list (the later list wins). The server keeps one reminder per instant, so the editor never adds an equal one and warns before a save where two would share one. The update reads the task back afterwards, because the answer echoes reminders the server merged.
- Undoing a done on a repeating task also sends its previous reminders, so the server's shift of absolute reminders is taken back.
- A label the sync finds deleted on the server leaves every unsent update; the label sync never purges or overwrites a label with a temporary id or one created during the run ([D109]).
- **Label creation through the outbox** (owner, step 40m, [D109]):
  - The picker offers "Create label "X"" when no label has the typed title (ignoring case), offline too: the label is stored at once under a temporary negative id with a random colour of the Okabe–Ito palette (owner, [D81]); attaching it is the ordinary update. Titles over 250 code points, or blank, are refused.
  - A task update naming a label whose create is queued waits for it; the answer moves the label and its uses to the server id ([D35]'s pattern, `label_id_remaps`).
  - A create whose answer was lost is not repeated blindly (the server would store a second label): the next attempt adopts a label with exactly that title that this user created around the attempt and the device did not know before; another member's label is never adopted. Quick add and the New task sheet first take the server's label of that title ignoring case.
- **People:** the picker searches the project's users online and stores them; offline or when the search fails it shows the known people with a notice, filtered ignoring case and accents ([D81]). A move keeps the assignees; one without access in the new project fails with 7003.
- **Reminder sheet:** the web's presets relative to the due date (else the start, else the end), a custom relative form and an absolute date. Editing a relative reminder keeps its sign, where the web always shows "before". The task detail uses the same pickers in place ([D84]).

Limits:
- The requests of one update are not atomic: when one fails for good, the earlier ones stay applied; Retry sends only what is still missing.
- Per id the last write wins: a label the web removed while the phone's add waited is attached again.
- Changing or deleting a label the server has, with nothing of it queued, still needs a connection ([D60]).

## D37: Account switcher: an avatar sheet, a switch resets the navigation

*Accepted 2026-10-11 (step 4).*

- **Entry points:** the active account's avatar (a guest's link icon, [D62]) in the Overview, Upcoming and Projects app bars opens the account switcher: the accounts by recency, the active one first, each with its server and badges for "Sign in again" and unsent changes, then "Add account" and "Manage accounts". The Account tab lists the other accounts and "Add account"; the rest of it is about the active account.
- **The switch** only sets the active id in the registry ([D25]), and everything keyed by the active account follows. It is refused while a sign-in, a sign-out or another switch runs (why: a finishing sign-in activates its own account).
  - Before the next frame the shell closes every dialog, sheet, pane ([D70]) and page over the shell (pages bound to an account show blank while they animate out), resets every tab to its root and shows the Overview, so no screen reads another account's database.
  - Links, widget and notification taps and shares switch the same way ([D44], [D66]), but first let what is open go as if the user went back ([D91]): what asks a question asks (Keep editing refuses the switch), a dialog or sheet that would not ask closes at once without an exit animation, and what cannot be popped and asks nothing, such as a busy sheet, refuses it.
  - A switch, a removal of the active account and re-adding an existing one wait (at most 5 s) for the target engine's stored state, so an account that has synced never passes through the first-sync screen; the router reads the registry and the sync status itself, and outbox readers ignore a value of the previous account (why: Riverpod delivers derived providers a frame late). The first-sync screen has no entrance transition (why: a quick round trip would build two shells with the same navigator keys).
- **Recency:** the registry keeps the activation order, most recent first, beside the stored order, which never changes; without it, the stored order with the active account first counts.
- **Add account:** the Connect screen over the shell, with the existing accounts' servers as chips. A new account goes to its first sync; an account already on the device (same user and server, so never a duplicate) gets its session replaced and becomes active, saying so.
- **Remove:** a full sign-out of that account (server logout, tokens wiped, registry entry removed, database deleted). The dialog names the account and server, warns of deleted local data and lost unsent changes and, for the active account, names the one the app switches to, the most recently active remaining. Removing an inactive account leaves the active one alone. Connect shows only after the last account. A removal that fails says so and the account stays; data a crash or a failed wipe left is deleted at the next start ([D96]). Cancelling an added account's first sync is the same sign-out.
- **Inactive outboxes drain in the foreground:** on start, resume and a change of the account list, every other account that does not need a sign-in and has queued ops is asked to drain, never during a sign-out; no sender is built for an account without queued ops, and one built is kept until the account goes. Inactive accounts are not synced in the foreground (why: queued changes are what cannot wait; [D40] syncs them in the background).

Limits:
- Start and resume open every inactive account's database to count its queue.
- An inactive account whose session ended needs a switch to sign in again.

## D38: Quick add: the web's grammar with fixes, through the outbox

*Accepted 2026-10-12 (step 13).*

- **The parser** is in the pure package `vikunja_logic`, its day intervals and default time shared with the app's date shortcuts; dates are local wall-clock times. It re-expresses the web's behaviour without its code ([D67]); the web's test vectors are ported, deviations marked `D19-n` or `D38-n`.
- **The grammar is the web's** ([research/client-logic.md](research/client-logic.md) §1.2–§1.8): prefix modes (`vikunja`: `*` label, `+` project, `!` priority, `@` assignee; `todoist`: `@`, `#`, `!`, `+`; `disabled` parses nothing), quoted items, priorities 0–5, repeats, dates with `at`/`@`; a day the month never has is no date ([D102] point 6). English keywords only (why: the web has no translated ones, and mixed languages would be ambiguous). Deviations:
  1. **Repeats** ([D19]): `every N months` (N ≠ 1) is N × 30 days, `every month`/`monthly` the monthly mode, `every N years`/`yearly`/`annually` N × 365 days, `biannually`/`semiannually` 180, `biennially` 730.
  2. **Capitalised keywords** (`Daily`, `Every Day`) mean what lower case means.
  3. **A trailing word boundary** for the date keywords: `todays`, `next weekend` stay text.
  4. **Day and month as whole words:** `12 decorations` stays text, `12 dec` parses.
  5. **The default time, not the clock time of `now`:** the user's `default_due_time` when set, else the next of 9, 12, 15, 18, 21 o'clock, for every date without a time and a repeat without a date ([D35], [D98], [D102] point 5); `tonight` is 21:00, `end of month` the last day; `at …` wins; `in N …` adds to `now`, as on the web. A passed default time on today gives 23:59, a passed ordinal is next year's ([D102] points 9 and 3).
  6. **`next monday` on a Monday** is today in the day interval, as on the web; quick add's `next` on the weekday itself is a week ahead ([D102] point 4). After 21:00 the next default time is 09:00.
  7. **An unmatched `+project` stays in the title** (why: the web drops it and silently uses another project). Archived projects (a create fails with 3008) and read-only ones are not matched ([D60]).
  8. **Lines that are only magic** never get labels created.
  9. **Whole words elsewhere:** `in …` needs a space or the line start before it (`within 2 days` stays text) and takes digits, `a`/`an` and one to twelve in any case, with the units minute to year; repeats take `eleven` and `twelve` (Vikunja 2.8.0's phrases, owner). A word boundary ends the unit, so `in 2 days,` is a date, unlike the web's space or end (owner); an apostrophe keeps it text (`in a day's work`), as on the web. Date phrases and an ordinal's month word go only as whole words (the web turns `fri frisbee` into `sbee`); a day no month has (`dec 45`) stays in the title; amounts above 100000 and `in …` dates after the year 9999 stay text.
  10. **Everything else follows the web:** a magic-only line keeps its raw title; a text quoted whole is literal; assignees stay in the title until resolved; a repeat without a date is due today; default reminders need a due date. A range of numeric dates (`31.12.2026 - 01.01.2027`) stays in the title and gives no date ([D98]).
  11. **No space before punctuation** (proposed for the owner to confirm, [D98]): a date phrase or time removed before punctuation (`.,;:!?…)]}"”»`, not an apostrophe or dash) takes the spaces before it, so `Call back tomorrow.` gives `Call back.`; the web leaves one. Spaces typed before punctuation stay; an apostrophe and a letter keep a keyword text ([D102] point 1).
- **Planning** needs no request and feeds both the preview and submit. Projects match by exact title ignoring case, else identifier ([D13]), among all projects first, so a read-only project's identifier gives "read-only" and an archived one's "not found", never a case twin. Labels match by title ignoring case, known users by exact username or name ignoring case. Without a date phrase or `!n` the sheet's date and priority apply.
- **Submit**, per line, deeper lines becoming subtasks that inherit the project ([D41]):
  - every name is looked up on the server by the web's rule (one result containing it in username, name or email, or one of several equal to it), resolved ones too (why: a known person may lack access); only a network failure keeps the plan;
  - missing labels are created once across all lines, offline too ([D36], [D81]); one that cannot be (over 250 code points, or a guest's new label) stays at the end of the title as typed;
  - a create, then the label and assignee update behind it, through the outbox ([D35], [D36]), in input order, never the bulk endpoint;
  - titles over 1000 code points are cut as [D78] says, the rest starting the description; the sheet's More options apply to every task ([D75]); reminders stop at [D78]'s 100;
  - a failure after earlier lines keeps the lines not created in the composer ([D96]).
- **Project order:** the matched `+project`, the screen's, `default_project_id`, the one titled Inbox, the tree's first, each only among projects the user may add to ([D60]).
- **Settings** from `GET /user`: `quick_add_magic_mode` (`vikunja` by default), `quick_add_default_reminders`, `default_project_id` (0 = none), read tolerantly (an odd or missing field takes the web's default); editing is [D54].
- **The composer** (the title field of [D75]'s new-task sheet):
  - highlights by colour and weight, never colour alone, with the parser's own tokenizer for highlighting, chips and suggestions, so it follows the parser in the edge cases (an unclosed quote, a quoted item holding the prefix, a doubled prefix at the line's start) (owner, 2026-11-20, [D110]);
  - previews as chips what the text sets, each removable from the text; the sheet's own date and priority are their rows' selected chips, and a due date that only a typed repeat gives keeps its chip (owner);
  - suggests labels, writable unarchived projects and people, ignoring case and accents;
  - has a `?` help button (English keywords, localised prose) unless the mode is `disabled`, and no `* + @ !` prefix toolbar (owner);
  - adds pasted lines as several tasks, each without the lines' common indent and the list markers `- `, `* `, `+ `, `[ ] `; the confirmation names the title the service created, so `Call @bob tomorrow.` with bob found reads "Added "Call ."" (owner, 2026-11-20, [D110]);
  - is a plain field when the mode is `disabled`.
- **From anywhere:** an Android app shortcut and an iOS quick action "New task" open the composer over the Overview once signed in and synced, and are ignored otherwise.

Limits:
- A label not created stays at the end of the title, not where it was typed (why: labels are created at Add, after the title was worked out; keeping it in place would need a second parse).
- A name resolved later, or a quoted label or project, can still leave a space before punctuation (`Call @bob tomorrow.` gives `Call .`), as the web's cleanup does.
- The range rule is the app's choice from the web's example, not its code (an em dash and `to` are no range); whether the web takes the time of `1.3 - 4.3 at 10:00` is unchecked; here the time alone dates the task today at 10:00.

## D39: Local notifications: a scheduler per account with a rolling window

*Accepted 2026-10-12 (step 15).*

- **Why local:** the server pushes nothing, and its in-app reminder notifications reach a phone only with a poll, after the fact.
- **The plan** (pure, from the local database): open tasks not queued for deletion that the user created or is assigned to ([D17]), on 2.8.0 and later for users instead the tasks they follow ([D80]); each future reminder and the due date, by the account's Reminders and Due dates switches. A reminder at the due instant is not planned while both are on, so that moment rings once, as "Due now"; snoozes never count in the plan, so a snoozed reminder at the due time still comes back. Instants go to the OS in UTC, so no time zone is involved. Title: the task's; body "Reminder · *project*" or "Due now · *project*", no identifier (owner, [D75]), or generic texts by the privacy settings ([D64]).
- **The rolling window:** only the first 100 entries (Android) or 60 (iOS, under its cap of 64, leaving room for snoozes and the test notification) go to the OS; iOS shares the 60 evenly among the signed-in accounts, less one each for the session reminder ([D94]). The first snoozed entry beyond the window goes too (why: its row is all that remembers the snooze).
  - Each reconcile diffs the window against what the OS was given and reschedules a changed entry without a cancel first (why: a cancel would take what the tray shows); it withdraws from the tray what is done, gone or no longer at that instant ([D94]).
  - The first reconcile of each account in a UI process schedules the whole window again (why: a force stop drops Android's alarms but not the plugin's pending list, [D90]); so does a granted or revoked exact-alarm permission (why: the pending list does not notice a revocation).
- **OS ids:** a 31-bit hash of `<accountId>:<key>`, probing upwards on a collision within the account. Id 1 is the test notification; negative ids are the session reminders ([D94]).
- **One scheduler per signed-in account** while the app runs, its state in the account's database. Without the permission, or with both switches off, it cancels everything of the account. Android uses exact alarms when allowed, else inexact; iOS is exact. It reconciles on changes to the tasks or preferences, on start and resume and after every background action or run ([D40]); privacy or language changes reschedule everything, snoozes kept ([D64], [D71]). Sign-out and removal cancel every id of the account before its database goes, and a deletion a crash cut short has its ids cancelled at the next start ([D96]).
- **Preferences per account** live in the preferences store, not the database (why: it may not be open yet): Reminders, Due dates and Activity ([D40]), all on by default.
- **Snooze is local only:** it only moves a local notification, by 10 minutes, 1 hour or to Tomorrow (the next day at the user's default due time, else 9:00, in the device's time zone). Nothing reaches the server (why: it would change the task for everyone, and the web has no snooze). Android shows Done, 1 hour and Tomorrow, as it shows at most three actions, and iOS all four (owner, 2026-11-19, [D100]).
- **Done from a background isolate, through the outbox, without a token refresh** (shared with the widgets, [D63]): a task already done, or repeating and moved past the occurrence, only gets a reconcile ([D94]); else it cancels the task's other notifications at once, then drains the outbox for at most ≈ 20 s (≈ 5 s on iOS, which may suspend the process).
  - It sends only while the stored access token needs no refresh (why: a lost refresh race ends the session, [D26]); else the op stays queued for a background drain ([D40]).
  - With the app lock on, iOS asks for the device unlock and Android shows no Done ([D64], [D97]).
  - On iOS every action first imports the widgets' waiting Done taps, without draining (why: their reminders would be scheduled again, and the network must not hold up the action's own Done, [D63]).
- **Texts** follow the app's language ([D71]); a headless isolate takes the device's locales, else the tag the app noted (iOS reports none there), else English.
- **A tap** opens the task ([D44]) after the shell and the lock, in the payload's account; a silent account switch needs the install's widget-link key ([D66]).
- **Setup:** once per device after the first account's first sync the app asks for the permission; on Android 14+ without exact alarms it says reminders can be up to an hour late and offers to allow them. The Account tab has the switches, a status line with its fix ([D95]) and a test notification.
- **Android** declares `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM` (never `USE_EXACT_ALARM`, which Play reserves for alarm, timer and calendar apps, [D76]) and `RECEIVE_BOOT_COMPLETED`; channel `reminders` at high importance; Done and the snoozes open no UI.

Limits:
- Without exact alarms (denied by default on Android 14+, or revoked) a reminder can be up to an hour late on Android 12 and later, later still in Doze or battery saver; the setup and the Account tab say so.
- While the app is closed only the background runs refill the window; a reboot restores only the pending ones.
- A second snoozed entry behind a full window is still cancelled and its snooze forgotten.
- A background Done with an expired token waits for a run that may refresh; a repeating task stays done locally until the server's answer reopens it.
- Reminders are not grouped (activity notifications are, per account), and the app brings no sounds of its own.
- A due notification snoozed to the exact time of one of the task's reminders rings twice.
- After the update from the old app ([D85]) its reminders and channels `Vikunja1` and `Vikunja2` are cleared on the first start. Android 16 had removed them at the install, as the update revokes the old app's exact-alarm permission; on older versions, untested, one may fire before that with the app's status bar icon ([D42]) and a Done that does nothing. The update leaves exact alarms off on Android 14+ (the old app declared `USE_EXACT_ALARM`); only the usual setup step handles it.

## D40: Background sync of every account; server notifications in an inbox

*Accepted 2026-10-13 (step 16).*

**Background runs** (why: Vikunja has no push channel to a phone)
- **One periodic job for all accounts** while an account exists: on Android every 30 min with a network and the battery not low ([D95]); on iOS the BGTaskScheduler task `io.vikunja.app.sync`, 30 min as the earliest begin. No foreground service, battery-optimisation exemption, exact alarm or expedited work, so no special Play declaration ([D76]). The first start after the update cancels the old app's jobs ([D85]).
- **The runner** uses session managers that refresh (why: else no session stays alive, [D22]; [D26] makes it safe), only while the answer can arrive before the container goes ([D59]). Deadlines: 9 min on Android (WorkManager stops at 10), 25 s on iOS, 2 min for a drain run. It always reports success (why: a failure adds WorkManager's backoff) and records each account's last run and outcome for the Account tab.
- **Skipped while the app is in front** (a UI heartbeat younger than 2 min), because the foreground syncs the active account, drains the others' outboxes ([D37]) and reconciles every scheduler.
- **Order:** the widgets' queued Done taps first ([D63]); then the accounts by the start of their last turn, the oldest first, so one that never gets through starves no other; a failure in one does not stop the next.
- **Queues first:** a run sends every account's queued changes before any account syncs (why: the user's own changes are worth more than fresh data when the OS ends a run early, as iOS does after 25 s).
- **Per account:** reconcile the notifications ([D39]) → incremental sync ([D33], never the daily full resync headless), which keeps the session alive ([D22]) → activity sync (not for guests, [D62]) → reconcile again → the session reminder ([D94]) → widget snapshots ([D63]). An unreachable server skips the remaining network steps.
- **Session ended:** the account is marked as needing a sign-in (data kept, outbox paused) and one "Sign in again to *host*" notification is posted per ended session, unless a restore finds the tokens working again ([D59]); it is withdrawn once the session works.
- **One sync per account across isolates:** each sync holds the account's 3-minute lease, renewed as it goes and checked before it purges or completes; a run that lost it stops without purging (why: a full run purges tasks it did not mark; [D32], [D96]). The app's engine waits for a foreign lease and adopts that state; headless engines skip, and a skipped sync counts as no background sync and reconciles nothing, while the activity fetch still runs ([D96]). A sign-out in the app releases the account in a running run. The outbox needs no lease ([D34]).
- **Drain after a background Done** whose token was rejected: on Android a one-off task with a network constraint, not expedited (why: below Android 12 that needs a foreground service the plugin lacks). iOS has no on-demand runs.

**Server notifications**
- **Activity sync** (per account, headless) pulls `GET /notifications` newest first until a known id, at most 3 pages, and sends the reads marked locally (a 403 or coded 404 counts as done). An account's first run stores everything as handled (why: a sign-in never floods the shade); the inbox still lists it.
- **Cadence:** the active account on start, resume, every 5 min in front and on pull-to-refresh; every account in every background run; the realtime socket stores pushed ones at once ([D46]). Stored per account, the newest 200 kept; reads are local-first, so badge and inbox change at once and work offline.
- **Activity notifications** for new unread `task.comment`, `task.assigned`, `task.mentioned`, `task.created`, `task.deleted`, `project.created` and `team.member.added`, while the Activity switch is on: the newest 5 of a run, the rest as one "More activity"; 10 per account kept in the tray (why: Android drops posts beyond 50 per app). Never `task.reminder` (the local ones fired on time). Ids are [D39]'s hash of `<account>:activity:<id>`. Title: the task, else the project or team; body in the web's wording with the doer (a comment's first 80 characters), unless notifications show no titles ([D64]). The active account's are not shown while the app is in front (the bell's badge shows them).
- **The inbox** (from the bell, not for guests): newest first, bold while unread, no identifier (owner, [D75]); a tap marks read and opens the task, the project or the team. A notification's tap switches account when needed, marks read and opens the task on the device at the comment (a task not on the device says so), else the inbox; silent switches need the widget-link key ([D66]).
- **Account tab:** the Activity switch; the last successful background sync (on iOS noting that the system decides), a failed attempt since, on Android a hint after a day without background runs, and the last ended session for two weeks ([D59]).

Limits:
- iOS may run the job rarely or never (never after a force-quit, not in Low Power Mode or without Background App Refresh), so its sessions can still end ([D22]); Doze and standby buckets stretch Android's runs. The app warns while Background App Refresh is off or the app restricted, and reminds the user 12 h before a session would end ([D94]).
- A run begun before the app came to the front can still be inside an account the user then removes; releasing the account in a running run at a sign-out narrows this, it does not close it. The data goes at the latest at the next start, but the account's scheduler can still plan its task reminders after the wipe ([D96]).
- On iOS an unreachable server, with changes queued, can take about 10 s of the 25 s before the first sync starts.
- Server notifications cannot be deleted in the app; Vikunja 2.6.0 and later can delete all of a user's at once (`DELETE /notifications`), not one.

## D41: Relations as task-update deltas, duplicate and follow online, indented subtasks

*Accepted 2026-10-13 (step 14).*

- **Edges ride in the task update** as deltas (the later change wins per edge), with no op kind of their own (why: one op per task keeps the rules of [D34] and [D35]). An edge is queued on the task the user edits, from its side, as on the web: a new subtask is the child's `parenttask` edge.
- **Sent with a read-before-write diff** against the task as the server has it. The server keeps the inverse edge on the other task and deletes both directions. An add answered 409 code 4008, a remove answered 404 code 4009, and a remove whose other task is gone (4002, 4040; its project 3001, 3018) once the edge is no longer listed count as done. An add whose other task is gone fails, when the task itself is there, as a missing related task (why: 4002 also means the base task is gone); so does such a remove while the edge is still listed.
- **Temporary ids at both ends:** an edge on an unsent task waits behind its create ([D35]), and a create's remap rewrites the stored relations and every queued payload.
- **Inverse rows locally:** queuing an edge also changes the inverse rows on a local other task, so a parent shows an offline subtask at once; a pulled task rewrites the inverse rows others hold to it (why: the server bumps `updated` only on the task the request named).
- **Failures:** a cycle (409 code 4023), the task itself (400 code 4010), an unknown kind (v2 422, v1 400 code 4007) and a missing related task are permanent sync problems that say why. A missing other task is forgotten like a gone label, out of every queued op and the stored rows.
- **Duplicate online only:** it drains the task's queued ops, refuses while any remain, and stores the server's copy (why: the server copies its own state, every request makes another copy, and a lost answer could not be recovered by title).
- **Following online only:** a task's or project's state is read when needed and toggled, the read-back stored for the notifications ([D80]); a subscribe answered 412 code 12002, and an unsubscribe answered 403 without a code when a read shows no subscription, count as done.
  - **Opt-outs from 2.6.0** ([D111]): unfollowing a task or subproject that a followed project covers stores an opt-out from Vikunja 2.6.0; 2.3.0 to 2.5.x refuse it with a 403 without a usable code ([D13]). Development builds and a server with `/api/v2` whose version cannot be read count as able (an older one then refuses with the usual error).
  - Without it a follow through a project is fixed: the bell stays on, and a tap sends nothing and explains that this server cannot unfollow just this one, naming the project to unfollow instead. A direct follow can be stopped on every version; on 2.3 to 2.5, with its project followed too, the read-back then shows the follow through the project.
  - The creator of a task follows it from 2.6.0 on; 2.3 to 2.5 subscribe no creator (2.4 subscribes assignees).
- **Indented quick-add lines become subtasks** by the web's rules, pinned by its test vectors; [D38]'s submit gives a child without a project its parent's and queues each child's `parenttask` edge after both creates.
- **UI** in the task detail: subtasks, the parent and relations by kind; "Add relation" starts at the user's `default_task_relation_type` (`related` when unset or unknown, [D98]) and searches local tasks. No task identifier anywhere here (owner, [D75]). The follow bell is hidden while unknown (offline) and asks before stopping just this task under an inherited follow. Relations are not edited on the edit page.

Limits:
- An update's requests are not atomic: after a permanent failure the earlier ones stay applied, and Retry sends only what is missing.
- An edge naming a task whose create was rejected waits as long as that create, holding later edits of its task; discarding that create drops the edge.
- A removed edge to a task in the trash comes back on 2.8.0 when that task is restored.
- On a server without opt-outs only the UI keeps the request back: the write port still turns the server's 403 for a covered task into a plain forbidden error.

## D42: App icon: Vikunja's logo, every variant derived by script

*Accepted 2026-10-13, the owner's decision; Vikunja's logo as the source since 2026-11-13 ([D83]), accepted 2026-11-14 (step 38a).*

- The only source is Vikunja's logo, the llama on the blue disc (`branding/source/logo.svg`, copied byte for byte from go-vikunja/vikunja's `frontend/originalMedia/images/logo.svg`; [branding/README.md](../branding/README.md) has its provenance and SHA-256, which a test checks) (owner). The old official app's icons are the look to follow (owner); they are not committed.
- `branding/build-icons.sh` derives every variant without editing the source, rendered at 4096 px and scaled down with Lanczos:
  - the llama on a solid `#196AFF`, in the old app's proportions: the adaptive layers keep head and ears inside the 66 dp safe zone, the neck running off the bottom edge (why: launcher masks would clip the ears); the iOS icon full-bleed without alpha; the iOS 18 dark icon on transparency, from which the tinted one is derived; the Android 7 legacy icon from the adaptive layers' visible 72 dp;
  - a glyph with the eyes, nose, mouth and inner ears cut out (why: Android uses only its alpha), for the themed icon and, as the head alone, the status bar and notification icon `ic_notification`;
  - the in-app logo is the round logo itself.
- The logo is used with the Vikunja project's permission; it and every file derived from it are not under the app's MIT licence, and `NOTICE.md` lists them under "Name and logo" ([D87]).
- File names and sizes stay fixed, so the launcher configuration, the iOS asset catalog, `keep.xml` and `NOTICE.md`'s globs keep matching.
- `vikunja_notification_logo`, the old app's status bar icon name, is an alias of `ic_notification`, kept from resource shrinking (why: the old app's reminders scheduled before the update look their icon up by that name, and a name that resolves to nothing would crash the notification plugin's receiver, [D85]). The old default icon `vikunja_logo` gets none: every old notification names its icon, and the app's first initialisation replaces the default.
- The store graphics come from the icons ([D76]); `branding/preview.sh` renders every variant for review.
- The theme's seed stays `#1973FF`, the Vikunja web's primary blue ([D56]).

Limits:
- The status bar icon is the head with the face cut out (the old app's was the plain silhouette with the neck); at 24 px the eyes and mouth are faint marks, and the themed icon shows the ears as thin outlines at small sizes.
- flutter_launcher_icons' scaling leaves a grid of hdpi background pixels one step off `#196AFF`, which nobody can see; the test allows one step.
- The Vikunja maintainers have yet to confirm the wording of the terms and say who holds the logo's copyright ([D87]).

## D43: Task lists from the local database, nested and ordered like the web's

*Accepted 2026-10-14 (step 9).*

- **Which tasks:** the filter engine evaluates a view's filter on the local tasks ([D51]), so changes show at once, offline too; a filter it refuses keeps the server's answer from the last download, minus tasks deleted here.
- **The web's tree as of 2.8.0, on every server** (owner, [D81]): the top level is what the server would send, the roots (matching tasks without a matching parent) and the subtasks reachable from them; a root is a top-level row only when none of its parents is in that set. Each top-level row is followed by its descendants from the local database (any project, done or not), depth first; a task expands only where it first appears below its row, and rows lie at depths 0 to 5; a subtask of two top-level rows shows under both. Indents are capped at four levels. The project widget follows the same tree.
- **Show done** (an app addition) on `done = false` views, per view, off by default: on, the done top-level tasks show in a Done part, which a view without a filter always has. Done subtasks of open parents stay nested, as on the web.
- **Order:** the lists sort themselves, by the view's sort, per view (the web's 17, "Manually" first). Manual order uses the last download's positions, tasks it lacked first (the server puts new tasks on top); the Done part goes by done-at, newest first. Dragging writes positions ([D49]).
- **View snapshots** hold the positions (why: they are per view, readable only through the view's tasks, and never bump `updated`). A list view downloads them, with the user's `filter_timezone`, when it opens with a snapshot missing or older than 5 min, and on pull-to-refresh; the sync never downloads views. A view whose filter the engine refuses shows its state (downloading, offline or failed) before its first download.
- **The Overview:** the saved filter named by `filter_id_used_on_overview`, evaluated on the device; only when the device cannot evaluate it does every sync download its open tasks, shown under a notice with the download time. Without one, every open task outside archived projects and their subprojects. Grouped by due date. It keeps to open tasks, as the web's Home asks with `done = false`, while a saved filter's own list also shows its done tasks ([D95]).
- **Upcoming**, the second tab: a web preset or custom range (default the next 7 days) in the device's zone with the server's datemath (weeks from Monday, wall clock kept across DST), a section per day. **Show overdue tasks** (on by default) pins every overdue open task in an Overdue part (why: what is late shows at a glance; the web drops the lower bound); **Show tasks without date** (off) adds a No due date part.
- **List preferences** per account, kept by a full resync: sort and show-done per view, Upcoming's range and switches, the view each project was last left in ([D45]).
- **The row** ([D56]) as on the web: priority only on open tasks from `minimum_priority` (medium when unset), up to three avatars and "+N", the due date also when done, the project for another project's task, the pending marker; no identifier (owner, [D75]). One screen-reader node, naming a subtask's parent.

Limits:
- In a view whose filter the engine refuses, or a downloaded Overview filter, tasks created here appear only with the next download.
- Upcoming uses the phone's zone, so it can differ from the web when the account's timezone setting differs.
- The tree cannot be collapsed.
- With "Show done" or in a view without a filter, a done task reached through another project can still show twice, because the open and the done part are built apart.
- Tasks more than five levels below a top-level row are not in the List view, as on the web; the detail sheet, the search, the Table and the Gantt chart reach them.

## D44: Task detail: own rich-text parser, online details, app-scheme links

*Accepted 2026-10-19 (step 10).*

- **Own parser and renderer** (why: the server stores description, comment and title HTML unsanitised, so the client is the only defence): rich text is parsed within [D58]'s budgets with the web editor's schema; only schema nodes and allowed hrefs come out, markup deeper than 96 elements becomes text, `math` and form controls drop with their text, nothing is autolinked on load, and images that are neither attachments nor absolute http(s) are dropped. It renders as native, selectable widgets, with no HTML widget package and no WebView (why: candidates applied inline styles, loaded images without the token or made `javascript:` links tappable). Editing is [D52].
- **Links:** a task link, or an http(s) address of a task under the server root or `frontend_url`, opens the task in the app; other http(s) links and `mailto`, `tel`, `sms` and the web's other schemes go through the external opener's allowlist. A long press shows the full address with its host in punycode; a tap asks first, with a warning, when the link's text begins with a web address on another host or the text or address has user info ([D97]).
- **Images:** attachment images load through an authenticated per-account cache at the `xl` preview ([D53]); responses above 25 MB and images above 40 megapixels are refused before decoding. External images load only on a tap, which opens the browser; SVG is never decoded.
- **Details online, on demand:** one `GET /tasks/{id}` when the detail opens, a quiet Retry line offline; unread is marked read at once and comments load a page at a time ([D57], [D96]). The detail is a sheet, or a pane on wide windows ([D70]), with [D75]'s header (no identifier) and [D84]'s editing; its Done offers the lists' Undo ([D34], [D95]).
- **Deep links:** `vikunja-io.vikunja.app://task/<id>` and `…://task/<IDENT-12>`, optionally `?account=`. On Android a pass-through activity owns host `task` (the sign-in callback keeps `oauth/callback`, [D23]) and hands links to the one main activity (why: no second engine), which drops a link on a Recents relaunch and on restore. Pushed routes reach the app only through [D66]'s relay, which passes on only `task` (and `widget`, [D63]). No link is logged.
- **One opener** for every task tap and link: it waits for start-up and the app lock ([D64]), the last request winning, and closes what is over the shell as if the user went back, asking when something is unsaved ([D93], [D98]). It takes the link's account, else one that has the task (the active one first), else the active one online, and asks before a link switches accounts (why: anyone can make a link). It finds the task locally, else online, following v2's 307 after a move; `.`, `..` and an all-digit identifier not local fail without a request. A trashed task offers Restore ([D79]).
  - An identifier names a local project only when exactly one matches, exact case first, else ignoring case ([D111]); one that names several, which only 2.3 allows ([D13]), goes to the server as typed.
  - 2.3 has no by-index route, so below 2.4 (an unknown version counts as new) the task comes from the project's tasks filtered by `index = n`. An empty page is not found (4002), an unknown or ambiguous identifier not found (3001), and so is the identifier of a project the user cannot read (forbidden from 2.4), while its project id stays forbidden.

Limits:
- No App or Universal Links for web addresses: self-hosted domains cannot be verified.
- On 2.3 `x-1` for another user's project `x` opens the user's own `X-1` when `X` is the only match; switching accounts still asks first. Exact case only would stop `proj-12` finding `PROJ` there, which it does on 2.4 and later.
- A web link to a comment opens its task, not the comment.
- Screen readers get a link's tap and its confirmation but not the long press; a misleading link whose text does not read like an address opens on a tap ([D97]).

## D45: App shell, colour scheme, display settings, Projects tab, smart lists, offline banner

*Accepted 2026-10-19 (step 8); the theme on the device since 2026-11-13, accepted 2026-11-14 (step 38b).*

- **Shell:** on Android and the other non-Apple platforms a navigation rail from 600 dp wide, with the four labelled destinations; iOS keeps the tab bar at every width, the iPad included ([D69]). The tab rule: re-selecting a tab pops to its root, an account switch resets the tabs, back goes to the first tab.
- **Theme** is a setting of this device: Light, Dark or System, System until another is picked, the same for every account and for guests, offline too (owner, 2026-11-13; why: the app's look is chosen on the device, independent of the web). It is the Theme row of the Account tab's Appearance section ([D75]). The app neither reads nor writes the account's `color_schema`, so the web's choice survives on the server. The start waits behind the launch screen, within its 5 s, so the first frame has the stored theme.
  - After the update from the old app ([D85]), its light or dark becomes this preference on the first start, before the first frame (owner, 2026-11-13).
- **Dynamic colour** on Android 12 and later: the system palette becomes the light and dark schemes. Off by default, so new installs show the brand scheme (owner, 2026-11-22, [D117]); the device-wide "Use system colors" switch (shown only where a palette exists) turns it on ([D56]). iOS always uses the brand scheme. After the update from the old app, its dynamic colors set the switch once: on only if they were on and could be read.
- **The web's display settings apply only once set** (why: the web's defaults `relative` and `24h` would change the app for everyone who never opened them). Until set, rows, comments and the inbox show relative dates and the rest the device's format; once set, an absolute `date_display` applies everywhere a date shows, `relative` where the app is relative, and an explicit `time_format` to every time and the time pickers, 12 hours in German included.
- **Week start** 1–6 sets the date pickers' first day; 0 keeps the locale's (why: the server cannot tell 0 from never set). Upcoming's presets stay on Monday weeks, like the server's date math.
- **Default view:** a project opens on the view it was last left in, while it has it (owner, 2026-11-18, [D95]), saved per account; else on the first view of the user's `default_view` kind, else its first view. A view named in the route wins without being saved; a guest's link lands on its view this way ([D62]).
- **Translated names** for display only: the pseudo project −1, the exact titles `Inbox` and `My Open Tasks`, and the four default view titles; storage, quick-add matching and default-project detection keep the server's titles.
- **Projects tab:** Favorites, All projects (the tree) and Saved filters ([D117]). Every project shows as a folder in its colour (owner, [D75]). "Show saved filters" ([D75]), "Show archived projects" and the collapsed branches are saved per account; wide windows show the tree beside the list ([D82]). Archived projects stay out of pickers, defaults and quick add, and their tasks are read-only ([D84], [D96]).
- **Smart lists** at negative ids: "Favorite tasks" comes from the local database; a saved filter is evaluated on the device ([D51]), else the server's answer is downloaded when its snapshot is missing or older than five minutes. A filter's list also shows the done tasks it matches unless `done = false` leaves them out, as on the web, at most the 100 most recently done ([D95]). Snapshots of gone filters are purged on every sync.
- **Offline banner** in the shell, not per list (why: no connectivity plugin can tell whether the server is reachable; the last sync can): offline after a sync run of the active account fails with a network failure, online after one gets through, unchanged while one runs, so retries do not flicker. It shows the last sync time; a tap syncs ([D96]).

Limits:
- The account's `language` and `timezone` settings are not used for display; the device's are.
- The native launch screen follows the system's dark mode, not the app's theme: with Dark picked on a light system it is light until the first frame. Following the theme would need native work, such as Android's per-app night mode.

## D46: Realtime: one WebSocket for the active account in the foreground

*Accepted 2026-10-19 (step 17).*

- **One socket, for the active account, while the app is in front:** after the account's first sync, never while it needs a new sign-in, never in a background isolate, never for a link-share guest ([D62]), only on servers with the WebSocket capability (`/api/v2/ws`, `/api/v1/ws` since 2.3.0). Inactive accounts keep their inbox poll; the background job is [D40]'s.
- **Transport** on dart:io without a new dependency, the upgrade done by hand so a refused one reports its status and `Retry-After`; it gives up after 15 s and pings every 25 s. Nothing logs frames or tokens. The server address's connection settings apply to every upgrade ([D65]); where they do not reach, realtime falls back to polling.
- **Protocol:** `auth` with the current token, `auth.success` within 10 s, `subscribe notification.created`, and an inbox catch-up alongside (why: events while disconnected are lost). A changed token re-authenticates; a re-auth without `auth.success` within 10 s reconnects (this also covers servers older than 2.7.0).
- **Events:** only `notification.created` (the server pushes no task or project changes and no reads). It is stored like a polled one, so the inbox and badge update by themselves; a reminder is stored but never shown or counted. Notifications about tasks and projects request one debounced incremental sync of the active account ([D97]). The 60 s sync timer ([D99]) and the inbox poll stay.
- **Failures fall back to polling, quietly** (why: the upgrade shares the server's per-IP limit of login and registration, 10 a minute): temporary failures (drops, 1013, 5xx, connection errors) reconnect with backoff from 2 s to 60 s with jitter, and six attempts in a row without `auth.success` stop until the next resume; a 429 waits its `Retry-After`, at most 5 minutes. A rejected token goes through the session manager's refresh, and a revoked session ends as for HTTP. A refused upgrade (404, 426, 3xx) or a TLS error before any socket of the account was live stops attempts until the app starts again or the account changes. Offline, nothing is tried; the offline banner stays bound to sync runs.

Limits:
- No sockets for inactive accounts or in the background, no switch to turn realtime off; 2.8.0's time-tracking events (`timer.*`) wait for step 34, and the server's reminders are not shown.
- dart:io reads no system proxy and on Android ignores user-installed CAs: a server reachable only that way keeps working through polling (trusting its CA in the app fixes the second, [D65]). On Android a server without TLS settings of its own gets the user CAs and the system proxy the platform reports ([D100]).

## D47: Kanban board from per-view snapshots, moves through the outbox

*Accepted 2026-10-19 (step 20).*

- **Kanban views** are tabs beside a project's other views; `default_view = kanban` opens the board ([D45]). The board replaces the list body, without sort or "Show done"; columns snap on a phone and show several where there is room ([D69]), each header with `count/limit`, in the error colour when full.
- **Card** like the web's, without done control or star, with no task identifier (owner, [D75]); one screen-reader node like the row's, and the card open in the pane is marked ([D70]).
- **Drag and drop** after a long press. The position comes from the cards above and below as shown (the web's `calculateItemPosition`), except that an empty column gets 65536 (why: 0 makes the server recalculate the whole view). A full column refuses a card from elsewhere. Screen readers get Move to each other column, Move up and Move down; Move to column… in the detail follows the same rules ([D84]). Filter-mode boards, archived projects and projects without write permission ([D60]) are read-only.
- **Board snapshots** per view, replaced in one transaction by a download that keeps the pages a bucket had loaded. The screen downloads when the board opens with a snapshot missing or older than five minutes, on pull and on coming back online. The sync never downloads boards (why: a request per view and run for data that matters only while the board is open); it purges those of views that no longer exist.
- **The board model** joins the snapshot with the local tasks: a queued placement wins; a task marked done after the download moves into the done bucket and an open one changed after it leaves it, while tasks done before a done bucket was chosen stay where the server keeps them; tasks created here, changed after the download or moved into the project show on top of the default bucket; the device's filters apply ([D51]), and a filter-mode board shows its download as it is.
- **Moves through the outbox** as a field of the task update, per view a bucket and a position (why: it rides the outbox's queueing, failures and sync problems). A later project move or done change drops the placements queued before it, so the server never gets a move for the wrong project or done state. A drop into the done bucket marks the task done, one out of it open; a repeating task dropped into Done is only marked done and goes to the default bucket. The move is written before the position (why: neither bumps `updated`, and a move keeps the old position). 10004 (bucket full), a missing bucket, 3008 (archived) and 403 become sync problems; discarding one puts the card back.
- **Add a task per column:** new tasks go on top of that column as far as its limit leaves room, created done in the done column, placed by a queued placement rather than `bucket_id` on the create (why: that applies to one view only and would change the create's recovery match, [D35]).

Limits:
- Not built: collapsing columns, kanban views of saved filters, cover images, attachment icons on cards.
- In filter mode a task the server lists in two buckets shows once.
- Moving a card within its column takes a drag or a screen reader's actions; there is no single-pointer way ([D68]). To another column, Move to column… is one ([D84]).

## D48: Kanban columns managed online from a column menu

*Accepted 2026-10-19 (step 21).*

- **Online, applied at once:** column changes call the server and queue nothing (why: they need server ids, change where queued moves land, and are rare). A success goes into the local board, then the board downloads quietly; offline or on a refusal nothing changes and a message says why.
- **Requests:** the bucket update always sends title, limit and position (why: the server's update replaces all three, and what is left out becomes 0). Done and default bucket are set by a merge-patch of the view on v2, and on v1 by writing the view back whole with only the bucket ids changed, so kind, filter, title and position survive.
- **The column menu** in each header holds the column's settings, moves and Delete, which asks first, naming where the tasks go; a tile at the end of the board creates a column. Titles must not be empty (stricter than the server), a limit below the count is allowed, and the last column cannot be deleted. The server's limit (100 manual columns, 412 code 10007) is said in the app's words.
  - The menu and the tile need write permission, done and default column admin ([D60]); filter-mode boards and archived projects show none of it.
  - Below admin, Delete is disabled for the leftmost column while no other column is the default and it holds tasks (why: that delete needs a new default first, which the server refuses below admin). The web offers it and the server accepts it, leaving the tasks in no column; the app offers a write member less than the web here ([D62]).
  - A link-share guest gets what a user of the share's permission gets, as the web offers it and the server accepts it ([D62]): a write guest deletes the done and default column too, which the server clears in the view, and an admin guest also chooses them.
- **Reordering** by Move left and Move right, in the menu and as screen-reader actions; columns are not dragged (why: on a phone that competes with dragging cards and with the snapping board).
- **Guard against orphaned tasks** (why: on the server, deleting the bucket that tasks fall back to leaves its tasks in no bucket): when the column to delete is the fallback and holds tasks, the app first makes the leftmost remaining column the default, then deletes, and puts the old default back when the delete fails; nothing is deleted when setting the default is refused or the server no longer has that column (it then stores no default), and the old default is put back.
  - **Before 2.5** ([D111], [D13]): 2.3.x and 2.4.x store a done or default column the server no longer has as sent, not as none. On these servers, and on unknown versions (a development build counts as new), the app reads the board after setting a new default and deletes only when that column is in it; a set default that is gone counts as none.
  - On the same servers a done or default column chosen after another device deleted it is checked too (why: it is kept as the deleted id, and tasks marked done or created then vanish from the board); when missing, none is sent and stored, as 2.5 and later do by themselves (owner, 2026-11-20: clearing, as built; the alternative was refusing with "the column no longer exists"). Each check costs a board read there; from 2.5 the requests are unchanged.

Limits:
- Not built: managing columns offline; collapsing columns is [D47]'s.
- Moves still queued into a deleted column fail as a sync problem.
- Before 2.5, with the default a column deleted elsewhere, the board does not know it is gone: the delete dialog does not say the leftmost column becomes the default.
- Below admin, Delete can be enabled when only the server's board needs a new default (a default cleared elsewhere, tasks not yet on the device), or with a default deleted elsewhere before 2.5; the server then refuses, nothing is deleted, and the message says the tasks have to go to another column first.

## D49: Manual ordering: lists through the outbox, projects online, no position below 0.1

*Accepted 2026-10-20 (step 22).*

- **Which lists can be reordered:** a list view sorted "Manually" that has been downloaded once, in a project that is not archived (itself or above) and that the user may write ([D60]), not a smart list; only the top-level rows of the open part, each with its nested subtasks as one block. The Done part, subtasks on their own and the leaving copies of just-completed tasks stay put.
- **List drag** as on the board: a long press lifts the row, a line shows where it lands, the list scrolls near its ends, and the position comes from the rows above and below as shown. Tasks without a downloaded position get made-up positions, which a move among them writes too, so the server gets the order shown. Screen readers get "Move up" and "Move down" where the order changes.
- **Positions through the outbox** as their own field of the task update, per view (why: positions do not bump `updated`, and a field of its own avoids the kanban placement's column and done rules): merged per view, dropped by a later project move, kept by a done change, folded behind an unsent create, overlaid on the manual order until sent, written after the body and the column moves. The view downloads quietly 2 s after they left the outbox. Discarding a refusal puts the row back.
- **Projects** are reordered and nested in "All projects" (Favorites and Saved filters stay as they are), online: a v2 merge-patch of position and parent, on v1 the project read and written back whole with only those changed; a quiet sync follows.
  - A long press lifts a project with its subtree; a drop between rows makes it a sibling at the level the line's indent shows, a drop onto a row that project's last child; it shows faded in its new place until the server answers.
  - It follows the stored permission ([D60], [D96]): a project the user may only read is not lifted, offers no screen-reader moves and takes no other project; without admin a project moves only among its siblings, else a haptic and a message, without a request. A move shown before the answer keeps the project's stored permission.
  - Refused without a request: onto itself or its subtree, into or out of an archived project, and any place whose position would fall below 0.1 (why: below 0.1 the server renumbers every sibling, for top-level projects those of every user on the instance; the API port refuses it too).
  - Screen readers get "Move up", "Move down", "Move out of <parent>" and "Move into <project>".
  - A shared project whose parent the user cannot see keeps that parent when reordered.
  - Failures say why in their own words.

Limits:
- Not built: ordering favourites, dragging in smart lists; Table and Gantt views have no manual order. Saved filters have no order on the server to set.
- On Vikunja 2.8.0 a move under a new parent needs admin on that parent too, while the app checks write there; that refusal shows as a message.
- Moving a task or project takes a drag or a screen reader's actions; there is no single-pointer way ([D68]).

## D50: Projects and views managed online, applied locally at once

*Accepted 2026-10-20 (step 23).*

- **Online, applied at once:** every action calls the server; on success the local database changes at once (the archive flag down the subtree; a deleted subtree purged with its tasks, their queued changes, snapshots, columns and list preferences), and a sync follows that never joins one already running, so a run in flight cannot undo the write ([D97]). Offline and on a refusal a message shows and nothing changes locally (why: temporary project ids would have to flow into tasks, views, columns and the outbox; deletes and duplicates need the server's answer).
- **Entry points:** "New project" in the Projects tab; the project menu, as far as the stored permission allows ([D60]) and nothing for link-share guests. The user's default project cannot be archived (disabled, with the reason) or deleted (hidden); an archived project offers Unarchive and Follow, and Unarchive under an archived parent is disabled with the reason.
- **Forms:** a new project opens once created; titles trimmed and required; limits count code points as the server does; the identifier has at most 10 characters; the parent lies outside the project's own subtree; the description goes through the editor ([D52]); colours are [D81]'s. Duplicate takes a parent the user may write and "Also copy its shares", on as on the web; the copy opens after a sync brought its tasks.
- **Confirmations:** archive and unarchive with the web's meaning, naming the user's default project when it is inside. Delete counts every task it would delete, in subprojects too (why: the web's count of direct children understates a recursive delete), and says it is for everyone; with the trash it moves the project there, with Undo ([D79]).
- **Views page:** create, edit, reorder and delete views (never the last, so the project always has something to show). "Show done tasks" for lists maps to the web's `done = false`; the filter is in the web's syntax with the filter builder ([D51]), the server's error shown and announced; a board's columns are its own or come from filters. A move sends only the position, so a view changed on the web meanwhile is not overwritten.
- **Local consequences the server leaves out:** an identifier change rewrites the stored task identifiers (why: the server changes them without bumping the tasks' `updated`); an unarchived subtree and a copy whose sync failed are pulled whole on the next run; a stored project below position 0.1 is lifted to at least 0.1 in the same update, so the server does not renumber its siblings.
- Failures say why in their own words.

Limits:
- Not built: backgrounds, webhooks, setting up filter-mode columns (left to the web), managing projects offline.
- Over v1 only, a view with more than 50 filter buckets from before 2.7.1 is refused when the app edits it.

## D51: Filter engine on the device, saved filters, filter builder, offline search

*Accepted 2026-10-20 (step 24).*

- **One engine in `vikunja_logic`** implements the server's filter grammar and semantics exactly (the server's fexpr reader translated, BSD 3-Clause; the date math after go-datemath, ISC; notices in `packages/vikunja_logic/THIRD_PARTY_NOTICES.md`). Deliberate differences: a date equal to a bound matches as written (on SQLite the server is off by one there); filters the server answers with a 500 (`position`, range comparisons on people, business-day rounding) are refused with 4019. Business-day offsets above 10000 in all are refused with 4019 on every server version ([D78]).
- **Timezone:** the user's timezone setting, else the device's zone; the server never stores a saved filter's own (`filter_timezone` is a request parameter only).
- **Where it applies:** list views, boards, saved filters, the Overview's saved filter and the widgets, each with the server's scope (a project view covers its project, archived tasks included; all tasks and saved filters cover the projects that are not archived plus the user's favourite tasks). Filters that use `now` are evaluated again every minute and on resume.
  - A filter the engine refuses, one naming `bucket_id`, or a saved filter whose definition is unknown falls back to the server's list, stored as a snapshot, with its notice. A saved filter's list takes its done matches too unless it says `done = false` ([D95]).
  - The sync reads the definitions of new or changed saved filters only (by `updated`).
- **Saved filter management** online, applied at once, from the Projects tab ([D75]); descriptions through the description editor ([D52], [D96]).
- **The filter builder:** a text field in the web's syntax (why: it keeps every filter the web can write), with suggestions for fields, operators and values. Value suggestions ignore case and accents on every server (owner, [D81]) and insert the exact title or username. Label and project titles are sent as ids ([D93]); a label created on the device is not suggested until its create is answered, and a temporary id is never kept ([D109]). The engine's error blocks saving.
- **Global search** (the Overview's search pill, [D56], and a search action in Upcoming and Projects): tasks, projects, saved filters and labels, open tasks first, offline and instant from a local index. Tasks match a substring of title or description, ignoring case (full Unicode folding) and accents (owner); `#12` and `PROJ-12` (an app addition) find a task by index or identifier. Every other search field that filters on the device ignores accents too ([D81]).

Limits:
- Not built: the server's ParadeDB full-text search, `uid` filters, a chip-based builder, searching comments and attachments, teams in search.
- Text in a filter and the search compare as SQLite does (`like` ignores ASCII case only, `=` and `<` compare bytes). The server leaves this to its database, which no answer names (on PostgreSQL `like` heeds case and the search ignores case beyond ASCII, `ILIKE` with `unaccent` where installed; on MySQL or MariaDB a `_ci` collation ignores case, often accents too), so there a text filter's matches can differ from the web's; documented rather than matched to one database ([D96]).

## D52: Descriptions edited in a locked-down TipTap WebView, never silently overwritten

*Accepted 2026-10-20 (step 25).*

- **Our own bundle, the web's output:** `app/editor/` builds one self-contained page from the TipTap and ProseMirror npm packages at the web's versions, with our own configuration of the web's extensions (why: the web frontend's code is AGPL, which the MIT-licensed app cannot take in). The recorded web outputs come out byte for byte; `tool/build_editor.sh --check` rebuilds the page and fails on any difference, and CI runs it. Everything bundled is MIT (`app/assets/editor/NOTICES.md`). Left out: code highlighting, slash commands, Markdown and image paste, floating popups (the web's popups and highlighting do not affect the stored HTML).
- **Locked down:** the page loads from the app's assets; a content security policy allows only its own hashed script and inline styles and no network at all (images are never loaded, so no token reaches the page; attachment previews arrive as `data:` URLs, [D101]); every navigation is refused; messages carry a per-load token both ways; file access and debugging are off. A page that was not changed is never written back.
- **The editor page:** full screen, from the detail and the edit pages, not for archived or read-only projects, with a native toolbar and link sheet (a scheme the editor would drop is refused, [D95]); `@` lists the project's people; images are [D53]'s. Save is explicit (why: it fits the app's edit pages and avoids writes while typing offline); leaving with changes asks, also before an account switch ([D91]).
  - A page that is not ready within 20 s, or reports a failure before it is, shows "The editor could not be opened." with Retry; a page that becomes ready after that replaces the notice with the working editor (owner, 2026-11-20, [D110]).
  - An unsaved edit is kept as a draft per account and description (the 20 most recent, in the accounts folder out of iOS backups, [D97]) and offered again; sign-out and account removal discard that account's drafts, and an editor still open after its account signed out keeps none ([D91]).
  - Comments ([D57]), label and team descriptions ([D60]) and saved filter descriptions ([D51]) use the same page.
- **Checklists ticked in place** in the detail: a tap changes only that item's checked state, queued through the outbox, so it works offline.
- **No silent overwrite** (why: a tick on the phone must not erase a paragraph written on the web): a queued description change remembers the description it started from and is checked against the server's current one before it is sent. Unchanged: sent. Changed, with only ticks queued: the ticks are applied again to the server's. Changed after an edit: a sync problem with Compare versions, Keep my version and Use the web version. When the description changed underneath while editing, Save asks: Overwrite, Reload or Keep editing. Project descriptions are saved online with the same check and question.

Limits:
- On v2 a web change landing between the check read and the write is still overwritten; the server offers no preconditions.
- Checklists in comments cannot be ticked.
- Not built: image paste and drop, Markdown paste, slash commands, code highlighting, collaborative editing.

## D53: Attachments uploaded through the outbox, opened through the platform; Android share target

*Accepted 2026-10-20 (step 26).*

- **Uploads through the outbox, in their own lane,** offline too: each file is checked against the smaller of the server's `max_file_size` and the app's ceiling of 50 MiB and copied into the account's uploads folder under a random name.
  - A second sender lane sends uploads beside the main queue (why: a large file would hold every edit back for minutes), one file per request (why: per-file errors carry no name and the body limit counts all files), with timeouts from one to four minutes by size. While it waits only for uploads another isolate is sending, none backing off, it names no failure, as the queue does (owner, 2026-11-20, [D110]).
  - A lost answer is matched by name, size and uploader ([D94]). Uploads give up after three timeouts or four other failures in a row, sooner than the queue's ops (why: each attempt sends the whole file again over mobile data), as sync problems whose Discard deletes the stored copy. Background runs leave uploads alone.
- **Photo and video locations are removed** before they are queued (owner): every photo and video from the photo picker and the camera (attachments, the editor's image button, the avatar) on iOS and Android, and on Android every copy of a file shared to the app ([D74], [D76], [D97]).
  - Pictures picked as files (an `image/*` type other than SVG, also in the editor's image menu) lose their location too (owner, 2026-11-18); other files, videos picked as files among them, stay unchanged.
  - A file whose location cannot be removed is uploaded only when the user chooses Upload in "Upload with location?"; Skip, and a question dismissed or one that could no longer be asked, leave it out and delete its copy (owner, 2026-11-18). A shared file gets the same question.
- **Per attachment:** Open (other files downloaded into the cache and handed to another app through a FileProvider), Share, Save to device, cover and Delete, the last two online; an update answered with 4020 (a dangling cover) is sent again once with the cover cleared. Downloads carry the Bearer header for the account's own server only, take a sanitised name, and are purged per account and after three days.
  - Previews go over v1's `preview_size` wherever the server offers v1, on a v2-only connection over v2's preview route from 2.7.1 on; a file without one (422 code 4038) keeps its icon. Description images are uploaded at once and inserted in the web's form ([D52]).
- **Share to Vikunja on Android:** an own pass-through activity (why: the share plugins use names the sending app chooses and read `file://` paths) forwards text and files to the app's one activity, which takes a share once (never again from Recents or after a restore). Only another app's `content://` files are read (no `file://`, not the app's own), copied under random names with the size cap; a file whose provider cannot be looked up is refused (why: the failed lookup cannot rule out a provider of the app's own, [D111]). It asks for the account when there are several and offers New task or Add to task, offline too, and "Open as guest" first for a share link ([D62]). iOS has no share extension before 1.0 ([D74]).
- **Picks survive an activity relaunch,** and a pick never receives an earlier pick's copies ([D96]).
- **Gating:** no uploads, deletes or covers in archived or read-only projects ([D60]) or when the server has attachments off; downloads always. Delete and the cover are off while offline ([D109]).

Limits:
- Attachment lists are not synced (why: an upload does not bump the task's `updated`); the details read online stay the source, and the last list read shows offline.
- Files up to 50 MiB are held in memory while they upload (the native HTTP adapter buffers bodies), so there is no real progress bar.
- Not built: attachments on comments, HEIC conversion, recovering a photo when Android kills the app while the camera is open.
- image_picker_android drops a lost result that holds only an error, so a pick failing after a relaunch, or a copy taking longer than 15 s, ends like a cancel; such a late copy stays in image_picker's cache folder, and a later pick receives it only when it lands during that pick's relaunch ([D96]); a process that dies during a pick loses it.

## D54: Account settings in the app; password and email on the web

*Accepted 2026-10-21 (step 30).*

- **The Account tab** opens with a profile header (own avatar, name, @username, server) and an "Account settings" row; the order of its sections is [D75]'s.
- **The Account settings page**, in the web's order: Profile (name, avatar); Password and email; Defaults (default project, default view, Quick Add Magic mode, minimum priority, the Overview's saved filter, first day of the week); Time and language (timezone, with the zones of the device's offset suggested; the server language, for emails and the web only; date and time formats); Email notifications (reminders, the daily overdue summary and its time); Privacy (findable by name or email). The web's colour scheme is not shown: the theme is a setting of the device, and `color_schema` stays on the server as the web set it ([D45]). Security and integrations are [D55].
  - Changes save at once, online, one at a time; offline the page is read-only; refusals show at their field. Back with an unsaved name asks first, also while another setting is being saved; only while the name itself is being saved does Back leave without asking ([D96]).
  - A return to the app reads the page again only when its last answered read (of the settings, or of every security part) began 5 min ago or more or never happened, after one of the web's pages was opened from it, or while an email change waits for its confirmation; opening the page and Retry always read ([D95]).
- **Writes that never wipe** (why: v1 `POST` and v2 `PUT` replace everything, and an omitted `frontend_settings` wipes every web setting):
  - on 2.7.0 and later a v2 merge-patch carries only the changed fields (web keys inside `frontend_settings`);
  - older servers get a full write built from a fresh read of the raw settings, keeping every key the app does not know, never from the local store, which keeps only what the app uses;
  - after each write the app reads `GET /user` again, stores settings and profile and syncs quietly; a new name shows at once in the header, the switcher and initials avatars, also when another isolate's sync saw it first.
- **Avatar page:** Default, Initials, Gravatar, Marble and "Your photo" (picked or taken, uploaded, which also selects it); the account's avatars are fetched again; a note says that the app draws initials where the server sends an SVG.
- **Password and email through the web** (why: the app never handles passwords, [D14]): for local users the two rows open the web's own pages in the browser; OIDC and LDAP users see that their provider manages them, and the rows stay hidden until the profile is known. A pending email change is shown.
  - Returning from the password page, the app checks its session at once; a changed password has ended it, and "Sign in again" takes over with queued changes kept.
  - On Vikunja 2.8.0 and later a note under the two rows carries [D81]'s lockout hint.

Limits:
- The web's frontend keys the app has no use for are kept but not shown; `default_due_time` and `default_task_relation_type` are applied ([D35], [D41], [D98]) but set only on the web.
- The account's language setting changes only the server's emails and the web, never the app's language ([D71]).

## D55: Security settings: two-factor status, sessions and tokens; a new token shown once

*Accepted 2026-10-21 (step 31).*

- **Everything that needs a password or code goes to the web's own page** in the browser (why: the app never handles passwords or TOTP codes, [D14]): two-factor setup and turning it off, export request and download, deletion request and cancel. No password or code field, no QR code, never the two-factor secret. Everything else is native and online only. The two-factor note says that turning it on signs out everywhere, this app included, and turning it off needs the password, on newer servers also a code.
- **Delete account** comes last, on every server (why: Apple Guideline 5.1.1(v) and Play ask an app through which accounts are created to offer their deletion, [D76]): a dialog with the consequences, the mail confirmation and the three days, then the web. Where the server does not allow it, a tap explains that whoever runs the server can delete the account (the glossary's term, not "administrator"). A scheduled deletion shows with "Cancel deletion". On 2.8.0 and later the deletion, export and two-factor notes carry [D81]'s lockout hint.
- **Sessions page:** a device line from the User-Agent (this app's `Vikunja-App/…` as "Vikunja app"), IP, last active, and "This device", which cannot be ended there. Ending sessions asks first; ending all others goes one by one (the server has no "end all others" call).
- **API tokens page:** an expiry of 30, 60 or 90 days or a picked day (no "never expires"), permissions from `/routes` with the web's four presets; a token already gone (404 code 14017) counts as deleted. Task management takes `projects.views_buckets_tasks_update` where `/routes` offers it, else its name before 2.7.1, `views_buckets_tasks`. On 2.8.0 Task management and Project management include the trash's permissions with their whole `tasks` or `projects` group (Delete forever, Empty trash and the project count among them), Full access everything and Read only none of them, as on the web (owner, [D81]).
- **CalDAV page:** the address from the server root (not the web address) and the username. On 2.8.0 and later it recommends a CalDAV token over the account password and says to remove a deleted token from the calendar apps first (why: every try with a wrong password or deleted token counts towards the lockout, [D81]).
- **A new token is shown once:** only in the state of the page that created it (never in a provider that outlives it, the database, the registry, logs or a route), with Copy through the sensitive clipboard ([D66]), and one question when leaving without copying.
  - While it shows, Android blocks screenshots (`FLAG_SECURE`, [D64]); iOS hides it while the screen is recorded or mirrored (owner, [D74]).
  - Log redaction also covers a `secret` key and `otpauth` links.
- **Two-factor status over http** is not read from servers before 2.7 (why: the answer carries the secret).
- **Returning from the web's two-factor page** runs the session check at once, so a session ended by turning it on asks to sign in again right away; a deleted account (`GET /user` 404 code 1005) ends the session the same way.
- **Waiting for a page the app opened** uses the pushed route's own pop (why: go_router's push futures never complete once it decodes its route list again, [D66]).
- Sessions and tokens are read whole by [D27]'s rule ([D96]). **The latest read wins** on the sessions, API tokens, CalDAV and data export pages (owner, 2026-11-20, [D110]): the list read after a change shows, and a session or token removed here cannot come back with an older answer.

Limits:
- Not built: bot users' tokens, the web's prefilled token links, webhooks, feeds and migration.
- Without mail on the server the deletion's confirmation never arrives, which the app cannot detect.

## D56: Design after the owner's mockups: blue scheme, cards, one task row

*Accepted 2026-10-21 (outside the roadmap's steps; the owner's mockups).*

- The app looks like the owner's mockups of eight screens without copying them blindly, and stays a typical Flutter app with material_ui and cupertino_ui ([D2]).
- **Colour:** the brand scheme (when the system palette is off or missing, and on iOS) is a tonal scheme with primary roles from the Vikunja blue `#1973FF`, cool grey-blue surfaces and an amber tertiary for highlights (favourite stars, high priority). Dynamic colour ([D45]) is an opt-in (owner, 2026-11-22) and then replaces the whole scheme; every component reads scheme roles, except the orange of Urgent and Do now ([D117]). High-contrast variants follow the platform ([D68]).
- **Surfaces and structure:** grouped content in 12 dp cards with inset dividers; primary-coloured section headers with an optional count; settings tiles with a 24 dp outlined leading icon; switches with a check in the thumb (Material only); segmented buttons for short exclusive choices.
- **One task row for every list** (Overview, Upcoming, project lists, the Table view, smart lists, search, labels): a square checkbox, the title after the task's colour dot, one wrapping meta line (priority flag; due date in the overdue, today or later tone, with an error icon when overdue; the project after a folder in its colour; label pills in the server's colours; checklist count; comment count with the unread dot; description and repeat icons; the not-yet-synced mark), the percent-done bar, an avatar stack and the favourite star. No task identifier (owner, [D75]).
- **Shared widgets** (`SectionCard`, `TaskRow` and the others): every list and settings page uses them, and new screens do too.
- **Screens:** the Overview starts with a search pill and a greeting with the tasks left for today; Upcoming has range presets, a day strip and a timeline of days; a project shows its progress, its views as tabs and "Show done" and the sort as chips; Kanban columns are cards with a count badge (red over the limit); the task detail has the project chip, a large title, a "Mark as done" button and an attribute card, as a sheet, and a pane beside the list on wide windows (owner, [D70]); the new-task sheet has a headline with the pin "Keep open after adding" ([D95]), a project field, due date and priority as chips, and expands for more options ([D75]); the Account tab has one Appearance section and ends with "Sign out" and the version.
- **Not copied from the mockups:** a Teams tab (Account stays the fourth tab), an inline Quick Add field and a project grid on the Overview (the button and the composer stay the way to add), a checkbox on Kanban cards (the done bucket keeps its rules), the task detail as a full page, the task identifier (row, card, header), a project's colour dot (every project has a folder in its colour), and the new-task sheet's row of reminder, repeat and attachment buttons (reminders and repeat are under More options) (owner for the last three). Kept although the mockups have none: the favourite star on rows.
- The labels of Android's navigation bar scale text up to 1.15× (why: the bold selected label must fit in German at 200 % text; a deviation listed in [D68]).
- `tool/seed_demo_data.py` fills an emptied test server with the demo projects and tasks.

## D57: Comments online with a kept draft; reactions; comment counts and unread dot

*Accepted 2026-10-21 (step 27).*

- **Online writes, a draft kept offline:** comments and reactions are written online and applied to the open sheet at once, then a quiet refresh (why: the server orders the thread and gives a comment its id, and a kept draft loses nothing). The sheet keeps the thread it last read and shows it offline ([D109]).
  - A new comment goes where the server's order puts it: first when newest first, last when oldest first; oldest first, the pages not loaded yet are read to the end in one load, so the comment shows and the sheet scrolls to it ([D95]).
  - The composer's text, its mentions and the reply it quotes are kept per account and task on the device (the 50 newest per account, deleted on sign-out), in files that backups leave out ([D66], [D97]). Offline the Send button is off with a note. A draft moves with its task between pane and sheet ([D70]).
- **A composer pinned under the task sheet** with @-mention suggestions from the project's people (for link-share guests only people already on the device, as the server refuses them a user search), sending the web's HTML byte for byte: escaped paragraphs, mention nodes, and the reply quote rebuilt from what the editor schema keeps (why: a quoted comment's hostile markup is not re-posted). The comments section is always there where the server offers comments; read-only and archived tasks get no composer.
- **Each comment:** avatar, name, time, "edited", its reactions and a menu with Reply, Copy link (the web's `…/tasks/{id}#comment-{id}`: [D84]'s task link with the comment added) and, for one's own comments, Edit (the full editor page with mentions, [D52]) and Delete (asked first; the paging adjusts so "Load more" skips nothing). The comment editor's route keeps the comment it was pushed with (why: go_router drops a non-JSON `extra` when it decodes its route list again, [D66]).
- **Reactions** on the task and on each comment: chips toggle one's own reaction, a long press says who reacted, "Add reaction" offers eight quick emoji and a field for any other. Read-only users see the chips disabled; link-share guests get no reactions ([D62]). Reactions are not synced (why: they never bump `updated`).
- **Counts and unread on rows:** stored tasks carry the comment count and the unread flag; rows and board cards show the count, in primary with a dot when unread. Opening a task marks it read and clears the dot once the server took the mark, so a mark that fails, offline for example, leaves the dot and the next opening tries again ([D96]).
- **Live and linked:** an open sheet reads its details and loaded comments again when the task changes on the server; notifications and inbox entries about a comment open the task at that comment.

Limits:
- A task read on the web or on another device keeps its unread dot here until the task changes or the daily full resync.
- Not built: a formatting toolbar in the composer, images in comments, comment search.

## D58: Server HTML parsed within work budgets; a document past one is cut

*Accepted 2026-10-21 (a hardening task after step 27).*

- Descriptions and comments are parsed by `parseBoundedHtml` (`vikunja_logic`) on the UI isolate and in headless isolates (why: the server stores their HTML unchanged, hostile markup included, and package:html has paths whose time grows with the square of the input, tens of seconds for under 1 MB).
- It parses with package:html itself, through subclasses of its tokenizer and tree builder (implementation imports, as the package offers no hooks), and counts the real parser's work against budgets:
  - the entries walked in the stack of open elements (once per token) and in the list of active formatting elements (per formatting element, times its attributes, and per round of the adoption agency): 2^24;
  - the elements created, reopened and cloned ones included: 2^18;
  - the characters of their attributes, copies included: 2^24;
  - the sibling positions searched to move nodes, for foster parenting and for the children the adoption agency moves: 2^28;
  - at most 1,024 elements open at once, for package:html's recursive serialiser.
- The parse stops between tokens, before an element is inserted or before a round of the adoption agency, never while a node is out of the tree.
  - Rich text shows what was parsed until there, then a paragraph `…`, and the document is marked truncated; checklist items before the cut still tick.
  - A reply quotes such a comment up to the cut, then `…`, and its preview ends with ` …`.
- Below the budgets the result is package:html's own. The converter still flattens what is nested deeper than 96 elements to its text.
- A numeric character reference past 64 bits reads as U+FFFD, as package:html reads one past U+10FFFF (why: package:html throws on it, so 26 bytes would break the task sheet).
- Linear passes: the converter removes blank text nodes, moves lists nested in a list and joins adjacent text each in one pass; the composer trims the end of a web address in one pass.
- The outbox's checklist rebase parses the description once for all queued taps and applies them from the last item to the first; when an item's change could reach the next item (only malformed HTML allows it), it parses again after each tap.

Limits:
- A document past a budget shows only its beginning in the app; the rest stays on the server and in the web, and its checklist items cannot be ticked in the app.
- An update of package:html can break the subclasses at compile time; the tests pin its output below the budgets. `packages/vikunja_logic/pubspec.yaml` holds it at exactly 0.15.7, so an upgrade is an edit of its own that reads the overridden internals again against the budgets ([D110]).

## D59: Sessions kept through lost refresh answers and storage errors; a record of why one ended

*Accepted 2026-11-20 (step 40y).*

**Context:** the owner got "Sign in again" although the Account tab showed a successful background sync 12 h earlier. Every background run renews the tokens (its first request finds the 600 s access token expired, [D22]), and Vikunja rotates the refresh token on every refresh, keeps no grace period and commits before it answers ([D26]). No single cause was found, as the app kept nothing about why a session ended, but these ways to lose a live one: a lost refresh answer (a dropped connection, a proxy's 502 after the commit, a worker the OS stops; the next refresh gets 16002), secure storage resetting itself, false ends (a race lost to a sibling isolate: 16004, or a 500 then 16002 on SQLite servers; a missing registry connection; a proxy's bare 401) and background runs cut short. Deletions on the server (a password or two-factor change, sessions ended elsewhere) and a shortened `service.jwtttl` end sessions too. An earlier build of it stays parked as a local stash, which is never pushed ([D87]).

**Storage** ([D24], [D25]):
- Android uses `resetOnError: false`: a value the plugin cannot decrypt is an error, not deleted data (why: the reset would wipe every account's tokens after a passing Keystore failure in a background engine).
- A failed token read is a transient `NetworkFailure` (its cause only the error's type): tokens, and a guest's link, are kept and tried again. Only reads that keep failing at app starts for 24 h with no good read between ask for a new sign-in (a key lost for good). This check and the install purge run in the app's start only (why: a background, notification or widget engine's first Keystore read is where a passing failure shows).
- **Sign-in writes** (the previous app's session too, [D85]) are retried, the third time with the plugin's default Android options, whose reset wipes data and keys only when the plugin cannot unwrap its key while it starts, which repairs a key lost for good; the plugin keeps its first start's options, so the write recovers only where the plugin has not started yet (the case a lost key causes) and is a plain retry elsewhere and on iOS. No other write asks for a reset. If the writes keep failing, the new session is logged out and nothing registered.
- On Android every token write waits until the plugin's file is on disk (why: the plugin writes with `apply()`), through `plugins/vikunja_storage_flush`; a failed flush is logged and the write counts as done.

**Refreshes** ([D26]):
- After 16002 or 16004 storage is re-read for about 16 s, going on from the refresh token last refused, also one a session-end answer (16003, 412) moved the refresh on to, so the re-reads never send that refused token again (owner, 2026-11-20, [D110]).
- Only a refusal without any sign of a race ends the session. After a race (16004, or a 16002 answering the retry after a 5xx) the call fails as deferred and a later one adopts the winner's tokens; a token refused longer than that window ago ends the session (why: no winner ever stored anything).
- **The refresh gate:** a retry after a server error is not sent once too little time is left for its answer or the OS stopped the run, and the call fails as deferred (why: its receive timeout would be what is left, possibly negative, and Dio's `dart:io` adapter bounds nothing with a timeout that is not positive).
- A missing registry connection fails a refresh as unexpected, not as an ended session, and so does a registry that cannot be read: a warning names only the error's type and the send is taken back (owner, 2026-11-20, [D110]). From 2.7.0 on a 401 without a code says nothing about the session (why: Vikunja codes every refusal from then on).
- An ended session adopts tokens another isolate stores later only when they name a refresh token it has neither seen refused nor rotated away, so storage it failed to update never revives a dead session, sends its dead token or hands out its still-valid access token. `settle()` finishes a refresh on its way and retries tokens storage refused at first.

**Requests that got no token** (a deferred refresh, unreadable storage) never left the device and are no outage: a deferred renewal takes the offline banner away, unreadable storage leaves it as it was, and no page that reads the server shows itself offline for them. The outbox counts them neither as possibly sent nor toward an upload's timeouts, storing `unreachable` with a not-sent note that reads back as nothing (support details: `network/not sent (deferred)` or `(storage)`). Their texts say that secure storage could not read the sign-in, or that the app was renewing it, and that nothing was sent; never that a connection is needed.

**Background runs** ([D40]):
- Every token answer must arrive by the deadline plus the 5 s settle, less 2 s; a token request waits what is left less its connect timeout (why: the native adapters bound a request by both together), at most 60 s, connecting within 10 s on Android and 5 s on iOS, and none starts with less than 30 s left on Android, 8 s on iOS, or once Android stopped the run. A queue's send or an account's turn starts only while a refresh could start and 10 s remain (why: its first request needs a refresh). After every run the container waits up to 5 s (after a stop 10 s) for every session's `settle()`.
- An account in `needsReauth` gets a restore first; a restored one sends its queue in its turn, before its sync, under the same rules as the other queues (only once it has synced, and while a refresh could start and 10 s remain).
- Each sync turn notes its outcome per account, synced at once when its sync went through; an OS stop stores Android's raw stop reason as a number (why: workmanager_platform_interface 0.10.5's names for those numbers are wrong). A session that ends during the settle is noted as ended, not stopped.

**Restore:** tried for a user's account in `needsReauth` whose last end was refused with another refresh token than the stored one, or whose storage could not be read; never while storage holds the token a refresh rotated away before the end (why: the server refuses that one too, and its refusal would replace the record). A refresh that works clears the mark and resolves the end as restored. A guest ([D62]) is restored, without a request, only when marked for an unreadable link that reads again; opening the link resolves an open record first, so a later end is never taken for an unreadable link. Both run for the active account at start, resume and switch (the session check) and for every account in every background run.

**Diagnostics** (preferences, no secrets: tokens only as the first 16 hex digits of their SHA-256), beside the support details' own short record ([D22], [D66]):
- The support details print the last end's record as one line, "Session end cause:", with its cause, the server's code, the part of the app, the time, the lost renewal's time and part, and what became of the session; never a token's fingerprint (owner, 2026-11-20, [D20]).
- **Refresh marker** per account: the token last sent, its earliest send whose answer was never stored (time and part) and when the server refused it. A send is noted before the request leaves and forgotten when the failure proves it never reached the server (read from the platform's error texts, as in [D65]) or the server answered without looking at the token (a rate limit, another 4xx); a 5xx stays noted (why: the server may have rotated before failing).
- **Last ended session** per account: the cause (refused, idle too long, disabled, locked, no tokens, storage unreadable for a day; for a guest also share gone, and password needed for 13001 and 13002), time, code, part, fingerprints and the refresh most likely lost, recorded before the account is marked, a guest's too. **What became of it** is judged at the next sign-in (the old tokens still worked, the server still listed the session or no longer had it); a session the server still lists is an orphan, revoked with the new tokens.
- Notes are written only for an account the registry lists, an unreadable registry counting as listing it (why: a skipped record let an older restored one stand in, and the restore unmarked a dead session), and forgotten if it is gone (why: account ids repeat, and a re-added account must never show a previous session's end). Sign-out forgets all of it.

**Shown:**
- The reauth banner (Account tab, first-sync screen) tells when and why the session ended while its record is unresolved; a guest's gives no reason. An end on this device reads "Signed out on this device" ("Guest access ended on this device"), also in a guest's notification and on widgets; no notification names who ended it.
- The banner reads the record again when the mark flips and every minute while the app is in front, and builds nothing until the record read under the mark arrives, so its live region is announced once; its reason line sits outside it (why: its times tick every minute, and TalkBack re-announces a live region whose label changes).
- The Account tab shows the last successful background sync, a failed attempt since, and on Android a hint after a day without a run; for two weeks after an end, its cause and what became of it, in words that never call a deleted, live or restored session a lost answer; a guest's gone share and needed password have their own words. Android stop reasons read by number: 3 ran too long, 4 battery saver or the device's state, 5 battery low, 7 network lost; others, and all below Android 12, "stopped by the system"; a turn cut short by the run's own deadline (9 min, on iOS 25 s) reads "the run's time ran out".

**Rejected:** background refreshes only once the last rotation is a day old (against [D40]'s freshness, and a network loss stays possible); a cross-isolate lock (POSIX locks do not separate isolates, [D26]; the longer re-read and the restore cover the race); keeping the plugin's reset (it deletes before the app sees an error); resetting all secure storage after failed sign-in writes (it cannot repair a lost key and deletes other accounts' tokens); both tokens under one key (a format change for a harmless rare case); one session-end record for support details and Account tab, and clearing background outcomes at a sign-in (it would cover neither a restore nor a guest) (neither decided by the owner).

Limits:
- An answer lost on the network can still end a session; only a short server-side grace period for the previous refresh token would prevent it (an upstream proposal). The record names the lost send, and the next sign-in revokes the orphan.
- A key lost for good keeps the account failing for up to a day of app starts.
- The plugin's lost-key detection was read from its source only; a passing Keystore failure lasting to a sign-in's third write, about 1 s after the first, wipes every account's tokens.
- After a recovering write `resetOnError` stays on in that engine, so undecryptable data is deleted instead of reported.
- A sign-in whose writes all fail at the access token leaves its logged-out refresh token over a re-auth's possibly live one; that isolate's manager stays retired until the next sign-in or start.
- The flush plugin has no native tests and has not run on a device; whether it drains the plugin's wrapped-key write is unchecked.
- A timeout, a lost connection, a 5xx and connection errors a platform words otherwise count as possibly sent, so a refusal can blame a send the server never saw.
- A race refused again after the window ends the session even when the winner holds the tokens only in memory; a restore brings it back once stored.
- A call at the moment of an end can get `SessionEnded` before the end is recorded.
- A guest whose server connection is missing fails its renewal as expired without ending, a failed renewal holds the next back, and an unreadable registry passes its raw error on ([D110]).
- iOS gives no stop signal (workmanager_apple 0.9.11): an early expiry drops a refresh in flight unnoted; its run's time counts from Dart's start and answers may arrive until 28 s, so a cold start can pass the roughly 30 s iOS grants before an answer is stored.
- An Android OS stop abandons a refresh still on the network after its 10 s grace, while a token request may wait 60 s.
- A turn notes an end during the settle only before the container is disposed; otherwise its stopped note shows as the last attempt while the account needs a sign-in.
- The 2 s answer margin is the only allowance for a cold Keystore's reads before a token request's timer starts.
- Android's stop reasons from 10 on (a quota, a background restriction, app standby) arrive as 0 (workmanager_platform_interface 0.10.5) and read "stopped by the system".
- In the app the restore checks only the active account; others wait for a background run or a switch.
- A guest's link read before a failing start in the same process lets a failing start a day later still mark it, until a session check or background run unmarks it.
- On the first-sync screen a failed sync can arrive before the mark, so the banner can change its words and be announced twice.
- No turn starts in the last 37 s or so of an Android run, so its local notification reconcile waits for the next run.
- A quick add stops its assignee searches after any network failure, a request without a token included; names not on the device stay in the title.
- Two records of a session end sit side by side: the support details' own and this one.
- Until Crowdin's German arrives ([D88]), German shows this entry's new texts in English; the background sync lines whose meaning changed had their German removed, so they never show the old meaning.
- Not built: reading the server's `jwtttl` (an OAuth client sees it only through a real rotation on the v2 cookie endpoint), Android's ApplicationExitInfo, a diagnostics screen.

## D60: Labels, teams and shares online; the stored project permission shapes every screen

*Accepted 2026-10-26 (step 28).*

- **Organize** on the Account tab, after Account settings and before Accounts, opens Labels and Teams (owner), and on servers with the trash the Trash ([D79]). Not for link-share guests ([D62]).
- **Labels, managed online and applied locally:** a change or delete goes to the server at once and its answer is stored, unless something for the label is still queued ([D109]); a delete takes the label off every task, and an update answered "gone" (8002) removes it here too. v1 posts a fresh read back whole with the change on top (why: another client's colour or description survives); v2 sends a merge-patch (a 304 is read back). Colours go without `#`.
  - Only the creator's labels offer Edit and Delete (why: lists carry no permission); a label made by the user's bot is not recognised, and the server's refusal is worded instead.
  - A search the server would read as ids (a number, or numbers with commas) pages the whole label list and matches on the device, so quick add finds an existing "2026" instead of creating a second one.
  - The Labels page has a search field above 12 labels (ignoring case and accents, owner); a tap on a label, here or on the task sheet, shows its open tasks. Titles have up to 250 code points; the description goes through the editor page ([D52]), saved online with nothing compared.
  - Labels are created offline too, through the outbox (owner, [D36], [D109]); only a guest's label or one over 250 code points typed in quick add stays in the task's title ([D38]).
- **Teams, online only and never stored** (why: membership changes bump neither `updated` nor the ETag): read on open, on pull and after every change; the exact username always finds a member to add.
  - **Guards the server lacks:** nobody demotes or removes themselves; the only admin with other members must make someone else admin first; the last member is offered "Delete team" instead of Leave; external teams offer no edit, add or leave. Make admin and Make member send the server's toggle only while a fresh read shows the role still differs (why: it is a toggle, so a stale page would demote, [D96]); its answer carries id 0, so the team is read to settle it.
  - A cleared description is written as `<p></p>` (why: the server does not store an empty one and keeps the old text). A create whose read-back fails returns the team with its creator as only admin, so a retry creates no second team.
  - Leave, Remove and Delete ask first with the access-cleanup notice (from 2.7.0 the task assignments, subscriptions and webhooks lost in projects no longer reachable). Refusals are worded, such as already a member (6005), the last member (6006), a team managed by a sign-in provider (6010), an unknown user (1005). A team notification opens the team when it names one, else the inbox ([D98]).
- **Sharing:** "Share" in a project's menu, for every real project that is not archived, never for guests ([D62]). Admins change or remove shares, asked first with the cleanup notice; lowering one's own share asks too. New people shares are Read only by default; a team the server hides shows as "Hidden team". Others see the lists read-only. A change of one's own share or any team share refreshes quietly, so the stored permission follows.
  - A Retry while a read runs reads again and the latest answer wins, in "Add team" as on the teams, team and share pages (owner, 2026-11-20, [D110]).
  - Links, where the server has link sharing and only for admins: a permission (Read only by default), an optional name and password (obscured), and the view it opens; they cannot be changed (the server refuses). Delete warns that anyone using the link loses access at once. The link is `{frontend}share/{hash}/auth?view={id}` on the frontend URL when it is http(s), else the server root, never http for an https server.
  - Share uses the system share sheet, Copy the sensitive clipboard ([D66]). The QR code (package `qr`, owner) is dark on white in both themes; a link that needs a QR version above 10 is called too long. Screenshots are not blocked (why: the link is meant to be shared).
  - **The hash appears only** in the link on screen, the QR code, the share sheet and the clipboard; the password only in its field and the create request. Neither is logged, put in a route, kept in a provider that outlives its page, or stored.
- **The permission stored:** `projects.max_permission` (0 read, 1 write, 2 admin), filled through `expand=permissions` on the sync's project list (why: no request is added) and compared by the diff, so a permission change alone is written although `updated` did not move. Null means unknown: offer the change and word the refusal. In a v1 single read the `x-max-permission` header wins over the body. Write answers never carry it; a created or duplicated project is unknown until the next sync.
- **Every screen shaped by it** (`ProjectAccess`, by the server's rules): write for editing a project and its tasks, new tasks, manual order, board moves ([D84]) and moving a project in the tree, into a parent only one the user may write ([D49]); admin for Views, Delete, the done and default column ([D48]) and moving a project into or out of a parent; read for Duplicate. Read-only projects are left out of every project picker, the default project and quick add's `+project` ([D38]); their tasks offer only Copy link and Share ([D84]), and the screen says "Read only". Archived projects keep their own rules on top.

Limits:
- Not built: teams in the global search, share counts in the project menu, a cleanup list per project.
- On Vikunja 2.8.0 a move under a new parent needs admin on that parent, while the app checks write.
- A tap on a team notification without the install's link key ([D66]), older or forged, opens the inbox.
- An assignee the server's access cleanup removed stays on the device until the daily full resync (why: the removal bumps no `updated`).
- A team whose create answer is lost can still be created twice; only a failed read after the create is covered.

## D61: Table as a detailed list, Gantt as a read-only timeline

*Accepted 2026-10-26 (step 29).*

**Both views:**
- Every view kind the app knows is a tab, in the web's order; the default view can be Table or Gantt. "New task" follows the stored permission ([D60]).
- Both read [D43]'s local list path through [D51]'s filter engine, so they work offline, show a local change at once and cost no request; only a view whose filter the engine refuses downloads its snapshot like a list view.
- Preferences: per view the table's sort and the timeline's range, "Show undated" and zoom; per account the table's columns. Deleting a view forgets its preferences. Wide windows follow [D69] and [D70].

**Table:**
- Flat rows as on the web: subtasks are rows of their own, done tasks stand among the open ones.
- Columns per account under the web's keys (why: the web keeps one choice for every table): Done, Title, Labels, Assignees and Due date by default; the title always shows. No task number column (owner, [D75]); a stored choice naming `index` loads without it.
- One sort key per view, the web's `field:dir`, by default `index:desc` (newest first), in the server's order: missing values last in both directions, priority and progress 0 as values, open before done, no done-at for an open task or one created done, a task created here after every server task, ties newest first (standing in for the view's positions, which are not downloaded). A sort on a hidden column gives way to the default, as the web leaves it out of its request.
- "Show done" only on a view whose filter is `done = false`.
- The row is [D56]'s task row with the chosen fields; dates are neutral, never red, and the priority shows every value, Unset and on done tasks included (why: the column promises it). Each row is one screen-reader node naming every shown field.

**Timeline (Gantt):**
- Which tasks: the web's range filter, character for character, ANDed with the view's filter as the server does it, with include-nulls if "Show undated" or the view asks, in the timezone setting's zone, else the device's. Where the engine refuses the view's filter, its last download stands in, narrowed to the range here.
- The web's quirks are copied where they decide which tasks show (the spanning clause ignores the due date; with "Show undated" every task with a missing date matches and the range trims it), not where they are drawing mistakes: days are calendar days, so nothing is a day off across a DST change.
- The default range follows today, 15 days back to 55 ahead; a custom range is stored per view.
- Rows: the matching tasks and every descendant, in any project, each task once under its first parent, indented up to four levels; tasks in a relation cycle become top-level. A parent without dates spans its subtasks.
- Bars in calendar days, at least one day wide; a start alone runs 7 days and fades out, an end alone starts 7 days before, an undated task runs from today for 7 days. Arrows for `blocking` and `precedes` only between rows that show; no arrow toggle, as on the web. Zoom is 20 to 72 dp per day (36 by default), stored per view.
- Read-only: a tap opens the task, dates are changed on the edit page ([D20]).
- Screen readers: one node per row with the title, parent, done, the dates in words, its arrows and an action to collapse or expand; grid, bands and arrows are left out ([D68]).

Limits:
- Table ties go newest first where the server uses the view's positions; they differ in a table view created after its tasks or reordered through the API.
- Titles sort ignoring case, SQLite by bytes.
- A view's filter carries no timezone on the server (`filter_timezone` is a request parameter only); with an empty timezone setting the server evaluates in its zone, the app in the device's.
- A view whose filter the engine refuses can list slightly other tasks than the server with "Show undated" on.
- Servers before 2.7 get 2.7's filter and tree rules, unchecked.
- Saved filters have no Table or Gantt view; a saved filter opens as one list.
- At 200 % text the table's chips on a 320 dp screen and the timeline's zoom and today buttons on a 360 dp phone run past the edge; the row scrolls sideways.

## D62: Onboarding through the browser; link-share guests as an account kind

*Accepted 2026-10-26 (step 32), the owner's decision where marked.*

**Onboarding** (the app still never takes an account password or a TOTP code, [D14]):
- "Create account", where the server allows registration, runs the normal browser sign-in (why: the web's sign-in page links to its register page and the pending sign-in survives the move; another host gets [D23]'s warning first); "Forgot password?" opens the web's reset page in the external browser.
- **Invite links** (`{base}register#invite-link=<token>`): checked on the server (404 code 2005: invalid, expired or used up; a server without the check gets the card unchecked), then opened in the external browser (why: the web drops the app's sign-in on an invite registration). The token is never shown or logged.
- **After the update from the old app** ([D85]): Connect fills in the old server address. While the old session is being kept, everything on Connect is off except a Cancel; the Cancel, or 30 s after the try started, ends it like a failed try, and Connect unlocks with the address filled in and the note to sign in again (owner, 2026-11-13; why: the steps' own timeouts add up to about 110 s at worst, too long for a locked screen).
- The Account tab's Server section, guests included, shows the MOTD and the server's legal links ([D81], [D78]).

**The guest account:**
- Kept in the official app (owner, 2026-11-12).
- **What a guest may do** (owner, 2026-11-12): what the Vikunja web interface offers a link share of the same permission (read, write, admin) and the server accepts, presented the app's way, for example disabled with a reason where the web hides it.
  - Not offered: what the web reaches only by a typed address, not through its interface: for a write share editing, archiving and the background of the project, for an admin share also managing its views and deleting it (owner).
  - Kept although the web lacks them, because the server accepts them (owner): a guest editing and deleting its own comments (the web compares the author's id with the wrong sign), and assigning people the device already knows (the server refuses link shares the user search).
  - Unavailable: what the server refuses or never stores (reactions, Follow, favourites, creating labels, the user search). A task's Copy link and Share are offered at every permission, as the web copies a task's link for every link share.
- A share link comes in by paste or through the Android share target; no QR scanner (owner). iOS has no share extension before 1.0 (owner, [D74]); a link is pasted there.
- The guest's user id is `-shareId` and its username `link-share-<id>`, as the server writes the guest (why: upload recovery and the guest's own comments match); the same link opened again replaces its session ([D25]). Its name is the share's or the project's, never the server's "Link Share".
- **Secrets:** the JWT and the hash sit in secure storage, the hash written first and deleted first; a guest counts as signed in while its hash is stored. The share's password is not stored or logged (why: a renewed token never expires and the password guards someone else's project), so a share with one asks again when the hash alone cannot sign in, unless the user ticks "Remember the password on this device" (unchecked by default), which keeps it beside the hash (owner, 2026-11-19, [D100]).

**The guest session:**
- `POST /shares/{hash}/auth` signs in; the token (72 h, no refresh token) is renewed through `POST /user/token` after half its lifetime; a failed renewal keeps the old token while valid and is retried after 5 minutes.
- An expired token is replaced by signing in again with the hash, so a guest signs in again by itself; a 429 blocks that for its `Retry-After`, and a container the OS started tries at most once (why: a share that needs its password must not spend the shared rate limit every half hour). A 401 code 11 signs in again, never renews (a renewal passes the same check). 13001, 13002 or a gone share end the session.
- A token written after a sign-out in another isolate deleted the hash is taken back. A guest's requests go to its session, so transport, sync and outbox need no guest branch; the sign-out skips the server's logout. The permission is the stored project permission, never the token's claim (why: the server reads the share on every request).

**A share gone** ends the session: v1's 400 code 13003; v2's 401 without a code only on a request with a link-share token (why: a user can get that answer too); 404 code 3006 or a codeless 404 (link sharing off) at the share endpoints. The session check reads `GET /user` (why: `/token/test` passes a deleted share's token). A 401 code 1027 (the endpoint needs a user) never ends it, nor do a missing or wrong password (412 code 13001, Forbidden code 13002) and an invalid invite (2005).
- **Before 2.7 over v1** ([D111]): 2.3.0 to 2.6.x answer a deleted share's token over v1 with a codeless 500 (v2 has its 401 from 2.4 on; on 2.3 the share endpoints are v1 only). Reading over v1 from such a server, or one of unknown version, the app checks such a 500 by renewing the token, which answers a gone share with 404 code 3006 on v1 and 401 on v2 on every release and is not on the sign-in limit, at most once per 5 min per guest; an ordinary 500 never ends a session.

**Sync:** no account phase for a guest (why: the server's pseudo user has no settings and would rename it "Link Share"). The shared project is read once per run when the list brings it without a permission, and always below 2.6.0 or on an unknown version (why: 2.3.0 to 2.5.x list it as read for every guest, [D111]), so [D60]'s `ProjectAccess` shapes a guest's screens.

**Gates**, where the server refuses link shares or the web offers them only by a typed address:
- No activity sync, inbox, bell or realtime socket; local reminders stay. Hidden: account settings, Organize, new projects, saved-filter editing, favourites, reactions, Follow, creating labels and the project menu, even for admin shares (why: the web offers a link share no project menu, and the server refuses a link share sharing and creating projects). Quick add creates no labels and looks no one up ([D38]); people pickers and @-mentions offer only people already on the device.
- **The board's columns** have no guest gate: a guest gets what a user of the share's permission gets ([D48]); a write guest deletes the done and default column too, which the server then clears in the view without asking for admin, but cannot choose them, as the server refuses every change of the view below admin. Apart from what the app builds for nobody (such as dragging dates on the timeline), the disabled Delete of the leftmost column holding tasks while no other is the default is the one place where the app offers a write share less than the web does and the server accepts (owner, 2026-11-12): the server would leave the column's tasks in no column, which [D48]'s guard against orphaned tasks prevents, and the new default that guard needs is refused below admin.
- **Routes are closed to guests by default:** only those in `AppRoutes.openToGuests` (`app/lib/app/router/app_router.dart`) open, others lead to the Overview; `guest_gates_test.dart` fails for a route on neither that list nor its closed list with a reason.
- **Actions:** a new action that needs a user is hidden or disabled for a guest where it is built; `guest_action_inventory_test.dart` fails for a use of a watched name not listed as `Gated`, `BehindClosedRoutes` or `Open` with its reason. A new provider that only passes a watched one on goes onto the watch list.
- Kept: the shell (without the tree's column, [D82]), task edits by the stored permission ([D84]), its own comments, every project view, the support details ([D20]).

**Guest entry:**
- Connect recognises a pasted share link before any probe, never one with user info such as `https://vikunja.example.com@evil.example/…`, which invite links refuse too ([D97]); it never shows the hash and keeps it out of the screen's state.
- The hash and the password go without asking only to a stored account on the link's own origin whose web frontend is the link's base, else to the base probed like a typed address (an http server asks first); if no Vikunja server answers, "Which server is it?" asks for its address. A stored server on another origin that names the link's base as its web frontend gets them only on Continue, with both hosts named ([D92]).
- Link sharing switched off is answered without a request only for a freshly probed server with no stored account (why: a stored account's `/info` can be hours old).
- The public demo button carries no pending share, so a hash never goes to try.vikunja.io. A share with files is never taken for a link.
- **Password sheet** (13001, 13002): obscured, no autofill, naming the host the password goes to ([D92]).
- Signing in writes the secrets before it replaces the share's old session, so a failed write leaves the old one working; when a removed guest's old database is not let go in time ([D31]), the link fails and the new token is dropped unstored.

**Guest UI:** "Guest · {host}" wherever an account shows. The Account tab has no account settings, Organize or deletion note, and its Appearance section is a user's ([D75]); Sign out reads "Remove guest access". An ended guest gets "Guest access ended" with "Open the link again", one whose link this device lost "Guest access ended on this device" ([D59]).

**Logs:** the segment after `share/` and `shares/` and the `"hash"` JSON key are redacted, and the link-share client logs no bodies (why: requests carry the hash and maybe the password, and answers echo the hash). No parsed link, token or share type prints its secret.

Limits:
- The banner does not tell a needed password from a deleted link; a tap does.
- A request inside the old session when "Open the link again" replaces it can still end as `SessionEnded`.
- A guest whose link needs opening again is tried again only by "Open the link again".
- The invite token stays in the Connect screen's state while the screen is open.
- Others see a guest's tasks and comments under the server's fixed English name, "Link Share" or "<share name> (Link Share)".
- Share links do not open the app straight from other apps (no App Links for self-hosted domains).
- Not probed: an admin link share, a real 72 h expiry, the sign-in sheet surviving a trip to the mail app, an invite that passes the check.
- On 2.4 to 2.6 over v2 the few v1 requests (attachment previews) get a plain 500 for a gone share; the next v2 request ends the session.
- The guest action inventory matches source text by name, not types, so an unusual construct may slip through; it decides names, not each use, a gated entry's check only finds that its files ask about guests somewhere, and calls and raw clients count only under `features/`. The tree's moves and a saved filter's menu are open because a guest never has their data, and the trash Undo is open to a write guest ([D79]).

## D63: Home-screen widgets: app-written snapshots, Glance on Android, WidgetKit on iOS

*In review since 2026-10-27 (steps 18 and 19, until the iOS device test).*

**Data: the app writes, the widgets only draw** (`app/lib/core/widgets/`); nothing native talks to the server or holds a token.
- Lists: Today (as on the Overview), Upcoming 3, 7 or 14 days, Overdue, Favorites, a project (as its first list view), a label, a saved filter (its open tasks, [D95]; not for guests); and a New task button.
- One versioned JSON snapshot per shown list, at most 30 rows plus the count of the rest, valid until the next local midnight at the latest. Done is offered by the stored permission, never in read-only or archived projects. Keys start with the account id, so a sign-out finds its files; `host.json` holds the active account, "Use system colors" and the widget-link key ([D66]).
- **Dart formats every text** ([D71]), so no native code copies those rules. Due labels are never relative (why: they would go stale between updates); a label naming a day also comes dated for an iOS widget left past midnight. Screen-reader labels carry no identifier and say "Overdue" only for the tone shown ([D68]).
- **No file holds a token or other secret**; task titles can be left out ([D64]). No task title, snapshot or link is logged, only counts and failure types.
- The snapshot builder in `core/` reuses feature code, a listed exception of the layer test ([D110]).

**The in-repo plugin** `plugins/vikunja_widgets` (a path dependency, so `packages/*` stay pure Dart, [D1]): Dart reads and writes the files; Kotlin and Swift only report directories, list placed widgets, redraw and pin. An Android redraw is a plain update broadcast (why: the plugin needs no Glance dependency).

**Publishing:** per signed-in account while the shell runs, at midnight and on resume; only what changed is written and redrawn, within 5 s of a change. Background runs import the widgets' taps first, so a sync run sends them before any account syncs (an account restored in its turn sends its queue there, [D59]), and publish after each account's turn. A sign-out or removal deletes the account's snapshots, catalog and waiting taps, and its widgets say "Account removed" (checked by `app/test/security/account_wipe_test.dart`).

**Done from a widget** takes the notification Done's path into the outbox ([D39]).
- **Exactly once:** a tap's Done is queued and its id recorded in one transaction, so a tap read again after a crash is skipped and a repeating task never moves twice; only then are taps acknowledged (why: acknowledging deletes them, and acknowledging first would bring the row back). Ids are kept 30 days; taps of an unknown account are dropped. A tap whose task is done already or, repeating, has another due date than the row showed queues nothing ([D94]).
- **Android:** a 48 dp Done button (Glance's `CheckBox` takes taps only on its 32 dp box, [D112]); an untick does nothing. The queue refuses a row already hidden. A tap rewrites the whole queue file (why: the app claims the queue by renaming it, so an append could be lost). An expedited worker runs a headless Dart engine (up to 3 minutes) that imports and publishes; with an empty queue it only publishes, once per key and process for a missing snapshot and once per expiry for a stale one. An inexact alarm redraws when a task turns overdue.
- **iOS:** an App Intent (iOS 17, requiring authentication, [D64]) in the extension writes one file per tap into the App Group; no network, keychain, SQLite or lock. A second tap before the import is ignored; an account id that is no safe file name writes nothing. The app imports on start, resume, every background run and a notification action.
  - A recorded tap also removes the task's scheduled and shown reminders and due notification, matched by the account and task key in their payload, which `app/test/app/widget_extension_contract_test.dart` checks and an upgrade must keep. Rejected: the app writing notification ids into the App Group (every isolate would write it, and it would miss one already shown).
  - The import should go before a reconcile (why: the scheduler would schedule the reminders again, [D39]). A notification action's import does not drain the outbox (why: the network must not hold up the action's own Done).
  - XCTests check the queue's files ([D111]) but have not run on a simulator yet ([threat model 8.3](threat-model.md#83-final-ios-phase)).
- **No widget link writes** (no `widget/done`), because any app, and on iOS any web page, can open the app scheme.

**Links** `<scheme>://widget/…` carry the install's key `k`; only with the right key does the app switch to the widget's account without asking ([D66]). A list link's days stay within 1–365; an unknown account or a malformed link is dropped.

**Widgets page and setup:** the Account tab's "Home screen" section notes that the home screen shows task titles, lists the placed Android widgets (an old one as "Widget of the previous app", [D85]; a failed preview shows its kind's title, [D96]) and, on Android 8+ where the launcher can pin, offers "Add a widget". The setup page opens only for a widget the plugin lists as placed, never on iOS, through `widget/configure` (why: a plain route path would be lost on a cold start), and offers a guest no project, label or saved filter.

**Android** (Glance 1.2.0): Tasks (3 × 2, resizable, setup optional, so Android 12+ places it showing the active account's Today) and New task (2 × 1).
- **The old app's provider** ([D85]): a second receiver under the old class name, `io.vikunja.app.widget.AppWidgetReciever` with its spelling, so old widgets survive the update. They show "Tap to choose what this widget shows" until set up (why: silently showing Today could change what an old widget showed); the old choice is not mapped and is deleted with the old widget data. The component is disabled once no widget uses it (why: launchers that ignore `hide_from_picker` would list "Tasks" twice).
- Rows at least 48 dp; text in `sp`. Removing a widget deletes its config. Theme: the system colours on Android 12+ when "Use system colors" is on, else [D56]'s brand colours. A project's folder takes the colour the app draws for the widget's light or dark background ([D117]).
- The configure activity accepts only the app's own widget ids and opens the setup in the app's own task, so no second Flutter engine runs on the same databases. Taps follow only the app's own widget links.
- Dependencies: the Compose compiler plugin equal to the Kotlin version; `androidx.work:work-runtime:2.11.2` (why: below it R8 strips Glance's RemoteViews translator); no `glance-material3`; ProGuard keeps every `ActionCallback`'s no-argument constructor (Glance calls it by reflection).

**iOS extension** `app/ios/VikunjaWidgets/` (plain Swift, added by `tool/add_widget_extension.rb`): iOS 17.0 (the app 15.0); the App Group, no keychain group and no token ([D24]) (why: access tokens live 600 s and the extension must never refresh).
- **The widget kinds must not change after the first release** (why: a placed widget refers to its kind, so a rename removes it); `app/test/app/widget_kinds_test.dart` checks both sides.
- Past a snapshot's expiry rows show dated labels and, on the medium and larger sizes, "Open Vikunja to update". A row past its due instant shows as overdue, and VoiceOver hears the label of what is shown.
- Dynamic Type shows fewer rows rather than smaller text. `.privacySensitive()` covers the rows' labels, the small widget and Done.

Limits:
- iOS lists refresh with the app closed only through background runs; a list configured then shows "Open Vikunja to load this list" until published, and after midnight which tasks Today and Upcoming show stays as last published (writing the next day ahead is left for later).
- The server learns of an iOS widget's Done only at the app's next start, resume, background run or a notification's Done in that account. Until the import, a reconcile can bring a ticked task's reminders back and a task whose id changed is not matched; the extension also removes the notifications of a tap the import then ignores; those of a task still open come back at the next reconcile.
- An iOS notification action with waiting taps imports them first, while iOS may suspend the process within seconds.
- Unticking is no undo, and there is no Undo. An old widget not set up still counts as Today, written for nothing.
- Android: the worker waits when Android 12+'s expedited quota is used up; below 12 a dark-mode change waits for the next redraw; after a force-stop a tap opens the task (14 or earlier) or the widgets are greyed out until the app opens (15+).
- Not offered: edits beyond Done, Android lock-screen widgets, a project on the Android New task button, lists across accounts, configuring an iOS widget from the app (iOS has no API).
- Waiting for the iOS device test: the configuration fields and project picker, the extension seeing placed widgets, "+N more", signing with the team's App Group, whether a lock-screen release build needs `DEAD_CODE_STRIPPING=NO`, the stale entries with their VoiceOver labels, a notification action with waiting taps finishing its own change, and whether the extension reaches the app's notifications (if not, a widget's Done removes the reminders only at the next import, and that becomes a limit here).

## D64: App lock over the UI, and device privacy settings

*Accepted 2026-10-27 (step 35a).*

- **A gate over the UI, not encryption:** data at rest stays as [D24] and [D31] describe, so nothing without a UI waits for the lock: the OAuth callback, notification actions, the widget worker, background runs, realtime and the schedulers.
- **Settings per device**, the same for every account and kept on sign-out: the app lock (off), lock after (immediately, 1 minute by default (owner), 5 or 15 minutes, 1 hour), Block screenshots (off, Android only), notification content (show everything by default, hide on the lock screen, never show task titles) and task titles in widgets (on).
  - **Fail closed:** settings that cannot be read give every switch its most private value for that launch, without writing back (why: the user may have chosen any of them). The app awaits the read (at most 5 s) before it runs.
- **Unlocking:** biometrics or the device credential (why: the screen lock stays a way in when biometrics lock out); `NSFaceIDUsageDescription` explains Face ID. Android needs a `FlutterFragmentActivity` for BiometricPrompt, with AppCompat themes, `USE_BIOMETRIC` and the default focus highlight off (why: AppCompat otherwise greys the whole app after a key press); `androidx.appcompat:appcompat:1.8.0` is declared (why: biometric 1.1.0 would pull in 1.2.0).
- **When it locks:** after every cold start ("unlocked" is never stored); after the chosen time out of sight by the wall clock (deep sleep counts; a clock that went back counts as passed); with "Immediately" on the hide. Lifecycle events during a prompt neither lock nor cover. Cancelled, locked out, stuck and unavailable stay locked.
  - Turning the lock on or off needs a successful prompt; without a device screen lock it cannot be turned on. When the device loses its screen lock, the app lock turns itself off and says so (why: removing the screen lock already needs the credential, and failing closed would leave only a reinstall).
- **Excursions don't relock:** the app's own round trips (pickers, the share sheet, the browser sign-in, the launcher's pin dialog) keep it open until the app is back (why: Android hands a picker's result over just before the resume), for at most the lock's own time, never more than 10 minutes, 30 s with "Immediately" ([D97]). External links are no excursion.
- **The gate** is the outermost widget of the router's builder: the app stays mounted below, unreachable, under an opaque lock screen or the privacy cover, so sheets and unsaved edits survive. No router redirect (why: it would replace the pages below). Links, widget taps, shortcuts, shares and notification taps wait and open after the unlock, the last one winning; back while locked moves the app to the back and never pops a route (from Android 14 a predictive back cannot be vetoed, so `MainActivity`'s own callback does it).
- **App switcher and screenshots:**
  - Android 13+: recents screenshots off while the lock is on, with no Flutter cover (why: it would blank the app at every loss of focus). Android 7–12 and iOS: a privacy cover while the app is inactive and the lock is on.
  - Block screenshots, a switch of its own, not tied to the lock (owner), Android only: `FLAG_SECURE` on the whole window, out of screenshots, recordings and Recents, reference-counted with every hold for a secret so they never clear each other. On iOS screenshots stay possible (owner); there one-time and revealed connection secrets are hidden while the screen is recorded or mirrored ([D74]).
- **Notification content** (reminders, due dates, activity):
  - Hide on the lock screen: Android posts as `secret` (why: `private` still shows the task title). iOS cannot be forced: the page says to set Show Previews to When Unlocked.
  - Never show task titles: generic texts, no project, name, comment or account label; tap and Done still work. The "Sign in again" notification holds no task data.
  - A change of the content or the lock reschedules every account (snoozes kept); one that shows less, turning the app lock on included (why: a Done already showing would run without the unlock, [D97]), withdraws the delivered reminders and activity notifications.
  - While the lock is on: on iOS Done requires authentication; on Android reminders and due notifications have no Done ([D97]). Snoozes stay on both.
- **Widgets:** with "Show task titles in widgets" off, a snapshot has no rows or due instants, so no Done, and a change deletes the account's other snapshots. On iOS the rows are always privacy-sensitive and Done asks for the unlock ([D63]); Android widgets are home-screen only, so their Done stays.
- The privacy page is open to guests. No settings value, prompt text or task title is logged, only failure types and local_auth's code names.

Limits:
- The app-switcher cover is best effort on Android 7–12, and there and on iOS it also shows whenever the app becomes inactive.
- With unreadable settings the page shows "off" although the app is locked for that launch.
- After Android drops a prompt silently, local_auth stays in progress until a restart; the lock screen says so.
- With "Immediately": cancelling the turn-off PIN screen on Android 7–10 locks the app; an activity relaunch in sight (system colours, wallpaper) locks and prompts.
- A background run in flight finishes with the old settings; "Show everything" again brings no withdrawn notification back; the test notification ignores the settings.
- A launcher that answers the pin request but shows nothing leaves no lock for up to the lock's time; with "Immediately" a browser sign-in over 30 s asks for the unlock ([D97]).
- Android has no per-action unlock with this plugin, so Done is left out while locked and Snooze runs from the lock screen ([D97]); with "Hide on the lock screen" the actions are not on the secure lock screen.
- No per-account settings and no PIN of the app's own.
- Waiting for the iOS device test: the passcode, Done asking for the unlock, and the redaction on the lock screen and in StandBy.

## D65: Connection settings per server address, applied in the app's transport

*Accepted 2026-10-27 (step 35b).*

**Where they apply:**
- Settings belong to an origin (scheme, lower-case host, effective port): a pinned server certificate or a trusted CA certificate, a client certificate, access headers, and the consent to unencrypted connections.
- One adapter in the base `Dio`s applies them below the retry, auth and log interceptors, so nothing above the transport holds a header value. An edit never rebuilds a `Dio` (why: that would tear down running syncs). Redirects are off (why: `dart:io` would copy access headers to a cross-origin target).
- No settings, only a consent or only headers: the platform adapter (Cronet, NSURLSession). A pin, a CA or a client certificate: a `dart:io` client per origin (why: only `dart:io` can pin in the handshake or present a client certificate; it brings HTTP/1.1, no OS proxy and no Android user CAs, which is why header-only origins stay native).
- An error quoting a stored header value or password of 8 characters or more keeps its kind and loses its text (`core/network/secret_scrubbing.dart`; shorter values turn up by chance in ports, errno numbers and host names).

**Pin or CA:**
- The pin is the SHA-256 of the leaf's DER, checked in the TLS handshake before any HTTP byte (never with dio's `validateCertificate`, which runs after the request was sent); only the origin's own host and port pass. Trust on first use: a changed certificate is recorded and stops every request until the user reviews it; nothing is trusted automatically, and "Accept new certificate" pins the one probed now, never the recorded one.
- A CA certificate (PEM, at most 64 KB, no private key) can be trusted instead, for short-lived leaves and private CAs; it is checked against the server before it is saved. The editor says that on iPhone and iPad the leaf must name the server and be valid for at most 825 days. A pin and a CA exclude each other (why: the CA would verify the chain before the pin is asked).
- The trust page shows the SHA-256 to compare and how; a certificate valid for less than 100 days gets a warning and puts the CA first.

**Client certificate:** a `.p12` or `.pfx` of at most 64 KB; the picker's cached copy is always deleted. Its file password is stored with it, because `dart:io` needs it for every context; it is no account password ([D14]). The certificate goes only to its origin; a private-CA server then needs that CA or a pin in the app too (why: certificates installed in the device settings do not apply to `dart:io`).

**Access headers:** at most 10, values of visible ASCII up to 4 KB, sent only to their own origin; names are RFC 7230 tokens, none the stack, Vikunja or the socket set (such as `Host`, `Authorization`, `Cookie`). Presets: "Cloudflare Access service token" and "Custom header".

**Unencrypted connections** need a consent per origin, enforced in the transport for requests and `ws://`; only the pre-consent `GET` of `/info` without `Authorization` or any part of the profile passes.
- The consent is recorded before the connection goes on; one that cannot be written ends in an error, never in a request. It can be revoked. Headers on an `http` origin need the consent and are noted as travelling unencrypted.
- The Connect screen does not ask again for an origin with the consent ([D95]), except an address typed without a scheme that reached `http` only after every `https` candidate failed: asked every time ([D8], [D97]).
- No `http` account is upgraded to `https` (why: the account id derives from the root, [D25]); the Connection page offers "Use HTTPS" to add one, and the app offers to remove the `http` one once the same user is signed in over `https` ([D97]).
- The `/info` probe reads at most 256 KiB and ends after 10 s, so the connector's bound of 17.5 s holds for every adapter ([D97]).

**Storage:** metadata (pin details, the public CA PEM, header names, the consent) in preferences; secrets (header values, the PKCS#12 file and its password) in secure storage under a hash of the origin key (why: secure storage cannot be listed). Settings with only a pin, a CA or a consent never read secure storage, so they work before the first unlock.

**Fail closed:** no request leaves without its origin's settings. Unreadable storage is transient ("not available until the device has been unlocked once", never "locked", the app lock's word); damaged metadata stops every origin until "Reset connection settings", which deletes the secrets it can name and gives no consent again; missing secrets: "needs re-entry". These failures print only class and origin and are not connection-level, so the connector never falls back to `http` and queued writes stay queued.

**Client-certificate refusals** are recognised by Cronet's and NSURLSession's client-certificate errors and the TLS alerts, never by `SSLV3_ALERT_HANDSHAKE_FAILURE`, which any mismatch sends. On `dart:io`, TLS 1.3 reports a refusal only on the first read, so the app confirms it with a second handshake (5 s, then up to 3 s for the server to hang up), the answer kept 10 s per origin (`core/network/client_certificate_check.dart`). nginx's default 400 pages for 495 and 496 count too; while connecting the app then tries no other port or scheme ([D96]).

**Realtime:** each upgrade gets the consent for `ws://`, the headers (the app's `User-Agent` last) and, for TLS settings, a `dart:io` client from the profile. An `HttpException` on such an upgrade runs the second handshake too, so a lost upgrade takes up to 8 s more before its retry (5 s for the handshake, 3 s of waiting), its answer kept 10 s per origin (owner, 2026-11-20, [D110]). On a refusal or any other settings failure the socket gives up until the next resume or edit; [D46]'s polling stays the fallback. Link-share guests have no socket ([D62]).

**Screens:** "Connection options" under the address field opens the typed origin's settings, which is how settings without an account are reached. Secret fields are hidden, without autofill, copy or cut, and hold the secure display while shown ([D64]).

**Hint before the browser leg:** before every browser sign-in, for the API's and the sign-in page's origin (host in punycode, as [D23] takes it, [D97]), a dialog says what the browser meets that the settings do not cover (why: the browser legs do not use them, see Limits): the pinned fingerprint to compare, a CA it may warn about, the client certificate needed in the device settings too, the access login, a different sign-in host. When [D23] asks about a sign-in page on another origin, this dialog carries that question, the warning first.

**Forgetting:** removing an origin's last account offers to forget its settings too (on by default); a failure never blocks the sign-out. Settings made without an account stay until forgotten.

**Logs:** no header value, certificate byte or password, failures by type; secrets appear in no `toString`. Redaction knows `CF-Access-Client-Id`, `CF-Access-Client-Secret` and `CF-Access-Token` (why: a 32-hex id is too short for the rule on long runs).

**Tests:** the unit tests use a committed dummy certificate set without CA keys; the opt-in Docker `tls` profile generates its own ([README](../test_servers/tls/README.md)).

Limits:
- The browser legs do not use the settings: a pinned or private-CA server shows the browser's warning at every sign-in, as the browser session is ephemeral ([D23]), and the password typed there is protected only by the user's check; a client-certificate server needs it in the OS too; an access proxy shows its own login every time, and a service-token-only one leaves only guests.
- A server's `frontend_url` and legal links with user info are still accepted; only incoming share and invite links with user info are refused ([D97]).
- A header-only origin behind a private CA keeps the socket on `dart:io`'s default trust, so on Android realtime polls unless the CA is trusted in the app.
- A socket on the platform's path knows a refused client certificate only by the alert; a server that just closes leaves it retrying.
- Cronet's and NSURLSession's client-certificate texts are unrecorded; a server with its own `error_page` for 495 and 496 ends in `NotAVikunjaServer(400)` ([D96]); on Android the trust page cannot see a user CA that already trusts the certificate.
- A background run in flight during an edit fails once; a hanging settings write blocks its isolate's later writes.
- After a reset `http` accounts need the consent again, and secrets of origins nobody names stay in secure storage.
- Not offered: SPKI pins, `Proxy-Authorization`, a list of all stored settings, a client certificate from the OS key store, user CAs for `dart:io`.
- Waiting for the iOS device test: pinning and PKCS#12 under SecTrust, the 825-day rule, headers through NSURLSession, the browser's warning; the app's own TLS through `HttpClient.connectionFactory` stays in reserve.

## D66: Threat model, redacted errors, no backups, keyed widget and notification links

*Accepted 2026-10-27 (step 35c), the owner's decision where marked.*

- The threat model is [threat-model.md](threat-model.md). Its residual and accepted risks ([§7](threat-model.md#7-residual-and-accepted-risks)) are the list of known gaps, and its rules for a diagnostics log ([§10](threat-model.md#10-rules-for-the-diagnostics-log)) bind the diagnostics log and the support details ([D94]); an export of its own stays postponed ([D20]).
- **Uncaught errors:** all four entry points (UI, background runs, notification actions, widget worker) install `FlutterError.onError` and `PlatformDispatcher.instance.onError` in every build (why: Flutter's default handler prints an error's details unredacted, in release builds too). They log redacted, a release build prints nothing (the diagnostics log gets records by type and the app's frames only, [D94]), and the engine never prints the error itself; debug builds thus lose Flutter's diagnostics tree and print unredacted stack frames.
- **Redaction** (`core/logging/redaction.dart`) also covers e-mail addresses, invite and share-auth tokens, a URL's fragment, the widget-link key (`k`), and a JWT or JSON secret cut off in a `FormatException`. No log call interpolates a secret, content, a link or a person, and model `toString`s print ids and kinds, not content (`Account`, `User` and `UserProfile` keep the username, parsed text its text); Kotlin logs failure types only, the Swift nothing (checked by `app/test/security/log_hygiene_test.dart`).
- **Support details** ([D20]): built from what the app stores when their page opens, with the diagnostics log at the end, kept only while it is open, and leaving the device only when the user shares them, after seeing them, or copies them from the release error screen without the preview (owner, 2026-11-18, [D94]). No person, content or id (the threat model's buffer rule 3); hosts only while the user's switch is on, without user info, query, fragment or a link share's hash; an outbox failure by its keys, never its message; the whole text redacted last. The last session end is stored as reason, part of the app and time only; the details print [D59]'s record of it without its token fingerprints (owner, 2026-11-20).
- **Backups, Android** (owner): `allowBackup="false"` and extraction rules that exclude all nine domains from cloud backup and device transfer, with no include and no cross-platform transfer (why: on Android 12 and later `allowBackup="false"` stops only cloud backup, and on some devices not a device-to-device transfer). Below Android 12 (minSdk 24) `allowBackup="false"` covers both.
- **Backups, iOS** (owner): the accounts folder (databases, queued uploads, drafts, [D97]) and the App Group's `widgets/` folder are excluded, nothing else; the preferences stay in backups. The mark is set again at every UI start, because a restore or a move can clear it.
- **Keychain and entitlements:** every secret stays in the Keychain or the Keystore ([D24]); tests pin the secure storage options (after the first unlock, this device only, not synchronizable, no Secure Enclave) and both iOS targets' entitlements (the App Group only, no keychain access group).
- **The app's iOS channel** is registered only on the UI engine; its backup exclusion logs an error by type, never a path, and the background state queries of both platforms log nothing.
- **Sensitive clipboard:** [D55]'s one-time secrets and copied share links are copied as sensitive (Android `IS_SENSITIVE`; iOS local only, expiring after 120 s), plainly when the channel does not answer.
- **Routes pushed by the platform:** the app-scheme relay, registered before go_router's own observer, takes every pushed route: an app-scheme URI goes to the deep-link relay, anything else is dropped, and the redirect sends a location with a scheme or a host to the splash (why: Android's embedding pushes the data of any intent that reaches the exported `MainActivity` as a route).
- **The widget-link key:** 32 random bytes in preferences, compared in constant time (why: any app, and on iOS any web page, can send a widget link, so a link alone must not switch accounts).
  - Only the UI start creates it, before the install marker is set, and replaces it only when missing or broken; headless containers only read it. Neither the key nor a link is logged. A fresh install gets a new key; an iOS restore brings the old one back.
  - Carried as `k` in every widget link, also those Kotlin and Swift build from `widgets/host.json`; links built before the app wrote it carry none. Without the right key a task link goes through [D44]'s task-link flow, which asks before it switches; other links act only in the active account; `widget/configure` needs no key.
- **The key in notification taps** (why: on Android any app can send `MainActivity` a made-up notification tap): without it a tap never switches accounts and marks nothing read: a task tap goes through the task-link flow, other taps open only in the active account. Notification actions need no key (their receivers are not exported).
- **Exported components:** `tool/check_exported_components.py` compares the merged release manifest's exported components, with their permissions and intent filters, against its allowlist (8 open, among them the old app's widget provider, [D63]; 4 behind a permission), and checks `allowBackup` and the extraction rules; CI runs it after the release build ([D73]).
- **The editor WebView** ([D52]) keeps its per-load channel token instead of an origin check; tests pin that a `window.open` navigation is prevented and the page's CSP (its `script-src` hash, no network load).
- **Dependencies** (in [D86]'s CI, running [D73]'s scripts): an OSV scan of the Dart, editor and Gradle lockfiles, also weekly, accepted advisories only in `osv-scanner.toml` with a reason and an `ignoreUntil`; `npm audit` (high and above) for the editor's shipped packages, while its test-only packages, which only jsdom reaches, warn in the OSV scan instead of failing it; `flutter pub outdated` for information ([D97]).
  - Gradle verifies every fetched file against `app/android/gradle/verification-metadata.xml` and locks the runtime classpaths of `:app` without `io.flutter:*` (why: tooling classpaths change with every Android Gradle plugin update and never ship, the engine's artifacts with every Flutter version). The wrapper pins the distribution's SHA-256.
  - Dependabot covers the GitHub Actions; the weekly "Upstream versions" workflow fails while Flutter's stable release or `cronet-bundled` is newer than the pin ([D97]).
- **Headless containers:** extensions, widgets and the notification-action isolate never refresh user tokens; a guest token may be renewed there, and a guest is signed in again at most once per container ([D62]; principle 5 of the [architecture](architecture.md#1-principles)).

Limits:
- iOS backups still hold the preferences (registry, the kept `http` accounts by ids and counts only, confirmed sign-in hosts [D23], [D65]'s connection metadata, privacy settings, install marker, widget-link key, each account's last session end [D20]). Restored to a new device, accounts need a new sign-in and settings with secrets re-entry; restored to the same device from an encrypted backup, the this-device-only Keychain items come back too (R21 to R23). Drafts that development builds wrote to the preferences stay on those installs ([D114]).
- The widget host can act as the app through Glance's collection template for the list rows, and it sees the key (R17): accepted for the beta (owner, 2026-11-12) and for 1.0 (owner, 2026-11-17, [D92]), as for every app with a Glance list, and reported to Google; a fixed list with "+N more" and a hand-built scrolling list stay the choices for a later step.
- An app that starts `MainActivity` from its own activity without `FLAG_ACTIVITY_NEW_TASK` would get a second UI engine (R33), so `MainActivity` restarts such an intent in the app's own task (not `singleTask`, which would clear the sign-in's Custom Tab); a device check is open, and a caller with `MULTIPLE_TASK` or `NEW_DOCUMENT`, or one that finishes its own activity first, still gets a second engine ([D97]).
- Keyless links still act in the active account; notifications scheduled by development builds before the key stay keyless until replaced, and their taps ask or do nothing (R18, R19).
- Outside the hooks: the drift database isolate, errors before logging is set up, plugins' prints and native logs (R24); they do not reach the diagnostics log either.
- Pub, npm and Gradle dependencies are raised by hand; native code no lockfile describes (SQLite, the Flutter engine, Cronet) is followed by hand (R26, [D97]).
- Not checked on an iOS device yet: the sensitive clipboard, the key in `host.json` and the extension's links, another account's notification tap ([threat-model.md §8.3](threat-model.md#83-final-ios-phase)).

## D67: AGPL-3.0-or-later with an app store permission, DCO, reserved brand, embedded Cronet

*Accepted 2026-10-27 (the licence step between steps 35 and 36), the owner's decision where marked; answers [Q3](open-questions.md#q3-licence-and-distribution). Superseded by [D87] for the licence, the contributions and the name and logo with step 38d, accepted 2026-11-16; the rest still holds, without the AGPL's reasons. The written offer's offerer and contact of step 38f were accepted 2026-11-17 ([D89]).*

The repository is under the MIT License, contributions follow Vikunja's rules without a sign-off, and the name and the logo are Vikunja's, under [D87]'s terms.

**Until step 38d** (superseded by [D87]; the owner's decisions of the AGPL period):
- AGPL-3.0-or-later for the whole repository (owner), with an additional permission under section 7 in `NOTICE.md` ("App stores"): distribution through an app store whose terms conflict with the AGPL, such as Apple's App Store, provided the Corresponding Source is also available under the AGPL through a channel without such restrictions (owner).
- Contributions under the Developer Certificate of Origin 1.1, every commit with a `Signed-off-by:`; contributors kept their copyright, and their contributions carried the same terms, the permission included (owner). No commit before the move carries a sign-off.
- The copyright line named the owner and the contributors of the app under its former name.
- The former name and its logo were not under the AGPL but reserved by the owner, and a fork that distributed an app had to use its own (owner). The app is now Vikunja with Vikunja's logo ([D15], [D42]), and no file is to name the former name ([D87]).

**What still holds:**
- F-Droid is not a distribution target: no flavour, the bundled SQLite stays (owner).
- Android ships embedded Cronet, never a Play services library (owner); the build and the reason are [D5]'s.
- Nothing of Vikunja's ships but its logo ([D42]): the app reads the web for behaviour and writes its own code and texts, error texts included ([D71]), and the editor keeps only what the stored HTML needs (node and attribute names, the task link's rank above the Link mark, the anchor, data attribute and attachment URL formats) (why: Vikunja's server and web are under the AGPL-3.0-or-later, which the MIT-licensed app cannot take in). Test files with Vikunja's test vectors stay AGPL-3.0-or-later and never ship; `NOTICE.md` lists them ([D87]) and covers the packages and the plugin. MIT, BSD, ISC and Apache material is attributed.

**What the app shows:**
- The About page, also for guests and signed out, shows the copyright, the MIT licence, no warranty, the licences, the source code and the terms for the name and the logo ([D87]; website rows [D76], [D77]).
- Only the release builds set the source link, to the tree at the release's tag ([D86], [D74]); a release-only test fails without it, and other builds say they have none. The repository is public before the first store release; the release build checks it and that the link opens signed out (why: every release links its source code for everyone).
- The licence page is Flutter's `LicensePage` in Flutter's own words ([D71]) with the app's legal assets: the app's notice beside the MIT `LICENSE`, the editor's npm packages, the code `vikunja_logic` translates (fexpr, go-datemath, prosemirror-model), the Material Icons font and three copied icon shapes (CC BY 4.0) and, on Android only, the Android libraries and the code of other projects in embedded Cronet.
  - The workspace root package is named `vikunja_app` (why: `vikunja` alone would read as the server); no workspace member may carry a `LICENSE` or `NOTICES` file, which would appear under an internal name.
  - The written offer for desugar_jdk_libs (GPL-2.0 with the Classpath exception, needed for flutter_local_notifications' desugaring) is made by the Vikunja project, for at least three years after a version was last distributed, ending "Ask the Vikunja project at hello@vikunja.io." ([D89]). Every GitHub release carries that library's source beside the APK ([D73]); Google Play and dl.vikunja.io, which get no source, rely on the offer.

**Notice generators** (`tool/build_editor.sh`, `tool/build_android_notices.py`, both with `--check` in CI) write the notices from what actually ships. The Android one refuses unknown Maven groups, Google Play services and any other `org.chromium.net` library, and adds what Cronet links statically without naming it (libc++, libc++abi, libunwind, Rust's standard library); `--refresh-cronet` takes Cronet's licence files only from AARs whose SHA-256 matches Google's Maven and from a Chrome stable release.

Limits:
- kolaente has yet to confirm the written offer in the Vikunja project's name and its contact ([D89], [beta.md](beta.md#what-kolaente-does)).
- image_picker_android's manifest still declares the disabled `com.google.android.gms.metadata.ModuleDependencies` service, a hint for Play services; it names no class in the app.

## D68: Screen readers: headings, one announcer, high contrast, Reduce Motion, route sweep

*Accepted 2026-10-28 (step 36a).*

- WCAG 2.2 AA is the internal yardstick, with the deviations below and no public conformance claim.
- **Headings:** level 1 for screen and sheet titles, app bar titles included; level 2 for section headers; the rich-text view keeps the description's h1–h6. Regions side by side each keep their level-1 title ([D70], [D82]).
  - Every app bar title is a `ScreenTitle`, whose level merges into the app bar's title node (why: two header flags never merge and would leave an empty level-0 header). Every other `header: true` names its `headingLevel`.
  - A heading never merges into a row and becomes its button. Two headings stay buttons: the Account tab's account header and the task sheet's title, which opens the edit page.
- **One announcer** (`features/common/presentation/announce.dart`) for every announcement: a platform announcement on iOS; on Android, whose engine reports no announce support, one polite live region above every sheet and dialog, hidden by the lock. There, an error already shown in a live region is spoken by the app's region only when its text stays the same (the same input submitted again).
- **High contrast:** high-contrast light and dark themes whenever the platform reports high contrast (iOS Increase Contrast, Android 14+'s Contrast at medium or high), for the brand scheme and the system colours.
- **Reduce Motion:** Android's Remove animations or iOS Reduce Motion, read from the platform at call time (why: `MediaQueryData` does not carry it), make the app's own animations jump (such as the board, the Android task sheet growing and Gantt's "Go to today").
- **Text size:** no global clamp; iOS text up to 3.12× (AX5, 53/17) works on the six core screens (the Overview, a project list, the task sheet, the edit page, the new-task sheet, the Account tab). App-bar text actions stop at 2.0×, as iOS's navigation-bar buttons do.
  - The navigation labels stay clamped, 1.15× on Android's bar ([D56]) and 1.3× on the iOS tab bar and the rail ([D45]); a long press shows the label as a tooltip or, past the clamp, at full size in the middle of the screen ([D100]).
- **Overdue** is not told by colour alone: an error icon instead of the calendar, as the widgets do, and the row says "Overdue, due …".
- **Gantt:** a row's label names the arrows the chart draws at both ends; the header reads today's date and the range. Widths are measured as drawn, bold under Bold Text ([D98]).
- **Refresh buttons** in the app bars of the session, API token and CalDAV lists (why: many screen-reader and switch users cannot pull to refresh).
- **The iOS tab bar's** inactive labels are `onSurfaceVariant` (why: Cupertino's grey stays below 4.5:1).
- **Strings:** new and changed ARB keys get a description, "Screen reader: " first for strings that are only spoken. A plural shows its number in a `one{…}` branch and has no `=1{…}` ([D88]). Some older messages still have no description.

**Deviations from WCAG 2.2 AA:**
- 1.4.4 Resize Text, below 200 %: the navigation labels above; the inbox badge ([D74]), the offline banner and Upcoming's date column (the rows carry the dates) at 1.3×, and from 1.5× it goes ([D117]); Upcoming's day strip and the Gantt header ([D61]) at 1.5×; avatar initials, reaction emoji and inline pills unscaled; Flutter's app bar title at 1.34×, ellipsized and spoken in full.
- 2.5.7 Dragging Movements: moving a card within its column, a task in a manually sorted list or a project among its siblings takes a drag or a screen reader's custom actions ([D47], [D49]). Single-pointer ways exist for a card's column (Move to column… in its task detail, [D84]), a column's place (Move left, Move right), a project's parent and a task's project (the edit pages).
- 1.4.11 Non-text Contrast: the light brand scheme's amber highlight (the star's fill, the high-priority flag) is about 1.82:1; it is supplementary (the star has a 6.18:1 outline, the flag stands beside the priority's name).
- 1.4.3 on iOS alerts: Apple's system blue and red measure 2.86–4.40:1 on the alert's material; under Increase Contrast the delete-task, sign-out and browser-hint alerts pass, while the insecure-connection alert's "Continue anyway" stays at 4.23:1.
- Platform target sizes (2.5.8's 24 × 24 is met): the Material date picker's day cells are 43.4 × 48 dp on a 360 dp phone, where Android asks for 48 dp; Cupertino's sliding segmented control keeps its native 28 pt, where Apple asks for 44 pt.
- Read-only selectable text, such as the server's message of the day, is skipped by both tap-target guidelines (2.5.8's inline exception; [D69]).
- Beyond AA, 2.3.3: under iOS Reduce Motion page and sheet transitions still slide, because the framework follows only `disableAnimations`; the board's settle after a fling follows the finger.
- Flutter's `LicensePage` marks its titles as headers at level 0 (1.3.1, 2.4.6); fixing it takes a licence page of our own.
- The sweep's distinct-tap-label check allows a sheet's barrier and its drag handle to share Material's dismiss label ("Dismiss"), as both close the sheet (3.2.4 holds; [D116]); a barrier with a label of its own does not pass.
- The sweep's distinct-tap-label check allows one repeat: on the Projects tab a favourite saved filter is listed in Favourites and again in Saved filters under the same name, as both rows open the same list (3.2.4 holds) and the section headings tell them apart.
- A new field error with a helper text may be spoken twice on Android, because Material builds it again when its fade-in ends.
- Colour-coded text inside merged labels is checked at scheme level only (4.5:1 for the text roles and for label pills over server colours, 3:1 for outline), for the brand and high-contrast schemes, light and dark; dynamic schemes are not checked.

**The guard, a route sweep** (`app/test/a11y/`, in CI's plain `flutter test`; [CONTRIBUTING.md](../CONTRIBUTING.md#rules-for-the-code)). No check is relaxed without a reason in the test and an entry among the deviations above.
- Every route needs a scenario, and every dialog, sheet, menu, picker and page route an overlay scenario or an exemption with its reason; a stale one fails.
- Each scenario runs light and dark, en and de, scrolled through, against the platform's tap-target guideline, labels, text contrast, heading levels 1 to 6, headings that are no controls and unique labels, in representative states (empty, error, offline, locked, a guest) and on tablets ([D69], [D70], [D82]).
- The six core screens run on iOS at 53/17 on 375 × 667 and 320 × 568; any exception fails.
- A source rule: every `header: true` names a `headingLevel` and the reverse; no announcement outside the announcer.

Limits:
- The manual TalkBack, Switch Access and VoiceOver pass is still open, planned for the device phase (owner, 2026-11-20); the Accessibility Scanner gave way to a scan of the real screens from `uiautomator` dumps ([D112]; [Q19](open-questions.md#q19-device-setup-for-the-manual-talkback-pass), [accessibility checklist](accessibility-checklist.md)). Open there: whether TalkBack speaks the live region reliably (right after a dialog closes, while it is speaking, a repeated message), board and list moves, a field error said twice, whether TalkBack enters the editor WebView, and real fonts.
- A few width decisions (the project view tabs, the trash page's tabs, the theme segments) are still measured without Bold Text.
- The widget setup page's preview is read line by line.
- Flutter's tap-target guideline skips nodes marked as links, and the sweep sees only what its scenarios show ([D112]).
- Tables in descriptions carry no row and column positions.

## D69: Large screens: a window-layout helper, readable widths, capped dialogs and sheets

*Accepted 2026-10-28 (step 36b).*

- **One window-layout helper** (`app/lib/app/layout/window_layout.dart`) holds every window threshold: Material 3's width classes (compact below 600 dp, medium 600–839, expanded from 840), compact height below 480, expanded height from 900, the panes ([D70], [D82]) and the gate below. The navigation rail stays from 600 dp ([D45]); the iPad keeps the bottom tab bar, with no sidebar. Widgets that size themselves read their own constraints, not the window.
- **The gate:** every cap applies only when the window is at least 480 dp high and either at least 840 dp wide or at least 900 dp high (why: every large phone in landscape is at least 840 dp wide but less than 480 dp high). Phones in either orientation are not capped.
- **Readable widths**, the cards' margins included:
  - **840 dp:** lists, such as the Overview, Upcoming, a project's List and Table views, search and the trash ([D79]); a project's tabs and controls too, so they do not move when the view changes.
  - **640 dp:** forms, sheets and settings pages, such as the Account tab's pages and task edit.
  - **560 dp:** dialogs (at least 280, Flutter's own).
  - **Their own caps:** the connect screen (480 dp), first sync, the notification setup and the lock screen (420 dp).
  - **The whole width:** app bars, the offline banner, the floating action buttons, the board, the Gantt timeline, the editors, the image viewer and Flutter's licence page.
  - **Snackbars:** at most 640 dp, centred in the scaffold that shows them ([D98]) (why: a snackbar then fits inside every band and lines up with the form cards).
  - Every route scenario of the sweep ([D68]) has its width class, and the sweep checks it.
- **How the band is made:** the content is centred inside a scroll view that keeps the whole width, so the margins scroll and the scrollbar and indicators stay at the window's edge; no scroll view sits in a `ConstrainedBox`, `Align` or `Center`. The wrappers stay in the tree with no inset while the gate is off, so a rotation across the gate keeps every screen's state.
- **Dialogs:** every Material dialog is 280–560 dp while the gate is on. The date and time pickers keep Flutter's own bounds through `pickerFormatsBuilder`, which every picker call uses (why: their landscape and large-text layouts need more than 560 dp). iOS alerts keep Cupertino's fixed width. Material bottom sheets keep M3's 640 dp.
- **iOS sheets** all open through `showReadableCupertinoSheet`: at most 640 pt, a centred card when at least 48 dp remain beside it, else the whole width (why: slivers of the page at the sides would look like a misplaced sheet). A tap beside the card closes it as a back would, so a `PopScope` keeps its guard; screen readers skip the area.
- **No golden images:** layouts are checked by geometry in widget tests (why: CI renders on Linux and development runs on macOS).
- **The sweep on tablets:** every scenario also runs on its platform's tablet in both orientations (Android 1280 × 800, iOS 1194 × 834), dark, en and de, with the width checks, and again at 200 % text.

Limits:
- Windows 600–839 dp wide and 480–899 dp high get no caps (an Android split screen in portrait, the Pixel Tablet's 50/50 split in landscape, an iPad's 2/3 split): their forms reach about 760 dp beside the rail and 839 pt on iOS, and their iOS sheets fill the window.
- With a task in the pane the shell's snackbar crosses the divider. A new narrower scaffold with its own snackbars needs its own snackbar width; nothing checks this.
- Pages over the shell, such as settings and search, cover the rail or the tab bar.
- The floating action buttons stay at the window's bottom right, beside the band, except New task on Android rail layouts, which is the rail's leading button ([D117]).
- The description and comment editors have no width of their own, and images in a description decode at the window's width.
- Not looked at on an iPad: the wheel popups as cards, an iPad mini or 11", Split View and Slide Over.

## D70: Task detail pane beside the list on two-pane windows, the sheet elsewhere

*Accepted 2026-10-28 (step 36c), the owner's decision where marked.*

- **When:** the detail ([D44]) opens in a pane beside the list (owner) when the window is two-pane (at least 840 dp wide and 480 dp high, [D69]), not in tabletop posture, and the task is opened from a screen inside a tab other than Account (the Overview, Upcoming, the smart lists, a project's views). Pages over the shell (search, the inbox, a label's tasks) and everything else keep the sheet, so phones and tablets in portrait below 840 dp do not change.
- **One pane per tab**, each with a stack of the tasks opened inside it, at most 10; a tab switch shows that tab's pane, or none.
- **Layout:** rail, list, a 1 dp divider, pane, all below every page over the shell. The pane takes 40 % of the content beside the rail, at least 360 and at most 480 dp; the list keeps the 840 dp band in what is left ([D82] puts the project tree first). Opening or closing the pane keeps the tabs' pages and scroll offsets. On a vertical fold or hinge the split sits on it when both sides keep 320 dp; a half-opened horizontal fold (tabletop) gives no pane.
- **The same detail** as the sheet: a related task or link opens inside the pane, with a back arrow to the task before; edit, pickers, dialogs and the image viewer open over the shell, with no navigator inside the pane. Delete removes the task from every tab's stack.
- **Selection:** the top task's row, card or timeline row is marked and reads as selected: a `surfaceContainerHighest` fill with a 4 dp `primary` bar on a row's start edge, a 2 dp `primary` outline on a card (why this fill: `secondaryContainer` fails in both high-contrast schemes).
- **Back**, for the button and the swipe alike: first what is over the shell or in the tab, then the task before in the pane, then the pane, then the tab's own pages, then [D45]'s tab rule.
- **Pages inside a tab have no predictive back preview on Android, at every size** (why: the predictive back detector took swipes for routes in covered or offstage navigators, which popped the wrong page on Android 14+ with gesture navigation). Pages over the shell keep the preview.
- **Resets:** a change of the active account closes every pane. A tab's pane closes when that tab's own location changes (another project, another smart list), a pop inside the tab included ([D116]), not for pages over the shell, another view of the same project or a list's filters; selecting the current tab again closes it. The app lock keeps the pane ([D64]).
- **Links, widget taps and notification taps** keep [D44]'s rules, then open the task in the Overview's pane when it fits and nothing covers the shell, else in a sheet.
- **Resize:** when the window stops being two-pane, the top task moves to a sheet with its comment draft; a sheet stays a sheet when the window grows.
- **Accessibility:** while the pane shows, list and pane are regions of their own, the list first; the pane's task title keeps its level-1 heading ([D68]). Nothing is announced. Focus moves into the pane on every open and change and back to the row last used on close.

Limits:
- Not checked on a device: back swipes with gesture navigation, the selected look in dark, a foldable, and TalkBack and VoiceOver with the pane ([Q19](open-questions.md#q19-device-setup-for-the-manual-talkback-pass)).
- An 11" iPad and an Android tablet in portrait keep the sheet.
- Back inside the pane restores only the scroll offset.
- Right to left is covered only by the tests of the split function and the highlight.
- With a page open in a hidden tab, the app tells Android that it handles back even on the Overview without a pane.
- Uncoloured label pills blend into the selected tint in the light brand scheme; their text keeps 7.28:1 on their own fill.
- No pane on pages over the shell, and no Esc for it yet (step 36d).

## D71: English and German: US base, glossary, error texts, live language changes

*Accepted 2026-10-29 (step 36e); US English since 2026-11-13 (owner, [D83]), accepted 2026-11-14 (step 38a); German through Crowdin and with Vikunja's German terms since step 38e, accepted 2026-11-16 (owner, [D88]); the store texts in US English since step 38f, accepted 2026-11-17 ([D89]).*

**Languages and wording:**
- The base language is US English, like the Vikunja web (owner), with `app_en.arb` as the template, for spelling and terms only (punctuation stays as the glossary has it), its descriptions included (they are the translators' context on Crowdin, [D88]), and the store texts ([D89]). Flutter's own licence page keeps Flutter's English. ARB keys, identifiers, comments, log strings and test names keep their British spelling (why: renaming keys touches hundreds of call sites for nothing a user sees). Tests fail on a British spelling in the English texts; there is no check of the former names (2026-11-20, owner) or of "unofficial" ([D114]).
- Contributors change only the English. German comes through Vikunja's Crowdin project like every other language, so it may lag the English on `main`, and a release needs it complete (owner, [D88]). A test checks each translation's keys, ICU and placeholders against the English.
- No web texts are copied ([D67]): error texts are written per code in our own words. This stands until kolaente agrees to pre-translating the app from the web's translations on Crowdin ([D88]).
- [glossary.md](glossary.md) sets the terms and style for both languages and the native strings, and a test checks its key German terms. Highlights:
  - German: du, „…“, erstellen, Gerät (never Handy), and Vikunja's own terms "Account" (never „Konto“) and „Anmeldename“ (never „Benutzername“), as in its German translation instructions (owner, [D88]). The field is „Fälligkeitsdatum“, but the detail sheet's row label stays the short „Fällig am“ for the narrow label column ([D77]).
  - The old app is "the previous app" („die bisherige App“), never old or legacy; the trash is the web's „Papierkorb“ ([D79]), subscriptions are „folgen“ ([D80]).
- The support details' text ([D20]) stays English in every app language, so reports compare.
- Texts change only when they are inconsistent, wrong, unclear or misspelt, never for taste.
- An API token's expiry reads "Last valid day", and the token expires at the end of that day. A link-share guest without a project to add tasks to is told that the shared link is read-only or the project archived ([D98]).

**Server errors:**
- Codes the app does not map show a localized sentence with the server's detail (why: for an unknown code the detail is the only clue).
- One shared function words four failures any action can meet: a guest link that is gone (checked first, as it extends the ended session), an ended session, rate limiting and a server failure; each screen's own arms still win. A 5xx without a body (a proxy's 502, 503 or 504) and a storage error without a code show the server-error text.
- Codes are mapped per path where they mean something specific there (such as 10007 for a board at the column limit, [D48]); for the task duplicate and the assignee search a 404 counts only when it is not a missing route.
- Filter errors: 4033 shows "too complex". 4016, 4017, 4019 and 4024 keep the server's detail, because they occur only when the server's parser disagrees with the app's.

**The language followed while the app runs:**
- On a locale change and on every resume, the UI follows the device's language or the per-app language without a restart, and so do notifications, widgets, the lock prompt and the app shortcut. Android reports both changes because the manifest handles `locale` in `configChanges`; iOS restarts the app instead.
- The locale is resolved as MaterialApp does, over the shipped languages only ([D88]), so the OS texts always match the UI; it carries the region of the device's first locale of that language ([D93]). Headless isolates resolve their texts once ([D39]).
- On a change both Android channels are created again under their ids, which renames them and keeps the user's settings; pending notifications are scheduled again in the new language.

**The App language row:**
- It opens the system's page (why: the system setting stays the one source of truth): on Android 13 and later the app's locale settings (through `android:localeConfig` and a `<queries>` entry), on iOS the app's page in Settings; hidden on Android 12 and older. Opening it is an excursion ([D64]); a failure is logged by its type only.
- It is the last row of the Account tab's Appearance section, after Theme and "Use system colors", with "On this device" under its subtitle (owner, [D75]).
- The account's language setting ([D54]) never changes the app's language.
- After the update from the old app ([D85]), its language override becomes the per-app language on Android 13 and later, only for a shipped language and only when the app has none yet, even when it equals the device's language (why: the old override pinned it too).

**Sorting and wrapping:**
- `compareTitles` sorts projects, labels, team members and the sort menu, folding case, accents and ß with stable tie-breaks. Its fold, `foldAccents`, includes the Romanian ș and ț and is shared by every on-device search ([D81]).
- At large text sizes, text wraps instead of being cut off.

Limits:
- On iOS the row may first open the Apps list of Settings, and the app's page reportedly shows Language only with more than one preferred language; both wait for the device test ([beta.md](beta.md)). iOS notification categories keep their texts until the app restarts.
- Android 12 and older have no row and follow the system language.
- The Projects tab's empty state can still invite a guest whose shared project is archived to create a project.
- Unmapped codes still show the server's English detail inside a localized sentence.
- The accent fold treats every language the same; it is no collation per language, which Swedish, for example, would need.

## D72: First release: Android and iOS together, Play and an APK, beta first

*Accepted 2026-10-29 (step 37), the owner's decision; the channels of step 38c, accepted 2026-11-16; the beta without a closed test of step 38f, accepted 2026-11-17.*

- Android and iOS reach 1.0.0 separately (owner, 2026-11-12): Android once its own checks pass; iOS stays in TestFlight until its device test passes, and both may still come out together if iOS is ready in time.
- Google Play, plus a signed APK for devices without Play in every GitHub release and on dl.vikunja.io, published from go-vikunja/app by GitHub Actions (owner, 2026-11-14; [D86]). No F-Droid ([D67]).
- The repository moves into go-vikunja/app with the import pull request of step 38d ([D83], [D87]). Until it is merged the repository is the app's earlier GitLab project, public and without CI; the owner then archives it with a pointer to go-vikunja/app.
- 1.0.0 comes after a beta: test builds are `1.0.0-beta.N` (Play's `beta` track, TestFlight, and GitHub releases marked as prereleases, [D86]), then `1.0.0` for everyone, on Play as a staged rollout.
  - Vikunja's listing is in production already ([D83]), so the closed test of at least 12 testers for 14 days that a new personal developer account needs does not apply, and the beta goes to Play's open testing track `beta` ([D89], [beta.md](beta.md)).
- iOS is tested only at the end of the project, not with each step (owner): in the simulator in the iOS phase ([D74]), then on a device before 1.0.0 ([beta.md](beta.md)).
- The release is step 37 on the [roadmap](roadmap.md) (owner): 37a release builds and GitLab CI, 37b the iOS phase, 37c store listings and policies, 37d beta and 1.0.0; 37e to 37h, for Vikunja 2.8.0, come before the first beta tag ([D78]).
- 36g comes before the first release and goes into the beta build (owner, [D82]). 36d comes after the first release; steps 33 and 36f are dropped ([roadmap](roadmap.md#dropped), [D88]).
- The repository prepares everything up to the work only the owner can do: accounts, keys, store records, testers, publication and the sign-offs. [beta.md](beta.md) lists that work in order.

## D73: CI from local scripts, versions from the tag, GitLab until the move

*Accepted 2026-10-29 (step 37a), the owner's decision where marked; the release channels are [D72]'s. Since step 38c, accepted 2026-11-16, GitHub Actions run the same scripts and publish the releases ([D86]). Step 38d, accepted 2026-11-16, deleted the GitLab pipeline (owner, 2026-11-16; [D87]), which supersedes this entry's GitLab parts.*

**The scripts:** the logic lives in `tool/ci/` and runs the same way on the owner's Mac and on GitHub Actions (bash 3.2 with `set -euo pipefail`, reading only the hosts' own variables and those named here and in [D86]). Only on GitHub-hosted runners do they install the pinned Flutter and set Gradle up, never on a developer's machine or a self-hosted runner.

**The jobs** (of the same names in [D86]'s workflow):
- `checks`: generated code, format, `tool/check_pure_dart_packages.sh`, the Android notices' and desugar source's checks, `flutter analyze` and every test but the contract tests; `flutter pub outdated` for information only.
- `editor` (Node 26.10.0, the owner's Node; `.nvmrc` stays `26`): `npm audit` of the shipped packages at high and above, as the OSV scan covers esbuild ([D97]), and the editor build's `--check`.
- `contract`: the contract tests against the server of `test_servers/docker-compose.yaml` ([D28], [D86], [D97]).
- `android`: the release APK with the debug key, since no key reaches it, then the exported-components check and the widgets' Kotlin tests.
- `osv`: the OSV scan of the three lockfiles, alone on the weekly schedule; it blocks on every finding except in the editor's test-only packages, which it reports ([D97]).
- `ios`: a release build without code signing, then the iOS notices and the required-reason API check.
- On a CI runner Gradle is capped at a 3 GB heap (why: the project's `gradle.properties` asks for 8 GB, more than a small runner has).

**The GitLab pipeline of step 37a** is gone with step 38d (owner, [D87]); the git history has it.

**Pins:** downloads are pinned by version and SHA-256 in `tool/ci/pins.sh`: Flutter 3.47.9 ([D1]) and osv-scanner 2.7.0. GitHub's hosted images cannot be pinned ([D86]). Outside CI the `flutter` on PATH is used; `flutter pub get --enforce-lockfile` always.

**Versions:** `tool/ci/release_version.py` turns `v1.2.3` or `v1.2.3-beta.4` into the build name and a build number: major·1,000,000 + minor·10,000 + patch·100 + n, where n is the beta number (1–98) or 99 for the final release, so every beta orders below its release and Play's limit of 2,100,000,000 holds ([D74] for iOS). Any other tag fails, and so does a pubspec whose version differs: the release commit bumps the pubspec. The publish script's Bash copy of the scheme is tested against it ([D110]). There are no product flavours: one application id serves Play and the APK.

**Signing in the Gradle build:** unsigned with `VIKUNJA_APP_UNSIGNED=true` (the release workflow signs afterwards, [D86]); else the gitignored `app/android/key.properties`; else the debug key, with a warning. A partial `key.properties` fails, naming no value; `.gitignore` also ignores `*.p12`, `*.pfx`, `*.pepk` and `*.keystore.b64`. The keys of distributed builds are [D86]'s; no distributed Android build is signed by Gradle or on a laptop. The iOS build is signed and uploaded from the owner's Mac ([D74]).

**The desugar_jdk_libs source** is attached to every release ([D86]) (why: a copy beside each release stays available whatever happens upstream). `tool/android_notices/desugar_jdk_libs.source` names its commit, as upstream has no 2.1.4 tag; `checks` compares the version with the Gradle build, the release build fetches that commit and checks its ids, and the notice says where the source is.

[releasing.md](releasing.md) is the release checklist; the threat model's R26, R28 and R34 cover CI, signing and Cronet.

**Runners:** GitHub-hosted runners ([D86]). iOS releases stay on the owner's Mac ([D74]).

Limits:
- The `android` job and the release build install NDK 28.2.13676358 from Google's SDK repository on every run, unpinned by the project.
- Anonymous Docker Hub pulls may hit its limits; a read-only token with a `docker login` in `tool/ci/contract.sh` is not built.
- The Linux and Windows builds of `aapt2` are trusted without a checksum until Gradle's verification metadata is written again on Linux ([D97]). Renovate is not used; the pub, npm and Gradle dependencies are raised by hand.

## D74: iOS phase: App Store prerequisites, TestFlight from the Mac, photo locations, capture cover

*Accepted 2026-11-02 (step 37b), the owner's decision where marked; the names, the source link and the CI check of step 38c, accepted 2026-11-16; the source link's single form of step 38d, accepted 2026-11-16; the German check of step 38e, accepted 2026-11-16.*

- The iOS share extension ("Share to Vikunja") comes after 1.0 (owner). Until then, iOS takes files only through the in-app pickers.
- On iOS, one-time secrets are covered while the screen is captured (recording, AirPlay or a mirrored display) (owner). Screenshots stay possible, and no undocumented secure-field trick is used.
- Photo and video locations are stripped before upload, and on Android too ([D76]) (owner).
- No Time Sensitive notifications: reminders keep the interruption level `active` (owner).

**App Store prerequisites:**
- Both targets have a privacy manifest declaring no tracking, no tracking domains and no collected data, since data leaves the device only for the server the user chose; crash reports to Vikunja's Sentry, once allowed, follow Apple's privacy label ([D113]); the plugins' own manifests are listed in [releasing.md](releasing.md#privacy-manifests). Required-reason APIs: file timestamp `C617.1` for both targets, user defaults `CA92.1` and system boot time `35F9.1` (Sentry's) for the app.
  - `tool/ci/required_reason_apis.py` checks every binary of the archive against its bundle's manifests, in the iOS release and the CI job `ios` (why: App Store Connect refuses an undeclared API, and a refused build uses up its build number).
- `ITSAppUsesNonExemptEncryption` is false: only standard, exempt encryption is used (HTTPS, TLS with pinning, PKCE).
- iOS uses the system SQLite; Android keeps the bundled build (why: the bundled build imports `statfs` and `fstatfs`, which no Apple reason fits, and Flutter cannot yet give a hook's framework a manifest). The app's SQL needs SQLite 3.30 (`NULLS LAST`) and uses no `RETURNING`, FTS or JSON functions; iOS 15, the oldest supported, ships 3.36.

**The iOS release:**
- The build name is the tag's `MAJOR.MINOR.PATCH`, since `CFBundleShortVersionString` takes nothing else, with the Android build number ([D73]).
- The owner runs TestFlight uploads by hand from the Mac with `tool/ci/ios_release.sh`. There is no CI job, because signing and the API key would have to live in a runner's macOS account (threat model R35) or in CI secrets; GitHub's job `ios` builds unsigned only ([D86]).
  - It refuses to run unless HEAD is the tag with a clean tree, Xcode and Flutter are the expected ones, the source link (`<repository>/tree/<tag>` of https://github.com/go-vikunja/app by default, [D86], [D87]) is https and opens signed out, the team and the App Store Connect key are set and readable by its owner only, German has every English text ([D88]; a patch release may pass without it, [D97]), and the 1024 icon is sRGB without alpha. The key's variables leave the environment before Flutter or Xcode runs ([releasing.md](releasing.md#ios-testflight-from-the-mac)).
- The iOS scripts unset `DEVELOPER_DIR` and require `xcode-select` to point into an Xcode app (why: the Dart native-asset hooks ignore `DEVELOPER_DIR`).
- `tool/ci/ios_notices.py` checks the built app's notices, frameworks (Sentry's among them, [D113]) and legal assets in the release and the job `ios` (why: Flutter skips a package without a licence file silently).

**In the app:**
- The Android 8.1+ themes name a transparent navigation bar and the launch's icons (why: Android 15 and later would otherwise force light icons).
- **Photo locations:** every photo and video from the app's picker and camera loses its location before it is handed on: an image loses its GPS tags in EXIF and XMP without encoding a JPEG or HEIC again (a PNG, which loses nothing, is), a video goes through a passthrough export filtered for sharing, and both are read back to check. A failure logs only its type. Pictures picked in Files lose their location too, other files stay untouched, and a file that kept its location is uploaded only after the user chooses Upload ([D97]). XCTests check the images ([D111]); videos and the camera stay manual, and the tests have not run on a simulator yet ([threat model 8.3](threat-model.md#83-final-ios-phase)).
- On iOS, library photos are named like camera shots, `IMG_<yyyyMMdd_HHmmss>.<ext>` at the time of the pick.
- "Save Image" asks only to add to Photos.
- **The capture cover:** while the screen is captured (the scene's capture state on iOS 17 and later, `UIScreen.isCaptured` below), one-time tokens and revealed secret fields are hidden with a note, and Copy still works. A secret also hides whenever the app leaves `resumed` and shows again only after a fresh answer on return, which covers the app switcher's snapshot; until iOS has answered it stays invisible. If the channel fails, the secret shows (why: a token shown only once must not be lost). Android keeps `FLAG_SECURE`.
- The inbox bell's badge grows only up to 1.3× text size ([D68]); its label speaks the count.

Limits:
- Not yet checked on a device or with the Apple account (the device test in [beta.md](beta.md)): signing, App Store Connect processing a build (the real test of the manifests), a real recording, the camera, BGTaskScheduler, iOS 15 to 17, signed-in online flows, the accessibility settings, Universal Clipboard, a restored backup; the rest is in [D23], [D63] to [D66], [D68] and [D69].
- Until the import into go-vikunja/app is merged ([D87]), a real iOS release needs `VIKUNJA_APP_SOURCE_CODE_URL` set to a public repository that has the tag.
- The job `ios` runs on GitHub's image `xcode-27`, the major version of the owner's releases (27.2 on the Mac), not yet tried; by its later changelog the held `image_picker_ios` 0.8.13+10 fails to compile with Xcode 27, though it built with 27.1 ([D97]).
- The three held iOS plugins stay pinned until the iOS device test ([releasing.md](releasing.md#held-ios-plugins)).
- Not built: iOS 27's extra-large portrait widget; the app's own TLS through `connectionFactory` stays a reserve of [D65].

## D75: Owner's UI review: no task identifier, coloured folders, new-task sheet, Account tab

*Accepted 2026-11-02 (the owner's UI review), the owner's decision where marked.*

**Task identifiers:**
- No task identifier (`WORK-3`, `#12`) is shown or spoken anywhere (owner), from rows and the detail to notifications and the widgets. Asked again for the task detail in step 40f, the owner kept this (2026-11-18, [D95]). Copy link and Share carry the database id in the web's address ([D84]).
- Every functional use stays: deep links such as `task/WORK-3`, the search by `#12` and `PROJ-12`, quick add's `+project`, filters and logs. The Table has no "Number" column or sort; its default sort, by the hidden index, reads "Default (newest first)" ([D61]).
- **The detail header:** the task's project chip with its parents takes the identifier's old place (owner), never cut off. Open or Done is a small line under the title; the task's colour dot stands before the title, so it does not read as the project's colour.
- The close button is "Close details" (why: a plain „Schließen“ would duplicate the drag handle's label, and "Close task" would read as marking the task done).

**Projects:**
- Every project shows as a small folder tinted with its colour, or `onSurfaceVariant` without one (owner), wherever a project appears, the native widgets included (the `folder` symbol on iOS). A colour dot stays for a task's own colour.
- A checked "Show saved filters" item sits in the Projects tab's menu, between "New saved filter" and "Show archived projects". It is on by default and not offered to guests (owner), and stored per account; off, the tab shows no saved filters, not even among the favourites.
- The review chose no remembered view (owner), a project opening on its default view every time ([D45]). Reversed by the owner on 2026-11-18: a project opens on the view it was last left in, per account ([D95]).

**The new-task sheet:**
- In order: the headline, the title, the Quick Add preview, the project, then the due date and the priority as two rows of chips (owner). The headline's row ends in the pin "Keep open after adding" ([D95]), off by default; with it on, an add empties the title and the description and keeps the rest (why a mode: Enter adds, so only a mode lets the keyboard add task after task).
- Each row is one line that scrolls sideways, with its heading above the chips (owner); on a 360 × 740 phone at 1.0 text both stay in view with the keyboard up.
- Due date: Today, Tomorrow, Next week, a chip for another date, and "Pick date…". The chosen shortcut shows the time the due date gets, for example "Tomorrow at 9:00 AM" ("{label} at {time}") (owner); one not chosen shows its day ("Next week · Sat, Nov 28") (owner, 2026-11-22, [D117]). Priority: Low to Do now (1 to 5).
- The title field is [D38]'s composer, without a prefix toolbar and with its help behind `?` (owner).
- The sheet sets a priority in every mode, as a fallback like the due date, and a line's own `!n` wins (owner, [D38]).
- "More options" expands the sheet in place and reads "Fewer options" while open (owner). It adds a Description, Labels, Reminders and Repeat; with several pasted lines every task gets them ([D38]). Nothing is created before Add, new labels included, so a dismissed sheet leaves nothing on the server.
- While the keyboard is hidden, the sheet's bottom clears Android's navigation bar and the iOS home indicator. While it shows, the bottom clears the keyboard (owner).
- **Leaving** with a title or description typed asks "Discard the new task?" on every way out ([D91], [D98]).

**The Account tab:**
- One Appearance section holds the rows Theme, "Use system colors" (Android 12 and later) and App language ([D71]) (owner). The Account settings page has no Appearance section.
  - Theme („Design“) is the device's theme ([D45]), with Light, Dark and System segments, a sliding segmented control on iOS (owner, 2026-11-13); it works offline and for guests.
  - Each row has "On this device" („Auf diesem Gerät“) in a small line under its title (owner, 2026-11-13). The section has no mark of its own and no hint pointing to the account settings.
- The tab's order is (owner): the banners, the header and the notes; Account settings, Organize and Accounts; Sync (the last sync or its phase, a failure's explanation, the background line, Sync now, Full resync, Pending changes, Sync problems); Home screen, Notifications, Privacy and Appearance; Server (the Vikunja version, Connection, the server's notices); Sign out and the version line, labelled "About, help and privacy" ([D117]).

Limits:
- While a quick-add token is typed, the suggestions strip leaves about 220 dp at 360 × 740 with the keyboard up, so the priority row scrolls under it; a very long line or a typed date's chip does the same.
- While `!n` locks the priority, the row does not scroll to its selected chip.
- At 200 % text with a long title, the help button can scroll out of view with the field.

## D76: Store listings and policies, the app's pages, photo locations removed on Android

*Accepted 2026-11-02 (step 37c), the owner's decision where marked; the name since step 38a, accepted 2026-11-14; the pages on vikunja.io, the listing's languages, the contacts and the Data safety answers of step 38f, accepted 2026-11-17 ([D89]).*

**The stores:**
- The name is "Vikunja" in both stores and both languages, the official app's ([D15], [D83]); no text calls the app unofficial. The descriptions and the review notes say that the app has no server of its own and talks only to the servers the user adds, apart from the crash reports the user allows ([D113]). The keywords leave out "Vikunja", which the stores index with the name; another app's or company's name stays out of the name fields and the keywords.
- The reviewers use the public demo `try.vikunja.io` through "Try the public demo", with the shared account `demo` / `demo` (owner; answers [Q21](open-questions.md#q21-a-server-for-the-store-reviewers)). The credentials stand in App Review's sign-in fields, never in the notes, as Apple asks; the notes lead through the demo and the offline use, ask the reviewers not to delete the shared account, carry the App Transport Security justification ([D8]) naming both questions before `http`, and say that only the shared demo account is open to every visitor ([D97]). Play's App access carries the demo's instructions.
- Play's Data safety is answered cautiously (owner), because Play counts every transmission off the device as collection, with no exception for a server the user chooses. It declares the union of the old app's answers and the app's own (owner, [D89]), because Play judges the form over every version it distributes until the old app is gone:
  - name, user ids, photos and videos, files, in-app messages and other user content: collected, not shared, for app functionality; from the old app's answers also the email address, and account management as a further purpose of the name, the email address and the user ids;
  - crash logs, diagnostics and other app performance data: collected, not shared, optional, for analytics, for the old app's Sentry reports and the app's opt-in ones ([D113]);
  - no location (owner): the app has no location permission and never reads the device's location, and a location left in an attachment is part of the content the user chose, declared with it;
  - data encrypted in transit "No", because plain `http` can be allowed after the user's consent ([D8], [D65]), and Google allows "Yes" only if it always holds (owner, step 38f; the old app's answer was "Yes");
  - deletion on request "Yes", with the help page's section "Delete your account" as the deletion URL.
- Apple's privacy label is open until the Apple account is decided ([D89]): "Data Not Collected" may no longer hold with Vikunja as the publisher, as Apple counts data the developer or its partners can access, and Vikunja also runs `try.vikunja.io` and Vikunja Cloud. A build with crash reports declares Crash Data and Other Diagnostic Data, not linked and not for tracking, whatever the account ([D113], [store-listing.md](store-listing.md#app-store-connect)).
- No exact-alarm declaration ([store-listing.md](store-listing.md#app-content)): Play's is for `USE_EXACT_ALARM`, which the app never declares, not for the user-granted `SCHEDULE_EXACT_ALARM`. No foreground-service declaration: workmanager's type `shortService` needs none.
- The trader status under the EU's Digital Services Act is the publishing account's: on Play Vikunja's, at Apple that of the account still to be decided ([D83]). Until step 38f a non-trader declaration was planned for an account of the owner's (owner).
- Target audience 18 and over; rated for all ages with "Users interact" (PEGI 3, USK 0, ESRB Everyone; Apple 4+); every country and region except mainland China; free, without ads or purchases; "Create account" kept on Play, with the deletion steps on the help page.
- Listings in US English (the default) and German, in the glossary's terms ([D71], [D89]); Play may machine-translate the rest, and the store texts are not on Crowdin. [store-listing.md](store-listing.md) holds every console form with its answer and source, and the [open points](store-listing.md#open-points).

**Listings and screenshots:**
- The listings are files under `fastlane/metadata/`, copied into the consoles by hand; fastlane is not run. Every feature named is in the app on that platform. The copyright is "2026 Vikunja and contributors" ([D87]). Play's short description is kolaente's, and the App Store subtitle is ours (owner, step 38f). `tool/check_store_metadata.py`, run in `checks`, enforces these rules and the stores' limits.
- Screenshots come from an emulator or a simulator, never a device, on Android in a 16:9 window (why: Play takes no side longer than twice the other) and from a Google Play system image (why: an AOSP image lacks Custom Tabs for the sign-in), on dedicated emulators (owner, [D89]). The tablet has four, because Google promotes an app on large screens only with at least four. The App Store's sets wait for the 1.0.0 submission; TestFlight needs none.
- The graphics come from the existing icons only ([D42]); the feature graphic has no text, so one serves both languages.

**The app's pages** are on vikunja.io, in go-vikunja/website, where kolaente publishes them from [vikunja-io-drafts.md](vikunja-io-drafts.md) ([D89]); English only, so each address serves every language. The addresses must not change once they are in the stores ([store-listing.md](store-listing.md#the-website)):
- privacy `https://vikunja.io/privacy/#mobile-app` (the stores link the whole policy, `https://vikunja.io/privacy/`); legal notice `https://vikunja.io/imprint/`; help and support `https://vikunja.io/help/mobile` (why not `/support`: it is about supporting the project), with Play's deletion URL at `#delete-your-account`; security `https://vikunja.io/security/` and [SECURITY.md](../SECURITY.md).
- Contacts without a person's name: `hello@vikunja.io` in public and for the written source offer ([D67]); `security@vikunja.io` and GitHub's private vulnerability reporting for security; for App Review and the testers an address kolaente sets up for the maintainers, `hello@vikunja.io` until then.
- The privacy section says: no server of the app's own, no analytics, ads or tracking, crash reports only if the user allows them ([D113]); apart from those, data goes only to the servers the user adds, a server named in a link the user opens, or `try.vikunja.io`, and reaches Vikunja only on a server Vikunja runs or through allowed crash reports. It also says which files keep their location. The help page says never to report a bug with a password or a token.
- The About page's section "Help, privacy and legal notice" holds the help row ([D77]), "Privacy policy" and "Legal notice", each opening its page above in the browser, the same in every build and language. Delete account shows on every server, as both stores ask ([D55]).

**Photo and video locations on Android** (owner; `LocationRemoval.kt`):
- Every photo and video from the app's picker and camera goes through the removal, as on iOS ([D74]), and so does every copy of a file shared to the app, before the copy is ready, whatever type the other app gave. Pictures picked as files lose their location too, other files go up unchanged (owner, 2026-11-18, [D97]).
- As Android's MediaProvider does for apps without `ACCESS_MEDIA_LOCATION`, the location is blanked in place, byte for byte, and a file without a location is never written to; nothing is re-encoded or remuxed, so a video keeps all its tracks. Only a JPEG's, PNG's or WebP's Exif is written again, by ExifInterface, into a copy that replaces the file only once written (why: ExifInterface writes over the file it reads, so an error would leave it cut short); this drops tags it does not know and moves the maker note. The app's own reader then blanks the GPS left in Exif, XMP and the location boxes of JPEG, PNG, WebP, HEIF, AVIF, TIFF-based raw, RAF, CR3, JPEG XL, MP4, 3GP and QuickTime, not trusting ExifInterface's offsets (why: they are off for unexpected GPS types and some WebPs, and ExifInterface reads HEIF only from Android 9, AVIF from 12). The result is read back.
- The removal fails open, as on iOS: a file that keeps its location is still handed on, with whatever could be blanked blanked, but marked: a picked file goes only when the user chooses Upload in "Upload with location?", and a shared file's row says so and Create or Add asks the same question (owner, 2026-11-18, [D97]). Kotlin logs only "A location stays in a file"; the app's log adds the reason, never the path.

Limits:
- Where the location stays, unreported: place names and country codes (XMP, IPTC, Samsung's fields); GPS in maker notes; anything after a JPEG's first image (multi-picture images, an Ultra HDR gain map, a motion photo's video, the likeliest case); PNG's raw profile chunks, XMP in UTF-16 or after broken markup; a GPS directory outside IFD0's chain or past its eighth IFD; unusual HEIFs (a misplaced Exif offset, no HEIF brand, image sequences); CR3 GPS outside `CMT4`; GIF, BMP, JPEG 2000, BigTIFF, WebM, MKV and AVI; a photo inside another file, such as a PDF; in a video a GPS track (`gpmd`, CAMM), a dashcam's GPS data in `mdat`, boxes deeper than 8 levels or after a broken size, Apple keys without "location" in their name and `©xyz` outside `udta` and `ilst` (the read-back reports some of these).
- Reported as kept: compressed XMP with GPS (only zlib is read), compressed PNG text named after a GPS property, a JPEG XL `brob` box, a GPS value over 64 KiB, an XMP packet over 64 MiB, a HEIF item `iloc` does not place, more than 100,000 boxes, an Apple `keys` box over 1 MiB, GPS in a RW2's embedded JPEG; a HEIF `infe` or `iloc` box over 64 MiB stops the removal before it blanks anything. A GPS value ExifInterface misreads onto other bytes that are not zero is also reported as kept.
- Blanked, not removed: outside a JPEG, PNG or WebP written again the GPS fields stay as zeros, which some apps read as 0° N, 0° E, and AVFoundation lists an empty location for a cleaned QuickTime video. The video check trusts `MediaMetadataRetriever`: an error it throws counts as no location.
- The public demo is reset at irregular intervals; if it is down or its account changed during a review, the review fails. A reviewer cannot finish deleting the shared account (the confirmation goes to its email), and whether Apple accepts that for 5.1.1(v) is open. The fallback is a review server of the owner's, with a review account seeded by `tool/seed_demo_data.py`.
- A moved page or a renamed heading ("Mobile app", "Delete your account") or slug in go-vikunja/website breaks the stores' addresses and the About page's links unnoticed between releases (the release scripts refuse a release while one of them does not open, [D90]). Until kolaente publishes the drafts, the addresses lead to pages that do not exist yet ([D89]).
- Not legal advice: the privacy section and the imprint's scope are for kolaente to confirm, as vikunja.io's policy names Vikunja's controller ([D89]); no fixed period for deleting support emails or the testers' list; the trader status is a legal judgment.
- Announced by Google for 2027, both left to the owner after 1.0: from April an app with a sign-in has to restore it on a new device, which would reverse keeping the tokens on their device ([D66]); from 2027-08-25 an app targeting API 37 needs `ACCESS_LOCAL_NETWORK` and a Play declaration for servers on the local network. So `targetSdk = 36` stands in `build.gradle.kts` instead of Flutter's default, which could bring API 37 unnoticed, checked by a test ([D97]).

## D77: Beta preparation: new app id, own signing key, public group, testers

*In review since 2026-11-02 (step 37d, first part), the owner's decision where marked; the testers, the help page and the feedback addresses of step 38f, accepted 2026-11-17 ([D89]).*

- The beta's runbook is [beta.md](beta.md).
- **Every project of the GitLab group `coderoftime` becomes public** (owner), because GitLab for Open Source takes only groups whose projects are all public under an OSI-approved licence ([Q22](open-questions.md#q22-ci-runners-on-gitlab)); the app, without a GitLab pipeline, no longer needs it ([D87]). The owner archives the app's earlier GitLab project with a pointer to go-vikunja/app once the import is merged ([D83], [D87]); its history goes over without a rewrite. iOS builds stay on the owner's Mac, by hand ([D74]).
- **Signing:** [Q20](open-questions.md#q20-signing-keys-and-the-apk-beside-the-play-build)'s option A (owner), an app signing key only the owner holds with a separate upload key, no longer applies, as the app ships in Vikunja's listing ([D83]): Vikunja's upload key signs the bundles and, without a separate APK key, the APK ([D86]).
- **The application id** is `io.vikunja.app` ([D15]); the server has no client registry.
- **The About page's row "Help and bug reports"** („Hilfe und Fehler melden“, the owner's words), first under "Help, privacy and legal notice" ([D76]), opens `https://vikunja.io/help/mobile` in every language ([D89]), so that testers and users find how to report a bug (owner).
- **The beta's testers** (owner): Play's open testing track `beta` ([D86]) and a public TestFlight link, with their own Vikunja server (2.3.0 or newer, [D13]) or the demo `try.vikunja.io`. No closed test of 12 testers for 14 days, which only a new personal account needs: `io.vikunja.app` is in production, so Play's open testing takes the beta ([D72], [D89]). Feedback goes to an address kolaente sets up for the maintainers (`hello@vikunja.io` until then) and to GitHub issues.
- **The threat model is signed off before the first beta tag and again before 1.0.0,** because the beta is public: each `v*` tag publishes a signed APK as a GitHub release (a beta as a prerelease) and on dl.vikunja.io ([D86]), and anyone can join TestFlight and Play's open test. Before `v1.0.0-beta.1` [threat model](threat-model.md) sections 8.1 and 8.2 run, with the emulator check of R33's fix, and the owner signs 8.4; 8.3 waits for the device test. Before 1.0.0 the owner signs again, with 8.1, 8.2 for what changed and 8.3.
- **Security reports go privately** to security@vikunja.io or through GitHub's private vulnerability reporting on go-vikunja/app, never in a public issue ([SECURITY.md](../SECURITY.md), [D87]); the vikunja.io help page says so too ([D89]).
- **The French encryption declaration** ([Q23](open-questions.md#q23-french-encryption-declaration-for-the-app-store)) is settled before the App Store release in France.
- **App Store Connect's Accessibility Nutrition Labels stay blank** until the device and screen-reader passes ([Q19](open-questions.md#q19-device-setup-for-the-manual-talkback-pass)) confirm what can be claimed.
- **Versions:** Flutter as [D1] pins it; the build number comes from the tag ([D73]). Vikunja 2.7.1's changes are in the entries they concern ([D48], [D53], [D55]).
- The task detail's attribute card stacks its rows when the longest name leaves its value too little room.

Limits:
- A leaked key of Vikunja's can move the APK's installs to another key only through APK signature rotation (Android 9 and later), which the release scripts do not support.
- Not known whether Play signs Vikunja's listing with the upload key's certificate, and so whether Play's installs and the APK update each other ([Q20](open-questions.md#q20-signing-keys-and-the-apk-beside-the-play-build)).

## D78: Vikunja 2.8.0: trash codes as gone, its limits, no NUL, `/info` re-read

*Accepted 2026-11-10 (step 37e).*

- **The app follows Vikunja 2.8.0** (owner): the trash in [D79], reminders as the server sends them in [D80], every legal link, the Okabe–Ito palette, the trash's token permissions, the lockout hint, subtasks expanded once and accent-free search in [D81].
- **The test servers run 2.8.0** ([D28]); the contract tests gate changed answers on the server version.
- **Gone stays gone:** a task is gone on 4002 or 4040 (in the trash), a project on 3001 or 3018 (anything in a project in the trash), wherever the app matches 4002 or 3001. Deletes complete on either code, queued ones in the outbox too; [D41]'s relation rules take both codes; failure texts say that the task or project no longer exists, and "in the trash" only where the user acts on the trashed thing ([D79]).
- **The server's limits hold on every server version,** because they are far beyond use and one rule keeps the outbox from producing a refusal anywhere:
  - titles at most 1000 code points: the title fields stop there and a longer text can only get shorter; while a changed title is too long Save is off, with a counter from 50 left; a stored longer title stays until changed;
  - text in bulk (shared text, Quick Add's lines) is cut at the last space that fits and the rest starts the description, so nothing is lost; a web address the cut would split moves whole into the description, and the title is the text before it or the address's host;
  - at most 100 reminders: the add-reminder chip is off at 100, and Quick Add stops the sheet's and the default reminders there;
  - the filter parser refuses business-day offsets above 10000 in all with the server's 4019, so the device never shows tasks for a filter the server refuses.
- **U+0000 is removed from every JSON write** once, in the write transport, nested values and keys included, because 2.8.0 refuses such a body with 400. The outbox's recovery of a lost create answer, its description check and the label lookup compare without it, and a label is created with the cleaned title, so a pasted NUL neither duplicates a task or label nor fails a write for good.
- **The server's `/info` is read again while signed in** (owner), for the active account in the foreground only: when it is first in front after the app starts, then at most every 6 hours, and 5 minutes after a probe that did not reach the server. An answer from another root or an unsupported server is not stored, and an API version the account has is never dropped, only added (why: a timed-out `/api/v1/info` would otherwise move attachment previews to v2). A changed answer is stored, so the Account tab shows the new version, notices and legal links; a changed server or API version rebuilds the account's API clients and sync engine, as a new sign-in does.
- **Legal links** (a web address with a host, and a text) are stored with the connection, built from the two deprecated fields on servers before 2.8.0; two texts at one address are both kept, only an exact repeat goes. The imprint and the privacy policy also come from a link named exactly "Imprint" or "Privacy Policy"; [D81] says how they are shown.
- **Quick Add takes the web's new phrases** (owner), while punctuation after a phrase still ends it ([D38], point 9).

Limits:
- A paste over 1000 code points into a single title field is cut without moving the rest.
- U+0000 stays in multipart uploads, a link share's password and an invitation token.
- The local filter compiler's saved-filter branch, which only tests use, gives each filter its own business-day budget.

## D79: The trash of Vikunja 2.8.0: Undo, queued deletes, a trash page

*Accepted 2026-11-10 (step 37f), the owner's decision where marked; the English texts say "trash" since step 38a, accepted 2026-11-14.*

The server's behaviour is in [research/trash.md](research/trash.md): trash routes on `/api/v2` only, from 2.8.0, with no flag in `/info`; 30 days, purged hourly; writers see and restore trashed tasks, only project admins purge, empty and see trashed projects.

- **The trash needs API v2 and 2.8.0 or newer** (development builds included, a version the app cannot parse not). Link-share guests have it too, since a write guest may restore by id, so Undo works for them; the trash page is for users only.
- **Terms:** "trash", as on the web ([D71]), German „Papierkorb“; "Delete forever" also for the server's purge, never "for good".
- **The delete confirmations stay, with trash wording,** on servers with the trash (owner; the 2.8.0 web dropped the task confirmation): the item moves to the trash for everyone and can be restored for 30 days. A task whose create the server never got or refused says it "won't be in the trash"; one whose create may have reached the server promises nothing either way ([D98]). A default project inside a deleted project stops being the default, even after a restore. Older servers keep the old texts; Delete stays hidden for archived projects and the default project.
- **Undo only on servers with the trash** (owner), for users and write guests, because elsewhere a delete cannot be taken back once sent: for 10 s, as on the web, and under a screen reader until used or closed. Older servers keep "Task deleted" without Undo.
- **A delete is queued like any other op, on every server,** so Undo can take it back ([D34]; for unsent creates [D35]). Undo takes a queued delete out of the queue without a request; a delete that may have reached the server is restored there too (`POST /api/v2/tasks/{id}/restore`, `/api/v2/projects/{id}/restore`; a live task answers 4042), and a delete in flight is waited for, at most 30 s. What a project delete purged locally stays purged.
- **The trash page** (owner; closed to guests): a row Trash in the Account tab's Organize section on servers with the trash, an 840 dp screen ([D69]); tabs Tasks and Projects, each read whole ([D27], [D96]), online only. Rows show who deleted what and when and the days until it is deleted forever, with Restore and Delete forever (which asks first; for a task only with `can_delete_permanently`). Empty trash asks with the count and includes what others moved there, as the web's default does; tasks that are not the user's to delete stay, as only project admins can delete these forever. Each action's failure has its own text (an archived project: 3008).
- **A link or notification to a task in the trash** says that the task (4040) or its project (3018) is in the trash, instead of "not found", and offers Restore to a signed-in user with `can_restore` (never a guest, as on the web). The inbox's "task deleted" entry reads the task from the server first, so a stale row is not opened (offline or on 4002: "This task was deleted").
- **"In the trash" only where the user acts on the trashed thing** (the opener, the inbox, the sync problems, the project identifier error, as a trashed project keeps its identifier for 30 days); every other failure text says "no longer exists" ([D78]).
- **30 days is a constant**; the days left round up and stay between 0 and 30, also with a device clock behind the server.
- No grouping, sorting or search in the trash.

Limits:
- The trash lists stop after 200 pages, 10,000 items at the server's default page size, and only the diagnostics log says so ([D96]).
- An action on the trash page answered by a proxy's bare 404 says "This server doesn't support the trash".
- An item can show "today" for up to an hour after its 30 days, until the server's hourly purge.

## D80: Reminders follow subscriptions on Vikunja 2.8.0 and later

*Accepted 2026-11-10 (step 37g), the owner's decision where marked.*

The server's behaviour is in [research/subscriptions.md](research/subscriptions.md): 2.8.0 reminds only a task's resolved subscribers (the user's own row on the task, else on its project, else on the nearest ancestor; an opt-out drops the user); it subscribes creators and new assignees on its own, and the upgrade subscribed every creator and assignee. For tasks only single reads carry the state, and a follow change is invisible to a sync.

- **The gate is the server version alone:** 2.8.0 or newer on any API version (development builds included, a version the app cannot parse not), because the server routes reminders whatever API the app speaks and the v1 reads carry the state too.
- **Older servers and link-share guests keep [D17]:** 2.7.1 reminds creators and assignees whatever they follow, and a guest cannot follow (403 code 1).
- **One rule for reminders and due dates:** on these servers both notify about the tasks the user follows, and unfollowing a task silences it on the phone too (owner), as it has to silence the due-date alarm as well, and the server's overdue e-mail goes to the same subscribers. Following a project brings the notifications of all its tasks, subprojects included; a project owner gets none for other people's tasks unless following them.
- **What is stored, without extra requests:** per project, which project's subscription covers it, from every project list; per task, the user's own row as last learnt from the task's details reads and the bell's reads: a read naming the task stores subscribed; one naming a project stores none (none while assigned for an assignee); one saying none stores opted out while the task's project is followed here, else none (or none while assigned), as an old opt-out cannot be told apart. Syncs and write answers never overwrite it, and a failure to record never fails the read.
- **When a task notifies:**

  | Stored | The task's reminders and due date reach the user when |
  |---|---|
  | (a temporary id) | always: the user created it |
  | unknown | the user created it, is an assignee or follows its project, as the server and its upgrade subscribe creators and assignees |
  | subscribed | always |
  | none | the user follows its project, or is an assignee now (the server subscribes a new assignee without an own row) |
  | none while assigned | the user follows its project |
  | opted out | never: the server keeps an opt-out through assignments and project changes |

  Done tasks and tasks queued for deletion stay out.
- **The bell and the project menu stay online-only** ([D41]). An unfollow that went through is recorded before its read-back, so a failed read-back does not keep the task ringing; a follow waits for its read-back, as it may have been a 412 through a parent.
- Every isolate plans alike, and a refreshed `/info` that turns the gate on or off ([D78]) plans again at once. The database upgrade forces no full sync: every task starts unknown, the state the server's upgrade left.
- **Texts** ([glossary](glossary.md): following): on 2.8.0 and later the notification setup says "Only for tasks you follow — you automatically follow the ones you create or are assigned to", and the Account tab that unfollowing a task stops its notifications. The help page drafted for vikunja.io says that on 2.8.0 and later reminders come for the tasks the user follows ([vikunja-io-drafts.md](vikunja-io-drafts.md#the-help-page)).

Limits:
- A follow change made on the web reaches the phone only with the next read of the task in the app (a project's with the next sync); until then the phone may ring once more or stay silent.
- Ex-assignees: the server keeps reminding them; the phone stops, unless the task was read while the user followed it.
- Unfollowed while assigned, then unassigned and assigned again: the server follows the user again, the phone stays silent until the next read.
- A read made before the sync brought an assignment records the wrong assignee flag until the task is read again.
- A read while the stored follow state of the task's project is out of date (changed on the web before the next sync) records none or opted out wrongly, so the phone rings or stays silent unlike the server until the task is read again.
- An old opt-out read while its project was not followed counts as none: when the project is followed again, the phone rings and the server does not.
- Inactive accounts on an upgraded server keep [D17] until they are active once and their `/info` is read again.
- A task restored from the trash starts unknown again.
- Large followed projects bring many notifications; the window still holds the soonest 100 (Android) or, on iOS, an even share of 60 less one place per account ([D94]).
- Not built: the bell's stored state shown offline, the project menu seeded from the stored state.

## D81: Vikunja 2.8.0 details: legal links, Okabe–Ito colours, lockout hints, subtask tree, accents

*Accepted 2026-11-10 (step 37h), the owner's decision where marked.*

**Legal links:**
- Every legal link the server lists shows (owner), in the server's order, when it has a text and an http or https address with a host, on the server overview and in the Account tab's Server section ([D78]).
- The exact texts "Imprint" and "Privacy Policy", case-sensitive as on the web, show in the app's words; every other text as its admin wrote it, untranslated (owner). Two links that then read the same at one address show as one button.
- The test server lists a further link (owner): "Terms of Service" at `https://example.org/terms`, in `test_servers/docker-compose.yaml`, for the TLS server too.

**Colours:**
- Every colour row offers the Okabe–Ito palette (owner): the seven colours of Okabe and Ito's "Color Universal Design" (J\*FLY, 2002, revised 2008) in its order without black, `e69f00`, `56b4e9`, `009e73`, `f0e442`, `0072b2`, `d55e00`, `cc79a7` (why no black: a black label or folder disappears in the dark theme). Folders and colour dots are drawn lighter or darker where a colour would fall below 3:1; the stored value stays the palette's ([D117]).
- The rows for tasks, projects and labels offer them after "No color"; a colour set elsewhere still shows as chosen and can be chosen again until the page is left (owner: colours already set stay). A new label gets one of the seven at random. Screen readers name the seven, any other colour as "Color #hex" ([D98]).

**API token presets:** on 2.8.0 they include the trash's permissions as the web's do (owner; [D55]).

**Lockout hints:**
- Vikunja 2.8.0 locks a local account at the tenth wrong password since the last successful sign-in (at sign-in, at the web's prompts or from a CalDAV app, on any device), ends every session, and keeps it locked until a password reset or an admin lifts it. The hints show on 2.8.0 or newer on either API version.
- On such a server, for an account with a password, "Ten wrong passwords sign you out on every device and lock your account until you reset your password." follows "The web asks for your password." wherever the app says that the web asks for the password (owner): the deletion dialog, the data export page, one note under Change password and Change email address, and both two-factor notes; the note to turn two-factor on also says it needs the password, as 2.8.0 asks for it there.
- A scheduled deletion (owner): for a local account, its note and the Delete account row say "The web asks for your password." on every server, as the web's cancel page asks for it, plus the lockout sentence on 2.8.0 and newer (why the row too: on a phone the note at the top is far from the row the user taps).
- The CalDAV page, on a server with the lockout (owner), recommends a CalDAV token instead of the account password, because a calendar app that keeps trying an old password locks the account after ten tries. Its delete confirmation says to remove the token from those apps first, as every further try with it counts as a wrong password, and names the lockout, for an account with a password or whose kind is not read yet, two-factor on included (why: 2.8.0 checks a CalDAV password that matches no token as the account password), not for a sign-in provider's account.

**The List view's subtask tree:** on every server it follows the web's since 2.8.0: a task expands once per top-level row and at most five levels deep (owner); [D43] has the rules.

**Accents in search** (on every server, owner):
- Every search field that filters on the device ignores case and accents ([D71]'s accent fold), from the search page and the pickers to the filter field's value suggestions (owner, [D51]). The assignee picker also matches the project's people from the server's answers, so a member its search misses for an accent stays and no one without access is added.
- Not folded (owner): the `like` filters and a view's or saved filter's stored search, as the server applies them (why: the device would otherwise find tasks the server does not). Also not folded: "Create label" (the exact title, ignoring case only), Quick Add's exact resolution of `*label`, `+project` and `@user`, and the searches the server runs.

Limits:
- Relative legal addresses are not shown, although the web shows them; texts are trimmed.
- The fold covers Latin letters only; Greek, Cyrillic and Vietnamese accents still count. The Romanian ș and ț also change how titles with them sort.
- The searches the server runs mind accents on SQLite and on PostgreSQL without `unaccent`; on MySQL the collation decides. Online, the assignee picker ignores accents only among the project's people its answers have listed, so when the empty query's answer failed, its server search decides.
- The swatch names are English in every language until Crowdin translates them ([D88]).
- A lock also ends every session, so the app usually learns of it through a failed refresh (401 code 16002) and only asks for a new sign-in; only a 412 code 1040 is named as a lock.

## D82: Projects list–detail: the project tree beside the project on wide windows

*In review since 2026-11-10 (step 36g), the owner's decision where marked.*

- Part of the first release's beta build (owner, [D72]).
- On wide windows the project tree, the open project and the task pane always stand side by side, and the pane keeps [D70]'s width (owner). Below the gate and on every phone nothing changes.
- **Gate** (`app/lib/app/layout/window_layout.dart`): where [D70]'s pane can show, no vertical fold or hinge divides the window, the account is no link-share guest, and the window less the 80 dp rail is at least 1,120 dp wide (Material 3's large class less its rail, which fits the tree, a project of about 350 dp and the pane): every iPad in landscape, none in portrait.
  - It comes from the window, not the measured content (why: the content changes with the rail's labels, so the gate would flip with the language and the text size).
  - No column for guests (why: it would hold one row, the project already open) or on a fold (to be safe; no known device of that width has one).
- **Where:** only the Projects tab, beside a project, Favorite tasks or a saved filter; other tabs keep [D70]'s two panes.
- **Layout:** the rail, the tree's column (320 dp, the narrowest phone width the app lays out for), a divider, the tab's pages, the pane. The pane keeps [D70]'s rule (40 % of the content beside the rail, 360–480 dp), so it looks the same in every tab (owner). The pages get the rest and behave as on a phone at that width ([D69]).
- **Nothing open:** beside the column the tab's first page says "No project open"; no project opens by itself, as nothing remembers a last project ([D75]).
- **The route is the source:** a row goes to the project's route exactly as on a phone, so links, search and widgets work unchanged. The open list's rows get [D70]'s selected look and read as selected. The column marks the project actually shown, so after Back no row is marked ([D116]).
- **Back:** the pane's stack, the pane, the project, the note, then [D45]'s tab rule. Beside the column a project's app bar has no back arrow; the system back and the iOS swipe from the project's own edge still go back.
- **Resize:** crossing the gate adds or removes only the column; the open project and the pane with its comment draft stay.
- **One tree at a time:** the column holds the same projects screen, built only while the Projects tab shows.
- **Accessibility:** the column, the tab and the pane are regions of their own, read and tabbed in that order after the rail, each with its level-1 title, which [D68] allows. Nothing is announced; focus follows Flutter's defaults. [D68]'s sweep runs its tablet-landscape passes (Android 1280 × 800, iPad 1194 × 834) with the column and measures the bands from its divider.
- **iPad:** the same layout from 1,120 pt, with the bottom tab bar and no sidebar.

Limits:
- With a task open at 1280 × 800 and on an 11" iPad, a project's list is phone-wide and Kanban shows one column at a time.
- The column does not keep its scroll offset across the gate.
- Two sync bars side by side, the tree's and the project's.
- Right to left only through the row's mirroring; the app has no right-to-left language yet.
- Not checked yet with real data on a tablet, on iPad, on a foldable or with TalkBack ([checklist](accessibility-checklist.md#25-checks-of-step-36g)).
- Not built: an option to hide the tree (it may come later, owner); the tree making way while a task is open; dragging a task onto a project in the tree; revealing the open project in a collapsed or scrolled tree; keyboard and Esc between the column, the project and the pane (36d).

## D83: Successor of the official Vikunja app in go-vikunja/app

*Accepted 2026-11-12, the owner's decision, agreed with the Vikunja maintainers; the decisions of 2026-11-13 for the switch (owner); steps 38a and 38b accepted 2026-11-14; the decisions of 2026-11-14 for step 38c (owner); step 38c accepted 2026-11-16; the decisions of 2026-11-16 for step 38d (owner, [D87]); step 38d accepted 2026-11-16; the decisions of 2026-11-16 for step 38e (owner, [D88]); step 38e accepted 2026-11-16; the decisions of 2026-11-17 for step 38f (owner, [D89]); step 38f accepted 2026-11-17.*

- The app becomes the official Vikunja mobile app and moves into https://github.com/go-vikunja/app; the owner is its main maintainer.
- **Android:** the Play listing `io.vikunja.app` stays in Vikunja's Play account, and the app ships there as an update of the old app: the same application id, signed with Vikunja's upload key, with a higher version code (why: the old app's installs keep updating). The first start after the update takes over the old app's server, session, theme and language, clears its leftovers and keeps its placed widgets ([D85]).
- **iOS:** the bundle id `io.vikunja.app`, since nothing is registered at Apple yet (owner, 2026-11-13; [D15]).
- **Licence:** MIT, in place of [D67]'s AGPL ([D87]).
- **Name and icon:** "Vikunja", and an icon derived from Vikunja's `logo.svg` with the old app's icons as the look to follow (owner, 2026-11-13), in place of the former name and its llama ([D15], [D42]). No text calls the app unofficial; `tool/check_store_metadata.py` refuses that ([D76]).
- **Language:** US English like the Vikunja web; the German stays (owner, 2026-11-13; [D71]).
- **Translations:** Vikunja's existing Crowdin project, in place of step 36f ([D88]).
- **Identity:** every id derives from `io.vikunja.app`, the scheme and client id are `vikunja-io.vikunja.app` ([D15], [D23]), the User-Agent is `Vikunja-App/…` ([D55]), and the internal names that ship or that contributors see carry the new name too. Nothing that fixes an id was created before the switch: no signing keys, Play app, Apple App IDs or release tag (why: [D15] makes an id permanent once these exist). The beta of 37d follows the switch, in the official listing.
- **The histories** are joined by the import pull request of [D87]: a commit that removes the old app's files, then a merge of this repository's `main` without a common history, merged with a merge commit, so that every commit hash of both histories stays. The old app's last commit is tagged `legacy-final`.
- **Vikunja's accounts and addresses:** the release keys keep the old app's secret names ([D86]); the app's pages are on vikunja.io; `hello@vikunja.io` and the address kolaente sets up serve App Review and the testers, and the Vikunja project makes the written offer for the desugar_jdk_libs source ([D67], [D89]).
- **Test data** carries the new names as well, so no file names the former name (owner, 2026-11-20, reversing the decision of 2026-11-18 to keep the E2E users' usernames; [D15], [D97]).

Open:
- The owner's rights in Vikunja's Play Console: step 38f asks kolaente for the store presence, the policy declarations and the testing tracks, not production ([D89]).
- The Apple account, and whether `io.vikunja.app` is still free at Apple ([D15]); it also decides the seller, the App Store name (if "Vikunja" is taken there) and Apple's privacy label ([D89]).
- The vikunja.io pages, which kolaente publishes from the drafts.

## D84: Everyday editing in the task detail: properties in place, task links, Move to column

*Accepted 2026-11-12 (step 37k).*

- **Properties in place,** in the sheet and in the pane ([D70]): the Due date, Priority and Reminders rows are buttons, the whole row. The Labels row has a "Change labels" button after its pills (why: the pills keep opening the label's tasks, [D60], so the row cannot be one button). Unset properties that may be set show as one add row at the end of the attribute card.
- **The controls:** the due date offers the new-task sheet's shortcuts ([D75]), each at the time already set, else at the user's default due time, else at the next breakpoint ([D35]); reminders up to 100, refusing two at one moment, because the server keeps one reminder per moment ([D36]). Project, title, start and end dates, progress, colour, repeat and assignees stay on the edit page; the rows of the dates, progress, repeat and assignees open it at their field ([D117]).
- **Writing:** each choice is one change of its field through the outbox ([D34], [D36]), offline too; a choice that changes nothing writes nothing. No confirmation, and Undo only for the due date ([D117]); screen readers hear what changed. One exception ([D98]): a due date that would put two of the task's reminders on one moment asks first, as the edit page warns.
- **Who may:** write permission ([D60]), a project not archived in the tree, and a task this device has a row of (why: a change for a task without one would be dropped); while the permission or the row is still loading, edits are offered. Without a row the sheet offers only comments, reactions, the follow bell, Copy link and Share ([D96]); in an archived project only reading, Copy link and Share. A subtask follows its own project's permission and archived state.
- **The menu,** "More": Move to column…, Copy link, Share, Duplicate, Delete. Copy link and Share appear for every task the server knows, also read-only, archived and offline, not for a task whose create is still queued; Duplicate and Delete only with write permission outside archived projects.
- **The task link** is `{web frontend}tasks/{id}`, on the frontend URL when it is http(s) and not http for an https server, else on the server root, as for link shares ([D60]); a comment's link adds `#comment-{id}` ([D57]). Copy uses the plain clipboard (why: a task link carries no secret, and only members of the project can open it). Leaving the app to share does not lock it ([D64]). The link carries the task's database id, which is not shown or spoken ([D75]).
- **Search** ([D51]): a pasted address of a task on the active account's server or frontend shows "Task from the link", which opens it ([D44]).
- **Move to column…:** only in a detail opened from a board card, while the board may be changed ([D47]) and has another column. Columns with repeated titles are numbered ("Later (2)"), as the screen-reader actions name them. The card goes on top of the chosen column by the board's own rules ([D47]), queued through the outbox, offline too.
- **Guests** ([D62]): in-place edits follow the share's stored permission, and no guest gets "Create label"; Copy link and Share are offered at every permission, as the web copies a task's link for every link share; Move to column… follows the board's own rule, as a write guest may already drag cards, and never changes the board's view.
- **Accessibility** ([D68]): each button row is one node with its hint; the add row's spoken labels contain their visible text (WCAG 2.5.3); every new control has a 48 dp target; after an editor the keyboard focus returns to what opened it. Move to column… is a single-pointer way to move a card to another column (2.5.7).

Limits:
- In the pane, Move to column… stays after a switch to another view of the same project; it still moves the card on the board it came from.
- When the pane gives way to a sheet while a list or picker is open, the choice is still written, but "Pick date…" opens no date picker, a due date that needs the question about reminders is not written, only said, and a refused reminder, "Moved to …" and the limit text are not shown.
- Reminders that already shared a moment before a due date change are not asked about.
- No Undo for priority, labels and reminders.
- Not checked yet with TalkBack or VoiceOver ([checklist](accessibility-checklist.md#26-checks-of-step-37k)).

## D85: Update from the old app: server prefill, one session try, leftovers cleared, widgets kept

*Accepted 2026-11-14 (step 38b), the owner's decision where marked.*

- On Android the app ships as an update of the old official app ([D83]), so the first start after the update finds the old app's data in the same app sandbox. That start takes over the server, the session, the theme and the language, clears the old app's leftovers and keeps its placed widgets, and a short note says what happened, only on that start (owner). iOS has nothing to take over, as the old app was never in the App Store.
- **When:** only in the UI isolate, on the start whose first-start wipe ([D24]) would delete the old entries (`core/previous_app/previous_app_import.dart`). The import runs before the account registry's first read, for at most 10 s, and never throws. It never reads `user-token`, the old access token, and stores only a record of the server, the recent servers and the number of placed old widgets, no secret ([D25]); the wipe then deletes every old entry. The session try runs at most once, and only after the stored copies are gone.

**Staying signed in, tried once** (owner):
- The app refuses before it sends the old token when the old server is on `http` or below the support floor ([D8], [D13]). It refreshes the token without a client id, which the server's refresh grant does not check, so the old app's token (client `vikunja-flutter`) is accepted ([D23]); `GET /user`, bounded by 20 s, must return the token's user, and on any failure from then on the new session is logged out best effort.
- The token lives only in memory and is never logged or stored; the import's findings print only the record. Any failure counts as the one try, an offline first start included (why: a second try would need the token kept in secure storage, a secret living longer).
- The try has an overall limit of 30 s, counted from when bootstrap starts it, not from when Connect appears, and a Cancel on Connect's progress line (owner, 2026-11-13). Either ends it at once like a failed try: the session counts as lost, the address stays filled in and the note says to sign in again (why: the steps' own timeouts add up to about 110 s at worst).
  - An answer that comes after the Cancel or the limit registers nothing, changes no state and stores nothing, and a session it brings is logged out best effort (owner). The server may have spent the old refresh token by then, so the session is lost.
  - Once the server has confirmed the account, a Cancel or the limit comes too late and the try ends as kept (why: only the device's storage is written from then on, and undoing it would register the account and remove it again).
  - A cancelled try counts as the one try; a Cancel does not start another (owner).

**The prefill and the note** ([D62]):
- Connect fills in the old server address (owner) while its field is empty, else the server the old app used last, since it deleted the address on sign-out but kept its recent servers. Up to 5 other recent servers, newest first, show as the "Your servers" chips (owner). Not in Add account.
- The note "This is the new Vikunja app" shows only in the process that ran the import with a finding, so once (owner).
- While the try runs Connect is locked; under its progress line a Cancel („Abbrechen“, the Connect screen's existing Cancel text) is the one control that works (owner, 2026-11-13): labelled, at least 48 dp and the only stop for the keyboard; only the line's text is a live region.

**Theme, system colors and language** are carried over (owner):
- "Use system colors" ([D45]) is on only when the old value was `true` and could be read (why: the old default was off, so its users saw the brand blue).
- The old light or dark theme becomes the device's theme ([D45]), whatever the server, the public demo included, as nothing goes to an account (owner, 2026-11-13); the first frame has it. Other values leave System.
- The old language becomes the per-app language on Android 13 and later, when the app has none yet and it is the tag of a shipped language, as the old app stored a bare language code ([D71], [D88]).
- The old app's "Enable Sentry" is not carried over (owner, 2026-11-21): the app asks about its own crash reports after the first sign-in ([D113]).

**Cleared** (owner), on every first start, fresh installs included (why: it is idempotent and cheap, so a job or reminder the detection missed cannot survive): the old reminders and notifications, background works ([D40]), channels ([D39]), widget preferences, the old widget provider while no widget uses it ([D63]), Sentry's cache `cache/sentry` with the old app's unsent reports and its installation id `files/INSTALLATION` ([D113]), and every secure-storage entry, the old tokens included ([D24]). Left on the device: old attachments in `files/`, the Keystore alias the app's secure storage uses, the plugins' stores, whose old handles the app overwrites, the WorkManager database, Glance's datastore and a background_downloader channel, if the old app made one.

**Widgets and icons:**
- A receiver under the old provider's class name, `io.vikunja.app.widget.AppWidgetReciever`, keeps the placed old widgets (owner); they lead to the app's widget setup, and the Widgets page lists each as "Widget of the previous app" ([D63]). The old widget's choice is not mapped.
- The old Quick Settings tile is not replaced in this step (owner); the system drops it, and the note does not mention it.
- `vikunja_notification_logo` is an alias of `ic_notification`, a crash guard for the old reminders set before the update (owner, [D42]).
- `io.vikunja.app/.MainActivity` is the old app's launcher component too, so placed launcher icons survive ([D15]).

**Tests:** `tool/e2e/update_test.sh` (the update over the old app's last commit `cdbc6e3`: the first start, the first sync and a new start) and `tool/e2e/smoke_test.sh` (a fresh install) run by hand on an emulator with the owner's sign-in, never in CI ([D111], [developer guide](development.md#update-and-smoke-tests-on-an-emulator), [threat model 8.2](threat-model.md#82-manual-on-the-android-emulator), item 13).

Limits:
- Builds from before February 2026 stored their entries with flutter_secure_storage 9, which version 11 cannot decrypt: their users get the note without a prefill ([D24]). Builds of March 2026 stored a `refresh-cookie` instead of a refresh token: their users get the prefill and the note, but no try.
- Nothing runs at the moment of the update (why: a receiver of the app's own would race the notification plugin's, which re-arms the old reminders), so an old reminder can fire until the first start, with the app's icon and a Done that does nothing ([D39]); on Android 16 such reminders were seen both removed at the install and surviving it.
- On Android 14 and later the update leaves exact alarms off, although the old app declared `USE_EXACT_ALARM`; only the usual setup step asks for them ([D17]).
- The kept account records no confirmed sign-in host, as there was no browser step ([D23]).
- An install whose first wipe failed (a broken Keystore) and whose user then saved connection settings would count as an update; the effect is the note.
- After a Cancel or the limit the token refresh and `GET /user` run on until their own timeouts, and a session they bring is logged out best effort within 20 s.
- When the import runs over its 10 s, the old theme and "Use system colors" show only from the next start.

Open:
- Whether a Cancel or the limit that comes after the server has confirmed the account may end the try as kept, as built, is for the owner to confirm.
- Whether the old reminders fire before the first start on Android versions older than 16, and the alias with them, was not tested.

## D86: CI and releases on GitHub Actions

*Accepted 2026-11-16 (step 38c), the owner's decisions of 2026-11-14 where marked; without GitLab since step 38d, accepted 2026-11-16 ([D87]).*

- GitHub Actions run the CI and the Android releases in go-vikunja/app ([D83], [D87]), each job running scripts of `tool/ci/` that run the same way locally ([D73]). They are the only CI: the GitLab pipeline, which had kept working beside them with a release job that only rehearsed (owner, 2026-11-14), is deleted (owner, 2026-11-16).
- **Builds only from tags** (owner; why: the old app uploaded every push to `main` to Play): a beta tag `vX.Y.Z-beta.N` goes to Play's `beta` track, a final tag `vX.Y.Z` to production as a staged rollout, and every release puts the APKs on GitHub Releases and on dl.vikunja.io. Pushes and pull requests run the checks only.
- Releases are published from no repository but go-vikunja/app, and the release jobs have a dry run without secrets (`VIKUNJA_APP_RELEASE_DRY_RUN=true`, with throwaway keys, publishing nothing), so the workflows can be tried first in a private test repository of the owner's (owner).
- **Keys only at the end:** the build jobs make unsigned files (`VIKUNJA_APP_UNSIGNED=true`) and never see a key; one job in the protected environment `release` signs, checks and publishes them.

**The workflows** (`.github/workflows/`, checked by `tool/ci/test_github_workflows.py`):
- `ci.yaml` runs on pushes to `main`, pull requests and by hand, and weekly with `osv` only. Its jobs `checks`, `editor`, `contract`, `android`, `osv` and `ios` are [D73]'s and the checks the ruleset on `main` requires; `contract` uses the runner's own Docker, published on `127.0.0.1` ([D28]). `ios` (Xcode 27, like the owner's releases, [D97]) builds unsigned, checks the notices and the required-reason APIs ([D74]) and runs the native XCTests on a simulator ([D111]); it runs in go-vikunja/app, where macOS runners are free, and elsewhere only with `VIKUNJA_APP_IOS_JOB=true` (why: a private repository pays about ten times the Linux price for macOS).
- `release.yaml` runs on `v*` tags only, and a malformed tag fails:
  - `ci` calls `ci.yaml` without secrets, so a release waits for the whole CI, `ios` included (why: a tag that does not build for iOS cannot be released from the Mac either);
  - `build` runs with no environment, no secret and no cache, and keeps the unsigned files as an artifact for 14 days;
  - `secret-scope` fails when any of the seven release credentials (the two key pairs, the Play service account and the two S3 keys) is a repository or organisation secret (why: such a copy can be read by any workflow on any branch, without the environment's reviewers);
  - `publish` needs `ci`, `build` and `secret-scope` and runs in the environment `release`, so a reviewer approves it; it is the only job with `contents: write`, publishes one tag at a time, never cancelled ([D97]), and gives each step only its own secrets;
- `contract-matrix.yaml` runs the contract tests nightly, on `v*` tags and by hand, against one release per minor line from the support floor to the test servers' default image, each image pinned by tag and digest ([D28], [D111]). It is no required check and does not hold `publish`: its run on a tag is read before the approval ([releasing.md](releasing.md#cutting-a-release)).
- `upstream.yaml` runs weekly without a secret; Dependabot updates the actions only, with a cooldown of 7 days (owner, 2026-11-18, [D97]). The update and smoke tests ([D85]) stay outside CI, as they need an emulator and the owner's sign-in.
- **Hardening:** `permissions: {}` at the top and `contents: read` per job; `persist-credentials: false` on every checkout; no `pull_request_target` or `workflow_run`; only GitHub's own actions, each pinned by its full commit SHA with the version beside it, and no Flutter setup action, as none verifies the SDK's checksum; no `${{ … }}` inside `run:` (values reach the scripts through `env:`), each `run` one `tool/ci/` script; never `secrets: inherit`; no cache in the release jobs; runner labels by name (`ubuntu-24.04`, `xcode-27`), never `-latest`, so an image switch shows in a diff; exactly these four workflow files, with no filters or inputs.
- No DCO job, as Vikunja has none ([D87]), and no Crowdin workflow: Crowdin's GitHub integration opens the translation pull requests, with no workflow and no secret in the repository ([D88]).
- **Runners:** the bare hosted images, not a container (why: they cannot be pinned anyway, `contract` needs the host's Docker and `ios` macOS). JDK 21 is set explicitly, as the Ubuntu image defaults to 17. Flutter comes from the checksum-verified download of `pins.sh` ([D73]), for Linux x86_64 or macOS arm64 only (the macOS SHA-256 from Homebrew's cask), so the runners stay on those.

**The build** (`tool/ci/release_build.sh`):
- Only a tag run of go-vikunja/app is real, checked by the repository's name and its numeric id `395095540` (why: another repository renamed to that name does not pass). Anything else is a dry run.
- The source link ([D67]) is the tree at the tag of the repository the workflow runs in; the repository must be public, and the link, like every vikunja.io page the app and the listings link, must open signed out ([D90]); the written offer needs its contact. The build runs the release-only source-link test and the notices' checks.
- It warns for a shipped language below 50 % and refuses when German lacks an English text, unless `VIKUNJA_APP_ALLOW_INCOMPLETE_GERMAN` lets a patch release go ([D88], [D97]), builds the bundle, a universal APK and one APK per ABI, runs the exported-components check, and checks that no output is signed (so a stray `key.properties` cannot sign a CI build).

**Signing** (`tool/ci/release_sign.sh`):
- The secrets keep the old app's names, `KEYSTORE_BASE64` and `KEY_PROPERTIES` (read like Java's `Properties.load`), so Vikunja's maintainers need no new ones. A separate APK key is optional; without it the upload key signs the APK too, as in the old app (why: installs of the old app's APKs keep updating).
- The secrets are unset before anything else runs and every value is masked (why: GitHub masks a multi-line secret only line by line); the keystore lives in the runner's temporary folder with umask 077 and is removed on every exit; passwords pass only through one command's environment.
- Each certificate's SHA-256 must equal the one committed in `tool/ci/release_certificates.txt`; until Vikunja's maintainers commit them in a reviewed commit, a real release fails (why: a swapped secret would otherwise sign the public APK with a stranger's key).
- `apksigner` signs the APKs (schemes v2 and v3), `jarsigner` the bundle. An APK is signed twice and must come out identical, so its key must be RSA (why: a re-run must reproduce the APK already published; an EC or DSA signature differs every time). Then [D73]'s checks (one signer, the committed certificate, no debug key, the tag's version) and `zipalign -c -P 16 4`.

**Publishing** (`tool/ci/release_publish.sh`):
- A step publishes only when the run is official, the ref is the built tag, the signing was real and nothing made it unreleasable, and the tag still points at the built commit; a run without the signing pair publishes nothing and fails (why: a tag that released nothing must not look green).
- Play through `tool/ci/play_upload.py`, standard library only (why: no third-party code sees Vikunja's service account key, and no fastlane, which would need Ruby); the service account's JSON sits in a 0600 file and its key reaches `openssl` on stdin. A final release goes to production with the rollout fraction `VIKUNJA_APP_PLAY_ROLLOUT` (0.1 when unset); raising or halting it is done in the Play Console. Production refuses without the en-US What's new ([D90]).
- The order is Play (the strictest check of the bundle and the key), dl.vikunja.io (https only, the keys on that one command; the old `/app/unstable/` is no longer updated), then the GitHub release, the announcement, with the workflow's own token, a beta as a prerelease, with `SHA256SUMS` and the desugar_jdk_libs source. A re-run needs the approval again; each step skips what is already there with the same SHA-256 and fails on other content. "Re-run all jobs" builds again, and a new build need not give the same files.
- `tool/ci/release.sh --dry-run` runs it all locally; without `--dry-run` it refuses. iOS releases stay manual on the owner's Mac ([D74]).

**What Vikunja's maintainers set up in go-vikunja/app** ([releasing.md](releasing.md#once-in-go-vikunjaapp)): the environment `release` with the owner and kolaente as its required reviewers, either of whom may approve a release, their own tag's too ("Prevent self-review" off, owner, 2026-11-14), and no administrator bypass, deploying from `v*` tags only; its secrets at environment level, and no repository or organisation copy of the seven credentials; the certificates in `release_certificates.txt`; rulesets for `v*` tags and for `main` with the six checks; read-only workflow permissions and approval for outside contributors' workflows.

Limits:
- The workflows have run only in the owner's test repository, public rather than private as planned, with throwaway keys; the environment, the rulesets, real signing, Play, dl.vikunja.io, a real release and the XCTests show only in go-vikunja/app; pull requests and runs by hand were not tried.
- GitHub can give `ios` no macOS arm64 runner within 15 minutes, which fails the job, in CI and in a release.
- The hosted images cannot be pinned, so their tools change with GitHub's image updates.
- The Play path is tested against a fake server only: a release during another rollout, managed publishing, a version code used elsewhere and a large upload show with the first real tag. `jarsigner` picks the bundle's signature algorithm from the JDK's defaults for the key.
- Documented but not yet seen: that the secret expressions give `true` or `false`, and `queue: max` on job-level concurrency.
- The unsigned files stay an artifact for 14 days, readable by everyone in a public repository; the signed ones are not kept.
- Not built: an iOS release job ([D74]), provenance attestations, a stable "latest APK" link, Renovate ([D87]).

Open:
- The upload certificate's SHA-256 (Play Console > Test and release > App integrity > Upload key certificate) for `release_certificates.txt`, from Vikunja's maintainers.

## D87: MIT, Vikunja's contribution rules and the move into go-vikunja/app

*Accepted 2026-11-16 (step 38d), the owner's decisions of 2026-11-16 where marked. The move is still to come: kolaente changes the ruleset, and then the tag `legacy-final` and the import pull request follow. The written offer and the last places that named the owner changed with step 38f, accepted 2026-11-17 ([D89]).*

Step 38d of [D83]. The points marked (owner) are the owner's answers of 2026-11-16; the others are defaults the owner was shown and did not object to.

**The licence** (in place of [D67]'s AGPL):
- MIT for the whole repository ([D83]). `LICENSE` is the standard MIT text with the line `Copyright (c) Vikunja and contributors`, exactly so, without a year (owner); the same line is in `NOTICE.md`, the app's notice and on the About page, which says the app is "open source under the MIT License". Contributors keep the copyright in their contributions and license them under the MIT License.
- **Earlier history** (`NOTICE.md`): this app's own commits before the move are MIT too; the previous app's history up to `legacy-final` and third-party material in old commits keep their own licences (for example the editor code before commit f44e04f, and texts that followed Vikunja's AGPL web frontend closely). The test files with vectors from Vikunja's tests stay AGPL-3.0-or-later and never ship.
- The former name and its llama logo are no longer reserved in the history, and no file is to name the former name (owner, 2026-11-20; [D15], [D42]).
- **Name and logo** (owner: the clause now; kolaente confirms the text later): the name "Vikunja" and the Vikunja logo belong to the Vikunja project and are not licensed under the MIT License; the app's icons derive from `logo.svg` of go-vikunja/vikunja and are used with the project's permission; a fork that distributes its own build uses its own name and logo. `NOTICE.md` (with the files derived from the logo, [D42]; the scripts, the Markdown files and the files that wire the icons in are MIT), the app's notice, `CONTRIBUTING.md`, `branding/README.md` and the About page carry the clause. The app's notice holds only the copyright line and this clause, beside the MIT `LICENSE` ([D67]).
- **What stays of [D67]:** the source link with its release-only test and the public-repository and signed-out checks, the About page's row and the release notes' line, without the AGPL reasons ([D86]); the written offer for the desugar_jdk_libs source (GPL-2.0 with the Classpath exception), which the Vikunja project makes with `hello@vikunja.io` ([D89]); and, with [D5]'s reason, embedded Cronet and no Play services library, so Cronet works on every device without Play, the app holds no proprietary code and F-Droid stays possible.

**The contribution rules are Vikunja's;** `CONTRIBUTING.md` keeps the app's own rules for the code:
- Pull requests disclose AI help and answer for every line, follow an agreed issue for a feature and use Conventional Commits; one whose review questions stay unanswered may be closed after two weeks. Translations come only through Vikunja's Crowdin project, German included ([D88]). **No CLA and no DCO.**
- **Security reports** go privately to security@vikunja.io or through GitHub's private vulnerability reporting, never in a public issue ([D77]); `SECURITY.md` covers the app, its widgets and editor, and the scripts and workflows that build and release it.
- **Not added** (owner): `AGENTS.md`, `CLAUDE.md`, `CODEOWNERS` and `FUNDING.yml`; CODEOWNERS and FUNDING go to kolaente as suggestions. Not copied: the paragraph of Vikunja's CONTRIBUTING that asks automated agents to put a marker in the pull request's title.

**GitLab CI is deleted** (owner), with its DCO job and the Mac as a GitLab runner ([D73]); [Q22](open-questions.md#q22-ci-runners-on-gitlab) is obsolete. So `test_servers/docker-compose.yaml` publishes on `127.0.0.1` only ([D28]), and `ios_release.sh` links `<repository>/tree/<tag>` for every host ([D74]). The app's earlier GitLab project is public; the owner archives it with a pointer to go-vikunja/app once the import is merged.

**The docs** are written for the official app. "The owner" is defined once, in the introduction of this log and in the [developer guide](development.md), as a role: the app's main maintainer. The repository names no person as maintainer, as that can change, and is written as Vikunja's general app repository (owner, 2026-11-16). No file names the owner, except the commit authorship ([D89]).

**The move:**
- The import pull request, from the owner's fork, holds only a commit that removes the old app's files (among them its workflows, `renovate.json` and its `crowdin.yml`) and a merge of our `main` with `--allow-unrelated-histories --no-ff`, so that the tree equals our `main`.
- **`legacy-final`:** an annotated tag on the old `main`'s last commit (cdbc6e3), pushed when the freeze of that `main` starts; no `legacy` branch; the old tags and releases stay.
- kolaente changes the ruleset "main protect" for the import (merge commits allowed, [D86]'s six checks required) and restores it afterwards, the recommendation being squash only. The owner merges with "Create a merge commit" (why: squash or rebase would rewrite or drop the imported commits, whose hashes the docs cite).
- **The history goes public unchanged:** it holds no real secrets, only documented test fixtures and fake values, and the GitLab project is public already. Only the import branch and `legacy-final` are pushed, never with `--mirror` or `--all`, which would publish the parked stash of the session hardening ([D59]).
- **The owner's GitHub account** must have the commits' author address verified, without "Block command line pushes that expose my email" for it (why: every commit before the move has that author address, [D114]).

**R17**, the Glance weakness ([D66]), stays as it is; it is public on GitLab already.

**For kolaente**, a list that the owner forwards in English: the ruleset; the name-and-logo text and who holds the logo's copyright; private vulnerability reporting, with the owner as a security manager; CODEOWNERS for `.github/` and `tool/ci/release_certificates.txt` and FUNDING.yml as suggestions; the stale branches of go-vikunja/app; the secrets as environment secrets ([releasing.md](releasing.md#once-in-go-vikunjaapp)); the certificate fingerprints ([D86]); the written offer ([D89]).

Limits:
- Until an admin switches on private vulnerability reporting, only the email route of `SECURITY.md` works.
- The app's texts reach Crowdin only after the import, once kolaente has connected the integration ([D88]).
- The old app's workflows stay in its commits: a `v*` tag pushed onto an old commit would run that commit's release workflow. The secrets only in the environment `release` and a ruleset for `v*` tags close this ([releasing.md](releasing.md#once-in-go-vikunjaapp)).

Open:
- kolaente's confirmations: the name-and-logo text and who holds the logo's copyright, the ruleset and private vulnerability reporting.
- The import pull request waits for the ruleset. Until it is merged, go-vikunja/app's `main` is the old app, frozen from the push of `legacy-final` on.

## D88: Translations through Vikunja's Crowdin project

*Accepted 2026-11-16 (step 38e), the owner's decisions of 2026-11-16 where marked, with the results of the owner's Crowdin rehearsal of the same day. The Crowdin integration and the German upload are still to come: they follow the import and kolaente's setup in Crowdin.*

Step 38e of [D83]. The points marked (owner) are the owner's answers of 2026-11-16; the others are defaults the owner was shown and did not object to. The Crowdin behaviour below is what the owner's rehearsal showed ([beta.md](beta.md#the-crowdin-rehearsal)).

**The generated l10n code leaves git** (owner, answers [Q18](open-questions.md#q18-generated-localisation-code-in-git)): `app/lib/l10n/generated/` is git-ignored (why: Crowdin's pull requests change only ARB files and would fail the check for stale generated code; each language adds about 224 KB). `flutter pub get`, `build` and `run` write it, `analyze` and `test` do not ([developer guide](development.md#generated-code)); every CI script runs pub get first ([D73]). Only build_runner's `*.g.dart` files stay committed and checked ([D3]).

**German comes through Crowdin** (owner), like every language, by Vikunja's rule (why: Crowdin's export writes whole files and would overwrite German changed in a pull request). A pull request changes only the English.
- German may lag English on `main`, English standing in. The ARB parity test allows missing messages but fails on extra keys, empty texts, ICU gen-l10n refuses, changed placeholders (why: a renamed one passes gen-l10n and breaks the call sites) or a wrong `@@locale`.
- **A release needs German complete:** `tool/ci/release_build.sh` ([D86]) and `ios_release.sh` ([D74]) refuse otherwise. A patch release may go without them, logged (owner, 2026-11-18, relaxing the rule above): only when `VIKUNJA_APP_ALLOW_INCOMPLETE_GERMAN` equals its tag, never for an `x.y.0` or its betas, naming how many texts German lacks; English stands in ([releasing.md](releasing.md#a-hotfix), [D97]).

**German terms follow Vikunja's German translation instructions** (owner): "Account" for „Konto“, „Anmeldename“ for „Benutzername“, no „Handy“ ([glossary.md](glossary.md)), store texts and native strings included; a test checks them.

**Which languages ship** (owner):
- A language ships once 50 % of the app's file is translated and approved, as on Vikunja's web; English and German from the start. A maintainer adds one in one pull request (CONTRIBUTING.md).
- `app/lib/app/l10n/shipped_locales.dart` is the list, English first as the fallback; an ARB file not on it is never shown. Notifications, widgets and the lock prompt follow it, all keeping the device's region for dates and numbers ([D71], [D93]); a test keeps the platforms' and the update's lists ([D85]) equal to it and asks each language for the picker support ([D93]).
- `tool/l10n_progress.py` gives each file's share, rounded down (why it can: Crowdin exports only approved translations and leaves untranslated ones out). `release_build.sh` warns about a shipped language below 50 % without refusing (why: English grows, so a share falls without anyone touching it).

**Not shipped yet** (translatable on Crowdin, never shown): right-to-left languages, until a pass over the layouts; Esperanto, which Material does not support; Vikunja's custom Swiss German, exported as `app_gsw.arb` through a mapping in the project's settings (why: the CLI refuses all of `crowdin.yml` for a custom code), for `two_letters_code` only, so the web's and API's files keep their names (why `gsw`: the custom code may be `de`, which would overwrite the German, and `gsw` is Swiss German's code, which Material supports). Shipping it is a later decision.

**Crowdin's codes as Flutter's locales:** for example `pt-BR` → `pt_BR`, `zh-TW` → `zh_Hant`, `no` → `nb` (what Norwegian devices report), `de-swiss` → `gsw`. Every regional or script file has a base file (why: gen-l10n fails without one). The template has no `@@locale` (why: Crowdin would write codes such as `pt-BR` there, which gen-l10n refuses).

**The integration** is Crowdin's GitHub integration, set up by kolaente through a dedicated bot account:
- `crowdin.yml` (checked by `tool/ci/test_crowdin_config.py`): project 462614, the English source, the translations as `app_%two_letters_code%.arb`, only approved translations, untranslated strings skipped, `append_commit_message: false` (why: Crowdin appends `[ci skip]` by default, which skips the checks); `"no"` quoted (why: YAML 1.1 reads a bare `no` as false). No token in it, and no workflow and no secret in the repository ([D86]): the integration keeps its credential in Crowdin, and the CLI takes its token from the environment.
- Its pull requests come from a branch of go-vikunja/app and run `ci.yaml` like any other; later syncs add commits to that branch without force-pushing it. The credential can push branches and open pull requests, but not merge while "main protect" requires a maintainer's approval, and not release: `v*` tags are protected and the environment `release` needs a reviewer (why the bot account: the credential reaches only what that account reaches; [threat model](threat-model.md) M47, R40). This holds while the account has Write, not admin, and is on no bypass list (an admin can change the rulesets and the environment).
- A translation cannot inject code: gen-l10n escapes it. Broken ICU or a renamed placeholder fails Crowdin's pull request; the fix is made on Crowdin.
- The source lands in a version branch `main` as `main/app_en.arb`, beside the old app's root file, so the old translations do not carry over; kolaente removes the root file after exporting it if translated since December 2025 (why: until then Crowdin's progress counts both).

**The uploads:** the source goes up only once the old app's nightly "Crowdin Sync" workflow is off (why: it would bring the old file back); the integration uploads it itself once connected. Right after, the owner uploads the German once with the CLI after a dry run, auto-approved, with `-b main` (why: else it writes into the old root file, which is not exported) and `--import-eq-suggestions` (why: 63 German texts equal the English, Crowdin skips them otherwise and German would never count as complete), and `--translate-hidden` if the project hides duplicates; commands in [beta.md](beta.md#the-translations-on-crowdin).

**The texts:**
- Every English plural has a `one{…}` branch that shows its number, no `=1{…}` (why: some languages use the one form for 21 or 31, French for 0, and translators copy the English); wording for exactly one, such as "Every day", is a message of its own. Every message with a placeholder or plural has a description, the translators' only context.
- Native strings stay English and German until a third language is about to ship. The old app's Polish is not uploaded (why: written for its 188 strings, few recur).
- Pre-translation from the web's translations waits for kolaente's OK (why: the web is under the AGPL, the app under the MIT License), then runs without auto-approval; until then [D71]'s "no web texts are copied" stands.

**For kolaente** ([beta.md](beta.md#what-kolaente-does)): the integration's "Push Sources" and its imports from the repository off, as the owner's upload brings the German (why: that upload can be dry-run and takes `-b main` and `--translate-hidden`, which the integration's page does not mention); the bot account lowered to Write once synced; the old nightly workflow disabled; Swiss German's mapping; no manager role for the owner, whose Developer role in 462614 covers the integration, approving the German and the old root file; "Skip untranslated strings" and "Export only approved translations" in the settings (why: Crowdin does not document whether the integration follows `crowdin.yml` there); the old secrets `CROWDIN_PROJECT_ID` and `CROWDIN_PERSONAL_TOKEN` deleted (why: any workflow on any branch can read them), and no other repository or organisation secret than the S3 ones, which hold no credential.

Limits:
- Nothing reaches Crowdin before kolaente's part; until the German upload, German added to `app_de.arb` in the repository is kept, and a Crowdin pull request before it fails the tests that pin German texts. Where the integration puts the source is not documented; kolaente checks it first.
- A changed English text keeps its translations unapproved, and the export drops them: after every English change a maintainer re-approves or retranslates its German on Crowdin, or the next Crowdin pull request lacks it, which a release refuses, and fails where a test pins the text; feature pull requests stay green.
- The first Crowdin pull request reformats every ARB file once into Crowdin's layout, which the tests accept.
- An untranslated message shows in English, so a language at 50 % is half English, and an untranslated language name shows "English" in the App language row; a third language sees English in the native strings. No right-to-left layout has been checked.
- After a pull that adds an ARB file, an incremental build keeps the old languages until `flutter pub get`.
- Only the Android release build warns about a language below 50 %; `ios_release.sh` checks only German.

Open:
- Whether the integration keeps working once the bot account has Write only: the rehearsal used the owner's admin account.
- kolaente's part, then the German upload and the first Crowdin pull request; pre-translation from the web; native strings on Crowdin and a right-to-left pass.

## D89: Store listing and web pages of the official app

*Accepted 2026-11-17 (step 38f), the owner's decisions of 2026-11-17 where marked, with the 20 Play screenshots retaken the same day. The vikunja.io pages, kolaente's Play Console permissions for the owner, the address for App Review and the testers and the Apple account are still to come: they follow from kolaente.*

Step 38f of [D83]. Points marked (owner) are the owner's answers of 2026-11-17; the rest are defaults the owner was shown and did not object to.

**The app's pages are on vikunja.io**, in English only, so one URL serves every language and both listings: privacy `https://vikunja.io/privacy/#mobile-app` (the stores link the whole page); help `https://vikunja.io/help/mobile` with `#delete-your-account`, also as support, marketing and Play's account-deletion URL (why: `/support` is about supporting the project); the imprint `https://vikunja.io/imprint/`, whose scope sentence names the apps; security `https://vikunja.io/security/` and [SECURITY.md](../SECURITY.md). The About page and both App Store languages use the same addresses ([D76]).

**Drafts only** (owner): the vikunja.io texts, the privacy section in Vikunja's "we" voice and controller among them, are drafts in [vikunja-io-drafts.md](vikunja-io-drafts.md); kolaente puts them into go-vikunja/website, and no pull request is prepared. No build is distributed before they are published.

**Store texts:** only `en-US` (US spelling, the glossary's terms, [D71]) and `de-DE`, not on Crowdin; they say "The app has no server of its own: it talks only to the servers you add" (why: with Vikunja as the publisher, the developer runs `try.vikunja.io` and Vikunja Cloud) and name the shipped languages ([D88]). `tool/check_store_metadata.py` pins languages, URLs, `hello@vikunja.io` and the copyright.

**Short description** (owner): Play's stays kolaente's "Plan your projects with the elegance of a sloth on a sunny day."; our "The app for your Vikunja server: tasks offline, with reminders and widgets." opens each Play full description; the App Store subtitle stays "Tasks on your own server".

**Data safety on Play** (owner), answers in [store-listing.md](store-listing.md#app-content):
- "Data is encrypted in transit": No (why: `http` is allowed after consent, [D8], and Google allows "Yes" only if it always holds).
- The data types are the union of the old app's and the new app's ([D76]) (why: Play judges the form over every distributed version, open testing included, until the old app is gone): the old app's name, email address and user IDs, for app functionality and account management, deletion on request, and its opt-in Sentry reports as crash logs, diagnostics and other app performance data, collected, not shared (Sentry is a service provider), optional, for analytics (as Google counts data about how an app performs). The new app has no analytics; its opt-in crash reports declare crash logs and diagnostics ([D113]).

**Apple's privacy label** ("Data Not Collected", [D76]) stays open until the Apple account is decided (why: with Vikunja as the publisher, what a user sends to its servers reaches the developer). Whatever the account, the opt-in crash reports add Crash Data and Other Diagnostic Data ([D113]).

**Contacts**, no person's name or private address: `hello@vikunja.io`; `security@vikunja.io` and GitHub's private vulnerability reporting ([D87]); for App Review and the testers an address kolaente sets up, until then `hello@vikunja.io`.

**Legal:** "the Vikunja project" makes the written offer for the desugar_jdk_libs source at `hello@vikunja.io` ([D67]) (why: GPL-2.0 section 3, as Play and dl.vikunja.io do not hold the source; GitHub releases carry it). The App Store copyright is "2026 Vikunja and contributors", like `LICENSE` ([D87]); the App Store shows the seller, the enrolled account's name, apart from it. No repository file names the owner, except the commit authorship and the log's history ([D87]).

**Screenshots are retaken** (owner): all 20 Play screenshots with `tool/store_screenshots.sh` ([D76]), on dedicated emulators, never the owner's own AVDs, with the seeded test server and the owner's sign-in once per device: agents never type credentials. The icon and the feature graphic stay.

**Play's closed test** of 12 testers for 14 days does not apply, as `io.vikunja.app` is in production ([D72]); betas go to the open testing track `beta` ([D86], [D77]).

**For kolaente** ([beta.md](beta.md#what-kolaente-does)): the owner's Play Console permissions for `io.vikunja.app` only (Manage store presence, Manage policy declarations, Release apps to testing tracks, Manage testing tracks and edit tester lists; not production); the drafts; the address for App Review and the testers; the written offer; whether the full description keeps the sloth line's spirit and names Vikunja Cloud; the Apple account, with the App Store name (a former contributor's team may hold "Vikunja" through the old app's Appfile); Vikunja Cloud's terms or DPA URL.

Limits:
- Until the pages are published, the help, support, marketing and deletion links lead nowhere, privacy to a policy without the app's section, and the imprint does not name the apps; the release scripts refuse a release until the pages open with their anchors ([D90]). The German app and listing open English pages.
- Until the old app is gone from every track, Data safety also declares what only it collected: the email address, account management as a purpose, other app performance data. Whether Sentry's installation id adds device or other ids is not established.
- App Review writes to `hello@vikunja.io`, which need not reach the maintainers, until kolaente's address exists.
- Nothing checks that a screenshot is current. vikunja.io has no `/.well-known/security.txt`, only `/security.txt`.

Open:
- kolaente's items (above), among them the vikunja.io pages, the address for App Review and the testers, and the owner's permissions in the Play Console.
- The Apple account, and with it the App Store name, seller, trader status and privacy label, before 37d's TestFlight ([D15], [D83]); [D74]'s privacy manifests, which declare no collected data, are checked against the label.

## D90: Fixes from the code review before beta.1

*Accepted 2026-11-17 (step 40a).*

Findings of the code review of 2026-11-17 that belong in the first public build, `v1.0.0-beta.1`.

**Reminders after a force stop** (B1): on Android a force stop cancels the alarms but keeps the notification plugin's pending ids, which the scheduler takes as armed ([D39]), and the plugin re-arms only after a boot or an app update, while a stopped app gets no boot broadcast until it is opened again, so no reminder would ring until then. So on Android each account's first reconcile in a UI process schedules the whole window again, without cancelling first (why: scheduling an id again replaces its alarm, while a cancel also removes the shown notification). Headless runs (after a force stop their WorkManager jobs come back only once the app has run) and iOS, whose pending list is the system's, do not re-arm. Rejected: a `PendingIntent` lookup (on Android 14 and older a cancelled alarm's stays findable for minutes), the force path (it withdraws shown notifications), `ApplicationExitInfo` (misses a stopped process that was not running), `ApplicationStartInfo.wasForceStopped()` (Android 15 only).

**Schema version 1** (E1): the Drift schema starts at version 1 with the first public build ([D31]) (why: from then on every version has to stay; the old app's database is another one, [D85]); version 2 is [D109]'s. A rollback keeps a later version's tables; no downgrade runs. The development-only migrations are gone, among them the cleartext one ([D65]), as every `http` connect records its consent and the update never registers an `http` account (the list of account roots stays: the reset finds the secrets to delete through it).

**Play's What's new** (P5) comes from `fastlane/metadata/android/<language>/changelogs/<versionCode>.txt`, sent by `tool/ci/play_upload.py` ([D86]), each in both listing languages. Production refuses without the en-US text, a beta sends what exists; a final tag without it fails only after signing and needs a new tag, so `tool/ci/release.sh --dry-run` comes first; only `<version code>.txt` counts (not `default.txt`, which the upload never reads); each text has at most 500 characters, checked before any request (why: in production the staged rollout starts at once, so a text typed into the Play Console comes too late, and for an old-app user it is the one place that says what changed). The texts of `1.0.0-beta.1` (1000001) and `1.0.0` (1000099) say that the app may ask you to sign in again (not that the server is filled in: old-app builds from before February 2026 give no prefill), that it needs Vikunja 2.3.0 or newer like the previous app, that old widgets need one tap each and that the Quick Settings tile is gone ([D85]).

**Servers older than 2.3.0** (P1) need no change: the old app has required 2.3.0 since spring 2026, so the floor ([D13]) is not new to its users; the Connect screen and the What's new say so.

**Store texts** (N2, N4), [D89]: they say what needs a connection and that Vikunja sends no push notifications, so a reminder or assignment made on the web arrives with the next sync ([D39], [D40]) (why: the listings promised more offline than the app does). The review notes say it in short.

**The vikunja.io pages** (P4): both release scripts check every vikunja.io page the app and the listings link (`RELEASE_WEBSITE_PAGES` in `tool/ci/release_lib.sh`, kept equal to them by `tool/ci/test_website_pages.py`): 200 signed out, redirects only over https to the page's own origin, each fragment an element id. A real release refuses otherwise (why: every build and listing links them, and Play's Data safety and account deletion and the App Store's support URL need them live). Not checked: `/docs/caldav/`, which the account settings link outside that list, and the security page, which only SECURITY.md and the help page link.

**US spelling in the demo data** (P9): "Change the tires" ([D71]); the spelling check covers the seed's English.

Limits:
- The re-arm is verified on Android 16 only; [releasing.md](releasing.md#cutting-a-release) repeats the check before every release. Whether some manufacturers' "close all" acts like a force stop is not verified; the re-arm covers them if it does.
- A reminder due while the app was force-stopped does not come afterwards, except one due less than 3 h before the next start ([D94]).
- A development install that never opened a build of step 40a stays at version 12, which [D109]'s migration upgrades like version 1 ([D114]); one at 2 to 11 fails until its data is cleared.
- Every real release is refused until kolaente publishes the pages; that the imprint names the apps stays a manual check ([releasing.md](releasing.md#the-website-and-the-store-listings)).
- The What's new texts wait for the owner's review. The 1.0.0 text is the beta's without its beta sentence; if 1.0.0 should say what changed since the betas, it is rewritten before its tag.
- Play gets notes only with an upload (a version code already on the track is skipped); that Play takes them in en-US and de-DE is tested against a fake server only.

## D91: Fixes from the code review: the description editor and leaving pages for a switch

*Accepted 2026-11-17 (step 40b).*

Findings B2, B9 and B17 of the code review of 2026-11-17 ([D90]).

**The copy follows every edit** (B2): the editor page keeps a copy of the edit, from which Reload and Save go on when the WebView's process has ended ([D52]). The WebView reports edits at most every 50 ms; the copy is taken by a 1 s throttle, not a debounce (why: a timer each edit restarts never fires while the user types on), so it is at most about a second behind.

**The draft kept while editing:**
- Each changed copy is also written as the draft, and going to the background writes it at once (why: when the WebView's renderer goes, Android ends the whole app, and the system may end it in the background).
- One draft per account and description, the 20 most recently saved in all (why: with one slot, typing in another editor replaced a draft the user had not seen). Never an autosave: the entity changes only on Save, and the next editor of the same description offers the draft back.
- Draft writes are serialised app-wide (why: every editor and the sign-out change the same list, and no write may lose another). A page writes none once it is closed or its account is no longer active (why: a sign-out wipes the drafts, and a later copy must not bring one back).

**When the draft goes** (B9, first half): on Save, Discard, leaving with nothing unsaved, declining the offer, or when it equals the stored description; sign-out and account removal discard the account's drafts. A page removed with unsaved changes, or while it still offers the draft, keeps it for the next editor.

**Leaving the pages over the shell before a switch** (B9, second half):
- A notification tap, task or widget link or share for another account first lets the dialogs, sheets and pages over the shell go one by one, as if the user went back ([D37]). Each with changes asks: Keep editing refuses the switch, and what was opened is dropped; Discard, or Save once saved, lets it go on. For the active account the task opens in a sheet over the page, which keeps its changes.
- One that cannot be popped and asks nothing (a draft's offer, a sheet busy creating) refuses the switch. One that would not ask is removed at once without animation (why: sliding out, it showed the next account's data).
- A leaving answer waits up to 30 s for the page to go, else the switch is refused silently and logged (why: Save may write online first).
- Only the share says why it stopped, and has to be shared again; a notification or widget needs no note, as the question was the feedback and the tap can be repeated. Other leaving callers, such as the Account tab, stop on Keep editing.

**The restore question, Save during an upload, temporary ids** (B17):
- "Restore unsaved changes?" is answered only by Discard or Restore, not by a tap beside it or Back (why: that counted as Discard, so the draft went unseen). Closed from outside, it counts as unanswered and the draft stays.
- Save in the leave dialog while an image uploads waits for the upload, so the image is saved; Back during the wait stops the upload and saves the rest, saying so. The app bar's Save stays off while an image uploads ([D53]).
- A draft of a task created offline follows its temporary id ([D35]) to the server id.

**Not done:** Android's WebView renderer crash is not handled natively as on iOS, where the page offers Reload (why: webview_flutter_android 4.14.1 does not expose `onRenderProcessGone`, and wrapping its `WebViewClient` natively is fragile). Android ends the app, and the draft brings the edit back at the next opening.

Limits:
- Up to about a second of typing, plus the time the HTML takes to read, can be lost when the app is ended.
- After a leaving answer, a Save that takes over 30 s, fails or asks again refuses the switch silently.
- Only a dialog or sheet with a question keeps its text on a switch (the New task sheet, [D98]); others, such as a new project or a link share's form, lose theirs.
- A busy sheet or a draft's offer refuses a switch from outside, and a share then shows its note although nothing may be unsaved.
- A switch while Save waits for an upload acts as Back: the description is saved without the image and the switch is refused.
- A page left after its question still slides out while the switch runs. Only the share shows a note; notification and widget opens could get one.
- That null or false means staying is a convention of the app's leave dialogs, not a type: another staying answer would make a caller wait 30 s and refuse silently, losing nothing.
- The cost of an edit report every 50 ms was not profiled.
- A WebView that stops during a slow online save ends its saving state, so a second Save could in theory start; only the wait for an upload guards against it.

## D92: Fixes from the code review: security

*Accepted 2026-11-17 (step 40c).*

Security findings S1 and S2 of the code review of 2026-11-17 ([D90]). S1 is fixed; S2 is not, by the owner's decision of 2026-11-17 (below).

**A shared link's server** (S1):
- Threat: any server the user once added, as an account or a guest, can name another server's web host as its frontend in `/info` ([D62]); trusting that claim would send a later link's hash, a long-lived secret (the threat model's R6), and a typed share password to it.
- A stored server is taken without asking only when the link's base has the origin (scheme, host, port) of the server's root and is its web frontend (the usual one-host setup).
- Otherwise the link's base is probed like a typed address, and a Vikunja server that answers there wins over any claim. Only when none answers is a stored server that claims the base offered, the first in the registry's order. A 401 or 403 offers "Add headers" and no stored server (why: it points to an access gate in front of the link's host); offline, timeouts and TLS errors offer none.
- "Which server is it?" then fills in that server's address without focusing the field, so the keyboard does not cover the card, and names both hosts, with their schemes where they would read alike, and that the link and its password go to that server if the user continues. Continue is the confirmation; until then the claiming server gets no request. Another address gets the link instead; Cancel or the demo button forgets it.
- Why ask: as with a sign-in page on another host ([D23], the threat model's [M13](threat-model.md#62-transport)), only the claiming server makes the claim and the app cannot check it, so the user decides. Why the card and not M13's dialog: the card already asks for this server's address.
- The password sheet names the host the password goes to, on the Connect screen and in the guest's "Open the link again" banner, which uses the guest's own stored server.
- The accessibility sweep has the card with a claiming server as the state "shared link server question" ([D68]).

**The Tasks widget's mutable PendingIntent** (S2), not fixed:
- Glance's `LazyColumn` gives the launcher a mutable `PendingIntent` that can start the app's components, the non-exported ones included (the threat model's [R17](threat-model.md#7-residual-and-accepted-risks)). The review wanted it closed and the widget-link key rotated when a widget is removed or set up again.
- The owner was asked to choose for 1.0 between a fixed list (immutable intents per row and an "N more" row, no longer scrolling), a scrolling list of the app's own whose template names a trampoline activity that checks every tap, and keeping the risk.
- The owner chose to keep accepting R17 for 1.0 (owner, 2026-11-17). R17 records the decision and keeps both lists for a later step. Nothing of S2 is built: the widget-link key rotates only on a fresh install.

Limits:
- In a split setup (web and API on different hosts) with an account on the device, each new link from the web host needs one Continue.
- When a split setup's web host is down or answers with an error, opening the link fails instead of silently using the stored server, the safer direction.
- Only the first claiming server is offered; the others are reachable through the known-server chips or by typing their address.
- A user who continues without reading the card, or whom a look-alike host misleads, still sends the link and its password to the claiming server (the threat model's [R41](threat-model.md#7-residual-and-accepted-risks)).
- The origin comparison lowercases only the host, so a host written another way (a trailing dot) goes through the probe, never silently.
- How TalkBack and VoiceOver read the card and the sheet's new line is part of the open manual pass ([Q19](open-questions.md#q19-device-setup-for-the-manual-talkback-pass)).

## D93: Fixes from the code review: quick fixes

*Accepted 2026-11-18 (step 40d).*

Quick fixes B3, B4, B8 and N5 of the code review of 2026-11-17 ([D90]).

**Opening from outside over About or Connection** (B3):
- "Signed in" comes from the account registry, not the route, for requests (notification taps, task and widget links, the New task shortcut) and shares alike. Signed out, a request is dropped and a share says so.
- Pages outside `/home` that cover the shell, such as About and the Connection pages, first go one by one as if the user went back, so a question there asks ([D98]); then the request runs as under `/home` ([D91]).
- When something stays, the request waits until the user is back under `/home`, then the last one runs, and nothing asks again before then (why: the user has just answered, and asking at every tap would repeat the question). One leave runs at a time, shared by requests and shares.

**Lists that show every change** (B4): tasks of a filter evaluated on the device, such as a saved filter or a label's list, deduplicate with the deep task comparison of `vikunja_domain` (why: a renamed label or a change made on the device leaves `updated` alone, so a shallow dedup hid it); the dedup stays (why: a clock tick of a relative-date filter that changes nothing must not emit). `Task ==` stays shallow (why: the sync and the outbox rely on it leaving out the reminders, [D36]); new code that deduplicates tasks uses the deep comparison.

**The label picked in the filter builder** (B8): the web and the app turn a title into the first label of that title ignoring case, so a label's title goes in only when no other label has the same title ignoring case (and a value can hold it); otherwise its id goes in, so the result does not depend on which twin the list shows first.

**Regional formats** (N5):
- The app's locale is the shipped language in the region of the device's first locale of that language ([en, en_GB] gives en_GB, [de, en_GB] gives de); a per-app language without a region takes the device's region for that language. Texts stay the language's; dates, numbers, the first weekday and the date input follow the region. The account's week start still wins.
- The clock, while the account sets no time format, follows the device's 24-hour switch, not the region (why: the switch follows the region unless the user set it, so the region's format would only overrule the user's choice). The web's 12-hour format keeps AM and PM in capitals in regional English (why: intl writes en_GB's as "am" and "pm").
- The app's own Material delegate adds the locale's formats to the language's Material class, so de_CH gets the German texts and en_GB the app's US English (why: Flutter's regional classes would mix British spelling, de_CH's all-caps buttons and an English "First page" into the app). Other languages fall through to Flutter's delegate, and Cupertino stays on Flutter's.
- Notifications, widgets, the lock prompt and the description editor follow the region too; a change of region alone redoes channels, reminders and widgets.

Limits:
- After Keep editing outside `/home`, nothing opens until the user is back under `/home`, and then only the last request; a package's licence page under About counts as staying, and a switch is refused there too.
- For another account About or Connection goes first; if an edit page under `/home` then stays, the request is dropped with them already gone.
- The share sheet's Open can still open its task under a page that covers the shell.
- `Label ==` does not compare creator or creation time and `User ==` has no avatar, so a change of only those does not refresh a list; none of these lists shows them.
- A label's title typed by hand still resolves to the first label of that title, as on the web, with no hint. The web turns `labels in 40` back into the first twin's id when it saves the filter, a web bug that could be reported upstream.
- Making the pickers' delegate the app's Material delegate goes beyond the finding; the alternative is Flutter's delegate app-wide, with its regional texts.
- If Android 13 and later or iOS report a per-app language without a region, as the update from the old app sets it, the app shows the language's default formats; not verified on a device.
- A region intl has no date data for falls back to the language's formats (no de_AT „Jänner“).
- The first resume after the update redoes channels, reminders and widgets once for everyone, as the noted tag goes from `en` to `en-US`.
- The description editor's regional tag was not checked in a WebView. Cupertino's de_CH class has an English "Clear", which only a search field shows.
- `picker_localizations.dart` holds the app-wide Material delegate under its old name.

## D94: Fixes from the code review: outbox, notifications, diagnostics, sessions

*Accepted 2026-11-18 (step 40e).*

Findings B5, B6, B7, P3 and N1 of the code review of 2026-11-17 ([D90]) and two of the review of step 40a on the notification scheduler.

**A change that keeps failing** (B5): the oldest op blocks the queue during its backoff ([D34]), so a change the server never takes must not be retried without end. Each failure is in one of three classes:
- **waits, never counted:** network failure, rate limit, lost refresh race, rejected token (why: about the network or the session; nothing else could be sent meanwhile either);
- **counted:** a 5xx, a 404 without a Vikunja code, a 3xx, and, for a create or upload only, an unreadable answer or an exception;
- **final at once:** everything else (why: a retry would only repeat it).

After 16 counted failures in a row the op becomes a sync problem, an upload after 4; Retry starts again (why 16: about 107 min with the backoff's 15-min cap, which rides out a server restart behind a proxy answering 502 and holds the queue at most about two hours; why 4: each attempt sends the whole file again, up to 50 MiB, [D53]). A create's or upload's unreadable 2xx or exception may have reached the server, so the next attempt looks it up first ([D35]), and an edit queues behind such a create instead of folding into it (why: adopting the server's task would lose the edit), and a delete queues behind it instead of being discarded at once. A 404 without a code is reported as an unexpected answer, not as a task gone from the server.

**A dead process's claim:** the first drain under another process id returns every op still `sending` at once, beside [D34]'s 5-minute rule. Why safe: every isolate runs in one process, as no plugin declares `android:process` and the iOS widget extension never opens the database ([D31]). Rejected: a claimer column, which would need schema version 2 ([D90]).

**A Done for an occurrence the task has passed** (B6): a Done from a notification or widget carries the occurrence it was tapped on ([D63]). It is ignored, queuing no op, when the task is done already, or when it repeats and that occurrence is no longer the one shown (why only repeating: only such a task moves on with each Done, losing the next occurrence and its reminder); so is a Snooze for a passed occurrence. **The tray:** every reconcile withdraws the account's shown reminder and due notifications whose task is done, gone or queued for deletion, or whose occurrence has passed; a Done from outside withdraws its task's at once (why: iOS may suspend the isolate during the drain).

**The iOS window shared by the accounts** (B7): iOS holds at most 64 pending notifications and drops what goes beyond, whatever the account, so each account gets 60 divided by the signed-in accounts, less one for its session reminder (59 with one account, 29 with two, at least 1; [D39]). Android keeps 100 per account. Rejected: the globally soonest 60, which would need state shared across isolates or go beyond 64 again; an even share needs nothing shared and never goes beyond 60. Not built: a notice "Open Vikunja to get the next reminders".

**No cancel before a schedule** (review of step 40a): only what left the window is cancelled; a changed or forced entry is scheduled again under its id, which replaces it (why: on Android a cancel also takes what the tray shows).

**Deferred inexact alarms** (review of step 40a): the plan also holds instants up to 3 h in the past, so a reconcile does not cancel an inexact alarm that Android deferred past its time (why 3 h: Android 12 and later defers an inexact alarm by up to an hour, and the rare standby bucket allows one alarm an hour). Such an entry is never scheduled anew, so one that has fired never shows twice, but the re-arm at an Android cold start ([D90]) shows one due less than 3 h before at once.

**The diagnostics log** (P3), under the rules of the threat model's [section 10](threat-model.md#10-rules-for-the-diagnostics-log):
- **What is kept:** records from WARNING up, in every build and every part (app, background run, notification and widget actions), redacted when made: the message through `redactSecrets`, one line of at most 300 characters; an error by its type only, never its text (warning, severe and shout calls alike, enforced by `log_hygiene_test.dart`); a stack by the app's own frames (`package:vikunja_*`) only, at most 8; an uncaught error as "Uncaught error (<library>)" with type and frames. Release builds log at WARNING instead of OFF ([D66]) and still print nothing.
- **Where:** one file per isolate in the cache directory, written so that a crash leaves it; at most 200 records and 64 KB per file and in the merged read; files older than 7 days are deleted, 3 earlier files per part kept. Why the cache folder: Android's backup and device transfer and iOS backups leave it out.
- **In the support details** ([D20]): they end with the warnings and errors of the last 7 days. There an account id becomes `<account-N>` (or `<account>` when gone); unless "Show server addresses" is on, a server's whole host becomes `<server-N>` and any other `scheme://host` `scheme://<server>`; `redactSecrets` runs over the whole text last. A note says these are kept only on this device, or, in a build with crash reports, that errors and the warnings before them also go with each crash report the user allows ([D113]).
- **The error screen:** outside debug builds a widget that fails to build shows "This part of the screen could not be shown." and "Copy support details" (servers hidden), which works even above `MaterialApp` or the `ProviderScope`, in English, and without a container copies the platform and this isolate's log; a failure inside it falls back to Flutter's error widget (why: else it would nest without end and hang the app).

**The copy without a preview** (the owner's decision of 2026-11-18): the error screen's "Copy support details" puts the redacted support details with the log on the clipboard without showing them first. This is an exception to the rule of [D20] and of the threat model ([section 10](threat-model.md#10-rules-for-the-diagnostics-log), rule 5) that the details leave the device only through the share sheet after a preview. Why: the copy is a deliberate action of the user; the text is the page's own, redacted, with the servers hidden; Android 13 and later show a preview of what was copied; and it works when the failure is in the router, where a button that opens the support details page would not. The other choice was such a button.

**Sessions that end while the app is not used** (N1): a session ends 72 h after its last refresh ([D22]), which only a background run or opening the app gives.
- **The warning** "Background sync is limited" says that a sign-in is needed again after 3 days without opening the app, with "Open settings" (none for iOS's `restricted`, which the user cannot lift there). It shows when the platform blocks background runs (iOS's Background App Refresh `denied` or `restricted`, Android's background restriction or `restricted` bucket), not for battery saving modes (iOS reports `denied` in Low Power Mode, which counts as paused) or the rare bucket, as a daily run still keeps a 72 h session; only while a user account is signed in (why: a guest signs in again with the link's hash, [D62]); it cannot be dismissed; the accessibility sweep has it as two states ([D68]). "Open settings" opens the app's page in the system settings without locking the app.
- **The session reminder**, one per signed-in user account, fires at the last server contact + 60 h, 12 h before the end (a sync first refreshes a token expiring within 600 s). One due between 21:00 and 08:00 moves back to 21:00 (why: in the night it is seen only in the morning). It names the host and the username, holds no task data and ignores the notification content setting, like "Sign in again"; a privacy change that shows less leaves it in the tray. It is inexact on Android, and planned while notifications are permitted, whatever the Activity switch (why: it is about the account), never for a link-share guest, and cancelled on a needed sign-in, removal and sign-out. A tap only opens the app, with no switch (why: in front the app syncs every user account, which keeps every session alive).

Limits:
- A 5xx outage longer than about one to two hours turns the queued ops into sync problems one after another; one "Try all again" sends them again ([D96]). A probe could avoid that later: give up only while a read succeeds and the write keeps failing.
- An upload that keeps getting 5xx answers is sent up to 4 times.
- The dead-process detection assumes one process: a later `android:process`, or an iOS extension that opens the database, would make it return a live claim and send an op twice.
- A Done made on the web and not yet synced is applied once more when the Done was queued while another change of the task waited ([D34], [D96]).
- A repeating task with reminders but no due date cannot be told apart in a widget row; its notifications can.
- The iOS share is even: an account with few reminders leaves part unused, and right after a sign-in iOS can hold more than 64 for a moment. The cost of listing the tray was not profiled.
- The session reminder takes the last sync as a lower bound of the last refresh, so it can come early. It and "3 days" assume the server's default `service.jwtttl` of 72 h, which the server reports nowhere. Android may deliver it late in Doze; it has at least 12 h of margin.
- A sign-out while a background run is inside that account can still leave that run's task reminders scheduled ([D40]); its session reminder is cancelled ([D96]).
- Task, sync run and saved filter ids stay in the log and the export; account ids stay in the log's files on the device, and only the export numbers them. A build with `--obfuscate` or `--split-debug-info`, which the app does not use, would keep no frames.
- The Connect screen's and sign-in's unexpected failures log only their type in debug builds too.
- Isolates of one part started in quick succession can delete a running one's log file; only one that records nothing more loses its entries, and nothing is corrupted.

## D95: Fixes from the code review: small things users notice

*Accepted 2026-11-18 (step 40f).*

Findings N6, N7, N8 and six points of N12 of the code review of 2026-11-17 ([D90]), and the review's known limits in the help page draft. The owner decided two questions on 2026-11-18 (below).

**Undo after Done in the task detail** (N6): the detail's and each subtask's Done show the lists' "Marked as done · Undo" for 3 s, kept under a screen reader; Undo gives a repeating task its dates and reminders back ([D34]). A sheet that closes while its Undo shows hands it to the sheet below or the screen (why: in a list of open tasks the row has already left, so nothing else would offer the Undo). A subtask's Done first reads the stored task (why: related tasks load without reminders); if that read fails, Undo sends no reminders, so none is deleted.

**The view a project was last left in** (N7; the owner's decision of 2026-11-18, below): a project opens on the view it was last left in, saved per account when the user picks a tab, in the format the versions before D75 wrote. A view the route names (`?view=`, as a guest's link does) wins and is not saved; a deleted view falls back to the default (the first view of the user's `default_view` kind, else the first). Deleting the project or signing out forgets it. The screen waits for the stored view, so the default neither flashes nor downloads first.

**Several tasks in a row** (N7): a pin "Keep open after adding" in the New task sheet's headline row, off by default and remembered per account; while on, an add clears title and description and keeps the rest, and confirmations show as an announced line under the title (why: the sheet covers the snackbar).
- Why a remembered toggle: Enter adds, so only a mode lets the keyboard add task after task. Rejected: a button "Add and keep open", which helps only taps; a long press on Add, which keyboard and screen-reader users do not find.
- Why in the headline row: in German the two buttons already take 278 of the 328 dp of a 360 dp phone's row, so a third control would stack them and push the chip rows out from above the keyboard ([D75]).

**Saved filters list their done tasks** (N8): a saved filter's own list shows the done tasks it matches unless its filter text says `done = false`, as on the web (why: Vikunja 0.24 and later write the web's "Show done tasks" into the filter text, and the web's List view of a saved filter has no filter of its own); an unknown or refused definition lets the server's answer decide. **The cap:** at most the 100 most recently done matches, with a note when more match (why: a saved filter can match an account's whole history, and loading every done match on each change makes the list stutter). The Overview with a saved filter, a label's tasks and the widgets still show open tasks only ([D63]).

**From N12:**
- **A muted reminders channel:** on Android the "Reminders" channel with the importance none counts as off; the Notifications section and the support details say so, with "Open settings". The scheduler keeps scheduling, so turning it on works at once ([D39]).
- **A new comment in a long thread sorted oldest first:** sending reads the remaining pages, so the comment shows last ([D57]).
- **Links typed without a scheme** ([D52]): a host gets `https://` (so `example.com:8080` is a host and a port), an email address `mailto:`; a scheme the editor keeps and a relative address stay as typed; any other scheme, such as `javascript:`, is refused at the field (why: `example.com` became a link relative to the server, and a dropped scheme made the link vanish without a word).
- **An accepted unencrypted server:** with the origin's recorded consent, a connect, an invite check and a guest sign-in do not ask again; the server overview still marks it unencrypted. A revoked or unreadable consent or another port asks again ([D8], [D65]); an address without a scheme that reached `http` only after every `https` candidate failed is asked every time ([D97]).
- **Background runs at a low battery:** Android's periodic sync also requires a battery that is not low ([D40]), for existing installs from their next registration; the one-off drain after a background Done does not (why: it sends what the user just did). Sessions stay safe ([D22]): a low battery (about 15 %, not charging) only defers runs, and the session reminder is an alarm no job constraint holds back ([D94]).
- **Account settings on resume** are read again only after 5 min, after one of the web's pages was opened from the page, or while an email change waits for its confirmation (why: its link is opened outside the app) ([D54], [D55]).

**The help page draft** lists the app's known limits ([vikunja-io-drafts.md](vikunja-io-drafts.md#the-help-page)), such as the read-only Gantt chart, the account settings that are on the web and that Vikunja sends no push notifications.

**The owner's decisions of 2026-11-18:**
- **No identifier in the task detail.** D75's "no task identifier is shown or spoken anywhere" stays ([D75]); the identifier from N12 is not built.
- **A remembered view per project** (above), reversing D75's "No remembered view".
- The points of the review of the decision log's limits that the roadmap had also listed for step 40f moved to step 40i (owner, 2026-11-18), which built them ([D98]).

The accessibility sweep covers the sheet kept open after an add and a saved filter's Done section ([D68]).

Limits:
- Swipe gestures on rows and selecting several tasks at once (N12) are [D106]'s.
- A muted "Activity" channel is not reported; below Android 8 there are no channels. "Open settings" opens the app's notification settings, not the Reminders channel's own page, which would need Kotlin that cannot be checked without a device.
- A comment posted in a long thread costs one request per page not loaded yet (20 for 1,000 comments), and "Comment sent" and the next Send wait for them.
- The cap's note leads nowhere: older done tasks are on the web or in a narrower filter. The device still evaluates every candidate on each change. With an unknown or refused definition, a task checked off on the device stays under Done until the next download.
- The rows the versions before D75 wrote count again, so a project may open on a view picked weeks ago.
- The keep-open pin's placement is to be reviewed on a device: its name is only in the tooltip and for screen readers, the headline row can scroll out of view on a very small phone, and top right is where some users expect a close button. Labels picked as new stay marked "new" after the first add (none is created twice), and a keyboard the user hid stays hidden.
- The link sheet reads `notes.md` as a host, as a browser does; an IP address gets `https://` although home servers often speak `http`; `example.com:abc` is refused as the scheme "example.com".
- A setting changed on another device shows on resume only after up to 5 min.
- A device below about 15 % for days without charging gets no background runs; the session reminder still comes.

## D96: Fixes from the code review: robustness

*Accepted 2026-11-18 (step 40g).*

Robustness findings B11 to B16, B18 and B19 of the code review of 2026-11-17 ([D90]) and points of the review of the decision log's limits (2026-11-18). 

**Local write errors** (B11): local changes await their write; a failure (a full disk, a broken database) is logged by type ([D94]) and shown, and a confirmation or Undo comes only after the change is stored (why: a message that claims a change the device does not hold is worse than none).

**The sync's purge and the writes during a run** (B12): a run purges the tasks it did not mark or return ([D32], [D33]), which must not hit a task another write stored meanwhile, such as a create's answer or a restore from the trash. So the account's lease names the run that holds it, other writes mark their rows as made during that run, in their own transaction so it works across isolates, and the purges leave such rows, except that a project reconcile still purges rows of the run's own delta that the server has since deleted; the next run removes one the server does not return.

**A crash-safe sign-out** (B13):
- The registry keeps a list of accounts still to delete, written with the removal in one step (why: a crash between removing the entry and the wipe, or a failed wipe, would leave the database, the uploads and the scheduled notifications with no account to reach them). Sign-out ends with the wipe, at most one per account at a time ([D16]). The start finishes every listed account, cancelling the notification ids stored in its database (why: no scheduler exists at the start), then wiping.
- **One registry writer at a time across isolates:** every registry write holds a lock every isolate of the process honours (`core/storage/process_lock.dart`), so no isolate writes back a stale read that brings a removed account back; reads stay without it. A holder that does not answer a ping within 0.5 s is taken over, and after 10 s a writer goes on without the lock, logged (why: a hung write must not block every isolate for good). Why not a file lock: POSIX locks belong to the process, so they do not keep isolates apart ([D26]).
- **Nothing planned after the sign-out:** cancelling a scheduler disposes it, waits until it is idle and cancels every id it handed to the OS ([D39]); the session reminder reads the registry again after scheduling and cancels itself when the account has gone ([D94]).
- A removal that fails says so, and the account stays ([D37]).

**A broken preferences file at the start** (B19): the client identity and the device language load before `runApp` with a 5 s limit each and a fallback, logged (why: unreadable preferences or a platform call that never answers held the app on the launch screen for good).

**The detail sheet when its row goes** (B14): while the project is locked or the task's row is missing, the sheet offers no change, as it would be dropped; the online parts, such as comments, stay ([D84]).

**Lists and projects** (B15):
- The due sections ignore `done`, so a task just marked done keeps its section while its Undo shows ([D43]); the Overview's tasks of archived projects have Done and the star off ([D45]).
- **The project tree follows the permission** ([D49], [D60]): a read-only project cannot be moved; another parent or the top level needs admin on the project, and a parent the user may only read is refused; a project the user may only write moves among its siblings.

**Sync details** (B16): a last run that seems to lie in the future (the clock set back) counts as due ([D33]). The unread dot clears only once the server took the mark as read ([D57]). Discarding a sync problem whose task is gone on the server (404 or 403) removes every op of the task with the row ([D34]).

**Sharing, teams and settings** (B18):
- **Make admin and Make member** read the team first and send the server's toggle only while the role still differs (why: the server only toggles, so a page that missed another admin's change demoted the member; [D60]).
- The share page reads its lists again after a change whose answer timed out, so a second Create adds no second link unseen.
- **A saved filter's description** opens the description editor, closed to guests ([D51], [D52], [D62]) (why: the web stores it as HTML, which the plain field showed as markup); it saves online with nothing compared, like a label's, writing back only the description. A new saved filter keeps the plain-text field.

**From B19:**
- **Repeats over 10 years:** the repeat editor refuses an interval over the server's `MaxTaskRepeatAfterSeconds` of 3650 days (87600 hours, 521 weeks); a sync problem with the code 4029 says that the server takes at most 10 years ([D35]).
- **Paging:** every list read whole goes through one helper in `vikunja_api` that stops at the server's page count or a page with no new id, can read one page past a full last page (teams with public ones), and stops at 200 pages (10,000 items at 50 a page) with a logged warning ([D27], [D55], [D79]).
- **Text filters are documented, not matched:** the device compares text as SQLite does (`like` ignores ASCII case only, `=` and `<` compare bytes), its search likewise. The server leaves this to its database (its search uses `ILIKE` on PostgreSQL, with `unaccent` where installed): on PostgreSQL a filter's `like` heeds case, on MySQL or MariaDB a `_ci` collation ignores case and often accents. No answer says which database a server uses, and matching another way would be wrong on SQLite servers, the default and the engine's reference, so the behaviour stays; `sql_text.dart` records why ([D51]).

**From the review of the decision log's limits:**
- **An answer that is not JSON waits:** a 2xx answer to a JSON request whose body does not parse as JSON (a captive portal's page) is an unexpected answer everywhere; the body is parsed, not the media type checked, because Vikunja's v2 answers the data export with `null` as `text/plain`. In the outbox it waits like a network failure, never counted; a create answered so is looked up first next time, and a delete answered so does not count as sent ([D34]).
- **"Try all again"** sits beside the Sync problems heading while two or more problems offer Try again; it resets only the ops still failed, then drains once.
- A sent create whose lookup finds no task, with a delete queued behind it, is dropped on the device with every op of the task and its row, without a request ([D35]).
- **A Done made on the web is not applied again:** a repeating task's Done carries the occurrence its row shows, only while the row is the server's task as last seen; when the server has moved on from that occurrence, the Done is not sent ([D34]).
- Quick add's `+project` takes only projects the user may write ([D38], [D60]).
- **nginx's 400 for a missing client certificate:** nginx's default pages for 496 and 495, sent as a 400 without a Vikunja code, are recognised: while connecting the Connect screen offers "Add client certificate"; after connecting they open the connection settings and keep queued work ([D65]).
- **A photo pick's leftovers:** on Android, image_picker's lost-data cache is read and so cleared before a pick (image_picker_android 0.8.13+25), so a relaunched pick never takes an earlier pick's copies for its own ([D53]).

Limits:
- A Done queued while another change of the task waits carries no occurrence, so a Done made on the web is applied once more then; for a repeating task without dates only `done_at` tells, so any Done on the server since the device last saw the task counts as made for the shown occurrence. An Undo after a skipped Done takes back the web's Done too.
- A proxy or misrouted server that answers every request with a 2xx page holds the queue as if offline, never as a sync problem, and writes that never read their answer fail on such a page. The contract tests are to confirm that no Vikunja endpoint answers a 2xx with other text than v2's `null` export.
- A 5xx outage of more than one to two hours still turns the queued ops into sync problems ([D94]). A database error in the drain has no hint for a full disk.
- Signing in again while the account is still listed for deletion takes it off and keeps what the failed wipe left (why: wiping first would let a wipe that keeps failing block every sign-in, as the account is known only when the browser returns).
- A background isolate's scheduler can still plan task reminders of an account the app removes meanwhile ([D40]); only the session reminder is checked again. The start's cancel from the stored ids runs only for accounts listed at the start; the normal sign-out cancels through the scheduler.
- The registry lock falls back to the old race after 10 s or for a holder that does not answer within 0.5 s, logged. It assumes one process, as [D94]'s claim does: an `android:process` or an extension writing the registry would go around it.
- The headless entry points still await the client identity without a limit, so preferences that hang, rather than fail, could stall them. With the fallback identity the User-Agent and the version line have no app version.
- A lease left by a run that died keeps marking writes until another run takes it; no other run purges by that id, so nothing is lost.
- Past 200 pages a list is cut, which only the diagnostics log says. The sessions list stops at a page without a new id, so a refresh that shifts a whole page could end it early. A `null` body (v1's empty list) reads as an empty page.
- A text filter's matches can differ in case, and on MySQL or MariaDB in accents, from the web's on servers that do not use SQLite. A probe or a setting per account would need the owner's call.
- On Vikunja 2.8.0 moving a project under a new parent needs admin on that parent too, while the tree and the parent picker check write ([D60]); the server's refusal shows as the admin message.
- Quick add still accepts a typed repeat over 10 years, which becomes a sync problem. A stored repeat over 10 years blocks Save on the edit page until it is changed.
- The show-done toggle lets Refresh start again while a refresh of the same list still runs.
- A saved filter's description editor needs a connection, like a label's on the server (one created on the device takes its description offline, [D109]); offline its save fails and the draft is kept.
- Only nginx's default pages for 495 and 496 are recognised, not a server's own `error_page`.
- An earlier pick's copy that lands only during the relaunch can still be taken; leftover copies stay in image_picker's cache folder.

## D97: Fixes from the code review: security and release

*Accepted 2026-11-19 (step 40h); the renames of 2026-11-20 (owner).*

The security and release findings of the code review ([D90]). The owner decided six questions on 2026-11-18, marked below.

**Unencrypted connections** (S3):
- An address typed without a scheme that is reached only over `http`, as every `https` candidate failed ([D8]), asks "No encrypted connection": someone on the network may be blocking `https://` (why: a network that blocks port 443 looks exactly like an `http` server). It is asked every time, also for an origin with the consent (why: the consent accepts `http` for that server, not that a network may take `https` away); the consent is still recorded. A typed `http://`, invites and shared links keep "Unencrypted connection", once per origin.
- **The offer of `https`:** the Connection page of an `http` origin probes `https` on ports 443 and 3456 and offers a new account there; the `http` account stays, as an account's id derives from its root ([D25]).
- **The `http` account afterwards:** once the same user (same user id, name, host and path; never a guest) is active over `https`, the shell offers to remove the `http` account, with the count of its unsent changes (why: with both, every reminder comes twice). Cancel stores only the account's id and that count, and it is asked again only once those changes are sent. Signing the `http` account out or removing it forgets the entry, so a new session is asked again and the id leaves the backed-up preferences (owner, 2026-11-20, [D110]).

**The `/info` probe** (S9) runs before any trust check, so it reads at most 256 KiB (why: enough for login pages to classify) and then cancels (why: in dio only a cancel closes the connection). It ends after twice the probe timeout (10 s by default), so the connector's bound of 17.5 s holds for every adapter.

**Links in rich text** (S6, R31):
- **A long press** on a link shows the address as the tap would open it, its host in punycode (why: a text that reads like one address could open another, [D44]).
- **A misleading link asks first:** a tap first shows the address with the warning "This link may not go where its text says. Check the address before you open it." when the link's text (invisible format characters left out) begins with a web address (`http://`, `https://` or `www.`) on another host (compared in punycode, ignoring case, a trailing dot and a leading `www.`), holds a bidirectional control character (U+061C, U+200E, U+200F, U+202A to U+202E, U+2066 to U+2069), or the text or address has user info (`https://vikunja.example.com@evil.example/`). Other links open at once.
- Incoming link-share and invite links with user info are refused, like deep links and attachment links ([D62], [D92]). The link dialog is an exempt overlay ([D68]).

**The app lock** (S4):
- **No Done on Android while the lock is on**, only Snooze (why: the notification plugin cannot ask for the unlock per action, so Done would run from the secure lock screen, [D64]); iOS's category `task_locked` asks for the unlock. Rejected: a Done that opens the app, which would need a foreground path through the exported `MainActivity` ([D66]), and every Done would open the app. Turning the lock on withdraws the notifications already showing, on iOS too (why: their Done would still run without the unlock).
- **Excursions**, the app's own round trips such as the browser sign-in, last at most the lock's time, never more than 10 minutes, and 30 s with "Immediately" (why: otherwise every round trip would end in a lock); a longer one counts as a hide from its start.
- **Another app's task** (R33): a `MainActivity` that is neither its task's root nor started with `NEW_TASK` restarts the intent in the app's own task, without selector and grant flags, and finishes, restoring nothing, running no Dart and attaching no plugin (why: otherwise another app gets a second UI engine on the same data). Not `singleTask`, which would clear the browser sign-in's Custom Tab whenever the launcher brings the app back.

**Photo locations** (S5):
- **Pictures picked as files** lose their location too (owner, 2026-11-18, reversing [D53]'s "A file picked as a file is uploaded unchanged"). A picture is an `image/*` type other than SVG, or decided by the file's name when the type is missing or `application/octet-stream`; other files, videos among them, stay unchanged.
- **A location that cannot be removed** (owner, 2026-11-18, reversing D53's "a file whose location cannot be removed is still uploaded"; [D76]): before queueing, the app asks "Upload with location?", saying that everyone who can see the task can see where the files were taken. Skip is the default, also when dismissed or when the task closed before the question: it leaves those files out and deletes their copies; uploading is the user's explicit choice. This covers attachments, images in descriptions and the share sheet, whose row of such a file says "location couldn't be removed". The avatar is uploaded as a PNG encoded again.

**Drafts out of iOS backups** (S9): comment and description drafts are files, on both platforms, in `<application support>/accounts/.drafts/`, inside the folder excluded from backups ([D66], [D52], [D57]), with plain key names only. What development builds left in the preferences is neither taken over nor removed ([D114]).

**Updates of the pins** (S7; owner, 2026-11-18):
- **Dependabot** for the GitHub Actions only: weekly, a 7-day cooldown, one pull request; actions stay pinned by full commit SHA ([D86]).
- **The workflow "Upstream versions"**, weekly, without a secret and with `contents: read`, fails while Flutter's stable release or the newest `cronet-bundled` is newer than the pin (why not a bot's pull request: raising either needs new checksums, notices and verification metadata, [releasing.md](releasing.md#raising-cronet)).
- **Gradle's dependency verification:** `app/android/gradle/verification-metadata.xml` holds the SHA-256 of every component the Android build fetches; the IDE's `-sources` and `-javadoc` jars are trusted without one ([releasing.md](releasing.md#gradle-dependency-verification)).

**The release** (P8), with [the rollout](releasing.md#the-rollout), [a hotfix](releasing.md#a-hotfix) and [communication](releasing.md#communication) in releasing.md:
- **German for a patch release** (owner, 2026-11-18, relaxing [D88]): a release may lack German texts only when the repository variable `VIKUNJA_APP_ALLOW_INCOMPLETE_GERMAN` equals its tag (why: a value that names the tag cannot carry over to the next release), never for an `x.y.0` or its betas; used, it logs how many texts lack German. Enforced in `tool/ci/release_lib.sh` for Android and iOS.
- **`queue: max`** on the publish job keeps every waiting publish, not only the newest; it cannot be combined with `cancel-in-progress`.
- Advisories in editor packages only the test runner jsdom reaches are information only; esbuild and the shipped packages still block, and `npm audit` omits dev packages, as osv covers esbuild. `release_sign.sh` refuses an EC APK key.

**Sideloading and the stores** (P9):
- **Per-ABI APKs** beside the universal APK, all with [D73]'s version code, so a device can move between them; each is signed, verified, hashed and published. A patch of an older line never becomes the "latest" release.
- **Updates of a hand-installed APK:** it gets none by itself, which the README, the release notes and the help page draft say; no third-party updater is named (owner, 2026-11-21, [D114]).
- The review notes name "No encrypted connection" beside "Unencrypted connection", and say that only the shared demo account is open to every visitor.
- **The held iOS plugins** bring no security fix the app needs; the pins stay until the iOS device test runs their newest versions ([releasing.md](releasing.md#held-ios-plugins)).

**The old names** (W5) in test data are renamed. The E2E usernames were kept (owner, 2026-11-18), then renamed to `vikunja-app-e2e` and `vikunja-app-e2e-2` (owner, 2026-11-20, reversing that; [D15]), with the TLS test certificates and the recorded fixtures.

**From the review of the limits:**
- **`targetSdk = 36`** stands as a literal, checked by a test (why: a Flutter update must not bring API 37 and its local network permission unnoticed, [D76]).
- The sign-in hint looks up the sign-in page's origin with its host in ASCII, as [D23]'s warning does, so an internationalised `frontend_url` finds its settings ([D65]).
- The contract tests' server image is pinned by the digest of its multi-platform index (why: so the pin works on CI's amd64 too; [D28], [D73]).
- **The `ios` job** runs on GitHub's image `xcode-27`, like the owner's releases ([D74], [D86]).

**The sync:**
- **The watermark cannot lose a task** ([D33]): the next run asks for `updated >= 'W − 120 s'`, W being the newest `updated` the run read itself, which the server reads as just above that second, so in effect `W − 119 s`. The device's clock enters only through the 1 h tolerance, which can only lower W.
- **Refreshes the user starts** (owner, 2026-11-18), such as pull to refresh or "Sync now", and moving a project or columns, wait for a run under way and then run their own; so do the outbox's refresh after sending (owner, 2026-11-18), the realtime connection's (why: the engine reports `SyncIdle` before it lets go of the run, [D46]) and the contract tests'. Automatic triggers such as the 60 s timer keep [D32]'s and [D33]'s join rule (why: a refresh that joined a run could miss a web change made after that run read its delta, and a run that read before the sender's write could store the old row after the answer, [D34], [D50]; the timer keeps joining, so it costs no run more).

Limits:
- Nothing moves an `http` account to `https` in place; its unsent changes go with it unless sent first. One kept with none unsent stays until removed. The `https` probe runs only for the first user account on the origin without an `https` twin, on the same host; a guest gets no offer, as it would need the shared link over `https`.
- On an `http`-only network, an address typed without a scheme asks at every Add account; a user who confirms still connects over `http` (R8).
- The long press is not reachable with TalkBack or VoiceOver; screen readers get the tap and, for a misleading link, the dialog. A misleading link whose text does not read like an address ("Click here") opens on a tap (R31).
- A server's `frontend_url` and legal links with user info are still accepted.
- While the lock is on, Snooze still runs from the lock screen. With "Immediately", the OAuth callback does not wait for the unlock after a round trip over 30 s; with other lock times the app stays unlocked for at most about twice the lock's time.
- The task restart waits for a device check. A caller that sets `NEW_TASK` with `MULTIPLE_TASK` or `NEW_DOCUMENT`, or finishes its own activity before `MainActivity.onCreate`, still gets a second UI engine (R33).
- Videos picked as files keep their location. On iOS an image ImageIO cannot read brings up the question, a false alarm in the safe direction. That `accounts/.drafts` inherits the backup exclusion on iOS is not checked on a device.
- `aapt2` for Linux and Windows is trusted without a checksum until the metadata is written again on Linux; a Linux runner or an IDE sync can meet a missing entry. A POM is checked only when downloaded.
- The `ios` job has not run on `xcode-27`, where the held `image_picker_ios` may fail to compile ([threat model](threat-model.md) 8.3 #1). Dependabot, the upstream workflow and `queue: max` first run on GitHub. Only `cronet-bundled` is watched.
- The rollout's thresholds and stages, the hotfix and the communication steps are proposals for the owner to confirm. A review account of the reviewers' own needs kolaente ([beta.md](beta.md#before-100)).
- The renamed E2E emails apply only to users registered after the test server's container is recreated; both users are seeded again then.
- A server clock that steps back more than 119 s hides the edits stamped in that gap from the delta until the daily full resync; creates and deletes still show in the count probe. A listener that calls `refresh()` on `SyncIdle` still joins the ending run. Some contract tests may race a running refresh; they were not audited.

## D98: Fixes from the review of the decision log's limits

*Accepted 2026-11-19 (step 40i).*

Points of the review of the decision log's limits (2026-11-18) that the owner moved here from [D95] on 2026-11-18.

- **Due date in the task sheet** ([D84]): a due date that would put two of the task's reminders on one moment asks "Change the due date?" first, and Cancel writes nothing (why: the server keeps one reminder per moment, [D36]). One chosen after the asking screen has gone is not written (why: it would drop a reminder the user never agreed to lose).
- **Default due time and relation kind** ([D35], [D41]): read from the web's `frontend_settings` (the time only as two-digit `HH:MM`, as the web reads it), set only on the web ([D54]). A date without a time takes the time it already has, then the default due time, then the next breakpoint, in the date shortcuts, chips and pickers, including the New task sheet's "Tomorrow at {time}" ([D75]'s owner decision), and in quick add as on the web, except `tonight` (21:00). An unset or unknown relation kind is `related`.
- **Leaving the New task sheet** ([D75], [D91]): with a non-blank title or description, every way of leaving asks "Discard the new task?" (a swipe down bypasses `PopScope`, so the sheet takes it through a local history entry); during an add nothing closes it. A sheet emptied by "Keep open after adding" ([D95]) closes without asking.
- **Leaving for a switch** ([D91]): after a question answered by leaving, the switch waits for the route's exit animation, at most 30 s (why: the sheet otherwise showed the next account's project while it slid out).
- **Connection editors** ([D65], [D93]) ask "Discard changes?" before unsaved headers or a client certificate are dropped; Back goes while a save runs (why: the save stores the values anyway).
- **Quick add** ([D38], [D78]): a range of numeric dates (`Vacation 31.12.2026 - 01.01.2027`) stays in the title and gives no date, as on the web; month-word ranges take the first date. A removed date phrase takes the spaces before punctuation along (`Call back tomorrow.` gives `Call back.`), [D38]'s point 11, a deviation from the web. "Added “title”" names the title the service created ([D110]).
- **A team notification** ([D60]) opens the team's page and marks it read; one without a team opens the inbox.
- **Trash** ([D79]): the delete confirmation promises the trash only when the task is surely on the server; for a create on its way, or a failed read, it says the task may or may not go to the trash. A Restore that fails in a way that may pass offers Restore again; Undo keeps D79's narrower rule.
- **A guest without a project** ([D71]) whose shared project takes no new tasks is told the link is read-only or the project archived, not to create a project.
- **Exact alarms** ([D39]): the text says reminders may come "up to an hour late" (why: without exact alarms Android delivers them in a window of up to an hour). It has a new key (why: a changed text under the old key keeps the old German until Crowdin's next export, and on Crowdin as a translation needing only approval, [D88]).
- **Accessibility** ([D68], [D69], [D81]): screen readers name the seven swatches under a "Color" heading, any other colour as "Color #hex"; Gantt text and measuring follow Bold Text. Snackbars on wide windows are 640 dp wide (why: the width of forms, sheets and dialogs, so they fit every band without a wrapper per page; the task pane would otherwise draw them edge to edge).
- **The help page draft** ([D80], [D89]) says that on Vikunja 2.8.0 and later reminders come for followed tasks ([vikunja-io-drafts.md](vikunja-io-drafts.md#the-help-page)).

Limits:
- A notification tap or a task or widget link for the active account, the New task shortcut and a newer share still close the New task sheet without asking ([D91]).
- The other sheets (new project or team, a view's or link share's form, a guest's password) still lose what was typed on a switch or swipe down.
- A switch from outside during an add is refused; a share then asks to save or discard although nothing is lost.
- The date-range rule is built from D38's note, not the web's code; an em dash and `to` do not count; `1.3 - 4.3 at 10:00` dates the task today, unchecked against the web.
- No space before punctuation is a deviation the roadmap asked for, while D38's limit had kept the web's space; it is for the owner to confirm. A name resolved after the date can still leave one: `Call @bob tomorrow.` gives `Call .`.
- With a task in the pane the shell's snackbar crosses the divider; a new narrower scaffold needs the cap's wrapper (`ReadableSnackBars`), and nothing checks for one.
- The project view tabs, the trash page's tabs and the theme segments still measure without Bold Text; the attribute card repeats the bold merge.
- Restore again is offered after a server error and the rate limit, while Undo is narrower.
- A team notification without the install's link key (an older or a forged one) still opens the inbox. The Projects tab's empty state can still ask a guest with an archived project to create one.

## D99: Battery and data

*Accepted 2026-11-19 (step 40j).*

Finding N11 of the code review and N12's bullets about the background job and the account settings.

**The daily full run** ([D32], [D33]):
- A page of a full run rewrites only the tasks that differ from the stored ones (relations compared as the stored edges, since the server nests a related task without its identifier, comment count and unread flag) or have a queued change; the others only take the run's mark, unseen by watchers (why: otherwise every list on screen reloaded once per page).
- Whether a run is the daily full run is decided when it starts, so one queued behind another run follows what that run left (why: one that decided before it waited pulled everything a second time). Refreshes the user starts, which still wait for a run under way and then run their own ([D97]), and `refreshAfterWrite()` run incrementally whenever the account has the state for it (why: a pull to refresh must not become the full run and hang for its length); the full run waits for the timer, a resume or the start. The Account tab's "Full resync" stays a full run.
- A full run that stopped continues from its checkpoint at the next full run, unless it began more than 24 h ago. Incremental runs in between leave the checkpoint, as its catch-up pass from the run's start covers what changed meanwhile. A project that became live (new or no longer archived, itself or through a parent; un-archived, restored or duplicated in the app) clears it, and the next full run starts over (why: the stopped run may have passed its tasks while they were out of reach and would purge them). A resumed run keeps the watermark of the incremental runs completed since it began, which read every change below it.

**The foreground timer** ([D33]): 60 s after a run that wrote the account's tasks, projects, labels or queue (an incremental run that finds nothing new writes none), doubling after each run that wrote nothing, up to 5 min; a write by the user or the outbox shortens it to 60 s after the last run. A 5xx and a 429 back off like a network failure; a 429 waits at least its `Retry-After`, at most 15 min (the outbox's bound), a resume too, and writes do not shorten a backoff. The activity sync ([D40]) runs on the first tick at least 5 min after its last run, as the ticks are 1 to 5 min apart.

**The progress bar** shows once a quiet run has lasted 1 s, on every screen; a refresh the user starts shows its own progress (the pull's spinner, for at most 9 s, [D117]; Sync now's).

**The background job and the account settings:** the periodic Android job runs only with a network and a battery that is not low; the account settings read the server on a resume only after 5 min, after one of the web's pages or while an email change waits ([D54]).

Limits:
- Projects and labels are still read on every incremental run (why: reading them less often would leave a new project's tasks without their project, and a deleted or archived project in the lists, until the next read); the adaptive wait cuts that to one read every 5 min while nothing changes.
- The daily full run still pulls the tasks of archived projects, as skipping them would need to know they were archived before the run and pulled after their last edits; unchanged pages are not written, so they cost requests only.
- A write by another isolate (a background run, a notification action) does not reach the foreground timer, as Drift's table updates are per connection; its next run finds the change.
- A write that stores what was there (a full run's projects and labels) counts as a change for the timer.
- The timings and the battery and data saved are estimated from request counts, not measured on a device.

## D100: Small things users notice, part 2

*Accepted 2026-11-19 (step 40k).*

The rest of finding N12 of the code review, N10's documentation, the owner's answer to S8 and the review's small findings.

**Snooze until tomorrow** ([D39]): Tomorrow moves a reminder to the next day at the user's `default_due_time`, else 9:00, in the device's time zone. On Android it takes the place of 10 minutes (owner, 2026-11-19): Done, 1 hour and Tomorrow, and while the app lock is on 1 hour and Tomorrow; iOS's categories have all four. A notification shown before the update keeps its 10 minutes, which still works.

**A shared link's password** ([D62]): the password sheet has "Remember the password on this device", unchecked (owner, 2026-11-19); D62's rule that a share's password is never stored gives way to it. Its note says where the password is kept. Checked, the password is kept in secure storage beside the hash and used when the token has expired. A remembered password the server refuses is forgotten and the session ends; opening the link again without the check forgets it; removing the guest deletes it.

**The realtime socket on Android** ([D46], S8): dart:io trusts no user-installed CA and reads no system proxy, so for a server without TLS settings of its own the socket's client takes the system roots, the user CAs and the proxy Java's `ProxySelector` picks, asked from the platform; a CA dart:io cannot read is left out, and a failing channel leaves plain dart:io. A server with TLS settings of its own keeps its client. The user CAs stay trusted for every server (S8, owner, 2026-11-19); the threat model's R8 gives the reasons.

**Large text in the navigation bar** ([D68]): the labels stop growing at 115 % (Android) or 130 % (iOS), so at a larger text size a long press on the bar shows the destination's icon and label at full size in the middle of the screen and lifting the finger opens it, as UIKit's large content viewer does; Android's destinations then have no tooltip.

**Smaller fixes:**
- The server overview does not list webhooks and project backgrounds, which stay in the web ([D20]).
- A username of only `.` or `..` is refused before a request, as `Uri` would resolve it to the parent path (`DELETE /projects/1/`).
- The checklist count reads `data-checked` only as an attribute inside a tag, so quoted HTML in a code block does not count; the web counts it.
- A mention search that answers after its controller was disposed writes nothing.
- The store texts and the help page draft name the snooze times and the known limits; the help page explains how to let the app through Authelia, Authentik, oauth2-proxy and Traefik's forwardAuth (`/api/` only).

Limits:
- A card dropped between two cards of the same position still lands after both, as on the web: they cannot be told apart without moving one, which the server does when positions come closer than 0.01.
- The large label is not offered to screen readers, which read the labels anyway.
- The user CAs and the proxy reach only the realtime socket; a server with TLS settings of its own still uses dart:io without the system proxy ([D8]). A SOCKS proxy is not used; the socket goes direct.
- The tab bar's large label on a device, the socket with a real user CA and proxy, and Tomorrow from a lock screen are tried in tests only.
- The German of the new strings comes through Crowdin ([D88]).

## D101: Images in the editor

*Accepted 2026-11-19 (step 40n).*

Finding N9 of the code review: every image in the description and comment editor was a grey box with its alt text.

- **The page still loads nothing** ([D52]): it has no session and no network, and its content security policy allows images only as `data:` URLs. Whenever the attachment images in its document change (on load, after an insert or a paste), it names them to the app, each URL once, only attachments of this server.
- **The app loads them**, once per page load, through the account's attachment images at the size the detail sheet shows (800 px wide), the original where the server has no preview (4038), and sends each as it arrives. A PNG, JPEG, GIF or WebP goes as it came when it is at most 1 MiB or at most 1,024 px wide (a PNG of the same width would be no smaller); a larger, wider one is decoded to 1,024 px wide as PNG, another image type to at most that; an SVG, or what is no image by its type, gets none, as the cache counts the pixels of images only. A page load gets at most 16 MiB of previews; an image that would go past that keeps its placeholder for that load while later ones that fit are still sent, so whether one shows does not depend on later edits. Images that fail (offline without a copy on disk, gone, too large) keep their placeholders. Closing or reloading the page ends its loading.
- **The page shows them** in the image's node view, at most 400 px high, and accepts only a raster `data:` URL for an attachment of this server. The node's attributes, and so the saved HTML, stay as they were. A preview belongs to one page load; a reload asks again.
- **Screen readers** name a shown image by its alt text, else "Image"; a placeholder keeps "Image (not shown while editing)".

Limits:
- An image that is not an attachment of the account's server (a link to another site) stays a placeholder: the page would have to load it, which the policy forbids.
- An attachment of a task the user cannot read keeps its placeholder.
- The previews in a real WebView on Android and iOS, and how a large one scrolls, are tried in tests only.
- The German of "Image" for a shown image comes through Crowdin ([D88]).

## D102: Quick add: parser fixes beyond the web

*Accepted 2026-11-19 (step 40p).*

Finding B10 of the code review and two fixes from the web's open pull requests (#4421, #4424). The grammar stays the web's ([D19], [D38]); these are bugs the web has too, kept as deviations (`D102-n` in the code and tests) and proposed upstream in the draft "Quick Add Magic misreads dates and removes text".

1. **An apostrophe and a letter end no keyword:** `today's`, `may's` stay text, even with the keyword elsewhere (`Fix today's build today` gives `Fix today's build`); a closing quote (`today'`) still ends it. The web gave `Fix 's build`.
2. **A time is a clock time:** after `at` or `@` the number must end there and be 0–23, or 1–12 with am/pm, with two-digit minutes 0–59. Anything else stays in the title; a later valid time still counts and is removed only where it stands (`Visit at 221B Baker street at 22` keeps `at 221B`). The web turned `Meet at 221B Baker street` into `Meet1B Baker street` at 22:00 (#4425 fixes part of it).
3. **An ordinal joins only the month beside it** (`5th may`, `may 5th`), today or ahead, else next year; a day that month never has is no date (the web took a month word from anywhere and kept passed dates).
4. **`next` on the weekday itself is a week ahead**; a bare weekday that is today is today. `this friday` works, as in #4424.
5. **Calendar dates:** today's date is today (the web moved it to next year); absolute and day-and-month dates take the default time ([D38] point 5), not 00:00. A number after `v`, `version`, `release`, `build`, `update`, `patch`, `rc`, `beta` or `alpha` without a year is no date (the web read `Release 1.2` as 1 February).
6. **A day the month never has is no date** (`apr 31`, `31st feb`), where JS rolls it over (#4426); `29 February` without a year is the next leap year's.
7. **Labels, projects and priorities leave the title only as whole tokens**, so removing `*bug` keeps `*bugfix`. A quoted token or a found name also ends at punctuation before a space or the end (as a removed date can leave punctuation there); an unquoted token before punctuation includes it (`!3,` stays). Every token takes along the repeated prefix the web drops (`**bike`). The service and the composer use the parser's own tokenizer ([D38], [D110]).
8. **A priority is a whole number from 0 to 5:** `!2fa` is none, `!03` is 3 (the web used `parseInt`, #4421). The composer highlights the token the parser removes, whole.
9. **A date on today never takes a default time that has passed** (owner, 2026-11-19): the date becomes 23:59 of today instead (why: the web keeps the passed time, so the task is overdue the moment it is set). This holds for quick add's date phrases and repeats without a date, and in the pickers for a date-only pick of today and for Today on a task whose time of day has passed. A time typed with `at` or picked stays; other days keep the default time (`tomorrow` after 21:00 is 09:00). Cancelling the clock after a day was picked counts as a date-only pick of that day ([D116]).
10. **German short dates** (owner, 2026-11-22, [D117]): `17.12.` and `17.12.2026.` are dates, and ranges with a final dot stay text. A lone `am` right before a dotted date goes with it, unless a number before it makes it the time's suffix (`at 9 am 17.12.` keeps it). Point 5's guard words gain Kapitel, Abschnitt, Seite, Folie, Teil and Nr., so `Kapitel 3.2` stays text.

Limits:
- The version words are a fixed list of English and a few German section words; `Release 1.2` in another language still reads as a date.
- `Fix today's build` keeps `today's`; a user who meant today types `today`.

## D103: Test hygiene, dead code and shared helpers

*Accepted 2026-11-19 (step 40r).*

Findings W3, E4, part of E3 and E2, and part of E5 of the code review. Nothing a user sees changes.

**Tests (W3):**
- The time budgets (the filter evaluation of 5,000 tasks, 300 ms; `vikunja_logic`'s parse, bind and first pass over 5,000 tasks, 150 ms; the Gantt layout, 50 ms; the timeline's layout and first frame, 40 and 600 ms) are checked only with `VIKUNJA_BENCHMARK=1`; otherwise the tests print the time and check everything else (why: a busy CI runner had failed one). The ReDoS guards with budgets of seconds stay unconditional.
- A realtime test that waits for frames gives up after 5 s.
- The contract test "v1 and v2 agree" (lists) reads until two reads in a row agree, as an assignment bumps `updated` asynchronously.
- `shellcheck` checks `tool/*.sh` and `tool/ci/*.sh` where it is installed.

**Dead code (E4):** a request's filter is merged with a view's or a saved filter's at the expression level, not by joining the texts; a saved filter's include-nulls is handled there ([D51]). A view's search builds its matcher once, not once per task. Helpers only tests used live in the tests.

**Shared helpers (E3, E2):**
- The requests and the realtime socket add a server's stored headers by one rule and record a pin mismatch through one recorder, which hands it to the stored settings once per origin and certificate (why: the socket handed it over on every reconnect, a read under the settings' write lock each time, [D65]).
- One timer type and one copy each of the time helpers in `core/time/`.
- Copying a secret goes only through the sensitive clipboard, by one widget, for the link share's address and the one-time secrets.
- The user settings' second JSON codec shares the reading rules only: the stored shape stays flat, as one shape would need a migration.
- `CONTRIBUTING.md` says why `tool/ci/play_upload.py` uses the standard library only, and how to check the time budgets.

Limits:
- The fixture scripts' helpers stay copied: their copies differ, and merging them would change what they record, which only a new recording against the server could check. The two Python dev tools keep a `credentials` and a `call` each.

## D104: Performance on large accounts

*Accepted 2026-11-19 (step 40s).*

Finding W2 of the code review: measure with 5,000 tasks first, then change only what stutters.

**Measured** with 5,000 tasks in 20 projects in a real Drift database (`test/performance/large_account_test.dart`): the open tasks of the active projects, the searchable tasks, and a write until a watched list has reloaded each take 21 to 32 ms, favourites and projects under 1 ms, in debug mode on the development Mac; a mid-range phone may take three to five times as long. None of this stutters, and the lists reload only for real changes ([D99]). The test keeps the numbers in view, with budgets that hold only with `VIKUNJA_BENCHMARK=1` ([D103]).

**Changed, as plain waste:**
- Deleting a project counts its tasks with one query instead of loading every task of the account.
- When another account becomes active, the previous account's attachment images, up to 32 MB, leave the memory; the provider that does it is listened to from the start, as a provider nobody listens to is paused.

**Left as they are:**
- The five steps before `runApp` run in their order on purpose: the app lock must hold before the first frame, and the previous app's import before the accounts load; the rest already runs side by side. Measuring them needs a device.
- The detail sheet reads its details again after the user's own change, as the server may have changed what was sent (merged reminders, a moved done date); it costs a request, not a frame.
- The foreground heartbeat's write every 30 s and the board's per-card work, which the review itself left out.

Limits:
- Nothing was measured on a device, nor with the widget tree of such an account.

## D105: Architecture overview and the step record in an archive

*Accepted 2026-11-19 (step 40v).*

Finding W1 of the code review: `architecture.md` had grown to more than a megabyte, a record of every step, which a new maintainer cannot read.

- [architecture.md](architecture.md) is a short overview of the design as it is: principles, packages and the dependency rule, the layers of the app, server and sessions, database, sync and outbox, the entry points outside the screens, the editor, tests and where to start. It names no steps and carries no status markers; the reasons stay in this log, linked by number.
- The step record's archive, `docs/archive/architecture-by-step.md`, is removed (owner, 2026-11-21, [D114]); its last version is in git: `git show c2bf10d:docs/archive/architecture-by-step.md`. This log carries the decisions of later steps.
- Principle 5 keeps the wording the threat model's R7 refers to; the anchor `architecture.md#1-principles` this log uses stays.
- A step changes the overview only where the design it describes changes.

## D106: Faster work in lists: swipes, selecting several tasks, Reschedule

*Accepted 2026-11-19 (step 40o).*

Finding N7 of the code review: working through a list took a tap on each task. The design follows the app's existing look and the common practice of other task apps, not a draft of its own (owner, 2026-11-19): a positive action on the leading edge, scheduling on the other; never a delete by a swipe without asking or an undo; selecting by a long press or a Select command, with the actions at the bottom; a Reschedule on the Overdue heading.

**Swipes** on a task row in every list: toward the end marks done or not done (with Undo), toward the start opens the due-date choices; past 35 % of the width, or flung past a quarter, the action runs; crossing the threshold ticks.
- No swipe on a task the user may not change, on board cards or timeline bars, or while the list selects.
- Screen readers get the same as row actions ("Mark as done", "Change due date", "Select", after a manual list's move actions), not as scroll actions, which would run them unasked.
- No delete by swipe (why: a swipe is easy to make by mistake, and a delete would need a question or an undo).

**Selecting several tasks:**
- Starts with a long press, the "Select" action or "Select tasks" in the list's menu; in a list sorted by hand a long press held without moving selects too, and one followed by a drag moves the row (owner, 2026-11-22, [D117]); while the list selects no row lifts.
- The app bar shows "N selected" (a live region) and Select all; a bottom bar holds Done, Due date, Priority, Move and Delete (why: five named actions do not fit beside the count on a phone, and the thumb reaches them there). A selected row reads as checked; the start and the end are announced.
- Only tasks the user may change can be selected; the actions take only the selected tasks the list shows. Back, the close button, an action that wrote something, another view or another account end it. On Android Back ends it before anything else goes back, on the Overview too; on iOS the edge swipe goes back and ends it with the page ([D116]).
- Each action writes one queued change per task ([D34]), never the server's bulk endpoints, which replace whole sets ([D36]), and offers Undo. Due date asks once when some tasks would get two reminders on one moment, and its Undo sends their reminders too, as the server kept only one. Move offers the projects the user may write to. Delete asks "Delete N tasks?" in the words of the single delete (for the trash, a guest and a server without it) and takes the tasks out of the pane; with the trash its Undo removes a delete still queued and restores one the server made; without the trash there is no Undo.

**Reschedule** on the Overdue heading (Overview, Upcoming, saved filters, a label's tasks) works like the selection's Due date for every open overdue task the user may change. Today keeps each task's time while still ahead and takes 23:59 otherwise, so none is overdue again at once ([D102] point 9). Not offered while the list selects.

**Today after 21:00** stays in the date shortcuts, which the web hides because its default time would lie in the past; here it takes 23:59 ([D102] point 9), and Reschedule needs it most in the evening.

Limits:
- The swipes are fixed; Todoist and TickTick let the user choose them. Labels, assignees and reminders cannot be changed for several tasks at once.
- No selecting on a board, in a timeline or in search.
- A selected task created on this device leaves the selection when its create is answered, as its id changes.
- The checks with TalkBack, Switch Access and VoiceOver on a device are open ([accessibility checklist](accessibility-checklist.md#28-checks-of-step-40o)).

## D107: Fixes from the make-up reviews of steps 40j to 40v

*Accepted 2026-11-19 (step 40x).*

The make-up reviews of steps 40j to 40v and of the today rule. The fixes are stated where they belong: the sync in [D99], quick add in [D102] and [D38], the editor's images in [D101] (threat model E16, B4, M27), the time budgets in [D103] and [D104]. What only this entry says:

- **The navigation bar's large label** ([D100]) measures at the label's own size, with a hair of tolerance for Android's float arithmetic at the bar's 115 % (why: under Android 14's nonlinear font scaling, which does not scale 100 sp, it never turned on).
- **A Tomorrow snooze behind a full notification window** ([D39]): the first snoozed entry after the window stays scheduled.
- **Selected images in the editor:** showing a preview changes only the preview's own classes, so a just-inserted image keeps its outline and is not replaced by the next keystroke.
- **The help draft** says that letting `/api/` past a sign-in proxy also opens password sign-in and registration.
- **The socket's certificate mismatch** is recorded once per certificate, and again after "Keep current" ([D103]).
- The subscription reminder contract test gives its writes 45 to 105 s before the server's cron run.

Limits:
- A project un-archived or restored while a full run is still running can still have that run purge its tasks below the cursor; an incremental run brings them back.
- A second snoozed notification behind a full window is still forgotten: iOS keeps room under its cap for one per account.
- Once the editor's 16 MiB are used up, the images after still load before they are left out; an animated GIF or WebP up to 1,024 px wide goes whole, also over 1 MiB.
- Seen, not changed: an ordinal's month word is removed at every occurrence, as on the web; an absolute date removed elsewhere is cut out of a longer date (`9/11/2022`); `*'kid's'` is read as the label `kid` while its token stays; `Ask @bob @bob,` with `bob` resolved loses `@bob` from `@bob,`.

## D108: The task detail sheet and the project screen in smaller parts

*Accepted 2026-11-19 (step 40l).*

Findings K1 and K2 of the code review: the two largest screens were the hardest way in for new maintainers. They are split without a visible change: texts, keys, semantics, focus order, announcements, timing and writes stay as they were.

**The task detail sheet** (K1):
- Each section is a widget or section function under `features/tasks/presentation/details/`. The list keeps exactly the same children in the same order, so its scroll and screen reader positions stay.
- The action flows (done with the hand-over of its Undo, a subtask's done, delete with the bin's Undo, duplicate, follow, reactions) are in `TaskDetailActions`, a `ChangeNotifier` the sheet owns, which takes the sheet's context for its dialogs and messages.

**The project screen** (K2):
- What a view shows is a sealed type, `ProjectViewContent`, with one subtype per view kind, so a failed load retried while another kind's view still shows builds no content of the wrong kind.
- Each kind's provider choice, listeners, controls and body are in a `ProjectViewDelegate` subclass.
- The refresh state (the queued-positions follow-up, the stale and quiet downloads, their failures) is one mixin keyed by view id (why: a view keeps its id when its kind changes, and one follow-up spans list and board views).
- The app bar, the tabs, the menu, the project management actions and the selection ([D106]) stay in the screen.

Limits, left for the later steps the review suggests:
- No controller per account and task yet: the sheet's State still holds the comments, the draft, links, relations, the edit pages and the checklist ticks, and `TaskDetailActions` needs a widget tree to be tested.
- No widget per view kind with its own refresh state: the selection and the view shown while the next one loads need the content in the screen's build, and per-kind refresh state would change when downloads run.
- `build()` of each screen is still long: the sheet's permission logic and editor wiring, the screen's view resolution and app bar.

## D109: Offline details: stored task details, images on disk, labels created offline

*Accepted 2026-11-20 (step 40m).*

Finding N4 of the code review: offline, the task sheet had no comments, reactions or attachments, a downloaded attachment could not be opened, a label typed in quick add stayed in the title, and previews and avatars were placeholders after a restart.

**The task details the sheet last read** (schema version 2):
- Tables per account keep the details, attachments, reactions and comments last read, with the people by name in the row. People are not written to `users` (why: every list stream watches `users`, and each read would reload every list). The migration only creates tables.
- A read that started before a write never stores the old state over it; a write the server took updates only what was stored.
- The sheet shows the stored copy while the first read runs, and with its age when the read fails for a reason that may pass (no connection, a server error, a rate limit, a rejected token, or a captive portal's answer; why: a boarding pass behind an airport's portal still shows). A task gone or no longer allowed shows the failure, not the stored copy. Notes say how old the stored parts are, with Try again; the comments' note is announced.
- Offline, a downloaded attachment opens, shares and saves; writes that need the server (Delete, the cover, comment edits, reactions) are off and say "This needs a connection to the server." to screen readers, without the error colour.
- On a phone an open task sheet covers the shell's offline banner, so offline it says "Offline — showing saved data" under the title, with Try again (owner); not in the pane beside a list, which the banner spans.

**Images on disk** (one cache per account):
- It keeps attachment images, previews and originals, and avatars as they load from the account's server, and answers only when the server cannot be asked or sends no image (a login or maintenance page). An attachment image kept already is not written again (why: attachments never change).
- At most 100 MB per account, least recently used first out; none unused for 30 days; raster images only (`image/*`, never SVG) up to 25 MB and 40 megapixels, checked when written and when read.
- A missing or forbidden attachment, or a missing user, is not read from disk and is deleted there; so is an attachment deleted in the app.
- Sign-out and account removal delete the account's folder, else the next start's wipe does; folders of accounts the registry does not know are deleted, unless the registry cannot be read. The folder is out of backups on both platforms ([D66]); the description editor page still gets `data:` URLs only ([D101]).

**Labels created offline** (owner, "Offline anlegen"; [D36], [D60]):
- A new label from any place is stored at once under a temporary negative id, with a queued `createLabel` op. `createLabel`, `updateLabel` and `deleteLabel` share the queue's order, with the label in `outbox.label_id` and task id 0. Blank titles and titles over 250 code points are refused; a link-share guest creates none.
- A task update naming a label whose create is queued waits for it. The sync never purges or overwrites a label with a temporary id or one a create got during the run, and the filter builder never offers one.
- Edits fold into a create that has not left the device, except one from quick add or the New task sheet (which takes the server's label of that title, ignoring case); otherwise they queue behind it. A label the server has with nothing queued stays online ([D60]). The Labels page marks a label with something queued "Not yet synced".
- Deleting a label whose create is not on its way cancels it without a request (why: a label a lost attempt made comes back as an ordinary label, which is better than deleting another of that title).
- A lost answer is looked for before the next request: the newest label of exactly that title by this user, created from an hour before the first uncertain attempt to an hour after the create's request last left the device, that the device did not have and nothing else took.
- A refused create, edit or delete is a sync problem named by the label, with Retry and Discard.

**Whole pulls:** a run clears only the whole-pull marks made before it began (why: a run under way would otherwise miss an un-archived, restored or duplicated project's older tasks until the daily full sync).

Limits:
- Comments shown newest first store only the pages read, so offline the oldest page can show reversed; offline there is no Load more.
- The stale-read guard is per isolate, so a background upload does not stop a details read in the app, which can store the list without the upload until the next read.
- After a failure that may pass while the device counts as online, reactions, attachment Delete and the cover stay offered and fail with a message.
- Images: offline each waits for the network error first; avatars sent as `application/octet-stream` are not kept; attachments deleted elsewhere keep their images until a load gets NotFound or Forbidden or 30 days pass; an account not used since the start is aged only when it is used; each account's folder is bounded on its own.
- A task update adding a label whose create waits holds back the task's other fields and later ops, as relations do ([D41]), until Retry or Discard if refused.
- A label created here cannot name a server filter until its create is answered; its title stays as typed.
- The lookup can adopt the user's own label of that title made elsewhere within that hour, as for tasks ([D35]).
- Not built: a pending marker on the label's own screen and form.

## D110: Structure: state machines, one outbox machinery, checked layers, one loading helper, a parity suite

*Accepted 2026-11-20 (step 40q).*

Findings K3 to K7 of the code review, the merges of E2 and E3 left by [D103], and W3's scenario suite. It restructures code for maintainers: no schema, stored key, stored format or string changes, and nothing a user sees changes except the fixes of bugs found on the way, which the owner asked for (owner, 2026-11-20: "fix all found bugs in 40q").

**The parity suite** (W3, `app/test/parity/`): one body of cases runs through the app's own sync engine, outbox and repositories against the unit tests' fakes and the local test server, so a fake that drifts from the server shows. Cases match failures by kind, never by code, and never ask which backend they run on. The fakes' group runs with the app's tests; the server group runs over v1 and v2 with `VIKUNJA_CONTRACT=1`, against the pinned server only ([D28]). The fake names a task's or label's creator only when given one; the parity backend gives it.
- **Divergences the fakes keep on purpose**, which the cases avoid: a task's identifier and index (`-<id>` on the fake, `#<index>` or `PREFIX-<index>` on the server); `updated` in microseconds on the fake, seconds on the server; a gone task's code (4002 on the fake, 4040 from Vikunja 2.8.0's trash; both `taskGone`); a task whose project was deleted, which the fake removes and 2.8.0 keeps in the trashed project; projects the fake creates without a permission or owner, shown as the user's own with admin permission.

**One outbox machinery** (K4): the queue and the upload lane share one lane state, but their loops stay apart, as they differ on purpose (the queue's oldest op blocks those behind it, the upload lane takes the oldest ready upload). One rule rewrites or drops a queued task update; one rule says which ops may leave something on the server without an answer (task and label creates, uploads).

**State machines** (K3):
- The description editor's load, the app lock's overdue rule (a clock that went back counts as passed; [D64]) and the filter field's count are each one state with pure transitions.
- **The session manager, partly** (owner, 2026-11-20): one sealed stop state (ended, retired) replaces the flags and epoch counter ([D26]), one sealed note per send replaces [D59]'s marker fields, and its decisions are pure functions with table tests (`core/auth/session_manager_states.dart`). The refresh flow stays a sequence of awaits.

**Layers and account state** (K5):
- `app/test/app/layer_imports_test.dart` checks `app/lib`: `core/` imports nothing from `features/`, `app/` or `bootstrap/` but the localisation in `app/l10n/`, and nothing by a relative path; `app/l10n/` and `app/layout/` import only the generated localisations and each other; `bootstrap/` is imported only by itself and `main.dart`. An exception needs an entry with its reason; the only ones are the home-screen widgets' code in `core/widgets/` ([D63]).
- The account data wiper lives in `features/session/` (why: it reaches every store of an account, the features' included). The widget worker's entry library keeps the path `WidgetActionsWorker.kt` names.
- `app/test/security/account_wipe_test.dart` fills every store of two accounts (preferences, secure storage, drafts, account folders, downloads, images on disk, notifications, widgets) and signs one out: nothing that names it is left but its widgets' "Account removed" and their config, the other keeps all its own, and a guest's hash, token and password go too. Every function that builds a String from an account id must be listed with how the test covers it.

**Pages that read the server** (K6): `LatestRead` (`features/common/presentation/latest_read.dart`) holds the one rule: the latest read wins, only while the page is mounted; a failure keeps the last value and is logged by type; a change made on the page during a read reads again after it. The teams, shares, trash, sessions, API tokens, CalDAV and export pages use it ([D55], [D60]), so a removed session or token cannot come back with an older answer.

**K7:**
- **One tokenizer** (owner, 2026-11-20; the scouting had put it off, as it changes edge cases): `quickAddTokens` splits prefixed items exactly as the web's `getItemsFromPrefix`, and the parser, the composer and the service all use it ([D38], [D102]). The service hands back the titles as created, which "Added …" names.
- `package:html` is held at exactly 0.15.7 in `vikunja_logic`, as the bounded parser subclasses its internals ([D58]).
- `tool/ci/test_release_publish.py` checks the Bash copy of the version scheme against `release_version.py` ([D73]).

**Merges** (E2, E3):
- Pages over the tab bar are bound to the account unless stated otherwise, and an account switch blanks them (pinned by `router_structure_test.dart`).
- The delete-task dialog uses the shared adaptive confirmation with [D79]'s texts.
- The list and table controls stay two public widgets over one private builder (why: a switch between them must replace the chips, not animate the done chip's check).
- A details or comments refresh under way when a change is made is dropped and read again once no write is pending (an object both controllers hold, as a mixin's private members cannot cross libraries).
- `vikunja_api` reads a streamed error body up to 64 KiB. Stored profile and settings are read by the server's rules (a two-digit default due time, an Overview filter id of −2 or less, no date of the year 1 or before), which every value the app has written meets.
- One issued access token type serves the previous app's sign-in and the browser sign-in, for which `browser_sign_in.dart` was edited (owner, 2026-11-20); the previous app's logout stays apart ([D85]).
- The requests and the realtime socket each hold the second handshake for a refused client certificate ([D65]).

**Fixes of bugs found on the way** (owner, 2026-11-20):
- A task created offline and marked done before its create was answered follows its server id, so no ghost row stays ([D34]).
- A description editor page that becomes ready after the 20 s timeout shows the editor ([D52]).
- An upload lane that waits only for uploads another isolate sends names no failure ([D53]).
- **Sessions** ([D26], [D59]): a retired manager hands out no token, also none from a refresh still running (tokens whose write began before still land in storage), and a refresh that failed for now does not fall back to the old access token. An unreadable registry during a refresh acts like a missing connection: the account stays signed in, and the warning names only the error's type. After a session-end answer (16003, 412) moved a refresh to another token that lost a race, the re-reads go on from the token refused; no refusal is noted for a token the server never refused. The last defer-or-end decision checks the refusal window (15.75 s) against the token sent last.
- Signing out or removing an account forgets its kept `http` twin entry, so the id leaves the backed-up preferences and a new session is asked again ([D97], [D66]).
- A realtime upgrade on the profile's own `dart:io` client that TLS 1.3 ends without naming a refusal runs the second handshake (its answer kept 10 s per origin); a confirmed refusal ends realtime until the next resume, with polling as the fallback ([D65]).

**Rejected alternatives:**
- Full transition machines for the app lock (each flag stands for a device quirk checked on devices), the filter field and the editor beyond its load; and the session manager's whole lifecycle (unread, live, ended, retired), which the owner left out (owner, 2026-11-20).
- Moving `core/widgets/` into the features (`core/` uses it; moving its helpers waits until after 1.0) or layering `core/` within itself (a redesign).
- A key prefix `account.<id>.` for every per-account preference, or one stored shape for user settings and the wire's: each needs a migration of every install, and the wipe test gives the guarantee without one.
- Merging the previous app's logout with the sign-in's ([D85]), or aligning the browser sign-in's web frontend rule with `webFrontendBase` ([D23], [D65]): both change behaviour.
- An input-size check before the HTML parser (it changes behaviour; the budgets bound the quadratic paths already); the Bash version check calling `release_version.py` (the test protects the same).
- One lease wrapper for both runs (the incremental one checks again and counts requests); three further outbox merges (more indirection than they save; equal only in practice, unprovable; too small); `RefreshableList` and the people searches on `LatestRead` (many screens for little); rebuilding the nullable active-account providers and the two filter paths before 1.0, which the review itself keeps.

Limits:
- Guests are not aligned with the users' sessions: a guest whose server connection is missing from the registry fails with `SessionEnded` without being ended on the device, and an unreadable registry passes its raw error on ([D59]).
- A manager retired while a token write fails keeps those tokens in memory; nothing hands them out, but each later call reads storage once before it throws.
- A saved filter's quiet download is still decided in `build`, as Riverpod 3 does not pause `ref.listenManual` while another page covers the list; in `build` the download waits until the list shows again.
- The outbox's label search by title reads every page without a cap ([D27]); the sync's page collector keeps its own rule on purpose.
- The three lifecycle listeners E3 named stay as they were.
- The parity suite has no kanban case (the fake imitates a server bug there) and no second user; the contract tests keep their own wrappers until one of their files is next changed, and overlapping cases, as they pin version-specific server details.
- The socket and the requests keep separate answers of the client-certificate check, and an `HttpException` naming another alert runs the check too.
- A page's Retry stays on during a read, so a double tap sends two reads; the later wins.
- A new page over the tab bar must update `router_structure_test.dart`'s count and decide whether it is bound to the account. The created titles are empty unless the service fills them, which only the local quick add service does.

## D111: Tests before production: a contract matrix, fixes for older servers, native tests, a scripted update test

*Accepted 2026-11-20 (step 40u).*

Finding P6 of the code review, planned for 1.0 (owner, 2026-11-19): the update and smoke tests on an emulator, XCTests for the iOS location removal and the widgets' Done queue, a test of Android's `ShareInbox`, and a contract matrix over the supported releases. The matrix found app bugs on servers before 2.7; the owner chose to fix every one rather than raise the support floor, which stays at 2.3.0 ([D13]; owner, 2026-11-20), and to download the images of 2.5.0 and 2.6.0 and add them to the matrix (owner, 2026-11-20). The emulator run of the update and smoke tests happened with the owner (owner, 2026-11-20). The owner also confirmed, on 2026-11-20, the look of a fixed follow, clearing a done or default column deleted elsewhere before 2.5, telling a gone share by a renewal after a 500 with 5 minutes between checks, the match of an identifier ignoring case on 2.3 when no project has it exactly, and the German of `followInheritedFixed` coming through Crowdin.

**The contract matrix** ([D28], [D86]):
- The workflow "Contract matrix" runs `tool/ci/contract.sh` against 2.3.0, 2.4.0, 2.5.0, 2.6.0, 2.7.1 and 2.8.0, the newest release of each minor line from the floor (Docker Hub has no patch release of 2.4 to 2.6, checked 2026-11-20), each pinned by tag and index digest: at night in go-vikunja/app, on every `v*` tag and by hand. Per-push CI stays on the latest release (owner, [D28]).
- 2.3.0 exits at a comment's notifications under immediate transactions, so it runs without them, its `vikunja_api` files one at a time; 2.4.0 to 2.6.0 exit about 30 s after a data export request, which the tests skip before 2.7, so they keep immediate transactions (why: one at a time is slower).
- Each version gate is set to the first release that has the behaviour, probed or proven by flipping it one release lower ([D13] lists them).

**Fixes for older servers** (owner, 2026-11-20), each probed on the releases concerned:
- **Writes to what the user follows on 2.4** (high): 2.4.0 over v2 refuses every merge-patch or full PUT of a followed task or project with 422 ([D13]), and 2.4 subscribes assignees, so this hit the user's assigned tasks. On v2 below 2.5 (builds after the 2.4 tag included; a development build is not gated), task field changes and project updates and moves carry `"subscription": null`, which 2.4.0 to 2.8.0 take while keeping the subscription, so a stale stored version is harmless. On 2.4.0 such a patch with nothing else answers 200 rather than 304 for a followed task, without bumping `updated`. From 2.5, and on v1, whose replace leaves `subscription` out, nothing sent changes.
- **A guest's permission before 2.6** (high): the list says read for every guest, so the app reads the shared project itself; never the token's `permission` claim ([D62]; the single read is right on every release).
- **A deleted share on v1 before 2.7**: 2.3.0 to 2.6.x answer its syncs with a 500, so a renewal of the token tells a gone share from a server error ([D62]). The app reads over v1 only on 2.3, or where a proxy hides `/api/v2`.
- **A task by its index on 2.3**: the route is missing, so a filtered read stands in ([D44]); a version gate, because the missing route's 404 cannot be told from an unknown project's.
- **Identifiers on 2.3** (low): they keep their case and are unique only in exact case, so one rule in `vikunja_domain` prefers the exact match and otherwise matches ignoring case, for the local lookup, the opener's choice of account (which skips an ambiguous one), the by-index read and quick add's `+project` ([D44], [D38]); with the data of 2.4 and later at most one project matches, so only a stale local row that repeats an identifier exactly goes to the server. Quick add matches among all the user's projects, archived and read-only ones included, before limiting them, so it never files a task into a case twin.
- **Stopping a follow through a project before 2.6** (low): the server refuses it with 403, so such a follow is shown fixed with a note naming the project to unfollow ([D41]), behind the opt-out capability (from 2.6.0, and on `/api/v2` of an unknown version, where an older server's 403 shows as an error).
- **A done or default column the server no longer has, before 2.5**: 2.3 and 2.4 answer with the deleted id, so the orphan guard could delete a column whose tasks then go nowhere. There the app reads the board first and clears such a column; such a default counts as none ([D48]).

**Native tests:**
- **iOS** ([D74], [D63]): the target `RunnerTests` holds `LocationRemovalTests.swift` and `DoneTapsTests.swift` (the location removal; the Done queue's safe account ids, a second tap before the import, pruning), without a host app, at iOS 17.0 (why: Xcode 27's XCTest is built for iOS 17, and the linker warns below it). The project and scheme change only through `tool/add_runner_tests.rb`, run after `add_widget_extension.rb`; the job `ios` runs the tests on a simulator after the release build, whose `Flutter/ephemeral` package the project needs ([D86]).
- **Android** ([D53]): `ShareInboxTest.kt` checks `isForeignContent` on the JVM: another app's provider is read, also one the app cannot see; every scheme but `content` is refused (any case), and so are a missing or empty authority, the app's own authorities, also behind user info or under another name, and an authority that only starts like the app's package; the provider after the last `@` is the one looked up; a failed lookup fails closed, as it cannot rule out the app's own provider.

**The update and smoke tests** ([D85], [threat model 8.2](threat-model.md#82-manual-on-the-android-emulator) item 13, which says what is automatic, what the owner judges and what stays by hand; commands in the [developer guide](development.md#update-and-smoke-tests-on-an-emulator)):
- `tool/e2e/update_test.sh` and `tool/e2e/smoke_test.sh` find the screen by the app's own texts from the ARB files and run on macOS's bash 3.2. They touch only an `emulator-<port>` whose AVD is `Vikunja_Screens` or `Vikunja_Tablet`, the project's own, else they stop before anything is installed; every command goes to the adb transport id recorded at the start, rechecked by AVD name before every install or uninstall, so an emulator that took over the serial gets nothing. The APKs must share one package and signing certificate, the new one with a higher version code.
- The owner does every sign-in: nothing prints a password or a token, the sign-in hint offers only the clipboard route, and the recording of the first start stops before a browser takes the focus or Connect takes input, so it never holds a sign-in. Dart's uncaught errors show only in a debug build's log, so for a release build the owner reads its support details' log.
- The old APK is 0.1.8-beta (490) from `cdbc6e3`, the commit `legacy-final` is to tag ([D87]); both APKs are re-signed with one throwaway key whose passwords stay in a private file.

**Rejected alternatives:**
- Raising the floor above the releases with bugs: the owner chose the fixes (owner, 2026-11-20).
- A v1 full replace for the 2.4 patches: a read before the write could lose a change made in between.
- Looking a task up by `s=PROJ-12` on 2.3, which finds nothing, or `s=#12`, which matches the index in every project.
- Telling a gone share by signing in with its hash again: the same 404 3006, but on the sign-in limit of 10 a minute.
- A disabled bell for a fixed follow: a disabled control cannot explain itself on a tap.
- The emulator tests in CI: they need an emulator and the owner's sign-in.

Limits:
- Not run yet: the XCTests on a simulator ([threat model 8.3](threat-model.md#83-final-ios-phase)), the contract matrix on GitHub; not seen on the emulator: a placed widget, API 35, Chrome's window names over `https`, real crash and ANR lines, a debug build's `SEVERE` lines. A screenshot taken as `am start -W` returns still shows the native launch screen.
- By hand still: the old reminders at T + 4, T + 10 and T + 25 min, whether the Quick Settings tile is gone, the web's sessions page, the old session ended on the web, the widget picker after a fresh install.
- An unknown version counts as new for the 2.4 patch, the by-index route and the opt-outs and as old for the guest's permission and the column check ([D13]).
- On 2.3, `+Ab` with no exact match but a read-only `ab` and an own `AB` files into `AB` without the chip, as quick add counts only the projects a task can go to there ([D38]). Before 2.5 the board's delete dialog does not know that a default column was deleted elsewhere ([D48]).

Accepted with the step (owner, 2026-11-20): opt-outs gated at 2.6.0 rather than 2.7; the 2.4 fix covering projects as well as tasks; on 2.3 `NotFound` rather than `Forbidden` for the identifier of a project the user cannot read; leaving the v1 previews on 2.4 to 2.6 out of the gone-share check; the cosmetic differences the tests skip ([D13]).

Open:
- Whether unsubscribing should also map the 403 for a covered task to a failure of its own.

## D112: Accessibility pass on an emulator: a scan of the real screens, 48 dp chips and widget targets

*Accepted 2026-11-21 (step 40w), the owner's decisions of 2026-11-20 where marked.*

The accessibility part of finding P6 of the code review.

- **TalkBack and Switch Access move to the device phase** (owner, 2026-11-20), together with VoiceOver ([accessibility checklist](accessibility-checklist.md), [Q19](open-questions.md#q19-device-setup-for-the-manual-talkback-pass)): TalkBack ignores the touch and key events an agent sends over adb ([D68]), so the 15 flows of the checklist need the owner at the controls, about two to three hours.
- **No Accessibility Scanner** (owner, 2026-11-20), and since 2026-11-21 not on a device either, so the checklist no longer asks for it (owner): it needs a Google sign-in on the emulator. In its place the release build was scanned on the emulator `Vikunja_Screens` from `uiautomator` dumps and screenshots, the way the Scanner checks: a tappable node without a name of its own or of a child, a tap target below 48 × 48 dp (one cut off by the screen or its scroll view excepted), text below 4.5:1 (3:1 when large), two targets with the same name and place. It covered the app's screens and settings pages, the description editor and both home-screen widgets, in English and light, then German and dark.
- **Chips are 48 dp:** the task sheet's project chip, quick add's recognised parts and suggestions and the filter field's suggestions take the standard density, as `VisualDensity.compact` lowers a chip's tap target with its look; they look the same, the extra height being transparent tap padding. Their tests check the height, because the route sweep does not see them: Flutter's tap-target guideline skips nodes marked as links, as the project chip is, and no scenario shows suggestions or recognised parts.
- **Widget targets** ([D63]): the Tasks widget's Done box is a 48 dp button named after its task (Glance's own checkbox is 32 dp and has no name); an untick from a widget drawn before the update is ignored until it is drawn again. The widget's title, which opens the list, keeps 48 dp through a spacer.
- **Contrast:** the scan's check only sees nodes with a text of their own, which Flutter gives text fields alone, so the contrast of Flutter's text stays with the route sweep, which measures it on every route ([D68]). The disabled name field on the account settings page measures 1.23:1, which 1.4.3 exempts.
- **For the TalkBack pass:** the description editor's WebView shows no nodes of its own in a dump and is itself a tappable node without a name, so whether TalkBack enters it (flow 12) stays open.

Limits:
- Not run: TalkBack, Switch Access and VoiceOver, and the scan at the largest font, which would change the emulator's system font size; the route sweep covers 200 % text on every route and 3.12× on the six core screens. The Kanban board was not scanned.
- The scan sees only what the accessibility tree exposes; a target that only the screen shows, without a node, cannot be found that way.

## D113: Opt-in crash reports through Vikunja's Sentry

*Accepted 2026-11-21 (step 41), the owner's decisions of 2026-11-21 where marked.*

Answers the deferred [Q12](open-questions.md#q12-crash-reporting): the owner asked for crash reports through Sentry, sent only after the user's consent and turned off at any time (owner, 2026-11-21), which [D20] no longer defers.

**The owner's decisions** (owner, 2026-11-21):
- **Where:** Vikunja's Sentry, in the old app's existing project as it is; no new project. The new app's reports are told apart by their release, `io.vikunja.app@<version>+<build>`.
- **The DSN:** the old app has it in its code. The owner copies it into the repository variable `VIKUNJA_APP_SENTRY_DSN` of go-vikunja/app, as the owner may create variables there; kolaente has nothing to create. A repository variable, not a variable of the environment `release` or a secret: the release job `build` has no environment ([D86]), and every build carries the DSN anyway. Without a DSN in the build the feature is absent: no question, no switch, and nothing starts the SDK.
- **kolaente** only checks the Sentry project's settings (IP addresses not stored, the data scrubbers, spike protection or a rate limit, the retention) and its region for the privacy text ([beta.md](beta.md#what-kolaente-does)).
- **Consent:** asked once after the first successful sign-in, and a switch on the Account tab under "App lock and privacy"; off by default; turning it off takes effect at once and deletes the reports not sent yet.
- **Scope:** crashes and the app's redacted error log, its SEVERE records as reports and its WARNING records as breadcrumbs.
- **The old app's "Enable Sentry"** is not carried over; the app asks anew ([D85]).
- **Downloads:** `sentry` and `sentry_flutter` 10.4.0 with their transitive packages, Sentry's Android SDK from Maven Central, and sentry-cocoa through Swift Package Manager.

**The choice** is a device setting like the theme: not asked, allowed or declined, the same for every account and guest, kept at sign-out. A value that cannot be read counts as declined, and nothing is asked until it can be read. A change takes effect at once; a failed write keeps it for this run only, and the switch says so.

**The question** shows, in a build with a DSN, over the shell after the first sign-in, for every account kind, guests and updated users included. "Send crash reports?" with "No thanks" and "Allow": neither is the default and both look the same; No thanks and back decline, a tap beside it does nothing. Its text says what a report holds, that "Before sending, the app removes server addresses, account details and anything else it recognizes as your data.", and where to change it; it promises no more than the scrubbers remove. Closed by the app (a notification tap, an account switch), it comes again at the next start; an answer is never asked again.

**The switch** "Send crash reports" ends the privacy page, with a note on what a report holds, what the app removes and that turning it off deletes the unsent reports; the support details' log note says that errors and the warnings before them go with each allowed report ([D20]). Glossary: crash reports, „Absturzberichte“ ([glossary](glossary.md)).

**A report** holds the error's type and stack trace, or a log record's redacted message, logger and error type; how it was caught (Flutter error, uncaught Dart error, Java or NDK crash, ANR); up to 50 of the app's own warnings before it; the release and build; the app's id, name, version and build; the device's family, model, manufacturer, brand, architecture and whether it is a simulator; the system's name, version and build; the Dart and Flutter versions; the tag `app.part`. By design never: the user or an id of the user, account, device or installation, the request, server names and addresses, IP addresses, file paths in texts, tokens, tasks, titles, names or e-mail addresses, the device's name, battery, memory, storage, locale, time zone, screen and permissions, the accessibility settings, screenshots, the view hierarchy, sessions, traces, profiles, replays and Sentry's automatic breadcrumbs.
- The texts are scrubbed by patterns, so what no rule recognises can still pass ([threat model](threat-model.md#7-residual-and-accepted-risks), R43).
- Android's NDK crash reports keep the load addresses of system libraries, which symbolication needs; Android maps them at the same addresses in every process until the device restarts, so reports from one boot can be linked through them. ANRs and Java crashes cannot.
- Sentry sees the sending device's IP address, which kolaente's project setting keeps it from storing.

**What reaches Sentry:**
- Uncaught errors, through the app's own logging hooks; silent Flutter errors (an image that failed to load) stay in the log. SEVERE and SHOUT records become reports and WARNING records breadcrumbs (`app.log`), each as redacted as the diagnostics log keeps it ([D94]); the log's own record of an uncaught error is skipped, so nothing goes twice.
- Until the choice is read, up to 20 reports and breadcrumbs wait in memory, and go only if it allows them. The reporter starts after the old app's import (why: its first read of the registry would run the first-start wipe before [D85]'s import). Allowing starts Sentry at once; declining closes it and deletes the unsent reports, also at every start while declined.
- **Volume:** a repeat of a report from the last 10 minutes is dropped; at most 20 reports per isolate run. Breadcrumbs have no limit; Sentry keeps 50.

**The Dart scrubber** (`beforeSend`, which drops a report when it throws):
- No user, request, server name or transaction; every text that is kept is scrubbed: the secret redaction, then rules for hosts, IP addresses, paths, `file://` and SQLite's statements; account ids and UUIDs become `<id>`; the registered hosts (address and frontend address) are replaced wherever they appear; a text stops at 1,000 characters.
- Exception values are stricter: known types keep a text without data (FormatException without its source, file, socket, TLS and HTTP exceptions without paths or addresses, TimeoutException, DioException by type, status and cause, SqliteException without the statement, InvalidDataException, PlatformException by code, the app's failures by type and code); a Dart `Error` keeps its text without double-quoted strings; anything else goes by type only ([rule 1](threat-model.md#10-rules-for-the-diagnostics-log)). An exception without its throwable (a Java exception parsed from a PlatformException) goes by type and module.
- A mechanism keeps only `code` and `library`; frames lose their source line, and frames and debug images the folder names Android and iOS pick at random per install (why: they would link one install's reports); the debug and code ids stay for symbolication.
- The contexts are an allowlist, the same on both sides: app (identifier, name, version, build, build type), os (name, version, build), device (family, model, model id, manufacturer, brand, arch, archs, simulator), runtimes (name, version, a raw description without `/` or `\`). Only `app.log` breadcrumbs pass, scrubbed when made too (why: the native SDK keeps breadcrumbs for its own reports).

**Sentry's options** (Dart):
- `sendDefaultPii` false; no attached stack traces or threads, automatic breadcrumbs, failed-request capture, client reports or tracing; transactions dropped; 50 breadcrumbs; the app's packages are its in-app frames; the dist is the build number.
- The integrations are an allowlist, so a new version's addition stays off until looked at: `EnricherIntegration`, `LoadReleaseIntegration`, `LoadContextsIntegration`, `WidgetsFlutterBindingIntegration`, `NativeSdkIntegration` (its close closes what sentry_flutter started natively) and three internal setup steps. Sentry's own error hooks are removed (why: they would send around the repeat rule, the limit and the consent check), as are screenshots, the view hierarchy, replay, frames, app start, sessions, `debugPrint` and debug images. Background isolates use the same allowlist, which also removes the isolate listener Sentry adds before the options callback.
- Native options: no sessions, automatic breadcrumbs, performance, frames or user interaction tracing, time to full display, native failed requests, screenshots, view hierarchy or package list; replay rates 0.
- The DSN is set last (why: Dart's `Sentry.init` swallows an options callback's error and starts with what was set, so a throwing callback leaves no DSN and Sentry does not start).

**Android:**
- The app starts Sentry's Android SDK itself, before `SentryFlutter.init`, so that every option that collects or sends is the app's and the scrubber is in place before the SDK handles anything. Start and stop run on a thread of their own (why: they keep Dart's order, and the native close's flush does not hold back the network settings a reconnect reads). A failed start leaves both SDKs stopped; failures are logged by class name only.
- The options are set one by one, then the DSN (an order no test can show, as the options class is final), then the markers; the rest keep sentry-android 8.64.0's defaults, and no manifest meta-data may set one. An option the SDK version lacks fails the start with the SDK disabled. Off: default PII, sessions, every automatic breadcrumb (activity, app lifecycle, system events and extras, app components, user interaction, network events), attached threads and stack traces, screenshots, view hierarchy, client reports, modules, the additional context (battery, storage), the root check, Spotlight, shake feedback, logs and metrics; tracing, all profiling, activity, frames and UI tracing, time to full display, performance v2, standalone app start; replay rates 0; tombstones, the memory limiter and historical ANRs, tombstones and memory exits; attached ANR thread dumps and raw tombstones (attachments never pass `beforeSend`), NDK app hang tracking, debug. On: ANRs, the uncaught exception handler, the NDK and the scope sync. 50 breadcrumbs, `app.log` only.
- The native scrubber (Dart's reports reach the SDK as envelopes it never sees): no user, request, server name, transaction, message, extras or unknown fields; tags only `app.part: app`; an exception keeps type, module, stack trace and its mechanism's type, never its value; frames lose variables and source context and the install folders' random segments; a thread name stays only when it matches `[A-Za-z0-9 _#()-]{1,40}`; only `app.log` breadcrumbs; the same contexts' allowlist.
- **Exits from before the consent:** Sentry reports the latest ANR of the process's history (91 days, the old app's included) unless a marker in the DSN's cache folder says it was reported. The start writes every missing marker (ANR, tombstone, memory limit) and fails when one is still missing. A marker's time is the newer of now and the newest exit in the exit history, so an exit from before the allow is never reported, even after the clock was set back; below Android 11, or when the history cannot be read, it is now. Turning reports off deletes `<cache>/sentry`, so the next allow writes them again; an exit while allowed is reported at the next start.
- **Packaging:** the manifest sets `io.sentry.auto-init` and `io.sentry.breadcrumbs.network-events` to false and removes `SentryPerformanceProvider` and `SentryNdkPreloadProvider`; sentry_flutter removes `SentryInitProvider`. No Sentry provider starts with the app; no permission or exported component is added.
- **The network security config** has a `domain-config` for `sentry.io` and its subdomains: https only, the system CAs only, so a CA that the user or a device policy installed for a server ([D8]) cannot read the reports.
- `tool/check_exported_components.py` enforces it: it fails on any `io.sentry` component, either meta-data missing or true, any other `io.sentry` meta-data (a library's manifest could bring one to set an option the app leaves at its default), and anything but exactly one such `domain-config`.

**iOS:** Dart's uncaught errors and SEVERE records only, through the Dart scrubber. Native crash, app hang and watchdog reports are off, because sentry-cocoa builds them natively, with its installation id as the user and the native exception texts, unscrubbed. Network breadcrumbs and failed requests are off, and without a sample rate sentry-cocoa traces nothing.

**Turning them off** closes Sentry (on Android the native SDK too) and deletes the unsent reports, the scope and the installation id: on Android `<cache>/sentry` and `files/INSTALLATION`, on iOS `<Caches>/io.sentry`, `<Caches>/SentryCrash` and `<Caches>/INSTALLATION`; what cannot be deleted is tried again at the next start while declined. The old app's import deletes its `cache/sentry` and `files/INSTALLATION` ([D85]).

**Background isolates** use the app's reporter in the app's isolate, so no second SDK starts; elsewhere they start Sentry's Dart SDK alone, which keeps nothing on the device, as the native SDKs are one per process. Each start reads the stored choice and the hosts again, through a registry read that does not wipe, and each report reads the choice again before it goes, else it is dropped (why: a notification action's engine lives as long as the process and is used again after the user turned reports off). Without a DSN nothing reads the preferences. Before the work ends the reports get one flush of 5 s; an iOS background run at most 2 s, within its 25 s deadline.

**The build:** the DSN comes from `--dart-define=VIKUNJA_APP_SENTRY_DSN`, trimmed, none when empty; no file of the repository holds it. The release script passes the repository variable to the bundle and both APK builds, the iOS release script reads it from the Mac's shell, and neither prints it. GitHub's log shows it, as a variable, unlike a secret, is not masked; harmless, as every build carries it. `check_sentry_dsn` (`tool/ci/release_lib.sh`) runs in both release scripts before building: unset or empty, the build goes on without crash reports; an https DSN on `sentry.io` or a subdomain passes; anything else, a space or line break included, fails without showing the value, as the network security config covers only `sentry.io` ([releasing.md](releasing.md#crash-reports)). `sentry` and `sentry_flutter` are pinned at exactly 10.4.0. `app/android/settings.gradle.kts` takes the Android Gradle plugin 7.4.2 off sentry_flutter's build classpath, so it builds on the app's 9.1.0 and nothing of 7.4.2 is fetched ([developer guide](development.md#security-checks-and-android-dependencies)); Gradle's verification lists the new artifacts ([releasing.md](releasing.md#gradle-dependency-verification)).

**Licences, manifests, stores:**
- The Android notices cover Sentry's artifacts and the code Sentry Java vendors (`tool/build_android_notices.py`); iOS has its own legal asset, `app/assets/legal/ios.md`, shown on iOS only, for the Swift packages fetched by URL, which `tool/ci/ios_notices.py` checks against the resolved pins; both `Package.resolved` files are committed with equal pins ([releasing.md](releasing.md#licence-notices)).
- Runner's privacy manifest declares system boot time (`35F9.1`), as sentry-cocoa is linked in statically and uses `systemUptime`, and no collected data; `Sentry.framework`'s own declares crash, performance and other diagnostic data, not linked and not for tracking, for app functionality ([releasing.md](releasing.md#privacy-manifests)). Play's Data safety declares crash logs and diagnostics, optional and not shared ([store-listing.md](store-listing.md#app-content)); Apple's label Crash Data and Other Diagnostic Data, not linked and not for tracking, once decided ([store-listing.md](store-listing.md#app-store-connect)). The privacy section's draft leaves the region and the retention to kolaente ([vikunja-io-drafts.md](vikunja-io-drafts.md)). The README and the store texts say that crash reports go only if the user allows them.

**Checks:** the e2e scripts decline the question (`decline_crash_reports` in `tool/e2e/lib.sh`), so they run with a DSN ([developer guide](development.md#update-and-smoke-tests-on-an-emulator)). `token_leak_test.dart` sends the app's secrets, a title, an e-mail address, a host and an IP address through the reports, and a file's name through sentry_flutter's real event processors.

**Rejected alternatives:**
- A new Sentry project for the new app: the owner chose the old app's (owner, 2026-11-21); the release tells the two apart.
- Carrying the old app's "Enable Sentry" over: the owner chose to ask anew (owner, 2026-11-21).
- sentry_flutter starting the Android SDK: it leaves the network breadcrumbs on, turns logs and metrics on, and the app's scrubber would come only after it, when an ANR of an earlier run may already be on its way.
- iOS's native reports behind a Swift scrubber: Runner's own code would have to call Sentry's API; they stay off until they can be scrubbed.
- GlitchTip or a self-hosted Sentry: Vikunja already has a Sentry project for the old app.

Limits:
- iOS sends no native crash, app hang or watchdog report; a native crash there reaches only Apple's crash reports. sentry-cocoa may still write `<Caches>/INSTALLATION`, which turning reports off deletes.
- No symbol or mapping upload yet, as there is no Sentry auth token: R8, which Flutter's Gradle plugin turns on for release builds, renames classes, and its mapping and the native debug symbols go only inside the bundle to Play and its `release-unsigned` artifact, so Java frames of renamed classes arrive obfuscated and native frames without symbols; native reports keep their debug images for a later upload. Dart frames are readable (no `--obfuscate` or `--split-debug-info`).
- Scrubbed reports are less useful: Java and NDK exception values are dropped, other exceptions go by type only, thread names outside the safe pattern and the device's state go on both sides. A Dart `Error`'s text with an unquoted value passes with redaction only.
- Errors of the start before the old app's import are not kept for the reports.
- A changed DSN leaves the old DSN's folder, with its unsent reports, markers and scope, on an Android device until reports are turned off: Sentry never reads or cleans another DSN's folder.
- Repeats are counted in memory only, so they start again with each start; a background isolate that ends within its flush, and an iOS background run after its 2 s, can lose reports.
- The background isolates send through `dart:io`, which does not use Android's network security config and trusts the system CAs. Each of their reports reads the preferences once.
- The DSN is public, as every build carries it, so anyone can send events to the project; spike protection and a rate limit are kolaente's ([beta.md](beta.md#what-kolaente-does)), as are the region and the retention the privacy section names.
- An arm64 APK still carries `libsentry.so` for all three ABIs.
- sentry-cocoa 9.34.0 is a binary: only its public headers and strings could be checked; the paths `<Caches>/INSTALLATION` and `<Caches>/SentryCrash` come from the source of 8.56.2 and are not confirmed for 9.34.0.
- The notices do not list the third-party code bundled inside `libsentry.so` (sentry-native) and sentry-cocoa, as their artifacts carry no notices for it.

Open:
- The owner sets `VIKUNJA_APP_SENTRY_DSN` before the first tag whose builds should send reports ([beta.md](beta.md#1-the-repository-and-ci)).
- kolaente's checks of the project's settings and its region ([beta.md](beta.md#what-kolaente-does)).
- The emulator and device checks of the native start, the markers, the decline helper and a report of each kind as it arrives in the project, and TalkBack, Switch Access and VoiceOver on the question and the switch ([accessibility checklist](accessibility-checklist.md#210-checks-of-step-41)).
- Apple's privacy label, and with it whether Runner's manifest declares the crash reports ([store-listing.md](store-listing.md#app-store-connect)).
- Uploads of the R8 mapping and the debug symbols, which need a Sentry auth token as a secret of the environment `release`.

## D114: Cleanup before the move

*Accepted 2026-11-21 (step 42), the owner's decisions of 2026-11-21 where marked.*

The move into go-vikunja/app ([D87]) carries no leftovers of the development builds, dead code, unused fixtures or notes that meant something only while the app was built step by step; what each step did stays in git.

**The owner's decisions** (owner, 2026-11-21):
- **The roadmap** keeps only the open steps word for word, the two dropped ones in a line each, and this step; the rest is in `git show c2bf10d:docs/roadmap.md`.
- **The step record** `docs/archive/architecture-by-step.md` goes, reversing [D105]'s archive (in git at `c2bf10d`). Comments that cited "architecture §5.8" cite [D26] alone.
- **The research:** only `auth.md` and `flutter-stack.md` go, as they cover finished work (in git at `c2bf10d`); `synthesis.md` (step 34's scope), `features.md` (the web's shortcuts for 36d) and [research/README.md](research/README.md) stay.
- **Obtainium** is no longer named in the README, the release notes, the runbook, the vikunja.io drafts or this log, reversing [D97]'s bullet, which came from the review's finding P9, not from an owner decision. The README, the release notes and the help page draft still say that an APK installed by hand gets no updates by itself.
- **Leftovers of the development builds:** the one-time removal of their preference drafts ([D97], [D91], [D52]) and the migration test of their schema version 12 ([D90]) go. Schema version 2 and its migration from 1 stay ([D109]).

**No guard tests** for names, ids or licence texts, in line with the owner's rule of 2026-11-20 ([D15]): no app test against "unofficial" (the store check, `tool/check_store_metadata.py`, still refuses it, [D76], [D83]), no store-check rule against naming the AGPL ([D76]), no test that every widget kind starts with "Vikunja", and no test of the widgets plugin's literal channel name. The widgets and storage-flush plugins' channel names are compared between their Dart and Kotlin files instead.

**Removed as unused:** dead code only its own tests used, fixtures no test reads, template leftovers, and development notes (step numbers and dated owner attributions in code became D numbers or plain words).

**Docs say how things hold today** where step 42 cleaned them: the threat model cites no decision numbers that no longer exist; releasing.md has no status notes, anecdotes or "since step" qualifiers; the glossary, the architecture overview and the branding README have no step markers, and the store listing no history clauses. The threat model, the store listing, beta.md, the open questions and this log's status lines keep their "since step" qualifiers The Crowdin rehearsal's instructions left beta.md; the owner cleaned up after the rehearsal (2026-11-21). `main`'s history was rewritten on 2026-11-21 so that every commit has the owner's GitHub address as author and committer; [D87] and beta.md say which address the GitHub account needs without naming one.

Limits:
- Drafts that development builds left in the preferences stay on the owner's own installs until the app is reinstalled or its data cleared. A development database still at version 12 has version 1's tables and is upgraded like one at version 1, as the migration creates only what is missing ([D109]); this is untested now.
- The `c2bf10d` pointers hold while the history keeps its hashes, which the import's merge commit does ([D87]).
- The roadmap's rows after 1.0 (36d, 39a, 39b, 34) become GitHub issues after the move; then the roadmap goes. Done steps are named only by this log's status lines.

## D115: The decision log shortened

*In review since 2026-11-21 (step 43), the owner's decision of 2026-11-21.*

- **Decision and reason only** (owner, 2026-11-21): the log had grown to 1.1 MB in 114 entries and could no longer be overseen. Each entry now says what holds today and why: every owner decision with its marker, the reasons and outside facts the code cannot show, the numbers that are rules, and the gaps still open. Gone from the entries' text are earlier states, "since step" qualifiers (the status lines keep theirs), the review process, test runs, and most names of classes, functions, keys and files that the code shows. The log is about 0.5 MB now; the full text from before is in `git show 41e9fc9:docs/decisions.md`.
- **Numbers and headings stay** (why: the code cites the numbers and the other docs link the headings' anchors). An overview at the top groups the entries by topic; links between entries take the short form `[D34]`, defined at the end of the file.
- **Citations checked:** every place in the code and the other docs that cites an entry was checked against the shorter text. Where one pointed at the wrong entry or said what the log contradicts, the citation or the doc was fixed (the Android manifest's Cronet comments cite [D5]; beta.md's support details include the diagnostics log, as [D20] says), and [D68] now lists the one repeated tap label the route sweep allows.

Limits:
- A detail cut here is in the code or in the text at `41e9fc9`, which holds while the history keeps its hashes ([D114]).

Open:
- Whether test results still go into a step's entry, as the accessibility checklist, beta.md (the beta log, the iOS device test) and the threat model's sign-off still ask.

## D116: Fixes from the UI/UX review, part one

*Accepted 2026-11-22 (step 44a).*

The owner asked for a UI/UX review of 1.0.0-beta.1 on an Android 16 emulator (2026-11-21). This entry holds its two bugs and the small fixes that reverse no owner decision; the larger items and the questions for the owner come next.

**Back during a selection** ([D106]):
- On Android a list that selects holds back for its own page and for the shell, so Back and the predictive back gesture end the selection first, on the Overview too (why: with predictive back Android asks beforehand whether the app handles back, and on the first tab the shell said no, so Android closed the app). A sheet, a dialog or the search page over the selecting list closes first; a selection in a hidden tab holds nothing.
- On iOS the edge swipe still goes back from a selecting list and ends the selection with the page (why: iOS has no Back to end it with, and holding back would turn the swipe off, which [D82] keeps).

**The shell reads the location of the tab's top page** (why: go_router keeps the shell's matched location after a pop inside a tab). The project tree's column therefore marks only the project actually shown: after Back no row is marked, and a tap opens the project again ([D82]). A tab's pane also closes when a pop inside the tab changes its location, such as the iOS edge swipe from a project with a task open ([D70]).

**Cancelling the clock** after a day was picked keeps that day as a date-only pick, at the task's own time or the default time, and at 23:59 when that time on today has passed ([D102] point 9). This holds in every flow, Reschedule and the selection's Due date included, which offer Undo (why: Cancel used to drop the day the user had just picked).

**Screen readers** ([D68]):
- A section heading speaks its count with its unit ("Overdue, 3 tasks").
- A toggle keeps its name and says its state: the star is "Favorite", the task sheet's bell "Follow task", each a switch that is on or off (why: a name that changes with the state, plus "selected", sounds like two controls).
- In the task sheet the attribute card's rows are read in their visual order, with Labels after the rows above it. The checklist ring is not read as a progress bar inside the Description heading. The edit page's progress slider says its name and value once, and the date chips name their field.
- Board cards are buttons at least 48 dp tall. A column's add button says which column it adds to and keeps its visible words ("Add another task to Doing", 2.5.3).
- Every bottom sheet's barrier reads Material's dismiss label ("Dismiss"), not "Scrim" ("Gitter" in German).

**Look:**
- Every sheet title has one style, a level-1 heading in `titleLarge`. At 200 % text on a 320 dp phone a picker's list gets shorter (the share sheet in German from 301 to 165 px), but every row still scrolls into reach (why: the pickers' header titles 24 sheets, so a smaller size there would bring two sizes back). The owner kept the large size (owner, 2026-11-22, [D117]).
- A section heading with an action (Overdue with Reschedule) puts its title on the action's 48 dp line, where the other headings' titles sit, also when the action wraps below it.
- The due date has one icon everywhere, the outlined calendar, with the error icon when overdue; start and end keep play and stop. The meta line's icons grow with the text, from 14 to 28 dp.
- The Table's priority column draws the rows' flag ([D61]).
- Gantt bars have a 1 dp border, primary around the default fill and outline around a task's own colour, at least 3:1 on every row background in the four schemes (1.4.11); derived bars keep their dashes.
- A swipe keeps its icon at the row's edge on both sides and shows its name only where the name fits.
- The project's views list shows a view's kind under its name only when the two differ.

**Texts:**
- Upcoming: a day picked in the strip shows in the subtitle ("Sun, Nov 22 · 2 open") beside an "All days" button. An empty range other than today says "Nothing due in this range", and so does the Upcoming widget.
- Checklist progress reads "2 of 5 checked" and "All 5 checked" (the glossary's checklist item, never "task"). One day away is "tomorrow" or "yesterday". A date and a time are joined by a message of their own, so each language sets their order and separator.
- The search field names what it searches: tasks, projects, saved filters, labels.
- Leaving the edit page with changes says when the description is already saved. Commenting offline says "Commenting needs a connection."
- The Account tab: background sync says it "hasn't run yet" before its first turn; how many notifications are scheduled on this device is a status line of its own, not the test notification's subtitle; the privacy page's title is its row's, "App lock and privacy" ([D64]).
- The server overview reads the host first, then the badges, Unencrypted and Demo server before the API chips ([D6]). The support card keeps "Fully supported", as its body already says every feature works ([D71] changes a text only when it is inconsistent, wrong, unclear or misspelt). The demo note, on the server overview and in the Account tab, also warns that anyone can see and change what a shared demo account adds.
- Connection options say "Type the server address first." while no address parses. An allowed cleartext connection shows the no-encryption icon in the error colour and repeats the trusted-network advice ([D8]); "Forget connection settings" shows only when there is more to forget than that consent.
- About: the privacy policy's row sums up the policy, no server of the app's own and, where the build has them, the crash reports the user allows ([D113]); the licences row explains the package name it lists ([D67]).

Limits:
- While a day is picked in Upcoming, the strip sits about 16 dp lower, for the 48 dp "All days" button (why: one height for both states moved the default view down instead).
- Checked in widget tests and on the Android emulator only; the TalkBack pass is still open ([D68]).


## D117: Fixes from the UI/UX review, part two

*In review since 2026-11-22 (step 44b), the owner's decisions of 2026-11-22 where marked.*

The rest of the UI/UX review of 2026-11-21 ([D116]): its larger findings, and twelve questions the owner answered on 2026-11-22.

**The owner's decisions** (owner, 2026-11-22):
- **Brand colours by default:** new installs start in the brand scheme, and "Use system colors" is an opt-in (why: the wallpaper's palette left Vikunja's blue only in the logo). Installs that never touched the switch show the brand blue too; the old app's import still sets it ([D85]). The app, the widgets and their host file share the default ([D45], [D63]).
- **Legible colours:** project folders, the task colour dot, Gantt bars in a task's own colour and the widgets' folders keep the stored hue and chroma but shift their lightness (Oklch) until they reach 3:1 against the surface they are drawn on, light or dark (why: dark colours vanished in dark mode and pale ones in light). The stored value is unchanged and the colour pickers show it; the drawn colour may differ slightly from the web's ([D75], [D81]).
- **Sheet titles stay large** ([D116]).
- **Upcoming at large text:** from 1.5× text the timeline drops its date column and rail line; the day headings stay and the cards get the full width ([D56]).
- **The version line** at the end of the Account tab is labelled "About, help and privacy", above "Vikunja app {version} ({build})" (two lines, as the glossary keeps the version after "Vikunja app"); its place and the tab's order stay ([D75], [D77]).
- **"On this device"** loses only what was doubled: the Notifications section's own paragraph goes and its follow note is one sentence ([D80]); the marks, Appearance's per-row line and the order stay ([D75]).
- **Selecting on the Overview** keeps the long press alone; its header gets no menu ([D56]).
- **Lists sorted by hand:** a long press held without moving selects, as in every other list; a long press followed by a drag moves the row ([D106]).
- **Date shortcut chips** keep their names, and one not chosen shows its day ("Next week · Sat, Nov 28"), as Reschedule does (why: Next week is seven days on there but the calendar week in Upcoming; [D75]).
- **Quick add stays English** ([D19], [D38]): a German date word without a parsed date, or a time after a date without `at`, gets a hint under the title, and the help's Dates section starts with the note that date words are English.
- **German short dates:** `17.12.` and `17.12.2026.` are dates, a lone `am` right before one goes with it, and German section words keep `Kapitel 3.2` text ([D102] point 10).
- **The edit page** takes the New task sheet's form: its headings, project field and date shortcuts (Today, Tomorrow, Next week, another date, "Pick date…"), one priority row with Unset first (so a priority can be cleared), and the description as a link to the editor ([D18], [D52], [D75]).

**The task sheet:**
- Edit opens over the sheet or the pane; Back or Save returns to the task, which says "Saved" (why: the sheet closed, so the user landed on the list).
- Start and end dates, progress, repeat and assignees are buttons that open the edit page at their field; they are still edited only there ([D84]).
- A tap on the description's text opens the editor where it may be edited; links and checkboxes keep their taps, and a long press still selects ([D44]).
- A due date changed in the sheet, the pane or by a swipe offers Undo, which also brings back reminders the change merged ([D84]).
- The bell confirms each change. On servers where reminders reach only followers, an unfollowed task says so under Reminders, with "Follow task" ([D80]).
- Subtasks, attachments and related tasks add through a "+ Add …" last row of their card, its only row while the section is empty.
- The breadcrumb's links are nodes of their own, read after Back and before the header's actions ([D112]).
- Repeat offers Never, Every… and "Same day every month"; the presets and "Count from when it's done" show under Every… ([D35]).

**Lists and the shell:**
- A task added from Upcoming starts on the selected day, else today, or a future range's first day. A single added task's confirmation offers Open.
- The Overview's tab shows a dot while activity is unread, not for guests ([D40]). The bell's page is "Activity"; "notifications" names only what the device shows (the glossary, [D71]).
- A pull's spinner ends after at most 9 s; a refresh still running then goes on under the quiet bar, with "Still waiting for the server — showing saved data" above the list. Every refresh the user starts still waits for the run under way and runs its own ([D97], [D99]).
- The Projects tab lists Favorites, All projects, then Saved filters ([D45]).
- Urgent and Do now are orange, a fixed hue shifted to 3:1 for the flag and 4.5:1 for the name (4.5:1 and 7:1 under high contrast), in rows, cards, the Table, the sheet and the widgets; error red stays for overdue (why: Urgent looked overdue, and a scheme role harmonised to the blue primary would turn red again). This deviates from [D56]'s scheme roles.
- From 1.5× text the list screens' New task button is the 56 dp icon button ([D68]). On Android rail layouts New task is the rail's leading button, offered by the screen in front ([D69]).
- On capped windows the app bars of Upcoming, the Projects tab, a project, saved filters and the Account tab keep their title and actions to the content band; the bar's surface stays full width ([D69]).
- A project row's details keep each count with its word and wrap between the parts, in every language.

**Quick add:** the typed project's chip and a locked Project field show the project's coloured folder; a row set from the title says "Set in the title"; a suggestion the typed token already names in full is hidden; project suggestions show and match the display title ("Eingang"), while completion and matching keep the server's titles ([D45]).

**Account, connection, privacy:**
- Settings sections are cards like the rest of the app, with the Theme segments in Appearance's card ([D56]).
- For a local-network host, "No encrypted connection" says the server probably uses only http:// and to type it; the question still comes every time ([D8]). Connection options say that the app tries https:// first.
- Without a screen lock on the device, the privacy page explains it in full contrast, on Android with "Open security settings", a trip that does not lock the app ([D64]).
- The glossary fixes the German terms of selecting, Reschedule, Move and Activity before translators start ([D88]).

Limits:
- After a due date changes, the row moves at once while its Undo shows.
- The selection bar and the pages over the shell keep the full-width app bar; saved filters show no open counts; label colour dots keep the stored colour.
- A dotted date inside a title without `at` after it (`Am 17.12. Zahnarzt`) is still no date, as the boundary rule for absolute dates stays.
- New texts show in English in the German app until Crowdin delivers them ([D88]).
- The widgets' new colours and their orange are checked in tests only so far, on devices at the device tests ([D74]).

[D1]: #d1-flutter-pub-workspace-with-pure-dart-packages
[D2]: #d2-material_ui-and-cupertino_ui-instead-of-the-sdks-libraries
[D3]: #d3-riverpod-3-with-code-generation
[D4]: #d4-go_router
[D5]: #d5-dio-with-native_dio_adapter-and-embedded-cronet
[D6]: #d6-v1v2-negotiation-with-capability-gating
[D7]: #d7-support-floor-200
[D8]: #d8-cleartext-only-after-the-users-consent
[D9]: #d9-flutter_test-instead-of-packagetest-in-pure-packages
[D10]: #d10-placeholder-application-ids
[D11]: #d11-docker-contract-matrix-10--20--23--24--27
[D12]: #d12-hand-written-api-adapters-over-one-shared-dto-set
[D13]: #d13-support-floor-230
[D14]: #d14-browser-sign-in-only
[D15]: #d15-app-id-iovikunjaapp-and-the-name-vikunja
[D16]: #d16-multi-account-in-the-first-release
[D17]: #d17-notification-policy
[D18]: #d18-descriptions-edited-with-tiptap-in-a-webview-shown-natively
[D19]: #d19-quick-add-keeps-the-web-grammar-and-fixes-four-parser-bugs
[D20]: #d20-scope-cuts-and-mobile-forms-of-desktop-features
[D21]: #d21-languages-english-and-german
[D22]: #d22-session-keep-alive-through-background-sync
[D23]: #d23-browser-sign-in-through-flutter_web_auth_2-in-an-ephemeral-session
[D24]: #d24-tokens-in-secure-storage-readable-after-the-first-unlock
[D25]: #d25-account-registry-in-sharedpreferences-without-secrets
[D26]: #d26-refresh-concurrency-single-flight-re-read-and-adopt-write-ahead-epoch
[D27]: #d27-paging-and-the-query-builder-beside-the-read-adapters
[D28]: #d28-contract-tests-against-the-latest-vikunja-release-only
[D29]: #d29-screens-read-and-write-through-repository-interfaces
[D30]: #d30-kanban-board-reads-deferred-to-step-20
[D31]: #d31-one-drift-sqlite-file-per-account-shared-across-isolates
[D32]: #d32-full-sync-by-keyset-paging-with-per-page-checkpoints
[D33]: #d33-incremental-sync-from-an-updated-watermark-deletes-found-by-counts
[D34]: #d34-outbox-local-first-task-writes-one-serial-sender-coalescing-retry-classes
[D35]: #d35-task-creates-through-the-outbox-under-temporary-negative-ids
[D36]: #d36-labels-assignees-and-reminders-in-the-task-update-labels-created-through-the-outbox
[D37]: #d37-account-switcher-an-avatar-sheet-a-switch-resets-the-navigation
[D38]: #d38-quick-add-the-webs-grammar-with-fixes-through-the-outbox
[D39]: #d39-local-notifications-a-scheduler-per-account-with-a-rolling-window
[D40]: #d40-background-sync-of-every-account-server-notifications-in-an-inbox
[D41]: #d41-relations-as-task-update-deltas-duplicate-and-follow-online-indented-subtasks
[D42]: #d42-app-icon-vikunjas-logo-every-variant-derived-by-script
[D43]: #d43-task-lists-from-the-local-database-nested-and-ordered-like-the-webs
[D44]: #d44-task-detail-own-rich-text-parser-online-details-app-scheme-links
[D45]: #d45-app-shell-colour-scheme-display-settings-projects-tab-smart-lists-offline-banner
[D46]: #d46-realtime-one-websocket-for-the-active-account-in-the-foreground
[D47]: #d47-kanban-board-from-per-view-snapshots-moves-through-the-outbox
[D48]: #d48-kanban-columns-managed-online-from-a-column-menu
[D49]: #d49-manual-ordering-lists-through-the-outbox-projects-online-no-position-below-01
[D50]: #d50-projects-and-views-managed-online-applied-locally-at-once
[D51]: #d51-filter-engine-on-the-device-saved-filters-filter-builder-offline-search
[D52]: #d52-descriptions-edited-in-a-locked-down-tiptap-webview-never-silently-overwritten
[D53]: #d53-attachments-uploaded-through-the-outbox-opened-through-the-platform-android-share-target
[D54]: #d54-account-settings-in-the-app-password-and-email-on-the-web
[D55]: #d55-security-settings-two-factor-status-sessions-and-tokens-a-new-token-shown-once
[D56]: #d56-design-after-the-owners-mockups-blue-scheme-cards-one-task-row
[D57]: #d57-comments-online-with-a-kept-draft-reactions-comment-counts-and-unread-dot
[D58]: #d58-server-html-parsed-within-work-budgets-a-document-past-one-is-cut
[D59]: #d59-sessions-kept-through-lost-refresh-answers-and-storage-errors-a-record-of-why-one-ended
[D60]: #d60-labels-teams-and-shares-online-the-stored-project-permission-shapes-every-screen
[D61]: #d61-table-as-a-detailed-list-gantt-as-a-read-only-timeline
[D62]: #d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind
[D63]: #d63-home-screen-widgets-app-written-snapshots-glance-on-android-widgetkit-on-ios
[D64]: #d64-app-lock-over-the-ui-and-device-privacy-settings
[D65]: #d65-connection-settings-per-server-address-applied-in-the-apps-transport
[D66]: #d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links
[D67]: #d67-agpl-30-or-later-with-an-app-store-permission-dco-reserved-brand-embedded-cronet
[D68]: #d68-screen-readers-headings-one-announcer-high-contrast-reduce-motion-route-sweep
[D69]: #d69-large-screens-a-window-layout-helper-readable-widths-capped-dialogs-and-sheets
[D70]: #d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere
[D71]: #d71-english-and-german-us-base-glossary-error-texts-live-language-changes
[D72]: #d72-first-release-android-and-ios-together-play-and-an-apk-beta-first
[D73]: #d73-ci-from-local-scripts-versions-from-the-tag-gitlab-until-the-move
[D74]: #d74-ios-phase-app-store-prerequisites-testflight-from-the-mac-photo-locations-capture-cover
[D75]: #d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab
[D76]: #d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android
[D77]: #d77-beta-preparation-new-app-id-own-signing-key-public-group-testers
[D78]: #d78-vikunja-280-trash-codes-as-gone-its-limits-no-nul-info-re-read
[D79]: #d79-the-trash-of-vikunja-280-undo-queued-deletes-a-trash-page
[D80]: #d80-reminders-follow-subscriptions-on-vikunja-280-and-later
[D81]: #d81-vikunja-280-details-legal-links-okabeito-colours-lockout-hints-subtask-tree-accents
[D82]: #d82-projects-listdetail-the-project-tree-beside-the-project-on-wide-windows
[D83]: #d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp
[D84]: #d84-everyday-editing-in-the-task-detail-properties-in-place-task-links-move-to-column
[D85]: #d85-update-from-the-old-app-server-prefill-one-session-try-leftovers-cleared-widgets-kept
[D86]: #d86-ci-and-releases-on-github-actions
[D87]: #d87-mit-vikunjas-contribution-rules-and-the-move-into-go-vikunjaapp
[D88]: #d88-translations-through-vikunjas-crowdin-project
[D89]: #d89-store-listing-and-web-pages-of-the-official-app
[D90]: #d90-fixes-from-the-code-review-before-beta1
[D91]: #d91-fixes-from-the-code-review-the-description-editor-and-leaving-pages-for-a-switch
[D92]: #d92-fixes-from-the-code-review-security
[D93]: #d93-fixes-from-the-code-review-quick-fixes
[D94]: #d94-fixes-from-the-code-review-outbox-notifications-diagnostics-sessions
[D95]: #d95-fixes-from-the-code-review-small-things-users-notice
[D96]: #d96-fixes-from-the-code-review-robustness
[D97]: #d97-fixes-from-the-code-review-security-and-release
[D98]: #d98-fixes-from-the-review-of-the-decision-logs-limits
[D99]: #d99-battery-and-data
[D100]: #d100-small-things-users-notice-part-2
[D101]: #d101-images-in-the-editor
[D102]: #d102-quick-add-parser-fixes-beyond-the-web
[D103]: #d103-test-hygiene-dead-code-and-shared-helpers
[D104]: #d104-performance-on-large-accounts
[D105]: #d105-architecture-overview-and-the-step-record-in-an-archive
[D106]: #d106-faster-work-in-lists-swipes-selecting-several-tasks-reschedule
[D107]: #d107-fixes-from-the-make-up-reviews-of-steps-40j-to-40v
[D108]: #d108-the-task-detail-sheet-and-the-project-screen-in-smaller-parts
[D109]: #d109-offline-details-stored-task-details-images-on-disk-labels-created-offline
[D110]: #d110-structure-state-machines-one-outbox-machinery-checked-layers-one-loading-helper-a-parity-suite
[D111]: #d111-tests-before-production-a-contract-matrix-fixes-for-older-servers-native-tests-a-scripted-update-test
[D112]: #d112-accessibility-pass-on-an-emulator-a-scan-of-the-real-screens-48-dp-chips-and-widget-targets
[D113]: #d113-opt-in-crash-reports-through-vikunjas-sentry
[D114]: #d114-cleanup-before-the-move
[D115]: #d115-the-decision-log-shortened
[D116]: #d116-fixes-from-the-uiux-review-part-one
[D117]: #d117-fixes-from-the-uiux-review-part-two
