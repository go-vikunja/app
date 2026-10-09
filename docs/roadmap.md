# Roadmap

Condensed from [research/synthesis.md](research/synthesis.md) §4, which has each step's full scope, out-of-scope list and acceptance criteria. Where the synthesis and this page or the [decision log](decisions.md) disagree, this page and the log win.

## How steps are reviewed

- Each step is one branch and one PR.
- Each PR comes with:
  - screenshots or a recording;
  - a green CI run, including the server-version contract matrix when the API is touched;
  - a "decisions taken" list;
  - the open follow-ups.
- The next step starts only after approval.

**Definition of done** for every step:
- `flutter analyze` is clean.
- New logic has unit and widget tests.
- The UI works in dark mode and at 200 % text scale.
- New interactive elements have semantics.
- Strings are in ARB (en + de).
- No secrets appear in logs.
- No new dependency is added without a note in the PR.

**Sizes:**

| Size | Effort | Diff |
|---|---|---|
| S | ≈ 1–2 engineer-days | < 600 changed lines |
| M | ≈ 3–5 engineer-days | |
| L | ≈ 6–10 engineer-days | split further if it grows |

## Milestones

| Milestone | Reached after | Result |
|---|---|---|
| M0 | Step 4 | Signed-in shell with several accounts |
| M1 | Step 10 | Offline read-only client |
| M2 | Step 14 | Daily-driver editing |
| M3 | Step 19 | Notifications, background sync, widgets: private beta candidate |
| M4 | Step 33 | Web parity without licensed features (time tracking, step 34, is deferred) |
| M5 | Step 37 | Store release |

Rough total: about 85 engineer-days to M3 and about 160 to M5.

## Steps

The owner's answers of 2026-10-09 ([open questions](open-questions.md)) changed this plan:
- Step 1 was finalized with the 2.3.0 floor without the `standard` tier ([D13](decisions.md#d13-support-floor-230)), the app id `dev.coderoftime.vikunja`, and the name Taskuna (proposed, pending approval) with its icon from [branding/README.md](../branding/README.md) ([D15](decisions.md#d15-app-id-devcoderoftimevikunja)).
- Step 4 was "Password + TOTP login, API-token login". Multi-account replaces it ([D14](decisions.md#d14-browser-sign-in-only), [D16](decisions.md#d16-multi-account-in-the-first-release)), so no step is renumbered.
- Step 34 is deferred and step 38 (legacy servers 0.24–1.x, optional) is removed ([D20](decisions.md#d20-scope-cuts-and-desktop-adaptations), [D13](decisions.md#d13-support-floor-230)).

| # | Step | Goal | Size | Status |
|---|---|---|---|---|
| | **Phase 0: Foundation** | | | |
| 1 | Walking skeleton and server connection | A CI-built Android and iOS app whose only feature is "Connect to server", showing version, API mode, tier and capabilities. Servers below the 2.3.0 floor are reported as unsupported | M | **in review** |
| 2 | HTTP core and error model | One reliable transport per server: retries, redacting logger, `VikunjaFailure`, paging, query builder | M | planned |
| 3 | Sign in with browser (OAuth + PKCE), session manager | A signed-in user on ≥ 2.3 servers (the support floor) with transparent token refresh. The session manager supports several accounts and refresh from background isolates ([D16](decisions.md#d16-multi-account-in-the-first-release), [D22](decisions.md#d22-session-keep-alive-through-background-sync)) | M | planned |
| 4 | Multi-account: add, switch and remove accounts | Account switcher in the first release. Each account has its own tokens and, from step 6, its own database ([D16](decisions.md#d16-multi-account-in-the-first-release)) | S | planned |
| | **Phase 1: Offline read path** | | | |
| 5 | Domain model and read ports (v1 + v2 adapters) | A complete read-only `VikunjaClient` for sync and the first screens | L | planned |
| 6 | Local database and initial sync | After login, the full account is in Drift and readable offline | M | planned |
| 7 | Incremental sync and delete reconciliation | Web changes, deletions included, appear on open and on pull-to-refresh | M | planned |
| 8 | App shell, theming, settings applied, projects tree | A navigable app that feels native, with the account switcher in the shell | M | planned |
| 9 | Task lists (read-only) | The daily views (Home, Upcoming, project list) work offline | M | planned |
| 10 | Task detail (read-only), HTML rendering, deep links | Every task property is visible and correctly rendered | M | planned |
| | **Phase 2: Write path** | | | |
| 11 | Outbox engine and first mutations (done/undo, favorite, delete) | The safe write pipeline, proven on the most frequent actions | M | planned |
| 12 | Task editing: core properties and simple create | Edit everything a daily driver needs | L | planned |
| 13 | Quick Add Magic and composer | Fast, web-compatible capture from anywhere in the app, with the four known parser bugs fixed ([D19](decisions.md#d19-quick-add-quirk-policy)) | L | planned |
| 14 | Subtasks, relations, duplicate, subscriptions | Complete the task graph | S | planned |
| | **Phase 3: Mobile capabilities** | | | |
| 15 | Local reminder and due notifications with Mark done / Snooze | Reliable reminders with in-notification actions for tasks the user created or is assigned to; due-date notifications at the exact due time; notification and exact-alarm permissions asked during onboarding; no overdue digest ([D17](decisions.md#d17-notification-policy)) | L | planned |
| 16 | Background sync, activity notifications, notifications inbox | Web-created tasks appear without opening the app (within OS limits). Background runs keep every account's session alive ([D22](decisions.md#d22-session-keep-alive-through-background-sync)) | M | planned |
| 17 | Realtime in the foreground (WebSocket) | Instant activity while the app is open | S | planned |
| 18 | Home-screen widgets: Android | Configurable, interactive Glance widgets | M | planned |
| 19 | Home-screen widgets: iOS | WidgetKit parity, mark done with the app terminated | L | planned |
| | **Phase 4: Web parity** | | | |
| 20 | Kanban board | Board with paged buckets and accessible drag-and-drop | M | planned |
| 21 | Bucket management | Bucket CRUD, limits, done/default bucket | S | planned |
| 22 | Manual ordering | Drag-reorder tasks and projects | S | planned |
| 23 | Project management and views | Project CRUD, archive, duplicate, views management | L | planned |
| 24 | Filters engine, saved filters, global search | Local filter evaluation, filter builder, offline search | L | planned |
| 25 | Description editor (TipTap in a WebView) and interactive checklists | Lossless rich-text editing ([D18](decisions.md#d18-tiptap-description-editor-in-a-webview)) | L | planned |
| 26 | Attachments and share target | Upload, download, previews, "Share to Taskuna" | M | planned |
| 27 | Comments, reactions, unread | Comment threads, mentions, reactions | M | planned |
| 28 | Labels, teams, sharing | Label CRUD, teams, project sharing and link shares | M | planned |
| 29 | Table and timeline views | Detailed list and a read-only timeline | M | planned |
| 30 | User settings and profile | General settings, avatar, password, email | M | planned |
| 31 | Security and integration settings | TOTP, sessions, API tokens, CalDAV, export, account deletion | M | planned |
| 32 | Onboarding extras and link-share guests | Registration, password reset (both re-scoped for browser sign-in, [D14](decisions.md#d14-browser-sign-in-only)), guest access through link shares | M | planned |
| 33 | Power-user features | Webhooks, bots, backgrounds, migration. No MCP page and no admin panel ([D20](decisions.md#d20-scope-cuts-and-desktop-adaptations)) | M | planned |
| 34 | Time tracking (licensed) | Timers and time entries when licensed | M | **deferred** until a Vikunja licence is available ([D20](decisions.md#d20-scope-cuts-and-desktop-adaptations)) |
| | **Phase 5: Hardening and release** | | | |
| 35 | Security hardening | Threat model, app lock, TLS pinning, mTLS, custom headers, audits | M | planned |
| 36 | Accessibility, i18n, tablets | Screen readers, complete English and German, tablet layouts, keyboard shortcuts on iPad ([D21](decisions.md#d21-languages-english-and-german)) | M | planned |
| 37 | Release engineering | Flavors, signing, store builds from tags | M | planned |
