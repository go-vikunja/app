# Decision log

This log holds the app's important decisions by topic, each with its reason ("why: ...") as it holds today. A decision belongs here when it changes how the app or its release works, is a rule that keeps users, data or security safe, records a server or store behavior the code cannot show, or is a deliberate choice someone could reverse by accident; fixes, review notes, step records and history stay in git. Limits and Open list the gaps that still matter. A decision is not reversed without discussing it first. The background for most topics is in [research/synthesis.md](research/synthesis.md).

How to cite it: in code comments, tests and tool messages, `(decision log: <Title>)` with the topic's heading exactly as written, at the end of the sentence, such as `(decision log: Sessions)` or, for two topics, `(decision log: Sync, Outbox)`; a deviation of quick add from the web as `QA-<n>` alone, such as `QA-8`. Docs link the heading's anchor: `[Sessions](decisions.md#sessions)` from `docs/`, `[Sessions](docs/decisions.md#sessions)` from the repository root. A heading is renamed only together with its citations.

The earlier numbered log (D1 to D118) is in git: `git show ae594a5:docs/decisions.md`.

## Topics

- [Identity and scope](#identity-and-scope): the official app, its ids, name, icon and license.
- [Stack and structure](#stack-and-structure): Flutter, the workspace, the libraries and the code rules the code cannot state by itself.
- [Servers](#servers): probing and capabilities, the support floor 2.3.0, Vikunja 2.8.0 and the contract tests.
- [Connections](#connections): the transport, unencrypted connections, connection settings per server, the probe and realtime.
- [Accounts and sign-in](#accounts-and-sign-in): browser sign-in, several accounts, account settings and link-share guests.
- [Sessions](#sessions): the server's session facts and how the app keeps every session alive.
- [Sync](#sync): the local database, full and incremental sync, background runs and realtime.
- [Outbox](#outbox): how local changes reach the server, and which writes stay online.
- [Tasks](#tasks): lists, search and filters, opening and editing a task, swipes and selection, the trash.
- [Projects](#projects): the Projects tab, views, Kanban, manual order, Table and Gantt, labels, teams and sharing.
- [Quick add](#quick-add): Quick Add Magic's grammar, its deviations QA-1 to QA-20, adding and the composer.
- [Descriptions, comments, attachments](#descriptions-comments-attachments): rich text as hostile input, the editor, comments, attachments and offline details.
- [Notifications and widgets](#notifications-and-widgets): which tasks notify, local scheduling, actions, activity and home-screen widgets.
- [Security and privacy](#security-and-privacy): the threat model, the app lock, screens and notifications, data on the device, errors and other apps.
- [Diagnostics](#diagnostics): the support details, the diagnostics log and opt-in crash reports.
- [Look and layout](#look-and-layout): design and color, device settings and the shell, large screens, the screens in the maintainer's order.
- [Accessibility](#accessibility): WCAG 2.2 AA as the yardstick, the deviations accepted on purpose and the guards.
- [Languages](#languages): US English as the base, Crowdin and German, language and region on the device.
- [The previous app](#the-previous-app): the first start after the update of the old Android app, and what it clears and keeps.
- [Releases](#releases): channels and versions, CI, signing and publishing, iOS, stores and pages.

## Identity and scope

### The official app

- The app is the official Vikunja mobile app, in https://github.com/go-vikunja/app. No file names a maintainer, except the commit authorship.
- **Ids:** `io.vikunja.app`. On Android it is the old app's listing in Vikunja's Play account, and the app ships as its update, signed with Vikunja's upload key (why: the old app's installs keep updating; [The previous app](#the-previous-app)); the iOS bundle id is the same, and Vikunja has nothing registered at Apple yet (Open below). The id is permanent once signing keys or store listings exist.
  - Derived: `io.vikunja.app.widgets` and the App Group `group.io.vikunja.app`; the launcher component stays `io.vikunja.app/.MainActivity`. The app scheme and the OAuth `client_id` are one value, `vikunja-io.vikunja.app`, as the maintainer named one value for both ([Accounts and sign-in](#accounts-and-sign-in)).
  - `User-Agent`: `Vikunja-App/<version>[+<build>] (<system> <version>)` (why: `Vikunja/…` could read as the server's own requests).
  - No `applicationIdSuffix` for debug builds (why: two installs would share the sign-in scheme, and the browser could hand the sign-in to the wrong one).
- **Name and icon:** **Vikunja** in both stores and languages, with an icon derived from Vikunja's logo and the old official app's icons as the look to follow. No text calls the app unofficial; `tool/check_store_metadata.py` refuses it.
  - The only icon source is Vikunja's `logo.svg`, copied byte for byte, its provenance in [branding/README.md](../branding/README.md); `branding/build-icons.sh` derives every variant under fixed file names (why: the launcher configuration, the asset catalog, `keep.xml` and `NOTICE.md` match them).
  - The name and the logo belong to the Vikunja project and are not under the MIT License; the logo is used with the project's permission, and a fork that distributes its own build uses its own name and logo.
- **No former name:** no file names the app's former development name or the name proposed before it, in its text or path; the git history keeps them. Test data carries the new names, the E2E users `vikunja-app-e2e` and `vikunja-app-e2e-2` included. No guard tests for names, ids or license texts.

### License and contributions

- **MIT,** with the line `Copyright (c) Vikunja and contributors`, exactly so, without a year. Third-party material in old commits keeps its own license; test files with vectors from Vikunja's tests stay AGPL-3.0-or-later and never ship.
- **Nothing of Vikunja's ships but its logo** (why: Vikunja's server and web are AGPL-3.0-or-later, which the MIT-licensed app cannot take in): the app reads the web for behavior and writes its own code and texts ([Languages](#languages)), and the editor keeps only what the stored HTML needs.
- **Vikunja's contribution rules** apply, the app's code rules in `CONTRIBUTING.md`: no CLA and no DCO; translations only through Crowdin; security reports privately to security@vikunja.io. Not added: `AGENTS.md`, `CLAUDE.md`, `CODEOWNERS`, `FUNDING.yml`. The GitLab CI is deleted.
- **Source and offer:** only release builds carry the source link, to the tree at the release's tag, which must open signed out (why: every release links its source for everyone; [Releases](#releases)). The Vikunja project makes the written offer for the desugar_jdk_libs source (GPL-2.0 with the Classpath exception) through hello@vikunja.io; GitHub releases carry that source, Google Play and dl.vikunja.io rely on the offer.

## Stack and structure

- **Flutter** is pinned by version and SHA-256 in `tool/ci/pins.sh` and the same version is used locally (why: what the release job builds is what was tested).
- **One pub workspace** with a single `pubspec.lock` (`app`, `packages/vikunja_domain`, `vikunja_api`, `vikunja_logic`, and the in-repo plugins under `plugins/`, path dependencies of the app only); `flutter pub get` runs only at the root.
  - `packages/*/lib` stays free of Flutter (no `package:flutter*`, `material_ui`, `cupertino_ui` or `dart:ui`), checked by `tool/check_pure_dart_packages.sh` (why: this code must also run on the plain Dart VM).
  - The pure packages test with `flutter_test` and `flutter test`, never `package:test` (why: in the shared resolution it conflicts with the `test_api` that `flutter_test` pins).
- **material_ui and cupertino_ui,** never `package:flutter/material.dart` or `cupertino.dart` (why: the SDK's Material library is being decoupled and deprecated, so there is no migration later).
- **Riverpod 3 with code generation;** a headless `ProviderContainer` serves the non-UI isolates (why: background runs, notification actions and widget callbacks build the same object graph without a widget tree).
  - The generated `*.g.dart` files are committed, and CI fails when regenerating them changes anything; the generated l10n code is not ([Languages](#languages)).
- **go_router** for every route (why: owned by flutter.dev, works with material_ui, and `StatefulShellRoute` gives the shell its per-tab stacks). Pages over the tab bar are bound to the account unless stated otherwise, and a switch blanks them.
- **dio everywhere;** the packages receive a configured `Dio` and never pick a transport (why: the interceptors for auth, retry and redacted logging are shared, while the app picks the stack per server, [Connections](#connections)).
- **Hand-written v1 and v2 adapters** over one shared DTO layer (why: both versions share the server's models, v1 has no usable spec, and the app needs a fraction of the operations); swagger_parser with retrofit stays the fallback if v2 grows faster than the adapters can follow.
- **Screens only through repository interfaces** and domain types, never DTOs or ports (why: an implementation can change without touching a screen, and widget tests use fakes). The contract is a stream of the current local state plus explicit refresh calls: a failed first load is the stream's error, a failed refresh throws and leaves the stale data. Online-only areas (account security, sharing, teams, the trash) have online implementations.
- **Lists read whole:** outside the sync, one helper in `vikunja_api` skips ids already seen, stops at the server's page count or at a page without a new id, and stops after 200 pages (10,000 items) with a warning in the diagnostics log. Keeping their own rule on purpose: the sync's walks, which never cut ([Sync](#sync)); reads of a bounded window; and the outbox's label search by title, which reads to the end.
- **Deep task comparison:** lists of a filter evaluated on the device deduplicate with `vikunja_domain`'s deep comparison (why: a renamed label or a local change leaves `updated` alone). `Task ==` stays shallow (why: the sync and the outbox rely on it leaving out the reminders); new code that deduplicates tasks uses the deep comparison.
- **package:html is held at exactly 0.15.7** (why: the bounded HTML parser subclasses its internals to count its work, [Descriptions, comments, attachments](#descriptions-comments-attachments)); an upgrade is a change of its own that rereads those internals against the budgets.
- **Checked layers** (`app/test/app/layer_imports_test.dart`): `core/` imports nothing of the app but itself and the localizations, `main.dart` and a conditional import's alternatives included, and nothing by a relative path; `bootstrap/` is imported only by itself and `main.dart`. An exception needs an entry with its reason; the only one is the home-screen widgets' code in `core/widgets/`.
- **The parity suite** (`app/test/parity/`) runs one body of cases through the app's own sync, outbox and repositories against the unit tests' fakes and against the test server over v1 and v2 (why: a fake that drifts from the server shows). Cases match failures by kind, never by code, and avoid the divergences the fakes keep on purpose, listed on `parityScenarios` in `scenarios.dart`.
- **Rejected:** a key prefix `account.<id>.` for per-account preferences, and one stored shape for the user settings and the wire's (why: each needs a migration of every install; the account wipe test gives the guarantee without one, [Security and privacy](#security-and-privacy)).

Limits:
- `webview_flutter`, `flutter_riverpod` and `flutter_web_auth_2` import the SDK's legacy libraries internally.
- No check of the DTOs against the server's OpenAPI spec; it is planned, not built.
- The parity suite has no Kanban case and no second user.

## Servers

### What the app reads of a server

- **Probing:** `/api/v2/info` and `/api/v1/info` in parallel; a probe counts only for a 200 with a JSON body that has a string `version`, and every API version that counts is recorded (why: `/api/v2` exists only from 2.4.0, and proxies can hide it). At most one redirect, only one that keeps the `/info` path or goes from `http` to `https` on the same host; never `https` to `http`, and anything else off the host counts as a login proxy.
- **Capabilities, never version strings alone:** features check what the API versions, version thresholds, `/info` flags and `enabled_pro_features` allow (why: development builds report `dev` or `unstable`, and admins and licenses switch features).
- **`/info` is read again while signed in**: for the active account in front, first in front after a start, then at most every 6 hours, and 5 minutes after a probe that failed. An answer from another root or an unsupported server is not stored, and an API version the account has is never dropped, only added (why: a timed-out `/api/v1/info` would otherwise move attachment previews to v2). A changed server or API version rebuilds the account's API clients and sync engine, as a new sign-in does; the account's sync status goes on meanwhile (why: a status that started over would send the router to the first-sync screen, over whatever the user was editing).

### The support floor

- Vikunja **2.3.0** and newer, 2.4.0 and newer with a reachable `/api/v2` first-class, as browser sign-in, the only sign-in, needs the server's OAuth 2.0 + PKCE endpoints, which exist from 2.3.0; the old app required 2.3.0 too. The floor stays at 2.3.0, and what older servers get wrong is fixed in the app instead. The v1 adapter stays for 2.3.x and for proxies that hide `/api/v2`; an older server shows a blocking banner and nothing to sign in with, and a shared link to it, or a guest's link opened again there, says so in the overview's words before the link is sent (why: a guest runs on the same adapters and sync, and what older servers do differently is answered only from 2.3.0).
- **What older servers do differently, and the app's answer**:
  - Below 2.5 on v2, every merge-patch or full PUT of a task or project the user follows fails with 422, so the app adds `"subscription": null` to those patches; 2.4.0 to 2.8.0 accept it and keep the follow.
  - Before 2.6 every link-share guest is listed with read permission, so the app reads the shared project itself ([Accounts and sign-in](#accounts-and-sign-in)).
  - Before 2.7 a deleted link share's token gets a 500 without a code on v1, so a token renewal, at most every 5 minutes, tells a gone share from a server error.
  - 2.3 has no task-by-index route, and its 404 looks like an unknown project's, so below 2.4 the task is read by filtering the project's tasks by `index`.
  - 2.3 keeps project identifiers in their typed case, unique only in exact case, so an identifier names the exact match, else the only match ignoring case.
  - Before 2.6 the server refuses to unfollow what a followed project covers (403), so such a follow shows as fixed, naming the project to unfollow.
  - Before 2.5 the server keeps a deleted done or default column, so the app reads the board first and clears it ([Projects](#projects)).
  - An unknown version (only possible with `/api/v2`) counts as new for the subscription patch, the by-index route and the unfollow, and as old for the guest's permission and the column check.
- Accepted as they are: on 2.3 the identifier of a project the user cannot read is not found rather than forbidden, and the v1 previews on 2.4 to 2.6 stay out of the gone-share check. Differences that change only an order or what a view shows stay, and their tests skip.

### Vikunja 2.8.0

- **The app follows 2.8.0**: the trash and accent-free search ([Tasks](#tasks)), reminders that follow subscriptions ([Notifications and widgets](#notifications-and-widgets)), the Okabe–Ito palette ([Look and layout](#look-and-layout)), the lockout hints ([Accounts and sign-in](#accounts-and-sign-in)) and the legal links.
- **Gone stays gone:** a task is gone on 4002 or 4040 (in the trash), a project on 3001 or 3018; deletes complete on either code, queued ones too.
- **Its limits hold on every server** (why: far beyond use, and one rule keeps the outbox from producing a refusal anywhere): titles of at most 1000 code points, a longer pasted or quick-added text cut at the last space that fits with the rest starting the description; at most 100 reminders; business-day offsets in a filter up to 10000.
- **U+0000 is removed from every JSON write** in the write transport (why: 2.8.0 refuses such a body with 400), and the outbox's lookups compare without it, so a pasted NUL neither duplicates a task nor fails a write for good.
- **Legal links:** every one the server lists with a text and an http(s) address with a host shows, in the server's order, on the server overview and in the Account tab; "Imprint" and "Privacy Policy" in the app's words, every other text as its admin wrote it.

### Contract tests

- **Per-push CI runs the latest release**, pinned in `test_servers/docker-compose.yaml` by tag and the digest of its multi-platform index (why: so the pin also holds on CI's amd64). The tests are tagged `contract`, need `VIKUNJA_CONTRACT=1` and run in a job of their own.
- **The contract matrix** runs them against the newest release of each minor line from the floor, 2.3.0 to 2.8.0, 2.5.0 and 2.6.0 included, nightly in go-vikunja/app, on every `v*` tag and by hand, beside CI. Before a release is approved, what fails in the tag's run is fixed or recorded in this log ([releasing.md](releasing.md#cutting-a-release)).
- **Version-aware tests:** a behavior that differs between releases is asserted from its first release, skipped or asserted the old way before it; each gate is proven by flipping it one release lower.
- **The test server listens on `127.0.0.1` only,** in CI too (why: open registration with a public JWT secret).
- **Server facts the test servers rely on:** the sign-in limit cannot be turned off, so they raise it from 10 to 1000 a minute. SQLite runs with immediate transactions, set through the database path (why: parallel writes then wait instead of failing with "database is locked"), which relies on the server appending its options after a `?`: after an image bump the startup line "Using SQLite database at:" must show them. Releases before 2.7 can hang under immediate transactions, so 2.3.0 runs without them, its `vikunja_api` files one at a time.

Limits:
- The older releases run only at night and on tags; the matrix is no required check and holds a release only through its reviewer. It has not run on GitHub yet.
- A stored server version stays until `/info` is read again: an account stored as 2.3 after an upgrade keeps the filtered read by index, which does not follow v2's 307 for a moved task.
- Relative legal addresses, which the web shows, are not shown.

## Connections

### The transport

- **Platform stacks:** Cronet on Android and NSURLSession on iOS, through native_dio_adapter (why: on Android `dart:io` ignores user-installed CAs and system proxies, dart-lang/sdk#50435). `dart:io` serves only servers with a pinned certificate, a trusted CA or a client certificate (why: only it can pin in the handshake or present a client certificate; it lacks the OS proxy and Android's user CAs, so every other server stays on the platform stack).
- **Embedded Cronet, never Play services' Cronet or any other Play services library**. Why: Cronet then works on every device without Play services, user CAs and proxies included, the app holds no proprietary code, and F-Droid stays possible. The Gradle build excludes `play-services-cronet` everywhere, and the notice generator refuses Play services.
- **No HTTP flags, no telemetry:** the manifest's disabled `android.net.http.MetaDataHolder` sets `ReadHttpFlags` and `EnableTelemetry` to false (why: otherwise Cronet applies a flags file from a system-image package, which can change its features or swap in the platform's `HttpEngine`).
- **Every answer's body has a size cap in the transport:** 64 MiB, 2 MiB for avatars, 25 MiB for attachments read into memory; a larger one is refused, its connection closed, and never retried (why: one endless answer from a hostile server would take the app's memory). Downloads to a file and the `/info` probe, which cuts its own body, are exempt.
- **Cronet's security fixes come only with an app update,** so a newer `cronet-bundled` is looked for at each Chrome stable release that fixes `net/`, BoringSSL or QUICHE and before each release; the weekly "Upstream versions" workflow fails while one is newer ([releasing.md](releasing.md#raising-cronet)).

### Unencrypted connections

- **The OS allows cleartext** (Android's network security config; iOS's `NSAllowsArbitraryLoads`), so home-LAN servers on `http://` can be reached at all; ATS exceptions and Android's per-domain rules are fixed at build time, so the in-app consent is the actual control. Never `NSAllowsLocalNetworking` or the web-content and media variants (iOS fact: iOS then ignores `NSAllowsArbitraryLoads` and blocks confirmed `http` to fully qualified hosts, such as split-DNS names, `*.ts.net` and VPN hosts).
- **`https` first:** `http` is tried only when the user typed no scheme and every `https` candidate failed at the connection level. A rejected certificate does not count (why: a TLS server answered, so the user is pointed at the certificate, never at cleartext).
- **"Unencrypted connection"** is asked once per origin. The consent is recorded before the connection goes on (a failed write ends in an error, never a request), can be revoked, and is enforced in the transport for requests and `ws://`; only the bare `GET` of `/info` passes before it.
- **"No encrypted connection"** is asked every time, consent or not, when an address typed without a scheme reached `http` only because `https` failed (why: a network that blocks port 443 looks exactly like an `http` server, and the consent accepts `http` for that server, not a network taking `https` away).
- **No `http` account is upgraded to `https`** (why: the account id derives from the root, [Accounts and sign-in](#accounts-and-sign-in)). The Connection page probes `https` on ports 443 and 3456 and offers a new account there; once the same user is signed in over `https`, the app offers to remove the `http` one, naming its unsent changes (why: with both, every reminder comes twice). Signing that account out forgets the offer, so its id leaves the backed-up preferences.

### Connection settings per server

- **Per origin** (scheme, lower-case host, effective port): a pinned certificate or a trusted CA, a client certificate, access headers and the consent, applied by one adapter below the retry, auth and log interceptors, so nothing above the transport holds a header value. An edit never rebuilds a `Dio` (why: it would tear down running syncs). Redirects are off (why: `dart:io` would copy access headers to a cross-origin target).
- **Pin:** the SHA-256 of the leaf's DER, checked in the handshake before any HTTP byte (never dio's `validateCertificate`, which runs after the request was sent); trust on first use, a changed certificate stopping every request until the user accepts the one probed now.
- **CA:** a PEM checked against the server before saving; on iOS the leaf must name the server and be valid for at most 825 days (Apple's rule). A pin and a CA exclude each other (why: the CA would verify the chain before the pin is asked).
- **Client certificate:** a `.p12` or `.pfx` with its file password (why: `dart:io` needs it for every context); a private-CA server then needs its CA or a pin in the app (why: device-installed certificates do not reach `dart:io`).
- **Access headers** go only to their own origin, never under a name the stack, Vikunja or the socket set.
- **Storage:** secrets (header values, the PKCS#12 file and its password) in secure storage under a hash of the origin (why: it cannot be listed), the rest in the preferences; settings without secrets work before the first unlock.
- **Fail closed:** no request leaves without its origin's settings. Unreadable storage is transient, damaged metadata stops every origin until "Reset connection settings", missing secrets need re-entry; none is a connection failure, so the connector never falls back to `http` and queued writes stay queued.
- **A settings failure is no outage:** a request the settings stopped (a client certificate refused or missing, an unencrypted connection without consent, settings not readable yet, incomplete or damaged) shows no offline state in the offline banner, the refreshed lists, the pages that read the server themselves (teams, a team, a project's shares, the trash) and the New team button; those pages say what went wrong and offer the settings, and the team, share and trash messages and the person search point to them (why: retrying at once does not help; a change of the settings does, or for settings not readable yet the device's unlock).
- **No secret in a message:** an error quoting a stored header value or password of 8 characters or more loses its text (why: shorter values turn up by chance in ports and host names).
- **Client-certificate refusals** count by the platform stacks' errors and the TLS alerts, never by `SSLV3_ALERT_HANDSHAKE_FAILURE`, which any mismatch sends. On `dart:io` TLS 1.3 reports a refusal only on the first read, so a second handshake confirms it, for requests and the socket alike, its answer kept 10 s per origin. nginx's default 400 pages for 495 and 496 count too.
- **Before every browser sign-in** a dialog says what the browser meets that the settings do not cover (why: the browser does not use them): the fingerprint to compare, a CA warning, the client certificate needed in the device settings, the access login, another sign-in host.

### Probe and realtime

- **The `/info` probe** runs before any trust check, so it reads at most 256 KiB (why: enough to classify login pages), then cancels (why: in dio only a cancel closes the connection), and ends after 10 s, so the connector's bound of 17.5 s holds for every adapter.
- **The realtime socket** runs on `dart:io` with the origin's consent, headers and TLS client. On Android a server without TLS settings gets the system roots, the user CAs and the system proxy the platform reports; user CAs are trusted for every server, for the reasons in the threat model's R8. A settings failure ends the socket until the next resume or edit; polling stays the fallback ([Sync](#sync)).

Limits:
- The browser legs do not use the settings: a pinned or private-CA server shows the browser's warning at every sign-in, the password typed there is protected only by the user's check, and an access proxy shows its own login every time.
- Chromium's network stack lags Chrome stable by weeks ([threat model](threat-model.md) R34), and the protobuf shaded into Cronet is named by no lockfile, so no scan sees it.
- `NSAllowsArbitraryLoads` also drops ATS's TLS 1.2 and forward-secrecy minimums for `https`.
- An `http` account's unsent changes go with it unless sent before it is removed.
- WebSocket messages and downloads to a file have no size cap ([threat model](threat-model.md) R49, R50).
- A server's `frontend_url` and legal links with user info are still accepted; a server's own `error_page` for 495 and 496 is not recognized.
- Not offered: SPKI pins, `Proxy-Authorization`, client certificates from the OS key store, a SOCKS proxy.
- Waiting for the iOS device test: pinning and PKCS#12 under SecTrust, the 825-day rule, headers through NSURLSession.
- A settings failure still reads as a missing connection in the task details and comments, inline attachment images, the assignee picker, the task reads of project views and smart lists, and the account settings and avatar pages.

## Accounts and sign-in

### Signing in

- **Browser sign-in only**: OAuth 2.0 with PKCE in the system browser; the app never handles an account password or a TOTP code, so no password form, no API-token login and no OIDC in an embedded WebView (why: Vikunja plans to remove password login, and from 2.3.0 the web's login page covers local, LDAP, OIDC and TOTP).
- Client id and redirect scheme `vikunja-io.vikunja.app` (server facts: no client registry, the id need only match between authorize and token call, and the scheme must start with `vikunja-`).
- **The browser session is ephemeral**, and a sign-in page on another origin than the server root is named first, "Sign in at {host}?" (why: Vikunja has no consent screen and no RFC 9207 `iss`, so a server could send the sheet to another server's sign-in page and redeem the code of the account signed in there). Only "Sign in again" at the origin the account last signed in at skips the question. No request carrying a token follows redirects.
- **The callback must match** the redirect URI and the state, and "Sign in again" accepts only the account's own user: another user is refused before anything is stored, and that session is logged out (why: an account's data and queued changes belong to its user).
- Create account runs the normal browser sign-in; Forgot password and invite links open the web's pages in the external browser (why: the web drops the app's sign-in on an invite registration).
- A shared text with an admin's invite asks first, as a project's link does, naming the host, and signed in can still become a task; the invite is checked only after Open invitation (why: the check sends the invite's token to the link's host, and the text may only mention the link).
- **iOS 15.0 is the minimum** (why: below iOS 17.4 flutter_web_auth_2 falls back to the older ASWebAuthenticationSession initializer, which handles the custom scheme; only `https` callbacks need 17.4).

### Several accounts

- **Several accounts in the first release**: a server plus a user, or a link-share guest, each with its own tokens, database, outbox and sync state; one is active in the UI, and background sync and reminders cover all.
- **The registry** (`auth.account_registry` in `SharedPreferencesAsync`) holds no secrets, and every write holds a lock all isolates of the process honor (why: isolates read it before any database opens, and a stale write-back would bring a removed account back). An entry that cannot be decoded is left out of the state but written back unchanged, and a registry that cannot be decoded at all is copied to `auth.account_registry.unreadable` before it is first overwritten (why: no write may lose an account the build cannot read).
- **Account id:** 32 hex digits of `sha256("${serverRoot}|${userId}")`, a guest's of `"${serverRoot}|share|${shareId}"`. So one server under two addresses gives two accounts, and an `http` account is never upgraded to `https` ([Connections](#connections)).
- **A switch** only sets the active id; before the next frame the shell closes everything over it and resets the tabs (why: no screen may read another account's database). A switch from outside (a link, a notification or widget tap, a share) first lets open pages go as if the user went back, and Keep editing refuses it.
- Inactive accounts' outboxes drain in the foreground, but only the active account syncs there (why: queued changes are what cannot wait).
- **Removal is a full sign-out** (server logout, tokens, registry entry, database, notifications) and crash-safe: the account is listed as still to delete in the same registry write, and the next start finishes the wipe. Every part of the wipe is tried, also after one failed, and an account a part failed for stays listed, so the next start tries again (why: a reminder with a task title, a widget's content or an unsent comment must not outlive its account); its database goes all the same, and the next start finds the notifications the device still holds by the account each one names. A failed removal says so and the account stays, marked to sign in again, with a sign-out that did not finish on record before the mark (why: its session was retired already, and a restore would otherwise take an earlier end's record and unmark it).
- **Signing straight back in** waits up to 30 s until a wipe of the account's data still running has ended and the old database isolate has gone (why: the same id would attach to it and work on deleted files); a user's sign-in waits for every removed account, as the account is known only when the browser returns.

### Account settings

- Account settings save online at once. **Writes never wipe the web's settings** (why: v1 `POST` and v2 `PUT` replace everything, and an omitted `frontend_settings` wipes every web setting): from 2.7.0 a merge-patch of the changed fields, before that a full write from a fresh raw read keeping every unknown key.
- **Everything that needs a password or code is on the web:** password and email, two-factor, data export, account deletion and its cancel; never a password field, QR code or two-factor secret in the app. Returning from those pages checks the session at once.
- Two-factor status is not read over `http` before 2.7 (why: the answer carries the secret).
- **Delete account on every server** (why: Apple Guideline 5.1.1(v) and Play require it where accounts are created); where the server does not allow it, the app says whoever runs the server can.
- API tokens always expire (30, 60, 90 days or a picked day); on 2.8.0 the Task and Project management presets include the trash's permissions as on the web.
- **Lockout hints**: 2.8.0 locks a local account at the tenth wrong password, from any device or CalDAV app, until a password reset; there the lockout sentence follows every "The web asks for your password.", and the CalDAV page recommends a CalDAV token. A scheduled deletion says on every server that the web asks for the password.

### Link-share guests

- **Kept in the official app**. A guest may do what the web's interface offers a link share of the same permission and the server accepts; not what the web reaches only by a typed address; also, as the server accepts them, editing its own comments and assigning people already on the device. A write guest gets less than the web in one place only, the column guard in [Projects](#projects). No QR scanner.
- A guest's permission is the stored project permission, never the token's claim (why: the server reads the share on every request).
- **Secrets:** JWT and hash in secure storage, the hash written first and deleted first. The share's password is not stored (why: a renewed token never expires and the password guards someone else's project), unless "Remember the password on this device" is ticked, off by default.
- **Opening a link:** Cancel or Close stores nothing until the server has answered for the hash; from then on both are gone and the guest is kept (why: as with the previous app's session, a guest stored halfway would leave its secrets behind). "Open link again" keeps whichever account is active and brings back no guest removed meanwhile (why: a switch or removal made while it runs stands).
- **Session:** the 72 h token from `POST /shares/{hash}/auth` is renewed after half its lifetime, and an expired one replaced by signing in with the hash; a 429 waits for `Retry-After`, and an OS-started container tries once (why: a password share must not spend the shared rate limit every half hour).
- **A gone share** ends it, and only the server's own answer says so: v1's 400 code 13003, v2's codeless 401 on a link-share request, 404 code 3006 or a codeless 404 at the share endpoints, a codeless answer only with a JSON body, as Vikunja always sends; the check reads `GET /user` (why: `/token/test` passes a deleted share's token). Any other 404 or 401, such as a reverse proxy's own page while the server restarts or an access gate's refusal, is an ordinary failure: a renewal backs off and keeps its token, and signing in with the hash is tried again later (why: the guest syncs again once the server is back, instead of being asked to open the link again). Meanwhile the request that needed the token fails as the server being unavailable (why: as that request's own 404 it would read as a feature the server lacks, and a queued upload would fail at once as attachments being off). Older servers are in [Servers](#servers).
- **A share that asks for its password** when the hash signs in again on its own, as none is remembered (412 code 13001) or the remembered one is refused (403 code 13002), ends the session as "password needed", never as a gone share, and a refused password is forgotten (why: only the user can give the password, and opening the link again asks for it; the share is still there, so the app must not say it is gone).
- **Closed by default:** only routes in `AppRoutes.openToGuests` open (`guest_gates_test.dart`), and `guest_action_inventory_test.dart` fails for a new user-only action not listed with its reason.
- **Where a link and its password go:** without asking only to a stored server on the link's own origin whose web frontend is the link's base; else the base is probed, and a Vikunja server answering there wins; a stored server that only claims the base gets them after Continue on a card naming both hosts (why: any added server can name another's web host in `/info`, and the hash is a long-lived secret). Links with user info are refused.

Limits:
- The mix-up stays open until the server sends `iss` or shows a consent screen; whether a named host belongs to the server is left to the user, and any app with a `vikunja-…` scheme can get a token from a web login in the system browser.
- Browsers the plugin takes to lack ephemeral sessions (Chrome and Edge before 141, Samsung Internet before 28, Firefox before 143) can reuse a web login; signing out of the app does not end it.
- flutter_web_auth_2 5.x predates its UIScene and Kotlin migrations (6.0 is due once stable); iOS has deprecated ASWebAuthenticationSession for `http://` pages.
- A user who continues past the link card unread, or a look-alike host, still sends the link and its password (the threat model's [R41](threat-model.md#7-residual-and-accepted-risks)).
- A proxy that answers a guest with a JSON object of its own, as a codeless 404 or 401, is still taken for the server.

Open:
- The browser sign-in on iOS 15 to 17.3, which relies on the plugin's older ASWebAuthenticationSession path, waits for the device test ([beta.md](beta.md#the-ios-device-test)).

## Sessions

A live session must never be lost to the app's own mistakes. The server facts it rests on:
- OAuth sessions never "stay signed in": they end 72 h after the last refresh (`service.jwtttl`, sliding, reported nowhere); access tokens live 600 s.
- Vikunja rotates the refresh token on every refresh, without grace, and commits before it answers: a rotated token gives 401 code 16002 and the session is lost; the loser of a concurrent rotation gets 16004, on SQLite servers a 500 and then 16002. From 2.7.0 every refusal carries a code.

### Keeping sessions alive

- **Background runs keep every signed-in account alive**: their first request finds the access token expired and refreshes, which slides the 72 h window ([Sync](#sync)). Opening or resuming the app checks the active session with `GET /user`.
- An ended session marks the account `needsReauth`: its data stays, its outbox pauses, and a "Sign in again" notification is posted.
- **"Background sync is limited"** shows while the platform blocks background runs (Background App Refresh off or restricted, an Android background restriction), not for battery saving, while a user account is signed in.
- **The session reminder**, per user account, comes 12 h before the session would end, moved to 21:00 when due at night; it holds no task data and never comes for a guest (why: a guest signs in again with its hash).

### Storage

- Tokens live only in secure storage, **readable after the first unlock** (why: background runs, notification actions and the widget worker use them while the device is locked); before it nothing refreshes, and a locked store counts as a network error. They stay out of backups and device transfers ([Security and privacy](#security-and-privacy)).
- **`resetOnError: false`** on Android (why: the plugin's reset would wipe every account's tokens after a passing Keystore failure in a background engine).
- **A failed token read is transient:** tokens are kept and tried again. Only reads that keep failing at app starts for 24 h with no good read between ask for a new sign-in; the check runs in the app's start only (why: a background engine's first Keystore read is where passing failures show).
- Sign-in writes are retried, the third time with the plugin's default options, which repair a lost key; if all fail the new session is logged out. No other write resets anything (why: a reset deletes every other account's tokens). On Android every token write waits until the plugin's file is on disk (why: the plugin writes with `apply()`).
- **A sign-in that cannot register its account** takes back what it stored when the account is new to the device and storage held nothing for it, and logs a user's new session out; a guest's link, token and remembered password go after any failure from the first write on (why: nothing may stay of an account the app does not list, and a guest's link never expires on its own). An account already on the device, or one whose storage held tokens or a link before, keeps what was stored (why: its entry, or one this build cannot read, names them). The registry is read before anything is stored, so one that cannot be read stores nothing.
- **After an iOS reinstall** the first start without install marker and registry wipes secure storage once (why: the Keychain survives deleting the app, the preferences do not). A wipe that has not answered after 10 s counts as failed, and the next start tries again (why: a Keystore that never answers must not hold the app on the launch screen); like any failed wipe, it leaves the previous app's session untried.

### Refreshes

- Only the session manager refreshes, one refresh per account and isolate at a time; before a refresh and on every session-ended answer it re-reads storage and adopts tokens another isolate stored.
- **Write-ahead:** rotated tokens are stored before the new access token is used (why: storage would otherwise hold the dead refresh token for a sibling isolate); a failed write keeps them in memory and writes them before the next token request, never over newer tokens.
- **No cross-isolate lock** (why: `RandomAccessFile.lock` takes POSIX locks, which belong to the whole process); re-read and adopt is the only cross-isolate mechanism.
- **Races are no end:** after 16002 or 16004 storage is re-read for about 16 s, and after a sign of a race the call fails as deferred so a later one adopts the winner's tokens. The re-reads never send a token already refused.
- **Failure classes:** network errors keep the tokens; a 5xx is retried once after 2 s; a 429 waits for `Retry-After`, at most 10 min; 16002 without a race, 16003 and 412 code 1020 or 1040 end the session; unreadable storage, a missing or unreadable registry connection and, from 2.7.0, a codeless 401 keep the tokens.
- **Retirement**: sign-out, removal and a new sign-in retire the account's manager for good; it hands out no token, not even from a refresh still running or the old access token after a failed one, and writes nothing more. A new sign-in retires it before storing the new tokens; a call that meets that retirement, a refresh still running included, gets "no token yet", like a deferred refresh, rather than "session ended", and goes out with the new session once it is stored, or with what storage still holds when the sign-in gives up; sign-out and removal answer "session ended" (why: after a sign-in nothing marks the account, so "session ended" would pause its outbox for as long as the app runs).
- The manager's stop state and per-send note are sealed types with pure, table-tested decisions; a full lifecycle machine was left out.
- **Short-lived isolates never refresh** (notification actions, the widget worker): they use a valid stored access token or fail as rejected. Background runs refresh only while the answer can arrive before their deadline (why: a rotation whose answer is never stored ends the session): a token request waits at most 60 s, none starts with less than 30 s left on Android or 8 s on iOS, and the container waits up to 5 s for every session to settle.
- **No token is no outage:** a request that got no token never left the device, so it shows no offline state and counts as not sent in the outbox.

### Why a session ended

- **A restore** is tried for a user account in `needsReauth` whose end was refused with another refresh token than the stored one, or whose storage could not be read, never while storage holds the token a refresh rotated away (why: the server refuses that one too).
- **A record per account**, without secrets: cause, time, code, part of the app, the refresh most likely lost (a send is noted before it leaves and kept after a 5xx, as the server may have rotated before failing) and what became of the session, judged at the next sign-in; a session the server still lists is an orphan and revoked. Written only for registered accounts and forgotten at sign-out (why: account ids repeat). Tokens appear only as SHA-256 prefixes, which [Diagnostics](#diagnostics) never prints. The reauth banner and the Account tab tell when and why.

Limits:
- An answer lost on the network after the server rotated still ends the session; only a short server-side grace period for the previous refresh token would prevent it (an upstream proposal).
- On iOS a session ends when the app is neither opened nor woken for 72 h, as the OS may run the background job rarely or never; on Android a force stop drops the job and the reminder until the next start. The reminder assumes the default `jwtttl`.
- A key lost for good keeps the account failing for up to a day of app starts. The plugin's lost-key detection was read from its source only: a passing Keystore failure that lasts to a sign-in's third write wipes every account's tokens. On Android, after a sign-in repaired the key, the open app keeps the plugin's reset until it is closed, as the plugin keeps the options its storage was first opened with: a token it cannot decrypt, which in practice only a background run still holding the old key can write, is deleted as if missing, so a user account is asked to sign in again at once instead of being retried for a day. No later start could decrypt that token either.
- Retirement is per isolate: a sibling isolate can still write tokens back after a sign-out elsewhere. iOS gives a background run no stop signal, so an early expiry drops a refresh in flight unnoted.
- The Android flush plugin has not run on a device.
- A stored account list that cannot be read at start keeps the launch screen for about 38 s while the read is retried, then the app shows Connect (why: a shorter retry would show Connect after a brief failure, and a signed-in user would look signed out and might add the account again).

## Sync

### The local database
- One Drift SQLite file per account, shared by every isolate of the process through one connection (why: no account column is needed, and a switch never shows another account's rows). Never in the iOS App Group; the widget extension never opens it.
- Not encrypted (why: it holds no secrets, and an encrypted file would need its key in every background isolate); out of backups and device transfer, see [Security and privacy](#security-and-privacy).
- Schema rules: the server's ids, temporary negative ids for unsent creates, the server's `created` and `updated` on every row, dates as UTC epoch milliseconds; no foreign key on a task's project or a relation's other task (either may arrive later or be unreadable).
- The schema starts at version 1 with the first public build, and every version stays from then on: each change bumps it with a dump in `app/drift_schemas/` and a migration test. No downgrade runs.
- Sign-out and removal delete the file after the tokens and the registry entry; a wipe cut short runs again at the next start. An account that needs a sign-in keeps its data; signing straight back in is in [Accounts and sign-in](#accounts-and-sign-in).

### Runs
- One headless engine per account; runs are serialized. Automatic triggers (timer, resume, start, background runs) join a run under way; every refresh the user starts (pull, Sync now, Retry, a project or column move) and the outbox's refresh after sending wait and run their own, as does the realtime socket's (why: a joined run may have read the server before the web's change or the sender's write, and could store the old row over the answer).
- Full run: the user, all projects (archived included), labels, tasks open then done, then each archived project's tasks (why: `GET /tasks` leaves them out), then the purge.
- Keyset paging by id, never page numbers (why: those are neither resumable nor stable while data changes), following the page size the server returns (it caps `per_page` silently). A page not strictly ascending above the cursor fails the run before it is stored (why: a skipped id would be purged silently). A page is stored in slices of 500 tasks, and a full run saves its checkpoint after each (why: an admin can raise the page size past the 32,766 variables one statement takes in the SQLite the app bundles, and asking for fewer would not hold a server that ignores `per_page`).
- A v1 answer without its page count (a proxy dropped `x-pagination-total-pages`) ends a walk only at a page that brings nothing new: an empty one, or for the project and label lists one without a new id (why: the page size the server applied is unknown then too, and a walk cut short would purge everything behind it). Such a project or label walk that misses a stored one is walked once more, and only one missing from both goes (why: with no count to compare, a delete between two pages moves the next item up into a page already read, and it would go with its tasks and the unsent edits that name them).
- A checkpoint after every page; a stopped full run resumes at the next one unless it began over 24 h ago. A project that became live (new, un-archived, restored, duplicated) or was archived elsewhere clears the checkpoint (why: the stopped run may have passed its tasks while out of reach, or read the project as live and passed it in its archived phase, and would purge them).
- Purges happen only at the end, by the run's mark on the rows, so an interrupted run never deletes; rows other writes stored during the run carry its `+` mark and stay (why: a create's answer or a restore must survive). A catch-up pass from the newest `updated` − 120 s goes first (why: a task reopened and done again between the passes). A resumed run also keeps the rows a sync begun after it stored (why: it does not read again what it had passed, and that sync read them from the server since; what the server deleted meanwhile goes with the next run's count).
- A full run writes only rows that differ (why: else every list on screen reloads per page); whether a run is full is decided when it starts (why: one queued behind another would pull everything twice). User refreshes stay incremental.

### Incremental sync
- The watermark is the newest task `updated` the run itself read, never the newest in the database (why: outbox answers, restores and creates write a fresh `updated` during a run); never lowered, and ignored when over 1 h ahead of the device clock.
- Server facts: a date filter compares as if just above its second (`>=` acts like `>`), so the delta asks `updated > 'U − 1 s'`; `updated` has second precision and is bumped late for comments, attachments, relations and assignees, hence 120 s of overlap. Archived projects' tasks need their own delta.
- Projects and labels are read whole every run and diffed by value (a favorite toggle bumps no `updated`). A new, un-archived, restored or duplicated project is pulled whole (why: its tasks may be older than the watermark), and so is one archived elsewhere, itself or through a parent (why: archiving bumps no task's `updated`, and a full run that still read the project as live purged, or never stored, the tasks `GET /tasks` then left out).
- Deletes are found by counts (why: a deleted task leaves no trace): the server's total against the local count of the same scope, tasks with a queued or failed change included (why: left out, a failed edit of a task the server still has, and every unsent one, would differ on every run); on a mismatch each differing project is walked and purged. A walk that purges nothing, finds no project gone and keeps no task only because another write stored it during the run is not repeated while the totals stay, until a full resync (why: else one request per project every 60 s): no walk settles a favorite deleted in an archived project, nor a task whose edit failed because the web deleted it, which stays until its sync problem is discarded. A count the server did not report counts as a mismatch and is never remembered, so on such a server every run reads each live project whole (why: a guessed count hides deletes).
- A project whose task request answers "not found" or "forbidden" with any Vikunja code, such as 3001, 3018 from the trash or 7003 for lost access, is purged with its tasks and the run goes on, in either run, the full run's pull of archived projects included; a 404 without a code is a missing route and fails the run (why: with a code the server says the project was deleted, trashed or unshared after the run read the project list, and a full run that failed there would fail at it again on every resume; a route an older server or a proxy lacks says nothing about the project).
- A daily full resync in the app when the last is older than 24 h, missing or seemingly in the future (why: it catches position and bucket moves, which bump no `updated`, and counts equal by chance). Headless engines stay incremental.

### Background runs
- One periodic job for all accounts (why: Vikunja has no push channel): Android every 30 min with a network and a battery not low; iOS `io.vikunja.app.sync`, 30 min at the earliest. No foreground service, battery exemption, exact alarm or expedited work (why: no special Play declaration). Skipped while the app is in front.
- Deadlines 9 min on Android (WorkManager stops at 10), 25 s on iOS. A run always reports success (why: a failure adds WorkManager's backoff).
- Queues first: the widgets' Done taps, then every account's queued changes before any account syncs (why: the user's changes matter more than fresh data when the OS ends a run early); then the accounts, the longest waiting first, so none starves. A queue's drain counts as the account's attempt, and the queue of an account whose last attempt timed out or was cut short by the deadline or the OS goes in its own turn instead (why: a server that never answers would otherwise use up every iOS run before any turn).
- One sync per account across isolates through a 3-minute lease, renewed as the run goes and checked inside every write of either run that deletes projects, labels or tasks; a run whose lease is no longer its own, missing or another's even if expired, stops there and deletes nothing (why: another run may have taken it, marked rows and let go, and a stalled run's lists can be older than the server's, so it could drop a project or label that is back, with the unsent edits that point to it). The lease names the process that holds it, and one another process left is taken over at once (why: every isolate of the app runs in one process, so that process was swiped away, crashed or ended by the system, and the next start would otherwise wait up to 3 minutes for it); one without a process, from an older version, only runs out. A background run lets go of its leases before its databases close (why: the app would otherwise wait up to 3 minutes for a sync the deadline cut short). The app waits for a lease another isolate of its process holds, headless engines skip. The outbox needs no lease.
- After a background Done that could not send, Android runs a one-off drain with a network constraint, neither expedited (why: below Android 12 that needs a foreground service) nor held back by a low battery (why: it sends what the user just did). The drain then plans each account's notifications from what its answers stored, whatever its outcome (why: a repeating task its Done moved on would otherwise ring for its next occurrence only after the next periodic run or the app's start).

### Realtime
- One WebSocket for the active account while the app is in front, after its first sync; never in the background, for a guest or while a sign-in is needed.
- Only `notification.created` exists (server fact), so the socket is a hint: a task or project notification requests one debounced incremental sync, with an inbox catch-up alongside (why: events while disconnected are lost). It never replaces the timer or the inbox poll.
- Failures fall back to polling quietly (why: the upgrade shares the server's limit of 10 logins a minute per IP): backoff 2–60 s, six attempts in a row without a successful authentication (`auth.success`), connection errors included and rate-limited ones not, stop it until the next resume, even when the network comes back, as does a TLS error; an upgrade refused before any socket was live stops it until a restart.

Limits:
- Until the daily full resync the delta misses position and bucket moves; a server clock that steps back more than 119 s hides the edits in that gap.
- An automatic refresh during a run joins it, so a change made after the run read its delta comes with the next run.
- iOS may run the background job rarely or never (after a force quit, in Low Power Mode, without Background App Refresh); Doze stretches Android's runs.
- A project archived, un-archived or restored during a full run can miss tasks until the next incremental run brings them back.
- The lease's takeover assumes one process, as the outbox's claim does: an `android:process` or an iOS extension opening the database would let a second run sync the account, and the run it displaced stops without deleting at its next lease check. A lease left by an isolate that ended while its process lives on still holds the next run for up to 3 minutes.
- Comments, attachments and boards are not synced, only stored as last read ([Descriptions, comments, attachments](#descriptions-comments-attachments), [Projects](#projects)).

## Outbox

### Queueing
- Local-first: a task write changes the local row and queues the server call in one transaction; it never fails for network reasons and shows at once (why: the lists work offline, and notification actions and widgets need the same queue). A confirmation or Undo comes only once the change is stored (why: a message claiming a change the device does not hold is worse than none).
- No 3-way merge: the server offers no precondition (it ignores `If-Match`), and v2 merges per field itself. Last write wins per field; the description is the exception ([Descriptions, comments, attachments](#descriptions-comments-attachments)).
- v2 sends a merge-patch of only the set fields (a cleared date as `0001-01-01T00:00:00Z`, never an unknown key, which is a 422). v1's update replaces the whole task, so v1 emulates the patch: read, overlay, write back with assignees and reminders as read and never labels.
- Coalescing: an update merges into the task's newest pending one, and an op that fails for good folds into a newer op of the task, so no two ops of a task can go out in either order and a Retry never overwrites a newer edit. Updates that may have reached the server are not folded (why: the next attempt may leave out the body it once sent).
- Deletes are queued on every server and can be taken back while queued. The sync never purges a row with a queued op and overlays pending changes on what it reads ([Sync](#sync)).

### Sending
- One serial sender per account: one op at a time, oldest first, each claimed `sending` in a transaction so only one isolate sends it; the oldest op blocks the queue during its backoff. A claim older than 5 min, or one left by another process, is taken back. The sender lives as long as the account's database: a changed server or API version rebuilds the account's clients and sync engine, not the sender, which takes the current ones for each request, so it stores the answer to the change on its way and the queue goes on at once (why: a sender rebuilt with them left that answer unstored, held the queue for 5 minutes and then sent the change again, a new task twice). A request the replaced client refused goes again at once over the new one, nothing counted.
- After sending, the sender asks for a sync run that starts after the sends (why: server-computed fields arrive, and a run that read before the write cannot store the old row over the answer).
- A repeating task's Done is applied once (why: the server moves its dates and reminders on every Done it gets): a later attempt reads the task first and counts the Done as landed when `done_at` and the dates moved, and a Done whose occurrence the server has passed (done on the web) is not sent.
- Retry classes:
  - waits, never counted: network failure, rate limit, lost refresh race, a rejected token, a 2xx that is not JSON (why: about the network or the session; a captive portal's page is told by its body, as v2 answers the data export with `null` as `text/plain`);
  - counted: a 5xx, a 404 without a Vikunja code, a 3xx, a 401 without a Vikunja code or a 407 (why: an access gate in front of the server refuses so, for example after its access header expired or was rotated, and the queue goes out if the header is fixed in time; the count bounds Vikunja's own rare codeless 401), and for a create or upload an unreadable answer; the 16th in a row fails the op (why: about 107 min, which rides out a server restart), an upload's 4th (why: each attempt sends the whole file again);
  - final at once: everything else (why: a retry would only repeat it).
  Backoff is jittered exponential from 2 s to 15 min; a `Retry-After` wins, capped the same.
- An ended session pauses the sender until the next sign-in, so a session's end never loses an edit; the only loss is the wipe at sign-out or removal, whose dialog counts the queued changes.
- Sync problems are listed on the Account tab with Retry and Discard. Discard reads the task from the server first, and a failed read changes nothing (why: an edit is never lost offline).

### Creates
- A create stores the row under a negative id, never reused (why: the server assigns ids and has no idempotency key); nothing is sent under it before the create is through. On success the row and its queued ops move to the server id in one transaction, recorded for good in `task_id_remaps`.
- Edits fold into a create that has not left the device; once it may be on the server, edits and deletes queue behind it.
- A create sends a date only when set (the server stores the zero date for an omitted one) and the project only in the path (a v1 body's `project_id` would override it); labels, assignees and placements follow as an update.
- Lost answer: the next attempt first looks among the project's tasks created from an hour before the first send whose answer was lost to an hour after the create's request last left the device, on the device's clock and on the server's by the offset the session learned last (why: a device clock that is wrong, or was changed since, would miss the task), for the newest one with the sent title, created by this user and not adopted yet, and sends again only if none is found (why: a blind resend makes a duplicate). An attempt that only looks, such as one offline, moves neither end, and a Retry days later looks no further (why: a task of that title made on the web meanwhile is not the lost request's, and the Done or delete queued behind the create would follow it there). Labels and uploads look the same way. A lookup the server refuses keeps the mark, so Retry looks again (why: the create may be on the server). Another member's task is never adopted (why: the queued ops would follow it there).

### Sets, relations, positions, labels
- Labels and assignees change as id deltas inside the update: the sender sends the body, reads the task and sends only the label and assignee requests that differ (why: the bulk endpoints and the v1 body replace the whole set, dropping what the web added meanwhile). Answers saying the change is there already (8001, 4021, a 403 for a label no longer attached) count as done.
- Reminders go as the task's whole list ([Tasks](#tasks) for equal instants).
- The cover is a field of the update, set and cleared offline too, and the task's stored details show it at once (why: v1 writes the whole task back, so a cover sent beside an edit on its way put one of them back). A cover whose attachment the server no longer has is left out of the update, and one the server still names after its attachment was deleted is cleared with the next update (why: the server refuses every update of such a task).
- Relations ride the update as edge deltas with the same diff. The server keeps the inverse edge but bumps `updated` only on the task the request named, so the app writes the inverse rows locally.
- Kanban placements and manual list positions are fields of the update (why: they ride the queue's ordering, failures and sync problems). A later project move drops those queued before it. A later change of the done state drops the placements queued before it only on views with a done column, where the move, sent after the body, would set the done state back; on other views an unsent card move or a new task's column stays. A view not stored on the device counts as one with a done column, and the sender leaves out a placement that would undo the done change on a view that has got a done column since (why: one may have been chosen on the web). The bucket move goes before the position (why: neither bumps `updated`, and a move keeps the old position). A new task is placed by a placement, never `bucket_id` on the create (why: that applies to one view and would change the lost-answer match).
- Labels are created offline too: under a negative id with a queued create that an update naming the label waits for. A lost answer adopts only this user's label of exactly that title made around the attempt; deleting a label whose create has not left cancels it without a request.
- Uploads go through a lane of their own beside the queue (why: a large file would hold every edit back for minutes), one file per request (why: per-file errors carry no name), with timeouts of one to four minutes by size; a lost answer is matched by name, size and uploader. Background runs leave uploads alone.

### What stays online
Applied at once on success, nothing queued, a message offline:
- Kanban columns, projects and views ([Projects](#projects) says why).
- Duplicating a task (why: the server copies its own state, and a lost answer could not be told apart), after draining the task's queued ops.
- Comments and reactions (why: the server orders the thread and gives a comment its id; the kept draft loses nothing).
- Following a task or project. Unfollowing one that a followed project covers stores an opt-out from Vikunja 2.6.0 on; older servers refuse it, so there such a follow shows as fixed, with a note naming the project to unfollow.
- Changes to labels the server has, attachment deletes, teams (never stored: membership changes bump neither `updated` nor the ETag) and shares. Deleting the cover's attachment clears the cover through the queue and sends the task's queued cover change first, and is refused while that cannot go (why: the server would keep naming the deleted attachment and refuse every later edit of the task).

Limits:
- Writes are at least once: an op whose answer could not be applied locally is sent again. A failed op that may have reached the server, retried after a newer edit, can overwrite that edit's fields when its own body never arrived.
- The requests of one update are not atomic; Retry sends only what is missing. An edge or label naming a waiting create holds the task's later edits back.
- The lost-answer lookup can adopt the user's own task or label of that title, or file of that name and size, made elsewhere between an hour before the first request whose answer was lost and an hour after the last request.
- A done column chosen on the web after a card move was queued on that board is known only after a sync; a Done sent before then is undone by the move.
- A 5xx outage over one to two hours turns the queued ops into sync problems one after another ("Try all again" resends them); a proxy answering everything with a 2xx page holds the queue as if offline.
- The claim rule assumes one process: an `android:process` or an iOS extension opening the database would send an op twice.

## Tasks

### Lists and search

- **Lists come from the local database through the device's filter engine,** so a change shows at once, offline too. Positions come from per-view snapshots that a list downloads when it opens (older than 5 min) or on pull, never in the sync (why: positions are per view and never bump `updated`).
- **The subtask tree follows the web's of 2.8.0 on every server**: rows at depths 0 to 5, a task expanded only where it first appears.
- **Show done,** an app addition, shows a `done = false` view's done tasks in a Done part, per view and off by default.
- **Upcoming pins every overdue open task in an Overdue part,** on by default (why: what is late shows at a glance; the web drops the lower bound). A custom range of days starts at its first day's midnight, where the presets keep the web's exclusive bounds (why: a task due at 00:00 of the first chosen day belongs to it).
- **A saved filter's own list shows the done tasks it matches** unless its text says `done = false`, as on the web (why: the web writes "Show done tasks" into the filter text). It shows at most the 100 most recently done (why: a filter can match a whole history, and loading it on every change makes the list stutter).
- **The filter engine** (`vikunja_logic`) implements the server's grammar, translated from the server's fexpr reader (BSD 3-Clause) and go-datemath (ISC), with notices in `packages/vikunja_logic/THIRD_PARTY_NOTICES.md`.
  - Filters the server answers with a 500 are refused with 4019. A filter the engine refuses, or one naming `bucket_id`, falls back to the server's list, with a notice.
  - A date equal to a bound matches as written, where the server on SQLite is off by one.
  - It uses the user's timezone setting, else the device's zone (the server stores none for a filter).
- **The filter builder is a text field in the web's syntax** with suggestions (why: it keeps every filter the web can write).
- **Search ignores case and accents on every server**, in the global search and every field that filters on the device. `like` filters and stored searches are not folded, as the server applies them (why: the device would otherwise find tasks the server does not).
- **Text comparison is documented, not matched:** the device compares as SQLite does. The server leaves this to its database, which no answer names, so on PostgreSQL or MySQL a text filter can match differently; matching another database would be wrong on SQLite servers, the default.

### Opening a task

- **One opener serves every task tap and link.** It waits for start-up and the app lock, and lets what covers its target go as if the user went back: the dialogs and sheets always, the pages over the shell where it has to leave them. What asks on Back (the New task sheet with typed text, an edit page) asks first, the rest goes as Back would close it, and one that stays, or is still saving, drops the opening, together with the openings that came during its question. It **asks before a link switches accounts** (why: anyone can make a link). No link is logged.
- No App Links or Universal Links (why: self-hosted domains cannot be verified).
- **No task identifier is shown or spoken anywhere**, also in the task detail. Deep links, search by `#12` or `PROJ-12`, `+project` and filters still use identifiers.

### Editing

- **Due date, priority, reminders and labels change in place** in the task detail, each through the outbox, offline too. The other fields stay on the edit page.
- **Editing needs** write permission, a project that is not archived, and a task row on this device (why: a change for a task without one would be dropped).
- **Copy link and Share work for every task the server knows.** The link is `{web frontend}tasks/{id}`, never http for an https server, and goes to the plain clipboard (why: it carries no secret, and only members can open it).
- **The server keeps one reminder per moment,** so the editor never adds an equal one, and a due date that would put two reminders on one moment asks first (why: one would be lost unasked).
- **Dates and reminders set on the device are stored in whole seconds,** as the server keeps them (why: a finer instant reads as moved once the server's copy syncs, and its reminder is withdrawn or ignored).
- **Date rules follow the web:**
  - A day without a time takes `default_due_time` from the web's `frontend_settings`, else the next of 9, 12, 15, 18 and 21 o'clock. The default relation kind comes from there too.
  - A default time today that has already passed becomes 23:59, and Today stays among the shortcuts after 21:00 ([QA-8](#quick-add)).
  - Repeats over the server's 10 years are refused.
- **Undo after Done** in the detail is handed to the sheet below when the detail closes (why: in a list of open tasks the row has already left).
- **Reopening a task whose Undo is still up is that Undo,** in a list and in the detail (why: a bare not-done after a Done already sent leaves a repeating task on its next occurrence). An Undo puts back the dates and reminders the server moved, but none while the Done has not left the device and none a queued edit made since (why: what the user set last stands).
- **Leaving the New task sheet** with a title or description typed asks "Discard the new task?" on every way out, also before a notification, widget, link or share opens something in the active account; Keep editing keeps the sheet and its text and drops that opening (why: an opening from outside comes unasked, and what was typed would be gone without a word).

### Swipes and selection

- **They follow the common practice of task apps, not a design of the app's own**: a swipe toward the end marks done or not done, with Undo, one toward the start opens the due-date choices; selecting starts by a long press or Select, with the actions in a bottom bar.
- **There is no delete by swipe** (why: a swipe is easy to make by mistake).
- In a list sorted by hand, a long press held still selects and one followed by a drag moves the row.
- **On Android, Back ends a selection first,** also on the first tab (why: with predictive back, Android closed the app there). On iOS the edge swipe goes back and ends the selection (why: holding Back would turn the swipe off).
- **Each action writes one queued change per task,** with Undo, never through the server's bulk endpoints (why: they replace whole sets).
- **Reschedule** on the Overdue heading gives every overdue task the user may change a new due date, as the selection's Due date does.

### The trash (Vikunja 2.8.0)

- **The trash needs API v2 and 2.8.0 or newer.** The server's behavior is in [research/trash.md](research/trash.md): `/api/v2` routes only, no flag in `/info`, 30 days.
- **Delete confirmations stay, with trash wording**, although the 2.8.0 web dropped the task's. They promise the trash only when the task is surely on the server.
- **Undo is offered only on servers with the trash**, for 10 s (why: elsewhere a delete cannot be taken back once sent). Deletes are queued on every server; Undo takes a delete out of the queue, or restores it from the trash once it was sent. The task's files that had not reached the server when it made the delete (waiting, backing off, on their way or failed) are set aside with their copies for as long as the Undo is offered (10 s, or until it is closed under a screen reader, which keeps it up), and an Undo that restores the task queues them again as they were, to upload once it is back; after that, or at the next start, they are dropped as before (why: an Undo that brought the task back without them would lose them unseen).
- **The trash page** (closed to guests) is online only.
- "In the trash" appears only where the user acts on the trashed thing; elsewhere the text says "no longer exists".

Limits:
- The tree cannot be collapsed. Tasks more than five levels deep are missing from the List view, as on the web.
- Upcoming uses the phone's zone, which can differ from the account's timezone setting.
- The accent fold covers Latin letters only.
- Not built: the server's full-text search, searching comments and attachments, and selecting on a board, in the timeline or in search.
- The trash lists stop after 200 pages (10,000 items), and only the diagnostics log says so.

## Projects

- **The Projects tab** lists Favorites, All projects (the tree) and Saved filters. Archived projects, and those below an archived one (servers before 2.6 let a subproject be unarchived while its parent stays archived), stay out of pickers, defaults, quick add, the share sheet and the widgets' Add, and their tasks are read-only.
- **A project opens on the view it was last left in**, saved per account. A view named in the route, such as a guest's link, wins and is not saved.

### The stored permission

- **`projects.max_permission`** (0 read, 1 write, 2 admin) comes from `expand=permissions` on the sync's project list (why: no request is added). It is compared on every sync, as a permission change alone does not move `updated`. Null means unknown: the app offers the change and words the refusal. A guest's permission comes from reading the shared project, never from the token's claim.
- **It shapes every screen by the server's rules:** write for editing a project and its tasks, manual order and board moves; admin for Views, Delete, the done and default column and changing a project's parent; read for Duplicate. Read-only projects are left out of every project picker and of `+project`.

### Projects and views

- **Managed online and applied locally at once** (why: temporary project ids would have to flow into tasks, views, columns and the outbox, and deletes and duplicates need the server's answer). Offline or on a refusal nothing changes.
- **A view or saved filter edit sends only the fields the user changed** (why: a change made elsewhere since the last sync stays, another admin's or the user's own on the web or another device). A saved filter's filter goes only with its changed keys, merged into the server's, so its search and sort stay; the form never sends the description, and reads the saved filter from the server first when its stored definition is missing or older than the listed one.
- **The user's default project** cannot be archived or deleted.
- **Delete counts every task it would delete,** subprojects included (why: the web's count of direct children understates a recursive delete).
- **An identifier change rewrites the stored task identifiers** (why: the server changes them without bumping the tasks' `updated`).

### Kanban

- **Boards come from per-view snapshots,** downloaded when a board opens (older than 5 min) or on pull, never in the sync (why: a request per view and run, for data that matters only while the board is open).
- **Card moves and a new task's column go through the outbox** ([Outbox](#outbox)). A drop into the done bucket marks the task done; a repeating task is only marked done and goes to the default bucket.
- **Cards without a place on the board yet** show on top at positions made up below the first placed card; a card dropped in their column, moved to it or added on its top also queues the positions shown for those of them the server holds there for sure (an unsent create, moved here or placed there), lowest first and before its own, never one below 0.01 (why: without a position they sort by the server's rules, and placing a card the server may hold in another column would move it).
- **Downloads of one view run one after another,** and one that read the server before a sent move keeps that move's place for its task; a download of a view whose kind changed meanwhile stores nothing, and a view that turns into a board or stops being one drops its downloads, the board's columns included (why: an older read would otherwise put the card or row back, or the new kind would count as downloaded).
- **An empty column's first card gets position 65536** (why: 0 makes the server recalculate the whole view).
- **Columns are managed online** (why: they need server ids, change where queued moves land, and are rare). A column update always sends title, limit and position, those it does not change as a read of the server's columns right before has them (why: the server replaces all three, so a missing one becomes 0, and the stored board may be minutes old). A move goes past the column the user saw it pass, in the server's order. Columns move by Move left and Move right, never by drag (why: on a phone that competes with dragging cards).
- **A guard keeps tasks from being orphaned** (why: deleting the column that tasks fall back to leaves them in no column). Before deleting that column while it holds tasks, the app makes the leftmost remaining column the default, and it puts the old default back if the delete fails.
  - Servers before 2.5 store a deleted done or default column as if it existed. There the app checks the board first and clears such a column, as 2.5 and later do.
  - Below admin, Delete is disabled for the leftmost column while it holds tasks and no other column is the default (why: the guard needs a new default, which the server refuses below admin). This is the one place where a write member or guest gets less than on the web.

### Manual order

- **Lists sorted "Manually" are reordered through the outbox,** with the position as its own field of the task update (why: positions do not bump `updated`, and a field of their own avoids the board's column rules).
- **Projects are reordered and nested online.** Without admin, a project moves only among its siblings.
- **No position below 0.1** (why: below 0.1 the server renumbers every sibling, for top-level projects those of every user on the instance). Such a move is refused, at the top of a level, where the user may move the first project, with a message that moving it down makes room, also for a screen reader's Move up (the app never moves that project itself: it would be a second online write); a stored project below 0.1 is lifted to at least 0.1 with its next update.

### Table and Gantt

- **Both read the local list,** so they work offline and cost no request.
- **The Table keeps its columns under the web's keys** (why: the web keeps one choice for every table). It has no task number column.
- **Gantt is a read-only timeline** ([Identity and scope](#identity-and-scope)); dates change on the edit page. It copies the web's range filter where it decides which tasks show, not the web's drawing mistakes.

### Labels, teams and sharing

- **Labels, Teams and the Trash** open from the Account tab's Organize section, never for guests.
- **Labels are managed online;** new labels can also be created offline ([Outbox](#outbox)).
  - On v1 a change is sent on a fresh read of the label (why: another client's color or description survives).
  - Only the creator's labels offer Edit and Delete (why: lists carry no permission).
- **Teams are online only and never stored** (why: membership changes bump neither `updated` nor the ETag). The app adds guards the server lacks:
  - Nobody demotes or removes themselves.
  - The only admin of a team with other members must make someone else admin first.
  - Make admin and Make member send the server's toggle only while a fresh read shows that the role still differs (why: the server only toggles, so a stale page would demote).
- **Sharing is offered** for every project that is not archived, never to guests. Shares are Read only by default, and link shares are for admins only.
- **A share's hash appears only** in the link on screen, its QR code, the share sheet and the sensitive clipboard. Its password appears only in its field and the create request. Neither is logged, put in a route or stored. Screenshots are not blocked there (why: the link is meant to be shared).

Limits:
- On Vikunja 2.8.0 moving a project under a new parent also needs admin on that parent, while the app checks write; the refusal shows as a message.
- Moving a card within its column, a task in a manual list or a project among its siblings takes a drag or a screen reader's actions ([Accessibility](#accessibility)).
- Not built: managing projects, views or columns offline; Kanban views of saved filters; ordering favorites. Backgrounds and webhooks stay on the web.
- An assignee removed by the server's access cleanup stays on the device until the daily full resync (why: the removal bumps no `updated`).
- A team whose create answer is lost can still be created twice.

## Quick add

- Quick Add Magic keeps the web's grammar ([research/client-logic.md](research/client-logic.md) §1.2–§1.8): the prefix modes (`vikunja`: `*` label, `+` project, `!` priority, `@` assignee; `todoist`: `@`, `#`, `!`, `+`; `disabled`), quoted items, priorities 0–5, repeats and dates with `at`/`@`. The maintainer chose the web's grammar with its parser bugs fixed, first QA-1, QA-2, QA-3 and QA-5; the deviations below are marked `QA-n` in the code and tests, and the bugs the web has too are proposed upstream.
- The parser in the pure package `vikunja_logic` re-expresses the web's behavior without its code (why: the web frontend is AGPL, [Identity and scope](#identity-and-scope)); the web's test vectors are ported.
- English keywords only (why: the web has none translated, and mixed languages would be ambiguous), kept by the maintainer: a German date word without a parsed date, or a time after a date without `at`, gets a hint under the title, and the help says date words are English.
- One tokenizer: `quickAddTokens` splits prefixed items exactly as the web's `getItemsFromPrefix`, for the parser, the composer and the service alike (why: highlighting and chips then follow the parser in the edge cases).

### Deviations from the web
- **QA-1 Repeats in months and years.** Web: `every N months` (N ≠ 1), `every year`, `yearly`, `biannually` give no repeat. App: N months is N × 30 days, `every month`/`monthly` the monthly mode, N years, `yearly`, `annually` N × 365 days, `biannually`/`semiannually` 180, `biennially` 730. Why: the user asked for a repeat and silently got none.
- **QA-2 Keywords in any case.** Web: `Daily` and `Every Day` repeat hourly. App: as lower case. Why: lines often start with a capital.
- **QA-3 Date keywords end at a word boundary.** Web: `todays`, `next weekend` parse as `today`, `next week`. App: they stay text. Why: a word that only starts with a keyword is no date.
- **QA-4 An apostrophe and a letter end no keyword.** Web: `Fix today's build today` gives `Fix 's build`. App: `today's`, `may's` stay text; a closing quote (`today'`) still ends one. Why: the web cuts text out of a word.
- **QA-5 Day and month as whole words.** Web: `12 decorations` is 12 December. App: text; `12 dec` parses. Why: as QA-3.
- **QA-6 Whole words elsewhere.** Web: `in …` matches inside words (`within 2 days`) and needs a space or the end after the unit; phrases and month words are cut out of longer words (`fri frisbee` gives `sbee`); `dec 45` is dropped. App: `in …` needs a space or the line start before it and takes digits, `a`/`an` and one to twelve, repeats eleven and twelve too, Vikunja 2.8.0's phrases; a word boundary ends the unit, so `in 2 days,` is a date, and a weekday or repeat word followed by QA-19's punctuation other than quote marks counts too, so `Call Bob friday.` and `Water plants daily.` set theirs, though only where no other date or repeat was found (`Dinner Fri, Dec 17` is 17 December), while `mon-fri` stays text; an apostrophe keeps it text (`in a day's work`) as on the web; phrases go only as whole words; `dec 45`, amounts over 100000 and `in …` dates past the year 9999 stay text. Why: typed text must not be eaten.
- **QA-7 The default time, not the clock time of now.** Web: weekday and ordinal dates keep the clock time of typing. App: a date without a time takes `default_due_time` (two-digit `HH:MM`, as the web reads it), else the next of 9, 12, 15, 18, 21 o'clock, also for a dateless repeat; `tonight` is 21:00, and an hour from 1 to 11 without am or pm with it is in the evening (`tonight at 8` is 20:00); `at …` wins; `in N …` still adds to now, in whole seconds. Why: a time taken from the moment of typing is arbitrary; the date shortcuts use the same rule.
- **QA-8 A passed default time on today becomes 23:59**. Web: keeps the passed time, so the task is overdue at once. App: 23:59 of today, in quick add, the pickers' date-only pick, the date shortcuts (Today stays offered after 21:00, which the web hides, as Reschedule needs it most in the evening), Reschedule and a canceled clock; a typed or picked time stays, other days keep the default time. Why: a task set for today should not start overdue.
- **QA-9 Calendar dates.** Web: today's date moves to next year, absolute dates get 00:00, `Release 1.2` is 1 February. App: today's date is today, absolute dates take the default time, and a number after `v`, `version`, `release`, `build`, `update`, `patch`, `rc`, `beta` or `alpha` without a year is no date, also with a final dot (`Release 2.`). Why: such numbers are common in titles.
- **QA-10 An ordinal joins only the month beside it.** Web: takes a month word from anywhere and keeps passed dates. App: `5th may`, `may 5th`, today or ahead, else next year. Why: a past due date is never meant.
- **QA-11 A day the month never has is no date.** Web: `apr 31` rolls over to 1 May. App: no date; `29 February` without a year is the next leap year's. Why: a typo must not move the task to another day.
- **QA-12 `next <weekday>` on that weekday.** Web: today. App: quick add goes a week ahead, a bare weekday that is today is today; the date shortcuts' day interval keeps the web's rule. Why: "next Monday" said on a Monday means the coming one.
- **QA-13 German short dates**. Web: its `D.M` pattern takes no final dot, so `17.12.` is no date. App: `17.12.` and `17.12.2026.` are dates; a lone `am` right before one goes with it, unless it is a time's suffix (`at 9 am 17.12.`); Kapitel, Abschnitt, Seite, Folie, Teil and Nr. join QA-9's words, so `Kapitel 3.2` stays text. Why: German users write dates so, while keywords stay English.
- **QA-14 A time is a clock time.** Web: `Meet at 221B Baker street` gives `Meet1B Baker street` at 22:00. App: after `at`/`@` the number must end there and be 0–23, or 1–12 with am/pm, with two-digit minutes; else it stays text, and a later valid time still counts. Why: the web eats text and invents a time.
- **QA-15 An unmatched `+project` stays in the title.** Web: drops it and silently uses another project. App: it stays; archived and read-only projects are not matched. Why: a typo must not file the task elsewhere unseen.
- **QA-16 Whole tokens.** Web: removing `*bug` cuts into `*bugfix`, and a doubled prefix leaves one behind (`**bike`). App: labels, projects and priorities leave the title only as whole tokens with every repeated prefix. Why: as QA-4.
- **QA-17 A priority is a whole number from 0 to 5.** Web: `parseInt`, so `!2fa` is 2. App: `!2fa` is none, `!03` is 3. Why: `!2fa` is text.
- **QA-18 Lines that are only magic never get labels created.** Web: a multi-line add creates them. App: none. Why: such a line keeps its raw title, so its labels are text.
- **QA-19 No space before punctuation**. Web: `Call back tomorrow.` gives `Call back .`. App: a date or time removed before `.,;:!?…)]}"”»` takes the spaces before it (`Call back.`), and a date or repeat that starts the line takes the punctuation and spaces after it (`Mon: standup` gives `standup`); typed spaces stay. Why: the title reads as typed.
- **QA-20 A date before tokens at the line's end**. Web: a day number (`5th`, `17.`) or a numeric date counts only at the very end of the line, so `Pay rent 5th *bills` and `Arzt 17.12. @anna` get no date. App: where the web's rule finds no date, labels, projects, priorities, assignees and typed spaces after a day number, and assignees and typed spaces after a numeric date, count as the end, and assignees between a date and its `at` time or month are passed over, in both prefix modes; an unmatched `+project` left in the title (QA-15) still keeps the date as text. Why: the user typed a date and silently got none.

The rest follows the web: a magic-only line keeps its raw title; a text quoted whole is literal; assignees stay in the title until resolved; a dateless repeat is due today; default reminders need a due date; a numeric date range (`31.12.2026 - 01.01.2027`) stays in the title and gives no date.

### Planning and adding
- Planning needs no request and feeds both preview and add. Projects match by title ignoring case, else identifier, the exact one before one equal ignoring case, as Vikunja 2.3 keeps the case; identifiers match among all projects first, so a read-only or archived project's identifier is reported, never its case twin taken. Without a date or `!n` in the line, the sheet's date and priority apply; the sheet sets a priority in every mode.
- Each line becomes a create with its label and assignee update behind it, through the outbox in input order ([Outbox](#outbox)); indented lines become subtasks by the web's rules, in the parent's project.
- Names are looked up on the server, resolved ones too (why: a known person may lack access to the project); a search the server did not answer keeps the plan, asked once per Add: no connection, an ended session, a rejected token, a rate limit, a server error, a redirect, an unreadable answer or a 401, 404 or 407 without Vikunja's error code, the failures the outbox waits for or retries; any other refusal, a codeless 403 included, is the server's answer.
- Missing labels are created once across all lines, offline too, taking the server's label of that title ignoring case first; one that cannot be (over 250 code points, or a guest's) stays at the end of the title.
- Titles over 1000 code points are cut at the last space, the rest starting the description; reminders stop at 100 ([Servers](#servers)). Lines not created after a failure stay in the composer.
- The project: the matched `+project`, the screen's, `default_project_id`, the one titled Inbox, the tree's first, each only among projects the user may add to. Mode, default reminders and default project come from `GET /user`, an odd or missing field taking the web's default.

### The composer
- The New task sheet's title field highlights by color and weight, never color alone; previews as removable chips what the text sets, the sheet's own date and priority being their rows' selected chips and a date only a typed repeat gives keeping its chip; suggests labels, writable projects and people, ignoring case and accents. A tap writes a token that reads back as exactly that label or project, in the quote its title lacks where needed; a project that cannot be written so goes by its identifier, and without a usable one is not suggested; the people come from the project of the line being typed, a subtask's from its parent's, as Add plans it.
- A `?` help button unless the mode is `disabled`, and no `* + @ !` prefix toolbar.
- Pasted lines become several tasks without their common indent and list markers.

Limits:
- A label not created stays at the end of the title, not where typed (why: labels are created at Add, after the title was worked out).
- A label whose title holds a space before the label prefix, or both kinds of quote together with a space or a leading quote, cannot be written as a token, so it is not suggested; the sheet's label picker still takes it.
- A name resolved later, or a quoted label or project, can still leave a space before punctuation, as on the web.
- The range rule follows the web's example, not its code (an em dash and `to` are no range); a dotted date mid-title without `at` after it (`Am 17.12. Zahnarzt`) is no date, as the web's boundary rule stays apart from QA-20.
- A typed repeat over the server's 10 years is accepted and becomes a sync problem.

## Descriptions, comments, attachments

The server stores the HTML of descriptions, comments and titles unsanitized, so the app is the only defense: it treats the server's rich text and files as hostile input.

### Rich text

- **The app has its own parser and a native renderer** (why: the HTML widget packages applied inline styles, loaded images without the token or made `javascript:` links tappable). Only the web editor's schema and allowed links come out, and reading uses no WebView.
- **Parsing and drawing stay within budgets.** Parsing has work budgets (why: package:html has paths whose time grows with the square of the input, tens of seconds for under 1 MB). Each text draws at most 5,000 blocks, list items, table rows and cells, links, mentions and task links and 100,000 characters (why: the app draws a description or comment all at once, and tens of thousands of short paragraphs, well within the parsing budgets, froze the task sheet). A document past a budget is cut and ends in `…`; the pinned package:html is in [Stack and structure](#stack-and-structure). The plain text behind search, the inbox, notifications and the edit pages comes from a linear scan instead and is never cut (why: its regular expressions took minutes on a long run of `<` or spaces).
- **A link that may mislead asks before it opens:** its text begins with a web address on another host, holds a bidirectional control character, or has user info (why: a text that reads like one address could open another). Other schemes go through the external opener's allowlist.
- **Images** above 25 MB or 40 megapixels are refused before decoding. External images load only on a tap, which opens the browser, and SVG is never decoded.
- **Attachment images load by themselves at most 10 per text, 3 at a time across the app** (why: anyone who can write in the project can name any number of the server's files in one description or comment, and each is fetched with the user's session); the others show Load image. Where the server has no preview of a file, its original loads by itself only when the task's attachment list names it as an image of at most 8 MiB (why: an original can be 25 MB); otherwise it waits for a tap, and in the editor keeps its placeholder. A file the list names as something other than an image is never asked for. A file that is no image, sent by a server before 2.7.1 in place of a preview, counts as no preview and is not read, other than a web page (why: 2.7.1 answers so, and one rule then holds on every server).

### The editor

- **TipTap in a WebView edits; native widgets render** (why: descriptions are HTML written by the web's TipTap, and Markdown editing would be lossy and is impossible on v1 servers).
- **The app bundles the web's TipTap packages itself** with its own configuration (why: the web frontend's code is AGPL, which the MIT-licensed app cannot take in). The web's outputs come out byte for byte, and `tool/build_editor.sh --check` fails in CI on any difference.
- **The page is locked down:** a content security policy allows no network, so no token reaches the page; every navigation is refused; messages carry a per-load token both ways (why: the JavaScript channel has no origin or frame check, [threat model](threat-model.md) R30).
- **Attachment images reach the editor as `data:` URLs** that the app loads (why: the page has no session and no network): like the task sheet, the text's first 10 by themselves, and those uploaded on the page, at most 16 MiB per page load.
- **Save is explicit** (why: it fits the app's edit pages and avoids writes while typing offline).
- **Drafts** are written while the user types and at once when the app goes to the background (why: when the WebView's renderer goes, Android ends the whole app). They are kept per account and description, the 20 most recently saved, out of backups, and discarded at sign-out; their writes are serialized app-wide (why: every editor and the sign-out change the same list, and no write may lose another). "Restore unsaved changes?" is answered only by Discard or Restore (why: a tap beside it or Back would discard a draft the user never saw).
- **No silent overwrite** (why: a tick on the phone must not erase a paragraph written on the web). A queued description change is checked against the server's text before it is sent. If that text changed meanwhile, queued checklist ticks alone are applied to it again, and an edit becomes a sync problem with Compare versions, Keep my version and Use the web version.
- **Checklist items are ticked in place,** one at a time, through the outbox, offline too.

### Comments

- **Comments are written online, and the composer's draft is kept** (why: the server orders the thread and gives each comment its id, and a kept draft loses nothing).
- **The app sends the web's HTML byte for byte.** A reply's quote is rebuilt from what the editor schema keeps (why: a quoted comment's hostile markup is not posted again).
- **Reactions are not synced** (why: they never bump `updated`).
- **The unread dot clears only once the server took the mark.**

### Attachments

- **Uploads go through the outbox in a lane of their own** (why: a large file would hold every edit back for minutes), one file per request, at most 50 MiB or the server's `max_file_size`. They give up sooner than other changes (why: each try sends the whole file again, often over mobile data). The details are in [Outbox](#outbox).
- **Photo and video locations are removed before queueing**, on iOS and Android, also from files shared to the app on Android. Pictures picked as files lose their location too. Both platforms find a position in metadata by its name, in any XMP namespace (a drone's `drone-dji:GpsLatitude`, IPTC's `Iptc4xmpExt:GPSLatitude`); iOS takes IPTC's location structures out whole, their place names with them.
- **"Upload with location?"**: a file whose location could not be removed goes up only when the user chooses Upload. Skip is the default and deletes the copy.
- **Downloads** send the token only to the account's own server, and a downloaded file is handed on only at the attachment's listed size, when the list gives one; a broken-off download resumes only when the bytes just before its end, read again, match (why: a captive portal's or a proxy's page answered in the file's place would otherwise be opened, shared or saved under the attachment's name).
- **Share to Vikunja on Android** uses a pass-through activity of the app's own (why: the share plugins use names the sending app chooses and read `file://` paths). It reads only another app's `content://` files, and refuses a file whose provider cannot be looked up (why: that provider could be the app's own). iOS: [Identity and scope](#identity-and-scope). A sending app gets time limits: 10 s per file to describe them, 5 min to open one and 30 s without a byte, at most 8 calls at once, each on a thread of its own, and an answer for a share that a newer one replaced is dropped; then the file's row says it couldn't be read, while Cancel or removing the row calls the copy off at once (why: any app can share to the app, and a provider that never answers would hold every later share).
- **Open on Android hands on the type of the file's name**, not the server's, and a web page, XML or SVG file, by its name, or by the server's type when the name has no known type, is offered for saving or sharing instead of opening; attachment names show as the file on the device is named, without control and direction characters (why: the server types an upload by its content, which the uploader controls, and a browser would run such a file; a right-to-left override can make `x.html` read as a PDF).

### Offline

- **The task details last read are stored** and shown when a read fails for a reason that may pass (why: a boarding pass behind an airport's login portal still shows). Offline, the sheet says "Offline — showing saved data".
- **Images are kept on disk** per account, at most 100 MB, out of backups.

Limits:
- A document past a budget shows only its beginning, and its later checklist items cannot be ticked.
- Before 2.7.1, an image a server cannot preview, such as WebP or HEIC, still comes whole in place of its preview, up to 25 MB, within the 10 per text.
- On v2 a web change that lands between the check and the write is still overwritten; the server offers no preconditions.
- A misleading link whose text does not read like an address opens on a tap ([threat model](threat-model.md) R31).
- Attachment lists are not synced (why: an upload does not bump `updated`).
- Location removal misses some places, such as place names (on iOS those outside IPTC's location structures), maker notes, a video's GPS track, on iOS a PNG text chunk named for GPS, and the parts after a JPEG's first image; videos picked as files keep their location.
- A provider that never answers keeps its thread until its process ends.
- Not built: image paste, Markdown paste, collaborative editing, images and attachments in comments.

## Notifications and widgets

### Which tasks notify
- Only undone tasks notify, at each reminder's time and, with a due date, at the exact due time; a reminder at the due instant rings once, as "Due now". No daily overdue digest for now.
- On Vikunja 2.8.0 and later: the tasks the user follows, for reminders and due dates alike, so unfollowing a task silences it on the phone too (why: the server reminds only a task's subscribers). On older servers and for link-share guests: the tasks the user created or is assigned to; tasks seen only through shares get none.
- The gate is the server version alone, development builds included (why: the server routes reminders whatever API the app speaks). Server behavior: [research/subscriptions.md](research/subscriptions.md).
- The follow state is stored without extra requests: per project from the project lists, per task from its own reads, which alone carry it (syncs never overwrite it). An opt-out never notifies (server fact: it holds through assignments and moves).
- An unfollow is recorded before its read-back (why: a failed read-back must not keep the task ringing); a follow waits for its read-back (why: its 412 may mean the follow comes through a parent).

### Local scheduling
- Notifications are scheduled on the device (why: the server pushes nothing, and its own reminders reach a phone only by a poll, after the fact). One scheduler per signed-in account plans from the local database by the account's Reminders and Due dates switches.
- A rolling window of each account's soonest entries, shared evenly among the signed-in accounts, less two each for the session reminder and the snoozed entry below (why: an even share needs nothing shared across isolates): on iOS 60 (why: iOS holds at most 64 pending and drops the rest, whatever the account); on Android 480, at most 100 each (why: once the app holds 500 alarms Android refuses every new one, even one that replaces another under its id, so every account's schedules would fail, the widget's redraw alarm too; the 20 left over are for that alarm and WorkManager's own, and more than 100 gains nothing). The first snoozed entry beyond the window goes too (why: its row is all that remembers the snooze).
- A changed entry is scheduled again under its id, never canceled first (why: on Android a cancel also takes what the tray shows); the tray loses what is done, gone or past. Android hands back the id of a notification it shows but not its payload (flutter_local_notifications returns one on iOS only), so the app keeps the payload it gave under each id, one preference per id, and forgets it at the cancel or once the notification is neither shown nor pending; a pending one without a kept payload takes the one the system holds (why: the tray is cleared by payload, and one preference per id lets several isolates write side by side). A reconcile whose table write went through also cancels the account's pending reminders and due dates that neither its table nor its window holds, pending ones only (why: a run that could not record what it scheduled, as against a widget's Done, would leave them to ring). Ids other accounts hold pending count as taken (why: a schedule under one replaces the other account's notification).
- Each account's first reconcile in an Android UI process schedules the whole window again (why: a force stop drops the alarms but not the plugin's pending list); verified on Android 16 only, so [releasing.md](releasing.md#cutting-a-release) repeats the check. The plan keeps instants up to 3 h past and never schedules them anew (why: Android defers inexact alarms by up to an hour, and a fired one must not show twice).
- Besides changes of the data, an account reconciles at start, on a return from the background and when the permission or exact alarms change, never after the notification shade, a system dialog or the app lock's prompt alone (why: each run reads and compares the whole window).
- Exact alarms are asked for at the onboarding with the notification permission. Without them Android falls back to inexact alarms, up to an hour late, which the app says. Never `USE_EXACT_ALARM` (Play reserves it for alarm, timer and calendar apps).
- A muted Reminders channel counts as off in the app while the scheduler keeps scheduling (why: turning it on then works at once). Sign-out cancels every id of the account before its database goes, also those the OS lists as pending with the account's payload (why: another isolate's snooze is recorded only in the database). Session reminders are [Sessions](#sessions)'s, hidden texts and the lock's effects [Security and privacy](#security-and-privacy)'s.

### Actions
- Snooze is local only (why: a server change would move the task for everyone, and the web has no snooze): 10 minutes, 1 hour, or Tomorrow at the user's default due time, else 9:00. Android shows Done, 1 hour and Tomorrow, as it shows at most three actions; iOS all four.
- A reminder or due date of a task the user may not change, its project read-only or archived (also through a parent), leaves Done out and offers only the snoozes, as the task's widget row offers no Done: on Android 1 hour and Tomorrow, with no 10 minutes in Done's place, on iOS a snooze-only set of all three (`task_snooze`) (why: the server refuses that Done, and the phone would show the task done with a sync problem until the change is discarded). Whether an entry offers Done is stored with it, so a permission or archive change plans it again; an unknown permission keeps Done ([Projects](#projects)). A Done tapped on a notification shown before such a change is ignored.
- Done runs in a background isolate through the outbox without a token refresh (why: a lost refresh race ends the session); a token that needs one leaves the op for a background drain. It withdraws the task's notifications at once (why: iOS may suspend the isolate), then drains for at most about 20 s (5 s on iOS).
- A Done or Snooze for an occurrence the task has passed is ignored (why: a repeating task moves on with each Done, so a second Done would skip the next occurrence).
- A tap opens the task after the lock, in the payload's account; a silent account switch needs the install's link key ([Security and privacy](#security-and-privacy)).
- **iOS: a Done or Snooze reaches the app when no scene connected**, as when iOS launches the app in the background for it. The app delegate hands each response to exactly one flutter_local_notifications instance: the UI engine's while that engine lives, else one made at launch without an engine, which only starts the plugin's background engine; a tap that opens the app waits for the scene's engine. The instances in the background engines (sync and actions) are never application delegates (why: every instance a registrar adds as one answers every response, so a Done would run twice), and the plugins' registrant for those engines is set at launch. Each action gets 20 s of background time (why: the plugin completes the response at once, and iOS may suspend a process it launched for one right after).

### Activity
- Server notifications are pulled per account (newest first until a known one, at most 3 pages): the active account on start, resume and every 5 min in front, every account in each background run. An account's first pull stores everything as handled (why: a sign-in never floods the shade).
- Comments, assignments, mentions and similar news show while the Activity switch is on, 10 per account in the tray (why: Android drops posts beyond 50 per app); never `task.reminder` (why: the local one fired on time), nor the active account's while the app is in front.
- Only the inbox's Mark all read goes out as one "mark all read" request, and only while nothing unread arrived since the user chose it (why: the server marks every notification read, older ones the phone does not keep included); every other mark goes out on its own, even one that leaves nothing unread on the phone.

### Home-screen widgets
- The app writes, the widgets only draw: one versioned snapshot per shown list, at most 30 rows plus a count, valid until midnight at the latest. On Android an Overdue or Upcoming list ends when its next task joins it, and the widget worker writes it again then; on iOS it stays until midnight and carries the tasks that join before then, as rows shown from their instant and in the count of each timeline entry, with the texts of every count an entry may show, also after Done taps (why: iOS draws a snapshot past its end as stale until a background run or the app writes it, and nothing writes it at a join while the app is closed). Nothing native talks to the server or holds a token (why: access tokens live 600 s, and an extension must never refresh). Dart formats every text; due labels are never relative (why: they would go stale between updates).
- Widgets are published when what they show changes, never for a sync's lease or checkpoints, and on a return from the background or a change of the device's 24-hour switch or time zone (why: each publish builds every list of the account).
- Done is exactly once: a tap's Done is queued and its id recorded in one transaction, and only then is the tap acknowledged (why: acknowledging deletes it, and a repeating task must never move twice). A tap whose task is done or has moved on queues nothing.
- No widget link writes (why: any app, and on iOS any web page, can open the app scheme); links switch accounts without asking only with the install's key.
- The widget kinds never change after the first release (why: a placed widget refers to its kind, so a rename removes it); `app/test/app/widget_kinds_test.dart` checks both sides.
- Android (Glance): Done is a button ([Accessibility](#accessibility)); the configure activity opens in the app's own task (why: no second Flutter engine on the same databases); `androidx.work` at 2.11.2 or later (why: below it R8 strips Glance's RemoteViews translator). Old widgets: [The previous app](#the-previous-app).
- iOS (WidgetKit): an App Intent requiring authentication writes one file per tap into the App Group, with no network, keychain or database. A tap also removes the task's notifications by the account and task key in their payload, which `app/test/app/widget_extension_contract_test.dart` pins. The app imports taps before a reconcile, at its start, on a return from the background and after a permission change too (why: the scheduler would schedule their reminders again). Every timeline renews the request markers of the widgets the system lists and of the widget that asks, which a prune always keeps (why: a widget placed again a moment ago may not be listed yet, and without its marker the app stops writing its project, label or saved filter).
- A widget worker or notification action still running when its account is removed checks the stored registry before each refresh and after each write, and puts "Account removed" back (why: nothing tells another isolate of a sign-out, and its write can land after the app's wipe). An unreadable registry removes nothing.
- The widget host can act as the app through Glance's list template and sees the link key ([R17](threat-model.md#7-residual-and-accepted-risks)): accepted for the beta and for 1.0. A fixed list with "+N more" or an own list behind a checking trampoline stay the choices for later.

Limits:
- While the app is closed only background runs refill the window; a reminder due during a force stop is lost unless due less than 3 h before the next start. A second snoozed entry behind a full window is forgotten.
- A follow change made on the web reaches the phone only with the next read of the task; until then it may ring once more or stay silent.
- A background run can still plan reminders of an account removed meanwhile.
- iOS widgets refresh with the app closed only through background runs, and their Done reaches the server only at the app's next start, resume, background run or notification action.

Open:
- On an iOS device: the widget configuration, the extension seeing placed widgets, App Group signing, whether a lock-screen release build needs `DEAD_CODE_STRIPPING=NO`, whether the extension reaches the app's notifications, the snooze-only actions of a task the user may not change (`task_snooze`), a Done or Snooze while the app is not running, a task joining an Overdue widget with the app closed, and a project widget removed and placed again.

## Security and privacy

- The threat model is [threat-model.md](threat-model.md); its residual and accepted risks ([§7](threat-model.md#7-residual-and-accepted-risks)) are the list of known gaps, and its rules for a diagnostics log ([§10](threat-model.md#10-rules-for-the-diagnostics-log)) bind [Diagnostics](#diagnostics).

### The app lock

- **A gate over the UI, not encryption:** data at rest stays as [Sessions](#sessions) and [Sync](#sync) store it, so nothing without a UI waits for the lock (the OAuth callback, notification actions, the widget worker, background runs).
- **Device settings**, the same for every account and kept at sign-out: the app lock (off), lock after (immediately, 1 minute by default, 5 or 15 minutes, 1 hour), Block screenshots, notification content, task titles in widgets.
- **Fail closed:** settings that cannot be read give every switch its most private value for that launch, without writing back (why: the user may have chosen any of them); the app waits at most 5 s for the read before it runs.
- Unlock by biometrics or the device credential (why: the screen lock stays a way in when biometrics lock out). It locks after every cold start and after the chosen time out of sight, measured both by the wall clock and by a clock that counts sleep and cannot be set (Android `SystemClock.elapsedRealtime`, iOS `mach_continuous_time`), whichever says it passed first; a wall clock set back to before the hide, a restart of the device and no reading of that clock on the return within 2 s count as passed (why: a clock set back to just after the hide would otherwise open the app without a prompt). Until that reading is in, the returning app stays covered and links wait as if it were locked. Without a device screen lock it turns itself off, saying so (why: removing the screen lock already needs the credential, and failing closed would leave only a reinstall).
- **Bounded excursions:** the app's own round trips (pickers, the share sheet, the browser sign-in) do not relock for at most the lock's time, never over 10 minutes, 30 s with "Immediately" (why: otherwise every round trip would end in a lock); a longer one counts as hidden from its start, and one that starts while the app is already out of sight counts from the hide (why: a download that finishes in the background would otherwise hide that time).
- The gate is the outermost widget of the router's builder, never a redirect (why: a redirect would replace the pages below and lose unsaved edits); links and taps wait for the unlock.

### Screens and notifications

- **Block screenshots**: Android only, a switch of its own not tied to the lock, `FLAG_SECURE` on the whole window. **On iOS screenshots stay possible**; one-time secrets are covered while the screen is recorded or mirrored, and hidden whenever the app leaves the foreground. If that channel fails the secret shows (why: a token shown only once must not be lost).
- While the lock is on, the app switcher shows no content (Android 13 and later without recents screenshots, elsewhere a privacy cover), and the app is covered whenever it goes out of sight (why: back under a translucent sheet left in its task, Android draws a frame before the lock is checked).
- **Notification content:** show everything (default), hide on the lock screen (Android posts as `secret`, why: `private` still shows the title), or never show task titles; a change that shows less withdraws what is delivered.
- **Background runs, the widget worker and notification actions read the privacy settings anew** for every reminder run, widget build and activity notification (why: nothing tells them of a change made in the app meanwhile).
- **No Done on Android while the lock is on**, only Snooze (why: the notification plugin cannot ask for the unlock per action, so Done would run from the secure lock screen); on iOS Done asks for the unlock. Turning the lock on withdraws the notifications already showing.
- **A new API token is shown once:** only in the state of the page that created it, never in a provider that outlives it, the database, the registry, logs or a route; one question when leaving without copying. One-time secrets and copied share links go through the sensitive clipboard (Android `IS_SENSITIVE`; iOS local only, expiring after 120 s).

### Data on the device

- **Backups excluded on Android**: `allowBackup="false"` plus extraction rules that exclude every domain from cloud backup and device transfer (why: from Android 12 `allowBackup="false"` stops only cloud backup, and on some devices not a device transfer).
- **Backups excluded on iOS**: the accounts folder (databases, queued uploads, drafts) and the App Group's `widgets/` folder, the mark set again at every UI start (why: a restore or a move can clear it).
- Secrets live only in the Keychain or the Keystore; tests pin the secure-storage options and the iOS entitlements (no keychain access group). **Headless containers** (extensions, widgets, notification actions) never refresh user tokens.
- **A file shared to another app goes at sign-out** (Android): the share plugin hands over a copy in the app's cache and empties that folder only at the next share, so signing out or removing any account deletes it, whichever account the file came from (why: the receiving app may still be reading it after the share sheet closes, so it cannot go earlier, and the folder holds only the last share's files). iOS shares the downloaded file itself, which goes with the downloads.
- `app/test/security/account_wipe_test.dart` signs one of two filled accounts out: nothing that names it may stay but its widgets' "Account removed", and every function that builds a String from an account id must be listed with how the test covers it.

### Errors and logs

- **Error hooks in every build:** all four entry points (UI, background runs, notification actions, widget worker) install `FlutterError.onError` and `PlatformDispatcher.instance.onError` (why: Flutter's default handler prints error details unredacted, in release builds too).
- **Redaction** (`core/logging/redaction.dart`) covers tokens, e-mail addresses, invite and share tokens, URL fragments and the widget-link key. No log call interpolates a secret, content, a link or a person; Kotlin logs failure types only and Swift nothing (`log_hygiene_test.dart`).

### Other apps

- **The widget-link key:** 32 random bytes in the preferences, compared in constant time and carried as `k` in every widget link (why: any app, and on iOS any web page, can send a widget link, so a link alone must not switch accounts). Without it a task link asks before it switches, and other links act only in the active account.
- **The key in notification taps** (why: any Android app can send `MainActivity` a made-up tap): without it a tap never switches accounts or marks anything read.
- **Routes pushed by the platform** go through the app-scheme relay, and anything else is dropped (why: Android's embedding pushes the data of any intent that reaches the exported `MainActivity` as a route).
- **No replay after a restore:** a start from Recents and a restore after Android ended the process get the launch intent without its notification tap, shortcut, link or share (why: the plugins read it again and would switch accounts or open the sheet once more); a relaunch for a configuration change keeps it (why: Dart may not have read the tap yet).
- **A second UI engine (R33):** a `MainActivity` started into another app's task restarts the intent in the app's own task without running Dart (why: else another app gets a second engine on the same data); one that Android adds in the app's own task above a picker, an opened attachment or a settings page (a reminder tap, a shortcut, the app icon after a reminder started the app) finishes and hands its intent to the running one with the hops' flags, which close what is above, or, for the app icon, only finishes, so the task comes back as it was; not `singleTask`, which would clear the sign-in's Custom Tab.
- **Launch extras:** the window is always opaque, and an activity that only hands a start over starts Flutter without the caller's extras (why: Flutter reads its launch configuration from extras any app can set, unchecked, and a bad one ends the app's process or makes the window translucent).
- **CI checks:** `tool/check_exported_components.py` holds the release manifest's exported components and backup rules to an allowlist; an OSV scan of every lockfile, also weekly, accepts an advisory only in `osv-scanner.toml` with a reason and an `ignoreUntil`; Gradle verifies every fetched file against `verification-metadata.xml`.

Limits:
- iOS backups still hold the preferences (registry, connection metadata, privacy settings, the widget-link key); restored to the same device from an encrypted backup, the this-device-only Keychain items return too (R21 to R23).
- Keyless links still act in the active account. The R33 restart and the hand-over of a second copy in the app's own task wait for a device check, and a caller with `MULTIPLE_TASK` or `NEW_DOCUMENT`, or one that finishes first, still gets a second engine.
- Snooze still runs from the lock screen. No per-account privacy settings and no PIN of the app's own.
- Outside the error hooks: the database isolate, errors before logging starts, plugins' prints and native logs (R24). Native code no lockfile describes (SQLite, the Flutter engine, Cronet) is followed by hand (R26).
- The widget host's mutable intent (R17) is in [Notifications and widgets](#notifications-and-widgets).

Open:
- The iOS device test ([threat model §8.3](threat-model.md#83-final-ios-phase)): the passcode, Done asking for the unlock, the redaction on the lock screen, a real screen recording, the sensitive clipboard and keyed links from the widget extension.

## Diagnostics

Problems reach the developer only through the user: no SDK that sends data apart from Sentry's for opt-in crash reports (why: the privacy manifests and store declarations stay simple), and release builds log nothing to the console.

### Support details

- **Support details**: the row on the About page, also signed out and for guests, builds a snapshot when tapped, shows it first, keeps it only while the page is open and lets it leave only through the share sheet (why no Copy button: the share sheet offers Copy on both platforms).
- **One exception**: the release error screen's "Copy support details" copies them, servers hidden, without the preview (why: the copy is deliberate, the text redacted, and it works when the router itself failed, where a button to the page would not).
- **They hold** the app's state and per account the server's version and features, the last syncs, the queue's counts and failure kinds and the last session end, in English in every app language (why: reports compare), ending with the diagnostics log of the last 7 days.
- **Never in them:** tokens, hashes, passwords, failure messages, names, e-mail addresses, ids of accounts, users, shares and projects, titles, payloads, user settings. Servers read `<server-N>` and accounts `<account-N>` unless "Show server addresses" is on, which is off at every opening; the redaction runs over the whole text last.
- **The last session end** is stored for them per account as reason, part of the app and time only, kept across a new sign-in (why: it answers why the account was signed out); they also print [Sessions](#sessions)' record of the end, never its token fingerprints.

### The diagnostics log

- Records from WARNING up, in every build and every part of the app, redacted when made: one line of at most 300 characters, an error by its type only, a stack by the app's own frames only.
- One file per isolate in the cache folder (why: backups and device transfers leave it out), at most 200 records and 64 KB, files older than 7 days deleted; no export of its own ([Identity and scope](#identity-and-scope)).

### Crash reports

- **Opt-in crash reports through Vikunja's Sentry**, in the old app's existing project; the new app's reports are told apart by their release, `io.vikunja.app@<version>+<build>`. kolaente only checks the project's settings (IP addresses not stored, scrubbers, spike protection or a rate limit, retention) and its region.
- **The DSN** is the repository variable `VIKUNJA_APP_SENTRY_DSN` of go-vikunja/app, set by the maintainer: not a secret or an environment's variable (why: the build job has no environment, and every build carries the DSN anyway). Without it the feature is absent: no question, no switch, no SDK start. `check_sentry_dsn` in both release scripts fails anything but an https DSN on `sentry.io` or a subdomain, without printing it (why: the network security config covers only `sentry.io`).
- **Consent**: off by default, asked once after the first successful sign-in, and a switch under "App lock and privacy"; turning it off takes effect at once and deletes the unsent reports. A device setting kept at sign-out; unreadable counts as declined. "No thanks" and "Allow" look alike, neither is the default, and the question promises no more than the scrubbers remove.
- **Scope**: crashes and the app's redacted error log, SEVERE records as reports and WARNING records as breadcrumbs. The old app's "Enable Sentry" is not carried over.
- **A report holds** the error, how it was caught, up to 50 of the app's warnings before it, the release, the device model and the system, Dart and Flutter versions. **Never:** any id of user, account, device or installation, requests, server names and addresses, IP addresses, file paths, tokens, tasks, titles, names, e-mail addresses, the device's name, state and settings, screenshots, sessions, traces or Sentry's automatic breadcrumbs.
- **Scrubbers and allowlists:** a Dart `beforeSend` and, on Android, a native scrubber; contexts and integrations are allowlists, so a new SDK version's addition stays off until looked at; exception texts stay only for known types without data; frames lose the folder names picked per install (why: they would link one install's reports). A report whose scrubbing throws is dropped by the app (why: the scrubber changes it in place, and Sentry versions before 10 send a report whose callback threw). Sentry's own error hooks are removed (why: they would bypass the repeat rule, the limit and the consent check); the DSN is set last (why: a throwing options callback then leaves Sentry unstarted). A repeat within 10 minutes is dropped, and an isolate run sends at most 20 reports.
- **Android:** the app starts Sentry's Android SDK itself, before `SentryFlutter.init` (why: every collecting option is then the app's, and the scrubber is in place before an earlier run's ANR goes out). The start writes exit markers dated no earlier than the newest exit (why: Sentry would otherwise report the latest ANR in the history, the old app's included, from before the consent).
- **`sentry.io` on system CAs only:** https and the system CAs only there (why: a CA a user or device policy installed for a server must not read the reports); `tool/check_exported_components.py` enforces it and that no Sentry component or setting enters the manifest.
- **iOS native reports are off** (why: sentry-cocoa builds them with its installation id and unscrubbed texts); only Dart's errors go.
- **Background isolates** re-read the choice before every report (why: a notification action's engine lives as long as the process).

Limits:
- Texts are scrubbed by patterns, so what no rule recognizes can pass (the threat model's [R43](threat-model.md#7-residual-and-accepted-risks)). Android's NDK reports keep system libraries' load addresses, which can link reports of one boot.
- The DSN is public, so anyone can send events, and Sentry sees the sender's IP address; a rate limit, spike protection and not storing IP addresses are the project's settings.
- iOS sends no native crash report. Background isolates send through `dart:io`, which ignores Android's network security config.
- No mapping or symbol upload yet: Java frames of classes R8 renamed arrive obfuscated, native frames without symbols.

Open:
- The maintainer sets `VIKUNJA_APP_SENTRY_DSN` before the first tag whose builds should send reports ([beta.md](beta.md#1-the-repository-and-ci)); kolaente checks the project's settings and region ([beta.md](beta.md#what-kolaente-does)).
- Device checks of the native start, the markers and a report of each kind, and the screen readers on the question and switch ([accessibility checklist](accessibility-checklist.md#210-checks-of-step-41)).
- The mapping and symbol uploads, which need a Sentry auth token as a secret of the environment `release`.

## Look and layout

### Design and color

- The app follows the maintainer's mockups in spirit and stays a typical Flutter app on material_ui and cupertino_ui. Not copied: a Teams tab, an inline Quick Add field and a project grid on the Overview, checkboxes on Kanban cards, the detail as a full page, and the task identifier ([Tasks](#tasks)), a project's color dot and the new-task sheet's row of reminder, repeat and attachment buttons. Kept although the mockups lack it: the favorite star on rows.
- **Brand colors by default**: a tonal scheme from the Vikunja web's blue `#1973FF`, also for installs that never touched the switch (why: the wallpaper's palette left Vikunja's blue only in the logo). "Use system colors" (Android 12 and later, where a palette exists) is an opt-in that replaces the whole scheme; iOS always uses the brand scheme. App and widgets share the default.
- Components read scheme roles, except Urgent and Do now: a fixed orange shifted to 3:1 for the flag and 4.5:1 for the name (4.5:1 and 7:1 under high contrast), widgets included, while red stays for overdue (why: Urgent looked overdue, and a role harmonized to the blue primary turns red again).
- **Legible colors**: folders, task color dots, Gantt bars and the widgets' folders keep the stored hue and chroma but shift their lightness (Oklch) to 3:1 against their surface (why: dark colors vanished in dark mode, pale ones in light). The stored value and the pickers keep the color as set.
- **Color rows offer the Okabe–Ito palette** without black (why: a black label or folder disappears in the dark theme), after "No color"; a color set elsewhere still shows as chosen and can be chosen again until the page is left.
- Every project shows as a folder in its color wherever it appears, the native widgets included; a color dot is only ever a task's own color.
- One task row serves every list, and new screens build on the shared widgets (`SectionCard`, `TaskRow` and the others).

### Device settings and the shell

- **The theme is a setting of this device**: Light, Dark or System (the default), the same for every account and guest, offline too (why: the app's look is chosen on the device, independent of the web). The account's `color_schema` is never read or written, so the web's choice survives.
- **The web's display settings apply only once set** (why: the web's defaults `relative` and `24h` would change the app for everyone who never opened them); until then the device's formats apply. A week start of 0 keeps the locale's (why: the server cannot tell 0 from never set).
- Default project and view titles (`Inbox`, `My Open Tasks`, the four default views) are translated for display only; storage and matching keep the server's titles.
- **Shell:** on Android a navigation rail from 600 dp; iOS keeps the bottom tab bar at every width, the iPad included. Re-selecting a tab pops to its root, an account switch resets the tabs, Back ends on the first tab. The shell reads the location of the tab's top page (why: go_router keeps the shell's matched location after a pop inside a tab).
- **The offline banner** is the shell's and follows the active account's sync runs, offline after one fails with a network failure, online after one gets through (why: no connectivity plugin can tell whether the server is reachable; the last sync can).

### Large screens

- **The gate:** widths are capped only on windows at least 480 dp high and at least 840 dp wide or 900 dp high (why: every large phone in landscape is at least 840 dp wide but under 480 dp high), so phones never are. Then lists keep to 840 dp; forms, sheets, settings pages and snackbars to 640 dp (why for snackbars: they fit every band without a wrapper per page); dialogs to 560 dp, except Flutter's date and time pickers, which need more.
- **No golden images:** layouts are checked by geometry in widget tests (why: CI renders on Linux, development on macOS).
- **The task pane beside the list** on windows at least 840 × 480 dp, not in tabletop posture, for tasks opened inside a tab other than Account; elsewhere the sheet. One pane per tab, at most 10 tasks deep, 40 % of the content within 360–480 dp; it closes on an account change and turns into a sheet, comment draft included, when the window shrinks.
- **Pages inside a tab have no predictive back preview on Android** (why: the detector took swipes for routes in covered navigators and popped the wrong page on Android 14 and later).
- **The project tree beside the project**: in the Projects tab, from 1,120 dp beside the rail (every iPad in landscape), tree, project and task pane stand side by side, the pane keeping its width. The gate comes from the window, not the content (why: the content changes with the rail's labels, so it would flip with language and text size); no tree for guests (why: it would hold only the open project). The route stays the source, so links work unchanged.

### Screens

- **The new-task sheet**: headline, title, Quick Add preview, project, then due date and priority as two chip rows that scroll sideways, both in view above the keyboard on a 360 × 740 phone. The sheet's date and priority are fallbacks in every mode that a line's own date or `!n` overrides. More options expands the sheet in place; nothing is created before Add, new labels included. Its bottom clears the system bars, and the keyboard while it shows.
- The pin "Keep open after adding" empties title and description after an add (why a mode: Enter adds, so only a mode lets the keyboard add task after task). Leaving with text typed asks "Discard the new task?".
- **The edit page** takes the sheet's form, with one priority row starting at Unset so a priority can be cleared.
- **The task detail header** shows the project chip with its parents, never cut off.
- **The Account tab's order**: banners and header; Account settings, Organize, Accounts; Sync; Home screen, Notifications, Privacy, Appearance; Server; Sign out; the About row above the version line.
- **Appearance** holds Theme, "Use system colors" and App language, each marked "On this device".
- **"Show saved filters"** in the Projects tab's menu is on by default, per account, not offered to guests.
- **Selecting on the Overview** is by long press alone, with no header menu; [Tasks](#tasks) has the rules.

Limits:
- The native launch screen follows the system's dark mode, not the app's theme, until the first frame.
- The account's `language` and `timezone` are not used for display; the device's are.
- Windows 600–839 dp wide and 480–899 dp high (split screens in portrait) get no caps; pages over the shell cover the rail or the tab bar and get no pane.
- Not checked on a device: back swipes in the pane, a foldable, iPad Split View and Slide Over, the widgets' new colors.

Open:
- An option to hide the project tree may come later.

## Accessibility

- **WCAG 2.2 AA is the internal yardstick,** with the deviations below and no public conformance claim.
- **Headings:** screen and sheet titles are level 1, section headers level 2. Every `header: true` names its `headingLevel`.
- **One announcer** (`features/common/presentation/announce.dart`) makes every announcement (why: Android's engine reports no announce support, so there a live region above every sheet and dialog speaks).
- **High-contrast themes** apply whenever the platform reports high contrast.
- **Reduce Motion** is read from the platform when needed (why: `MediaQueryData` does not carry it).
- **Text size has no global clamp.** iOS text up to 3.12× (AX5) works on the six core screens: the Overview, a project list, the task sheet, the edit page, the New task sheet and the Account tab.
  - Navigation labels stop at 1.15× on Android (why: the bold selected label must fit in German at 200 % text) and at 1.3× on iOS and the rail. Past that, a long press shows the label at full size, like UIKit's large content viewer.
- **Overdue is not shown by color alone:** an error icon replaces the calendar, and the row says "Overdue".
- **Refresh buttons** sit in the session, API token and CalDAV lists (why: many screen-reader and switch users cannot pull to refresh).
- **Toggles keep their names** and say their state (why: a name that changes with the state sounds like two controls).
- **Targets are 48 dp:**
  - Chips take the standard density (why: the compact density shrinks a chip's tap target), with tests of their own, as the route sweep does not see them.
  - The Tasks widget's Done is a 48 dp button named after its task (why: Glance's own checkbox is 32 dp and has no name).
- **Single-pointer ways** exist to move a card to another column, move a column, and change a project's parent or a task's project.

### Deviations from WCAG 2.2 AA

- **1.4.4 Resize Text:** below 200 % for the navigation labels, the inbox badge, the offline banner and Upcoming's date column (1.3×), Upcoming's day strip and the Gantt header (1.5×), and Flutter's app bar title (1.34×). Avatar initials, reaction emoji and inline pills do not scale.
- **2.5.7 Dragging Movements:** moving a card within its column, a task in a manually sorted list or a project among its siblings takes a drag or a screen reader's actions.
- **1.4.11 Non-text Contrast:** the light brand scheme's amber highlight is about 1.82:1; it only supplements the star's outline and the priority's name.
- **1.4.3 on iOS alerts:** Apple's system colors measure 2.86 to 4.40:1; under Increase Contrast the insecure-connection alert's "Continue anyway" stays at 4.23:1.
- **Platform target sizes:** the Material date picker's day cells are 43.4 × 48 dp on a 360 dp phone, and Cupertino's segmented control is 28 pt.
- **Read-only selectable text,** such as the server's message, has no minimum target size: 2.5.8's inline exception, as its line height sets its size and selecting is a text function.
- **Two headings are also buttons:** the Account tab's heading, the signed-in account, opens its settings, and the task sheet's title opens the edit page where the task can be changed.
- **A sheet's barrier and drag handle** both read "Dismiss" and both close the sheet, so the name keeps one purpose (3.2.4); only Android tells them apart.
- **2.3.3 (beyond AA):** under iOS Reduce Motion, page and sheet transitions still slide.
- **Flutter's `LicensePage`** marks its titles as level-0 headers.
- **On Android,** a new field error with a helper text may be spoken twice.
- **Dynamic color schemes** are not checked for contrast.

### The guards

- **The route sweep** (`app/test/a11y/`, run in CI) is the guard. No check is relaxed without a reason in the test and an entry among the deviations above.
  - Every route needs a scenario. Every dialog, sheet, menu, picker and page route needs an overlay scenario or an exemption with its reason.
  - Scenarios run in light and dark, in English and German, checking tap targets, labels, contrast, heading levels and unique labels.
- **An emulator scan replaces the Accessibility Scanner**, which needs a Google sign-in; the Scanner is not used on a device either. The scan reads `uiautomator` dumps of the release build.
- **The manual TalkBack, Switch Access and VoiceOver pass belongs to the device phase**. Why: TalkBack ignores the input an agent sends over adb, so the checklist's 15 flows need the maintainer, about two to three hours.

Limits:
- The sweep sees only what its scenarios show.
- The scan did not run at the largest font, and the Kanban board was not scanned.

Open:
- The manual pass ([accessibility checklist](accessibility-checklist.md)) still has to check:
  - whether TalkBack speaks the live region reliably;
  - board and list moves, in-place editing, swipes and selection;
  - whether TalkBack enters the editor's WebView.

## Languages

- **US English is the base**, like the Vikunja web: `app_en.arb` is the template, and the ARB descriptions and store texts follow it. Keys, identifiers, comments, logs and test names keep their British spelling (why: renaming keys touches hundreds of call sites for nothing a user sees).
- Every string is in `app_en.arb`, and every message with a placeholder or plural has a description (why: it is the translators' only context on Crowdin).
- **Every language comes through Vikunja's Crowdin project, German included** (why: Crowdin's export writes whole files and would overwrite German changed in a pull request). Once the maintainer's one-time upload has taken German to Crowdin, pull requests change only the English and German may lag on `main`; until then a change of English also writes its German.
  - The one exception, which the maintainer chose: a pull request that removes or renames an English text, or changes its placeholders, also deletes that text from every other language file, as Crowdin's next export would (why: the translation checks fail on a key or a placeholder English lacks, and English stands in until the export).
- **A release needs German complete**; both release scripts refuse otherwise. A patch release may go without it only while the repository variable `VIKUNJA_APP_ALLOW_INCOMPLETE_GERMAN` equals its tag (why: a value naming the tag cannot carry over to the next release), never an `x.y.0` or its betas.
- **Which languages ship**: English and German from the start, any other once 50 % of the app's file is translated and approved, as on Vikunja's web, added to `shipped_locales.dart`; an ARB file not on that list is never shown. The Android release build only warns below 50 % (why: English grows, so a share falls without anyone touching it). Not shipped yet: right-to-left languages until a layout pass, Esperanto (no Material support), Vikunja's custom Swiss German, exported as `app_gsw.arb` through a project mapping (why: its custom code may be `de`, which would overwrite German).
- **No web texts are copied** (why: the web is under the AGPL, the app under the MIT License); error texts are our own words. Pre-translation from the web's translations waits for kolaente's agreement.
- **Terms:** [glossary.md](glossary.md) sets them for both languages. German says du and follows Vikunja's German translation instructions: "Account", never „Konto“; „Anmeldename“, never „Benutzername“; „Gerät“, never „Handy“, store texts and native strings included.
- The app calls itself "Vikunja" where it names itself on the device (launcher, notifications, widgets), "the app" where the sentence also names a server, syncing, the license or data handling, and "Vikunja app {version}" before a version (why: there "Vikunja" reads as the server, "Vikunja 1.0.0" as a server version).
- Texts change only when inconsistent, wrong, unclear or misspelled, never for taste. The support details stay English in every language, so reports compare.
- **Plurals:** every English plural has a `one{…}` branch that shows its number, never `=1{…}` (why: some languages use the one form for 21 or 31, French for 0, and translators copy the English).
- **The generated l10n code is not in git** (why: Crowdin's pull requests change only ARB files and would fail a check for stale generated code). `flutter pub get`, `build` and `run` write it, `analyze` and `test` do not, so every CI script runs pub get first.

### Crowdin

- **The sync is the workflow `crowdin.yaml`**, nightly and by hand on `main` of go-vikunja/app, not Crowdin's GitHub integration (why: that authorizes through a person's OAuth, reaching all their repositories, and needs admin on the repository). Its Crowdin token is a secret of the environment `crowdin`, which deploys from `main` only. The pinned CLI uploads the English and downloads only approved translations.
- German comes only from its own download, and no other export may write `app_de.arb` or `app_en.arb` (why: the custom Swiss German could export as `app_de.arb` without the project's mapping).
- The files become one pull request from the branch `crowdin`, whose CI runs once a maintainer approves it (why: a pull request opened with `GITHUB_TOKEN` starts no checks by itself). The job with the write token runs no third-party code and treats the CLI's files as untrusted; gen-l10n escapes every translation.
- `crowdin.yml` keeps the source in the version branch `main`, beside the old app's root file, so old translations do not carry over, and quotes `"no"` (why: YAML 1.1 reads a bare `no` as false). Crowdin's `no` becomes `nb`, what Norwegian devices report; every regional file needs a base file (why: gen-l10n fails without one), and the template has no `@@locale` (why: Crowdin would write codes gen-l10n refuses).
- **The uploads:** the source only once the old app's nightly "Crowdin Sync" is off (why: it would bring the old file back); right after, the maintainer's one German upload, auto-approved, with `-b main` (why: else it lands in the old root file, which is not exported) and `--import-eq-suggestions` (why: 68 German texts equal the English and would be skipped, so German would never be complete). Commands are in [beta.md](beta.md#the-translations-on-crowdin).

### On the device

- The locale is resolved over the shipped languages only, so the system's texts match the UI, in the region of the device's first locale of that language: dates, numbers, the first weekday and date input follow the region. The clock follows the device's 24-hour switch while the account sets no time format (why: the switch already follows the region unless the user set it).
- The app's own Material delegate adds the region's formats to the language's texts (why: Flutter's regional classes would mix British spelling, de_CH's all-caps buttons and English into the app).
- The UI, notifications, widgets and the lock prompt follow a language change without a restart; the notification channels are created again under their ids, which keeps the user's settings.
- **The App language row opens the system's page** (why: the system setting stays the one source of truth), hidden on Android 12 and older. The account's language setting never changes the app's.
- **Server errors:** an unmapped code shows a localized sentence with the server's detail (why: for an unknown code the detail is the only clue).

Limits:
- A changed English text leaves its translations unapproved and the export drops them: after every English change a maintainer re-approves or retranslates its German on Crowdin, or the next Crowdin pull request lacks it and a release refuses.
- An untranslated message shows in English, so a language at 50 % is half English; native strings stay English and German until a third language is about to ship. Only the Android release build warns below 50 %.
- On iOS the App language row and the app's Language page wait for the device test.

Open:
- The workflow's first run, the maintainer's German upload, and the first Crowdin pull request, which reformats every ARB file once.
- For kolaente ([beta.md](beta.md#what-kolaente-does)): the Swiss German mapping; the token's owner and expiry; pre-translation from the web; removing the old root file.

## The previous app

On Android the app ships as an update of the old official app ([Identity and scope](#identity-and-scope)), so its first start finds the old app's data in the same sandbox. iOS has nothing to take over; the old app was never in the App Store.

### The first start after the update

- It takes over the server, the session, the theme, "Use system colors" and the language, clears the old app's leftovers and keeps its placed widgets; the note "This is the new Vikunja app" says so, once.
- **When:** in the UI isolate, on the start whose first-start wipe of secure storage would delete the old entries ([Sessions](#sessions)), before the account registry's first read (why: that read runs the wipe), within 10 s and never throwing. It never reads the old access token and keeps only a record without secrets (servers, number of placed widgets). The crash reporter starts after it (why: its registry read would run the wipe first, [Diagnostics](#diagnostics)).
- **The session, tried once**:
  - Not for a server on `http` or below the support floor: the old token is not sent, and Connect asks as usual (why: the old app never asked the cleartext question, [Connections](#connections)).
  - The refresh goes without a client id, which the server's refresh grant does not check, so the old app's token is accepted; `GET /user` must return the token's user within 20 s, and on any failure the new session is logged out best effort.
  - The token lives only in memory, never logged or stored, and any failure, an offline start included, uses up the one try (why: a second try would need the token kept in secure storage, a secret living longer).
  - An overall limit of 30 s and a Cancel on Connect's progress line, the one control while it runs (why: the steps' own timeouts add up to about 110 s). Either ends it as a failed try with the address filled in; a later answer stores nothing, and a session it brings is logged out. A canceled try is the one try. Once the server has confirmed the account, the session is kept (why: only local storage is written from then on, and undoing it would register and remove the account).
- **The prefill**: Connect fills in the old server address, else the server the old app used last (why: it deleted the address on sign-out but kept its recent servers), and shows up to 5 other recent servers as "Your servers". Not in Add account.
- **Theme, colors, language**: the old light or dark becomes the device's theme before the first frame. "Use system colors" is on only when the old value was `true` and could be read (why: the old default was off, so its users saw the brand blue). The old language becomes the per-app language on Android 13 and later when it is shipped and the app has none yet, even when it equals the device's (why: the old override pinned it too).
- The old app's "Enable Sentry" is not carried over; the app asks anew ([Diagnostics](#diagnostics)).

### Cleared and kept

- **Cleared** on the first start of every install, fresh ones included (why: idempotent and cheap, so a job or reminder the detection missed cannot survive): the old reminders and notifications first (why: a reminder that fires would create its channel again), its background works, its channels, its widget data, the old widget provider while no widget uses it, Sentry's unsent reports and installation id, and every secure-storage entry.
- **Kept**:
  - Placed old widgets, through a receiver under the old class name `io.vikunja.app.widget.AppWidgetReciever` (spelling kept). They ask to be set up rather than show Today (why: that could change what an old widget showed); the old choice is not mapped. The component is disabled once no widget uses it (why: some launchers would list "Tasks" twice).
  - The launcher component `io.vikunja.app/.MainActivity`, so placed launcher icons survive.
  - `vikunja_notification_logo` as an alias of `ic_notification`, kept from resource shrinking (why: old reminders set before the update name that icon, and a name that resolves to nothing would crash the notification plugin's receiver).
- **Nothing runs at the moment of the update** (why: a receiver of the app's own would race the notification plugin's, which re-arms the old reminders), so an old reminder can fire until the first start, with a Done that does nothing.
- The old Quick Settings tile is not replaced; the system drops it.

### The update and smoke tests

- `tool/e2e/update_test.sh` (over the old app's last build, from `cdbc6e3`) and `tool/e2e/smoke_test.sh` (a fresh install) run by hand on an emulator, never in CI (why: they need an emulator and the maintainer's sign-in); see the [developer guide](development.md#update-and-smoke-tests-on-an-emulator) and [threat model 8.2](threat-model.md#82-manual-on-the-android-emulator).
- They touch only an `emulator-<port>` whose AVD is the project's `Vikunja_Screens` or `Vikunja_Tablet`, else stop before installing, and send every command to the adb transport id recorded at the start, rechecked by AVD name before each install or uninstall (why: an emulator that took over the serial must get nothing).
- The maintainer does every sign-in: nothing prints a password or token, and the recording stops before a browser or Connect takes input.

Limits:
- Builds from before February 2026 wrote with flutter_secure_storage 9, which version 11 cannot decrypt: their users get the note without a prefill. Builds of March 2026 stored a refresh cookie: prefill and note, but no try.
- On Android 14 and later the update leaves exact alarms off; only the usual setup step asks ([Notifications and widgets](#notifications-and-widgets)).
- The kept account has no confirmed sign-in host, so a later "Sign in again" on another host asks once.
- An install whose first wipe failed (a broken Keystore) and whose user then saved connection settings counts as an update; the effect is the note.

Open:
- Whether a Cancel or the limit after the server has confirmed the account may end the try as kept, as built (the maintainer to confirm).
- Whether old reminders fire before the first start below Android 16, untested.

## Releases

The checklist is [releasing.md](releasing.md), the beta's runbook [beta.md](beta.md).

### Channels and versions

- **Android and iOS reach 1.0.0 separately**: Android once its checks pass, iOS after its device test. iOS is tested only at the end, in the simulator and then on a device.
- **Beta first**: `1.0.0-beta.N` on Play's open testing track, a public TestFlight link and GitHub prereleases, with testers on their own server or `try.vikunja.io`; then `1.0.0` as a staged rollout. Play's closed test of 12 testers for 14 days does not apply (why: only a new personal account needs it, and `io.vikunja.app` is in production).
- **Google Play, plus a signed APK** on GitHub Releases and dl.vikunja.io: a universal APK and one per ABI, all with one version code so a device can move between them. A hand-installed APK gets no updates by itself, as the README and help page say; no third-party updater is named.
- **Builds come only from tags** (why: the old app uploaded every push to `main` to Play): a beta tag goes to Play's beta track, a final one to production at `VIKUNJA_APP_PLAY_ROLLOUT` (0.1 when unset).
- **Version and build number come from the tag**, every beta ordering below its release within Play's limit of 2,100,000,000; no product flavors, as one application id serves Play and the APK.
- **What's new** is a file per version code and listing language, at most 500 characters; production refuses without the en-US one (why: the staged rollout starts at once, and it is where an old-app user learns what changed).
- `targetSdk = 36` stays a literal checked by a test (why: API 37's local network permission needs a Play declaration from 2027-08-25, and a Flutter update must not bring it unnoticed).

### CI and the release workflow

- The logic lives in `tool/ci/` scripts that run the same locally and on GitHub Actions, the only CI; every download is pinned by SHA-256, Flutter included, and Gradle's verification metadata pins every Android dependency.
- **Only go-vikunja/app publishes:** a real run needs a tag of that repository, checked by its numeric id (why: another repository renamed to that name does not pass); anything else is a dry run without secrets, so the workflows can be tried in a test repository first.
- **Keys only at the end:** build jobs make unsigned files; only `publish` signs and publishes, after the whole CI, `ios` included, which runs on `xcode-27`, the Xcode of the iOS releases (why: a tag that does not build for iOS cannot be released from the Mac either). The contract matrix's run on the tag is read before the approval ([Servers](#servers)).
- **The environment `release`**, set up before the first tag, so every release, the betas included, waits for a reviewer: the maintainer and kolaente as required reviewers, either may approve, their own tag's too ("Prevent self-review" off), no administrator bypass. It deploys from `v*` tags only and holds the seven release credentials as its own secrets, with no repository or organization copy (why: such a copy can be read by any workflow on any branch, without the reviewers).
- **The maintainer has the role Maintain on go-vikunja/app, not admin**, and kolaente sets only what is needed: first the environments `release` and `crowdin` with their secrets and Actions allowed to open pull requests (for Crowdin); then "main protect" with a pull request, one approval and the six checks, and a `v*` tag ruleset that only the admin and Maintain roles bypass (why: only maintainers start a release, and a release tag is never moved).
- Workflows are hardened as a test checks (least permissions, GitHub's own actions pinned by commit SHA, runner labels never `-latest`). Dependabot updates only the actions, with a 7-day cooldown, and a weekly workflow fails while Flutter or `cronet-bundled` is newer than its pin (why not a bot's pull request: raising either needs new checksums, notices and verification metadata).

### Signing and publishing

- **Vikunja's upload key signs the bundle and, without a separate APK key, the APK** (why: installs of the old app's APKs keep updating); the secrets keep the old app's names, so the maintainers need no new ones. No distributed build is signed by Gradle or on a laptop.
- Each certificate must match `tool/ci/release_certificates.txt` (why: a swapped secret would otherwise sign the public APK with a stranger's key). An APK is signed twice and must come out identical, so its key is RSA (why: a re-run must reproduce the APK already published).
- The build refuses unless the source link at the tag is public, German is complete ([Languages](#languages)) and every vikunja.io page the app and listings link opens signed out (why: Play's Data safety, account deletion and the App Store's support URL need them live).
- **The order:** Play first (the strictest check of bundle and key), through a standard-library uploader (why: no third-party code sees Vikunja's service account key), then dl.vikunja.io, then the GitHub release with `SHA256SUMS` and the desugar_jdk_libs source. Each step skips what is there with the same SHA-256 and fails on other content.
- A newer `cronet-bundled` is looked for before each release ([Connections](#connections)).

### iOS

- **TestFlight uploads run by hand from the maintainer's Mac** (why: in CI, signing and the API key would live in a runner's account or in secrets); `ios_release.sh` refuses unless HEAD is the clean tag and German is complete. The iOS scripts require `xcode-select` to point into an Xcode app and unset `DEVELOPER_DIR` (why: the Dart native-asset hooks ignore it).
- **App Store prerequisites:** the app's and the widget extension's privacy manifests declare no tracking and no collected data (why: apart from the crash reports, data leaves the device only for the user's server); `Sentry.framework`'s own declares crash and diagnostic data, not linked and not for tracking, and the privacy label adds Crash Data and Other Diagnostic Data ([Diagnostics](#diagnostics)). Every binary is checked against its required-reason declarations (why: a refused build uses up its build number). `ITSAppUsesNonExemptEncryption` is false (why: only standard, exempt encryption: HTTPS, TLS with pinning, PKCE). iOS uses the system SQLite (why: the bundled build imports `statfs`, which no Apple reason fits), so the app's SQL may need nothing newer than iOS 15's SQLite 3.36 ([the minimum](#accounts-and-sign-in)).
- No Time Sensitive notifications. The Accessibility Nutrition Labels stay blank until the device passes.

### Stores and pages

- **The name is "Vikunja"** in both stores, never "unofficial"; the texts say that the app has no server of its own (why: Vikunja, the publisher, also runs `try.vikunja.io` and Vikunja Cloud) and that Vikunja sends no push notifications. Listings are US English and German, not on Crowdin; Play's short description stays kolaente's and the App Store subtitle is ours. [store-listing.md](store-listing.md) has every console answer.
- **Reviewers use the public demo** with its shared account.
- **Play's Data safety is answered cautiously** (why: Play counts every transmission off the device as collection, even to the user's own server), as the union of the old app's answers and the app's own (why: Play judges the form over every version it distributes). No location. Encrypted in transit: No (why: `http` can be allowed after consent, and "Yes" must always hold).
- Screenshots come from dedicated emulators or simulators, the maintainer signing in; agents never type credentials.
- **The app's pages are on vikunja.io** in English (why: one address serves every language) and must not move once in the stores: `/privacy/#mobile-app`, `/help/mobile` (support and account deletion), `/imprint/`, `/security/`. The texts are drafts in [vikunja-io-drafts.md](vikunja-io-drafts.md) for kolaente to publish, and no build is distributed before.
- Contacts name no person: `hello@vikunja.io`, `security@vikunja.io` for private security reports. The About page's first row "Help and bug reports" opens the help page.
- **The threat model is signed off before the first beta tag and again before 1.0.0** (why: the beta is public).

Limits:
- The workflows ran only in a test repository with throwaway keys, the Play path only against a fake server.
- A leaked key moves the APK's installs only through signature rotation, which the scripts do not support; whether Play's installs and the APK update each other is unknown.
- A vikunja.io page moved after a release breaks the stores' links unnoticed until the next one.
- The demo is reset at irregular intervals; the fallback is a review server seeded by `tool/seed_demo_data.py`.
- From April 2027 Google wants a sign-in restored on a new device, which would reverse keeping tokens on the device ([Sessions](#sessions)); left to the maintainer after 1.0.

Open:
- The upload certificate's SHA-256, from Vikunja's maintainers.
- From kolaente ([beta.md](beta.md#what-kolaente-does)): the vikunja.io pages, an address for App Review and testers, the maintainer's Play Console permissions, the Apple account with the App Store name, seller and privacy label.
- Whether a `github-actions` approval meets "main protect"'s required approval.
- The French encryption declaration, before the App Store release in France ([releasing.md](releasing.md#export-compliance)).
- The rollout stages and hotfix steps in [releasing.md](releasing.md#the-rollout), proposals for the maintainer.
