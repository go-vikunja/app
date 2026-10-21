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
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_user_repository.dart';
import 'package:vikunja_mobile/core/repositories/user_repository.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
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
  late final LabelsWritePort labels = _SwitchableLabels(this);

  @override
  AttachmentsWritePort get attachments => _real.attachments;

  @override
  NotificationsWritePort get notifications => _real.notifications;

  @override
  SubscriptionsWritePort get subscriptions => _real.subscriptions;

  @override
  BucketsWritePort get buckets => _real.buckets;

  @override
  ProjectViewsWritePort get views => _real.views;

  @override
  ProjectsWritePort get projects => _real.projects;

  @override
  SavedFiltersPort get savedFilters => _real.savedFilters;

  @override
  CommentsWritePort get comments => _real.comments;

  @override
  ReactionsWritePort get reactions => _real.reactions;

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

  @override
  Future<Task> duplicate(int id) {
    _client._check();
    return _client._real.tasks.duplicate(id);
  }

  @override
  Future<void> markRead(int id) {
    _client._check();
    return _client._real.tasks.markRead(id);
  }
}

final class _SwitchableLabels implements LabelsWritePort {
  new(this._client);

  final _SwitchableWriteClient _client;

  @override
  Future<Label> create(NewLabel label) {
    _client._check();
    return _client._real.labels.create(label);
  }
}

/// The user search behind the same switch.
final class _SwitchableUsers implements UserRepository {
  new(this._real, this._writes);

  final UserRepository _real;
  final _SwitchableWriteClient _writes;

  @override
  Future<List<User>> searchAssignees(int projectId, String query) {
    _writes._check();
    return _real.searchAssignees(projectId, query);
  }

  @override
  Future<List<User>> knownUsers() => _real.knownUsers();

  @override
  Stream<List<User>> watchKnownUsers() => _real.watchKnownUsers();

  @override
  void dispose() => _real.dispose();
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

void main() {
  group('quick add against the local Docker server', skip: contractSkip, () {
    late Dio dio;
    late ServerConnection connection;
    late TestUser user;
    late int garageId;
    late int wichtigId;

    // One user for both API versions: /register and /login share the
    // limiter. Each version creates a label of its own, so that it is new
    // on both.
    setUpAll(() async {
      dio = contractDio();
      connection = await DioServerConnector(dio)
          .connect('http://localhost:$contractServerPort');
      user = await registerAndLogin(dio, connection);
      final seeder = Seeder(dio, connection, user);
      garageId = await seeder.create('/projects', {'title': 'Garage'});
      wichtigId = await seeder.create('/labels', {'title': 'wichtig'});
      final current = await seeder.get('/user');
      // PUT replaces every field, so the whole object goes back.
      await seeder.put('/user/settings/general', {
        ...current['settings']! as Map<String, Object?>,
        'frontend_settings': {
          'quick_add_default_reminders': [
            {'relative_period': -3600, 'relative_to': 'due_date'},
          ],
        },
      });
    });

    tearDownAll(() => dio.close(force: true));

    for (final apiVersion in ApiVersion.values) {
      group('over ${apiVersion.pathSegment}', () {
        late VikunjaReadClient reads;
        late _SwitchableWriteClient writes;
        late AppDatabase db;
        late OutboxSender sender;
        late LocalTaskRepository tasks;
        late LocalLabelRepository labels;
        late UserRepository users;

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
          labels = LocalLabelRepository(db, writes, reads);
          users = _SwitchableUsers(LocalUserRepository(db, reads), writes);
          await engine.ensureInitialSync();
        });

        // As the app builds it: from what the sync stored.
        Future<LocalQuickAddService> service() async => LocalQuickAddService(
          snapshot: QuickAddSnapshot(
            projects: await db.projectsDao.loadAll(),
            labels: await db.labelsDao.loadAll(),
            knownUsers: await db.usersDao.loadAll(),
            settings: decodeUserSettings(
              (await db.syncStateDao.readAll())[SyncStateKeys.userSettings],
            ),
          ),
          tasks: tasks,
          labels: labels,
          users: users,
          now: DateTime.now,
        );

        Future<Task> sentTask(int localId) async {
          await _until(() async => await db.outboxDao.count() == 0);
          final local = await tasks.watchTask(localId).first;
          expect(local!.id, isPositive);
          return await reads.tasks.read(local.id);
        }

        test('everything of the line reaches the server', () async {
          final newLabel = 'neu${apiVersion.name}';
          final today = DateTime.now();

          final result = await (await service()).submit(
            'Reifen wechseln *wichtig *$newLabel +Garage @${user.username} '
            '!3 tomorrow at 9:00 every week',
          );

          expect(result.labelsNotCreated, isEmpty);
          expect(result.unresolvedAssignees, isEmpty);
          await sender.drain();
          final task = await sentTask(result.createdTaskIds.single);
          expect(task.title, 'Reifen wechseln');
          expect(task.projectId, garageId);
          expect(task.labels.map((label) => label.title).toSet(), {
            'wichtig',
            newLabel,
          });
          expect(task.labels.map((label) => label.id), contains(wichtigId));
          expect(task.assignees.map((assignee) => assignee.id), [user.id]);
          expect(task.priority, TaskPriority.high);
          expect(
            task.dueDate,
            DateTime(today.year, today.month, today.day + 1, 9).toUtc(),
          );
          expect(task.repeatAfter, const Duration(days: 7));
          expect(task.repeatMode, RepeatMode.afterAmount);
          // The user's default reminders, relative to the due date.
          expect(task.reminders, hasLength(1));
          expect(
            task.reminders.single.relativePeriod,
            const Duration(hours: -1),
          );
          expect(task.reminders.single.relativeTo, ReminderRelativeTo.dueDate);
        });

        test('a name known nowhere on the device is found by the server '
            'search in the project', () async {
          final partial = user.username.substring(
            0,
            user.username.length ~/ 2 + 1,
          );
          final quickAdd = await service();
          expect(quickAdd.plan('x @$partial +Garage').unresolvedAssignees, [
            partial,
          ]);

          final result = await quickAdd.submit('Teilname @$partial +Garage');

          expect(result.unresolvedAssignees, isEmpty);
          await sender.drain();
          final task = await sentTask(result.createdTaskIds.single);
          expect(task.title, 'Teilname');
          expect(task.assignees.map((assignee) => assignee.id), [user.id]);
          expect(task.reminders, isEmpty);
        });

        test('offline: created at once, sent with its label after '
            'reconnect', () async {
          writes.offline = true;

          final result = await (await service()).submit(
            'Offline erledigen *wichtig +Garage @nobody${apiVersion.name}',
          );
          await sender.drain();

          expect(result.unresolvedAssignees, ['nobody${apiVersion.name}']);
          final localId = result.createdTaskIds.single;
          expect(localId, isNegative);
          final local = (await db.tasksDao.find(localId))!;
          expect(local.labels.map((label) => label.id), [wichtigId]);
          expect(await db.outboxDao.count(), 2);

          writes.offline = false;
          await sender.sendNow();

          final task = await sentTask(localId);
          expect(task.title, 'Offline erledigen @nobody${apiVersion.name}');
          expect(task.projectId, garageId);
          expect(task.labels.map((label) => label.id), [wichtigId]);
        });
      });
    }
  });
}
