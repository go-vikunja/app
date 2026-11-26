import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';

import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 10, 20, 9);
  const alice = User(id: 7, username: 'alice', name: 'Alice');
  final updated = DateTime.utc(2026, 10, 2);
  final listView = sampleListView(id: 11, projectId: 1);
  final kanban = sampleKanbanView(id: 12, projectId: 1);
  final work = Project(
    id: 1,
    title: 'Work',
    description: '<p>Office</p>',
    identifier: 'WRK',
    hexColor: '1973ff',
    position: 2,
    owner: alice,
    views: [listView, kanban],
    updated: updated,
  );
  final reports = sampleProject(
    id: 2,
    title: 'Reports',
    parent: 1,
    views: [sampleListView(id: 21, projectId: 2)],
  );
  final drafts = sampleProject(id: 3, title: 'Drafts', parent: 2);
  final home = sampleProject(
    id: 4,
    title: 'Home',
    views: [sampleListView(id: 41, projectId: 4)],
  );

  setUp(() async {
    db = testDatabase();
    await db.projectsDao.upsertAll([work, reports, drafts, home]);
  });

  Future<Project?> stored(int id) => db.projectsDao.loadProject(id);

  test('one project loads with its views and owner', () async {
    final found = (await stored(1))!;

    expect(found, work);
    expect(found.owner, alice);
    expect(found.views.map((v) => v.id), [11, 12]);
    expect(await stored(99), isNull);
  });

  test('a subtree is the project and every project below it', () async {
    expect(await db.projectsDao.subtreeOf(1), {1, 2, 3});
    expect(await db.projectsDao.subtreeOf(2), {2, 3});
    expect(await db.projectsDao.subtreeOf(4), {4});
    expect(await db.projectsDao.subtreeOf(99), {99});
  });

  group('an edit', () {
    test('writes only the given fields and keeps updated', () async {
      await db.projectsDao.updateProject(1, title: 'Office');

      final edited = (await stored(1))!;
      expect(edited.title, 'Office');
      expect(edited.identifier, 'WRK');
      expect(edited.hexColor, '1973ff');
      expect(edited.description, '<p>Office</p>');
      expect(edited.updated, updated);
      expect(edited.views.map((v) => v.id), [11, 12]);

      await db.projectsDao.updateProject(
        1,
        hexColor: '',
        parentProjectId: 4,
        isFavorite: true,
      );

      final again = (await stored(1))!;
      expect(again.hexColor, '');
      expect(again.parentProjectId, 4);
      expect(again.isFavorite, isTrue);
      expect(again.title, 'Office');
      expect(again.position, 2);
    });

    test("of the identifier renames the project's server tasks, by "
        'index', () async {
      await db.tasksDao.upsertAll([
        sampleTask(
          id: 31,
          title: 'One',
          identifier: 'WRK-4',
        ).copyWith(index: 4),
        sampleTask(
          id: 32,
          title: 'Two',
          identifier: 'WRK-5',
        ).copyWith(index: 5),
        sampleTask(id: 33, title: 'Elsewhere', projectId: 4, identifier: 'H-1'),
      ]);
      final local = await db.outboxDao.queueCreate(
        const NewTask(projectId: 1, title: 'Unsent'),
        now: now,
      );

      await db.projectsDao.updateProject(1, identifier: 'NEW');

      Future<String> identifierOf(int id) async =>
          (await db.tasksDao.findRow(id))!.identifier;
      expect(await identifierOf(31), 'NEW-4');
      expect(await identifierOf(32), 'NEW-5');
      expect(await identifierOf(33), 'H-1');
      expect(await identifierOf(local), '');
      expect((await stored(1))!.identifier, 'NEW');

      await db.projectsDao.updateProject(1, identifier: '');

      expect(await identifierOf(31), '#4');
      expect(await identifierOf(32), '#5');
    });
  });

  test('archiving cascades to every project below, and so does '
      'unarchiving', () async {
    final archived = await db.projectsDao.setArchived(1, archived: true);

    expect(archived, {1, 2, 3});
    for (final id in [1, 2, 3]) {
      expect((await stored(id))!.isArchived, isTrue, reason: '$id');
      expect((await stored(id))!.updated, id == 1 ? updated : null);
    }
    expect((await stored(4))!.isArchived, isFalse);

    await db.projectsDao.setArchived(3, archived: false);
    expect((await stored(3))!.isArchived, isFalse);
    expect((await stored(2))!.isArchived, isTrue);

    await db.projectsDao.setArchived(3, archived: true);
    await db.projectsDao.setArchived(1, archived: false);
    for (final id in [1, 2, 3]) {
      expect((await stored(id))!.isArchived, isFalse, reason: '$id');
    }
  });

  group('purging confirmed deleted projects', () {
    test('removes the projects, their views, boards and snapshots and '
        'returns their ids', () async {
      final loadedAt = DateTime.utc(2026, 10, 19);
      await db.tasksDao.upsertAll([
        sampleTask(id: 31, title: 'In work'),
        sampleTask(id: 41, title: 'At home', projectId: 4),
      ]);
      await db.listSnapshotsDao.replace('view:11', {31: 1}, loadedAt: loadedAt);
      await db.listSnapshotsDao.replace('view:41', {41: 1}, loadedAt: loadedAt);
      await db.kanbanDao.replaceBoard(
        12,
        buckets: [
          const Bucket(id: 5, viewId: 12, title: 'To-Do', position: 100),
        ],
        slots: {31: (bucketId: 5, position: 1)},
        loadedPages: const {},
        loadedAt: loadedAt,
      );

      final purgedViews = await db.projectsDao.purgeDeletedProjects({1, 2, 3});

      expect(purgedViews, {11, 12, 21});
      expect((await db.projectsDao.loadAll()).map((p) => p.id), [4]);
      expect(await db.projectsDao.loadView(11), isNull);
      expect(await db.projectsDao.loadView(21), isNull);
      expect((await db.listSnapshotsDao.load('view:11')).loadedAt, isNull);
      expect(await db.kanbanDao.buckets(12), isEmpty);
      expect(await db.tasksDao.findRow(31), isNull);
      expect(await db.tasksDao.findRow(41), isNotNull);
      expect((await db.listSnapshotsDao.load('view:41')).positions, {41: 1});
    });

    test('removes queued work only for confirmed gone tasks and cancels '
        'creates', () async {
      await db.tasksDao.upsertAll([
        sampleTask(id: 31, title: 'Edited'),
        sampleTask(id: 32, title: 'Deleted', projectId: 2),
        sampleTask(id: 33, title: 'Moved in', projectId: 4),
        sampleTask(id: 41, title: 'At home', projectId: 4),
      ]);
      await db.outboxDao.queueUpdate(
        31,
        const TaskChanges(title: 'Edited again'),
        now: now,
      );
      await db.outboxDao.queueDelete(32, now: now);
      await db.outboxDao.queueUpdate(
        33,
        const TaskChanges(projectId: 3),
        now: now,
      );
      await db.outboxDao.queueUpdate(
        41,
        const TaskChanges(title: 'Home edit'),
        now: now,
      );
      final created = await db.outboxDao.queueCreate(
        const NewTask(projectId: 3, title: 'Unsent'),
        now: now,
      );

      final memberships = await db.tasksDao.queuedMembershipsInProjects({
        1,
        2,
        3,
      });
      await db.projectsDao.purgeDeletedProjects(
        {1, 2, 3},
        checkedTasks: {
          for (final membership in memberships)
            if (membership.id != 33) membership: null,
        },
      );

      expect(await db.tasksDao.findRow(31), isNull);
      expect(await db.tasksDao.findRow(32), isNull);
      expect(await db.tasksDao.findRow(created), isNull);
      // The server has it in project 4 still; its op fails and a discard
      // brings it back.
      expect((await db.tasksDao.findRow(33))!.projectId, 3);
      expect(await db.tasksDao.findRow(41), isNotNull);
      final queued = {for (final op in await db.outboxDao.all()) op.taskId};
      expect(queued, {33, 41});
    });

    test('keeps an uncertain create whose request went to a surviving '
        'project, though a later move named a deleted one', () async {
      final sentElsewhere = await db.outboxDao.queueCreate(
        const NewTask(projectId: 4, title: 'Lost answer'),
        now: now,
      );
      final sentHere = await db.outboxDao.queueCreate(
        const NewTask(projectId: 3, title: 'Gone with it'),
        now: now,
      );
      for (final id in [sentElsewhere, sentHere]) {
        final create = (await db.outboxDao.all()).singleWhere(
          (op) => op.taskId == id,
        );
        await db.outboxDao.markUncertain(create.id, sentAt: now);
      }
      await db.outboxDao.queueUpdate(
        sentElsewhere,
        const TaskChanges(projectId: 3),
        now: now,
      );

      await db.projectsDao.purgeDeletedProjects({1, 2, 3});

      expect(await db.tasksDao.findRow(sentElsewhere), isNotNull);
      expect(await db.tasksDao.findRow(sentHere), isNull);
      expect((await db.outboxDao.all()).map((op) => op.taskId).toSet(), {
        sentElsewhere,
      });
    });

    test("keeps a repeating task's schedule notice: its task is checked "
        'with queued work, not evicted', () async {
      final review = sampleTask(id: 34, title: 'Weekly review');
      await db.tasksDao.upsertAll([review]);
      await db.outboxDao.queueUpdate(
        34,
        const TaskChanges(done: true, title: 'Weekly retro'),
        now: now,
      );
      await db.outboxDao.settleDone(
        (await db.outboxDao.all()).single,
        const TaskChanges(),
        review,
        unmatched: const TaskChanges(title: 'Weekly retro'),
      );
      expect((await db.tasksDao.findRow(34))!.pendingChanges, isNull);

      final memberships = await db.tasksDao.queuedMembershipsInProjects({
        1,
        2,
        3,
      });
      expect(memberships.map((m) => m.id), [34]);

      // Unverified: the row and its notice stay.
      await db.projectsDao.purgeDeletedProjects({1, 2, 3});

      expect(await db.tasksDao.findRow(34), isNotNull);
      final notice = (await db.outboxDao.loadProblems()).single;
      expect(notice.taskId, 34);
      expect(isRecurringScheduleConflict(notice.failure), isTrue);
    });

    test('an evicted task loses its own edges, but edges to it stay: '
        'eviction does not prove it gone', () async {
      final evicted = sampleTask(id: 31, title: 'Maybe moved');
      final home = sampleTask(id: 41, title: 'At home', projectId: 4);
      await db.tasksDao.upsertAll([
        evicted.copyWith(
          relatedTasks: {
            TaskRelationKind.related: [home],
          },
        ),
        home.copyWith(
          relatedTasks: {
            TaskRelationKind.related: [evicted],
          },
        ),
      ]);

      await db.projectsDao.purgeDeletedProjects({1, 2, 3});

      expect(await db.tasksDao.findRow(31), isNull);
      final edges = {
        for (final row in await db.select(db.taskRelations).get())
          (row.taskId, row.otherTaskId),
      };
      expect(edges, {(41, 31)});
    });
  });

  group('views', () {
    test('one is added or replaced as answered', () async {
      const gantt = ProjectView(
        id: 13,
        projectId: 1,
        title: 'Timeline',
        kind: ProjectViewKind.gantt,
        position: 500,
      );
      await db.projectsDao.putView(gantt);

      expect((await stored(1))!.views.map((v) => v.id), [11, 12, 13]);

      await db.projectsDao.putView(
        const ProjectView(
          id: 11,
          projectId: 1,
          title: 'Everything',
          kind: ProjectViewKind.list,
          position: 600,
        ),
      );

      final views = (await stored(1))!.views;
      expect(views.map((v) => v.id), [12, 13, 11]);
      expect(views.last.title, 'Everything');
      expect(views.last.filter, isNull);
    });

    test('one is removed with its board and snapshot', () async {
      final loadedAt = DateTime.utc(2026, 10, 19);
      await db.listSnapshotsDao.replace('view:11', {31: 1}, loadedAt: loadedAt);
      await db.kanbanDao.replaceBoard(
        12,
        buckets: [
          const Bucket(id: 5, viewId: 12, title: 'To-Do', position: 100),
        ],
        slots: const {},
        loadedPages: const {},
        loadedAt: loadedAt,
      );

      await db.projectsDao.removeView(12);

      expect((await stored(1))!.views.map((v) => v.id), [11]);
      expect(await db.kanbanDao.buckets(12), isEmpty);
      expect((await db.listSnapshotsDao.load('view:11')).loadedAt, loadedAt);

      await db.projectsDao.removeView(11);

      expect((await db.listSnapshotsDao.load('view:11')).loadedAt, isNull);
    });
  });
}
