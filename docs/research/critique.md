# Completeness critique of the seven research files (Vikunja mobile client)

Reviewed: `api-v1.md`, `api-v2.md`, `auth.md`, `sync.md`, `features.md`, `client-logic.md`, `flutter-stack.md`.
I re-checked them against the read-only checkout (`main` @ `e7d7f17`, 2026-10-06; latest tag v2.7.0). All paths are relative to the repo root.

Labels:
- **[V]**: I verified it in source during this review.
- **[I]**: inference, either from library semantics I could not inspect (no Go module cache here) or from naming.
- **[X]**: platform knowledge from outside the repo. Re-check it against current OS documentation.

---

## 0. Verdict in one paragraph

The seven files are broadly accurate and verified in depth. Of 16 load-bearing claims I spot-checked:
- **9 are correct as stated.**
- **5 are wrong in at least one file:**
  - api-v2 says an out-of-scope API token gets a plain Echo 401.
  - sync.md has the refresh-token reuse semantics wrong.
  - flutter-stack says Markdown change detection exists in REST.
  - sync.md gives a v1 Atom feed path that does not exist.
  - api-v1 claims a "v2-only trash".
- **2 are incomplete in a way that matters:**
  - 2.7.0 renumbered several error codes, so older servers send different codes.
  - Delta sync on `updated` silently misses tasks of projects that become newly visible.

The biggest *uncovered* areas were:
- a server-version matrix below 2.0 (0.21 / 0.22 / 0.24 / 1.0 break the API);
- server error localisation;
- CalDAV as a product option;
- licensing mechanics;
- network and proxy realities of self-hosting (forward-auth, iOS Local Network permission, no gzip on `/api`);
- notification platform details;
- accessibility, which no file covered at all.

I filled these gaps in §3.

---

## 1. Spot-check of the most load-bearing claims

| # | Claim (file) | Verdict | Correct fact and evidence |
|---|---|---|---|
| 1 | `401 {"code":11,"message":"missing, malformed, expired or otherwise invalid token provided"}` means "JWT missing, malformed or expired". It is the v1 shape even on `/api/v2` (all files) | **Correct** | `pkg/routes/api_tokens.go:35-68`. The echo-jwt `ErrorHandler` emits `web.HTTPError{401, 11, …}` for every failure. |
| 2 | An unknown, expired or out-of-scope **API token** (`Bearer tk_…`) gets… api-v1 §1.5 and auth.md §5: 401 code 11. api-v2 §3.5: "a plain Echo 401" | api-v1 and auth.md **correct**; **api-v2 wrong** | The Skipper evaluates `checkAPITokenAndPutItInContext(...) == nil` and throws its `echo.NewHTTPError(401,"Unauthorized")` away (`api_tokens.go:43-56,93-103`). echo-jwt then parses `tk_…` as a JWT, fails, and returns **code 11**. Code 11 therefore means "refresh may help" only if the client sent a user JWT. Decide by the stored credential type, not by the body. |
| 3 | Refresh contract (auth.md §4; sync.md §7 "strict one-time use; reuse → ErrRefreshTokenAlreadyUsed") | auth.md **correct**; **sync.md partly wrong** | Details below the table. Sources: `pkg/modules/auth/auth.go:408-491`, `pkg/models/sessions.go:127-138,212-229`, `pkg/models/error.go:2420-2530`, `oauth2server/token.go` (`exchangeRefreshToken`). |
| 4 | OAuth-code sessions and OIDC sessions are always "short" (72 h idle). Only password login with `long_token:true` is long (30 d) | **Correct** | `oauth2server/token.go:145` `CreateSession(..., false, nil)`; `pkg/routes/api/v2/auth_openid.go:66` `IssueUserToken(..., false, oidcData)`; `auth_login.go:94` `in.Body.LongToken`. **Product impact:** with the recommended PKCE login, a user who does not open the app for 3 days (and gets no iOS background run) must log in again. No API upgrades a session to long. Only an admin can raise `service.jwtttl`. |
| 5 | The v2 list envelope is `{items,total,page,per_page,total_pages}`. `items` is never null. `per_page` defaults to `maxitemsperpage` and is silently capped at it. `page` has a minimum of 1 (all files) | **Correct** | `pkg/routes/api/v2/types.go:29-75`. Nuances below the table. |
| 6 | WebSocket: only `notification.created` and `timer.created\|updated\|deleted` exist; there are no task events (api-v2, sync, auth, features, client-logic) | **Correct** | `pkg/websocket/connection.go:336-342`. Auth details below the table. |
| 7 | The filter accepts `updated` with `>`/`>=`, so incremental pulls work (sync.md §2.2) | **Correct, but the sync design has a hole** | `task_collection_sort.go:30-56,98-120` (`updated` is a sortable and filterable field), `task_collection.go:106-116`. Value parsing and the hole are described below the table. |
| 8 | OIDC callback: the server sets `Oauth2Config.RedirectURL = cb.RedirectURL`, exchanges the code as a confidential client, and uses no PKCE (auth.md §8, flutter-stack §3.8) | **Correct** | `pkg/modules/auth/openid/openid.go:49-57` (`Callback{code, scope, redirect_url, totp_passcode}`), `:614-627`. The redirect URL is never validated server-side; the IdP enforces it. |
| 9 | Vikunja OAuth server details (auth.md §7) | **Correct** | `oauth2server/client.go:25-46`, `token.go`, `frontend/src/views/user/OAuthAuthorize.vue:56-84`, `frontend/src/router/index.ts:437`. Details below the table. |
| 10 | `/info` fields (api-v2 §9, features §1.2) | **Correct** (list); one point unverified | `pkg/routes/api/shared/info.go:36-60,92-176`. Extra facts and the `concurrent_writes` question are below the table. |
| 11 | `/api/v2` first shipped in **2.4.0** (api-v2, auth, sync) | **Correct** | `CHANGELOG.md:1466` (2.4.0 header), `:2179` "Scaffold /api/v2 Echo group". No v2 entries exist before that. |
| 12 | v1 `POST /tasks/{id}` (and v2 `PUT`) is a full replace. Omitted `assignees` or `reminders` are **deleted** (api-v1 §6.1, sync §6) | **Correct** | `pkg/models/tasks.go:1292-1315` (`updateTaskAssignees` runs unconditionally), `task_assignees.go:77-83` (empty means delete all), `tasks.go:1535-1537,2067-2072` (reminders are deleted and re-inserted). The bulk-update hazard is described below the table. |
| 13 | flutter-stack §3.12: "the server canonicalizes and **skips the rewrite when the Markdown is semantically unchanged** (`richtext.Changed`)" | **Wrong** | `richtext.Changed` has exactly one caller: CalDAV (`pkg/routes/caldav/listStorageProvider.go:659`). On REST, every markdown write is converted MD→HTML (lossy) (`pkg/routes/api/v2/richtext.go:56-140`). api-v2 §3.6 has this right. The hidden PATCH trap is described below the table. |
| 14 | sync.md §4.2: Atom feed v1 at `GET /api/v1/notifications.atom` | **Wrong** | The feeds are `GET /feeds/notifications.atom` (root, **not** under `/api/v1`, Basic auth) and `GET /api/v2/notifications.atom` (`pkg/routes/routes.go:257-260,304,360`). api-v1 and api-v2 have this right. |
| 15 | api-v1 §0: "Features added after the freeze (time tracking, bulk task create, **trash**) are v2-only" | **Wrong** about the trash | There is no trash, restore or undelete route in any API version (grep over `pkg/routes`, and the `pkg/routes/api/v2/` file list). Soft-deleted tasks are only visible via CalDAV `sync-collection`. The only "restore" code is DB dump restore (`pkg/db/dump.go`). |
| 16 | Error-code tables in auth.md §6 and api-v1 §1.5 (1039 TOTP reused, 1040 locked, 4035 file too large) | **Incomplete**: true only for **≥ 2.7.0** | 2.7.0 renumbered codes: `CHANGELOG.md:91` (file too large was **4013**, which collides with "invalid sort param"), `:183` (import failures were 14001/14002, now 14011/14012), `:271` (OIDC custom scope 1022→1038), `:273` (TOTP reused **1025→1039**), `:275` (locked **1026→1040**). A client supporting older servers must map codes per server version (§3.2). |

### Details for rows 3–13

**Row 3: refresh contract**
- The refresh token rotates on every call.
- A rotated (old) token fails lookup with **16002** (`ErrInvalidRefreshToken`). There is **no reuse detection** and the session is *not* revoked.
- **16004** occurs only when two requests race on the *same* token and one loses the `UPDATE … WHERE token_hash=old`.
- 16003 means idle longer than `jwtttl`/`jwtttllong`. The session row is deleted.
- 16005 means no cookie was sent (cookie endpoint only).
- Disabled or locked user: the session is deleted, then **412** 1020/1040.
- The refresh grant does not check `client_id`.
- A refresh token from the login cookie can be redeemed at `/oauth/token`, because both paths call the same `RefreshSession`.
- Consequence for clients: after either 16002 or 16004, re-read secure storage first, because a sibling isolate may have rotated the token. Only declare the session dead if the stored token is still the one that failed.

**Row 5: pagination nuances**
1. `GET /projects/{p}/views/{v}/buckets/tasks` returns `{items: Bucket[], total: <#buckets>}`. Its route doc says "page/per_page do not apply", but the handler passes them into `DoReadAll`, and `GetTasksInBucketsForView` runs one query per bucket with those options, setting `bucket.Count = total` (`pkg/routes/api/v2/task_collection.go:209-241`, `pkg/models/kanban.go:158-270`). So `per_page` is a **per-bucket** limit, which is how the web uses it (`per_page=25`). [V code path]
2. The project list (v1 and v2) appends the **Favorites pseudo project (-1) and all saved filters (≤ -2) to every page** (`pkg/models/project.go:286-298` and `:691-705`). `total` counts only real projects. Dedupe by id when sweeping pages. Only api-v1 mentioned this.

**Row 6: WebSocket auth**
- Authenticate with the first message within 30 s, or the socket closes with 1008 "auth timeout".
- The token must be a JWT of `type==1` with `id`, `exp` and a non-empty `sid`, and its signature must verify.
- **Expired JWTs are rejected** with `{"error":"invalid_token"}`, which is terminal. Refresh *before* connecting.
- The server also checks that the session row exists and the user is active.
- Re-auth must keep the same uid and sid.
- The socket closes at `exp`.
- Transient DB errors close with 1013.
- Sources: `connection.go:34-35,189-271`, `pkg/modules/auth/auth.go:307-367`.
- API tokens and link-share JWTs can never use the socket.

**Row 7: filter values and the sync hole**
- Date values: datemath is tried first. Otherwise the server tries RFC3339, then `YYYY-MM-DD HH:MM`, `YYYY-MM-DD` and `Y-M-D`, all in `filter_timezone`. **Everything is converted to UTC** (`task_collection_filter.go:83-115,459-477`). The DB stores naive UTC (`pkg/db/db.go:121-126`).
- **The hole:** a task whose project *becomes* visible keeps its old `updated` and is never returned by `updated > W`. That happens when a project is newly shared, a team is added, or a project is un-archived. Archived projects are excluded from `/tasks` (`project.go:650-652`). See §3.3.

**Row 9: OAuth server details**
- The redirect scheme must start with `vikunja-`, or be `http` on localhost or a loopback IP.
- PKCE S256 is mandatory.
- `client_id` is free-form.
- The code is single-use with a 10 min TTL.
- The SPA calls `POST /oauth/authorize` **on mount, with no consent UI**.

**Row 10: `/info` extras**
- `frontend_url` is normalised to end with `/` and to use http(s) when set. It is mandatory when `cors.enable` (the default) is on (`pkg/config/config.go:794-809`).
- `max_file_size` is the **raw config string** parsed by `datasize` (`config.go:858-866`). Expect `"20MB"`, `"1GB"`, `"500KB"` and similar, and parse it leniently with a base of 1024.
- `allow_icon_changes` is documented as "project icons", but it controls the seasonal logo.
- api-v2 calls `concurrent_writes` "probably unreleased". That is **unverified, and probably wrong**: 2.4.0 already shipped "Add labels sequentially when the backend db serializes writes" (`CHANGELOG.md:1672`). Either way, a missing field means "unknown": serialize writes.

**Row 12: bulk-update hazard**
- **Bulk update wipes them too.** v1 `POST /tasks/bulk` and v2 `PUT /tasks/bulk` clone `values` for each id and call `updateSingleTask(s, a, fields)`.
- The `fields` filter limits only columns. Assignees and reminders are always replaced from `values`, so they are deleted when `values` omits them (`tasks.go:1700-1706` → `1314`, `1536`).
- Never use bulk update on tasks that have assignees or reminders unless `values` carries them. [V code path; not covered by a test]

**Row 13: Markdown PATCH trap**
- Autopatch forwards headers to its internal GET, so with `X-Vikunja-Format: markdown` the GET returns Markdown.
- The internal PUT then re-converts the **whole description** MD→HTML, even for a `{"done":true}` patch.
- Never send the header unless the patch contains a description. [I from `richtext.go:20-33` and `requestWantsMarkdown` reading the header on every leg]

### Smaller errors found while reading

- **features.md §16, API tokens "never" expiry:** wrong. `expires_at` is `valid:"required"` (`pkg/models/api_tokens.go:60`). The form only offers day presets or a custom date (`frontend/src/components/token/ApiTokenForm.vue:49-72,269-279`). auth.md §9 is right.
- **features.md §16, TOTP QR "PNG":** it is `image/jpeg` (`pkg/routes/api/v1/user_totp.go:217`, `pkg/routes/api/v2/user_totp.go:257`).
- **features.md §16, "planka and CSV detect/preview appear v2-only":** CSV `status/detect/preview/migrate` exist on v1 as `PUT`s (`pkg/modules/migration/csv/handler.go:34-41`). Only Planka is v2-only.
- **api-v2 §11, "v2-only from day one: sessions, bots":** wrong. v1 has `GET/DELETE /user/sessions[/:session]` and `/user/bots` CRUD (`routes.go:616-617,649-653`). Its §12.2 table is correct.
- **api-v1 §1.4, "per_page <1 → 400":** `per_page=0`, or omitting it, means the default. Only negative values give 400 (`pkg/web/handler/read_all.go:81-89`). Separately, **`page=0` returns *all* rows** (`models.go:94-99` `getLimitFromPageIndex`), with no cap.
- **flutter-stack §3.8, "the v1 token endpoint binds JSON while AppAuth sends form-encoded":** probably wrong [I]. v1 `HandleToken` uses Echo `c.Bind()` on a struct with `form:` tags (`oauth2server/token.go:43-50`), and Echo's default binder decodes `application/x-www-form-urlencoded` by Content-Type. Verify against a 2.3.x server before relying on it.
- **sync.md §4.3, "selects reminders … in each recipient's timezone":** misleading. The cron compares instants (`r.Reminder.In(tz).After(now)…`), and `In()` does not change the instant (`pkg/models/task_reminder.go:246-345`). Reminders are absolute instants, which is what the mobile scheduler needs.
- **features.md §1.1, "max_permission field (projects with ?expand=permissions)":** incomplete. On v2, every conditional single read (task, label, view, filter, team, comment, …) returns `max_permission` in the body. Projects need `expand=permissions` on the list.

---

## 2. Cross-file contradictions, resolved

| Topic | Files disagree | Resolution |
|---|---|---|
| API token out of scope | api-v1/auth vs api-v2 | 401 **code 11** (row 2). |
| Reuse of a rotated refresh token | auth vs sync | **16002**; 16004 only for a concurrent race (row 3). |
| Markdown change detection | flutter-stack vs api-v2 | CalDAV only (row 13). |
| v1 feed path | sync vs api-v1/api-v2 | `/feeds/notifications.atom` (row 14). |
| CSV migrator on v1 | features vs api-v1 | Present on v1 (§1). |
| Sessions and bots on v1 | api-v2 §11 vs api-v1/api-v2 §12 | Present on v1 (§1). |
| Kanban per-bucket paging on `/buckets/tasks` | api-v2 vs route doc | Applies per bucket (row 5). |

---

## 3. Gaps none of the files covered, with source-verified fills

### 3.1 Server-version matrix below 2.0 (the user wants "API v1 and v2", but v1 spans eight years)

All rows are taken from `CHANGELOG.md` section headers and line numbers [V], unless marked [I].

| Version | Date | API-shaping change | Evidence |
|---|---|---|---|
| < 0.21 | — | "Lists", not projects; reminders were bare dates (`reminder_dates`, [I] from memory). **Not supportable.** | — |
| **0.21.0** | 2023-07-07 | Lists renamed to **projects** everywhere; **relative reminders** (`reminders[]` objects) | `:8056-8073`, `:8058` |
| **0.22.0** | 2023-12-19 | **API tokens** (`tk_`), **webhooks**. **BREAKING:** task create moved to `PUT /projects/:project/tasks` (was `PUT /projects/:project`) | `:7747-7757`, `:7776`, `:7582` |
| **0.24.0** | 2024-07-02 | See the bullets below this table | `:6476`, `:6773`, `:7242-7254` |
| **1.0.0-rc0** | 2025-08-17 | **BREAKING "rename right to permission"**: DB columns on `link_shares`, `users_projects`, `team_projects` (`pkg/migration/20250813093602.go`). See the bullets below. | `:4314`, `:5855`, `:5748` |
| 1.0.0-rc3 | 2025-11-27 | Task **unread tracking** (`is_unread`, `/tasks/{id}/read`) | `:4118` |
| **2.0.0** | 2026-02-25 | **Sessions with a rotating refresh cookie**, `jwtttlshort` (600 s). Before this, login returned one long JWT (`long_token`), renewed via `POST /user/token` [I, auth.md] | `:3306-3309` |
| 2.2.0 | 2026-03-20 | `expand`/`expand[]`, account lock status, user-level webhooks, SQLite immediate txlock | `:2921`, `:2955`, `:2886-2887` |
| **2.3.0** | 2026-04-09 | **OAuth 2.0 + PKCE server**, **WebSocket** `/api/v1/ws`, TOTP on OIDC | auth.md §1 |
| **2.4.0** | 2026-07-19 | See the bullets below this table | `:2179`, `:2190`, `:2099`, `:2101`, `:1676` |
| 2.5.0 / 2.6.0 / 2.7.0 | 2026-08/09/10 | Bulk create / pending email, Planka, v2 cookie path (`:886`) / **error-code renumbering (row 16)**, 307 by-index, invite links, MCP, WebSocket re-auth | api-v2 §11 |

**0.24.0 changes:**
- **Project views**: buckets are per view, done and default bucket live on the view, and a new `/tasks/{id}/position` endpoint exists.
- `bucket_id` on task update is ignored.
- The **new `filter=` query language**, which replaced `filter_by`/`filter_value`/`filter_comparator` [I: the old names do not appear in this CHANGELOG].
- Reactions.

**1.0.0-rc0 changes:**
- JSON fields and the permission header were presumably `right` and `x-max-right` before this release [I: high confidence from the column rename and commit title; not verifiable in this checkout].
- `registration_enabled` moved under `auth.local`.
- `expand` on read-one task.

**2.4.0 changes:**
- **`/api/v2`**.
- **Soft delete** of tasks.
- Time tracking (licensed) and bots.
- Markdown exchange.
- CalDAV descriptions became Markdown, and `sync-collection` was added.
- "Bump project and task updated times when task sub-entities change". Before 2.4.0, some sub-entity edits may not move `updated` [I].

**Recommended support tiers [I]:**

| Tier | Server versions | Behaviour |
|---|---|---|
| Unsupported | < 0.24 | Show "Server too old (needs ≥ 0.24)". |
| Legacy | 0.24.x – 1.x | v1 only, password login, long JWT renew. Apply a `right`→`permission` / `x-max-right`→`x-max-permission` shim below 1.0. No WebSocket, so poll only. |
| Standard | 2.0 – 2.2 | Same as Legacy, but with cookie refresh parsed from `Set-Cookie`. |
| OAuth | 2.3.x | PKCE login, `/api/v1/oauth/token`, WebSocket on `/api/v1/ws`. |
| Full | ≥ 2.4 | v2 adapter. |

- Parse `/info.version` leniently: strip `v`, ignore the `-N-gHASH` suffix, and treat `dev`/`unstable` as latest.
- Gate optional features on `/info` flags and on feature probes, not on the version alone.
- **Open:** `GET /tasks` vs `/tasks/all` on 0.24.x is still unverified (sync.md also flagged it). The swagger in this checkout only shows `/tasks` (`pkg/swagger/swagger.yaml:5370`). Probe both on legacy servers.

### 3.2 Server error localisation (none of the files covered this)

- The web localises errors **client-side**: `t('error.<code>', i18n_params)` (`frontend/src/message/index.ts:12-20`).
  - `en.json` has **108** numeric `error.*` keys.
  - For filter errors 4016, 4017, 4018, 4019 and 4024 it appends the server `message`.
  - `i18n_params` is a `map[string]string` keyed by the translation placeholder names (`pkg/web/web.go:51-52`).
- **Mobile:** import the `error.*` keys into ARB, and fall back to `detail ?? message`.
- **Version map:** on servers < 2.7.0:
  - 1026 means "account locked" (now 1040);
  - 1025 means "TOTP reused" (now 1039);
  - **4013 on an upload** means "file too large" (now 4035), but 4013 elsewhere is "invalid sort param";
  - 14001/14002 are import failures (now 14011/14012).
- Server-side emails and DB notifications are rendered in the user's `settings.language` (backend has 38 lang files in `pkg/i18n/lang/`). Keep `language` within the backend allow-list (`pkg/i18n/i18n.go` `HasLanguage`; `fa-IR` is missing, client-logic quirk 13).

### 3.3 Sync blind spots the sync design does not handle

1. **Projects that become visible**, through a new share, a team membership or an un-archive, bring tasks whose `updated` is older than the watermark. The `updated > W` pull never returns them. **Fix:** in the project diff, every *new* project id, and every project whose `is_archived` flipped to false, triggers a **full keyset pull** of `GET /projects/{id}/tasks`. [V for the filter semantics and the archived exclusion at `project.go:650-652`; I for the fix]
2. **Pseudo projects repeat on every page** of the project list (row 5). Dedupe them, and never count them as projects.
3. **No HTTP compression for the API:** the gzip middleware skips every path starting with `/api/` (`pkg/routes/static.go:278-285`). An initial sync of thousands of tasks at 50 per page is uncompressed unless the reverse proxy compresses. Send `Accept-Encoding: gzip` anyway (proxies often honour it), keep `expand` minimal, and avoid `expand=comments` in sync.
4. **v1 `page=0` returns all rows in one response** (§1). This makes a cheap v1 initial or full-reconcile pull possible, but the response can be huge. Use it only for id-only reconciliation on small accounts. [V code; I advice]
5. **Label rename, kanban position or bucket moves, and subscription state** do not bump `tasks.updated` (sync.md lists most of these). Subscription state appears only on single reads, so the notification scheduler cannot know about "subscribed but not assignee" tasks without N single reads. Decide a policy: schedule local reminders only for tasks where the user is the creator or an assignee, as sync.md suggests.
6. **Filter-string transport:** filters contain `&&`, `=`, quotes and spaces. Always build query strings with `Uri(queryParameters: …)` (percent-encoding `&` as `%26`). A hand-built URL silently truncates the filter at `&&`. [I]
7. **Dedup lookup for uncertain creates** (sync.md §9.4) uses `title = '<escaped>'`. The fexpr pre-processor auto-quotes values (`task_collection_filter.go:243-276`), but titles containing `'` or `"` need testing. Use `created >= … && created_by …` and compare titles client-side. [I]

### 3.4 Licensing ("pro features"): how it actually works

- Config `license.key` (`pkg/config/config.go:251-253`). With no key, the server runs in "community mode with all non-licensed features available" (`config-raw.json:1147-1152`).
- Features: `admin_panel`, `time_tracking`, `audit_logs`, `user_invites` (`pkg/license/license.go:64-85`).
- The key is validated against a license server. A cached validation is honoured for **72 h** if the server is unreachable; otherwise the instance degrades to free (`license.go:148-195`).
- `/info.enabled_pro_features` lists features **only while licensed** (`EnabledProFeatures()` returns `[]` otherwise).
- Gated routes return **404 at runtime**: Echo `RequireFeature` (`pkg/routes/feature_gate.go`) and the Huma `timeTrackingGate` (`pkg/routes/api/v2/time_entries.go:34-48`). They still appear in the OpenAPI spec.
- **Mobile:** most self-hosters will not have `time_tracking`. Build it last and gate it strictly on `enabled_pro_features`.

### 3.5 Time tracking (only touched on in features.md)

- `TimeEntry` = `{id, user_id(ro), task_id | project_id (XOR), start_time, end_time (null = running), comment, created, updated}` (`pkg/models/time_tracking.go:38-51`).
- **Starting a new running timer auto-stops the previous one.** A manual entry with `end_time` set leaves the running timer alone (`time_tracking.go:71-75,104-116`).
- Stop: `POST /api/v2/time-entries/timer/stop`, which returns 404/18005 when no timer is running.
- Realtime: WebSocket `timer.*` events.
- Requires ≥ 2.4 and a license.
- An Android ongoing notification or iOS Live Activity with a stop action is the natural mobile UI [I].

### 3.6 CalDAV: a product option, not a sync channel

- Endpoints: `/dav/`, `/dav/principals/*`, `/dav/projects[/:project[/:task]]`, `/.well-known/caldav` (`pkg/routes/routes.go:245-251,1068-1083`).
- Basic auth with any of:
  - a **CalDAV token**;
  - a `tk_` API token with `caldav.access`;
  - the account password, rejected if TOTP is on; bots are rejected;
  - (`pkg/routes/caldav/auth.go:55-100`).
- Tasks are VTODO with **VALARM** reminders (`pkg/caldav/caldav.go`). Descriptions are Markdown since 2.4.0 (`CHANGELOG.md:2099`).
- `sync-collection` reports deletions, with tokens valid for 30 days (`pkg/routes/caldav/sync_collection.go:114-200`).
- Gated by `/info.caldav_enabled`.
- **Product idea [I/X]:** an "Add to Apple Reminders / DAVx⁵" helper that creates a CalDAV token (`PUT /api/v1/user/settings/token/caldav`, `POST /api/v2/user/settings/token/caldav`) and shows the URL `{frontend_url}dav/principals/{username}/`. iOS can also install a CalDAV account through a `.mobileconfig` profile.
- Do **not** use CalDAV for the app's own sync: the XML is heavy, every project needs its own token, and descriptions are lossy Markdown.

### 3.7 Link shares (covered in pieces; the consolidated constraints)

- Login: `POST /shares/{hash}/auth {password?}` returns a link-share JWT (72 h). Errors: 13001 (password required), 13002 (wrong password), 3006 (share not found).
- Renew via `POST /user/token`. There is no refresh token.
- **No WebSocket** (`ParseUserToken` requires `type==1`, `auth.go:320-323`).
- No `/user`, no subscriptions, and no saved filters (11002).
- A share's project list returns only the shared project, with `parent_project_id` forced to none (`project.go:253-266`).
- Share URLs `{frontend_url}share/{hash}/auth?view=…` live on the user's own domain. App Links / Universal Links cannot be verified for arbitrary self-hosted domains [X], so the app needs an "Open shared link" paste or QR flow.

### 3.8 Network and proxy realities of self-hosting (missing everywhere)

- **Forward-auth or Basic-auth reverse proxies** (Authelia, Authentik proxy outpost, nginx `auth_basic`, Cloudflare Access) in front of Vikunja break native clients:
  - Vikunja itself uses the `Authorization` header (Bearer), so proxy Basic auth cannot coexist with it.
  - Cookie-based forward-auth needs a browser session.
  - **Recommendation [I]:** per-server "custom request headers" (for example `CF-Access-Client-Id` / `CF-Access-Client-Secret` service tokens), plus the mTLS client-certificate option that flutter-stack already plans, and a clear error when `/info` returns HTML or a 302 to an IdP.
- **iOS Local Network privacy (iOS 14+)** [X]: connecting to LAN or `.local` servers (very common for self-hosters) triggers the Local Network permission prompt. It needs `NSLocalNetworkUsageDescription`, and background tasks fail silently before the user has granted it. ATS also needs `NSAllowsLocalNetworking` for plain-http LAN servers.
- **Android** [X]: cleartext for http LAN servers needs a `network_security_config` domain or base config (flutter-stack covers the user-CA side).
- **Rate limits shared per IP**: the WebSocket upgrade counts against the **login** limiter (10/min/IP, cannot be disabled; `config-raw.json:484-486`, `routes.go:491,522`). Reconnect storms behind CGNAT can lock out logins for everyone on that IP. Cap reconnects at well under 10 per minute.
- **Server URL input:** accept a bare host, a host with a sub-path, and a `.../api/v1` or `/api/v2` suffix, and fall back to port 3456 (client-logic §14). Warn on `http://`.

### 3.9 Notification and platform details not covered [X unless noted]

- **Android notification channels**: create separate channels such as "Reminders", "Due dates", "Activity" (server notifications) and "Sync problems". Users mute per channel, and importance is fixed after creation.
- **Action categories**: iOS `UNNotificationCategory` and Android action intents must be registered at **every** launch, including background launches, or the "Mark done" action disappears. In flutter_local_notifications this means `DarwinInitializationSettings(notificationCategories: …)` during initialisation in every isolate.
- **iOS Time Sensitive** interruption level for reminders needs the Time Sensitive Notifications capability. Without it, Focus modes suppress reminders.
- **Notification grouping** per project (`threadIdentifier`, Android `groupKey`) and a summary notification. This avoids a flood after the first sync of many overdue reminders. Do not fire notifications for reminders that are already in the past at first sync [I].
- **App Store review**: a self-hosted client needs a working demo server and credentials in the review notes. Vikunja's `demo_mode_enabled` instance type fits.
  - Sign in with Apple is not required: guideline 4.8 exempts apps that are clients for a specific service where users log in to their own account [X, re-check the current guideline].
  - Account deletion: the app must expose deletion when the server allows registration (features.md §16 mentions it). Use `/info.user_deletion_enabled` and otherwise link to the web UI or the admin.
- **Privacy manifests** (`PrivacyInfo.xcprivacy`) for required-reason APIs (UserDefaults, file timestamps) in the app and widget extension. Check that every plugin ships one.
- **Tablets and foldables**: none of the files plans adaptive layouts. Use list-detail (`NavigationRail` plus a two-pane task view) at width ≥ 600 dp, iPad split view and multitasking, and hardware-keyboard shortcuts (features §19 maps them) [I].

### 3.10 Accessibility (no file covered this)

- **Web parity reference:** 1.0.0-rc0 shipped a batch of a11y fixes, including labels on task inputs, editor buttons, reactions, notifications and the logo, and hiding unfocusable buttons (`CHANGELOG.md:4318-4330`). The server provides nothing a11y-specific.
- Mobile requirements [I]:
  - **Swipe actions** (done, defer, delete) need equivalent `Semantics` custom actions (VoiceOver rotor, TalkBack actions). Gesture-only kanban drag needs a "Move to bucket…" action, which features.md already proposes.
  - **Dynamic Type / font scaling** up to 200% without truncating titles. Widgets must also respect text size.
  - **Contrast:** label chips with arbitrary `hex_color` should use the web's `getTextColor` rule (WCAG ≥ 4.5:1, client-logic §6). Priority and overdue must not be signalled by colour alone (add an icon or text).
  - **Rich text:** HTML rendered in a WebView or HTML widget needs semantic headings and lists. Checklist items need checkbox semantics with state.
  - **Reduced motion:** honour the system setting for done animations and haptics. The web's 300 ms done delay should not block screen readers.
  - **RTL:** `ar-SA`, `he-IL`, `fa-IR` are UI locales (client-logic §17). Mirror layouts and swipe directions.
  - **Notifications:** put the task title first in the notification body, and give actions explicit titles.
  - **Testing:** Flutter `meetsGuideline` (text contrast, tap target size, labeled tap targets) in widget tests, plus manual VoiceOver and TalkBack passes.

### 3.11 i18n additions

- Quick-add grammar and notification strings are English-only on the web (client-logic §1.8, §7). Decide whether to localise the parser.
- The server's default entity names ("Inbox", "My Open Tasks") are English and are translated client-side by exact title match (client-logic §7).
- Error messages: see §3.2.
- The server renders reminder emails in the user's `language`. Offer to sync the app language to `settings.language` through a merge-patch.

---

## 4. Still unverified (needs a live-server test before relying on it)

1. Whether Huma rejects **unknown JSON properties** with 422. This is Huma's registry default; Vikunja does not override it (no `AdditionalProperties` setting in `pkg/routes/api/v2` or `pkg/modules/humabridge`). Do not send client-only fields.
2. The **304 on a no-op PATCH** (upstream autopatch). The web relies on it in `frontend/src/client/queries/account.ts`.
3. Form-encoded bodies on v1 `/oauth/token` (§1).
4. `right` / `x-max-right` naming on < 1.0 servers, and `/tasks` vs `/tasks/all` on 0.24.x.
5. Whether a Dart `WebSocket.connect` sends no `Origin`. coder/websocket v1.8.15 accepts an empty Origin [I].
6. Whether a done-changing kanban move bumps `updated` (xorm auto-`updated` combined with `Cols(...)`).
7. The release that first shipped `concurrent_writes`.

---

## 5. Changes to the recommendations the files make

1. **Retry rule:** refresh on `401 && code==11` **only for user-JWT accounts**. For API-token accounts, code 11 means "revoked, expired or out of scope". Show a re-auth or scope error and never loop.
2. **Refresh failures:** handle 16002 like 16004. Re-read storage under the lock, and only then declare the session dead.
3. **Session lifetime:** prefer PKCE, but warn that OAuth sessions die after 72 h idle. On servers where password login is available, consider offering "Stay signed in (30 days)" through `/login` with `long_token:true`, then move the cookie token to `/oauth/token` refresh.
4. **Never use v1/v2 bulk update** for tasks with assignees or reminders unless `values` carries them.
5. **Never send `X-Vikunja-Format: markdown`** unless the description is part of the patch. Do not plan a "Markdown quick edit" on the assumption that the server skips unchanged text.
6. **Sync:** full-pull new and un-archived projects; dedupe pseudo projects per page; build filters with `Uri`; keep a version-aware error-code map.
7. **Minimum server:** declare ≥ 0.24.0 (v1 legacy tier) and recommend ≥ 2.4.0.
