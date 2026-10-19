import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_resolver.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FakeSyncClient read;
  late LocalTaskResolver resolver;

  Task indexed(int id, {required int projectId, required int index}) => Task(
    id: id,
    title: 'Task $id',
    projectId: projectId,
    index: index,
    identifier: 'stale-$index',
  );

  setUp(() async {
    db = testDatabase();
    read = FakeSyncClient();
    resolver = LocalTaskResolver(db, read);
    await db.projectsDao.upsertAll([
      sampleProject(id: 7, title: 'Garden', identifier: 'GARDEN'),
      sampleProject(id: 8, title: 'Street', identifier: 'STRAßE'),
      sampleProject(id: 9, title: 'Numbers', identifier: '129332'),
      sampleProject(id: 10, title: 'Plain'),
      sampleProject(id: 11, title: 'Dashes', identifier: 'MY-PRJ'),
    ]);
    await db.tasksDao.upsertAll([
      indexed(1, projectId: 7, index: 3),
      indexed(2, projectId: 8, index: 1),
      indexed(3, projectId: 9, index: 4),
      indexed(4, projectId: 11, index: 12),
    ]);
  });

  group('locally', () {
    test('an id is the stored task, no request', () async {
      final task = await resolver.resolve(const TaskById(1));

      expect(task.id, 1);
      expect(read.requests, isEmpty);
    });

    test('an identifier is the task with that index in the project with '
        'that identifier, ignoring case', () async {
      for (final (identifier, index, id) in [
        ('GARDEN', 3, 1),
        ('garden', 3, 1),
        ('Garden', 3, 1),
        ('straße', 1, 2),
        ('STRAßE', 1, 2),
        ('Straße', 1, 2),
        ('my-prj', 12, 4),
      ]) {
        final task = await resolver.resolve(
          TaskByIdentifier(identifier, index),
        );
        expect(task.id, id, reason: '$identifier-$index');
      }
      expect(read.requests, isEmpty);
    });

    test('a project identifier of digits only is found locally', () async {
      final task = await resolver.resolve(const TaskByIdentifier('129332', 4));

      expect(task.id, 3);
      expect(read.requests, isEmpty);
    });

    test('the stored task identifier does not count: the server echoes a '
        'stale one after a move', () async {
      read
        ..allProjects = [sampleProject(id: 7, title: 'Garden')]
        ..allTasks = [indexed(1, projectId: 7, index: 3)];

      await expectLater(
        resolver.resolve(const TaskByIdentifier('stale', 3)),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 3001)),
      );
      expect(read.requests, ['task by-index stale 3']);
    });

    test('a local lookup answers without a request, null when the task is '
        'not here', () async {
      expect((await resolver.findLocal(const TaskById(1)))?.id, 1);
      expect(
        (await resolver.findLocal(const TaskByIdentifier('straße', 1)))?.id,
        2,
      );
      expect(await resolver.findLocal(const TaskById(99)), isNull);
      expect(
        await resolver.findLocal(const TaskByIdentifier('GARDEN', 99)),
        isNull,
      );
      expect(
        await resolver.findLocal(const TaskByIdentifier('NOPE', 3)),
        isNull,
      );
      expect(read.requests, isEmpty);
    });

    test('a temporary id follows its remap', () async {
      await db
          .into(db.taskIdRemaps)
          .insert(
            TaskIdRemapRow(localId: -4, serverId: 1, at: DateTime.utc(2026)),
          );

      expect((await resolver.resolve(const TaskById(-4))).id, 1);
      expect(read.requests, isEmpty);
    });
  });

  group('online', () {
    test('a task id the device does not have is read and stored', () async {
      const anna = User(id: 9, username: 'anna', name: 'Anna');
      read.allTasks = [
        sampleTask(
          id: 20,
          title: 'From elsewhere',
          projectId: 7,
          assignees: [anna],
          labels: [sampleLabel(id: 2, title: 'Urgent')],
        ),
      ];

      final task = await resolver.resolve(const TaskById(20));

      expect(task.title, 'From elsewhere');
      expect(task.assignees, [anna]);
      expect(read.requests, ['task 20']);
      final stored = await db.tasksDao.find(20);
      expect(stored?.labels.single.title, 'Urgent');
      expect((await db.tasksDao.findRow(20))?.syncRunId, isNull);

      read.requests.clear();
      expect((await resolver.resolve(const TaskById(20))).id, 20);
      expect(read.requests, isEmpty);
    });

    test('an index the device does not have in a local project is read by '
        'the numeric project id', () async {
      read
        ..allProjects = [
          sampleProject(id: 8, title: 'Street', identifier: 'STRAßE'),
        ]
        ..allTasks = [indexed(21, projectId: 8, index: 2)];

      final task = await resolver.resolve(const TaskByIdentifier('straße', 2));

      expect(task.id, 21);
      expect(read.requests, ['task by-index 8 2']);
      final again = await db.tasksDao.findByIdentifier('STRAßE', 2);
      expect(again?.task?.id, 21);
    });

    test('a moved task is found through its old address', () async {
      read
        ..allProjects = [
          sampleProject(id: 7, title: 'Garden', identifier: 'GARDEN'),
          sampleProject(id: 12, title: 'Moved to', identifier: 'NEW'),
        ]
        ..allTasks = [indexed(22, projectId: 12, index: 1)]
        ..retiredIndexes[(7, 9)] = 22;

      final task = await resolver.resolve(const TaskByIdentifier('GARDEN', 9));

      expect(task.id, 22);
      expect(task.projectId, 12);
      expect(read.requests, ['task by-index 7 9']);
    });

    test('an identifier no local project has is sent as typed', () async {
      read
        ..allProjects = [
          sampleProject(id: 30, title: 'Shared', identifier: 'ÄB9332'),
        ]
        ..allTasks = [indexed(23, projectId: 30, index: 1)];

      final task = await resolver.resolve(const TaskByIdentifier('äb9332', 1));

      expect(task.id, 23);
      expect(read.requests, ['task by-index äb9332 1']);
    });

    test('an identifier of digits only no local project has is not sent: '
        'the server would read it as a project id', () async {
      await expectLater(
        resolver.resolve(const TaskByIdentifier('17', 1)),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 3001)),
      );
      expect(read.requests, isEmpty);
    });

    test('a task queued for deletion stays hidden, although the server '
        'still has it', () async {
      read.allTasks = [indexed(1, projectId: 7, index: 3)];
      await (db.update(db.tasks)..where((t) => t.id.equals(1))).write(
        const TasksCompanion(pendingDelete: Value(true)),
      );

      await expectLater(
        resolver.resolve(const TaskById(1)),
        throwsA(isA<NotFound>()),
      );
      expect(read.requests, ['task 1']);
      expect((await db.tasksDao.findRow(1))?.pendingDelete, isTrue);
    });

    test(
      'failures propagate: gone, forbidden, unknown project, offline',
      () async {
        read.allProjects = [
          sampleProject(id: 7, title: 'Garden', identifier: 'GARDEN'),
          sampleProject(id: 40, title: 'Foreign', identifier: 'FOREIGN'),
        ];
        read.forbiddenProjects.add(40);

        await expectLater(
          resolver.resolve(const TaskById(99)),
          throwsA(isA<NotFound>().having((f) => f.code, 'code', 4002)),
        );
        await expectLater(
          resolver.resolve(const TaskByIdentifier('GARDEN', 99)),
          throwsA(isA<NotFound>().having((f) => f.code, 'code', 4002)),
        );
        await expectLater(
          resolver.resolve(const TaskByIdentifier('foreign', 1)),
          throwsA(isA<Forbidden>()),
        );
        await expectLater(
          resolver.resolve(const TaskByIdentifier('NOPE', 1)),
          throwsA(isA<NotFound>().having((f) => f.code, 'code', 3001)),
        );

        read.beforeRequest = (_) async =>
            throw const NetworkFailure(NetworkProblem.unreachable);
        await expectLater(
          resolver.resolve(const TaskById(99)),
          throwsA(isA<NetworkFailure>()),
        );
        expect(
          (await resolver.resolve(const TaskById(1))).id,
          1,
          reason: 'a local task needs no connection',
        );
      },
    );
  });
}
