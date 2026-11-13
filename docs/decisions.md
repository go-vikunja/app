# Decision log

Each entry has a number, a status and the step that took it, and states the decision as it holds today: what later steps changed is worked into the entry, and what no longer applies is gone. An entry that a later one replaced completely keeps its number and points to its replacement. D59 is reserved for the session hardening that is on hold and has no entry. "(owner)" marks a point the owner decided; "Limits" lists the known gaps that are still open. How each entry came about, with all its earlier versions, is in the git history of this file. The background for most entries is in [research/synthesis.md](research/synthesis.md) §2–3 and [research/flutter-stack.md](research/flutter-stack.md).

## D1: Flutter pub workspace with pure-Dart packages

*Accepted 2026-10-09 (step 1).*

- Flutter 3.47.9 / Dart 3.13.7, pinned in CI (`tool/ci/pins.sh`) and used locally, so that what the release job builds is what was tested ([D73](#d73-gitlab-ci-from-local-scripts-versions-from-the-tag-release-signing), [D77](#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)).
  - 3.47.9 carries the fix of the Dart security advisory GHSA-frr6-h895-5pxp, which concerns the servers the app reaches through `dart:io` ([D65](#d65-connection-settings-per-server-address-applied-in-the-apps-transport)).
- The repository is one pub workspace with a single `pubspec.lock`: `app`, `packages/vikunja_domain`, `packages/vikunja_api`, `packages/vikunja_logic` and `plugins/vikunja_widgets` ([D63](#d63-home-screen-widgets-app-written-snapshots-glance-on-android-widgetkit-on-ios)) (in review).
  - `flutter pub get` runs only at the root.
- `packages/*/lib` stays free of Flutter (no `package:flutter*`, `material_ui`, `cupertino_ui` or `dart:ui`), checked in CI by `tool/check_pure_dart_packages.sh` (why: this code must also run on the plain Dart VM).
- Lints are very_good_analysis 11 with `public_member_api_docs` off.
- Code uses the Dart 3.13 constructor syntax (`new(...)`, `factory name(...)`), enforced by the lint `unnecessary_type_name_in_constructor`.

## D2: material_ui and cupertino_ui instead of the SDK's libraries

*Accepted 2026-10-09 (step 1).*

- The app's code imports `package:material_ui/material_ui.dart` (1.6.x) and `package:cupertino_ui/cupertino_ui.dart` (1.1.x), never `package:flutter/material.dart` or `cupertino.dart` (why: the SDK's Material library is being decoupled and deprecated, so there is no migration later).
- Localisation delegates come from material_ui (`GlobalMaterialLocalizations.delegates`).
- Third-party widgets built on the legacy libraries may need wrappers.

Limits:
- The WebView plugin (`webview_flutter` and its Android and WebKit packages) imports the legacy Material library internally ([D52](#d52-descriptions-edited-in-a-locked-down-tiptap-webview-never-silently-overwritten)).

## D3: Riverpod 3 with code generation

*Accepted 2026-10-09 (step 1).*

- flutter_riverpod 3 with riverpod_annotation and riverpod_generator for dependency injection and state; a headless `ProviderContainer` serves the non-UI isolates (why: background tasks, notification actions and widget callbacks build the same object graph without a widget tree).
- The generated `*.g.dart` and l10n files are committed and excluded from analysis and from the format check.
  - CI regenerates them and fails when the result differs. After changing ARB files or annotated providers, run `cd app && flutter gen-l10n && dart run build_runner build`.
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
- Pinned, CA-trusted and client-certificate servers go through a `dart:io` client of their own inside the same adapter of both base `Dio`s ([D65](#d65-connection-settings-per-server-address-applied-in-the-apps-transport)).
- Android ships embedded Cronet, never Play services' Cronet (owner; why, [D67](#d67-agpl-30-or-later-with-an-app-store-permission-dco-reserved-brand-embedded-cronet)), so every Android device gets Cronet and user CAs and system proxies work without Play services too:
  - `org.chromium.net:cronet-bundled` 500.1.0, which brings `cronet` 500.1.0 (Chromium 155.0.8059.16, Chrome Android stable since 2026-09-23), with cronet_http 1.10.0.
  - `app/android/app/build.gradle.kts` excludes `com.google.android.gms:play-services-cronet` and the empty transitional artifacts (`cronet-api`, `cronet-common`, `cronet-embedded`, `cronet-fallback`, `cronet-shared`, `httpengine-native-provider`) from every configuration, so every build, test and CI run is embedded without a `--dart-define`.
  - `NativeCronetProviderSentinel` enables `NativeCronetProvider`, so the bundled library is always chosen; native_dio_adapter's `dart:io` fallback stays only as a safety net.
  - No HTTP flags and no telemetry: `AndroidManifest.xml` declares the disabled, unexported placeholder service `android.net.http.MetaDataHolder` with `android.net.http.ReadHttpFlags` and `android.net.http.EnableTelemetry` set to `false` (why: otherwise Cronet applies a flags file from a system-image package, which can change its features and settings or swap in the platform's `HttpEngine`).
  - The app declares `ACCESS_NETWORK_STATE` itself, which Cronet's network change notifier needs; the 500.x AARs declare no permissions.
  - Cronet's security fixes come only with an app update. The owner reviews it at each Chrome stable release whose fixes touch `net/`, BoringSSL or QUICHE and at each dependency update, and a newer `cronet-bundled` is looked for before each release; raising it is a version in `build.gradle.kts`, the locks, a release build and `tool/build_android_notices.py --refresh-cronet`, which refuses a build that is not a Chrome stable release ([releasing.md](releasing.md#raising-cronet)).
- Build workarounds: `android.uniquePackageNames=false` in `app/android/gradle.properties` (cronet_http's namespace clash under AGP 9, dart-lang/http#1932) and the template flag `android.builtInKotlin=false` (cronet_http still applies the Kotlin Gradle Plugin).

Limits:
- Chromium's network stack updates only with an app update, never with Play services on the device, and the bundled build lags the newest Chrome stable release by the weeks Google takes to publish it ([threat model](threat-model.md) R34).
- The protobuf copy shaded into `cronet` is named by no lockfile, so no scan sees it. The AARs' `.asc` signatures are not verified; the checks rest on Google's published SHA-256s.
- In the APK three `java.time.Duration` setters of `DnsOptions` do not resolve after core library desugaring; cronet_http's client never calls them.

## D6: v1/v2 negotiation with capability gating

*Accepted 2026-10-09 (step 1).*

- `/api/v2/info` and `/api/v1/info` are probed in parallel. A probe counts only for a 200 with a JSON body that has a string `version`; every API version whose probe counts goes into `ServerConnection.apiVersions`, and when both count the v2 `/info` is used (why: `/api/v2` exists only from 2.4.0 and proxies can hide it).
- At most one redirect is followed per connection attempt, and only when the resolved `Location` keeps the `/api/v1/info` or `/api/v2/info` path under another origin or sub-path, or is a same-host `http` → `https` redirect; the derived root is probed like any other candidate.
  - An `https` → `http` downgrade is never accepted. Any other redirect off the host, or to a login-like path, is `BehindLoginProxy`.
- `ServerCapabilities` is derived from the reachable API versions, version thresholds, the `/info` flags and `enabled_pro_features`. Features check capabilities, never version strings alone (why: development builds report `dev` or `unstable`, and admins and licences switch features).
- The adapter choice per API group follows `Capability.apiV2`.
- The server's `/info` is read at sign-in and again while signed in ([D78](#d78-vikunja-280-trash-codes-as-gone-its-limits-no-nul-info-re-read)).

## D7: Support floor 2.0.0

*Superseded by [D13](#d13-support-floor-230).*

## D8: Cleartext only after the user's consent

*Accepted 2026-10-09 (step 1).*

- The OS configuration allows cleartext, so that home-LAN servers on plain `http://` can be reached at all:
  - Android: a network security config with `cleartextTrafficPermitted="true"` that trusts system and user CAs.
  - iOS: `NSAllowsArbitraryLoads`, plus `NSLocalNetworkUsageDescription`.
- Only the `http` and `https` schemes are accepted.
- The connector tries `https` first. It tries `http` only when the user typed no scheme and every `https` candidate failed at the connection level (DNS, refused, timeout, or a TLS handshake failure).
  - A rejected certificate does not count: a TLS server answered, so the connector reports `TlsFailure` and points the user at the certificate rather than at cleartext.
- An `http` server is used only after the user confirms the "Unencrypted connection" question, and is marked as unencrypted afterwards.
  - The consent is recorded per server address, can be revoked and is enforced in the transport for requests and the socket; the `/info` probe before the consent is the only exception ([D65](#d65-connection-settings-per-server-address-applied-in-the-apps-transport)).
- The OS permissions stay broad because they cannot be narrowed to hosts typed at runtime; the in-app consent is the actual control.
  - iOS ATS exceptions and Android's per-domain cleartext rules are build-time only.
  - `NSAllowsLocalNetworking` (or `NSAllowsArbitraryLoadsInWebContent` / `NSAllowsArbitraryLoadsForMedia`) is never added: iOS would then ignore `NSAllowsArbitraryLoads` and block confirmed `http` connections to fully qualified hosts (split-DNS LAN names, Tailscale `*.ts.net`, VPN hosts).

Limits:
- App Review may ask about `NSAllowsArbitraryLoads`; the review notes carry its justification ([D76](#d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android)).
- `NSAllowsArbitraryLoads` also removes ATS's TLS 1.2 and forward-secrecy minimums for `https`; system certificate validation still applies.

## D9: flutter_test instead of package:test in pure packages

*Accepted 2026-10-09 (step 1).*

- The pure packages use `flutter_test` as their dev dependency and run their tests with `flutter test`, never `dart test` (why: in the shared workspace resolution `package:test` conflicts with the `test_api` version that `flutter_test` pins).
- Only `test/` touches Flutter; `lib/` stays pure Dart ([D1](#d1-flutter-pub-workspace-with-pure-dart-packages)).
- Contract tests run with `flutter test --tags contract` ([D28](#d28-contract-tests-against-the-latest-vikunja-release-only)).

## D10: Placeholder application ids

*Superseded by [D15](#d15-app-id-iovikunjaapp-and-the-name-vikunja).*

## D11: Docker contract matrix 1.0 / 2.0 / 2.3 / 2.4 / 2.7

*Superseded by [D28](#d28-contract-tests-against-the-latest-vikunja-release-only).*

Its rule that contract tests are tagged `contract`, need `VIKUNJA_CONTRACT=1` and run in a CI job of their own is kept in [D28](#d28-contract-tests-against-the-latest-vikunja-release-only).

## D12: Hand-written API adapters over one shared DTO set

*Accepted 2026-10-09 (step 1).*

- The v1 and v2 adapters of `vikunja_api` are hand-written over one shared codec layer (`lib/src/dto/`), because both versions share the server models; there is no code generation (why: v1 has no usable spec, and the app needs only a fraction of the operations).
- swagger_parser + retrofit stay the fallback if v2 grows faster than the adapters can follow.

Limits:
- Planned, not built: committing the OpenAPI 3.0 spec of the pinned test server image and a contract test that every DTO field exists in it and every write field is writable, so that spec drift is caught.

## D13: Support floor 2.3.0

*Accepted 2026-10-09 (step 1 review), the owner's decision.*

- Vikunja 2.3.0 and newer are supported; 2.4.0 and newer with a reachable `/api/v2` are first-class (why: browser sign-in, the only sign-in method ([D14](#d14-browser-sign-in-only)), needs the server's OAuth 2.0 + PKCE endpoints, which exist from 2.3.0).
- The tiers of `SupportTier`: `unsupported` (older than 2.3.0, or a version that cannot be read, without `/api/v2`), `oauth` (2.3.0 or newer with `/api/v1` only) and `full` (`/api/v2` reachable).
- An unsupported server is not a connection failure: the server overview shows the header, the badges and a blocking banner saying that browser sign-in needs 2.3.0, but no sign-in methods and no server features.
- No legacy tier for 0.24–1.x.
- The v1 adapter stays for 2.3.x and for servers whose proxy hides `/api/v2`.

## D14: Browser sign-in only

*Accepted 2026-10-09 (step 1 review), the owner's decision.*

- The only way to sign in is OAuth 2.0 + PKCE in the system browser ([D23](#d23-browser-sign-in-through-flutter_web_auth_2-in-an-ephemeral-session)) (why: Vikunja plans to remove username and password login, and on 2.3.0 and newer the web's login page covers local, LDAP, every OIDC provider and TOTP).
- The app never handles an account password or a TOTP code: no native password + TOTP form, no API-token login, no OIDC in an embedded WebView.
  - Creating an account goes through the browser's sign-in page, a password reset and an invite through the web's own pages in the external browser; link-share guests are a separate account kind ([D62](#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind)).
  - Two-factor setup and everything else that needs the password stay on the web ([D54](#d54-account-settings-in-the-app-password-and-email-on-the-web), [D55](#d55-security-settings-two-factor-status-sessions-and-tokens-a-new-token-shown-once)).
- The redirect scheme, `vikunja-io.vikunja.app` since step 38a (in review), starts with `vikunja-` and is neither the desktop app's `vikunja-desktop` nor the old app's `vikunja-flutter` ([D23](#d23-browser-sign-in-through-flutter_web_auth_2-in-an-ephemeral-session)).

Limits:
- OAuth sessions are always short: 72 h without a refresh end them, and there is no 30-day "stay signed in" ([D22](#d22-session-keep-alive-through-background-sync)).

## D15: App id `io.vikunja.app` and the name Vikunja

*Accepted 2026-10-09 (step 1 review), the owner's decision; the official app's id and name since 2026-11-13 ([D83](#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp)), in review with step 38a.*

- Android `applicationId` and iOS bundle id: `io.vikunja.app`, the official Vikunja app's (owner), so that the app reaches the old app's installs on Play as an update ([D83](#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp)). On iOS nothing is registered yet, so the bundle id is the same (owner).
  - The id is permanent once signing keys or store listings exist.
- Ids derived from it:
  - the Android namespace and Kotlin package `io.vikunja.app`, the widgets in `io.vikunja.app.widgets` (why: the launcher component stays `io.vikunja.app/.MainActivity`, most likely the old app's, so that launcher icons placed for it survive the update; step 38b checks it);
  - the iOS test bundle `io.vikunja.app.RunnerTests` and the widget extension `io.vikunja.app.widgets`, a suffix that does not depend on the target's name;
  - the App Group `group.io.vikunja.app`, the only id derived for the extension: no keychain group exists ([D24](#d24-tokens-in-secure-storage-readable-after-the-first-unlock), [D63](#d63-home-screen-widgets-app-written-snapshots-glance-on-android-widgetkit-on-ios));
  - the method channels `io.vikunja.app/device`, `/documents`, `/files`, `/share` and `/widget_worker`, the share action `io.vikunja.app.action.SHARE`, the kept engine's id `io.vikunja.app.ENGINE_ID`, the background task identifiers `io.vikunja.app.sync` and `.drain` and the widget actions' unique work `io.vikunja.app.widget_actions`; the FileProvider authority follows `applicationId` by itself (`io.vikunja.app.files`);
  - the app scheme `vikunja-io.vikunja.app`, whose prefix Vikunja requires, and the OAuth `client_id`, the same value, since the owner named one value for both, as the old app used `vikunja-flutter` for both (the alternative, the app id as the client id, would work as well: the server only compares the value between the authorize and the token call) ([D23](#d23-browser-sign-in-through-flutter_web_auth_2-in-an-ephemeral-session)).
  - Not derived: the notification channels `reminders` and `activity` ([D39](#d39-local-notifications-a-scheduler-per-account-with-a-rolling-window), [D40](#d40-background-sync-of-every-account-server-notifications-in-an-inbox)), which do not clash with the old app's `Vikunja1` and `Vikunja2`.
- The HTTP `User-Agent` is `Vikunja-App/<version>[+<build>] (<system> <version>)` (why: `Vikunja/…` could read as the server's own requests; [D55](#d55-security-settings-two-factor-status-sessions-and-tokens-a-new-token-shown-once)). The app's Dart package keeps its internal name `vikunja_mobile`; the workspace root package is `vikunja_app` ([D67](#d67-agpl-30-or-later-with-an-app-store-permission-dco-reserved-brand-embedded-cronet)) and the widgets plugin `vikunja_widgets` ([D63](#d63-home-screen-widgets-app-written-snapshots-glance-on-android-widgetkit-on-ios)).
- The app is called **Vikunja** (owner, [D83](#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp)), with the icon of [D42](#d42-app-icon-vikunjas-logo-every-variant-derived-by-script). Its texts say "Vikunja" where the app names itself on the device: the launcher, the iOS display names of the app and the widget extension, the lock screen and its prompt, the privacy switches, notifications, widgets, "Share to Vikunja", iOS Settings paths and the permission texts. They say "the app" or "this app" where the same sentence names a server, a host, syncing, the licence, the publisher or the handling of data ("This app needs Vikunja 2.3 or newer", "About the app"), and "Vikunja app {version}" where a version follows, on the Account tab and the sessions page (why: there "Vikunja" reads as the server, and "Vikunja 1.0.0" as a server version). [glossary.md](glossary.md) has the rule for both languages.
- The store name is "Vikunja" in both stores and both languages ([D76](#d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android)).
- `app/test/app/app_identity_test.dart` pins these ids in the Android, iOS and Dart files. It fails when the app's Android or iOS sources, `lib`, the plugins or the packages' `lib` name `dev.coderoftime`, and when a shipped source (`lib`, the Android app's main sources, `ios/Runner` and the widget extension, the assets, the editor's sources, the plugins and the packages' `lib`) names Rurana in any case, in its text or its path, apart from the exceptions it lists with the step that removes each (38d, 38f); a second test fails when an exception no longer matches, so those steps delete it.

Limits:
- No `applicationIdSuffix` for debug builds (why: two installs would share the sign-in scheme, and the browser could hand the sign-in to the wrong one). A debug build therefore cannot be installed beside the old app from Play, which is signed with another key, and the earlier development builds `dev.coderoftime.rurana` and `dev.coderoftime.vikunja` stay installed beside it, with their own data, until they are uninstalled.
- `io.vikunja.app` may already be taken at Apple: the old app's fastlane configuration named it with its former contributor's team, which uploaded TestFlight builds, and App Store Connect refuses an id that another team used. To be checked with the Vikunja maintainers before the first iOS upload ([D83](#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp)); a change then touches the Xcode project, the App Group and their tests.
- Until the Apple account is settled, no build for a physical device with automatic signing under the owner's team: Xcode would register `io.vikunja.app`, `io.vikunja.app.widgets` and `group.io.vikunja.app` in that team, and no other team could use them. Simulator builds register nothing.

## D16: Multi-account in the first release

*Accepted 2026-10-09 (step 1 review), the owner's decision.*

- The first release adds, switches and removes accounts ([D37](#d37-account-switcher-an-avatar-sheet-a-switch-resets-the-navigation)).
- An account is a server plus a user, or a link-share guest ([D62](#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind)). Each has its own tokens, database, outbox and sync state; the UI shows one active account at a time.
- Per-account providers are keyed by the account id.
- Background sync and reminders cover every signed-in account, not only the active one ([D39](#d39-local-notifications-a-scheduler-per-account-with-a-rolling-window), [D40](#d40-background-sync-of-every-account-server-notifications-in-an-inbox)).
- Removing an account signs it out, wipes its secure entries, deletes its database and cancels its notifications. Signing the same account in again right after waits until part of the app that still holds its old database has let go of it ([D31](#d31-one-drift-sqlite-file-per-account-shared-across-isolates)).
- Notification payloads and widget data carry the account id, so a tap opens the right account; it switches without asking only with the install's key ([D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links)).

## D17: Notification policy

*Accepted 2026-11-10 (steps 1 and 37g), the owner's decision.*

- Only undone tasks notify. Which ones:
  - On Vikunja 2.8.0 and later (`Capability.remindersToSubscribers`): the tasks the user follows, for reminders and due dates alike, as the server sends its reminders; unfollowing a task silences it on the phone too (owner, [D80](#d80-reminders-follow-subscriptions-on-vikunja-280-and-later)).
  - On older servers and for link-share guests: the tasks where the user is the creator or an assignee; tasks visible only through shared projects or subscriptions get none (owner).
- Reminders fire at their reminder time; a task with a due date also notifies at the exact due time (owner). A reminder at the due time itself rings once, as the due notification, while due dates notify ([D39](#d39-local-notifications-a-scheduler-per-account-with-a-rolling-window)).
- Android schedules both as exact alarms. The onboarding after the first sign-in asks for the notification permission and for exact-alarm access (`SCHEDULE_EXACT_ALARM`, which the user grants on Android's "Alarms & reminders" page and which is denied by default on Android 14+); iOS asks for the notification permission at the same point (owner).
- Without exact-alarm access Android falls back to inexact alarms, which can be minutes late; the notification settings say so and link to the system setting ([D39](#d39-local-notifications-a-scheduler-per-account-with-a-rolling-window)).
- No daily overdue digest for now (owner); one could be added as a setting without changing the scheduler.

## D18: Descriptions edited with TipTap in a WebView, shown natively

*Accepted 2026-10-09 (step 1 review), the owner's decision.*

- Descriptions are edited with TipTap in a WebView: a bundled editor page whose own TipTap configuration produces the web's HTML, no remote loads, HTML in and out through a JavaScript channel ([D52](#d52-descriptions-edited-in-a-locked-down-tiptap-webview-never-silently-overwritten), locked down per [D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links)) (why: descriptions are HTML written by the web's TipTap editor; Markdown editing would be lossy and is not possible on v1 servers).
- Read-only rendering is native ([D44](#d44-task-detail-own-rich-text-parser-online-details-app-scheme-links)).

Limits:
- The WebView plugin and the bundled JavaScript build make the app larger.
- The JavaScript channel has no native origin or frame check; the per-load token and the page's CSP stand in for it ([D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links), [threat model](threat-model.md) R30).

## D19: Quick add keeps the web grammar and fixes four parser bugs

*Accepted 2026-10-09 (step 1 review), the owner's decision.*

- Quick Add Magic keeps the web's grammar but fixes four parser bugs, items 1–4 of the quirk register in [research/client-logic.md](research/client-logic.md) §20 (the code cites them as "D19 item n" or `D19-n`):
  1. `every N months` (N ≠ 1), `every year`, `yearly`, `biannually` and similar produce a repeat instead of none.
  2. Capitalised `Daily` and `Every Day` mean daily, as in lower case, not hourly.
  3. `today`, `tomorrow` and `next week` need a word boundary, so `todays` and `next weekend` stay text.
  4. Day-and-month dates need whole words, so `12 decorations` stays text.
- The fixes are documented in `packages/vikunja_logic` as deliberate deviations from the web.
- The other quirks are decided in [D38](#d38-quick-add-the-webs-grammar-with-fixes-through-the-outbox).

## D20: Scope cuts and mobile forms of desktop features

*Accepted 2026-10-09 (step 1 review), the owner's decision.*

- **Adaptations:**
  - Gantt is a read-only timeline and the table a detailed list ([D61](#d61-table-as-a-detailed-list-gantt-as-a-read-only-timeline)).
  - Keyboard shortcuts on every platform, ⌘ on Apple and Ctrl elsewhere (owner), with the iPad key menu, in step 36d after the first release.
  - Home-screen widgets and app shortcuts replace the desktop quick-entry window ([D63](#d63-home-screen-widgets-app-written-snapshots-glance-on-android-widgetkit-on-ios)).
  - No seasonal logo and no PWA banners.
- **Dropped:** the MCP information page and the admin panel (owner); the power-user features of step 33, webhooks, bot users, project backgrounds and imports from other services, which stay in the web (owner, 2026-11-12).
- **Time tracking** (step 34) comes in release 1.4 (owner), tested against a licence or a test instance from the Vikunja maintainers; the app parses `enabled_pro_features`, so it can be gated by the server.
- **Deferred, not planned for now** (owner):
  - Push on Android through a Vikunja webhook, ntfy and UnifiedPush.
  - Crash reporting: no Sentry, GlitchTip or similar SDK.
  - A diagnostics export with a stored log buffer; the threat model's rules for such a buffer bind it ([D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links)).
- **Support details** (owner, 2026-11-12): a row beside "Help and bug reports" builds a snapshot of the app's state when tapped (app and server versions, the last sync and background run, the queue by state, the permissions, the reason of the last session end), shows it first and lets it leave only through the share sheet; servers show as `<server-N>` unless the user chooses otherwise. Nothing is sent automatically and no SDK is involved; only the last session end is stored, as a tiny record of its reason, the part of the app and the time (owner). As built:
  - The row is "Support details" („Support-Details“), not "Copy support details", because the text leaves only through the share sheet, which offers Copy itself on both platforms. It follows "Help and bug reports" on the About page, so it is there signed out and for guests, and opens a full-screen page.
  - The page: a note on what the details hold, what they never hold and that nothing leaves the device until it is shared; the switch "Show server addresses", off at every opening and remembered nowhere; the text in a monospaced block that cannot be selected; Share in the app bar. The snapshot is collected once when the page opens and kept only while it is open; the switch shows the same snapshot again.
  - The text is plain English "key: value" lines in every app language, so reports compare; only the page around it is translated ([D71](#d71-english-and-german-us-base-glossary-error-texts-live-language-changes)). Times are UTC to the minute.
  - The device: the app's version and build, the platform and its version, the app's and the device's language, the notification permission, exact alarms (Android), what the OS allows in the background (Android: battery optimisation, background restriction and standby bucket from Android 9, battery saver; iOS: Background App Refresh and Low Power Mode, both read through the app's device channel, anything it cannot read shown as unknown), and the last background run's outcome and time.
  - Each account, in the registry's order: user or guest, active or not, signed in or needing a sign-in, the server as `<server-N>` (accounts on one server share N) or, with the switch on, its address without user info, query, fragment or share hash; the server's version, support tier, API versions and features; the last sync and full sync; this app session's sync and sending state where they exist; its last background turn (started, synced); the unsent changes by kind and state (new, waiting, due again, held for sign-in, in flight, failed), the kinds of their last errors (kind, problem or reason, code, HTTP status), how many may have reached the server, the most attempts and the oldest; the notification switches; the last session end.
  - Never in it: tokens, link-share hashes, passwords, failure messages, user, display and share names, e-mail addresses, ids of accounts, users, shares and projects, titles, payloads, user settings, the server's notices and frontend address; hosts only with the switch on. A server version keeps letters, digits and `.+_-`, at most 40 characters, and the redaction of [D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links) runs over the whole text last.
  - The last session end: every container's session managers and guest sessions (the app, a background run, a notification action, a widget action) hand an ended session on after they have marked the account, and the reason, the part of the app and the time are stored under `support.lastSessionEnd.<account>` in the preferences, only while the account is registered; the server's code and message are not. One per account, the latest, kept across a new sign-in because it answers why the account was signed out, forgotten at sign-out.
  - Not in it: an account marked at start because its stored tokens are missing (a restore without the Keychain or Keystore), which ends no session; a result per account of the last background turn. Opening the page opens the database of every registered account, which stays open until sign-out, as the notification schedulers keep theirs. The iOS background values are checked only in the device test ([beta.md](beta.md#the-ios-device-test)), and the page with TalkBack and VoiceOver not yet ([checklist](accessibility-checklist.md#27-checks-of-step-37l)).
- The server overview lists neither the admin panel nor time tracking, even for a licensed server.
- Without third-party SDKs the privacy manifests and store data declarations stay simple; release builds log nothing, so no logs reach the developer.

## D21: Languages English and German

*Accepted 2026-10-09 (step 1 review), the owner's decision.*

- The first release ships English and German; the web's 32 locales are not imported, and more languages may come later. How both are written, error texts included, is [D71](#d71-english-and-german-us-base-glossary-error-texts-live-language-changes)'s.
- Every string is in both ARB files (definition of done); new and changed keys get a description ([D68](#d68-screen-readers-headings-one-announcer-high-contrast-reduce-motion-route-sweep)).

## D22: Session keep-alive through background sync

*Accepted 2026-10-09 (step 1 review), the owner's decision.*

- OAuth sessions end after 72 h without a refresh (`service.jwtttl`, sliding), and browser sign-in gives no 30-day session ([D14](#d14-browser-sign-in-only)); the background sync keeps every signed-in account's session alive ([D40](#d40-background-sync-of-every-account-server-notifications-in-an-inbox)).
  - Each background run's incremental sync starts with `GET /user`; access tokens live 600 s and runs are at least 15 min apart, so that request refreshes the token and slides the 72 h window. Where the run first sends the account's queued changes, their first request does it.
  - Android runs it as WorkManager periodic work every 30 min; iOS through BGTaskScheduler, when the OS chooses.
- Opening or resuming the app checks the active session with `GET /user`; a check that refreshes an expiring token moves the window too.
- Refreshes from several isolates follow [D26](#d26-refresh-concurrency-single-flight-re-read-and-adopt-write-ahead-epoch).
- A session that ends puts the account into `needsReauth`: its local data stays, its outbox pauses, and a "Sign in again" notification appears. Its reason, the part of the app and the time are kept for the support details ([D20](#d20-scope-cuts-and-mobile-forms-of-desktop-features)).

Limits:
- On iOS a session still expires when the app is neither opened nor woken for 72 h, as the OS may run the background job rarely or never ([D40](#d40-background-sync-of-every-account-server-notifications-in-an-inbox)).

## D23: Browser sign-in through flutter_web_auth_2 in an ephemeral session

*Accepted 2026-10-09 (step 2+3).*

- `client_id` `vikunja-io.vikunja.app`, the same value as the scheme ([D15](#d15-app-id-iovikunjaapp-and-the-name-vikunja)); redirect URI `vikunja-io.vikunja.app://oauth/callback` (in review).
  - Vikunja has no client registry: the `client_id` only has to match between the authorize and the token call (else 400 code 17001), and the redirect scheme must start with `vikunja-` (else 17002).
- The browser leg runs through flutter_web_auth_2 5.1.0, only behind the `WebAuthenticator` interface: ASWebAuthenticationSession on iOS; on Android a Chrome Auth Tab where the browser supports it, otherwise a Custom Tab, with the plugin's `CallbackActivity`.
- The browser session is ephemeral (`preferEphemeral: true`), so no web login is reused (why: Vikunja has no consent screen and its callback carries only `code` and `state`, no RFC 9207 `iss`, so with a reused web login a malicious server could send the sheet to another server's authorize page and receive a code without the user noticing).
- The authorize URL is `{frontend_url}oauth/authorize`, or the server root + `/` when `/info` has no `frontend_url` or an `http://` one for an `https://` server; with an S256 challenge over a 32-byte random verifier and a 16-byte random state, both fresh per attempt.
- When the authorize URL is on another origin than the server root (scheme, host and port; the host compared in punycode and without a trailing dot, `otherSignInHost` in `features/session/application/sign_in_hosts.dart`), the app asks before the browser opens: "Sign in at {host}?", saying that the server gets access to the account the user signs in with at that host and to continue only if the host belongs to the server, with Cancel and Sign in, in the dialog of [D65](#d65-connection-settings-per-server-address-applied-in-the-apps-transport)'s hint (why: the callback carries no `iss`, so a server whose `frontend_url` names another server's genuine sign-in page receives the code, and with the token request the verifier, for the account signed in there and can redeem both at that server, while nothing on the page looks wrong).
  - `SignInController.signIn` and `signInAgain` take the question as a required `confirm:`, so no caller can leave it out. A first sign-in, "Add account" and "Create account" ask every time, since the account is known only when the browser returns. "Sign in again" negotiates first and asks about the page of that connection, unless the account last signed in at the same origin.
  - Only a sign-in that returns the account remembers the origin: `ConfirmedSignInHosts` keeps a JSON map of account id to origin in the preference `auth.confirmed_sign_in_hosts` ([D25](#d25-account-registry-in-sharedpreferences-without-secrets)), removes the account's entry when its page is on the server's origin again, and the key when the map is empty. Cancel, a closed browser or a failed sign-in remember nothing; sign-out and account removal forget the account's entry. A map that cannot be read counts as nothing confirmed.
  - Link-share guests sign in through the API ([D62](#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind)) and never open the browser.
- The code is exchanged at `/api/v2/oauth/token` when `/api/v2` is reachable, else at `/api/v1/oauth/token`, with a JSON body. The token client never follows redirects, and neither does any request that carries an access token.
- The callback must match the redirect URI's scheme and path and the state, and must carry a `code`; an `error` parameter is a failure; a cancelled sheet returns silently.
- "Sign in again" accepts only the account's own user; another user is refused before anything is stored, and its new session is logged out best effort.
- Android declares the `CallbackActivity` exported with a `VIEW` / `DEFAULT` / `BROWSABLE` filter for the scheme, host `oauth` and path `/callback` only; iOS declares a URL type for the scheme, which the task links use ([D44](#d44-task-detail-own-rich-text-parser-online-details-app-scheme-links)).
- The iOS deployment target stays 15.0: below iOS 17.4 the plugin falls back to `init(url:callbackURLScheme:completionHandler:)`, which handles the custom scheme; only `https` callbacks need 17.4.

Limits:
- Every sign-in shows the Vikunja login form, and OIDC and SSO users sign in at their identity provider again each time.
- Browsers the plugin treats as lacking ephemeral support (Chrome and Edge before 141, Samsung Internet before 28, Firefox before 143) get a Custom Tab that can share the browser's cookies and reuse a web login. Signing out of the app does not end a web login in the browser.
- The browser leg does not use a server's connection settings (pin, CA, client certificate, access headers); the app says so before it ([D65](#d65-connection-settings-per-server-address-applied-in-the-apps-transport)).
- The mix-up is not closed; that needs a server change (RFC 9207 `iss`, or a consent screen that names the client). A sign-in page on another origin is named before the browser opens, but whether it belongs to the server is left to the user, and a look-alike host reads like the real one. A server whose own `/oauth/authorize` redirects to another host's page is not asked about: only the browser's address bar shows that host. Without a consent screen any app with a `vikunja-…` scheme can get a token for a user signed in to the web in the system browser.
- The plugin's 5.x line predates its UIScene and built-in Kotlin migrations (6.0 is still alpha): it finds the window through `UIApplication.keyWindow`, and Flutter warns that its Kotlin Gradle setup will stop building in a future release, so the move to 6.0 is due once it is stable. A version that stops working can be replaced by a platform channel of our own behind `WebAuthenticator`, recorded as a new decision.
- The fallback below iOS 17.4 is checked only by reading the plugin's source; it waits for a device test on iOS 15–17.3.
- iOS logs that ASWebAuthenticationSession support for `http://` pages is deprecated; servers on plain `http://` may lose browser sign-in in a future iOS release.

## D24: Tokens in secure storage, readable after the first unlock

*Accepted 2026-10-09 (step 2+3).*

- flutter_secure_storage 11.x with the entries `account.<id>.refresh_token` and `account.<id>.access_token` per account (why: the refresh token is the most sensitive secret the app holds, and secrets live only in the Keychain or the Keystore).
  - iOS: `KeychainAccessibility.first_unlock_this_device`, `synchronizable: false`.
  - Android: the plugin's v11 defaults (AES-GCM with a key wrapped by an Android Keystore RSA key).
- First-unlock accessibility, because background sync, notification actions and the widget worker must use the tokens while the device is locked. Before the first unlock after a restart nothing can refresh; background runs treat the locked Keychain like a network error: keep everything, retry later.
  - The app lock does not change this: it is a gate over the UI only ([D64](#d64-app-lock-over-the-ui-and-device-privacy-settings)).
- The access token is stored as well, so another isolate can adopt a refresh result instead of refreshing again ([D26](#d26-refresh-concurrency-single-flight-re-read-and-adopt-write-ahead-epoch)).
- The other secrets use the same store and accessibility: link-share tokens and hashes ([D62](#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind)), access header values and client certificates ([D65](#d65-connection-settings-per-server-address-applied-in-the-apps-transport)).
- No other place holds secrets: not the preferences, not the database, not logs. The log redaction covers `Bearer`, `access_token`, `refresh_token`, `code=` and `state=`, among others.
- Android keeps the entries out of backups and device-to-device transfer (owner, [D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links)); on iOS the `ThisDeviceOnly` items never reach another device and never sync through iCloud Keychain.
- Widgets and extensions get no keychain access group and no token ([D63](#d63-home-screen-widgets-app-written-snapshots-glance-on-android-widgetkit-on-ios)).
- iOS keeps Keychain items when the app is deleted, but not its preferences: the first UI start that finds neither the install marker (`auth.install_marker`) nor a registry wipes secure storage once (`app/lib/core/auth/previous_install.dart`). A locked Keychain leaves the marker unset, so the next start tries again; a registry without the marker is an update from an older build and is left alone.

Limits:
- Changing the accessibility class later means rewriting the existing items.
- An iOS backup brings the tokens back only to the same device, from an encrypted backup ([D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links)); elsewhere the restored accounts need a new sign-in.
- Deleting the app never logs its sessions out on the server; they end after 72 h without a refresh.

## D25: Account registry in SharedPreferences, without secrets

*Accepted 2026-10-09 (step 2+3).*

- The registry is JSON in `SharedPreferencesAsync` under `auth.account_registry` (why: the UI and background isolates need the accounts, the active one and each server before any database is open):
  - the accounts (`Account`: id, kind, server root, user id, username, display name, `addedAt`, `needsReauth`, and for a link-share guest the share id, project and share name, [D62](#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind));
  - the active account id and the activation order, most recent first ([D37](#d37-account-switcher-an-avatar-sheet-a-switch-resets-the-navigation));
  - each account's last server connection (root, reachable API versions, `/info` re-serialised by `serverInfoToJson`).
- `SharedPreferencesAsync`, not the cached legacy API: every read goes to the platform store, so a background isolate never works on a stale in-memory copy.
- Account id: the first 32 hex characters of `sha256("${serverRoot}|${userId}")`, for a guest of `sha256("${serverRoot}|share|${shareId}")`. The same user on the same server is always the same account; signing in again replaces its session, and the old session is logged out best effort.
- The registry holds no tokens or other secrets ([D24](#d24-tokens-in-secure-storage-readable-after-the-first-unlock)). Nor does `auth.confirmed_sign_in_hosts` beside it, which keeps per account id the origin of a sign-in page on another host where the account last signed in after the user confirmed it ([D23](#d23-browser-sign-in-through-flutter_web_auth_2-in-an-ephemeral-session)).
- The registry and secure storage can disagree after a crash or a restore: an account without tokens is handled like `needsReauth`, marked when the app starts (`app/lib/core/auth/accounts_without_tokens.dart`) or when a session manager finds no tokens. Secure storage that cannot be read yet (before the first unlock) does not count as missing tokens.
- An entry that cannot be decoded is left out of the state but written back unchanged; a readable entry with the same id replaces it. A registry that cannot be decoded at all is copied to `auth.account_registry.unreadable` before it is first overwritten.

Limits:
- The id depends on the normalised server root: the same server reached through two addresses (a LAN IP and a domain) gives two accounts, and an `http` account is never upgraded to `https` ([D65](#d65-connection-settings-per-server-address-applied-in-the-apps-transport)).

## D26: Refresh concurrency: single-flight, re-read and adopt, write-ahead, epoch

*Accepted 2026-10-09 (step 2+3).*

- Why: Vikunja rotates the refresh token on every refresh without a grace period; reusing a rotated token gives 401 code 16002 and the session cannot be recovered, and the loser of a concurrent rotation gets 16004.
- The session manager (`app/lib/core/auth/session_manager.dart`) is the only code that refreshes; `vikunja_api` sees it only through `AccessTokenSource`.
- Single-flight: one refresh per account and isolate at a time.
- Before calling the server, the stored refresh token is re-read; when it differs from the caller's snapshot, the stored tokens are adopted and the call skipped.
- Every session-ended answer re-reads storage first and adopts a session another isolate stored meanwhile; only then is the session ended. 16002 and 16004 (a lost rotation) re-read at once and again after 250 ms, 500 ms, 1 s and 2 s; 16003 and 412, which concern the session of the token sent, re-read once.
- Write-ahead: the rotated tokens are persisted before the new access token is used.
  - If that write fails, or the read of storage right before it, the new tokens are used from memory, marked as not yet stored. After a failed read nothing is written at that point, because storage may hold a newer sign-in; a manager retired meanwhile still discards the result, and a read that finds no tokens still ends the session.
  - Tokens not yet stored are written at the next `validAccessToken()` or `refreshAfterRejection()`, in `settle()` and before the next refresh, each time after a read of storage that drops them when it holds newer tokens (why: until then storage holds the refresh token the server has invalidated, and a sibling isolate refreshing with it would end the session). Concurrent callers share one such write, and a refresh waits for one already started, so older tokens never land last. Only the error type is logged.
- The refresh request is not tied to UI cancellation and has a generous timeout.
- A per-account auth epoch, raised by sign-out and account removal; a refresh that finishes under an older epoch is discarded. Sign-out retires the session manager first and wipes storage afterwards; a retired manager hands out no token and writes nothing until a new sign-in replaces it, and `retire()` waits only for a storage write that has already started, never for a refresh still on the network.
- Expiry is judged with the per-account server clock offset stored in preferences, so a cold start or a new isolate need not wait for a response.
- Failure classes:
  - network errors keep the tokens for a later retry;
  - 5xx is retried once after 2 s, after re-reading storage (a SQLite server answers the loser of a race with 500 instead of 16004); a newer stored token is adopted instead;
  - 429 waits for `Retry-After`, at most 10 min;
  - a session-ended answer (16002 after re-reading, 16003, 412 code 1020 or 1040) marks the account `needsReauth` and keeps its local data.
- There is no cross-isolate lock: `RandomAccessFile.lock` takes POSIX record locks, which belong to the whole process, so it does not keep two isolates apart. The re-read and adoption rules are the only cross-isolate mechanism.
- Short-lived isolates (a notification action) use a session manager with `refreshes: false`: it hands out a stored access token while it is valid and otherwise fails the request as a rejected token, leaving the rotation to the app ([D39](#d39-local-notifications-a-scheduler-per-account-with-a-rolling-window)). Background runs do refresh, with a deadline that leaves a refresh in flight time to land its write-ahead ([D40](#d40-background-sync-of-every-account-server-notifications-in-an-inbox)).

Limits:
- Without a lock two isolates can send the same refresh token at once; the loser adopts the winner's tokens once written, so the adoption re-reads must outlast the winner's write-ahead.
- A response lost after the server rotated (the process killed mid-request, the network dropping) ends that session in `needsReauth`.
- Tokens not yet stored live only in that isolate's memory: while secure storage keeps failing, an isolate that ends loses the rotation, and every call tries storage again and logs one warning.
- Retirement is per isolate: a sibling isolate can still write tokens back after a sign-out elsewhere; [D40](#d40-background-sync-of-every-account-server-notifications-in-an-inbox) narrows this but does not close it.

## D27: Paging and the query builder beside the read adapters

*Accepted 2026-10-09 (step 2+3).*

- `Page<T>` (v1's pagination headers, v2's `{items,total,…}` envelopes; `total` only on v2) and the query builder `TaskQuery` (filter, sort and paging parameters) are in `vikunja_domain` and serve the v1/v2 read adapters of `vikunja_api` ([D12](#d12-hand-written-api-adapters-over-one-shared-dto-set)).

## D28: Contract tests against the latest Vikunja release only

*Accepted 2026-10-09, the owner's decision.*

- `test_servers/docker-compose.yaml` runs one `vikunja/vikunja` image of the latest release, now 2.8.0, pinned by its tag:
  - the service `vikunja` on port 34527, published on `127.0.0.1` only, because it allows open registration with a public JWT secret (CI publishes on `0.0.0.0` inside its own docker-in-docker daemon, `RURANA_TEST_PUBLISH_ADDRESS`); its state lives in a tmpfs;
  - the opt-in `tls` profile (`vikunja-tls`, ports 34528–34531) runs the same release ([D65](#d65-connection-settings-per-server-address-applied-in-the-apps-transport));
  - the tag is bumped when a release comes out, in the compose file and in `defaultTestServerImage` of `packages/vikunja_api/test/contract/helpers.dart`, which `test_server_image_test.dart` beside it checks (it is not tagged `contract`, so CI's ordinary test run includes it); the service names carry no version;
  - `RURANA_TEST_VIKUNJA_IMAGE` runs another release in both services instead (`${RURANA_TEST_VIKUNJA_IMAGE:-vikunja/vikunja:2.8.0}`). `vikunja_api`'s contract tests expect the version of its tag (`contractServerVersion`) and refuse an image without a release tag; the app's gate only on the version the server reports. A switch recreates the server, empty.
- The servers raise Vikunja's sign-in limit, which cannot be turned off, from 10 to 1000 a minute per IP (`VIKUNJA_RATELIMIT_NOAUTHLIMIT`), and open SQLite with immediate transactions through the database path (`/tmp/vikunja.db?_txlock=immediate&_busy_timeout=30000&_x=`), so that parallel writes wait instead of failing with "database is locked".
  - The path relies on the server appending its own options after a `?`: after a bump, the startup line "Using SQLite database at:" must show it, and a contract run must log no "database is locked".
- Contract tests are tagged `contract`, need `VIKUNJA_CONTRACT=1` and run only against this server (`flutter test --tags contract` in `packages/vikunja_api` and in `app/`), in a CI job of their own ([D73](#d73-gitlab-ci-from-local-scripts-versions-from-the-tag-release-signing)). The app's also take `VIKUNJA_CONTRACT_PORT` (34527 when unset), so they can run against a throwaway server on another port.
- The Android emulator reaches the server as `localhost` through `adb reverse tcp:34527 tcp:34527`.
- Before each release is tagged, the contract tests run once locally against the newest release of the previous minor version, today 2.7.1, through `tool/ci/contract.sh` ([releasing.md](releasing.md#cutting-a-release)); what fails is fixed or recorded here. CI stays on the latest release. Both suites pass on 2.7.1, which takes the compose environment unchanged and ignores the test server's terms link (`/info` lists legal links from 2.8.0); the tests of what 2.8.0 brought skip there by the server's version: the trash, the 2.8.0 title and reminder limits, reminders that follow subscriptions and the legal links.
- Support for older servers down to the 2.3.0 floor stays in the code, covered by unit tests against `/info` and error fixtures recorded from older images.

Limits:
- Regressions that only show on older servers are caught only by the local run before a release, and only for the previous minor version; no release below 2.7 has run live, down to the 2.3.0 floor (an older image runs the same way through the variable).
- `tool/contract_tests.sh` starts the servers only when they are not running, so it does not switch a running server to the variable's image, and the version test then fails; `tool/ci/contract.sh` always does. That script stops at the first suite that fails, so on an older release the app's suite may need a run of its own.

## D29: Screens read and write through repository interfaces

*Accepted 2026-10-10 (step 5).*

- Screens depend only on the interfaces in `app/lib/core/repositories/` (`ProjectRepository`, `TaskRepository` and the others) and on the domain types; they never see `Page`, the ports or DTOs (why: an implementation can change without touching a screen, and widget tests use fakes).
- The contract: streams of the current local state plus explicit refresh calls. A failed first load is the stream's error; a failed refresh throws the `VikunjaFailure` and leaves the stale data in the stream.
- The implementations in `local/` serve from the account's database ([D31](#d31-one-drift-sqlite-file-per-account-shared-across-isolates)), which the sync fills through the same read ports ([D32](#d32-full-sync-by-keyset-paging-with-per-page-checkpoints), [D33](#d33-incremental-sync-from-an-updated-watermark-deletes-found-by-counts)); the online-only areas (account security, sharing, teams, the trash) have implementations in `online/`.
- The read client and the repositories are Riverpod providers keyed by the account id and disposed on sign-out.

## D30: Kanban board reads deferred to step 20

*Superseded by [D47](#d47-kanban-board-from-per-view-snapshots-moves-through-the-outbox).*

## D31: One Drift SQLite file per account, shared across isolates

*Accepted 2026-10-10 (step 6).*

- drift 2.35 with drift_flutter 0.3 and sqlite3 3.7 through its build hook, no `sqlite3_flutter_libs`: Android uses the prebuilt SQLite with verified hashes, iOS the system's SQLite (`hooks.user_defines.sqlite3` in the root `pubspec.yaml`), which needs no privacy manifest ([D74](#d74-ios-phase-app-store-prerequisites-testflight-from-the-mac-photo-locations-capture-cover)).
- One database per account at `<application support>/accounts/<accountId>/vikunja.db` (`AccountDatabaseFiles.pathFor`), opened through `driftDatabase(name:, native: DriftNativeOptions(databasePath:, shareAcrossIsolates: true))` in WAL mode.
  - `shareAcrossIsolates` finds the running database server through `IsolateNameServer`, so every isolate of the process shares one connection and one stream-update bus.
  - Per-account files need no `account_id` column, and an account switch never shows another account's rows.
  - Never in the iOS App Group container; the widget extension never opens it ([D63](#d63-home-screen-widgets-app-written-snapshots-glance-on-android-widgetkit-on-ios)).
  - Not encrypted: it holds no secrets, and an encrypted database would need its key in every background isolate. It stays out of backups and device transfer (owner, [D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links)).
- **The core schema:** `projects`, `project_views`, `labels`, `users`, `tasks`, `task_labels`, `task_assignees`, `task_reminders`, `task_relations` and the key-value `sync_state`; later entries add their tables by migration (schema version 12 now).
  - Indexes on `tasks(project_id)`, `tasks(done, due_date)` and `project_views(project_id)`; the primary key `(task_id, label_id)` of `task_labels` doubles as its `task_id` index.
  - Ids are the server ids; unsent creates use temporary negative ids ([D35](#d35-task-creates-through-the-outbox-under-temporary-negative-ids)).
  - Every entity row keeps the server's `created` and `updated`, which the delta sync keys on ([D33](#d33-incremental-sync-from-an-updated-watermark-deletes-found-by-counts)). Dates are nullable UTC epoch milliseconds.
  - Related tasks are stored as relation rows only; a task's `relatedTasks` is rebuilt from the rows whose other task is local.
  - Tasks carry `sync_run_id`, the run that last returned them, so a full run's purge survives a restart. Reminders have no server id and are keyed by `(task_id, ordinal)`.
  - Foreign keys with `ON DELETE CASCADE` from the task child tables to `tasks`, from `task_labels` to `labels`, `task_assignees` to `users` and `project_views` to `projects`; none on `tasks.project_id` (a task can arrive before its project) or `task_relations.other_task_id` (the other task may be one the user cannot read).
  - Pseudo projects (Favorites `-1`, saved filters `≤ -2`) are not stored as projects; the saved filters are kept in `sync_state` ([D43](#d43-task-lists-from-the-local-database-nested-and-ordered-like-the-webs), [D51](#d51-filter-engine-on-the-device-saved-filters-filter-builder-offline-search)).
- Every schema change bumps the version, adds a dump to `app/drift_schemas/` (`dart run drift_dev schema dump`) and a migration test on the helpers generated from the dumps (`drift_dev schema generate` into `app/test/core/db/generated/`); a test checks that the generated schema still matches the code.
- The database is a provider keyed by the account id (`appDatabase(accountId)`), closed on dispose and on sign-out through an `OpenDatabases` registry. Because `close()` with `shareAcrossIsolates` only disconnects the client, the registry waits until the database isolate has removed its `IsolateNameServer` mapping (polled every 20 ms, up to 5 s, logged on timeout) before the files are deleted. When the isolate is still there after the 5 s, because a client in another isolate keeps it alive (a background run, or a notification's or widget's Done, which waits up to 20 s), the files are deleted all the same and the account is remembered as left over from its sign-out.
- Sign-out and account removal delete the file with its `-wal`, `-shm` and `-journal` companions (`AccountDatabaseFiles.deleteFor`) after the tokens and the registry entry ([D26](#d26-refresh-concurrency-single-flight-re-read-and-adopt-write-ahead-epoch)). An account in `needsReauth` keeps its data.
- **Signing straight back in**: the account gets the same id again, so its new database would attach to the old isolate by the port name and work on the deleted files. Before a sign-in registers an account, `settleSignedOutDatabases` waits until the isolate of each leftover has gone (polled every 100 ms, at most 30 s in all), deletes its files once more and forgets it; one still there after that throws `SignOutStillFinishing`. Without leftovers it returns at once and touches no file.
  - A user's sign-in waits for every leftover, after the question of [D23](#d23-browser-sign-in-through-flutter_web_auth_2-in-an-ephemeral-session) and before the browser opens, because the account is known only when the browser returns. Meanwhile the button reads "Finishing the sign-out…" and Create account is off; Back and "Use a different server" leave and drop the sign-in. A guest waits only for its own account, before its token is stored ([D62](#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind)). "Sign in again" waits only for its own account, while it shows as in progress (why: its account is normally still registered and none is a leftover, but an entry kept from before a sign-out would be registered again onto a database still closing).
  - When the wait gives up, the sign-in fails with "Still finishing the sign-out" (for a guest's link "Still removing the guest access") and "Wait a moment and try again. If it keeps happening, close the app and open it again.", logged as expected, not as an error.
  - Two sign-ins waiting for the same account delete its files once, and one leaves alone a leftover that another sign-in settled meanwhile, which may be registered again by then.
  - The leftovers are kept in memory per isolate, as the port names are: sign-out and sign-in both run in the app's isolate, and a restart ends the old database isolate with the process.

Limits:
- A client in another isolate keeps the old database isolate alive past the sign-out's wait and works on the deleted files until it lets go; signing that account in again waits for it, at most 30 s.
- A user's sign-in waits for any account still closing, not only its own; usually there is none, and it does not wait at all.
- An Android build needs the sqlite3 build hook to fetch its prebuilt library (honours `HTTPS_PROXY`).

## D32: Full sync by keyset paging with per-page checkpoints

*Accepted 2026-10-10 (step 6).*

- `DefaultSyncEngine`, one per account, headless: no `BuildContext` and no Riverpod inside; the read client, the database, a clock and a `GET /user` source are injected. Runs are serialised per account; a call during a run joins it. `status` replays the current `SyncStatus` on subscription, once the stored state has been read.
- The full run, the first sync and [D33](#d33-incremental-sync-from-an-updated-watermark-deletes-found-by-counts)'s full resync, goes in phases:
  - `account`: `GET /user` with the user's settings and profile;
  - `projects`: all pages with `is_archived=true`; projects the server did not return are purged;
  - `labels`: all pages;
  - `tasks`: two `per_page=1` requests for the totals, then keyset `done = false`, then `done = true`;
  - `archivedTasks`: the same keyset on `GET /projects/{id}/tasks` for every archived project and its descendants (why: `GET /tasks` leaves out the tasks of archived projects);
  - `finishing`: the Overview's saved filter downloaded when the device cannot evaluate it ([D43](#d43-task-lists-from-the-local-database-nested-and-ordered-like-the-webs)), the tasks not seen in this run purged, `last_synced_at` written.
- Keyset paging, because page numbers are neither resumable nor stable while data changes: `filter=done = false && id > <lastId>` (or `done = true`), `sort_by=id&order_by=asc`, `per_page` = `max_items_per_page`, `page: 1` on every request, following the page size the server returns (it caps `per_page` silently).
  - Every page must be strictly ascending by id and start above the cursor, otherwise the run fails as `UnexpectedResponse` before the page is stored (why: a cursor that skipped ids would make the purge delete them silently).
- After every page the engine checkpoints run id and start, phase, done count and total, last id, done filter and archived project id in `sync_state`. `ensureInitialSync()` resumes an interrupted run from its checkpoint and returns at once for an account that has completed a run.
- Purging happens only in `finishing`, by the run id on the rows, so an interrupted run never deletes.
- Before the purge a catch-up pass over `GET /tasks` with `updated >= <newest task updated − 120 s>` marks its rows with the run id, so a task reopened after the open pass passed its id and completed again after the done pass is not purged. The bound is a server time: the newest `updated` from one `per_page=1` request sorted by `updated` descending with `filter=updated <= '<device clock + 1 h>'`, made before the task phase and kept in the checkpoint (why: a row a fast server clock once wrote would put the pass above every real change); it is also the run's watermark ([D33](#d33-incremental-sync-from-an-updated-watermark-deletes-found-by-counts)).
- A failed request ends the run with `SyncFailed(failure, lastSyncedAt)`; rows from earlier runs stay readable, and the caller of a refresh gets the failure ([D29](#d29-screens-read-and-write-through-repository-interfaces)). A stored state that cannot be read is reported as `SyncFailed(UnexpectedResponse, lastSyncedAt: null)` and read again on the next call, so the first-sync screen's Retry covers a damaged file.
- `SyncRunning.initial` stays true until the first run has completed: the app shows a blocking first-sync screen (cancel signs out), afterwards only a quiet indicator. An account that has synced opens the shell at once; a `NetworkFailure` with cached rows is an "offline" notice, not an error.

Limits:
- A full run costs about `tasks / max_items_per_page` requests plus the project, label and archived-project pages.
- Comments, attachments and the boards' buckets and positions are not part of the sync; they are read online on demand ([D44](#d44-task-detail-own-rich-text-parser-online-details-app-scheme-links), [D47](#d47-kanban-board-from-per-view-snapshots-moves-through-the-outbox)).

## D33: Incremental sync from an `updated` watermark, deletes found by counts

*Accepted 2026-10-10 (step 7).*

- `SyncEngine.refresh()` is the incremental run, `fullResync()` the full run of [D32](#d32-full-sync-by-keyset-paging-with-per-page-checkpoints), `ensureInitialSync()` the first one. `refreshAfterWrite()` is a refresh that starts after the call, for a write the app has just made, so that a run already in flight cannot undo it ([D50](#d50-projects-and-views-managed-online-applied-locally-at-once)).
- Runs are serialised per account; a `fullResync()` asked for during an incremental run follows it instead of joining it. Every run holds the account's lease in `sync_state` ([D40](#d40-background-sync-of-every-account-server-notifications-in-an-inbox)).
- **Watermark:** every completed run writes `last_synced_at` and the task watermark (`sync_state` key `watermark`), a server time: the newest task `updated` the run read itself on `GET /tasks` (`NewestUpdated`), never the newest in the database (why: outbox answers, Discards, restores, duplicates and creates write server rows with a fresh `updated` while a run goes on, and a watermark above them would skip what others changed in that gap).
  - The incremental run takes it from its `GET /tasks` delta pages only, not from the archived projects' deltas, the whole pulls or the reconciles, and never lowers it.
  - A full run writes `last_full_sync_at` and sets the watermark afresh to the newest `updated` the server had when its task phase began (one `GET /tasks?per_page=1` sorted by `updated` descending with `filter=updated <= '<device clock + 1 h>'`, kept in the checkpoint), not to what its catch-up pass reads (why: that pass walks by id, so a later page can lie above an edit to an id it has already passed).
  - A value more than 1 h ahead of the device clock is left out (logged), so a fast server clock cannot push every delta into the future; such a row is still stored, and every delta reads it again. A full run whose probe finds no task within that bound stores 1970.
- **The incremental run**, reported as `SyncRunning(initial: false)`, in this order:
  - `GET /user` with the settings and profile, as in the full run ([D38](#d38-quick-add-the-webs-grammar-with-fixes-through-the-outbox)).
  - **Projects:** all pages with `is_archived=true`, diffed against the local table.
    - A project the server no longer lists is purged with its tasks.
    - A project new to the device or un-archived is pulled whole (its tasks may carry `updated` values below the watermark); so are projects the app stored itself from a write's answer. Their ids are kept in `sync_state` (`pending_whole_pull`) until a run completes.
    - An archived project whose `updated` differs, or that is newly archived itself or through a parent, gets its delta through the project.
    - Only rows that differ by value are written (a favourite toggle bumps no `updated`), so a run that finds nothing new leaves the database's watchers alone.
    - The list is walked by page number; when the server's count (`total` on v2, the page count on v1) changes between two pages, the walk starts over, at most three times, then the run fails as `UnexpectedResponse`.
  - **Labels:** all pages with the same guard; changed ones upserted, missing ones purged. Task rows take their labels from `labels` by id, so a rename shows without a task change.
  - **Task delta** on `GET /tasks`, keyset over `(updated, id)` from the watermark minus 120 s:
    - the first page `filter=updated >= '<W − 120 s>'`, every later page `filter=(updated > '<U>') || (updated > '<U − 1 s>' && id > <I>)` with `(U, I)` the last item of the previous page; always `sort_by=updated&sort_by=id&order_by=asc&order_by=asc` and the server's maximum `per_page`;
    - why the tie clause is not `updated = '<U>'`: Vikunja compares a date filter value as if it sat just above its second (`>=` behaves like `>`, `=` never matches), and with whole-second timestamps `updated > '<U − 1 s>'` means `updated >= '<U>'` under both semantics;
    - a page out of that order fails the run before it is stored;
    - the rows that differ (reminders compared too, [D36](#d36-labels-assignees-and-reminders-in-the-task-update-label-creation-online)) are upserted per page in one transaction. The 120 s overlap covers the second granularity and the server's asynchronous `updated` bumps for comments, attachments, relations and assignees.
  - **Archived projects:** a changed one gets the same delta on `GET /projects/{id}/tasks` (why: `GET /tasks` leaves out their tasks, except the user's favourites); one pulled whole gets the keyset-by-id pull, and its local tasks not returned are purged after its last page.
  - **Delete detection:** a deleted task leaves no trace, so one probe, `GET /tasks?per_page=1`, gives the server's count of `GET /tasks` (`total` on v2, the page count on v1), compared with the local count of the same scope as the saved filters ([D51](#d51-filter-engine-on-the-device-saved-filters-filter-builder-offline-search)): the tasks outside archived projects and their subprojects, plus the user's favourites anywhere, done ones included, as 2.8.0 counts on v1 and v2 (it leaves out trashed tasks and projects and projects the user lost access to, which the app does not hold). That count includes rows queued for deletion and leaves out unsent creates ([D34](#d34-outbox-local-first-task-writes-one-serial-sender-coalescing-retry-classes), [D35](#d35-task-creates-through-the-outbox-under-temporary-negative-ids)).
    - Only on a mismatch are the live projects counted one by one (`GET /projects/{id}/tasks?per_page=1`), and each that differs is reconciled: keyset by id without a done filter, upserting, then purging the project's local tasks that were not returned.
    - When that walk finds no project that differs and none gone, the pair of totals (`remote,local`) is kept in `sync_state` (`unexplained_totals`), and incremental runs skip the walk while the probe gives exactly that pair; any other pair, equal totals included, and a completed full run clear it (why: the walk cannot locate a difference among an archived project's favourites, and repeating it would cost one request per live project every 60 s).
    - A 404 or 403 with a Vikunja code on a project's requests (3001; 3018 for a project in 2.8.0's trash; 7003 for lost access) purges the project with its tasks; a missing route does not.
    - Why counts and not `projects.updated`: it has second precision and misses a delete inside the second the previous sync saw.
  - **Finishing:** after the last phase the Overview's saved filter is downloaded when the device cannot evaluate it ([D43](#d43-task-lists-from-the-local-database-nested-and-ordered-like-the-webs)); then one transaction writes the watermark and `last_synced_at` and clears `pending_whole_pull`, and `SyncIdle` follows. A failure keeps the old watermark and rows and emits `SyncFailed`; nothing is purged by a partial result. There is no checkpoint: the next run restarts from the watermark.
- **Daily full resync:** in the app, `refresh()` runs `fullResync()` instead when `last_full_sync_at` is missing or older than 24 h, or no watermark is stored (why: it catches what bumps no `updated`, such as position and bucket moves, and a count that matched by coincidence). Headless engines (background runs, notification actions) stay incremental once a run has completed ([D40](#d40-background-sync-of-every-account-server-notifications-in-an-inbox)).
- **Triggers** (`app/lib/features/sync/application/`):
  - `StartupSync` on the shell's first frame and on an account switch.
  - `ForegroundSyncScheduler`, one per active account: a run 60 s after the last run ended, whoever started it, while the app is in front, and one on resume after a pause or hide when the last run is older than 60 s (a focus change alone is no resume). After a `NetworkFailure` the wait doubles up to 5 min and resets on success. It stops when the app is paused or hidden, on sign-out and while nothing listens to it (the first-sync screen).
  - Pull-to-refresh and "Sync now" are incremental; the Account tab has a secondary "Full resync", disabled during a run and in `needsReauth`.
  - The background runs ([D40](#d40-background-sync-of-every-account-server-notifications-in-an-inbox)) and the realtime socket ([D46](#d46-realtime-one-websocket-for-the-active-account-in-the-foreground)) call the same `refresh()`; the socket never replaces the 60 s timer.
- **Budget:** a run that finds nothing new costs 5 requests for a small account (`GET /user`, the project page, the labels page, one empty delta page, the count probe), far below the server's optional limit of 100 per minute; a difference the walk cannot explain costs one walk per pair of totals, not one per run; the engine logs each run's request count at FINE.

Limits:
- Until the next full resync the delta misses pure position and bucket moves and other server-side changes that bump no `updated`, and a task deleted on the server right before its project was archived stays (an archived project's delta cannot see a delete). If it was a favourite, the totals differ and the walk runs once, then the kept pair stops it; a favourite toggle the server refuses with 3008 because the project was archived meanwhile does the same until it is discarded.
- On v1 a project deleted while the list is paged, without changing the page count, can shift another project out of that run's walk; that project is purged and comes back as added on the next run.

## D34: Outbox: local-first task writes, one serial sender, coalescing, retry classes

*Accepted 2026-10-10 (step 11).*

- **Local-first:** `TaskRepository`'s writes change the local row and queue the server call in one transaction and return once it has committed; they never throw for network reasons, and the row shows the change with the next stream event, offline too (why: the lists work offline, and notification actions and widgets need the same queue).
- **Tables:**
  - `outbox`: `id` (uuid), an account-local `sequence` for FIFO, `kind`, `task_id`, `payload` (JSON), `created_at`, `attempts`, `next_attempt_at`, `last_attempt_at`, `state` (`pending`, `sending` or `failed`), `last_error` (the normalised failure as JSON) and `sent_at` (a create's or upload's request that may have reached the server, [D35](#d35-task-creates-through-the-outbox-under-temporary-negative-ids); since step 37l also a repeating task's Done, below); indexed on `(state, sequence)`.
  - `tasks.pending_changes` (the coalesced `TaskChanges` the server has not accepted yet) and `tasks.pending_delete`.
  - No 3-way merge: the server offers no precondition (it ignores `If-Match` and never answers a conflict with 412), and v2 merges per field on its own.
- **Op kinds:** `createTask` ([D35](#d35-task-creates-through-the-outbox-under-temporary-negative-ids)), `updateTask`, `deleteTask`, and `uploadAttachment` in a lane of its own ([D53](#d53-attachments-uploaded-through-the-outbox-opened-through-the-platform-android-share-target)).
- **`TaskChanges`** (`vikunja_domain`) is the payload and the write port's argument: one nullable field per writable property, null meaning unchanged, a date as a `DateChange` (`set` or `clear`); `merge(later)` lets the later value win per field. It carries title, description ([D52](#d52-descriptions-edited-in-a-locked-down-tiptap-webview-never-silently-overwritten)), done, favourite, priority, percent done, colour, the three dates, repeat and project ([D35](#d35-task-creates-through-the-outbox-under-temporary-negative-ids)), labels, assignees and reminders ([D36](#d36-labels-assignees-and-reminders-in-the-task-update-label-creation-online)), relations ([D41](#d41-relations-as-task-update-deltas-duplicate-and-follow-online-indented-subtasks)), board placements and list positions ([D47](#d47-kanban-board-from-per-view-snapshots-moves-through-the-outbox), [D49](#d49-manual-ordering-lists-through-the-outbox-projects-online-no-position-below-01)) and the cover image ([D53](#d53-attachments-uploaded-through-the-outbox-opened-through-the-platform-android-share-target)).
- **Write ports** (`vikunja_api`, `lib/src/write/`), v2 or v1 from the connection like the read client:
  - v2 sends `PATCH /tasks/{id}` as `application/merge-patch+json` with only the set fields under their wire names, a cleared date as `0001-01-01T00:00:00Z` and `hex_color` without `#`, never a key the server does not know (a 422), and re-reads the task after a 304.
  - v1 emulates the patch, because its `POST /tasks/{id}` is a full replace: `GET /tasks/{id}`, overlay the changes, `POST` the whole object back with `assignees` and `reminders` exactly as read and never `labels`.
  - A delete counts a gone task (404 code 4002, or 4040 for one in the trash) as success.
- **Coalescing**, in the write transaction:
  - An update merges into the task's newest pending update and into its `pending_changes`. When that update carries a Done that may already be on the server (`sent_at`, below), the edit becomes an op of its own behind it instead, Undo too.
  - A delete is queued like any other op, on every server, and can be taken back while queued (`unqueueDelete`, the Undo of [D79](#d79-the-trash-of-vikunja-280-undo-queued-deletes-a-trash-page)): the task's queued edits and `pending_changes` stay and reach the server before it (a delete never overtakes its task's update, also when that update waits for another task's create); its queued uploads stay, but the upload lane skips the task until the delete goes or is taken back.
  - An op that fails for good while a newer op of the task is queued folds into that op (an update gives it the fields it does not set, a delete makes it moot), so a task never has two ops that could go out in either order and a Retry never overwrites a newer edit. Two updates are not folded when either has `sent_at`: the failed one stays a sync problem for Retry or Discard, since its next attempt may leave out the body it sent once, and an edit folded into it would go with that body; a newer delete still makes it moot.
  - Rows with `pending_delete` are left out of every DAO query.
- **`OutboxSender`** (`core/outbox/`), one per account, headless:
  - It drains the queue oldest first, one op at a time, each claimed `sending` in a transaction that re-reads it; never two sends at once per account.
  - A drain starts when the sender is built, after every local write, on resume, on "Send now" (which drops every backoff), when a retry is due, when a paused sender resumes, when a sync reaches the server while the oldest op waits out a network failure, and in every background run ([D40](#d40-background-sync-of-every-account-server-notifications-in-an-inbox)).
  - The oldest op blocks the queue during its backoff, so later ops never overtake it; a `failed` op does not block.
  - On success the server's task replaces the row, except the fields a newer op still holds pending; the op is removed. After a drain that sent something the sender calls `SyncEngine.refresh()`, so server-computed fields arrive (a repeating task marked done comes back open with shifted dates), unless its caller syncs right after: `sendNow(refreshAfter: false)` leaves the refresh to the caller for that sender's life, which a background sync run does ([D40](#d40-background-sync-of-every-account-server-notifications-in-an-inbox)).
  - Senders may run in several isolates on the shared database: the claim lets only one send an op, and an op `sending` elsewhere stops every queue until it is 5 min old, then goes back to `pending`.
- **A repeating task's Done is applied once** (why: the server moves a repeating task's dates and reminders on every Done it gets, so a Done whose answer was lost and that is sent again moves them twice):
  - Before the first attempt of an update with `done: true` on a task the local row says repeats, the sender reads the task. When it repeats on the server and is open, its due, start and end dates and `done_at` (`DoneBase`) go into the op as `TaskChanges.doneBase` (`done_base` in the payload, never sent; a merge keeps the earliest) and the attempt's time into `sent_at`, in one write and only while the op is still this sender's `sending` claim (`OutboxDao.markDoneAttempt`). Cost: one `GET` per first attempt of a repeating Done, none for other ops.
  - Every later attempt reads the task again. The Done counts as landed when the server's `done_at` differs from the base's, and its dates do too or the base had none (compared to the second): the server stamps `done_at` and moves the dates for each Done, while a date edited on the web leaves `done_at` alone. Landed, only what has requests of its own goes (labels, assignees, relations, board placements and list positions, `withoutBody`), since the body reached the server in the same request and its dates or reminders sent again would undo the server's move; with nothing left the read task is applied without a request. Not landed, or the task gone, the op is sent as before.
  - This covers a lost answer, a later request of the same op that failed (also after a Retry, which keeps `sent_at`), an answer that could not be applied locally, a kill or dispose between the server's apply and the local one, and a cancelled request.
- **Retry classes** (the transport retries only GET and HEAD; writes are retried only by the sender, and a paused sender resumes with the next sign-in, so a session's end never loses an edit):

  | Answer | Op | Sender |
  |---|---|---|
  | success, 304, or a gone task on a delete | the answer applied (a delete removes the row), the op removed | next op |
  | `NetworkFailure`, `ServerFailure`, `RateLimited`, `TokenRejected` after the interceptor's own refresh and retry, and answers that are not Vikunja's (`UnexpectedResponse` with no status or one below 400, `NotFound` without a Vikunja code) | back to `pending`, `attempts + 1`, `next_attempt_at` = now + 2 s · 2ⁿ shortened by up to half at random, at most 15 min; a `Retry-After` above zero wins, capped the same | waits; later ops wait behind it |
  | `SessionEnded` | stays `pending`, untouched | paused until the account is signed in again ([D22](#d22-session-keep-alive-through-background-sync)) |
  | `NotFound` with a Vikunja code, `Forbidden`, `DomainError` 3008, `ValidationFailed`, `UnexpectedResponse` 4xx or 5xx | `failed`, the failure as `last_error`: a `SyncProblem`, or folded into a newer op of the task | next op |

- **Sync problems:** the Account tab lists the failed ops with what failed and when, with Retry (back to `pending`) and Discard (the task is read from the server first, then the op deleted and the row replaced, or removed on a 404 or 403; a read that fails otherwise changes nothing, so an edit is never lost offline; the op is checked again inside the transaction, so an op that got through meanwhile is not undone). It shows "Pending changes: N" with "Send now" while N > 0, counting `sending` ops too; "Send now" is not offered while every queued change is a sync problem and says in a snackbar what still blocks the queue afterwards. A row with unsent changes shows a cloud-off icon.
- **Sync interplay:** the sync's upserts overlay the row's `pending_changes` on the incoming task, so unsent fields keep the local value; a `pending_delete` row is written but stays hidden; no purge removes a row with a queued op; no run touches the outbox ([D33](#d33-incremental-sync-from-an-updated-watermark-deletes-found-by-counts)).
- **UI:** a done (with a haptic and the strikethrough at once) shows "Marked as done · Undo" for 3 s (persisting under a screen reader), and in the lists a done row stays in place until its 3 s are up and its snackbar has gone, so a second tap never pulls a row away under the finger. Undo is a second write, `undoDone(previous)`: `done: false` plus, for a repeating task, its previous dates and reminders ([D36](#d36-labels-assignees-and-reminders-in-the-task-update-label-creation-online)), which works whether the done is still queued, in flight or answered.
- The sign-out and account-removal dialogs say how many queued changes the wipe would lose and point to Send now; that wipe is the only way an edit is lost.

Limits:
- Writes are at least once: an op whose answer could not be applied locally, or a kill between the server's apply and the local one, is sent again; a repeating task's Done is checked first (above), within these limits:
  - a task the device does not know as repeating yet (the repeat set on the web and not synced) gets no base, and a re-sent Done moves its dates again;
  - a server that does not stamp `done_at` makes every attempt send the Done again; the contract tests check 2.8.0;
  - a failed op with `sent_at` that is retried after a newer edit of the task was sent can overwrite that edit's fields of the same name when its own body never arrived, as such ops are no longer folded;
  - a move into a board's done column without `done` in the same op gets no base; the board turns such a move of a repeating task into a plain Done ([D47](#d47-kanban-board-from-per-view-snapshots-moves-through-the-outbox)).
- Last write wins per field: a field the web changed while the phone's value for it waited loses to the phone; the description is the exception ([D52](#d52-descriptions-edited-in-a-locked-down-tiptap-webview-never-silently-overwritten)).
- Undo on a repeating task leaves `done_at` stamped and the server's checklist reset in the description in place.
- A repeating task marked done offline with the "from completion" mode counts from the send, not the tap.
- A failed update with a delete queued behind it is still dropped, so an Undo brings the task back without that edit, and the row shows the edit until the next sync.

## D35: Task creates through the outbox under temporary negative ids

*Accepted 2026-10-11 (step 12a).*

- **Temporary ids:** `TaskRepository.createTask(NewTask)` inserts the row under a negative id (the next value of the `sync_state` counter `local_task_ids`, negated, never reused) without an `updated`, and queues a `createTask` op with the `NewTask` as JSON, in one transaction (why: the server assigns ids and has no idempotency key, so no id is known before it answers).
  - The row is an ordinary task for every query and screen, sorted before the server's tasks. The sync never overwrites or purges it, and the count probe leaves it out ([D33](#d33-incremental-sync-from-an-updated-watermark-deletes-found-by-counts)). Negative ids never reach the server.
- **Coalescing on a temporary id:**
  - While the create has not left the device (never sent, or rejected), an edit folds into the `NewTask`, so the create goes out as one request with it; `done`, which a create cannot carry, becomes an update queued behind it.
  - Once the create may be on the server (in flight, or sent without an answer), later edits queue behind it under the temporary id; the sender takes no op under a temporary id before its create is through. When the server then rejects the create, such an edit folds into it too (only a `done` stays queued).
  - A delete of a create that never left the device waits behind it; when the sender reaches the create it drops create, delete and row in one transaction without a request (`cancelDeletedCreate`), unless an Undo took the delete back first ([D79](#d79-the-trash-of-vikunja-280-undo-queued-deletes-a-trash-page)). A task whose create the server refused is discarded at once when it is deleted: a queued delete cancels a refused create, also with kept edits between them.
- **Sending:** v2 `POST`, v1 `PUT /projects/{id}/tasks`. The body carries title, description, priority, percent done, colour, repeat, favourite and reminders under the update's wire names, a date only when set (the server stores the zero date for an omitted one), and the project only in the path (a `project_id` in a v1 body would override it); never `done`, assignees, `bucket_id` or labels, which follow as an update after the remap ([D36](#d36-labels-assignees-and-reminders-in-the-task-update-label-creation-online)).
- **Remap**, in one transaction on success: the create op goes, the ops behind it move to the server id, the temporary row is replaced by the server's task with the pending fields applied again (child rows included), and `(local_id, server_id, at)` goes into `task_id_remaps`, which is never pruned.
  - `watchTask(id)` resolves through the remap on every emission, so a screen open on the new task follows it; an edit or delete addressed to a remapped temporary id follows it to the server row; relation refs are resolved at send time ([D41](#d41-relations-as-task-update-deltas-duplicate-and-follow-online-indented-subtasks)).
- **Lost response:** a `NetworkFailure` or `ServerFailure` on a create, or a kill while it was `sending`, records `sent_at` (the first such attempt). The next attempt first lists the project's tasks created since `sent_at − 1 h`, newest first, page by page until the newest match or the window's end, and adopts the newest one with the sent title that this account's user created (for a link-share guest the share's pseudo user, id `-shareId`, [D62](#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind)) and that no other create of this device has adopted (of two in the same second, the higher id), completing the create as if the answer had arrived; only when none is found is the create sent again (why: a blind resend makes a duplicate). Another member's task of the same title is never adopted, because the ops queued behind the create would follow it to that task. The creator is checked whenever the account's user id is known, as for uploads ([D53](#d53-attachments-uploaded-through-the-outbox-opened-through-the-platform-android-share-target)).
- **A rejected create** (`DomainError` 4001 or 4029, `ValidationFailed`, no access, project gone or archived) is a sync problem that names the title. The ops behind it wait; an edit folds into it and queues it again, as Retry does; Discard cancels the create with its row, without a server read.
- **Edits:** `TaskChanges` carries `repeatAfter` (sent as seconds; `Duration.zero` in the default mode removes the repeat), `repeatMode` and `projectId`. After a move both adapters read the task back, because the server's answer still carries the old project's identifier.
- **Editing rules from the web** (`vikunja_logic`):
  - the date shortcuts of the web's `buildDateShortcuts(now)` with its day-interval table: from 21:00 `today` is hidden (another shortcut landing on today still shows), `thisWeekend` is hidden on Sunday, `inAMonth` is clamped to the month's last day, and of two shortcuts on the same day the later one is dropped;
  - a date-only pick takes the next breakpoint among 9, 12, 15, 18 and 21 (a full hour counts as its own breakpoint; after 21:00 it is 9 the same day), and a date change keeps a time already set;
  - repeats: the presets every day, every week and every 30 days, the modes default, monthly and from completion date, the units hours, days and weeks; an amount of 0 is ignored and a negative one refused;
  - priority 0–5; percent done in 10 % steps;
  - colours: the colour row of [D81](#d81-vikunja-280-details-legal-links-okabeito-colours-lockout-hints-subtask-tree-accents).
- **UI:** a full-screen edit page (`/home/tasks/:id/edit`) edits title, project (the tree without archived projects), the three dates with time, priority, percent done, colour and repeat, plus labels, assignees and reminders ([D36](#d36-labels-assignees-and-reminders-in-the-task-update-label-creation-online)). Save sends only the diff, is disabled while nothing changed or the title is empty, and closes the page with a "Saved" snackbar; back with unsaved changes asks first. The task detail also changes the due date, priority, reminders and labels in place, each choice one change ([D84](#d84-everyday-editing-in-the-task-detail-properties-in-place-task-links-move-to-column)). The New task sheet is [D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab)'s, and the project a new task goes into is [D38](#d38-quick-add-the-webs-grammar-with-fixes-through-the-outbox)'s.

Limits:
- The lost-response match by title and creator can still adopt the user's own task of the same title that another device or the web created in that project within that hour; the phone's own is then never sent. Description and due date are no tie-break, because the server normalises both.
- The window has no upper end: a retry after a long time offline reads every task created in the project since `sent_at − 1 h`, page by page, when none matches.
- `default_due_time` from the web's settings is stored but not applied: a date-only pick always takes the breakpoint time.

## D36: Labels, assignees and reminders in the task update; label creation online

*Accepted 2026-10-11 (step 12b).*

- **Id-set deltas:** `TaskChanges.labels` and `TaskChanges.assignees` are `IdSetChange`s (`added`, `removed`; on merge the later change wins for an id both touch) in the ordinary update op, so the queueing, merging and folding of [D34](#d34-outbox-local-first-task-writes-one-serial-sender-coalescing-retry-classes) and the remap of [D35](#d35-task-creates-through-the-outbox-under-temporary-negative-ids) apply unchanged; there are no op kinds of their own. The edit page emits the deltas by id.
- **Sending with a read-before-write diff:** `TasksWritePort.update` sends the body fields first, then takes the task as the server has it (that answer, or `GET /tasks/{id}` when there were no body fields) and sends only what differs, in this order: label removes, label adds, assignee removes, assignee adds (`DELETE`, or v2 `POST` / v1 `PUT`, on `/tasks/{id}/labels` and `/tasks/{id}/assignees`); then it reads the task back once.
  - Counted as done: a label add answered 400 code 8001, an assignee add answered 400 code 4021, and a label remove answered 403 when one `GET` shows the label no longer attached. So the whole update is idempotent and a resend is harmless. A resend after a repeating task's Done had landed leaves out the body and sends only these requests, with the relations, board placements and list positions ([D34](#d34-outbox-local-first-task-writes-one-serial-sender-coalescing-retry-classes)).
  - Why not the bulk endpoints or the v1 body: they replace the whole set, so a label added on the web while the phone's change waited would be dropped.
- **Failures:** `NotFound` 8002 (label gone) or 1005 (user gone) and `Forbidden` 7003 (user without access to the project) or without a code (a label the user cannot see) are permanent: a sync problem with Retry and Discard; Discard restores the server's labels, assignees and reminders. A transient 500 is retried. A `NotFound` other than a gone task's never removes the task.
- **Reminders as the whole list:** `TaskChanges.reminders` is the task's complete list (empty removes every reminder; the later list wins), sent as `reminders` in the patch or the v1 overlay, and with a create in `NewTask.reminders`.
  - A relative reminder's instant is computed locally from its date (null while that date is unset) until the server's value replaces it.
  - The server keeps one reminder per instant, so the editor never adds a reminder equal to one listed, and the edit page warns before a save where two would share an instant (every relative reminder of an unset date counts as one).
- **Read-back:** after a reminder or date change, a move, or label and assignee requests, `update` reads the task back once, because the answer echoes reminders the server merged. The sync also rewrites a task whose reminders differ from the local ones (`sameReminders`), although `Task ==` ignores them.
- **Local apply:** `task_labels`, `task_assignees` and `task_reminders` change in the transaction that queues the op; an id without a local label or user row is queued but not shown until a sync brings the row. The remap applies the pending changes to the child rows too, and the sync's upserts keep pending labels and assignees (as a delta on the incoming sets) and pending reminders (replacing the incoming list, relative instants computed again).
- A label the sync finds deleted on the server leaves the queue: `OutboxDao.forgetLabels` takes its id out of every unsent update; an update left empty goes, a failed one that changed is queued again.
- Undoing a done on a repeating task also sends its previous reminders, so the server's shift of absolute reminders is taken back.
- **Label creation online only** (owner, [D60](#d60-labels-teams-and-shares-online-the-stored-project-permission-shapes-every-screen)):
  - The label picker offers "Create label "X"" when no label has the typed title (case-insensitive); the label is created on the server with a random colour of the Okabe–Ito palette (owner, [D81](#d81-vikunja-280-details-legal-links-okabeito-colours-lockout-hints-subtask-tree-accents)) and stored, and attaching it goes through the outbox. Offline the picker says that creating a label needs a connection; titles over 250 characters are refused before a request.
  - A create whose answer was lost is not repeated blindly (the server would store a second label with that title): the newest label with exactly that title that this user created within the last hour and the device does not know is adopted. Another member's label of that title, which the label search returns once it is attached to a task the user can see, is never adopted; the user id comes from the account registry, as for the outbox sender. Titles with an unanswered create are looked up the same way before the next create of that title, and when that lookup fails too, the create stops and the picker says it could not confirm the label.
- **People search online, known people offline:** `searchAssignees(projectId, query)` (v2 `GET /projects/{id}/users/search?q=`, v1 `GET /projects/{id}/projectusers?s=`) stores the users it returns. The picker searches on open and 300 ms after the last keystroke; only the latest query's answer counts. When the search fails, it shows the known people (of the synced tasks and earlier searches) with a notice. A move to another project keeps the assignees; one without access there fails with 7003 as a sync problem. Known people are filtered ignoring case and accents, and an answer keeps the project's people from earlier answers that match the query ignoring accents ([D81](#d81-vikunja-280-details-legal-links-okabeito-colours-lockout-hints-subtask-tree-accents)).
- **UI:** on the edit page, Labels and Assignees after Project, Reminders after the dates: label chips in the label's colour and assignee chips with initials and the display name, each removable; label and people pickers as adaptive multi-select sheets; reminder rows with edit and remove (a relative one with its instant from the draft's dates, or a warning that its date is not set); the reminder sheet with the web's presets relative to the due date (else the start, else the end date), a custom relative form and an absolute date and time. Editing a relative reminder keeps its sign, where the web always shows "before". The task detail also changes labels and reminders in place, with the same label picker, reminder rows and reminder sheet, as it does the due date and the priority ([D84](#d84-everyday-editing-in-the-task-detail-properties-in-place-task-links-move-to-column)).

Limits:
- The requests of one update are not atomic: when one fails for good, the earlier ones stay applied; Retry sends only what is still missing.
- Per id the last write wins: a label the web removed while the phone's add waited is attached again.
- Creating a label needs a connection.

## D37: Account switcher: an avatar sheet, a switch resets the navigation

*Accepted 2026-10-11 (step 4).*

- **Entry points:** the active account's avatar (a guest's link icon, [D62](#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind)) at the end of the Overview, Upcoming and Projects app bars, announced as "Accounts, signed in as *name* on *host*", opens the adaptive account switcher sheet: the accounts by recency, the active one first and marked, each with avatar, name (else username), `@username · <host>` (the port only when not the default) and badges for "Sign in again" (`needsReauth`) and "N unsent"; a tap switches, closes the sheet and confirms with a snackbar; then "Add account" and "Manage accounts" (opens the Account tab). The Account tab's Accounts section lists the other accounts (tap to switch, a menu with "Remove…") and "Add account"; the rest of the Account tab (banner, sync status, pending changes, sync problems) stays about the active account.
- **The switch:** `AccountSwitcher.switchTo(id)` only sets the active id in the registry ([D25](#d25-account-registry-in-sharedpreferences-without-secrets)), and everything keyed by the active account follows. It refuses (returns false) for the active or an unknown id and while a sign-in, a sign-out or another switch runs (why: a finishing sign-in activates its own account).
  - Before the next frame the shell closes every dialog, sheet, pane ([D70](#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere)) and page over the shell (pages in `AccountBoundScreen` show blank while they animate out), resets every tab to its root and shows the Overview, so no screen reads another account's database. Links, widget and notification taps switch the same way ([D44](#d44-task-detail-own-rich-text-parser-online-details-app-scheme-links), [D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links)).
  - A switch, a removal of the active account and re-adding an existing one wait (at most 5 s) for the target engine's stored state, so an account that has synced never passes through `/sync`; the router reads the registry and `accountSyncStatusProvider(id)` itself, and outbox readers ignore a value of the previous account (why: Riverpod delivers derived providers a frame late). `/sync` has no entrance transition (why: a quick round trip would build two shells with the same navigator keys).
- **Recency:** the registry keeps the activation order, most recent first, as an extra field; `setActive` and `upsert(activate: true)` move the id to the front, `remove` drops it. Without the field it reads as the stored order with the active account first; the stored order never changes.
- **Add account:** the onboarding Connect screen pushed over the shell in an adding mode, with a close button (Android back and the iOS swipe too) and the existing accounts' servers as chips ("Your servers", reusing their stored root). A new account goes to its first sync. One already on the device (same user and server, so never a duplicate; `SignInSucceeded.isNewAccount` false) gets its session replaced, becomes active and says "You're already signed in to this account — switched to it" (without "switched to it" when it was already active).
- **Remove:** `SignOut` for any account (server logout, tokens wiped, registry entry removed, sender and engine disposed, database deleted). The dialog names the account and server and warns of deleted local data and lost unsent changes. While other accounts exist, the active account's button reads "Sign out of this account" and its dialog names the account the app switches to: the most recently active remaining one; the snackbar says "Signed out of *name*". Removing an inactive account leaves the active one and its screens alone (its scheduler and session check only pause while the sign-out runs). Connect shows only after the last account. Cancelling an added account's first sync is the same sign-out.
- **Inactive outboxes drain in the foreground** (`inactiveOutboxesProvider`, while the shell is up): on start, resume and a change of the account list, every other account that is not `needsReauth` and has queued ops (counted on its database) is asked to drain, never during a sign-out; no sender is built for an account without queued ops, and one built is kept until the account goes. The active account keeps its own triggers. Inactive accounts are not synced in the foreground (why: queued changes are what cannot wait; [D40](#d40-background-sync-of-every-account-server-notifications-in-an-inbox) syncs them in the background).

Limits:
- Start and resume open every inactive account's database to count its queue.
- An inactive account whose session ended needs a switch to sign in again.

## D38: Quick add: the web's grammar with fixes, through the outbox

*Accepted 2026-10-12 (step 13).*

- **The parser** lives in the pure package `vikunja_logic` (`parseTaskText(text, now:, mode:)`, `quickAddPrefixes`, `cleanupItemText`, `ParsedTaskText`, `QuickAddRepeat.toTaskRepeat()`), with the day intervals (`calculateDayInterval`) and the default time (`nearestBreakpointHour`, the web's `calculateNearestHours`) that the app's `date_shortcuts.dart` also uses; `now` is injected, dates are local wall-clock `DateTime`s. It re-expresses the web's behaviour without its code ([D67](#d67-agpl-30-or-later-with-an-app-store-permission-dco-reserved-brand-embedded-cronet)); the web's vectors (`quickAddMagic.test.ts`, `helpers/task.test.ts`, `useQuickAddTask.test.ts` at `e7d7f17`) are ported with fixed `now`s, the cases of a deviation marked `D19-n` ([D19](#d19-quick-add-keeps-the-web-grammar-and-fixes-four-parser-bugs)'s items, points 1–4 below) or `D38-n` (the points below).
- **The grammar is the web's** ([research/client-logic.md](research/client-logic.md) §1.2–§1.8): pipeline order, prefix modes (`vikunja`: `*` label, `+` project, `!` priority, `@` assignee; `todoist`: `@`, `#`, `!`, `+`; `disabled` parses nothing), quoted items, the cleanup, priorities 0–5, repeat phrases, the date rules with the `at`/`@` suffix and the absolute patterns, emulating JS `Date` (a day up to 31 overflows into the next month, two-digit years). English keywords only (why: the web has no translated ones, and mixed languages would be ambiguous).
  1. **Repeats** (D19 item 1): `every N months` (N ≠ 1) every N × 30 days; `every month`, `monthly` the monthly mode; `every N years`, `yearly`, `annually` every N × 365 days; `biannually`, `semiannually` 180 days; `biennially` 730 days.
  2. **Capitalised keywords** (`Daily`, `Every Day`, `Weekly`) mean what the lower-case ones mean (D19 item 2).
  3. **A trailing word boundary** for `today`, `tonight`, `tomorrow`, `next week`, `next month`, `this weekend`, `later this week`, `later next week`, `end of month`, `next monday`: `todays`, `tomorrows`, `next weekend` stay text (D19 item 3).
  4. **Day and month as whole words:** `12 decorations` stays text, `12 dec` and `dec 12` parse (D19 item 4).
  5. **Weekday and ordinal dates get the default time** (the next of 9, 12, 15, 18 and 21 o'clock, seconds zero), not the clock time of `now`; `at …` wins; `end of month` is 09:00 of the last day. As on the web, an ordinal with a month may lie in the past and `in N …` adds to `now`.
  6. **`next monday` on a Monday is today; after 21:00 the default time is 09:00 the same day**, as on the web.
  7. **An unmatched `+project` stays in the title** (why: the web drops it and silently uses another project). Archived projects are not matched (a create there fails with 3008).
  8. **Lines that are only magic** never get labels created.
  9. **Whole words elsewhere:** the `in …` rule needs a space or the line start before it (`within 2 days` stays text); it takes digits, `a`/`an` and one to twelve in any case, with the units minute to year, and repeats take `eleven` and `twelve` (Vikunja 2.8.0's phrases, owner). After the unit a word boundary ends it, so punctuation still gives a date (`in 2 days,`), unlike the web's space or end (owner); an apostrophe keeps it text (`in a day's work`), as on the web. Date phrases and an ordinal's month word are removed only as whole words (the web turns `fri frisbee` into `sbee`); a day no month has (`dec 45`, `dec 0`) stays in the title; amounts above 100000 in `every N …` and `in N …`, and `in …` dates after the year 9999, stay text.
  10. **Everything else follows the web:** a magic-only line keeps its raw title and parses nothing; a text quoted whole is literal, without the quotes; assignees stay in the title until resolved; a repeat without a date is due today at the default time; default reminders apply only with a due date.
- **`QuickAddService.plan(line, fallbackProjectId:, fallbackDueDate:, fallbackPriority:)`** resolves without a request against the active account's snapshots: unarchived projects by exact title ignoring case, else identifier (of several the first, saying so); labels by exact title ignoring case (others are new); known users by exact username or name ignoring case. An unmatched project's token is reparsed as one word, so title, dates and highlighting come from one parse. Without a date phrase the sheet's date applies (else, for a repeat, today at the default time), without `!n` the sheet's priority, and the default reminders become relative to the due date. The preview comes from it, and submit creates what it plans.
- **`submit(text, …, extras:)`** plans each line (several lines lose their common indent and the markers `- `, `* `, `+ `, `[ ] `; deeper lines become subtasks, [D41](#d41-relations-as-task-update-deltas-duplicate-and-follow-online-indented-subtasks)), then:
  - looks every name up with `UserRepository.searchAssignees(projectId, name)` by the web's rule (one result containing it in username, name or email, or one of several equal to it), the plan's resolved ones too, since a known person may lack access; only on a `NetworkFailure` does the plan stand; resolved names leave the title, the others stay;
  - creates missing labels once across all lines through `LabelRepository.findOrCreate` (adopting the server's label of that title, else online with a random Okabe–Ito colour, [D81](#d81-vikunja-280-details-legal-links-okabeito-colours-lockout-hints-subtask-tree-accents), and [D36](#d36-labels-assignees-and-reminders-in-the-task-update-label-creation-online)'s adoption of a lost answer), skipping one that fails; label creation stays online only ([D60](#d60-labels-teams-and-shares-online-the-stored-project-permission-shapes-every-screen));
  - keeps a typed label that could not be created (offline after the first network failure, refused by the server, longer than a label may be, or any new label of a guest) at the end of its line's title as typed (`*Urgent`, `*"road trip"`, `@neu` in the Todoist mode, a doubled prefix too), found in the line ignoring case, else written as the prefix and the title, quoted when it holds a space; not a second time when the title holds it already (an unclosed quote, which the parser leaves in the text);
  - queues per line `createTask`, then `updateTask(labels:, assignees:)` behind it, sent after the remap ([D35](#d35-task-creates-through-the-outbox-under-temporary-negative-ids), [D36](#d36-labels-assignees-and-reminders-in-the-task-update-label-creation-online)), offline too, in input order, never the bulk endpoint;
  - cuts a title over 1000 code points as [D78](#d78-vikunja-280-trash-codes-as-gone-its-limits-no-nul-info-re-read) says, the rest starting the description, after the kept labels were added;
  - gives every task the sheet's More options (`QuickAddExtras`: description, labels, reminders, repeat, [D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab)), a line's labels and reminders adding to them without duplicates and its repeat replacing the sheet's; the sheet's and the default reminders stop at [D78](#d78-vikunja-280-trash-codes-as-gone-its-limits-no-nul-info-re-read)'s 100;
  - returns (`QuickAddResult`) the created local ids, the labels picked in the sheet that could not be created (`labelsNotCreated`), the typed labels kept in a title (`labelsKept`, as typed and once each ignoring case; one both typed and picked is in both) and the names left in a title; a failure after earlier lines is `QuickAddPartlyFailed`, and the composer keeps the lines not created.
- **Project order:** the matched `+project`, else the screen's project, `default_project_id`, the project titled Inbox, the tree's first project (`defaultProjectFor`), each only among the projects the user may add tasks to ([D60](#d60-labels-teams-and-shares-online-the-stored-project-permission-shapes-every-screen)); without one the composer says so inline.
- **Settings:** `GET /user`, which every sync run reads first, gives `quick_add_magic_mode` (`disabled`, `vikunja` or `todoist`; `vikunja` by default), `quick_add_default_reminders` (`[{relative_period: seconds}]`, none by default) and `default_project_id` (0 = none). `parseUserSettings` (`vikunja_api`) reads them into `UserSettings` (`vikunja_domain`) tolerantly: an odd or missing field, or a `frontend_settings` that is `null` or no object, takes the web's default, and only reminders with an integer `relative_period` count. A change is stored in the account's `sync_state` (`user_settings`); `userSettingsProvider` streams the active account's, the defaults before the first sync. Editing them is [D54](#d54-account-settings-in-the-app-password-and-email-on-the-web).
- **The composer** (the new-task sheet's title field; the sheet is [D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab)):
  - highlights what the plan recognised by colour and weight, never by colour alone;
  - previews as chips what the text sets (due date, repeat, project or "Project "x" not found", labels marked "new", offline "needs a connection" and for a guest "stays in the title", assignees "will be looked up", priority, default reminders), each removable from the text, keeping the focus; the sheet's own date and priority are the selected chips of their rows, and a due date that only a typed repeat gives keeps its chip (owner);
  - suggests, in a prefixed token, labels, unarchived projects and people (known users plus a debounced server search for the project, the latest query winning), ignoring case and accents, above the buttons; a tap puts in the value, quoted when it has spaces, plus a space;
  - has a `?` button at the end of the field for the mode's help (English keywords, localised prose, and the sheet says so) unless the mode is `disabled`, and no `* + @ !` prefix toolbar (owner); the help says that without a connection a new label's word stays in the title, and a guest's that only existing labels are added;
  - leaves the sheet's project, date and priority as fallbacks: each shows the text's value and is locked while every line sets it (a subtask without a project takes its parent's);
  - turns multi-line when lines are pasted, with "Add N tasks", the keyboard's action key still adding; Add closes the sheet and confirms "Added "title"" or "Added N tasks", naming the labels kept in a title (which "Added "title"" shows too), the sheet's labels not created and names left in titles;
  - is a plain field, without highlighting or suggestions, when the mode is `disabled`.
- **From anywhere:** an Android app shortcut and an iOS quick action "New task" (`quick_actions`, localised titles) open the composer over the Overview once signed in and synced, and are ignored otherwise.

Limits:
- A new label needs a connection; offline the task is created without it, and the word stays at the end of the title, not where it was typed: labels are created at Add, after the title was worked out, and keeping the word in place would need a second parse.
- A doubled prefix inside a line (`Fix **bike`) leaves one `*` in the text, as the web's parser does, so a label kept there reads `Fix * **bike`.
- A date phrase removed before punctuation leaves a space (`Call back .`).
- The web's Quick Add keeps a date range such as `31.12.2026 - 01.01.2027` in the title, while the app's parser takes the first date.

## D39: Local notifications: a scheduler per account with a rolling window

*Accepted 2026-10-12 (step 15).*

- **Why local:** the server pushes nothing, and its in-app reminder notifications reach a phone only with a poll, after the fact.
- **The plan** (`planNotifications`, pure, from the local database): open tasks not queued for deletion that the user created or is assigned to ([D17](#d17-notification-policy)); on Vikunja 2.8.0 and later, for users, the tasks the user follows ([D80](#d80-reminders-follow-subscriptions-on-vikunja-280-and-later)). Each future reminder gives the key `<taskId>:reminder:<ordinal>` (its position in the task's list, so the key stays when the reminder moves) while the account's Reminders switch is on, the due date `<taskId>:due` at its instant while Due dates is on. A reminder at the due instant itself is not planned while both switches are on, so that moment rings once, as "Due now"; the task's other reminders keep their keys, and an entry already scheduled under the dropped key is cancelled by the next reconcile's diff. Snoozes never count here: a snoozed reminder at the due time still comes back, and while the due date is snoozed every reminder stays. Sorted by instant, then key. Instants are scheduled in UTC (`tz.TZDateTime.from(instant, tz.UTC)`), so no time zone is involved. Title: the task's; body "Reminder · *project*" or "Due now · *project*", no identifier (owner, [D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab)), or generic texts by the privacy settings ([D64](#d64-app-lock-over-the-ui-and-device-privacy-settings)).
- **The rolling window** (`diffSchedule`, pure): only the first 100 entries (Android) or 60 (iOS, leaving room under its cap of 64 for snoozes and the test notification) go to the OS. What left the window or differs (instant, title, body, exactness, privacy) is cancelled, what is missing is scheduled, the rest stays; every reconcile refills it. A row whose id the OS no longer holds is scheduled again. Each row records whether its alarm was exact, so a granted or revoked exact-alarm permission re-registers the window (why: the plugin's pending list does not notice a revocation).
- **OS ids:** a 31-bit hash of `<accountId>:<key>` (the first four bytes of its SHA-256, sign bit cleared), probing upwards on a collision within the account; across accounts a collision is fixed by the other account's next reconcile. Id 1 is the test notification.
- **`scheduled_notifications`** in the account's database (shared across isolates, gone with the account): `key`, `os_id`, `task_id`, `kind`, `fire_at`, `title`, `body`, `snoozed_until`, `snooze_original_fire_at`, `exact`, `hidden_on_lock_screen`, `done_needs_unlock`.
- **`NotificationScheduler`**, one per signed-in account while the app runs (a keep-alive provider the shell listens to): `reconcile()` plans, diffs, cancels, schedules and writes the table guarded (when another isolate changed it meanwhile, it runs again); runs are serialized, a call during one queues one more. Without the permission, or with both switches off, it cancels everything of the account and clears the table. Android uses `exactAllowWhileIdle` when exact alarms are allowed, else `inexactAllowWhileIdle`; iOS is exact.
  - Triggers: a ≈ 700 ms debounced watch on `tasks`, `task_reminders`, `task_assignees` and `projects`, the preferences, start and resume, the end of a background action and every background run ([D40](#d40-background-sync-of-every-account-server-notifications-in-an-inbox)); privacy or language changes reschedule everything (`reconcile(force: true)`, snoozes kept, [D64](#d64-app-lock-over-the-ui-and-device-privacy-settings), [D71](#d71-english-and-german-us-base-glossary-error-texts-live-language-changes)).
  - Sign-out and removal dispose it and cancel the account's ids before its database goes (`AccountDataWiper`).
- **Preferences per account** (`notifications.<accountId>` in the preferences store, not the database, which may not be open yet): Reminders, Due dates and Activity ([D40](#d40-background-sync-of-every-account-server-notifications-in-an-inbox)), all on by default.
- **Snooze is local only** (`snooze_10m`, `snooze_1h`): the row stores `until` (now + 10 min or + 1 h) and the planned instant, the OS gets the moved entry at once, and the plan keeps it at `until` while that instant still matches; after the notification fired the entry is rebuilt from the task by its key, and an unset or later instant makes the snooze a no-op. A changed task time or an expired snooze drops it. Nothing reaches the server (why: it would change the task for everyone, and the web has no snooze).
- **Done from a background isolate, through the outbox, without a token refresh:** the top-level `@pragma('vm:entry-point')` handler (`core/notifications/notification_entry_points.dart`) builds a container like `bootstrap.dart` and runs `ExternalDone`, shared with the widgets ([D63](#d63-home-screen-widgets-app-written-snapshots-glance-on-android-widgetkit-on-ios)): `setDone` through the outbox (a temporary id through the remap), the task's other notifications cancelled before any wait, a drain of at most ≈ 20 s (≈ 5 s on iOS, which may suspend the process), a reconcile. Its sender sends only while the stored access token needs no refresh (why: a lost refresh race ends the session, [D26](#d26-refresh-concurrency-single-flight-re-read-and-adopt-write-ahead-epoch)); else the op waits and, on Android, a one-off drain is queued ([D40](#d40-background-sync-of-every-account-server-notifications-in-an-inbox)). Errors never crash the isolate. With the app lock on, iOS asks for the unlock ([D64](#d64-app-lock-over-the-ui-and-device-privacy-settings)).
- **Texts:** the app's isolate follows the device's or app's language ([D71](#d71-english-and-german-us-base-glossary-error-texts-live-language-changes)) and notes its tag (`notifications.locale`); a headless isolate resolves the device's locales once, else that tag (iOS reports none there), else English.
- **A tap** (also on a cold start) opens the task through `TaskOpener` ([D44](#d44-task-detail-own-rich-text-parser-online-details-app-scheme-links)), after the shell and the lock, in the payload's account; a refused switch drops it, a gone task says so. The payload `{account, task, key, k}` switches silently only with the install's widget-link key `k` ([D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links)). Notifications also show while the app is in front (on iOS as alert, banner and sound).
- **Setup once per device** (`/notifications-setup`, after the first account's first sync, while `notifications.onboarded` is unset; "Not now" sets it): "Stay on top of your tasks", what is notified (reminders at their time, due dates at the exact time, and for which tasks, worded by [D80](#d80-reminders-follow-subscriptions-on-vikunja-280-and-later)) and "Turn on notifications"; on Android 14+ without exact alarms a step saying reminders can be minutes late, with "Allow exact alarms" and "Skip", checked again on resume.
- **Account tab, Notifications:** the switches and which tasks they cover ([D80](#d80-reminders-follow-subscriptions-on-vikunja-280-and-later)), a status line ("Notifications are off" with "Open settings", "Reminders may be late" with "Allow exact alarms"), the count scheduled and "Send a test notification" (id 1; its tap opens the Account tab).
- **Platforms:** flutter_local_notifications 22.3.2 and timezone 0.11.2 behind `LocalNotificationGateway`; Android channel `reminders` (high importance, localised name and description); Done and both snoozes as background actions (Android `showsUserInterface: false`, `cancelNotification: true`; iOS categories `task` and, with the app lock on, `task_locked`, without the foreground option). Android declares `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM` (never `USE_EXACT_ALARM`, which Play reserves for alarm, timer and calendar apps, [D76](#d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android)) and `RECEIVE_BOOT_COMPLETED`, with core library desugaring and the llama head as the monochrome icon ([D42](#d42-app-icon-vikunjas-logo-every-variant-derived-by-script)).

Limits:
- Without exact alarms on Android 14+ a reminder can be minutes late; the setup and the Account tab say so.
- While the app is closed only the background runs refill the window; a reboot restores only the pending ones.
- A background Done with an expired token waits for a run that may refresh; a repeating task stays done locally until the server's answer reopens it.
- No grouping and no custom sounds.
- A due notification snoozed to the exact time of one of the task's reminders rings twice at that moment.

## D40: Background sync of every account; server notifications in an inbox

*Accepted 2026-10-13 (step 16).*

**Background runs** (why: Vikunja has no push channel to a phone)
- **One periodic job for all accounts** (`WorkmanagerBackgroundScheduler`, workmanager 0.10.10), registered after the first frame while an account exists, cancelled by the last sign-out (`cancelAll()`): Android every 30 min with `NetworkType.connected` and `ExistingPeriodicWorkPolicy.update` (re-registering neither duplicates nor restarts it); iOS the BGTaskScheduler task `io.vikunja.app.sync` (in review), 30 min as the earliest begin (`UIBackgroundModes: fetch`, the permitted identifier and the plugin's handlers in `AppDelegate.swift`). No foreground service, battery-optimisation exemption, exact alarm or expedited work, so no special Play declaration ([D76](#d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android)).
- **The runner** (`BackgroundSyncRunner`, from `callbackDispatcher` in `core/background/background_entry_point.dart`) uses session managers that refresh (why: else no session stays alive, [D22](#d22-session-keep-alive-through-background-sync); [D26](#d26-refresh-concurrency-single-flight-re-read-and-adopt-write-ahead-epoch) makes it safe). Deadline 9 min on Android (WorkManager stops at 10), 25 s on iOS, 2 min for a drain run; an account starts only with at least 10 s left; at the deadline or an OS stop (`onTaskStopped`) a refresh in flight gets 3 s, then the container is disposed. It always reports success (why: a failure adds WorkManager's backoff). It records `background.lastRunAt.<account>` and `background.lastRunResult` for the Account tab.
- **Skipped while the app is in front:** a run finding the UI's heartbeat (every 30 s while visible, on its own timer) younger than 2 min does nothing, checked again before each account (why: the foreground syncs the active account, drains the others' outboxes, [D37](#d37-account-switcher-an-avatar-sheet-a-switch-resets-the-navigation), and reconciles every scheduler).
- **Order:** the widgets' queued Done taps are imported first ([D63](#d63-home-screen-widgets-app-written-snapshots-glance-on-android-widgetkit-on-ios)); accounts take turns by the start of their last turn, the oldest first, so one that never gets through starves no other; a failure in one does not stop the next.
- **Queues first**: a sync run sends every account's queued changes before any account syncs, in the same order (why: the user's own changes are worth more than fresh data when the OS ends a run early, as iOS does after 25 s). It skips an account that must sign in again, one that never synced, one the app released and an empty queue (a local count, no sender built, no request). Each send keeps the 10 s rule and the check for the app in front, which end the run as they do between turns; backoffs are dropped. The sender leaves its refresh to the run (`sendNow(refreshAfter: false)`, [D34](#d34-outbox-local-first-task-writes-one-serial-sender-coalescing-retry-classes)), which syncs right after, so each account syncs once. A server found unreachable while sending is not synced in that run. On every platform, not only iOS: one way through, at the cost of a local count per account on Android.
- **Per account:** reconcile the notifications from local data ([D39](#d39-local-notifications-a-scheduler-per-account-with-a-rolling-window)) → incremental sync ([D33](#d33-incremental-sync-from-an-updated-watermark-deletes-found-by-counts), never the daily full resync headless) → activity sync and notifications (not for guests, [D62](#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind)) → reconcile again after a sync → widget snapshots ([D63](#d63-home-screen-widgets-app-written-snapshots-glance-on-android-widgetkit-on-ios)). An unreachable server skips the remaining network steps; an account without a completed first sync only reconciles. A drain run only drains, with the sender's own refresh after it, and publishes the widgets.
- **The keep-alive:** each run's incremental sync keeps the account's session alive as [D22](#d22-session-keep-alive-through-background-sync) says.
- **Session ended:** the account is marked `needsReauth` (data kept, outbox paused) and one "Sign in again to *host*" notification is posted per ended session (key `session:<account>`, remembered in `notifications.sessionEnded.<account>`), withdrawn once it works again; meanwhile it only reconciles and publishes widgets.
- **One sync per account across isolates:** each sync takes the account's lease in `sync_state` (`sync_lease`, `{owner, until}`, 3 min), renews it at checkpoints and before requests, checks it in the purge's and completion's transactions, and stops without purging when it lost it (why: a full run purges tasks it did not mark). The app's engine waits for a foreign lease and adopts that state; headless engines (`runsHeadlessProvider`) skip. A sign-out in the app releases the account in a running run (`BackgroundRunnerChannel`). The outbox needs no lease ([D34](#d34-outbox-local-first-task-writes-one-serial-sender-coalescing-retry-classes)).
- **Drain after a background Done:** a notification's or widget's Done ending with `TokenRejected` calls `enqueueDrain()`: on Android an ordinary one-off task with a network constraint, appended after a running one (`ExistingWorkPolicy.append`); not expedited (why: below Android 12 that needs a foreground service the plugin lacks). On iOS it does nothing, as iOS has no on-demand runs.

**Server notifications**
- **`ActivitySync`** (per account, headless) pulls `GET /notifications` newest first until a known id, at most 3 pages (hourly and on pull-to-refresh further while an older stored one is unread here, within the 200 kept), keeps the local `read_pending` and `notified`, and sends pending reads (`markAllRead()` when all unread are pending, else `markRead(id)`; kept on failure; a 403 or coded 404 counts as done). The first run of an account (no `activity_synced_at` in `sync_state`) stores everything as handled (why: a sign-in never floods the shade); the inbox still lists it.
- **Cadence:** the active account on start, resume, every 5 min in front (every 5th foreground tick) and on pull-to-refresh; every account in every background run; the realtime socket stores pushed ones at once ([D46](#d46-realtime-one-websocket-for-the-active-account-in-the-foreground)).
- **`server_notifications`** in the account's database (`id`, `name`, `payload`, `created`, `read_at`, `read_pending`, `notified`), pruned to the newest 200. Reads are local-first (`LocalActivityRepository`): marking read changes the table, badge and inbox at once and the next activity sync sends it; offline the inbox works from the table.
- **Activity notifications** (`ActivityNotifier`) for new unread `task.comment`, `task.assigned`, `task.mentioned`, `task.created`, `task.deleted`, `project.created` and `team.member.added`, while the Activity switch is on and the OS allows: the newest 5 of a run, the rest as one "More activity"; 10 per account kept in the tray (why: Android drops posts beyond 50 per app). Never `task.reminder` (the local ones fired on time).
  - Id: [D39](#d39-local-notifications-a-scheduler-per-account-with-a-rolling-window)'s hash of `<account>:activity:<id>`; payload `{account, task or 0 (0 for a deleted task), key: activity:<id>}`.
  - Title: the task (else the project or team); body in the web's wording with the doer: "Anna commented: …" (the comment's first 80 characters as plain text), "Anna assigned you", "Anna mentioned you", "Anna created this task in *project*", "Anna deleted this task", "Anna created the project *title*", "Anna added you to the team *team*"; the account named when several are signed in, unless notifications show no titles ([D64](#d64-app-lock-over-the-ui-and-device-privacy-settings)).
  - Android channel `activity` (default importance), no actions, no iOS category. The active account's are not shown while the app is in front (the bell's badge shows them).
- **The inbox** (`/home/inbox`, from the bell "Notifications, N unread" in the Overview header and Upcoming's menu, both not for guests): newest first under Today, Yesterday, Earlier; kind icon, doer's initials, the web's text with the task's title ("a task" without one), relative time, bold while unread; no identifier (owner, [D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab)). A tap marks read and opens the task (read online when not on the device, at the comment for one), the project or the team; "Mark all as read", pull-to-refresh, "You're all caught up".
- **Taps:** `activity:<id>` switches when needed, marks read and opens the task on the device (at the comment; a task not on the device says so), else the inbox (task 0, also "More activity"); `session:<account>` switches and opens the Account tab with its banner; silent switches need the widget-link key ([D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links)).
- **Account tab:** the Activity switch under Notifications; under Sync "Background sync: *time* ago" or "Background sync has not run yet", on iOS noting that the system decides.

Limits:
- iOS may run the job rarely or never (never after a force-quit, not in Low Power Mode or without Background App Refresh), so its sessions can still end ([D22](#d22-session-keep-alive-through-background-sync)); Doze and standby buckets stretch Android's runs.
- A run begun before the app came to the front can still be inside an account the user then removes; the release narrows this, it does not close it.
- On iOS a server that cannot be reached, with changes queued, can take about 10 s of the 25 s before the first sync starts.
- Server notifications cannot be deleted in the app.

## D41: Relations as task-update deltas, duplicate and follow online, indented subtasks

*Accepted 2026-10-13 (step 14).*

- **Edges in `TaskChanges`:** `relations` is a `RelationChange` (`vikunja_domain`: edges `added` and `removed`, each a `TaskRelationRef(kind, otherTaskId)`; the later change wins per edge), stored as `{"added": [{"kind", "other"}], "removed": […]}`. No op kind of its own (why: one op per task keeps the rules of [D34](#d34-outbox-local-first-task-writes-one-serial-sender-coalescing-retry-classes) and [D35](#d35-task-creates-through-the-outbox-under-temporary-negative-ids)). An edge is queued on the task the user edits, from its side, as on the web: a new subtask is the child's `parenttask` edge.
- **Sent with a read-before-write diff:** `TasksWritePort.update` compares with the task as the server has it, removes listed `removed` edges, then adds missing `added` ones (v2 `POST`, v1 `PUT /tasks/{id}/relations`; `DELETE /tasks/{id}/relations/{kind}/{otherId}`), and reads the task back once when it sent anything. The server keeps the inverse edge on the other task and deletes both directions.
  - Done already: an add answered 409 code 4008, a remove answered 404 code 4009, and a remove whose other task is gone (4002, 4040; its project 3001, 3018) once the task no longer lists the edge.
  - An add whose other task is gone fails, when the task itself is there, as `RelatedTaskMissing` with the server's code (why: 4002 also means the base task is gone); so does such a remove while the edge is still listed. The op's other requests are tried first.
  - Temporary ids are refused (`ArgumentError`): the caller resolves them.
- **Temporary ids at both ends:** an edge on an unsent task waits behind its create ([D35](#d35-task-creates-through-the-outbox-under-temporary-negative-ids)); the other end is resolved through `TasksDao.resolveId` at send time, and an op still naming a temporary id waits while the next op goes first. `completeCreate` rewrites `task_relations.other_task_id` and the refs of every queued payload.
- **Inverse rows locally:** queuing an edge also changes the inverse rows on a local other task (subtask–parenttask, related–related, duplicateof–duplicates, blocking–blocked, precedes–follows, copiedfrom–copiedto), so a parent shows an offline subtask at once. The overlay keeps pending deltas over synced rows, and a pulled task rewrites the inverse rows others hold to it (why: the server bumps `updated` only on the task the request named). The v1 update takes the relations from its first read, not from its answer.
- **Failures:** a cycle (409 code 4023), the task itself (400 code 4010), an unknown kind (v2 422, v1 400 code 4007) and `RelatedTaskMissing` are permanent sync problems that say why, with Retry and Discard. A missing other task is forgotten like a gone label, out of every queued op and the stored rows; the failed op stays only to say why, and an edit merged into it later goes without that edge. A task the sync purges is forgotten the same way.
- **Duplicate online only:** `duplicateTask` drains the task's queued ops, refuses while any remain ("needs a connection" offline), calls `TasksWritePort.duplicate` (v2 `POST`, v1 `PUT /tasks/{id}/duplicate`) and upserts the copy; the source's `copiedto` edge comes with the next sync (why: the server copies its own state, every request makes another copy, and a lost answer could not be recovered by title).
- **Following online only:** `SubscriptionRepository` reads a task's or project's state when needed and toggles it, returning the read-back; a subscribe answered 412 code 12002, and an unsubscribe answered 403 without a code when a read shows no subscription, count as done. A task whose create is queued can be followed once synced. Nothing is queued; the reads are stored for the notifications ([D80](#d80-reminders-follow-subscriptions-on-vikunja-280-and-later)).
- **Indented quick-add lines become subtasks:** `parseSubtasksViaIndention(text, mode:)` (`vikunja_logic`) gives each line (`IndentedLine`) its parent line and inherited `+project` by the web's rules (a tab is four spaces, a bare `[ ] ` is a marker, a marker-only line is dropped and its subtasks move up, grandchildren inherit the project), pinned by `parseSubtasksViaIndention.test.ts` at `e7d7f17`. `submit` ([D38](#d38-quick-add-the-webs-grammar-with-fixes-through-the-outbox)) gives a child without a project its parent's and queues each child's `parenttask` edge after both creates.
- **UI** in the task detail:
  - Subtasks with a done checkbox, the title and, in another project, that project, a tap opening it; "Add subtask" creates one in the parent's project, offline too.
  - A Parent line that opens the parent, and Related grouped under localised kinds (Related to, Blocks, Blocked by, Precedes, Follows, Duplicate of, Duplicated by, Copied from, Copied to), each removable after a confirmation; "Add relation" has a kind picker (default `related`) and a search ("Search by title", identifiers too, ignoring accents) over local tasks, without the task itself and with done ones only when toggled.
  - No task identifier anywhere here (owner, [D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab)).
  - Duplicate in the menu ("Duplicated", with Open); a follow bell in the header from the details read, hidden while unknown (offline, with a hint that following needs a connection), showing "Following the project *title*" for an inherited follow and asking before stopping just this task; "Follow project" and "Unfollow project" in a project's menu.
  - Relations are not edited on the edit page; the composer counts a tree ("3 tasks, 2 as subtasks").

Limits:
- An update's requests are not atomic: after a permanent failure the earlier ones stay applied, and Retry sends only what is missing.
- An edge naming a task whose create was rejected waits as long as that create, holding later edits of its task; discarding that create drops the edge.
- A removed edge to a task in the trash comes back on 2.8.0 when that task is restored.
- `default_task_relation_type` is not read; "Add relation" starts at `related`.

## D42: App icon: Vikunja's logo, every variant derived by script

*Accepted 2026-10-13, the owner's decision; Vikunja's logo as the source since 2026-11-13 ([D83](#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp)), in review with step 38a.*

- The only source is Vikunja's logo, the llama on the blue disc (`branding/source/logo.svg`, copied byte for byte from go-vikunja/vikunja's `frontend/originalMedia/images/logo.svg`; [branding/README.md](../branding/README.md) has its provenance and SHA-256, which `app/test/app/app_icons_test.dart` checks) (owner). The old official app's icons are the look to follow (owner); they are not committed.
- `branding/build-icons.sh` derives every variant without editing the source: python3 writes two copies of the SVG (the llama without the disc, and a glyph), ImageMagick 7's own SVG renderer draws them at 4096 px, and every result is scaled down with Lanczos.
  - The llama on a solid `#196AFF`, as the old app's icons, in their proportions: the adaptive layers with the head and ears inside the 66 dp safe zone and the neck running off the bottom edge (why: launcher masks would clip the ears); the iOS icon on full-bleed blue without alpha; the iOS 18 dark icon on transparency, from which flutter_launcher_icons desaturates the tinted one; the Android 7 legacy icon from the visible 72 dp of the adaptive layers.
  - A glyph, the llama's silhouette with the eyes, nose and mouth and the inner ears cut out (why: Android uses only its alpha), for the themed icon and, as the head alone, the status bar and notification icon `ic_notification`.
  - The in-app logo is the round logo itself.
- File names and sizes are unchanged, so the launcher configuration, the iOS asset catalog, `keep.xml` and the globs of `NOTICE.md` keep matching. `app_icons_test.dart` checks the sizes, the white status bar icon, the blue background, the opaque iOS icon and the logo's transparent corners.
- The store graphics come from the icons ([D76](#d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android)); `branding/preview.sh` renders every variant for review.
- The theme's seed stays `#1973FF`, the Vikunja web's primary blue ([D56](#d56-design-after-the-owners-mockups-blue-scheme-cards-one-task-row)).

Limits:
- The status bar icon is the head with the face cut out; the old app's was the plain silhouette with the neck. At 24 px the eyes and mouth are faint marks, and the themed icon shows the ears as thin outlines at small sizes.
- flutter_launcher_icons' scaling leaves a regular grid of hdpi background pixels one step off `#196AFF`, which nobody can see; the test allows one step.
- Until step 38d `NOTICE.md` still calls the icon files derivatives of the Rurana llama, whose source (`branding/source/logo-llama.jpg`) and explorations stay in the repository, because a test needs every file `NOTICE.md` lists ([D67](#d67-agpl-30-or-later-with-an-app-store-permission-dco-reserved-brand-embedded-cronet)).
- The old app's status bar icon was called `vikunja_notification_logo`; step 38b adds that name as an alias for the update.

## D43: Task lists from the local database, nested and ordered like the web's

*Accepted 2026-10-14 (step 9).*

- **Which tasks:** the filter engine evaluates a view's filter on the local tasks ([D51](#d51-filter-engine-on-the-device-saved-filters-filter-builder-offline-search)), so changes show at once, offline too; a filter it refuses keeps the server's answer from the last download, minus tasks deleted here. `classifyViewFilter` (`vikunja_logic`) still tells the shapes `none`, `done = false`, `done = true` and other apart for the parts below.
- **The web's tree as of 2.8.0, on every server** (`buildTaskTree`, `vikunja_logic`; owner, [D81](#d81-vikunja-280-details-legal-links-okabeito-colours-lockout-hints-subtask-tree-accents)):
  - The top level is tested against what the server would send: the roots (the matching tasks without a matching parent) and every subtask reachable from them in the database, at any depth. A root is a top-level row only when none of its parents is in that set, so an open task below a done subtask shows once, nested, and a cycle that only its own tasks lead into shows nothing.
  - Each top-level row is followed by its descendants from the local database (any project, done or not), depth first in the parent's relation order. Each row has its own set of expanded tasks: a task expands only where it first appears below its row and only above `maxSubtaskDepth` (5), so rows lie at depths 0 to 5; a later appearance, a cycle's ancestor included, is a row without subtasks, and a subtask of two top-level rows shows under both.
  - Indents are capped at four levels. The project home-screen widget follows the same tree.
- **Show done** (an app addition) on `done = false` views, per view, off by default: on, the view is built as one without a filter, and the done top-level tasks follow in a Done part, which a view without a filter always has; `done = true` views and views with another filter have one part. Done subtasks of open parents stay nested, as on the web.
- **Order:** the view's sort, per view (the web's 17, "Manually" first). Manual order uses the last download's positions, with open tasks it lacked first, newest first (the server puts new tasks on top), then by position and id; the Done part by done-at, newest first, except in `done = true` views and views with another filter, which keep the positions. Other sorts put missing values last in both directions and fall back to the manual order on ties; priority and percent done count 0 as a value; "Updated" uses the created time of a task never sent. Dragging writes positions ([D49](#d49-manual-ordering-lists-through-the-outbox-projects-online-no-position-below-01)).
- **View snapshots** (`list_snapshots`, `list_snapshot_tasks`), because positions are per view, readable only through the view's tasks and never bump `updated`: `refreshProjectList` runs the sync and downloads the view's tasks by position over all pages (`filter_timezone` from the user's setting when set) when a list view opens with a snapshot missing or older than 5 min, and on pull-to-refresh; a view whose filter the engine refuses says so before its first download (downloading, offline or failed). The sync never downloads views.
- **The Overview:** the saved filter named by `filter_id_used_on_overview` (a pseudo project id the last project list named), evaluated on the device; only when the device cannot evaluate it does every sync run, background ones included, download its open tasks into the snapshot `overview:<pseudoId>` (rewritten only when they or their order changed; tasks done or deleted here hidden), shown under a notice with the filter's name ("My Open Tasks" translated) and the download time. Without one, every open task outside archived projects and their subprojects (`watchActiveOpenTasks`). Grouped by due date.
- **Upcoming**, the second tab: `selectUpcoming` evaluates in the device's zone with the server's datemath (`evaluateDatemath`: weeks from Monday, wall clock kept across DST) a web preset or custom range (default the next 7 days), strict bounds, a section per day. **Show overdue tasks** (on by default) pins every overdue open task in an Overdue part, never repeated below (why: what is late shows at a glance; the web drops the lower bound); **Show tasks without date** (off) adds a No due date part.
- **`list_preferences`** per account (in its database, kept by a full resync): sort and show-done per view, Upcoming's range and switches. A project opens on its default view every time ([D45](#d45-app-shell-colour-scheme-display-settings-projects-tab-smart-lists-offline-banner)).
- **The row** ([D56](#d56-design-after-the-owners-mockups-blue-scheme-cards-one-task-row)) as on the web: priority only on open tasks from `minimum_priority` (medium when unset), the task's colour, labels de-duplicated and by title, up to three avatars and "+N" (`AvatarsPort`, cached per account, SVG and missing ones as initials, failures retried after 2 min), the due date also when done, description and repeat icons, the checklist count, the percent bar, the project for another project's task, the pending marker; no identifier (owner, [D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab)). One screen-reader node, naming a subtask's parent.

Limits:
- Tasks created here sit at the top of a manual list until the next download places them; in a view whose filter the engine refuses, or a downloaded Overview filter, they appear only then.
- Upcoming uses the phone's zone, so it can differ from the web when the account's timezone setting differs.
- The tree cannot be collapsed.
- With "Show done" or in a view without a filter, a done task reached through another project can still show twice, because the open and the done part are built apart.
- Tasks more than five levels below a top-level row are not in the List view, as on the web; the detail sheet, the search, the Table and the Gantt chart reach them.

## D44: Task detail: own rich-text parser, online details, app-scheme links

*Accepted 2026-10-19 (step 10).*

- **Own parser and renderer** (why: the server stores description, comment and title HTML unsanitised, so the client is the only defence): `parseRichText` (`vikunja_logic`, on `package:html` within [D58](#d58-server-html-parsed-within-work-budgets-a-document-past-one-is-cut)'s budgets) parses like ProseMirror with the web editor's schema into a typed `RichDocument`; only schema nodes and allowed hrefs come out, and markup deeper than 96 elements becomes text. It matches the web's ProseMirror JSON on the oracle vectors except: no autolink on load, `<p><br></p>` is empty, `math` and form controls drop with their text, images neither attachments nor absolute http(s) are dropped.
  - Rendered with material_ui and cupertino_ui in a `SelectionArea`: header semantics, checkboxes ticked in place ([D52](#d52-descriptions-edited-in-a-locked-down-tiptap-webview-never-silently-overwritten)), code and wide tables scrolling sideways (beyond 50 columns or 5,000 cells row by row), mention and task-link pills. No HTML widget package and no WebView for reading (why: candidates applied inline styles, loaded images without the token or made `javascript:` links tappable). Editing is [D52](#d52-descriptions-edited-in-a-locked-down-tiptap-webview-never-silently-overwritten).
- **Links:** a task link, or an http(s) address `parseTaskIdFromUrl` accepts against the server root and `frontend_url`, opens the task in the app in the same account; other http(s) links open the browser (relative ones against the frontend URL); `mailto`, `tel`, `sms` and the web's other schemes pass `ExternalLinkOpener`'s allowlist. Such a task address pasted into the search shows that task ([D84](#d84-everyday-editing-in-the-task-detail-properties-in-place-task-links-move-to-column)).
- **Images:** attachment images load through the authenticated, per-account `AttachmentImages` memory cache at the `xl` preview ([D53](#d53-attachments-uploaded-through-the-outbox-opened-through-the-platform-android-share-target)'s preview route), falling back to the original, and open a zoomable viewer. The cache holds 32 MB and refuses responses above 25 MB and images above 40 megapixels before decoding. External images load only on a tap, which opens the browser; SVG is never decoded.
- **Details online, on demand:** one `GET /tasks/{id}` with `expand=reactions`, `comment_count` and `is_unread` when the detail opens; offline a quiet line with Retry, the synced part complete. An unread task is marked read at once. Comments load on "Show comments", a page at a time, by `(created, id)` in `comment_sort_order` ([D57](#d57-comments-online-with-a-kept-draft-reactions-comment-counts-and-unread-dot)); attachments show `md` thumbnails or icons, size and the cover badge ([D53](#d53-attachments-uploaded-through-the-outbox-opened-through-the-platform-android-share-target)).
- **The detail** (sheet, or pane on wide windows, [D70](#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere)): [D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab)'s header (the colour before the title, the project path as a breadcrumb, open or done under the title, no identifier), the watched project, the checklist summary, sorted labels, assignee avatars, a metadata line (created by, updated, done). The due date, priority, reminders and labels change in place, and the menu holds Move to column… for a board's card, Copy link, Share, Duplicate and Delete ([D84](#d84-everyday-editing-in-the-task-detail-properties-in-place-task-links-move-to-column)).
- **Deep links:** `vikunja-io.vikunja.app://task/<id>` (in review) and `…://task/<IDENT-12>`, optionally `?account=` on links the app makes. Android: a pass-through `TaskLinkActivity` owns host `task` (the sign-in `CallbackActivity` keeps `oauth/callback`, [D23](#d23-browser-sign-in-through-flutter_web_auth_2-in-an-ephemeral-session)) and hands links to the one `MainActivity` in the app's own task (why: no second engine), which drops a link on a Recents relaunch and on restore. iOS: a `CFBundleURLTypes` entry. Pushed routes reach the app only through [D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links)'s app-scheme relay, which passes on only the `task` host (and `widget`, [D63](#d63-home-screen-widgets-app-written-snapshots-glance-on-android-widgetkit-on-ios)). `overridePlatformDefaultLocation` keeps cold starts on the splash, and the start link is read once from the platform's default route. No link is logged.
- **One opener** (`TaskOpener`) for notification and widget taps, links, the inbox and pills: it waits for the splash, the first sync, the notification setup and the app lock ([D64](#d64-app-lock-over-the-ui-and-device-privacy-settings)), the last request winning; it picks the account (the link's, else the active one when it has the task locally, else those that have it, else the active one online) and asks before a link switches (why: anyone can make a link); `TaskResolver` finds the task locally by id or identifier and index, else online by id or by index with the project id, following v2's 307 after a move (an all-digit identifier not local, `.` and `..` fail without a request), and stores a task read online ("Opening the task…" shows while it reads). Then the dialogs and sheets close, another tab goes back to the Overview (a page over the shell stays), and the detail opens in the Overview's pane where it fits, else in a sheet ([D70](#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere)). A task in the trash says so, with Restore ([D79](#d79-the-trash-of-vikunja-280-undo-queued-deletes-a-trash-page)).

Limits:
- No App or Universal Links for web addresses: self-hosted domains cannot be verified.
- A web link to a comment opens its task, not the comment (`parseTaskIdFromUrl` ignores the fragment).

## D45: App shell, colour scheme, display settings, Projects tab, smart lists, offline banner

*Accepted 2026-10-19 (step 8).*

- **Shell:** on Android and the other non-Apple platforms a navigation rail from 600 dp wide, with the four labelled destinations (labels clamped at 1.3× text) and the tab bar's behaviour: re-selecting a tab pops to its root, an account switch resets the tabs, back goes to the first tab. The rail sits outside the shell's scaffold, so snackbars stay beside it. iOS keeps the tab bar at every width, the iPad included ([D69](#d69-large-screens-a-window-layout-helper-readable-widths-capped-dialogs-and-sheets)).
- **Colour scheme** from the active account's `color_schema` (`light`, `auto`, `dark`), set as the Theme row of the Account tab's Appearance section and saved to the server (owner, [D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab)); `auto`, no signed-in account and link-share guests follow the system. The start waits for the settings behind the launch screen, so the theme does not flash.
- **Dynamic colour** on Android 12 and later: the system palette, read at start and on every return to the front, becomes the light and dark schemes under the app's component themes. On by default; the device-wide "Use system colors" switch (in review) in the same Appearance section (shown only where a palette exists) brings back the brand scheme ([D56](#d56-design-after-the-owners-mockups-blue-scheme-cards-one-task-row)). iOS always uses the brand scheme.
- **The web's display settings apply only once set** (why: the web's defaults `relative` and `24h` would change the app for everyone who never opened them). Until `date_display` and `time_format` are set, the app uses relative dates in rows, the metadata line, comments and the inbox, the device's absolute format elsewhere, and the device's 12 or 24 hours. Once set, one `MomentFormatter` applies them:
  - an absolute `date_display` (six numeric patterns, two long forms) everywhere a date is shown, the new-task sheet and the quick-add preview included;
  - `relative` where the app is relative, with "just now" / "gerade eben" under a minute; the absolute places keep the device format;
  - screen-reader labels and tooltips use the long form with the weekday, as the web's tooltips do;
  - an explicit `time_format` applies to every time shown and to the time pickers, 12 hours in German included (a settings-aware `MaterialLocalizations` per picker; `use24hFormat` on iOS);
  - Upcoming's day headers and range, the Overview's groups and the "as of" and "last synced" notes keep their own formats.
- **Week start** 1–6 sets the first day of the Material date pickers; 0 keeps the locale's (why: the server cannot tell 0 from never set). Upcoming's presets stay on Monday weeks, like the server's date math.
- **Default view:** a project opens on the first view of the user's `default_view` kind, else its first view, every time; a view the user picks stays while the screen is open, and nothing is remembered (owner, [D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab)): nothing reads or writes `last_view:*`, and `forget` still deletes a deleted project's old row (`LocalListPreferences.lastViewKey`).
  - A view named in the route wins while the project has it: `AppRoutes.project(id, viewId:)` builds `/home/projects/<id>?view=<viewId>`, `ProjectTasksScreen` is keyed by id and view, and a guest's link lands on its view this way ([D62](#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind)).
- **Translated names** through one `projectDisplayTitle` (id −1, the exact titles `Inbox` and `My Open Tasks`) wherever a project title is shown, notifications included; the view switcher translates the four default view titles. Storage, quick-add matching and default-project detection keep the server's titles. Saved filters, and projects with equal positions, sort by title ignoring case and accents like the web's `localeCompare`.
- **Projects tab** in three sections: Favorites ("Favorite tasks" while an open favourite task outside archived projects exists, then favourite saved filters and favourite projects), Saved filters (by title) and All projects (the tree), the English names in US spelling since step 38a (in review). Every project shows as a folder in its colour (owner, [D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab)).
  - The menu's "Show saved filters" ([D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab)) and "Show archived projects", and the collapsed branches, are saved per account (`list_preferences` key `projects`).
  - Archived projects carry an archive icon and stay out of pickers, defaults and quick add. An archived project shows the web's note, no New task button, and rows without the done and star controls. Its tasks' detail offers only reading, Copy link and Share: no Done, Edit, in-place edits, subtask or relation changes, Duplicate or Delete, and the star is off ([D84](#d84-everyday-editing-in-the-task-detail-properties-in-place-task-links-move-to-column)).
  - On wide windows the tree also shows as a column beside the open project, saved filter or Favorite tasks ([D82](#d82-projects-listdetail-the-project-tree-beside-the-project-on-wide-windows), in review).
- **Smart lists** at negative ids:
  - "Favorite tasks" comes from the local database: open favourite tasks outside archived projects and their subprojects, ordered like the Overview.
  - A saved filter is evaluated on the device ([D51](#d51-filter-engine-on-the-device-saved-filters-filter-builder-offline-search)). Where the engine refuses it or its definition is unknown, the server's answer is downloaded with `filter_timezone` into the view snapshot `filter:<pseudo project id>` when the list opens and the snapshot is missing or older than five minutes, on pull and when the device comes back online.
  - The sync stores `is_favorite` with the saved filters and purges the `filter:` snapshots of gone filters on every run; a filter no longer listed shows as gone.
  - Rows show their project; done and star work as everywhere; New task opens without a project.
- **Offline banner** in the shell, not a notice per list (why: no connectivity plugin can tell whether the server is reachable; the last sync can): offline after a sync run of the active account fails with a network failure, online again after a run gets through, unchanged while one runs, so retries do not flicker. "Offline — showing saved data" with the last sync time, above the bottom bar or below the content beside the rail, across every pane; a tap syncs. Pages over the shell, such as the inbox, keep their own notice from the same state; a failed view or filter download alone shows the list's own state.

Limits:
- The account's `language` and `timezone` settings are not used for display; the device's are.

## D46: Realtime: one WebSocket for the active account in the foreground

*Accepted 2026-10-19 (step 17).*

- **One socket, for the active account, while the app is in front** (`realtimeConnectionProvider`): after the account's first sync, never while it needs a new sign-in or is being signed out, never in a background isolate, never for a link-share guest ([D62](#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind)), only on servers with the WebSocket capability (`/api/v2/ws`, `/api/v1/ws` since 2.3.0).
  - It opens on start and resume, closes normally on hide and pause, and moves with an account switch. It closes before the app's own logout request, so the server's "session revoked" that follows is ignored.
  - Inactive accounts keep their inbox poll; the background job is [D40](#d40-background-sync-of-every-account-server-notifications-in-an-inbox)'s. `HomeShell` keeps this provider and the other per-account services alive from `initState` (why: listening in `build` restarted them on every tab switch).
- **Transport** in `vikunja_api` on dart:io, without a new dependency: `IoRealtimeConnector` does the upgrade by hand so that a refused one reports its status and `Retry-After`, checks `Sec-WebSocket-Accept`, sends the app's User-Agent and no Origin, gives up after 15 s and pings every 25 s. `realtimeUri` uses the negotiated API version and keeps the sub-path and port. Nothing logs frames or tokens; states, statuses and close codes are logged at FINE.
  - The server address's connection settings apply to every upgrade (`ProfileRealtimeConnector`, [D65](#d65-connection-settings-per-server-address-applied-in-the-apps-transport)); where they do not reach, realtime falls back to polling.
- **Sequence:** upgrade, `auth` with the account's current token, `auth.success` within 10 s, `subscribe notification.created`, live. A catch-up of the inbox runs alongside (why: events while disconnected are lost).
- **Events:** the socket carries only `notification.created` (no task or project changes, no reads). A pushed notification is stored at once like a polled one, as handled, so the inbox and the bell badge update by themselves; a reminder is stored as the poll stores it, never shown and never counted.
  - Comments, assignments, mentions, created and deleted tasks and created projects request one incremental sync of the active account, debounced by 2 s and coalesced with a run in progress; team memberships and reminders request nothing.
  - The 60 s sync timer and the inbox poll stay.
- **Re-auth:** every 20 s the connection reads the account's token and re-authenticates when it changed; a token of another session (a new sign-in) reconnects instead, and a re-auth without `auth.success` within 10 s closes and reconnects (this also covers servers older than 2.7.0).
- **Failures fall back to polling, quietly** (why: the upgrade shares the server's per-IP limit of login and registration, 10 a minute):
  - `invalid_token` and "session revoked" go through the session manager's `refreshAfterRejection`; a newer token reconnects once, anything else stops the socket until the next resume, and a revoked session ends inside the manager's refresh as for HTTP.
  - Drops, "token expired", "auth timeout", 1013, 5xx, a cut-off TLS handshake and connection errors reconnect after 2 s doubling to 60 s with ±25 % jitter, reset after a minute live and on resume; six attempts in a row without `auth.success` stop until the next resume.
  - A 429 waits its `Retry-After`, at least 2 s (doubling with every 429 in a row), at most 5 minutes.
  - Any other refused upgrade (404, 426, 3xx and the like) or a TLS error before any socket of the account was live stops all attempts until the app starts again or the account changes; after a socket was live the same answers count as temporary.
  - While the shell says offline nothing is tried; when it turns online, at once.
- Nothing new on screen: the badge, the inbox and the lists update sooner; the offline banner stays bound to sync runs.

Limits:
- No sockets for inactive accounts or in the background, no time-tracking events, no switch to turn realtime off; the server's reminders are not shown.
- The socket runs on dart:io, which reads no system proxy and on Android ignores user-installed CAs: a server reachable only that way keeps working through polling (trusting its CA in the app fixes the second, [D65](#d65-connection-settings-per-server-address-applied-in-the-apps-transport)).

## D47: Kanban board from per-view snapshots, moves through the outbox

*Accepted 2026-10-19 (step 20).*

- **Kanban views on the project screen:** a project's kanban views are tabs beside its other views; `default_view = kanban` opens the board ([D45](#d45-app-shell-colour-scheme-display-settings-projects-tab-smart-lists-offline-banner)). The board replaces the list body and has no sort or "Show done" controls.
- **Layout:** columns as wide as the board less 80 dp, at most 280 dp, 12 dp apart, in a horizontal scroll that snaps to columns on a phone and shows several side by side where there is room, clear of the safe-area insets; the board takes the whole width ([D69](#d69-large-screens-a-window-layout-helper-readable-widths-capped-dialogs-and-sheets)) and fills the height below the notes. A column has its header (title, the done marker with the web's hint, `count/limit` in the error colour when full, else the count), its cards, "Load more" for a partly loaded bucket (also on reaching the end) and "Add a task".
- **Card** like the web's, without done control or star: the done badge, the priority from the minimum and only while open, the due date in the user's format (red when overdue and open), the checklist summary, the comment count with the unread dot, description and repeat icons, the not-yet-synced mark, the title with the task's colour, labels, progress and assignees. No task identifier (owner, [D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab)). One screen-reader node built like the row's; a tap opens the task, and the card of the task open in the pane is marked ([D70](#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere)).
- **Drag and drop:** a long press lifts the card; the column under the finger shows where it lands; the board and the column scroll near the edges, the board does not snap while a card is held and settles on the column that took it.
  - The position comes from the cards above and below as shown (the web's `calculateItemPosition`, except that an empty column gets 65536, because 0 makes the server recalculate the whole view), never below the last loaded card of a partly loaded column.
  - A full column refuses a card from elsewhere with a haptic and the web's limit text.
  - For screen readers every card offers "Move to <column>" for each other column (numbered when two share a title), "Move up" and "Move down", and the result is announced; a drop's announcement numbers the column the same way.
  - Without a drag, a card's task detail offers Move to column…, which puts the card on top of another column by the same rules ([D84](#d84-everyday-editing-in-the-task-detail-properties-in-place-task-links-move-to-column)).
  - Filter-mode boards, archived projects and projects without write permission ([D60](#d60-labels-teams-and-shares-online-the-stored-project-permission-shapes-every-screen)) are read-only.
- **Board snapshots:** `kanban_buckets` holds a view's buckets with title, limit, count, position and pages loaded; `list_snapshot_tasks` carries the bucket. A download replaces both in one transaction under `view:<id>`: one board request for the first page of every bucket, then the further pages a bucket had loaded, so what was scrolled to stays. The download's time is taken before its request.
  - The screen downloads when the board opens and the snapshot is missing or older than five minutes, on pull, when the device comes back online, and quietly 2 s after its own placements have left the outbox.
  - The sync never downloads boards (why: a request per view and run for data that matters only while the board is open); it purges the snapshots and buckets of views that no longer exist.
- **The board model** (`buildBoard`, `vikunja_logic`) joins the snapshot with the local tasks:
  - a queued placement wins;
  - a done task moves into the done bucket only when it was marked done after the download (its `doneAt`, else `updated`, is newer, or a done change is queued), and an open task leaves it for the default bucket (the leftmost when none is set) only when it changed after the download; tasks done before a done bucket was chosen stay where the server keeps them;
  - tasks created here, changed after the download or moved into the project show on top of the default bucket; tasks deleted or moved away are hidden;
  - the filters the device can evaluate apply ([D51](#d51-filter-engine-on-the-device-saved-filters-filter-builder-offline-search)); a filter-mode board shows its download as it is;
  - a sent placement updates the stored board at once, counts included.
- **Moves through the outbox:** `TaskChanges.kanban` maps a view to a bucket and a position, merged per view, folded behind an unsent create, kept as pending until sent (why: a field of the task update rides the outbox's queueing, failures and sync problems).
  - A later project move or a change that flips `done` drops the placements queued before it, so the server never gets a move for the wrong project or done state.
  - A drop into the done bucket queues `done: true` with the placement, one out of it `done: false`; a repeating task dropped into Done is only marked done and placed in the default bucket without a position.
  - The sender writes the body (with done) first, then per view the move and, when the answer's bucket is the target, the position (why: neither a move nor a position write bumps `updated`, and a move keeps the old position).
  - 10004 (bucket full), a missing bucket, 3008 (archived) and 403 become sync problems with their own wording; discarding one puts the card back.
- **Add a task per column:** the new-task sheet creates the tasks and places them on top of that column, as many as its limit leaves room for (the rest stay in the default column and the snackbar says so); in the done column they are created done. New tasks are placed by a queued placement, not `bucket_id` on the create (why: that applies to one view only and would change the create's recovery match, [D35](#d35-task-creates-through-the-outbox-under-temporary-negative-ids)).

Limits:
- Not built: collapsing columns, kanban views of saved filters, cover images, attachment icons on cards.
- In filter mode a task the server lists in two buckets shows once.
- Moving a card within its column takes a drag or a screen reader's actions; there is no single-pointer way ([D68](#d68-screen-readers-headings-one-announcer-high-contrast-reduce-motion-route-sweep)). To another column, Move to column… is one ([D84](#d84-everyday-editing-in-the-task-detail-properties-in-place-task-links-move-to-column)).

## D48: Kanban columns managed online from a column menu

*Accepted 2026-10-19 (step 21).*

- **Online, applied at once:** `BucketRepository` calls the server and queues nothing (why: the actions need server ids, change where queued moves land, and are rare). On success it writes the answer into the local board in one transaction (a new column with count 0; renamed, limited and moved columns keep their stored count; a deleted column's cards move to where the server puts them; the view's done and default ids go to `project_views` alone), then downloads the board quietly.
  - Offline or on a refusal nothing changes and a message says why: no connection, the change could not be confirmed, only project admins can choose the done or default column, a board needs at least one column, the column no longer exists, the project is archived, no permission; for a delete that needed a new default first, that its tasks have to go to another column first when the server refused the new default, and that the column to become the default no longer exists when it was deleted elsewhere. Every success is announced to screen readers.
- **Requests:** the bucket update always sends title, limit and position (why: the server's update replaces all three, and what is left out becomes 0); no body carries an `id` or `project_view_id`. Done and default bucket are set by a merge-patch of the view on v2, and on v1 by reading the view and writing it back whole with only the bucket ids changed, so kind, filter, title and position survive. A bucket already gone counts as deleted.
- **The column menu** behind an options button in each header ("Options for <column>"): Rename, Limit ("Not set" when none), Done column and Default column (checked when they are, with the web's hints; choosing a checked one clears it), Move left and Move right (where possible), Delete (disabled, saying why, for the last column, and below admin permission for one whose delete needs a new default first).
  - Rename, the limit and a new column use an input sheet; titles are trimmed and must not be empty (stricter than the server); a limit below the current count is allowed and shows red.
  - Delete asks first, naming the column, where its tasks go and, when needed, the column that becomes the default.
  - "Create a column" is a tile one column wide at the end of the board, so the column snapping stays even; a new column goes to the right.
  - The menu and the tile need write permission, Done column and Default column admin ([D60](#d60-labels-teams-and-shares-online-the-stored-project-permission-shapes-every-screen)); filter-mode boards and archived projects show none of it.
  - Below admin permission the Delete of the leftmost column while no other column is the default and it holds tasks is disabled, saying that its tasks have to go to another column first, as deleting it now would leave them in no column and only project admins can choose another default column: that delete needs a new default first (the guard below), which the server refuses below admin. The web offers a write member that Delete and the server accepts it, leaving the tasks in no column; the app keeps its guard and offers a write member less than the web does here ([D62](#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind)).
  - A link-share guest gets what a user of the share's permission gets, as the web offers it and the server accepts it ([D62](#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind)): a write guest deletes the done and the default column too, which the server clears in the view, and an admin guest also chooses them.
- **Reordering** by Move left and Move right, in the menu and as screen-reader actions, with the position from the new neighbours (also when they share a position or the first is at 0, where the web's formula lands on the wrong side; a move that cannot land is not offered). Columns are not dragged (why: on a phone that competes with dragging cards and with the snapping board).
- A board at the server's column limit (100 manual columns, 412 code 10007) says so in the app's words (`boardColumnsAtMaximum`).
- **Guard against orphaned tasks** (why: on the server, deleting the bucket tasks fall back to leaves its tasks in no bucket): before deleting, the app reads the view from the server; when the column is the fallback and holds tasks (when it looks empty, the board is downloaded first to be sure), the app first makes the leftmost remaining column the default, then deletes, and puts the old default back when the delete fails. When the first call is refused, nothing is deleted. Nor when the server no longer has the column that was to become the default (deleted elsewhere since the last download), which it then stores as no default: the app sends no delete, puts the old default back where the call cleared it, and downloads the board.

Limits:
- Not built: managing columns offline; collapsing columns is [D47](#d47-kanban-board-from-per-view-snapshots-moves-through-the-outbox)'s.
- Moves still queued into a deleted column fail as a sync problem.
- A user or guest with write but not admin permission finds the Delete enabled when only the server's board makes it one that needs a new default first: a default cleared elsewhere since the last sync, or tasks in the leftmost column that the device does not show yet. The server then refuses the new default, nothing is deleted, and the message says that its tasks have to go to another column first.

## D49: Manual ordering: lists through the outbox, projects online, no position below 0.1

*Accepted 2026-10-20 (step 22).*

- **Which lists can be reordered:** a list view sorted "Manually" that has been downloaded once, in a project that is not archived (itself or above) and that the user may write ([D60](#d60-labels-teams-and-shares-online-the-stored-project-permission-shapes-every-screen)), not a smart list; only the top-level rows of the open part, each with its nested subtasks as one block. The Done part, subtasks on their own and the leaving copies of just-completed tasks stay put.
- **List drag** as on the board: a long press lifts the row (its controls' tooltips are off while it can be lifted), a line shows where it lands, the list scrolls near its ends; the position comes from the rows above and below as shown.
  - Tasks without a downloaded position get made-up positions, and a move among them also writes theirs, so the list keeps the order shown and the server gets that order.
  - Screen readers get "Move up" and "Move down" on the row, offered only where the order changes, and announced.
- **Positions through the outbox:** `TaskChanges.positions` maps a view to a position, merged per view, dropped by a later project move, kept by a done change, folded behind an unsent create, overlaid on the manual order until sent (why: positions do not bump `updated`, and a field of its own avoids the kanban placement's column and done rules).
  - The sender writes them after the body and the column moves, one request per view; the stored list takes the sent position; the screen downloads the view quietly 2 s after its own positions have left the outbox.
  - A refusal reads "This list can't be reordered" or "The list no longer exists"; discarding it puts the row back.
- **Projects** are reordered and nested in "All projects" (Favorites and Saved filters stay as they are), online: `moveProject` sends a v2 merge-patch with position and parent, or on v1 reads the project and writes it back whole with only those changed; the answer is written locally and a quiet sync follows.
  - A long press lifts a project with its subtree; a drop between rows makes it a sibling at the level the line's indent shows; a drop onto a row makes it that project's last child (a collapsed one opens). It shows in its new place, faded, until the server answers.
  - Refused without a request: onto itself or its subtree, into or out of an archived project, and any place whose position would fall below 0.1 (why: below 0.1 the server renumbers every sibling, for top-level projects those of every user on the instance; the port refuses it too).
  - Screen readers get "Move up", "Move down", "Move out of <parent>" and "Move into <project>".
  - A shared project whose parent the user cannot see keeps that parent when reordered.
  - Failures have their own words: only admins may move a project under another one, no permission, archived, not possible there, the project is gone, needs a connection, could not be confirmed.

Limits:
- Not built: ordering favourites and saved filters, dragging in smart lists; Table and Gantt views have no manual order.
- Reordering projects is not gated by the stored permission ([D60](#d60-labels-teams-and-shares-online-the-stored-project-permission-shapes-every-screen)); a refusal shows as a message.
- Moving a task or project takes a drag or a screen reader's actions; there is no single-pointer way ([D68](#d68-screen-readers-headings-one-announcer-high-contrast-reduce-motion-route-sweep)).

## D50: Projects and views managed online, applied locally at once

*Accepted 2026-10-20 (step 23).*

- **Online, applied at once:** every action calls the server; on success the local database changes at once (a new project with its views, only the changed fields, the archive flag down the subtree, a deleted subtree purged with its tasks, their queued changes, list snapshots, columns and list preferences), and a sync follows that never joins one already running (`refreshAfterWrite`), so a run in flight cannot undo the write. Offline and on a refusal a message shows and nothing changes locally. (why: temporary project ids would have to flow into tasks, views, columns and the outbox; deletes and duplicates need the server's answer.)
- **Entry points:** "New project" in the Projects tab's app bar and its empty state. The project screen's menu, in groups, with what the stored permission allows ([D60](#d60-labels-teams-and-shares-online-the-stored-project-permission-shapes-every-screen)) and nothing for link-share guests: Edit, Views, Share, Add to or Remove from favorites, Follow; New subproject, Duplicate; Archive (disabled for the user's default project, with the reason), Delete (hidden for it). An archived project offers Unarchive and Follow; Unarchive under an archived parent is disabled with the reason.
- **Forms:**
  - new project: title, parent, colour; then the project opens;
  - edit page: title, identifier (at most 10 characters, "Used in task links such as PROJ-12"), colour, parent outside the project's own subtree, and the description through the editor page ([D52](#d52-descriptions-edited-in-a-locked-down-tiptap-webview-never-silently-overwritten));
  - duplicate: parent (only projects the user may write) and "Also copy its shares", on as on the web; the copy opens after a sync brought its tasks;
  - titles are trimmed and required; limits count code points as the server does;
  - the colour rows are [D81](#d81-vikunja-280-details-legal-links-okabeito-colours-lockout-hints-subtask-tree-accents)'s.
- **Confirmations:** archive and unarchive with the web's meaning, also naming the user's default project when it is inside. Delete counts every task it would delete, in subprojects too (why: the web's count of direct children understates a recursive delete), and says it is for everyone.
  - On servers with the trash the delete moves the project there, with its own confirmation and Undo ([D79](#d79-the-trash-of-vikunja-280-undo-queued-deletes-a-trash-page)).
- **Views page:** the project's views in order with their translated title and kind; create, edit, Move up and Move down, delete (never the last view, so the project always has something to show). The form: title, kind, "Show done tasks" for lists (mapped to the web's `done = false`), the filter in the web's syntax with the filter builder ([D51](#d51-filter-engine-on-the-device-saved-filters-filter-builder-offline-search)) and the server's error shown and announced, and for boards whether the columns are their own or come from filters. A move sends only the position, so a view changed on the web meanwhile is not overwritten.
- **Local consequences the server leaves out:** an identifier change rewrites the stored task identifiers (why: the server changes them without bumping the tasks' `updated`); an unarchived subtree and a copy whose sync failed are pulled whole on the next run; a stored project below position 0.1 is lifted to at least 0.1 in the same update, so the server does not renumber its siblings.
- **Failure wording** for no connection, could not be confirmed, no permission, admin only, archived, archived parent, default project, identifier taken, invalid filter and not found.

Limits:
- Not built: backgrounds, webhooks, setting up filter-mode columns (left to the web), managing projects offline.
- Over v1 only, a view with more than 50 filter buckets from before 2.7.1 is refused when the app edits it.

## D51: Filter engine on the device, saved filters, filter builder, offline search

*Accepted 2026-10-20 (step 24).*

- **One engine in `vikunja_logic`:** `parseTaskFilter` and `matchesFilter` implement the server's grammar and semantics exactly (the server's fexpr reader translated, BSD 3-Clause; the date math after go-datemath, ISC; notices in `packages/vikunja_logic/THIRD_PARTY_NOTICES.md`). Two deliberate differences:
  - a date equal to a bound matches as written (on SQLite the server is off by one there);
  - filters the server answers with a 500 (`position`, range comparisons on people, business-day rounding) are refused with 4019.
- Business-day offsets above 10000 in all are refused with 4019 on every server version ([D78](#d78-vikunja-280-trash-codes-as-gone-its-limits-no-nul-info-re-read)).
- **Timezone:** a saved filter's own, else the user's timezone setting, else the device's zone, through `package:timezone`.
- **Where it applies:** list views with any filter (the view's snapshot only orders a manual list), boards, saved filters, the Overview's saved filter and the widgets, each with the server's scope (a project view covers its project, archived tasks included; all tasks and saved filters cover the projects that are not archived plus the user's favourite tasks).
  - Filters that use `now` are evaluated again every minute and on resume, so "due today" turns over at midnight.
  - A filter the engine refuses, one naming `bucket_id`, or a saved filter whose definition is unknown keeps the downloaded list, with its notice; saved filters the device evaluates are not downloaded.
- **Definitions in the sync:** the project phase keeps each saved filter's `updated` and reads the definition (`GET /filters/{id}`) of new or changed ones only; a failed read keeps the previous definition.
- **Saved filter management** online, applied at once: "New saved filter" ends the Saved filters section and is in the Projects menu (only there while "Show saved filters" is off, [D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab)); a saved filter's screen offers Edit, Add to or Remove from favorites, and Delete. The form: title, description (plain text; the web's HTML is shown as text and kept when untouched), the filter, "Include tasks which don't have a value set" (the web's wording) and favourite; new filters start with the web's defaults.
- **The filter builder** (saved filters and the views form): a text field in the web's syntax (why: it keeps every filter the web can write), operators in bold and values underlined (no backgrounds, so selection and caret stay visible).
  - Suggestions under the text for fields, operators, labels, projects, people and named date shortcuts, kept in view above the keyboard. Value suggestions (labels and projects by title, people by username or name) ignore case and accents on every server (owner, [D81](#d81-vikunja-280-details-legal-links-okabeito-colours-lockout-hints-subtask-tree-accents)); a tap inserts the exact title or username, and a value is not offered again once the typed text equals what a tap inserts, ignoring case only, so `cafe` still offers `Café`, which `labels in cafe` would not find.
  - Label and project titles are sent as ids; ids without a local title are kept.
  - The engine's error appears after a short pause or on leaving the field and blocks saving.
  - A live count of matching tasks on the device, read out when it changes.
- **Global search:** the search pill at the top of the Overview ([D56](#d56-design-after-the-owners-mockups-blue-scheme-cards-one-task-row)) and a search action in the Upcoming and Projects app bars open one field with results grouped as tasks, projects, saved filters and labels, open tasks first.
  - Tasks match a substring of title or description, ignoring case (full Unicode folding) and accents, in the query and in every text compared (owner); `#12` and `PROJ-12` (an app addition) find a task by its index or identifier, though the start text does not name them.
  - Offline and instant from an index kept up to date as tasks change; a label opens its open tasks with the saved filters' scope; the last query comes back when Search opens again.
  - Every other search field that filters on the device ignores accents too ([D81](#d81-vikunja-280-details-legal-links-okabeito-colours-lockout-hints-subtask-tree-accents)).

Limits:
- Not built: the server's ParadeDB full-text search, `uid` filters, a chip-based builder, searching comments and attachments, teams in search.

## D52: Descriptions edited in a locked-down TipTap WebView, never silently overwritten

*Accepted 2026-10-20 (step 25).*

- **Our own bundle, the web's output:** `app/editor/` builds one self-contained page, `app/assets/editor/editor.html`, from the TipTap and ProseMirror npm packages at the web's versions, with our own configuration of the web's extensions written from its behaviour (why: the web frontend's code is AGPL and its popups and highlighting do not affect the stored HTML).
  - Left out: code highlighting (and with it highlight.js), slash commands, Markdown paste, image paste and drop, floating popups.
  - All 123 recorded web outputs come out of the editor byte for byte (Node with jsdom). `tool/build_editor.sh --check` rebuilds the page and fails on any difference; CI runs it. Everything bundled is MIT, listed in `app/assets/editor/NOTICES.md`. Node is needed only to rebuild the page.
- **Locked down:** the page loads from the app's assets; a content security policy allows only its own hashed script and inline styles and no network at all (images show as labelled placeholders and are never loaded, so no token reaches the page); every navigation is refused; messages carry a per-load token both ways; file access and debugging are off. The bridge exchanges `init`, commands, `state`, mention queries and the HTML; a page that was not changed is never written back.
- **The editor page:** full screen over the task or project, opened from an Edit button by the description in the detail sheet ("Add description" when empty) and from a Description row on the task and project edit pages; not for archived or read-only projects.
  - A native toolbar above the keyboard (bold, italic, underline, strikethrough, code, heading levels, bullet, numbered and check lists, quote, code block, link, table menu, divider, image, undo, redo, clear formatting) shows the active formatting; links are set in a native sheet; `@` opens a native list of the project's people (the locally known ones offline). The image button is described in [D53](#d53-attachments-uploaded-through-the-outbox-opened-through-the-platform-android-share-target).
  - Save is explicit (why: it fits the app's edit pages and avoids writes while typing offline); leaving with changes asks. The page follows the app's theme, text size and language.
  - An unsaved edit is kept as a draft (`description_editor.draft`) when the app goes to the background and offered again next time. Sign-out and account removal discard that account's draft (`DescriptionDrafts.discardAll`; another account's stays), and an editor still open after its account signed out keeps none. When the description changed underneath while editing, Save asks: Overwrite, Reload or Keep editing.
  - Comments ([D57](#d57-comments-online-with-a-kept-draft-reactions-comment-counts-and-unread-dot)) and label and team descriptions ([D60](#d60-labels-teams-and-shares-online-the-stored-project-permission-shapes-every-screen)) use the same page.
- **Checklists ticked in place:** a tap on a checkbox in the detail sheet replaces only that item's `data-checked` value (and the input's `checked` in TipTap's exact shape) in the HTML the view was built from, queued through the outbox, so it works offline, with a haptic and an announcement; a tap on a view that is no longer current is refused.
- **No silent overwrite** (why: a tick on the phone must not erase a paragraph written on the web): a queued description change remembers the description it started from and, for ticks, which items it ticked (by `data-task-id`, else position and text). When it is sent, the app compares that with the server's current description (v1 from the read it makes anyway, v2 with one read):
  - unchanged: sent as queued;
  - changed, and only ticks queued: the ticks are applied again to the server's description;
  - changed after an edit: a sync problem "The description was changed on the web too" with Compare versions, Keep my version and Use the web version.
  - Project descriptions are saved online with the same check and the same question.

Limits:
- On v2 a web change landing between the check read and the write is still overwritten; the server offers no preconditions.
- Checklists in comments cannot be ticked.
- Not built: image paste and drop, Markdown paste, slash commands, code highlighting, collaborative editing.

## D53: Attachments uploaded through the outbox, opened through the platform; Android share target

*Accepted 2026-10-20 (step 26).*

- **Uploads through the outbox, in their own lane:** "Add" in a task's Attachments section picks files (an own Android picker that copies off the main thread with a cap; `file_selector` on iOS), photos or the camera (`image_picker`).
  - Each file is checked against the smaller of the server's `max_file_size` and the app's ceiling of 50 MiB, moved into the account's uploads folder under a random name and queued as one `uploadAttachment` operation, offline too.
  - A second sender loop sends uploads beside the main queue (why: a large file would hold every edit back for minutes); one file per request (why: per-file errors carry no name and the body limit counts all files), with timeouts from one to four minutes by size; behind an unsent create it follows the new id.
  - An answer that got lost is recognised by name, size and uploader within an hour. Three timeouts in a row, a file too large, a task gone or archived become sync problems (Discard deletes the stored copy; a lost copy offers only Discard). Background runs leave uploads alone.
  - Pending uploads show as rows with Cancel.
- **Photo and video locations are removed** before they are queued (owner): every photo and video from the photo picker and the camera (attachments, the description editor's image button, the avatar) on iOS and Android, and on Android also every copy of a file shared to the app ([D74](#d74-ios-phase-app-store-prerequisites-testflight-from-the-mac-photo-locations-capture-cover), [D76](#d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android)). A file picked as a file is uploaded unchanged; a file whose location cannot be removed is still uploaded.
- **Per attachment:** Open (images in the viewer; other files downloaded into the cache and handed to another app through a FileProvider), Share, Save to device (the system's "save as"), Make cover or Remove cover, Delete with the web's confirmation.
  - Cover and delete are online and refresh the details; deleting the cover clears it first. An update answered with 4020 (a dangling cover) is sent again once with the cover cleared.
  - Downloads stream to disk with the Bearer header for the account's own server only, resume, can be cancelled, are named from the sanitised `file.name` and are purged per account and after three days.
  - Previews go over v1's `preview_size` wherever the server offers v1; a v2-only connection uses v2's preview route from 2.7.1 on. A file without a preview (422 code 4038) keeps its icon; an image in a description or comment falls back to the original ([D77](#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)).
- **Images in descriptions:** the editor's image button (online, not for archived projects) uploads the picked or photographed image at once and inserts it in the web's form (`<img data-src=… src="#" id="tiptap-image-{t}-{a}">`); the editor shows a labelled placeholder ([D52](#d52-descriptions-edited-in-a-locked-down-tiptap-webview-never-silently-overwritten)).
- **Share to Vikunja on Android** (the name since step 38a, in review): an own pass-through activity (why: the share plugins use names the sending app chooses and read `file://` paths) accepts text and files from other apps and forwards them to the app's one activity, which takes a share once (never again from Recents or after a restore).
  - Only another app's `content://` files are read (no `file://`, not the app's own), copied off the main thread under random names with the size cap; a share without permission for a file falls back to the files it may read, else to the text.
  - The app waits for its start and first sync, asks for the account when there are several, then offers New task (title from the subject or first line, the rest as description with links, project, files) or Add to task (local search; files queued, text appended to the description). A shared share link offers "Open as guest" first ([D62](#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind)). It all works offline through the outbox.
  - iOS has no share extension before 1.0 ([D74](#d74-ios-phase-app-store-prerequisites-testflight-from-the-mac-photo-locations-capture-cover)).
- **Picks survive an activity relaunch:** a pick or "save as" open while Android relaunches the activity (system colours, contrast, wallpaper) keeps its result; the camera and the photo picker read image_picker's lost-data cache once the app is back (every 500 ms, up to 15 s).
- **Gating:** no uploads, deletes or covers in archived or read-only projects ([D60](#d60-labels-teams-and-shares-online-the-stored-project-permission-shapes-every-screen)) or when the server has attachments off; downloads always.

Limits:
- Attachment lists are not stored offline (why: an upload does not bump the task's `updated`); the details read online stays the source.
- Files up to 50 MiB are held in memory while they upload (the native HTTP adapter buffers bodies), so there is no real progress bar.
- Not built: attachments on comments, HEIC conversion, recovering a photo when Android kills the app while the camera is open.
- image_picker_android drops a lost result that holds only an error, so a photo-picker pick failing after a relaunch ends like a cancel after 15 s; a pick whose copy takes longer than 15 s also counts as a cancel, its copies stay in image_picker's cache, and a pick started meanwhile may receive them; a process that dies during a pick loses it.

## D54: Account settings in the app; password and email on the web

*Accepted 2026-10-21 (step 30).*

- **The Account tab** opens with a profile header (own avatar, name, @username, server) and an "Account settings" row; the order of its sections is [D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab)'s.
- **The Account settings page**, in the web's order: Profile (name, avatar); Password and email; Defaults (default project, default view, Quick Add Magic mode, minimum priority, the Overview's saved filter, first day of the week); Time and language (timezone with the zones matching the device's offset suggested, the server language with a note that it is for emails and the web while the app follows the device's language, date and time formats with a live example); Email notifications (reminders, the daily overdue summary and its time); Privacy (findable by name or email). The colour scheme is the Theme row of the tab's Appearance section ([D45](#d45-app-shell-colour-scheme-display-settings-projects-tab-smart-lists-offline-banner)), saved through the same code (`saveAccountSettings`). The security and integration sections are in [D55](#d55-security-settings-two-factor-status-sessions-and-tokens-a-new-token-shown-once).
  - Changes save at once, online, one at a time; offline the page is read-only; refusals show at their field.
- **Writes that never wipe** (why: v1 `POST` and v2 `PUT` replace everything, and an omitted `frontend_settings` wipes every web setting):
  - on 2.7.0 and later a v2 merge-patch carries only the changed fields (web keys inside `frontend_settings`);
  - older servers get a full write built from a fresh read of the raw settings, keeping every key the app does not know, never from the local store, which keeps only what the app uses;
  - after each write the app reads `GET /user` again, stores settings and profile at once and syncs quietly. The name reaches the account registry, so the header, the switcher and avatars with initials change at once (also when another isolate's sync saw it first).
- **Avatar page:** Default, Initials, Gravatar, Marble and "Your photo" (picked or taken, uploaded, which also selects it); the caches are evicted and every avatar of the account fetched again; a note says that the app draws initials where the server sends an SVG. The own avatar shows in the Account tab and the account switcher.
- **Password and email through the web** (why: the app never handles passwords, [D14](#d14-browser-sign-in-only)): for local users the two rows open the web's own pages in the browser; OIDC and LDAP users see that their provider manages them, and the rows stay hidden until the profile is known. A pending email change is shown.
  - Returning from the password page, the app checks its session at once; a changed password has ended it, and "Sign in again" takes over with queued changes kept.
  - On Vikunja 2.8.0 and later a note under the two rows carries [D81](#d81-vikunja-280-details-legal-links-okabeito-colours-lockout-hints-subtask-tree-accents)'s lockout hint.

Limits:
- The web's frontend keys the app has no use for are kept but not shown; `default_due_time` among them is not applied ([D35](#d35-task-creates-through-the-outbox-under-temporary-negative-ids)).
- The account's language setting changes only the server's emails and the web, never the app's language ([D71](#d71-english-and-german-us-base-glossary-error-texts-live-language-changes)).

## D55: Security settings: two-factor status, sessions and tokens; a new token shown once

*Accepted 2026-10-21 (step 31).*

- **Everything that needs a password or code goes to the web's own page** in the browser (why: the app never handles passwords or TOTP codes, [D14](#d14-browser-sign-in-only)): two-factor setup and turning it off, export request and download, deletion request and cancel. Everything else is native. The app shows no password or code field, no QR code and never the two-factor secret.
- **Account settings sections** (after those of [D54](#d54-account-settings-in-the-app-password-and-email-on-the-web)):
  - Security: the two-factor status On, Off or "Setup not finished", only where the server offers it and for local users, opening the web with a note: while off, that turning it on signs out everywhere, this app included; while on, that turning it off needs the password and newer servers also ask for a code. Sessions with their count.
  - Integrations: API tokens with their count; CalDAV where the server offers it.
  - Your data: the export with its status.
  - Delete account, last, on every server, because Apple (Guideline 5.1.1(v)) and Play ask an app through which accounts are created to offer their deletion ([D76](#d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android)): a dialog with the consequences, the mail confirmation and the three days, then the web. Where the server does not allow it (`allowsAccountDeletion`, `Capability.userDeletion`), the row reads "Not allowed by this server" („Von diesem Server nicht erlaubt“) with an info icon, and a tap only opens a dialog (`explainAccountDeletionNotAllowed`): "Ask whoever runs the server" („Frage die Person, die den Server betreut“; the glossary's term, not "administrator"), "This server does not allow deleting accounts in the app. Whoever runs it can delete your account for you.", OK.
  - A scheduled deletion shows at the top of the page and below the Account tab's profile header with "Cancel deletion"; then the Delete account row opens the web without a dialog. For a local account, on every server, the note says that the web asks for the password.
  - On Vikunja 2.8.0 and later the deletion dialog, the scheduled deletion's note, the data export page and both two-factor notes carry [D81](#d81-vikunja-280-details-legal-links-okabeito-colours-lockout-hints-subtask-tree-accents)'s lockout hint.
- **Sessions page:** a device line read from the User-Agent (this app's `Vikunja-App/…` as "Vikunja app" with version and system, in review; browser and system; else the raw text, so the old app's "Vikunja Mobile App" and the earlier `Rurana/…` show as stored), IP, last active, and "This device" on the app's own session, which cannot be ended there. Ending one or all other sessions asks first; ending all goes one by one (the server has no "end all others" call), stops at the first failure and says how many ended.
- **API tokens page:** the list with expiry (expired ones in the error colour) and a detail sheet with the permissions and Delete; a token already gone (404 code 14017) counts as deleted. The form: a title, an expiry of 30, 60 or 90 days or a picked day (valid through its end, in the device's zone; a past day is refused; no "never expires"), and the permissions from `/routes` with the web's four presets, each replacing the selection with what the server offers of its groups and permissions, and a mixed-state checkbox per group (groups start collapsed).
  - Task management takes `projects.views_buckets_tasks_update` where `/routes` offers it, else its name before 2.7.1, `views_buckets_tasks`.
  - On 2.8.0 Task management and Project management include the trash's permissions with their whole `tasks` or `projects` group (Delete forever, Empty trash and the project count among them), Full access everything and Read only none of them, as on the web (owner, [D81](#d81-vikunja-280-details-legal-links-okabeito-colours-lockout-hints-subtask-tree-accents)).
- **CalDAV page:** the address from the server root (not the web address) and the username, both with Copy; the password text matching the account (local without two-factor, with two-factor, or a sign-in provider); the token list with a delete confirmation. On 2.8.0 and later the page recommends a CalDAV token rather than the account password, and the delete confirmation says to remove the token from the calendar apps first (why: every try with a wrong password or deleted token counts towards the lockout; the texts are [D81](#d81-vikunja-280-details-legal-links-okabeito-colours-lockout-hints-subtask-tree-accents)'s).
- **A new token is shown once:** only in the state of the page that created it (never in a provider that outlives it, the database, the registry, logs or a route), in a selectable monospace text with Copy through the sensitive clipboard ([D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links)), and one question when leaving without copying.
  - While it shows, Android blocks screenshots (`FLAG_SECURE` through a `SecureHold`, [D64](#d64-app-lock-over-the-ui-and-device-privacy-settings)); iOS hides it while the screen is recorded or mirrored (owner, [D74](#d74-ios-phase-app-store-prerequisites-testflight-from-the-mac-photo-locations-capture-cover)).
  - Log redaction also covers a `secret` key and `otpauth` links.
- **Two-factor status over http** is not read from servers before 2.7 (why: the answer carries the secret); the row says so and still opens the web.
- **Returning from the web's two-factor page** runs the session check at once, so a session ended by turning it on asks to sign in again right away. A deleted account (`GET /user` 404 code 1005) ends the session the same way.
- **Waiting for a page the app opened** uses the pushed route's own pop (`pushPage`) (why: go_router's push futures never complete once it decodes its route list again, [D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links)); this covers these pages and the description editor's callers.
- Every page here is online only; offline it shows its offline state.

Limits:
- Not built: bot users' tokens, the web's prefilled token links, webhooks, feeds and migration.
- Without mail on the server the deletion's confirmation never arrives, which the app cannot detect.

## D56: Design after the owner's mockups: blue scheme, cards, one task row

*Accepted 2026-10-21 (outside the roadmap's steps; the owner's mockups).*

- The app looks like the owner's mockups of eight screens without copying them blindly, and stays a typical Flutter app with material_ui and cupertino_ui ([D2](#d2-material_ui-and-cupertino_ui-instead-of-the-sdks-libraries)).
- **Colour:** the brand scheme (used when the system palette is off or missing, and on iOS) is a tonal scheme with primary roles from the Vikunja blue `#1973FF`, cool grey-blue surfaces and an amber tertiary for highlights (favourite stars, high priority). Dynamic colour ([D45](#d45-app-shell-colour-scheme-display-settings-projects-tab-smart-lists-offline-banner)) stays on by default and replaces the whole scheme; every component reads scheme roles. High-contrast variants follow the platform ([D68](#d68-screen-readers-headings-one-announcer-high-contrast-reduce-motion-route-sweep)).
- **Surfaces and structure:** grouped content sits in 12 dp cards (`surfaceContainerLow`) with inset dividers; section headers are primary-coloured with an optional count; settings lists have a 24 dp outlined leading icon on every tile and a divider between sections; switches show a check in the thumb (Material only); short exclusive choices are segmented buttons.
- **One task row for every list** (Overview, Upcoming, project lists, the Table view, smart lists, search, labels): a square checkbox, the title (after the task's colour dot), one wrapping meta line (priority flag; due date in the overdue, today or later tone, with a calendar icon, or an error icon when overdue; the project after a folder in its colour, muted without one; label pills in the server's colours; checklist count; comment count with the unread dot; description and repeat icons; the not-yet-synced mark), the percent-done bar, an avatar stack and the favourite star. No task identifier (owner, [D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab)).
- **Shared widgets:** every list and settings page uses `SectionCard`, `TaskRow`, `PriorityFlag`, `DueBadge`, `LabelPill`, `AvatarStack`, `CountBadge`, `SearchPill`, `SettingsSection`, `ProjectIcon`; new screens use them.
- **Screens:**
  - the Overview starts with a search pill and a greeting (date, "Good morning, …", the tasks left for today, the bell);
  - Upcoming has the range presets in its app bar, a day strip to pick one day and a timeline of days;
  - a project shows its done/total progress, its views as tabs, "Show done" and the sort as chips, and a grouped overflow menu;
  - Kanban columns are cards with a count badge (red over the limit) and elevated cards;
  - the task detail has the project chip in its header, a large title, a "Mark as done" button and the properties in an attribute card; it is a sheet, and a pane beside the list on wide windows (owner, [D70](#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere));
  - the new-task sheet has a headline, a project field, the due date and priority as two rows of chips, and expands for more options ([D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab));
  - the Account tab has one Appearance section and ends with "Sign out" and the version.
- **Not copied from the mockups:** a Teams tab (Account stays the fourth tab), an inline Quick Add field and a project grid on the Overview (the button and the composer stay the way to add), a checkbox on Kanban cards (the done bucket keeps its rules), the task detail as a full page, the task identifier (row, card, header), a project's colour dot (every project has a folder in its colour), and the new-task sheet's row of reminder, repeat and attachment buttons (reminders and repeat are under More options) (owner for the last three). Kept although the mockups have none: the favourite star on rows.
- The labels of Android's navigation bar scale text up to 1.15×, so that the bold selected label fits in German at 200 % text (a deviation listed in [D68](#d68-screen-readers-headings-one-announcer-high-contrast-reduce-motion-route-sweep)).
- `tool/seed_demo_data.py` fills an emptied test server with the demo projects and tasks.

## D57: Comments online with a kept draft; reactions; comment counts and unread dot

*Accepted 2026-10-21 (step 27).*

- **Online writes, a draft kept offline:** comments and reactions are written online and applied to the open sheet at once, then a quiet refresh (why: the thread can only be read online, and a kept draft loses nothing). The composer's text, its mentions and the reply it quotes are kept per account and task on the device (the 50 newest per account, deleted on sign-out); offline the Send button is off with a note. A draft moves with its task between pane and sheet ([D70](#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere)).
- **A composer pinned under the task sheet** with @-mention suggestions from the project's people (for link-share guests only people already on the device, as the server refuses them a user search), sending the web's HTML byte for byte: escaped paragraphs, mention nodes, and the reply quote rebuilt from what the editor schema keeps, so a quoted comment's hostile markup is not re-posted. The comments section is always there where the server offers comments ("No comments yet"); read-only and archived tasks get no composer.
- **Each comment:** avatar, name, time, "edited", its reactions and a menu with Reply, Copy link (the web's `…/tasks/{id}#comment-{id}`: the task's own link of [D84](#d84-everyday-editing-in-the-task-detail-properties-in-place-task-links-move-to-column), with the comment added) and, for one's own comments, Edit (the full editor page with mentions, [D52](#d52-descriptions-edited-in-a-locked-down-tiptap-webview-never-silently-overwritten)) and Delete (asked first; the paging adjusts so "Load more" skips nothing). The comment editor's route keeps the comment it was pushed with (why: go_router drops a non-JSON `extra` when it decodes its route list again, [D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links)).
- **Reactions** on the task and on each comment: chips toggle one's own reaction, a long press says who reacted, "Add reaction" offers eight quick emoji and a field for any other. Read-only users see the chips disabled; link-share guests get no reactions ([D62](#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind)). Reactions are not synced (why: they never bump `updated`).
- **Counts and unread on rows:** `tasks` stores `comment_count` and `is_unread`, which every stored task read expands; rows and board cards show the count, in primary with a dot when unread. Opening a task marks it read and clears the dot at once.
- **Live and linked:** an open sheet reads its details and loaded comments again when the task changes on the server; notifications and inbox entries about a comment open the task at that comment.

Limits:
- A task read on the web or on another device keeps its unread dot here until the task changes or the daily full resync.
- The drafts live in the preferences, which stay in iOS backups ([D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links)).
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
  - Rich text shows what was parsed until there, then a paragraph `…`, and `RichDocument.truncated` is set; checklist items before the cut tick as before.
  - A reply quotes such a comment up to the cut, then `…`, and its preview ends with ` …`.
- Below the budgets the result is package:html's own. The converter still flattens what is nested deeper than 96 elements to its text.
- A numeric character reference past 64 bits reads as U+FFFD, as package:html reads one past U+10FFFF (why: package:html throws on it, so 26 bytes would break the task sheet).
- Linear passes: the converter removes blank text nodes, moves lists nested in a list and joins adjacent text each in one pass; the composer trims the end of a web address in one pass.
- The outbox's checklist rebase parses the description once for all queued taps and applies them from the last item to the first; when an item's change could reach the next item (only malformed HTML allows it), it parses again after each tap.

Limits:
- A document past a budget shows only its beginning in the app; the rest stays on the server and in the web, and its checklist items cannot be ticked in the app.
- An update of package:html can break the subclasses at compile time; the tests pin its output below the budgets.

## D60: Labels, teams and shares online; the stored project permission shapes every screen

*Accepted 2026-10-26 (step 28).*

- **Organize** (in review) on the Account tab, after Account settings and before Accounts, opens Labels and Teams (owner), and on servers with the trash the Trash ([D79](#d79-the-trash-of-vikunja-280-undo-queued-deletes-a-trash-page)). Not for link-share guests ([D62](#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind)).
- **Labels, managed online and applied locally:**
  - A change or delete goes to the server at once and the answer is stored right away: a change replaces the stored label; a delete removes the row (which takes the label off every task through the foreign key) and forgets its queued adds in the outbox, in one transaction. A quiet `refreshAfterWrite` follows. A failure changes nothing, except an update answered "gone" (8002), which removes the label here too.
  - v2 sends a merge-patch of the changed fields only (a 304 is read back); v1 reads the label and posts it back whole with the change on top, so another client's colour or description survives. Colours go without `#`; an empty one clears the colour.
  - Only the creator's labels (`created_by` is the user) offer Edit and Delete, because lists carry no permission; a label made by the user's bot is not recognised, and the server's refusal is worded instead.
  - A search the server would read as ids (a number, or numbers with commas) pages the whole label list and matches title and description on the device, so quick add and the lost-answer lookup find an existing "2026" instead of creating a second one.
  - Labels page: "Your labels" and "From others" (labels on shared tasks), a search field above 12 labels (ignoring case and accents, owner), "New label" (off while offline), pull to refresh as a sync. A tap on a label, here or on the task sheet, shows its open tasks.
  - The form: a title of up to 250 code points; [D81](#d81-vikunja-280-details-legal-links-okabeito-colours-lockout-hints-subtask-tree-accents)'s colour row and a custom hex value, a new label taking one of its colours at random; the description in the editor page ([D52](#d52-descriptions-edited-in-a-locked-down-tiptap-webview-never-silently-overwritten)), saved online with nothing compared. Delete asks first and says that the label leaves every task.
  - Creating labels stays online only (owner). A label typed in quick add that could not be created stays in the task's title, as typed ([D38](#d38-quick-add-the-webs-grammar-with-fixes-through-the-outbox)).
- **Teams, online only and never stored** (why: membership changes bump neither `updated` nor the ETag): read on open and on pull to refresh; a page counts as offline only when its own last request found no connection, before that the sync's state decides; every change reads the team again.
  - Teams page: the member count and the badges Admin, Public (where the server has public teams) and "Managed by {provider}" or "Managed externally". New team: a name and, where enabled, "Public team"; then its page.
  - Team page: the description; for admins of a team that is not external, Edit (the name and the public switch, which always sends the stored value back) and "Edit description" through the editor page; the members with "You", Admin or Member; for admins a row menu with Make admin or Make member and Remove, never on one's own row; "Add member" through the people search (300 ms debounce, the latest query wins, a hint that the exact username always works).
  - Guards the server lacks (`TeamGuards`): nobody demotes or removes themselves from their row; the only admin with other members is asked to make someone else admin first; the last member is offered "Delete team" instead of Leave; external teams offer no edit, add or leave. Leave reads the team first, so the guard runs on its current members.
  - The admin toggle's answer with id 0 is settled by reading the team (the member's flag, or `TeamMemberMissing`).
  - v1 updates post name, description and `is_public` from a fresh read; v2 sends a merge-patch. A cleared description is written as `<p></p>` (why: the server does not store an empty one and keeps the old text).
  - A create is read back for its members; when that read fails, the created team is returned with its creator as the only admin, so a retry creates no second team.
  - Leave, Remove and Delete ask first with the access-cleanup notice (from 2.7.0 the task assignments, subscriptions and webhooks lost in projects no longer reachable; one sentence on older servers). After leaving or deleting, the page goes back to the Teams page and a quiet `refreshAfterWrite` follows.
  - Refusals are worded: already a member (6005), the last member (6006), a team managed by a sign-in provider (6010), an unknown user (1005), no permission, an invalid name.
  - An inbox entry about being added to a team opens the team's page when the notification names the team.
- **Sharing:** "Share" in the first group of a project's menu, for every real project that is not archived and never for link-share guests ([D62](#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind)), opens `/home/project/:id/share`.
  - People: avatar, name ("You" on one's own row) and permission. Admins change a row through an option sheet with the three permissions and Remove, which asks first with the cleanup notice; lowering one's own share asks first too. "Add person" opens the people search (without oneself, the owner and those already shared), then the permission (Read only by default), with one request.
  - Teams: an initials avatar (without a provider suffix), the name or "Hidden team" for a team the server hides, the member count and the permission, with the same actions; "Add team" offers the user's teams, and public ones where enabled, not shared yet.
  - Links, only where the server has link sharing and only for admins: the name or "Link without a name", the permission, "Password protected", "Created by {name}". A link's sheet: the view it opens (the project's views in order, the first by default), Share, Copy link, QR code and Delete ("Anyone using this link loses access at once."). "Create link" takes a permission (Read only by default), an optional name and an optional password (obscured, autofilled as a new password), then shows the same sheet as "Link created", without Delete. Links cannot be changed (the server refuses).
  - The link is `{frontend}share/{hash}/auth?view={id}` (`linkShareUrl`), on the frontend URL when it is http(s), else the server root, never http for an https server.
  - Share goes through the system share sheet (`LinkShareActions`, anchored on iPad), Copy through the sensitive clipboard ([D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links)). The QR code (package `qr`, owner) is dark on white in both themes with a quiet zone of 4 modules and the link selectable below; a link that needs a QR version above 10 says "This link is too long for a QR code". Screenshots are not blocked: the link is meant to be shared.
  - The hash appears only inside the link on screen, in the QR code, the share sheet and the clipboard; the password only in its field and the create request. Neither is logged, put in a route, kept in a provider that outlives its page or stored.
  - Others see people and teams read-only, with "Only project admins can change who has access". A change of one's own share or of any team share is followed by a quiet `refreshAfterWrite`, so the stored permission follows. A link share already gone counts as deleted.
- **The permission stored:** `projects.max_permission` (0 read, 1 write, 2 admin), filled through `expand=permissions` on the sync's project list, so no request is added; the project diff compares it, so a change of the permission alone is written although `updated` did not move. Null means unknown: offer the change and word the refusal. In a v1 single read the `x-max-permission` header wins over the body. Write answers never carry it, so the stored value is kept; a created or duplicated project is unknown until the next sync.
- **Every screen shaped by it** (`ProjectAccess`, by the server's rules; `projectAccessProvider` follows the stored row):
  - the project menu: Edit, Archive or Unarchive, the favourite and New subproject need write; Views and Delete need admin; Duplicate needs read, and its parent picker lists only projects the user may write;
  - "New task", the manual order of lists, and the board's drag, its cards' Move to column… ([D84](#d84-everyday-editing-in-the-task-detail-properties-in-place-task-links-move-to-column)) and its column menu need write; Done column and Default column need admin, and so does the Delete of a column that needs a new default first ([D48](#d48-kanban-columns-managed-online-from-a-column-menu));
  - the project pickers for new and moved tasks and for a project's parent leave out read-only projects, and so does the default project (the new-task sheet, the Android share target, quick add's fallback); the Android share target's Add to task leaves out their tasks;
  - the task sheet of a read-only project offers no Mark as done, Edit, in-place edits, Duplicate, Delete, Add subtask, description editing, checklist ticks, relation changes, attachment changes or favourite, and its menu holds only Copy link and Share ([D84](#d84-everyday-editing-in-the-task-detail-properties-in-place-task-links-move-to-column)); comments and reactions follow the stored permission until the details arrive, and the stored permission wins over an earlier read in the same run;
  - in rows of a read-only project the checkbox, labelled "Read only", and the star are off; each subtask's checkbox follows its own project;
  - a read-only project's screen says "Read only" under its progress line;
  - archived projects keep their own rules on top.

Limits:
- Not built: offline label creation (deferred by the owner), teams in the global search, share counts in the project menu, a cleanup list per project.
- Not gated by the permission: reordering and favouriting projects in the Projects tab, and quick add's `+project` naming a read-only project.
- A tap on the OS notification about a team membership opens the inbox.
- An assignee the server's access cleanup removed stays on the device until the daily full resync, because the removal bumps no `updated`.
- A team whose create answer is lost can still be created twice; only a failed read after the create is covered.

## D61: Table as a detailed list, Gantt as a read-only timeline

*Accepted 2026-10-26 (step 29).*

**Both views:**
- Every view kind the app knows is a tab, in the web's order (`isShownInApp` in `project_list_model.dart`); the user's default view can pick Table or Gantt. "New task" follows the stored permission ([D60](#d60-labels-teams-and-shares-online-the-stored-project-permission-shapes-every-screen)).
- Both read the local list path of [D43](#d43-task-lists-from-the-local-database-nested-and-ordered-like-the-webs) (`watchProjectList` over `LocalFilters`) through the filter engine of [D51](#d51-filter-engine-on-the-device-saved-filters-filter-builder-offline-search), so they work offline, show a local change at once and cost no request; pull to refresh runs the sync. Only a view whose filter the engine refuses downloads its snapshot like a list view (`downloadsSnapshot`: on open, on pull and after an edit, with [D43](#d43-task-lists-from-the-local-database-nested-and-ordered-like-the-webs)'s states).
- Preferences in the account's `list_preferences`: per view under `list:view:<id>` the table's `table_sort` and the timeline's `{range: "default" | {from, to}, without_dates, day_width}`; per account `table_columns`. Each field decodes on its own, a bad one as its default, and deleting a view forgets its preferences.
- On wide windows the table is 840 dp wide and the timeline takes the whole width ([D69](#d69-large-screens-a-window-layout-helper-readable-widths-capped-dialogs-and-sheets)); the task open in the pane marks its row ([D70](#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere)).
- The logic is pure Dart in `vikunja_logic`: `TableSort`, `TableColumn`, `compareTasksForTable`, `CalendarDate`, `GanttRange`, `defaultGanttRange`, `ganttFilterText`, `layoutGantt`, `ganttArrows`.

**Table:**
- Flat rows as on the web: subtasks are rows of their own, done tasks stand among the open ones, and a task marked done here keeps its place while its Undo is offered.
- Columns per account (`table_columns`, the web's keys), as the web keeps one choice for every table: the Columns sheet lists the web's columns except the task number (15), with Done, Title, Labels, Assignees and Due date shown by default and "Default columns" to go back. The title always shows. No task number column (owner, [D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab)); a stored choice naming `index` loads without it, and an empty choice is the defaults.
- One sort key per view (`table_sort`, the web's `field:dir`): "Default (newest first)" („Standard (neueste zuerst)“, also on the Sort chip), which is `index:desc`, and the 20 other pairs of column and direction. An unknown value or `index:asc` reads as the default.
- The server's order (`compareTasksForTable`): the key first, missing values last in both directions, priority and progress 0 as values, open before done, no done-at for an open task or one created done, a task created here after every server task. Ties go newest first, standing in for the view's positions, which are not downloaded. Titles compare ignoring case first.
- A sort on a hidden column gives way to the default (rows, Sort chip and check mark), as the web leaves it out of its request; the stored sort stays and applies again once its column shows. Picking a sort for a hidden column shows that column.
- "Show done" only on a view whose filter is `done = false`.
- The row is the task row of [D56](#d56-design-after-the-owners-mockups-blue-scheme-cards-one-task-row) with the chosen fields: the Done badge on done tasks; the project after a folder in its colour; labels; assignees; the comment count above 0 with the unread dot; the creator's avatar and name; the due, start, end, done-at (done tasks only), created and updated dates after their icons, formatted by the display settings, neutral and never red, an unset one left out; progress as a ring and a whole percent; and the priority with every value, Unset and on done tasks included, because the column promises it (Unset and Low in the primary colour, Medium amber, High and up the error colour with a circled exclamation mark). The checkbox and the star stay as on every row, and a tap opens the task sheet. Each row is one screen-reader node naming every shown field.

**Timeline (Gantt):**
- Which tasks: the web's range filter (`ganttFilterText`, character for character) ANDed with the view's filter as the server does it, with include-nulls if "Show undated" or the view asks (`LocalFilter.compileWithRequest`), in the timezone setting's zone, else the device's (`locationForFilters`). Where the engine refuses the view's filter, its last download stands in, narrowed to the range here with include-nulls from "Show undated" or the view.
- The web's quirks are copied where they decide which tasks show (a task starting on the last day after midnight shows only through another clause; the spanning clause ignores the due date; with "Show undated" every task with a missing date matches and the range trims it; a subtask with two parents shows once; a bar ending at midnight of the range's first day keeps its row). They are not copied where they are drawing mistakes: days are calendar days (`CalendarDate`), so nothing is a day off across a DST change; "today" (`todayProvider`) is taken when the screen opens or resumes and turns over at midnight while it is open; "Reset" is translated.
- The range per view, stored as "default" so it follows today (15 days back to 55 ahead) or as a custom from and to. The Date range chip opens a sheet with "Default (15 days back, 55 ahead)", "Custom range…" (the day-range picker in `features/common/`) and, only while the range or "Show undated" differs from the default, "Reset to defaults", which resets both, not the zoom.
- "Show undated" ("Undatierte zeigen") is the include-nulls switch, per view.
- Rows (`layoutGantt`): the matching tasks and every descendant, in any project. Top-level rows by start date (missing last), open before done, then newest first, each followed by its subtasks depth first, each task once under its first parent, indented up to four levels; tasks in a relation cycle become top-level rows. A parent without dates takes the earliest start and the latest end (else due date) of its subtasks. A row is left out without dates while "Show undated" is off, and when its bar lies wholly outside the range.
- Bars in calendar days of the device's zone, at least one day wide: start and end (else due) rounded to their days, an end before noon ending at the start of its day; a start alone runs 7 days and fades out; an end or due date alone starts 7 days before and fades in; undated from today to today + 7, neutral and dashed; a parent's span from its subtasks dashed. The fill is the task's colour or the primary container, with the text colour by contrast; a done bar is mixed with the surface, so its title stays readable, and its title is struck through.
- Titles sit in the bar when they fit, on a partial bar only on its opaque part (the first 60 % or from 40 % on), else after the bar. When a bar starts left of the screen, its title and a parent's chevron follow the visible part; the tap target and the screen-reader node stay with the bar.
- Parents get end markers, a band behind them and their subtask rows as wide as all their bars (`GanttLayout.groupSpans`) and a 48 dp chevron that collapses their subtasks, not stored. The chevron shows only where a subtask row would show; a collapsed parent outside the range hides nothing.
- Arrows for `blocking` (solid, error colour) and `precedes` (dashed, outline colour), from the right edge of one bar to the left edge of the other, one per pair and kind, only between rows that show: a hidden task's arrows go to its outermost collapsed ancestor that shows, an arrow to itself is dropped, and several on one end spread by min((n − 1)·6, 24) dp. No toggle, as on the web.
- The chart scrolls horizontally under a two-row header (month and year; weekday over day number, today filled; text capped at 150 %), with weekends tinted and today's line. It opens with today in its left third, again after the range changes, and "Go to today" scrolls back. Rows are 48 dp (more with large text); rows and header days are built only while on screen. A layout is computed once per source, range, day, "Show undated" and collapse.
- Zoom by − and + or by two fingers, 20 to 72 dp per day (36 by default), stored per view; a pinch saves when the fingers lift and holds the vertical scroll and pull to refresh while it lasts.
- Read-only: a tap opens the task, a long press does nothing, dates are changed on the edit page ([D20](#d20-scope-cuts-and-mobile-forms-of-desktop-features)).
- Empty state: "No tasks between {from} and {to}" with a hint to choose another range or show undated tasks. A view whose filter the engine refuses has [D43](#d43-task-lists-from-the-local-database-nested-and-ordered-like-the-webs)'s states before its first download and the note that the server applies its filter.
- Screen readers: one node per row with the title, "subtask of …", done, the dates ("{from} to {to}", "starts …, open end", "ends …, open start", "due …, open start", "no dates, estimated" or "dates from its subtasks"), its arrows ([D68](#d68-screen-readers-headings-one-announcer-high-contrast-reduce-motion-route-sweep)) and the expanded state with an action to collapse or expand. The grid, the bands and the arrows are left out; the header has one summary node ([D68](#d68-screen-readers-headings-one-announcer-high-contrast-reduce-motion-route-sweep)).

Limits:
- Table ties go newest first where the server uses the view's positions; they differ in a table view created after its tasks or reordered through the API.
- Titles sort ignoring case, SQLite by bytes.
- The timezone a view's own filter may carry on the server is not modelled; with an empty timezone setting the server evaluates in its zone, the app in the device's.
- A view whose filter the engine refuses can list slightly other tasks than the server with "Show undated" on.
- Servers before 2.7 get 2.7's filter and tree rules, unchecked.
- Saved filters have no Table or Gantt view; a saved filter opens as one list.
- At 200 % text the table's chips on a 320 dp screen and the timeline's zoom and today buttons on a 360 dp phone run past the edge; the row scrolls sideways.

## D62: Onboarding through the browser; link-share guests as an account kind

*Accepted 2026-10-26 (step 32), the owner's decision where marked.*

**Onboarding** (the app still never takes an account password or a TOTP code, [D14](#d14-browser-sign-in-only)):
- Server overview, under "Continue to sign-in", both off while a sign-in runs:
  - "Create account" where the server allows registration (`Capability.registration`): a dialog says "On the sign-in page, choose Create account. You come back here afterwards." (Cancel, "Continue to sign-in"), then the normal browser sign-in runs, because the web's sign-in page links to its register page and the pending sign-in survives the move. A sign-in page on another host puts [D23](#d23-browser-sign-in-through-flutter_web_auth_2-in-an-ephemeral-session)'s warning first in that dialog.
  - "Forgot password?" with local accounts (`Capability.localAuth`) opens the web's `get-password-reset` in the external browser (`passwordResetPageUri`, on `webFrontendBase`).
  - A server with invite links but no registration says "Registration needs an invitation."; the sign-in methods card says the sign-in page also creates accounts or resets passwords, as far as the server allows.
  - The action bar is pinned only on a screen at least 480 dp times the text scale tall.
- Invite links (`{base}register#invite-link=<token>`, pasted on the Connect screen or shared to the app): the base is probed and the invite checked (`InviteLinksPort.check`, `POST /api/v2/invite-links/check`). A card shows its name, teams and whether the email needs confirming; "Create account in the browser" opens the invite in the external browser, because the web drops the app's sign-in on an invite registration; "Continue to sign-in" goes to the server overview. 404 code 2005 reads "This invitation is invalid, expired or used up"; a server without the route gets the card unchecked. The token is never shown or logged.
- Account tab, Server section, for every account, guests included: a demo-server note in the amber accent, the MOTD card and every legal link of the server ([D81](#d81-vikunja-280-details-legal-links-okabeito-colours-lockout-hints-subtask-tree-accents)), from the stored `/info`, read again while signed in ([D78](#d78-vikunja-280-trash-codes-as-gone-its-limits-no-nul-info-re-read)).

**The guest account:**
- Kept in the official app (owner, 2026-11-12).
- **What a guest may do** (owner, 2026-11-12): what the Vikunja web interface offers a link share of the same permission (read, write, admin) and the server accepts, presented the app's way, for example disabled with a reason where the web hides it.
  - Not offered: what the web reaches only by a typed address and not through its interface, for a write share editing, archiving and the background of the project, for an admin share also managing its views and deleting it (owner).
  - Kept although the web lacks them, because the server accepts them (owner): a guest editing and deleting its own comments, which the web lacks only because it compares the author's id with the wrong sign, and assigning people the device already knows, which the web lacks because the server refuses link shares the user search.
  - Unavailable stays what the web shows but the server refuses or never stores: reactions, Follow, favourites, creating labels and the user search; hidden or disabled.
  - Tests make every new route and every new use of what needs this decision decide: routes through `AppRoutes.openToGuests` and `guest_gates_test.dart`, actions through the guest action inventory (see the gates below).
- A share link comes in by paste or through the Android share target; no QR scanner (owner).
- `Account.linkShare` (`AccountKind.linkShare`) with the share id, project id and share name; `userId` `-shareId` and username `link-share-<id>`, as the server writes the guest, so upload recovery and the guest's own comments match. Its id follows [D25](#d25-account-registry-in-sharedpreferences-without-secrets), so the same link opened again replaces the guest's session. The registry entry has `kind: link_share`, `link_share_id`, `project_id`, `share_name` and no `user_id`.
- Name: the share's name, else the project's title (read at sign-in, then followed from each sync's project list, `AccountRegistry.updateGuestTitle`), else `link-share-<id>`; never the server's "Link Share".
- `LinkShareStore` keeps the JWT and the hash in secure storage, the hash written first and deleted first; a guest counts as signed in while its hash is stored. The share's password is never stored or logged, since a renewed token never expires and the password guards someone else's project; a share with a password asks again when the hash alone cannot sign in.

**The guest session** (`LinkShareSession`, an `AccessTokenSource` per guest, held by `LinkShareSessions`, beside `SessionManager` and `TokenStore`, which are built around a rotating refresh token):
- `POST /shares/{hash}/auth` signs in; the token (72 h, no refresh token) is renewed through `POST /user/token` once half its lifetime has passed. Renewals are de-duplicated; a failed one keeps the old token while valid and retries after 5 minutes.
- An expired token is replaced by signing in again with the hash; a 429 blocks that for its `Retry-After`. A container the OS started tries at most once, so a share that needs its password never spends the shared rate limit every half hour.
- A 401 code 11 takes a newer stored token, else signs in again, never a renewal (it passes the same check).
- 13001 or 13002 on that sign-in, or a gone share, end the session and mark the account `needsReauth`.
- The server clock offset comes from each token's `iat` and stays in memory. After writing a token the session reads the hash again and takes the token back when a sign-out in another isolate deleted it meanwhile.
- `AccountTokens` hands a guest's requests to its session, so transport, sync and outbox need no guest branch; the session check, the background runner and the sign-out have guest branches that never touch `SessionManager`, and the sign-out skips the server's logout. The account settings repository refuses a guest as the server would (403 code 1023).
- The permission is the stored project permission, never the token's claim, because the server reads the share on every request.

**A share gone** is `LinkShareGone`, a `SessionEnded` with the reason `linkShareGone`: v1's 400 code 13003 through `normalizeError`; v2's 401 without a code only through `LinkShareGoneInterceptor` on a request with a link-share token, since a user can get that answer too; at the share endpoints 404 code 3006 or 404 without a code (link sharing off), told apart by the `code`. The outbox stores and reloads it as a `SessionEnded` with that reason, so code reading the outbox checks the reason. The session check reads `GET /user` through the guest's session on a client without the interceptor and maps v2's 401 without a code itself, because `/token/test` passes a deleted share's token. A 401 code 1027 (the endpoint needs a user) stays an ordinary failure and never ends the session; a guest's screens do not call those endpoints. A missing password, a wrong one and an invalid invite stay a `DomainError` 412 code 13001, a `Forbidden` code 13002 and a `NotFound` code 2005.

**Sync:** no account phase for a guest, since the server's pseudo user has no settings and would rename it "Link Share". `GuestReadClient` reads the shared project once (`GET /projects/{id}`, one request per run) when the project list brings it without a permission, so [D60](#d60-labels-teams-and-shares-online-the-stored-project-permission-shapes-every-screen)'s `ProjectAccess` shapes a guest's screens. Labels and tasks sync as for users.

**Gates** (`activeAccountIsGuest`, `accountIsGuest`), by the rule above: where the server refuses link shares, or the web offers them only by a typed address:
- No activity sync (in front, for other accounts or in the background runs), inbox, bell, activity switch or realtime socket; local reminders stay.
- Hidden: the account settings, Organize, new projects, saved-filter editing, favourites, reactions and Follow, which the server refuses or ignores for a link share, and the project menu's Edit, Archive, Share, Duplicate and New subproject, also for write shares, and its Delete and Views even for admin shares, as the web offers a link share no project menu: it reaches the project's settings only by a typed address, and the server refuses a link share sharing and creating projects.
- The board's columns have no guest gate: a guest gets what a user of the share's permission gets ([D48](#d48-kanban-columns-managed-online-from-a-column-menu)), which is what the web offers and the server accepts.
  - A write guest creates, renames, limits, moves and deletes columns, the done and the default column too, which the server then clears in the view without asking for admin permission; it gets no Done column and Default column, which the web shows a write share but the server refuses, as every change of the view needs admin permission.
  - An admin guest also chooses the done and the default column, as the web offers an admin share.
  - The leftmost column holding tasks while no other column is the default is deleted only after a new default ([D48](#d48-kanban-columns-managed-online-from-a-column-menu)): a write guest, as a write user, finds that Delete disabled with the reason that its tasks have to go to another column first; an admin guest sets the new default first, as an admin user does.
  - Apart from what the app builds for nobody (such as dragging dates on the timeline), that disabled Delete is the one place where the app offers a write share less than the web does and the server accepts (owner, 2026-11-12): the web offers it and the server accepts it, but leaves the column's tasks in no column, which [D48](#d48-kanban-columns-managed-online-from-a-column-menu)'s guard against orphaned tasks prevents, and the new default that guard needs is refused below admin permission.
- No "Create label" (the picker says why); quick add creates no labels and looks no one up; people pickers and @-mentions offer only people already on the device. A label a guest types that does not exist stays in the task's title: the preview marks it "stays in the title", and the help says that only existing labels are added ([D38](#d38-quick-add-the-webs-grammar-with-fixes-through-the-outbox)).
- Routes are closed to guests by default. `AppRoutes.openToGuests` lists, by full path as go_router matches them (`GoRouterState.fullPath`), the routes a guest may open: the pages outside the shell (the splash, Connect, the server overview, the first sync, the notification setup, Connection, About), the tabs and the shared project, the task's edit, description and comment editors, the search, a label's task list, the widget pages, Privacy and adding an account. The router sends a guest from every other route to the Overview, also from a location that matches no route; closed today are the account settings, teams, the trash, the inbox, label management, the saved-filter form and the project's edit, description, views and share pages. `app/test/app/guest_gates_test.dart` walks the router and fails for a route on neither that list nor its own list of closed routes, each with the reason a guest is kept from it, and for an entry that matches no route.
- Actions are decided by the rule above too: a new action that uses what needs the decision is hidden or disabled for a guest where it is built (`activeAccountIsGuest`, `accountIsGuest`) when the rule keeps guests from it, and `app/test/app/guest_action_inventory_test.dart` makes it decide. It scans `app/lib` for the uses of a watch list (`guest_action_inventory.dart`): the providers of what needs a user (Follow, teams, project sharing, saved filters, account settings and user-settings writes, account security, activity, the trash), of the label and people repositories, whose writes and server lookups need one, of the project views, which the web offers a link share only by a typed address, and of the board's columns, which the web offers a link share by its permission, and under `features/` an account's raw clients (`readClientProvider`, `writeClientProvider`, `accountDioProvider`, which would go around the repositories) and the calls for favourites, reactions, creating and changing projects (create, update, the description, move, duplicate, delete), the board view's done and default column, and restores from the trash. A call is an instance's, also one on `this` in a mixin, an extension or a subclass: a type's member of the same name, such as `TrashAction.restoreTask`, is none, and neither is a declaration of the name, such as a method's or an enum value's. Each declaration with such a use (file and enclosing member, named as the accessibility sweep's overlay inventory names them: a top-level function, getter or variable, or a type's method, getter, field, operator or constructor, whatever its type, records and type arguments included; an unnamed constructor is `new`, an extension type or mixin class goes by its name, and an unnamed extension by `extension on <type>`, numbered from the second on that type in a file) is listed as `Gated` (a guest check in its file, or in the files where the action is offered), `BehindClosedRoutes` (routes on the guest test's closed list) or `Open` with the reason, and with the watched names it uses (`uses`), each decided by that entry. The test fails for an unlisted declaration, an entry of none, a listed declaration whose watched names differ from its entry's `uses` (a name that comes into it has to be decided like a new declaration, one that leaves it taken out), a gated entry whose files ask nothing about guests, a route not closed to guests and a name on the watch list that no longer exists; sample sources check the scan's names, its wiring rule and the check of `uses`. A use inside the declaration that generates another watched provider is its wiring, but only when the `@riverpod` or `@Riverpod(…)` annotation is right above that declaration and the `.g.dart` beside it generates the provider from it (`@ProviderFor`): a widget or function that only shares the provider's name is a site. A new provider that only passes a watched one on goes onto the watch list instead. It lists 102 declarations: 59 behind closed routes, 28 gated and 15 open, deciding 113 uses of 33 watched names; the board's column changes and its done and default column are open, following the share's permission.
- The actions of step 37k ([D84](#d84-everyday-editing-in-the-task-detail-properties-in-place-task-links-move-to-column)), none of which uses a watched name:
  - the task detail's in-place edits follow the share's stored permission, as the edit page does: a read guest gets none, a write guest edits, and the label picker offers no "Create label";
  - its Copy link and Share are offered to guests of every permission, as the web copies a task's link from its identifier for every link share;
  - a card's Move to column… follows the board's own rule (`boardIsReadOnly`), as a write guest may already drag cards, and never changes the board's done or default column.
- The support details of step 37l ([D20](#d20-scope-cuts-and-mobile-forms-of-desktop-features)) are on the About page, open to guests like the page, and use no watched name; they show a guest as "Kind: guest" and record its ended session too (`linkShareGone`, `expired`).
- Kept: the app's shell (on wide windows without the project tree's column, [D82](#d82-projects-listdetail-the-project-tree-beside-the-project-on-wide-windows)), so the shared project shows in the Overview, Upcoming and the search, the app's way of showing what the web shows a guest in one project card; task edits by the stored permission, on the edit page and in place in the task detail; comments with Edit and Delete on its own; attachments with upload, delete and the cover, subtasks, relations, Duplicate, and Delete with Undo, as the web offers a write share; every project view.

**Guest entry:**
- The Connect screen recognises a pasted share link before any probe (`parseLinkShareUrl`: an explicit http(s) scheme, any path before `share/`, the web's `#share-auth-token=` address, a link inside text), shown shortened in the progress line, never with its hash, and the hash stays out of the screen's state.
- The link's server: a stored account's server whose web frontend is the link's base, else the base probed like a typed address (an http server asks first); if no Vikunja server answers, "Which server is it?" asks for the server's address and the link opens once it is entered. Offline, timeouts and TLS errors stay ordinary connection errors.
- Link sharing switched off is answered without a request only for a freshly probed server with no stored account, because a stored account's `/info` can be hours old; otherwise the server's 404 says it.
- "Open a shared link" under "Try the public demo" opens a sheet with a field and Paste. Only the address field, Continue and the known-server chips carry a pending share on, not the demo button, so a hash never goes to try.vikunja.io.
- Android share target: a shared text with a share link offers "Open as guest", signed in also "Make it a new task instead"; an invite link goes to the invite check; a share with files is never taken for a link. iOS has no share extension before 1.0 (owner, [D74](#d74-ios-phase-app-store-prerequisites-testflight-from-the-mac-photo-locations-capture-cover)); a link is pasted there.
- Password sheet (13001, 13002): obscured with show and hide, no autofill, "Wrong password" inline with the field kept focused, and the note that the app does not save the password (in review).
- `GuestSignIn` signs in and writes the secrets before it replaces the share's old session, so the old one keeps answering until the new one exists and a failed write leaves it working. Before it writes them, a guest removed a moment ago waits until part of the app lets go of its old database ([D31](#d31-one-drift-sqlite-file-per-account-shared-across-isolates)); when that wait gives up, the link fails with "Still removing the guest access" and the new token is dropped without being stored. It upserts and activates the account; after the first sync the guest lands on the shared project in the link's view (`?view=<id>`). "Open the link again" uses the stored hash and server and stays where the user is.

**Guest UI:**
- Account tile, switcher button ("Accounts, guest in …"), Account tab header, Accounts section and the share sheet's account line show a link icon, the guest's name and "Guest · {host}". The Overview greets a guest without a name.
- The Account tab has no Edit, account settings, Organize, deletion note or Theme row (a guest follows the system); a Guest note gives the share's permission as the last sync stored it, what it allows and what needs an account. Sign out reads "Remove guest access", and its dialog names the guest and the server.
- An ended guest gets "Guest access ended" with "Open the link again" (asking for the password where needed) on the Account tab and the first-sync screen; a gone link and link sharing switched off get their own card. The badge, the background notification ("Guest access to {name} ended") and the sync's failure texts say "Open the link again".
- Logs: `describeUriForLog` replaces the segment after `share/` and `shares/` (a numeric share id stays), `redactSecrets` also the `"hash"` JSON key, and the link-share client's `Dio` logs no bodies, as requests carry the hash and maybe the password and answers echo the hash. No parsed link, token or share type prints its secret.

Limits:
- The banner does not tell a needed password from a deleted link; a tap does. While the password sheet is open, its button reads "Waiting for sign-in…".
- A request already inside the old session when "Open the link again" replaces it can still end as `SessionEnded`, as with user sessions.
- A guest whose link needs opening again gets one sign-in attempt per app start.
- The invite token stays in the Connect screen's state while the screen is open.
- Others see a guest's tasks and comments under the server's English "Link Share" name.
- Share links do not open the app straight from other apps (no App Links for self-hosted domains); they come by paste or the share target.
- Not probed: an admin link share, a real 72 h expiry, servers before 2.7 (on 2.3 the share endpoints are v1 only), the sign-in sheet surviving a trip to the mail app, and an invite that passes the check.
- The guest action inventory is a scan of the source text, by name and not type-checked, so an unusual construct may slip through it; review still covers what it does not see. It sees names, not types: a watched repository handed on as a value is listed where its provider is read; a call of another repository's method of a watched name is a use too, so the share sheet's Add to task (the task repository's `updateDescription`) is listed, open, as it offers only tasks the share may change, and the description editor's write is listed behind its closed routes although its task branch runs on the open task route; so is a call of the app's own method of such a name, so the project menu's handler is listed, gated, for calling `ProjectManagementActions`' `duplicateProject` and `deleteProject`; and a gated entry's check only finds that its files ask about guests somewhere. An entry decides names, not each use: another use of a name its `uses` holds, in the same declaration, passes unseen. Calls and raw clients count only under `features/`, a declaration only at the top level or as a type's member (a local function counts as the declaration around it), and its name is read from a line that starts with its modifiers, its type or the name itself, as dart format writes them: a name on a line of its own below a type split over lines counts, a name after the closing bracket of such a type on the same line does not. Two entries are open because a guest never has their data: the project tree's moves (its tree holds only the shared project) and a saved filter's menu (the server lists a link share no saved filters). The trash's port goes into the task and project repositories for their restores only, so the entries of those two providers are open and every restore call is a site of its own: the task sheet's Undo is open to a write guest ([D79](#d79-the-trash-of-vikunja-280-undo-queued-deletes-a-trash-page)), the opener's Restore gated, a project's Undo gated with the project menu's Delete, and the trash page's restores behind its closed route.

## D63: Home-screen widgets: app-written snapshots, Glance on Android, WidgetKit on iOS

*In review since 2026-10-27 (steps 18 and 19, until the iOS device test).*

**Data: the app writes, the widgets only draw** (`app/lib/core/widgets/`):
- Kinds (`WidgetKind`): Today (overdue and due today like the Overview, or the Overview's saved filter when one is picked), Upcoming 3, 7 or 14 days (overdue and due within the days), Overdue, Favorites, Project (its first list view's filter and stored sort, done tasks hidden), Label (its open tasks), Saved filter (not for guests), and the New task button.
- One snapshot per shown list (`WidgetSnapshot`), versioned JSON with epoch milliseconds: the state (`ok`, `needsReauth`, `guestEnded`, `accountRemoved`, `gone`), title, subtitle, `generatedAt`, `validUntil` (the next local midnight at the latest), `changesAt` (the due instants in range), at most 30 rows and the count of the rest, the texts and the links. A row has the task id, title, a day-level due label with its tone (`overdue`, `today`, `later`, `none`), the priority, the project with its colour, whether Done is offered (by the stored permission, never in read-only or archived projects), a screen-reader label without an identifier, and its link. A fingerprint without `generatedAt` keeps unchanged content from being rewritten.
- Keys are `<accountId>.<part>` (`today`, `overdue`, `favorites`, `quick_add`, `upcoming_<days>`, `project_<id>`, `label_<id>`, `filter_<id>`), so a sign-out finds its files. One catalog per account (`WidgetCatalog`) feeds the native pickers: the account's name, host and guest flag, the lists with their keys, the projects without archived ones (nested ones with their parents' path, and whether they take tasks), labels and saved filters; `host.json` holds the active account, the "Use system colors" switch and the widget-link key ([D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links)).
- Dart formats every text (`WidgetTexts`) with the account's display settings and translated names, in the app's current language ([D71](#d71-english-and-german-us-base-glossary-error-texts-live-language-changes)), so no native code copies those rules. Due labels stay right until midnight ("Today, 14:30", "Tomorrow", a weekday, a date, or the web's absolute format), never relative, which would go stale between updates. The device's 24-hour switch and the locale are noted for headless isolates.
- No file holds a token or other secret; task titles can be left out ([D64](#d64-app-lock-over-the-ui-and-device-privacy-settings)). No task title, snapshot or link is logged; Dart logs counts and failure types, Kotlin failure types.
- The snapshot builder in `core/` reuses the features' Overview grouping, project list model, project tree and access, default project, display settings, date formatter and task meta texts rather than moving them out of the features.

**The in-repo plugin** `plugins/vikunja_widgets` (Dart, Kotlin, Swift; SwiftPM; the Kotlin package and the channel `io.vikunja.vikunja_widgets`, in review), a path dependency of `app`, so `packages/*` stay pure Dart ([D1](#d1-flutter-pub-workspace-with-pure-dart-packages)):
- Dart reads and writes the files (a temp file and a rename); Kotlin and Swift only report the directories, list the placed Android widgets, redraw and pin (`requestPin`; the launcher's pin callback writes the new widget's config natively).
- `takeActions()` and `ackActions(ids)` on both platforms: entries stay until acknowledged, so the caller de-duplicates by id.
- A redraw is an `ACTION_APPWIDGET_UPDATE` broadcast to the two receivers by class name, so the plugin needs no Glance dependency; on iOS `reloadTimelines(ofKind:)`.

**Publishing:**
- One `WidgetPublisher` per signed-in account while the shell runs: 1 s after the last change of the account's tables, registry entry or sync state, at most 3 s after the first, at midnight and on resume; it writes only what changed and redraws only the widgets showing it (a change reaches a widget within 5 s).
- It writes the lists on screen (Android: the configured keys plus the active account's Today for a widget not set up; iOS: the extension's request markers, plus the smart lists and New task always). `publish(config)` writes a list before a widget shows it (Save, "Add" before the pin).
- The background runs import the widgets' taps first, so that a sync run sends them with every account's queue before any account syncs and a drain run in its turns, and publish after each account's turn, an account that needs a new sign-in included.
- A sign-out or removal deletes the account's snapshots, catalog and waiting taps through the account data wiper; widgets still on screen say "Account removed".

**Done from a widget** runs the notification Done's `ExternalDone` (`core/outbox/`, [D39](#d39-local-notifications-a-scheduler-per-account-with-a-rolling-window)), which also redraws the widgets before it waits for the network and again at the end; a notification's Done redraws them too.
- Exactly once: `WidgetTapImport` queues each tap's Done and records its id in `imported_widget_actions` (`id` primary key, `imported_at`; schema v10) in one transaction of the account's database, so a tap read again after a crash before its file is deleted is skipped and a repeating task never moves twice. Only then are the taps acknowledged (which deletes them; acknowledging first would bring the row back) and the widgets redrawn. Taps of an unknown account are dropped; ids are kept 30 days. The same table covers Android's queue.
- **Android:** the Glance checkbox runs `MarkDoneAction`; an untick does nothing. `WidgetActionQueue.add` refuses a row already hidden (queued, claimed, or pending from a newer list than the row's), so a repeating task can be ticked again once a newer list shows it. A tap rewrites the whole `widget_actions.jsonl` (a temp file and a rename, under an in-process lock) rather than appending, because the app claims the queue by renaming it and an append could be lost; a rewrite can at worst duplicate a tap, which the table drops.
  - The row hides at once (`android-pending.json`), and `WidgetActionsWorker` (unique work, `APPEND_OR_REPLACE`, expedited on Android 12+) starts a headless engine with `widgetActionsMain` (`core/widgets/widget_entry_points.dart`, re-exported by `main.dart` so the AOT build keeps it), waits up to 3 minutes for `finished` on `io.vikunja.app/widget_worker` (in review), redraws and destroys the engine. The Dart side builds the notification action's container, imports the taps and publishes every account.
  - With an empty queue the worker only publishes: once per key and process when a widget finds no snapshot (placed while the app is closed), and once per `validUntil` for a stale one. An inexact alarm that does not wake the device redraws at the earliest `changesAt` or `validUntil`, so a task due today turns overdue on time.
- **iOS:** `MarkDoneIntent` (`Button(intent:)`, iOS 17, `authenticationPolicy = .requiresAuthentication`, [D64](#d64-app-lock-over-the-ui-and-device-privacy-settings)), only in the extension, writes one file per tap, `outbox/<uuid>.json` (account id, task id, `createdAt` in whole milliseconds; the plugin rounds a fractional one), as `<uuid>.json.tmp` and a rename (the plugin skips `.tmp` files), records the task as hidden in `ios-pending.json` and reloads the timeline; a second tap while its file exists is ignored. No network, keychain, SQLite or lock. The app imports the outbox on start, on resume and in every background run.
- No widget link writes (no `widget/done`), because any app, and on iOS any web page, can open the app scheme. After a force-stop on Android 14 or earlier a row's tap opens the task, and a tap that reached the queue is imported at the next app start; Android 15+ greys out a force-stopped app's widgets until it is opened.

**Links** `<scheme>://widget/…` (`core/links/widget_link.dart`): `task/<id>?account=`, `new-task[?account=][&project=]`, `list?account=&kind=[&id=][&days=]` (days 1–365), `account?account=`, `open[?account=]` and `configure?appWidgetId=`, each with the install's key `k` ([D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links)).
- `DeepLinkRelay` passes them to `widgetLinks`; `WidgetLinkListener` switches to the widget's account without asking only with the right key, by [D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links)'s rules. An unknown account or a malformed link is dropped.
- They open the task sheet (or "This task is gone"), New task (`TaskOpener.requestNewTask`), the Overview, Upcoming, a project, Favorites, a saved filter, a label's tasks, the Account tab or the setup page.

**Widgets page and setup page** (`features/widgets/`):
- The Account tab's "Home screen" section (on this device) opens `/home/widgets`: what a widget shows, the steps per platform, a note that the home screen shows task titles, the placed Android widgets (one not set up included) with their setup, and on Android 8+ where the launcher can pin, "Add a widget" with Today, Upcoming 7 days, Overdue, Favorites and New task (`requestPinAppWidget` through the plugin, the list published first); a project, label or saved filter is chosen in the widget's setup afterwards. A launcher that declines is an announced note.
- The setup page `/home/widgets/configure?appWidgetId=…` waits behind the sign-in, the first sync and the notification setup; native code reaches it through `widget/configure`, since a plain route path would be lost on a cold start. It opens only for a widget the plugin lists as placed, else, and always on iOS, "This widget can't be set up here". It offers the account (with several), the list, the days, or a project, label or saved filter (none for a guest) from a picker, with a live preview; Save writes the config and publishes, and from the launcher (`&from=widget`) moves the app to the back (`moveTaskToBack`, not `SystemNavigator.pop()`, which would finish the activity).

**Android widgets** (Glance 1.2.0):
- `TasksWidget` (3 × 2 by default, resizable, `reconfigurable|configuration_optional`, so Android 12+ places it showing the active account's Today) and `QuickAddWidget` (2 × 1).
- `SizeMode.Responsive` with four layouts, the smallest only the header, centred. The header has the title, subtitle, count and "+" for a new task. Rows at least 48 dp with a 48 dp checkbox where Done is offered, the due label in its tone's colour (overdue also with a warning icon), the priority and the project after a folder tinted with its colour (`onSurfaceVariant` without one); "+N more", empty and message states, a sign-in banner; on a configured widget "Account removed" and "gone" open its setup. Text sizes in `sp`; a count without its spoken label reads a native plural.
- The state definition reads the files on every update, so a new snapshot shows at once; removing a widget deletes its config.
- Theme: the system colours on Android 12+ unless "Use system colors" is off, else [D56](#d56-design-after-the-owners-mockups-blue-scheme-cards-one-task-row)'s brand colours.
- `WidgetConfigureActivity` (exported for the launcher's configuration step) checks that the widget id is the app's, sets `RESULT_OK` and opens `widget/configure` in `MainActivity` in the app's own task (`NEW_TASK`, `SINGLE_TOP`, `CLEAR_TOP`), like `TaskLinkActivity`, so no second Flutter engine runs on the same databases. Taps follow only the app's own widget links.
- Static preview layouts and images serve every version (no generated previews for Android 15+). Fixed strings (picker name and description, a few states) are in `res/values(-de)/strings.xml`; everything else comes translated in the snapshot.
- Dependencies: the Compose compiler plugin equal to the Kotlin version (2.4.0) with `buildFeatures.compose`; `androidx.work:work-runtime:2.11.2` declared, because below it R8 strips Glance's RemoteViews translator; no `glance-material3`. `proguard-rules.pro` keeps every `ActionCallback`'s no-argument constructor, which Glance calls by reflection.

**iOS extension** `app/ios/VikunjaWidgets/`, target `VikunjaWidgets` (plain Swift; added by the idempotent `tool/add_widget_extension.rb`, which puts the embed phase before Flutter's "Thin Binary" and keeps the file list in sync):
- Bundle id `io.vikunja.app.widgets`, iOS 17.0 (the app 15.0); the App Group `group.io.vikunja.app` on both targets (in review), no keychain group and no token ([D24](#d24-tokens-in-secure-storage-readable-after-the-first-unlock)), since access tokens live 600 s and the extension must never refresh.
- `VikunjaTasks` (`AppIntentConfiguration`: account, list kind and days, project, label or saved filter from the catalogs; a nested project shows "in *parent*") and `VikunjaQuickAdd` (account and an optional project that takes tasks). A new widget shows the active account.
  - A placed widget refers to its kind, so a renamed kind removes the widgets placed under the old one: the kinds must not change after the first release. `WidgetKinds` in the extension and the plugin's `kinds` name the same two, and every widget configuration takes its kind from `WidgetKinds` (`app/test/app/widget_kinds_test.dart`) (in review).
- The extension takes every snapshot key from the catalog and never builds one; it leaves a marker `requests/<key>` for each list it shows and removes one older than 24 h whose widget is gone. Timeline entries now, at every `changesAt` and at `validUntil`, reloaded `.after(validUntil)`, so a task due today turns overdue on time without the app.
- Small, medium, large, the iPad's extra large and three lock-screen sizes; dark, tinted and Dynamic Type (fewer rows rather than smaller text; the header stays and "+N more" counts every row not shown). `.privacySensitive()` covers the rows' labels, the small widget and Done.
- Fixed strings in `en.lproj` and `de.lproj` (`Localizable.strings`); `Localizable.stringsdict` has the plurals `%lld tasks`, for a count without the app's label, and `+%lld more`.

Limits:
- iOS lists are refreshed while the app is closed only by the background runs; a list configured then shows "Open Vikunja to load this list" (in review) until published, and "Tomorrow" can be stale after midnight (overdue switches on time).
- Unticking is no undo, and the widget offers no Undo.
- With Android 12+'s expedited quota used up, the worker runs later as ordinary work; the tap stays queued. Below Android 12 a dark-mode change waits for the next redraw.
- Not offered: edits beyond Done, Android lock-screen widgets, a project on the Android New task button, lists across accounts, configuring an iOS widget from the app (iOS has no API; Edit Widget on the home screen does it).
- Waiting for the iOS device test: the configuration fields, the project picker following the account, the extension seeing which widgets are placed, the large widget's "+N more", signing with the team's App Group, and whether a lock-screen release build needs `DEAD_CODE_STRIPPING=NO`.

## D64: App lock over the UI, and device privacy settings

*Accepted 2026-10-27 (step 35a).*

- **A gate over the UI, not encryption:** data at rest stays as [D24](#d24-tokens-in-secure-storage-readable-after-the-first-unlock) and [D31](#d31-one-drift-sqlite-file-per-account-shared-across-isolates) describe, so nothing without a UI waits for the lock: the OAuth callback, the notification actions, the widget worker and the iOS widget outbox import, the background runs, the realtime connection and the schedulers.
- **Settings per device** (`PrivacySettings` in `core/security/`), the same for every account and kept on sign-out: `appLock` (off), `lockAfter` (immediately, 1 minute by default (owner), 5 or 15 minutes, 1 hour), `blockScreenshots` (off, Android only), `notificationContent` (show everything by default, hide on the lock screen, never show task titles) and `widgetTitles` (on).
  - Stored as `privacy.settings`, JSON with `version: 1`: unknown fields are ignored and an unknown choice is its default; another version or a field of the wrong type makes it unreadable.
  - Fail closed: unreadable settings give every switch its most private value for that launch (the lock on, Block screenshots on, no task titles in notifications or widgets), because the user may have chosen any of them, without writing back; the page shows the defaults with a note, and saving overwrites. The controller starts locked, and `bootstrap.dart` awaits the read (at most 5 s) before `runApp`.
- **Unlocking** (`DeviceAuthenticator` over local_auth): biometrics or the device credential (`biometricOnly` off, so the screen lock stays a way in when biometrics lock out; `persistAcrossBackgrounding` off, because the lock prompts again on its own return; `sensitiveTransaction` off). Android's prompt has the app's name as title, a hint and the reason, all localized; iOS shows the reason, and `NSFaceIDUsageDescription` (en, de) explains Face ID.
  - Android: `MainActivity` extends `FlutterFragmentActivity` (BiometricPrompt needs it), `LaunchTheme` and `NormalTheme` have AppCompat parents (`Theme.AppCompat.Light.NoActionBar`, at night `Theme.AppCompat.NoActionBar`), the manifest declares `USE_BIOMETRIC`, and `defaultFocusHighlightEnabled` is off on the `FlutterView` (in `onPostResume`, API 26+), because AppCompat otherwise greys the whole app after a key press.
- **When it locks** (`AppLockController`):
  - After every cold start while on; "unlocked" is never stored.
  - After `lockAfter` out of sight by the wall clock (deep sleep counts), and whenever the clock went back; "Immediately" locks on the hide. `isLockedNow()` evaluates at once, so a link handled before the show event still waits.
  - Lifecycle events during a prompt neither lock nor cover, so "Immediately" does not relock behind a PIN screen; time out of sight during a prompt that then fails counts from the prompt's first hide. After a return from a prompt that hid the app, a prompt with no answer within 2 s counts as cancelled and its late answer is ignored.
  - It prompts by itself once per return, after 300 ms resumed, and not again within 3 s of a prompt cancelled out of sight; the lock screen's Unlock prompts again. Cancelled, locked out, a stuck prompt ("close Vikunja completely and open it again") and unavailable stay locked.
  - When the device has no screen lock any more, the app lock turns itself off, unlocks and says once "App lock was turned off because this device has no screen lock", because removing the screen lock already needs the credential and failing closed would leave only a reinstall.
  - Turning the lock on or off needs a successful prompt (off also when the device has no screen lock any more); changing the time does not. Without a device screen lock a lock that is off cannot be turned on: the switch is disabled ("Set a screen lock on this device first"), and the app asks the device again on every resume.
- **Excursions don't relock** (`AppExcursions`): the app's own round trips (the pickers and camera, "save as", the share sheet, "open with", the browser sign-in, the permission request and the system's notification, exact-alarm and app-language pages, the launcher's pin dialog). `roundTrip` lasts until the app is resumed, because Android hands a picker's result over just before the resume; `launchAway` until the app has left and come back, or ends at once when nothing opened. Nested and overlapping excursions are counted. One lasts at most 10 minutes, then counts as a hide from its start. External links and the web's pages are no excursion.
- **The gate** (`AppLockGate`), the outermost widget of `MaterialApp.router`'s `builder`, around `NotificationTapListener` and the other listeners: the app stays mounted below without pointers, semantics, focus or tickers, so sheets, the task pane and unsaved edits survive; above it the opaque lock screen ("Vikunja is locked", the error as a live region, Unlock) or the privacy cover. No router redirect, which would replace the pages below.
  - Links, widget taps (`widget/configure` included), the New task shortcut, shares and notification taps wait while `isLockedNow()` and open after the unlock, the last one winning; a share stays in Android's `ShareInbox` meanwhile.
  - System back while locked moves the app to the back and never pops a route: the gate's observer comes before the router's, and from Android 14 (or an unknown version), where a predictive back gesture cannot be vetoed, the gate holds back the navigators' reports, tells the platform the framework does not handle back, and `MainActivity`'s own `OnBackPressedCallback`, switched on while locked (`setBackMovesTaskToBack` on the device channel, `AppBackgrounding.setBackMovesToBack`), moves the task to the back. Before Android 14 back always arrives as a pop, which the framework keeps handling.
- **App switcher and screenshots:**
  - Android 13+: `setRecentsScreenshotEnabled(false)` while the lock is on, with no Flutter cover, which would blank the app at every loss of focus.
  - Android 7–12 and iOS: the privacy cover while the app is inactive and the lock is on, not during a prompt or an excursion; best effort on Android, as the page says.
  - Block screenshots, a switch of its own, not tied to the lock (owner), Android only: `FLAG_SECURE` on the whole window, out of screenshots, screen recordings and Recents. `SecureDisplay` is reference-counted, so the switch and every `SecureHold` (one-time secrets, connection secrets) never clear each other. On iOS screenshots stay possible (owner); there `SecureDisplay` hides one-time and revealed connection secrets while the screen is recorded or mirrored ([D74](#d74-ios-phase-app-store-prerequisites-testflight-from-the-mac-photo-locations-capture-cover)).
- **Notification content** (reminders, due dates and activity):
  - Hide on the lock screen: Android posts with `NotificationVisibility.secret`, since `private` still shows the task title. iOS cannot be forced: the page says to set Show Previews to When Unlocked and opens the app's notification settings.
  - Never show task titles: "Task reminder", "Task due" and "New activity" with "Open Vikunja to see it", no project, name, comment or account label; the payloads stay, so a tap and Done work. The "Sign in again" notification holds no task data and stays as it is.
  - A change of the content or the lock reschedules every account (`reconcile(force: true)`, snoozes kept); schema v11 stores each row's `hidden_on_lock_screen` and `done_needs_unlock` and the diff compares them like the texts, so an entry another isolate scheduled with older settings is scheduled again by the next run; headless containers read the settings for every run. A change that shows less withdraws the account's delivered reminders and activity notifications; nothing is posted again.
  - iOS: every `initialize` registers `task` and `task_locked`; while the lock is on, notifications use `task_locked`, whose Done has `authenticationRequired`; the snoozes stay plain.
- **Widgets:** with "Show task titles in widgets" off, a snapshot keeps its title, count, links and "+" but has no rows, "+N more" or due instants, and a non-empty list shows the count and "Open Vikunja to see them", so there is no Done; the publishers republish on a change and delete the account's other snapshots. On iOS the widgets always mark their rows privacy-sensitive and Done asks for the unlock ([D63](#d63-home-screen-widgets-app-written-snapshots-glance-on-android-widgetkit-on-ios)). Android widgets are home-screen only, so their Done stays.
- **Settings UI** (`features/privacy/`): the Account tab's Privacy section (on this device) has "App lock and privacy" with "App lock: Off" or "App lock: On · after 1 minute" and opens `/home/privacy`, open to guests: the app lock switch, "Lock after" while it is on ("Vikunja always locks after a restart"), a line on the app switcher (best effort on Android 12 and older or an unknown version), Block screenshots on Android, the three notification choices (on iOS with the hint and the settings button for "Hide on the lock screen") and the widget titles switch; failures show under the switches, announced.
- Dependencies: `local_auth: ^3.0.2` (with `local_auth_android` 2.3.0 and `local_auth_darwin` 2.0.5), `local_auth_android: ^2.3.0` named directly for `AndroidAuthMessages`, and `androidx.appcompat:appcompat:1.8.0` declared, because biometric 1.1.0 would otherwise pull in 1.2.0.
- No settings value, prompt text or task title is logged: failures by type, local_auth's by its code name, an unreadable value by the error's type.

Limits:
- On Android 12 and older the app-switcher cover is best effort, and there and on iOS it also shows whenever the app becomes inactive (the shade, split screen, Control Center).
- With unreadable settings the page shows "off" although the app is locked for that launch.
- Once Android has dropped a prompt silently, local_auth stays in progress until the app restarts; the lock screen says so.
- With "Immediately": cancelling the turn-off prompt's PIN screen on Android 7–10 locks the app; Android relaunching the activity in sight (system colours, contrast, wallpaper) locks and prompts.
- A background run that started before a change finishes with the old settings; switching back to "Show everything" brings no withdrawn notification back; the Account tab's test notification ignores the settings.
- A launcher that answers the pin request but shows nothing leaves no lock for up to 10 minutes.
- Android cannot ask for the unlock per notification action with this plugin; with "Hide on the lock screen" the actions are not on the secure lock screen at all.
- No per-account settings and no PIN of the app's own.
- Waiting for the iOS device test: the passcode, Done asking for the unlock, and the redaction on the lock screen and in StandBy.

## D65: Connection settings per server address, applied in the app's transport

*Accepted 2026-10-27 (step 35b).*

**Where they apply:**
- Settings belong to an origin (`OriginKey`: scheme, lower-case host, effective port, e.g. `https://host:443`, IPv6 in brackets): a pinned server certificate or a trusted CA certificate, a client certificate, access headers, and the consent to unencrypted connections. Two servers under one origin share them, and the connector's `:3456` candidate is another origin.
- `createDio(…, profiles:)` wraps the platform adapter in a `NetworkProfileAdapter`. `dioProvider` and `authDioProvider` each own one over the shared `networkProfilesProvider`, so an edit changes the table in place and never rebuilds a `Dio`, which would tear down running syncs; the account `Dio`s borrow the adapter. Below the retry, auth and log interceptors, nothing above the transport ever holds a header value. The base `Dio`s set `followRedirects: false`, because `dart:io` would copy access headers to a cross-origin redirect target. The four containers (the UI, the background runs, the notification actions, the widget worker) need no override: each loads the table on its first request.
- Per request:
  - An `http` origin without consent: only the pre-consent probe passes (marked `preConsentProbeKey`, a `GET` of `/api/v1/info` or `/api/v2/info` without `Authorization`), without any part of the profile; anything else fails with `CleartextBlockedException`.
  - No settings, only a consent or only headers: the platform adapter (Cronet, NSURLSession), with the headers merged in (a header the request has wins, ignoring case).
  - A pin, a CA or a client certificate: a `dart:io` `IOHttpClientAdapter` per origin, cached by revision and settings, its `SecurityContext` checked on creation; a replaced one closes without force, so requests in flight finish, and a request that meets an adapter already closed is sent once more on the current one. Only `dart:io` can pin in the handshake or present a client certificate; it brings HTTP/1.1, no OS proxy and no Android user CAs, which is why header-only origins stay native.
  - Errors leave with the caller's own request options, which never held a header value; the app's own exceptions pass as they are. A `FormatException` or `ArgumentError` on a request with headers means a stored value was refused ("needs re-entry"); any other error quoting a stored header value or password of 8 characters or more keeps its kind and loses its text (`secret_scrubbing.dart`); shorter values turn up by chance in ports, errno numbers and host names.

**Pin or CA:**
- The pin is the SHA-256 of the leaf certificate's DER, checked in the TLS handshake (a context without system roots, so `badCertificateCallback` sees every leaf before any HTTP byte), never with dio's `validateCertificate`, which runs after the request was sent. Only the origin's own host and port with the pinned hash pass. Any other leaf is recorded as the origin's last mismatch (fingerprint, subject, issuer, validity and when it was seen; once per certificate; the revision stays) and fails the handshake like any rejected certificate; nothing is trusted automatically. A changed certificate thus stops every request to its server until the user reviews it.
- A CA certificate (PEM, at most 64 KB, no private key) can be trusted instead, for short-lived leaves and for client-certificate servers on a private CA. It is checked against the server before it is saved (`CertificateProbe.verifyWithCa`): trusted; not issued by it, with the offer to trust the server's leaf; not checkable, with "Save anyway"; not a certificate. The editor says that on iPhone and iPad the leaf must name the server and be valid for at most 825 days. For header-only and plain private-CA servers, which keep the native adapter, installing the CA in the OS stays the advice.
- A pin and a CA exclude each other, since the CA would verify the chain before the pin is asked.

**Client certificate:** a `.p12` or `.pfx` (legacy format too) of at most 64 KB from the document picker, validated by building a context as the transport will, else "Wrong password or unsupported file"; the picker's cached copy is always deleted. Its file password is stored with it, because `dart:io` needs it for every context; it is no account password ([D14](#d14-browser-sign-in-only)). The page says that the certificate is presented only to its origin, that the key and password stay encrypted on the device, and that a server certificate from a private CA needs that CA or a pin in the app too, because certificates installed in the device settings do not apply to `dart:io`. Picking a certificate file does not lock the app ([D64](#d64-app-lock-over-the-ui-and-device-privacy-settings)).

**Access headers:** at most 10. A name is an RFC 7230 token, unique ignoring case, and none the stack, Vikunja or the socket set (`Host`, `Authorization`, `Cookie`, `Content-Length`, `Content-Type`, `Content-Encoding`, `Transfer-Encoding`, `Connection`, `Upgrade`, `User-Agent`, `Accept`, `Accept-Encoding`, `Origin`, `Range`, `If-Range`, `Expect`, `TE`, `Trailer`, `Keep-Alive`, `Cache-Control`, every `Proxy-*` and `Sec-*`). A value is stored trimmed and may hold only visible ASCII, spaces and tabs inside, at most 4 KB ("Only visible ASCII characters are allowed"). Only the names in the metadata are sent, and only to their own origin. Presets: "Cloudflare Access service token" (`CF-Access-Client-Id`, `CF-Access-Client-Secret`) and "Custom header". A Cloudflare Access app that allows only service tokens lets guests in but no browser sign-in, as the editor says.

**Unencrypted connections** need a consent per origin, enforced in the transport for requests and `ws://`:
- "Continue anyway" records it before the connection goes on; a consent that cannot be written ends in the unexpected-failure text, never in a request. On its first load the table gives it once to every registry account, user or guest, on an `http` origin without an entry (`cleartextMigrated`); it never changes an existing entry, so a revoke stays.
- The Connection screen of an `http` origin offers "Revoke" (its accounts stop working) or "Allow unencrypted connection". Headers can be added only with the consent, noted as travelling unencrypted; headers stored before a revoke stay listed as not sent, with Remove.
- No `http` account is upgraded to `https`, since the account id derives from the root ([D25](#d25-account-registry-in-sharedpreferences-without-secrets)).

**Storage** (`NetworkProfiles`):
- Metadata in preferences under `network.profiles` (JSON, `schemaVersion: 1`, `cleartextMigrated`, a revision counter): per origin key the pin with the certificate's details and `trustedAt`, the CA certificate's file name, PEM (public, so not a secret) and import date, the client certificate's file name and import date, the header names, `cleartextConsentAt`, `lastPinMismatch`, and a revision that grows with every edit and is never reused for an origin forgotten and set up again. Unknown fields and entries are written back as they were.
- Secrets in secure storage as `network_profile.<id>.secrets` (the first 32 hex characters of the origin key's SHA-256, since secure storage cannot be listed): the header values, the PKCS#12 file and its password, written before the metadata and deleted after it. Settings with only a pin, a CA or a consent never read secure storage, so they work before the first unlock.
- Storage is the truth across isolates: every write reads afresh under a lock and changes only its origin; the metadata is cached for at most 30 s or until this isolate writes, successful secret reads per origin and revision.

**Fail closed:** no request leaves without its origin's settings.
- Storage not readable (before the first unlock, or a platform error): `ConnectionProfileLockedException`, transient, read again after 5 s at the earliest and failing fast meanwhile; the text says "not available until the device has been unlocked once", never "locked", which is the app lock's word.
- Damaged metadata (not JSON, a newer schema, an unreadable entry, a pin with a CA): `ConnectionProfilesDamagedException` for every origin until "Reset connection settings", which first writes empty settings, then deletes the secrets of every origin it can name (the old settings' and the registry accounts'), and gives no consent again. A read that fails is not damage.
- Missing or broken secrets, or a context `dart:io` refuses: `ConnectionProfileIncompleteException`, "needs re-entry".
- The five exceptions (with `CleartextBlockedException` and `ClientCertificateRefusedException`) print only class and origin and map by type to `ConnectionSettingsFailure` or `TlsFailure(clientCertificateRefused: true)`, neither connection-level, so the connector stops at the `https` address and never tries `http`. After the connect they are `NetworkFailure`s with the problems `clientCertificate`, `cleartextBlocked`, `profileLocked`, `profileIncomplete` and `profileDamaged`: queued writes stay queued, since nothing left the device; the retry interceptor retries neither them nor `tls`; a failure card shows them, not the offline banner or notices.

**Client-certificate refusals** are recognised by Chromium's `ERR_BAD_SSL_CLIENT_AUTH_CERT` and `ERR_SSL_CLIENT_AUTH_CERT_NEEDED` (Cronet's -117 and -110), NSURLErrorDomain -1205 and -1206 (not read as a rejected server certificate), and the received alerts `TLSV1_ALERT_CERTIFICATE_REQUIRED`, `TLSV1_ALERT_UNKNOWN_CA`, `TLSV1_ALERT_ACCESS_DENIED`, `SSLV3_ALERT_BAD_CERTIFICATE`, `SSLV3_ALERT_UNSUPPORTED_CERTIFICATE` and `SSLV3_ALERT_CERTIFICATE_REVOKED`, `_EXPIRED`, `_UNKNOWN`; never `SSLV3_ALERT_HANDSHAKE_FAILURE`, which any mismatch sends. On `dart:io`, where TLS 1.3 reports a refusal only on the first read, an `HttpException` before the response starts a check without HTTP: a second handshake (`SecureSocket` with the profile's own context and pin check, 5 s), then up to 3 s for the server to hang up. A server that ends that connection, or a handshake failing with one of the alerts, confirms it (`ClientCertificateRefusedException`, kept 10 s per origin); data, silence or a socket error do not, and the original error stands. It runs for every `https` origin on `dart:io`, so a client-certificate server is recognised before a certificate is stored.

**Realtime** (`ProfileRealtimeConnector` in `core/realtime/realtime_providers.dart`): each upgrade gets the consent for `ws://`, the headers (the socket's own win, the app's `User-Agent` last) and, for a pin, a CA or a client certificate, a `dart:io` client from the profile (`IoRealtimeConnector(createHttpClient:)`). Errors follow the adapter's rules; one naming a client-certificate alert becomes `ClientCertificateRefusedException`. On any of the five exceptions the socket gives up until the next resume. `realtimeConnectionProvider` waits until the origin's settings were read once and restarts the socket after every edit or revoke, not after a recorded mismatch; [D46](#d46-realtime-one-websocket-for-the-active-account-in-the-foreground)'s polling stays the fallback. Link-share guests have no socket ([D62](#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind)).

**Screens:**
- Connect screen: a failure the settings can fix gets its action on the error card, also for a shared link or an invite: a rejected certificate "View certificate" (the trust page, or the review when the origin has a pin); a refused client certificate "Add client certificate" ("Replace client certificate" when one is stored); a login proxy (`BehindLoginProxy`, or `NotAVikunjaServer` with 401 or 403) "Add access headers"; settings needing re-entry "Open connection settings"; settings not available yet only the text and Try again; damaged settings "Reset connection settings" after a confirmation. The controller keeps the target (an address, a shared link, one with the server address typed for it, an invite) and runs it again once an editor saved (`retryAfterConnectionChange`), so a shared link opens as a guest without being sent again. "Connection options" under the address field opens the typed origin's settings ("Settings for https://host:443", disabled while the address is invalid) and says "Saved settings" where some exist, which is how settings without an account are found.
- Connection screen `/connection?origin=…`, a top-level route no redirect touches, signed in or not: from "Connection" in the Account tab's Server section (users and guests; it shows what is stored or needs attention), the Connect screen and every "Open connection settings" (data failure cards, sync status, first-sync screen, server overview, guest banner). An `https` origin shows the trusted certificate with its fingerprint and date or the trusted CA, or "Check the server's certificate"; the client certificate's file name and date with Replace and Remove; the header names with hidden values, Edit and Remove; Forget, whose confirmation says the accounts there stop working until the settings are entered again and that the consent goes too. Removing a trust, a client certificate or the headers asks first. Damaged settings show only the notice and the reset; settings not available yet the text and Try again.
- The trust page shows the origin; the SHA-256 as 32 hex pairs in rows of four, selectable, with a plain copy and one screen-reader label; issued to and by ("Self-signed"); the validity, with a warning when expired or not yet valid; the hint `openssl x509 -noout -fingerprint -sha256 -in cert.pem`; that the browser will warn as well and the app trusts it only for this origin; "Trust this certificate" and "Use a CA certificate instead", with a note when one replaces the other. A certificate valid for less than 100 days gets a warning and puts the CA first; one the device already trusts gets a note and no filled Trust button.
- After a mismatch, "The server's certificate changed" leads to a review showing a fresh probe with the recorded certificate and whether they match: "Accept new certificate" pins the certificate probed now, never the recorded one, which may be old, and says so when they differ; "Keep current certificate" clears the record.
- Secret fields (header values, the file password) are hidden, without suggestions, autocorrect or autofill, take a paste but offer no copy or cut, and hold `SecureDisplay` while shown ([D64](#d64-app-lock-over-the-ui-and-device-privacy-settings)).
- Before the browser sign-in (`confirmBrowserLeg`, which the sign-in controller asks through `browserLegConfirmation` after "Continue to sign-in" and at the four places with "Sign in again", and merged into the question of "Create account"), for the API's origin and the sign-in page's origin ([D23](#d23-browser-sign-in-through-flutter_web_auth_2-in-an-ephemeral-session)'s `frontend_url` when usable): the pinned fingerprint to compare when the sign-in page's origin is pinned, a note that the browser may warn when it trusts a CA, the client-certificate note ("the browser needs the client certificate installed in the device settings too, or the sign-in page must be reachable without it"), "the browser goes through the access login itself" for headers, and "Sign-in opens host" when the origins differ, with Continue and Cancel; nothing without a pin, CA, client certificate or headers (a consent alone needs no hint).
  - When [D23](#d23-browser-sign-in-through-flutter_web_auth_2-in-an-ephemeral-session) asks about a sign-in page on another origin, the same dialog carries the question: "Sign in at {host}?", the warning first, the hint after it without its "Sign-in opens host" note, and Sign in in place of Continue. "Create account" puts the warning first in its own question.
  - "Sign in again" asks after its new negotiation, about the page that negotiation gives, so its button shows the progress behind the dialog.
- Removing the last account, user or guest, of an origin offers in its confirmation "Also forget this server's connection settings" (on), listing what is stored ("Unencrypted connections allowed", "Trusted certificate, Access headers"), only when settings exist and no other account uses the origin. `SignOutController.signOut(…, forgetConnectionSettings:)` forgets them after the sign-out, only when still no account uses the origin; a failure is logged by type and never blocks the sign-out. The checkbox is adaptive, because the Material one asserts in a Cupertino dialog. Settings made without an account stay until forgotten.

**Logs:** no header value, certificate byte or password, failures by type; `ProfileSecrets` appears in no `toString` and no metadata JSON; redaction knows `CF-Access-Client-Id`, `CF-Access-Client-Secret` and `CF-Access-Token`, since a 32-hex id is too short for the rule on long runs.

**Test certificates:** the unit tests use a committed dummy set in `app/test/fixtures/tls/` (no CA keys; `fixtures_expiry_test.dart` fails 60 days before the 820-day CA-chained leaf expires); the opt-in Docker `tls` profile generates its own with `tool/gen_tls_test_certs.sh` into the gitignored `test_servers/tls/generated/` ([README](../test_servers/tls/README.md)).

Limits:
- The browser legs (sign-in, "Sign in again", "Create account", the web pages the app opens) do not use the settings: a pinned or private-CA server shows the browser's warning at every sign-in, as the browser session is ephemeral ([D23](#d23-browser-sign-in-through-flutter_web_auth_2-in-an-ephemeral-session)), and the password typed there is protected only by the user's check; a client-certificate server needs the certificate in the OS for the browser too; an access proxy shows its own login in the browser every time, and a service-token-only one leaves only guests.
- The hint finds the sign-in page's origin through `webFrontendBase` without converting an internationalised host to punycode, so for such a server with settings it can add a wrong "Sign-in opens host" note and miss the settings of the page's origin; [D23](#d23-browser-sign-in-through-flutter_web_auth_2-in-an-ephemeral-session)'s warning compares the punycode form.
- A header-only origin behind a private CA keeps the socket on `dart:io`'s default trust, so on Android realtime polls; trusting the CA in the app fixes it.
- The socket knows a refused client certificate only by the alert; a server that just closes leaves it retrying.
- Cronet's and NSURLSession's client-certificate texts are unrecorded and nginx's HTTP 400 after the handshake is not classified; "Connection options" still leads to the settings. On Android the trust page cannot see a user CA that already trusts the certificate.
- A background run in flight during an edit fails once; a hanging settings write blocks its isolate's later writes.
- After a reset `http` accounts need the consent again, and secrets of origins nobody names stay in secure storage.
- Not offered: SPKI pins, `Proxy-Authorization`, a list of all stored settings, a client certificate from the OS key store, user CAs for `dart:io`.
- Waiting for the iOS device test: pinning and PKCS#12 under SecTrust, CA trust under the 825-day rule, headers through NSURLSession, the browser's certificate warning; the app's own TLS through `HttpClient.connectionFactory` stays in reserve should it find a gap.

## D66: Threat model, redacted errors, no backups, keyed widget and notification links

*Accepted 2026-10-27 (step 35c), the owner's decision where marked.*

- The threat model is [threat-model.md](threat-model.md). Its residual and accepted risks ([§7](threat-model.md#7-residual-and-accepted-risks)) are the list of known gaps, and its rules for a later diagnostics buffer ([§10](threat-model.md#10-constraints-for-the-later-diagnostics-buffer)) bind the diagnostics export, which the owner postponed ([D20](#d20-scope-cuts-and-mobile-forms-of-desktop-features)). The support details of D20 keep no log and are no such buffer, but follow its rules on content and on sharing (below).
- **Uncaught errors:** `configureLogging` (`bootstrap/logging_setup.dart`, called by all four entry points: the UI, the background runs, the notification actions, the widget worker) installs `FlutterError.onError` and `PlatformDispatcher.instance.onError` in every build (why: Flutter's default handler prints an error's details unredacted, in release builds too).
  - Both log through `Logger('Flutter')` and `Logger('Uncaught')`, redacted when the record is made. A release build prints nothing (`Level.OFF`); a debug build prints the redacted line and up to 20 stack frames. `FlutterError.presentError` is never called.
  - Each hook catches everything (a text that cannot be built becomes the error's type), and the dispatcher hook always returns true, so the engine never prints the error itself. Debug builds thus lose Flutter's diagnostics tree; their stack frames are not redacted.
- **Redaction** (`core/logging/redaction.dart`) also covers e-mail addresses (in free text, as a JSON key and as `email=`), `invite-link=`, `share-auth-token=`, a URL's fragment, the widget-link key (`?k=`, `&k=`, `"k":`), and a JWT or JSON secret cut off as a `FormatException` quotes it.
- **No content in logs:** `Task` prints its id and identifier in `toString`, `Project`, `Label` and `TaskAttachment` their id, `ProjectView` its id and kind; `Account`, `User` and `UserProfile` keep the username, `ParsedTaskText` and `IndentedLine` their text for test diffs. No log call interpolates any of these, a secret, content, a link or a person; Kotlin logs failure types only, the Swift nothing (checked by `app/test/security/log_hygiene_test.dart`).
- **Support details** ([D20](#d20-scope-cuts-and-mobile-forms-of-desktop-features)): built from what the app stores, never from logs, when their page opens; kept only while it is open; they leave the device only when the user shares them, after seeing them. They name no person, content or id (the threat model's buffer rule 3); hosts appear only while the user's switch is on, through `describeUriForLog`, so without user info, query, fragment or a link share's hash; an outbox failure is read through a list of its keys (kind, problem, reason, code, HTTP status), so never its message; the whole text goes through `redactSecrets` last. `app/test/security/token_leak_test.dart` builds them from accounts, a queue and failures full of secrets, names, titles and addresses and finds none of them, and no host while the switch is off. The last session end is stored as three fields only (reason, part of the app, time).
- **Backups, Android** (owner): `android:allowBackup="false"` and `android:dataExtractionRules="@xml/data_extraction_rules"`, which exclude all nine domains with `path="."` in `<cloud-backup>` and in `<device-transfer>`, with no `<include>` and no `<cross-platform-transfer>` (why: on Android 12 and later `allowBackup="false"` stops only cloud backup, and on some devices not a device-to-device transfer). No `fullBackupContent`: below Android 12 (minSdk 24) `allowBackup="false"` covers both.
- **Backups, iOS** (owner): `excludeAppDataFromBackup` (`core/platform/backup_exclusion.dart`) sets `isExcludedFromBackup` on `<application support>/accounts` (the databases and queued uploads) and on the App Group's `widgets/` folder (snapshots, catalogs, configs, `outbox/`, `requests/`, `host.json`), nothing else. `bootstrap.dart` calls it after the first frame of every UI start, because a restore or a move can clear the mark; best effort, a failure logged by its type. The preferences stay in iOS backups.
- **Keychain and entitlements:** every secret stays in the Keychain or the Keystore ([D24](#d24-tokens-in-secure-storage-readable-after-the-first-unlock)). Static tests pin the options of `secure_store.dart` (`first_unlock_this_device`, not synchronizable, no Secure Enclave) and both iOS targets' entitlements (the App Group only, no keychain access group).
- **The app's iOS channel** `io.vikunja.app/device` (in review) (`DeviceChannel` in `app/ios/Runner/AppDelegate.swift`) is registered in `didInitializeImplicitFlutterEngine`, so only the UI engine has it. Its `excludeFromBackup` names an error by its type, never a path. Its `backgroundState` (Background App Refresh and Low Power Mode, for the support details) logs nothing, and so does Android's.
- **Sensitive clipboard:** the one-time secrets of [D55](#d55-security-settings-two-factor-status-sessions-and-tokens-a-new-token-shown-once) and copied share links go through `PlatformSensitiveClipboard`: on Android with `IS_SENSITIVE`, on iOS through `copySensitive` (`localOnly`, expiring after 120 s), with a plain copy, logged by type, when the channel does not answer.
- **Routes pushed by the platform** (`app/router/app_router.dart`): `_AppSchemeLinks`, registered before go_router's own observer, takes every pushed route: a URI of the app's scheme goes to the deep-link relay, anything else (another scheme, a bare path) is dropped. The top-level redirect sends a location with a scheme or a host to the splash. Why: Android's embedding pushes the data of any intent that reaches the exported `MainActivity` as a route.
  - So no platform route reaches go_router; push futures that never complete and dropped `extra`s come from go_router decoding its route list again, as on a state restoration (flutter/flutter#128122).
- **The widget-link key** (`core/links/widget_link_key.dart`): `widgets.link_key` in preferences, 32 bytes from `Random.secure()` in base64url without padding, compared in constant time after decoding (`widgetLinkKeyMatches`, false for a missing, malformed or wrong key). Why: any app, and on iOS any web page, can send a widget link, so a link alone must not switch accounts.
  - Only the UI start creates it, in `bootstrap.dart` before the registry's first read sets the install marker: a new key without the marker, else the stored one, replaced only when missing or broken. The headless containers only read it, and without one build links and payloads without it. Neither the key nor a link is logged. A fresh install gets a new key; an iOS restore brings the old one back.
  - Carried as `k`: `WidgetLink.linkKey`, every link of the Dart snapshot builder, and for the links Kotlin and Swift build without a snapshot (setup, Open, New task; on iOS also task and list links) the `linkKey` in `widgets/host.json`, which only the UI writes. Links built before the app has written `host.json` carry none.
  - Without the right key (`WidgetLinkListener`): a task link goes through the task-link flow of [D44](#d44-task-detail-own-rich-text-parser-online-details-app-scheme-links), which asks before it switches; list, Account tab, Open and New task links act only when they name no account or the active one; `widget/configure` needs no key.
- **The key in notification taps:** `NotificationPayload.linkKey`, written as `k`, optional when read; the scheduler, the activity notifier and the test notification add it when there is one (why: on Android any app can send `MainActivity` a made-up `SELECT_NOTIFICATION` tap). Without the right key a tap never switches accounts and marks nothing read: a payload naming a task (an id other than 0) goes through the task-link flow; session, inbox and test taps and task-less activities open only in the active account. Notification actions need no key (their receivers are not exported).
- **Exported components:** `tool/check_exported_components.py` (run with `python3 -I`) compares the exported activities, aliases, receivers, services and providers of the merged release manifest (`exported="true"`, or an intent filter without `exported="false"`; any other value fails), each with its permission and intent filters, with its allowlist; an addition, removal or change fails, and so do an `allowBackup` other than `false` and a missing rules attribute. The allowlist has 11 components: 7 open (`MainActivity`, `TaskLinkActivity`, `ShareTargetActivity`, flutter_web_auth_2's `CallbackActivity`, `WidgetConfigureActivity`, the two widget receivers) and 4 behind a permission (Glance's `GlanceRemoteViewsService` behind `BIND_REMOTEVIEWS`, WorkManager's `SystemJobService` behind `BIND_JOB_SERVICE`, its `DiagnosticsReceiver` and the `ProfileInstallReceiver` behind `DUMP`). CI runs it after the release build ([D73](#d73-gitlab-ci-from-local-scripts-versions-from-the-tag-release-signing)).
- **The editor WebView** ([D52](#d52-descriptions-edited-in-a-locked-down-tiptap-webview-never-silently-overwritten)) keeps its per-load channel token instead of an origin check; tests pin that a `window.open` main-frame navigation is prevented and the page's CSP (its `script-src` hash, no network load).
- **Dependencies** (the CI jobs are [D73](#d73-gitlab-ci-from-local-scripts-versions-from-the-tag-release-signing)'s): an OSV scan of `pubspec.lock`, `app/editor/package-lock.json` and `app/android/app/gradle.lockfile`, also weekly, with accepted advisories in `osv-scanner.toml`, each with a reason and an `ignoreUntil` (none now); `npm audit --package-lock-only --audit-level=high` for the editor; `flutter pub outdated` for information only.
  - The Gradle wrapper pins `distributionSha256Sum` of `gradle-9.3.1-all.zip`, which it checks only when it downloads the distribution. Gradle locks the `*RuntimeClasspath` configurations of `:app` without `io.flutter:*` (why: the tooling classpaths change with every Android Gradle plugin update and never ship, the engine's artifacts with every Flutter version); after a change, `./gradlew :app:dependencies --write-locks` in `app/android`.
- Extensions, widgets and the notification-action isolate never refresh user tokens; a guest token may be renewed there, and a guest is signed in again at most once per container ([D62](#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind); principle 5 of the [architecture](architecture.md#1-principles)).

Limits:
- iOS backups still hold the preferences: drafts, the account registry, the confirmed sign-in hosts ([D23](#d23-browser-sign-in-through-flutter_web_auth_2-in-an-ephemeral-session)), the connection metadata of [D65](#d65-connection-settings-per-server-address-applied-in-the-apps-transport), the privacy settings, the install marker, the widget-link key and each account's last session end ([D20](#d20-scope-cuts-and-mobile-forms-of-desktop-features)). Restored to a new device, accounts need a new sign-in and settings with secrets re-entry; restored to the same device from an encrypted backup, the `ThisDeviceOnly` Keychain items come back too and the databases sync again. Whether the drafts leave the preferences is open with the owner (R21 to R23).
- The widget host can act as the app through Glance's collection template for the list rows, and it sees the key (R17): accepted for the beta (owner, 2026-11-12), as for every app with a Glance list, and reported to Google; if Glance does not change, the owner chooses before 1.0 between a fixed list with "+N more" and a hand-built scrolling list.
- An app that starts `MainActivity` from its own activity without `FLAG_ACTIVITY_NEW_TASK` gets a second UI engine in its task (R33).
- Keyless links still act in the active account; notifications scheduled before step 35c stay keyless until replaced, and their taps ask or do nothing (R18, R19).
- Outside the hooks: the drift database isolate, errors before `configureLogging`, plugins' own prints and native logs (R24). No redaction at capture, as there is no log buffer yet.
- No automated dependency updates; native code that no lockfile describes (SQLite, the Flutter engine and Dart runtime, Cronet) is followed by hand (R26).
- Not checked on an iOS device yet: the sensitive clipboard, the key in `host.json` and the extension's links, another account's notification tap ([threat-model.md §8.3](threat-model.md#83-final-ios-phase)).

## D67: AGPL-3.0-or-later with an app store permission, DCO, reserved brand, embedded Cronet

*Accepted 2026-10-27 (the licence step between steps 35 and 36), the owner's decision where marked; answers [Q3](open-questions.md#q3-licence-and-distribution).*

**Licence and contributions:**
- AGPL-3.0-or-later for the whole repository: the app, the packages, the plugin, the tools and the documentation (owner). `LICENSE` is the unchanged text from gnu.org (a test checks its SHA-256 `0d96a4ff…abcb0`).
- An additional permission under AGPL section 7, in the owner's words in `NOTICE.md` ("App stores"): distribution through an app store whose terms conflict with the AGPL, such as Apple's App Store, provided that the Corresponding Source is also available under the AGPL through a channel without such restrictions (owner).
- Contributions under the Developer Certificate of Origin 1.1: every commit, merges included, carries a `Signed-off-by:` with its author's name and email; contributors keep their copyright, and their contributions carry the same terms, the permission included (owner). The GitLab job `dco` checks merge requests ([D73](#d73-gitlab-ci-from-local-scripts-versions-from-the-tag-release-signing)).
- Copyright line: "Copyright (C) 2026 Benedikt Lesch and the Rurana contributors".
- The name "Rurana" and the llama logo are not under the AGPL: all rights reserved by Benedikt Lesch; a fork that distributes an app uses its own name and logo (owner). Since step 38a the app is called Vikunja and its icons come from Vikunja's logo ([D15](#d15-app-id-iovikunjaapp-and-the-name-vikunja), [D42](#d42-app-icon-vikunjas-logo-every-variant-derived-by-script)); the terms, the llama files and `NOTICE.md`'s file table, which still lists the regenerated icon files, stay until step 38d settles the terms for Vikunja's name and logo ([D83](#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp)) (in review).
  - The logo files may be copied unmodified only as part of a copy of the repository or of its history, or of an unmodified build of the app published by Benedikt Lesch; an app built from modified source may not be distributed with them (owner). `NOTICE.md` and the app's notice carry the owner's sentence verbatim and add that the files are listed in `NOTICE.md`; the README, `branding/README.md`, `CONTRIBUTING.md` and the About page say it in short.
- F-Droid is not a distribution target: no flavour, the bundled SQLite stays (owner).
- Android ships embedded Cronet, never a Play services library (owner; the build is [D5](#d5-dio-with-native_dio_adapter-and-embedded-cronet)'s), because then contributors' code is combined only with free software and needs no further permission.
- Nothing of Vikunja's ships: the app reads the web for behaviour and writes its own code and texts, error texts included ([D71](#d71-english-and-german-us-base-glossary-error-texts-live-language-changes)). Why: only copyright holders can grant the section 7 permission, and anyone may remove it from a part it does not cover.
  - The editor (`app/editor/src/extensions.js`, `links.js`) keeps only what the stored HTML needs: the node and attribute names, the task link's rank above the Link mark and its `a[href]` rule at priority 100, the plain-anchor conditions, `['a', attrs, href]`, an 8-character `data-task-id` per item, a positive integer `data-comment-id`, `data-src` with `src="#"` and `id="tiptap-image-<task>-<attachment>"`, and the attachment URL pattern.
  - MIT, BSD, ISC and Apache material is attributed. Test files with Vikunja's test vectors are AGPL only, without the permission, and never ship.
- `NOTICE.md` holds the copyright, the AGPL's "how to apply" notice, the permission, the brand files by glob, the third-party material and the test files with Vikunja vectors; `CONTRIBUTING.md` the DCO text. The packages and the plugin need no licence file of their own.
- AGPL section 13 does not apply: the app reaches its users as object code (section 6), and the Vikunja server is not part of this repository.

**What the app shows** (AGPL section 5(d)):
- The About page (`/about`, outside the shell, so for users, guests and signed out), from the Account tab's version line and, signed out, from a button on the Connect screen: the name, version and copyright line, the licence with the app store permission ("This app is free software…"), no warranty ("This app comes with no warranty…"), Licenses, the source code, the name and the logo; en and de; the title "About the app" (in review). Its website rows are [D76](#d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android)'s and [D77](#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)'s.
- The source link is `sourceCodeUrl` in `app/lib/app/legal.dart`, `String.fromEnvironment('SOURCE_CODE_URL')`, null when empty. Only the release builds set it: the GitLab release job (`$CI_PROJECT_URL`, [D73](#d73-gitlab-ci-from-local-scripts-versions-from-the-tag-release-signing)) and `tool/ci/ios_release.sh` ([D74](#d74-ios-phase-app-store-prerequisites-testflight-from-the-mac-photo-locations-capture-cover)); their release-only test `app/test/app/release_source_code_test.dart` (tag `release`) fails without it. Every other build says "This build has no link to its source code. Every release of the app links the source code it was built from." („Dieser Build hat keinen Link zu seinem Quellcode. Jede Veröffentlichung der App verlinkt den Quellcode, aus dem sie gebaut wurde.“) (in review).
- The repository is public before the first store release (AGPL section 6 and the permission's condition; the release job checks it, [D73](#d73-gitlab-ci-from-local-scripts-versions-from-the-tag-release-signing)).
- The licence page is Flutter's `LicensePage` in Flutter's own words, "Licenses" and „Lizenzen“ (in review: the British override of its English is gone, [D71](#d71-english-and-german-us-base-glossary-error-texts-live-language-changes)). `registerAppLicenses` (`core/legal/app_licenses.dart`) calls `LicenseRegistry.addLicense` once and reads committed assets only when the page asks:
  - under `vikunja_app` the app's notice (`assets/legal/vikunja_app.md`, worded as `NOTICE.md` below its own heading, compared by a test; in review) beside the AGPL from Flutter's build; the editor's npm packages (`app/assets/editor/NOTICES.md`); the code `vikunja_logic` translates (`packages/vikunja_logic/THIRD_PARTY_NOTICES.md`: fexpr, go-datemath, prosemirror-model); the Material Icons font and three copied icon shapes (CC BY 4.0); on Android only, `assets/legal/android.md` with the Android libraries and the code of other projects in embedded Cronet.
  - The workspace root package is named `vikunja_app` (in review; why: `vikunja` alone would read as the server), so Flutter lists the root `LICENSE` under it; no workspace member may carry a `LICENSE` or `NOTICES` file, which would appear under an internal name (a test checks it).
  - The written offer for desugar_jdk_libs (GPL-2.0 with the Classpath exception; core library desugaring, which flutter_local_notifications needs) runs for three years from Benedikt Lesch and ends "Ask Benedikt Lesch at coderoftime@gmail.com." (`WRITTEN_OFFER_CONTACT` in `tool/build_android_notices.py`); every release carries that library's source at its recorded commit ([D73](#d73-gitlab-ci-from-local-scripts-versions-from-the-tag-release-signing)).

**Notice generators** (both with `--check`, run in CI):
- `tool/build_editor.sh` writes `NOTICES.md` from what esbuild bundled and refuses a licence text with a line starting with three backticks, which would cut the text short on the licence page.
- `tool/build_android_notices.py` writes `app/assets/legal/android.md` from the lockfile's release classpath. It refuses unknown Maven groups, Google Play services (`com.google.android.gms`), a bundled "external" AndroidX artifact without an entry, fenced lines, any other `org.chromium.net` library, a stored Cronet licence that does not belong to the locked build, was edited or has another Chromium licence than `chromium.txt`, and a `source.json` that `--refresh-cronet` could not have written. It adds `CRONET_SUPPLEMENT`: libc++, libc++abi and libunwind (LLVM's `LICENSE.TXT` texts in `tool/android_notices/`) and Rust's standard library (MIT OR Apache-2.0), which Cronet's native library links statically but its licence files do not name.
  - `--refresh-cronet` copies `third_party_licenses.txt` and `.json` of the locked `cronet` and `cronet-bundled` AARs into `tool/android_notices/cronet/` with `source.json`, after these checks: exactly `cronet` and `cronet-bundled` of one version are locked; each AAR has the SHA-256 Google's Maven publishes; the build in the native library's name is the one in `cronet`'s `ImplVersion`, and Chromium Dash lists it at that commit as a Chrome stable release for Android; `NativeCronetProviderSentinel` is there; both AARs carry the same licence files, and the index covers the text exactly; the "Cronet" entry equals the Chromium bucket's `LICENSE` where the bucket has the build. Until Cronet changes, the check needs neither Gradle nor the network.

Limits:
- The owner has yet to confirm the written offer's wording ([beta.md](beta.md)).
- image_picker_android's manifest still declares the disabled `com.google.android.gms.metadata.ModuleDependencies` service, a hint for Play services; it names no class in the app.
- The DCO check covers merge requests only; a fork's merge request runs with the fork's configuration until a maintainer runs it in the project.

## D68: Screen readers: headings, one announcer, high contrast, Reduce Motion, route sweep

*Accepted 2026-10-28 (step 36a).*

- WCAG 2.2 AA is the internal yardstick, with the deviations below and no public conformance claim.
- **Headings:** level 1 for screen and sheet titles, app bar titles included; level 2 for section headers; the rich-text view keeps the description's h1–h6. Regions side by side each keep their level-1 title ([D70](#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere), [D82](#d82-projects-listdetail-the-project-tree-beside-the-project-on-wide-windows)).
  - `ScreenTitle` (`features/common/presentation/screen_title.dart`) is every app bar's title: `Semantics(headingLevel: 1)` around the text, which merges into the app bar's own title node, so the title stays one node (header, label, level 1 and on Android the route's name). It asserts in debug builds that it sits in an `AppBar` that marks its title. Why no `header: true` of its own: two header flags never merge and would leave an empty level-0 header.
  - Every other `header: true` names its `headingLevel` in the same `Semantics`: level 1 for the titles the app draws itself (the lock screen, the Overview's header, the sheets' titles, `PickerHeader`), level 2 for `ListSectionHeader` (and so `SectionCard` and `SettingsSection`), `FormSectionTitle`, `DetailSectionHeader`, `SectionHeading`, `EmptyState` and the like. An `EmptyState` that stands in for a screen without an app bar is level 1 (`isScreenTitle`) and names its route on Android.
  - `SectionSemantics` (`section_semantics.dart`, `explicitChildNodes`) wraps a heading and its section (`SettingsSection`, a titled `SectionCard`, Upcoming's days, the server message card, the task sheet's sections, the widgets page's group), so a heading never merges into a single row and becomes its button. Untitled cards stay merged.
  - Two headings stay buttons: the Account tab's account header and the task sheet's title, which opens the edit page. The team page has one heading with the team's name; its card shows the name as plain text.
  - The search page's field is no heading (`excludeHeaderSemantics`) but names the route on Android ("Search" and its hint).
- **One announcer** (`features/common/presentation/announce.dart`): every announcement goes through `announce(context, text)`, or `Announcer.of(context)` taken before an `await` and its `say(text)` after it.
  - Where the platform announces (`MediaQuery.supportsAnnounceOf`, so on iOS) it calls `SemanticsService.sendAnnouncement`; otherwise, on Android always, because the engine reports no announce support on any version, the text goes to `AnnouncerHost`. Without a host (a page alone in a widget test) it calls `sendAnnouncement`; it never throws.
  - `AnnouncerHost` is mounted once, as the direct child of `AppLockGate` in `MaterialApp.router`'s `builder`: a `Stack` of the app and a 1×1 polite live region (a container, focus blocked, no actions) painted after the routes, so no sheet or dialog hides it, while the lock and the privacy cover do. A repeated message is cleared for one frame and set again; the region empties 5 s after the last message.
  - An error already shown in a live region (a field's `errorText` where the platform cannot announce, a `FormErrorText`) is not announced again: `say(text, onlyIfPlatformAnnounces: true)`, and the app's region speaks it only when its text stays the same, such as the same input submitted again. Errors that are no live region keep the announcer.
- **High contrast** (`app/theme/app_theme.dart`): `AppTheme.highContrastLight` and `highContrastDark` are `MaterialApp.router`'s `highContrastTheme` and `highContrastDarkTheme`, so they apply whenever the platform reports `highContrast` (iOS Increase Contrast, Android 14+'s Contrast at medium or high). With brand colours they are `brandScheme` at contrast level 1 for each seeded part, keeping the amber tertiary, the neutral tones and `HighlightColors`; with system colours, a scheme seeded from the system's primary at contrast level 1, keeping the user's hue.
- **Reduce Motion** (`features/common/presentation/motion.dart`): `reduceMotionOf(context)` is true with Android's Remove animations (`disableAnimations`) or iOS Reduce Motion (`accessibilityFeatures.reduceMotion`, which `MediaQueryData` does not carry), read at call time. The app's own animations then jump: the board settling on a column and following a move, Gantt's "Go to today", the Android task sheet growing to full height (`jumpTo`, as the controller refuses a zero duration), the scroll to a comment, the filter suggestions, the connect screen's error card and the server overview's scroll to its error.
- **Text size:** no global clamp; iOS text up to 3.12× (AX5, 53/17) works on the six core screens: the Overview, a project list, the task sheet, the edit page, the new-task sheet and the Account tab.
  - App-bar text actions (`AppBarTextAction`: Save, Create, Upload) and the headers of the iOS picker and day-range sheets grow to 2.0× at most, as iOS's own navigation-bar buttons stop growing. Above 1.3× the picker sheet's title gets a line of its own above Cancel and Done, and both sheets stack their buttons when they do not fit; the day-range sheet's From/To text stops at 2.0×.
  - The navigation labels stay clamped, 1.15× on Android's bar ([D56](#d56-design-after-the-owners-mockups-blue-scheme-cards-one-task-row)) and 1.3× on the iOS tab bar and the rail ([D45](#d45-app-shell-colour-scheme-display-settings-projects-tab-smart-lists-offline-banner)); a long press shows the label as a tooltip.
- **Overdue** is not told by colour alone: `DueBadge` and the task sheet's due row show `Icons.error_outline` in the error colour instead of the calendar, as the home-screen widgets do, and the sheet's due row says "Overdue, due …" (`taskOverdueSemantics`).
- **Gantt** (`TimelineSemantics`): a row's label ends with "blocks …", "blocked by …", "precedes …" or "follows …" for the arrows the chart draws, at both ends; one text node over the header reads "Today, *date*; showing *range*".
- **Refresh buttons** (`RefreshButton`) in the app bars of the session, API token and CalDAV lists (why: many screen-reader and switch users cannot pull to refresh).
- **The iOS tab bar's** inactive labels are `onSurfaceVariant` (Cupertino's grey stays below 4.5:1).
- **Strings:** new and changed ARB keys get a description, starting with "Screen reader: " for strings that are only spoken; new plurals put the number in the singular branch as well (`=1{{count} task}`). Older keys get theirs in step 36f.

**Deviations from WCAG 2.2 AA:**
- 1.4.4 Resize Text, below 200 %: the navigation labels above; the inbox badge at 1.3× ([D74](#d74-ios-phase-app-store-prerequisites-testflight-from-the-mac-photo-locations-capture-cover)); the offline banner at 1.3×; Upcoming's date column at 1.3× (out of the semantics; the rows carry the dates) and its day strip at 1.5×; the Gantt header at 1.5× ([D61](#d61-table-as-a-detailed-list-gantt-as-a-read-only-timeline)); avatar initials, reaction emoji and inline pills unscaled; Flutter's app bar title at 1.34×, ellipsized when long and spoken in full.
- 2.5.7 Dragging Movements: moving a card within its column, a task in a manually sorted list or a project among its siblings takes a drag or a screen reader's custom actions ([D47](#d47-kanban-board-from-per-view-snapshots-moves-through-the-outbox), [D49](#d49-manual-ordering-lists-through-the-outbox-projects-online-no-position-below-01)). Single-pointer ways exist for a card's column (Move to column… in its task detail, [D84](#d84-everyday-editing-in-the-task-detail-properties-in-place-task-links-move-to-column)), a column's place (Move left, Move right), a project's parent and a task's project (the edit pages).
- 1.4.11 Non-text Contrast: the light brand scheme's amber highlight (the star's fill, the high-priority flag) is about 1.82:1 on the surface; it is supplementary (the star has a `tertiary` outline at 6.18:1, the flag stands beside the priority's name).
- 1.4.3 on iOS alerts: `CupertinoDialogAction` in Apple's system blue and red measures 2.86–4.40:1 on the alert's translucent material; under Increase Contrast the delete-task, sign-out and browser-hint alerts pass, while the insecure-connection alert's "Continue anyway" over the light connect screen stays at 4.23:1.
- Platform target sizes (2.5.8's 24 × 24 is met): the Material date picker's day cells are 43.4 × 48 dp on a 360 dp phone, where Android asks for 48 dp; Cupertino's sliding segmented control keeps its native 28 pt height, where Apple asks for 44 pt (the Account tab's Theme row on iOS, the day-range sheet's From/To).
- Read-only selectable text, such as the server's message of the day, is skipped by both tap-target guidelines (2.5.8's inline exception; [D69](#d69-large-screens-a-window-layout-helper-readable-widths-capped-dialogs-and-sheets)).
- Beyond AA, 2.3.3: under iOS Reduce Motion the page and sheet transitions still slide, because the framework follows only `disableAnimations`; the board's settle after a fling follows the finger.
- Flutter's `LicensePage` marks its titles as headers at level 0 (1.3.1, 2.4.6); fixing it takes a licence page of our own.
- A new field error with a helper text may be spoken twice on Android, because Material builds it again when its fade-in ends.
- Colour-coded text inside merged labels (due dates, priority, label pills) is checked at scheme level only: a unit test asks for 4.5:1 of the text roles on surface and surfaceContainerHighest, 3:1 of outline on surfaceContainer and 4.5:1 of label pills over server colours, for the brand and high-contrast schemes, light and dark; dynamic schemes are not checked.

**The guard, a route sweep** (`app/test/a11y/`, run by CI's plain `flutter test`; [CONTRIBUTING.md](../CONTRIBUTING.md#merge-requests)):
- Every GoRoute with a builder needs a scenario (`route_walk.dart`), and a route that builds several screens needs one per variant (`/home/projects/:id` as list, Kanban, table, Gantt, favourites and saved filter; `/connection` for https, http and its editors); the redirect-only `/home` is skipped and `/splash` exempt. A route scenario must end on its GoRoute pattern and find its screen exactly once; a stale scenario, exemption or variant fails.
- Every call in `app/lib` of `showAdaptiveDialog`, `showDialog`, `showModalBottomSheet`, `showCupertinoSheet`, `showCupertinoModalPopup`, `showDatePicker`, `showTimePicker`, `showMenu`, `MenuAnchor`, `PopupMenuButton`, `MaterialPageRoute`, `CupertinoPageRoute` or `PageRouteBuilder` (`overlay_sites.dart`) needs an entry in `overlay_inventory.dart`: an overlay scenario or an exemption with its reason.
- Scenarios reach their screen through the router or the app's show functions, never by tapping text; `sweep_suites.dart` maps each `<name>_sweep_test.dart` to its scenarios, and no other sweep file is allowed.
- Each scenario runs on its platforms, light and dark, en and de, with the square test font, on the first frame and after each page of scrolling (up to 10 stops): the platform's tap-target guideline, labelled tap targets, text contrast, a heading level from 1 to 6 on every header (framework nodes included), headings that are no controls, image labels, unique action labels and distinct tap labels. Representative states (empty, error, offline, loading, locked, a guest) are swept too, and so are the tablet sizes, the task pane and the project tree's column ([D69](#d69-large-screens-a-window-layout-helper-readable-widths-capped-dialogs-and-sheets), [D70](#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere), [D82](#d82-projects-listdetail-the-project-tree-beside-the-project-on-wide-windows)).
- `text_scale_312_test.dart` runs the six core screens on iOS at 53/17 on 375 × 667 and 320 × 568, en and de, scrolled to their ends; any exception fails.
- `source_rules_test.dart`: every `header: true` names a `headingLevel` in the same call and the reverse (only `screen_title.dart` exempt); no `SemanticsService.sendAnnouncement` or `announce` outside `announce.dart`.

Limits:
- The manual TalkBack, Switch Access, Accessibility Scanner and VoiceOver pass is still open ([Q19](open-questions.md#q19-device-setup-for-the-manual-talkback-pass), [accessibility checklist](accessibility-checklist.md)): whether TalkBack speaks the live region reliably (right after a dialog closes, while it is speaking, a repeated message), board and list moves, a field error said twice, whether TalkBack enters the editor WebView, and real fonts.
- Text the Gantt painters draw may not follow iOS Bold Text (unconfirmed).
- The widget setup page's preview is read line by line under its "Preview" heading.
- Tables in descriptions carry no row and column positions.

## D69: Large screens: a window-layout helper, readable widths, capped dialogs and sheets

*Accepted 2026-10-28 (step 36b).*

- **One window-layout helper** (`app/lib/app/layout/window_layout.dart`): `WindowLayout.of(context)`, from `MediaQuery.sizeOf`, with Material 3's width classes (`WindowSizeClass.compact` below 600 dp, `medium` 600–839, `expanded` from 840), `compactHeight` (below 480), `expandedHeight` (from 900), `twoPane` (at least 840 wide and not compact in height, [D70](#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere)), `threePane(besideRail:)` ([D82](#d82-projects-listdetail-the-project-tree-beside-the-project-on-wide-windows)) and `capsWidths`. Every window threshold of the app is a constant there.
  - The navigation rail stays from 600 dp ([D45](#d45-app-shell-colour-scheme-display-settings-projects-tab-smart-lists-offline-banner)); the iPad keeps the bottom `CupertinoTabBar`, with no sidebar.
  - Widgets that size themselves read their own constraints, not the window: `ListSectionHeader`'s trailing text takes at most 40 % of the header's width, `TimelineChart` hands its own width to `TimelineHeader` and `TimelineRow`, and a row lifted to be dragged measures the content.
- **The gate** (`capsWidths`): every cap applies only when the window is at least 480 dp high and either at least 840 dp wide or at least 900 dp high. Why: every large phone in landscape is at least 840 dp wide but less than 480 dp high. So phones in either orientation and the 800 × 600 test surface look as before.
- **Readable widths** (`app/lib/app/layout/readable_width.dart`): `ReadableWidth.list` (840), `form` (640), `sheet` (640), `dialog` (560) and `defaultDialogConstraints` (at least 280, Flutter's own). The widths include the cards' 16 dp margins, so a card is 808 or 608 dp wide.
  - **840 dp:** the Overview, Upcoming, the project tree, a project's List and Table views in every state, favourites and saved filters, a label's tasks, search, the inbox and the trash (`/home/trash`, [D79](#d79-the-trash-of-vikunja-280-undo-queued-deletes-a-trash-page)); and for every view of a project its tabs, its progress line and the controls under them, so they do not move when the view changes.
  - **640 dp:** the Account tab (guests too); account settings, the avatar and its crop, sessions, API tokens, CalDAV and the data export, the API token form and its one-time secret; the connection pages; privacy; About (not the licence page); the widgets page and widget setup; labels and the label form, teams and a team; project edit, views and share; the saved-filter form; task edit; the server overview, whose pinned actions follow the band.
  - **Their own caps:** the connect screen (480 dp), first sync, the notification setup and the lock screen (420 dp).
  - **The whole width:** app bars with their progress bars, the offline banner, snackbars, the floating action buttons at the window's bottom right, the board with its notes, the Gantt timeline, the description and comment editors, the image viewer and Flutter's licence page.
  - `app/test/a11y/readable_widths.dart` gives every route scenario of the sweep ([D68](#d68-screen-readers-headings-one-announcer-high-contrast-reduce-motion-route-sweep)) its class, and the sweep checks it.
- **How the band is made:** the content is centred and the scroll view keeps the whole width, so the margins scroll and the scrollbar and the refresh and overscroll indicators stay at the window's edge; no scroll view sits in a `ConstrainedBox`, `Align` or `Center`.
  - The inset on each side is max(0, (available − max) / 2) while `capsWidths`, else 0; `available` is the scroll view's own width (beside the Android rail the window less the rail). The gate comes from the window, the amount from the constraints. The inset adds to a screen's safe-area padding.
  - `ReadableWidth` pads a box; `ReadableWidth.builder` hands the width and the inset to a `ListView` or `SingleChildScrollView`, which adds the media query's top and bottom padding back; `SliverReadableWidth` (`.group` around a `SliverMainAxisGroup`) pads the slivers of a `CustomScrollView`. `CenteredScrollView` and `RefreshableList.buildRefreshable` take a `maxWidth`, so the loading, empty and failure states share the band.
  - The wrappers stay in the tree with no inset while the gate is off, so a rotation across the gate keeps every screen's state.
  - The Overview's header scrolls with the list and follows the band; the other tabs' app bar titles stay at the window's edge.
- **Dialogs:** a `Theme` around `AppLockGate` in `MaterialApp.router`'s `builder` sets `dialogTheme.constraints` to 280–560 dp while `capsWidths`, for every Material dialog of the app; with the gate off dialogs keep Flutter's bounds (at least 280 dp, at most the window less 80), and the static `AppTheme` is unchanged. The date and time pickers keep Flutter's own bounds through `pickerFormatsBuilder` (`app/lib/app/l10n/picker_localizations.dart`), which every picker call uses, because their landscape and large-text layouts need more than 560 dp. iOS alerts keep Cupertino's fixed width.
- **Material bottom sheets** keep M3's 640 dp at every size.
- **iOS sheets:** `showReadableCupertinoSheet` (`app/lib/app/layout/readable_sheet.dart`) is the app's only call of `showCupertinoSheet` and wraps the content in `ReadableSheetWidth`: at most 640 pt, centred, a card with 12 dp top corners when at least 48 dp (`minMargin`) remain beside it, else the whole width as on a phone (why: slivers of the page at the sides would look like a misplaced sheet). The card takes the height it is given, so a drag closes the sheet and its list scrolls as before.
  - A tap beside a sheet's card closes the sheet (`ReadableSheetWidth.closesOnTapBeside`, set by `showReadableCupertinoSheet`, through `Navigator.maybePop`, so a `PopScope` keeps its guard); screen readers skip the area.
  - The two wheel popups (`cupertino_picker_sheet.dart`, `day_range_picker.dart`) keep `showCupertinoModalPopup` and wrap their content in the same widget, with the tap beside off, as a tap beside their card reaches their own barrier.
- **No golden images:** layouts are checked by geometry in widget tests, because CI renders on Linux and development runs on macOS.
- **The sweep on tablets:** every scenario also runs on its platform's tablet (Android 1280 × 800 and 800 × 1280, iOS 1194 × 834 and 834 × 1194), dark, en and de, with the guidelines and the width checks, and again at 200 % text, where it must show without an exception at every scroll stop.

Limits:
- Windows 600–839 dp wide and 480–899 dp high get no caps: an Android split screen in portrait, the Pixel Tablet's 50/50 split in landscape (about 640 × 800), an iPad's 2/3 split (about 790 × 834). Their forms reach about 760 dp beside the Android rail and 839 pt on iOS, and their iOS sheets fill the window.
- Snackbars span the content beside the rail, about 1,170 dp at 1280 × 800.
- Pages over the shell, such as settings, forms, search and the inbox, cover the rail or the tab bar, with their content centred in the window.
- The floating action buttons stay at the window's bottom right, beside the band.
- The description and comment editors have no width of their own, and images in a description decode at the window's width.
- Not looked at on an iPad: the wheel popups as cards, an iPad mini or 11", Split View and Slide Over.

## D70: Task detail pane beside the list on two-pane windows, the sheet elsewhere

*Accepted 2026-10-28 (step 36c), the owner's decision where marked.*

- **When:** the detail ([D44](#d44-task-detail-own-rich-text-parser-online-details-app-scheme-links)) opens in a pane beside the list (owner) when the window is `WindowLayout.twoPane` (at least 840 dp wide and 480 dp high, [D69](#d69-large-screens-a-window-layout-helper-readable-widths-capped-dialogs-and-sheets)), not in tabletop posture, and the task is opened from a screen inside a tab other than Account: the Overview, Upcoming, the smart lists and a project's List, Table, Kanban and Gantt views. Pages over the shell (search, the inbox, a label's tasks) and everything else keep the sheet, so phones, tablets in portrait below 840 dp and the 800 × 600 test surface do not change.
  - On the iPad: in landscape on every iPad and in portrait on a 13" iPad; an 11" iPad or an iPad mini in portrait, Split View, Slide Over and an iPhone in landscape keep the sheet.
- **One pane per tab:** the Overview, Upcoming and Projects tabs each have a stack of the tasks opened inside the pane, at most 10, the oldest dropped; only the top task is built. A tab switch shows that tab's pane, or none; the Account tab never has one.
- **Layout:** beside the tab's content and below every page over the shell: rail, list, a 1 dp divider in `outlineVariant`, pane. The pane takes 40 % of the content beside the rail, at least 360 and at most 480 dp; the list keeps the 840 dp band in what is left. On the Projects tab the project tree's column comes first ([D82](#d82-projects-listdetail-the-project-tree-beside-the-project-on-wide-windows)). The navigation shell keeps its place in the tree in every state, so opening or closing the pane keeps the tabs' pages and scroll offsets.
  - The offline banner and snackbars span list and pane, while the pane's own messages (a comment posted, copied, failures) stay in it; the tab's floating action button stays left of the pane; on iOS the pane sits above the tab bar.
  - The pane is on the page's surface colour, takes the status bar's inset as its own top padding and the keyboard as the shell's Scaffold does. While it shows, the list loses its end-side safe-area padding and the pane its start-side padding, mirrored right to left.
  - On a vertical fold or hinge inside the content that has a width or is half opened, the split sits on it, without a divider (the pane may then be wider than 480 dp), when both sides keep 320 dp; a half-opened horizontal fold (tabletop) gives no pane. `paneSplitFor` and `isTabletop` (`app/layout/pane_split.dart`) are pure functions.
- **The same detail:** the pane shows `TaskDetailSheet` through `TaskDetailPaneHost`:
  - The close button ("Close details") closes the pane. A related task, a subtask, the parent, a task link and the duplicate's "Open" open inside the pane, and a back arrow before the project chip, "Back to *title*", returns to the task before; the menu's tooltip is "More for *title*".
  - Delete leaves the task, closes the pane after the last one, says "Task deleted" on the screen beside it and removes the task from every tab's stack, so that no stack shows the same task twice in a row.
  - Edit, the description and comment editors, pickers, dialogs, menus and the image viewer open on the root navigator over the shell, with the pane under them; there is no navigator inside the pane.
  - The header row and the 4 dp progress line are pinned above the pane's list, so close and back stay in reach. Tasks in the pane change without an animation.
- **Selection:** the row, board card or timeline row of the top task in the current tab's pane is marked and reads as selected (`SelectedTaskHighlight`): a row gets a `surfaceContainerHighest` fill and a 4 dp `primary` bar on its start edge, a board card the fill and a 2 dp `primary` outline inside its corners, a timeline row a 60 % band of the fill and a 2 dp `primary` outline around its bar. Rows on pages over the shell, in sheets and inside the pane never are. It follows a queued create's server id. Why this fill: `secondaryContainer` fails in both high-contrast schemes.
- **Back**, for the button and the swipe alike: first a page, sheet, dialog or menu over the shell or in the tab; then the task before in the pane; then the pane; then the tab's own pages; then the tab rule of [D45](#d45-app-shell-colour-scheme-display-settings-projects-tab-smart-lists-offline-banner). A `BackButtonListener` after `AppLockGate`'s observer and before go_router's delegate handles the pane, and `PopScope.canPop` includes `!paneShown`.
- **Pages inside a tab have no predictive back preview on Android, at every size:** the tab navigators use `FadeForwardsPageTransitionsBuilder`, so a swipe goes the way of the back button. Why: the predictive back detector took swipes for routes in covered or offstage navigators, which popped the wrong page on Android 14+ with gesture navigation. Pages over the shell keep the preview.
- **Resets:** any change of the active account closes every pane. A tab's pane closes when that tab's own location changes (the shell route's own `matchedLocation`: another project, up to the tree, another smart list, a `go` elsewhere in the branch), while pages over the shell, another view of the same project, Upcoming's ranges and a list's filters and sorts keep it. Selecting the current tab again closes its pane. The app lock keeps the pane, its stack and a comment draft, as it keeps sheets and pages ([D64](#d64-app-lock-over-the-ui-and-device-privacy-settings)).
- **Links, widget taps and notification taps** (`TaskOpener.showTask`): the rules of [D44](#d44-task-detail-own-rich-text-parser-online-details-app-scheme-links) stay (open dialogs and sheets close, another tab goes back to the Overview); then the task opens anew in the Overview's pane, at its comment for a notification about one, when the pane fits and nothing covers the shell, else in a sheet. A tapped row or card whose task is already on top opens nothing new; a card sets the entry's board and a row clears it ([D84](#d84-everyday-editing-in-the-task-detail-properties-in-place-task-links-move-to-column)).
- **Resize:** when the window stops being two-pane (a rotation, a split screen, a freeform resize, a fold into tabletop), the current tab's top task opens as a sheet with its comment draft and its board once the shell is in front again; its stack and the other tabs' panes are dropped. If the room comes back before that, with the same tab and location, the task returns to the pane; a newer task from the opener replaces it. A sheet stays a sheet when the window grows. A resize that keeps two panes keeps the pane, its stack and both scroll offsets.
- **Accessibility:** while the pane shows, the list and the pane are regions of their own (a semantics container and a focus group each), the list first. The pane's task title keeps its level-1 heading beside the screen's own ([D68](#d68-screen-readers-headings-one-announcer-high-contrast-reduce-motion-route-sweep)). The pane has no label, and opening, changing and closing it announce nothing; the back arrow is read once, by its tooltip. Focus moves into the pane on every open and change and back to the row last used on close, else it stays in the list; the pane's focus node adds no semantics node.
- **State:** the stacks of `TaskDetailPaneEntry` (the task, a comment to show once, the scroll offset, and the board whose card opened it, `TaskBoardOrigin`, for Move to column… of [D84](#d84-everyday-editing-in-the-task-detail-properties-in-place-task-links-move-to-column)), one per branch with the location it was opened at, are plain State of `_HomeShellState` (`features/home/presentation/home_shell.dart`) and go with the shell on sign-out. `TaskDetailPaneScope` (`features/tasks/presentation/task_detail_pane.dart`) wraps only the branch navigators, so only screens inside a tab find it; `openTaskDetail(context, task:, board:)` opens the pane when it is available, else `showTaskDetail`, and hands either the card's board. A task opened inside the pane gets none. The comment draft is also saved in `deactivate`, so a fresh entry for the same task in the same frame reads it.

Limits:
- Not checked on a device: back swipes with gesture navigation, the selected look in dark, a foldable, and TalkBack and VoiceOver with the pane ([Q19](open-questions.md#q19-device-setup-for-the-manual-talkback-pass)).
- An 11" iPad and an Android tablet in portrait keep the sheet.
- Back inside the pane restores only the scroll offset: the comments are collapsed and the details read again.
- Right to left is covered only by the tests of the split function and the highlight.
- With a page open in a tab that is not shown, the app tells Android that it handles back even on the Overview without a pane.
- Uncoloured label pills blend into the selected tint in the light brand scheme; their text keeps 7.28:1 on their own fill.
- No pane on pages over the shell (search, the inbox, a label's tasks), and no Esc for it yet (step 36d).

## D71: English and German: US base, glossary, error texts, live language changes

*Accepted 2026-10-29 (step 36e); US English since 2026-11-13 (owner, [D83](#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp)), in review with step 38a.*

**Languages and wording:**
- The base language is US English, like the Vikunja web (owner), with `app_en.arb` as the template (in review):
  - spelling and terms only: color, favorite, organize and organization, recognize, license, check off, the trash. Sentence case, the spaced em dash, curly quotes and punctuation outside quotes stay as the glossary has them;
  - the descriptions in `app_en.arb` follow it too, as they become Crowdin's source text (step 38e);
  - ARB keys, identifiers, comments, log strings and test names keep their British spelling (`taskEditColour`, `projectsFavouritesHeading`; why: renaming keys touches hundreds of call sites for nothing a user sees);
  - Flutter's own licence page keeps Flutter's English ("Licenses"), and the app's own words in the Material Icons notice are US English too;
  - the store texts in the `en-GB` folders stay British until step 38f decides the listing's languages ([D76](#d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android));
  - `app/test/l10n/us_english_test.dart` fails on a British spelling in an English value or description (key names in descriptions ignored) or in the native English texts and the Material Icons notice, on "Rurana" in a value or description of either language (except `aboutNameAndLogo`, until step 38d) or a native text, and on "unofficial" or „inoffiziell“.
- German stays complete on every commit; `app/test/l10n/arb_parity_test.dart` enforces parity and placeholders.
- No web texts are copied ([D67](#d67-agpl-30-or-later-with-an-app-store-permission-dco-reserved-brand-embedded-cronet)), and there is no ARB import tool for `error.*`. Error texts are written per code in our own words.
- [glossary.md](glossary.md) sets the terms and style for both languages and for the native strings. Highlights:
  - German: du, „…“, erstellen, Gerät (not Handy). The field is „Fälligkeitsdatum“, but the detail sheet's row label stays the short „Fällig am“ (`taskDetailDueDateRow`) for the narrow label column beside the value ([D77](#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)).
  - English: US spelling (in review), sentence case, the ASCII apostrophe, a spaced em dash, "Mark as done", and "column" for a bucket.
  - The server's trash keeps the web's word, the trash („Papierkorb“; in review) ([D79](#d79-the-trash-of-vikunja-280-undo-queued-deletes-a-trash-page)), and its subscriptions are following („folgen“) ([D80](#d80-reminders-follow-subscriptions-on-vikunja-280-and-later)).
  - A bug is reported („einen Fehler melden“), never in a „Fehlermeldung“, which reads as a message the app shows; a label that shows something says „anzeigen“; the texts on waiting for a sign-out use the full imperative. `app/test/l10n/german_texts_test.dart` checks these three.
- The support details' text ([D20](#d20-scope-cuts-and-mobile-forms-of-desktop-features)) stays English in every app language, so reports compare; only their page is translated.
- Texts change only when they are inconsistent, wrong, unclear or misspelt, never for taste. Every new or changed message has a description ([D68](#d68-screen-readers-headings-one-announcer-high-contrast-reduce-motion-route-sweep)).
- An API token's expiry reads "Last valid day" and "Until the end of {date}" (German keeps „bis einschließlich“), and the token expires at the end of that day. The no-project error says "Create one on the Projects tab first".

**Server errors:**
- The fallback is a localized sentence with the server's detail, for codes the app does not map (why: for an unknown code the detail is the only clue). Rare or diagnostic codes stay on it.
- `actionFailureText` (`features/common/presentation/action_failure_text.dart`) words four failures any action can meet:
  - a guest link that is gone (`LinkShareGone`, checked first, as it extends `SessionEnded`);
  - an ended session (`SessionEnded`, `TokenRejected`, `RefreshRaceLost`);
  - `RateLimited`;
  - `ServerFailure`.
- The failure texts of the project move, board columns, attachments, project changes, saved filters, label changes, teams, account settings, account security, the task duplicate and the trash ([D79](#d79-the-trash-of-vikunja-280-undo-queued-deletes-a-trash-page)) call `actionFailureText` just before their server-message arm, so their own arms still win, for example `FileTooLarge`, the sign-in-again texts of account settings and account security, and account security's "The server is busy…".
- A 5xx without a body (a proxy's 502, 503 or 504) and a storage error without a code show `actionFailureServerError`.
- Mapped per path:
  - task duplicate: 403, 4034, 4002 and 3008;
  - attachments: a download's 403, plus 4034 and 4002;
  - board columns: 3014, 3001, and 10007 for a board at the column limit ([D48](#d48-kanban-columns-managed-online-from-a-column-menu));
  - project move: 3016;
  - project changes: a duplicate's 4034, a 3016 with a new parent, and 3005;
  - teams: 6001;
  - assignee search: a 403 or a 404 (`assigneePickerNoAccess`), and a 5xx, a 429 or an ended session (`assigneePickerSearchFailed`);
  - the label picker words every failure through `labelChangeFailureText`.
- For the task duplicate and the assignee search, a 404 counts only when it is not a missing route.
- Filter errors: 4033 shows `filterErrorTooComplex`. 4016, 4017, 4019 and 4024 keep the server's detail, because they occur only when the server's parser disagrees with the app's. All five show at the filter field and mark the view or saved filter invalid (`isInvalidViewFilter`, `isInvalidSavedFilter`).

**The language followed while the app runs:**
- On a locale change and on every resume, the UI follows the device's language or the per-app language without a restart, and so do the notification channels, scheduled notifications, widgets, activity notifications, the lock prompt and the app shortcut. Android reports both changes through `didChangeLocales`, because the manifest handles `locale` in `configChanges`; iOS restarts the app instead.
- `deviceAppLocalizationsProvider` (`core/notifications/local_notification_gateway_provider.dart`) is a kept-alive Notifier, overridden at bootstrap with `loadDeviceAppLocalizations` and in the three headless entry points with a value.
  - `follow(locales)` takes the first supported locale, else English; an empty list changes nothing. On a change it notes the tag under `notifications.locale`.
  - The headless isolates resolve their texts once, from the device or that tag ([D39](#d39-local-notifications-a-scheduler-per-account-with-a-rolling-window)).
  - `deviceLanguageFollowerProvider` (UI engine only) calls `follow` from `didChangeLocales` and from an `AppLifecycleListener` on resume.
- The notification gateway is not rebuilt, because the activity tray keeps its instance. Instead, `LocalNotificationGateway.updateTexts` creates both Android channels again under their ids once the plugin is initialised, which renames them and keeps the user's settings; it never throws. On iOS the categories keep their texts until the app restarts.
- On a change, each account's scheduler reconciles with `force`, so every pending notification is scheduled again in the new language. Each widget publisher publishes again.

**The App language row:**
- The row reads "App language" („App-Sprache“) with the language's own name ("English", „Deutsch“) and opens the system's page (why: the system setting stays the one source of truth):
  - Android 13 and later: `ACTION_APP_LOCALE_SETTINGS` with the package URI. The row shows only if the intent resolves; a `<queries>` entry makes it visible. Configured through `android:localeConfig`.
  - iOS: the app's page in Settings (`openSettingsURLString`).
  - Hidden on Android 12 and older.
- It lives in `core/platform/app_language_settings.dart`. `appLanguageSettingsAvailableProvider` is false until the platform answers, and stays false if it fails.
- Opening it is an `AppExcursions.launchAway` excursion, so the app does not lock ([D64](#d64-app-lock-over-the-ui-and-device-privacy-settings)); the excursion ends at once when the page did not open, and a failure is logged by its type only.
- It is the last row of the Account tab's Appearance section, after Theme and "Use system colors", with "On this device" under its subtitle (owner, [D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab)).
- The account's language setting ([D54](#d54-account-settings-in-the-app-password-and-email-on-the-web)) never changes the app's language.

**Sorting, measuring and wrapping:**
- `compareTitles` (`core/text/title_order.dart`) sorts projects, the row label pills (`rowLabels`), the label list (`LocalLabelRepository.watchAll`), a team's members (by display name, then username, then id) and the sort menu (`sortsInMenuOrder`). It folds case, accents and ß, with stable tie-breaks: "apfel", "Ärger", "Zahlung".
- Its fold is public as `foldAccents`, includes the Romanian ș and ț, and is shared by every on-device search ([D81](#d81-vikunja-280-details-legal-links-okabeito-colours-lockout-hints-subtask-tree-accents)).
- `TimelineHeader` uses one-letter weekdays only when the widest of the locale's short names does not fit.
- At large text sizes, text wraps instead of being cut off:
  - the repeat and reminder amount errors, up to five lines;
  - the reminder picker's reference chips, up to four lines with a fixed-size checkmark;
  - the help under the project identifier and under the column limit, up to ten lines.

Limits:
- On iOS the row may first open the Apps list of Settings instead of the app's page, and the app's page reportedly shows Language only with more than one preferred language; both wait for the device test ([beta.md](beta.md)).
- Android 12 and older have no row and follow the system language.
- A read-only guest is also told to create a project on the Projects tab.
- Unmapped codes still show the server's English detail inside a localized sentence.
- The accent fold treats every language the same. It is not a collation per language, which Swedish, for example, would need.

## D72: First release: Android and iOS together, Play and a GitLab APK, beta first

*Accepted 2026-10-29 (step 37), the owner's decision.*

- Android and iOS reach 1.0.0 separately (owner, 2026-11-12): Android once its own checks pass; iOS stays in TestFlight until its device test passes, and both may still come out together if iOS is ready in time.
- Google Play, plus a signed APK in every GitLab release for devices without Play. No F-Droid ([D67](#d67-agpl-30-or-later-with-an-app-store-permission-dco-reserved-brand-embedded-cronet)).
- The repository is on GitLab, https://gitlab.com/coderoftime/rurana, and CI runs on GitLab CI ([D73](#d73-gitlab-ci-from-local-scripts-versions-from-the-tag-release-signing)); it goes public before the first beta, with every project of its group ([D77](#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)).
- 1.0.0 comes after a beta: test builds are `1.0.0-beta.N` (Play's closed test, TestFlight, and GitLab releases marked " (beta)", [D73](#d73-gitlab-ci-from-local-scripts-versions-from-the-tag-release-signing)), then `1.0.0` for everyone.
  - A new personal Play developer account has to run a closed test with at least 12 testers for 14 days before it can publish to production. The beta covers this.
- iOS is tested only at the end of the project, not with each step (owner): in the simulator in the iOS phase ([D74](#d74-ios-phase-app-store-prerequisites-testflight-from-the-mac-photo-locations-capture-cover)), then on a device before 1.0.0 ([beta.md](beta.md)).
- The release is step 37 on the [roadmap](roadmap.md) (owner): 37a release builds and GitLab CI, 37b the iOS phase, 37c store listings and policies, 37d beta and 1.0.0; 37e to 37h, for Vikunja 2.8.0, come before the first beta tag ([D78](#d78-vikunja-280-trash-codes-as-gone-its-limits-no-nul-info-re-read)).
- 36g comes before the first release and goes into the beta build (owner, [D82](#d82-projects-listdetail-the-project-tree-beside-the-project-on-wide-windows)). 36d, 36f and step 33 come after the first release.
- The repository prepares everything up to the work only the owner can do: accounts, keys, store records, testers, publication and the sign-offs. [beta.md](beta.md) lists that work in order.

## D73: GitLab CI from local scripts, versions from the tag, release signing

*Accepted 2026-10-29 (step 37a), the owner's decision where marked; the release channels are [D72](#d72-first-release-android-and-ios-together-play-and-a-gitlab-apk-beta-first)'s.*

**The pipeline:**
- `.gitlab-ci.yml` is thin. It uses plain YAML with anchors and `extends` only, because `tool/ci/test_gitlab_ci.py` parses it with Ruby's YAML.
- The logic lives in scripts under `tool/ci/` that run the same way on the owner's Mac. They are bash that runs on bash 3.2, with `set -euo pipefail`, and read only GitLab's `CI_*` variables and the variables named here.
- Pipelines run for a merge request, the default branch, a `^v` tag (`release_version.py` fails loudly on a malformed one), a schedule and a run by hand (`web`); any other branch without a merge request, and any other tag, runs none.
- A branch push never runs while the branch has an open merge request. A newer commit cancels interruptible jobs (`auto_cancel: on_new_commit: interruptible`), and every job is interruptible except `osv` and `release`.
- What runs: a merge request runs `checks`, `editor`, `contract`, `android`, `osv` and `dco`. Main and a run by hand run the first five, and a `v*` tag runs those five and then `release`. The weekly schedule runs `osv` only. Every job but `release` starts at once (`needs: []`).
- The jobs:
  - `checks` runs in one job, to save one Flutter setup per pipeline.
    - `checks.sh` checks that `flutter gen-l10n` and `build_runner` leave the generated code unchanged, then runs the format check, `tool/check_pure_dart_packages.sh`, the Android notices' self-test and check, `desugar_source.py --check-manifest`, `flutter analyze`, the Python tests of `tool/ci/`, and shellcheck when it is installed.
    - `test.sh` runs the tests of the app, every package and `vikunja_widgets` (in review), except the contract tests, with `vikunja_logic`'s `test/time` run again in Europe/Berlin, on every CPU of the runner (half of them locally).
    - `outdated.sh` runs afterwards, for information only.
  - `editor` (`node:26.10.0-trixie-slim`, the owner's Node; `.nvmrc` stays `26`) runs `npm audit --package-lock-only --audit-level=high` and `tool/build_editor.sh --check`.
  - `android` builds the release APK with the debug key, since no signing variable reaches it. It then runs the exported-components check and the widgets' Kotlin JVM tests.
  - `osv` runs in every pipeline, the schedule included, with `osv-scanner scan source --config=osv-scanner.toml` over `pubspec.lock`, the editor's `package-lock.json` and the Gradle lockfile. The scanner comes from PATH, else the pinned download for Linux amd64 or macOS arm64.
  - `ios` builds with `flutter build ios --release --no-codesign` and runs `ios_notices.py` on a runner tagged `macos`.
    - It runs only while `RURANA_MACOS_RUNNER` is `true`, only on protected refs (main and `v*` tags), and never on the schedule. A merge request's code never runs on the owner's Mac (threat model R35).
    - It counts when it runs (`allow_failure: false`). Unset the variable while the Mac is away, because GitLab cannot tell an absent runner from a busy one and fails the pipeline after up to a day.
  - `release` runs on tags only, after the five test jobs. It uses `environment: release` and `resource_group: release`.
    - It uses no cache, so Flutter and the packages never come from a cache another pipeline wrote.
    - Its artifacts are the bundle and `SHA256SUMS`, for the Developer role, kept for 30 days; the project setting "Keep artifacts from most recent successful jobs" keeps the latest bundle beyond that.
- Timeouts, estimates for a 2-vCPU runner: `checks` and `release` 90 minutes, `contract` 30, `android` and `ios` 45, `editor` and `osv` 10, `dco` 5.
- Caches live under `.cache/` (`PUB_CACHE`, `GRADLE_USER_HOME`, `npm_config_cache`), which is gitignored and excluded from the analyzer, because GitLab caches nothing outside the project. Flutter's cache is keyed by `pins.sh`, pub's by `pubspec.lock`, Gradle's by its lockfile and the wrapper's properties, npm's by the editor's lockfile.
- On GitLab's Linux runners, `lib.sh` caps Gradle at a 3 GB heap, a 1 GB Kotlin daemon and two workers. The project's `gradle.properties` asks for 8 GB, more than a small shared runner has. The cap never touches `~/.gradle` on a developer's machine.

**Images and pins:**
- Every Linux job but `editor` runs on `ghcr.io/cirruslabs/android-sdk:36` (Ubuntu 24.04, OpenJDK 21, no NDK). Flutter comes from its tarball, because no Flutter image exists for 3.47.
- Images and services are pinned by digest in `.gitlab-ci.yml`: `android-sdk:36`, `node:26.10.0-trixie-slim` and the service `docker:29.9.2-dind`.
- Downloads are pinned by version and SHA-256 in `tool/ci/pins.sh` (sourced, values only):
  - Flutter 3.47.9 ([D1](#d1-flutter-pub-workspace-with-pure-dart-packages));
  - osv-scanner 2.7.0, for Linux amd64 and macOS arm64;
  - the Docker CLI 29.9.2 (hash computed from the download, because Docker publishes none);
  - Compose 5.6.1.
- `setup_flutter` uses the checked tarball on GitLab's Linux runners. Elsewhere it uses the `flutter` on PATH, warning about another version, or failing when `CI=true`. It then runs `flutter pub get --enforce-lockfile`.

**The contract job:**
- It runs `test_servers/docker-compose.yaml` on docker-in-docker (TLS on port 2376, pulls through `mirror.gcr.io`), publishing the server on `0.0.0.0` inside its own daemon ([D28](#d28-contract-tests-against-the-latest-vikunja-release-only)).
- Only there, `contract.sh` installs the pinned Docker CLI, Compose and `socat`, waits up to 60 s for the daemon, then forwards `127.0.0.1:34527` and `[::1]:34527` to the service, so the tests, the server's public URL and `tool/wait_for_test_servers.sh` keep `localhost`.
- Locally (colima) it uses `docker compose` or `docker-compose`, installs nothing and leaves the servers running.
- A failure prints `compose ps --all` and the servers' logs.
- It runs the `vikunja_api` contract tests, then the app's in Europe/Berlin, one file at a time (`--concurrency=1`), both naming `test/contract`.

**The DCO job** (merge requests, full history):
- `dco.sh` runs the merge request's own `tool/check_dco.py --self-test`.
- It then runs the target branch's current copy of the script (`CI_MERGE_REQUEST_TARGET_BRANCH_SHA` in a merged results pipeline, else the branch's tip, fetched with its history) over the commits from the merge base (`CI_MERGE_REQUEST_DIFF_BASE_SHA`) to the source branch's head (why: a merge request can neither change the check that judges it nor pick an older one by branching from an old commit).
- Changes to `dco.sh` or `.gitlab-ci.yml` show in the diff for the reviewer.
- Locally, BASE's copy judges.

**Versions and signing:**
- `tool/ci/release_version.py` turns `v1.2.3` or `v1.2.3-beta.4` into the build name (`1.2.3`, `1.2.3-beta.4`) and a build number:
  - The build number is major·1,000,000 + minor·10,000 + patch·100 + n. Here n is the beta number (1–98), or 99 for the final release, so every beta orders below its release and Play's limit of 2,100,000,000 holds.
  - It also prints `CHANNEL` and the iOS pair ([D74](#d74-ios-phase-app-store-prerequisites-testflight-from-the-mac-photo-locations-capture-cover)).
  - Any other tag fails, and so does a pubspec whose version name differs from the build name: the release commit bumps the pubspec.
- There are no product flavours: one application id serves Play and the GitLab APK.
- `app/android/app/build.gradle.kts` has one `release` signing config and takes its key from the first source that is set:
  - the four `RURANA_SIGNING_*` variables;
  - else the four keys of the gitignored `app/android/key.properties` (`storeFile`, relative to `app/android/`, `storePassword`, `keyAlias`, `keyPassword`);
  - else the debug key, with a warning when a release APK or bundle is packaged.
  - A partial set fails and names the missing keys, never a value.
  - Nothing sniffs task names: the release script chooses each build's key.
- In CI, the upload set (`RURANA_UPLOAD_KEYSTORE_BASE64`, `_STORE_PASSWORD`, `_KEY_ALIAS`, `_KEY_PASSWORD`) signs the bundle and is required. The optional `RURANA_APK_*` set signs the APK, all four or none.
  - The APK set is the owner's app signing key, which is also uploaded to Play App Signing with PEPK, so Play's builds and the GitLab APK share one signature (Q20 option A, owner, [D77](#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)).
  - Without the APK set, the upload key signs the APK too, and sideloaded installs stay bound to it. The job log then shows a boxed warning, and the release note says so.
- Every signing variable is protected, scoped to the environment `release`, and "Masked and hidden", and `v*` tags are protected. A PKCS12 key's password equals its store password ([releasing.md](releasing.md)).
- `release.sh` copies the variables into unexported shell variables and unsets them, so only the build a set signs sees them.
  - It decodes a keystore into a `mktemp -d` folder (umask 077) for that build only, and traps remove it afterwards.
  - Passwords go only through the environment, never the command line or the log.
  - Before the long builds, it checks that each set opens its keystore and reads its certificate's SHA-256.
- `.gitignore` also ignores `*.p12`, `*.pfx`, `*.pepk`, `*.keystore.b64` and `.cache/`.
- Every Android build that is distributed comes from the release job of a protected tag. The iOS build is signed and uploaded from the owner's Mac ([D74](#d74-ios-phase-app-store-prerequisites-testflight-from-the-mac-photo-locations-capture-cover)).

**The release job** (`tool/ci/release.sh [--tag TAG] [--dry-run]`):
- Guards, before anything is built:
  - `CI_PROJECT_URL` must be https.
  - The project must be public, and anonymous reads of the repository at the tag, of the releases and of the package registry must answer 200, so the source link and the files open for everyone (AGPL section 6).
  - The written offer needs a contact (`build_android_notices.py --require-offer-contact`, [D67](#d67-agpl-30-or-later-with-an-app-store-permission-dco-reserved-brand-embedded-cronet)).
  - The upload set must be complete, and the APK set complete or absent.
  - Neither the release nor the package `rurana/<name>` may exist yet.
- It runs the release-only source-link test and the notices' checks.
- It builds the bundle with the upload set and one universal APK with the APK set, else the upload set, both with `--build-name`, `--build-number` and `--dart-define=SOURCE_CODE_URL=$CI_PROJECT_URL` ([D67](#d67-agpl-30-or-later-with-an-app-store-permission-dco-reserved-brand-embedded-cronet)). It never uses `--split-per-abi`, which would change the version codes.
- It runs the exported-components check and verifies the artifacts:
  - The APK has a v2 signature by exactly one signer, the APK set's (`apksigner`).
  - The bundle passes `jarsigner -verify` and is signed by the upload set's key.
  - Neither is signed by `CN=Android Debug`.
  - The APK's `versionCode` and `versionName` are the tag's.
- It publishes `rurana-<name>.apk`, `desugar_jdk_libs-2.1.4-src.tar.gz` and `SHA256SUMS` (for those two; the bundle's hash goes into the log) into the generic package `rurana/<name>`, then creates the release through the Releases API with `CI_JOB_TOKEN`.
  - The release is named `Rurana <name>`, with " (beta)" for a beta.
  - Its description gives the APK's SHA-256, the APK signing certificate's SHA-256, the source link to the tree at the tag and the note on the desugar_jdk_libs source, and it links the three files.
  - A failure after the first upload leaves a package that has to be deleted before a retry.
- The bundle reaches Play by hand from the job's artifacts. There is no Play API upload.
- `--dry-run` does everything but the publication, with two throwaway one-day PKCS12 keys, the source URL `https://gitlab.example/rurana` and, by default, the tag `v<the pubspec's version name>`. The visibility and contact guards become warnings; it prints the uploads and the release's JSON instead of sending them and ends with `DRY RUN: NOT RELEASABLE (<reasons>)`.
- The desugar_jdk_libs source is attached to every release, because a copy beside each release stays available whatever happens upstream.
  - `tool/android_notices/desugar_jdk_libs.source` names its commit (`50d9c1fb…`, as upstream has no 2.1.4 tag) and tree.
  - `desugar_source.py --check-manifest` (in `checks`, offline) checks the version against `build.gradle.kts`.
  - `--fetch` (in the release) fetches that commit with depth 1, checks its commit and tree ids and its `VERSION_JDK11.txt`, and writes its `git archive`, about 18 MB. The archive's hash depends on the git version, so it is an output only.
  - The notice says that the source is at that commit, that upstream has no tag for 2.1.4, and that a copy is attached to every release.

[releasing.md](releasing.md) is the release checklist; the threat model's R26, R28, R34 and R35 cover CI, signing, Cronet and the Mac runner.

**Runners:** GitLab's small shared runners. A full pipeline takes an estimated 100–150 compute minutes, and the free 400 a month are shared by every project of `coderoftime`, so the group, made public, applies for GitLab for Open Source (owner, [D77](#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)). iOS builds stay on the owner's Mac.

Limits:
- Until the first pipeline on GitLab ([beta.md](beta.md)), the Linux-only paths are untested: the Flutter tarball, docker-in-docker with the forwarder, the osv-scanner Linux binary, the NDK install and the Gradle caps.
- Some downloads are not pinned by the project:
  - the `android` and `release` jobs install NDK 28.2.13676358 from Google's SDK repository on every run;
  - `socat` comes unpinned from Ubuntu;
  - the test server's image is pinned by its tag only ([D28](#d28-contract-tests-against-the-latest-vikunja-release-only));
  - the Docker CLI's hash was taken on first use.
- Anonymous Docker Hub pulls may hit its limits. A read-only token with a `docker login` in `contract.sh` is not built.
- GitLab has no pre-release flag, so a beta becomes the latest release. Links therefore name a specific release, never `permalink/latest`.
- Each beta costs two full pipelines, one for the push to `main` and one for the tag.
- Not built: a Play API upload, a Mac runner for the heavy jobs, Dependabot or Renovate, and Gradle's dependency verification metadata.

## D74: iOS phase: App Store prerequisites, TestFlight from the Mac, photo locations, capture cover

*Accepted 2026-11-02 (step 37b), the owner's decision where marked.*

- The iOS share extension ("Share to Vikunja") comes after 1.0 (owner). Until then, iOS takes files only through the in-app pickers.
- On iOS, one-time secrets are covered while the screen is captured (recording, AirPlay or a mirrored display) (owner). Screenshots stay possible, and no undocumented secure-field trick is used.
- Photo and video locations are stripped before upload, and on Android too ([D76](#d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android)) (owner).
- No Time Sensitive notifications: reminders keep the interruption level `active` (owner).

**App Store prerequisites:**
- Both targets have a privacy manifest: `Runner/PrivacyInfo.xcprivacy` and `VikunjaWidgets/PrivacyInfo.xcprivacy` (in review), added by `tool/add_widget_extension.rb`.
  - They declare no tracking, no tracking domains and no collected data, since data leaves the device only for the server the user chose. The plugins' own manifests are listed in [releasing.md](releasing.md#privacy-manifests).
  - The required-reason APIs are file timestamp `C617.1` for both and user defaults `CA92.1` for the app.
  - `tool/ci/required_reason_apis.py` checks every binary of the archive (`nm -u` and the listed selectors) against its bundle's manifests, because App Store Connect refuses an undeclared API and a refused build uses up its build number.
- `ITSAppUsesNonExemptEncryption` is false: only standard, exempt encryption is used (HTTPS, TLS with pinning, PKCE).
- iOS uses the system SQLite (`hooks.user_defines.sqlite3` in the workspace's `pubspec.yaml`, `/usr/lib/libsqlite3.dylib` by its full path), and Android keeps the bundled build.
  - Why: the bundled build imports `statfs` and `fstatfs`, which no Apple reason fits, and Flutter cannot yet give a hook's framework a manifest.
  - The app's SQL needs SQLite 3.30 (`NULLS LAST`; upserts 3.24); iOS 15, the oldest supported, ships 3.36. The app uses no `RETURNING`, FTS or JSON functions.

**The iOS release:**
- The version comes from the tag ([D73](#d73-gitlab-ci-from-local-scripts-versions-from-the-tag-release-signing)): `IOS_BUILD_NAME` is the tag's `MAJOR.MINOR.PATCH`, since `CFBundleShortVersionString` takes nothing else, and `IOS_BUILD_NUMBER` is the Android build number. So the betas of 1.0.0 are 1.0.0 with growing build numbers.
- The owner runs TestFlight uploads by hand from the Mac with `tool/ci/ios_release.sh`. There is no GitLab job, because signing and the API key would have to live in the runner's macOS account (threat model R35).
  - It refuses to run unless all of these hold: Xcode is selected, Flutter is the pinned one, HEAD is the tag with a clean tree, the source link (`RURANA_SOURCE_CODE_URL`, else `CI_PROJECT_URL`) is https and its tree at the tag opens signed out, `DEVELOPMENT_TEAM` and the key variables `RURANA_ASC_KEY_ID`, `RURANA_ASC_ISSUER_ID` and `RURANA_ASC_KEY_FILE` are set (the key file readable by its owner only), and the 1024 icon is sRGB without alpha.
  - It runs the release-only source-link test.
  - It builds with `flutter build ipa --release`, using the tag's version, `SOURCE_CODE_URL` and export options for automatic signing with the team in `DEVELOPMENT_TEAM`.
  - It checks the archive: both bundles at the tag's version, the plist key, the committed manifests, the required-reason APIs and the licence notices.
  - It uploads its one IPA with `xcrun altool --upload-package` and the App Store Connect API key. The key's variables leave the environment before Flutter or Xcode runs.
  - `--dry-run` builds unsigned and stops before export ([releasing.md](releasing.md#ios-testflight-from-the-mac)).
- `ios.sh` and `ios_release.sh` refuse to run unless `xcode-select` points into an Xcode app (`use_selected_xcode` in `tool/ci/lib.sh`, which also unsets `DEVELOPER_DIR` and prints Xcode's version), because the Dart native-asset hooks ignore `DEVELOPER_DIR`.
- `tool/ci/ios_notices.py` runs in the release and in the CI job `ios`, because Flutter skips a package without a licence file silently.
  - Every licence of every package's `NOTICES` or `LICENSE` must be in `NOTICES.Z`; a package without one must be the repository's or the Flutter SDK's.
  - The repository's `LICENSE` must be listed under `ownLicensePackage`, the name the app's own notice joins.
  - The only frameworks allowed are Flutter's, `App.framework` and the native assets of `NativeAssetsManifest.json`.
  - Every legal asset of `app_licenses.dart` must be bundled and equal to its source.
  - It does not see Swift packages fetched by URL; no plugin uses one.

**In the app:**
- A system bar fallback (`systemBarStyleOn`, `_SystemBarFallback` in `vikunja_app.dart`) covers every page without an app bar or a region of its own.
  - It gives a transparent status bar with text that reads on the theme's surface, and Android's navigation bar in `surfaceContainer` with readable icons.
  - It is applied every frame, so both bars follow a theme change while the app runs.
  - The Android 8.1+ themes (`values-v27`, `values-night-v27`) name a transparent navigation bar and the launch's icons, because Android 15 and later would otherwise force light icons.
  - App bars and the lock cover still set the status bar where they are; the lock screen and the privacy cover also set the navigation bar's background and icons.
- Photo locations (`removeLocation` in `AppDelegate.swift`, `core/platform/location_removal.dart`):
  - Every photo and video from `pickPhotos` and `takePhoto` loses its location before it is handed on: attachments, the description editor's Image button and the avatar.
  - The removal works in place, off the main thread.
    - An image is written again with its metadata minus the GPS tags, in EXIF and XMP, without encoding a JPEG or HEIC again (a PNG, which loses nothing, is).
    - A video goes through a passthrough export with `metadataItemFilter = .forSharing()`.
    - Both are read back to check.
  - A file without a location stays untouched. A failure leaves the file as it was and logs only its type. Files from the Files picker are not touched.
- On iOS, library photos in image_picker's temporary copy are named like camera shots, `IMG_<yyyyMMdd_HHmmss>.<ext>` at the time of the pick, numbered `_1`, `_2` within one pick (`iosLibraryFileNames`). Videos keep the name after the picker's temporary prefix; any other name stays.
- `NSPhotoLibraryAddUsageDescription` (English and German) lets "Save Image" ask only to add to Photos.
- The capture cover:
  - `SecureWindow.setSecure` reports whether the screen is captured, and each change (`screenCaptureChanged`). It uses the scene's capture-state trait on iOS 17 and later, and `UIScreen.isCaptured` below.
  - While captured, the one-time token view shows "Hidden while your screen is being recorded or mirrored." instead of the token, and Copy still works. A revealed `SecretTextField` masks itself the same way.
  - A secret also hides whenever the app leaves `resumed`, and shows again only after a fresh answer on return, which covers the app switcher's snapshot and a capture that started while the app was away. Until iOS has answered, the token keeps its space but is invisible.
  - If the channel fails, the secret shows, because a token shown only once must not be lost.
  - Android keeps `FLAG_SECURE`.
- The inbox bell's badge grows only up to 1.3× text size, like the tab bar's labels ([D68](#d68-screen-readers-headings-one-announcer-high-contrast-reduce-motion-route-sweep)); the button's label speaks the count.
- The iOS hint under "Hide on the lock screen" does not say "On iPhone", as it shows on the iPad too.

Limits:
- Not yet checked on a device or with the Apple account (the device test in [beta.md](beta.md)): signing, and App Store Connect processing a build (the real test of the manifests); the capture cover in a real recording; the camera; BGTaskScheduler; iOS 15 to 17; signed-in online flows; Increase Contrast, Bold Text and Reduce Motion; Universal Clipboard; a restored backup. What else waits for the device test is in the entries concerned ([D23](#d23-browser-sign-in-through-flutter_web_auth_2-in-an-ephemeral-session), [D63](#d63-home-screen-widgets-app-written-snapshots-glance-on-android-widgetkit-on-ios) to [D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links), [D68](#d68-screen-readers-headings-one-announcer-high-contrast-reduce-motion-route-sweep), [D69](#d69-large-screens-a-window-layout-helper-readable-widths-capped-dialogs-and-sheets)).
- Not built: iOS 27's extra-large portrait widget; drafts out of the backed-up preferences (open with the owner, [D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links)); the app's own TLS through `connectionFactory` stays a reserve of [D65](#d65-connection-settings-per-server-address-applied-in-the-apps-transport).

## D75: Owner's UI review: no task identifier, coloured folders, new-task sheet, Account tab

*Accepted 2026-11-02 (the owner's UI review), the owner's decision where marked.*

**Task identifiers:**
- No task identifier (`WORK-3`, `#12`) is shown or spoken anywhere (owner).
  - Covered: rows of every list, the Kanban card, the detail sheet and pane, the Subtasks, Related and Parent rows, the relation and "Add to task" pickers, task-link pills, the inbox ("Anna commented on *title*"), local reminder and due notifications, and the widgets' spoken rows.
  - The task's Copy link and Share carry its database id in the web's address and show nothing ([D84](#d84-everyday-editing-in-the-task-detail-properties-in-place-task-links-move-to-column)).
- Every functional use stays: deep links such as `task/WORK-3`, the search by `#12` and `PROJ-12`, the relation and share pickers matching on it, quick add's `+project` by the project's identifier, filters and logs.
  - The search's start text does not mention identifiers.
  - The relation picker's field reads "Search by title".
  - The project identifier's help reads "Used in task links such as PROJ-12".
- The Table has no "Number" column and no "Number" sorts; its default sort reads "Default (newest first)" ([D61](#d61-table-as-a-detailed-list-gantt-as-a-read-only-timeline)).
- The detail header (`DetailHeaderLayout`):
  - The task's project chip with its parents (`ProjectBreadcrumb`) takes the identifier's old place (owner).
  - The pane's back arrow, the chip and the actions (Edit, Follow, the star, the menu, close) share one line when the chip fits whole. Otherwise the chip moves to its own line below them, in line with the title, never cut off.
  - The Open or Done state and "Not yet synced" are a small line under the title.
  - The task's colour dot stands before the title, so it does not read as the project's colour.
  - In the pane, Tab reaches the chip first. A screen reader reads it alone after the back arrow.
- The close button is "Close details" („Details schließen“) (why: a plain „Schließen“ would duplicate the drag handle's label, and "Close task" would read as marking the task done).
- The relation rows and the relation picker name the project only for a task in another project. The share target's picker always names it.

**Projects:**
- Every project shows as a small folder tinted with its colour, or `onSurfaceVariant` without one (owner). This is the shared `ProjectIcon`. `ColorDot` stays for a task's own colour.
  - `ProjectIcon` appears in:
    - the project tree with its drag feedback, favourites and search;
    - the new-task sheet's project field (quick add's accent still marks a project the text decides);
    - the task's project chip;
    - the project, parent and default-project pickers;
    - the edit page's project tile;
    - a row's meta line and the Table's project column;
    - the widget setup;
    - the filter builder's suggestions;
    - the share sheet's chip;
    - quick add's `+project` suggestions.
  - The native widgets draw a tinted folder for every project:
    - Android: `widget_project.xml`, Material's outlined folder, 12 dp with a 3 dp gap, `onSurfaceVariant` without a colour.
    - iOS: the `folder` symbol, `.secondary` without a colour.
  - Other icons: archived projects keep their archive icon in the filter builder, labels their circle in the widget setup, and the parent tile, the default-project row, the quick-add preview chip and the help sheet a generic folder.
- A checked "Show saved filters" item („Gespeicherte Filter anzeigen“) sits in the Projects tab's menu, between "New saved filter" and "Show archived projects". It is on by default and not offered to guests (owner).
  - It is stored per account as `show_saved_filters` in the `projects` value of `list_preferences`, and reads as on unless stored as `false`.
  - Off, the tab shows no saved filters, not even among the favourites. The empty state counts them as none and drops its own "New saved filter" button, and the tree does not wait for them. They are still watched, so showing them again needs no wait.
  - "New saved filter" stays in the menu, and a filter created while they are hidden opens its list.
  - Search, the widget setup and the Overview's filter choice are not affected.
- No remembered view (owner): a project opens on its default view every time ([D45](#d45-app-shell-colour-scheme-display-settings-projects-tab-smart-lists-offline-banner)).

**The new-task sheet:**
- The sheet shows, in order: the headline, the title, the Quick Add preview, the project, then the due date and the priority as two rows of chips (owner).
  - Each row is one line that scrolls sideways, with its heading above the chips (owner). The headings are small, at level 2.
  - Due date: Today, Tomorrow, Next week, a chip for a picked or parsed date that matches no shortcut, and "Pick date…". The chosen shortcut shows the time the due date gets, for example "Tomorrow at 9:00 AM" ("{label} at {time}") (owner).
  - Priority: Low, Medium, High, Urgent and Do now (1 to 5). Tapping the chosen chip again unsets it.
  - On a 360 × 740 phone at 1.0 text, both rows stay in view with the keyboard up. Below them is a pinned part holding only the progress slot, the suggestions while a token is typed, and the buttons.
  - While the options are closed the content scrolls from its bottom, so the headline leaves first; open, it scrolls from its top. The title field has a one-line hint.
- The title field is [D38](#d38-quick-add-the-webs-grammar-with-fixes-through-the-outbox)'s composer, without a prefix toolbar and with its help behind `?` (owner).
- The sheet sets a priority in every mode, as a fallback like the due date (`fallbackPriority`), and a line's own `!n` wins (owner, [D38](#d38-quick-add-the-webs-grammar-with-fixes-through-the-outbox)).
- "More options" expands the sheet in place and reads "Fewer options" while open (owner).
  - It is always enabled, even before a title.
  - It adds a Description (multi-line plain text, sent as HTML through `sharedTextHtml`: escaped paragraphs, line breaks, links), plus Labels, Reminders and Repeat, using the edit page's sections and pickers; a relative reminder needs a due date. Opening it brings the Description into view.
  - Nothing is created before Add, and Add needs a title. The "Added …" snackbar stays.
  - With several pasted lines every task gets the fields ([D38](#d38-quick-add-the-webs-grammar-with-fixes-through-the-outbox)). After "Fewer options" the fields keep their values and still apply.
  - New labels are marked ("Errands · new") and created once, on Add, together with typed `*labels`, so a dismissed sheet leaves nothing on the server. A label picked here that cannot be created joins the snackbar's list; a typed one stays in its title ([D38](#d38-quick-add-the-webs-grammar-with-fixes-through-the-outbox)).
  - Reminders are relative to the first line's due date, or to the sheet's date while there is no text. A duplicate is silently skipped.
  - An invalid repeat:
    - With the options open, Add is disabled.
    - With them closed, Add and the keyboard's Done open them, bring the amount field and its error into view, announce the error, and add nothing.
  - A repeat picked in the sheet sets no due date, while a typed one still dates the task today.
- While the keyboard is hidden, the sheet's bottom clears Android's navigation bar and the iOS home indicator. While it shows, the bottom clears the keyboard (owner).

**The Account tab:**
- One Appearance section holds the rows Theme, "Use system colors" (Android 12 and later) and App language ([D71](#d71-english-and-german-us-base-glossary-error-texts-live-language-changes)) (owner). The Account settings page has no Appearance section.
  - Theme („Design“) is the account's `color_schema` on the server ([D45](#d45-app-shell-colour-scheme-display-settings-projects-tab-smart-lists-offline-banner)), with Light, Dark and System segments, a sliding segmented control on iOS.
    - It is online only, and disabled offline, while a sign-in is needed and while signing out.
    - It shows a "Saving" spinner and announces "Saved".
    - Errors use the shared `saveAccountSettings` (`account_settings_save.dart`, also used by the Account settings page): the field's refusal, or a snackbar that does not lock the control.
    - It takes "offline" from the sync.
    - It is one screen-reader group, marked disabled when it cannot change.
    - A running save or a refusal survives the row scrolling away.
  - Each row says where it is stored, in a small line under its title: "Saved to your account" („In deinem Konto gespeichert“) or "On this device" („Auf diesem Gerät“). The section has no mark of its own and no hint pointing to the account settings.
  - Guests get no Theme row, and the section disappears when it has no rows.
- The tab's order is (owner):
  - the banners, the header and the notes;
  - Account settings, Organize and Accounts;
  - Sync („Synchronisierung“): the last sync or its phase, a failure's explanation, the background line, Sync now, Full resync, Pending changes and Sync problems;
  - Home screen, Notifications, Privacy and Appearance;
  - Server: the Vikunja version, Connection and the server's notices;
  - Sign out and the version line.

Limits:
- While a token such as `+Wo` is typed, the suggestions strip leaves about 220 dp at 360 × 740 with the keyboard up, so the priority row scrolls under it until the token is done. A very long line has the same limit.
- While `!n` locks the priority, the row does not scroll to its selected chip.
- A date typed in the title adds its chip under the field, and on a 360 × 740 phone the priority row is then a short scroll away.
- At 200 % text with a long title, the help button can scroll out of view with the field.

## D76: Store listings and policies, the app's pages, photo locations removed on Android

*Accepted 2026-11-02 (step 37c), the owner's decision where marked; the name since step 38a, in review.*

**The stores:**
- The name is "Vikunja" in both stores and both languages, the official app's ([D15](#d15-app-id-iovikunjaapp-and-the-name-vikunja), [D83](#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp)); no text calls the app unofficial. The first paragraph of each description says that Vikunja is the open-source task manager you can run on your own server and that this is its app for the platform. The keywords leave out "Vikunja", which the stores index with the name; another app's or company's name stays out of the name fields and the keywords (in review).
- The reviewers use the public demo `try.vikunja.io` through "Try the public demo", with the shared account `demo` / `demo` (owner; answers [Q21](open-questions.md#q21-a-server-for-the-store-reviewers)). The credentials stand in App Review's sign-in fields (`fastlane/metadata/review_information/demo_user.txt` and `demo_password.txt`), never in the notes, as Apple asks; the notes lead through the demo, ask the reviewers not to delete the shared account, explain the offline use and carry the App Transport Security justification ([D8](#d8-cleartext-only-after-the-users-consent)). Play's App access carries the demo's instructions.
- Play's Data safety is answered cautiously (owner), because Play counts every transmission off the device as collection, with no exception for a server the user chooses:
  - name, user ids, photos and videos, files, in-app messages and other user content: collected, not shared, for app functionality;
  - no location (owner): the app has no location permission and never reads the device's location, and a location left in an attachment is part of the content the user chose, declared with it; "Email address" is not declared;
  - data encrypted in transit "No", because plain `http` can be allowed ([D65](#d65-connection-settings-per-server-address-applied-in-the-apps-transport));
  - deletion on request "Yes", with the support page's deletion question as the deletion URL.
- Apple's privacy label is "Data Not Collected", because Apple counts only data the developer or its partners can access; it matches [D74](#d74-ios-phase-app-store-prerequisites-testflight-from-the-mac-photo-locations-capture-cover)'s privacy manifests.
- No exact-alarm declaration ([store-listing.md](store-listing.md#app-content)): Play's is for `USE_EXACT_ALARM`, which the app never declares; `SCHEDULE_EXACT_ALARM`, which the user grants, needs none. The Play description still explains the permission and that reminders can be late without it. No foreground-service declaration: workmanager's `SystemForegroundService` has the type `shortService`, which Play does not ask about.
- Non-trader under the EU's Digital Services Act in both stores (owner).
- Target audience 18 and over; the content rating for all ages with "Users interact" and no shared location (PEGI 3, USK 0, ESRB Everyone; Apple 4+ with "Messaging and chat"); every country and region except mainland China; free, without ads, purchases or donations; "Create account" kept on Play, with the deletion steps on the website.
- Listings and policy in British English (en-GB, the default listing) and German (de-DE); the German privacy policy is binding. The listing texts stay British, unlike the app ([D71](#d71-english-and-german-us-base-glossary-error-texts-live-language-changes)), until step 38f decides the listing's languages (in review).
- [store-listing.md](store-listing.md) holds every form of the Play Console and App Store Connect with its answer, reason and source, and the answers still uncertain ([open points](store-listing.md#open-points)).

**Listings, graphics and screenshots:**
- The listings are files in fastlane's layout (`fastlane/metadata/`: supply's for Play, deliver's for the App Store), copied into the consoles by hand; fastlane is not run. Play: title, short and full description, an empty `changelogs/`. App Store: name, subtitle, description, keywords, promotional text, empty release notes, the URL files with each language's addresses (the German privacy URL with `#de`), `copyright.txt` (`2026 Benedikt Lesch`; the app itself keeps "Benedikt Lesch and the Rurana contributors" until step 38d), `primary_category.txt` (`PRODUCTIVITY`) and `review_information/` (the notes, the demo account and the email). Every feature named comes from the README and is in the app on that platform.
- `tool/check_store_metadata.py` checks the listings: both languages complete without stray files, an empty file as an error, the stores' limits (in bytes where Apple counts bytes), the naming rules above (`title.txt` and `name.txt` exactly "Vikunja", a keyword naming it fails as "the app name is indexed already", any text calling the app unofficial fails; in review), no claims or emoji in the short fields, no mention of the other platform, the keyword format, the category, each URL file an https address on coderoftime.dev equal to the page's address for its language, the email, the copyright and the screenshots' sizes and alpha; `--strict` also wants each store's minimum screenshots. A test checks the committed listing, so the `checks` job keeps it valid.
- The graphics come from the existing icons only (`branding/build-store-graphics.sh`, ImageMagick): the Play icon `branding/png/play-icon-512.png` (the full-bleed iOS icon, as Play rounds the corners) and the feature graphic `branding/png/feature-graphic-1024x500.png` (the iOS dark icon's llama on `#196AFF`, flush with the bottom, without text, so one serves both languages; in review, [D42](#d42-app-icon-vikunjas-logo-every-variant-derived-by-script)). App Store Connect takes its icon from the build.
- `tool/seed_demo_data.py --lang en` seeds an English set with the same projects, labels, tasks, saved filter and board as the German default (the board with renamed columns and two cards in progress, the second user named Sam, the task for today due at 21:00, or two full hours later when seeded in the evening); `--reset` deletes only items titled like either set, so the language changes without a new sign-in; a 304 counts as success, and a 500 (the SQLite test server's "database is locked") is tried again after a second.
- `tool/store_screenshots.sh` takes an emulator (`emulator-<port>` that reports itself as one) or a booted simulator, never a device. It sets a clean status bar (Android's SystemUI demo mode, `xcrun simctl status_bar … override`): full battery and Wi-Fi without the no-internet mark, no mobile signal, no notifications, on Android the 24-hour clock, and the device's own time at each shot; on Android a 16:9 window (1080 × 1920 on a phone, 2560 × 1440 on the Pixel Tablet, as Play takes no side longer than twice the other). It asks for one motif after the other, saves each without alpha into fastlane's paths and restores the device on exit, Ctrl-C or an error. Motifs: on the phone the Overview, a project's list, its board, the task detail (from its title, without the checklist), the New task sheet and Upcoming (scrolled to the end of its list); on the tablet the Overview, the board, Upcoming and a project's list, each but the board with a task in the pane (four, because Google promotes an app on large screens only with at least four).
- Play's screenshots (phone and tablet, both languages) come from an emulator with a Google Play system image (why: an AOSP image lacks Custom Tabs for the sign-in). The App Store's sets wait for the 1.0.0 submission; TestFlight needs none.

**The app's pages** are part of the owner's website coderoftime.dev, in its own repository (owner), under `/rurana/` until step 38f moves them to vikunja.io ([D83](#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp)); this repository has no website, no `site/` and no job `pages`. Their addresses are fixed and must not change once they are in the stores ([store-listing.md](store-listing.md#the-website) lists what uses each):
- privacy policy `https://coderoftime.dev/rurana/privacy/`, one page, English and then German at `#de` (`src/content/legal/rurana-privacy.en.md` and `.de.md` in the website's repository);
- legal notice: the website's Impressum `https://coderoftime.dev/impressum/`, German first and English at `#en`, with the operator's name, a c/o address of a service with authority to accept service (owner) and a phone from the website's `src/site.config.ts`, and the email;
- support `https://coderoftime.dev/rurana/support/` and `https://coderoftime.dev/de/rurana/support/` (`src/content/support/rurana.en.md` and `.de.md`), one heading per question; "How do I delete my account?" („Wie lösche ich mein Konto?“) makes Play's deletion URL `https://coderoftime.dev/rurana/support/#how-do-i-delete-my-account`;
- the project page `https://coderoftime.dev/rurana/` and `https://coderoftime.dev/de/rurana/` as the marketing URL;
- one contact, `coderoftime@gmail.com`, for Play's developer email, support, privacy questions, App Review, TestFlight feedback and the written source offer ([D67](#d67-agpl-30-or-later-with-an-app-store-permission-dco-reserved-brand-embedded-cronet)).
- The pages speak in the first person, with "du" in German; the English privacy policy says that it translates the binding German one. The privacy policy says that the developer runs no server and no analytics, ads, tracking or crash reporting; that data goes only to the servers the user adds, to a server named in a link the user opens, or to `try.vikunja.io` under the Vikunja project's policy; and it covers signing in in the system browser, what stays on the device and exactly what sign-out deletes (the description draft among it), backups, the permissions, which files keep their location, the stores' own processing, test versions and the APK on GitLab, support emails and the project's issues, the rights under Art. 15 to 18, 20 and 77 GDPR with the objection under Art. 21(1) in a section of its own, and the controller by name and address. Visiting the website is left to the website's own policy, which names the app, as Rurana, among the app policies. Support answers eleven questions, from connecting and the public demo to deleting the account, reporting a bug (never with a password or a token) and a security problem.

**In the app:**
- The About page's header has the logo, the name, the version and the copyright line, without a line calling the app unofficial (in review). Right under it, the section "Help, privacy and legal notice" („Hilfe, Datenschutz und Impressum“) holds the help row ([D77](#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)), "Privacy policy" („Datenschutzerklärung“) and "Legal notice" („Impressum“), each opening its page in the browser through the link opener, with its snack bar when that fails. The addresses are constants of `WebsitePage` in `app/lib/app/legal.dart`, the same in every build: an app in German opens `https://coderoftime.dev/rurana/privacy/#de` and `https://coderoftime.dev/impressum/#de`, every other language `https://coderoftime.dev/rurana/privacy/` and `https://coderoftime.dev/impressum/#en`. They are apart from the server's own legal links on the Account tab.
- Delete account shows on every server, as both stores ask ([D55](#d55-security-settings-two-factor-status-sessions-and-tokens-a-new-token-shown-once)).

**Photo and video locations on Android** (owner; `LocationRemoval.kt`, `removeLocation` in `DeviceChannel.kt`, `core/platform/location_removal.dart`):
- `PluginAttachmentPicker` hands every photo and video from `pickPhotos` and `takePhoto` (attachments, the description editor's Image button, the avatar) to the removal, as on iOS ([D74](#d74-ios-phase-app-store-prerequisites-testflight-from-the-mac-photo-locations-capture-cover)), and `ShareFilesController` hands it every copy of a file shared to the app, before the copy is ready and whatever type the other app gave (`shareLocationRemoval`). Files picked "as a file" go up unchanged on both platforms.
- As Android's MediaProvider does for apps without `ACCESS_MEDIA_LOCATION`, the location is blanked in place, byte for byte; nothing is encoded or muxed again but a JPEG's, PNG's or WebP's Exif, which ExifInterface writes again. A file without a location is never written to (an empty or zeroed location box, a GPS directory with only its version or XMP with only `GPSVersionID` counts as none). The removal runs on one background thread, always answers, tells formats apart by their first bytes (a share's copy has no extension) and checks no Android version.
- A JPEG, PNG or WebP is first written again by ExifInterface (`androidx.exifinterface` 1.4.2, the version image_picker_android resolves to, declared directly) without the 32 GPS tags it knows, so the GPS directory goes. It writes a copy beside the file, which takes the file's place once written, because ExifInterface writes over the file it reads and holds a whole WebP in memory, so an error such as an OutOfMemoryError would leave the file cut short; where the copy cannot be written, the file stays as it was.
- Then, in every photo format, the app's own reader finds what is left by the file's own structure and blanks it in place:
  - `ExifTiff` zeroes the GPS values of each Exif: the GPS directory that IFD0 or an IFD after it points to, each entry read by its own type and count, only inside the Exif data and only GPS tags 0 to 31;
  - `XmpGps` overwrites GPS in XMP with spaces of the same length, so the packet stays well-formed: a property whose local name starts with "GPS" or names a latitude, longitude or altitude, ignoring case, or ends in "Lat", "Lon" or "Lng" (DJI's `drone-dji:LRFTargetLat`), an element without a prefix being in the default namespace, as an attribute, an element's text or an attribute value inside its element such as `rdf:value`;
  - it reads a JPEG's Exif and its standard and extended XMP in APP1; a PNG's `eXIf`, its XMP in `iTXt` or `tEXt`, and ImageMagick's text chunks named after a GPS property (`exif:GPSLatitude` and the like, not the version or the directory's pointer), blanked with spaces and the chunk's CRC computed again; a WebP's `EXIF` and its `XMP ` chunk, which ExifInterface never reads; a HEIF's or AVIF's Exif and XMP items through `iinf` and `iloc` (an XMP item by its content type, ignoring case and parameters), in the file or in `idat`; TIFF-based raw photos (DNG, CR2, NEF, ARW, ORF, RW2) and a Fujifilm RAF's JPEG; and XMP in Exif's tag 700 in all of them.
  - ExifInterface's own offsets (`getAttributeRange`) are not used for writing: they are off for a GPS value of an unexpected type and by six bytes in a WebP whose Exif starts with JPEG's identifier, and ExifInterface reads HEIF only from Android 9 and AVIF only from Android 12.
- MP4, 3GP and QuickTime videos, CR3 and JPEG XL: the boxes are walked (`IsoLocation`: 64-bit sizes, a size of 0 to the end, at most 8 levels and 100,000 boxes, the media data skipped). Every `©xyz`, `loci`, `gps ` and `gps0` box with a value becomes a `free` box with its payload zeroed, which ISO BMFF and QuickTime allow anywhere. In Apple's `mdta` metadata the `data` values of each item whose key names a location (`com.apple.quicktime.location.ISO6709`, `.accuracy`, `.body` and the like) are zeroed, their type and locale kept. GPS in XMP is blanked in `XMP_` boxes, XMP `uuid` boxes and `xml ` boxes in `meta`; a CR3's GPS directory in Canon's `CMT4` and a JPEG XL's `Exif` box are zeroed and a JPEG XL's `xml ` box blanked. There is no `MediaExtractor` and no `MediaMuxer`.
- The result is read back: a photo by ExifInterface (its GPS tags and its XMP tag) and by the reader again, a video by the walk again and by `MediaMetadataRetriever`'s `METADATA_KEY_LOCATION`. A location left throws `LocationKept` with a fixed reason (`LocationRemoval.Reason`) that never names the file.
- The removal fails open, as on iOS: a file that keeps its location is still handed on and uploaded, with whatever could be blanked blanked. The platform answers `remove_location_failed` with the reason (or an unexpected error's type); Kotlin logs only "A location stays in a file", and the app's log adds the reason, never the path.
- Only location bytes change in a video or a HEIF, AVIF, raw, CR3 or JPEG XL photo, so a QuickTime file stays QuickTime with all its tracks, samples, creation time and other metadata. A JPEG, PNG or WebP that ExifInterface writes again keeps its image data and the tags ExifInterface knows and gains its default tags (width, height, orientation 0, light source) where they were missing; tags it does not know (Windows' XP tags, PrintIM and the like) go, the maker note moves (so one whose offsets count from the TIFF header, as Canon's and Sony's do, no longer points at its data), a JPEG keeps only its last standard XMP packet, and its comment (COM) is also copied into an empty Exif UserComment.

Limits:
- Where the location stays, unreported, on every Android version: place names and country codes (XMP's `photoshop:City` or `Iptc4xmpCore:Location`, IPTC in a JPEG's APP13, Samsung's maker-note and trailer fields); GPS in maker notes; anything after a JPEG's first image (a multi-picture file's extra images, an Ultra HDR gain map, the video of a motion photo, the likeliest case); PNG's raw profile chunks, XMP in UTF-16 and XMP after markup that is not well-formed; a GPS directory outside IFD0's chain or past its eighth IFD; a HEIF Exif item whose TIFF offset misses the header, a HEIF whose `ftyp` names no HEIF brand, and HEIF image sequences; CR3 GPS outside `CMT4`; GIF, BMP, JPEG 2000, BigTIFF, WebM, MKV and AVI; a photo embedded in another file, such as a PDF; and in a video a GPS track (GoPro's `gpmd`, CAMM), a dashcam's GPS data in `mdat` that a `gps ` box points to (only the box is freed), boxes deeper than 8 levels or after a broken size, Apple keys without "location" in their name and `©xyz` outside `udta` and `ilst` (ExifInterface's and `MediaMetadataRetriever`'s checks report some of these where they read them).
- Reported as kept, after whatever else could be blanked is blanked: compressed XMP with GPS (a PNG's `zTXt` or compressed `iTXt`, a HEIF XMP item with a content encoding; only zlib is read, other encodings go unnoticed), compressed PNG text named after a GPS property, a JPEG XL `brob` box holding Exif or XMP, a GPS value over 64 KiB, an XMP packet over 64 MiB, a HEIF Exif or XMP item that `iloc` does not place in the file, a video or HEIF of more than 100,000 boxes, an Apple `keys` box over 1 MiB, and GPS in a RW2's embedded JPEG; a HEIF's `infe` or `iloc` box over 64 MiB stops the removal before it blanks anything. A GPS value of an unexpected type is zeroed, but where ExifInterface misreads it onto other bytes that are not zero, the file is still reported as kept.
- Nothing tells the user that a file kept its location; the privacy policy and store-listing.md name the likeliest cases.
- Blanked, not removed: outside a JPEG, PNG or WebP written again, the GPS directory and Apple's location items stay with zeros, so an app that reads zeros as a position puts the file at 0° N, 0° E, and AVFoundation lists an empty location for a cleaned QuickTime video.
- The video check trusts `MediaMetadataRetriever`: an error it throws counts as no location.
- The public demo is reset at irregular intervals; if it is down or its account changed during a review, the review fails. A reviewer cannot finish deleting the shared account (the confirmation goes to its email), and whether Apple accepts that for 5.1.1(v) is open. The fallback is a review server of the owner's, with a review account seeded by `tool/seed_demo_data.py`.
- The pages live in another repository: a moved page or a reworded deletion question breaks the stores' addresses and the About page's links, and nothing here notices; the website's README says they must not change.
- The release scripts do not check that the privacy policy answers.
- Not legal advice, for the owner to confirm: the privacy policy names the supervisory authority only as that of the owner's federal state and gives no fixed period for deleting support emails or the testers' list; the trader status is a legal judgement.
- Announced by Google for 2027, both left to the owner after 1.0: from April an app with a sign-in has to restore it on a new device, which would reverse keeping the tokens on their device ([D66](#d66-threat-model-redacted-errors-no-backups-keyed-widget-and-notification-links)); from 2027-08-25 an app targeting API 37 needs `ACCESS_LOCAL_NETWORK` and a Play declaration for servers on the local network.

## D77: Beta preparation: new app id, own signing key, public group, testers

*In review since 2026-11-02 (step 37d, first part), the owner's decision where marked.*

- The beta's runbook is [beta.md](beta.md).
- **Every project of the GitLab group `coderoftime` becomes public** (owner), so that the group can join GitLab for Open Source, which takes only groups whose projects are all public under an OSI-approved licence. This answers [Q22](open-questions.md#q22-ci-runners-on-gitlab).
  - The project stays https://gitlab.com/coderoftime/rurana, because its address is every release's source link (`RURANA_SOURCE_CODE_URL` for the iOS release); its history is kept as it is, without a rewrite. Once public, its issues and merge requests are open to everyone.
  - iOS builds stay on the owner's Mac, by hand (`tool/ci/ios_release.sh`, [D74](#d74-ios-phase-app-store-prerequisites-testflight-from-the-mac-photo-locations-capture-cover)).
- **Signing follows [Q20](open-questions.md#q20-signing-keys-and-the-apk-beside-the-play-build)'s option A** (owner): an app signing key that only the owner holds, uploaded to Play App Signing with PEPK when the app is created ("Provide a copy of your app signing key"), in place of Play's default hybrid signing with keys Google generates; a separate upload key signs the bundles (`RURANA_UPLOAD_*`); the release job signs the GitLab APK with the app signing key (`RURANA_APK_*`, [D73](#d73-gitlab-ci-from-local-scripts-versions-from-the-tag-release-signing)).
  - Why: Play's builds and the APK share one signature and update each other, and Android's developer verification already knows the APK's key.
  - The app signing key stays with the owner and, for the APK, in protected variables of the `release` environment.
- **The application id** is the official app's `io.vikunja.app` since step 38a, with every id derived from it ([D15](#d15-app-id-iovikunjaapp-and-the-name-vikunja), in review). Nothing changes on the server, which has no client registry.
- **The About page's row "Help and bug reports"** („Hilfe und Fehler melden“, the owner's words), subtitle "Answers to common questions and how to report a bug" („Antworten auf häufige Fragen und wie du einen Fehler meldest“), first in the section "Help, privacy and legal notice" ([D76](#d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android)), opens the app's support page in the app's language (`WebsitePage.support`), so that testers and users find how to report a bug (owner).
- **The beta's testers** (owner): Play's closed test takes them through a Google Group that the owner creates, TestFlight through a public link; they use their own Vikunja server (2.3.0 or newer, [D13](#d13-support-floor-230)) or the public demo `try.vikunja.io`, with a Google account for Play or the TestFlight app on iOS.
- **The threat model is signed off before the first beta tag and again before 1.0.0,** because the beta is public: each `v*` tag publishes a GitLab release with a signed APK, shown as the latest release, and the TestFlight link and the Google Group are open to anyone. Before `v1.0.0-beta.1` sections 8.1 and 8.2 of the [threat model](threat-model.md) run, with the emulator check of R33's fix, and the owner signs section 8.4; section 8.3 waits for the device test. Before 1.0.0 the owner signs again, with 8.1, 8.2 for what changed and 8.3.
- **Security reports go by email first,** to `coderoftime@gmail.com`, with a confidential GitLab issue as the alternative and never a public one, as [CONTRIBUTING.md](../CONTRIBUTING.md#issues), the support page and the website's `security.txt` say.
- **The French encryption declaration** is [Q23](open-questions.md#q23-french-encryption-declaration-for-the-app-store), to be settled before the App Store release in France.
- **App Store Connect's Accessibility Nutrition Labels stay blank** until the device and screen-reader passes ([Q19](open-questions.md#q19-device-setup-for-the-manual-talkback-pass)) confirm what can be claimed.
- **Versions:** Flutter as [D1](#d1-flutter-pub-workspace-with-pure-dart-packages) pins it; `app/pubspec.yaml` at `1.0.0-beta.1+1`, the build number coming from the tag ([D73](#d73-gitlab-ci-from-local-scripts-versions-from-the-tag-release-signing)).
- **Vikunja 2.7.1's changes** are in the entries they concern: attachment previews ([D53](#d53-attachments-uploaded-through-the-outbox-opened-through-the-platform-android-share-target)), the token presets, a gone token and the two-factor note ([D55](#d55-security-settings-two-factor-status-sessions-and-tokens-a-new-token-shown-once)), and the column limit ([D48](#d48-kanban-columns-managed-online-from-a-column-menu)).
- **The task detail's attribute card** gives its names one column as wide as the widest name on one line (measured bold when the platform's bold text is on), at least 96 grown with the names' text size; when the longest name leaves its value too little room, every row stacks.

Limits:
- Until GitLab for Open Source is granted, a fix can ship about once a month, as the group shares the free runner minutes ([D73](#d73-gitlab-ci-from-local-scripts-versions-from-the-tag-release-signing)); the iOS build costs none.
- A leaked app signing key cannot be replaced for existing installs.
- Not known: whether an uploaded app signing key gets hybrid signing (the owner checks it when creating the app), whether Play's builds and an RSA-only APK update each other on Android 17 and later, whether Play asks a new personal account to verify a real Android phone, and how GitLab for Open Source judges the AGPL with the additional permission in `NOTICE.md`.

## D78: Vikunja 2.8.0: trash codes as gone, its limits, no NUL, `/info` re-read

*Accepted 2026-11-10 (step 37e).*

- **The app follows Vikunja 2.8.0** (owner). Built elsewhere: the trash, with its wording, Undo and trash page, in [D79](#d79-the-trash-of-vikunja-280-undo-queued-deletes-a-trash-page); reminders as the server sends them in [D80](#d80-reminders-follow-subscriptions-on-vikunja-280-and-later); every legal link, the Okabe–Ito palette, the trash's token permissions, the lockout hint, subtasks expanded once and searches ignoring accents in [D81](#d81-vikunja-280-details-legal-links-okabeito-colours-lockout-hints-subtask-tree-accents).
- **The test servers run 2.8.0** ([D28](#d28-contract-tests-against-the-latest-vikunja-release-only)); the contract tests expect the version of the image's tag and gate changed answers on the server version.
- **Gone stays gone.** `NotFound` in `vikunja_domain` has `taskGone` (4002, or 4040 for a task in the trash) and `projectGone` (3001, or 3018 for anything in a project in the trash), used wherever 4002 or 3001 was matched:
  - a task's delete completes on either task code, a project's on `projectGone`, and a queued delete in the outbox completes;
  - the relation rules of [D41](#d41-relations-as-task-update-deltas-duplicate-and-follow-online-indented-subtasks) take both codes;
  - the failure texts of attachments, comments, the duplicate, board columns and shares say that the task or project no longer exists; where the user acts on the trashed thing they say "in the trash" ([D79](#d79-the-trash-of-vikunja-280-undo-queued-deletes-a-trash-page)).
- **The server's limits are kept in the app on every server version,** because they are far beyond use and one rule keeps the outbox from producing a refusal anywhere:
  - `Task.maxTitleLength` (1000 code points): the title fields of the edit page, the share sheet and the subtask field stop there, and a text already longer can only get shorter. A stored longer title stays until changed; while a changed one is too long, Save is off, with a counter from 50 left.
  - Where text arrives in bulk (shared text, Quick Add's lines) a too-long title is cut at the last space that fits and the rest starts the description, so nothing is lost; a web address the cut would split moves whole into the description, and the title is the text before it or the address's host.
  - `Task.maxReminders` (100): the add-reminder chip is off at 100, and Quick Add stops the sheet's and the default reminders there.
  - The filter parser refuses business-day offsets above 10000 in all with the server's 4019, so the device never shows tasks for a filter the server refuses.
- **U+0000 is removed from every JSON write,** once, in the write transport, nested values and keys included, because 2.8.0 refuses such a body with 400. The outbox's recovery of a create whose answer was lost, its description check and the label lookup compare without it, and a label is created with the cleaned title, so a pasted NUL neither duplicates a task or label nor fails a write for good.
- **The server's `/info` is read again while signed in** (owner), by `ConnectionRefresh` on the foreground sync scheduler:
  - when the active account is first in front after the app starts, then at most every 6 hours while it is in front, and 5 minutes after a probe that did not reach the server;
  - an answer from another root or an unsupported server is not stored, and an API version the account has is never dropped, only added (a timed-out `/api/v1/info` would otherwise move attachment previews to v2);
  - a changed answer is stored, so the Account tab shows the new version, notices and legal links, and a changed server or API version rebuilds that account's API clients and sync engine, as a new sign-in does;
  - only the active account is read again, and background runs never read it.
- **Legal links:** `LegalLinks.links` holds the server's legal links (a web address with a host, and a text), built from the two deprecated fields on servers before 2.8.0 and stored with the connection; two texts at one address are both kept, only an exact repeat goes. The imprint and the privacy policy also come from a link named exactly "Imprint" or "Privacy Policy". [D81](#d81-vikunja-280-details-legal-links-okabeito-colours-lockout-hints-subtask-tree-accents) says how they are shown.
- **Quick Add takes the web's new phrases** (owner), while punctuation after a phrase still ends it; [D38](#d38-quick-add-the-webs-grammar-with-fixes-through-the-outbox)'s point 9 has them. The help sheet shows `in two weeks` and `in 30 minutes` as well.

Limits:
- A paste over 1000 code points into a single title field is cut without moving the rest.
- The Quick Add preview and its "Added" message show the uncut line, so submit creates a shorter title than the plan shows.
- U+0000 stays in multipart uploads, a link share's password and an invitation token.
- `LocalFilter.compileWithRequest`'s saved-filter branch, which only tests use, gives each filter its own business-day budget.

## D79: The trash of Vikunja 2.8.0: Undo, queued deletes, a trash page

*Accepted 2026-11-10 (step 37f), the owner's decision where marked; the English texts say "trash" since step 38a (in review).*

The server's behaviour is in [research/trash.md](research/trash.md): trash routes on `/api/v2` only, from 2.8.0, with no flag in `/info`; 30 days, purged hourly; writers see and restore trashed tasks, only project admins purge, empty and see trashed projects.

- **`Capability.trash` means v2 and 2.8.0 or newer,** development builds and `v2.8.0-N-g…` included, a version the app cannot parse not. Link-share guests have it too, since a write guest may restore by id, so Undo works for them; the trash page is for users only.
- **Terms:** English "trash", as on the web, since US English is the base ([D71](#d71-english-and-german-us-base-glossary-error-texts-live-language-changes); in review), German „Papierkorb“; moved to the trash / in den Papierkorb verschoben, Restore / Wiederherstellen, Delete forever / Endgültig löschen (also for the server's purge, never "for good"), Empty trash / Papierkorb leeren, Trash emptied. Code, ARB keys and the API say "trash" too.
- **The delete confirmations stay, with trash wording,** on servers with the trash (owner; the 2.8.0 web dropped the task confirmation):
  - a task "moves to the trash, for everyone" and can be restored for 30 days; users are told the trash is on the Account tab, guests get a variant without that;
  - a task with a temporary id "hasn't reached the server yet" and "won't be in the trash", for users and guests;
  - a project moves there with its counted tasks and subprojects (counted locally), a default project inside stops being the default even after a restore, and it can be restored for 30 days;
  - older servers keep the old texts. Delete stays hidden for archived projects and the default project.
- **Undo only on servers with the trash** (owner), for users and write guests, because elsewhere a delete cannot be taken back once sent:
  - "Task moved to the trash · Undo" and "Project moved to the trash · Undo" for 10 s, as on the web, replacing a snackbar still showing; under a screen reader it stays until used or closed (a snackbar without Undo never stays);
  - a task whose create never reached the server reads "Task deleted" with Undo while its delete is queued, and without Undo when it was discarded at once (its create refused);
  - when Undo fails because the delete is on its way or the device is offline, the message offers Undo again; its result waits behind a newer snackbar instead of hiding it;
  - older servers keep "Task deleted" without Undo; signing out of the last account clears the snackbars.
- **A delete is queued like any other op, on every server,** so Undo can take it back; the outbox's rules for it are [D34](#d34-outbox-local-first-task-writes-one-serial-sender-coalescing-retry-classes)'s and, for unsent creates, [D35](#d35-task-creates-through-the-outbox-under-temporary-negative-ids)'s.
- **Task Undo is `TaskRepository.restoreTask`:**
  - a queued delete (pending, or failed as a sync problem) is taken out (`unqueueDelete`) and the row shows again with its queued changes, without a request;
  - a delete tried before (`last_attempt_at` set) may be on the server, so the task is also restored there, a live task answering 4042 and then read; a request that does not get through leaves the row showing; only a refusal that keeps the task in the trash (no permission, a domain error, 3018) is reported, the row showing all the same;
  - a delete in flight is waited for (every 250 ms, at most 30 s), then decided again; after 30 s the user is asked to try again;
  - a delete the server made is undone with `POST /api/v2/tasks/{id}/restore`; the answer is stored at once, ops the server refused while the task was gone go back to the queue (`retryRefusedAsGone`), and a quiet sync follows.
- **Project Undo is `ProjectRepository.restoreProject`:** `POST /api/v2/projects/{id}/restore`, then the sync after a write, which pulls the project whole; if that run fails, the answer is stored and a whole pull is marked for the next run. What the local delete purged stays purged: the subtree's queued creates, edits, uploads, task deletes and sync problems, list preferences and collapsed state; a task whose own delete had not gone out comes back alive. The default project the server unset stays unset, as on the web.
- **The trash page** (owner; `TrashPage`, `/home/trash`, closed to guests) is a third row, Trash, in the Account tab's Organize section, on servers with the trash only, and an 840 dp screen ([D69](#d69-large-screens-a-window-layout-helper-readable-widths-capped-dialogs-and-sheets)):
  - two tabs, Tasks and Projects, each read whole when opened (at most 20 pages, 1,000 items), with pull to refresh and a refresh button; online only, with the teams page's offline and failure states, and "This server doesn't support the trash" when the server has none;
  - a task row: the title, its project when stored here, "Deleted 3 days ago by Kim" (by you, through a link share, or no one named) and "Deleted forever in 27 days" ("today" at 0); Restore, and Delete forever only with `can_delete_permanently`;
  - a project row: its coloured folder and title, "With 2 subprojects: Garden, Tools", the same two lines counted from the listed project's date; Restore and Delete forever;
  - at large text the buttons go below the lines; Delete forever asks first;
  - each tab has a 30-day note and Empty trash, which reads the count first: with nothing to delete the tab is read again, and the Tasks tab says that only project admins can delete these forever when a listed task is not the user's to delete; otherwise it asks "Delete the tasks in the trash forever?" (or the projects) with the count, how many others moved there and, when a listed task is not the user's to delete, that such tasks stay. Empty always includes what others moved there (the web's checkbox defaults to it);
  - a project restore reads the task tab again; results are announced, failures show in a snackbar with a text for each action and code (an archived project, 3008, among them).
- **A link or notification to a task in the trash:** the opener says "This task is in the trash" (4040) or "This task's project is in the trash" (3018) instead of "not found"; with 4040, `can_restore`, a signed-in user (not a guest, as on the web) and a server with the trash, its snackbar offers Restore, which brings the task back and opens it. On servers with the trash the inbox's "task deleted" entry reads the task from the server first (`openDeletedInActiveAccount`), so a stale row is not opened: a live task opens, 4040 and 3018 answer as above, and offline or on 4002 it says "This task was deleted".
- **"In the trash" only where the user acts on the trashed thing:** the opener and the inbox, the sync problems (4040 "The task is in the trash on the server.", 3018 "Its project is in the trash on the server.", upload problems included) and, on servers with the trash, the project edit page's identifier error, which adds that a project in the trash keeps its identifier for 30 days. Every other failure text says "no longer exists" ([D78](#d78-vikunja-280-trash-codes-as-gone-its-limits-no-nul-info-re-read)).
- **30 days is a constant** (`trashRetention` in `vikunja_logic`); `trashDaysLeft` rounds up and stays between 0 and 30, also with a device clock behind the server.
- No grouping, sorting or search in the trash.

Limits:
- A create sent without an answer gets the "won't be in the trash" confirmation, although it may end up there.
- The opener's Restore offers no retry after a failure.
- The trash lists stop at 1,000 items without saying so.
- An action on the trash page answered by a proxy's bare 404 says "This server doesn't support the trash".
- An item can show "today" for up to an hour after its 30 days, until the server's hourly purge.
- A Discard of a refused create does not start a drain.

## D80: Reminders follow subscriptions on Vikunja 2.8.0 and later

*Accepted 2026-11-10 (step 37g), the owner's decision where marked.*

The server's behaviour is in [research/subscriptions.md](research/subscriptions.md): 2.8.0 reminds only a task's resolved subscribers (the user's own row on the task, else on its project, else on the nearest ancestor; an opt-out drops the user); it subscribes creators and new assignees on its own, and the upgrade subscribed every creator and assignee. For tasks only single reads carry the state, and a follow change is invisible to a sync.

- **The gate is the server version alone:** `Capability.remindersToSubscribers` means 2.8.0 or newer on any API version, development builds and `v2.8.0-N-g…` included, a version the app cannot parse not, because the server routes reminders whatever API the app speaks and the v1 reads carry the state too.
- **Older servers and link-share guests keep [D17](#d17-notification-policy):** 2.7.1 reminds creators and assignees whatever they follow, and a guest cannot follow (403 code 1).
- **One rule for reminders and due dates:** on these servers both notify about the tasks the user follows, and unfollowing a task silences it on the phone too (owner), as it has to silence the due-date alarm as well, and the server's overdue e-mail goes to the same subscribers. Following someone else's task brings its notifications, following a project those of all its tasks, subprojects included; a project owner gets none for other people's tasks unless following them.
- **What is stored** (schema 12):
  - **per project,** `projects.subscribed_via` (null for none): the project whose subscription covers it (`Project.subscription`, which `parseProject` reads leniently: only a project entity counts, a malformed value is none). It comes from every project list, on every server, and is unused before 2.8.0; as `Project ==` includes it, a follow change reaches the database with the next incremental run without an extra request. The project menu's read and toggle store their answer at once (`ProjectsDao.storeSubscription`, written only on a change), also for the stored subprojects covered through that project; a subproject a nearer project covers keeps that, and one none covers waits for the next project list;
  - **per task,** `tasks.own_subscription` (null for unknown): the user's own row as last learnt, `subscribed`, `none`, `none_assigned` or `opted_out` (`OwnTaskSubscription` in `vikunja_logic`). It is recorded only on these servers and only for users (`RegisteredAccount.subscriberId`), from the details read when a task opens online (`LocalTaskDetailsRepository`) and from the bell's reads and read-backs (`LocalSubscriptionRepository`), through `TasksDao.storeOwnSubscription`, which judges the read against the stored follow state of the task's project and its stored assignees in one transaction and writes only on a change. A read through a project first stores that project's subscription for the task's stored project when that is the project named or lies below it. `upsertAll` never writes the column, so syncs, a full resync, write answers and the outbox keep it, and a new row starts unknown. A failure to record is logged and never fails the read.
- **How a read is stored** (`ownTaskSubscriptionFrom`) **and when a task notifies** (`SubscribedTasks.covers`):

  | The read says | Stored |
  |---|---|
  | a subscription naming the task | subscribed |
  | one naming a project | none, or none while assigned when the user is an assignee here |
  | none, the task's project followed here | opted out |
  | none, the project not followed here | none, or none while assigned: an old opt-out cannot be told apart |

  | Stored | The task's reminders and due date reach the user when |
  |---|---|
  | (a temporary id) | always: the user created it |
  | unknown | the user created it, is an assignee or follows its project, as the server and its upgrade subscribe creators and assignees |
  | subscribed | always |
  | none | the user follows its project, or is an assignee now (the server subscribes a new assignee without an own row) |
  | none while assigned | the user follows its project |
  | opted out | never: the server keeps an opt-out through assignments and project changes |

  Done tasks and tasks queued for deletion stay out.
- **No extra requests:** a follow change made on the web reaches the phone with the next read of the task in the app online (opening it, also from its notification, or the bell); a project's with the next sync run.
- **The bell and the project menu stay online-only** ([D41](#d41-relations-as-task-update-deltas-duplicate-and-follow-online-indented-subtasks)); offline the bell stays unknown and refuses, although the state is stored. After the server answers, the read-back is stored and the scheduler, which also watches `projects`, plans again within its debounce of about 700 ms. An unfollow that went through, of a task or a project (with the subprojects covered through it), is recorded as none before its read-back, so a failed read-back does not keep them ringing; a follow waits for its read-back, as it may have been a 412 through a parent. A project's toggle also starts a quiet `refreshAfterWrite`, so the other subprojects follow with the next project list.
- **Isolates and widgets:** the background sync, the notification actions and a widget's Done build the same `notificationSchedulerProvider(accountId)`, which selects the user id and whether the account follows subscriptions from its stored capabilities. A refreshed `/info` that turns `remindersToSubscribers` on or off ([D78](#d78-vikunja-280-trash-codes-as-gone-its-limits-no-nul-info-re-read)) rebuilds the scheduler, which plans again at once; other capability changes or a new display name do not.
- **The schema 12 migration** adds both columns as null and keeps `last_full_sync_at`: the next project list fills `subscribed_via`, and every task starts unknown, which `covers` reads as [D17](#d17-notification-policy) plus the followed projects, the state the server's upgrade left.
- **Texts** ([glossary](glossary.md): following, folgen):
  - the notification setup's third point on 2.8.0 and later: "Only for tasks you follow — you automatically follow the ones you create or are assigned to" („Nur für Aufgaben, denen du folgst – du folgst automatisch allen, die du erstellst oder die dir zugewiesen werden“); older servers and guests keep "Only for tasks you created or are assigned to";
  - a line in the Account tab's Notifications section, under the one that says these settings stay on this device: on 2.8.0 and later "Reminders and due dates notify you about the tasks you follow: the ones you create or are assigned to, and those in projects you follow. Unfollow a task to stop its notifications.", on older servers "Reminders and due dates notify you about the tasks you created or are assigned to.", none for guests;
  - the general texts stay: the Android channel's description, the follow dialogs, whose "notifications" include the reminders, and the share cleanup's "subscriptions" („Abonnements“).

Limits:
- A follow change made on the web reaches the phone only with the next read of the task in the app; until then the phone may ring once more, or stay silent for a task followed there.
- Ex-assignees: the server keeps their row and keeps reminding; the phone stops, unless the task was read while the user followed it.
- Unfollowed while assigned, then unassigned and assigned again: the server follows the user again, the phone stays silent until the next read.
- A read made before the sync brought an assignment records the wrong assignee flag until the task is read again.
- A read while the stored follow state of the task's project is out of date (changed on the web before the next sync): an own task unfollowed under a project followed there is recorded as none, so the phone rings while the server does not; a task without an own row read under a project unfollowed there is recorded as opted out, so the phone stays silent when the project is followed again or the user is assigned; both until the task is read again.
- An old opt-out read while its project was not followed counts as none: when the project is followed again, the phone rings and the server does not.
- Inactive accounts on an upgraded server keep [D17](#d17-notification-policy) until they are active once and their `/info` is read again.
- A task restored from the trash starts unknown again; the restore answer is not recorded.
- Large followed projects bring many notifications; the window still holds the soonest 100 (Android) or 60 (iOS).
- Not built: the bell's stored state shown offline, the project menu seeded from the stored state, a hint on a task with reminders the user does not follow.
- The website's support pages and project page (`src/content/support/rurana.en.md`, `rurana.de.md` and `src/content/projects/rurana.md` in the separate repository of the app's pages) still describe the old rule; left for the owner.

## D81: Vikunja 2.8.0 details: legal links, Okabe–Ito colours, lockout hints, subtask tree, accents

*Accepted 2026-11-10 (step 37h), the owner's decision where marked.*

**Legal links:**
- Every legal link the server lists shows (owner), in the server's order, when it has a text and a web address (http or https with a host): on the server overview and in the Account tab's Server section (`ServerNotices`), as link buttons with an open-in-new icon (`LegalLinksRow.shownOf`). The row shows when one link does.
- The exact texts "Imprint" and "Privacy Policy" (`LegalLink.imprintText`, `privacyPolicyText`), case-sensitive as on the web, show in the app's words (Imprint, Privacy policy; Impressum, Datenschutzerklärung); every other text as its admin wrote it, untranslated (owner). Two links that then read the same at one address show as one button (Imprint and Impressum in German).
- The parser (`server_info_parser.dart`) leaves out relative addresses and trims texts; which links it keeps is [D78](#d78-vikunja-280-trash-codes-as-gone-its-limits-no-nul-info-re-read)'s. `imprintUrl` and `privacyPolicyUrl` stay in the domain; the UI does not read them.
- The test server lists a further link (owner): "Terms of Service" at `https://example.org/terms`, in the shared environment block of `test_servers/docker-compose.yaml`, so the TLS server has it too.

**Colours:**
- Every colour row offers the Okabe–Ito palette (owner): `okabeItoColors` (`features/tasks/application/color_palette.dart`), the seven colours of Okabe and Ito's "Color Universal Design" (J\*FLY, 2002, revised 2008) in its order without black: `e69f00`, `56b4e9`, `009e73`, `f0e442`, `0072b2`, `d55e00`, `cc79a7` (why no black: a black label or folder disappears in the dark theme).
- `ColorRow` offers them for tasks (the edit page), projects (the new-project sheet and the edit page) and labels (the form), after "No color" and before the item's colour when the page opened and its current colour, each while it is none of the seven, so a colour set elsewhere stays, shows as chosen and can be chosen again until the page is left (owner: colours already set stay).
- A new label gets one of the seven at random (`randomLabelColor`): the label form, the label picker and Quick Add.

**API token presets:**
- On 2.8.0 the presets include the trash's permissions as the web's do (owner); [D55](#d55-security-settings-two-factor-status-sessions-and-tokens-a-new-token-shown-once) has them.

**Lockout hints:**
- Vikunja 2.8.0 locks a local account at the tenth wrong password since the last successful sign-in (at sign-in, at the web's prompts or from a CalDAV app, on any device), ends every session and stays locked until a password reset or an admin lifts it.
- `Capability.accountLockout` means 2.8.0 or newer on either API version, development builds and `v2.8.0-N-g…` included, an unparsable version not.
- On such a server, for an account with a password, "Ten wrong passwords sign you out on every device and lock your account until you reset your password." (`accountSettingsAccountLockout`) follows "The web asks for your password.", joined with a space (`webAsksPasswordNote`, `withAccountLockout` in `web_password_note.dart`), wherever the app says that the web asks for the password (owner):
  - the deletion dialog and the data export page;
  - one note with a lock icon under Change password and Change email address, for both rows (why: the email row's subtitle is a fragment or the pending address);
  - both two-factor notes; the note to turn it on also says that this needs the password (`accountSettingsTotpTurnOnPasswordNote`), because 2.8.0 asks for it there too. Older servers keep the note without it.
- A scheduled deletion (owner): for a local account, `DeletionScheduledNote` (below the Account tab's header and at the top of Account settings) says under the date, in the note's colour and one size smaller, "The web asks for your password." on every server, since the web's cancel page asks for it, plus the lockout sentence on 2.8.0 and newer. The Delete account row of a scheduled deletion, which opens the web without a dialog, says the same below "Cancel it on the web.", small and muted (why: on a phone the note at the top is far from the row the user taps).
- The CalDAV page, on a server with `Capability.accountLockout` (owner):
  - recommends a CalDAV token instead of the account password (`caldavTokenRecommended`), because a calendar app that keeps trying an old password, for example after a password change, locks the account after ten tries; this for a local account without two-factor authentication and while the account's kind or two-factor status is not known. The texts with two-factor on and for a sign-in provider's account stay, as they name only a token;
  - the delete confirmation (`caldavDeleteBodyLockout`) reads "CalDAV apps using it can no longer sign in. This cannot be undone. Remove it from those apps first; otherwise every further try with it counts as a wrong password, and ten wrong passwords lock your account until you reset your password." It says what cannot be undone right after the deletion, so that this is not read as the lock, and names the lockout itself, since with two-factor on the page's text above does not. It shows for an account with a password or whose kind is not read yet, with two-factor on too (why: 2.8.0 checks a CalDAV password that matches no token as the account password), not for a sign-in provider's account;
  - API tokens are not mentioned; older servers keep their texts.

**The List view's subtask tree:**
- On every server it follows the web's since 2.8.0: a task expands once per top-level row and at most five levels deep (owner); [D43](#d43-task-lists-from-the-local-database-nested-and-ordered-like-the-webs) has the rules.

**Accents in search** (on every server, owner):
- Every search field that filters on the device ignores case and accents through `foldForSearch` (`core/filters/search_index.dart`): lower case, the full case foldings, then `foldAccents` (`core/text/title_order.dart`), [D71](#d71-english-and-german-us-base-glossary-error-texts-live-language-changes)'s fold behind `compareTitles`, with the Romanian ș and ț and pure ASCII returned at once. It serves:
  - the search page, for the query and every text it compares (task titles and descriptions, the identifier, projects, saved filters, labels);
  - the label picker, the Labels page and Quick Add's label suggestions (`filterLabels`), and Quick Add's project suggestions;
  - the people the device knows, shown by the assignee picker until its server search answers and when it fails, and suggested by mentions and Quick Add (`filterUsers`);
  - the project's people the assignee picker has from the server's answers, the empty query's included, matched against each later query and added to the server's answer, so a member its search misses for an accent stays and no one without access is added;
  - the add-relation sheet (`relationCandidates`), the team picker (`filterTeams`), the share sheet's Add to task (`shareTargets`), the time zone and server language sheets (`SearchableOption.matches`);
  - the filter field's value suggestions (owner, [D51](#d51-filter-engine-on-the-device-saved-filters-filter-builder-offline-search)).
- Not folded (owner): the `like` filters and a view's or saved filter's stored search, as the server applies them (why: the device would otherwise find tasks the server does not). Also not folded: "Create label" (the exact title, ignoring case only), Quick Add's exact resolution of `*label`, `+project` and `@user`, and the searches the server runs.

Limits:
- Relative legal addresses are not shown, although the web shows them; texts are trimmed.
- The fold covers Latin letters only; Greek, Cyrillic and Vietnamese accents still count. The ș and ț also change how titles with them sort.
- The searches the server runs (mentions online, the person search when sharing a project, Quick Add's people from the server) mind accents on SQLite and on PostgreSQL without `unaccent`; on MySQL the collation decides. Online, the assignee picker ignores accents only among the project's people its answers have listed, so when the empty query's answer failed, its server search decides.
- The swatches are read aloud as hex codes; names would need seven new strings.
- The app learns of a lock only through a failed refresh (401 code 16002) and then asks for a new sign-in, where the web's sign-in page says that the account is locked.

## D82: Projects list–detail: the project tree beside the project on wide windows

*In review since 2026-11-10 (step 36g), the owner's decision where marked.*

- Part of the first release's beta build (owner, [D72](#d72-first-release-android-and-ios-together-play-and-a-gitlab-apk-beta-first)).
- On wide windows the project tree, the open project and the task pane always stand side by side, and the pane keeps [D70](#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere)'s width (owner). Below the gate and on every phone nothing changes.
- **Gate** (`WindowLayout.threePane(besideRail:)`, `app/lib/app/layout/window_layout.dart`; checked in `HomeShell`): the tree's column shows where [D70](#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere)'s pane can (`twoPane`, not in tabletop posture), where no vertical fold or hinge divides the window (`hasVerticalFold` in `pane_split.dart`, shared with `paneSplitFor`), for an account that is no link-share guest, and where the window, less a rail of 80 dp where the rail shows (`railWidth`), is at least 1,120 dp wide (`threePaneContentFrom`).
  - 1,120 is Material 3's large class (1,200 dp) less its rail: Android windows from 1,200 dp and iPad windows from 1,120 pt, at least 480 high, so every iPad in landscape and none in portrait. It fits the tree, a project of about 350 dp and the pane at 448 dp.
  - It comes from the window, not the measured content (why: the content changes with the rail's labels, so the gate would flip with the language and the text size).
  - No column for guests (why: it would hold one row, the project already open) or on a fold (to be safe; no known device of that width has one).
- **Where:** only the Projects tab, at `/home/projects` and `/home/projects/:id`, beside a project, Favorite tasks or a saved filter. Other tabs keep [D70](#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere)'s two panes; pages over the shell cover the tree's column as they cover the tabs.
- **Layout,** from the start edge: rail, the tree's column (320 dp, the narrowest phone width the app lays out for), a 1 dp divider, the tab's pages, [D70](#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere)'s divider, the pane.
  - The pane keeps [D70](#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere)'s rule (40 % of the content beside the rail, 360–480 dp, from the whole content; the same `paneSplitFor`), so it looks the same in every tab (owner).
  - The tab's pages get the rest: lists, the Table view and the smart lists keep [D69](#d69-large-screens-a-window-layout-helper-readable-widths-capped-dialogs-and-sheets)'s 840 dp band in it, the board and Gantt take its whole width (the board one column at a time below 600 dp), and the header, view tabs and controls behave as on a phone at those widths.
  - The FAB stays in the project's area; the offline banner and snackbars span all three; on iOS the tab bar runs under all three. The tree's column keeps the start-side safe-area padding and the pages lose it, mirrored right to left.
- **Nothing open:** beside the tree's column the tab's first page (`/home/projects`) is `NoProjectOpen`: "No project open" and "Open a project from the list to see its tasks here." (`projectsNoneOpenTitle`, `projectsNoneOpenBody`), in the 840 dp band and without an app bar of its own. No project opens by itself, as [D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab) remembers no view and nothing remembers a last project. Below the gate the first page is the tree. The tree's column stays in place when a project opens, changes or closes.
- **The route is the source:** a row goes to `/home/projects/:id` exactly as on a phone, so links, the breadcrumb, search, widgets, the guest landing and [D70](#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere)'s location rule work as on a phone. The column reads the open id from the shell route's `matchedLocation` (`AppRoutes.projectIdIn`: the id of a project location without a query, else null).
  - The open list's rows (`ProjectsScreen(selectedId:)`) get [D70](#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere)'s selected look (the `surfaceContainerHighest` fill and the 4 dp `primary` bar on the start edge) and read as selected, while their texts and icons keep their usual colours (`ListTile`'s selected colours pinned to `onSurface` and `onSurfaceVariant`).
  - Marked are both rows of a favourite project, Favorite tasks and both rows of a favourite saved filter; never the dragged row, the row to create a saved filter or search's rows. A tap on the open row does nothing.
  - Another project replaces the middle and closes the tab's pane ([D70](#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere)'s location rule); selecting the tab again closes both, back to the note.
- **Back:** the pane's stack, the pane, the project, the note, then [D45](#d45-app-shell-colour-scheme-display-settings-projects-tab-smart-lists-offline-banner)'s tab rule (to the Overview). Beside the tree's column a project's or list's app bar has no back arrow (`ProjectTasksScreen`, its "project gone" scaffold included, and `SmartListScreen`, through `ProjectTreeColumnScope.shownOf`); the system back, the iOS swipe from the project's own edge and the tab still go back. No predictive back inside the tabs, as in [D70](#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere).
- **Resize:** crossing the gate adds or removes only the tree's column; the open project with its view and offsets and the pane with its stack and comment draft stay, and the tab's first page switches between the tree and the note.
  - Every child of the shell's row has a `ValueKey` ('tree column', 'tree divider', 'tabs', 'pane divider', 'pane gap', 'pane'), so the tabs' semantics region and focus group survive when both ends of the row change in one frame (why: a `Row` builds an unkeyed child between two changed ends anew).
  - The tree's column keeps its scroll offset across tab switches, per account (a `PageStorageKey` of the tree and the active account). The tree's menu (route `project-tree-menu`), if open when the gate is crossed, closes with the tree that opened it.
- **One tree at a time:** the column (`ProjectTreeColumn` in `features/projects/presentation/project_tree_column.dart`) holds the same `ProjectsScreen` (app bar with search, New project, the menu and the account switcher; sync bar; sections; drag and drop), built only while the Projects tab shows and not while the tabs reset after an account switch. Its rows are built lazily.
  - While the column shows, `ProjectsTab`, the page of `/home/projects`, keeps watching what the tree waits for (`projectsProvider`, `projectTreePreferencesProvider`, `savedFiltersProvider`, `favoriteTasksProvider`, `openTaskCountsProvider`), so these pause offstage with the tab instead of being disposed, and back on the tab the column shows its tree in the first frame.
  - `ProjectTreeColumnScope(shown:)` has the same value in every tab, so the Projects tab's offstage pages do not change with the tab shown.
- **Accessibility:** the tree's column, the tab and the pane are regions of their own (a semantics container and a focus group each), read and tabbed in that order after the rail; the tab is a region whenever the column or the pane shows. Each keeps its level-1 title, which [D68](#d68-screen-readers-headings-one-announcer-high-contrast-reduce-motion-route-sweep) allows: Projects, the project, the task. With nothing open the note's title is the tab's level-1 title (`EmptyState(isScreenTitle:)`), which on Android also names the route, as an app bar's title does. Nothing is announced; focus follows Flutter's defaults. [D68](#d68-screen-readers-headings-one-announcer-high-contrast-reduce-motion-route-sweep)'s sweep runs its tablet-landscape passes (Android 1280 × 800, iPad 1194 × 834) with the tree's column and measures the bands from its divider.
- **iPad:** the same layout from 1,120 pt, with the bottom tab bar and no sidebar.

Limits:
- With a task open at 1280 × 800 and on an 11" iPad, a project's list is phone-wide and Kanban shows one column at a time.
- The tree's column does not keep its scroll offset across the gate, where the page's tree is another one.
- Two sync bars side by side, the tree's and the project's.
- Right to left only through the row's mirroring; the app has no right-to-left language yet.
- Play's tablet screenshots 02-kanban and 04-project-detail predate the tree's column ([store listing](store-listing.md#screenshots)).
- Not checked yet with real data on a tablet, on iPad, on a foldable or with TalkBack ([checklist](accessibility-checklist.md#25-checks-of-step-36g)).
- Not built: an option to hide the tree (it may come later, owner); the tree making way while a task is open; dragging a task onto a project in the tree; revealing the open project in a collapsed or scrolled tree; keyboard and Esc between the column, the project and the pane (36d).

## D83: Successor of the official Vikunja app in go-vikunja/app

*Accepted 2026-11-12, the owner's decision, agreed with the Vikunja maintainers; the decisions of 2026-11-13 for the switch (owner) and step 38a in review.*

- The app becomes the official Vikunja mobile app and moves into https://github.com/go-vikunja/app; the owner is its main maintainer.
- **Android:** the Play listing `io.vikunja.app` stays in Vikunja's Play account, and the app ships there as an update of the old app: the same application id, signed with Vikunja's upload key, with a higher version code (why: the old app's installs keep updating).
- **iOS:** the bundle id `io.vikunja.app` now, since nothing is registered at Apple yet (owner, 2026-11-13; [D15](#d15-app-id-iovikunjaapp-and-the-name-vikunja)). Which Apple account publishes the app is open.
- **Licence:** MIT, in place of [D67](#d67-agpl-30-or-later-with-an-app-store-permission-dco-reserved-brand-embedded-cronet)'s AGPL with the app store permission, from the move on.
- **Name and icon:** "Vikunja", and an icon derived from Vikunja's `logo.svg` with the old app's icons as the look to follow (owner, 2026-11-13), in place of Rurana and its llama ([D15](#d15-app-id-iovikunjaapp-and-the-name-vikunja), [D42](#d42-app-icon-vikunjas-logo-every-variant-derived-by-script)).
- **Language:** US English like the Vikunja web; the German stays (owner, 2026-11-13; [D71](#d71-english-and-german-us-base-glossary-error-texts-live-language-changes)).
- **Translations:** Vikunja's existing Crowdin project; its integration is still to be built (step 38e), and it replaces step 36f.
- **Order:** the remaining steps of the roadmap were finished first; the switch follows as steps 38a–38f, then the beta of 37d in the official listing. Until then nothing that would fix an id is created: no signing keys, Play app, Apple App IDs or release tag (why: [D15](#d15-app-id-iovikunjaapp-and-the-name-vikunja) makes an id permanent once these exist).
- **Step 38a, the identity** (in review): the application id `io.vikunja.app` with every id derived from it, and the scheme and client id `vikunja-io.vikunja.app` ([D15](#d15-app-id-iovikunjaapp-and-the-name-vikunja), [D23](#d23-browser-sign-in-through-flutter_web_auth_2-in-an-ephemeral-session)); the name in the app's texts, the store texts and their checks, without the "unofficial" lines ([D76](#d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android)); the icons from Vikunja's logo ([D42](#d42-app-icon-vikunjas-logo-every-variant-derived-by-script)); US English ([D71](#d71-english-and-german-us-base-glossary-error-texts-live-language-changes)); the User-Agent `Vikunja-App/…` with the sessions page's label ([D55](#d55-security-settings-two-factor-status-sessions-and-tokens-a-new-token-shown-once)). The internal names that ship or that contributors see were renamed while nothing depends on them: the widgets plugin `vikunja_widgets`, the iOS extension target `VikunjaWidgets` and the WidgetKit kinds `VikunjaTasks` and `VikunjaQuickAdd` ([D63](#d63-home-screen-widgets-app-written-snapshots-glance-on-android-widgetkit-on-ios)), the root package `vikunja_app` with the notice asset `assets/legal/vikunja_app.md` ([D67](#d67-agpl-30-or-later-with-an-app-store-permission-dco-reserved-brand-embedded-cronet)), the editor bridge `VikunjaEditor` and `window.vikunja` with the npm name `vikunja-editor` ([D52](#d52-descriptions-edited-in-a-locked-down-tiptap-webview-never-silently-overwritten)), the background runners' and the pre-consent probe's names and the IDE's run configurations.
- **Left by step 38a for the later steps** (in review):
  - 38b, the update from the old app: the old status bar icon's name `vikunja_notification_logo` as an alias ([D42](#d42-app-icon-vikunjas-logo-every-variant-derived-by-script)); reading the old app's secure-storage entries before the app wipes them (flutter_secure_storage's key alias most likely follows the package name, now the old app's); whether `io.vikunja.app.MainActivity` is the old app's launcher component; the old app's jobs, notification channels, Glance receiver and Quick Settings tile, which do not clash with the new names; the old app's User-Agent "Vikunja Mobile App", which the sessions page shows as it is stored.
  - 38c, CI and releases: the `RURANA_*` variables, `.gitlab-ci.yml` and the GitLab release names (`rurana-<version>.apk`, the generic package `rurana`, the release title "Rurana …"), and a contract run: the two Docker-only contract tests carry the new client id and redirect but have not run against a server yet.
  - 38d, the licence and the move: `NOTICE.md` and the app's notice (the copyright "Benedikt Lesch and the Rurana contributors", "Rurana, an unofficial mobile client…", the name-and-logo terms and their file table, which until then call the regenerated icon files derivatives of the llama), the About page's "Name and logo" row and licence lines, `copyrightNotice`, the llama source and the explorations in `branding/`, and `CONTRIBUTING.md`.
  - 38f, the store listing and the website: the app's pages on `coderoftime.dev/rurana/…` (the About page's rows, the store URLs and their checker), the contact `coderoftime@gmail.com`, the listing's languages (the `en-GB` texts stay British until then), the screenshots, which still show the llama and Rurana, and the App Store name if "Vikunja" is taken there.
  - Test data that needs Docker or a new capture keeps the old name: the TLS test certificates, the seeded E2E user, the captured fixtures and their capture tools, and the contract tests' user agents and titles.
- With the later steps [D67](#d67-agpl-30-or-later-with-an-app-store-permission-dco-reserved-brand-embedded-cronet) (38d), [D72](#d72-first-release-android-and-ios-together-play-and-a-gitlab-apk-beta-first), [D73](#d73-gitlab-ci-from-local-scripts-versions-from-the-tag-release-signing) and [D77](#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers) (38c) and [D76](#d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android) (38f) change.

Open:
- Whether the owner gets release rights in Vikunja's Play Console.
- The Apple account, and whether `io.vikunja.app` is still free at Apple ([D15](#d15-app-id-iovikunjaapp-and-the-name-vikunja)).
- How the old app's history and this repository's history are joined.

## D84: Everyday editing in the task detail: properties in place, task links, Move to column

*Accepted 2026-11-12 (step 37k).*

- **Properties in place,** in the sheet and in the pane ([D70](#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere)):
  - The Due date, Priority and Reminders rows are buttons, the whole row, with the tap hints "Change due date", "Change priority" and "Edit reminders".
  - The Labels row has a "Change labels" button after its pills, with a label icon rather than the header's Edit pencil. The pills keep opening the label's tasks ([D60](#d60-labels-teams-and-shares-online-the-stored-project-permission-shapes-every-screen)) (why: they are buttons of their own, so the row cannot be one).
  - Unset properties show as one add row at the end of the attribute card: "+ Due date", "+ Priority", "+ Reminder" and "+ Label", spoken "Add due date", "Set priority", "Add reminder" and "Add label". It holds only the properties that are unset and may be set, and wraps on a narrow phone. A bare task gets a card that holds only this row.
- **What each control opens** (`features/tasks/presentation/details/attribute_editors.dart`):
  - Due date: a list with Today, Tomorrow and Next week, the new-task sheet's shortcuts ([D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab)), each at the time already set, else at the next breakpoint ([D35](#d35-task-creates-through-the-outbox-under-temporary-negative-ids)), with its date and time under it and the current due date's day checked; then "Pick date…" (the edit page's date and time pickers) and, when a due date is set, "Clear due date". The edit page keeps the full row of shortcuts.
  - Priority: a list of the six levels, Unset included, the current one checked.
  - Reminders: a sheet with the edit page's reminder rows. A tap edits a reminder, the cross removes it, "Add reminder" adds one up to 100, and each change is written at once. The same reminder twice and a reminder at the moment of another are refused with a line under the sheet's title, because the server keeps one reminder per moment ([D36](#d36-labels-assignees-and-reminders-in-the-task-update-label-creation-online)). "+ Reminder" opens the reminder picker directly, and a refusal there shows as a message.
  - Labels: the label picker. Done writes the labels added and removed against those it opened with; dismissing it writes nothing.
- **Writing:** each choice is one `TaskChanges` of its field through the outbox ([D34](#d34-outbox-local-first-task-writes-one-serial-sender-coalescing-retry-classes), [D36](#d36-labels-assignees-and-reminders-in-the-task-update-label-creation-online)), offline too, written onto the task's row as it is once the choice is made.
  - A choice that changes nothing writes nothing; a due date counts to the minute it shows.
  - No Undo and no confirmation: the row changes at once, and screen readers hear what changed (the new due date, "Due date removed", the priority, "Reminder added", "Labels changed" and the like).
  - The sheet stays open. A choice made after the screen that asked has gone, as the pane goes when the window narrows, is still written and said.
- **What stays on the edit page:** project, title, start and end dates, progress, colour, repeat and assignees.
- **Who may:** write permission ([D60](#d60-labels-teams-and-shares-online-the-stored-project-permission-shapes-every-screen)), a project not archived in the tree, and a task this device has a row of (why: a change for a task without one would be dropped). While the permission or the row is still loading, edits are offered.
  - In an archived project the sheet also leaves out Done and Edit, turns the star off and takes away the title's tap, the changes of subtasks and relations, Duplicate and Delete: only reading, Copy link and Share remain. A subtask follows its own project's permission and archived state.
- **The menu,** "More" ("More for *title*" in the pane): Move to column… (below), Copy link, Share, then Duplicate, then Delete. It shows whenever it holds an item, so read-only projects have it too.
  - Copy link and Share appear for every task the server knows (an id above 0), also in read-only and archived projects and offline; not for a task whose create is still queued.
  - Duplicate and Delete appear only with write permission, outside archived projects.
- **The task link:** `AccountLinkBases.taskLink` builds `{web frontend}tasks/{id}` on `webFrontendBase`: the frontend URL when it is http(s) and not http for an https server, else the server root, as for link shares ([D60](#d60-labels-teams-and-shares-online-the-stored-project-permission-shapes-every-screen)). A comment's link is that address with `#comment-{id}` ([D57](#d57-comments-online-with-a-kept-draft-reactions-comment-counts-and-unread-dot)).
  - Copy uses the plain clipboard (why: a task link carries no secret, and only members of the project can open it). Android 13 and later confirm the copy themselves; elsewhere "Link copied" shows in the sheet.
  - Share opens the system's share sheet through `LinkShareActions` (`shareWebLink`), with the task's title as the subject. Leaving the app for it does not lock the app ([D64](#d64-app-lock-over-the-ui-and-device-privacy-settings)), and on an iPad it is anchored on the menu button.
  - The link carries the task's database id, which is not shown or spoken ([D75](#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab)).
- **Search** ([D51](#d51-filter-engine-on-the-device-saved-filters-filter-builder-offline-search)): a pasted absolute http(s) address of a task on the active account's server or frontend shows one section, "Task from the link": the task's row when the device has the task, else "Open the linked task", which opens it through the opener ([D44](#d44-task-detail-own-rich-text-parser-online-details-app-scheme-links)). A link to a comment opens its task.
- **Move to column…** (`features/tasks/presentation/details/move_to_column.dart`):
  - Only in a detail opened from a board card. The card passes its board (`TaskBoardOrigin`: the project and the view) to `openTaskDetail`, which hands it to the pane's entry or to the sheet, and the change from pane to sheet on a resize keeps it. Tasks opened inside the pane or the sheet get none. When the task is already on top of the pane, its row from a list clears the board and its card sets it again.
  - Offered while the board's view is stored, the board may be changed (`boardIsReadOnly`: archived, no write permission, filter mode; [D47](#d47-kanban-board-from-per-view-snapshots-moves-through-the-outbox)), it has another column, and it still shows the card in its project.
  - The list holds the board's other columns in their order, numbered when titles repeat ("Later (2)", as the screen-reader actions name them), a full column greyed out with "Full" under it, and the done hint under the done column. A column that fills while the list is open refuses the card with the board's limit text.
  - The card goes on top of the chosen column by the board's own rules: the column's limit first, then the done column, where a repeating task is marked done and stays in the default column ([D47](#d47-kanban-board-from-per-view-snapshots-moves-through-the-outbox)). The move is planned against the board as it is once a column is picked and queued through the outbox, offline too.
  - A selection haptic and "Moved to …" in the sheet; a full column gets the heavy haptic and the board's limit text. The sheet stays open.
  - The board's drop announcement names the column the same way ("Moved to Later (2)").
- **Guests** ([D62](#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind)):
  - In-place edits follow the share's stored permission, as the edit page does: a read guest gets none, a write guest edits, and the label picker offers a guest no "Create label".
  - Copy link and Share are offered to guests of every permission, as the web copies a task's link from its identifier for every link share ([D62](#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind)'s rule).
  - Move to column… follows the board's own rule, as a write guest may already drag cards; it never changes the board's view (done or default column).
- **Accessibility** ([D68](#d68-screen-readers-headings-one-announcer-high-contrast-reduce-motion-route-sweep)):
  - Each button row is one node, a button with its hint. The add row's spoken labels contain their visible text (WCAG 2.5.3). Every new control has a 48 dp target and a name of its own.
  - The lists and the reminders sheet have level-1 titles. Every change is said through the one announcer.
  - After an editor, the keyboard focus returns to the row or button that opened it, and a focused comment field does not bring the keyboard back.
  - The sweep has a "reminders sheet" scenario, and its option-sheet scenario has an option with a second line.
  - Move to column… is a single-pointer way to move a card to another column (2.5.7).

Limits:
- A due date changed in the sheet can put a relative reminder on another reminder's moment; the server then keeps only one. The edit page warns before such a save, the sheet does not. So clearing the due date of a task with two or more reminders relative to it leaves one of them after the next sync.
- On Android, cancelling the time dialog after "Pick date…" keeps the picked date at the time the dialog started with.
- In the pane, Move to column… stays after a switch to another view of the same project; it still moves the card on the board it came from.
- When the pane gives way to a sheet while a list or picker is open, the choice is still written, but "Pick date…" then opens no date picker, and a refused reminder, "Moved to …" and the limit text are not shown.
- No Undo.
- Not checked yet with TalkBack or VoiceOver ([checklist](accessibility-checklist.md#26-checks-of-step-37k)).
