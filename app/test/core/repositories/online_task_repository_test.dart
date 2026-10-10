import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/online/online_task_repository.dart';
import 'package:vikunja_mobile/core/repositories/paged_list.dart';

import '../../helpers/fake_read_client.dart';
import '../../helpers/sample_data.dart';

void main() {
  late FakeReadClient client;
  late OnlineTaskRepository repository;

  List<Task> tasks(int count, {bool done = false}) => [
    for (var i = 1; i <= count; i++)
      sampleTask(id: i, title: 'Task $i', done: done),
  ];

  setUp(() {
    client = FakeReadClient();
    repository = OnlineTaskRepository(client);
  });

  tearDown(() => repository.dispose());

  group('open tasks', () {
    test('loads every page with the overview query', () async {
      client.tasks.openTasks = tasks(5);
      client.tasks.perPage = 2;
      final seen = <List<Task>>[];
      repository.watchOpenTasks().listen(seen.add);
      await pumpEventQueue();

      expect(seen, hasLength(1));
      expect(seen.single.map((task) => task.id), [1, 2, 3, 4, 5]);
      expect(client.tasks.listQueries.map((q) => q.page), [1, 2, 3]);
      for (final query in client.tasks.listQueries) {
        expect(query.filter, 'done = false');
        expect(query.sort, TaskQuery.dueDateSort);
        expect(query.perPage, isNull);
      }
    });

    test('stops at the page cap and says so in the log', () async {
      client.tasks.openTasks = tasks(10);
      client.tasks.perPage = 1;
      final records = <LogRecord>[];
      final subscription = Logger.root.onRecord.listen(records.add);
      addTearDown(subscription.cancel);
      final seen = <List<Task>>[];
      repository.watchOpenTasks().listen(seen.add);
      await pumpEventQueue();

      expect(seen.single, hasLength(OnlineTaskRepository.openTasksPageCap));
      expect(
        client.tasks.listQueries,
        hasLength(OnlineTaskRepository.openTasksPageCap),
      );
      expect(
        records.where((r) => r.level == Level.WARNING).map((r) => r.message),
        [contains('capped')],
      );
    });

    test('a failed first load is the stream error', () async {
      client.tasks.onList = (_) async =>
          throw const NetworkFailure(NetworkProblem.timeout);
      final errors = <Object>[];
      repository.watchOpenTasks().listen((_) {}, onError: errors.add);
      await pumpEventQueue();

      expect(errors, [isA<NetworkFailure>()]);
    });

    test('a failed refresh throws and keeps the stale list', () async {
      client.tasks.openTasks = tasks(2);
      final seen = <List<Task>>[];
      final errors = <Object>[];
      repository.watchOpenTasks().listen(seen.add, onError: errors.add);
      await pumpEventQueue();
      client.tasks.onList = (_) async => throw const ServerFailure(503);

      await expectLater(
        repository.refreshOpenTasks(),
        throwsA(isA<ServerFailure>()),
      );

      expect(errors, isEmpty);
      expect(seen, hasLength(1));
    });

    test('a refresh replaces the list', () async {
      client.tasks.openTasks = tasks(2);
      final seen = <List<Task>>[];
      repository.watchOpenTasks().listen(seen.add);
      await pumpEventQueue();
      client.tasks.openTasks = tasks(1);

      await repository.refreshOpenTasks();

      expect(seen.last.map((task) => task.id), [1]);
    });
  });

  group('project tasks', () {
    setUp(() {
      client.tasks.projectTasks = {
        7: [...tasks(5), ...tasks(2, done: true).map(_shiftId(10))],
      };
      client.tasks.perPage = 2;
    });

    test('loads the first page, then appends on load more', () async {
      final seen = <PagedList<Task>>[];
      repository.watchProjectTasks(7, showDone: false).listen(seen.add);
      await pumpEventQueue();
      expect(seen.last.items.map((t) => t.id), [1, 2]);
      expect(seen.last.hasMore, isTrue);

      await repository.loadMoreProjectTasks(7, showDone: false);
      expect(seen.last.items.map((t) => t.id), [1, 2, 3, 4]);
      expect(seen.last.hasMore, isTrue);

      await repository.loadMoreProjectTasks(7, showDone: false);
      expect(seen.last.items.map((t) => t.id), [1, 2, 3, 4, 5]);
      expect(seen.last.hasMore, isFalse);

      await repository.loadMoreProjectTasks(7, showDone: false);
      expect(client.tasks.projectQueries.map((q) => q.$2.page), [1, 2, 3]);
      for (final (projectId, query) in client.tasks.projectQueries) {
        expect(projectId, 7);
        expect(query.filter, 'done = false');
        expect(query.sort, TaskQuery.defaultSort);
      }
    });

    test('show done is a separate query without the done filter', () async {
      final open = <PagedList<Task>>[];
      final all = <PagedList<Task>>[];
      repository.watchProjectTasks(7, showDone: false).listen(open.add);
      repository.watchProjectTasks(7, showDone: true).listen(all.add);
      await pumpEventQueue();

      expect(open.last.items.map((t) => t.id), [1, 2]);
      expect(all.last.items.map((t) => t.id), [1, 2]);
      expect(client.tasks.projectQueries.map((q) => q.$2.filter), [
        'done = false',
        null,
      ]);
    });

    test('a refresh re-queries the watched list with the other show-done '
        'setting', () async {
      final open = <PagedList<Task>>[];
      final all = <PagedList<Task>>[];
      repository.watchProjectTasks(7, showDone: false).listen(open.add);
      repository.watchProjectTasks(7, showDone: true).listen(all.add);
      await pumpEventQueue();
      client.tasks.perPage = 10;

      await repository.refreshProjectTasks(7, showDone: true);
      expect(all.last.items.map((t) => t.id), [1, 2, 3, 4, 5, 11, 12]);
      // The other list follows quietly, not on the refresh's future.
      await pumpEventQueue();

      expect(open.last.items.map((t) => t.id), [1, 2, 3, 4, 5]);
      expect(client.tasks.projectQueries.map((q) => (q.$2.filter, q.$2.page)), [
        ('done = false', 1),
        (null, 1),
        (null, 1),
        ('done = false', 1),
      ]);
    });

    test('a refresh forgets the unwatched list with the other show-done '
        'setting, so the next watch re-queries', () async {
      final all = <PagedList<Task>>[];
      final subscription = repository
          .watchProjectTasks(7, showDone: true)
          .listen(all.add);
      await pumpEventQueue();
      await subscription.cancel();

      await repository.refreshProjectTasks(7, showDone: false);
      expect(client.tasks.projectQueries, hasLength(2));

      client.tasks.perPage = 10;
      final again = <PagedList<Task>>[];
      repository.watchProjectTasks(7, showDone: true).listen(again.add);
      await pumpEventQueue();

      expect(again.single.items.map((t) => t.id), [1, 2, 3, 4, 5, 11, 12]);
      expect(client.tasks.projectQueries, hasLength(3));
    });

    test('a refresh that completes before an older load more wins', () async {
      final seen = <PagedList<Task>>[];
      repository.watchProjectTasks(7, showDone: false).listen(seen.add);
      await pumpEventQueue();
      await repository.loadMoreProjectTasks(7, showDone: false);
      expect(seen.last.items.map((t) => t.id), [1, 2, 3, 4]);
      final gates = {1: Completer<Page<Task>>(), 3: Completer<Page<Task>>()};
      client.tasks.onListInProject = (_, query) => gates[query.page]!.future;

      final loadMore = repository.loadMoreProjectTasks(7, showDone: false);
      final refresh = repository.refreshProjectTasks(7, showDone: false);
      gates[1]!.complete(pageOf(tasks(5), page: 1, perPage: 2));
      await refresh;
      gates[3]!.complete(pageOf(tasks(5), page: 3, perPage: 2));
      await loadMore;

      expect(seen.last.items.map((t) => t.id), [1, 2]);
      expect(seen.last.hasMore, isTrue);
      client.tasks.onListInProject = null;
      await repository.loadMoreProjectTasks(7, showDone: false);
      expect(seen.last.items.map((t) => t.id), [1, 2, 3, 4]);
    });

    test('a load more during a refresh does nothing', () async {
      final seen = <PagedList<Task>>[];
      repository.watchProjectTasks(7, showDone: false).listen(seen.add);
      await pumpEventQueue();
      final gate = Completer<Page<Task>>();
      client.tasks.onListInProject = (_, _) => gate.future;

      final refresh = repository.refreshProjectTasks(7, showDone: false);
      await repository.loadMoreProjectTasks(7, showDone: false);
      expect(client.tasks.projectQueries.map((q) => q.$2.page), [1, 1]);
      gate.complete(pageOf(tasks(5), page: 1, perPage: 2));
      await refresh;

      expect(seen.last.items.map((t) => t.id), [1, 2]);
      expect(seen.last.hasMore, isTrue);
    });

    test('a refresh goes back to the first page', () async {
      final seen = <PagedList<Task>>[];
      repository.watchProjectTasks(7, showDone: false).listen(seen.add);
      await pumpEventQueue();
      await repository.loadMoreProjectTasks(7, showDone: false);
      expect(seen.last.items, hasLength(4));

      await repository.refreshProjectTasks(7, showDone: false);

      expect(seen.last.items.map((t) => t.id), [1, 2]);
      expect(seen.last.hasMore, isTrue);
      await repository.loadMoreProjectTasks(7, showDone: false);
      expect(seen.last.items.map((t) => t.id), [1, 2, 3, 4]);
    });

    test('a task that moved onto the next page is kept once', () async {
      client.tasks.onListInProject = (projectId, query) async => Page(
        items: query.page == 1
            ? tasks(2)
            : [tasks(2).last, sampleTask(id: 9, title: 'Nine')],
        page: query.page,
        perPage: 2,
        totalPages: 2,
      );
      final seen = <PagedList<Task>>[];
      repository.watchProjectTasks(7, showDone: false).listen(seen.add);
      await pumpEventQueue();

      await repository.loadMoreProjectTasks(7, showDone: false);

      expect(seen.last.items.map((t) => t.id), [1, 2, 9]);
    });

    test('a failed first load is the stream error', () async {
      client.tasks.onListInProject = (_, _) async =>
          throw const Forbidden(code: 3004);
      final errors = <Object>[];
      repository
          .watchProjectTasks(7, showDone: false)
          .listen((_) {}, onError: errors.add);
      await pumpEventQueue();

      expect(errors, [isA<Forbidden>()]);
    });

    test('a failed refresh or load more throws and keeps the pages', () async {
      final seen = <PagedList<Task>>[];
      final errors = <Object>[];
      repository
          .watchProjectTasks(7, showDone: false)
          .listen(seen.add, onError: errors.add);
      await pumpEventQueue();
      client.tasks.onListInProject = (_, _) async =>
          throw const NetworkFailure(NetworkProblem.unreachable);

      await expectLater(
        repository.loadMoreProjectTasks(7, showDone: false),
        throwsA(isA<NetworkFailure>()),
      );
      await expectLater(
        repository.refreshProjectTasks(7, showDone: false),
        throwsA(isA<NetworkFailure>()),
      );

      expect(errors, isEmpty);
      expect(seen, hasLength(1));
      expect(seen.single.items, hasLength(2));
    });

    test('concurrent load-more calls share one request', () async {
      final seen = <PagedList<Task>>[];
      repository.watchProjectTasks(7, showDone: false).listen(seen.add);
      await pumpEventQueue();
      final gate = Completer<Page<Task>>();
      client.tasks.onListInProject = (_, _) => gate.future;

      final first = repository.loadMoreProjectTasks(7, showDone: false);
      final second = repository.loadMoreProjectTasks(7, showDone: false);
      gate.complete(
        Page(
          items: [sampleTask(id: 3, title: 'Three')],
          page: 2,
          perPage: 2,
          totalPages: 2,
        ),
      );
      await Future.wait([first, second]);

      expect(client.tasks.projectQueries, hasLength(2));
      expect(seen.last.items.map((t) => t.id), [1, 2, 3]);
    });
  });
}

Task Function(Task) _shiftId(int by) =>
    (task) => sampleTask(id: task.id + by, title: task.title, done: task.done);
