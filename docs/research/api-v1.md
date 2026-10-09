# Vikunja `/api/v1` — complete surface map (for the Flutter client)

Reference checkout: shallow clone of `main` (HEAD `e7d7f173e406`, 2026-10-06; latest release v2.7.0). All paths below are relative to the repo root.

Legend: **[V]** = verified by reading source (file cited). **[I]** = inferred from code reading / Go/Echo semantics, not executed. Nothing was run.

---

## 0. Orientation facts

- `/api/v1` is Echo (labstack/echo **v5**) and is **frozen**: "bug fixes and ports to v2 only"; every new route goes to `/api/v2` (Huma). [V] `AGENTS.md`, `.agents/docs/api.md`
- Models in `pkg/models/` are shared by v1 and v2, so JSON field names/semantics of entities are identical; only the HTTP surface differs. [V] `.agents/docs/api.md`
- The current web frontend no longer uses v1 for resources; it uses the generated v2 client (`frontend/src/client/generated`). [V] `.agents/docs/api.md` → v1 is effectively only for old clients/third parties. Features added after the freeze (time tracking, bulk task create, trash) are **v2-only** (§12).
- Route registration: `pkg/routes/routes.go` → `registerAPIRoutes()` (line ~503) for v1. Generic CRUD goes through `pkg/web/handler/*.go` (`CreateWeb`, `ReadOneWeb`, `ReadAllWeb`, `UpdateWeb`, `DeleteWeb`) which call the model's `Can*` + CRUD methods via `Do*` in `pkg/web/handler/core.go`.
- Swagger (swaggo, v1 only): `pkg/swagger/swagger.yaml` / `swagger.json`, served at `GET /api/v1/docs.json`, ReDoc UI at `GET /api/v1/docs`. `basePath: /api/v1`. Several annotations are wrong (see §11).

---

## 1. Global conventions

### 1.1 Verbs (v1)
- **PUT = create**, **POST = update**, GET = read, DELETE = delete. [V] `.agents/docs/api.md` ("v1: PUT creates, POST updates"), `pkg/models/api_routes.go` comment in `getRouteDetail`.
- Exceptions: some non-CRUD actions use POST for "create-like" ops (`POST /tasks/{id}/assignees/bulk`, `POST /tasks/{id}/labels/bulk`, `POST /notifications` = mark all read, `POST /{kind}/{id}/reactions/delete`), admin uses PATCH. [V] `pkg/routes/routes.go`

### 1.2 Status codes of the generic handlers [V] `pkg/web/handler/*.go`
| Handler | Success |
|---|---|
| `CreateWeb` | **201** + created object |
| `ReadOneWeb` | 200 + object + header `x-max-permission` |
| `ReadAllWeb` | 200 + JSON array (never `null`; nil slice → `[]`) + pagination headers |
| `UpdateWeb` | 200 + updated object |
| `DeleteWeb` | 200 + `{"message":"Successfully deleted."}` |

Body binding: `ctx.Bind()` binds path params then body (JSON); then `ctx.Validate()` (govalidator `valid:` tags) runs for Create/Update only. [V] `pkg/web/handler/create.go`, `update.go`; validator `pkg/routes/validation.go`.

### 1.3 Headers
- `Cache-Control: no-store` on every v1 response (downloads override to `no-cache`). [V] `pkg/routes/routes.go` `noStoreCacheControl()`; `pkg/web/files/file.go`
- `x-max-permission` on every `ReadOneWeb` response: `0` read-only, `1` read & write, `2` admin. [V] `pkg/web/handler/read_one.go`, `pkg/models/permissions.go` (`PermissionRead=0, PermissionWrite=1, PermissionAdmin=2`)
- Pagination (only from `ReadAllWeb`): `x-pagination-total-pages`, `x-pagination-result-count`; plus `Access-Control-Expose-Headers`. **There is no total-items header in v1.** [V] `pkg/web/handler/read_all.go`
- Rate limit (only if `ratelimit.enabled`, default **false**): `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`; 429 with `Retry-After`. Unauthenticated credential routes have their own per-IP limiter (`ratelimit.noauthlimit` default 10/min) and refresh routes (`ratelimit.tokenrefreshlimit` default 60/min) — these are **always on**. [V] `pkg/routes/rate_limit.go`, `pkg/routes/routes.go` lines 527-555, `config-raw.json`
- Request ID: `X-Request-Id` reused or generated. [V] `pkg/routes/routes.go` `middleware.RequestID()`
- Query arrays may be sent as `sort_by=a&sort_by=b` or `sort_by[]=a&sort_by[]=b` (normalized, order preserved). [V] `pkg/routes/middleware/array_param_normalizer.go`
- Body limit = `files.maxsize` (+2 MB overhead); oversize → 413 with code 4035. [V] `pkg/routes/routes.go` `BodyLimit`, `pkg/routes/error_handler.go`

### 1.4 Pagination semantics [V] `pkg/web/handler/read_all.go`, `pkg/models/models.go` `getLimitFromPageIndex`
- Query params: `page` (default 1), `per_page` (default = `service.maxitemsperpage`, default **50**; values > max are **silently capped**; `<1` → 400), `s` (search string passed to the model's `ReadAll`).
- `x-pagination-total-pages = ceil(totalItems / per_page)`, `0` if the page returned 0 items. `x-pagination-result-count` = items in this response.
- `page=0` (explicit) is accepted and means **no limit** in most models (`getLimitFromPageIndex(page<1) → limit 0` → `if limit > 0 { Limit(...) }` e.g. `pkg/models/task_search.go` ~l.638/689). [V for code path; I that it is safe to rely on — it bypasses `max_items_per_page`.]
- Max items per page is exposed in `GET /info` → `max_items_per_page`.
- Endpoints that ignore pagination entirely: project views list, buckets list (all returned). [V] `pkg/models/project_view.go`, `pkg/models/kanban.go`

### 1.5 Error format [V] `pkg/web/web.go`, `pkg/routes/error_handler.go`
- Domain errors: HTTP status + body `{"code": <int>, "message": "<text>", "i18n_params": {...}?}` (`i18n_params` omitempty).
- Validation errors (`valid:` tags): **HTTP 412**, `{"code": 2002, "message": "Invalid Data", "invalid_fields": ["title: ..."]}`. [V] `pkg/models/error.go` `ValidationHTTPError`, `InvalidFieldError`
- Plain Echo errors (404 route, generic 403 `echo.ErrForbidden`, 429, 500): `{"message": "Forbidden"}` (no `code`). [V] `error_handler.go` wraps string messages in `{"message":...}`.
- Generic permission denial from `Do*`: **403** `{"message":"Forbidden"}`; read denial message "You don't have the permission to see this". [V] `pkg/web/handler/error.go`
- Bind errors: 400 code 2004 (`ErrInvalidModel`). [V]

**Error code 11** — verified: `ErrCodeInvalidToken = 11`, returned as **401** `{"code":11,"message":"missing, malformed, expired or otherwise invalid token provided"}` whenever the JWT middleware rejects the bearer. [V] `pkg/routes/api_tokens.go`. The web client does "a single refresh-and-retry on 401 code 11". [V] `.agents/docs/api.md`.
Important nuance [V by code path]: an **API token** (`Bearer tk_...`) that is unknown/expired/owner-disabled **or lacks the permission for that route** makes the skipper return false, so the JWT middleware tries to parse `tk_...` as JWT and also answers **401 code 11**. A client using API tokens must not try to "refresh" on code 11.

Important codes (status from each error's `HTTPError()` in `pkg/models/error.go`, `pkg/user/error.go`, `pkg/files/error.go`) [V]:

| Code | Meaning | HTTP |
|---|---|---|
| 11 | invalid/expired JWT (or rejected API token) | 401 |
| 1005 | user does not exist | 404 |
| 1011 | wrong username or password | **403** |
| 1012 | email not confirmed | 412 |
| 1017 | invalid TOTP passcode (also "TOTP required" at login) | 412 |
| 1020 / 1040 | account disabled / locked | 412 |
| 1031 | account is a bot (login refused) | 412 |
| 1039 | TOTP passcode already used | 412 |
| 2002 | invalid data (validation) | 412 (validation) / 400 (`ErrInvalidData`) |
| 2003 | invalid timezone (filter_timezone) | 400 |
| 2004 | invalid model (bind) | 400 |
| 3001 | project does not exist | 404 |
| 3007 | project identifier not unique | 400 |
| 3008 | project is archived (write on archived) | 412 |
| 3012/3013 | cannot delete / archive default project | 412 |
| 3014 | project view does not exist | 404 |
| 4001 | task title empty | 400 |
| 4002 | task does not exist | 404 |
| 4004 | bulk: need at least one task | 400 |
| 4007/4008/4009/4010/4023 | relation kind invalid / exists (409) / not found (404) / same task / cycle (409) | |
| 4011/4012 | attachment not found (404) / too large (400) | |
| 4013/4014/4016 | invalid sort param / order / task field | 400 |
| 4017/4019/4024/4033 | invalid filter comparator / value / expression / too complex | 400 |
| 4020 | cover attachment not on task | 400 |
| 4021 | user already assigned | 400 |
| 4022 | relative reminder without `relative_to` | 400 |
| 4026 | sort by position needs a view | 400 |
| 4027 | bulk update: invalid column in `fields` | 400 |
| 4029 | invalid repeat_after (<0 or >10y) | 400 |
| 4035 | file too large | 413 |
| 6002 | team does not exist | 404 |
| 7002 | user already has access | 409 |
| 8001/8002/8003 | label already on task (400) / label not found (404) / no access to label (403) | |
| 10001..10006 | bucket not found (404), not in view (400), cannot remove last bucket (412), **bucket limit exceeded (412)**, … | |
| 11001/11002 | saved filter not found (404) / not for link shares (412) | |
| 12002 | subscription already exists | 412 |
| 13001/13002 | link share password required (412) / invalid (403) | |
| 16002 | invalid refresh token | 401 |
| 16003 | session expired | 401 |
| 16004 | refresh token already used (rotation race) | 401 |
| 16005 | no refresh token cookie | 401 |
| 17001..17007 | OAuth2 server errors | 400 |
| 19001 | user data export not found | 404 |

Full list of codes extracted from source: 11, 1004–1040, 2001–2007, 3001–3017, 4001–4035, 6001–6010, 7002–7003, 8001–8003, 9001, 10001–10006, 11001–11002, 12001–12003, 13001–13003, 14001–14016, 14201–14204, 15001, 16001–16005, 17001–17007, 18001–18007 (time tracking, v2), 19001. [V] grep of `ErrCode*` constants in `pkg/`.

### 1.6 Dates, zero dates, nulls
- All `time.Time` fields serialize with Go's RFC 3339 (`encoding/json`), e.g. `"2026-10-08T14:00:00+02:00"` or `"...Z"`. The DB engine is set to the service time zone (`service.timezone`, default `GMT`), so offsets in responses follow the **server** zone. [V] `pkg/db/db.go` `SetTZLocation(config.GetTimeZone())`; [I] exact offset formatting. Always parse with offset, store as UTC.
- "No date" = Go zero time → `"0001-01-01T00:00:00Z"`. The web frontend treats **any year ≤ 1** as null (`frontend/src/helpers/parseDateOrNull.ts`) and writes `"0001-01-01T00:00:00Z"` to clear a date (`frontend/src/client/queries/taskMutations.ts` `API_ZERO_DATE`). [V]
- Clearing in v1 task update: a zero (or omitted, or `null`) `due_date`/`start_date`/`end_date` **clears** the date (full-replace semantics, §6). [V] `pkg/models/tasks.go` `updateSingleTask` ("if t.DueDate.IsZero() { ot.DueDate = time.Time{} }"). [I] JSON `null` for a `time.Time` is a no-op in Go → zero value.
- Dates sort with `NULLS LAST` on Postgres/SQLite (MySQL emulated). [V] `pkg/models/task_search.go` `getOrderByDBStatement`
- Empty relation arrays (`assignees`, `labels`, `attachments`, `reminders`) are **`null`** when empty (Go nil slices); `related_tasks` is `{}`; `reactions` is `null` unless expanded. [V] `pkg/models/tasks.go` `addMoreInfoToTasks`, `updateReminders` sets `nil` for none. Parse defensively.
- `hex_color`: stored without `#`, max 6 chars (`#` stripped, truncated to 6). [V] `pkg/utils/normalize_hex.go`

### 1.7 IDs and pseudo IDs [V] `pkg/models/project.go`, `pkg/models/saved_filters.go`, `pkg/models/link_sharing.go`
- `-1` = Favorites pseudo project (views `-1` List with filter `done = false`, `-2` Gantt, `-3` Table). Only listed when the user has ≥1 favorite task.
- Saved filter `n` ↔ project id `-(n) - 1` (filter 1 → project −2). `GetSavedFilterIDFromProjectID(p) = -p - 1`.
- Link-share "users" appear with `id = -shareID`, `username = "link-share-<id>"`, name `"<name> (Link Share)"`.

---

## 2. Authentication & session lifecycle

### 2.1 Auth methods [V] `pkg/routes/api_tokens.go`, `pkg/modules/auth/auth.go`, `pkg/routes/routes.go`
1. **User JWT** — `Authorization: Bearer <jwt>`. HS256 signed with `service.secret`. Claims: `type` (1 = user), `id`, `username`, `is_admin`, `iat`, `exp`, `sid` (session UUID), `jti`. Lifetime `service.jwtttlshort` (default **600 s**). [V] `NewUserJWTAuthtoken`, `config-raw.json`
2. **API token** — `Authorization: Bearer tk_<hex>`; scoped by route groups (`GET /routes`), has `expires_at`. Checked per route by `models.CanDoAPIRoute`. [V] `pkg/models/api_tokens.go` (`APITokenPrefix = "tk_"`), `pkg/routes/api_tokens.go`
3. **Link-share JWT** — claims `type`=2, `id`, `hash`, `project_id`, `permission`, `sharedByID`; lifetime `service.jwtttl` (default 259200 s = 3 days); renew with `POST /user/token`. [V] `NewLinkShareJWTAuthtoken`, `pkg/routes/api/v1/login.go` `RenewToken`
4. Basic auth only for CalDAV (`/dav`, `/.well-known/caldav`) and Atom feed (`/feeds/notifications.atom`) — not under `/api/v1`. [V] `pkg/routes/routes.go`

Per-request JWT validation does **not** check the session (`sid`) — a revoked session's access token stays valid until `exp` (≤10 min). [V] `pkg/user/user.go` `GetUserFromClaims` (no sid lookup); [I] consequence.

### 2.2 Refresh (critical for a mobile app)
- `POST /api/v1/user/token/refresh` reads the refresh token **only from the HttpOnly cookie** `vikunja_refresh_token` (path-scoped to `/api/v1/user/token/refresh` and `/api/v2/user/token/refresh`, prefixed with the base path of `service.publicurl`). Rotates the refresh token on every call (new `Set-Cookie`). Response `{"token": "<jwt>"}`. Errors 16002–16005 (401). [V] `pkg/routes/api/v1/login.go` `RefreshToken`, `pkg/modules/auth/auth.go` `SetRefreshTokenCookie`, `RefreshSession`
- `POST /api/v1/oauth/token` with JSON `{"grant_type":"refresh_token","refresh_token":"<raw>"}` → `{"access_token","token_type":"bearer","expires_in":600,"refresh_token":"<rotated>"}`. Uses the **same** `auth.RefreshSession` as the cookie endpoint, i.e. a refresh token from any session (incl. the one set as cookie by `/login`) can be refreshed here **without cookies**. [V] `pkg/modules/auth/oauth2server/token.go` `exchangeRefreshToken`; [I] that the cookie value from `/login` is interchangeable (same `session.RefreshToken`, same lookup `GetSessionByRefreshToken`).
- Session validity is sliding: refresh fails with 16003 if `now - last_active > jwtttl` (3 days) or `jwtttllong` (30 days) for long sessions (`long_token: true` at login). [V] `RefreshSession`
- Concurrent refresh with the same token → one wins, the other gets 16004 (do not clear stored token on 16004). [V] `RotateRefreshToken` + `IsUnusableRefreshToken`

### 2.3 Native-app login via built-in OAuth 2.0 (Authorization Code + PKCE) [V]
- Open in system browser: `{frontend_url}/oauth/authorize?response_type=code&client_id=<any>&redirect_uri=<uri>&state=<s>&code_challenge=<b64url(sha256(verifier))>&code_challenge_method=S256`. The web frontend route `oauth.authorize` (`frontend/src/router/index.ts`, `frontend/src/views/user/OAuthAuthorize.vue`) makes the user log in (local/LDAP/OIDC/TOTP), calls `POST /oauth/authorize`, then redirects to `redirect_uri?code=...&state=...`.
- `redirect_uri` must have a scheme starting with **`vikunja-`** (e.g. `vikunja-flutter://callback`) or be loopback `http://localhost|127.x|[::1]`. [V] `pkg/modules/auth/oauth2server/client.go`
- No client registry: `client_id` is free text, but must match between authorize and token. Code TTL 10 min, single use. [V] `pkg/models/oauth_codes.go`
- Exchange: `POST /api/v1/oauth/token` `{"grant_type":"authorization_code","code","client_id","redirect_uri","code_verifier"}` → TokenResponse (session created with `long=false`, i.e. 3-day sliding). [V] `token.go`
- `POST /api/v1/oauth/authorize` (JWT required, API tokens refused with 403): body `{response_type:"code", client_id, redirect_uri, state, code_challenge, code_challenge_method:"S256"}` → `{code, redirect_uri, state}`. [V] `authorize.go`

### 2.4 Auth endpoints (no JWT unless stated) — group `ur` is IP-rate-limited
| Method | Path | Notes |
|---|---|---|
| POST | `/login` | Only if local or LDAP auth enabled. Body `user.Login` `{username, password, totp_passcode?, long_token?}`. 200 `{"token": "<jwt>"}` + `Set-Cookie: vikunja_refresh_token=...; HttpOnly; SameSite=Lax; Path=/api/v1/user/token/refresh` (and v2 path). Errors: 1011 (403), 1017 (412, also when TOTP enabled and passcode missing), 1020/1040 (412), 1031, 400 bind. [V] `pkg/routes/api/v1/login.go`, `pkg/routes/api/shared/auth.go`, `pkg/user/user.go` |
| POST | `/user/token/refresh` | cookie only (see 2.2). Refresh limiter. |
| POST | `/oauth/token` | see 2.2/2.3. Refresh limiter. |
| POST | `/register` | Only if local auth; 404 if `service.enableregistration=false`. Body `{username (3–250, no spaces), password (8–72), email, language?}`. 200 `user.User`. Validation errors 412 w/ `invalid_fields`. [V] `user_register.go`, `pkg/user/user.go` `APIUserPassword` |
| POST | `/user/password/token` | `{email}` → `{"message":"Token was sent."}` [V] `user_password_reset.go` |
| POST | `/user/password/reset` | `{token, new_password}`; deletes **all** sessions of the user. [V] `shared.ResetPassword` |
| POST | `/user/confirm` | `{token}` email confirmation. 412 on bad token. [V] |
| POST | `/auth/openid/{provider}/callback` | Only if OIDC enabled. Body `{code, scope?, redirect_url, totp_passcode?}`; provider key from `/info` → `auth.openid_connect.providers[].key`. 200 `{token}`. [V] `pkg/modules/auth/openid/openid.go` |
| POST | `/shares/{share}/auth` | Only if link sharing enabled. `{password}` (path = share **hash**). 200 = `{token, id, hash, name, permission, sharing_type, shared_by, created, updated, project_id}` (password blanked). 412 code 13001 if password required. [V] `link_sharing_auth.go`, `shared.AuthenticateLinkShare` |
| GET | `/info` | public, see §3.1 |
| GET | `/docs.json`, `/docs`, `/docs/redoc.standalone.js` | public |
| GET | `/ws` | WebSocket upgrade, auth by first message (§9) |
| GET | `/metrics` | Prometheus if enabled |
| PATCH `/test/{table}`, DELETE `/test/all` | only if `service.testingtoken` set; header `Authorization: <testingtoken>` | e2e only |

Authenticated:
| Method | Path | Notes |
|---|---|---|
| GET | `/token/test` | 200 `{"message":"ok"}` (route check skipped for API tokens) [V] `token_check.go` |
| POST | `/token/test` | 418 `{"message":"🍵"}` |
| POST | `/user/token` | renew **link-share** token only; user tokens → 400 [V] |
| POST | `/user/logout` | deletes current session (`sid`), clears cookie. 200 `{"message":"Successfully logged out.","oidc_logout_url"?}` [V] |
| GET | `/routes` | API-token permission catalogue: `{"<group>": {"<perm>": {"path","method"}}}` [V] `pkg/models/api_routes.go` |

---

## 3. Route catalogue by resource

Auth column: **J** = JWT/API token required (all routes after `a.Use(SetupTokenMiddleware())`, `pkg/routes/routes.go` l.572); **P** = public. Flags = config switch that must be on for the route to exist (`/info` exposes most of them).

### 3.1 Service info
`GET /info` (P) → `shared.VikunjaInfos` [V] `pkg/routes/api/shared/info.go`:
```json
{"version","frontend_url","motd","link_sharing_enabled","max_file_size":"20MB","max_items_per_page":50,
 "available_migrators":["vikunja-file","ticktick","wekan","csv","planka", "+todoist/trello/microsoft-todo if enabled"],
 "task_attachments_enabled","enabled_background_providers":["upload","unsplash"],"totp_enabled",
 "legal":{"imprint_url","privacy_policy_url"},"caldav_enabled",
 "auth":{"local":{"enabled","registration_enabled"},"ldap":{"enabled"},
         "openid_connect":{"enabled","providers":[{"name","key","auth_url","logout_url","client_id","scope","email_fallback","username_fallback","force_user_info"}]}},
 "email_reminders_enabled","user_deletion_enabled","task_comments_enabled","demo_mode_enabled",
 "webhooks_enabled","public_teams_enabled","allow_icon_changes","enabled_pro_features":[...],
 "concurrent_writes": false-on-SQLite}
```
`concurrent_writes=false` → serialize batched writes (SQLite deadlocks). [V] doc string in `info.go`. Note `planka` is listed as available but has **no v1 route** (v2 only). [V] `routes.go` `registerMigrations` has no planka.

### 3.2 Current user, settings, avatar, TOTP, tokens, export, deletion
All J. [V] `pkg/routes/routes.go` l.587-653 and handlers in `pkg/routes/api/v1/`.

| Method | Path | Body / params | Response |
|---|---|---|---|
| GET | `/user` | — | `UserWithSettings` = `user.User` fields + `settings` (`UserGeneralSettings`), `deletion_scheduled_at`, `is_local_user`, `auth_provider` ("local"/"ldap"/OIDC name), `is_admin`, `pending_email?` (`user_show.go`) |
| POST | `/user/password` | `{old_password, new_password(8–72)}` | Message; **invalidates all sessions** (`models.ChangeUserPassword`) |
| GET | `/users` | `s` | `[]user.User` search (name/email only if target allows discovery) (`user_list.go`) |
| POST | `/user/settings/email` | `{new_email, password}` | Message (confirmation mail flow) |
| GET | `/user/settings/avatar` | — | `{avatar_provider}` |
| POST | `/user/settings/avatar` | `{avatar_provider}` one of `gravatar, upload, initials, marble, ldap, openid, default` | Message |
| PUT | `/user/settings/avatar/upload` | multipart field **`avatar`** | Message; sets provider `upload`; 400 if not an image |
| POST | `/user/settings/general` | `UserGeneralSettings` (§5.17) — **full replace** incl. `frontend_settings` | Message |
| GET | `/user/timezones` | — | `[]string` (unsorted) |
| PUT | `/user/settings/token/caldav` | — | **201** `user.Token` `{id, token (clear text, once), created}` |
| GET | `/user/settings/token/caldav` | — | `[]{id, created}` |
| DELETE | `/user/settings/token/caldav/{id}` | — | Message |
| GET | `/user/sessions` | page/per_page | `[]Session` `{id, device_info, ip_address, last_active, created}` (no swagger doc) |
| DELETE | `/user/sessions/{session}` | — | Message |
| GET/POST/PUT/DELETE | `/user/settings/webhooks[...]` | flag `webhooks.enabled` | see §3.15 |
| GET | `/user/settings/totp` | flag `service.enabletotp`; local users only (1021 otherwise) | `{secret, enabled, url}` (`APICopy`) |
| POST | `/user/settings/totp/enroll` | — | `user.TOTP` |
| POST | `/user/settings/totp/enable` | `{passcode}` | Message; **deletes all sessions** of the user → client must re-login |
| POST | `/user/settings/totp/disable` | `{password}` | Message |
| GET | `/user/settings/totp/qrcode` | — | `image/jpeg` |
| POST | `/user/export/request` | `{password}` (local users) | Message (async, mail when ready) |
| POST | `/user/export/download` | `{password}` (local users) | ZIP stream (`Content-Disposition`), 404 if none |
| GET | `/user/export` | — | `{id, size, created, expires}` or `{}` |
| POST | `/user/deletion/request` | `{password}` (local users) | Message (mail with token) — flag `service.enableuserdeletion` |
| POST | `/user/deletion/confirm` | `{token}` | 204 |
| POST | `/user/deletion/cancel` | `{password}` (local users) | 204 |
| PUT | `/user/bots` | `BotUser` (username must start `bot-`) | 201 |
| GET | `/user/bots`, `/user/bots/{bot}` | — | `[]BotUser` / `BotUser` |
| POST/DELETE | `/user/bots/{bot}` | `{status: 0|2, ...}` | |
| GET | `/avatar/{username}` | `size` (default 250, capped) | image blob (mime varies). **Requires auth header** (registered after token middleware). Swagger wrongly says `/{username}/avatar`. |

### 3.3 API tokens [V] `pkg/models/api_tokens.go`
| PUT `/tokens` | `{title, permissions: {"tasks":["read_all","update"],...}, expires_at, owner_id?(bot)}` → 201 incl. clear `token` (`tk_...`, shown once) |
|---|---|
| GET `/tokens` | `s`, page/per_page → `[]APIToken` (no `token`) |
| DELETE `/tokens/{token}` | Message |

### 3.4 Projects [V] `pkg/models/project.go`, `routes.go` l.655-677
| Method | Path | Params/Body | Response |
|---|---|---|---|
| GET | `/projects` | `page, per_page, s` (title/description/identifier, or comma list of ids), `is_archived=true` (include archived), `expand=permissions` (adds `max_permission`) | `[]Project` **flat**, ordered by `position`; build the tree from `parent_project_id`. Appended: Favorites pseudo project (if any favorite task) and **all saved filters as pseudo projects** (negative ids) on every page. `x-pagination-result-count` counts real projects + favorites, not saved filters. |
| GET | `/projects/{project}` | — | `Project` incl. `views`, `subscription`, `owner`, `background_information` |
| PUT | `/projects` | `Project` (`title` required 1–250; `parent_project_id` needs write on parent) | 201 `Project` incl. 4 default views (List w/ filter `done = false`, Gantt, Table, Kanban with buckets To-Do/Doing/Done) [V] `CreateDefaultViewsForProject` in `project_view.go` |
| POST | `/projects/{project}` | `Project` (see §6.2 semantics) | `Project`; for a saved-filter pseudo id it updates title/description/is_favorite of the filter |
| DELETE | `/projects/{project}` | — | Message; default project only deletable by owner (3012) |
| GET | `/projects/{project}/projectusers` | `s` | `[]user.User` all users with access (any path) |
| PUT | `/projects/{projectid}/duplicate` | `{parent_project_id?, duplicate_shares?}` | 201 `{..., "duplicated_project": Project}` |
| GET | `/projects/{project}/background` | — | `image/jpg` blob (flag `backgrounds.enabled`), `Last-Modified`/304 support |
| DELETE | `/projects/{project}/background` | — | `Project` |
| PUT | `/projects/{project}/backgrounds/upload` | multipart **`background`** | `Project` (flag `backgrounds.upload.enabled`) |
| GET | `/backgrounds/unsplash/search` | `s`, `p` (page) | `[]{id,url,thumb,blur_hash,info}` (flag unsplash) |
| POST | `/projects/{project}/backgrounds/unsplash` | `background.Image` (`id` required) | `Project` |
| GET | `/backgrounds/unsplash/images/{image}` and `/thumb` | — | proxied image (auth required). Swagger wrongly says `/image/`. |

Archive: `is_archived` cascades to descendants; archived projects are read-only (3008/412). Archiving the user's default project → 3013. [V] `UpdateProject`

### 3.5 Project views [V] `pkg/models/project_view.go`
| GET `/projects/{project}/views` | `[]ProjectView` ordered by `position` (no paging) |
|---|---|
| GET `/projects/{project}/views/{view}` | `ProjectView` |
| PUT `/projects/{project}/views` | `ProjectView` → 201. Non-kanban views force `bucket_configuration_mode:"none"`; kanban with `none` → `manual` + default buckets To-Do/Doing/Done created and set as `default_bucket_id`/`done_bucket_id` |
| POST `/projects/{project}/views/{view}` | update; omitted `bucket_configuration_mode` keeps stored mode |
| DELETE `/projects/{project}/views/{view}` | deletes view + its task_buckets/positions |

### 3.6 Buckets (kanban) [V] `pkg/models/kanban.go`, `kanban_task_bucket.go`
| GET `/projects/{project}/views/{view}/buckets` | `[]Bucket` (no tasks), by position |
|---|---|
| PUT `/projects/{project}/views/{view}/buckets` | `{title, limit?, position?}` → 201 |
| POST `/projects/{project}/views/{view}/buckets/{bucket}` | update |
| DELETE `/projects/{project}/views/{view}/buckets/{bucket}` | cannot delete last bucket (10003); server clears `default_bucket_id`/`done_bucket_id` if it was one |
| POST `/projects/{project}/views/{view}/buckets/{bucket}/tasks` | **move task to bucket**: body `{"task_id": N}` → `TaskBucket` `{bucket_id, bucket (with updated count), task_id, project_view_id, task}`. Moving into the view's `done_bucket_id` marks the task done (repeating tasks are re-scheduled and routed back to `default_bucket_id`); moving out of done bucket marks undone. Bucket `limit` enforced (10004, 412). |

### 3.7 Tasks [V] `pkg/models/tasks.go`, `task_collection.go`, `routes.go` l.679-743
| Method | Path | Notes |
|---|---|---|
| GET | `/tasks` | all tasks across all **non-archived** projects of the user (+ favorites); collection params §4. Flat `[]Task`. |
| GET | `/projects/{project}/tasks` | collection for one project without view (flat). Not in swagger. |
| GET | `/projects/{project}/views/{view}/tasks` | collection through a view: view filter AND-ed with request filter; for kanban views with bucket mode ≠ none returns **`[]Bucket` each with `tasks` and `count`** instead of `[]Task` (§4.4). Positions populated. |
| PUT | `/projects/{project}/tasks` | create → 201 `Task`. Body = Task (§5.1). `assignees` (array of `{id}`) **are applied**, `labels` are **ignored** (use label endpoints), `reminders` applied, `is_favorite` applied, `bucket_id` optional (else default bucket of each kanban view), `index` ignored. |
| GET | `/tasks/{id}` | `Task` + `subscription`; `expand` allowed. |
| GET | `/projects/{project}/tasks/by-index/{index}` | `{project}` = numeric id **or** project identifier (e.g. `PROJ`, upper-cased; pure digits = id). |
| POST | `/tasks/{id}` | update (full replace!, §6.1). Moving projects via `project_id` (re-indexes task; old address kept as alias). |
| DELETE | `/tasks/{id}` | **soft delete** (`deleted_at`), hard-deleted by cron after 30 days; disappears from all v1 reads. |
| PUT | `/tasks/{id}/duplicate` | 201 `{"duplicated_task": Task}`; copies labels, assignees, attachments, reminders, adds `copiedfrom` relation |
| POST | `/tasks/{id}/read` | mark read for current user (removes unread status). Response object has no json tags → keys `TaskID`,`UserID` [V struct] |
| POST | `/tasks/{task}/position` | `{project_view_id, position}` → `TaskPosition`. Positions < `MinPositionSpacing` (0.01) apart trigger server recalculation. |
| POST | `/tasks/bulk` | `BulkTask` `{task_ids:[...], fields:["done",...], values: Task}` → `BulkTask` with `tasks`. Allowed `fields`: `title, description, done, due_date, repeat_after, priority, start_date, end_date, hex_color, percent_done, project_id, bucket_id, repeat_mode, cover_image_attachment_id` (else 4027). Needs write on every project. See §6.1 caveat. |

### 3.8 Assignees [V] `pkg/models/task_assignees.go`
| PUT `/tasks/{id}/assignees` | `{"user_id": N}` → 201 `{user_id, created}`; implicitly subscribes assignee; 4021 if already assigned |
|---|---|
| DELETE `/tasks/{id}/assignees/{userId}` | numeric user id |
| GET `/tasks/{id}/assignees` | `s`, page/per_page → `[]user.User` |
| POST `/tasks/{id}/assignees/bulk` | `{"assignees":[{"id":1},...]}` replaces full set (empty array = unassign all) → 201 |

### 3.9 Labels [V] `pkg/models/label.go`, `label_task.go`
| GET `/labels` | `s`, page/per_page → labels created by user or on any task the user can read |
|---|---|
| GET `/labels/{id}` | |
| PUT `/labels` | `{title(1–250), description?, hex_color?}` → 201 |
| POST `/labels/{id}` | update (creator only). Swagger wrongly says PUT. |
| DELETE `/labels/{id}` | creator only |
| GET `/tasks/{task}/labels` | `s`, page → `[]Label` |
| PUT `/tasks/{task}/labels` | `{"label_id": N}` → 201 `{label_id, created}`; bumps task `updated` |
| DELETE `/tasks/{task}/labels/{label}` | |
| POST `/tasks/{task}/labels/bulk` | `{"labels":[{"id":..},...]}` replaces full set → 201 |

### 3.10 Relations [V] `pkg/models/task_relation.go`
| PUT `/tasks/{task}/relations` | `{other_task_id, relation_kind}` → 201 `{task_id, other_task_id, relation_kind, created_by, created}`; inverse row auto-created; cross-project allowed (write on base, read on other); cycles → 4023 |
|---|---|
| DELETE `/tasks/{task}/relations/{relationKind}/{otherTask}` | deletes both directions |

Kinds and auto-inverse: `subtask↔parenttask`, `related↔related`, `duplicateof↔duplicates`, `blocking↔blocked`, `precedes↔follows`, `copiedfrom↔copiedto`. Meaning: kind describes base→other ("task 2 `subtask` of 1" stores 2→1 `subtask`… see comment block in file). [V] `getInverseRelation`

### 3.11 Comments (flag `service.enabletaskcomments`) [V] `pkg/models/task_comments.go`
| GET `/tasks/{task}/comments` | `order_by=asc|desc` (by created), `s`, page/per_page → `[]TaskComment` with `reactions` |
|---|---|
| PUT `/tasks/{task}/comments` | `{"comment": "<html>"}` → 201; @mentions notify |
| GET/POST/DELETE `/tasks/{task}/comments/{commentid}` | read / update `{comment}` / delete |

### 3.12 Attachments (flag `service.enabletaskattachments`) [V] `pkg/routes/api/v1/task_attachment.go`, `pkg/models/task_attachment.go`, `pkg/web/files/*.go`
| GET `/tasks/{task}/attachments` | page/per_page → `[]TaskAttachment` |
|---|---|
| PUT `/tasks/{task}/attachments` | multipart, field **`files`** (repeatable) → 200 `{"success":[TaskAttachment...], "errors":[{"code"?, "message"}]}` (per-file failures don't fail request) |
| GET `/tasks/{task}/attachments/{attachment}` | download: `Content-Disposition: attachment; filename=...`, `Content-Type`, `Content-Length`, `Last-Modified`, `X-Content-Type-Options: nosniff`, Range/If-Modified-Since for local storage. `preview_size=sm|md|lg|xl` (100/200/400/800 px wide) → `image/png` preview when the file is an image. Returns JSON on error. |
| DELETE `/tasks/{task}/attachments/{attachment}` | |

Max size: `files.maxsize` (default 20MB, `/info.max_file_size`).

### 3.13 Sharing
Users [V] `pkg/models/project_users.go`:
| GET `/projects/{project}/users` | `s`, page → `[]UserWithPermission` (user + `permission`) |
|---|---|
| PUT `/projects/{project}/users` | `{"username": "...", "permission": 0|1|2}` → 201 |
| POST `/projects/{project}/users/{username}` | `{permission}` — path segment is the **username** (swagger says userID) |
| DELETE `/projects/{project}/users/{username}` | |

Teams [V] `pkg/models/project_team.go`:
| GET `/projects/{project}/teams` | → `[]TeamWithPermission` |
|---|---|
| PUT `/projects/{project}/teams` | `{team_id, permission}` → 201 |
| POST/DELETE `/projects/{project}/teams/{team}` | numeric team id |

Link shares (flag `service.enablelinksharing`) [V] `pkg/models/link_sharing.go`:
| PUT `/projects/{project}/shares` | `{name?, permission, password?}` → 201 (`hash` generated; `sharing_type` 1=no pw, 2=with pw) — admin on project required |
|---|---|
| GET `/projects/{project}/shares` | `s` (hash), page |
| GET/DELETE `/projects/{project}/shares/{share}` | numeric id |

Share URL in frontend: `{frontend_url}share/{hash}/auth` [I — not verified in this pass].

### 3.14 Teams [V] `pkg/models/teams.go`, `team_members.go`
| GET `/teams` | `s`, page, `include_public=true` (if public teams enabled) |
|---|---|
| GET `/teams/{team}` | `Team` with `members` |
| PUT `/teams` | `{name, description?, is_public?}` → 201 |
| POST/DELETE `/teams/{team}` | |
| PUT `/teams/{team}/members` | `{"username": "...", "admin": bool}` → 201 |
| DELETE `/teams/{team}/members/{username}` | |
| POST `/teams/{team}/members/{username}/admin` | toggles admin (swagger says userID; it is the username param) |

### 3.15 Saved filters [V] `pkg/models/saved_filters.go`
| PUT `/filters` | `{title, description?, filters: {filter, filter_include_nulls?, sort_by?, order_by?, s?}, is_favorite?}` → 201; creates default views for pseudo project `-(id)-1` |
|---|---|
| GET/POST/DELETE `/filters/{filter}` | numeric **filter id** (not the pseudo project id) |

There is **no** `GET /filters` list in v1 — saved filters come via `GET /projects` (negative ids). Tasks of a saved filter: `GET /projects/{-id-1}/views/{viewId}/tasks`. Link shares can't use saved filters (11002). If the filter has no `filter_timezone`, the owner's timezone is used.

### 3.16 Subscriptions [V] `pkg/models/subscription.go`
`PUT /subscriptions/{entity}/{entityID}` (entity `project` | `task`) → 201 `{id, entity, entity_id, created}`; `DELETE` same path (if inherited from parent project, an opt-out is stored). Current state is embedded as `subscription` in `GET /tasks/{id}` and `GET /projects/{id}`.

### 3.17 Notifications [V] `pkg/models/notifications_database.go`, `pkg/routes/api/v1/notifications.go`
| GET `/notifications` | page/per_page → `[]{id, name, notification:{...}, read_at, created}` (only notifications for projects still readable) |
|---|---|
| POST `/notifications/{id}` | `{"read": true|false}` → updated |
| POST `/notifications` | mark all read → `{"message":"success"}` (link shares 403) |
| DELETE `/notifications` | delete all of the caller |

`name` values persisted to DB and their payloads [V] `pkg/models/notifications.go`:
- `task.reminder` → `{task, project}` (reminder itself not stored)
- `task.comment` → `{doer, task, comment, mentioned, project}`
- `task.assigned` → `{doer, task, assignee, project}`
- `task.deleted` → `{doer, task}`
- `task.created` → `{doer, task, project}`
- `project.created` → `{doer, project}`
- `team.member.added` → `{member, doer, team}`
- `task.mentioned` → `{doer, task, is_new, project}`
- Overdue (`task.undone.overdue`) and `data.export.ready` are **mail-only** (`ToDB()` returns nil).
Plus user/migration notifications from `pkg/user/notifications.go`, `pkg/modules/migration/handler/notifications.go` (e.g. `migration.done`, `migration.failed`).

### 3.18 Reactions [V] `pkg/models/reaction.go`, `reaction_permissions.go`
`{kind}` = `tasks` | `comments`.
| GET `/{kind}/{id}/reactions` | → `ReactionMap` = `{"👍": [user,...], ...}` |
|---|---|
| PUT `/{kind}/{id}/reactions` | `{"value": "<≤20 chars>"}` → 201 |
| POST `/{kind}/{id}/reactions/delete` | `{"value": "..."}` removes caller's reaction |

### 3.19 Webhooks (flag `webhooks.enabled`) [V] `pkg/models/webhooks.go`, `user_webhooks.go`
| GET/PUT `/projects/{project}/webhooks` | `{target_url, events:[...], secret?, basic_auth_user?, basic_auth_password?}` |
|---|---|
| POST/DELETE `/projects/{project}/webhooks/{webhook}` | update changes **events only** |
| GET `/webhooks/events` | `[]string` |
| GET/PUT `/user/settings/webhooks`, POST/DELETE `/user/settings/webhooks/{webhook}`, GET `/user/settings/webhooks/events` | user-level webhooks (PUT returns 200, not 201) |

### 3.20 Migration [V] `pkg/modules/migration/handler/*.go`, `pkg/routes/routes.go` `registerMigrations`
- OAuth migrators (if enabled): `todoist`, `trello`, `microsoft-todo`: `GET /migration/{name}/auth` → `{url}`; `POST /migration/{name}/migrate` `{"code": "..."}` → Message (async); `GET /migration/{name}/status` → `migration.Status` `{id, migrator_name, started_at, finished_at, error_kind, error_message}`.
- File migrators (always): `vikunja-file`, `ticktick`, `wekan`: `PUT /migration/{name}/migrate` multipart field **`import`**; `GET /migration/{name}/status`.
- CSV: `GET /migration/csv/status`, `PUT /migration/csv/detect` (`import`), `PUT /migration/csv/preview` (`import` + `config` JSON), `PUT /migration/csv/migrate`.
- One migration per user at a time (14005).

### 3.21 Admin (license feature `admin_panel` + instance admin; otherwise **404**) [V] `pkg/routes/admin_gate.go`, `feature_gate.go`, `pkg/routes/api/v1/admin/*.go`
`GET /admin/overview`, `GET /admin/users` (`s`, page) → `[]AdminUser` (user + `is_admin, status, issuer, subject?, auth_provider?`), `POST /admin/users` (`{username,password,email,name?,language?,is_admin?,skip_email_confirm?}`), `PATCH /admin/users/{id}/admin` `{is_admin}`, `PATCH /admin/users/{id}/status` `{status: 0..3}`, `DELETE /admin/users/{id}?mode=now|scheduled` (204), `GET /admin/projects` (`s`, page), `PATCH /admin/projects/{id}/owner` `{owner_id}`. Not relevant for an end-user mobile app.

### 3.22 Plugins
`/api/v1/plugins/*` when `plugins.enabled` (authenticated + unauthenticated groups). [V] `routes.go` l.998-1006. Out of scope.

### 3.23 Time tracking
**Not in v1.** Only `/api/v2/time-entries`, `/api/v2/tasks/{task_id}/time-entries`, `/api/v2/projects/{project_id}/time-entries`, `/api/v2/time-entries/timer/stop`. v1 only exposes `expand=time_entries_count` on tasks. [V] `pkg/routes/api/v2/time_entries.go`, absence in `routes.go`.

---

## 4. Task collections (list/filter/search)

### 4.1 Query parameters [V] `pkg/models/task_collection.go`, `task_collection_sort.go`, `pkg/web/handler/read_all.go`
| Param | Meaning |
|---|---|
| `page`, `per_page` | §1.4 |
| `s` | full-text over `title`,`description`; `#12` also matches task index 12 |
| `sort_by` (repeatable) | `id, title, description, done, done_at, due_date, created_by_id, project_id, repeat_after, priority, start_date, end_date, hex_color, percent_done, uid, created, updated, position, bucket_id, index, relevance` (`relevance` only on ParadeDB w/ `s`). `position` requires a view (4026). `id asc` always appended as final tiebreaker. Through a view, `position asc` appended if not given. |
| `order_by` (repeatable, index-aligned with `sort_by`) | `asc` (default) / `desc`; anything else → 4014 |
| `filter` | filter expression §4.2 |
| `filter_timezone` | IANA zone used for datemath rounding (`now/d`) and naive dates; invalid → 2003. Default: server time zone. |
| `filter_include_nulls` | `true` → each comparison also matches NULL (and 0 for numeric fields) |
| `expand` (repeatable) | `subtasks` (only root tasks + their subtasks, may exceed per_page), `buckets` (`buckets` array per task), `reactions`, `comments` (first 50), `comment_count`, `time_entries_count`, `is_unread`; invalid → 412/2002 |

Unknown params ignored [I].

### 4.2 Filter grammar [V] `pkg/models/task_collection_filter.go`, `task_search.go`
- Expression parsed by `fexpr` after preprocessing: `field op value` joined with `&&` / `||`, parentheses allowed. Ops: `=, !=, >, >=, <, <=, like, in, not in` (`like` → `%value%`). Values may be quoted `'..'`/`".."`; bare values get quoted automatically.
- Fields: any sortable field above (`project` is an alias for `project_id`), plus `assignees` (by **username**, comma list for `in`), `labels`/`label_id` (label ids), `reminders` (datetime), `created_by` (username), `parent_project`/`parent_project_id`, `bucket_id`.
- Date values: datemath (`now`, `now/d`, `now+7d`, `now/w`, …) evaluated in `filter_timezone`, or RFC 3339, `YYYY-MM-DD HH:MM`, `YYYY-MM-DD`, `YYYY-M-D`. Booleans `true/false`.
- Limits: 16 KiB and nesting depth 100 (4033).
- Example used by the web "upcoming" page: `sort_by=due_date&sort_by=id&order_by=asc&order_by=desc&filter=done = false && due_date < '<ISO to>' && due_date > '<ISO from>'&filter_include_nulls=false&expand=comment_count&expand=is_unread&filter_timezone=<user tz>` [V] `frontend/src/views/tasks/ShowTasks.vue` l.264-299. Widget-style "today": `done = false && due_date < now/d+1d` with `filter_timezone=<tz>` [I composed from grammar].
- Default saved filter created for every user: `done = false && assignees = <username>` ("My Open Tasks"). [V] `project.go` `CreateDefaultSavedFiltersForUser`

### 4.3 View interplay [V] `task_collection.go` `ReadAll`
- View filter `view.filter.filter` is AND-ed with the request filter: `(request) && (view)`. Consequence: the default **List view (`done = false`) can never return done tasks** via v1 request params; use the Table view, no-view endpoint, or `/tasks` with `project = X`. [V code; I consequence]
- View `filter.s` overrides request `s`; view `filter_include_nulls=true` forces it on.
- Saved filters (`project_id < -1`): stored `sort_by/order_by` appended after request ones; request filter merged.
- Link-share auth: project pinned to the share's project.

### 4.4 Kanban responses [V] `kanban.go` `GetTasksInBucketsForView`, `task_collection.go` `getTaskOrTasksInBuckets`
- `GET /projects/{p}/views/{kanbanView}/tasks` → `[]Bucket` (ordered by position), each `{..., "tasks":[Task...], "count": <total in bucket>}`; `per_page`/`page` apply **per bucket**; tasks sorted by position. Pagination headers count buckets.
- Load more of one bucket: same URL with `filter=bucket_id = <id>&page=N` → returns a **flat `[]Task`**.
- Filter-mode buckets (`bucket_configuration_mode:"filter"`): bucket ids are the indexes into `bucket_configuration`, each bucket's tasks are the result of its filter; tasks cannot be moved manually.
- Tasks without a bucket row in that view are not returned in any bucket.

---

## 5. JSON models (field-by-field)

### 5.1 Task [V] `pkg/models/tasks.go` struct `Task`
| Field | Type | R/W | Notes |
|---|---|---|---|
| `id` | int64 | RO | path param on update |
| `title` | string | RW | required on create (4001); `minstringlength(1)` |
| `description` | string | RW | HTML (TipTap). Recurring tasks: checklists reset when re-opened |
| `done` | bool | RW | |
| `done_at` | datetime | RO | set when marked done, zeroed when undone |
| `due_date` | datetime | RW | zero = none |
| `reminders` | `[]TaskReminder` or null | RW | full replace on update |
| `repeat_after` | int64 seconds | RW | 0..315360000 (10y) else 4029 |
| `repeat_mode` | int | RW | 0 = after `repeat_after`, 1 = monthly (ignores repeat_after), 2 = from current date |
| `priority` | int64 | RW | UI scale 0 unset,1 low,2 medium,3 high,4 urgent,5 do now (`frontend/src/constants/priorities.ts`) |
| `start_date`, `end_date` | datetime | RW | |
| `assignees` | `[]user.User` or null | RW on create & update (full replace!) | emails stripped |
| `labels` | `[]Label` or null | RO | use label endpoints |
| `hex_color` | string ≤7 | RW | stored w/o `#` |
| `percent_done` | float 0..1 | RW | |
| `identifier` | string | RO | `"<PROJECT_IDENTIFIER>-<index>"` or `"#<index>"` if project has no identifier |
| `index` | int64 | RO | per project, reassigned when moved between projects |
| `project_id` | int64 | RW | from URL on create; change on update = move |
| `related_tasks` | `{kind: [Task]}` | RO | nested tasks have `related_tasks: null`, only accessible ones included |
| `attachments` | `[]TaskAttachment` or null | RO | |
| `cover_image_attachment_id` | int64 | RW | must belong to task (4020); 0 = none |
| `is_favorite` | bool | RW | per user |
| `is_unread` | bool? | RO | only with `expand=is_unread`; omitted when false? — present (`true`) only if an unread row exists [V `addIsUnreadToTasks`] |
| `subscription` | Subscription? | RO | only on single-task read |
| `created`, `updated` | datetime | RO | |
| `deleted_at` | datetime | RO | `omitzero`, never seen in v1 reads |
| `bucket_id` | int64 | (RO in practice) | only populated through a kanban view; **ignored by v1 update** (§6.1) but honored on create |
| `buckets` | `[]Bucket` | RO | `expand=buckets` |
| `comments` | `[]TaskComment` | RO | `expand=comments` (first 50) |
| `comment_count` | int64? | RO | `expand=comment_count` |
| `time_entries_count` | int64? | RO | `expand=time_entries_count` |
| `position` | float64 | RO | per view; 0 outside a view; change via `/tasks/{id}/position` |
| `reactions` | ReactionMap | RO | `expand=reactions` |
| `created_by` | user.User | RO | |
Not exposed: `uid` (CalDAV only), `created_by_id`.

### 5.2 TaskReminder [V] `pkg/models/task_reminder.go`
`{"reminder": datetime, "relative_period": int64 seconds (negative = before), "relative_to": "" | "due_date" | "start_date" | "end_date"}`. Relative reminders get `reminder` computed server-side from the referenced date (zero if that date is unset). `relative_period ≠ 0` without `relative_to` → 4022. Duplicates resolved by absolute unix time (two relative reminders on an unset date would collapse — [I]). Sorted ascending. Repeating tasks: on done, server shifts reminders by the repeat interval itself (client-sent reminders are overwritten in that update). [V] `updateDone`, `setTaskDates*`

### 5.3 Label `{id, title, description, hex_color, created_by, created, updated}` [V]
### 5.4 TaskAttachment `{id, task_id, created_by, file:{id, name, mime, size, created}, created}` [V] `task_attachment.go`, `pkg/files/files.go`
### 5.5 TaskComment `{id, comment, author, reactions, created, updated}` [V]
### 5.6 TaskRelation `{task_id, other_task_id, relation_kind, created_by, created}` [V]
### 5.7 Project [V] `pkg/models/project.go`
`{id, title(1–250, required), description, identifier(≤10, unique), hex_color, parent_project_id (always a number in responses, 0 = top level), owner, is_archived, background_information (null | UnsplashPhoto | {"Type":"upload"} — struct without json tag), background_blur_hash, is_favorite, subscription?, position (float), views:[ProjectView], max_permission (null unless expand=permissions; 0/1/2), created, updated}`.
### 5.8 ProjectView [V] `pkg/models/project_view.go`
`{id, title, project_id, view_kind:"list"|"gantt"|"table"|"kanban", filter: {filter, s, sort_by, order_by, filter_include_nulls} | null, position, bucket_configuration_mode:"none"|"manual"|"filter", bucket_configuration:[{title, filter:{filter,...}}], default_bucket_id, done_bucket_id, created, updated}` (enums serialized as strings).
### 5.9 Bucket `{id, title, project_view_id, tasks?(omitempty), limit (0 = none), count, position, created_by, created, updated}` [V] `kanban.go`
### 5.10 TaskPosition `{task_id, project_view_id, position}`; TaskBucket `{bucket_id, bucket, task_id, project_view_id, task}` [V]
### 5.11 BulkTask `{task_ids, fields, values: Task, tasks}` [V] `bulk_task.go`
### 5.12 SavedFilter `{id, filters: TaskCollection, title, description, owner, is_favorite, created, updated}` [V]
### 5.13 Subscription `{id, entity:"project"|"task", entity_id, created}` [V]
### 5.14 LinkSharing `{id, hash, name, permission, sharing_type (0/1/2), password (write-only), shared_by, created, updated}` [V]
### 5.15 Team `{id, name, description, external_id, created_by, members:[{...user, admin}], is_public, created, updated}`; TeamMember `{id, username, admin, created}`; ProjectUser `{id, username, permission, created, updated}`; TeamProject `{id, team_id, permission, created, updated}` [V]
### 5.16 user.User (public view) `{id, name, username, email? (omitempty, usually stripped), bot_owner_id? , created, updated}` [V] `pkg/user/user.go`
### 5.17 UserGeneralSettings [V] `pkg/models/user_settings.go`
`{name, email_reminders_enabled, discoverable_by_name, discoverable_by_email, overdue_tasks_reminders_enabled, overdue_tasks_reminders_time ("HH:MM", required), default_project_id, week_start (0=Sun..6), language, timezone, frontend_settings (any JSON), extra_settings_links (RO)}`. Update replaces every field (send the whole object back).
### 5.18 Webhook `{id, target_url, events, project_id, user_id, secret/basic_auth_* (write-only), created_by, created, updated}`; APIToken `{id, title, token? (create only), permissions, expires_at, created, owner_id?}`; Session `{id, device_info, ip_address, last_active, created}` [V]
### 5.19 Notification `{id, name, notification, read_at (zero = unread), created}` [V] `pkg/notifications/` `DatabaseNotification`

---

## 6. Write semantics & gotchas (important for an offline-first client)

### 6.1 `POST /tasks/{id}` is a full replace [V] `pkg/models/tasks.go` `updateSingleTask` (~l.1292-1677)
- Columns always written: `title, description, done, due_date, repeat_after, priority, start_date, end_date, hex_color, percent_done, project_id, bucket_id(no-op), repeat_mode, cover_image_attachment_id` (+`done_at`, `index` when relevant). Zero/omitted values **clear** `description, priority, due_date, start_date, end_date, repeat_after, hex_color, percent_done, repeat_mode, is_favorite, cover_image_attachment_id, done`. `title`/`project_id` keep the old value when empty/0 (mergo).
- **Assignees** are replaced by the sent `assignees` (omitted → all removed). [V] `updateTaskAssignees` called unconditionally.
- **Reminders** are deleted and re-inserted from the sent `reminders` (omitted → all removed). [V] `updateReminders` called unconditionally.
- **Labels** in the body are ignored. [V] commented-out code.
- `bucket_id` in the body is **ignored** for moves (field is `xorm:"-"`, no handling in update) despite the struct doc; use `POST /projects/{p}/views/{v}/buckets/{b}/tasks`. [V code; I that the doc is stale]
- Bulk update (`POST /tasks/bulk` with `fields`) limits the **columns**, but the same function still replaces assignees and reminders from `values` [V: no guard on `fields` for those calls; no test covers it] → for v1 always send `values.assignees`/`values.reminders` round-tripped or avoid bulk for tasks with assignees/reminders. [I] treat as bug risk.
- **Safe recipe**: always `GET /tasks/{id}`, mutate, POST the complete object back (exactly what the old web client did). For "mark done" from a notification action: GET + POST with `done:true`.
- Marking a repeating task done: server advances `due_date/start_date/end_date/reminders` by the interval (`repeat_mode` rules), sets `done=false`, `done_at=now`, resets description checkboxes; response contains the new dates. In kanban, it is moved to the default bucket. [V] `updateDone`, `setTaskDatesDefault/MonthRepeat/FromCurrentDateRepeat`, `moveTaskToDefaultBuckets`
- Done ↔ done bucket: marking done moves the task to the done bucket of every manual kanban view of the project; undone moves it out. [V] `moveTaskToDoneBuckets`

### 6.2 `POST /projects/{id}` [V] `UpdateProject`
- Always writes `title, is_archived, identifier, hex_color, position` → omitted values clear them; omitted `position` (0) triggers recalculation of all sibling positions (`< 0.1`). Round-trip the full object.
- `description` only written if non-empty → **cannot clear a project description via v1**.
- `parent_project_id` written only when present; explicit `0` detaches (needs admin permission).
- `is_favorite` toggles favorite for the caller.

### 6.3 Others
- `POST /user/settings/general` replaces all settings (incl. `frontend_settings`). [V]
- Project view update with missing `bucket_configuration_mode` keeps the stored mode. [V]
- Webhook update changes only `events`. [V]
- Echo binds path params before the JSON body; a body `id` could override the path id [I — Echo bind order]; send matching ids.

---

## 7. Sync-relevant facts
- Tasks are **soft-deleted**; v1 offers **no way to list deletions** (only CalDAV sync-collection uses `GetDeletedTasksSince`). Delta sync via `filter=updated > '<ts>'` therefore cannot detect deletions → periodic full ID reconcile per project needed (or use v2 if it offers a trash/deleted listing — out of scope here). [V] `tasks.go` `Delete`, `GetDeletedTasksSince`
- `updated` is bumped on task update, label add/remove (sync), and **asynchronously** via event listener for comments, assignees, attachments, relations (`HandleTaskUpdateLastUpdated` registered for `TaskComment*`, `TaskAssignee*`, `TaskAttachment*`, `TaskRelation*` events). [V] `pkg/models/listeners.go` l.50-58, `label_task.go`. Position/bucket moves without done change: [I] probably no `updated` bump.
- Project `updated` is bumped by most task mutations (`updateProjectLastUpdated`). [V]
- WebSocket `GET /api/v1/ws` (also `/api/v2/ws`): client sends `{"action":"auth","token":"<jwt or api token>"}`, then `{"action":"subscribe","event":"<name>"}`; server pushes `{"event": ..., "data": ...}`. Pushed events are only `notification.created`, `timer.created/updated/deleted`, and session revocation — **no task change events**. [V] `pkg/websocket/messages.go`, `listener.go`
- Atom feed `/feeds/notifications.atom` (Basic auth with a feeds-scoped API token). [V] `routes.go`
- Webhooks can push task events to a server but not to a phone directly.

---

## 8. Reminders / notifications server side
- The server sends reminder **emails** (if `email_reminders_enabled`) and stores `task.reminder` DB notifications; there is no push to mobile devices. The app must schedule local notifications itself from `reminders[].reminder` and `due_date`. [V] `pkg/models/task_reminder.go`, `notifications.go`

---

## 9. Feature flags that remove routes (check `/info` before showing UI)
`service.enablelinksharing` (shares + share auth), `service.enabletaskattachments`, `service.enabletaskcomments`, `service.enabletotp`, `service.enableuserdeletion`, `service.enableregistration`, `auth.local.enabled` (register/password reset/confirm/login), `auth.ldap.enabled`, `auth.openid.enabled`, `webhooks.enabled`, `backgrounds.enabled` (+ `upload`/`unsplash`), `migration.*.enable`, `service.enablecaldav`, `plugins.enabled`, `ratelimit.enabled`. Disabled routes → Echo 404. [V] `pkg/routes/routes.go`

---

## 10. Permissions model
`Can*` methods per model (`*_permissions.go`). Project permission levels 0/1/2 via direct user share, team share, link share, or ownership; inherited by child projects [I from `project_access.go` naming]. Task permissions = project permissions. Labels: update/delete only by creator; read if on any readable task. [V] `label.go` annotations.

---

## 11. Swagger vs. reality (v1) [V by comparing `pkg/swagger/swagger.yaml` paths with `pkg/routes/routes.go`]
| Swagger | Actual |
|---|---|
| `PUT /labels/{id}` (update) | `POST /labels/{id}` |
| `GET /{username}/avatar` | `GET /avatar/{username}` (auth required) |
| `GET /backgrounds/unsplash/image/{image}[/thumb]` | `/backgrounds/unsplash/images/{image}[/thumb]` |
| `/projects/{projectID}/users/{userID}` | path segment is the **username** |
| `/teams/{id}/members/{userID}/admin` | path segment is the **username** |
| missing | `GET /projects/{project}/tasks`, `GET/DELETE /user/sessions[/{session}]`, `/user/bots*`, `GET|POST /token/test`, `GET /ws` |
| `per_page` "per bucket" note only on webhooks | per-bucket paging applies to kanban task collections |
| Task `bucket_id` "can be used to move" | ignored on update |
| swagger `version` | set at build from git (`pkg/version`), `dev` in source |

---

## 12. Not available in v1 (v2-only) [V] `pkg/routes/api/v2/*.go` file list + absence in `routes.go`
Time tracking (`time_entries.go`), bulk task create (`task_bulk_create.go`, `/projects/{project}/tasks/bulk`), invite links, admin teams/invite links, Planka migration, MCP, Huma OpenAPI docs, `/api/v2/health`. Everything else in v1 has a v2 counterpart.

---

## 13. Recommendations for the Flutter client (all [I])
1. Auth: prefer the OAuth2 PKCE flow (§2.3) with `redirect_uri=vikunja-<app>://callback`; it supports local, LDAP, OIDC and TOTP through the web UI and yields an access+refresh token pair usable on v1 **and** v2. Fallback: `POST /login` + capture `Set-Cookie: vikunja_refresh_token` and refresh via `POST /oauth/token` (no cookie jar needed). Also offer API-token login (`tk_...`), never refresh those.
2. Refresh on `401 && code == 11` once (single-flight), proactively before `exp` (decode JWT `exp`; 10-min default). Treat 16002/16003 as logged out; 16004 = retry with the newer stored token.
3. Store tokens in Keychain/Keystore (`flutter_secure_storage`).
4. Writes: model tasks as full objects; for v1 always POST the full round-tripped object (assignees + reminders included). Use dedicated endpoints for labels, bucket moves, positions.
5. Dates: parse with offset, map year ≤ 1 → null, send `0001-01-01T00:00:00Z` to clear.
6. Lists: omit `per_page` and drive paging from `x-pagination-total-pages`; use `/info.max_items_per_page`.
7. Widget/"Today"/"Upcoming": `GET /tasks?filter=done = false && due_date < now/d+1d&filter_timezone=<tz>&sort_by=due_date&sort_by=id&order_by=asc` (+ `filter_include_nulls=false`).
8. Deletions: reconcile IDs periodically (no deleted feed in v1).
9. Authenticated images (avatars, attachments/previews `preview_size=md`, project backgrounds, unsplash proxy) need the `Authorization` header in the image loader.
10. Gate UI on `/info` flags; handle `concurrent_writes=false` by serializing outbox writes.
