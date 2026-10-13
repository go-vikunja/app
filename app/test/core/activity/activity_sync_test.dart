import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/activity/activity_sync.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  final noon = DateTime.utc(2026, 10, 13, 12);
  late AppDatabase db;
  late FakeSyncClient read;
  late FakeWriteClient write;
  late ActivitySync sync;

  ActivitySync syncWith({int perPage = 50}) => ActivitySync(
    db: db,
    read: read.notifications,
    write: write.notifications,
    now: () => noon,
    perPage: perPage,
  );

  /// Newest first, like the server.
  List<ServerNotification> server(
    Iterable<int> ids, {
    Set<int> read = const {},
  }) => [
    for (final id in ids.toList()..sort((a, b) => b.compareTo(a)))
      sampleNotification(id: id, readAt: read.contains(id) ? noon : null),
  ];

  setUp(() {
    db = testDatabase();
    read = FakeSyncClient();
    write = FakeWriteClient(clock: () => noon);
    sync = syncWith();
  });

  test(
    'the first run stores everything as handled and returns nothing',
    () async {
      read.serverNotifications = server([1, 2, 3]);

      expect(await sync.run(), isEmpty);

      expect(await db.serverNotificationsDao.count(), 3);
      expect(await db.serverNotificationsDao.unhandledUnread(), isEmpty);
      expect(await db.serverNotificationsDao.unreadCount(), 3);
      expect(
        (await db.syncStateDao.readAll())[SyncStateKeys.activitySyncedAt],
        noon.toIso8601String(),
      );
    },
  );

  test('a first run that finds nothing still counts: what arrives later is '
      'new', () async {
    expect(await sync.run(), isEmpty);
    read.serverNotifications = server([1]);

    expect((await sync.run()).map((n) => n.id), [1]);
  });

  test(
    'a later run returns only what is new and unread, oldest first',
    () async {
      read.serverNotifications = server([1, 2]);
      await sync.run();
      read.serverNotifications = server([1, 2, 3, 4, 5], read: {4});

      final fresh = await sync.run();

      expect(fresh.map((n) => n.id), [3, 5]);
      expect((await db.serverNotificationsDao.find(4))!.isRead, isTrue);
      // Returned until something handles them.
      expect((await sync.run()).map((n) => n.id), [3, 5]);
      await db.serverNotificationsDao.markHandled([3, 5]);
      expect(await sync.run(), isEmpty);
    },
  );

  test('stops at the first page that holds a stored notification', () async {
    sync = syncWith(perPage: 2);
    read.serverNotifications = server([1, 2]);
    await sync.run();
    read.requests.clear();
    read.serverNotifications = server([1, 2, 3, 4, 5]);

    final fresh = await sync.run();

    // Page 1: 5, 4; page 2: 3, 2 (stored).
    expect(read.requests, ['notifications 1', 'notifications 2']);
    expect(fresh.map((n) => n.id), [3, 4, 5]);
  });

  test('reads three pages at most', () async {
    sync = syncWith(perPage: 2);
    await sync.run();
    read.requests.clear();
    read.serverNotifications = server([for (var id = 1; id <= 10; id++) id]);

    final fresh = await sync.run();

    expect(read.requests, [
      'notifications 1',
      'notifications 2',
      'notifications 3',
    ]);
    expect(fresh.map((n) => n.id), [5, 6, 7, 8, 9, 10]);
  });

  group('the hourly read-back', () {
    ActivitySync later(Duration after, {List<int>? withdrawn}) => ActivitySync(
      db: db,
      read: read.notifications,
      write: write.notifications,
      now: () => noon.add(after),
      perPage: 2,
      withdraw: (ids) async => withdrawn?.addAll(ids),
    );

    test(
      'goes past the stored ones while an older one is unread here, so '
      'what was read on the web is read here too, and leaves the tray',
      () async {
        sync = syncWith(perPage: 2);
        read.serverNotifications = server([1, 2, 3, 4, 5, 6]);
        await sync.run();
        read
          ..requests.clear()
          ..serverNotifications = server(
            [1, 2, 3, 4, 5, 6, 7],
            read: {1, 2, 3, 4, 5, 6},
          );
        final withdrawn = <int>[];

        final fresh = await later(const Duration(minutes: 59)).run();
        expect(read.requests, ['notifications 1']);
        expect(await db.serverNotificationsDao.unreadCount(), 6);
        expect(fresh.map((n) => n.id), [7]);

        read.requests.clear();
        await later(const Duration(hours: 1), withdrawn: withdrawn).run();

        expect(read.requests, [
          'notifications 1',
          'notifications 2',
          'notifications 3',
          'notifications 4',
        ]);
        expect(await db.serverNotificationsDao.unreadCount(), 1);
        expect(withdrawn, unorderedEquals([1, 2, 3, 4, 5]));
      },
    );

    test('stops once nothing older is unread here', () async {
      sync = syncWith(perPage: 2);
      read.serverNotifications = server([1, 2, 3, 4, 5, 6], read: {1, 2, 3});
      await sync.run();
      read.requests.clear();

      await later(const Duration(hours: 1)).run();

      // Page 1: 6, 5; page 2: 4, 3 (nothing unread below 3).
      expect(read.requests, ['notifications 1', 'notifications 2']);
    });

    test('what it finds that was never stored is old, never new', () async {
      sync = syncWith(perPage: 2);
      read.serverNotifications = server([5, 8, 9, 10]);
      await sync.run();
      read.serverNotifications = server([for (var id = 1; id <= 10; id++) id]);

      final fresh = await later(const Duration(hours: 1)).run();

      expect(fresh, isEmpty);
      expect(await db.serverNotificationsDao.count(), 6);
      expect(await db.serverNotificationsDao.unhandledUnread(), isEmpty);
    });

    test('pull-to-refresh does it at once', () async {
      sync = syncWith(perPage: 2);
      read.serverNotifications = server([1, 2, 3, 4]);
      await sync.run();
      read
        ..requests.clear()
        ..serverNotifications = server([1, 2, 3, 4], read: {1, 2, 3, 4});

      await sync.run(wholeWindow: true);

      expect(read.requests, ['notifications 1', 'notifications 2']);
      expect(await db.serverNotificationsDao.unreadCount(), 0);
    });
  });

  test('a failed pull throws and keeps what is stored', () async {
    read.serverNotifications = server([1]);
    await sync.run();
    read.beforeRequest = (_) =>
        throw const NetworkFailure(NetworkProblem.unreachable);

    await expectLater(sync.run(), throwsA(isA<NetworkFailure>()));

    expect(await db.serverNotificationsDao.count(), 1);
  });

  group('read marks', () {
    test('are sent one by one and cleared', () async {
      read.serverNotifications = server([1, 2, 3]);
      await sync.run();
      await db.serverNotificationsDao.markRead([1, 3], at: noon);

      await sync.run();

      expect(write.notifications.marked, [(1, true), (3, true)]);
      expect(write.notifications.markedAll, 0);
      expect(await db.serverNotificationsDao.pendingReads(), isEmpty);
      expect(await db.serverNotificationsDao.unreadCount(), 1);
    });

    test(
      'go out as one "mark all read" when every unread one is marked',
      () async {
        read.serverNotifications = server([1, 2, 3], read: {2});
        await sync.run();
        await db.serverNotificationsDao.markAllRead(at: noon);

        await sync.run();

        expect(write.requests, ['notifications read all']);
        expect(await db.serverNotificationsDao.pendingReads(), isEmpty);
      },
    );

    test('are sent one by one when something unread arrived since the '
        'list was marked', () async {
      read.serverNotifications = server([1, 2]);
      await sync.run();
      await db.serverNotificationsDao.markAllRead(at: noon);
      read.serverNotifications = server([1, 2, 3]);

      final fresh = await sync.run();

      expect(write.notifications.markedAll, 0);
      expect(write.notifications.marked, [(1, true), (2, true)]);
      expect(fresh.map((n) => n.id), [3]);
    });

    test('stay pending after a failure a later run may get past', () async {
      read.serverNotifications = server([1, 2]);
      await sync.run();
      await db.serverNotificationsDao.markRead([1], at: noon);
      write.beforeRequest = (_) =>
          throw const NetworkFailure(NetworkProblem.timeout);

      await sync.run();

      expect(await db.serverNotificationsDao.pendingReads(), [
        (id: 1, read: true),
      ]);
      expect((await db.serverNotificationsDao.find(1))!.isRead, isTrue);

      write.beforeRequest = null;
      await sync.run();
      expect(await db.serverNotificationsDao.pendingReads(), isEmpty);
      expect(write.notifications.marked, [(1, true)]);
    });

    test('are dropped when the server refuses them for good', () async {
      read.serverNotifications = server([1]);
      await sync.run();
      await db.serverNotificationsDao.markRead([1], at: noon);
      write.beforeRequest = (_) => throw const Forbidden();

      await sync.run();

      expect(await db.serverNotificationsDao.pendingReads(), isEmpty);
    });
  });

  test('keeps the newest 200', () async {
    read.serverNotifications = server([for (var id = 1; id <= 150; id++) id]);
    await sync.run();
    read.serverNotifications = server([for (var id = 1; id <= 300; id++) id]);

    await sync.run();

    expect(await db.serverNotificationsDao.count(), 200);
    expect(await db.serverNotificationsDao.maxId(), 300);
  });

  test('a call during a run joins it', () async {
    read.serverNotifications = server([1]);

    await Future.wait([sync.run(), sync.run()]);

    expect(read.requests, ['notifications 1']);
  });
}
