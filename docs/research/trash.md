# The trash of Vikunja 2.8.0

Research of **2026-11-09** for step 37f ([D79](../decisions.md)). Verified live on throwaway `vikunja/vikunja:2.8.0` servers with an owner, users with write, read and admin shares, a user without access, and read, write and admin link shares; the purge cron was checked with backdated rows. The web's behaviour was read from the frontend source at tag v2.8.0 for behaviour only (AGPL, nothing copied). The captured answers are in `packages/vikunja_api/test/fixtures/trash/`.

## Routes

- On `/api/v2` only:
  - Tasks: `GET /tasks/deleted`, `GET /tasks/deleted/count`, `DELETE /tasks/deleted?include_others=`, `POST /tasks/{id}/restore`, `DELETE /tasks/{id}/permanent`.
  - Projects: `GET /projects/deleted`, `GET /projects/deleted/count`, `DELETE /projects/deleted?include_others=`, `POST /projects/{id}/restore`, `DELETE /projects/{id}/permanent`, and `GET /projects/{id}/count`.
- `/api/v1` has none of them: `GET` and `DELETE /api/v1/tasks/deleted` read `deleted` as a task id (400 code 2004, nothing is emptied), and the restore, purge and count paths answer a bare 404. On 2.7.1 the v2 restore answers a bare 404 and `GET /api/v2/tasks/deleted` 422.
- `/info` has no trash field, and the server sends no other flag. The trash is known only from the version: v2 and 2.8.0 or newer. The web ships with its server and does not check either.
- `/routes` names the API token permissions `deleted`, `deleted_count`, `deleted_delete`, `permanent` and `restore` for tasks, and the same plus `count` for projects.

## Lists

- The envelope is `{items, total, page, per_page, total_pages}`: `items` is never null, `total_pages` is 0 when empty, and there are no paging headers and no ETag.
- `page` starts at 1; a page past the end is 200 with no items. `per_page` defaults to and is capped silently at `/info`'s `max_items_per_page` (50 by default). 0, negative or non-numeric values are 422 without a code. Other parameters, `q` and `sort_by` among them, are ignored.
- The order is newest deletion first (`deleted_at` descending, then id). `deleted_at` is UTC with seconds.
- **Tasks:** every trashed task in a project where the caller may write, through ownership, a user or team share, or a parent project. Hidden: tasks in an archived project or under an archived ancestor (they show again after unarchiving), and tasks whose project is itself in the trash (they show again after its restore).
  - Each item is the v2 task plus `deleted_at`, `deleted_by` and `can_delete_permanently` (the caller is admin of the task's project). `related_tasks` and `attachments` are listed; comments and the subscription are not. `bucket_id` and `position` are 0, and `updated` keeps its value from before the delete.
- **Projects:** only the topmost trashed projects the caller is admin of; writers and readers get an empty list. Archived projects can be trashed and are listed. A trashed subproject is folded into its topmost trashed ancestor as `trashed_sub_projects: [{id, title, parent_project_id, depth}]`, depth 1 below the listed project, shallowest first; the field is absent when there are none.
- `deleted_by` is `{id, name, username, created, updated}`, never an email, and absent when the deleter is unknown. A link share's deletion names `{id: -shareId, username: "link-share-<shareId>"}` with the share's name followed by " (Link Share)" as `name`, or "Link Share" alone for an unnamed share; the negative id is what marks a link share.
- Link shares get 403 code 1 on the lists, the counts and the empties, whatever their permission.

## Counts and emptying

- `…/deleted/count` answers `{total, by_others}` and counts exactly what emptying would purge: items in projects where the caller is admin. A writer whose list shows tasks gets `{0, 0}`. `by_others` counts items deleted by someone else, by a link share, or by nobody known.
- `DELETE …/deleted` answers 204 without a count. `include_others` defaults to true; with false only the caller's own deletions go. Only items in projects where the caller is admin go: a writer's empty is a 204 that changes nothing, and tasks in archived projects stay.

## Restore

- **Task:** 200 with the v2 task (labels, assignees, reminders, attachments, relations and the caller's subscription included). Its `updated` and its project's are set to the restore time. It goes to the default bucket, or the done bucket when done, at a new top position. Write permission is enough, write and admin link shares included.
  - A live task: 409 code 4042, for anyone who can read it, so a second restore answers 4042. Unknown, purged or unreadable: 404 code 4002. Read only: 403 without a code. Archived project or ancestor: 412 code 3008. Project in the trash: 404 code 3018.
- **Project:** 200 with the v2 project, views included. Every trashed descendant comes back, whenever it was trashed; tasks trashed on their own stay in the trash and are listed again. `updated` is bumped on every restored project and its tasks; shares, link shares, views and buckets come back; an archived project stays archived. Admin only.
  - A live, unknown or unreachable project: 404 code 3001 (there is no "not in the trash" code for projects). Writer or reader: 403 without a code. Parent in the trash: 412 code 3019 (also for a grandchild). Parent archived: 412 code 3016.
- **The default project:** trashing one's own default project sets the default to none, and a restore does not set it back. Trashing someone else's default project is 412 code 3012.

## Permanent delete

- **Task:** 204, admin of the project only; writers, readers and every link share get 403 without a code. A live, unknown or purged task is 404 code 4002 (not 4042). Archived project: 412 code 3008. Inside a trashed project: 404 code 3018.
- **Project:** 204, removing the subtree with every task, trashed ones included. A live, unknown or unreachable project is 404 code 3001, and so is a second purge; afterwards its tasks answer 4002.

## Reads of trashed items

- A trashed task answers every task route with 404 code 4040 and `details: {id, project_id, deleted_at, deleted_by?, can_restore}`, on v1 and v2 alike, to everyone who can read its project. `can_restore` is true with write permission in a project that is not archived.
- A task or project inside a trashed project answers 404 code 3018 with the project's details: `{id, deleted_at, deleted_by?, can_restore, trashed_root_id?, can_restore_root}`. Below a trashed root `can_restore` is false, `trashed_root_id` names the root and `can_restore_root` is true for its admin. Under an archived parent both are false and no root is named.
- A caller without access gets 4002 or 3001.
- The delete answers are unchanged (v2 204, v1 200) and never say that the item went to the trash.
- A trashed project keeps its identifier: a new project with the same identifier is 400 code 3007 until the purge.

## Retention

- 30 days after each item's own `deleted_at`, hard-coded on the server, not configurable and not reported anywhere but the OpenAPI descriptions. The web hard-codes it too.
- The purge runs hourly, tasks at minute 0 and projects at minute 30, so an item lives up to an hour longer and answers 4040 or 3018 until then. A subproject trashed before its root is purged on its own date, although the list shows only the root's.
- Restores and purges send no notification.

## The web (read for behaviour)

- A Trash entry is the last item of the main menu, for every signed-in user; link-share guests have no menu. The page has a Tasks and a Projects tab, each with its own Empty button, disabled when the tab is empty.
- Rows are not clickable. A task row shows the task line, who deleted it and how long ago, and the days left (rounded up, never below 0, "today" at 0), with Restore and, when allowed, Delete forever. A project row can expand its trashed subprojects by depth.
- Restore needs no confirmation; Delete forever and Empty ask first. Empty reads the count when its dialog opens, says how many items others moved there and offers a checkbox, on by default, to include them.
- A task delete is no longer confirmed: the task goes to the trash at once and a 10-second message offers Undo, which restores it. A project delete is confirmed with the counts of `GET /projects/{id}/count` and also offers Undo.
- A link to a trashed task shows a box saying so, with who deleted it, the days left and, for users with `can_restore`, Restore; link-share guests get no button. For 3018 the box offers to restore the project or its trashed root.
- The inbox's "task deleted" entry links nowhere.
