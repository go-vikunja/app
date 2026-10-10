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

*Accepted, step 1. Superseded by [D28](#d28-test-only-the-latest-vikunja-release) on 2026-10-09.*

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

*Accepted. The hand-written read adapters are built in step 5; the committed OpenAPI spec and the DTO-vs-schema test are still planned.*

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

*Accepted 2026-10-09, step 1 review. From [Q4](open-questions.md#q4-login-methods). Plugin, `client_id` and redirect scheme: [D23](#d23-browser-sign-in-through-flutter_web_auth_2-client-id-and-redirect-uri).*

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

*Accepted 2026-10-09, step 1 review. Supersedes [D10](#d10-placeholder-application-ids). From [Q2](open-questions.md#q2-app-identity). The app id and the ids derived from it are accepted. The owner chose the name Rurana and the "checkbox ears" icon on 2026-10-09 (the proposed Taskuna and its check-llama icon were rejected).*

- **Decision:**
  - Android `applicationId` and iOS bundle id: `dev.coderoftime.vikunja`.
  - App name: **Rurana** (Quechua *rurana*, "what is to be done"), with the "checkbox ears" llama icon; see [branding/README.md](../branding/README.md). The store listing reads `Rurana – client for Vikunja` (de: `Rurana – Client für Vikunja`). Name and logo lean on Vikunja's, but must not suggest an official Vikunja app.
  - Platform ids under the app id: the Android namespace and the Kotlin package `dev.coderoftime.vikunja`, the iOS test bundle `dev.coderoftime.vikunja.RunnerTests`, and the method channel `dev.coderoftime.vikunja/device`. The HTTP `User-Agent` starts with `Rurana/<version>`. The Dart package keeps its internal name `vikunja_mobile`.
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

*Accepted 2026-10-09, step 1 review. From [Q5](open-questions.md#q5-session-lifetime). The refresh mechanism is refined by [D26](#d26-refresh-concurrency-single-flight-re-read-and-adopt-write-ahead-epoch).*

- **Context:** OAuth sessions end after 72 h without a refresh (`service.jwtttl`, sliding). With browser sign-in only ([D14](#d14-browser-sign-in-only)) there is no 30-day session.
- **Decision:**
  - The background sync (step 16) refreshes the session of every signed-in account at least about every 24 h, even when nothing else needs syncing.
  - Android uses WorkManager periodic work. iOS uses BGAppRefresh, which the OS runs at its own discretion.
  - The session manager (step 3) supports refreshing from background isolates: file lock, re-read, write-ahead.
  - Since step 2+3, opening or resuming the app checks the active session with `GET /user`; a check that has to refresh an expiring access token moves the 72 h window. Step 16 adds the background runs.
- **Consequences:** On iOS a session can still expire when the app is neither opened nor woken for 72 h. The account then goes to `needsReauth`: local data stays, the outbox pauses, and a "Sign in again" notification appears.

## D23: Browser sign-in through flutter_web_auth_2, client id and redirect URI

*Accepted 2026-10-09, step 2+3. Implements [D14](#d14-browser-sign-in-only).*

- **Context:**
  - D14 makes OAuth 2.0 + PKCE in the system browser the only sign-in, and leaves the plugin, the `client_id` and the redirect scheme to this step.
  - Vikunja has no client registry. The `client_id` is free text that must match between the authorize and the token call (else 400 code 17001). The redirect URI's scheme must start with `vikunja-` (else 17002). There is no consent screen ([research/auth.md](research/auth.md) §7).
- **Decision:**
  - `client_id`: `dev.coderoftime.vikunja`, the app id ([D15](#d15-app-id-devcoderoftimevikunja)).
  - Redirect URI: `vikunja-dev.coderoftime.vikunja://oauth/callback`, so the callback scheme is `vikunja-dev.coderoftime.vikunja`. It is neither `vikunja-desktop` nor `vikunja-flutter`, as D14 requires.
  - The browser leg runs through flutter_web_auth_2 5.1.0: ASWebAuthenticationSession on iOS; on Android a Chrome Auth Tab where the browser supports it, otherwise a Custom Tab, with the plugin's `CallbackActivity`.
  - The browser session is ephemeral (`preferEphemeral: true`), so no web login in Safari or Chrome is reused. Vikunja has no consent screen and its callback carries only `code` and `state`, no `iss` (RFC 9207; `frontend/src/views/user/OAuthAuthorize.vue`). With a reused web login, a malicious server could send the sheet to another server's authorize page and receive a code, and the PKCE verifier with it, without the user noticing (a mix-up). This replaces the step 2+3 plan and [research/auth.md](research/auth.md) §15.1's advice not to set `preferEphemeral`.
  - "Sign in again" accepts only the account's own user. Another user is refused before anything is stored, and its new session is logged out best effort.
  - The app uses the plugin only through a `WebAuthenticator` interface; tests use a fake.
  - The authorize URL is `{frontend_url}oauth/authorize` (the server root + `/` when `/info` has no `frontend_url`) with an S256 challenge over a 32-byte random verifier and a 16-byte random state, both fresh per attempt. An `http://` `frontend_url` is never used for an `https://` server; the server root + `/` is used instead.
  - The token client does not follow redirects, and neither does any request that carries an access token.
  - The code is exchanged at `/api/v2/oauth/token` when `/api/v2` is reachable, otherwise at `/api/v1/oauth/token`, with a JSON body.
  - The callback must match the redirect URI's scheme and path and the state, and must carry a `code`. An `error` parameter is a failure. A cancelled sheet returns silently.
- **Consequences:**
  - Android declares the `CallbackActivity`, exported, with a `VIEW` / `DEFAULT` / `BROWSABLE` intent filter for the scheme. iOS needs no URL type for ASWebAuthenticationSession; step 2+3 verifies this on the simulator.
  - Every sign-in shows the Vikunja login form, and OIDC and SSO users sign in at their identity provider again each time. iOS shows no "… Wants to Use … to Sign In" prompt (checked on the iOS 18.6 simulator).
  - On Android, the plugin opens a Custom Tab instead of an Auth Tab for Chrome and Edge before 141, Samsung Internet before 28 and Firefox before 143, which it treats as lacking ephemeral support. There the sheet can share the browser's cookies and reuse a web login; other browsers may ignore the flag as well.
  - Signing out of the app does not end a web login the user has in the browser. Only the fallback browsers above would reuse it.
  - The mix-up is not fully closed: a malicious server can still show another server's login page, but the user has to type that server's credentials. Closing it needs a server change: RFC 9207 `iss` in the callback, or a consent screen that names the client. Worth raising upstream.
  - PKCE keeps an intercepted code useless to another app that claims the same scheme. Without a consent screen, though, any app with a `vikunja-…` scheme can get a token for a user who is signed in to the web app in the system browser. This is a server-side property.
  - The plugin's stable 5.x line predates both its UIScene migration (6.0.0-alpha.2) and its built-in Kotlin migration (6.0.0-alpha.0). 5.1.0 is used because 6.0 is still alpha. Under the app's UIScene lifecycle it finds the window through its `UIApplication.keyWindow` fallback; the sheet opens and cancels correctly on the iOS 18.6 simulator, and the Custom Tab on the Android emulator (step 2+3, without completing a sign-in). Flutter warns that the plugin's old Kotlin Gradle plugin setup will stop building in a future release, so the move to 6.0 is due once it is stable. If a version stops working, the `WebAuthenticator` interface allows a small platform channel of our own (ASWebAuthenticationSession and Custom Tabs) instead, recorded as a new decision.
  - **The iOS deployment target stays 15.0.** The plugin's README says 4.0 and later "require" iOS 17.4, but its `Package.swift` and podspec declare iOS 11, and the Swift source uses the iOS 17.4 `ASWebAuthenticationSession.Callback` API only behind `#available(iOS 17.4, *)`. Below 17.4 it falls back to `init(url:callbackURLScheme:completionHandler:)` (iOS 12+), which handles our custom scheme. Only `https` callbacks (universal links) need 17.4, and the app does not use them. The fallback is checked by reading the 5.1.0 source; it is not run on a device, because no simulator runtime older than iOS 18.6 is installed. A real iOS 15–17.3 device check belongs to the release checklist (step 37).
  - iOS logs that ASWebAuthenticationSession support for `http://` pages is deprecated. Servers on plain `http://` may lose browser sign-in in a future iOS release.
  - Code-grant sessions are never long-lived: 72 h without a refresh ends them ([D22](#d22-session-keep-alive-through-background-sync)).

## D24: Tokens in secure storage, readable after the first unlock

*Accepted 2026-10-09, step 2+3.*

- **Context:**
  - The refresh token is the most sensitive secret the app holds.
  - Background sync (step 16) and notification actions (step 15) must refresh tokens while the device is locked.
  - Principle 5 of the [architecture](architecture.md#1-principles): secrets live only in the Keychain or the Keystore.
- **Decision:**
  - flutter_secure_storage 11.x, with the entries `account.<id>.refresh_token` and `account.<id>.access_token` per account.
  - iOS: `KeychainAccessibility.first_unlock_this_device` and `synchronizable: false`.
  - Android: the plugin's v11 defaults (AES-GCM with a key wrapped by an Android Keystore RSA key). `android:allowBackup="false"`, set since step 1, keeps the entries out of Auto Backup.
  - The access token is stored as well, so another isolate can adopt a refresh result instead of refreshing again ([D26](#d26-refresh-concurrency-single-flight-re-read-and-adopt-write-ahead-epoch)).
  - No other place holds secrets: not SharedPreferences, not the database, not logs. The log redaction also covers `Bearer`, `access_token`, `refresh_token`, `code=` and `state=`.
- **Consequences:**
  - After a restart, nothing can refresh until the user unlocks the device once. Background runs before that must treat the locked Keychain like a network error: keep everything, retry later.
  - Tokens never leave the device through iCloud Keychain or backups. A backup restored onto another iPhone brings the account registry ([D25](#d25-account-registry-in-sharedpreferences-without-secrets)) but no tokens, so those accounts need a new sign-in.
  - Widgets and extensions get no keychain access group. Step 19 revisits this only if an extension must authenticate.
  - Changing the accessibility class later means rewriting the existing items.
  - iOS keeps Keychain items when the app is deleted, but not its preferences. The first UI start that finds neither the install marker (`auth.install_marker`) nor a registry therefore wipes secure storage once (`app/lib/core/auth/previous_install.dart`); a locked Keychain leaves the marker unset, so the next start tries again. A registry without the marker is an update from an older build and is left alone. On Android, deleting the app removes everything and the wipe finds nothing.
  - Deleting the app never logs its sessions out on the server. They end after 72 h without a refresh.

## D25: Account registry in SharedPreferences, without secrets

*Accepted 2026-10-09, step 2+3. Builds on [D16](#d16-multi-account-in-the-first-release).*

- **Context:**
  - The app starts with several accounts ([D16](#d16-multi-account-in-the-first-release)). The UI and background isolates need the account list, the active account and each account's server before any database exists (step 6).
  - From step 6 on, the per-account databases are found through this list.
- **Decision:**
  - The registry is JSON in `SharedPreferencesAsync`: the accounts (`Account`: id, server root, user id, username, display name, `addedAt`, `needsReauth`), the active account id, and each account's last server connection (root, reachable API versions, `/info` re-serialised by `serverInfoToJson`).
  - Account id: the first 32 hex characters of `sha256("${serverRoot}|${userId}")`. The same user on the same server is always the same account; signing in again replaces its session, and the old session is logged out best effort.
  - The registry holds no tokens or other secrets ([D24](#d24-tokens-in-secure-storage-readable-after-the-first-unlock)).
  - `SharedPreferencesAsync` rather than the cached legacy API: every read goes to the platform store, so a background isolate never works on a stale in-memory copy.
- **Consequences:**
  - The registry and secure storage are written separately and can disagree after a crash or a restore. An account without tokens is handled like `needsReauth`: the accounts provider marks it when the app starts (`app/lib/core/auth/accounts_without_tokens.dart`), and a session manager that finds no tokens ends the session the same way. Secure storage that cannot be read (the Keychain before the first unlock) does not count as missing tokens.
  - The id depends on the normalised server root. The same server reached through two different addresses (a LAN IP and a domain) gives two accounts.
  - An entry that cannot be decoded is left out of the state but written back unchanged, so it is not lost; a readable entry with the same id replaces it. A registry that cannot be decoded at all is copied to `auth.account_registry.unreadable` before it is first overwritten.
  - Step 4 builds the switcher on this registry. Step 6 names the database files by account id.

## D26: Refresh concurrency: single-flight, re-read and adopt, write-ahead, epoch

*Accepted 2026-10-09, step 2+3. Refines the mechanism that [D22](#d22-session-keep-alive-through-background-sync) names ("file lock, re-read, write-ahead").*

- **Context:**
  - Vikunja rotates the refresh token on every refresh and has no grace period. Reusing a rotated token gives 401 code 16002 and the session cannot be recovered; the loser of a concurrent rotation gets 16004 ([research/auth.md](research/auth.md) §4.1).
  - Several isolates can refresh the same account: the UI isolate now, background tasks and notification actions later (steps 15–16).
  - A response that is lost after the server committed a rotation also kills the session.
- **Decision:**
  - Single-flight: one refresh per account and isolate at a time.
  - Before calling the server, re-read the stored refresh token. If it differs from the caller's snapshot, adopt the stored tokens and skip the call.
  - On 16002 or 16004, re-read storage a few times with short delays and adopt a newer token if one appears. Only then is the session ended (`needsReauth`).
  - Write-ahead: persist the rotated tokens before the new access token is used.
  - The refresh request is not tied to UI cancellation and has a generous timeout.
  - A per-account auth epoch, increased by sign-out and account removal. A refresh that finishes under an older epoch is discarded. Sign-out retires the session manager first and wipes storage afterwards; the retired manager hands out no token and writes nothing until a new sign-in replaces it. `retire()` waits only for a storage write that has already started, never for a refresh still on the network.
  - Every session-ended answer re-reads storage first: 16002 and 16004 as above, and also 16003 and 412, which are about the session of the token sent. A session that another isolate stored meanwhile is adopted.
  - If the secure write after a successful refresh fails, the new tokens stay in memory and are written again before the next refresh; newer tokens in storage win.
  - Expiry is judged with the per-account server clock offset stored in preferences, so a cold start or a new isolate need not wait for a response.
  - Failure classes: network errors keep the tokens for a later retry; 5xx is retried once; 429 waits for `Retry-After`, capped at 10 min; a session-ended answer (16002 after re-reading, 16003, 412 code 1020 or 1040) marks the account `needsReauth` and keeps its local data.
  - Cross-isolate lock: `RandomAccessFile.lock` does **not** serialise two isolates of one process. POSIX record locks belong to the whole process, so a second isolate acquires a lock the first still holds (verified on the macOS host by `app/test/core/auth/file_lock_isolates_test.dart`; Android and iOS use the same `fcntl` locks). The re-read and adoption rules above are therefore the only cross-isolate mechanism, as documented in `app/lib/core/auth/session_manager.dart`.
  - A 5xx on refresh can be a lost race too: SQLite servers answer the loser with 500 instead of 16004 ([research/README.md](research/README.md) item 7). Before the one retry, storage is re-read; a newer token found there is adopted instead of retrying with the dead one.
- **Consequences:**
  - The session manager is the only code that refreshes. `vikunja_api` sees it only through `AccessTokenSource`.
  - Without a lock, two isolates can send the same refresh token at once. The loser then adopts the winner's tokens once they are written, so the adoption re-reads must outlast the winner's write-ahead.
  - The remaining risk is a response lost after the server rotated: the process is killed mid-request, or the network drops. That session ends in `needsReauth`. Background runs must not start a refresh with only seconds of runtime left (step 16).
  - Retirement is per isolate. A sibling isolate can still write tokens back after a sign-out in another isolate; step 16 needs a guard for that.

## D27: Paging and the query builder move to step 5

*Accepted 2026-10-09, step 2+3.*

- **Context:** The owner merged roadmap steps 2 (HTTP core and error model) and 3 (browser sign-in, session manager) into one step on 2026-10-09. Step 2's scope included paging and a query builder, but step 2+3 calls no list endpoint. The first paged reads are step 5's read ports.
- **Decision:**
  - Step 2+3 builds the error model (`VikunjaFailure`, `normalizeError`), the retry interceptor, the wider log redaction and the authenticated transport.
  - `Page<T>` (v1 pagination headers, v2 `{items,total,…}` envelopes) and the query builder (filter, sort and paging parameters) are built with the v1/v2 read adapters in step 5.
- **Consequences:**
  - Both are designed against their first real callers, and step 2+3 stays focused on sign-in.
  - Step 5 (L) grows. It is split if it gets too large.

## D28: Test only the latest Vikunja release

*Accepted 2026-10-09 (owner decision). Supersedes [D11](#d11-docker-contract-matrix-10--20--23--24--27).*

- **Context:** The five-server matrix (1.0, 2.0, 2.3, 2.4, 2.7) plus an emulator-only server slowed the contract runs and shared one login rate limit. The owner asked to test only the newest release from now on.
- **Decision:**
  - `test_servers/docker-compose.yaml` runs a single `vikunja/vikunja:2.7.0` on `127.0.0.1:34527`; the tag is bumped when a new release comes out.
  - Contract tests (negotiation and the full OAuth flow) run only against it.
  - The Android emulator reaches it as `localhost` through `adb reverse tcp:34527 tcp:34527`, so no emulator-specific server is needed.
  - Support for older servers down to the 2.3.0 floor stays in the code; it is covered by unit tests against the recorded `/info` and error fixtures captured from the old images.
- **Consequences:**
  - Regressions that only show on 2.3–2.6 servers are no longer caught by a live server. If such a server matters again, an image can be added back temporarily.
  - CI pulls one image and the contract job is faster.

## D29: UI reads through repository interfaces; the online implementation is replaced by Drift in step 6 without UI changes

*Accepted 2026-10-10, step 5.*

- **Context:**
  - Principle 1 of the [architecture](architecture.md#1-principles) makes the local database the UI's only source, but Drift comes in step 6. The roadmap had step 5 as read ports only, with the first screens in steps 8–10, so the read adapters would have had no real consumer until then.
  - Screens written directly against `VikunjaReadClient` would have to be rewritten when the database arrives.
- **Decision:**
  - Step 5 puts the first screens on real data (open tasks by due date, project tree, a project's tasks, task detail), read-only and online.
  - They read through interfaces in `app/lib/core/repositories/`: `ProjectRepository` (`watchAll()`, `refresh()`, `find(id)`) and `TaskRepository` (`watchOpenTasks()`, `watchProjectTasks(projectId, showDone:)` as a `PagedList` of the items loaded so far plus `hasMore`, the matching refresh calls and `loadMoreProjectTasks`). The contract is streams of the current local state plus explicit refresh and load-more: a failed first load is the stream's error, a failed refresh or load-more throws and leaves the stale data in the stream. Database streams and a sync trigger satisfy this shape as well.
  - Step 5 ships `OnlineProjectRepository` and `OnlineTaskRepository`: an in-memory cache per account, filled on first subscription and on refresh through `VikunjaReadClient`. A failed refresh keeps the stale data visible and surfaces the `VikunjaFailure`.
  - The read client and the repositories are Riverpod providers keyed by the active account id and are disposed on sign-out.
  - The screens depend on these interfaces and the domain types only; they never see `Page`, the ports or DTOs. Task detail shows the task from the list without a request of its own.
  - Step 6 replaces the online implementations with Drift-backed ones behind the same interfaces. The sync engine fills the database through the same read ports.
- **Consequences:**
  - Step 6 changes no screen, and the widget tests of step 5 keep running against fake repositories.
  - Until step 6 nothing survives a restart, the app needs the server, and the overview reads at most 5 pages of `GET /tasks` (logged when capped). All three limits go away with Drift.
  - Steps 8 and 9 shrink to what remains: shell polish and settings applied; offline lists and Upcoming presets.

## D30: Kanban board reads deferred to step 20

*Accepted 2026-10-10, step 5.*

- **Context:**
  - The synthesis scope of step 5 covered every read operation, kanban included: `GET /projects/{p}/views/{v}/tasks` answers with buckets for a kanban view, v2 adds `…/views/{v}/buckets/tasks`, and `per_page` applies per bucket there.
  - The first consumer is the kanban board (step 20). The sync of steps 6–7 reads tasks through `GET /tasks`; buckets and positions are on-demand data that do not bump `tasks.updated`.
  - Step 5 already grew by paging and the query builder ([D27](#d27-paging-and-the-query-builder-move-to-step-5)) and by the first screens ([D29](#d29-ui-reads-through-repository-interfaces-the-online-implementation-is-replaced-by-drift-in-step-6-without-ui-changes)).
- **Decision:**
  - Step 5's read client has `ProjectsPort`, `LabelsPort` and `TasksPort` only. `TasksPort.listInView` is never called with a kanban view, and the bucket-shaped answer is not parsed.
  - `ProjectView` (kind, filter, bucket configuration) is parsed in step 5, because the project read carries the views.
  - Step 20 adds the kanban read path with the board: a buckets port, the bucket codecs and per-bucket paging, on v1 and v2. The acceptance "kanban per-bucket paging works on both versions" moves there.
- **Consequences:**
  - Step 5 shows no board; the Projects tab opens a project's task list only.
  - Step 6 decides whether the bucket tables of the schema are created empty or added by a migration in step 20.

## D31: One Drift SQLite file per account, shared across isolates, deleted on sign-out

*Accepted 2026-10-10, step 6. Implements principle 1 of the [architecture](architecture.md#1-principles) and the per-account database of [D16](#d16-multi-account-in-the-first-release).*

- **Context:**
  - Since step 5 the screens read through repository interfaces ([D29](#d29-ui-reads-through-repository-interfaces-the-online-implementation-is-replaced-by-drift-in-step-6-without-ui-changes)), but nothing survives a restart and the app needs the server.
  - Background sync, notification actions and the widget callback (steps 15–18) will open the same database from other isolates. The iOS widget extension is a separate process and never opens it ([research/flutter-stack.md](research/flutter-stack.md) §3.2–3.3).
  - drift 2.35 runs on sqlite3 3.x, which ships SQLite through a Dart build hook; `sqlite3_flutter_libs` is end-of-life.
- **Decision:**
  - drift 2.35 with drift_flutter 0.3 and sqlite3 3.7 (build hook, prebuilt SQLite with verified hashes; no `sqlite3_flutter_libs`).
  - One database per account at `<application support>/accounts/<accountId>/vikunja.db` (`AccountDatabaseFiles.pathFor`), opened through `driftDatabase(name:, native: DriftNativeOptions(databasePath:, shareAcrossIsolates: true))` in WAL mode. Never in the iOS App Group container. Not encrypted: the file holds no secrets, and an encrypted database would need its key in every background isolate.
  - Schema version 1: `projects`, `project_views`, `labels`, `users`, `tasks`, `task_labels`, `task_assignees`, `task_reminders`, `task_relations` and the key-value `sync_state`; indexes on `tasks(project_id)`, `tasks(done, due_date)` and `project_views(project_id)` (the primary key `(task_id, label_id)` of `task_labels` doubles as its `task_id` index). Ids are the server ids. Every entity row keeps the server's `created` and `updated`, because step 7's delta sync keys on `updated`. Dates are nullable UTC epoch milliseconds. Related tasks are stored as relation rows only; a task's `relatedTasks` is rebuilt from the rows whose other task is local. Tasks carry `sync_run_id`, the run that last returned them, so the purge at the end of a run survives a restart. Reminders have no server id and are keyed by `(task_id, ordinal)`.
  - Foreign keys with `ON DELETE CASCADE` from the task child tables to `tasks`, from `task_labels` to `labels`, `task_assignees` to `users` and `project_views` to `projects`; none on `tasks.project_id` (a task can arrive before its project, and the purge keeps them in step) or `task_relations.other_task_id` (the other task may be one the user cannot read).
  - The schema is dumped to `app/drift_schemas/drift_schema_v1.json` (`dart run drift_dev schema dump`, drift_dev's file name), the test helpers are generated from the dumps (`drift_dev schema generate` into `app/test/core/db/generated/`), and a test checks that the generated schema still matches the code. Every later schema change bumps the version, adds a dump and a migration test on that harness.
  - Pseudo projects (Favorites `-1`, saved filters `≤ -2`) are not stored in step 6. The sync skips them, because no screen shows them yet; step 24 (saved filters) decides their storage.
  - No bucket, position or outbox columns yet, which settles the open point of [D30](#d30-kanban-board-reads-deferred-to-step-20): step 11 adds the outbox and the merge columns (`base_json`, `dirty_fields`, `sync_status`), step 20 the bucket tables, each by a migration.
  - Sign-out and account removal close the database and delete the file with its `-wal`, `-shm` and `-journal` companions (`AccountDatabaseFiles.deleteFor`); the order of the token and registry wipe ([D26](#d26-refresh-concurrency-single-flight-re-read-and-adopt-write-ahead-epoch)) is unchanged. Local data of an account in `needsReauth` stays ([D22](#d22-session-keep-alive-through-background-sync)).
- **Consequences:**
  - The database, like the session manager, is a provider keyed by the account id (`appDatabase(accountId)`), closed on dispose and on sign-out through an `OpenDatabases` registry, so that sign-out can await the close before it deletes the files. With `shareAcrossIsolates`, `close()` only disconnects the client and the database isolate closes sqlite afterwards on its own, so the registry waits until the isolate has removed its `IsolateNameServer` mapping (polled every 20 ms, up to 5 s, logged on timeout) before the wipe deletes the files; a client in another isolate (step 16) keeps the isolate alive past that wait and must be stopped first, or a re-opened account would attach to the old isolate and write into an unlinked file. `shareAcrossIsolates` finds the running database server through `IsolateNameServer`, so every isolate of the process shares one connection and one stream-update bus. It must be closed explicitly.
  - Per-account files make an `account_id` column unnecessary; the research schema ([research/sync.md](research/sync.md) §9.2) had one.
  - Android's `allowBackup="false"` keeps the file out of Auto Backup. On iOS it is part of the device backup; it holds no secrets.
  - `flutter build` needs the sqlite3 build hook to fetch its prebuilt library (honours `HTTPS_PROXY`); an F-Droid flavour would compile from source (`hooks.user_defines.sqlite3`).
  - Switching accounts switches databases, so an account switch never shows another account's rows.

## D32: Initial sync by keyset paging with per-page checkpoints; full re-pull as refresh until step 7

*Accepted 2026-10-10, step 6. The incremental delta and the delete reconciliation are step 7.*

- **Context:**
  - Verified server facts ([research/sync.md](research/sync.md) §9, [research/api-v1.md](research/api-v1.md) §1.4, [research/api-v2.md](research/api-v2.md) §3.2): `GET /tasks` excludes the tasks of archived projects; keyset paging by id (`filter=done = false && id > <lastId>`, `sort_by=id&order_by=asc`) works on both API versions; the server caps `per_page` silently at `max_items_per_page`; the project list repeats the pseudo projects on every page; Vikunja leaves no tombstones.
  - Page-number paging is neither resumable nor stable while the data changes.
  - The app can be killed during the first pull of a large account.
- **Decision:**
  - `DefaultSyncEngine`, one per account, headless (no `BuildContext`, no Riverpod inside; the read client, the database, a clock and a `GET /user` source are injected, because the read client has no user port). Runs are serialized per account; a call during a run joins it. `status` replays the current `SyncStatus` on subscription, once the stored state has been read.
  - Phases, in order: `account` (`GET /user`) → `projects` (all pages, `is_archived=true`, upsert and purge the projects the server did not return) → `labels` (all pages) → `tasks` (two `per_page=1` requests for the total, then keyset `done = false`, then `done = true`, `per_page = info.max_items_per_page`, `page: 1` on every request, following the returned page size) → `archivedTasks` (the same keyset on `GET /projects/{id}/tasks` for every archived project and its descendants) → `finishing` (purge the tasks not seen in this run, write `last_synced_at`).
  - After every page the engine checkpoints run id and start time, phase, done count and total, last id, done filter and archived project id in `sync_state`. `ensureInitialSync()` resumes an interrupted run from that checkpoint and returns at once for an account that has completed a run. `refresh()` starts a new run id, re-pulls everything and purges by "not seen in this run"; purging happens only in `finishing`, so an interrupted run never deletes.
  - Every keyset page must be strictly ascending by id and start above the cursor; otherwise the run fails as `UnexpectedResponse` before the page is stored. A server that applied another order to `/tasks` or `/projects/{id}/tasks` would make the cursor skip ids, and the purge would then delete them silently.
  - Before the purge, `finishing` makes one more keyset pass over `GET /tasks` with `updated >= <newest updated at the start of the task phase − 120 s>` and marks its rows with the run id. The bound is a server time, the newest task `updated` the server reported in one `per_page=1` request sorted by `updated` descending before the open pass began (since step 7; step 6 used the device clock at the run start, which a device clock ahead of the server moved past a flip during a long run). A task reopened after the open pass had passed its id, and completed again after the done pass had, is returned by neither filter and would otherwise vanish until the next refresh; the 120 s overlap is the one step 7's delta uses for the server's commit lag. Tasks of archived projects cannot change, so `/tasks` suffices.
  - A failed request ends the run with `SyncFailed(failure, lastSyncedAt)`; rows from earlier runs stay readable, and `refresh()` rethrows the failure to its caller, as the repository contract of [D29](#d29-ui-reads-through-repository-interfaces-the-online-implementation-is-replaced-by-drift-in-step-6-without-ui-changes) requires. A stored state the engine cannot read when it is built is reported as `SyncFailed(UnexpectedResponse, lastSyncedAt: null)` and read again on the next call, so the first-sync screen's Retry covers a damaged file as well.
  - `SyncRunning.initial` stays true until the first run has completed: the app shows a blocking first-sync screen then (cancel = sign out) and a quiet indicator afterwards. An account that has synced opens the shell at once and refreshes quietly on start; a `NetworkFailure` with cached rows is an "offline" notice, not an error.
  - Until step 7, `refresh()` is this full re-pull. Step 7 replaces it with the `(updated, id)` delta, the project diff and the count checks; the stored `updated` and the run-id purge are built for that.
- **Consequences:**
  - The local repositories serve every list from the database: `showDone` is a WHERE clause, `loadMoreProjectTasks` is a no-op and `PagedList.hasMore` is false. The 5-page cap on the overview ([D29](#d29-ui-reads-through-repository-interfaces-the-online-implementation-is-replaced-by-drift-in-step-6-without-ui-changes)) is gone.
  - A refresh costs about `tasks / max_items_per_page` requests plus the project, label and archived-project pages, on every pull-to-refresh. Large accounts feel this until step 7.
  - Kanban buckets and positions are not synced ([D30](#d30-kanban-board-reads-deferred-to-step-20)); comments and attachments are not either.
  - The engine is contract-tested against the live 2.7.0 server from an app test tagged `contract` (`VIKUNJA_CONTRACT=1 flutter test --tags contract` in `app/`), because it needs the app's database code.
  - Step 16 can run the same engine in a background isolate through the same `ProviderContainer`; the `SyncStatus` of a run in another isolate is not shared yet.

## D33: Incremental sync: watermark on `updated` with a 120 s overlap, keyset over (updated, id), delete detection by per-project count check and id reconcile, daily full resync

*Accepted 2026-10-10, step 7. Replaces the "full re-pull as refresh" part of [D32](#d32-initial-sync-by-keyset-paging-with-per-page-checkpoints-full-re-pull-as-refresh-until-step-7); the initial sync of D32 is unchanged and stays available as the full resync.*

- **Context:**
  - Since step 6 every `refresh()` re-pulls the account: about `tasks / max_items_per_page` requests plus the project, label and archived-project pages, on every pull-to-refresh ([D32](#d32-initial-sync-by-keyset-paging-with-per-page-checkpoints-full-re-pull-as-refresh-until-step-7)). A sync on a timer is out of the question at that price, and web changes should appear on the phone after one sync.
  - Verified server facts ([research/sync.md](research/sync.md) §2–§3 and §7, [research/api-v1.md](research/api-v1.md) §4.1–4.2): `updated` is filterable and sortable; filter values are RFC 3339 and converted to UTC; timestamps have second granularity; the server appends `id asc` as the final tie-breaker unless the last sort is already `id`; parentheses and `||` are allowed in filters (16 KiB, 100 levels). `tasks.updated` is bumped by task edits (done, dates, favourite, reminders, assignees in the body) and by label add and remove, **asynchronously** by comment, attachment, relation and assignee changes through an event listener, and not at all by pure position or bucket moves. `projects.updated` is bumped by task create, update and delete, label changes and share or team changes, not by a favourite or subscription toggle. `GET /tasks` leaves out the tasks of archived projects. Deletes leave no tombstone: a deleted task is absent (404, code 4002 on a single read); project deletes are hard and cascade; losing access makes a project and its tasks vanish from the list. `GET /projects` with `is_archived=true` returns everything the user can see, flat. v2 returns `total`; v1 has no total, but with `per_page=1` the page count from the headers is the item count. A label rename does not bump `tasks.updated`.
  - The general API rate limit is off by default and 100 requests per minute per user when on; `Cache-Control: no-store` on every API response rules out HTTP caching; the login limiter does not apply to authenticated routes.
- **Decision:**
  - `SyncEngine.refresh()` is the incremental run. `fullResync()` is the full pull of [D32](#d32-initial-sync-by-keyset-paging-with-per-page-checkpoints-full-re-pull-as-refresh-until-step-7) with its purge by run id, and `ensureInitialSync()` is unchanged. Every completed run writes `last_synced_at` (`SyncIdle.lastSyncedAt` keeps meaning the last completed run of any kind) and the task watermark (`sync_state` key `watermark`): the newest task `updated` the database holds when the run completes, `MAX(tasks.updated)`, a server time, never the device clock, and never lower than before; an account without tasks stores 1970, so its delta asks for everything, which is nothing. The full pull writes `last_full_sync_at` as well. The new state lives in `sync_state`; the schema stays at version 1.
  - An incremental run is serialized with the other runs (a `fullResync()` asked for during an incremental run follows it rather than joining it, because joining would resolve without the full pull), reported as `SyncRunning(initial: false)` from before its first request, with phases of its own, and does, in order:
    1. **Projects:** all pages with `is_archived=true`, diffed against the local table. A project the server no longer lists is purged with its tasks (the foreign keys cascade through the task child tables); a project that was not local before is *added*, one that was archived and no longer is *un-archived*, an archived one whose `updated` differs, or that is newly archived (itself or through a parent, which takes its tasks out of `GET /tasks`), *changed*: the archive may have followed a task edit inside the second a sync last saw, which leaves `updated` as it was; a live project needs no such flag, its tasks come through `GET /tasks`. Only rows that differ from the local ones by value (the favourite flag bumps no `updated`) are written, so a run that finds nothing new leaves the database's watchers alone; the archived set is noted. The ids of the projects to pull whole are written with the rows (`sync_state` key `pending_whole_pull`): a run that fails afterwards would otherwise find them local and unchanged, and an archived project shared while archived would stay empty until the daily full pull; a completed run clears the key. The list is walked by page number, so when the server's count (`total` on v2, the page count on v1) changes between two pages, an item deleted meanwhile has shifted the next page's first item into the page already fetched, and the walk starts over (three times at most, then the run fails as `UnexpectedResponse`); on v1 a delete that leaves the page count unchanged goes unnoticed for that run, and a project it dropped comes back as *added* on the next one.
    2. **Labels:** all pages with the same guard against a change while paging, upsert the ones that differ, purge the ones not returned. Labels are few, and task rows take their labels from the `labels` table by id, so a rename shows without any task change.
    3. **Task delta** on `GET /tasks`: keyset over `(updated, id)` from the watermark minus 120 s. The first page has `filter=updated >= '<W − 120 s>'`, every later page `filter=(updated > '<U>') || (updated > '<U − 1 s>' && id > <I>)` with `(U, I)` the last item of the previous page, always `sort_by=updated&sort_by=id&order_by=asc&order_by=asc` and `per_page` = the server's maximum. The tie clause is not `updated = '<U>'`: Vikunja 2.7.0 compares a date filter value as if it sat just above its second (`>=` behaves like `>`, `<` like `<=`, `=` never matches; verified on both API versions with sort direction and fractional-second values), and timestamps are whole seconds, so `updated > '<U − 1 s>'` means `updated >= '<U>'` under the server's and the exact semantics alike. Of every page, the rows that differ from the local ones are upserted in one transaction: every change bumps `updated`, asynchronously for the listener's changes, which the overlap re-reads. The overlap covers the listener's lag and the second granularity; the rows it returns again unchanged are not written.
    4. **Archived projects:** an archived project whose `updated` changed gets the same delta over `GET /projects/{id}/tasks`, because `/tasks` leaves it out. An added or un-archived project gets the full keyset-by-id pull of its tasks instead, because they may carry `updated` values older than the watermark; the ids it returns are complete, so the project's local tasks not among them are purged right there (no separate count).
    5. **Delete detection:** a deleted task leaves no trace, and `projects.updated` has second precision, so a delete inside the second the previous sync saw leaves the project looking unchanged (the contract test showed it deterministically). Delete detection therefore does not key on `projects.updated`: one probe, `GET /tasks?per_page=1`, gives the server's count of live tasks (`total` on v2, the page count on v1), compared with the local count outside the archived projects. Only on a mismatch are the live projects counted one by one with `GET /projects/{id}/tasks?per_page=1`, and the ones whose count differs reconciled: keyset by id over `GET /projects/{id}/tasks` without a done filter (the endpoint returns done tasks without one; no view is involved), upserting the rows and purging the project's local tasks whose ids were not returned, after its last page. A `NotFound` with Vikunja's code 3001 means the project was deleted, a `Forbidden` with code 7003 that the user lost access to it (verified on 2.7.0 on both API versions: only a deleted project answers 404/3001, an unshared one 403/7003); either way it is purged with its tasks. When the probe matches, no project is counted. Tasks of archived projects cannot change (the server refuses edits and deletes there with 412), so they stay outside the probe. A move is caught by the delta already, because it bumps the task's `updated`; the counts of both projects then match.
    6. **Finishing:** watermark := max(`MAX(tasks.updated)` over the rows not more than 1 h ahead of the device clock, old watermark): a row from a server whose clock once ran fast would otherwise put every delta in the future for good, so such a row is logged and left out; `last_synced_at` := now; `pending_whole_pull` cleared; `SyncIdle`. A failure anywhere keeps the old watermark and the old rows and emits `SyncFailed`; because a project's tasks are purged only after its last page, an interrupted run never purges by a partial result. The incremental run has no checkpoint: it is short and restarts from the watermark.
  - **24 h rule:** `refresh()` runs `fullResync()` instead when `last_full_sync_at` is missing or older than 24 h, or when no watermark is stored (a database written by step 6). The daily full pull catches what the delta cannot see: positions and bucket moves, any server-side change that bumped no `updated`, and a count that matched by coincidence. It sets the watermark afresh (no max with the old one), so a value a fast clock once stored goes with it.
  - **Keyset filter:** the parenthesised `||` filter is proven by the contract test on 2.7.0 on both API versions with `per_page=5`, so that several delta pages occur: the test asserts the first page's `updated >=` filter, the parenthesised form of every continuation and the `updated, id` sort. Neither version rejects it, so there is no page-number fallback.
  - **Triggers** (`features/sync/application/`): `StartupSync` on the shell's first frame and on an account switch, unchanged except that it is incremental now. A `ForegroundSyncScheduler`, one per active account, runs `refresh()` on resume (after a pause or hide; a focus change alone, such as a dialog or the notification shade, is not one) when the last run finished more than 60 s ago and every 60 s while the app is in front; after a `SyncFailed` with a `NetworkFailure` the interval doubles up to 5 min and resets on success; it never overlaps (it joins the engine's run) and stops when the app is paused or hidden, on sign-out and while nothing listens to its provider (the first-sync screen), because a provider without listeners is not rebuilt either; its clock and timer are injectable. Pull-to-refresh and "Sync now" stay incremental; the Account tab gets a secondary "Full resync" (`fullResync()`), disabled during a run and in `needsReauth`. Nothing runs in the background (step 16), no WebSocket (step 17).
  - **Budget:** a run that finds nothing new costs the project pages, one labels page, one empty delta page and the count probe: 4 requests for a small account, which the contract test asserts (`GET /projects`, `/labels`, `/tasks` with the delta filter, `/tasks?per_page=1`); the engine logs the request count of every run at FINE. With the 60 s timer that is at most 240 requests per hour, well below the server's optional limit of 100 per minute. Changes add the delta pages, the delta of each changed archived project, one count request per live project when the probe differs, the reconcile pages of a project with a mismatch and the full pull of a new or un-archived project.
  - **Rejected alternatives:**
    - **CalDAV `sync-collection`** (RFC 6578, Vikunja 2.4.0) reports deleted tasks per project since a sync token, but needs CalDAV credentials (Basic auth with a CalDAV token the user would have to create in the web app, which browser sign-in does not give the app, [D14](#d14-browser-sign-in-only)), XML handling and one token per project, and a token older than 30 days forces a full resync anyway.
    - **Webhooks** fire on a server-side event to a public HTTPS URL per project; a phone has no such URL, a relay would be a push service of its own ([D20](#d20-scope-cuts-and-desktop-adaptations)), and webhooks are per project and per project admin, not per user.
    - **Full id reconciliation of every project on every run**, the research's safety net ([research/sync.md](research/sync.md) §3.2), costs as much as the full pull. It is what the daily full resync does, once a day.
    - **`filter=id in …` over chunks of local ids** (research §3.2, item 4) pages at 50 as well, needs the chunks to stay under 16 KiB and gains over the keyset only for projects with many deletes. It may come back for big projects.
    - **ETag / `If-None-Match`** exists on v2 single reads only, not on lists.
    - **A separate cheap probe** ("about 2 requests decide whether a delta is needed", the step 6 plan) is unnecessary: the first delta page is the probe.
- **Consequences:**
  - Web changes, deletions included, are on the phone after one `refresh()`: on start, on resume, every minute while the app is open, on pull-to-refresh and on "Sync now". Large accounts stop paying the full pull on every refresh.
  - Until the next full resync, the delta does not see pure position and bucket moves (not stored yet, [D30](#d30-kanban-board-reads-deferred-to-step-20)), a change the listener has not committed when the run passes (the next run's 120 s overlap catches that), and a task deleted right before its project was archived (the archived project is outside the count probe).
  - `SyncPhase` grows by `delta` and `reconcile`, with their labels in the ARB files; `SyncStatus` keeps its shape. A full resync no longer happens unnoticed: once a day a refresh takes as long as the step 6 refresh did.
  - A database written by step 6 has no watermark, so its first step 7 refresh is a full resync.
  - Step 16 runs the same `refresh()` in the background and moves the daily full resync and the session keep-alive there; step 17 uses the WebSocket as a trigger of `refresh()`, never as a source of truth.
  - The engine is contract-tested against the live 2.7.0 server on both API versions (`app/test/contract/incremental_sync_contract_test.dart`, tagged `contract`): seed, initial sync, then creates, edits, a done, deletes, a move, a new project, an archived project with an edited task, a deleted and a renamed label; one `refresh()` must mirror the server, and a second one with nothing changed must issue at most 4 requests.

## D34: Outbox: local-first writes, serial sender, coalescing, retry classes, sync interplay (pending fields win until sent, pending deletes hidden), v1 full-replace emulation

*Accepted 2026-10-10, step 11. Implements principle 3 of the [architecture](architecture.md#1-principles). Replaces the outbox part of [D31](#d31-one-drift-sqlite-file-per-account-shared-across-isolates-deleted-on-sign-out): the reserved `base_json`, `dirty_fields` and `sync_status` columns become `pending_changes` and `pending_delete`.*

- **Context:**
  - Since step 7 the database mirrors the server and stays current ([D33](#d33-incremental-sync-watermark-on-updated-with-a-120-s-overlap-keyset-over-updated-id-delete-detection-by-per-project-count-check-and-id-reconcile-daily-full-resync)), but every screen is read-only. The most frequent actions of a daily driver are done, undo, favourite and delete, and they must work offline, because the lists do.
  - Verified server facts ([research/sync.md](research/sync.md) §4.4, §6 and §8, [research/api-v1.md](research/api-v1.md) §5.1 and §6, [research/api-v2.md](research/api-v2.md) §3.4): v2 `PATCH /tasks/{id}` with `Content-Type: application/merge-patch+json` merges the sent fields onto the server's current state, field by field, and answers with the full task; a patch that changes nothing answers 304 with an empty body; an unknown key is a 422. v1 `POST /tasks/{id}` is a full replace: an omitted field clears description, dates, priority, colour, percent done, repeat and favourite, omitted `assignees` and `reminders` delete them, `labels` in the body are ignored and so is `bucket_id`. A date is cleared with `0001-01-01T00:00:00Z` on both versions and `hex_color` travels without `#`. Marking a repeating task done makes the server reopen it with shifted dates (mode 0 by `repeat_after`, mode 1 by a month, mode 2 from now) and return that. `DELETE /tasks/{id}` answers 204 on v2 and 200 on v1; a 404 with code 4002 means the task is already gone. There are no idempotency keys and no preconditions: `If-Match` is ignored on writes, a conflicting edit never gets a 412, and concurrent writes are serialized by a row lock, so the last write wins. A 401 with code 11 is refreshed once and retried by the auth interceptor ([D26](#d26-refresh-concurrency-single-flight-re-read-and-adopt-write-ahead-epoch)); the transport retries GET and HEAD only.
  - Answers that will not change on a retry: 403 code 7003 (no access), 404 code 3001 (project gone), 412 code 3008 (project archived), 400 code 4001 (empty title), 422 (validation). Transient: network errors, 5xx and 429 with `Retry-After`.
  - The step 7 sync upserts every row the server returns by value and the reconcile purges rows the server does not list. Without a rule for unsent local edits a pull would overwrite a change still on its way, and a task deleted offline would come back.
  - The research design ([research/synthesis.md](research/synthesis.md) §2.7): one transaction per local write, coalescing, serial FIFO sending, backoff, a "Sync problems" list and an incremental pull after the drain.
- **Decision:**
  - **Local-first.** `TaskRepository.setDone`, `setFavorite` and `deleteTask` change the local row and queue the server call in one transaction and return when it has committed; they never throw for network reasons. The UI is optimistic: the row shows the change with the next stream event, offline too. Done shows an Undo snackbar for 3 s (persisting under a screen reader); undo is a second write, `undoDone(previous)`: `done: false` plus, for a repeating task, the dates the task had before, because the server may already have moved them on; the server does not shift an open task again, so the undo works whether the done is still queued, in flight or answered. A delete hides the row at once.
  - **Schema version 2** (migrated from 1; dump `drift_schemas/drift_schema_v2.json`, migration test with data): the table `outbox` (`id` uuid, an account-local `sequence` for FIFO, `kind` update or delete, `task_id`, `payload` as JSON of the `TaskChanges`, `created_at`, `attempts`, `next_attempt_at`, `last_attempt_at` (the "failed … ago" of a sync problem), `state` pending, sending or failed, `last_error` as JSON of the normalized failure: kind, code, message) with an index on `(state, sequence)`; `tasks` gains `pending_changes` (the coalesced `TaskChanges` the server has not accepted yet, nullable) and `pending_delete`. Not the `base_json`, `dirty_fields` and `sync_status` of D31: there is no 3-way merge, because the server offers no precondition that would detect a conflict and v2 merges per field on its own, so the dirty set is enough, and a delete is a flag.
  - **`TaskChanges`** (`vikunja_domain`): one nullable field per writable property (`title`, `description`, `done`, `isFavorite`, `priority`, `percentDone`, `hexColor`, `dueDate`, `startDate`, `endDate`); null means unchanged, a date is a `DateChange` (`set` or `clear`); `merge(later)` lets the later value win per field; `isEmpty`. It is the outbox payload and the argument of the write port. Step 11 sets `done` and `isFavorite` only; step 12 adds the remaining properties (`repeat_after`, `repeat_mode`, `project_id`, reminders, cover image).
  - **Write ports** (`vikunja_api`, `lib/src/write/`): `TasksWritePort.update(id, TaskChanges)` returns the task as the server stored it; `delete(id)` treats 404 code 4002 as success on both versions. `VikunjaWriteClient` from `createWriteClient(dio:, connection:)` picks v2 or v1 from the connection like the read client. The v2 adapter sends a merge-patch with only the set fields under their wire names (`due_date`, `is_favorite`, `percent_done`, …), `DateChange.clear` as the zero date, never a key the server does not know, and re-reads the task after a 304. The v1 adapter emulates the patch: `GET /tasks/{id}`, overlay the changes, `POST` the whole object back with `assignees` (`{id, username, name}`) and `reminders` exactly as read and never `labels`, so the full replace clears nothing. Both go through `normalizeError`; a cancelled request rethrows its `DioException`.
  - **Coalescing** in the write transaction: an update for a task whose update is still pending is merged into it (`TaskChanges.merge`; into the newest such op, so an older one left behind failed never takes an edit a newer op would revert) and into the row's `pending_changes`; an update followed by a delete becomes the delete; a delete is final. An op that fails for good while a newer op of the task is queued folds into that op (an update gives it the fields it does not set, a delete makes it moot), so a task never has two ops the sender could send in either order and a Retry can never overwrite a newer edit. Rows with `pending_delete` are left out of every DAO query; the counts the sync's probe compares ([D33](#d33-incremental-sync-watermark-on-updated-with-a-120-s-overlap-keyset-over-updated-id-delete-detection-by-per-project-count-check-and-id-reconcile-daily-full-resync)) include them, because the server holds those tasks until the delete is sent.
  - **`OutboxSender`** (`core/outbox/`), one per account, headless (the write client, the database, a clock and the `SyncEngine` are injected, so steps 15 and 16 can run it without a widget tree): drains the queue oldest first, one op at a time, each claimed `sending` in a transaction that re-reads it (an edit merged in since the queue was read goes with it), never two sends at once per account. A drain starts when the sender is built (app start), after every local write, when the app comes back to the front, on "Send now" in the Account tab (which drops every backoff first), when a retry is due, when a paused sender resumes, and when a sync reaches the server while the oldest op waits out a network failure (the backoff is dropped: the network is back); nothing runs in the background yet (step 16). Only the request is guarded: once the server has stored the change, an error while applying the answer locally propagates and leaves the op `sending`, so nothing is re-sent on the spot; the next start resets and re-sends it. The oldest op blocks the queue while it waits for its backoff, so later ops never overtake it; a `failed` op does not block. On success the server's task replaces the row, every field except the ones a newer op of the same task still holds pending; those fields leave `pending_changes`; the op is deleted. A repeating task therefore comes back open with its shifted dates. After a drain that sent at least one op the sender calls `SyncEngine.refresh()`, so server-computed fields arrive.
  - **Retry classes:**

    | Answer | Op | Sender |
    |---|---|---|
    | success, 304, or 404 code 4002 on a delete | the response is applied (a delete removes the row), the op is removed | next op |
    | `NetworkFailure`, `ServerFailure`, `RateLimited`, `TokenRejected` after the interceptor's own refresh and retry (the session was replaced by a new sign-in, or the server will take the next token; a session that ended for good arrives as `SessionEnded`), and an answer that is not Vikunja's: `UnexpectedResponse` with no status or one below 400 (a captive portal's page, a proxy's redirect, an empty body) and `NotFound` without a Vikunja code (a web server's 404 during a deploy) | back to `pending`; `attempts + 1`; `next_attempt_at` = now + 2 s · 2ⁿ, shortened by up to half at random, at most 15 min; a `Retry-After` above zero wins when the server sends one, capped the same way | waits for it; later ops wait behind it |
    | `SessionEnded` | stays `pending`, untouched | `paused` until the account is signed in again ([D22](#d22-session-keep-alive-through-background-sync)); nothing is ever dropped |
    | `NotFound` with a Vikunja code (3001; on an update also 4002, the task itself gone), `Forbidden`, `DomainError` code 3008, `ValidationFailed`, `UnexpectedResponse` 4xx or 5xx | `failed`, the failure as `last_error`: a `SyncProblem`, or folded into a newer queued op of the task | goes on with the next pending op |

    The spec's table had `TokenRejected` pause the sender and every `UnexpectedResponse` and `NotFound` fail for good; the review of step 11 moved them: a `TokenRejected` pause had no resume trigger (the session manager sets `needsReauth` only for `SessionEnded`), and the read side already treats a portal's or proxy's answer as a failed run to retry, so the two halves of the app now agree on what is transient.

  - **Sync problems:** `watchSyncProblems` streams the failed ops joined with the task title; the Account tab lists them with what failed and when, Retry (the op goes back to `pending`) and Discard (the task is read from the server first, `GET /tasks/{id}` through the read client, then the op is deleted and the row replaced, or removed on a 404 or a 403, which means the task left the user's projects and its row would otherwise stay purge-protected forever; a read that fails for another reason throws and changes nothing, so the local edit is never lost offline; the op is checked again inside the transaction, so a retry or delete that got through meanwhile is not undone). "Send now" says in a snackbar what still blocks the queue afterwards and is not offered while every queued change is a sync problem. `watchPendingChanges` counts every queued op, `sending` included; the Account tab shows "Pending changes: N" with "Send now" while N > 0, and a row whose task has unsent changes shows a cloud-off icon.
  - **Sync interplay:** the sync engine's upserts (initial, full, incremental, reconcile) overlay the row's `pending_changes` on the incoming task, so the incoming values win for every other field and the unsent fields keep the local value; a `pending_delete` row is written but stays hidden; every purge (the full pull's, the reconcile's, a removed project's) skips rows with a pending op; no run touches the outbox. Once the op is sent, the drain's refresh sorts the row out.
  - **UI:** the circle of a task row and the done control of the sheet call `setDone` (haptic, strikethrough at once, "Marked done · Undo" in the lists, where a done row stays in place until its own 3 s are up and its snackbar has gone, so a second tap never pulls the earlier row away under the finger; the sheet's checkbox is its own undo); the star toggles the favourite in the row and the sheet; Delete sits in the sheet's overflow menu behind an adaptive confirmation, after which the sheet closes and a snackbar confirms. The screens see the repository interface plus `SyncProblem`, `OutboxOperationKind` and `PendingTaskIdsSource` from `core/outbox/`, nothing of the DAO or the sender. The sign-out dialog says how many queued changes the wipe would lose and points to Send now. Semantics on every new control, en and de, dark mode and 200 % text scale as in every step.
  - **Rejected alternatives:**
    - **Sending each write straight to the server, without a queue.** Offline, a write would fail or be lost, and two quick taps could overtake each other. The transport retries GET and HEAD only, for good reason, so every write path would need retries of its own, and the notification actions (step 15) and the widgets (steps 18–19) need the same queue anyway (principle 3).
    - **Blocking the UI until the server answers.** A spinner on every tick, no editing offline, and a repeating task would still need the response applied afterwards. The optimistic row costs one stream event, and the Undo snackbar covers the mistaken tap.
    - **CalDAV** (Vikunja 2.4.0) as the write channel: it needs a CalDAV token created in the web app, which browser sign-in does not give the app ([D14](#d14-browser-sign-in-only)), it is a second protocol (XML, iCalendar) next to the JSON API, a VTODO has no favourite flag, and the result would have to be pulled back through the API anyway.
    - **`If-Match` preconditions and a 3-way merge over `base_json`** (the D31 reservation; [research/sync.md](research/sync.md) §6): the server ignores `If-Match` on writes and never answers 412 for a conflict, and v2's merge-patch already merges per field on the server. A field changed on the web while the same field waited in the outbox is overwritten by the phone's value; the description editor of step 25 revisits that for the one field where it hurts.
    - **Idempotency keys:** the server has none. An uncertain create needs the lookup of [research/sync.md](research/sync.md) §9.4, which arrives with creates in step 12.
- **Consequences:**
  - Done, undo, favourite and delete work offline and show at once; what is queued is visible in the Account tab and on the rows. Nothing is dropped silently: a permanent rejection keeps the local edit visible until the user retries or discards it, and a sign-out with queued changes says so in its dialog before the wipe (the only way an edit is lost, and only on the user's word).
  - Writes are at least once: an op whose answer could not be applied locally (the database closing, a full disk), or a kill between the server's apply and the local one, is re-sent at the next start. For a repeating task a re-sent `done: true` shifts the dates a second time; the GET-before-resend that would avoid it is left for a later step.
  - Undo of a repeating task restores the dates the task had; `done_at` stays stamped on the server, absolute reminders stay shifted (`TaskChanges` has no reminders field until step 12; relative ones follow the restored date) and the server's checklist reset in the description is not reverted.
  - Last write wins per field: a field the web changed while the phone's queued value for the same field waited loses to the phone; every other field survives (v2 by the server's merge, v1 by the overlay on a fresh read). Until step 12 only `done` and `is_favorite` can collide.
  - A repeating task shows done until the server answers, then reopens with the shifted dates. Marked done offline, a mode 2 task computes "from now" at send time, not at tap time.
  - The probe's local counts include the rows queued for deletion, because the server holds them until the delete is sent; a pending or failed delete therefore costs no extra requests on every refresh. A task deleted on the web while its local delete is queued is a mismatch until that delete is sent, which the 404 code 4002 answers as success.
  - The transport keeps retrying GET and HEAD only; writes are retried by the sender with its backoff, and a paused sender resumes with the next sign-in, so the 72 h session end ([D22](#d22-session-keep-alive-through-background-sync)) never loses an edit.
  - `TaskRepository` gains the write methods; the step 5 widget tests keep running against the fake repository. The migration to schema version 2 runs on the first open after the update.
  - Step 12 extends `TaskChanges` and adds creates (a local id until the server answers, the id mapping and the uncertain-create lookup); steps 15 and 18–19 send their "Mark done" through the same outbox; step 16 drains it in the background.
  - The write ports are contract-tested against the live 2.7.0 server on both API versions (`packages/vikunja_api/test/contract/write_contract_test.dart`: a task seeded with an assignee, two reminders and a label keeps all three through a done toggle, the v1 full-replace regression; undo, favourite, title, a repeating task reopened a day later, a delete twice), and so is the whole pipeline (`app/test/contract/outbox_contract_test.dart`: seed, initial sync, `setDone`, `setFavorite` and `deleteTask` drained and checked on the server and in the row, a write whose first attempt fails with a `NetworkFailure` and is retried, a repeating task reopened with the server's date).
