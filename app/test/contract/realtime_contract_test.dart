@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/activity/activity_sync.dart';
import 'package:vikunja_mobile/core/activity/activity_tray.dart';
import 'package:vikunja_mobile/core/realtime/realtime_connection.dart';
import 'package:vikunja_mobile/core/repositories/local/local_activity_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

import '../helpers/notification_fakes.dart';
import '../helpers/recording_sync_engine.dart';
import '../helpers/test_database.dart';
import 'helpers.dart';

/// The real port, with its pulls counted.
final class _CountingReads implements NotificationsPort {
  new(this._real);

  final NotificationsPort _real;
  int started = 0;
  int finished = 0;

  @override
  Future<Page<ServerNotification>> list({int page = 1, int? perPage}) async {
    started++;
    try {
      return await _real.list(page: page, perPage: perPage);
    } finally {
      finished++;
    }
  }
}

// The reader's task gets a comment from the doer (an assignment when the
// server has comments off): the reader's socket, over the real connector,
// stores it in the inbox without a pull and asks for a sync. Two users for
// the whole file and one upgrade per API version: /register, /login and
// the upgrade share the limiter, whose 429 the connection waits out.
void main() {
  group('realtime against the local Docker server', skip: contractSkip, () {
    late Dio dio;
    late ServerConnection connection;
    late TestUser reader;
    late TestUser doer;
    late Seeder asReader;
    late Seeder asDoer;
    late int projectId;
    late String runId;

    setUpAll(() async {
      dio = contractDio();
      connection = await DioServerConnector(dio)
          .connect('http://localhost:$contractServerPort');
      reader = await registerAndLogin(dio, connection);
      doer = await registerAndLogin(dio, connection);
      asReader = Seeder(dio, connection, reader);
      asDoer = Seeder(dio, connection, doer);
      runId = Random.secure().nextInt(1 << 16).toRadixString(16);
      projectId = await asReader.create('/projects', {
        'title': 'Realtime $runId',
      });
      await asReader.post('/projects/$projectId/users', {
        'username': doer.username,
        'permission': 1,
      });
    });

    tearDownAll(() => dio.close(force: true));

    for (final apiVersion in ApiVersion.values) {
      test('over ${apiVersion.pathSegment}: a comment by the doer reaches '
          'the inbox of the reader within 3 s without a pull, and a sync is '
          'requested', () async {
        final only = onlyApiVersion(connection, apiVersion);
        final tokens = StaticJwt(reader.jwt);
        final authenticated = createAuthenticatedDio(
          base: dio,
          connection: only,
          tokens: tokens,
        );
        final reads = _CountingReads(
          createReadClient(dio: authenticated, connection: only).notifications,
        );
        final db = testDatabase();
        final repository = LocalActivityRepository(
          db,
          ActivitySync(
            db: db,
            read: reads,
            write: createWriteClient(
              dio: authenticated,
              connection: only,
            ).notifications,
          ),
          accountId: 'reader',
          tray: ActivityTray(FakeNotificationGateway()),
        );
        addTearDown(repository.dispose);
        final engine = RecordingSyncEngine(
          SyncIdle(lastSyncedAt: DateTime.now()),
        );
        final realtime = RealtimeConnection(
          connector: const IoRealtimeConnector(),
          url: realtimeUri(only),
          headers: const {'User-Agent': 'Rurana contract tests'},
          tokens: tokens,
          engine: engine,
          activity: repository,
        );
        addTearDown(realtime.dispose);
        expect(realtimeUri(only).path, '/api/${apiVersion.pathSegment}/ws');

        realtime.start();
        await realtime.states
            .firstWhere((state) => state == RealtimeState.live)
            .timeout(const Duration(minutes: 3));
        // The catch-up after connecting.
        while (reads.finished == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        final pullsBefore = reads.started;
        final unreadBefore = await repository.watchUnreadCount().first;

        final taskId = await asReader.create('/projects/$projectId/tasks', {
          'title': 'Realtime ${apiVersion.pathSegment} $runId',
        });
        final kind = connection.info.taskCommentsEnabled
            ? 'task.comment'
            : 'task.assigned';
        final arrived = repository
            .watchAll()
            .map(
              (all) => [
                for (final n in all)
                  if (n.taskId == taskId && n.name == kind) n,
              ],
            )
            .firstWhere((matching) => matching.isNotEmpty);
        final sinceWrite = Stopwatch()..start();
        if (kind == 'task.comment') {
          await asDoer.post('/tasks/$taskId/comments', {
            'comment': '<p>From the doer</p>',
          });
        } else {
          await asDoer.post('/tasks/$taskId/assignees', {'user_id': reader.id});
        }
        final stored = (await arrived.timeout(const Duration(seconds: 3)))
            .single;

        expect(sinceWrite.elapsed, lessThan(const Duration(seconds: 3)));
        expect(reads.started, pullsBefore, reason: 'no pull');
        expect(realtime.state, RealtimeState.live);
        expect(stored.payload['doer'], containsPair('username', doer.username));
        expect(await db.serverNotificationsDao.unhandledUnread(), isEmpty);
        expect(await repository.watchUnreadCount().first, unreadBefore + 1);
        final listed = (await reads.list()).items.singleWhere(
          (n) => n.id == stored.id,
        );
        expect(stored, listed);
        expect(stored.payload, listed.payload);

        expect(engine.refreshCalls, 0);
        await Future<void>.delayed(
          RealtimeConnection.syncDebounce + const Duration(milliseconds: 500),
        );
        expect(engine.refreshCalls, 1);
      });
    }
  });
}
