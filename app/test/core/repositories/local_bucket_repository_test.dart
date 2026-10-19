import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/kanban_dao.dart';
import 'package:vikunja_mobile/core/repositories/bucket_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_bucket_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/sync/list_downloads.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FakeWriteClient write;
  late LocalBucketRepository repository;
  late List<(int, int)> refreshes;
  late List<Task> serverTasks;
  // What a board refresh does besides being recorded.
  Future<void> Function()? onRefresh;
  final now = DateTime.utc(2026, 10, 19, 12);
  final old = DateTime.utc(2026, 10, 2);
  const todo = Bucket(
    id: 1,
    viewId: 80,
    title: 'To-Do',
    count: 2,
    position: 100,
  );
  const doing = Bucket(
    id: 2,
    viewId: 80,
    title: 'Doing',
    limit: 3,
    count: 1,
    position: 200,
  );
  const doneBucket = Bucket(
    id: 3,
    viewId: 80,
    title: 'Done',
    count: 1,
    position: 300,
  );
  const slots = <int, BoardSlot>{
    1: (bucketId: 1, position: 65536),
    2: (bucketId: 1, position: 131072),
    3: (bucketId: 2, position: 32768),
    4: (bucketId: 3, position: 65536),
  };
  final tasks = [
    for (var id = 1; id <= 4; id++)
      sampleTask(
        id: id,
        title: 'Task $id',
        projectId: 7,
        done: id == 4,
        updated: old,
      ),
  ];

  ProjectView kanban({int defaultBucketId = 1, int doneBucketId = 3}) =>
      sampleKanbanView(
        id: 80,
        projectId: 7,
        defaultBucketId: defaultBucketId,
        doneBucketId: doneBucketId,
      );

  Future<void> seed({
    List<Bucket> buckets = const [todo, doing, doneBucket],
    Map<int, BoardSlot> cards = slots,
    int defaultBucketId = 1,
    int doneBucketId = 3,
    int? serverDefaultBucketId,
  }) async {
    final view = kanban(
      defaultBucketId: defaultBucketId,
      doneBucketId: doneBucketId,
    );
    final serverDefault = serverDefaultBucketId ?? defaultBucketId;
    await db.projectsDao.upsertAll([
      sampleProject(
        id: 7,
        title: 'Work',
        views: [sampleListView(id: 70, projectId: 7), view],
      ),
    ]);
    await db.kanbanDao.replaceBoard(
      80,
      buckets: buckets,
      slots: cards,
      loadedPages: const {},
      loadedAt: now,
    );
    write
      ..serverBuckets[80] = {for (final bucket in buckets) bucket.id: bucket}
      ..bucketSlots[80] = {...cards}
      ..kanbanViews[80] = (
        doneBucketId: doneBucketId,
        defaultBucketId: serverDefault,
      )
      ..serverViews[80] = kanban(
        defaultBucketId: serverDefault,
        doneBucketId: doneBucketId,
      );
  }

  setUpAll(() {
    // The fresh download goes into a second in-memory database.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );
  });

  setUp(() async {
    db = testDatabase();
    write = FakeWriteClient(clock: () => now);
    refreshes = [];
    serverTasks = tasks;
    onRefresh = null;
    repository = LocalBucketRepository(
      db,
      write,
      refreshBoard: (projectId, viewId) async {
        refreshes.add((projectId, viewId));
        await onRefresh?.call();
      },
    );
    await db.tasksDao.upsertAll(tasks, syncRunId: 'run');
  });

  /// The board as the fake server has it, into [target].
  Future<void> downloadInto(AppDatabase target) => downloadBoard(
    db: target,
    client: FakeSyncClient()
      ..allTasks = serverTasks
      ..viewBuckets[80] = [...write.serverBuckets[80]!.values]
      ..bucketSlots[80] = {...?write.bucketSlots[80]},
    perPage: 50,
    projectId: 7,
    viewId: 80,
    now: () => now,
  );

  /// What a board download right now would store.
  Future<StoredBoard> freshDownload() async {
    final fresh = testDatabase();
    await fresh.projectsDao.upsertAll([
      sampleProject(id: 7, title: 'Work', views: [kanban()]),
    ]);
    await downloadInto(fresh);
    return await fresh.kanbanDao.load(80);
  }

  /// The task ids of each column of the board built from the device.
  Future<Map<int, List<int>>> shownBoard() async {
    final source = await db.tasksDao.loadBoard(7, 80);
    return {
      for (final column in buildBoard(
        view: source.view!,
        buckets: source.buckets,
        snapshot: source.snapshot,
        loadedAt: source.loadedAt,
        projectTasks: source.projectTasks,
        queued: source.queued,
      ))
        column.bucket.id: [for (final task in column.tasks) task.id],
    };
  }

  Future<void> expectLikeFreshDownload() async {
    final local = await db.kanbanDao.load(80);
    final fresh = await freshDownload();
    expect(local.buckets, fresh.buckets);
    expect(local.slots, fresh.slots);
    final view = await db.projectsDao.loadView(80);
    final server = write.kanbanViews[80]!;
    expect(
      (view?.doneBucketId, view?.defaultBucketId),
      (server.doneBucketId, server.defaultBucketId),
    );
  }

  List<int> idsOf(List<Bucket> buckets) => [
    for (final bucket in buckets) bucket.id,
  ];

  void failRequests(Pattern pattern, Exception failure) =>
      write.beforeRequest = (request) async {
        if (request.startsWith(pattern)) throw failure;
      };

  group('creating', () {
    test('sends the title with a position right of the last bucket, adds '
        'the bucket to the board without tasks and downloads the board '
        'quietly', () async {
      await seed();

      await repository.create(7, 80, 'Review');

      expect(write.requests, [
        'create bucket view 80 Review limit 0 at 65836.0',
      ]);
      final stored = await db.kanbanDao.load(80);
      expect(
        stored.buckets.last,
        const Bucket(id: 700, viewId: 80, title: 'Review', position: 65836),
      );
      expect(stored.slots, slots);
      expect(refreshes, [(7, 80)]);
      await expectLikeFreshDownload();
    });

    test('trims the title and refuses a blank one without a request', () async {
      await seed();

      await repository.create(7, 80, '  Review ');
      await expectLater(
        repository.create(7, 80, '   '),
        throwsA(isA<ArgumentError>()),
      );

      expect(write.requests, [
        'create bucket view 80 Review limit 0 at 65836.0',
      ]);
    });

    test('the first bucket of an empty board gets 65536', () async {
      await seed(buckets: const [], cards: const {});

      await repository.create(7, 80, 'Backlog');

      expect(write.requests, [
        'create bucket view 80 Backlog limit 0 at 65536.0',
      ]);
    });

    test('a failure throws it and changes nothing', () async {
      await seed();
      failRequests(
        'create bucket',
        const NetworkFailure(NetworkProblem.timeout),
      );

      await expectLater(
        repository.create(7, 80, 'Review'),
        throwsA(isA<NetworkFailure>()),
      );

      expect(await db.kanbanDao.buckets(80), [todo, doing, doneBucket]);
      expect(refreshes, isEmpty);
    });
  });

  group('renaming and limiting', () {
    test('a rename sends the stored limit and position along and keeps the '
        "bucket's count and cards", () async {
      await seed();

      await repository.rename(7, 80, 2, ' Doing now ');

      expect(write.requests, [
        'update bucket 2 view 80 Doing now limit 3 at 200.0',
      ]);
      expect(
        (await db.kanbanDao.buckets(80))[1],
        const Bucket(
          id: 2,
          viewId: 80,
          title: 'Doing now',
          limit: 3,
          count: 1,
          position: 200,
        ),
      );
      expect((await db.kanbanDao.load(80)).slots, slots);
      expect(refreshes, [(7, 80)]);
      await expectLikeFreshDownload();
    });

    test('a limit sends the stored title and position along; one below '
        'the count is taken, 0 removes it', () async {
      await seed();

      await repository.setLimit(7, 80, 1, 1);
      expect((await db.kanbanDao.buckets(80)).first.limit, 1);
      await expectLikeFreshDownload();

      await repository.setLimit(7, 80, 2, 0);

      expect(write.requests, [
        'update bucket 1 view 80 To-Do limit 1 at 100.0',
        'update bucket 2 view 80 Doing limit 0 at 200.0',
      ]);
      final stored = await db.kanbanDao.buckets(80);
      expect(
        [for (final b in stored) (b.limit, b.count)],
        [(1, 2), (0, 1), (0, 1)],
      );
      await expectLikeFreshDownload();
    });

    test('a blank title or a negative limit is refused without a '
        'request', () async {
      await seed();

      await expectLater(
        repository.rename(7, 80, 2, ' '),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        repository.setLimit(7, 80, 2, -1),
        throwsA(isA<ArgumentError>()),
      );

      expect(write.requests, isEmpty);
    });

    test('a bucket the board no longer has is a NotFound 10001 without a '
        'request', () async {
      await seed();

      await expectLater(
        repository.rename(7, 80, 9, 'Gone'),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 10001)),
      );

      expect(write.requests, isEmpty);
    });

    test('a bucket deleted elsewhere throws its NotFound and downloads the '
        'board quietly, which drops it', () async {
      await seed();
      failRequests('update bucket', const NotFound(code: 10001));

      await expectLater(
        repository.rename(7, 80, 2, 'Doing now'),
        throwsA(isA<NotFound>()),
      );

      expect(refreshes, [(7, 80)]);
    });

    test('a refusal throws it and keeps the bucket as it was', () async {
      await seed();
      failRequests('update bucket', const DomainError(412, code: 3008));

      await expectLater(
        repository.rename(7, 80, 2, 'Doing now'),
        throwsA(isA<DomainError>()),
      );

      expect(await db.kanbanDao.buckets(80), [todo, doing, doneBucket]);
      expect(refreshes, isEmpty);
    });
  });

  group('moving', () {
    test('to the front halves the first position', () async {
      await seed();

      await repository.move(7, 80, 3, toIndex: 0);

      expect(write.requests, ['update bucket 3 view 80 Done limit 0 at 50.0']);
      expect(idsOf(await db.kanbanDao.buckets(80)), [3, 1, 2]);
      expect(refreshes, [(7, 80)]);
      await expectLikeFreshDownload();
    });

    test('right by one lands between the new neighbours', () async {
      await seed();

      await repository.move(7, 80, 1, toIndex: 1);

      expect(write.requests, [
        'update bucket 1 view 80 To-Do limit 0 at 250.0',
      ]);
      expect(idsOf(await db.kanbanDao.buckets(80)), [2, 1, 3]);
      await expectLikeFreshDownload();
    });

    test('to the end goes 65536 past the last; an index past it is the '
        'end', () async {
      await seed();

      await repository.move(7, 80, 2, toIndex: 9);

      expect(write.requests, [
        'update bucket 2 view 80 Doing limit 3 at 65836.0',
      ]);
      expect(idsOf(await db.kanbanDao.buckets(80)), [1, 3, 2]);
      await expectLikeFreshDownload();
    });

    test('in front of a column another client left at 0 goes below '
        'it', () async {
      await seed(
        buckets: [
          const Bucket(
            id: 1,
            viewId: 80,
            title: 'To-Do',
            count: 2,
            position: 0,
          ),
          doing,
          doneBucket,
        ],
      );

      await repository.move(7, 80, 2, toIndex: 0);

      expect(write.requests, [
        'update bucket 2 view 80 Doing limit 3 at -65536.0',
      ]);
      expect(idsOf(await db.kanbanDao.buckets(80)), [2, 1, 3]);
      await expectLikeFreshDownload();
    });

    test('between two columns of one position that its id does not sort '
        'between sends nothing', () async {
      await seed(
        buckets: [
          const Bucket(
            id: 1,
            viewId: 80,
            title: 'To-Do',
            count: 2,
            position: 0,
          ),
          const Bucket(
            id: 2,
            viewId: 80,
            title: 'Doing',
            count: 1,
            position: 0,
          ),
          const Bucket(id: 3, viewId: 80, title: 'Done', count: 1, position: 0),
        ],
      );

      await repository.move(7, 80, 3, toIndex: 1);

      expect(write.requests, isEmpty);
      expect(refreshes, isEmpty);
    });

    test('to where it is already sends nothing', () async {
      await seed();

      await repository.move(7, 80, 2, toIndex: 1);

      expect(write.requests, isEmpty);
      expect(refreshes, isEmpty);
    });
  });

  group('deleting', () {
    test("moves the bucket's cards to the default bucket with their "
        'positions and count', () async {
      await seed();

      await repository.delete(7, 80, 2);

      expect(write.requests, ['read view 80', 'delete bucket 2 view 80']);
      final stored = await db.kanbanDao.load(80);
      expect(idsOf(stored.buckets), [1, 3]);
      expect(stored.buckets.first.count, 3);
      expect(stored.slots[3], (bucketId: 1, position: 32768.0));
      expect(refreshes, [(7, 80)]);
      await expectLikeFreshDownload();
    });

    test('the done bucket clears it on the view; its done tasks stay '
        'done in the default bucket', () async {
      await seed();

      await repository.delete(7, 80, 3);

      final view = await db.projectsDao.loadView(80);
      expect((view?.doneBucketId, view?.defaultBucketId), (0, 1));
      expect((await db.kanbanDao.load(80)).slots[4]?.bucketId, 1);
      expect((await db.tasksDao.find(4))?.done, isTrue);
      await expectLikeFreshDownload();
    });

    test('the default bucket right of others clears it; the cards go to '
        'the leftmost', () async {
      await seed(defaultBucketId: 2);

      await repository.delete(7, 80, 2);

      expect(write.requests, ['read view 80', 'delete bucket 2 view 80']);
      expect((await db.projectsDao.loadView(80))?.defaultBucketId, 0);
      expect((await db.kanbanDao.load(80)).slots[3]?.bucketId, 1);
      await expectLikeFreshDownload();
    });

    for (final (label, defaultBucketId) in [
      ('the default bucket', 1),
      ('while no default is set, the leftmost bucket', 0),
    ]) {
      test('$label holding tasks: the next bucket becomes the default '
          'first, so the server does not strand the tasks', () async {
        await seed(defaultBucketId: defaultBucketId);

        await repository.delete(7, 80, 1);

        expect(write.requests, [
          'read view 80',
          'view 80 buckets done null default 2',
          'delete bucket 1 view 80',
        ]);
        expect(write.bucketSlots[80], {
          1: (bucketId: 2, position: 65536.0),
          2: (bucketId: 2, position: 131072.0),
          3: (bucketId: 2, position: 32768.0),
          4: (bucketId: 3, position: 65536.0),
        });
        final stored = await db.kanbanDao.load(80);
        expect(idsOf(stored.buckets), [2, 3]);
        expect(stored.buckets.first.count, 3);
        expect((await db.projectsDao.loadView(80))?.defaultBucketId, 2);
        await expectLikeFreshDownload();
      });
    }

    const emptyTodo = Bucket(id: 1, viewId: 80, title: 'To-Do', position: 100);
    final withoutTodoCards = {3: slots[3]!, 4: slots[4]!};

    test('the leftmost bucket that looks empty is checked with a board '
        'download first, and needs no new default while it stays '
        'empty', () async {
      await seed(
        buckets: [emptyTodo, doing, doneBucket],
        cards: withoutTodoCards,
      );
      final requestsAtRefresh = <List<String>>[];
      onRefresh = () async => requestsAtRefresh.add([...write.requests]);

      await repository.delete(7, 80, 1);

      expect(write.requests, ['read view 80', 'delete bucket 1 view 80']);
      expect(requestsAtRefresh.first, ['read view 80']);
      expect((await db.projectsDao.loadView(80))?.defaultBucketId, 0);
      await expectLikeFreshDownload();
    });

    test('a task created here after the download, which the stored count '
        'misses, needs the new default first', () async {
      await seed(
        buckets: [emptyTodo, doing, doneBucket],
        cards: withoutTodoCards,
      );
      final added = sampleTask(
        id: 9,
        title: 'Buy milk',
        projectId: 7,
        created: now.add(const Duration(minutes: 1)),
        updated: now.add(const Duration(minutes: 1)),
      );
      await db.tasksDao.upsertAll([added], syncRunId: 'run');
      serverTasks = [...tasks, added];
      write.bucketSlots[80]![9] = (bucketId: 1, position: 0);
      expect((await shownBoard())[1], [9]);

      await repository.delete(7, 80, 1);

      expect(write.requests, [
        'read view 80',
        'view 80 buckets done null default 2',
        'delete bucket 1 view 80',
      ]);
      expect(write.bucketSlots[80]?[9], (bucketId: 2, position: 0.0));
      expect((await shownBoard())[2], [9, 3]);
      expect(refreshes, [(7, 80)], reason: 'only the quiet one after');
    });

    test('a task created elsewhere, which only the board download shows, '
        'needs the new default first', () async {
      await seed(
        buckets: [emptyTodo, doing, doneBucket],
        cards: withoutTodoCards,
      );
      final elsewhere = sampleTask(
        id: 10,
        title: 'From the web',
        projectId: 7,
        created: now.add(const Duration(minutes: 1)),
        updated: now.add(const Duration(minutes: 1)),
      );
      serverTasks = [...tasks, elsewhere];
      write.bucketSlots[80]![10] = (bucketId: 1, position: 0);
      onRefresh = () async {
        await db.tasksDao.upsertAll([elsewhere], syncRunId: 'run 2');
        await downloadInto(db);
      };

      await repository.delete(7, 80, 1);

      expect(write.requests, [
        'read view 80',
        'view 80 buckets done null default 2',
        'delete bucket 1 view 80',
      ]);
      expect(write.bucketSlots[80]?[10], (bucketId: 2, position: 0.0));
      await pumpEventQueue();
      await expectLikeFreshDownload();
    });

    test("plans from the server's default when the stored one is "
        'stale', () async {
      await seed(defaultBucketId: 2, serverDefaultBucketId: 0);

      await repository.delete(7, 80, 1);

      expect(write.requests, [
        'read view 80',
        'view 80 buckets done null default 2',
        'delete bucket 1 view 80',
      ]);
      expect(write.bucketSlots[80]?[1]?.bucketId, 2);
      await expectLikeFreshDownload();
    });

    test("keeps a default chosen on the web that the device doesn't know "
        'yet', () async {
      await seed(defaultBucketId: 0, serverDefaultBucketId: 3);

      await repository.delete(7, 80, 1);

      expect(write.requests, ['read view 80', 'delete bucket 1 view 80']);
      expect((await db.kanbanDao.load(80)).slots[1]?.bucketId, 3);
      expect((await db.projectsDao.loadView(80))?.defaultBucketId, 3);
      await expectLikeFreshDownload();
    });

    test('when the new default is refused, the delete is not sent and '
        'nothing changes', () async {
      await seed();
      failRequests('view 80', const Forbidden());

      await expectLater(repository.delete(7, 80, 1), throwsA(isA<Forbidden>()));

      expect(write.requests, [
        'read view 80',
        'view 80 buckets done null default 2',
      ]);
      expect(await db.kanbanDao.buckets(80), [todo, doing, doneBucket]);
      expect((await db.projectsDao.loadView(80))?.defaultBucketId, 1);
      expect(refreshes, isEmpty);
    });

    test('when the delete fails after the new default, the old default is '
        'put back and the failure thrown', () async {
      await seed();
      failRequests(
        'delete bucket',
        const NetworkFailure(NetworkProblem.timeout),
      );

      await expectLater(
        repository.delete(7, 80, 1),
        throwsA(isA<NetworkFailure>()),
      );

      expect(write.requests, [
        'read view 80',
        'view 80 buckets done null default 2',
        'delete bucket 1 view 80',
        'view 80 buckets done null default 1',
      ]);
      expect(await db.kanbanDao.buckets(80), [todo, doing, doneBucket]);
      expect((await db.projectsDao.loadView(80))?.defaultBucketId, 1);
      expect(write.kanbanViews[80]?.defaultBucketId, 1);
      expect(refreshes, isEmpty);
    });

    test('when putting the old default back fails too, the new default is '
        'named with the failure', () async {
      await seed(defaultBucketId: 0);
      write.beforeRequest = (request) async {
        if (request.startsWith('delete bucket') ||
            request == 'view 80 buckets done null default 0') {
          throw const NetworkFailure(NetworkProblem.unreachable);
        }
      };

      await expectLater(
        repository.delete(7, 80, 1),
        throwsA(
          isA<DeleteFailedAfterNewDefault>()
              .having((e) => e.failure, 'failure', isA<NetworkFailure>())
              .having((e) => e.bucket, 'bucket', todo)
              .having((e) => e.newDefault.id, 'newDefault', 2),
        ),
      );

      expect(await db.kanbanDao.buckets(80), [todo, doing, doneBucket]);
      expect((await db.projectsDao.loadView(80))?.defaultBucketId, 2);
      expect(write.kanbanViews[80]?.defaultBucketId, 2);
    });

    test(
      'the last bucket is refused by the server with 10003 and stays',
      () async {
        await seed(buckets: const [todo], cards: {1: slots[1]!, 2: slots[2]!});

        await expectLater(
          repository.delete(7, 80, 1),
          throwsA(isA<DomainError>().having((f) => f.code, 'code', 10003)),
        );

        expect(write.requests, ['read view 80', 'delete bucket 1 view 80']);
        expect(await db.kanbanDao.buckets(80), [todo]);
        expect(refreshes, isEmpty);
      },
    );
  });

  group('the done and default bucket', () {
    test('are set and cleared on the server and written to the view at '
        'once; no task changes', () async {
      await seed();

      await repository.setDoneBucket(7, 80, 2);
      var view = await db.projectsDao.loadView(80);
      expect((view?.doneBucketId, view?.defaultBucketId), (2, 1));

      await repository.setDefaultBucket(7, 80, 3);
      await repository.setDoneBucket(7, 80, null);
      await repository.setDefaultBucket(7, 80, null);

      expect(write.requests, [
        'view 80 buckets done 2 default null',
        'view 80 buckets done null default 3',
        'view 80 buckets done 0 default null',
        'view 80 buckets done null default 0',
      ]);
      view = await db.projectsDao.loadView(80);
      expect((view?.doneBucketId, view?.defaultBucketId), (0, 0));
      expect(view?.kind, ProjectViewKind.kanban);
      expect(view?.title, 'Kanban');
      final stored = await db.tasksDao.findAll([1, 2, 3, 4]);
      expect(
        [
          for (final id in [1, 2, 3, 4]) stored[id]?.done,
        ],
        [false, false, false, true],
      );
      expect(refreshes, hasLength(4));
      expect((await db.kanbanDao.load(80)).slots, slots);
    });

    test("store the server's answer: an unknown bucket becomes none", () async {
      await seed();

      await repository.setDoneBucket(7, 80, 99);

      expect((await db.projectsDao.loadView(80))?.doneBucketId, 0);
    });

    test('a refusal throws it and keeps the view', () async {
      await seed();
      failRequests('view 80', const Forbidden());

      await expectLater(
        repository.setDoneBucket(7, 80, 2),
        throwsA(isA<Forbidden>()),
      );

      expect((await db.projectsDao.loadView(80))?.doneBucketId, 3);
      expect(refreshes, isEmpty);
    });

    test('a watched board follows at once', () async {
      await seed();
      final seen = <BoardSource>[];
      final subscription = db.tasksDao.watchBoard(7, 80).listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await repository.setDoneBucket(7, 80, 2);
      await pumpEventQueue();

      expect(seen.last.view?.doneBucketId, 2);
    });
  });

  test('a failed quiet download is swallowed', () async {
    await seed();
    final failing = LocalBucketRepository(
      db,
      write,
      refreshBoard: (_, _) async =>
          throw const NetworkFailure(NetworkProblem.unreachable),
    );

    await failing.rename(7, 80, 2, 'Doing now');
    await pumpEventQueue();

    expect((await db.kanbanDao.buckets(80))[1].title, 'Doing now');
  });
}
