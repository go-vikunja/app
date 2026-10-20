@Tags(['contract'])
@Timeout(Duration(minutes: 8))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/local/local_label_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_subscription_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_user_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';
import 'package:vikunja_mobile/features/quick_add/application/local_quick_add_service.dart';

import '../helpers/test_database.dart';
import 'helpers.dart';

/// The real write client behind a connection that is down while
/// [offline] is set.
final class _SwitchableWriteClient implements VikunjaWriteClient {
  new(this._real);

  final VikunjaWriteClient _real;
  bool offline = false;

  @override
  late final TasksWritePort tasks = _SwitchableTasks(this);

  @override
  LabelsWritePort get labels => _real.labels;

  @override
  AttachmentsWritePort get attachments => _real.attachments;

  @override
  NotificationsWritePort get notifications => _real.notifications;

  @override
  late final SubscriptionsWritePort subscriptions = _RetryingSubscriptions(
    _real.subscriptions,
  );

  @override
  BucketsWritePort get buckets => _real.buckets;

  @override
  ProjectViewsWritePort get views => _real.views;

  @override
  ProjectsWritePort get projects => _real.projects;

  @override
  SavedFiltersPort get savedFilters => _real.savedFilters;

  void _check() {
    if (offline) throw const NetworkFailure(NetworkProblem.unreachable);
  }
}

final class _SwitchableTasks implements TasksWritePort {
  new(this._client);

  final _SwitchableWriteClient _client;

  @override
  Future<Task> create(NewTask task) {
    _client._check();
    return _client._real.tasks.create(task);
  }

  @override
  Future<Task> update(
    int id,
    TaskChanges changes, {
    String Function(String current)? rebaseDescription,
  }) {
    _client._check();
    return _client._real.tasks.update(
      id,
      changes,
      rebaseDescription: rebaseDescription,
    );
  }

  @override
  Future<void> delete(int id) {
    _client._check();
    return _client._real.tasks.delete(id);
  }

  // A write the server refused as a lost race made no copy, so it may go
  // again.
  @override
  Future<Task> duplicate(int id) {
    _client._check();
    return despiteWriteRaces(() => _client._real.tasks.duplicate(id));
  }

  @override
  Future<void> markRead(int id) {
    _client._check();
    return _client._real.tasks.markRead(id);
  }
}

/// Both calls are safe to repeat over the lost write races of the shared
/// SQLite server; the outbox retries its own writes.
final class _RetryingSubscriptions implements SubscriptionsWritePort {
  new(this._writes);

  final SubscriptionsWritePort _writes;

  @override
  Future<void> subscribe(SubscriptionEntity entity, int id) =>
      despiteWriteRaces(() => _writes.subscribe(entity, id));

  @override
  Future<void> unsubscribe(SubscriptionEntity entity, int id) =>
      despiteWriteRaces(() => _writes.unsubscribe(entity, id));
}

Future<void> _until(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

Set<int> _idsOf(Task task, TaskRelationKind kind) => {
  for (final other in task.relatedTasks[kind] ?? const <Task>[]) other.id,
};

void main() {
  group(
    'relations, duplicate and subscriptions against the local Docker '
    'server',
    skip: contractSkip,
    () {
      late Dio dio;
      late ServerConnection connection;
      late TestUser user;
      late int projectId;

      // One user for both API versions: /register and /login share the
      // limiter.
      setUpAll(() async {
        dio = contractDio();
        connection = await DioServerConnector(dio)
            .connect('http://localhost:$contractServerPort');
        user = await registerAndLogin(dio, connection);
        projectId = await Seeder(
          dio,
          connection,
          user,
        ).create('/projects', {'title': 'Baum'});
      });

      tearDownAll(() => dio.close(force: true));

      for (final apiVersion in ApiVersion.values) {
        group('over ${apiVersion.pathSegment}', () {
          late VikunjaReadClient reads;
          late _SwitchableWriteClient writes;
          late AppDatabase db;
          late OutboxSender sender;
          late LocalTaskRepository tasks;
          late LocalSubscriptionRepository subscriptions;
          late LocalQuickAddService quickAdd;
          final v = apiVersion.name;

          setUpAll(() async {
            final only = onlyApiVersion(connection, apiVersion);
            final authenticated = createAuthenticatedDio(
              base: dio,
              connection: only,
              tokens: StaticJwt(user.jwt),
            );
            reads = createReadClient(dio: authenticated, connection: only);
            writes = _SwitchableWriteClient(
              createWriteClient(dio: authenticated, connection: only),
            );
            db = testDatabase();
            final engine = DefaultSyncEngine(
              db: db,
              client: reads,
              perPage: only.info.maxItemsPerPage,
              currentUser: AccountApi(
                authenticated,
                only,
              ).currentUserWithSettings,
            );
            addTearDown(engine.dispose);
            sender = OutboxSender(
              db: db,
              writeClient: writes,
              readClient: reads,
              sync: engine,
            );
            addTearDown(sender.dispose);
            tasks = LocalTaskRepository(db, engine, sender, writes);
            addTearDown(tasks.dispose);
            subscriptions = LocalSubscriptionRepository(db, reads, writes);
            await engine.ensureInitialSync();
            quickAdd = LocalQuickAddService(
              snapshot: QuickAddSnapshot(
                projects: await db.projectsDao.loadAll(),
              ),
              tasks: tasks,
              labels: LocalLabelRepository(db, writes, reads),
              users: LocalUserRepository(db, reads),
              now: DateTime.now,
            );
          });

          Future<int> serverIdOf(int localId) async {
            await _until(() async => await db.outboxDao.count() == 0);
            final local = await tasks.watchTask(localId).first;
            expect(local!.id, isPositive);
            return local.id;
          }

          Future<int> createdOnServer(String title) async {
            final localId = await tasks.createTask(
              NewTask(projectId: projectId, title: title),
            );
            await sender.drain();
            return await serverIdOf(localId);
          }

          test('a tree added offline arrives with its subtasks, and the local '
              'rows carry the server ids', () async {
            writes.offline = true;

            final result = await quickAdd.submit(
              'Parent $v\n  Child one $v\n  Child two $v',
              fallbackProjectId: projectId,
            );
            await sender.drain();

            final [parent, one, two] = result.createdTaskIds;
            expect([parent, one, two], everyElement(isNegative));
            expect(
              _idsOf(
                (await db.tasksDao.find(parent))!,
                TaskRelationKind.subtask,
              ),
              {one, two},
            );

            writes.offline = false;
            await sender.sendNow();

            final parentId = await serverIdOf(parent);
            final oneId = await serverIdOf(one);
            final twoId = await serverIdOf(two);
            final onServer = await reads.tasks.read(parentId);
            expect(onServer.title, 'Parent $v');
            expect(_idsOf(onServer, TaskRelationKind.subtask), {oneId, twoId});
            expect(
              _idsOf(
                await reads.tasks.read(oneId),
                TaskRelationKind.parentTask,
              ),
              {parentId},
            );
            final local = (await db.tasksDao.find(parentId))!;
            expect(_idsOf(local, TaskRelationKind.subtask), {oneId, twoId});
            expect(
              _idsOf(
                (await db.tasksDao.find(twoId))!,
                TaskRelationKind.parentTask,
              ),
              {parentId},
            );
            expect(await db.tasksDao.find(parent), isNull);
          });

          test('a relation added and removed through the outbox', () async {
            final blocker = await createdOnServer('Blocker $v');
            final blocked = await createdOnServer('Blocked $v');

            await tasks.updateTask(
              blocker,
              TaskChanges(
                relations: RelationChange(
                  added: {TaskRelationRef(TaskRelationKind.blocking, blocked)},
                ),
              ),
            );
            await _until(() async => await db.outboxDao.count() == 0);

            expect(
              _idsOf(
                await reads.tasks.read(blocker),
                TaskRelationKind.blocking,
              ),
              {blocked},
            );
            expect(
              _idsOf(await reads.tasks.read(blocked), TaskRelationKind.blocked),
              {blocker},
            );
            expect(
              _idsOf(
                (await db.tasksDao.find(blocked))!,
                TaskRelationKind.blocked,
              ),
              {blocker},
            );

            await tasks.updateTask(
              blocker,
              TaskChanges(
                relations: RelationChange(
                  removed: {
                    TaskRelationRef(TaskRelationKind.blocking, blocked),
                  },
                ),
              ),
            );
            await _until(() async => await db.outboxDao.count() == 0);

            expect((await reads.tasks.read(blocker)).relatedTasks, isEmpty);
            expect((await reads.tasks.read(blocked)).relatedTasks, isEmpty);
            expect((await db.tasksDao.find(blocker))!.relatedTasks, isEmpty);
            expect((await db.tasksDao.find(blocked))!.relatedTasks, isEmpty);
            expect(await db.outboxDao.loadProblems(), isEmpty);
          });

          test('a duplicate is stored with copiedfrom, its source with '
              'copiedto', () async {
            final source = await createdOnServer('Original $v');

            final copy = await tasks.duplicateTask(source);

            expect(copy, isNot(source));
            final onServer = await reads.tasks.read(copy);
            expect(onServer.title, 'Original $v');
            expect(_idsOf(onServer, TaskRelationKind.copiedFrom), {source});
            final local = (await db.tasksDao.find(copy))!;
            expect(local.title, 'Original $v');
            expect(_idsOf(local, TaskRelationKind.copiedFrom), {source});
            expect(
              _idsOf(
                (await db.tasksDao.find(source))!,
                TaskRelationKind.copiedTo,
              ),
              {copy},
            );
          });

          test('a duplicate waits for the queued changes; offline it is '
              'refused', () async {
            final source = await createdOnServer('To copy $v');
            writes.offline = true;
            await tasks.updateTask(source, const TaskChanges(priority: 4));

            await expectLater(
              tasks.duplicateTask(source),
              throwsA(isA<NetworkFailure>()),
            );

            writes.offline = false;
            final copy = await tasks.duplicateTask(source);
            expect(
              (await reads.tasks.read(copy)).priority,
              TaskPriority.urgent,
            );
          });

          test('following and unfollowing a task and its project', () async {
            final task = await createdOnServer('Followed $v');
            const ownProject = SubscriptionEntity.project;

            // The creator follows a new task.
            expect(
              (await subscriptions.forTask(task))?.entity,
              SubscriptionEntity.task,
            );

            expect(
              await subscriptions.setTaskSubscribed(task, subscribed: false),
              isNull,
            );
            expect(
              await subscriptions.setTaskSubscribed(task, subscribed: true),
              Subscription(entity: SubscriptionEntity.task, entityId: task),
            );
            // Twice is no failure.
            expect(
              await subscriptions.setTaskSubscribed(task, subscribed: true),
              isNotNull,
            );

            expect(
              await subscriptions.setProjectSubscribed(
                projectId,
                subscribed: true,
              ),
              Subscription(entity: ownProject, entityId: projectId),
            );
            expect(
              await subscriptions.forProject(projectId),
              Subscription(entity: ownProject, entityId: projectId),
            );
            expect(
              await subscriptions.setProjectSubscribed(
                projectId,
                subscribed: false,
              ),
              isNull,
            );
          });

          test('a task whose create is still queued is not subscribable '
              'yet', () async {
            writes.offline = true;
            final localId = await tasks.createTask(
              NewTask(projectId: projectId, title: 'Not yet $v'),
            );

            await expectLater(
              subscriptions.forTask(localId),
              throwsA(isA<TaskNotSyncedYet>()),
            );

            writes.offline = false;
            await sender.sendNow();
            final serverId = await serverIdOf(localId);
            expect((await subscriptions.forTask(localId))?.entityId, serverId);
          });
        });
      }
    },
  );
}
