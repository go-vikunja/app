# Decision log

ADR-lite. Each entry has a number, a status and the step that took it. A decision is replaced by a new entry, never edited away. The background for most entries is in [research/synthesis.md](research/synthesis.md) §2–3 and [research/flutter-stack.md](research/flutter-stack.md).

## D1: Flutter 3.47.5 pub workspace with pure-Dart packages

*Accepted, step 1.*

- **Context:** The app needs shared logic that runs in the UI isolate, in background isolates and in plain unit tests.
- **Decision:**
  - Use Flutter 3.47.5 / Dart 3.13.4, the stable release installed when step 1 started. The 3.47.6 hotfix is not adopted yet.
  - The repository is one pub workspace: `app`, `packages/vikunja_domain` and `packages/vikunja_api`, plus `packages/vikunja_logic` later.
  - It has a single `pubspec.lock`.
  - Lints are very_good_analysis 11, with `public_member_api_docs` off.
- **Consequences:**
  - `flutter pub get` runs only at the root.
  - CI pins the exact Flutter version.
  - Code uses the Dart 3.13 constructor syntax (`new(...)`, `factory name(...)`), which the lint `unnecessary_type_name_in_constructor` enforces.
  - `packages/*/lib` must stay Flutter-free, which is checked in CI.

## D2: material_ui and cupertino_ui

*Accepted, step 1.*

- **Context:** The Material and Cupertino libraries inside the Flutter SDK are being decoupled. The in-SDK Material library is scheduled for deprecation (Nov 2026).
- **Decision:**
  - New code imports `package:material_ui/material_ui.dart` (1.6.x) and `package:cupertino_ui/cupertino_ui.dart` (1.1.x), never `package:flutter/material.dart` or `cupertino.dart`.
  - Localisation delegates come from material_ui (`GlobalMaterialLocalizations.delegates`).
- **Consequences:**
  - There is no migration later.
  - Third-party widgets built on the legacy libraries may need wrappers.

## D3: Riverpod 3 with code generation

*Accepted, step 1.*

- **Context:** Every entry point (UI, background tasks, notification actions, widget callbacks) must build the same object graph without a widget tree.
- **Decision:** Use flutter_riverpod 3 with riverpod_annotation and riverpod_generator for dependency injection and state. A headless `ProviderContainer` serves the non-UI isolates.
- **Consequences:**
  - The app needs a build_runner step. The generated `*.g.dart` and l10n files are committed, and they are excluded from analysis and from the format check.
  - CI regenerates them and fails when the result differs from the committed files. After changing ARB files or annotated providers, run `cd app && flutter gen-l10n && dart run build_runner build`.
  - riverpod_lint is not enabled yet, because it would be a new dependency.

## D4: go_router

*Accepted, step 1.*

- **Context:** The app needs deep links (`vikunja-<app>://task/<id>`, pasted web URLs) and later a bottom-navigation shell with per-tab stacks.
- **Decision:** Use go_router 18. It is owned by flutter.dev, works with material_ui, and has `StatefulShellRoute`. Step 1 has two routes: connect (`/`) and server overview (`/server`, nested under `/`). `/server` redirects to `/` while no server is selected.
- **Consequences:**
  - Routes are declared centrally.
  - go_router_builder (typed routes) can be added once there are enough routes to justify it.

## D5: dio with native_dio_adapter

*Accepted, step 1.*

- **Context:**
  - Self-hosters often use private CAs. On Android, `dart:io` ignores user-installed CAs (dart-lang/sdk#50435).
  - The client also needs interceptors for auth, retry and redacted logging.
- **Decision:**
  - Use dio 5 everywhere.
  - The app injects `NativeAdapter` from native_dio_adapter: Cronet on Android, NSURLSession on iOS.
  - The packages receive a configured `Dio` and never pick a transport.
- **Consequences:**
  - cronet_http clashes with another namespace under AGP 9 (dart-lang/http#1932). The workaround is `android.uniquePackageNames=false` in `app/android/gradle.properties`.
  - Flutter warns that plugins applying the Kotlin Gradle Plugin (KGP) will stop building in a future version; cronet_http is one of them. Until upstream fixes it, the template flag `android.builtInKotlin=false` stays.
  - Pinned or mTLS servers will need a per-server switch to `IOHttpClientAdapter` (step 35).
  - Without Google Play services (AOSP images, de-Googled or Huawei devices), every Cronet provider is disabled, so `createPlatformHttpAdapter` falls back to `dart:io`. That transport does not trust user-installed CAs. Embedded Cronet (`--dart-define=cronetHttpNoPlay=true`, about +6.5 MB APK) avoids this and is the option for F-Droid and other no-GMS builds ([Q3](open-questions.md#q3-licence-and-distribution), [research/flutter-stack.md](research/flutter-stack.md) §3.21).

## D6: v1/v2 negotiation with capability gating

*Accepted, step 1.*

- **Context:**
  - `/api/v2` exists only from 2.4.0 onwards and can be hidden by proxies.
  - Development builds report `dev`/`unstable` instead of a semver.
  - Admins and licences switch features on and off.
- **Decision:**
  - Probe `/api/v2/info` and `/api/v1/info` in parallel. A probe counts only for a 200 with a JSON body that has a string `version`. Every API version whose probe counts goes into `ServerConnection.apiVersions`. When both count, the v2 `/info` document is the one used.
  - Follow at most one redirect per connection attempt, and only when the resolved `Location` keeps the `/api/v1/info` or `/api/v2/info` path under another origin or sub-path, or is a same-host `http` → `https` redirect. The root derived from it is probed like any other candidate. An `https` → `http` downgrade is never accepted; an `http` → `https` upgrade is. Any other redirect off the host, or to a login-like path, is `BehindLoginProxy`.
  - Derive `ServerCapabilities` from the reachable API versions, version thresholds, the `/info` flags and `enabled_pro_features`.
  - Features check capabilities, never version strings alone.
- **Consequences:**
  - The adapter choice per API group follows `Capability.apiV2`.
  - Re-negotiation at login, every 24 h and after a "route absent" 404 is planned for steps 3 and 5.

## D7: Support floor 2.0.0

*Superseded by [D13](#d13-support-floor-230) on 2026-10-09. Was: accepted, step 1.*

- **Context:** Before 2.0.0, auth works differently (a long JWT renewed through `/user/token`, no sessions), and the naming and error behaviour is unverified.
- **Decision:**
  - Support 2.0.0 and newer; 2.4.0 and newer is first-class.
  - A Vikunja server below 2.0.0 is not a connection failure: it yields `SupportTier.unsupported`, and the UI shows what was found. The server overview then shows the header, the badges and a blocking banner, but no sign-in methods and no server features.
  - A legacy tier for 0.24–1.x is optional (step 38).
- **Consequences:** The contract matrix keeps a 1.0.0 server to pin the "unsupported" path.

## D8: Cleartext policy

*Accepted, step 1.*

- **Context:** Many self-hosted servers on a home LAN only speak plain `http://`. Using it silently would expose passwords and tasks to anyone on the network.
- **Decision:**
  - The OS configuration allows cleartext, so such servers can be reached at all:
    - Android: a network security config with `cleartextTrafficPermitted="true"` that trusts system and user CAs.
    - iOS: `NSAllowsArbitraryLoads`, plus `NSLocalNetworkUsageDescription`.
  - The connector tries `https` first. It tries `http` only when the user typed no scheme and every `https` candidate failed at the connection level (DNS, refused, timeout, or a TLS handshake failure). A rejected certificate does not count: a TLS server answered, so the connector reports `TlsFailure` and does not fall back to `http`.
  - The app uses an `http` server only after the user confirms an "Unencrypted connection" dialog, and marks it as unencrypted afterwards.
  - Only the `http` and `https` schemes are accepted.
- **Consequences:**
  - App Review may ask about `NSAllowsArbitraryLoads`.
  - A server with an untrusted certificate is reported as a TLS failure even when it also serves plain `http`, so the user is pointed at the certificate rather than at cleartext.
  - The OS permissions cannot be narrowed to the hosts users type:
    - iOS ATS exceptions are build-time only, so exception domains cannot name hosts typed at runtime.
    - On iOS 10 and later, adding `NSAllowsLocalNetworking` (or `NSAllowsArbitraryLoadsInWebContent` / `NSAllowsArbitraryLoadsForMedia`) makes iOS ignore `NSAllowsArbitraryLoads`. That would silently block confirmed `http` connections to fully qualified hosts (split-DNS LAN names, Tailscale `*.ts.net`, VPN hosts).
    - `NSAllowsArbitraryLoads` therefore stays as long as users can confirm `http` for arbitrary hosts. The in-app "Unencrypted connection" confirmation is the actual control.
    - Android's per-domain cleartext rules are build-time only as well, so `cleartextTrafficPermitted="true"` stays too.
  - `NSAllowsArbitraryLoads` also removes ATS's TLS 1.2 and forward-secrecy minimums for `https`. System certificate validation still applies.

## D9: flutter_test instead of package:test in pure packages

*Accepted, step 1.*

- **Context:** In the shared workspace resolution, `package:test` conflicts with the `test_api` version that `flutter_test` pins.
- **Decision:** The pure packages use `flutter_test` as their dev dependency and run their tests with `flutter test`, not `dart test`.
- **Consequences:**
  - Only `test/` touches Flutter. `lib/` stays pure Dart, which is checked in CI.
  - The synthesis says contract tests run with "plain `dart test`". With this decision they run with `flutter test --tags contract`.

## D10: Placeholder application ids

*Superseded by [D15](#d15-app-id-devcoderoftimevikunja) on 2026-10-09. Was: accepted for now, step 1.*

- **Context:** The final app name, `applicationId`, bundle id and OAuth redirect scheme are still open ([Q2](open-questions.md#q2-app-identity)).
- **Decision:** Keep the Flutter template ids until Q2 is answered: Android `com.example.vikunja_mobile`, iOS `com.example.vikunjaMobile`.
- **Consequences:**
  - Changing the ids is cheap now.
  - It becomes expensive once signing keys, App Groups, keychain groups, OAuth clients or store listings exist. It must be decided before step 3 (OAuth redirect) and step 19 (App Group).

## D11: Docker contract matrix 1.0 / 2.0 / 2.3 / 2.4 / 2.7

*Accepted, step 1.*

- **Context:** Behaviour differs across server lines. Mocks alone cannot prove v1/v2 detection.
- **Decision:**
  - `test_servers/docker-compose.yaml` runs the `vikunja/vikunja` images 1.0.0, 2.0.0, 2.3.0, 2.4.0 and 2.7.0 on fixed ports 34510–34527, published on `127.0.0.1` only, because they allow open registration with a public JWT secret.
  - Each image is pinned to an exact tag and keeps SQLite in a tmpfs.
  - Contract tests are tagged `contract`, need `VIKUNJA_CONTRACT=1`, and run in a separate CI job.
- **Consequences:**
  - New server releases are added deliberately.
  - Recorded `/info` fixtures come from these images.
  - Running the tests locally needs Docker (or colima).

## D12: Hand-written API adapters and an OpenAPI spec for contract tests

*Accepted, implemented in step 5 (planned).*

- **Context:**
  - v1 and v2 share the same server models.
  - v1 has no usable spec.
  - The app needs about 70 of 216 operations.
- **Decision:**
  - Hand-write the v1 and v2 adapters over one shared DTO set.
  - Commit the OpenAPI 3.0 spec of the pinned 2.7.0 image (`api_spec/`).
  - A contract test checks that every DTO field exists in the spec and that every write field is writable.
- **Consequences:**
  - There is no codegen churn.
  - Spec drift is caught by the test.
  - swagger_parser + retrofit stay the fallback if v2 grows faster than the adapters can follow.

## D13: Support floor 2.3.0

*Accepted 2026-10-09, step 1 review. Supersedes [D7](#d7-support-floor-200). From [Q1](open-questions.md#q1-minimum-server-version) and [Q4](open-questions.md#q4-login-methods).*

- **Context:**
  - For Q1 the owner chose option A (floor 2.0.0): the app is meant to be released some day, and older servers are rare.
  - Browser sign-in is the only sign-in method ([D14](#d14-browser-sign-in-only)). The server's OAuth 2.0 + PKCE endpoints exist only from 2.3.0 onwards, so nobody can sign in to a 2.0–2.2 server.
- **Decision:**
  - Support 2.3.0 and newer. 2.4.0 and newer, with `/api/v2`, stays first-class.
  - A Vikunja server below 2.3.0 yields `SupportTier.unsupported` and is shown as described in D7: header, badges and a blocking banner, which says that browser sign-in needs 2.3.0.
  - `SupportTier.standard` (2.0–2.2) is dropped. The remaining tiers are `unsupported`, `oauth` (≥ 2.3.0 without a reachable `/api/v2`) and `full` (`/api/v2` reachable).
  - No legacy tier for 0.24–1.x. Roadmap step 38 is removed.
- **Consequences:**
  - The step 1 finalization updated `ServerCapabilities`, the server overview, the tests and the contract expectations.
  - The cookie refresh for 2.0–2.2 is never needed. The v1 adapter is still needed for 2.3.x and for servers whose proxy hides `/api/v2`.
  - The contract matrix ([D11](#d11-docker-contract-matrix-10--20--23--24--27)) keeps 1.0.0 and 2.0.0 to pin the "unsupported" path. 2.3.0 is the oldest supported line.

## D14: Browser sign-in only

*Accepted 2026-10-09, step 1 review. From [Q4](open-questions.md#q4-login-methods).*

- **Context:** Vikunja plans to remove username and password login. On ≥ 2.3.0 the browser flow covers local, LDAP, every OIDC provider and TOTP, because the web frontend's login page handles them.
- **Decision:**
  - The only way to sign in is OAuth 2.0 + PKCE in the system browser: ASWebAuthenticationSession on iOS, Custom Tabs on Android (planned through flutter_web_auth_2). The code is exchanged at `/api/v2/oauth/token`, or at `/api/v1/oauth/token` on 2.3.x.
  - Not planned for now: a native password + TOTP form, API-token login, and OIDC in an embedded WebView.
  - The OAuth `client_id` and the redirect scheme are fixed in step 3. The scheme must start with `vikunja-` and must not be `vikunja-desktop` or `vikunja-flutter`.
- **Consequences:**
  - The app never handles passwords or TOTP codes.
  - OAuth sessions are always short (72 h without a refresh) and there is no 30-day "stay signed in". [D22](#d22-session-keep-alive-through-background-sync) keeps sessions alive.
  - Roadmap step 4 (password + TOTP, API tokens) is replaced by multi-account ([D16](#d16-multi-account-in-the-first-release)).
  - Managing TOTP and API tokens in the account settings (step 31) and guest access through link shares (step 32) are not sign-in methods and stay planned. Step 32's registration and password reset are re-scoped for browser sign-in when that step starts.

## D15: App id `dev.coderoftime.vikunja`

*Accepted 2026-10-09, step 1 review. Supersedes [D10](#d10-placeholder-application-ids). From [Q2](open-questions.md#q2-app-identity). The app id and the ids derived from it are accepted; the name, store listing, `User-Agent` prefix and icon are **proposed, pending owner approval**.*

- **Decision:**
  - Android `applicationId` and iOS bundle id: `dev.coderoftime.vikunja`.
  - App name (proposed, pending owner approval): **Taskuna** (*task* + *vicuña*), with the "check-llama" icon; see [branding/README.md](../branding/README.md). The store listing reads `Taskuna – client for Vikunja` (de: `Taskuna – Client für Vikunja`). Name and logo lean on Vikunja's, but must not suggest an official Vikunja app.
  - Platform ids under the app id: the Android namespace and the Kotlin package `dev.coderoftime.vikunja`, the iOS test bundle `dev.coderoftime.vikunja.RunnerTests`, and the method channel `dev.coderoftime.vikunja/device`. The HTTP `User-Agent` starts with `Taskuna/<version>`, following the proposed name. The Dart package keeps its internal name `vikunja_mobile`.
  - Ids derived from it later: the App Group `group.dev.coderoftime.vikunja` and a keychain group on the same base (step 19). The OAuth `client_id` and redirect scheme follow [D14](#d14-browser-sign-in-only).
- **Consequences:**
  - The step 1 finalization replaced the template ids `com.example.vikunja_mobile` and `com.example.vikunjaMobile`. A debug build with the old id stays installed next to the new one until it is uninstalled.
  - The id is permanent once signing keys or store listings exist.
  - Before the store release (step 37), check the use of the name and logo with the Vikunja maintainers.

## D16: Multi-account in the first release

*Accepted 2026-10-09, step 1 review. From [Q6](open-questions.md#q6-multi-account).*

- **Context:** The architecture keeps tokens and one database per account from step 3 onwards.
- **Decision:**
  - The first release has an account switcher: add, switch and remove accounts (roadmap step 4).
  - An account is a server plus a user. Each account has its own tokens, database, outbox and sync state. The UI shows one active account at a time.
  - Background sync and reminders cover every signed-in account, not only the active one.
- **Consequences:**
  - The session manager (step 3) is multi-account from the start. Per-account providers are keyed by account id.
  - Removing an account signs it out and wipes its secure entries; from step 6 on it also deletes its database and cancels its notifications.
  - Notification payloads and widget data carry the account id, so a tap opens the right account.

## D17: Notification policy

*Accepted 2026-10-09, step 1 review. From [Q7](open-questions.md#q7-notification-policy-defaults).*

- **Decision:**
  - Local notifications only for undone tasks where the user is the creator or an assignee. Tasks that are visible only through shared projects or subscriptions get none.
  - Task reminders fire at their reminder time. A task with a due date also gets a due-date notification at the exact due time.
  - Android schedules both as exact alarms. The onboarding after the first sign-in asks for the notification permission and for exact-alarm access (`SCHEDULE_EXACT_ALARM`, denied by default on Android 14+). iOS asks for the notification permission at the same point.
  - No daily overdue digest for now.
- **Consequences:**
  - Without exact-alarm access Android falls back to inexact alarms (`inexactAllowWhileIdle`). The notification settings show this and link to the system setting.
  - The store release (step 37) needs the Play Console exact-alarm declaration.
  - A digest can be added later as a setting without changing the scheduler.

## D18: TipTap description editor in a WebView

*Accepted 2026-10-09, step 1 review. From [Q8](open-questions.md#q8-description-editing).*

- **Context:** Task descriptions are HTML written by the web frontend's TipTap editor. Markdown editing would be lossy and is not possible on v1 servers.
- **Decision:** Step 25 edits descriptions with TipTap in a WebView: a bundled editor page with the web frontend's TipTap configuration, no remote loads, and HTML in and out through a JavaScript channel. Read-only rendering stays native (step 10).
- **Consequences:**
  - New dependencies (a WebView plugin and a bundled JavaScript build) and a larger app.
  - Step 35 hardens the WebView: no remote loads, origin check on the JavaScript channel.
  - Porting the TipTap configuration adds to the licence question ([Q3](open-questions.md#q3-licence-and-distribution)).

## D19: Quick-add quirk policy

*Accepted 2026-10-09, step 1 review. From [Q9](open-questions.md#q9-quick-add-quirks).*

- **Decision:** The Quick Add Magic port (step 13) keeps the web grammar but fixes four parser bugs, items 1–4 of the quirk register in [research/client-logic.md](research/client-logic.md) §20:
  1. `every N months` (N ≠ 1), `every year`, `yearly`, `biannually` and similar produce a repeat instead of none.
  2. Capitalised `Daily` and `Every Day` mean daily, as in lower case, not hourly.
  3. `today`, `tomorrow` and `next week` need a word boundary, so `todays` and `next weekend` stay text.
  4. Day-and-month dates need whole words, so `12 decorations` stays text.
- **Consequences:**
  - The ported golden cases that pin these bugs are changed and marked as deliberate deviations. The fixes are documented in `packages/vikunja_logic` and in step 13's PR.
  - The other register items are decided when their step comes.

## D20: Scope cuts and desktop adaptations

*Accepted 2026-10-09, step 1 review. From [Q10](open-questions.md#q10-desktop-centric-features), [Q11](open-questions.md#q11-optional-near-real-time-push-on-android), [Q12](open-questions.md#q12-crash-reporting) and [Q14](open-questions.md#q14-licensed-features).*

- **Adaptations:**
  - Gantt becomes a read-only timeline, and table becomes a detailed list (step 29).
  - Keyboard shortcuts on iPad only (step 36).
  - Home-screen widgets and app shortcuts replace the desktop quick-entry window (steps 13, 18, 19).
  - Seasonal logo and PWA banners are skipped.
- **Dropped:** the MCP information page and the admin panel (step 33).
- **Deferred, not planned for now:**
  - Time tracking (step 34), until the owner has a Vikunja licence to test against.
  - Push on Android through a Vikunja webhook, ntfy and UnifiedPush.
  - Crash reporting (no Sentry, GlitchTip or similar SDK).
- **Consequences:**
  - The app keeps parsing `enabled_pro_features`, so time tracking can be gated correctly when step 34 resumes.
  - The server overview does not list the admin panel or time tracking, even for a licensed server.
  - Without third-party SDKs the privacy manifests and store data declarations stay simple. Logs reach the developer only through the diagnostics export (step 35).

## D21: Languages English and German

*Accepted 2026-10-09, step 1 review. From [Q13](open-questions.md#q13-launch-languages).*

- **Decision:** The first release ships English and German. Step 36 does not import the 32 web locales; more languages come later.
- **Consequences:**
  - Every string stays in both ARB files (definition of done).
  - The `error.*` ARB import tool (step 2) imports only `en` and `de`.

## D22: Session keep-alive through background sync

*Accepted 2026-10-09, step 1 review. From [Q5](open-questions.md#q5-session-lifetime).*

- **Context:** OAuth sessions end after 72 h without a refresh (`service.jwtttl`, sliding). With browser sign-in only ([D14](#d14-browser-sign-in-only)) there is no 30-day session.
- **Decision:**
  - The background sync (step 16) refreshes the session of every signed-in account at least about every 24 h, even when nothing else needs syncing.
  - Android uses WorkManager periodic work. iOS uses BGAppRefresh, which the OS runs at its own discretion.
  - The session manager (step 3) supports refreshing from background isolates: file lock, re-read, write-ahead.
- **Consequences:** On iOS a session can still expire when the app is neither opened nor woken for 72 h. The account then goes to `needsReauth`: local data stays, the outbox pauses, and a "Sign in again" notification appears.
