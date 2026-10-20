import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/local/local_list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/local/local_project_view_repository.dart';
import 'package:vikunja_mobile/core/repositories/project_view_repository.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late RecordingSyncEngine sync;
  late FakeWriteClient server;
  late FakeSyncClient read;
  late LocalProjectViewRepository repository;
  final now = DateTime.utc(2026, 10, 20, 12);
  final list = sampleListView(id: 11, projectId: 1);
  final board = sampleKanbanView(id: 12, projectId: 1);
  final work = sampleProject(id: 1, title: 'Work', views: [list, board]);
  final tasks = [
    sampleTask(id: 31, title: 'Open'),
    sampleTask(id: 32, title: 'Done', done: true),
  ];

  setUp(() async {
    db = testDatabase();
    sync = RecordingSyncEngine();
    server = FakeWriteClient(clock: () => now);
    read = FakeSyncClient()..allTasks = tasks;
    repository = LocalProjectViewRepository(
      db,
      sync,
      server,
      read,
      perPage: 50,
      now: () => now,
    );
    await db.projectsDao.upsertAll([work]);
    await db.tasksDao.upsertAll(tasks, syncRunId: 'run');
    server.serverProjects[1] = work;
    // What the sync after a write would read from the server.
    sync.onRefreshAfterWrite = () async {
      read.allProjects = [...server.serverProjects.values];
      for (final MapEntry(key: viewId, value: buckets)
          in server.serverBuckets.entries) {
        read.viewBuckets[viewId] = [...buckets.values];
      }
    };
  });

  Future<List<ProjectView>> storedViews() async =>
      (await db.projectsDao.loadProject(1))!.views;

  test('a new view goes last unless placed, is stored as answered, and its '
      'list is downloaded after the sync', () async {
    final id = await repository.createView(
      1,
      const ViewDraft(
        title: ' Done ',
        kind: ProjectViewKind.list,
        filter: ViewFilter(filter: 'done = true'),
      ),
    );
    await pumpEventQueue();

    expect(server.requests, ['create view project 1 Done list']);
    final created = (await storedViews()).last;
    expect(created.id, id);
    expect(created.title, 'Done');
    expect(created.position, 400 + 65536.0);
    expect(created.filter?.filter, 'done = true');
    expect(sync.refreshAfterWriteCalls, 1);
    expect((await db.listSnapshotsDao.load('view:$id')).positions.keys, [32]);
  });

  test("a new board without a mode becomes manual with the server's "
      'columns, downloaded after the sync', () async {
    final id = await repository.createView(
      1,
      const ViewDraft(title: 'Sprint', kind: ProjectViewKind.kanban),
    );
    await pumpEventQueue();

    final created = (await storedViews()).last;
    expect(created.bucketConfigurationMode, BucketConfigurationMode.manual);
    expect(created.defaultBucketId, isNot(0));
    expect((await db.kanbanDao.buckets(id)).map((b) => b.title), [
      'To-Do',
      'Doing',
      'Done',
    ]);
  });

  test('an edit sends the draft, stores the answer and downloads the list '
      'again', () async {
    await db.listSnapshotsDao.replace('view:11', {31: 1}, loadedAt: now);

    await repository.updateView(
      1,
      11,
      const ViewDraft(title: 'Everything', kind: ProjectViewKind.list),
    );
    await pumpEventQueue();

    expect(server.requests, ['update view 11 project 1 Everything list']);
    final edited = (await storedViews()).first;
    expect(edited.title, 'Everything');
    expect(edited.filter, isNull);
    expect(edited.position, 100);
    expect((await db.listSnapshotsDao.load('view:11')).positions.keys, [
      31,
      32,
    ]);
  });

  test('a move puts the view between its new neighbours', () async {
    await repository.moveView(1, 12, toIndex: 0);

    expect(server.requests, ['move view 12 project 1 to 50.0']);
    final views = await storedViews();
    expect(views.map((v) => v.id), [12, 11]);
    expect(views.first.position, 50);
    expect(views.first.bucketConfigurationMode, board.bucketConfigurationMode);

    await repository.moveView(1, 12, toIndex: 0);
    expect(server.requests, hasLength(1));
    expect(sync.refreshAfterWriteCalls, 1);
  });

  test('a move sends only the position, so a board changed elsewhere since '
      'the last sync keeps its mode, filter and title', () async {
    final changedElsewhere = ProjectView(
      id: 12,
      projectId: 1,
      title: 'Columns',
      kind: ProjectViewKind.kanban,
      position: board.position,
      filter: const ViewFilter(filter: 'priority >= 3'),
      bucketConfigurationMode: BucketConfigurationMode.filter,
    );
    server.serverProjects[1] = sampleProject(
      id: 1,
      title: 'Work',
      views: [list, changedElsewhere],
    );

    await repository.moveView(1, 12, toIndex: 0);

    final onServer = server.serverProjects[1]!.views.firstWhere(
      (v) => v.id == 12,
    );
    expect(onServer.title, 'Columns');
    expect(onServer.filter?.filter, 'priority >= 3');
    expect(onServer.bucketConfigurationMode, BucketConfigurationMode.filter);
    expect(onServer.position, 50);
    expect(server.serverBuckets[12], isNull);
    final stored = (await storedViews()).first;
    expect(stored.id, 12);
    expect(stored.title, 'Columns');
    expect(stored.bucketConfigurationMode, BucketConfigurationMode.filter);
  });

  test('a delete removes the view with its preferences; the last one is '
      'refused before any request', () async {
    final preferences = LocalListPreferences(db);
    const shown = ViewPreferences(showDone: true);
    await preferences.saveView('view:12', shown);

    await repository.deleteView(1, 12);

    expect(server.requests, ['delete view 12 project 1']);
    expect((await storedViews()).map((v) => v.id), [11]);
    expect(await preferences.watchView('view:12').first, isNot(shown));

    await expectLater(
      repository.deleteView(1, 11),
      throwsA(isA<LastViewNotDeletable>()),
    );
    expect(server.requests, hasLength(1));
  });

  test('a view or project this device no longer has is refused before any '
      'request', () async {
    const draft = ViewDraft(title: 'Board', kind: ProjectViewKind.kanban);
    await expectLater(
      repository.updateView(1, 99, draft),
      throwsA(isA<NotFound>().having((e) => e.code, 'code', 3014)),
    );
    await expectLater(
      repository.deleteView(1, 99),
      throwsA(isA<NotFound>().having((e) => e.code, 'code', 3014)),
    );
    await expectLater(
      repository.createView(9, draft),
      throwsA(isA<NotFound>().having((e) => e.code, 'code', 3001)),
    );
    await expectLater(
      repository.createView(
        1,
        const ViewDraft(title: ' ', kind: ProjectViewKind.list),
      ),
      throwsArgumentError,
    );

    expect(server.requests, isEmpty);
  });

  test('a refusal or no connection changes nothing', () async {
    server
      ..refusedViewProjects[1] = const Forbidden()
      ..refusedFilters['((('] = const DomainError(400, code: 4024);
    await expectLater(
      repository.updateView(
        1,
        11,
        const ViewDraft(title: 'All', kind: ProjectViewKind.list),
      ),
      throwsA(isA<Forbidden>()),
    );
    server.refusedViewProjects.clear();
    await expectLater(
      repository.createView(
        1,
        const ViewDraft(
          title: 'Broken',
          kind: ProjectViewKind.list,
          filter: ViewFilter(filter: '((('),
        ),
      ),
      throwsA(isA<DomainError>().having((e) => e.code, 'code', 4024)),
    );
    server.beforeRequest = (_) async =>
        throw const NetworkFailure(NetworkProblem.unreachable);
    await expectLater(
      repository.deleteView(1, 12),
      throwsA(isA<NetworkFailure>()),
    );

    expect(await storedViews(), [list, board]);
    expect(sync.refreshAfterWriteCalls, 0);
  });

  group('planning a move', () {
    ProjectView view(int id, double position) => ProjectView(
      id: id,
      projectId: 1,
      title: '$id',
      kind: ProjectViewKind.list,
      position: position,
    );

    test('between neighbours, first and last', () {
      final views = [view(1, 100), view(2, 200), view(3, 300)];

      expect(planViewMove(views, 3, 0), 50);
      expect(planViewMove(views, 1, 1), 250);
      expect(planViewMove(views, 1, 2), 300 + 65536);
      expect(planViewMove(views, 1, 9), 300 + 65536);
      expect(planViewMove(views, 2, 1), isNull);
      expect(planViewMove(views, 9, 0), isNull);
    });

    test('below a first neighbour at 0 or less, and among equal positions '
        'by id', () {
      expect(planViewMove([view(1, 0), view(2, 10)], 2, 0), -65536);
      expect(planViewMove([view(1, 5), view(2, 5), view(3, 5)], 3, 1), isNull);
      expect(planViewMove([view(1, 5), view(3, 5), view(2, 9)], 2, 1), 5);
    });

    test('sorted views are by position, then id', () {
      expect(
        sortedViews([view(3, 1), view(1, 2), view(2, 1)]).map((v) => v.id),
        [2, 3, 1],
      );
    });
  });
}
