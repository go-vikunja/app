# Vikunja `/api/v2` (Huma): surface, conventions, v1 comparison, version detection

Research area: **api-v2** for the Flutter mobile client.
Source: shallow clone of `main` (latest tag v2.7.0, 2026-10-02). All paths are relative to the repo root.

Legend:
- **[V]** means I verified it in source. The citation is the file (and line where it helps).
- **[I]** means I inferred it (from library defaults, naming, CHANGELOG absence, etc.). Confirm it against a live server before you rely on it.

---

## 0. Key takeaways for the mobile client

1. **v2 first shipped in v2.4.0 (2026-07-19).** [V] `CHANGELOG.md` §2.4.0 lines ~1498–2086: "Scaffold /api/v2 Echo group", "Add task CRUD on /api/v2", … No `api/v2` entries exist before 2.4.0.
   - Some features came later: bulk create 2.5.0, Planka and pending-email in 2.6.0, MCP, invite links and the by-index 307 in 2.7.0. See §11.
2. **v1 is frozen but still served.** [V] `.agents/docs/api.md` "Version policy". All new routes go to v2 only.
   - Both versions run on the same server and use the same models (`pkg/models`). JSON field names are identical; the HTTP conventions differ.
3. **Version detection.** `GET {root}/api/v2/info`: a 200 response whose JSON has a string `version` means v2 is supported. Otherwise fall back to `GET {root}/api/v1/info`.
   - Both endpoints return the **same** `VikunjaInfos` body. [V] `pkg/routes/api/v1/info.go:35` and `pkg/routes/api/v2/info.go:50` both call `shared.BuildInfo()`.
   - v2 adds a `$schema` key.
4. **The OpenAPI spec is served live, not committed.** [V]
   - Live endpoints:
     - `GET /api/v2/openapi.json` (OpenAPI 3.1)
     - `/api/v2/openapi.yaml`
     - `/api/v2/openapi-3.0.json` and `/api/v2/openapi-3.0.yaml` (3.0 downgrade)
     - `/api/v2/schemas/{Name}.json`
     - Scalar UI at `/api/v2/docs`
   - All of these are public. [V] `pkg/routes/routes.go:330-337`.
   - **No static v2 spec exists in the repo.** `pkg/swagger/swagger.{json,yaml}` is the **v1** Swagger 2.0 doc.
   - The closest committed artifact is the generated TypeScript client in `frontend/src/client/generated/{sdk.gen.ts,types.gen.ts}` (216 operations), which is built from the canonical spec (`apiv2.NewCanonicalAPI`, `magefile.go:1523`).
   - Dart generators should consume `openapi-3.0.json`.
5. **Lists use a body envelope, not headers.** v2 returns `{items,total,page,per_page,total_pages}`. [V] `pkg/routes/api/v2/types.go`. v1 returns a bare array plus `x-pagination-total-pages` / `x-pagination-result-count` headers.
6. **Errors follow RFC 9457 `application/problem+json`.** [V] `pkg/routes/api/v2/errors.go`.
   - Fields: `type,title,status,detail,instance,errors[{location,message,value}]`, plus Vikunja's numeric `code` and `i18n_params`.
   - Validation failures return **422** (v1 returns 412).
   - **Exception:** errors raised by Echo middleware before Huma runs (invalid JWT returns 401 `{code:11,message}`; rate limit returns 429) keep the **v1 shape** `{code,message}`. [V] `pkg/routes/api_tokens.go:56-64`, `frontend/src/client/problem.ts`.
7. **Verbs are inverted compared to v1.** v2 uses `POST` to create (201) and `PUT` to replace (200). [V] `pkg/routes/api/v2/huma.go:146-162`, `.agents/docs/api.md`.
   - **`PATCH` is synthesized automatically** (Huma AutoPatch) for every GET+PUT pair.
   - Accepted content types: `application/merge-patch+json` (or `application/json`), `application/json-patch+json`, `application/merge-patch+shorthand`.
   - A no-op patch returns **304** with an empty body. [V] `frontend/src/client/queries/account.ts:220-228`. Huma `autopatch.go` v2.39.1 was checked upstream.
   - Only 11 PATCH ops exist (§5.2).
8. **Reads of single entities return an `ETag`.** The ETag is `"<updatedUnixNano>-<permission>"`. Sending `If-None-Match` gets a **304**. [V] `types.go:conditionalReadResponse`.
   - Single reads also carry `max_permission` in the **body** (v1 sends it as the `x-max-permission` header).
   - `GET /projects/{id}` deliberately has **no** ETag. [V] `projects.go` description.
9. **Rich text.** Stored as HTML (TipTap).
   - v2 can exchange GFM Markdown via `?format=markdown` (GET/POST/PUT) or the `X-Vikunja-Format: markdown` header (required for PATCH). [V] `pkg/routes/api/v2/richtext.go`.
   - This applies to task/project/label/team/saved-filter descriptions and task comments.
   - Markdown writes are lossy, and a markdown PUT/PATCH round-trips **the whole description**. Do not edit with markdown unless the user actually changed the text.
10. **Auth caveat for native apps.** v2 `POST /login` and `POST /user/token/refresh` deliver the refresh token **only as an HttpOnly cookie** `vikunja_refresh_token`, path-scoped to `/api/v1/user/token/refresh` and `/api/v2/user/token/refresh`. [V] `pkg/routes/api/v2/auth_login.go`, `pkg/modules/auth/auth.go:57-99`.
    - A Flutter app must either keep a cookie jar, or use the **OAuth 2.0 Authorization Code + PKCE** flow, whose `POST /api/v2/oauth/token` returns `refresh_token` in the JSON body (redirect URI scheme `vikunja-*` or loopback; since 2.3.0, v2 since 2.4.0). See §7.
11. **Realtime.** `GET /api/v2/ws` (WebSocket) only pushes `notification.created` and `timer.created|updated|deleted`. **There are no task-change events.** [V] `pkg/websocket/connection.go:337-342`.
    - Background sync of web-created tasks therefore needs polling.
    - REST also exposes no tombstones. Soft-deleted tasks (`deleted_at`) are only surfaced to CalDAV sync. [V] `pkg/models/tasks.go:147,2287-2300`.

---

## 1. How v2 is mounted

**Stack** [V]
- Huma v2.39.1 (`go.mod:40`) is mounted on the Echo v5 group `/api/v2` via upstream `humaecho` and Vikunja glue in `pkg/modules/humabridge/humabridge.go`.
- `GroupPrefix = "/api/v2"` (`huma.go:69`).
- `NewAPI` (`huma.go:73-139`):
  - `huma.DefaultConfig("Vikunja API", version.Version)`
  - `OpenAPIPath="/openapi"`
  - `DocsPath=""`, because Huma's own unpkg docs are disabled and Scalar is served locally.
  - `FieldsOptionalByDefault=true`
  - an extra request format `application/x-www-form-urlencoded`, used only by the OAuth token endpoint.

**Security schemes** (global; public ops opt out with `Security: []`) [V] `huma.go:95-123`:
- `JWTKeyAuth`: http bearer JWT, the user session JWT.
- `APITokenAuth`: http bearer, `tk_…` API tokens with scoped permissions.
- `BasicAuth`: used only by `GET /notifications.atom`. The username is the token owner and the password is a feeds-scoped `tk_` token.

**`servers[]`** [V] `huma.go:133-137`:
- `[{url:"/api/v2"}]`, plus `{url: <service.publicurl>/api/v2}` when `publicurl` is set.
- The relative entry must stay at index 0.
- The canonical spec has only the relative one (`canonical.go`).

**Middleware on the group, in order** [V] `pkg/routes/routes.go:467-500`:
1. `Cache-Control: no-store` on every response.
2. JWT / API-token middleware. Paths in `unauthenticatedAPIPaths` are skipped.
3. Refresh rate limit on `/user/token/refresh` and `/oauth/token`.
4. Unauthenticated rate limit on credential paths.
5. General rate limit and metrics.
6. Admin gate: `/api/v2/admin*` needs license feature `admin_panel` plus instance admin, and `user_invites` for invite links and admin teams. A failed gate returns **404**.

Other notes:
- `GET /api/v2/ws` is a raw Echo route outside the spec.
- MCP is at `/api/v2/mcp` (since 2.7.0).
- `RegisterAll` (`registry.go:40-47`) runs every `init()` registrar, then `EnableAutoPatch`, `requireMultipartBodies` and `stripPatchFormatQuery`.

**Public (no JWT) v2 paths** [V] `routes.go:330-364`:
- `openapi.json|yaml`, `openapi-3.0.json|yaml`, `docs`, `docs/scalar.standalone.js`, `schemas/:schema`, `info`
- `register`, `invite-links/check`, `user/password/token`, `user/password/reset`, `user/confirm`
- `shares/:share/auth`, `oauth/token`, `login`, `user/token/refresh`, `auth/openid/:provider/callback`
- `test/all`, `test/:table` (only mounted when a testing token is set)
- `health`, `notifications.atom` (Basic auth), `ws` (authenticates via its first message)

**Feature gates.** These gates are checked at route registration, so a disabled feature means the route does not exist (404) and is missing from the live spec. [V]

| Gate | Routes affected |
|---|---|
| local or LDAP auth enabled | login |
| local auth | register, password reset, confirm, invite-links check |
| `service.enableregistration` | `/register` returns 404 unless an `invite_token` is given |
| OpenID | `/auth/openid/{provider}/callback` |
| link sharing | `/shares/{share}/auth`, `/projects/{project}/shares*` |
| task attachments | `/tasks/{task}/attachments*` |
| task comments | `/tasks/{task}/comments*` |
| webhooks | project webhooks, user webhooks, `/webhooks/events` |
| TOTP | `/user/settings/totp*` |
| backgrounds | `backgrounds*` (upload and unsplash have separate sub-flags) |
| todoist / trello / microsoft-todo | the matching OAuth migrators |

Sources: `auth_login.go:63`, `auth_public.go:67-71,147`, `auth_openid.go:39`, `link_sharing.go:44`, `task_attachments.go:56`, `task_comments.go:42`, `webhooks.go:43`, `user_webhooks.go:48`, `webhook_events.go:36`, `user_totp.go:64`, `backgrounds.go:44,81,94`, `migration_oauth.go:50-52`, `invite_links.go:42`.

**License gates at runtime** (return 404 when off) [V]:
- Time tracking (`time_tracking` feature): `time_entries.go:36-49`, `timeTrackingGate`.
- Admin (`admin_panel`, `user_invites`): `routes.go:452-462`.

**Client implication.** Use `/info` flags (§9) to hide UI. Treat a 404 on a gated route as "feature unavailable".

---

## 2. OpenAPI spec and code generation

**Served endpoints** [V]
- `/api/v2/openapi.json`, `.yaml`, `-3.0.json`, `-3.0.yaml` and `/api/v2/schemas/:schema` are whitelisted in `routes.go:330-336`. They are produced by Huma's `OpenAPIPath="/openapi"` (`huma.go:75`).
- Tests fetch `/api/v2/openapi.json` (`pkg/webtests/huma_task_test.go:358`, `huma_richtext_test.go:53`).
- Scalar UI: `GET /api/v2/docs`, which loads `data-url="/api/v2/openapi.json"` (`pkg/routes/api/v2/scalar/scalar.html`).
  - The URL is absolute, so the UI breaks under a sub-path deployment; the spec itself is fine. [I]
- `info.description` holds the rich-text Markdown explanation (`huma.go:92-94`, `richtext.go:39-48`).
- **v1 for comparison:** `GET /api/v1/docs.json` (Swagger 2.0, swaggo) and `/api/v1/docs` (Redoc) [V] `routes.go:516-519`. Static copies are in `pkg/swagger/swagger.json|yaml` (v1 only).

**The live spec depends on instance config.** Gated routes are absent; see §1.

**Canonical spec** [V] `pkg/routes/api/v2/canonical.go`:
- `NewCanonicalAPI()` enables every optional feature (local + OIDC, registration, link sharing, TOTP, attachments, comments, webhooks, backgrounds + upload + unsplash, todoist/trello/msft migrators).
- It blanks the testing token and public URL, and registers `mcp-info`.
- The result is used by `mage generate:frontend-client` (`magefile.go:1523-1545`): the spec goes to a temp file, then through `@hey-api/openapi-ts` (`frontend/openapi-ts.config.ts`).
- **Recommendation:** generate the Dart client from a canonical-equivalent spec. Either fetch `/openapi-3.0.json` from a fully-featured dev server, or write a tiny Go program calling `apiv2.NewCanonicalAPI()` (you must not run scripts in the reference repo; do it in your own checkout).
- Every response object has an optional read-only `$schema` string. Ignore it.

**Schema conventions that matter for codegen** [V] `.agents/skills/api-v2-routes/SKILL.md`, `validation.go`:
- Server-controlled fields are `readOnly: true`. Generators may produce separate "Writable" types (the TS client has e.g. `TaskReadOneBodyWritable`).
- `FieldsOptionalByDefault=true`: nearly every property is optional in the schema. Real required/format rules come from govalidator `valid:` tags, enforced in the `Register` wrapper **before** the permission check (`huma.go:155-161`). Failures return 422 with `errors[].location = "body.<field>"`.
- Unknown JSON properties are probably rejected. [I] Huma's registry default is `AllowAdditionalPropertiesByDefault: false` (checked upstream in `registry.go` v2.39.1), and Vikunja does not override it.
  - Expect 422 for fields not in the schema.
  - readOnly fields are accepted and ignored, so a GET body can be round-tripped into a PUT (`validation.go:63-64`, SKILL.md).
- **PUT bodies are the read shape.** For resources with `max_permission`, the PUT body type is the `XReadBody` (model + `max_permission`), so a GET→PUT round trip validates (SKILL.md; e.g. `labels.go:149-152`, `tasks.go:225-229`). Create takes the bare model.
- **URL wins over body** for ids and parents on create and update (e.g. `tasks.go:211`, `buckets`, `task_bucket.go:61-63`).

---

## 3. Cross-cutting conventions (v2)

### 3.1 Status codes [V] `huma.go:146-154`
- `Register` sets POST→**201** and DELETE→**204** unless `DefaultStatus` is set explicitly. GET/PUT return 200.
- Explicit 200 POSTs: login, logout, refresh, openid callback, link-share auth, password token/reset, confirm, oauth token/authorize, invite check, notifications mark-all, reactions delete, team-member toggle-admin, change password, resend email, TOTP enroll/enable/disable, export request/download, CSV detect/preview, migrate, token test/check, token renew, timer stop, admin password-reset-email.
- Explicit 204 POSTs: user-deletion request/confirm/cancel.
- DELETE with 200: `projects-background-delete` (returns the project), `user-cancel-email-update`, `testing-truncate-all`.
- PUT with explicit 200: avatar upload, background upload. `testing-replace-table` returns 201.

### 3.2 Pagination [V] `types.go:27-75`

Envelope:
```json
{"items":[...], "total": 123, "page": 1, "per_page": 50, "total_pages": 3}
```

- `items` is never null; it is an empty array when there are no results (`NewPaginated`).
- `total_pages = ceil(total/per_page)`.

Query parameters (`ListParams`):

| Param | Rule |
|---|---|
| `page` | default 1, minimum 1; `page=0` returns 422 |
| `per_page` | minimum 1; **no default in the schema**; `Resolve()` sets it to `service.maxitemsperpage` (default 50, `pkg/config/config.go:385`) when it is missing or larger. The cap is silent, so drive paging from the returned `per_page`/`total_pages`. |
| `q` | search |

Exceptions:
- `GET /projects/{p}/views/{v}/buckets/tasks` returns `{items: Bucket[], total: <#buckets>}` with no page fields. `per_page`/`page` still apply **per bucket**: each bucket's `tasks` are limited and `bucket.count` is the total in that bucket. [V] `task_collection.go:38-46`, `pkg/models/kanban.go:255-270`.
  - To load more of one bucket, call `GET /projects/{p}/views/{v}/tasks?filter=bucket_id = N&page=k&sort_by=position&order_by=asc`. [V] `frontend/src/client/queries/kanbanMutations.ts:105-114`.
  - The web app uses `expand=comment_count&expand=is_unread` on boards (`kanban.ts:6-9`).
- `GET /users` and `GET /projects/{p}/users/search` return everything as one page (`total=len`, `page=1`). [V] `user_search.go:84,119`
- `GET /backgrounds/unsplash/search` has only `q` and `page`; `total` is the page length. [V] `backgrounds.go:151-178`
- `/projects/{p}/views` and `/projects/{p}/views/{v}/buckets` are "not paginated by the server but in the envelope". [V] descriptions.
- `GET /{entitykind}/{id}/reactions` returns a bare map (`ReactionMap`, value → users).
- `GET /webhooks/events` and `/user/settings/webhooks/events` return a bare `string[]`.
- `GET /user/timezones` returns `string[]` (unsorted).
- `GET /routes` returns a map.

### 3.3 Single read + ETag + max_permission [V] `types.go:77-103`
- Read ops embed `conditional.Params`: `If-None-Match`, `If-Match`, `If-Modified-Since`, `If-Unmodified-Since`.
- The response sends `ETag: "<updated.UnixNano>-<maxPermission>"`.
- `If-None-Match` with the same ETag returns `304` with an empty body. A failing `If-Match` returns 412 (Huma conditional).
- Ops with ETag: labels-read, tasks-read, tasks-read-by-index, task-comments-read, project-views-read, filters-read, teams-read, shares-read, bots-read, time-entries-read. [V] each `*_read` handler calls `conditionalReadResponse`.
- `projects-read` has no ETag: it is served fresh because it carries per-user state (`projects.go:46`; CHANGELOG 2.4.0 "Drop ETag/conditional read on project get").
- `max_permission` (0=read, 1=read/write, 2=admin) is a body field on these reads.
  - `GET /projects?expand=permissions` adds `max_permission` per project; otherwise it is omitted or null.
- The body also has `$schema`. Huma also emits `Link: </api/v2/schemas/X.json>; rel="describedBy"`. [V] `schema_link_test.go` comment; [I] exact header format.

### 3.4 PATCH (AutoPatch) [V] `registry.go:40-47`, `huma.go:164-182`; Huma upstream `autopatch/autopatch.go` v2.39.1
- PATCH is synthesized for every path with GET+PUT. It does an internal GET, applies the patch, then an internal PUT.
- **Accepted Content-Type:**
  - `application/merge-patch+json` (also plain `application/json` or empty), RFC 7396
  - `application/json-patch+json`, RFC 6902 `[{"op":"replace","path":"/title","value":"x"}]` (used in `pkg/webtests/huma_task_patch_subscription_test.go`)
  - `application/merge-patch+shorthand`
  - Anything else returns 415.
- **No-op returns 304 Not Modified** with an empty body. [V] Upstream `jsonpatch.Equal(patched, original)`; relied on by `frontend/src/client/queries/account.ts:227`.
- The response is the PUT's status and body (200 + entity).
- Query parameters are **not** forwarded to the internal GET/PUT. Headers are, except Accept, conditionals and content headers on the GET. This is why rich-text Markdown on PATCH must use the `X-Vikunja-Format` header. [V] `richtext.go:20-33,55-72`.
- Conditional headers:
  - Autopatch sets `If-Match: <GET ETag>` on the internal PUT when the client sent no conditional headers.
  - Vikunja's PUT handlers do not declare `conditional.Params`, so **no lost-update protection actually happens**. [I] (PUT input structs in e.g. `labels.go:150-154`, `tasks.go:225-229` have no conditional params.)
- Merge-patch on objects merges key by key. For example `frontend_settings` in user settings merges per key (`user_settings.go:125` description).
- API-token permissions: PATCH is accepted under the stored PUT ("update") permission. [V] SKILL.md; `pkg/models/api_routes.go`.

### 3.5 Error model [V] `errors.go`
- Content-Type `application/problem+json`, body `vikunjaErrorModel`:
```json
{"$schema":"…","type":"about:blank?","title":"Not Found","status":404,"detail":"The task does not exist.",
 "instance":"…","errors":[{"location":"body.title","message":"…","value":…}],
 "code":4002,"i18n_params":{"…":"…"}}
```
- `code` is the Vikunja numeric error code (same catalogue as v1, https://vikunja.io/docs/errors/). It comes from `web.HTTPErrorProcessor` (`errors.go:47-67`).
- `title = http.StatusText(status)`. `type` and `instance` are Huma defaults [I].
- Validation (govalidator) returns **422** with `code` set and `errors[].location="body.<field>"`. Model-side `ValidationHTTPError` is also mapped to 422 (`errors.go:68-78`). v1 used 412 for these.
- All 5xx errors have `errors[]` stripped and are logged server-side (`errors.go:126-145`).
- A missing or failed auth context inside a handler returns `401 "invalid or missing authentication"` (`errors.go:33-45`).
- **Non-problem bodies on v2** [V]:
  - The JWT middleware returns `401 {"code":11,"message":"missing, malformed, expired or otherwise invalid token provided"}` (`pkg/routes/api_tokens.go:38,56-64`). **Code 11 is the "refresh and retry" trigger** (`frontend/src/client/http.ts:108-136`).
  - An API token without permission for the route gets a plain Echo 401.
  - Rate limits return 429 with `Retry-After` (exposed via CORS, `routes.go:283`).
  - Normalize these like `frontend/src/client/problem.ts` does: use `status` from HTTP and `detail ?? message`.

### 3.6 Rich text [V] `pkg/routes/api/v2/richtext.go`, `pkg/richtext/*`, `pkg/webtests/huma_richtext_test.go`
- **Storage:** HTML (TipTap) for task `description`, project `description`, label `description`, team `description`, saved filter `description`, and task comment `comment`.
- **Default (no param):** v2 reads and writes HTML verbatim. A markdown string sent without the param is stored **unconverted** (test "default write stores body verbatim").
- **Markdown mode:** request with `?format=markdown`, or header `X-Vikunja-Format: markdown`. The header is required for PATCH, where `stripPatchFormatQuery` removes the query param from PATCH ops.
  - Read: HTML→GFM (`richtext.HTMLToMarkdown`). Mentions `<mention-user data-id="user">` become `@user`. TipTap task lists become `- [ ]` / `- [x]`.
  - Converted fields: list, read and the write echo. This includes nested tasks in buckets, expanded comments, and related-task descriptions (`convertTasksToMarkdown`).
  - Write: GFM→HTML (goldmark GFM, `pkg/richtext/markdowntohtml.go`). `@username` matching an existing user becomes `<mention-user data-id="username" data-label="Name">`. Unknown mentions stay as text.
- **Lossy.** Markdown cannot express e.g. underline. PUT/PATCH round-trip the whole resource, so in markdown mode an untouched description is still re-converted. There is no change detection in the REST path; `richtext.Changed` is used only by CalDAV (`pkg/routes/caldav/listStorageProvider.go:659`).
- **Mobile recommendation:**
  - Read with `format=markdown` for display, or render HTML.
  - Write with `format=html` (or omit the header) unless the description or comment was edited. When it was edited, send markdown with the header or param.
  - CalDAV always exchanges Markdown.
- `?format` enum is `html|markdown` on list/read/create/update ops of those resources (`huma_richtext_test.go:84-97`).

### 3.7 Expand [V] `tasks.go:33-52`, `pkg/models/task_collection.go:76-82`
- **Tasks:** `expand` is repeatable (`?expand=a&expand=b`; `expand[]=` is also normalized by `NormalizeArrayParams`, `routes.go:191-193`).
  - Values: `subtasks`, `buckets`, `reactions`, `comments`, `comment_count`, `time_entries_count`, `is_unread`.
  - An invalid value returns 422.
  - `subtasks` can return more tasks than `per_page`.
  - Applies to `tasks-read`, `tasks-read-by-index` and all task lists.
- **Projects:** `expand=permissions` only (`projects.go:91`).
- `is_unread`, `comment_count`, `time_entries_count`, `reactions`, `comments`, `buckets` are read-only Task fields that are only filled when expanded.

### 3.8 Project identifier, by-index, 307 [V] `tasks.go:54-80,151-237`
- `GET /projects/{project}/tasks/by-index/{index}`: `{project}` is a numeric id or a textual identifier (case-insensitive, stored uppercase). An all-digit value is always an id. An unknown identifier returns 404.
- If the index is historical (the task moved projects), the response is **307** with `Location: /api/v2/projects/{newProjectId}/tasks/by-index/{newIndex}?<original query>` and `Cache-Control: no-store`.
  - Readability is checked first, so the response is 403 vs 307 rather than leaking existence.
  - Added in 2.7.0 (CHANGELOG line 427 "Redirect historical task indexes on v2").
- Pseudo projects: `-1` is Favorites; other negative ids are saved filters. They exist only in the project list and `projects-read` (`.agents/docs/api.md` Query cache rules; `projects.go:46`).

### 3.9 "canonical.go"
- `canonical.go` is **not** about canonical resource URLs. It builds the canonical (all-features) OpenAPI document used for client generation (§2). [V]
- Resource URLs follow kebab-case paths with snake_case JSON (`.agents/docs/api.md`).
- The only redirect-style canonicalization is the by-index 307 (§3.8).

---

## 4. Auth-related v2 behaviour (summary; see the auth research doc for depth)

**Login** — `POST /api/v2/login` [V] `auth_login.go`, `pkg/user/user.go:53-59`
- Body: `{username,password,totp_passcode,long_token}`.
- Response: `200 {token}` with `Cache-Control: no-store`, plus `Set-Cookie: vikunja_refresh_token=…; Path=<base>/api/v1/user/token/refresh` and a second cookie with `Path=<base>/api/v2/user/token/refresh`. Both are `HttpOnly; SameSite=Lax; Secure` when the publicurl is https; `Max-Age` is jwtttl (72h) or jwtttllong (30d).
- JWT TTL is `service.jwtttlshort` (default 600 s) (`pkg/config/config.go:376-378`).
- JWT claims: `type,id,username,is_admin,iat,exp,sid,jti` (`pkg/modules/auth/auth.go:178-200`).

**Refresh** — `POST /api/v2/user/token/refresh` [V] `auth_refresh.go`
- Reads only the cookie (no body) and rotates it.
- Errors: missing cookie returns `ErrNoRefreshToken`; an unusable token also clears the cookie.

**Logout** — `POST /api/v2/logout` returns `{message, oidc_logout_url?}`.

**OAuth 2.0 (native-app friendly)** [V] `pkg/routes/api/v2/oauth.go`, `pkg/modules/auth/oauth2server/*`, `frontend/src/views/user/OAuthAuthorize.vue`
- Open `{frontend_url}/oauth/authorize?response_type=code&client_id=<any>&redirect_uri=vikunja-<x>://cb&state=…&code_challenge=<S256>&code_challenge_method=S256` in the system browser.
  - The web app (logged-in user) calls `POST /api/v2/oauth/authorize` and redirects to `redirect_uri?code=…&state=…`.
  - `redirect_uri` must use a `vikunja-*` scheme, or `http` on localhost or a loopback IP (`client.go`).
  - PKCE S256 is mandatory.
  - `client_id` is free-form (no registration); it must match at exchange.
  - API tokens are rejected at authorize (403).
- `POST /api/v2/oauth/token` (form-urlencoded or JSON):
  - `grant_type=authorization_code&code&client_id&redirect_uri&code_verifier`, or `grant_type=refresh_token&refresh_token`.
  - Returns `{access_token, token_type:"bearer", expires_in, refresh_token}`. Refresh tokens rotate (`token.go:181-193`).
- Available since 2.3.0 on v1 (`/api/v1/oauth/token`, `/api/v1/oauth/authorize`), and on v2 since 2.4.0.

**Other auth endpoints**
- `POST /api/v2/auth/openid/{provider}/callback` with `{code, redirect_url, scope?, totp_passcode?}`. Returns 412 when TOTP is required, then retry with `totp_passcode` (`auth_openid.go:46`).
- `POST /api/v2/shares/{share}/auth` with `{password?}` returns `{token, …LinkSharing fields, project_id}`.
- `POST /api/v2/user/token` renews a **link-share** JWT only; user tokens get 400 (`token_meta.go:93-127`).
- `GET|POST /api/v2/token/test` returns 200 when the bearer is valid (JWT or API token) (`token_meta.go:61-80`; API tokens allowed since 2.6.0, CHANGELOG line 885).

**API tokens**
- Same permission keys apply to v1 and v2 (`pkg/models/api_routes.go:31-80,120-160`).
- `GET /api/v2/routes` lists v1 and v2 groups, including v2-only groups like `time_entries` and `mcp`.

---

## 5. Complete v2 operation inventory

All operations are extracted from `pkg/routes/api/v2/*.go` `huma.Operation{…}` literals; 196 registrations, with migrators templated. The canonical spec has **216** operations, including the 11 AutoPatch PATCH ops (`frontend/src/client/generated/sdk.gen.ts`).

Column notes:
- "Req": request body or important query params. "Resp": 2xx body.
- `P<T>` means `Paginated<T>` (§3.2); `T+mp` means T plus `max_permission`; `ETag` marks conditional reads.
- Default statuses per §3.1.

### 5.1 Core task-management resources

| opId | Method | Path | Req | Resp | Notes (file) |
|---|---|---|---|---|---|
| projects-list | GET | /projects | `page,per_page,q,expand=permissions,is_archived,format` | P<Project> | owned+shared+children; archived excluded unless `is_archived=true` (projects.go) |
| projects-read | GET | /projects/{id} | `format` | Project (with views, subscription, max_permission) | no ETag; resolves -1 Favorites / filter pseudo-projects |
| projects-create | POST | /projects | Project | Project | creates default views + backlog bucket |
| projects-update | PUT (+PATCH) | /projects/{id} | Project (read shape) | Project | admin needed to reparent/delete |
| projects-delete | DELETE | /projects/{id} | – | 204 | cascades |
| projects-duplicate | POST | /projects/{projectid}/duplicate | `{parent_project_id?, duplicate_shares?}` | `{duplicated_project}` | project_duplicate.go |
| project-views-list | GET | /projects/{project}/views | ListParams | P<ProjectView> | project_views.go |
| project-views-read | GET | /projects/{project}/views/{view} | cond. | ProjectView+mp, ETag | |
| project-views-create | POST | /projects/{project}/views | ProjectView | ProjectView | project admin |
| project-views-update | PUT (+PATCH) | /projects/{project}/views/{view} | ProjectView+mp | ProjectView | |
| project-views-delete | DELETE | /projects/{project}/views/{view} | – | 204 | |
| buckets-list | GET | /projects/{project}/views/{view}/buckets | ListParams | P<Bucket> | buckets.go |
| buckets-create | POST | …/buckets | Bucket | Bucket | write access |
| buckets-update | PUT | …/buckets/{bucket} | Bucket (title, limit, position) | Bucket | no PATCH (no single GET) |
| buckets-delete | DELETE | …/buckets/{bucket} | – | 204 | tasks go to default bucket; last bucket returns 412 |
| task-bucket-update | PUT | /projects/{project}/views/{view}/buckets/{bucket}/tasks | TaskBucket `{task_id}` | TaskBucket `{task_id,bucket_id,project_view_id,task?,bucket?}` | done-bucket marks done; repeating task reopens; bucket limit returns 412 (task_bucket.go) |
| tasks-list | GET | /tasks | TaskListQueryParams (§6) | P<Task> | all projects, flat (task_collection.go) |
| project-tasks-list | GET | /projects/{project}/tasks | same | P<Task> | |
| project-view-tasks-list | GET | /projects/{project}/views/{view}/tasks | same | P<Task> | view filter/sort applied; always flat |
| project-view-buckets-tasks-list | GET | /projects/{project}/views/{view}/buckets/tasks | same | `{items:Bucket[] (with tasks,count), total}` | 400 if the view has no buckets |
| tasks-read | GET | /tasks/{task} | `expand[],format`, cond. | Task+mp, ETag | tasks.go |
| tasks-read-by-index | GET | /projects/{project}/tasks/by-index/{index} | same | Task+mp, ETag; or 307 | §3.8 |
| tasks-create | POST | /projects/{project}/tasks | Task, `format` | Task | |
| tasks-update | PUT (+PATCH) | /tasks/{task} | Task+mp, `format` | Task | changing `project_id` moves the task |
| tasks-delete | DELETE | /tasks/{task} | – | 204 | soft delete (deleted_at) [V models/tasks.go:147] |
| tasks-bulk-create | POST | /projects/{project}/tasks/bulk | `{tasks: Task[]}` (≤100, atomic) | BulkTaskCreation | since 2.5.0 (task_bulk_create.go) |
| tasks-bulk-update | PUT | /tasks/bulk | `{task_ids:[], fields:[], values: Task}` | BulkTask `{…, tasks}` | all-or-nothing (bulk_task.go) |
| tasks-duplicate | POST | /tasks/{task}/duplicate | – | `{duplicated_task}` | adds a copiedfrom relation |
| tasks-position-update | PUT | /tasks/{task}/position | `{project_view_id, position}` | TaskPosition | the server may recalc positions |
| tasks-relations-create | POST | /tasks/{task}/relations | `{other_task_id, relation_kind}` | TaskRelation | inverse auto-created; cycles rejected |
| tasks-relations-delete | DELETE | /tasks/{task}/relations/{relationKind}/{otherTask} | – | 204 | kinds: subtask, parenttask, related, duplicateof, duplicates, blocking, blocked, precedes, follows, copiedfrom, copiedto |
| tasks-mark-read | PUT | /tasks/{task}/read | – | `{message}` | idempotent (task_unread_status.go) |
| task-assignees-list | GET | /tasks/{task}/assignees | ListParams | P<User> | |
| task-assignees-create | POST | /tasks/{task}/assignees | `{user_id}` | TaskAssginee (sic) | |
| task-assignees-delete | DELETE | /tasks/{task}/assignees/{user} | – | 204 | `{user}` = user id |
| task-assignees-bulk | PUT | /tasks/{task}/assignees/bulk | `{assignees: User[]}` | BulkAssignees | replaces the set |
| task-labels-list | GET | /tasks/{task}/labels | ListParams | P<Label> | |
| task-labels-create | POST | /tasks/{task}/labels | `{label_id}` | LabelTask | |
| task-labels-delete | DELETE | /tasks/{task}/labels/{label} | – | 204 | |
| task-labels-bulk-replace | PUT | /tasks/{task}/labels/bulk | `{labels: Label[]}` | LabelTaskBulk | |
| task-comments-list | GET | /tasks/{task}/comments | ListParams, `order_by=asc|desc`, `format` | P<TaskComment> | gated by task comments |
| task-comments-read | GET | /tasks/{task}/comments/{commentid} | cond. | TaskComment+mp, ETag | |
| task-comments-create | POST | /tasks/{task}/comments | `{comment}`, `format` | TaskComment | |
| task-comments-update | PUT (+PATCH) | /tasks/{task}/comments/{commentid} | TaskComment+mp | TaskComment | author only |
| task-comments-delete | DELETE | /tasks/{task}/comments/{commentid} | – | 204 | author only |
| task-attachments-list | GET | /tasks/{task}/attachments | ListParams | P<TaskAttachment> | gated (task_attachments.go) |
| task-attachments-upload | POST | /tasks/{task}/attachments | multipart `files` (repeat) | `{success: TaskAttachment[], errors: [...]}` | 201 even on partial failure |
| task-attachments-download | GET | /tasks/{task}/attachments/{attachment} | `preview_size=sm|md|lg|xl` (100/200/400/800 px PNG, images only) | binary, real Content-Type | needs Authorization header |
| task-attachments-delete | DELETE | /tasks/{task}/attachments/{attachment} | – | 204 | |
| reactions-list | GET | /{entitykind}/{entityid}/reactions | entitykind ∈ tasks, comments | map value→User[] | not paginated |
| reactions-create | POST | /{entitykind}/{entityid}/reactions | `{value}` | Reaction | |
| reactions-delete | POST | /{entitykind}/{entityid}/reactions/delete | `{value}` | 200, empty | POST because of body |
| subscriptions-create | POST | /subscriptions/{entity}/{entityID} | entity ∈ project, task | Subscription | |
| subscriptions-delete | DELETE | /subscriptions/{entity}/{entityID} | – | 204 | inherited sub becomes an opt-out |
| labels-list/read/create/update(+PATCH)/delete | GET/GET/POST/PUT/DELETE | /labels, /labels/{id} | `format` | P<Label> / Label+mp ETag / Label | labels.go (reference impl) |
| filters-read/create/update(+PATCH)/delete | GET/POST/PUT/DELETE | /filters/{filter}, /filters | SavedFilter `{title,description,filters:TaskCollection,is_favorite}` | SavedFilter(+mp, ETag) | no list op: filters appear as negative-id pseudo projects (saved_filters.go) |
| time-entries-list | GET | /time-entries | ListParams + `filter`, `filter_timezone` (fields user_id, task_id, project_id, start_time, end_time; `end_time = null` = running) | P<TimeEntry> | license `time_tracking` (time_entries.go) |
| time-entries-read | GET | /time-entries/{id} | cond. | TimeEntry+mp, ETag | |
| time-entries-create | POST | /time-entries | `{task_id XOR project_id, start_time, end_time?, comment}` | TimeEntry | `end_time` null = start timer |
| time-entries-update | PUT (+PATCH) | /time-entries/{id} | TimeEntry+mp | TimeEntry | author only |
| time-entries-delete | DELETE | /time-entries/{id} | – | 204 | |
| task-time-entries-list | GET | /tasks/{task_id}/time-entries | ListParams | P<TimeEntry> | empty list if inaccessible |
| project-time-entries-list | GET | /projects/{project_id}/time-entries | ListParams | P<TimeEntry> | |
| time-entries-timer-stop | POST | /time-entries/timer/stop | – | TimeEntry | 404 if no timer |

### 5.2 PATCH operations (AutoPatch)

These 11 operations are synthesized (`sdk.gen.ts`: `patch*`):
- `/filters/{filter}`
- `/labels/{id}`
- `/projects/{id}`
- `/projects/{project}/views/{view}`
- `/tasks/{task}`
- `/tasks/{task}/comments/{commentid}`
- `/teams/{id}`
- `/time-entries/{id}`
- `/user/bots/{bot}`
- `/user/settings/avatar/provider`
- `/user/settings/general`

Hand-registered PATCH operations exist only on admin routes (§5.4).

### 5.3 Sharing, teams, users, account

| opId | Method | Path | Req → Resp / notes |
|---|---|---|---|
| project-users-list/create/update/delete | GET/POST/PUT/DELETE | /projects/{project}/users[/{user}] | `{username, permission}`. `{user}` is the **username**. P<UserWithPermission>. Direct shares only. |
| project-teams-list/create/update/delete | GET/POST/PUT/DELETE | /projects/{project}/teams[/{team}] | `{team_id, permission}`. P<TeamWithPermission>. |
| shares-list/read/create/delete | GET/GET/POST/DELETE | /projects/{project}/shares[/{share}] | LinkSharing (hash generated server-side; password write-only). Project admin. |
| teams-list | GET | /teams | ListParams + `include_public`, `format` → P<Team> |
| teams-read/create/update(+PATCH)/delete | GET/POST/PUT/DELETE | /teams/{id}, /teams | Team (+mp 0 or 2, ETag) |
| teams-members-add / remove / toggle-admin | POST / DELETE / POST | /teams/{team}/members, …/{user}, …/{user}/admin | `{username}`; `{user}` = username; toggle returns 200 |
| users-search | GET | /users?q= | all results in one page; emails never returned |
| projects-users-search | GET | /projects/{project}/users/search?q= | users with access (owner/share/team) |
| user-show | GET | /user | User + `settings`, `deletion_scheduled_at`, `is_local_user`, `auth_provider`, `is_admin`, `pending_email` (user_settings.go:37-45) |
| user-settings-read / user-update-settings(+PATCH) | GET / PUT | /user/settings/general | UserGeneralSettings: `name, email_reminders_enabled, discoverable_by_name, discoverable_by_email, overdue_tasks_reminders_enabled, overdue_tasks_reminders_time "HH:MM", default_project_id, week_start 0-6, language, timezone, frontend_settings(any), extra_settings_links(ro)`. PUT returns `{message}`. (pkg/models/user_settings.go:34-46) |
| user-change-password | POST | /user/password | `{old_password,new_password}`; invalidates all sessions |
| user-update-email / cancel / resend | PUT / DELETE / POST | /user/settings/email, /user/settings/email/resend | `{new_email,password}`; cancel and resend since 2.6.0 |
| user-get/set-avatar-provider(+PATCH) | GET/PUT | /user/settings/avatar/provider | `{avatar_provider}` ∈ gravatar, upload, initials, marble, ldap, openid, default |
| user-avatar-upload | PUT | /user/settings/avatar | multipart `avatar` (png/jpeg/gif/tiff/bmp) |
| avatar-get | GET | /avatar/{username}?size=250 | image bytes (auth required; not in public list) |
| user-timezones | GET | /user/timezones | string[] |
| totp-get/enroll/enable/disable/qrcode | GET/POST/POST/POST/GET | /user/settings/totp[/enroll\|/enable\|/disable\|/qrcode] | enable `{passcode}`, disable `{password}`, qrcode returns image/jpeg; gated |
| caldav-tokens-create/list/delete | POST/GET/DELETE | /user/settings/token/caldav[/{id}] | clear token shown once |
| sessions-list / sessions-delete | GET / DELETE | /user/sessions[/{session}] | P<Session `{id(uuid),device_info,ip_address,created,last_active…}`>; link shares forbidden |
| tokens-list/create/delete | GET/POST/DELETE | /tokens[/{id}] | `owner_id` query/body for bot tokens; cleartext once |
| bots-list/read/create/update(+PATCH)/delete | GET/GET/POST/PUT/DELETE | /user/bots[/{bot}] | username must start `bot-`; update requires `status` (0 active, 2 disabled) |
| user-webhooks-list/events/create/update/delete | … | /user/settings/webhooks[/events\|/{webhook}] | gated by webhooks |
| webhooks-list/create/update/delete | GET/POST/PUT/DELETE | /projects/{project}/webhooks[/{webhook}] | update only changes `events` |
| webhooks-events-list | GET | /webhooks/events | string[] |
| user-deletion-request/confirm/cancel | POST ×3 | /user/deletion/{request\|confirm\|cancel} | `{password}` / `{token}`; 204 |
| user-export-request / download / status | POST / POST / GET | /user/export/request, /user/export/download, /user/export | download streams a zip |
| notifications-list | GET | /notifications | ListParams → P<DatabaseNotification `{id,name,notification(any),read_at,created}`>, newest first |
| notifications-mark-read | PUT | /notifications/{notificationid} | `{read: bool}` |
| notifications-mark-all-read | POST | /notifications | → 200 `{message}` |
| notifications-delete-all | DELETE | /notifications | 204 |
| notifications-atom-feed | GET | /notifications.atom | HTTP Basic (owner + feeds-scoped `tk_`); Atom XML |
| projects-background-get/delete | GET/DELETE | /projects/{project}/background | GET returns image/jpeg (If-Modified-Since gives 304); DELETE returns Project |
| projects-background-upload | PUT | /projects/{project}/backgrounds/upload | multipart `background` → Project |
| backgrounds-unsplash-search / -image / -thumb / projects-background-unsplash-set | GET/GET/GET/PUT | /backgrounds/unsplash/search, /backgrounds/unsplash/images/{image}[/thumb], /projects/{project}/backgrounds/unsplash | proxied |

### 5.4 Public, service, admin, misc

| opId | Method | Path | Notes |
|---|---|---|---|
| info | GET | /info | public, §9 |
| health | GET | /health | public; `{status:"OK"\|"degraded", openid_providers?}`; 500 when unhealthy |
| auth-login / auth-logout / auth-refresh-token / auth-openid-callback | POST | /login, /logout, /user/token/refresh, /auth/openid/{provider}/callback | §4 |
| auth-register | POST | /register | User + `invite_token?` |
| auth-password-token / auth-password-reset / auth-confirm-email | POST | /user/password/token, /user/password/reset, /user/confirm | |
| auth-link-share | POST | /shares/{share}/auth | |
| invite-links-check | POST | /invite-links/check | `{token}` → `{name, teams, skip_email_confirm}`; since 2.7.0 |
| oauth-token / oauth-authorize | POST | /oauth/token, /oauth/authorize | §4 |
| token-test / token-check / token-routes / token-renew | GET / POST / GET / POST | /token/test, /token/test, /routes, /user/token | |
| mcp-info | GET | /mcp/info | user session only; 2.7.0 |
| migration-{todoist,trello,microsoft-todo}-{auth,status,migrate} | GET/GET/POST | /migration/{name}/… | config-gated |
| migration-{vikunja-file,ticktick,wekan,planka}-{status,migrate} | GET/POST | /migration/{name}/… | Planka is v2-only (2.6.0) |
| migration-csv-{status,detect,preview,migrate} | GET/POST×3 | /migration/csv/… | |
| admin-overview | GET | /admin/overview | admin_panel license + instance admin, else 404 |
| admin-users-list / create / delete | GET/POST/DELETE | /admin/users[/{id}] | delete `mode=now\|scheduled` |
| admin-users-patch-admin / patch-status / set-password | PATCH | /admin/users/{id}/admin, …/status, …/password | |
| admin-users-password-reset-email | POST | /admin/users/{id}/password-reset-email | 200 |
| admin-projects-list / patch-owner | GET / PATCH | /admin/projects, /admin/projects/{id}/owner | list filters `owner_id, exclude_default_projects, sort_by, order_by` |
| admin-teams-list | GET | /admin/teams | + `user_invites` license |
| admin-invite-links-list/create/delete | GET/POST/DELETE | /admin/invite-links[/{id}] | + `user_invites` license |
| testing-truncate-all / testing-replace-table | DELETE / PUT | /test/all, /test/{table} | only when a testing token is set |

---

## 6. Task list query parameters (`TaskListQueryParams`) [V] `pkg/routes/api/v2/task_collection.go:49-61`

| Param | Type | Notes |
|---|---|---|
| `page`, `per_page`, `q` | int, int, string | `q` = search |
| `filter` | string | Vikunja filter DSL, e.g. `done = false && due_date < now+7d`. See https://vikunja.io/docs/filters |
| `filter_timezone` | string | IANA timezone for relative dates |
| `filter_include_nulls` | bool | include tasks whose filtered field is null |
| `sort_by` | string[] (repeatable) | e.g. `due_date`, `priority`, `done`, `position`, `id`; `relevance` needs `q` |
| `order_by` | string[] (repeatable) | `asc` / `desc`, paired positionally with `sort_by` |
| `expand` | enum[] | §3.7 |
| `format` | `html` / `markdown` | §3.6 |

Mobile widget examples [I] (filter field names come from the shared DSL):
- "Today": `GET /api/v2/tasks?filter=done = false && due_date < now/d+1d&filter_timezone=Europe/Berlin&sort_by=due_date&order_by=asc`
- "Upcoming": the same filter with a later bound, e.g. `due_date < now+7d`.

---

## 7. WebSocket `/api/v2/ws` [V] `pkg/websocket/{messages.go,connection.go,listener.go}`, `routes.go:486-491`

- It is also served at `/api/v1/ws` (since 2.3.0). The v2 path has existed since 2.4.0 (CHANGELOG line 2085).
- Client → server messages:
  - `{"action":"auth","token":"<JWT>"}`
  - `{"action":"subscribe","event":"notification.created"}`
  - `{"action":"unsubscribe","event":…}`
- Server → client messages: `{"action":"auth.success","success":true}`, `{"event":"…","data":…}`, `{"error":"invalid_token"|"auth_required"|"invalid_event","event"?:…}`. Probed on 2.7.0 (2026-10-19, step 17): `forbidden` and `unsubscribed` are never sent, subscribes are never acknowledged, `data` of `notification.created` equals the `GET /notifications` item, and the upgrade shares the per-IP limit of login and registration ([D46](../decisions.md#d46-realtime-in-the-foreground-one-websocket-for-the-active-account-while-the-app-is-in-front-pushed-notifications-stored-at-once-and-a-sync-nudged-for-the-task-they-name-re-auth-on-every-token-change-quiet-fallback-to-polling)).
- Subscribable events are **only** `notification.created`, `timer.created`, `timer.updated` and `timer.deleted` (`connection.go:337-342`).
  - Timer events require the `time_tracking` license.
- Sockets close when a session is revoked (2.7.0).
- Origin is checked against `cors.origins` (`handler.go:51`). [I] This only matters for browsers; a native client sends no Origin header or controls it.

---

## 8. Rate limits and caching

- Every `/api/v2` response has `Cache-Control: no-store` (`routes.go:388-398`).
- Rate limit: `config.RateLimitKind` (user or IP).
  - Credential paths use `noAuthRateLimit`.
  - Refresh and oauth/token have their own budget (since 2.6.0).
  - `Retry-After` is exposed to CORS.
- Body limit: `files.maxsize` + 2 MB. Upload body read timeout is 15 min (`huma.go:192-197`, 2.7.0).

---

## 9. `/info` response: every field, verified [V] `pkg/routes/api/shared/info.go:36-175`

Both `GET /api/v1/info` and `GET /api/v2/info` are public and return this body; v2 adds `$schema`.

| JSON field | Type | Source / meaning |
|---|---|---|
| `version` | string | `version.Version`, set by ldflags from `git describe` (e.g. `v2.7.0`, `v2.7.0-12-0123abcdef`, `dev`/`unstable` on dev builds) (`magefile.go:123-147,194`). Parse leniently (strip `v`, ignore suffix). |
| `frontend_url` | string | `service.publicurl` |
| `motd` | string | `service.motd` |
| `link_sharing_enabled` | bool | `service.enablelinksharing` |
| `max_file_size` | string | `files.maxsize`, human-readable, e.g. `"20MB"` (default `"20MB"`, config.go:483) |
| `max_items_per_page` | int | `service.maxitemsperpage` (default 50) |
| `available_migrators` | string[] | always `vikunja-file`, `ticktick`, `wekan`, `csv`, `planka`; plus `todoist`/`trello`/`microsoft-todo` when enabled. [I] exact Name() strings come from the migrator packages; the URL segments match (§5.4). |
| `task_attachments_enabled` | bool | |
| `enabled_background_providers` | string[] or null | `upload`, `unsplash` (only when backgrounds are enabled) |
| `totp_enabled` | bool | |
| `legal` | `{imprint_url, privacy_policy_url}` | |
| `caldav_enabled` | bool | |
| `auth` | `{local:{enabled, registration_enabled}, ldap:{enabled}, openid_connect:{enabled, providers:[{name,key,auth_url,logout_url,client_id,scope,email_fallback,username_fallback,force_user_info}]}}` | `registration_enabled = local.enabled && service.enableregistration`. There is **no top-level `registration_enabled`**; it moved under `auth.local` in 1.0.0-rc0 (CHANGELOG line 5855 "Refactor registration enabled setting in /info"). Provider fields: `pkg/modules/auth/openid/openid.go:61-70`. |
| `email_reminders_enabled` | bool | |
| `user_deletion_enabled` | bool | |
| `task_comments_enabled` | bool | |
| `demo_mode_enabled` | bool | |
| `webhooks_enabled` | bool | |
| `public_teams_enabled` | bool | |
| `allow_icon_changes` | bool | `service.allowiconchanges` |
| `enabled_pro_features` | string[] | licensed features: `admin_panel`, `time_tracking`, `audit_logs`, `user_invites` (`pkg/license/license.go:66-86`). Added in 2.4.0 (CHANGELOG line 2151). |
| `concurrent_writes` | bool | false when the DB is SQLite: **serialize batched writes**. [I] Likely **unreleased** (post-2.7.0 main); there is no CHANGELOG entry. Treat a missing value as unknown and serialize writes. |

Fields **not** present (the task's list mentioned them): `registration_enabled` at top level, and any `license` object. License info is only `enabled_pro_features`; the full license snapshot is on admin `GET /admin/overview`.

---

## 10. How a client should detect API versions [V]+[I]

The web frontend's algorithm is the model [V] `frontend/src/helpers/apiUrl.ts`, `checkAndSetApiUrl.ts`, `stores/config.ts:135-148`:

1. Normalize the user input: strip a trailing `/` and any `/api/v1` or `/api/v2` suffix. Add a scheme if missing.
2. Candidates: the given URL, then the same host on port `3456`.
3. Probe `GET {root}/api/v2/info`. Accept the response only if it is JSON with a `version` field. Otherwise reject.

Recommended mobile algorithm:
1. `GET {root}/api/v2/info`. HTTP 200 + JSON + string `version` means **v2 available** (server ≥ 2.4.0).
   - Current servers never serve the SPA index for `/api/*` paths (`pkg/routes/static.go:136`).
   - Older servers or reverse proxies may return HTML or a 404, so always validate the body.
2. Otherwise `GET {root}/api/v1/info`. A valid body means v1-only (server < 2.4.0, or a proxy that only forwards `/api/v1`). [I]
3. Parse `version` for feature thresholds (§11). Gate optional features on `/info` flags and `enabled_pro_features` rather than version alone.
   - Handle `dev` and `unstable` versions as "latest".
4. For fine-grained capability checks, optionally fetch `/api/v2/openapi.json` once and cache by `version`. Examples: whether `tasks-bulk-create`, `invite-links-check` or `mcp-info` exist, or whether `expand` accepts `time_entries_count`.
   - The spec reflects the instance's config gates (§1).
   - It does **not** reflect license gates: time entries and admin show up but return 404 at runtime.

---

## 11. CHANGELOG timeline: when v2 capabilities appeared [V] `CHANGELOG.md`

| Version (date) | v2-relevant additions (CHANGELOG line refs) |
|---|---|
| ≤ 2.3.0 (2026-04-09) | **No /api/v2.** Did ship things later exposed on v2: OAuth 2.0 authorize/token + PKCE on v1 (lines 2654-2659), WebSocket at `/api/v1/ws` (2644-2648), user-level webhooks (2.2.0, 3044-3047), `expand` / `expand[]` both accepted (2.2.0, 2921). |
| **2.4.0 (2026-07-19)** | **/api/v2 introduced** (2179 "Scaffold /api/v2 Echo group"). Huma, AutoPatch (2016), Scalar `/api/v2/docs` (2018), problem+json with `code` (2019), 422 validation (2040), central validation (2039). <br>Ported: labels, projects, views, buckets (2086), tasks CRUD (2056), task collection/lists (2063), comments, assignees, labels, bulk ops, relations, reactions, positions, kanban moves, duplicates, attachments, subscriptions, notifications, project user/team/link shares, saved filters, teams + members, webhooks, user settings/account, TOTP, CalDAV tokens, user webhooks, deletion, export, avatars, backgrounds + unsplash, migrators, admin, info, health, notifications.atom, ws, login/logout, OIDC callback, refresh, OAuth, token test/routes/renew (2020-2085). <br>v2-only from day one: **sessions** list/delete (2032), **bots** (2035), **time entries** (2194; license `time_tracking`), **Markdown rich text** (2012-2013), `enabled_pro_features` in /info (2151), by-index with project identifier (2008-2011), API tokens usable on v2 (1637), Cache-Control/rate limit on v2 (1656-1657). |
| 2.5.0 (2026-08-04) | **Bulk task creation** `POST /projects/{p}/tasks/bulk` (1420); validation of slice elements (1255); 5xx detail stripping (1253-1254). |
| 2.6.0 (2026-08-31) | **Pending email**: `pending_email` field + cancel/resend endpoints (1125); admin users list on v2 (1124); refresh-token endpoint rate-limited (979); `/api/v2/token/test` accepts API tokens (885); AutoPatch GET no longer requires read_one token permission (879); **Planka migrator (v2-only)** (1148); frontend refreshes via v2 with v1 fallback (1139). |
| 2.7.0 (2026-10-02) | **Historical task index → 307** (427); **user invite links** + `user_invites` license (446-447) → `/invite-links/check`, `/admin/invite-links`, `/admin/teams`; **MCP** at `/api/v2/mcp` + `/mcp/info` (450-470); admin project list filters (423); WebSocket re-auth and close on session revocation (288, 482); `X-Vikunja-Format` header constant exported (431); upload body-read timeout (27); webhook list pagination (480). |
| main after 2.7.0 [I] | `concurrent_writes` in /info has no CHANGELOG entry. Treat as possibly unreleased. |

### Minimum server version per capability (for feature gating)

| Capability | Min version | Basis |
|---|---|---|
| Any `/api/v2` route, problem+json, envelope pagination, ETag, AutoPatch, `format=markdown` | 2.4.0 | §11 |
| v2 sessions, bots, time entries (and license), notifications.atom on v2, `/api/v2/ws` | 2.4.0 | lines 2032, 2035, 2194, 2084, 2085 |
| OAuth PKCE (`/oauth/authorize`, `/oauth/token`) | 2.3.0 (v1) / 2.4.0 (v2) | 2654-2659 / 2071 |
| Bulk task create | 2.5.0 | 1420 |
| `pending_email`, cancel/resend email; Planka migrator | 2.6.0 | 1125, 1148 |
| API tokens on `/token/test` (v2) | 2.6.0 | 885 |
| by-index 307 redirect, invite links, MCP | 2.7.0 | 427, 446, 470 |
| `X-Vikunja-Format` on PATCH | [I] present by 2.7.0 (431); possibly since 2.4.0, but there is no explicit entry. On < 2.7.0, prefer `format=html` writes. |
| `concurrent_writes` | [I] unreleased / main | no entry |

---

## 12. v1 vs v2 comparison

### 12.1 Conventions

| Aspect | v1 (`/api/v1`, Echo, frozen) | v2 (`/api/v2`, Huma) |
|---|---|---|
| Create / update verbs | PUT create, POST update | POST create (201), PUT replace (200), PATCH partial (synthetic) |
| List response | bare JSON array + headers `x-pagination-total-pages`, `x-pagination-result-count` (`pkg/web/handler/read_all.go:113-115`) | `{items,total,page,per_page,total_pages}` |
| Permission on read | header `x-max-permission` (`read_one.go:59`) | body `max_permission` |
| Conditional GET | none | ETag + `If-None-Match` → 304 |
| Errors | `{code, message, i18n_params?}` (`pkg/web/web.go:47-53`) | RFC 9457 problem+json + `code` + `i18n_params` + `errors[]` |
| Validation status | 412 | 422 |
| Rich text | HTML only | HTML or Markdown (`format` / `X-Vikunja-Format`) |
| Spec | Swagger 2.0 `/api/v1/docs.json`, Redoc `/api/v1/docs`, committed `pkg/swagger/*` | OpenAPI 3.1/3.0 live `/api/v2/openapi*.{json,yaml}`, Scalar `/api/v2/docs`, not committed |
| Security schemes | JWTKeyAuth (JWT + API tokens conflated) | JWTKeyAuth, APITokenAuth, BasicAuth (feed) |
| Path param names | e.g. `/tasks/:projecttask`, `/tokens/:token` | `/tasks/{task}`, `/tokens/{id}` |

### 12.2 Per-resource availability

Sources: v1 from `pkg/routes/routes.go:520-1006`; v2 from §5.

| Resource / action | v1 | v2 | Differences |
|---|---|---|---|
| Info | ✓ `/info` | ✓ `/info` | identical body |
| Health | `/health` (root, not under /api) | ✓ `/api/v2/health` (with OIDC provider status) | |
| Login / register / password reset / confirm | ✓ | ✓ | same paths |
| Refresh (cookie) | ✓ | ✓ | same cookie set for both paths |
| OAuth authorize/token | ✓ (2.3.0) | ✓ | |
| OpenID callback | ✓ | ✓ | |
| Logout | ✓ `/user/logout` | ✓ `/logout` | **path differs** |
| Link-share auth / renew | ✓ | ✓ | |
| Token test / routes | ✓ | ✓ | |
| Projects CRUD | ✓ | ✓ | v2 `expand=permissions`, no ETag on read |
| Project duplicate | ✓ PUT | ✓ POST | |
| Project views | ✓ | ✓ | |
| Kanban buckets | ✓ | ✓ | |
| Task→bucket move | ✓ POST | ✓ PUT | |
| Buckets with tasks | via `GET /projects/{p}/views/{v}/tasks` on a kanban view (polymorphic) | separate `…/buckets/tasks`; `…/views/{v}/tasks` is always flat | **behaviour split** |
| Tasks CRUD, by-index | ✓ | ✓ | v2 adds the 307 redirect (2.7.0) |
| Task lists (all / project / view) | ✓ | ✓ | same filter params |
| Bulk update | ✓ POST `/tasks/bulk` | ✓ PUT `/tasks/bulk` | |
| **Bulk create** | ✗ | ✓ (2.5.0) | v2-only |
| Duplicate, position, relations, assignees (+bulk), labels (+bulk), comments, attachments | ✓ | ✓ | verbs inverted; attachment upload response `{success, errors}` |
| Mark task read | ✓ POST `/tasks/:t/read` | ✓ PUT `/tasks/{task}/read` | |
| Reactions | ✓ (PUT create) | ✓ (POST create) | |
| Labels | ✓ | ✓ | |
| Saved filters | ✓ (no list) | ✓ (no list) | |
| Project user/team shares | ✓ | ✓ | |
| Link shares | ✓ | ✓ | |
| Teams, members | ✓ | ✓ | |
| Subscriptions | ✓ | ✓ | |
| Notifications list/mark/mark-all/delete-all | ✓ | ✓ | |
| Notifications Atom feed | `/feeds/notifications.atom` (root) | `/api/v2/notifications.atom` | |
| Webhooks project/user/events | ✓ | ✓ | |
| API tokens | ✓ | ✓ | v2 has `owner_id` for bots |
| CalDAV tokens | ✓ | ✓ | |
| TOTP | ✓ | ✓ | |
| User show | ✓ | ✓ | v2 adds `pending_email`; includes `settings` |
| General settings | POST update only | GET + PUT + PATCH | v2 can read and merge-patch |
| Email change | POST | PUT | **cancel/resend v2-only** (2.6.0) |
| Avatar provider | GET/POST `/user/settings/avatar` | GET/PUT/PATCH `/user/settings/avatar/provider` | **path differs** |
| Avatar upload | PUT `/user/settings/avatar/upload` | PUT `/user/settings/avatar` | **path differs** |
| Avatar get | ✓ | ✓ | |
| User search | `GET /users` | `GET /users` | |
| Project users search | `GET /projects/:p/projectusers` | `GET /projects/{p}/users/search` | **path differs** |
| Timezones, export, deletion | ✓ | ✓ | |
| **Sessions** list/delete | ✓ (`/user/sessions`) | ✓ | both exist; v2 port since 2.4.0 |
| **Bot users** | ✓ (`/user/bots`) | ✓ | both exist since 2.4.0 |
| **Time entries / timer** | ✗ | ✓ | **v2-only**, license `time_tracking` |
| **Invite links** (`/invite-links/check`, `/admin/invite-links`, `/admin/teams`) | ✗ | ✓ (2.7.0) | **v2-only**, license `user_invites` |
| **MCP** (`/mcp`, `/mcp/info`) | ✗ | ✓ (2.7.0) | **v2-only** |
| Admin: overview, users list/create/patch admin/status/delete, projects list/patch owner | ✓ | ✓ | |
| Admin: set password, password-reset email | ✗ | ✓ | **v2-only** (2.4.0 pro feature, line 2170) [I version] |
| Migrators: todoist, trello, msft, vikunja-file, ticktick, wekan, csv | ✓ | ✓ | |
| Planka migrator | ✗ | ✓ (2.6.0) | v2-only |
| Backgrounds (upload, unsplash, get/delete) | ✓ | ✓ | unsplash set: v1 POST, v2 PUT |
| WebSocket | `/api/v1/ws` | `/api/v2/ws` | same protocol |
| Prometheus `/metrics` | ✓ `/api/v1/metrics` | ✗ | v1-only |
| Plugins `/plugins` | ✓ | ✗ | v1-only |
| Testing endpoints | DELETE `/test/all`, PATCH `/test/:table` | DELETE `/test/all`, PUT `/test/{table}` | testing token only |
| "notifications_feed", "task_unread_status" | – | – | These are v2 **file names** (`notifications_feed.go` = Atom feed; `task_unread_status.go` = mark-read), not separate resources. Both exist on v1 too (`/feeds/…`, `POST /tasks/:t/read`). |

---

## 13. Open questions and risks

1. **Refresh cookie on mobile.** Using v2 `/login` requires cookie persistence: the cookie is path-scoped and HttpOnly, with Secure only on https. OAuth PKCE is cleaner. However, it needs the server's web frontend reachable at `frontend_url` with the `/oauth/authorize` route, and the user to be logged in there. [V] for mechanics; [I] for UX.
2. **No change feed.** Background sync must poll. Options:
   - Lists sorted by `updated` with a filter like `updated > <ts>`. [I] Whether `updated` is filterable must be checked in the filter DSL (another research area).
   - Single-task ETags.
   - Deletions require a full id reconciliation, or CalDAV `sync-collection`.
3. **Unknown-field rejection** [I]: do not send client-only fields in bodies.
4. **License-gated routes** appear in the spec but return 404: time entries, admin.
5. **SQLite instances:** serialize bulk writes (`concurrent_writes=false`).
6. Spec drift: generate code per server `version` or from the canonical spec of the minimum supported version (2.4.0). Paths and verbs added later (§11) must be feature-detected.
