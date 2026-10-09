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
