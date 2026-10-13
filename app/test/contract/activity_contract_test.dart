@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'dart:math';
import 'dart:ui' show Locale;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/activity/activity_notifier.dart';
import 'package:vikunja_mobile/core/activity/activity_sync.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/notification_fakes.dart';
import '../helpers/test_database.dart';
import 'helpers.dart';

/// The real write port, with the calls recorded.
final class _RecordingWrites implements NotificationsWritePort {
  new(this._real);

  final NotificationsWritePort _real;
  final List<String> calls = [];

  @override
  Future<void> markRead(int id, {bool read = true}) {
    calls.add('markRead $id $read');
    return _real.markRead(id, read: read);
  }

  @override
  Future<void> markAllRead() {
    calls.add('markAllRead');
    return _real.markAllRead();
  }
}

// Another user assigns the reader to a task in a project shared with the
// reader (and mentions the reader in a comment, when the server has
// comments on): the reader's activity sync stores it, the notifier shows
// it, and the reader's read marks reach the server. Two users for the
// whole file: /register and /login share the limiter.
void main() {
  group('activity against the local Docker server', skip: contractSkip, () {
    late Dio dio;
    late ServerConnection connection;
    late TestUser reader;
    late TestUser doer;
    late Seeder asDoer;
    late int projectId;
    late String runId;

    setUpAll(() async {
      dio = contractDio();
      connection = await DioServerConnector(dio)
          .connect('http://localhost:$contractServerPort');
      reader = await registerAndLogin(dio, connection);
      doer = await registerAndLogin(dio, connection);
      asDoer = Seeder(dio, connection, doer);
      runId = Random.secure().nextInt(1 << 16).toRadixString(16);
      projectId = await asDoer.create('/projects', {
        'title': 'Activity $runId',
      });
      await asDoer.post('/projects/$projectId/users', {
        'username': reader.username,
        'permission': 1,
      });
    });

    tearDownAll(() => dio.close(force: true));

    for (final apiVersion in ApiVersion.values) {
      group('over ${apiVersion.pathSegment}', () {
        late NotificationsPort reads;
        late _RecordingWrites writes;
        late AppDatabase db;
        late ActivitySync sync;
        late FakeNotificationGateway gateway;
        late ActivityNotifier notifier;
        late Account account;

        /// The doer's task with the reader assigned (and mentioned).
        Future<int> assignedTask(String title) async {
          final taskId = await asDoer.create('/projects/$projectId/tasks', {
            'title': title,
          });
          await asDoer.post('/tasks/$taskId/assignees', {'user_id': reader.id});
          if (connection.info.taskCommentsEnabled) {
            final name = reader.username;
            await asDoer.post('/tasks/$taskId/comments', {
              'comment':
                  '<p>Check the <strong>pots</strong> '
                  '<mention-user data-id="$name">@$name</mention-user></p>',
            });
          }
          return taskId;
        }

        Set<String> expectedKinds() => {
          'task.assigned',
          if (connection.info.taskCommentsEnabled) 'task.comment',
        };

        /// Syncs until the task's notifications have arrived: the server
        /// stores them from asynchronous event handlers.
        Future<List<ServerNotification>> syncUntilArrived(int taskId) async {
          final deadline = DateTime.now().add(const Duration(seconds: 30));
          while (true) {
            final fresh = await sync.run();
            final ofTask = [
              for (final n in fresh)
                if (n.taskId == taskId) n,
            ];
            if (ofTask
                    .map((n) => n.name)
                    .toSet()
                    .containsAll(expectedKinds()) ||
                DateTime.now().isAfter(deadline)) {
              return fresh;
            }
            await Future<void>.delayed(const Duration(milliseconds: 500));
          }
        }

        Future<ServerNotification> onServer(int id) async =>
            (await reads.list()).items.singleWhere((n) => n.id == id);

        setUpAll(() async {
          final only = onlyApiVersion(connection, apiVersion);
          final authenticated = createAuthenticatedDio(
            base: dio,
            connection: only,
            tokens: StaticJwt(reader.jwt),
          );
          reads = createReadClient(
            dio: authenticated,
            connection: only,
          ).notifications;
          writes = _RecordingWrites(
            createWriteClient(
              dio: authenticated,
              connection: only,
            ).notifications,
          );
          db = testDatabase();
          sync = ActivitySync(db: db, read: reads, write: writes);
          gateway = FakeNotificationGateway();
          final preferences = FakeNotificationPreferencesStore();
          addTearDown(preferences.dispose);
          notifier = ActivityNotifier(
            gateway: gateway,
            preferences: preferences,
            store: MemoryPreferencesStore(),
            l10n: lookupAppLocalizations(const Locale('en')),
          );
          account = Account(
            id: 'reader-${apiVersion.pathSegment}',
            serverRoot: connection.rootUri,
            userId: reader.id,
            username: reader.username,
            displayName: reader.username,
            addedAt: DateTime.now().toUtc(),
          );
          // The history (the other version's notifications) is stored
          // without a single OS notification.
          expect(await sync.run(), isEmpty);
        });

        test('an assignment arrives, is shown once, and its read mark '
            'reaches the server', () async {
          final title = 'Water the plants ${apiVersion.pathSegment} $runId';
          final taskId = await assignedTask(title);

          final fresh = await syncUntilArrived(taskId);

          final assigned = fresh.singleWhere(
            (n) => n.taskId == taskId && n.name == 'task.assigned',
          );
          expect(assigned.projectId, projectId);
          expect(
            assigned.payload['doer'],
            containsPair('username', doer.username),
          );
          final shown = await notifier.show(
            account: account,
            db: db,
            fresh: fresh,
          );
          expect(shown, expectedKinds().length);
          final notice = gateway.activities.firstWhere(
            (a) => a.payload.contains('activity:${assigned.id}'),
          );
          expect(notice.title, title);
          expect(notice.body, '${doer.username} assigned you');
          if (connection.info.taskCommentsEnabled) {
            expect(
              gateway.activities.map((a) => a.body),
              contains(
                '${doer.username} commented: Check the pots '
                '@${reader.username}',
              ),
            );
          }
          expect(await sync.run(), isEmpty, reason: 'never twice');

          await db.serverNotificationsDao.markRead([
            assigned.id,
          ], at: DateTime.now());
          await sync.run();

          expect(writes.calls, ['markRead ${assigned.id} true']);
          expect(await db.serverNotificationsDao.pendingReads(), isEmpty);
          expect((await onServer(assigned.id)).readAt, isNotNull);
          expect(
            (await db.serverNotificationsDao.find(assigned.id))!.isRead,
            isTrue,
          );
        });

        test('"mark all read" goes out as one request when every unread one '
            'is marked', () async {
          final taskId = await assignedTask(
            'Repot the fern ${apiVersion.pathSegment} $runId',
          );
          final fresh = await syncUntilArrived(taskId);
          await db.serverNotificationsDao.markHandled(fresh.map((n) => n.id));
          writes.calls.clear();

          await db.serverNotificationsDao.markAllRead(at: DateTime.now());
          final pending = await db.serverNotificationsDao.pendingReads();
          await sync.run();

          expect(
            writes.calls,
            pending.length > 1
                ? ['markAllRead']
                : ['markRead ${pending.single.id} true'],
          );
          final onServerNow = (await reads.list()).items;
          expect(onServerNow.where((n) => n.readAt == null), isEmpty);
          expect(await db.serverNotificationsDao.unreadCount(), 0);
        });
      });
    }
  });
}
