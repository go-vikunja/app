# Vikunja Flutter client: synthesis, architecture and roadmap

Date: 2026-10-08. Inputs: `api-v1.md`, `api-v2.md`, `auth.md`, `sync.md`, `features.md`, `client-logic.md`, `flutter-stack.md`, and the corrections in `critique.md`. Where they conflict, **the critique wins** and this document already applies its corrections.

Reference: Vikunja `main` @ `e7d7f17` (2026-10-06), latest release **v2.7.0 (2026-10-02)**. All Vikunja paths are relative to the repo root.

Evidence labels:

| Label | Meaning |
|---|---|
| **[V]** | Verified in Vikunja source by the research files or the critique. The path is cited. |
| **[V\*]** | Re-verified by me during this synthesis. |
| **[I]** | Inference, design decision or recommendation. Not verified against a running server. |
| **[X]** | External platform or package knowledge from `flutter-stack.md` (pub.dev and docs, fetched 2026-10-08). Not from the Vikunja repo. |

---

## 1. Key facts

### 1.1 Versions and platform baseline

| Item | Value | Evidence |
|---|---|---|
| Latest Vikunja release | v2.7.0 (2026-10-02) | `CHANGELOG.md` [V] |
| `/api/v2` (Huma) introduced | 2.4.0 (2026-07-19) | `CHANGELOG.md:1466,2179` [V] |
| OAuth 2.0 + PKCE server, WebSocket `/api/v1/ws` | 2.3.0 (2026-04-09) | `CHANGELOG.md:2644-2659` [V] |
| Sessions with rotating refresh token, 600 s access JWT | 2.0.0 (2026-02-25) | `CHANGELOG.md:3306-3309`, `pkg/config/config.go:376-378` [V] |
| Projects (not "lists"), object reminders | 0.21.0 | `CHANGELOG.md:8056-8073` [V] |
| Project views, per-view buckets, `filter=` query language | 0.24.0 | `CHANGELOG.md:6476,6773,7242-7254` [V] |
| `right` renamed to `permission` (JSON and header) | 1.0.0-rc0 | `pkg/migration/20250813093602.go` [V]; JSON field rename itself [I] |
| Error codes renumbered (1025→1039, 1026→1040, 4013→4035 on upload, 14001/14002→14011/14012, 1022→1038) | 2.7.0 | `CHANGELOG.md:91,183,271,273,275` [V] |
| Flutter / Dart | 3.47.5 / 3.13.4 | `flutter-stack.md` §0 [X] |
| Minimum OS | iOS 15.0 (app), iOS 17.0 (widget extension); Android minSdk 24, target/compile 36 | `flutter-stack.md` §3.22 [X] |
| Vikunja licence | AGPL-3.0-or-later (server and web frontend) | `LICENSE`, `frontend/package.json:6` [V\*] |

### 1.2 Which servers we can support

| Tier | Server versions | What works | Recommendation |
|---|---|---|---|
| Unsupported | < 0.24 | Lists instead of projects, old filters | Show "Server too old" |
| Legacy | 0.24.x – 1.x | v1 only; password login with long JWT renewed via `POST /user/token` [I]; `right`→`permission` shim below 1.0 [I]; no WebSocket | **Optional**, late step 38, only if Q1 says so |
| Standard | 2.0 – 2.2 | v1; password login; refresh through the cookie endpoint | **Supported (floor)** |
| OAuth | 2.3.x | + PKCE "sign in with browser", `/api/v1/oauth/token`, WebSocket `/api/v1/ws` | Supported |
| Full | ≥ 2.4.0 | + v2 adapter (PATCH, ETag, envelopes, problem+json, Markdown), `/api/v2/ws` | **First-class target** |

Source: `critique.md` §3.1 [V for the dates; I for the tiering]. Gate features on `/info` flags and probes, never on the version string alone: `dev`/`unstable` builds report no semver (`magefile.go:123-147`) [V].

### 1.3 How v1 and v2 differ

Both versions run on the same binary and share `pkg/models`, so **entity JSON field names are identical**. Only the HTTP conventions differ (`.agents/docs/api.md`, `api-v2.md` §0) [V].

| Aspect | v1 (Echo, frozen) | v2 (Huma, ≥ 2.4.0) | Evidence |
|---|---|---|---|
| Create / update | `PUT` create (201), `POST` update = **full replace** | `POST` create (201), `PUT` replace, `PATCH` synthesized by AutoPatch (merge-patch or JSON-patch; empty **304** on no-op) | `pkg/routes/api/v2/huma.go:146-182`, `registry.go:40-47` [V]; 304 [I upstream] |
| List shape | bare array + `x-pagination-total-pages`, `x-pagination-result-count` (no total) | `{items,total,page,per_page,total_pages}`; `items` never null | `pkg/web/handler/read_all.go:113-115`, `pkg/routes/api/v2/types.go:29-75` [V] |
| Paging | `page=0` returns **all rows**; negative `per_page` → 400; search param `s` | `page ≥ 1` (0 → 422); search param `q`; `per_page` silently capped at `max_items_per_page` (default 50) | `pkg/models/models.go:94-99`, `read_all.go:81-89` [V] |
| Permission on reads | header `x-max-permission` | body `max_permission` (projects need `expand=permissions`) | `read_one.go:59`, `types.go:77-103` [V] |
| Errors | `{code,message,i18n_params?}`; validation **412**/2002 with `invalid_fields` | RFC 9457 problem+json + `code`, `errors[]`; validation **422** | `pkg/web/web.go:47-53`, `pkg/routes/api/v2/errors.go` [V] |
| Errors raised before the handler | v1 shape on **both** versions: 401 `{"code":11,…}`, 429 `{"message":…}` | same | `pkg/routes/api_tokens.go:35-68` [V] |
| Conditional reads | none | `ETag: "<updatedUnixNano>-<perm>"`, `If-None-Match` → 304 (not on `GET /projects/{id}`); `If-Match` is **ignored** on writes | `types.go:77-103`, `sync.md` §6 [V] |
| Rich text | HTML only | HTML by default; `?format=markdown` or `X-Vikunja-Format: markdown` (lossy, converts the **whole** field) | `pkg/routes/api/v2/richtext.go` [V] |
| Kanban read | `GET /projects/{p}/views/{v}/tasks` returns `[]Bucket` for kanban views | that path is always flat; board at `…/views/{v}/buckets/tasks` → `{items: Bucket[], total}`; `per_page` applies **per bucket** | `pkg/models/task_collection.go:206-213`, `pkg/routes/api/v2/task_collection.go:209-241` [V] |
| Paths that differ | `/user/logout`, `/user/settings/avatar[/upload]`, `/projects/{p}/projectusers?s=`, `/feeds/notifications.atom` (root, Basic auth) | `/logout`, `/user/settings/avatar/provider` + `PUT /user/settings/avatar`, `/projects/{p}/users/search?q=`, `/api/v2/notifications.atom` | `api-v2.md` §12.2, `pkg/routes/routes.go:257-260,304,360` [V] |

### 1.4 v2-only, v1-only, and neither

- **v2-only:**
  - time tracking (licence `time_tracking`)
  - bulk task create (2.5.0)
  - `pending_email` plus cancel/resend of an email change (2.6.0)
  - Planka migrator (2.6.0)
  - invite links and admin teams (2.7.0, licence `user_invites`)
  - MCP (2.7.0)
  - admin set-password and password-reset email
  - `GET /user/settings/general` (v1 can only write it)
  - historical by-index **307** redirect (2.7.0)
  - AutoPatch, ETag, Markdown exchange, `/api/v2/health`
  - Sources: `api-v2.md` §11–12 [V].
- **On both** (corrections from the critique):
  - sessions and bots (`routes.go:616-617,649-653`)
  - CSV migrator (`pkg/modules/migration/csv/handler.go:34-41`)
  - OAuth, WebSocket, every core resource [V]
- **v1-only:** `/api/v1/metrics`, plugins [V].
- **Neither version has:**
  - a trash or restore route (critique row 15) [V]
  - task-change push events [V]
  - a push service (no FCM, APNs or WebPush code in `pkg/`) [V]
  - idempotency keys [V]
  - a REST listing of deleted tasks (only CalDAV `sync-collection`, `pkg/routes/caldav/sync_collection.go`) [V]

### 1.5 Facts that shape the architecture

1. **Realtime:** the WebSocket emits only `notification.created` and `timer.created|updated|deleted` (`pkg/websocket/connection.go:336-342`) [V]. Web-created tasks reach the phone **only by polling**.
2. **Incremental pull works:** `updated` is filterable and sortable (`task_collection_sort.go:30-56,98-120`). Dates are converted to UTC (`task_collection_filter.go:83-115`) [V].
   - **Hole 1:** tasks of projects that *become* visible (new share, team, un-archive) keep an old `updated` and are missed (critique §3.3).
   - **Hole 2:** `/tasks` excludes archived projects (`pkg/models/project.go:650-652`) [V].
3. **Deletes leave no tombstone.** Tasks are soft-deleted (`pkg/models/tasks.go:147`), but REST shows nothing. Every delete bumps `projects.updated` (`tasks.go:2175`) [V].
4. **Full-replace hazards:**
   - v1 `POST /tasks/{id}` and v2 `PUT` wipe assignees and reminders when they are omitted (`tasks.go:1292-1315,1535-1537`, `task_assignees.go:77-83`) [V].
   - Bulk update does the same, whatever `fields` says (`tasks.go:1700-1706`) [V].
   - v1 project update rewrites `title, is_archived, identifier, hex_color, position` and **cannot clear** a description (`api-v1.md` §6.2) [V].
5. **No optimistic concurrency.** Writes are last-write-wins under a row lock (`tasks.go:1294`) [V]. v2 PATCH merges onto current server state, which gives field-level LWW.
6. **Auth lifetimes:**
   - The access JWT lives 600 s.
   - Refresh tokens rotate on every use, with **no grace period**: an old token returns 16002, a lost race returns 16004 (`pkg/modules/auth/auth.go:408-491`, `pkg/models/sessions.go:127-138,212-229`) [V].
   - OAuth and OIDC sessions are always "short": **72 h idle** (`oauth2server/token.go:145`) [V].
   - Password login with `long_token:true` gets 30 days (`auth_login.go:94`) [V].
7. **Reminders are not pushed.** A server cron stores in-app `task.reminder` notifications and sends optional email (`pkg/models/task_reminder.go:246-392`) [V]. **The app must schedule OS notifications locally** from absolute `reminders[].reminder` instants.
8. **Limits:**
   - The WebSocket upgrade shares the **login** limiter: 10/min/IP, cannot be disabled (`routes.go:491,522`, `config-raw.json`) [V].
   - The refresh limiter is 60/min/IP [V].
   - `/api/*` responses are **never gzipped** by Vikunja (`pkg/routes/static.go:279-284`) [V\*].
9. **Licensed features** (`admin_panel`, `time_tracking`, `audit_logs`, `user_invites`):
   - They appear in `/info.enabled_pro_features` only while licensed.
   - Gated routes return a plain 404 `{"message":"Not Found"}` (`pkg/routes/feature_gate.go:29` returns `echo.ErrNotFound` [V\*]; `pkg/license/license.go:64-85`) [V].
10. **Unknown JSON properties** are probably rejected with 422 on v2 (Huma default; `critique.md` §4.1) [I]. Send only explicitly writable fields.

---

## 2. Recommended architecture

### 2.1 Principles

1. **The local DB is the single source of truth for the UI.** Screens read Drift streams. The network only feeds the DB.
2. **One domain-level API interface, two transport adapters.** The adapter is chosen per operation group from the negotiated **capabilities**, not from a version string.
3. **Every mutation goes through the outbox, even when online.** The UI, notification actions and widgets all share one retry, ordering and conflict path.
4. **Every entry point builds the same object graph** with a Riverpod `ProviderContainer`: the UI isolate, WorkManager/BGTask, the notification-action isolate, and the home_widget callback.
5. **Secrets live only in the Keychain/Keystore.** Extensions and widgets never refresh tokens.
6. **Pure logic lives in pure-Dart packages** and is pinned by test vectors ported from the web frontend's tests.

### 2.2 Packages and layers (Dart pub workspace)

```
 app/ (Flutter)
 ├─ features/*/presentation   screens, widgets (material_ui / cupertino_ui adaptive)
 ├─ features/*/application    Riverpod notifiers, use cases
 ├─ core/repositories         read = Drift streams, write = local tx + outbox op
 ├─ core/sync                 SyncEngine, pullers, reconciler, OutboxSender
 └─ core/platform services    auth/session, notifications, widgets bridge, background, realtime
        │ depends on
 packages/vikunja_api    (pure Dart) VikunjaClient ports → RoutedVikunjaClient → V2 | V1 adapters → dio
 packages/vikunja_logic  (pure Dart) quick-add, filters, dates, positions, colors, checklist, identifiers
 packages/vikunja_domain (pure Dart) entities, TaskChanges, Page<T>, VikunjaFailure, ServerCapabilities
```

Dependency rule: presentation → application → repositories → (DAOs, `vikunja_api` ports). The UI never imports DTOs or adapters.

`vikunja_api` takes an injected `HttpClientAdapter`, so it stays pure Dart. The app passes `NativeAdapter` (Cronet / NSURLSession). Contract tests run with plain `dart test` and the IO adapter against Docker servers [I].

### 2.3 Folder tree (feature-first)

```
vikunja-mobile/                              pub workspace root (workspace: [app, packages/*])
├── analysis_options.yaml                    very_good_analysis + riverpod_lint plugin
├── .github/workflows/{ci,release}.yaml
├── test_servers/
│   ├── docker-compose.yaml                  vikunja/vikunja 2.0.x, 2.3.x, 2.4.x, 2.7.0 (+1.x for "too old")
│   └── seed/                                test-only seeding: users, TOTP, projects, tasks, shares
├── api_spec/vikunja-2.7.0.openapi-3.0.json  from GET /api/v2/openapi-3.0.json of the pinned image
├── editor/                                  TipTap 3.31.x bundle source (pinned package.json)
├── tool/
│   ├── import_web_i18n.dart                 frontend en.json (+ error.* keys) → ARB
│   └── build_editor.sh                      editor/ → app/assets/editor/
├── packages/
│   ├── vikunja_domain/lib/src/
│   │   ├── entities/                        task, reminder, project, project_view, bucket, label, user,
│   │   │                                    team, comment, attachment, relation, notification,
│   │   │                                    saved_filter, share, session, api_token, time_entry
│   │   ├── capabilities/                    server_version, capability, server_capabilities, support_tier
│   │   ├── failures/vikunja_failure.dart
│   │   └── queries/                         task_query, task_changes, page
│   ├── vikunja_api/
│   │   ├── lib/src/
│   │   │   ├── client/                      vikunja_client (ports), routed_vikunja_client, route_table
│   │   │   ├── negotiation/                 url_normalizer, server_probe, capability_detector
│   │   │   ├── transport/                   dio_factory, query_builder, pagination, interceptors/
│   │   │   ├── errors/                      error_normalizer, error_codes (version-aware)
│   │   │   ├── dto/                         shared wire DTOs + codecs (zero date, hex colour)
│   │   │   ├── v1/                          v1_tasks, v1_projects, v1_views, v1_labels, v1_account, …
│   │   │   ├── v2/                          v2_tasks, v2_projects, …, merge_patch, problem_json
│   │   │   ├── auth_protocol/               oauth_pkce, token_endpoint, password_login, set_cookie, jwt_claims
│   │   │   └── realtime/                    ws_protocol, ws_client
│   │   └── test/{unit,contract}/            contract tests run against test_servers
│   └── vikunja_logic/
│       ├── lib/src/{quick_add,subtask_indent,filters,dates}/
│       ├── lib/src/{positions,colors,identifiers,checklist,task_links,notification_text}.dart
│       └── test/golden/                     vectors ported from frontend *.test.ts
└── app/
    ├── android/                             network_security_config.xml, gradle.properties, Glance widget
    ├── ios/
    │   ├── Runner/
    │   ├── VikunjaWidgets/                  WidgetKit + AppIntents (Swift), deployment target 17.0
    │   └── Shared/                          SnapshotStore.swift, OutboxFile.swift, TokenMirror.swift
    ├── assets/editor/                       built TipTap bundle
    ├── lib/
    │   ├── main.dart
    │   ├── bootstrap/                       bootstrap, container, entrypoints (@pragma('vm:entry-point'))
    │   ├── app/                             app, router/, theme/, shell/ (adaptive scaffold), l10n/
    │   ├── core/
    │   │   ├── accounts/                    account_registry, active_account
    │   │   ├── auth/                        session_manager, token_store, refresh_lock, auth_interceptor, server_clock
    │   │   ├── db/                          app_database, tables/, daos/, converters/, schema dumps + migrations
    │   │   ├── repositories/                tasks, projects, labels, users, notifications, saved_filters
    │   │   ├── sync/                        sync_engine, pullers/, reconciler, merge/, triggers,
    │   │   │                                outbox/{dao,coalescer,sender,retry_policy,ops/}
    │   │   ├── realtime/                    realtime_controller
    │   │   ├── notifications/               scheduler, desired_set, channels, actions, ids, activity_notifier
    │   │   ├── widgets_bridge/              widget_configs, snapshot_builder, home_widget_gateway,
    │   │   │                                app_group_outbox_importer
    │   │   ├── background/                  workmanager_setup, background_sync
    │   │   ├── richtext/                    sanitizer, html_view, tiptap_editor, authed_image
    │   │   ├── media/                       cache_manager (DioFileService), avatars
    │   │   ├── security/                    app_lock, privacy_overlay, tls_profile
    │   │   └── telemetry/                   log, redaction, diagnostics_export
    │   └── features/                        each: application/ + presentation/ (+ data/ for online-only resources)
    │       ├── onboarding/                  server_select, sign_in, register, password_reset, link_share_guest
    │       ├── home/                        overview, upcoming
    │       ├── projects/                    tree, project_screen, project_settings, views_management
    │       ├── list_view/  kanban/  table_view/  timeline/
    │       ├── task_detail/                 sections/, sheets/ (dates, reminders, repeat, labels, assignees, relations)
    │       ├── composer/                    quick-add sheet, share-target entry
    │       ├── search/  filters/            filter builder, saved filters ("smart lists")
    │       ├── comments/  attachments/  labels/  teams/  sharing/  inbox/
    │       ├── settings/                    general, profile, security, integrations, data, app
    │       └── time_tracking/  admin/  about/
    ├── test/                                unit + widget tests (mirror lib/)
    └── integration_test/                    patrol E2E against test_servers
```

### 2.4 API abstraction: one domain interface, v1 and v2 underneath

**Negotiation** (at login, every 24 h, on app update, and after a "route absent" 404):

1. **Normalise the URL.**
   - Default the scheme to `https://`.
   - Strip a trailing `/`, `/api/v1` or `/api/v2`, and keep any sub-path.
   - Same rules as `frontend/src/helpers/apiUrl.ts` and `checkAndSetApiUrl.ts` [V].
2. **Probe `GET {root}/api/v2/info`.** Accept it only if the response is 200, JSON, and has a string `version`. Otherwise probe `GET {root}/api/v1/info`. Otherwise retry both on port **3456**.
   - If the answer is HTML or a 302 to an IdP, report "server is behind a login proxy" and point to custom headers (step 35).
   - Sources: `api-v2.md` §10, `critique.md` §3.8 [V/I].
3. **Parse `version` leniently.** Strip `v`, drop a `-N-gHASH` suffix, and treat `dev`/`unstable` as latest.
4. **Build `ServerCapabilities`** from:
   - version thresholds;
   - `/info` flags: `link_sharing_enabled`, `task_attachments_enabled`, `task_comments_enabled`, `totp_enabled`, `caldav_enabled`, `webhooks_enabled`, `public_teams_enabled`, `user_deletion_enabled`, `email_reminders_enabled`, `auth.*`, `enabled_background_providers`, `available_migrators`, `max_items_per_page`, `max_file_size` (a raw string such as `"20MB"`; parse it with base 1024), `frontend_url` (ends with `/`), `concurrent_writes` (missing means unknown, so serialize writes);
   - licence features from `enabled_pro_features`;
   - Sources: `pkg/routes/api/shared/info.go:36-175`, `critique.md` row 10 [V].

```dart
enum Capability {
  apiV2, oauthPkce, sessionRefresh, websocket, autoPatch, etag, markdownExchange,
  bulkCreateTasks, pendingEmail, byIndexRedirect, inviteLinks, timeTracking, adminPanel,
  linkSharing, attachments, comments, totp, caldav, webhooks, publicTeams, registration,
  userDeletion, emailReminders, backgroundUpload, backgroundUnsplash,
}

enum ApiGroup { tasks, projects, views, buckets, labels, comments, attachments, sharing,
  teams, notifications, account, filters, timeTracking, admin }

abstract interface class VikunjaClient {
  ServerCapabilities get capabilities;
  TasksPort get tasks;
  ProjectsPort get projects;
  ViewsPort get views;
  LabelsPort get labels;
  CommentsPort get comments;
  AttachmentsPort get attachments;
  SharingPort get sharing;
  TeamsPort get teams;
  NotificationsPort get notifications;
  AccountPort get account;
  TimeTrackingPort? get timeTracking;
  AdminPort? get admin;
}

abstract interface class TasksPort {
  Future<Page<Task>> list(TaskQuery query);
  Future<Conditional<Task>> read(int id, {Set<TaskExpand> expand, String? ifNoneMatch});
  Future<Task> create(int projectId, NewTask task);
  Future<List<Task>> createMany(int projectId, List<NewTask> tasks);
  Future<Task> update(int id, TaskChanges changes);
  Future<void> delete(int id);
  Future<void> markRead(int id);
  Future<TaskPosition> setPosition(int id, {required int viewId, required double position});
  Future<TaskBucket> moveToBucket(int taskId, {required int projectId, required int viewId, required int bucketId});
}

final class RoutedVikunjaClient implements VikunjaClient {
  RoutedVikunjaClient(this.capabilities, this._v1, this._v2);

  @override
  final ServerCapabilities capabilities;
  final V1Adapter _v1;
  final V2Adapter? _v2;
  final Set<ApiGroup> _downgraded = {};

  T _route<T>(ApiGroup group, T v1, T? v2) =>
      v2 != null && capabilities.has(Capability.apiV2) && !_downgraded.contains(group) ? v2 : v1;

  void markRouteAbsent(ApiGroup group) => _downgraded.add(group);

  @override
  TasksPort get tasks => _route(ApiGroup.tasks, _v1.tasks, _v2?.tasks);
  // other ports follow the same pattern; timeTracking/admin return null unless licensed
}
```

**Routing rules** [I]:
- v2 wins whenever it exists. It gives PATCH (no full-replace hazard), totals, ETag and problem+json.
- A 404 **without** a Vikunja `code` on a core group means the route is absent, so no handler ran. Downgrade that group to v1 and re-send; this is safe even for writes.
- On licence-gated groups the same 404 means `FeatureUnavailable`.
- v2-only operations have no v1 fallback. `createMany` degrades to sequential creates; everything else hides its UI.

**Per-operation mapping** (adapters, [V] paths from `api-v1.md` §3 and `api-v2.md` §5):

| Domain op | v2 adapter | v1 adapter | Notes |
|---|---|---|---|
| list tasks | `GET /tasks`, `/projects/{p}/tasks`, `/projects/{p}/views/{v}/tasks` | same paths; `s` instead of `q`; totals via headers (`per_page=1` → `x-pagination-total-pages` = count) | always build queries with `Uri(queryParameters:)`, since filters contain `&&` (critique §3.3.6) |
| kanban board | `GET …/views/{v}/buckets/tasks?per_page=25` | `GET …/views/{v}/tasks` (polymorphic) | more of one bucket: `filter=bucket_id = N&page=k&sort_by=position` |
| create task | `POST /projects/{p}/tasks` | `PUT /projects/{p}/tasks` | labels in the body are ignored, so add them separately; v1 applies `assignees` |
| update task | `PATCH /tasks/{id}`, `application/merge-patch+json`, **changed fields only** | `GET /tasks/{id}` → overlay changes → `POST /tasks/{id}` with the full object | v1 must round-trip `assignees` and `reminders` |
| mark done | `PATCH {"done":true}` | GET + POST | **apply the response**: repeating tasks come back `done:false` with shifted dates |
| bulk create | `POST /projects/{p}/tasks/bulk` (≤100, atomic, 2.5.0+) | sequential creates | the web submits the last chunk first |
| bulk update | **never used** for tasks with assignees or reminders | same | critique row 12 |
| delete task | `DELETE /tasks/{id}` (204) | `DELETE` (200 message) | 404/4002 counts as success |
| labels / assignees / relations | `POST`/`DELETE` | `PUT`/`DELETE` | treat 8001 / 4021 / 4008 as success |
| bucket move / position / mark read | `PUT` | `POST` | done-bucket rules are server-side |
| user settings | `PATCH /user/settings/general` (merge-patch, changed keys only, including only changed `frontend_settings` keys; 304 = unchanged) | `GET /user` → overlay → `POST /user/settings/general` (full replace) | `client-logic.md` §16 |
| project update | `PATCH /projects/{id}` | full round-trip `POST /projects/{id}` | v1 cannot clear a description |
| refresh (OAuth) | `POST /api/v2/oauth/token` (form or JSON) | `POST /api/v1/oauth/token` (JSON) on 2.3.x | `auth.md` §4.3 |

**Wire DTOs** [I]:
- Use one hand-written freezed/json_serializable DTO set shared by both adapters, because the server models are identical.
- Write bodies come from explicit allow-lists. The task allow-list is `title, description, done, due_date, start_date, end_date, priority, hex_color, percent_done, repeat_after, repeat_mode, is_favorite, project_id, reminders, cover_image_attachment_id` (`frontend/src/client/queries/taskMutations.ts`, `client-logic.md` §12) [V].
- Codecs:
  - year ≤ 1 ↔ `null`; clear a date with `"0001-01-01T00:00:00Z"`;
  - `hex_color` without `#`;
  - `null` empty arrays parse as `[]`;
  - RFC3339 with offset is parsed to UTC.
- **Contract test:** every DTO field must exist in the committed `api_spec/vikunja-2.7.0.openapi-3.0.json`, and every write field must be non-readOnly.
- I chose this over swagger_parser + retrofit codegen (the `flutter-stack.md` proposal) for three reasons: one DTO set serves both versions, v1 needs hand-written code anyway, and we use about 70 of the 216 operations. Revisit if v2 grows faster than we can follow.

**Error model** [V shapes; I mapping]:

```dart
sealed class VikunjaFailure {
  const VikunjaFailure();
}
final class NetworkFailure extends VikunjaFailure { /* offline | timeout | tls */ }
final class TokenRejected extends VikunjaFailure { /* 401 code 11 */ }
final class SessionDead extends VikunjaFailure { /* 16002/16003/16005 after re-read, 412 1020/1040 */ }
final class Forbidden extends VikunjaFailure { /* 403, optional code */ }
final class NotFound extends VikunjaFailure { /* code == null → route absent */ }
final class ValidationFailed extends VikunjaFailure { /* v1 412 invalid_fields, v2 422 errors[].location */ }
final class Conflict extends VikunjaFailure {}
final class RateLimited extends VikunjaFailure { /* Retry-After */ }
final class FeatureUnavailable extends VikunjaFailure {}
final class ServerFailure extends VikunjaFailure {}
final class DomainError extends VikunjaFailure { /* code, detail ?? message, i18n_params */ }
```

- **Code map by server version.** On servers < 2.7.0, map 1026→1040, 1025→1039, 4013-on-upload→4035, 14001/14002→14011/14012, 1022→1038 (`critique.md` §3.2) [V].
- **Localisation.** Translate on the client with `error.<code>` keys imported from `frontend/src/i18n/lang/en.json` (108 keys). The web appends the server message for 4016–4019 and 4024 (`frontend/src/message/index.ts:12-20`) [V].

### 2.5 Auth and session manager

**Account types:**
- `oauth` (≥ 2.3)
- `password` (local or LDAP, `long_token:true`)
- `apiToken` (`tk_…`)
- `linkShare` (step 32)
- `legacyJwt` (< 2.0, only with step 38)

**Sign in with browser** (`auth.md` §7) [V contract; I client]:
1. Read `frontend_url` from `/info`.
2. Create a 32-byte base64url verifier, its S256 challenge and a random `state`.
3. Open `{frontend_url}oauth/authorize?response_type=code&client_id=<app>&redirect_uri=vikunja-<app>://callback&state=…&code_challenge=…&code_challenge_method=S256` through `flutter_web_auth_2`. Do not use an ephemeral session, so an existing web login is reused.
4. Check `state`.
5. Exchange the code at `POST /api/v2/oauth/token`, or `/api/v1/oauth/token` with JSON on 2.3.x.

Server rules:
- The redirect scheme must start with `vikunja-` (`pkg/modules/auth/oauth2server/client.go:38`) [V\*].
- The code is single-use and lives 10 min.
- The desktop app uses `vikunja-desktop`, so we must not (`desktop/oauth.js:4-5`) [V\*].
- **OIDC, LDAP and TOTP all work through this one flow.** No native OIDC is needed on ≥ 2.3.

**Password login** (`auth.md` §6, §15.1):
1. `POST /api/v{2|1}/login {username,password,totp_passcode?,long_token:true}`.
2. A 412/1017 with no passcode sent means a TOTP step is needed.
3. Read `vikunja_refresh_token` from `Set-Cookie` (dio list headers).
4. Refresh:
   - **≥ 2.3:** switch to `/oauth/token` with `grant_type=refresh_token`; it is the same session table (critique row 3).
   - **2.0–2.2:** send `Cookie: vikunja_refresh_token=…` to `/api/v1/user/token/refresh` and re-parse `Set-Cookie` on every response.
5. Send `User-Agent: Vikunja-Flutter/<ver> (<OS> <ver>; <model>)` so `/user/sessions` is readable.

**API-token accounts:**
- Never refresh.
- A 401 code 11 means revoked, expired or **out of scope**, not "refresh me" (critique row 2).
- Validate the token with `GET /token/test`.
- Show the limits: no WebSocket, no subscriptions, no user settings (`auth.md` §9).

**Token storage:** `flutter_secure_storage` with:
- iOS `KeychainAccessibility.first_unlock_this_device`, `synchronizable:false`;
- a keychain access group, used only to mirror the **access** token for the iOS widget intent;
- on Android, Auto Backup excluded.

**Refresh algorithm** (`auth.md` §5, §15.3–15.4; critique §5) [I]:
- **Proactive:** refresh when `exp − serverNow < 60 s`, with `serverClockOffset = iat − localNow` taken at issue time.
- **Reactive:** on 401 code 11 for user-JWT accounts, refresh once and retry once.
- **Concurrency:** single-flight per isolate, plus a per-account exclusive file lock (`RandomAccessFile.lock`) across isolates. Under the lock:
  1. Re-read the stored refresh token.
  2. If it changed, adopt it.
  3. Otherwise call the server.
  4. **Persist the rotated refresh token before using the new access token.**
  5. Bump the auth epoch, then release.
- Make the refresh call non-cancellable with a generous timeout.
- **Failure classes:**

  | Failure | Action |
  |---|---|
  | network | keep tokens |
  | 5xx | retry once |
  | 429 | wait for `Retry-After` (cap 10 min) |
  | 16002 or 16004 | re-read storage, then declare the session dead only if the stored token is unchanged |
  | 16003, 16005, 412 1020/1040 | session dead |

- A dead session sets `needsReauth`: keep local data, pause the outbox and post "Sign in again".
- **Keep-alive:** background work refreshes at least every ~24 h, because OAuth sessions die after 72 h idle.
- Our own password change, password reset or TOTP enable kills **all** sessions, including ours (`auth.md` §4.4). Start the login flow immediately.
- **Logout:**
  1. Ensure a valid token.
  2. Best-effort `POST /api/v2/logout` (v1: `/api/v1/user/logout`).
  3. Wipe the account DB file, secure entries, scheduled notifications and widget snapshots; close the WebSocket; bump the epoch.

### 2.6 Offline-first data layer (Drift)

- **One SQLite file per account** at `<appSupport>/accounts/<accountId>/vikunja.db` (WAL).
  - `accountId = sha256(serverRoot | userId)`.
  - Open it with `driftDatabase(native: DriftNativeOptions(shareAcrossIsolates: true, databasePath: …))`. The UI, WorkManager and notification-action isolates then share one DB server isolate [X].
  - Logout means deleting the file.
  - **Never** put it in the iOS App Group container (0xdead10cc) [X].
- The **account registry** (accounts, server root, capabilities JSON, active account) lives in `shared_preferences`. Secrets go to secure storage.
- **Tables:** sync.md §9.2, adapted for one file per account.

  | Table | Contents |
  |---|---|
  | `project` | Real projects only; `max_permission`, `is_archived`, `updated` |
  | `saved_filter` | Pseudo projects ≤ −2 (`id = −filterId − 1`); never mixed into `project` |
  | `project_view` | Views, including `filter` and `bucket_configuration` |
  | `bucket`, `task_bucket`, `task_position` | Per-view state |
  | `task` | `local_id` (stable PK), `server_id` (nullable), all scalar fields, `base_json`, `dirty_fields`, `sync_status` (`synced`, `pending_create`, `pending_update`, `pending_delete`, `conflict`, `create_uncertain`) |
  | `task_reminder` | `reminder_utc`, `relative_to`, `relative_period` |
  | `task_label`, `task_assignee`, `task_relation`, `attachment`, `comment` | `comment` is lazy, per task |
  | `label`, `user`, `notification` | |
  | `view_member`, `saved_filter_member` | Cached server membership for filters the local compiler cannot evaluate |
  | `outbox` | Operations to send |
  | `sync_state` | Watermarks per scope |
  | `scheduled_notif` | Notifications handed to the OS |
  | `conflict` | Losing description text |
  | `task_fts` | FTS5 over title and plain-text description, for offline search [X: FTS5 is in the default sqlite3 build] |

- **Migrations:** drift schema dumps plus generated migration tests from the first schema onwards.

### 2.7 Outbox and write pipeline

Source: `sync.md` §9.4, with the critique fixes applied.

**Local write.** One transaction updates the row, sets `dirty_fields` and appends an outbox op `{uuid, entity, entity_local_id, op, payload, base_updated}`. The UI is optimistic.

**Coalescing:**

| Ops in the outbox | Sent as |
|---|---|
| patch + patch | one patch with the union of fields |
| create + patch | create with the merged fields |
| create + delete | nothing (both dropped) |
| patch + delete | delete |

**Sending:**
- Send **serially, FIFO per account**. This is required when `concurrent_writes` is false or missing, and simplest everywhere.
- Ops that depend on a pending create wait for its `server_id`. References resolve `local_id → server_id` at send time.

**Retry:**

| Result | Handling |
|---|---|
| network, 5xx or 429 | exponential backoff from 2 s to 15 min with jitter; honour `Retry-After` and `X-RateLimit-Reset` |
| `TokenRejected` | refresh path (§2.5) |
| `SessionDead` | pause; **never drop ops** |
| idempotent-ish errors (8001, 4021, 4008, delete 404/4002) | success |
| permanent errors (3001, 7003, 3008 archived, 4001, filter errors) | mark the op `failed`, flag the entity and show it in a "Sync problems" list |

**Uncertain create** (timeout after the request was sent):
- Mark the task `create_uncertain`.
- Look it up with `filter=created >= '<sentAt−60s>' && created_by = '<me>'` on that project, then match the title client-side (critique §3.3.7).
- Re-send only if no match is found.

**Rich text:** never send `X-Vikunja-Format` or `format=markdown` unless the description itself changed. The app stores HTML canonically (critique row 13).

After the outbox drains, run an incremental pull so server-computed fields arrive (`done_at`, repeat shifts, relative reminders, `index`, `identifier`).

### 2.8 Sync engine

**Initial sync** (foreground, with progress, resumable from `sync_state`):
1. `info`, then `GET /user` (settings embedded).
2. All project pages (`is_archived=true`, `expand=permissions` on v2), then all labels, then notifications page 1.
3. Tasks, keyset by id: `filter=done = false && id > X`, then `done = true && id > X`, with `sort_by=id&per_page=<max>`.
4. Archived projects through `/projects/{id}/tasks`.
5. Set the watermark `W = max(updated)` in server time.

**Incremental sync** (every trigger):
1. Make sure the token is fresh.
2. **Projects:** pull all pages and **de-duplicate pseudo projects, which repeat on every page** (`pkg/models/project.go:286-298`) [V]. Then:
   - missing ids → purge locally;
   - **new or newly un-archived ids → full keyset pull of `/projects/{id}/tasks`**, which closes hole 1;
   - a changed `updated` → mark for the count check.
3. **Tasks delta**, keyset on `(updated, id)`:
   - `filter=(updated > 'W') || (updated = 'W' && id > lastId)&sort_by=updated&sort_by=id&order_by=asc&order_by=asc`, starting from **W − 120 s** to cover async `updated` bumps.
   - Changed archived projects use the same filter on `/projects/{id}/tasks`.
4. **Deletes:**
   - For each changed project, `per_page=1` gives the total (v2 `total`, v1 `x-pagination-total-pages`). Compare it with the local synced count.
   - On a mismatch, reconcile ids keyset by id. `id in …` chunks must stay under 16 KiB.
   - Run a full reconcile every 24 h, in the foreground or while charging.
   - A 404/4002 on a single read means the task was deleted.
5. **Labels:** full pull. **Notifications:** pull until a known id appears. **User and settings:** `GET /user`.
6. **On demand only:** kanban buckets and positions, comments, attachments, reactions. These do not bump `tasks.updated` (`sync.md` §2.4).
7. **Merge:**
   - A `synced` row is overwritten and its `base_json` replaced.
   - A dirty row gets a per-field 3-way merge: remote-only changes apply, local-only changes stay dirty, and when both changed the latest wins. For `description`, the losing text goes to `conflict` and the user decides.
8. **Post-sync hooks:** notification scheduler diff (§2.10) and widget snapshot rebuild (§2.11).

**Cheap probe**: `GET /tasks?filter=updated > 'W'&per_page=1` plus a project-list fingerprint, about 2 requests.

**Transport hygiene:**
- Send `Accept-Encoding: gzip` (proxies may compress).
- Keep `expand` minimal; never use `expand=comments` in sync.
- Send filter dates as UTC `Z` strings.
- Pass `filter_timezone = settings.timezone` only for datemath.

**Triggers** [X for OS limits]:

| Trigger | Action |
|---|---|
| App start / resume | incremental sync, drain outbox |
| Foreground timer (30–60 s) | cheap probe → incremental if changed |
| WebSocket `notification.created` | debounced (1–2 s) incremental sync; for `task.comment` also refresh that task's comments |
| Pull-to-refresh | incremental + on-screen kanban/comments |
| After outbox drain / local action | incremental |
| Android WorkManager periodic (≥ 15 min, network constraint) | probe → delta, keep-alive refresh, activity notifications |
| Android expedited one-off | drain after notification or widget action |
| iOS `BGAppRefreshTask` (opportunistic, ~30 s) | probe + small delta |
| iOS `BGProcessingTask` (overnight, charging) | full reconcile |

### 2.9 Realtime (WebSocket)

Sources: `auth.md` §14, `sync.md` §1, critique row 6.

- Connect **only in the foreground**: `/api/v2/ws` on v2, otherwise `/api/v1/ws` (≥ 2.3).
- Only user-JWT accounts can connect. API tokens and link shares cannot.
- **Handshake:**
  1. Refresh first if `exp` is within 5 s (expired JWTs are rejected).
  2. Send `{"action":"auth","token":…}` within 30 s.
  3. Subscribe to `notification.created`, plus `timer.*` when licensed.
  4. After every token refresh, re-send `auth` with the same `sid`.
- **Close and error handling:**

  | Signal | Handling |
  |---|---|
  | `invalid_token` / `auth_required` | terminal: stop and poll instead |
  | 1013 | reconnect |
  | 1008 "session revoked" | `needsReauth` |

- **Reconnect:** backoff 1 s → 30 s, ±25 % jitter, and **at most ~5 upgrades per minute**, because the upgrade shares the 10/min/IP login limiter.
- After every (re)connect, run an incremental sync. Events are in-memory, single-node, and dropped when the 64-message buffer is full (`pkg/events/events.go:36-39`, `hub.go:97-101`) [V]. **Never treat the socket as a source of truth.**

### 2.10 Notification scheduler

Sources: `sync.md` §9.7, `flutter-stack.md` §3.10, `critique.md` §3.9 [I/X].

**Desired set**, computed from the DB only:
- absolute `reminder_utc > now` reminders;
- due-date notifications per app setting (the server has none);
- an optional daily overdue digest at `overdue_tasks_reminders_time` (the server only emails it);
- restricted to undone tasks that are not `pending_delete`;
- scope policy (Q7): default is tasks where I am the creator or an assignee, which matches the server's recipients minus subscribers.

**Diff, don't rebuild:**
- Compare the desired set with `scheduled_notif` and cancel or schedule only the difference.
- IDs are deterministic 31-bit hashes of `(accountId, taskId, kind, instant)`.
- Keep a rolling window: **iOS ≤ 60 pending** (the OS keeps 64), Android ≤ 200 (the limit is 500 alarms per uid).
- Run the diff after sync, local edits, boot (`RECEIVE_BOOT_COMPLETED`), time-zone changes, resume and background runs.
- Never fire reminders that are already past at first sync.
- Group per project (`threadIdentifier` / `groupKey`) with a summary notification.

**Channels and categories:**
- Android channels: Reminders, Due dates, Activity, Sync problems. Importance is fixed once a channel is created.
- **Register the iOS categories and Android actions in every isolate at every init.**
- iOS reminders use the Time Sensitive interruption level, which needs the entitlement.

**Actions:**

| Action | Behaviour |
|---|---|
| **Mark done** | Runs in the background: no `foreground` option on iOS, `showsUserInterface:false` on Android |
| **Snooze 10 min / 1 h** | Local reschedule; optionally persisted as a new absolute reminder through PATCH |
| Tap | Opens the deep link `vikunja-<app>://task/<id>` |

**Mark-done handler** (top-level `@pragma('vm:entry-point')`):
1. Build the container and open the shared DB.
2. Mark the task done locally and add an outbox op.
3. Cancel the task's sibling notifications.
4. Try the call right away: v2 PATCH, or v1 GET + POST.
5. Apply the response. A repeating task comes back reopened, so reschedule it.
6. Rebuild the widget snapshot.
7. On Android, also enqueue an expedited drain.

**Permissions:**
- Android 13+: request `POST_NOTIFICATIONS`.
- Exact alarms are opt-in (`SCHEDULE_EXACT_ALARM`, denied by default on Android 14+). Otherwise use `inexactAllowWhileIdle`.

**Server notifications:**
- New `notification` rows (`task.comment`, `task.assigned`, `task.mentioned`, `task.created`, `task.deleted`, `project.created`, `team.member.added`) become OS notifications on the **Activity** channel when they arrive in a background pull.
- Skip `task.reminder` rows, because the local scheduler already covers them.
- De-duplicate foreground socket reminders by task id within ±2 min.

### 2.11 Widget bridge

**Snapshot builder** (Dart, runs in the UI or background isolate after each sync, local mutation or midnight tick):
- Builds compact JSON per widget configuration: items with title, identifier, due instant, project colour, flags and deep link.
- Includes ~48 h of upcoming items so iOS timelines can roll "today → overdue" without the app.
- Written with `HomeWidget.saveWidgetData`/`saveFile`, followed by `updateWidget`.

**Configurations:** Today (overdue + due today), Upcoming N days, Overdue, Project (with sub-projects), Label, Favorites, Saved filter (cached membership), Quick-add button.

**Android** [X]:
- Glance widget with a configuration activity.
- Mark done goes through `HomeWidgetBackgroundIntent` → Dart callback → outbox + snapshot.
- Fallback when the callback fails after the app was killed (home_widget #318): open the app through a deep link.

**iOS** [X]:
- WidgetKit extension (iOS 17.0) in SwiftUI, with `AppIntentConfiguration` whose entities come from App Group defaults.
- Mark done is a **native Swift AppIntent** that:
  1. updates the snapshot JSON;
  2. appends to an App Group outbox file (JSON lines with op uuid);
  3. best-effort calls `PATCH /api/v2/tasks/{id} {"done":true}` with the mirrored access token, **only if `exp > now + 30 s`** — it never refreshes;
  4. reloads timelines.
- The app imports the App Group outbox on its next run and de-duplicates by uuid.
- **The extension never opens SQLite.**

### 2.12 Background execution

- workmanager 0.10.10 [X]:
  - Android: a periodic `sync` task (15 min, network constraint) and an expedited one-off `drain` task.
  - iOS: BGAppRefresh and BGProcessing identifiers in `Info.plist`.
  - Under UIScene, call `WorkmanagerPlugin.registerLaunchHandlers()` and register the plugin-registrant callbacks.
- iOS runs get about 30 s: probe, then a small delta. Never start a token refresh with less than ~10 s left.
- Background runs refresh only when the stored access token is about to expire.

### 2.13 Rich text

- **Render** natively with `flutter_widget_from_html_core`, behind a sanitizer allow-list of TipTap node types. Custom factories handle:
  - checklists `ul[data-type=taskList] > li[data-checked]` (tap toggles the attribute, then PATCH the description HTML);
  - `mention-user` pills;
  - task-link pills (deep links; parse rules from `frontend/src/helpers/parseTaskIdFromUrl.ts`);
  - authenticated inline images matching `^(.*?)(?:/api/v[12])?/tasks/(\d+)/attachments/(\d+)$` (`client-logic.md` §13) [V].
- **Edit** in a bundled TipTap 3.31.x editor, with the same extensions as `frontend/src/components/input/editor/editorExtensions.ts`, inside `webview_flutter`.
  - Load it from assets with no remote content; HTML goes in and out over a JavaScript channel.
  - Keep `data-task-id` on checklist items.
  - This is the only lossless option against both API versions [I].

### 2.14 Cross-cutting

- **i18n:** gen-l10n ARB. Seed it from the web's `en.json` and its 32 enabled locales (AGPL, see Q3). Quick-add grammar stays English, as on the web.
- **Accessibility:**
  - Every swipe and drag gets a `Semantics` custom action ("Mark done", "Move to bucket…").
  - Text scales to 200 %.
  - Label contrast follows `getTextColor` (`client-logic.md` §6); priority and overdue are never shown by colour alone.
  - RTL works for `ar-SA`, `he-IL` and `fa-IR`.
- **Theming:** material_ui with `.adaptive` widgets and cupertino_ui sheets on iOS; dynamic_color on Android; `frontend_settings.color_schema`.
- **Deep links:** `vikunja-<app>://task/<id>` and `…/project/<id>`.
  - Pasted or QR web URLs are parsed: `/tasks/<id>`, `/share/<hash>/auth`.
  - `PROJ-12` resolves through by-index; on v2 ≥ 2.7, follow the 307.
- **Logging:** `logging` with a ring buffer and a rotating file. Redaction drops `Authorization`, `Cookie`, `Set-Cookie`, OAuth codes, tokens and optionally titles. A "share diagnostics" action exports the log.
- **Tablets:** `NavigationRail` with a list-detail layout at ≥ 600 dp.

---

## 3. Technology choices

Versions are from pub.dev on 2026-10-08 (`flutter-stack.md` §2 and Appendix A) [X].

| Area | Package | Version | Why (main alternative and why it lost) |
|---|---|---|---|
| SDK | Flutter / Dart | 3.47.5 / 3.13.4 | Current stable. The iOS 15 floor comes from the template. |
| Design system | material_ui + cupertino_ui | 1.6.0 / 1.1.2 | New codebase. The in-SDK Material library is scheduled for deprecation (Nov 2026), so start on the new packages. |
| State / DI | flutter_riverpod + riverpod_annotation + riverpod_generator (+ riverpod_lint plugin) | 3.4.3 / 4.0.7 / 4.0.9 (3.1.9) | DI and state in one. `ProviderContainer` works in headless isolates. Bloc needs get_it and has no headless story. |
| Local DB | drift + drift_dev + drift_flutter + sqlite3 (build hooks) | 2.35.2 / 2.35.1 / 0.3.1 / 3.7.0 | Typed SQL, streams, migrations, `shareAcrossIsolates`, FTS5. Isar is abandoned; ObjectBox has weak relational queries. |
| HTTP | dio + native_dio_adapter (cronet_http 1.10.0 / cupertino_http 3.1.0) | 5.11.1 / 1.8.0 | Interceptors. Cronet honours user CAs on Android, which dart:io does not (sdk#50435). Per-server switch to `IOHttpClientAdapter` for pinned or mTLS servers. |
| Models | freezed + freezed_annotation + json_serializable + json_annotation + build_runner | 4.0.2 / 3.1.0 / 6.14.1 / 4.12.0 / 2.16.2 | Verified to run in one build_runner pass. |
| API client | **hand-written** v1 + v2 adapters over a shared DTO set; OpenAPI spec used for contract tests | — | See §2.4. swagger_parser 1.45.0 + retrofit 4.10.0 are the documented fallback. |
| Routing / links | go_router (+ go_router_builder), app_links | 18.0.2 (4.5.0), 7.2.2 | flutter.dev-owned, material_ui-native, `StatefulShellRoute`. |
| Secure storage | flutter_secure_storage | 11.2.0 | Keychain/Keystore. Must set `first_unlock_this_device`; the default `unlocked` breaks background isolates. |
| Auth UI | flutter_web_auth_2 (+ crypto for PKCE) | 5.1.0 (3.0.7) | ASWebAuthenticationSession / Custom Tabs. flutter_appauth needs a discovery document Vikunja does not have. |
| Background | workmanager | 0.10.10 | Android WorkManager plus iOS BGTaskScheduler. Recent Android 16 fixes. |
| Notifications | flutter_local_notifications + timezone + flutter_timezone | 22.3.1 / 0.11.1 / 5.1.1 | Background action isolate, exact/inexact modes, Darwin categories. awesome_notifications is CocoaPods-only. |
| Widgets | home_widget (+ home_widget_cli optional) | 0.10.0 (0.4.0+1) | Glance plus WidgetKit, configurable and interactive. iOS mark-done implemented natively in Swift. |
| HTML render | flutter_widget_from_html_core | 0.17.4 | Maintained, 160 points. flutter_html does not compile on current Flutter. |
| HTML edit | webview_flutter + bundled TipTap 3.31.x | 4.14.1 | Lossless round-trip. Quill/Fleather convert lossily; AppFlowy and SuperEditor do not compile. |
| Images / files | cached_network_image + flutter_cache_manager (DioFileService); file_picker; image_picker; share_plus; url_launcher | 4.0.4 / 3.4.5; 13.1.0; 1.2.4; 13.3.1; 6.3.3 | Authenticated image fetch through the same dio. `cacheKey = url`, so rotating JWTs do not bust the cache. |
| Theming | dynamic_color | 2.1.0 | material_ui-native. |
| App lock | local_auth | 3.0.2 | Biometrics plus a privacy overlay. |
| Prefs / misc | shared_preferences, path_provider, package_info_plus, uuid, collection | 2.5.6 / 2.1.6 / 10.2.2 / 4.6.0 / 1.19.1 | Non-secret settings; outbox op ids. |
| UI helpers | flutter_slidable, skeletonizer | 4.0.3 / 3.0.0 | Swipe actions, loading states. |
| Later / optional | kalender, two_dimensional_scrollables, flutter_markdown_plus | 0.33.0 / 0.5.5 / 1.0.12 | Agenda/calendar; table and timeline grids; Markdown only if Q8 picks Markdown. |
| i18n | gen-l10n + intl | 0.20.3 | ARB pipeline. slang would be the alternative for reusing the web JSON directly. |
| Logging | logging | 1.3.0 | Local, redacted. sentry_flutter 9.x fails to resolve (jni pin). Optional self-hosted Sentry/GlitchTip once 10.x is stable (Q12). |
| Lints | very_good_analysis | 11.0.0 | Disable `public_member_api_docs`. riverpod_lint runs as an analysis_server_plugin. |
| Tests | flutter_test, mocktail, patrol + patrol_cli, alchemist (optional) | —, 1.0.5, 4.10.0 / 4.8.0, 0.14.1 | Patrol drives the notification shade, permission dialogs and the auth sheet. |
| CI/CD | GitHub Actions (subosito/flutter-action v2.23.0), fastlane 2.240.1, Docker `vikunja/vikunja:<ver>` service containers | — | Open-source friendly. The version matrix runs in CI. |

**Not adopted:**
- connectivity_plus 7.3.2: dbus conflict with flutter_local_notifications; use request failures and WorkManager constraints instead.
- sentry_flutter 9.x, flutter_quill, flutter_appauth, isar, awesome_notifications, flutter_html, open_filex.

**Required native configuration** [X]:
- **Android:**
  - `android.uniquePackageNames=false` (Cronet namespace clash, dart-lang/http#1932)
  - core library desugaring (`desugar_jdk_libs:2.1.4`)
  - `buildFeatures.compose = true` (Glance)
  - `network_security_config.xml` trusting system + user CAs, with cleartext only per opted-in host
  - `MainActivity : FlutterFragmentActivity`
  - permissions `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, `USE_BIOMETRIC`
  - backup exclusion
- **iOS:**
  - App Group and Keychain group on Runner and the widget extension
  - `UIBackgroundModes` fetch/processing and `BGTaskSchedulerPermittedIdentifiers`
  - `NSLocalNetworkUsageDescription` + `NSAllowsLocalNetworking`
  - `NSFaceIDUsageDescription`
  - Time Sensitive entitlement
  - `PrivacyInfo.xcprivacy` for the app and the extension
  - UIScene launch-handler registration

---

## 4. Roadmap: small, individually reviewable increments

**Review protocol:**
- Each step is one branch and one PR.
- Each PR comes with screenshots or a screen recording, a green CI run (including the server-version contract matrix when the API is touched), a "decisions taken" list, and the open follow-ups.
- The next step starts only after you approve.

**Sizes** [I]:

| Size | Effort | Diff |
|---|---|---|
| S | ≈ 1–2 engineer-days | < 600 changed lines |
| M | ≈ 3–5 days | |
| L | ≈ 6–10 days | split further if it grows |

**Definition of done for every step:**
- `flutter analyze` is clean.
- New logic has unit and widget tests.
- The UI works in dark mode and at 200 % text scale.
- New interactive elements have semantics.
- Strings are in ARB (en + de).
- No secrets appear in logs.
- No new dependency without a note in the PR.

**Milestones:**

| Milestone | Reached after | Result |
|---|---|---|
| M0 | Step 4 | Signed-in shell |
| M1 | Step 10 | Offline read-only client |
| M2 | Step 14 | Daily-driver editing |
| M3 | Step 19 | Notifications, background sync, widgets: private beta candidate |
| M4 | Step 34 | Web parity |
| M5 | Step 37 | Store release |

Rough total: about 90 engineer-days to M3, and about 170 to M5 [I].

### Why step 1 is "walking skeleton + server negotiation"

1. **Every later decision depends on the server's capabilities:**
   - which login flow (OAuth ≥ 2.3, cookie refresh 2.0–2.2, v2 token endpoint ≥ 2.4);
   - which adapter;
   - which features are visible (licence and `/info` flags);
   - how writes are serialized (`concurrent_writes`).
   Building auth or sync first would hard-code assumptions that negotiation would later have to unwind.
2. **It is the only slice that is end-to-end against real servers yet needs no credentials.** `/info` is public. The diff stays small and easy to review, and it still proves real behaviour across server versions.
3. **It surfaces the toolchain risks on day one, while the app is empty and fixes are cheap:**
   - the Cronet namespace clash (`android.uniquePackageNames=false`)
   - AGP 9 / KGP warnings
   - the UIScene template
   - the material_ui split
   - iOS Local Network permission
   - Android user-CA trust
4. **It sets up the Docker server-version matrix in CI.** Every later API step relies on it for v1/v2 contract tests.

### Phase 0: Foundation

#### Step 1: Walking skeleton and server connection `[M]`

**Goal:** a CI-built Android and iOS app whose only feature is "Connect to server". It shows the detected server version, API mode, tier and capabilities.

**Scope:**
- Pub workspace (`app/`, `packages/vikunja_domain`, `packages/vikunja_api` negotiation only).
- Flutter 3.47.5, material_ui/cupertino_ui, Riverpod, go_router with one route, gen-l10n (en, de), very_good_analysis, the logging/redaction scaffold.
- dio + native_dio_adapter with the Android fixes; network security config with user CAs; iOS Local Network keys.
- URL normaliser with the 3456 fallback, the v2 → v1 probe, version parser, `ServerCapabilities` with tier, and error states ("not Vikunja", "too old", "behind login proxy", `http://` warning).
- GitHub Actions: analyze, test, `build apk`, `build ios --no-codesign`; Docker matrix 1.x/2.0/2.3/2.4/2.7.

**Out of scope:** login, database, task UI, signing, app icon.

**Acceptance:**
- CI is green on both platforms.
- Negotiation contract tests: v2 is detected on 2.4 and 2.7, v1-only on 2.0 and 2.3, and 1.x is reported as too old (or legacy, per Q1). Flags equal `/info`.
- Unit tests cover URL normalisation (vectors from `frontend/src/helpers/apiUrl.test.ts`, `checkAndSetApiUrl.test.ts`) and version strings (`v2.7.0`, `v2.7.0-12-gabc`, `dev`, `unstable`).

#### Step 2: HTTP core and error model `[M]`

**Goal:** one reliable transport per server that every later step reuses.

**Scope:**
- dio factory (base URL, UA, `Accept-Encoding: gzip`, timeouts).
- Retry interceptor for idempotent requests (backoff, jitter, `Retry-After`, `X-RateLimit-*`) and a redacting logger.
- `VikunjaFailure` and its normaliser for:
  - v1 `{code,message}`
  - v2 problem+json
  - Echo `{message}`
  - 401 code 11, 429
- Validation-field mapping (`invalid_fields "field: msg"`, `errors[].location body.x`; `frontend/src/helpers/parseValidationErrors.test.ts`).
- Version-aware code map; the `error.*` ARB import tool.
- `Page<T>` normaliser (envelope or headers); `Uri`-based query builder (repeated params, `&&` in filters); zero-date and hex-colour codecs.

**Out of scope:** auth interceptor, TLS pinning and mTLS (step 35).

**Acceptance:**
- Fixture tests recorded from each Docker version.
- A filter containing `&&`, quotes and spaces round-trips byte-exact.
- `per_page` above the cap is reported correctly.
- A 2.6 server's 1026 maps to "account locked".

#### Step 3: Sign in with browser (OAuth + PKCE) and session manager `[M]`

**Goal:** a signed-in user on ≥ 2.3 servers, with transparent token refresh.

**Scope:**
- Account registry and token store with the secure-storage options above.
- PKCE flow with `flutter_web_auth_2`, `state` check, code exchange (v2, or v1 on 2.3.x).
- JWT claims parsing and server clock offset.
- Auth interceptor with proactive and reactive refresh; single-flight plus file lock plus re-read plus write-ahead plus auth epoch; failure classes; `needsReauth`.
- Logout. A "Who am I" screen showing `GET /user`.

**Out of scope:** password and API-token login, multi-account UI, background refresh.

**Acceptance:**
- Patrol E2E against 2.3.x and 2.7.0 (Docker, local auth): browser login works, and the username shows.
- With a server configured to `jwtttlshort=30`, requests keep working through refreshes.
- A unit test with two isolates or containers refreshing concurrently sees exactly one network refresh.
- A rotated old token → 16002 → the re-read path adopts the newer token.
- The session shows up in `/user/sessions` with a readable `device_info`.
- Logout wipes the secure entries.

#### Step 4: Password + TOTP login, API-token login `[M]`

**Goal:** work with 2.0–2.2 servers and with servers where the browser flow is not wanted.

**Scope:**
- Native form when `auth.local.enabled || auth.ldap.enabled`, with autofill hints and "Stay signed in" (`long_token:true`).
- TOTP step on 412/1017; messages for 1011, 1012, 1017, 1021, 1031, 1039/1025 and 1040/1026.
- `Set-Cookie` extraction, then `/oauth/token` refresh (≥ 2.3) or cookie refresh (2.0–2.2).
- API-token login: `GET /token/test`, a capability warning, no refresh, and code 11 shown as "revoked/expired/out of scope".
- The sign-in screen offers only the methods the server supports; OIDC provider names appear as hints on "Sign in with browser".

**Out of scope:** registration, password reset, link shares, < 2.0 servers.

**Acceptance:**
- Contract tests on 2.0, 2.2, 2.3 and 2.7: login, TOTP login (TOTP is enabled through a seed helper), refresh survives three rotations.
- An API token with a reduced scope never enters a refresh loop.

### Phase 1: Offline read path

#### Step 5: Domain model and read ports (v1 + v2 adapters) `[L]`

**Goal:** a complete read-only `VikunjaClient` used by sync and the first screens.

**Scope:**
- Domain entities; shared DTOs and codecs.
- Read operations for user and settings, projects (with views), views, buckets, labels, task lists (all, project, view, kanban board), single task (with ETag on v2), notifications, and saved filters (read).
- `RoutedVikunjaClient` with route-absent downgrade.
- The committed OpenAPI spec and the DTO-vs-schema contract test.

**Out of scope:** writes, comments, attachments, teams.

**Acceptance:**
- Seeded data read through the v1 and v2 adapters gives **equal domain objects**, except fields that only exist on v2.
- The Favorites pseudo project and saved filters are separated correctly even though they repeat on every page.
- Kanban per-bucket paging works on both versions.

#### Step 6: Local database and initial sync `[M]`

**Goal:** after login, the full account is in Drift and readable offline.

**Scope:**
- One DB per account and `shareAcrossIsolates`.
- The schema from §2.6 with its first schema dump.
- DAOs with stream queries.
- Initial keyset sync (undone tasks first; archived projects through the per-project path) with progress UI and resume from `sync_state`.
- `task_fts` index.

**Out of scope:** incremental sync, writes.

**Acceptance:**
- 5,000 seeded tasks sync completely and can be resumed after the app is killed mid-sync.
- The UI isolate and a test background isolate read the same data.
- The migration test harness is in place.

#### Step 7: Incremental sync and delete reconciliation `[M]`

**Goal:** changes made on the web appear when the app opens or on pull-to-refresh, including deletions.

**Scope:**
- Project diff: purge missing projects; full pull of new and un-archived ones.
- `(updated,id)` keyset delta with 120 s overlap; count check and id reconcile; labels and notifications pull; cheap probe.
- Foreground triggers (start, resume, timer, pull-to-refresh); "last synced" status.

**Out of scope:** writes, background, WebSocket.

**Acceptance:** contract scenarios on 2.0 and 2.7. Each of these is reflected after one sync:
- create, edit and delete a task on the server;
- share a project to the user;
- un-archive a project;
- move a task across projects.

The probe makes ≤ 2 requests when nothing changed.

#### Step 8: App shell, theming, settings applied, projects tree `[M]`

**Goal:** a navigable app that feels native.

**Scope:**
- Bottom navigation (Home, Upcoming, Projects, Search, More) and a rail at ≥ 600 dp.
- Theme with dynamic colour and `color_schema`.
- Read and apply `frontend_settings` (date display, time format, week start, minimum priority, default view).
- Projects tree with collapsible children, a Favorites section, "Smart lists" (saved filters), an archived toggle and translated default names (`Inbox`, `My Open Tasks`, Favorites).
- Offline banner.

**Out of scope:** editing projects, task lists.

**Acceptance:**
- Golden tests in light and dark themes.
- A TalkBack/VoiceOver pass on the tree.
- Settings changed on the web take effect after a sync.

#### Step 9: Task lists (read-only) `[M]`

**Goal:** the daily views work offline.

**Scope:**
- **Home "current tasks"**, including `filter_id_used_on_overview`.
- **Upcoming** with presets (today, week, month and the others from `dateRanges.ts`), a pinned **Overdue** section and the show-without-dates toggle.
- **Project List view**, per view, with subtask nesting (`useTaskListFiltering` rules), the sort sheet and a "Show done" toggle.
- Row content: labels, authenticated avatars, relative due date, priority above the minimum, icons, checklist progress, percent done.
- Local SQL for the standard screens; `view_member` cache for view filters the app cannot evaluate yet.

**Out of scope:** editing, kanban, filter builder.

**Acceptance:**
- Vectors ported from `ShowTasks.test.ts` and `useTaskListFiltering.test.ts` pass.
- The offline list matches the online server result for seeded fixtures.

#### Step 10: Task detail (read-only), HTML rendering, deep links `[M]`

**Goal:** every task property is visible and correctly rendered.

**Scope:**
- All fields; related tasks; attachment list with authenticated thumbnails (`preview_size=md`); comments read on demand; reactions shown; created/updated/done metadata; identifier (`getTaskIdentifier`); breadcrumbs.
- Sanitized HTML with checklist display, mention and task-link pills, and authenticated inline images.
- Mark-as-read on open (idempotent direct call).
- Deep links `vikunja-<app>://task/<id>` and `PROJ-12` via by-index (follow the 307).

**Out of scope:** editing.

**Acceptance:**
- Sanitizer fuzz tests: scripts, iframes and event handlers are dropped.
- Ported `parseTaskIdFromUrl.test.ts` and `checklistFromText.test.ts` pass.

### Phase 2: Write path

#### Step 11: Outbox engine and first mutations (done/undo, favorite, delete) `[M]`

**Goal:** the safe write pipeline, proven on the most frequent actions.

**Scope:**
- Outbox DAO, coalescer, serial sender, retry policy and the "Sync problems" list.
- v2 merge-patch for changed fields only; v1 GET-overlay-POST.
- Done with undo: a repeating task restores its snapshot; haptics.
- Favorite, followed by a refresh of the Favorites pseudo project.
- Delete with confirmation (404 counts as success).
- 3-way merge on incoming pulls; uncertain-create handling.

**Out of scope:** editing other properties.

**Acceptance:**
- Toggling done in airplane mode reaches the server after reconnect.
- A repeating task gets the server dates applied.
- On v2, a concurrent web title edit and a phone done toggle both survive.
- **On v1, assignees and reminders are preserved after done** (regression test against the full-replace hazard).
- No duplicate appears after a simulated lost create response.

#### Step 12: Task editing: core properties and simple create `[L]`

**Goal:** edit everything a daily driver needs.

**Scope:**
- Title.
- Due, start and end dates: pickers with `buildDateShortcuts`, default-time logic and the end = due rule.
- Priority, percent done, colour.
- Repeat: modes 0, 1 and 2, presets, period conversion.
- Reminders: relative or absolute, presets, local recomputation of relative reminders while offline.
- Move to project.
- Labels: picker plus create-on-the-fly with the 13-colour palette.
- Assignees: project user search on the per-version path.
- A simple "new task" sheet (title + project).

**Out of scope:** quick-add grammar, description editing.

**Acceptance:**
- Vectors ported from `dateShortcuts.test.ts`, `calculateDayInterval.test.ts`, `getDateWithTime.test.ts`, `period` and `task.test.ts` pass.
- Every property edited offline syncs correctly on v1 and v2.

#### Step 13: Quick Add Magic and composer `[L]`

**Goal:** fast, web-compatible capture from anywhere in the app.

**Scope:**
- Parser port in `vikunja_logic`, with about 600 golden cases from `quickAddMagic.test.ts` plus `useQuickAddTask.test.ts` and `parseSubtasksViaIndention.test.ts`; quirk policy per Q9.
- Composer sheet with live token chips.
- Project, label and assignee resolution rules; `NO_PROJECT` error; default reminders.
- Multi-line input: bulk create (≥ 2.5, chunks of 100, last chunk first) or sequential creates; indentation creates `parenttask` relations.
- Android app shortcut and iOS Quick Action "New task"; plain text shared into the app opens the composer.

**Out of scope:** files shared into the app (step 26).

**Acceptance:**
- The golden suite is 100 % green.
- Pasting 150 lines creates 150 tasks with the right parents on 2.7, and works sequentially on 2.3.

#### Step 14: Subtasks, relations, duplicate, subscriptions `[S]`

**Goal:** complete the task graph.

**Scope:**
- Subtask section with inline add and checkbox.
- All relation kinds: create-and-relate, remove.
- Duplicate.
- Subscribe toggle for tasks and projects (state comes from single reads).

**Out of scope:** Gantt arrows.

**Acceptance:** relations show their inverse on the other task after a sync, on both API versions.

### Phase 3: Mobile capabilities (core user requirements)

#### Step 15: Local reminder and due notifications with Mark done / Snooze `[L]`

**Goal:** reliable reminders with in-notification actions.

**Scope:** everything in §2.10:
- channels, categories registered in every isolate, the diff scheduler with rolling window;
- deterministic ids, no flood on first sync, grouping;
- background mark-done handler, snooze;
- exact-alarm opt-in flow, iOS Time Sensitive;
- settings screen with notification policy (Q7), daily overdue digest.

**Out of scope:** server activity notifications (step 16).

**Acceptance:**
- Patrol on an Android emulator: the reminder fires, "Mark done" from the shade with the **app killed** completes the task on the server, and a repeating task's next reminder gets scheduled.
- Time-zone change test.
- A 100-reminder account keeps ≤ 60 pending on iOS (simulator check).
- A manual iOS device protocol is documented.

#### Step 16: Background sync, activity notifications, notifications inbox `[M]`

**Goal:** tasks created on the web appear on the phone without opening the app (within OS limits).

**Scope:**
- WorkManager periodic and expedited drain; iOS BGAppRefresh and BGProcessing; session keep-alive.
- Server notifications become Activity OS notifications.
- In-app inbox: list, read/unread, mark all, clear all, per-type deep links (`helpers/notification.ts` texts).
- A "Sign in again" notification on `needsReauth`.

**Out of scope:** WebSocket.

**Acceptance:**
- Android: a task created on the web shows up in the DB and on the widget data path within one periodic window, and on resume within 2 s.
- An idle background run makes ≤ 6 requests.
- The expected iOS latency is documented honestly in the About screen.

#### Step 17: Realtime in the foreground (WebSocket) `[S]`

**Goal:** instant activity while the app is open.

**Scope:** §2.9: auth, subscribe, re-auth on refresh, capped reconnects, terminal states, sync after (re)connect, dedupe of socket reminders.

**Out of scope:** timers (step 34).

**Acceptance:**
- A comment from the web triggers a refresh within 3 s.
- The kill/restart server test stays under 5 upgrades per minute.
- An API-token account falls back to polling.

#### Step 18: Home-screen widgets: Android `[M]`

**Goal:** configurable Glance widgets.

**Scope:**
- Snapshot builder; configurations Today, Upcoming N, Overdue, Project, Label, Favorites, Saved filter, Quick add.
- Configuration activity; interactive mark done through the Dart callback; deep-link fallback.

**Out of scope:** iOS.

**Acceptance:**
- The widget updates within 5 s of an in-app change.
- Mark done works with the app in the background, and through the fallback after a force-stop.
- Widget font scaling is respected.

#### Step 19: Home-screen widgets: iOS `[L]`

**Goal:** WidgetKit parity.

**Scope:**
- Widget extension (17.0) with SwiftUI timelines that include boundary entries.
- `AppIntentConfiguration` entities.
- Native Swift mark-done intent with App Group outbox, mirrored access token and the never-refresh rule.
- The app imports the App Group outbox.

**Out of scope:** Live Activities.

**Acceptance:**
- On a device, mark done from the widget with the app terminated completes on the server, either immediately (token valid) or at the next app run.
- The extension never touches SQLite (code review checklist item).

### Phase 4: Web parity

#### Step 20: Kanban board `[M]`

**Scope:**
- Board with horizontally paged columns and 25 tasks per bucket with load-more.
- Long-press drag across columns with edge auto-scroll, plus a "Move to bucket…" sheet as the accessible alternative.
- Done-bucket and default-bucket semantics; refusal at the bucket limit.
- Cards with cover image, labels, assignees and checklist progress.

**Acceptance:**
- The ported position-math tests pass.
- A move into the done bucket marks the task done on both API versions.
- The limit (10004) is shown without corrupting state.

#### Step 21: Bucket management `[S]`

**Scope:** add, rename and delete buckets (not the last one); WIP limit; set done/default bucket; reorder; local collapse; filter-mode buckets read-only.

**Acceptance:** works offline through the outbox, or is disabled offline with a clear message.

#### Step 22: Manual ordering `[S]`

**Scope:** drag-reorder in List view (`PUT|POST /tasks/{id}/position`, midpoint math); project reorder and re-parenting in the tree.

**Acceptance:**
- Positions match `calculateItemPosition` vectors.
- The server's recalculation is picked up.

#### Step 23: Project management and views `[L]`

**Scope:**
- Create a project or child project; edit title, description, identifier, colour and parent.
- Archive and un-archive (default-project guard); delete, showing the task and child counts; duplicate (optionally with shares).
- Project info header; remembered view per project and `default_view`; subscribe.
- **Views management:** CRUD, reorder, view filter editor, kanban bucket configuration.

**Acceptance:** each action works on v1 and v2. On v1 the description is not lost when editing a project; the inability to clear it is documented and surfaced.

#### Step 24: Filters engine, saved filters, global search `[L]`

**Scope:**
- Ports of `transformFilterStringForApi`/`FromApi` with the golden tests.
- Local DSL → SQL compiler for the supported fields, with datemath in the user's time zone and a fallback to cached server membership.
- Visual filter builder plus raw query field with autocomplete; "include nulls".
- Saved filter CRUD, favourite, "use as overview".
- Search tab: local FTS5 offline, server `q` online, scoped tokens `+project *label @team`.

**Acceptance:**
- For the seeded fixture set, local filter results equal server results for the supported subset.
- Unsupported expressions transparently use the server.

#### Step 25: Description editor (TipTap) and interactive checklists `[L]`

**Scope:**
- Bundled TipTap build in CI.
- Full-screen editor with the same extensions, mentions (300 ms debounced user search), task links, image paste uploaded as attachments.
- Drafts persisted locally.
- Interactive checklists in read mode.

**Acceptance:**
- Round-trip tests: HTML saved by the web is unchanged after opening and saving in the app without edits.
- The checklist progress counter matches the web.

#### Step 26: Attachments and share target `[M]`

**Scope:**
- Upload from camera, photos or files (multi, progress, `max_file_size` check).
- Download, open and share; previews; set and unset cover; delete.
- Files shared into the app: "Share to Vikunja" creates a task or attaches to one. The share-intent package or extension is to be chosen in this step; it was not covered by the research.

**Acceptance:**
- Per-file errors from `{success, errors}` are shown.
- Large files show progress and the upload can be cancelled.

#### Step 27: Comments, reactions, unread `[M]`

**Scope:**
- Comment thread honouring `comment_sort_order`.
- Composer (TipTap-lite or the full editor), edit and delete own comments, reply/quote (`<blockquote data-comment-id>`), mentions.
- Reactions on tasks and comments.
- Unread dots via `expand=is_unread`.

**Acceptance:** a mention notifies the mentioned user (seeded check); reactions toggle on both API versions.

#### Step 28: Labels, teams, sharing `[M]`

**Scope:**
- **Labels:** CRUD (creator only), "show tasks with label".
- **Teams:** CRUD, members, admin toggle, leave (with the access-cleanup notice), public teams, a badge for external (OIDC/LDAP) teams.
- **Project sharing:** users (by username), teams and link shares with permission levels; share link via share sheet and QR.

**Acceptance:** permission changes are reflected in `max_permission` gating after a sync.

#### Step 29: Table and timeline views `[M]`

**Scope:**
- Table view as a "detailed list" with column chooser and sort.
- Gantt as a read-only horizontal timeline (tap opens the task; dates are edited through sheets).
- Optional agenda/calendar view.

**Acceptance:** the timeline uses the web's Gantt filter and default range (`useGanttFilters.test.ts` vectors).

#### Step 30: User settings and profile `[M]`

**Scope:**
- General settings editing: merge-patch on v2, full POST on v1.
- `frontend_settings`, including a `mobile_*` namespace.
- Offer to set `settings.timezone` and `language` from the device.
- Avatar (provider, upload with crop).
- Password change, followed by re-login.
- Email change, with pending/resend/cancel on ≥ 2.6.
- About screen: versions, pro features, legal links, MOTD.

**Acceptance:** web-only `frontend_settings` keys survive edits made in the app (v2), and survive the v1 full-replace round-trip.

#### Step 31: Security and integration settings `[M]`

**Scope:**
- TOTP: enroll, show the JPEG QR, open an `otpauth://` link, enable (then re-login), disable.
- Sessions: list, mark the current one by `sid`, revoke, "sign out other devices".
- API tokens: scopes from `GET /routes`, expiry presets (required), copy-once.
- CalDAV tokens plus an "Add to Apple Reminders / DAVx⁵" helper (`{frontend_url}dav/principals/{username}/`).
- Data export (request, status, download).
- Account deletion (request, confirm, cancel; banner on Home).

**Acceptance:** each flow works against 2.7.0; session-killing actions lead straight into a fresh login.

#### Step 32: Onboarding extras and link-share guests `[M]`

**Scope:**
- Registration, including the invite-link check on ≥ 2.7.
- Email confirmation and password reset (paste the token or open the web link).
- Demo-mode banner, MOTD, legal links.
- **Link-share guest account:** paste a URL or scan a QR, password prompt, reduced UI, token renewal via `POST /user/token`, no WebSocket.

**Acceptance:** a guest with a read-only share can browse but not write; a write share can edit tasks in that project.

#### Step 33: Power-user and admin features `[M]`

**Scope:**
- Project and user webhooks.
- Bot users and their tokens.
- Project backgrounds: upload, Unsplash search, remove, blurhash placeholder, brightness.
- Migration: link out to the web, with optional file import for vikunja-file, TickTick and WeKan.
- Atom feed URL (needs a feeds-scoped token).
- MCP info page (read-only).
- **Admin panel** (`is_admin` plus `admin_panel` licence): overview, users, projects, invite links.

**Acceptance:** everything is hidden when the flag or licence is absent; a 404 on a gated route never crashes or loops.

#### Step 34: Time tracking (licensed) `[M]`

**Scope:**
- Start and stop a timer (starting one auto-stops the previous); running-timer ongoing notification with a Stop action (Android).
- Manual entries, per-task panel, list page with filters.
- WebSocket `timer.*` events.
- Hidden unless `time_tracking` is in `enabled_pro_features`.

**Acceptance:** works against a licensed test server, or a mocked server if no licence is available. Decide this with the user.

### Phase 5: Hardening and release

#### Step 35: Security hardening `[M]`

**Scope:**
- A written threat model.
- App lock with timeout (local_auth); privacy overlay in the app switcher; optional `FLAG_SECURE`.
- Per-server TLS profile:
  - "trust this certificate" (SHA-256 pin through `IOHttpClientAdapter`);
  - mTLS (PKCS#12 in the keychain);
  - custom request headers (for example `CF-Access-Client-Id/Secret`) stored as secrets;
  - per-host cleartext opt-in.
- Option to hide task titles on the lock screen.
- Log-redaction audit; backup-exclusion test; deep-link input validation.
- WebView hardening: no remote loads, origin check on the JavaScript channel.
- Review of the widget extension's token handling.
- Dependency audit with a committed lockfile; OSV scan and `pub outdated` in CI.

**Acceptance:**
- Security checklist signed off.
- Pinned self-signed and mTLS test servers in Docker work.
- No token appears in any log or diagnostics export (automated grep test).

#### Step 36: Accessibility, i18n, tablets `[M]`

**Scope:**
- Semantics actions everywhere; 200 % text scale; contrast; reduced motion; RTL.
- `meetsGuideline` tests.
- Import of all 32 web locales into ARB.
- iPad and tablet list-detail; hardware-keyboard shortcuts (the web map in `features.md` §19).

**Acceptance:** manual VoiceOver and TalkBack passes on the top 10 flows; layouts in `ar-SA` and `de-DE` are verified.

#### Step 37: Release engineering `[M]`

**Scope:**
- Flavors:
  - Play / App Store;
  - F-Droid: embedded Cronet, sqlite3 built from source, no proprietary dependencies.
- fastlane signing and upload; store listings.
- Privacy manifests; Play exact-alarm declaration.
- App Review notes with a demo server (`demo_mode_enabled`) and account deletion exposed.
- A published compatibility matrix.

**Acceptance:** internal-track and TestFlight builds are produced from tags.

#### Step 38 (optional): Legacy servers 0.24 – 1.x `[M]`

**Scope:**
- `right` → `permission` and `x-max-right` shim.
- Long-JWT renew via `POST /user/token`.
- Probe `/tasks` vs `/tasks/all`.
- Error codes; no WebSocket.

**Acceptance:** contract tests against 0.24.x and 1.x images. All items here are currently unverified (critique §4).

### Coverage check: web features → steps

Feature inventory sections are from `features.md`.

| Web area | Steps |
|---|---|
| §2 Server select, login (local/LDAP/OIDC/OAuth/TOTP), logout, account-gone | 1, 3, 4 |
| §2 Registration, invites, password reset, email confirm, link-share access | 32 |
| §3 Home, current tasks, upcoming, overdue, MOTD/demo/legal | 9, 32 |
| §4 Projects: tree, CRUD, move/reorder, favorite, archive, duplicate, info, background, subscribe, webhooks, views management | 8, 11, 22, 23, 33, 14 |
| §5 List view (subtasks, row content, done+undo, add, sort, filter, show done, reorder) | 9, 11, 12, 13, 22, 24 |
| §6 Table view | 29 |
| §7 Kanban (board, move, done/default bucket, bucket CRUD, limits, collapse, cards) | 20, 21 |
| §8 Gantt | 29 |
| §9 Task detail (all properties, description, reminders, repeat, labels, assignees, attachments, relations, move, duplicate, delete, subscribe, comments, reactions, unread, metadata, share/copy) | 10–14, 25–27 |
| §10 Quick Add Magic, multi-line, subtasks via indentation | 13 |
| §11 Filter language, saved filters, global search | 24 |
| §12–14 Labels, teams, sharing | 28 |
| §15 Notifications center, Atom feed | 16, 33 |
| §16 Settings (general, password, email, avatar, TOTP, CalDAV, API tokens, sessions, webhooks, bots, MCP, export, deletion, migration) | 30, 31, 33 |
| §17 Time tracking | 34 |
| §18 Admin panel | 33 |
| §19 Keyboard shortcuts | 36 (mapped to gestures throughout) |
| §20 About, offline states, theme, i18n, token renew on focus | 3, 7, 8, 30, 36 |
| Mobile-only: background sync, widgets, notifications with mark-done, share target, app shortcuts, app lock | 13, 15–19, 26, 35 |

---

## 5. Open questions and decisions for you

Each question includes my recommendation.

1. **Minimum server version.**
   - Option A (recommended): floor **2.0.0**, first-class ≥ 2.4.0. Reason: pre-2.0 auth and naming behaviour is unverified.
   - Option B: also support 0.24–1.x through step 38.
   - Which version does **your** instance run? Is the app meant for other people's servers too, for example via a public store listing?
2. **App identity.**
   - App name: avoid implying an official Vikunja app; ask the Vikunja maintainers about name and logo use.
   - Android `applicationId` and iOS bundle id.
   - OAuth `client_id` and redirect scheme. The scheme must start with `vikunja-`; avoid `vikunja-desktop` and the `vikunja-flutter` example used in the server's source comment.
   - App Group id and keychain group.
3. **Licence and distribution.**
   - Porting the web frontend's logic and strings (quick-add parser, i18n files, error strings, TipTap configuration) probably makes the app a derivative of AGPL-3.0-or-later code.
   - Do you want the app open source under AGPL-3.0-or-later?
   - Target stores: Play, App Store, F-Droid? F-Droid affects the Cronet and SQLite build choices and rules out Sentry.
   - Not legal advice; verify.
4. **Login methods in step 3/4.**
   - Recommended: browser OAuth + PKCE first (covers local, LDAP, every OIDC provider and TOTP on ≥ 2.3), then password + TOTP and API token in step 4.
   - Native OIDC for < 2.3 servers (embedded WebView): recommend **not** doing it.
   - Do you use OIDC on your server?
5. **Session lifetime.** OAuth sessions expire after 72 h without a refresh, which is likely on iOS if the app is not opened. Options:
   - Accept it, with background keep-alive.
   - Prefer password login with "stay signed in 30 days" when local/LDAP auth exists.
   - Ask admins to raise `service.jwtttl`.
   - Recommendation: OAuth by default, plus the 30-day password option.
6. **Multi-account.** Architecture-ready from step 3. Account-switcher UI in the first release (+S), or later?
7. **Notification policy defaults.**
   - Which tasks get local reminders: creator or assignee (recommended), or all visible tasks including shared projects?
   - Due-date notification default: at due time, N minutes before, or off?
   - Daily overdue digest on or off?
   - Ask for Android exact alarms at onboarding, or only when the user enables "exact reminders"?
8. **Description editing.**
   - TipTap in a WebView (recommended: lossless, heavier).
   - Markdown-only editing on v2 (lossy; v1 servers would be read-only).
   - Plain text.
9. **Quick-add quirks.**
   - Replicate the web exactly (parity), or fix obvious bugs?
   - Examples: `every 2 months`/`yearly` produce no repeat; capitalised `Daily` means hourly; `todays` and `next weekend` mis-parse; `12 decorations` becomes Dec 12 (`client-logic.md` §20).
   - Recommendation: fix 1–4, document the fixes, keep the grammar.
10. **Desktop-centric features.** Confirm these adaptations:
    - Gantt as a read-only timeline.
    - Table as a detailed list.
    - Keyboard shortcuts on iPad only.
    - MCP page as information only.
    - Desktop quick-entry window replaced by widget and app shortcuts.
    - Seasonal logo and PWA banners skipped.
    - Admin panel included when licensed.
11. **Optional Android near-real-time push** via Vikunja webhook → self-hosted ntfy → UnifiedPush. It is Android-only, needs per-project webhooks and `webhooks.allownonroutableips` for LAN targets. In scope after M3, or never?
12. **Crash reporting.** None (recommended for launch), or opt-in self-hosted Sentry/GlitchTip once sentry_flutter 10.x is stable?
13. **Launch languages.** English + German only at first, or all 32 web locales from the start of step 36?
14. **Licensed features.** Do you have, or can you get, a Vikunja licence for testing time tracking and the admin panel? Otherwise steps 33 and 34 are tested against mocks only.

---

## 6. Risks

Ranked by impact × likelihood [I].

| # | Risk | Impact | Mitigation |
|---|---|---|---|
| 1 | **iOS background execution is opportunistic.** "Web tasks appear on the phone" is guaranteed only on open/resume. There are no runs after a force-quit, and no push channel exists. | Core requirement only partially met on iOS | Sync on resume in < 2 s; BGAppRefresh plus BGProcessing; honest "last synced" UI. Optional push is out of scope (Q11). |
| 2 | **Refresh-token rotation without a grace period**, plus 72 h idle expiry for OAuth sessions. A lost refresh response means a forced re-login. | Users logged out; background sync stops | Write-ahead persistence, file lock and re-read, non-cancellable refresh, 24 h keep-alive, 30-day password option (Q5), `needsReauth` that keeps the outbox. |
| 3 | **Data loss from full-replace semantics:** v1 task update, v2 PUT, bulk update, v1 project update. | Silent loss of assignees, reminders or descriptions | v2 PATCH with changed fields only; v1 GET-overlay-POST; bulk update banned; regression tests in step 11. |
| 4 | **Sync blind spots:** no tombstones, newly visible projects, archived-project exclusion, position, bucket and label-rename changes not bumping `updated`. | Stale or ghost tasks | Project diff with full pulls, count check and id reconcile, 24 h full reconcile, on-open refresh for kanban and comments. |
| 5 | **Server version matrix and drift:** error renumbering in 2.7, unverified legacy behaviour, v2 growing weekly, Huma probably rejecting unknown fields [I]. | Breakage on some servers | Capability model, Docker matrix in CI, strict write allow-lists, schema contract test, version-aware error map. |
| 6 | **Notification platform limits:** iOS 64 pending; Android 14+ denies exact alarms by default; OEM battery killers; categories must be re-registered in every isolate. | Missed or late reminders; vanished "Mark done" | Rolling window, inexact fallback with user opt-in, registration at every init, patrol tests, dontkillmyapp guidance. |
| 7 | **Widget interactivity bugs:** home_widget #318 (Android after kill), #455 (WorkManager crash on Pixel 8 Pro / Android 14); iOS intents run in the extension process. | Widget actions fail | Native Swift intent with App Group outbox; deep-link fallback on Android; test early (steps 18–19). |
| 8 | **Flutter ecosystem churn:** the material_ui transition (bridge already deprecated); Cronet namespace clash; KGP cutoff for cronet_http, flutter_web_auth_2, home_widget, patrol and workmanager; Riverpod 4 and freezed 4 changes; flutter_web_auth_2 UIScene support only in a 6.0 alpha. | Build breaks | Step 1 de-risks the build; committed lockfile; wrapper widgets around legacy-Material dependencies; dependency upgrades as separate PRs. |
| 9 | **Self-hosting network realities:** forward-auth or Basic-auth proxies, self-signed certificates, user CAs, LAN http, iOS Local Network permission, CGNAT plus the WebSocket upgrade sharing the 10/min login limiter. | Cannot connect, or login lockouts | Clear proxy detection, custom headers, pinning and mTLS (step 35), network security config, permission UX, reconnect cap. |
| 10 | **Rich text:** the TipTap WebView must track the web's TipTap version (3.31.3) and has IME quirks; Markdown is lossy and converts the whole field. | Corrupted descriptions | HTML stays canonical; round-trip tests; Markdown never sent unless the description changed. |
| 11 | **Legal and store:** AGPL derivation; "Vikunja" name and logo use; App Review needs a demo server and account deletion. | Rejection or licence conflict | Decide Q2 and Q3 before step 37; demo-mode server; deletion flow in step 31. |
| 12 | **Performance on big accounts:** 50 items per page, no gzip on `/api`, initial sync of thousands of tasks. | Slow first run, data usage | Keyset paging, undone tasks first, minimal `expand`, `Accept-Encoding`, progress UI, resumable sync. |
| 13 | **Unverified server behaviours:** 304 on a no-op PATCH, unknown-field 422, a native WebSocket without `Origin` being accepted, a done-changing bucket move bumping `updated`, go-datemath week start, form-encoded v1 `/oauth/token`. | Wrong assumptions | Each becomes an explicit contract test in the step that first depends on it (steps 3, 5, 11, 17, 20, 24). |
| 14 | **Time-zone semantics:** server datemath uses `settings.timezone`, while the app shows device time. | "Today" differs between web and phone | Compute widget and local lists in device time; offer to sync `settings.timezone` (step 30). |
| 15 | **Multi-node servers:** WebSocket events are in-memory per node and lost on restart. | Missed realtime hints | The socket is only a hint; polling and probes are the truth. |
| 16 | **Licence gating:** gated routes appear in the OpenAPI spec but return 404; the cached licence validation lapses after 72 h offline. | Features flicker | Gate strictly on `enabled_pro_features` from the latest `/info`; treat 404 on gated groups as `FeatureUnavailable`. |
