# Subscriptions and reminders in Vikunja 2.8.0

Research of **2026-11-09** for step 37g ([D80](../decisions.md#d80-reminders-as-the-server-sends-them-on-vikunja-280-and-later-the-phone-notifies-about-the-tasks-the-user-follows-the-follow-state-kept-per-task-from-single-reads-and-per-project-from-the-project-lists-d17-for-older-servers-and-guests)). Verified live on throwaway `vikunja/vikunja:2.8.0` servers with fresh users: owners, followers, assignees, users with read and write shares, a user who lost access, and link shares; two reminder probes with 13 users in all. The 2.8.0 server source was read for behaviour only (AGPL, nothing copied), and 2.7.1's for comparison. The web says subscribe and unsubscribe; the app says follow and unfollow ([glossary](../glossary.md)). The contract tests `packages/vikunja_api/test/contract/relations_subscriptions_contract_test.dart` and `app/test/contract/subscription_reminders_contract_test.dart` check the parts the app relies on.

## Who gets a reminder

- **Only a task's resolved subscribers.** For each user the server takes the first subscription row it finds:
  1. the user's own row on the task;
  2. the user's row on the task's project;
  3. the user's rows on the project's ancestors, nearest first.
- **An opt-out wins.** A muted own row on the task (an opt-out) is found first and drops the user, whatever the projects above say.
- **Only active users who are not bots and can read the project** are reminded (the status filter for subscribers is new in 2.8.0).
- **The tasks:** only those that are not done, not in the bin and not in a project in the bin (the last is new in 2.8.0).
- **Timing:** the cron runs at second 00 of every minute and sends each reminder due in [now, now + 60 s), so a reminder arrives up to 59 s early. A reminder at 14:10:30 was stored at 14:10:00.
- **What is sent:** an in-app notification `task.reminder` is always stored (its `reminder` field is null); an e-mail follows only when the server sends reminder e-mails and the user has `email_reminders_enabled`.
- **Due dates:** there is no due-date notification. The daily overdue e-mail (at the user's `overdue_tasks_reminders_time`, with `overdue_tasks_reminders_enabled` and a mailer) goes to the same recipients and is never stored as an in-app notification; the mail tells assigned tasks from followed ones. It was read in the source, not checked live: the test servers have no mailer.
- **2.7.1** sent to the union of the active assignees, the active creator and the subscribers, so creators and assignees were reminded even after they unfollowed.

## The live results

All tasks had a reminder in the same minute, in a project owned by the owner, shared with the others.

| Case | Reminded |
|---|---|
| The creator, still following | yes |
| The creator who unfollowed (the project not followed) | no |
| An assignee | yes |
| An assignee who unfollowed | no |
| An assignee who was unassigned again | yes: the row stays |
| A follower of the project, for a task in it or in a subproject | yes |
| A follower of the project who opted out of the task | no |
| The project owner, for a task someone else created, not following | no |
| A user with a read share, not following | no |
| A user who followed the task and then lost access | no |
| Anyone, for a done task | no |

## Rows the server creates on its own

- **The creator and every new assignee** get an own row on the task unless they already have one: the creator on every create (v1 and v2, with assignees too), but only a user, never a link share; an assignee through every path (the assignee routes, bulk assignees, a task update or a create with assignees).
  - 2.8.0 ignores inherited subscriptions here: a creator or assignee who follows the project still gets an own row. 2.7.1 skipped the row then, and such tasks read the project's subscription.
- **An opt-out stays.** A user who opted out and is then assigned stays silent.
- **Unassigning keeps the row,** so an ex-assignee is still reminded.
- **Losing access** to a project (a share removed) deletes the user's assignments and their task and project rows in that project and its subprojects.
- **No other rows:** the project owner is not subscribed to tasks others create, a task a link share creates has no subscriber, and creating a project subscribes nobody.
- **The upgrade to 2.8.0** gave every creator and assignee without an own row one, tasks in the bin included. On 2.7.1 unfollowing one's own or assigned task in a project nobody followed deleted the row and stored no opt-out, so the upgrade follows those tasks again. Opt-outs stay. Reproduced by rolling the migration back and running it again.

## Following and unfollowing

- **Routes:** v1 `PUT /subscriptions/{task|project}/{id}` answers 201 with `{id, entity, entity_id, created}` and `DELETE` 200 with a message; v2 `POST` answers 201 with the subscription and `DELETE` 204 without a body. v2 has no `PUT` (405), and `GET` on these paths is 405 on both versions.
- **Unfollow:** `DELETE` removes the user's own row. When a parent still covers the item (the task's project or an ancestor, or a parent project of a project), it stores an opt-out instead. So unfollowing one's own task deletes the row when the project is not followed, and stores an opt-out when it is. With nothing to delete (an opt-out already stored, or no row and nothing inherited) the answer is 403 (v1 code 0, v2 without a code).
- **Follow:** subscribing lifts an opt-out (201, with the opt-out row's id and a new `created`). Already subscribed, by an own row or through any parent, is 412 code 12002. A read share is enough to follow.
- **Other answers:**
  - an unknown task is 404 code 4002; an unknown entity v1 412 code 12001, v2 422 on `path.entity`; no access 403 (v1 code 0, v2 without a code);
  - following a task in the bin is 404 code 4040, a task in a project in the bin 404 code 3018; unfollowing a task in the bin is 200 while the user holds an own row, which is then gone after a restore, and 404 code 4040 without one;
  - link shares get 403 code 1 on both versions; API tokens get 401 code 11, because the subscriptions are not among a token's permissions (a task read with a token still carries the subscription).

## Where the state shows

- **The shape** is `subscription: {id, entity: "task" | "project", entity_id, created}`. The key is absent, never null, when the user does not follow, and the opt-out flag is never sent. `created` has seconds in reads and nanoseconds in a subscribe answer.
- **An inherited subscription** shows the winning project row: `entity: "project"` and `entity_id` naming the project that holds it, possibly a grandparent.
- **Tasks: only single reads carry it,** v1 and v2 `GET /tasks/{id}` (with or without `expand`), v2 `GET /projects/{p}/tasks/by-index/{i}` and the v2 restore answer.
  - No list carries it (v1 `/tasks`, the views' tasks and buckets; v2 `/tasks`, a project's tasks, the views' tasks and bucket tasks), and neither do the create answers and the v1 update answer.
  - As an `expand` it is refused with 422; as a filter (`subscription = 1`, `subscribed = true`) with 400 code 4016.
  - The v2 `PUT` answer echoes whatever `subscription` the request body held, a made-up one included. The v2 `PATCH` answer shows the server's state, because the patch reads the task first; neither is a source to rely on.
- **Projects: the lists carry it too.** Both project lists (v1 and v2, with `expand=permissions` too) and the single reads carry each project's resolved subscription, although the OpenAPI text names the single read only. 2.7.1's lists carry it as well.
  - A child or grandchild of a followed project names the followed one.
  - An opted-out child shows nothing, and so do its tasks and subprojects; an own row further down wins again (a followed grandchild under an opted-out child names itself).
  - The answer to creating a project has none.

## What a sync cannot see

- Following, unfollowing and opt-outs bump neither the task's nor the project's `updated`. Assigning someone does.
- The v2 ETag (`updated` and the permission) stays the same, so a conditional read answers 304 and keeps a stale subscription. The v2 project read sends no ETag for this reason.
- No event, webhook or websocket message is sent.
- No route lists a user's subscriptions (`GET /subscriptions` is 404 on both versions), `/user` has none, and the data export has none.
- So the project lists are the only source in bulk, for the resolved state of every project. A task's own row or opt-out needs a single read of that task.
