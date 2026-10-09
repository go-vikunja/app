# Vikunja web frontend: user-facing feature inventory (for the Flutter mobile app)

Source: shallow clone of `main` at release **v2.7.0 (2026-10-02)**, read-only at
`scratchpad/ref/vikunja`. All paths below are relative to the repo root. Everything is **verified in
source** unless marked **[inferred]**.

Method: every route in `frontend/src/router/index.ts`, every view in `frontend/src/views/**`, the components they
mount, the TanStack query modules in `frontend/src/client/queries/**`, the generated v2 SDK
(`frontend/src/client/generated/sdk.gen.ts`, 216 operations), the v1 Echo routes in `pkg/routes/routes.go`
(lines ~517-1046), plus `frontend/src/i18n/lang/en.json` as a cross-check of UI strings.

---

## 0. Legend

| Tag | Meaning |
|---|---|
| **P0** | MVP: needed for a usable daily-driver todo app |
| **P1** | Needed for "every web feature on mobile" parity, second wave |
| **P2** | Niche / power-user; implement late or as read-only |
| **SKIP?** | Desktop-centric or makes little sense on a phone; candidate to drop or replace |
| **[ADMIN]** | Instance admins only (`GET /user` -> `is_admin: true`) |
| **[LIC:x]** | Gated by `pkg/license` feature `x` (`admin_panel`, `time_tracking`, `user_invites`; `audit_logs` is server-only). Advertised in `GET /info` -> `enabled_pro_features[]`. Gated routes answer **404** when the feature is off (`pkg/routes/feature_gate.go`). |
| **[CFG:x]** | Hidden unless `GET /info` field `x` is true (instance config) |
| **[PERM:w/a]** | Needs write (1) / admin (2) permission on the project (`max_permission`, `constants/permissions.ts`: 0 read, 1 read+write, 2 admin) |
| **[v2-only]** | No `/api/v1` route exists |
| **[DESKTOP]** | Desktop-centric interaction in the web UI |

API notation: `v2: VERB /path` is relative to `/api/v2`, `v1: VERB /path` is relative to `/api/v1`.

---

## 1. Cross-cutting API facts every feature depends on

### 1.1 v1 vs v2 conventions (verified)

| Concern | v1 (`pkg/routes/routes.go`, frozen) | v2 (`pkg/routes/api/v2/*`, Huma) |
|---|---|---|
| Create | `PUT` | `POST` (`.agents/docs/api.md` "Conventions") |
| Update | `POST` (full object) | `PUT` (full) or `PATCH` (partial) |
| Partial update | none | `PATCH` with `application/json-patch+json` (RFC 6902 array) **or** `application/merge-patch+json` (RFC 7396). Task/project PATCH ops: "Partial update operation supporting both JSON Merge Patch & JSON Patch updates" (`sdk.gen.ts` `patchTasksRead`). Frontend uses JSON Patch for tasks (`client/queries/taskMutations.ts:taskPatchBody`, `{op:'add', path:'/field', value}`) and projects (`client/queries/projects.ts:351`), and merge-patch for user settings (`client/queries/account.ts:221-228`). |
| List shape | bare JSON array + headers `x-pagination-total-pages`, `x-pagination-result-count` (`pkg/web/handler/read_all.go:113-115`) | envelope `{items, total, page, per_page, total_pages}` (`types.gen.ts` `PaginatedTask`) |
| Search param | `s` (`pkg/web/handler/read_all.go:93`, `pkg/models/task_collection.go:35`) | `q` (`TasksListData.query.q`) |
| Paging | `page`, `per_page` | `page`, `per_page`; omitted `per_page` = server max `GET /info -> max_items_per_page`; larger values silently capped |
| Single-item permission | header `x-max-permission` (`pkg/web/handler/read_one.go:59`) | `max_permission` field (projects with `?expand=permissions`) |
| Errors | `{code, message}` | RFC 7807-ish `VikunjaErrorModel {status, detail, code, title, type, errors[], i18n_params}` |
| Rich text | HTML only | HTML by default; `?format=markdown` (GET/POST/PUT) or header `X-Vikunja-Format: markdown` (PATCH) converts descriptions/comments to GFM Markdown; writing Markdown is **lossy** (`pkg/routes/api/v2/richtext.go`). |
| Conditional GET | n/a | Single-item GETs send `ETag`; `If-None-Match` -> 304 (`sdk.gen.ts` doc of `tasksRead`, `labelsRead`, `timeEntriesRead`) |
| Kanban board read | `GET /projects/{p}/views/{v}/tasks` returns **buckets with tasks** for a kanban view (`pkg/models/task_collection.go:206-213`) | flat tasks at `/views/{v}/tasks`; board at `GET /projects/{p}/views/{v}/buckets/tasks` |

Version history (from `CHANGELOG.md`): `/api/v2` appears in **2.4.0** (2026-07-19); WebSocket + OAuth2/PKCE
authorize endpoint in **2.3.0**; refresh-token sessions in **2.0.0**; time tracking and bot users in **2.4.0**;
bulk task create in **2.5.0**; reactions in **0.24.0**. A mobile client must probe (`GET /api/v2/info` -> fall back
to `GET /api/v1/info`) and feature-detect.

### 1.2 Capability gating from `GET /info` (`pkg/routes/api/shared/info.go`)

Fields the UI branches on: `version`, `frontend_url`, `motd`, `link_sharing_enabled`, `max_file_size`,
`max_items_per_page`, `available_migrators[]`, `task_attachments_enabled`, `enabled_background_providers[]`
(`upload`, `unsplash`), `totp_enabled`, `legal.{imprint_url, privacy_policy_url}`, `caldav_enabled`,
`auth.local.{enabled, registration_enabled}`, `auth.ldap.enabled`, `auth.openid_connect.{enabled, providers[]}`,
`email_reminders_enabled`, `user_deletion_enabled`, `task_comments_enabled`, `demo_mode_enabled`,
`webhooks_enabled`, `public_teams_enabled`, `allow_icon_changes`, `enabled_pro_features[]`, `concurrent_writes`
(false on SQLite: serialize batched writes).

### 1.3 Pseudo projects (verified)

* **Favorites** = project id **-1** (`pkg/models/project.go:154`), views `-1` List, `-2` Gantt, `-3` Table
  (`project.go:170-190`). Included in `GET /projects` **only if the user has at least one favorite task**
  (`project.go:690-704`). Favorite *projects* are a sidebar section, not this pseudo project
  (`components/home/Navigation.vue:94`).
* **Saved filters** appear as projects with negative ids: `projectId = -filterId - 1`, i.e. filter 1 -> project -2
  (`client/queries/projects.ts:219-230`). They have views and can be favorited.
* Pseudo projects have no detail endpoint; use the `/projects` list entry (`.agents/docs/api.md`).

### 1.4 Real-time / sync relevant facts (verified, details belong to the sync research)

* WebSocket at `GET /api/v{1,2}/ws`; client sends `{"action":"auth","token":...}` then
  `{"action":"subscribe","event":...}` (`frontend/src/composables/useWebSocket.ts:47-90`).
* Only four events exist: `notification.created`, `timer.created`, `timer.updated`, `timer.deleted`
  (`pkg/websocket/connection.go:338-341`). **There are no task/project change events**: task changes from the web
  must be discovered by polling, e.g. `filter=updated > <ts>` (`updated` is a filter field,
  `frontend/src/helpers/filters.ts:13-21`).
* Notifications fall back to 10 s polling when the socket is not authenticated
  (`components/notifications/Notifications.vue:148`).
* `task.reminder` notifications are stored in the DB (in-app), independently of email
  (`pkg/models/notifications.go:89-99`); overdue summaries and data-export-ready are email-only (`ToDB()` returns nil,
  `notifications.go:398-472, 562`).

---

## 2. Onboarding, authentication, link shares

Routes: `/login`, `/register`, `/get-password-reset`, `/password-reset`, `/auth/openid/:provider`,
`/oauth/authorize`, `/share/:share/auth` (`frontend/src/router/index.ts:64-96, 212-216, 432-440`).

* **Server selection** — user enters the instance URL; client validates it via `/info`, stores it without the
  `/api/vN` suffix (`helpers/checkAndSetApiUrl.ts`, `helpers/apiUrl.ts:1-20`; i18n `apiConfig.*`). Shows `motd`
  on unauthenticated screens (`components/misc/NoAuthWrapper.vue:11-14`).
  API: `v2: GET /info` / `v1: GET /info`. Mobile: first-run screen with URL field, QR-scan option, recent servers. **P0**
* **Login (local/LDAP)** — username-or-email + password, "remember me" (= `long_token`), TOTP second step when
  error code **1017** is returned (`views/user/Login.vue:97-128`, `stores/auth.ts:260-300`,
  `constants/auth.ts:9-12`: 1005 user does not exist, 1020 disabled, 1040 locked).
  API: `v2: POST /login {username,password,totp_passcode,long_token}` / `v1: POST /login`. Refresh:
  `v2: POST /user/token/refresh` uses an **HttpOnly refresh-token cookie** (`sdk.gen.ts` `authRefreshToken`).
  Mobile: native form with password-manager autofill (`autocomplete=username/password/one-time-code`), OTP field
  with SMS/authenticator autofill. **P0**
* **OAuth 2.0 Authorization Code + PKCE (recommended for mobile)** — used by the Electron app
  (`desktop/oauth.js`): open `{frontend_url}/oauth/authorize?response_type=code&client_id=<id>&redirect_uri=<uri>&code_challenge=<S256>&code_challenge_method=S256&state=<s>`;
  the SPA (`views/user/OAuthAuthorize.vue`) logs the user in by whatever method (local, LDAP, OIDC, TOTP), calls
  `v2: POST /oauth/authorize` and redirects to `redirect_uri?code=...&state=...`; client then calls
  `POST /api/v2/oauth/token {grant_type:"authorization_code", code, client_id, redirect_uri, code_verifier}` ->
  `{access_token, token_type, expires_in, refresh_token}`; refresh with `{grant_type:"refresh_token", refresh_token}`
  (`pkg/modules/auth/oauth2server/token.go:37-52, 87-92`). Constraints: `response_type` must be `code`,
  `code_challenge_method` must be `S256`, redirect URI scheme must **start with `vikunja-`** (e.g.
  `vikunja-mobile://callback`) or be `http://localhost`/loopback (`oauth2server/client.go`, `authorize.go`);
  `client_id` is free-form and only has to match between the two calls. API tokens cannot authorize (403).
  Also registered on v1: `v1: POST /oauth/token`, `v1: POST /oauth/authorize` (`routes.go:555, 585`). Since 2.3.0.
  Mobile: `ASWebAuthenticationSession` / Android Custom Tabs; this single flow covers local, LDAP and every OIDC
  provider and avoids the cookie-based refresh. **P0**
* **OIDC login (web flow)** — buttons "Log in with {provider}" per `auth.openid_connect.providers[]`
  (`Login.vue` bottom); redirect to `provider.auth_url?client_id=&redirect_uri={frontend}/auth/openid/{key}&response_type=code&scope=&state=`
  (`helpers/redirectToProvider.ts`); callback `v2: POST /auth/openid/{provider}/callback {code, redirect_url, totp_passcode?}`
  (`stores/auth.ts:339-370`); auto-redirect when OIDC is the only method (`getAutoRedirectProvider`). Provider
  `logout_url` honored on logout. Mobile: use the OAuth/PKCE flow above instead (the provider's redirect URI is
  bound to the web frontend). **P0 via OAuth flow**
* **Registration** — username, email, password (`views/user/Register.vue:47-90`), language auto-sent; demo-mode
  warning; hidden unless `auth.local.registration_enabled`. Invite links: `/register#invite-link=<token>` ->
  `v2: POST /invite-links/check {token}` (404 = invalid/expired/unlicensed) -> `POST /register {..., invite_token}`
  (`client/inviteLink.ts`), shows teams the invitee will join. API: `v2: POST /register` / `v1: POST /register`.
  Email confirmation via `?userEmailConfirm=<token>` -> `POST /user/confirm {token}` (`router/index.ts:500-523`).
  Mobile: native form; handle confirm/invite deep links (App/Universal Links on `frontend_url`). **P1** (invites [LIC:user_invites] **P2**)
* **Password reset** — request: email -> `POST /user/password/token {email}`; reset page reads
  `?userPasswordReset=<token>` -> `POST /user/password/reset {token,new_password}` (`views/user/RequestPasswordReset.vue`,
  `PasswordReset.vue:75-95`). Same paths v1/v2. Only when `auth.local.enabled`. Mobile: native screens + deep link
  for the emailed URL. **P1**
* **Logout** — `v2: POST /logout` / `v1: POST /user/logout` (`stores/auth.ts:588-600`); redirects to provider
  `logout_url` for OIDC users. Mobile: settings -> sign out, also clears local DB and cancels scheduled
  notifications. **P0**
* **Link-share access** — URL `{frontend}/share/{hash}/auth[?view=<id>&logoVisible=true|false]`
  (`components/sharing/LinkSharing.vue:266`, `views/sharing/LinkSharingAuth.vue`). `POST /shares/{hash}/auth {password?}`
  -> token + `project_id`; error **13001** = password required, **13002** = wrong password. Link-share sessions get
  a reduced UI (`components/home/ContentLinkShare.vue`: only the shared project and its views; cannot create
  labels `task.label.linkShareCannotCreate`; no time tracking `TaskDetailView.vue:104`). Token renewal:
  `v2/v1: POST /user/token` (link shares only). Mobile: open shared links as a guest session (separate "account"
  entry), or hand off to browser. **P2**
* **Desktop login / quick-entry window** — Electron-only (`views/user/DesktopLogin.vue`, `helpers/desktopAuth.ts`,
  `components/quick-actions/QuickAddOverlay.vue`). **SKIP** (the OAuth flow is the mobile equivalent).
* **Account-gone handling** — 1005/1020/1040 on refresh log the user out (`stores/auth.ts:53-56, 525`). **P0**

---

## 3. Home / overview / upcoming

* **Home (Overview)** (`views/Home.vue`, route `/`) — daytime salutation (`composables/useDaytimeSalutation.ts`,
  `en.json home.welcome*`), account-deletion-scheduled banner with cancel link (`deletion_scheduled_at` from
  `GET /user`), **quick-add input** (§8), import hint, **"Last viewed" projects** (max 6, localStorage
  `projectHistory`, `modules/projectHistory.ts:23`; hidden when `frontend_settings.show_last_viewed === false`),
  and **"Current tasks"** list. Mobile: "Today/Inbox" tab; last viewed as horizontal chips. **P0**
* **Current tasks list** (`views/tasks/ShowTasks.vue:235-280`) — all undone tasks:
  `v2: GET /tasks?filter=done = false&sort_by=due_date&sort_by=id&order_by=asc&order_by=desc&filter_include_nulls=false&expand=comment_count&expand=is_unread&filter_timezone=<tz>`
  (`v1: GET /tasks` with `s` instead of `q`). If the user set `frontend_settings.filter_id_used_on_overview`, the
  overview shows that saved filter instead: `GET /projects/{-filterId-1}/tasks` (`ShowTasks.vue:268-275`).
  Optional label filter `?labels=1&labels=2` -> `&& labels in 1, 2` (`Home.vue`, `ShowTasks.vue:262-266`). Rows can
  be checked off only if `max_permission > READ` on the task's project. Mobile: pull-to-refresh, swipe right = done,
  swipe left = defer/schedule, long-press = multi-select. **P0**
* **Upcoming** (route `/tasks/by/upcoming?from=&to=&showOverdue=&showNulls=`, `router/index.ts:225-234`) — date range
  picker with presets, toggles "Show tasks without dates" (`filter_include_nulls`) and "Show overdue tasks"
  (drops the lower bound). Default range now .. now+7 days. Filter built as
  `done = false && due_date < '<to>' [&& due_date > '<from>']` (`ShowTasks.vue:254-261`). Presets
  (`components/date/dateRanges.ts`): today `now/d..now/d+1d`, tomorrow, lastWeek, thisWeek, restOfThisWeek, nextWeek,
  next7Days, lastMonth, thisMonth, restOfThisMonth, nextMonth, next30Days, thisYear, restOfThisYear (date-math
  strings sent verbatim to the API). Mobile: "Upcoming" tab grouped by day (agenda), segmented control
  Today/Week/Month, overdue section pinned on top, toggles in a filter bottom sheet. **P0**
* **Overdue** — not a separate page; it is the `showOverdue` toggle of Upcoming and the red due-date styling.
  Mobile: dedicated "Overdue" section/widget. **P0**
* **Daily overdue email / email reminders** — user settings only (§16). **P1**
* **MOTD, demo-mode banner, legal links, "add to home screen" PWA banner, update-available banner**
  (`components/home/DemoMode.vue`, `AddToHomeScreen.vue`, `UpdateNotification.vue`, `AppHeader.vue:105-114`).
  Mobile: show MOTD/demo banner and legal links in About; skip PWA/update banners. **P2**

---

## 4. Projects

Routes: `/projects`, `/projects/new`, `/projects/:parentProjectId/new`, `/projects/:id/settings/{edit,background,duplicate,share,webhooks,delete,archive,views}`,
`/projects/:id/info`, `/projects/:id` (redirects to last-used view, `helpers/projectView.ts`), `/projects/:id/:viewId`
(`router/index.ts:249-391`).

Project fields (`types.gen.ts Project`): `id, title (1-250), description (HTML), identifier (0-10 chars),
hex_color (6 hex, no #), is_archived, is_favorite (per user), parent_project_id, position (float), views[],
background_information, background_blur_hash, owner, max_permission, subscription, created, updated`
(`pkg/models/project.go:44-77`).

* **Project list / tree** (`views/project/ListProjects.vue`, sidebar `components/home/ProjectsNavigation*.vue`) —
  card grid; "Show archived" toggle (localStorage `showArchived`); buttons "New project", "New saved filter".
  Sidebar shows Favorites section, Saved filters section, and the project tree with collapsible children.
  API: all pages of `v2: GET /projects?is_archived=true&expand=permissions` (`client/queries/projects.ts:156`) /
  `v1: GET /projects?is_archived=true` (permission via header only on single reads). Mobile: "Projects" tab with
  an expandable tree, color dots, favorites pinned on top, search field. **P0**
* **Create project / child project** (`views/project/NewProject.vue`) — title, parent (`ProjectSearch`), color.
  `v2: POST /projects` / `v1: PUT /projects`. Backend auto-creates views List (filter `done = false`), Gantt, Table,
  Kanban with buckets To-Do / Doing / Done, default = To-Do, done = Done (`pkg/models/project_view.go:816-870,
  439-520`). Mobile: FAB on projects tab -> bottom sheet (title, color swatches, parent picker). **P0**
* **Edit project** (`views/project/settings/ProjectSettingsEdit.vue`) — title, parent (= move), description
  (rich text editor), identifier (tooltip: used for task identifiers like `PROJ-12`), color; admins see Delete.
  `v2: PUT /projects/{id}` (or `PATCH`) / `v1: POST /projects/{id}`. [PERM:w]. Mobile: full-screen form. **P0**
* **Move / reorder projects** — drag in sidebar sets `position` (midpoint algorithm, `helpers/calculateItemPosition.ts`:
  before/after midpoint, +2^16 at end, /2 at start, +0.01 on ties) and `parent_project_id`
  (`ProjectsNavigation.vue:98-127`). Mobile: "Reorder" edit mode with drag handles; "Move to..." action with parent
  picker. **P1**
* **Favorite project** — star in sidebar/menu: `v2: PATCH /projects/{id}` body `[{"op":"replace","path":"/is_favorite","value":true}]`
  (`projects.ts:348-353`) / `v1: POST /projects/{id}` full object. Saved filters favorite via
  `PATCH /filters/{id}` (`ProjectsNavigationItem.vue:221-229`). Mobile: swipe action / long-press menu. **P0**
* **Archive / unarchive** (`ProjectSettingsArchive.vue`) — update with `is_archived` toggled; archived projects show a
  read-only banner (`ProjectWrapper.vue:73-77`); the user's default project cannot be archived or deleted
  (`ProjectSettingsDropdown.vue:86, 116`, `menu.cantArchiveIsDefault`). Mobile: menu action with confirm dialog. **P1**
* **Delete project** (`ProjectSettingsDelete.vue`) — shows how many tasks/child projects will be deleted ("cannot be
  undone"). `v2/v1: DELETE /projects/{id}`. [PERM:a]. Mobile: destructive confirm sheet. **P1**
* **Duplicate project** (`ProjectSettingsDuplicate.vue`) — choose parent, option "duplicate shares".
  `v2: POST /projects/{id}/duplicate {parent_project_id, duplicate_shares}` -> `{duplicated_project}` /
  `v1: PUT /projects/{id}/duplicate`. Mobile: menu action -> sheet. **P2**
* **Project info / description viewer** (`views/project/ProjectInfo.vue`, header "i" button `AppHeader.vue:29`).
  Mobile: collapsible description header in project screen. **P1**
* **Background** (`ProjectSettingsBackground.vue`) [CFG:`enabled_background_providers`] — upload image
  (`v2/v1: PUT /projects/{id}/backgrounds/upload`, multipart field `background`), Unsplash search with paging
  (`GET /backgrounds/unsplash/search?q=&page=`, thumbs `GET /backgrounds/unsplash/images/{id}/thumb`), set Unsplash
  (`v2: PUT /projects/{id}/backgrounds/unsplash {id}` / `v1: POST`), remove (`DELETE /projects/{id}/background`).
  Display: `GET /projects/{id}/background` bytes + `background_blur_hash` placeholder
  (`composables/useProjectBackground.ts`); user setting `background_brightness`. Mobile: photo picker/camera upload,
  Unsplash grid in a sheet, blurhash header image on project screen. **P2**
* **Subscribe to project** — `Subscription` item in project menu (`ProjectSettingsDropdown.vue:93-100`):
  `v2: POST|DELETE /subscriptions/project/{id}` / `v1: PUT|DELETE`. Mobile: bell toggle in project menu. **P1**
* **Project webhooks** (`ProjectSettingsWebhooks.vue` -> `components/misc/WebhookManager.vue`) [CFG:`webhooks_enabled`]
  [PERM:w] — create `{target_url, events[], secret?, basic_auth_user?, basic_auth_password?}`, edit events only,
  delete; events list `GET /webhooks/events`. `v2: GET|POST /projects/{id}/webhooks`, `PUT|DELETE .../{webhook}` /
  `v1: GET|PUT`, `POST|DELETE`. Mobile: plain settings list. **P2**
* **Sharing** — see §11. **P1**
* **Project views management** (`ProjectSettingsViews.vue`, `components/project/views/ViewEditForm.vue`) — only
  project admins may edit (`project.views.onlyAdminsCanEdit`). Per view: `title`, `view_kind` (list/gantt/table/kanban),
  view `filter` (TaskCollection: `filter`, `filter_include_nulls`, `s`, `sort_by`, `order_by`), for kanban
  `bucket_configuration_mode` (`none|manual|filter`) and, in filter mode, `bucket_configuration[] {title, filter}`;
  drag to reorder (`position`); delete. `v2: GET|POST /projects/{id}/views`, `GET|PUT|PATCH|DELETE /projects/{id}/views/{view}` /
  `v1: GET|PUT`, `GET|POST|DELETE`. Default bucket / done bucket are set from the kanban board (§7). Mobile: view
  switcher as segmented control/tabs at top of the project; "Manage views" screen with reorderable list and edit
  sheets; filter editor reuses §9. **P1**
* **Remembered view per project** — last used view id in localStorage (`helpers/projectView.ts:8-29`); user setting
  `frontend_settings.default_view` (`first|list|gantt|table|kanban`, `constants/projectView.ts`). Mobile: same. **P1**
* **Drag a task onto a sidebar project to move it** (`composables/useTaskDragToProject.ts`,
  `ProjectsNavigationItem.vue:125-170`) [DESKTOP]. Mobile: "Move to project" action instead. **P1 (as action)**

---

## 5. List view (`components/project/views/ProjectList.vue`)

* **Task list per view** — `v2: GET /projects/{p}/views/{v}/tasks?page=&sort_by=&order_by=&filter=&filter_include_nulls=&q=&filter_timezone=&expand=subtasks&expand=comment_count&expand=is_unread`
  (`client/queries/tasks.ts:163-170`, `ProjectList.vue:158-160`) / `v1: GET /projects/{p}/views/{v}/tasks` (with `s`).
  Default sort `position asc, id desc` (`tasks.ts:77-86`); URL-persisted `sort`, `filter`, `s`, `page`
  (`composables/useTaskList.ts:63-79`). Pagination with numbered pages (`components/misc/Pagination.vue`).
  Mobile: infinite scroll (keep page numbers internally), pull-to-refresh. **P0**
* **Subtask nesting** — tasks whose parent is in the same view are rendered nested under the parent, cross-project
  subtasks stay top-level (`composables/useTaskListFiltering.ts:14-31`, `SingleTaskInProject.vue` bottom). Needs
  `expand=subtasks`. Mobile: indented rows with expand/collapse chevron. **P0**
* **Row content** (`components/tasks/partials/SingleTaskInProject.vue`) — done checkbox (readonly tooltip if no
  write), color bubble, project link (in cross-project lists), priority label (only `>= minimum_priority` setting,
  `PriorityLabel.vue:3`), title, labels, assignee avatars, due date (relative, red if overdue) with **defer popup**
  (+1 day / +3 days / +1 week, `DeferTask.vue:79-107`), icons for attachments / description / repeating / comment
  count + unread dot (`CommentCount.vue`), checklist progress from description checkboxes (`ChecklistSummary.vue`),
  percent-done bar, favorite star. Mobile: compact two-line row; swipe actions (done, defer, delete), star on
  long-press menu. **P0**
* **Mark done with undo** — `PATCH /tasks/{id}` `done`; toast "done"/"un-done" with **Undo** action; optional pop
  sound (`frontend_settings.play_sound_when_done`, `helpers/playPop.ts`); 300 ms animation delay
  (`SingleTaskInProject.vue:121-170`). Repeating tasks come back undone with shifted dates (server-side, see §6
  repeat). Mobile: haptic + snackbar with Undo. **P0**
* **Add task inline** (`components/tasks/AddTask.vue`) with quick-add magic (§8), hidden on archived projects or
  without write. Mobile: FAB + bottom-sheet composer. **P0**
* **Sort popup** (`components/project/partials/SortPopup.vue:85-104`) — manual (position) or title/priority/due/start/end
  date/percent done/created/updated asc|desc. Valid sort fields: `id, index, done, title, priority, due_date,
  start_date, end_date, percent_done, created, updated, done_at, position` (`useTaskList.ts:25-28`). Mobile: sort
  bottom sheet. **P0**
* **Filter popup** (`components/project/partials/FilterPopup.vue`, `Filters.vue`) — filter query input with
  autocomplete (§9), "include tasks without value", notice that the view's own filter applies additionally
  (`filters.fromView`). Hidden for saved-filter projects. Mobile: filter bottom sheet with chips + raw query field. **P1**
* **"Show done tasks"** — no dedicated toggle: the default List view carries the filter `done = false`
  (`pkg/models/project_view.go:823-825`); users change it via the filter popup or the view's filter. Mobile: offer an
  explicit "Show completed" toggle that rewrites the query (`done = false` vs none) client-side **[inferred design]**. **P0**
* **Drag to reorder** — only when sorting by position and the user can write (or saved-filter project); saves
  `v2: PUT /tasks/{id}/position {project_view_id, position}` / `v1: POST /tasks/{id}/position`, midpoint algorithm
  (`ProjectList.vue:92, 150-165`; server recalculates when spacing too small, `TaskPosition` doc). Mobile:
  long-press-and-drag reorder. **P1**
* **Keyboard j/k/enter navigation** (`components/misc/keyboard-shortcuts/shortcuts.ts:60-75`) [DESKTOP] -> §17.

---

## 6. Table view (`components/project/views/ProjectTable.vue`)

* Column chooser (stored locally): `index (#)`, `done`, `project`, `title`, `priority`, `labels`, `assignees`,
  `commentCount`, `dueDate`, `startDate`, `endDate`, `percentDone`, `doneAt`, `created`, `updated`, `createdBy`
  (`ProjectTable.vue:30-76`); click headers to sort (`composables/useTableSort.ts`); filter popup; pagination;
  `expand=comment_count,is_unread` (`ProjectTable.vue:414`). Same list endpoint as §5.
  Mobile: render as a "detailed list" (configurable secondary fields on each row) or a horizontally scrollable data
  table in landscape/tablet. **P2 [DESKTOP]**

## 7. Kanban view (`components/project/views/ProjectKanban.vue`)

Bucket fields (`types.gen.ts Bucket`): `id, title, limit (0 = none), count, position, project_view_id, tasks[],
created, created_by, updated`. View fields `default_bucket_id`, `done_bucket_id`, `bucket_configuration_mode`.

* **Load board** — `v2: GET /projects/{p}/views/{v}/buckets/tasks?per_page=25&expand=comment_count&expand=is_unread&<filter params>`
  (first 25 tasks per bucket, `client/queries/kanban.ts:5-9, 73-85`); **load more per bucket**:
  `GET /projects/{p}/views/{v}/tasks?page=N&per_page=25&sort_by=position&order_by=asc&filter=(<f>) && bucket_id = <b>`
  (`kanbanMutations.ts:97-113`). Bucket list only: `GET .../buckets`.
  `v1: GET /projects/{p}/views/{v}/tasks` returns buckets-with-tasks (`pkg/models/task_collection.go:206-213`).
  Mobile: horizontally paged columns (one bucket per screen, peek next), infinite scroll per column. **P0**
* **Move task between buckets** — drag; `v2: PUT /projects/{p}/views/{v}/buckets/{b}/tasks {task_id}` ->
  `{task, bucket}` / `v1: POST .../buckets/{b}/tasks`; plus position update in the target view (§5). On touch
  devices a dedicated drag handle is rendered and tapping the card opens it (`ProjectKanban.vue:217-235`).
  Task detail also has a **bucket select** dropdown for manual-mode kanban views (`components/tasks/partials/BucketSelect.vue`).
  Mobile: long-press drag across columns with edge auto-scroll **and** a "Move to bucket" bottom sheet. **P0**
* **Done bucket** — moving a task into it marks it done; marking a task done moves it there; un-done moves it back to
  the default bucket (`taskMutations.ts:reconcileDoneBuckets`, `project.kanban.doneBucketHintExtended`); repeating tasks
  bounce back (`@taskCompletedRecurring`). Toggle via bucket menu (`toggleDoneBucket`) = update view `done_bucket_id`.
  Mobile: bucket menu item with checkmark. **P1**
* **Default bucket** — where new tasks land (`default_bucket_id`, `toggleDefaultBucket`). **P1**
* **Bucket CRUD** — add bucket (`v2: POST .../buckets {title}` / `v1: PUT`), rename inline
  (`v2: PUT .../buckets/{b}` / `v1: POST`), delete (cannot delete last bucket, `project.kanban.deleteLast`;
  server clears `default_bucket_id`/`done_bucket_id`), reorder buckets by drag (position). [PERM:w]. Mobile: column
  header menu (rename, limit, done/default, collapse, delete), "Add column" page at the end. **P1**
* **WIP limit** — `limit`; header shows `count/limit`, highlights when full, disables adding tasks
  (`ProjectKanban.vue` "limit" block). **P1**
* **Collapse bucket** — local only (`helpers/saveCollapsedBucketState.ts`). Mobile: collapse to a thin column / hide
  from pager. **P2**
* **Add task in bucket** — inline input per bucket with quick-add magic; blocked at limit. **P0**
* **Card** (`components/tasks/partials/KanbanCard.vue`) — cover image (attachment `cover_image_attachment_id`), done
  badge, due date, project title (in saved filters), percent bar, labels, priority, icons (attachments, description,
  repeat), comment count, assignees, checklist summary. Ctrl-click marks done [DESKTOP]. **P0**
* **Filter-based buckets** (`bucket_configuration_mode = filter`) — buckets computed from per-bucket filters,
  not draggable (`ViewEditForm.vue`). Mobile: read-only columns. **P2**
* **"Always show bucket task count"** user setting (§16). **P2**

## 8. Gantt view (`components/project/views/ProjectGantt.vue`, `components/gantt/*`) [DESKTOP]

* Date range (default today .. +7 days, `ProjectGantt.vue:114-121`), "show tasks without dates", all tasks fetched
  with `fetchAllPages` and filter
  `((start_date >= from && start_date <= to) || (end_date >= from && end_date <= to) || (start_date <= from && end_date >= to))`
  sorted by `start_date, done` (`views/project/helpers/useGanttFilters.ts:83-96`, `useGanttTaskList.ts`).
* Drag bar = move, drag edges = resize start/end, keyboard arrows move/expand/shrink; bars for partial dates
  ("start only / end only"), "scheduled vs estimated" styling; parent/subtask tree with expand/collapse
  (`helpers/ganttTaskTree.ts`); relation arrows toggle (`helpers/ganttRelationArrows.ts`); add task row; updates via
  `PATCH /tasks/{id}` `start_date`/`end_date` rounded to day boundaries (`GanttChart.vue:535-545`).
* Mobile: read-only horizontal timeline (pinch to zoom, tap bar to open task) or replace with an **agenda/calendar
  view**; editing dates via the task detail. **P2 / SKIP? for editing**

---

## 9. Task detail (`views/tasks/TaskDetailView.vue`, route `/tasks/:id`, opened as modal over lists)

Load: `v2: GET /tasks/{id}?expand=reactions&expand=is_unread&expand=buckets[&expand=time_entries_count]`
(`TaskDetailView.vue:108-116`) / `v1: GET /tasks/{id}`. If `is_unread`, `v2: PUT /tasks/{id}/read` /
`v1: POST /tasks/{id}/read` (`:387`). Writes: `v2: PATCH /tasks/{id}` JSON Patch of changed fields
(`taskMutations.ts:181-190`; writable fields `title, description, done, due_date, start_date, end_date, priority,
hex_color, percent_done, repeat_after, repeat_mode, is_favorite, bucket_id, project_id, reminders,
cover_image_attachment_id`, `:44-62`; empty dates are sent as `0001-01-01T00:00:00Z` to clear, `:43, 72-77`) /
`v1: POST /tasks/{id}` with the full task. Fields only appear once set or added from the action sidebar
(`activeFields.*`). Task type: see `types.gen.ts Task` (also `identifier`, `index`, `created_by`, `done_at`,
`related_tasks{kind:[Task]}`, `reactions{emoji:[User]}`, `subscription`, `deleted_at`).

Mobile shell: full-screen page (push) with a sticky header (identifier, done button, overflow menu) and
property "chips" that open bottom sheets; "Add property" sheet replaces the desktop action sidebar. **P0 overall**

* **Header** (`components/tasks/partials/Heading.vue`) — color dot, **identifier** (`PROJ-12` or `#12`,
  `helpers/task.ts:44-49`; tap copies the task URL `/tasks/{id}`), done badge, inline-editable **title** with
  saving/saved indicator, project breadcrumb (parent chain) and **bucket select**. Mobile: tap title to edit; share
  sheet with link / identifier. **P0**
* **Done / Undone** — big button (shortcut `t`). **P0**
* **Favorite** (shortcut `s`) — `PATCH /tasks/{id}` `is_favorite` (`taskMutations.ts:255-260`); feeds the Favorites
  pseudo project. **P0**
* **Description** (`components/tasks/partials/Description.vue`, TipTap editor `components/input/editor/*`) — HTML;
  autosave with delay + explicit save, local draft persistence (`helpers/editorDraftStorage.ts`, localStorage).
  Editor features: bold/italic/underline/strike, sub/superscript, headings 1-3, bullet/ordered lists, **task
  lists/checklists** (nested, checkable even in read mode by toggling `checked` on `taskItem` with stable
  `data-task-id`, `editorExtensions.ts:342-386`), blockquote, code + code blocks with syntax highlight, tables,
  links, horizontal rule, images, typography, emoji (`:` suggestions), slash-command menu (`/`, `suggestion.ts`),
  **@mentions** of project users (`mention-user` nodes, search `GET /projects/{p}/users/search?q=`,
  `mention/mentionSuggestion.ts`), **task links** (URLs to `/tasks/{id}` on this instance render as live pills with
  title/done state, `taskLink.ts`, `helpers/parseTaskIdFromUrl.ts`), paste/drag images -> uploaded as attachments
  and inserted (`TipTap.vue:473-520`, `PasteHandler`). Checklist progress shown in lists (`ChecklistSummary.vue`).
  API alternative for mobile: `?format=markdown` / `X-Vikunja-Format: markdown` (lossy; underline, colors etc. lost,
  `richtext.go`). Mobile: native rich-text editor with a markdown-like toolbar above the keyboard; render HTML
  read-only by default, edit on tap; interactive checkboxes in read mode. **P0 (view+basic edit), P1 (full editor)**
* **Due date** (shortcut `d`) — datepicker with quick-select shortcuts (today, tomorrow, next Monday, this weekend,
  later this week, next week; `helpers/time/calculateDayInterval.ts`), time control, clear; user setting
  `default_due_time` pre-fills time. Mobile: native date+time picker in a sheet with preset chips. **P0**
* **Start date / End date** — same picker. **P1**
* **Reminders** (shortcut Alt/Shift+R, `Reminders.vue`, `ReminderDetail.vue`, `ReminderPeriod.vue`) — list of
  `TaskReminder {reminder (absolute ISO), relative_period (seconds, negative = before), relative_to
  ('due_date'|'start_date'|'end_date')}`; presets: at due, 2 h, 1 day, 3 days, 1 week, 30 days before
  (`ReminderDetail.vue:130-137`); custom relative (minutes/hours/days/weeks before/after) or absolute date.
  Server fires reminders as email (if `email_reminders_enabled` setting) and as in-app `task.reminder`
  notification. Mobile: schedule **local notifications** for each resolved reminder, with "Mark done" / "Snooze"
  actions (the user requirement); sheet with presets. **P0**
* **Repeat** (`RepeatAfter.vue`) — `repeat_after` seconds + `repeat_mode`: 0 default (every N hours/days/weeks),
  1 monthly (ignores `repeat_after`), 2 from current date; quick buttons every day / every week / every 30 days.
  Marking done re-opens and shifts dates/reminders (server; `Task.repeat_after` doc). Mobile: repeat sheet with
  presets + custom interval. **P0**
* **Priority** (shortcut `p`) — 0 unset, 1 low, 2 medium, 3 high, 4 urgent, 5 DO NOW (`constants/priorities.ts`);
  high+ shown with exclamation (`PriorityLabel.vue`). Mobile: segmented chips. **P0**
* **Percent done** — 0..1 in steps of 0.1 (`PercentDoneSelect.vue:10`). Mobile: slider with 10 % detents. **P1**
* **Color** (shortcut `c`) — `hex_color`, palette + custom (`components/input/ColorPicker.vue:76`). **P1**
* **Labels** (shortcut `l`, `EditLabels.vue`) — multiselect with search over all labels, create-on-the-fly with random
  color (`v2: POST /labels`), add `v2: POST /tasks/{id}/labels {label_id}` / `v1: PUT`, remove
  `DELETE /tasks/{id}/labels/{label}`; bulk replace exists (`v2: PUT /tasks/{id}/labels/bulk` / `v1: POST`, unused by
  web). Link shares cannot create labels. Mobile: chip picker sheet with search + "Create '…'". **P0**
* **Assignees** (shortcut `a`, `EditAssignees.vue`) — search users with access to the project
  `v2: GET /projects/{p}/users/search?q=` / `v1: GET /projects/{p}/projectusers?s=` (`pkg/routes/api/v1/user_list.go:102`); add
  `v2: POST /tasks/{id}/assignees {user_id}` / `v1: PUT`; remove `DELETE /tasks/{id}/assignees/{userId}`; bulk
  `v2: PUT /tasks/{id}/assignees/bulk` / `v1: POST`. Avatars via `GET /avatar/{username}?size=`. Mobile: avatar
  picker sheet. **P0**
* **Attachments** (shortcut `f`, `Attachments.vue`) [CFG:`task_attachments_enabled`] — upload multiple files with
  progress (`v2/v1: PUT|POST /tasks/{id}/attachments` multipart `files`; v2 returns `{success[], errors[]}` per-file,
  `types.gen.ts AttachmentUploadResult`), drop zone over the whole task, paste images into editor, list with image
  thumbnails (`GET /tasks/{id}/attachments/{aid}?preview_size=sm|md|lg|xl`), image lightbox, inline PDF and audio
  preview, download, copy URL, delete (confirm), **set/unset as cover image** (`cover_image_attachment_id`). Max
  size `max_file_size` from `/info`. Mobile: camera/photo/document picker, **share-sheet target** ("Share to
  Vikunja" creates task or attaches), native viewer (QuickLook / Intent), long-press menu. **P1**
* **Related tasks** (shortcut `r`, `RelatedTasks.vue`) — kinds `subtask, parenttask, related, duplicateof,
  duplicates, blocking, blocked, precedes, follows, copiedfrom, copiedto` (`types.gen.ts TaskRelation`); search tasks
  across projects (`GET /tasks?q=<text>&sort_by=done`), or **create a new task and relate it**; default kind from
  setting `default_task_relation_type`; delete with confirm. `v2: POST /tasks/{id}/relations {other_task_id,
  relation_kind}` / `v1: PUT`; `DELETE /tasks/{id}/relations/{kind}/{otherId}`. Inverse relation is created by the
  server. Mobile: "Subtasks" section with inline add + checkboxes (most important kind), other relations grouped
  under "Links". **P0 (subtasks), P1 (others)**
* **Move to project** (shortcut `m`) — `ProjectSearch` -> `PATCH /tasks/{id}` `project_id` (needs write on target).
  Mobile: project picker sheet. **P0**
* **Duplicate** — `v2: POST /tasks/{id}/duplicate` -> `{duplicated_task}` / `v1: PUT /tasks/{id}/duplicate`; navigates
  to the copy (`TaskDetailView.vue:562-570`). **P1**
* **Delete** (shortcut Delete/Backspace) — confirm modal; `v2/v1: DELETE /tasks/{id}`; navigates back to the project.
  Server soft-deletes (`deleted_at`, kept 30 days, `pkg/models/tasks.go:147`) but **no restore UI or route was found**
  in the frontend. Mobile: confirm sheet; optional "Undo" snackbar would need a server restore endpoint (none found). **P0**
* **Subscribe to task** (`TaskSubscription`, `components/misc/Subscription.vue`) — shows inherited subscription
  when subscribed via the project (disabled toggle). `v2: POST|DELETE /subscriptions/task/{id}` / `v1: PUT|DELETE`.
  Mobile: bell icon in header. **P1**
* **Comments** (`components/tasks/partials/Comments.vue`) [CFG:`task_comments_enabled`] — paginated list
  `v2: GET /tasks/{id}/comments?order_by=asc|desc&page=` (`client/queries/comments.ts:55-65`), sort order toggle saved
  to `frontend_settings.comment_sort_order`; rich-text editor with mentions and image upload; create
  (`v2: POST` / `v1: PUT /tasks/{id}/comments {comment}`), edit own (`v2: PUT .../{cid}` / `v1: POST`), delete
  (confirm), **reply/quote** (prefills `<blockquote data-comment-id="…">`, mentions stripped, `Comments.vue:326-357`),
  permalink `#comment-{id}`, "edited" marker, author avatar. Mobile: chat-style thread at the bottom of the task or a
  "Comments" tab; composer pinned above keyboard; swipe-to-reply. **P1**
* **Reactions** (`components/input/Reactions.vue`) on tasks and comments — emoji picker, toggle own reaction;
  `v2: POST /{tasks|comments}/{id}/reactions {value}`, remove `POST /{kind}/{id}/reactions/delete {value}`, list
  `GET /{kind}/{id}/reactions` / `v1: PUT` create, same delete. Only with write access (changelog 0.24.0).
  Mobile: long-press -> emoji bar. **P2**
* **Unread state** — `expand=is_unread` drives an unread dot on the comment-count icon (`CommentCount.vue:6-13`);
  opening the task marks it read. Mobile: unread badge in lists. **P1**
* **Created / updated / done-at by** (`CreatedUpdated.vue`) — "created {since} by {user}", "updated {since}",
  "done {since}". **P1**
* **Time tracking panel** — §13 [LIC:time_tracking]. **P2**
* **Copy helpers** — `.` copies identifier, `..` identifier+title, `...` + URL, Ctrl+. copies URL
  (`composables/useTaskDetailShortcuts.ts:60-90`) [DESKTOP]. Mobile: share sheet with these three formats. **P1**
* **Glance tooltip on hover** (`TaskGlanceTooltip.vue`) [DESKTOP]. Mobile: long-press peek preview. **P2**
* **Scroll to bottom button, back button, close** — mobile navigation handles these. n/a

---

## 10. Quick Add Magic (`frontend/src/modules/quickAddMagic/*`, `composables/useQuickAddTask.ts`, `components/tasks/AddTask.vue`)

* **Prefix modes** (`prefixes.ts`): `vikunja` (default) label `*`, project `+`, priority `!`, assignee `@`;
  `todoist` label `@`, project `#`, priority `!`, assignee `+`; `disabled`. User setting
  `frontend_settings.quick_add_magic_mode`.
* **Parsing** (`quickAddMagic.ts:14`, types `ParsedTaskText {text, date, labels[], project, priority, assignees[], repeats}`):
  labels/projects support quotes for spaces (`*"Label with spaces"`, `prefixParser.ts:3-38`); priority `!1`..`!5`;
  dates: `today`, `tonight`, `tomorrow`, `next monday`, `this weekend`, `later this week`, `later next week`,
  `next week`, `next month`, `end of month`, `in N days/weeks…`, weekday names, month names / numeric dates,
  `17th` of current month, `at 15:00` / `3pm` (`dateParser.ts:47-165`); repeat: `every [N|one..ten] hours|days|weeks|months|years`,
  `daily, hourly, weekly, monthly, yearly, annually, biannually, semiannually, biennially` (`repeatParser.ts`).
* **Execution** (`useQuickAddTask.ts:48-160`): project resolved by exact title or identifier from all projects
  (error if missing), else current route project, else default project; labels created if missing
  (`POST /labels` with random color); assignees resolved by `GET /projects/{p}/users/search?q=`; then
  `POST /projects/{p}/tasks` and per-label/assignee calls (`runWrites`, serialized when `concurrent_writes=false`).
  Default reminders from `frontend_settings.quick_add_default_reminders [{relative_period}]`.
* **Multi-line paste** -> one task per line via `v2: POST /projects/{p}/tasks/bulk` (≤100 tasks, 2.5.0+) [v2-only];
  **indentation creates parent/subtask relations** (`helpers/parseSubtasksViaIndention.ts`, `AddTask.vue:137-231`).
  v1 fallback: one `PUT /projects/{p}/tasks` per line **[inferred]**.
* Mobile: single composer used everywhere (FAB, widget "+", share sheet, Siri/App Intents/Android shortcuts),
  live-highlight recognised tokens as chips (like the web `QuickAddMagic.vue` help), port the parser to Dart (pure
  functions, has an extensive test file `quickAddMagic.test.ts` to port as golden tests). **P0**

---

## 11. Filters, saved filters, search

* **Filter query language** (`helpers/filters.ts`, `components/input/filter/*`, i18n `filters.query.help`):
  fields `done, priority, percentDone, dueDate, startDate, endDate, doneAt, reminders, created, updated,
  assignees, createdBy, labels, project` (project only in saved filters); operators `!= = > >= < <= like in
  'not in' ?=`; joins `&& || ( )`; date math (`now`, `now/d`, `now+7d`, `now/w-1w`, …, `DatemathHelp.vue`).
  The UI shows label/project **titles** but the API needs **ids** and snake_case field names:
  `transformFilterStringForApi` maps `labels in Foo` -> `labels in 3`, `dueDate` -> `due_date`
  (`filters.ts:93-192`); the reverse runs when loading. Always send `filter_timezone=<user tz>`.
  Autocomplete for labels/assignees/createdBy/project values (`FilterAutocomplete.ts`), syntax highlighting
  (`highlighter.ts`). Mobile: visual filter builder (field -> operator -> value pickers, chips) that serialises
  to the same query, with an "advanced" raw text field. **P1**
* **Saved filters** (`views/filters/FilterNew.vue`, `FilterEdit.vue`, `FilterDelete.vue`) — title, description
  (rich text), filter (TaskCollection), favorite. `v2: POST /filters`, `GET|PUT|PATCH|DELETE /filters/{id}` /
  `v1: PUT /filters`, `GET|POST|DELETE /filters/{id}`. Owner only. They appear as pseudo projects (§1.3) with
  views (manage views as for projects). Can be selected as the overview list (§3). Mobile: "Smart lists" section;
  create from the current filter sheet ("Save as smart list"). **P1**
* **Global search / quick actions** (`components/quick-actions/QuickActions.vue`, Ctrl/Cmd+K) — one box searching
  commands (new task / new project / new team), projects (local), tasks
  (`GET /tasks?q=<text>&sort_by=done&sort_by=relevance&filter=labels in …`), labels, teams
  (`GET /teams?q=&include_public=`); syntax `+project`, `*label`, `@team` to scope; Enter creates a task in the
  current project. `relevance` sort needs a search term and DB support (`TasksListData` doc). Mobile: search tab /
  pull-down search field with scoped tokens and recent searches. **P0 (task+project search), P2 (commands)**

## 12. Labels (`views/labels/ListLabels.vue`, `NewLabel.vue`)

Fields: `id, title (1-250), description, hex_color, created_by, created, updated` (`types.gen.ts Label`).
List: all pages of `v2: GET /labels` (visible = own + labels on accessible tasks) / `v1: GET /labels`. Create
(`v2: POST /labels` / `v1: PUT`), edit title/description/color and delete **only by creator**
(`ListLabels.vue:41`; `v2: PUT|PATCH|DELETE /labels/{id}` / `v1: POST|DELETE`). Tap a label on home filters the
overview (`?labels=`). Mobile: Labels screen in "More" tab, swipe-to-delete, color chips; "show tasks with label"
action. **P1**

## 13. Teams (`views/teams/*`, `components/teams/EditTeamForm.vue`)

Fields: `id, name, description, is_public, external_id, members[] {…User, admin}, created_by` (`types.gen.ts Team`).
* List (`v2/v1: GET /teams`), create (`v2: POST` / `v1: PUT /teams {name, is_public?}`), edit name/description/public
  (`v2: PUT|PATCH /teams/{id}` / `v1: POST`), delete. **P1**
* Members: add by username search (`GET /users?q=`, `v2: POST /teams/{id}/members {username, admin:false}` /
  `v1: PUT`), remove (`DELETE /teams/{id}/members/{username}`), toggle admin (`POST .../members/{username}/admin`),
  leave team (with "access cleanup" notice: assignments, subscriptions and webhooks lost,
  `components/sharing/ProjectAccessCleanupList.vue`). Only team admins edit. **P1**
* **Public teams** [CFG:`public_teams_enabled`] — `is_public` checkbox; discoverable via `include_public=true`. **P2**
* **OIDC/LDAP (external) teams** — `external_id` set => read-only in the UI (no member editing, no leave,
  `EditTeam.vue:7, 22, 122`); synced by the server. Mobile: show a "managed by {provider}" badge. **P2**
* Mobile: teams under "More" -> list/detail with member list and swipe actions. **P1**

## 14. Sharing (`views/project/settings/ProjectSettingsShare.vue`, `components/sharing/*`)

Permissions 0 read, 1 read+write, 2 admin (`constants/permissions.ts`).
* **User shares** — list (`v2/v1: GET /projects/{p}/users`), search users (`GET /users?q=`; name/email matching only
  for users who are discoverable, email never returned, `sdk.gen.ts usersSearch` doc), add
  (`v2: POST /projects/{p}/users {username, permission}` / `v1: PUT`), change permission
  (`v2: PUT /projects/{p}/users/{username}` / `v1: POST`), remove (`DELETE`). **P1**
* **Team shares** — same with `/projects/{p}/teams`, body `{team_id, permission}`; team search includes public teams
  when enabled. **P1**
* **Link shares** [CFG:`link_sharing_enabled`] [PERM:a] — create `{permission, name?, password?}`
  (`v2: POST /projects/{p}/shares` / `v1: PUT`), list, delete; per-row "open in view" selector builds
  `{frontend_url}share/{hash}/auth?view={id}`; copy link (`LinkSharing.vue:266`). `sharing_type` 1 = no password,
  2 = password. Mobile: native **share sheet** with the generated URL, QR code. **P1**
* Mobile: "Share" screen per project with three sections; search with debounce. **P1**

## 15. Notifications center (`components/notifications/Notifications.vue`, `helpers/notification.ts`)

* Bell in header with unread count; list (`v2: GET /notifications?page=&per_page=` / `v1: GET /notifications`),
  "load more", mark one read/unread (`v2: PUT /notifications/{id} {read}` / `v1: POST`), mark all read
  (`POST /notifications`), clear all (`DELETE /notifications`), subscribe to Atom feed link.
* Types and routing (`helpers/notification.ts:1-110`): `task.comment` (-> task), `task.assigned`, `task.deleted`,
  `task.created`, `task.reminder` (-> task), `task.mentioned` (-> task), `project.created` (-> project),
  `team.member.added` (-> team). Payload `notification.{task, project, doer, assignee, member, team}`; `read_at`.
* Live updates via WebSocket `notification.created`, else 10 s polling (§1.4).
* Mobile: Inbox/Activity screen; **convert new notifications to OS notifications** in background fetch (the server
  has no push service: a grep for `fcm|apns|firebase|unifiedpush|webpush` over `pkg/**/*.go` finds nothing);
  tap -> deep link to task. **P0**
* **Atom feed** (`views/user/settings/AtomFeed.vue`) — URL `{api root}/feeds/notifications.atom` (v1 group) or
  `v2: GET /notifications.atom`, authenticated with an API token. Mobile: show/copy URL only. **P2**

## 16. User settings (`views/user/Settings.vue` + `views/user/settings/*`)

Menu entries and conditions (`Settings.vue:20-91`): General; Password (local users); Email (local users); Avatar;
TOTP ([CFG:`totp_enabled`] + local); Data export; Import/Migrate (if migrators); CalDAV ([CFG:`caldav_enabled`]);
MCP; Feeds; API tokens; Sessions; Webhooks ([CFG:`webhooks_enabled`]); Bots; Delete account
([CFG:`user_deletion_enabled`]); plus server-provided `extra_settings_links` from the OIDC provider.

* **General** (`GeneralSettingsForm.vue`) — server fields (`types.gen.ts UserGeneralSettings`): `name`,
  `default_project_id`, `email_reminders_enabled`, `overdue_tasks_reminders_enabled`, `overdue_tasks_reminders_time`
  (HH:MM), `language`, `timezone` (list from `GET /user/timezones`), `week_start` (0 Sun … 6 Sat),
  `discoverable_by_name`, `discoverable_by_email`; name read-only for external users. **Frontend settings** (free JSON
  blob `frontend_settings`, defaults in `helpers/userSettings.ts:17-90`): `default_view`, `minimum_priority`
  (default 2), `default_due_time`, `filter_id_used_on_overview`, `show_last_viewed`, `date_display`
  (`relative`, `mm-dd-yyyy`, `dd-mm-yyyy`, `yyyy-mm-dd`, `mm/dd/yyyy`, `dd/mm/yyyy`, `yyyy/mm/dd`, `dayMonthYear`,
  `weekdayDayMonthYear`), `time_format` (`12h|24h`), `time_tracking_default_start`, `color_schema`
  (`light|auto|dark`), `quick_add_magic_mode`, `quick_add_default_reminders`, `default_task_relation_type`,
  `play_sound_when_done`, `allow_icon_changes`, `always_show_bucket_task_count`, `background_brightness`,
  `comment_sort_order`, `sidebar_width`, `desktop_quick_entry_shortcut`.
  Read: `GET /user` (settings embedded) or `v2: GET /user/settings/general`. Write: `v2: PATCH /user/settings/general`
  with **`Content-Type: application/merge-patch+json`**, 304 = nothing changed (`client/queries/account.ts:206-228`) /
  `v1: POST /user/settings/general` (full object). Mobile: honour the shared settings (date display, time format,
  week start, timezone, minimum priority, quick-add mode, default reminders, default view, theme); store mobile-only
  prefs under a namespaced key such as `frontend_settings.mobile_*` via merge-patch so web keys are preserved
  **[inferred design]**. **P0 (read & apply), P1 (edit)**
* **Password change** — `POST /user/password {old_password, new_password}` (same v1/v2). Local users only. **P1**
* **Email change** — new email + current password: `v2: PUT /user/settings/email` / `v1: POST`; pending state with
  resend (`v2: POST /user/settings/email/resend`) and cancel (`v2: DELETE /user/settings/email`) [v2-only]; confirmed via
  emailed `?userEmailConfirm=` link (`EmailUpdate.vue`, `router/index.ts:500-523`). **P2**
* **Avatar** — providers `default, initials, gravatar, marble, upload` (+ `ldap`/`openid` read-only)
  (`Avatar.vue:96-102`); upload with square cropper. `v2: GET|PUT|PATCH /user/settings/avatar/provider`,
  `PUT /user/settings/avatar` (multipart) / `v1: GET|POST /user/settings/avatar`, `PUT /user/settings/avatar/upload`.
  Mobile: camera/gallery + native cropper. **P2**
* **TOTP 2FA** — enroll (`POST /user/settings/totp/enroll`), QR (`GET .../qrcode`, PNG) + secret, confirm passcode
  (`POST .../enable {passcode}`), disable with password (`POST .../disable {password}`), status `GET .../totp`.
  Mobile: show secret as an `otpauth://` link button to open an authenticator app on the same device. **P2**
* **CalDAV** [CFG:`caldav_enabled`] — URL `{api root}/dav/principals/{username}/` (`Caldav.vue:175`), token list /
  create (`v2: POST` / `v1: PUT /user/settings/token/caldav`, token shown once) / delete. Mobile: info screen (copy URL,
  create token); note iOS can add CalDAV accounts natively. **P2**
* **API tokens** (`ApiTokens.vue`, `components/token/ApiTokenForm.vue`) — title, expiry (30/60/90/365 days, custom,
  never), permission scopes `{group: [perm,…]}` from `GET /routes` (license-gated groups removed at runtime,
  `pkg/models/api_routes.go:370-400`), presets; token shown once. `v2: GET|POST /tokens`, `DELETE /tokens/{id}` /
  `v1: GET|PUT|DELETE`. Mobile: list + create flow with grouped checkboxes; copy-once dialog. **P2**
* **Sessions** — list `{id, device_info, ip_address, last_active, created}`, current marked, revoke
  (`GET /user/sessions`, `DELETE /user/sessions/{uuid}`, same on v1). Mobile: "Devices" screen; the app's own OAuth
  session appears here. **P2**
* **User webhooks** [CFG:`webhooks_enabled`] — like project webhooks but user-directed events only
  (`GET /user/settings/webhooks/events`); `v2: GET|POST /user/settings/webhooks`, `PUT|DELETE .../{id}` /
  `v1: GET|PUT`, `POST|DELETE`. **P2 / SKIP?**
* **Bot users** (`BotUsers.vue`, since 2.4.0) — create bot (username, name), edit, enable/disable, delete, manage the
  bot's API tokens (`ApiToken.owner_id`). `v2: GET|POST /user/bots`, `GET|PUT|PATCH|DELETE /user/bots/{bot}` /
  `v1: PUT /user/bots`, `GET`, `POST|DELETE /user/bots/{bot}`. **P2 / SKIP?**
* **MCP** (`Mcp.vue`, `components/token/McpClientGuide.vue`) — shows MCP endpoint (`v2: GET /mcp/info`) and setup
  guides for AI clients, lists tokens [v2-only]. **SKIP? [DESKTOP]**
* **Data export** — request with password (`POST /user/export/request {password}`), status (`GET /user/export`),
  download zip (`POST /user/export/download {password}`, blob); emailed link opens `/user/export/download`
  (`views/user/DataExportDownload.vue`). Mobile: request + download to Files/share sheet. **P2**
* **Account deletion** [CFG:`user_deletion_enabled`] — request with password (`POST /user/deletion/request`), email
  confirm (`POST /user/deletion/confirm {token}`), scheduled state with cancel (`POST /user/deletion/cancel {password}`);
  banner on home. Mobile: required by App Store guideline 5.1.1(v) for apps with account creation
  **[inferred: policy, not source]**. **P1**
* **Import / migration** (`views/migrate/*`) [CFG:`available_migrators`] — OAuth importers todoist, trello,
  microsoft-todo (`GET /migration/{svc}/auth` -> provider -> callback `/migrate/{svc}?code=` ->
  `POST /migration/{svc}/migrate {code}`, poll `GET /migration/{svc}/status` `{started_at, finished_at}`); file importers
  vikunja-file, ticktick, wekan (multipart `POST /migration/{svc}/migrate`); credentials importer planka (URL + API
  key or password); **CSV wizard** (`MigrationCSV.vue`: upload -> `POST /migration/csv/detect` -> column mapping,
  delimiter, date format, skip rows -> `POST /migration/csv/preview` -> `POST /migration/csv/migrate`, status).
  v1 has the same `/migration/<svc>/...` routes for todoist/trello/microsoft-todo/vikunja-file/ticktick/wekan/csv
  (`pkg/routes/routes.go:1005-1046`); planka and CSV detect/preview appear v2-only **[inferred from route list]**.
  Mobile: link out to the web UI ("Import on the web"), maybe support file import from the share sheet. **SKIP? / P2**

## 17. Time tracking [LIC:time_tracking] [v2-only] (since 2.4.0)

Gate: `GET /info -> enabled_pro_features` contains `time_tracking`; routes 404 otherwise; hidden for link shares.
TimeEntry: `{id, task_id | project_id (exactly one), start_time, end_time (null = running timer), comment, user_id,
created, updated}` (`types.gen.ts TimeEntry`).
* **Timer** — start = `POST /time-entries {task_id, start_time}` without end; stop `POST /time-entries/timer/stop`;
  active timer = `GET /time-entries?filter=user_id = {me} && end_time = null` (`client/queries/timeEntries.ts:72-80`);
  header badge with elapsed time + stop (`components/time-tracking/TimerBadge.vue`), favicon indicator
  (`useTimeTrackingFavicon.ts`); WebSocket `timer.*` events keep tabs in sync. Mobile: start/stop in task detail,
  **ongoing notification / Live Activity** with stop action, widget. **P2**
* **Manual entries** (`TimeEntryForm.vue`) — project or task, comment, from/to, "smart fill" start
  (`helpers/time/smartFillStart.ts`), user setting `time_tracking_default_start`. CRUD `POST /time-entries`,
  `PUT|PATCH|DELETE /time-entries/{id}` (author only). **P2**
* **Per-task panel** (`TaskTimeTracking.vue`) — list for task (`GET /time-entries?filter=task_id = X` or
  `GET /tasks/{id}/time-entries`), `expand=time_entries_count` on the task. **P2**
* **Time tracking page** (`views/time-tracking/TimeTracking.vue`, route `/time-tracking`) — paginated list with
  filter modal (date range, project, task, user), filter persisted in URL; filter syntax over `user_id, task_id,
  project_id, start_time, end_time` (`TimeEntriesListData` doc). **P2**

## 18. Admin panel [ADMIN] [LIC:admin_panel] (route `/admin`, `views/admin/*`)

All under `v2: /admin/*` (v1 subset under `/api/v1/admin/*`: overview, users list/create/patch admin/status/delete,
projects list/owner, `routes.go:988-995`). Non-admin or unlicensed => 404.
* **Overview** — counts (users, projects, tasks, teams, user/team/link shares), version, license status
  (`GET /admin/overview`). **P2**
* **Users** — search/list (`GET /admin/users?q=`), create (`POST /admin/users` with `is_admin`, `skip_email_confirm`),
  promote/demote (`PATCH /admin/users/{id}/admin`), status (`PATCH .../status`), set password (`PATCH .../password`,
  412 for external accounts) [v2-only], send reset email (`POST .../password-reset-email`) [v2-only], delete
  (`DELETE /admin/users/{id}?mode=now|scheduled`), details (issuer/subject for OIDC). **P2**
* **Projects** — list all incl. archived, filter by owner, hide default projects, reassign owner
  (`GET /admin/projects`, `PATCH /admin/projects/{id}/owner`). **P2**
* **Invite links** [LIC:user_invites] [v2-only] — list/create (name, max uses, expiry, teams via `GET /admin/teams`,
  skip email confirm; token shown once)/delete (`/admin/invite-links`). **P2**
* Mobile: read-mostly admin section behind the avatar menu, only when `is_admin` and the feature is licensed.
  **P2 / SKIP?**

## 19. Keyboard shortcuts -> mobile equivalents (`constants/shortcuts.ts`, `components/misc/keyboard-shortcuts/shortcuts.ts`)

| Web shortcut | Action | Mobile equivalent |
|---|---|---|
| Mod+K | quick search / actions | Search tab, pull-down search, Spotlight/App Search indexing |
| Mod+E | toggle sidebar | bottom navigation / drawer swipe |
| Shift+/ | shortcut help | n/a (hardware-keyboard help on iPad only) |
| g o / g u / g p / g a / g m | go to overview / upcoming / projects / labels / teams | bottom-nav tabs + "More" |
| g l / g g / g t / g k | switch to list / gantt / table / kanban view | view segmented control, horizontal swipe between views |
| j / k / Enter (list) | navigate / open | scroll + tap |
| Ctrl+click (kanban) | mark done | tap card checkbox / swipe |
| ← → Shift/Ctrl+←→ (gantt) | move / resize bar | drag handles in read-only timeline or date sheet |
| t | mark done | header done button, swipe, notification action |
| s | favorite | star in header / swipe |
| l, p, c, a, f, r, m, d, Alt/Shift+r, e | labels, priority, color, assign, attachments, related, move, due date, reminder, edit description | property chips -> bottom sheets; "Add property" sheet |
| Delete/Backspace | delete task | overflow menu -> delete (confirm) |
| u | open project | breadcrumb tap |
| Ctrl+S | save | autosave on blur/dismiss |
| `.` / `..` / `...` / Ctrl+. | copy identifier / +title / +URL / URL | Share sheet with format options |

Hardware-keyboard support on iPad/Chromebook can reuse the same bindings (`PlatformMenuBar`/`Shortcuts` widgets)
**[inferred design]**.

## 20. Misc / About

* **About** (`views/About.vue`) — frontend and API versions, "Pro features active" note (`about.proActive`).
  Mobile: About screen with app version, server version, licensed features, legal links. **P1**
* **Offline / error states** — offline banner (`en.json offline.*`, `composables/useOnline.ts`), retry on load errors.
  Mobile: offline-first DB with sync status indicator. **P0**
* **Theme** — `color_schema` light/auto/dark. **P0**
* **i18n** — `frontend/src/i18n/lang/*.json` (Crowdin); language synced to server `language`. Mobile: reuse
  translations (convert to ARB) **[inferred design]**. **P1**
* **Seasonal logo** (`allow_icon_changes`, `components/home/Logo.vue`). **SKIP**
* **Token renew on focus** (`composables/useRenewTokenOnFocus.ts`), clock-skew handling (`helpers/serverClock.ts`).
  Mobile: refresh on resume. **P0**
* **Home-screen widget / notifications with actions** — do not exist on the web; they are new mobile features
  required by the user; data sources: §3 lists (today / upcoming / overdue / a saved filter / a project), action
  = `PATCH /tasks/{id} done` (v1: `POST /tasks/{id}` full object).

---

## 21. Server capabilities the web UI does not use (useful for mobile)

Verified by grepping every SDK operation name across `frontend/src` (excluding generated and tests):
`tasksReadByIndex` (`GET /projects/{p}/tasks/by-index/{index}`, `{p}` may be the textual identifier, e.g.
`PROJ` — resolve `PROJ-12` deep links), `tasksBulkUpdate` (`PUT /tasks/bulk {task_ids?, fields[], values}` — multi-select
edit), `taskAssigneesBulk`, `taskLabelsBulkReplace`, `tasksUpdate` (full PUT), `taskCommentsRead`,
`taskAttachmentsList`, `reactionsList`, `projectViewsList/Read`, `labelsRead` (+ETag), `timeEntriesRead`,
`projectTimeEntriesList`, `taskTimeEntriesList`, `userSettingsRead`, `notificationsAtomFeed`, `oauthToken`,
`tokenTest`/`tokenCheck` (`GET|POST /token/test`, validate a token), `health` (`GET /health`).

## 22. Prioritised build order (suggested)

1. **P0 core**: server setup + OAuth/PKCE login (+ password login fallback for pre-2.3 servers), project tree,
   favorites, list view with subtasks, task detail (title, description view/basic edit, done, due/start/end,
   reminders, repeat, priority, labels, assignees, subtasks, move, delete), quick add magic, overview/upcoming/overdue,
   search, notifications inbox, settings read/apply, offline cache, local reminder notifications with "mark done",
   widget.
2. **P1 parity**: kanban (board, move, done/default bucket, bucket CRUD, limits), views management, filters +
   saved filters, attachments + share-sheet, comments, relations (all kinds), labels/teams/sharing screens, project
   edit/archive/delete/reorder/subscribe, task duplicate/subscribe/percent/color, user settings editing, account
   deletion.
3. **P2**: table, gantt (read-only), backgrounds, reactions, time tracking [LIC], webhooks, API tokens, CalDAV info,
   TOTP, sessions, avatar, data export, bots, admin panel [ADMIN][LIC], link-share guest mode, migration (link out).

## 23. Open points / not verified

* No task restore/undelete endpoint was found despite soft delete (`deleted_at`); confirm with backend research.
* Exact v1 behaviour of `format=markdown`, `PATCH`, bulk create: v1 has none of them per `routes.go` (verified absence
  of routes), but older servers (< 2.4.0) also lack all of `/api/v2`; field names on very old servers (0.x) may differ
  — not checked here.
* Whether `client_id` should be registered/allow-listed in future releases (today free-form) — monitor
  `pkg/modules/auth/oauth2server/`.
