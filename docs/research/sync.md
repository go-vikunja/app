# Vikunja mobile: offline-first sync, background sync, realtime

Research basis: Vikunja `main`, shallow clone, latest release **v2.7.0 (2026-10-02)**. All paths are relative to the repo root.
Legend: **[V]** verified in source; **[I]** inferred (reasoned from source, not executed); **[X]** external platform/library knowledge, not from the Vikunja repo. Verify **[X]** against current OS docs before relying on it.

---

## 0. TL;DR for the sync architect

1. **The server pushes no task, project or label changes.** The WebSocket only emits `notification.created`, `timer.created`, `timer.updated` and `timer.deleted` **[V]** (`pkg/websocket/connection.go:337-342`). "Task created on web shows up on phone" has to be built on **polling plus a local DB**. The socket is only a hint to sync now.
2. **Incremental pull works.** The task filter accepts `updated` (also `created`, `done_at`, `id`, ...) with `>`/`>=`, and `sort_by=updated` is allowed **[V]**. `GET /api/v2/tasks` (v1: `GET /api/v1/tasks`) lists tasks across all projects. Paging is capped at `max_items_per_page` (default **50**) **[V]**.
3. **Deletes leave no REST tombstone.** Tasks are soft-deleted since 2.4.0, but only CalDAV `sync-collection` exposes the deletes **[V]**. Every task delete bumps `projects.updated` **[V]**. Detect deletes with a project-list diff, then a per-project **count check** (`per_page=1` → `total`), then an id reconciliation only when the counts differ. This design is mine **[I]**.
4. **No optimistic concurrency on writes.** ETags exist only on v2 single-resource GETs (`If-None-Match` → 304). PUT/PATCH ignore `If-Match` **[V]** (Huma autopatch forwards it, but the PUT handlers declare no `conditional.Params`). The result is last-write-wins under a row lock. **v1 `POST /tasks/{id}` replaces every field, including assignees and reminders**. Prefer **v2 `PATCH` with only the changed fields**, which the server merges as GET → merge → PUT **[V]**.
5. **Reminders are server-side only as e-mail plus in-app notification.** A cron runs every minute and stores a `task.reminder` notification for each assignee, the creator and subscribers **[V]**. There is no mobile push. **Local OS notifications must be scheduled from `reminders[]` and `due_date`.** The daily overdue reminder is e-mail-only and never stored **[V]**.
6. **There is no idempotency key** **[V]**. Retrying a task create after a lost response can duplicate the task. De-duplicate with a `created >= ... && title = ...` lookup before you retry.
7. **iOS:** there is no reliable background fetch, and silent push is impossible without an APNs-capable push service that Vikunja does not have **[X]**. Treat iOS background sync as best effort. The truth is synced on foreground.

---

## 1. WebSocket (realtime)

### 1.1 Endpoint, availability, transport [V]
| Item | Value | Source |
|---|---|---|
| v1 path | `GET /api/v1/ws` (upgrade) | `pkg/routes/routes.go:522` |
| v2 path | `GET /api/v2/ws` (same handler, raw Echo route outside the Huma/OpenAPI spec) | `pkg/routes/routes.go:486-491`, JWT-exempt list `routes.go:364` |
| Web frontend uses | `${apiRoot}/api/v2/ws`, `wss:` when https | `frontend/src/helpers/apiUrl.ts:16-18`, `frontend/src/composables/useWebSocket.ts:47-51` |
| Library | `github.com/coder/websocket v1.8.15` | `go.mod:37` |
| Origin check | `websocket.Accept(..., OriginPatterns: config.CorsOrigins)` | `pkg/websocket/handler.go:50-52` |
| Config toggle | none; the hub is always initialised | `pkg/initialize/init.go:155-161` |
| Rate limit on upgrade | `noAuthRateLimit` = `ratelimit.noauthlimit` (default **10 req/min per IP**). It is the **same limiter instance** as login/register/password reset. | `routes.go:239,491,522`, `config-raw.json` (`ratelimit.noauthlimit`) |

Release history (CHANGELOG.md):
- Added in **2.3.0** (2026-04-09): message types, hub, `/api/v1/ws`, `notification.created` (lines 2644-2648).
- **2.4.0**: timers broadcast (2197), `/api/v2/ws` (2085).
- **2.5.0**: upgrade rate limited (1311).
- **2.7.0**: session check, close on revocation, re-auth (lines 287-289, 481-482).
- Servers **< 2.3.0 have no socket**.

[I] Native clients (Dart `WebSocket.connect`) send no `Origin` header by default. coder/websocket accepts requests without an Origin, so the CORS origin list does not block the app. Verify against a live server.

### 1.2 Handshake / protocol [V] (`pkg/websocket/messages.go`, `connection.go`)
Client → server, JSON text frames:
```json
{"action":"auth","token":"<user JWT>"}
{"action":"subscribe","event":"notification.created"}
{"action":"unsubscribe","event":"notification.created"}
```
Server → client:
```json
{"action":"auth.success","success":true}
{"error":"invalid_token"}                         // then close; terminal, don't retry
{"error":"auth_required"}                         // subscribe before auth
{"error":"invalid_event","event":"foo"}
{"event":"notification.created","data":{ /* DatabaseNotification */ }}
{"event":"timer.updated","data":{ /* TimeEntry */ }}
```
- **Auth happens after the upgrade, in the first message.** If no auth arrives within **30 s**, the server closes with 1008 "auth timeout" (`connection.go:35,130-135`).
- **Only user JWTs are accepted.** The JWT needs `type`=user, `id`, `exp` and a non-empty `sid` claim (`pkg/modules/auth/auth.go:310-344`), and the session must still exist (`CheckUserTokenSession`, `auth.go:346-367`). **API tokens (`tk_…`) and link-share JWTs are rejected** with `invalid_token`. Tokens from the OAuth server are user JWTs with a `sid` (`pkg/modules/auth/oauth2server/token.go:158`), so they work.
- **Token expiry:** the server closes the socket at the JWT `exp` with code 1008 "token expired" (`connection.go:247-251`). To keep the socket open, send another `auth` frame with a refreshed token. The new token must carry the **same user id and same `sid`**, or the server returns `invalid_token` and closes (`reauth`, `connection.go:222-244`). A re-auth keeps the subscriptions.
- **Transient validation failure** (for example a DB error): the server closes with **1013 TryAgainLater** and no error frame (`failAuth`, `connection.go:262-271`). Reconnect in that case.
- **Session revoked** (logout elsewhere, password change, account lock): the server closes the socket with 1008 "session revoked" (`listener.go:119-140`, `hub.go:64-80`).
- The server pings every **30 s** with a 10 s write timeout (`connection.go:32-37,298-334`). The client does not need to send pings. The server does **not acknowledge subscribes** (`frontend/src/composables/useWebSocket.ts:130`).
- The per-connection send buffer holds **64** messages. When it is full, messages are **dropped silently** (`hub.go:97-101`).

### 1.3 Events pushed [V]
`validEvents` = `notification.created`, `timer.created`, `timer.updated`, `timer.deleted` (`connection.go:337-342`). **No task, project, label, comment or bucket events exist.**
- `notification.created`: one per stored notification for that user. Before pushing, the server reloads the row and checks `CanReadNotification` (`listener.go:44-80`). Payload = `DatabaseNotification` `{id, name, notification:{...}, read_at, created}` (`pkg/notifications/database.go:31-52`).
- `timer.*`: the user's own time entry. Sent only when the licensed `time_tracking` feature is enabled (`listener.go:93-117`).
- **Scoping:** the hub maps userID → connections (`hub.go:26-29`). `PublishForUser` sends only to that user's sockets that subscribed to the event (`hub.go:83-103`).
- [I] **Single-node only.** Events use an in-memory watermill GoChannel (`pkg/events/events.go:36-39,92`) and the hub lives in memory. On a multi-replica deployment a client only receives events processed on the node it is connected to. Events are not persisted, so anything in flight during a restart is lost. **Never treat the socket as a source of truth.**

### 1.4 What the web client does (reference behaviour) [V]
`frontend/src/composables/useWebSocket.ts`, `useServerCacheEvents.ts`, `client/queries/serverEvents.ts`:
- **Reconnect:** exponential backoff, 1 s base, max 30 s, ±25 % jitter (`useWebSocket.ts:22-23,158-183`). It stops reconnecting on `invalid_token`/`auth_required` and falls back to polling. If the token is within 5 s of expiry, it refreshes the token *before* sending `auth` (`:59-76`). It re-sends `auth` whenever the token is refreshed (`:78-90`) and re-subscribes after `auth.success` (`:121-133`).
- **On reconnect** (`mayHaveMissedEvents`) it invalidates **all** notifications, time entries, comments, task details and task membership caches (`serverEvents.ts:134-140`). Events may have been missed, so it re-syncs.
- On `notification.created`, it refetches notifications and, for `task.comment`, that task's comments (`serverEvents.ts:68-76,116-125`).
- The notification bell polls every **10 s** while the socket is not authenticated (`frontend/src/components/notifications/Notifications.vue:144-149`).
- The web app itself gets **no realtime task updates**. It uses `staleTime: 60_000` and `refetchOnWindowFocus: false` (`frontend/src/client/queryClient.ts:16-18`).

### 1.5 Mobile use of the socket [I]
- Connect only while the app is in the foreground (and on Android optionally while a foreground service runs; not recommended). On `AppLifecycleState.paused`, close the socket cleanly.
- Subscribe to `notification.created`. Treat **every** event as "something changed": run a debounced (≈1-2 s) incremental sync. For `name == "task.comment"`, also refresh that task's comments.
- After every (re)connect, run a full incremental sync, as the web client does.
- Respect the shared 10/min/IP upgrade limit. Mobile carriers often use CGNAT, so many users can share an IP. Use the same 1 s → 30 s jittered backoff. A 429 from the upgrade request carries `Retry-After` (`pkg/routes/rate_limit.go:64-69`).

---

## 2. Fetching changes since a timestamp

### 2.1 Endpoints [V]
| Purpose | v1 | v2 |
|---|---|---|
| All tasks the user can see, flat | `GET /api/v1/tasks` (`routes.go:712`) | `GET /api/v2/tasks` op `tasks-list` (`pkg/routes/api/v2/task_collection.go:96-103`) |
| Tasks of one project | `GET /api/v1/projects/{id}/tasks` (`routes.go:685`) | `GET /api/v2/projects/{project}/tasks` |
| Tasks of one view | `GET /api/v1/projects/{id}/views/{view}/tasks` (a kanban view returns buckets) | `GET /api/v2/projects/{project}/views/{view}/tasks` (always flat) and `GET …/views/{view}/buckets/tasks` (buckets, not paginated) |
| Single task | `GET /api/v1/tasks/{id}` | `GET /api/v2/tasks/{task}` (sends **ETag**, supports `If-None-Match` → 304) (`v2/tasks.go:63-68,135,152`) |

Query parameters:
- **v2:** `page`, `per_page`, `q` (search), `filter`, `filter_timezone`, `filter_include_nulls`, `sort_by` (repeat), `order_by` (repeat), `expand` (repeat: `subtasks,buckets,reactions,comments,comment_count,time_entries_count,is_unread`), `format=html|markdown` (`v2/task_collection.go:26-35`, `v2/types.go:59-63`).
- **v1:** the same names, except search is **`s`** (`pkg/models/task_collection.go:31-71`, `pkg/web/handler/read_all.go:93`).

Pagination:
- **v2** returns `{"items":[…],"total":N,"page":p,"per_page":n,"total_pages":t}` (`v2/types.go:30-55`).
- **v1** returns a JSON array plus the headers `x-pagination-total-pages` and `x-pagination-result-count` (`pkg/web/handler/read_all.go:113-115`). v1 has no total count, but with `per_page=1` the total page count equals the item count.
- `per_page` defaults to `service.maxitemsperpage` and is **silently capped** at it (default **50**, `config-raw.json` `service.maxitemsperpage`). The value is reported as `max_items_per_page` by `GET /info` (`pkg/routes/api/shared/info.go:42`, `v2/types.go:68-75`, `read_all.go:81-89`).

What a task list item contains [V] (`pkg/models/tasks.go:709-855`):
- Always: scalar fields plus `assignees`, `labels`, `attachments` (metadata), `created_by`, `reminders`, `related_tasks`, `is_favorite`, `identifier`, and `position` (view-scoped).
- Comments only with `expand=comments` (first 50) or `expand=comment_count`. `subscription` only on a single read (`tasks.go:126` doc).

Task fields relevant for sync [V] (`pkg/models/tasks.go:96-182`):
- `id`, `project_id`, `index`, `title`, `description` (HTML by default; `format=markdown` on v2), `done`, `done_at` (server-set), `due_date`, `start_date`, `end_date`
- `reminders[{reminder, relative_period, relative_to}]`, `repeat_after` (seconds), `repeat_mode` (0 default, 1 monthly, 2 from current date)
- `priority`, `percent_done`, `hex_color`, `cover_image_attachment_id`, `bucket_id`
- `created`, **`updated`**, `deleted_at` (omitzero; never returned in practice because soft-deleted rows are filtered out)
- `UID` is `json:"-"`, so it is invisible and not client-settable.

### 2.2 Filter grammar facts [V]
- Allowed filter fields (`pkg/models/task_collection.go:106-117`, `task_collection_sort.go:30-57,98-124`): `id, title, description, done, done_at, due_date, created_by_id, project_id (alias project), repeat_after, priority, start_date, end_date, hex_color, percent_done, uid, created, updated, position, bucket_id, index, assignees, labels, reminders, created_by`.
- Comparators: `= != > >= < <= like in "not in"`. Join with `&&` / `||` and parentheses (`task_collection_filter.go:381-428,180-276`).
- Values are auto-quoted (`preprocessFilterString`, `:245-276`).
- Size limits: **16 KiB** and **100 levels of nesting**. Exceeding them returns error 4033 (`:278-313`).
- Date values (`:430-475,83-118`): first parsed as datemath (`now-1d` etc.), then as RFC3339, then Safari formats, then `Y-M-D`. Results are **converted to UTC**. The DB stores UTC (`engine.SetTZDatabase(GMT)`, `pkg/db/db.go:121-126`). Responses render times in the server timezone with an offset, so parse them to UTC.
- [I] Timestamps have second granularity (DB time format `2006-01-02 15:04:05`, `task_reminder.go:72`).
- So `filter=updated >= '2026-10-08T10:00:00Z'` with `sort_by=updated&order_by=asc&sort_by=id&order_by=asc` is valid. The server always appends `id asc` as the final tie-breaker unless the last sort is already `id` (`tasks.go:344-351`).

### 2.3 Caveats of `/tasks` (all projects) [V]
- It only covers **non-archived** projects. `getRelevantProjectsFromCollection` calls `getRawProjectsForUser` with `getArchived=false` (`task_collection.go:220-230`, `project.go:650-651`). Tasks of archived projects need `GET /projects/{id}/tasks` (that path does a plain `CanRead`, `task_collection.go:233-245`).
- `/tasks` includes Favorites membership logic (pseudo project −1). Saved filters appear as pseudo projects with ids `< -1` in the project list (`project.go:154-163,290-295`). Their task membership is server-evaluated.
- Typesense, if configured, may serve searches (`tasks.go:355-362`). Sync queries use no `q`, so the DB searcher applies [I].

### 2.4 Which actions bump `tasks.updated` [V]
| Action | Bumps `tasks.updated`? | Bumps `projects.updated`? | Source |
|---|---|---|---|
| Task create | (created) | yes | `tasks.go:1181` |
| Task update (incl. done, reminders, assignees through the update body) | yes. xorm `updated` tag; the code re-reads `updated` after `Update` | yes | `tasks.go:1652-1674` |
| Task delete (soft) | n/a | **yes** | `tasks.go:2175` |
| Label add/remove on task | yes | yes | `label_task.go:74,79,119,129` |
| Assignee add/remove | yes (async listener) | yes | `task_assignees.go:147,179,282`, `listeners.go:53-54` |
| Comment create/edit/delete, attachment add/del, relation add/del | yes (**async** listener `HandleTaskUpdateLastUpdated`) | yes | `listeners.go:50-58,962-1023` |
| Kanban bucket move that changes `done` | yes (`Update` with `done`/`done_at` columns) [I: xorm auto-sets `updated`] | — | `kanban_task_bucket.go:171-188` |
| Pure position change / bucket move without a done change | **no** [I]: only `task_positions`/`task_buckets` rows are written | no | `task_position.go:345-352`, `kanban_task_bucket.go:248-261` |
| Favorite toggle | yes [I] (it goes through `Task.Update`) | yes | `tasks.go:1643-1646` |
| Project share/team change | — | yes | `project_users.go:124,173,275`, `project_team.go:134,187,314` |
| Favorite/subscription on a project | — | **no** (stated explicitly) | `v2/projects.go:52` |

Consequence [I]: `projects.updated` works as a per-project change marker for everything except positions, buckets and user-scoped flags.

---

## 3. Deletions and other entity changes

### 3.1 Tasks [V]
- **Soft delete since 2.4.0** (CHANGELOG.md:2190). `DELETE /tasks/{id}` sets `deleted_at` (xorm `deleted` tag) and dispatches `task.deleted` (`tasks.go:2133-2178`). An hourly cron hard-deletes rows older than **30 days** (`pkg/models/task_delete_cron.go`: `TaskDeleteRetention = 30*24h`, schedule `0 * * * *`).
- **No REST endpoint lists or restores deleted tasks** (grep: no `Restore`/trash route). A deleted task returns **404, code 4002** on GET or PATCH.
- **CalDAV RFC 6578 `sync-collection`** (2.4.0, CHANGELOG.md:2101) reports deleted tasks per project as 404 entries since a sync token (`pkg/routes/caldav/sync_collection.go`, `models.GetDeletedTasksSince`, `tasks.go:2287-2299`). It needs CalDAV credentials (Basic auth, CalDAV token), XML handling and one token per project. Tokens older than 30 days force a full resync. Every task gets a UID on create (`tasks.go:1083-1085`), so all deletes are covered. **Possible, but heavy for a mobile app.**
- **Project deletes are hard** (the project and all its tasks via `hardDeleteTask`, `project.go:1469`). **Losing access** (unshare, team removal) also makes tasks vanish without a tombstone.

### 3.2 Recommended delete detection, no CalDAV [I]
1. Pull the full project list every sync: `GET /api/v2/projects?is_archived=true` (all pages; `expand=permissions` adds `max_permission`; `v2/projects.go:90-92`).
   - A project id missing from the list means it was deleted or access was lost: purge it locally with its tasks.
   - A project with a newer `updated` goes into the "changed projects" set.
2. Run the incremental task pull (§2) first.
3. For each changed project: `GET /api/v2/projects/{id}/tasks?per_page=1` → `total` (v1: `x-pagination-total-pages` with `per_page=1`).
   - If `total == local count of synced tasks with that project_id`, nothing was deleted. Moves were already applied, because a move changes the task's `updated`.
   - Otherwise reconcile ids: page through the project with `sort_by=id`, preferably keyset (`filter=id > X`). Any local synced id not returned is deleted.
4. Cheaper alternative for big projects: `filter=id in 1,2,3,…` over chunks of local ids (keep under 16 KiB). Ids not returned are deleted. Each chunk still pages at 50.
5. On a 404 (4002) for a single task (detail open, PATCH): delete it locally.
6. As a safety net, run a full id reconciliation of all projects about every 24 h (foreground or charging only).

### 3.3 Projects, labels, views, buckets, teams [V]
- **Project** fields: `id, title, description, identifier, hex_color, parent_project_id, owner, is_archived, background_information, background_blur_hash, is_favorite, position, views[], max_permission, created, updated` (`project.go:35-118`). Views are embedded in project responses.
- **Label** fields: `id, title, description, hex_color, created_by, created, updated` (`label.go:30-50`). Deletes are hard.
  - `GET /api/v2/labels` returns every label the user can access, paginated. Re-pull the full list each sync: labels are small, and a missing id means deleted.
  - [I] A label rename does **not** bump `tasks.updated`. Labels embedded in cached tasks go stale, so render labels from the `labels` table by id.
- **Kanban buckets / positions:** changes bump neither `tasks.updated` nor `projects.updated` [I]. Re-fetch `GET …/views/{view}/buckets/tasks` (v2) or the v1 kanban view when the board is opened, and on pull-to-refresh.
- **Saved filters:** `updated` exists (`saved_filters.go:53-54`). The pseudo project id is `-(filterId+1)`-style negative (`project.go:154-158`). Membership is computed on the server, so cache the result id list per filter [I].
- **Teams:** `teams-read` has an ETag (`v2/teams.go:122`). Refresh rarely.

---

## 4. Notifications / events

### 4.1 Persisted in-app notifications (`name` values) [V]
Registered in `pkg/models/notifications.go:35-44`. Names: `:99,169,235,267,303,336,367,537,568`.

| `name` | Who gets it | Stored? |
|---|---|---|
| `task.reminder` | Each assignee, the creator and task subscribers, when a reminder fires (§4.3) | yes. Payload `{task, project}`; reminder time **not** included (`notifications.go:89-95`) |
| `task.comment` | Task subscribers and users quoted in the comment, not the doer | yes |
| `task.assigned` | Subscribers (incl. the assignee), not the doer | yes |
| `task.created` | Subscribers of the task, i.e. project subscribers [I], not the doer | yes |
| `task.deleted` | Subscribers, not the doer | yes |
| `task.mentioned` | @mentioned users (task description/comments) | yes |
| `project.created`, `team.member.added`, `data.export.ready` | — | yes |
| `task.undone.overdue` (single and digest) | — | **no**: `ToDB()` returns nil, e-mail only (`notifications.go:396-399,464-467`) |
| `api_token.expiring.week/day` (`api_tokens_expiry_notification.go:57,87`), `pkg/user/notifications.go` (TOTP, failed login, deletion) | — | user-account notifications |

Recipient logic: `pkg/models/listeners.go`. The doer is always excluded (e.g. `SendTaskCreatedNotification`), so **your own web edits never produce a notification or socket event for you**.

### 4.2 Notification endpoints [V]
| Purpose | v2 | v1 |
|---|---|---|
| List (newest first, paginated; hides notifications for projects the user can no longer read) | `GET /api/v2/notifications` (`v2/notifications.go:50-57`) | `GET /api/v1/notifications` (`routes.go:886`) |
| Mark one read/unread, body `{"read":true}` (`pkg/models/notifications_database.go:26-35`) | `PUT /api/v2/notifications/{id}` | `POST /api/v1/notifications/{id}` |
| Mark all read | `POST /api/v2/notifications` (200 `{"message":…}`) | `POST /api/v1/notifications` |
| Delete all | `DELETE /api/v2/notifications` | `DELETE /api/v1/notifications` |
| Atom feed (Basic auth, failures rate limited) | `GET /api/v2/notifications.atom` | `GET /api/v1/notifications.atom` (`routes.go:256-260,304`) |

`DatabaseNotification.AfterInsert` dispatches `NotificationCreatedEvent`, which drives the socket push (`pkg/notifications/database.go:59-70`).

### 4.3 Reminders are server cron and e-mail [V]
- `RegisterReminderCron`: `* * * * *` (`pkg/models/task_reminder.go:365-392`). It selects reminders in [now, now+1 min) in **each recipient's timezone**, for tasks with `done = false` and `deleted_at IS NULL` (`:227-327`).
- Recipients: **assignees, creator, task subscribers** (`getTaskUsersForTasks`, `:75-225`).
- For each recipient: `notifications.Notify` always stores the in-app notification. E-mail only if `service.enableemailreminders`, the mailer is enabled and the user has `email_reminders_enabled` (`notifications.go:75-87`). A `task.reminder.fired` event goes to webhooks (`:329-362`).
- `TaskReminder` JSON: `{"reminder": RFC3339, "relative_period": seconds (negative = before), "relative_to": "due_date"|"start_date"|"end_date"|""}` (`task_reminder.go:36-58`). The server recomputes absolute `reminder` from relative ones when dates change (`updateRelativeReminderDates`, `tasks.go:2032-2060`). Offline date edits need the same computation locally [I].
- **Due dates have no notification of their own**, only reminders and the daily overdue e-mail (`service`/user setting `overdue_tasks_reminders_enabled` default true, `overdue_tasks_reminders_time` default `9:00`, `config-raw.json`). User settings fields: `default_project_id, email_reminders_enabled, overdue_tasks_reminders_enabled, overdue_tasks_reminders_time, timezone, week_start, language, frontend_settings, …` (`pkg/models/user_settings.go`).
- **⇒ The mobile app must schedule OS notifications locally** from `reminders[].reminder` (absolute UTC instants) and, optionally, `due_date`.
- In the foreground the socket will also deliver `notification.created` with `name:"task.reminder"`. De-duplicate it against the local notification by task id within about ±2 min.

### 4.4 Repeating tasks: what the server does on `done=true` [V] (`tasks.go:1838-2029`)
- If `repeat_after > 0` or `repeat_mode == 1`: the server sets `done` back to **false**, shifts `due_date`, `start_date`, `end_date` and every reminder (mode 0: by `repeat_after` until the result is in the future; mode 1: +1 month; mode 2: from *now*), stamps `done_at`, and **resets description checklists**.
- The response carries the new dates, so the client must apply the server response and reschedule notifications [I].
- An offline "done" replayed later computes "now" at **replay** time. This matters for mode 2 [I].

---

## 5. Webhooks (not usable for direct mobile push; noted for completeness) [V]
- Config: `webhooks.enabled` default **true**, `timeoutseconds` 30, `allownonroutableips` default **false** (SSRF guard), optional proxy (`config-raw.json` webhooks section). `/info.webhooks_enabled` exposes it.
- **Project webhooks:** `GET|POST /api/v2/projects/{project}/webhooks`, `PUT|DELETE …/{webhook}` (`v2/webhooks.go:50-81`).
- **User-level webhooks** (since 2.2.0, CHANGELOG.md:3045-3047): `/api/v2/user/settings/webhooks[...]`, events list `/api/v2/user/settings/webhooks/events` (`v2/user_webhooks.go:55-95`). User webhooks only fire for the **user-directed** events `task.reminder.fired`, `task.overdue`, `tasks.overdue` (`listeners.go:80-82,1597-1628`).
- Project events: `task.created/updated/deleted`, `task.assignee.*`, `task.comment.*`, `task.attachment.*`, `task.relation.*`, `project.updated/deleted/shared.user/shared.team` (`listeners.go:63-79`).
- Webhook fields: `{id, target_url, events[], project_id, user_id, secret (write-only), basic_auth_user/password (write-only), created_by, created, updated}` (`webhooks.go:54-79`). The HMAC-SHA256 signature is sent in the `X-Vikunja-Signature` header (`webhooks.go:357-363`).
- [I] An optional Android-only realtime path: create a webhook that targets a self-hosted **ntfy** topic, and have the app receive it via UnifiedPush. Project webhooks would be needed for every project, and private IPs are blocked unless `allownonroutableips` is enabled. For iOS this still requires APNs via the app vendor, so it is out of scope for v1 of the app.

---

## 6. Concurrency / conflicts [V]
- **ETag** only on v2 single reads: tasks (`tasks-read`, `tasks-read-by-index`), labels, teams, project views, saved filters, comments, link shares, time entries, bots (`grep conditional.Params pkg/routes/api/v2`). ETag = `"<updated.UnixNano>-<maxPermission>"` (`v2/types.go:88-97`). `If-None-Match` returns **304**. Project reads deliberately send no ETag (`v2/projects.go:52`).
- **Writes have no precondition support.** `tasksUpdate` (PUT) declares no `conditional.Params` (`v2/tasks.go:254-273`).
  - Huma autopatch (huma v2.39.1, `go.mod:40`) runs PATCH as an internal **GET** (which strips client conditional headers) → apply the patch → internal **PUT**. It forwards a client `If-Match` to the PUT, or adds the GET's ETag itself, but the PUT handler ignores it.
  - Source for the autopatch behaviour: `github.com/danielgtaylor/huma/v2@v2.39.1/autopatch/autopatch.go`, read upstream, not vendored in this repo.
  - **There is no way to get a 412 on a conflicting edit.**
- **Server-side serialization:** `updateSingleTask` takes a row lock (`lockingSession`) on the task (`tasks.go:1294-1295`). Concurrent writes are therefore **last write wins**, never torn.
- **v1 `POST /api/v1/tasks/{id}` and v2 `PUT` are full replaces.**
  - Columns `title, description, done, due_date, repeat_after, priority, start_date, end_date, hex_color, percent_done, project_id, bucket_id, repeat_mode, cover_image_attachment_id` (`tasks.go:1319-1334`) are overwritten.
  - Zero values clear fields (`tasks.go:1580-1650`).
  - **Assignees are replaced** from the body: an empty list deletes all assignees (`task_assignees.go:64-83`, called at `tasks.go:1314`). **Reminders are replaced** too.
- **v2 `PATCH /api/v2/tasks/{task}`** is the best available primitive. The server merges your patch onto the *current* state, so concurrent edits to other fields survive (field-level LWW).
  - Content types: `application/json-patch+json` (used by the web client, `frontend/src/client/generated/sdk.gen.ts:2436-2452`, body `[{op:"add",path:"/done",value:true}]`, `taskMutations.ts:82-84`), `application/merge-patch+json` / `application/json` (body `{"done":true}`), and `application/merge-patch+shorthand`. Any other type returns 415 (Huma upstream).
  - [I] The web client sends *all* fields in its patch; the app should send only the changed ones.
- **Conflict-detection strategy [I]:**
  - Store each task's last seen `updated` (the base).
  - Before pushing a queued edit, optionally `GET /api/v2/tasks/{id}` with `If-None-Match: "<etag>"`. A 304 means no remote change; with a 200, compare fields for a per-field 3-way merge.
  - On v1 servers, emulate PATCH: GET fresh → overlay local changed fields → POST full object. That narrows the lost-update window to milliseconds.

---

## 7. Rate limits and other server limits relevant for polling [V]
| Limit | Default | Notes | Source |
|---|---|---|---|
| General API rate limit | **disabled** (`ratelimit.enabled=false`) | When enabled: `limit` **100** per `period` **60 s**, `kind` `user` (per user id; unauthenticated requests per IP); store `keyvalue`/memory/redis | `config-raw.json` ratelimit; `pkg/routes/rate_limit.go:20-70,170-185` |
| Headers on every rate-limited response | `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` (unix seconds) | 429 `Too Many Requests` + `Retry-After: <secs>` | `rate_limit.go:46-56,64-69` |
| Unauthenticated routes incl. **WS upgrade** | **10/min/IP** | Cannot be disabled | `ratelimit.noauthlimit` |
| Token refresh / OAuth token endpoint | **60/min/IP** | | `ratelimit.tokenrefreshlimit` |
| CalDAV/feeds Basic-auth failures | 10/min/IP | | `ratelimit.basicauthlimit` |
| Page size | **50** max | | `service.maxitemsperpage` |
| Access-token TTL | **600 s** (`jwtttlshort`) | A background run must normally refresh first | `config-raw.json` service.jwtttlshort |
| Session idle expiry | short sessions 3 days (`jwtttl` 259200), long sessions 30 days (`jwtttllong`) | Sliding, measured from the last refresh (`last_active`). **OAuth sessions are short** (`oauth2server/token.go:145`, `long=false`) | `pkg/modules/auth/auth.go:407-445`, `pkg/models/sessions.go:242-270` |
| Refresh-token rotation | **Strict one-time use**; reuse → `ErrRefreshTokenAlreadyUsed` | Two isolates refreshing concurrently means one gets logged out → must be single-flight | `sessions.go:208-230` |
| `Cache-Control: no-store` | on all `/api/v1` and `/api/v2` responses | Do not rely on HTTP caching; use explicit ETag | `routes.go:383-395` |
| `/info.concurrent_writes` | `false` on SQLite | "Clients should serialize batched writes" → the outbox must send serially | `pkg/routes/api/shared/info.go:59` |

[I] Budget: one background sync on an idle account costs about 1 refresh + ceil(projects/50) + 1 probe + 1 label page + 1 notifications page, i.e. 4-6 requests. Even with the limit enabled that is far below 100/min. **The initial full sync** of 5000 tasks is ≥100 pages. Throttle using `X-RateLimit-Remaining` and honour `Retry-After`.

---

## 8. Idempotency [V]
- There is no `Idempotency-Key` support. Only `X-Request-Id` is generated/propagated for logging (`routes.go:155-157`, `pkg/events/request_meta.go`).
- Task create is **not idempotent**; the server assigns `id` and `index`; the client cannot set `UID`.
- Idempotent-ish errors to treat as success on retry:

| Error | HTTP | Code | Source |
|---|---|---|---|
| Label already on task | 400 | 8001 | `pkg/models/error.go:1816` |
| User already assigned | 400 | 4021 | `error.go:1299` |
| Relation already exists | 409 | 4008 | `error.go:939` |
| DELETE of an already deleted task | 404 | 4002 | `error.go:787` |

- Permanent failures (drop the op and surface it to the user):

| Error | HTTP | Code |
|---|---|---|
| Project does not exist | 404 | 3001 |
| No access to project | 403 | 7003 |
| Project archived | **412** | 3008 |
| Task title empty | 400 | 4001 |
| Invalid filter | 400 | 4016/4019/4024/4033 |

- Auth: 401 with code **11** means the token is invalid or expired (`pkg/routes/api_tokens.go:38`); refresh once, then retry.

---

## 9. Proposed sync design [I]

### 9.1 Capability detection (per account, at login and then daily)
- `GET /api/v1/info` → `version`, `max_items_per_page`, `concurrent_writes`, `caldav_enabled`, `webhooks_enabled`, `enabled_pro_features`, `email_reminders_enabled`.
- `GET /api/v2/info` answers on ≥ 2.4.0 → use the v2 adapter. Otherwise use v1.
- The socket exists on ≥ 2.3.0. Use `/api/v2/ws` when v2 exists, else `/api/v1/ws`.
- Filter-string syntax exists since 0.24.0 [I from CHANGELOG ~6324-6532]. On older servers fall back to full pulls.
- In this source the v1 all-tasks route is `/api/v1/tasks`. [X/unverified] Some older releases exposed `/tasks/all`; probe both.

### 9.2 Local DB (SQLite via drift; WAL; shared by the UI isolate and the background isolate)
```
account(id PK, base_url, api_mode['v1'|'v2'], user_id, username, server_version,
        max_items_per_page, concurrent_writes, tz, settings_json, ws_supported)
sync_state(account_id, scope TEXT /* 'tasks','projects','labels','notifications','project:<id>' */,
           watermark_utc TEXT, last_ok_at, last_full_reconcile_at, extra_json, PK(account_id,scope))

project(id PK, account_id, parent_id, title, description, identifier, hex_color, is_archived,
        is_favorite, position, max_permission, owner_id, blur_hash, created, updated,
        local_task_count_cache, sync_status)            IDX(account_id,parent_id)
project_view(id PK, project_id, title, view_kind, position, filter, bucket_mode,
             default_bucket_id, done_bucket_id, updated)
bucket(id PK, view_id, title, "limit", position, count, updated)
task_bucket(task_id, view_id, bucket_id, PK(task_id,view_id))
task_position(task_id, view_id, position, PK(task_id,view_id))

task(local_id INTEGER PK AUTOINCREMENT,              -- stable local key used by UI/outbox/notifications
     server_id INTEGER UNIQUE NULL,                   -- null until created on server
     account_id, project_id /* server id; or project local id if project pending */,
     idx, identifier, title, description, done, done_at, due_date, start_date, end_date,
     priority, percent_done, hex_color, repeat_after, repeat_mode, cover_attachment_id,
     is_favorite, created_by_id, created, updated /* server */, 
     base_json /* server snapshot at last sync, for 3-way merge */,
     dirty_fields TEXT /* JSON array */, local_modified_at,
     sync_status /* synced|pending_create|pending_update|pending_delete|conflict|create_uncertain */)
  IDX(account_id, done, due_date)            -- today/upcoming/overdue, widget
  IDX(project_id, done)                      -- project lists, count check
  IDX(updated), IDX(sync_status) WHERE sync_status!='synced'
task_reminder(task_local_id, seq, reminder_utc, relative_to, relative_period, PK(task_local_id,seq))
  IDX(reminder_utc)
label(id PK, account_id, title, description, hex_color, created_by_id, updated)
task_label(task_local_id, label_id, PK)
user(id PK, username, name, avatar_etag)
task_assignee(task_local_id, user_id, PK)
task_relation(task_local_id, other_task_server_id, kind, PK)
attachment(id PK, task_local_id, file_name, mime, size, created, local_path NULL)
comment(id PK, task_local_id, author_id, body, created, updated)      -- lazily, per task
notification(id PK, account_id, name, payload_json, read_at, created)  IDX(created DESC)
saved_filter_member(filter_project_id, task_server_id, fetched_at, PK)

outbox(id INTEGER PK AUTOINCREMENT, account_id, entity /*task|label_task|assignee|comment|...*/,
       entity_local_id, op /*create|patch|delete|add|remove|done*/, payload_json,
       base_updated, created_at, attempts, next_attempt_at, last_http, last_code, state /*queued|inflight|failed|done*/)
  IDX(state, next_attempt_at)
scheduled_notif(key TEXT PK /* "<task_local_id>:<kind>:<fire_utc>" */, os_id INTEGER UNIQUE,
                fire_utc, title, kind /* reminder|due|digest */)
```
- References between local rows use `task.local_id`. Outbox payloads refer to `entity_local_id` and resolve `server_id` **at send time**, so no id rewrites are needed after an offline create.
- Ops that depend on a pending create (labels, assignees, comments) block until the parent's `server_id` is known.

### 9.3 Pull
**Initial sync** (foreground, with progress UI, resumable from `sync_state`):
1. `info` → `user` (+ `/user/settings/general`) → all projects (`is_archived=true`, all pages) → all labels → notifications page 1.
2. Tasks, keyset-paged: `GET /api/v2/tasks?filter=id > {lastId}&sort_by=id&order_by=asc&per_page={max}` until fewer than `max` are returned. Do undone tasks first for a fast first paint: `filter=done = false && id > X`, then `done = true && id > X`.
3. Archived projects: `GET /api/v2/projects/{id}/tasks` with the same keyset.
4. Set the `tasks` watermark W = max(`updated`) over all returned items (server time, never the device clock).

**Incremental sync** (every trigger):
1. Refresh the access token if `exp - now < 60 s` (single-flight; see §9.6).
2. **Projects:** pull all pages, diff (new / changed `updated` / missing → purge).
3. **Changed tasks**, keyset on `(updated, id)` to survive concurrent edits and same-second ties:
   `filter=(updated > '{W}') || (updated = '{W}' && id > {lastIdAtW})&sort_by=updated&order_by=asc&sort_by=id&order_by=asc&per_page={max}`.
   - Start from **W − 120 s overlap** to cover the commit lag of long transactions and async `HandleTaskUpdateLastUpdated` bumps.
   - Skip items whose `updated` equals the local row and whose row is not dirty.
   - Use the same query on `/projects/{id}/tasks` for archived changed projects.
4. **Deletes:** the count check per changed project (§3.2), and an id reconciliation on mismatch.
5. **Labels:** full pull (cheap). **Notifications:** page 1+ until a known id appears.
6. **Kanban:** only for views on screen. **Comments:** only for the open task (`expand=comment_count` on demand).
7. On success, advance W. Then recompute the notification schedule (§9.7) and the widget snapshot (§9.8).
8. **Merge rule for incoming tasks:**
   - If the local row is `synced`, overwrite it and replace `base_json`.
   - If it is dirty, run a 3-way merge per field (base vs. local vs. remote):
     - Remote-only changes apply.
     - Local-only changes are kept and stay dirty.
     - If both sides changed a field, the **later wins** (local edit time vs. remote `updated`), except `description`: keep both by storing the losing text in a conflict record and flag the task `conflict` for user review.
   - `done` toggles always take the latest.

**Cheap "anything changed?" probe** (foreground timer, background): `GET /api/v2/tasks?filter=updated > '{W}'&per_page=1` → `total`. If it is 0 and the project list is unchanged, stop. That is 2 requests in total.

### 9.4 Push (outbox)
- Every local mutation is one DB transaction: update the local row, set `dirty_fields`, and append an outbox op. The UI is optimistic.
- **Coalesce** per entity before sending:
  - patch + patch → one patch with the union of fields;
  - create + patch → create with the merged fields;
  - create + delete → drop both;
  - patch + delete → delete.
- **Send serially** in FIFO order (mandatory when `concurrent_writes=false`; simplest in all cases). Calls per op type:
  - create: `POST /api/v2/projects/{pid}/tasks` (v1: `PUT /api/v1/projects/{pid}/tasks`). Store `server_id`, `index`, `identifier`, `updated` from the response.
  - update: `PATCH /api/v2/tasks/{id}` with `Content-Type: application/merge-patch+json` and only the dirty fields. v1: GET → overlay dirty fields → `POST /api/v1/tasks/{id}` with the full object, keeping assignees and reminders from the fresh GET.
  - done (notification action): the same PATCH with `{"done":true}`. Apply the **response** because repeating tasks come back reopened with new dates.
  - delete: `DELETE /tasks/{id}`. A 404 counts as success.
  - labels and assignees: v2 `POST|DELETE /tasks/{id}/labels[/{label}]` and `/tasks/{id}/assignees[/{user}]`; v1 uses `PUT` instead of `POST`.
- **Retry policy:**
  - network/5xx/429: exponential backoff from 2 s to 15 min with jitter; honour `Retry-After` and `X-RateLimit-Reset`.
  - 401 code 11: refresh once, then retry. If the refresh is rejected, pause the outbox and ask for login, but **never discard queued ops**.
  - 4xx permanent errors (§8): mark the op `failed`, roll back or flag the entity, and notify.
- **Uncertain create** (timeout or connection reset after the request was sent): set `create_uncertain`. Before resending, query `GET /api/v2/projects/{pid}/tasks?filter=created >= '{sentAt-60s}' && title = '{escaped title}'` and match `created_by.id == me` (plus `description`). Adopt a match; resend only if none is found.
- After the outbox drains, run an incremental pull. Your own writes come back with server `updated` and server-computed fields such as repeat shifts, relative reminders and `done_at`.

### 9.5 Triggers
- **Foreground:**
  - On app start and resume: incremental sync.
  - While visible: socket events (debounced) plus the cheap probe every 30-60 s, which is also the fallback when the socket is unavailable: < 2.3.0, API token login, rejected token.
  - Pull-to-refresh: full incremental sync, plus kanban/comments for the current screen.
- **Connectivity regained** (connectivity_plus): drain the outbox, then sync.
- **Android background** [X]:
  - WorkManager `PeriodicWorkRequest`. The minimum interval is **15 min**. It runs only in Doze maintenance windows, and App Standby Buckets limit it further: *working_set* ~ ≤2 h, *frequent* ~ ≤8 h, *rare* ~ ≤24 h, *restricted* (Android 12+) about once a day. Use a `NetworkType.CONNECTED` constraint.
  - A one-off expedited `OneTimeWorkRequest` drains the outbox right after a notification/widget action.
  - Run via the `workmanager` Flutter plugin in a background isolate that opens the same drift DB.
- **iOS background** [X]:
  - `BGAppRefreshTask` (via `workmanager`'s iOS support or a native bridge). `earliestBeginDate` is only a hint. The system schedules runs based on app-usage patterns: often a few per day for frequently used apps, **possibly never** for rarely opened ones. **There are no runs after the user force-quits the app**, and none in Low Power Mode or with Background App Refresh disabled. Each run has about **30 s**, so do the probe plus a small delta and finish.
  - `BGProcessingTask` (minutes, typically overnight while charging) for full reconciliation.
  - **Silent/remote push is impossible:** Vikunja has no push service, and APNs requires the app publisher's key on a server the publisher runs.
  - Be honest in the UI: show "last synced X ago" and sync on open.
- **Session keep-alive:** the OAuth session expires after **3 days without a refresh** (§7). Background runs refresh it as a side effect. On iOS, if the user doesn't open the app for 3 days and no background run occurred, re-login is required. Prefer a long session where the login flow supports it. That is the auth topic's call.

### 9.6 Token handling across isolates
- **Single-flight refresh** guarded by a DB lock row (or a file lock) shared by the UI isolate, the WorkManager isolate and the notification-action isolate.
- Write the rotated refresh token to secure storage **before** using the new access token. Rotation is strict one-time use (`sessions.go:208-230`), so a lost write means a logout.
- Background runs must not refresh at all if the foreground holds a fresh token (read it from shared secure storage).
- When the socket is open and the token refreshes, send `{"action":"auth","token":new}`. This is the same session (`sid`), so the server accepts it (§1.2).

### 9.7 Local notification scheduler (reads only the local DB)
- **Source:** `task_reminder.reminder_utc > now` and `due_date` (an app setting such as "at due time" or "N min before"), for tasks with `done = 0`, `sync_status != pending_delete`, and the user is the creator or an assignee. That mirrors the server's recipients minus subscribers; subscription state is only on single reads.
- Optional "daily overdue digest" at the user's `overdue_tasks_reminders_time` when `overdue_tasks_reminders_enabled` is set. The server only e-mails it.
- **Diff-based:** compute the desired set, diff it against `scheduled_notif`, cancel the stale ones and schedule the new ones. Run the diff after every sync, every local edit and boot (`RECEIVE_BOOT_COMPLETED`; flutter_local_notifications reschedules on boot), and after a timezone change. Store absolute UTC instants and schedule as instants (`zonedSchedule` with the `timezone` package); due dates are absolute.
- **iOS cap** [X]: max **64 pending** local notifications. Schedule the nearest ~60 and refill on each sync, app open and BG run.
- **Android** [X]:
  - Exact alarms need `SCHEDULE_EXACT_ALARM`, which Android 14+ does not pre-grant to new installs; the user must allow it. `USE_EXACT_ALARM` is restricted by Play policy to alarm/calendar apps. Fall back to inexact `AndroidScheduleMode.inexactAllowWhileIdle`, which can be minutes late in Doze.
  - About 500 concurrent alarms per app; keep only the next N.
  - `POST_NOTIFICATIONS` runtime permission on Android 13+.
- **"Mark done" action** [X + I]:
  - Android: a notification action handled by a background handler (`onDidReceiveBackgroundNotificationResponse`, separate isolate).
  - iOS: `UNNotificationAction` without the `.foreground` option, giving a few seconds of background execution.
  - Steps:
    1. Write the local done state and an outbox op.
    2. Cancel the task's other notifications.
    3. Try the PATCH immediately. On Android, also enqueue expedited work.
    4. When the response shows a repeating task reopened, reschedule from the response dates.
  - Also offer "Snooze 10 min / 1 h" as a **local-only** reschedule. Optionally persist it as a new absolute reminder via PATCH.
- **De-duplicate** server `task.reminder` socket events (foreground) against the local notifications, by task id within ±2 min.

### 9.8 Home widget (reads a precomputed snapshot, never the network)
- After each sync, local mutation or midnight tick, the app (or the BG isolate) computes per-widget-config lists from the DB and writes compact JSON into shared storage via `home_widget`: Android SharedPreferences; iOS **App Group** UserDefaults/container, because the WidgetKit extension cannot run Dart or open the drift DB easily.
- **Configs:**
  - today: due today, or overdue and undone;
  - upcoming N days;
  - overdue;
  - project X (incl. subprojects);
  - label X;
  - favorites;
  - saved filter X (from `saved_filter_member`, last server result).
- Include ~48 h of items with their due instants so the timeline can roll "today → overdue" without the app (iOS: multiple `TimelineEntry`s at boundary times).
- **Refresh** [X]:
  - Android: `AppWidgetManager` updates pushed by the app; `updatePeriodMillis` minimum 30 min.
  - iOS: `WidgetCenter.reloadTimelines` after a sync. The daily reload budget is roughly a few dozen; reloads while the app is in the foreground are generally not counted.
- **Interactive "mark done"** [X]: on Android via a `home_widget` background callback (Dart isolate); on iOS 17+ via an AppIntent (home_widget's interactivity callback). Both write the outbox and update the snapshot immediately.

### 9.9 Edge cases checklist
- Project archived on the server → its tasks vanish from `/tasks`. Keep them read-only and pull them via `/projects/{id}/tasks`. A write returns 412/3008.
- Task moved to a project the user can't read → it is absent from all lists and the GET returns 403/404 → delete locally.
- Server timezone ≠ device timezone: parse all RFC3339 values to UTC. Send filter dates as UTC `Z` strings; `filter_timezone` only matters for datemath like `now/d`.
- Relative reminders edited offline: recompute `reminder` = base date + `relative_period` locally, and take the server value on the next pull.
- Description format: v1 returns HTML; v2 accepts and returns Markdown with `format=markdown`. Store one canonical format and always send the same `format`.
- Multi-account: every table carries `account_id`. Socket, outbox and watermarks are per account.
- Favorites (−1) and saved filters (< −1) are not real projects: never write tasks to them, never count-check them.

---

## 10. Open questions to verify empirically
1. Whether `updated` advances on a bucket move that changes `done` (xorm auto-update with `Cols(...)`). Strongly implied by `tasks.go:1660-1667`, but untested.
2. `filter=updated >= '2026-…Z'` parsing through datemath vs. RFC3339 on MySQL, Postgres and SQLite. Write a quick integration test against a dev server.
3. Whether a native Dart WebSocket without `Origin` is accepted when `cors.enable=true` with an origin list.
4. Exact v1 repeated-param syntax for `sort_by` (`sort_by=a&sort_by=b` vs `sort_by[]=`) on older servers.
5. The v1 all-tasks path on pre-1.0 servers (`/tasks` vs `/tasks/all`).
