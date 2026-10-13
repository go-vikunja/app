import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/server_notifications_dao.dart';

import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ServerNotificationsDao dao;
  final noon = DateTime.utc(2026, 10, 13, 12);

  setUp(() {
    db = testDatabase();
    dao = db.serverNotificationsDao;
  });

  test('upsertAll stores the payload and the server read state; a new read '
      'one counts as handled', () async {
    await dao.upsertAll([
      sampleNotification(id: 1),
      sampleNotification(id: 2, readAt: noon),
    ], handled: false);

    final unread = (await dao.find(1))!;
    expect(unread.name, 'task.assigned');
    expect(unread.taskId, 1);
    expect(unread.projectId, 7);
    expect(unread.payload['doer'], {
      'id': 9,
      'username': 'anna',
      'name': 'Anna',
    });
    expect(unread.isRead, isFalse);
    expect((await dao.find(2))!.readAt, noon);
    expect((await dao.unhandledUnread()).map((n) => n.id), [1]);
    expect(await dao.maxId(), 2);
    expect(await dao.existingIds([1, 3]), {1});
  });

  test('upsertAll keeps a pending mark with its local read time and whether '
      'a row was handled', () async {
    await dao.upsertAll([
      sampleNotification(id: 1),
      sampleNotification(id: 2),
    ], handled: true);
    await dao.markRead([1], at: noon);

    await dao.upsertAll([
      sampleNotification(id: 1, name: 'task.comment'),
      sampleNotification(id: 2, readAt: noon.add(const Duration(hours: 1))),
      sampleNotification(id: 3),
    ], handled: false);

    final first = (await dao.find(1))!;
    expect(first.name, 'task.comment');
    expect(first.readAt, noon);
    expect(await dao.pendingReads(), [(id: 1, read: true)]);
    expect((await dao.find(2))!.readAt, noon.add(const Duration(hours: 1)));
    expect((await dao.unhandledUnread()).map((n) => n.id), [3]);
  });

  test(
    'watchAll is newest first; watchUnreadCount follows local marks',
    () async {
      await dao.upsertAll([
        sampleNotification(id: 1),
        sampleNotification(id: 3),
        sampleNotification(id: 2),
      ], handled: false);
      final counts = <int>[];
      final subscription = dao.watchUnreadCount().listen(counts.add);
      addTearDown(subscription.cancel);

      expect((await dao.watchAll().first).map((n) => n.id), [3, 2, 1]);
      await pumpEventQueue();
      await dao.markRead([2], at: noon);
      await pumpEventQueue();
      await dao.markAllRead(at: noon);
      await pumpEventQueue();

      expect(counts, [3, 2, 0]);
      expect(await dao.pendingReads(), [
        (id: 1, read: true),
        (id: 2, read: true),
        (id: 3, read: true),
      ]);
      expect((await dao.watchAll().first).every((n) => n.isRead), isTrue);
    },
  );

  test('markRead leaves a notification that is read already alone', () async {
    await dao.upsertAll([
      sampleNotification(id: 1, readAt: noon),
    ], handled: true);

    await dao.markRead([1], at: noon.add(const Duration(days: 1)));

    expect((await dao.find(1))!.readAt, noon);
    expect(await dao.pendingReads(), isEmpty);
  });

  test('clearPending lets the next pull bring the server read time', () async {
    await dao.upsertAll([sampleNotification(id: 1)], handled: true);
    await dao.markRead([1], at: noon);

    await dao.clearPending([1]);
    expect(await dao.pendingReads(), isEmpty);
    expect((await dao.find(1))!.readAt, noon);

    final serverTime = noon.add(const Duration(minutes: 1));
    await dao.upsertAll([
      sampleNotification(id: 1, readAt: serverTime),
    ], handled: false);
    expect((await dao.find(1))!.readAt, serverTime);
  });

  test('markHandled takes notifications out of the unhandled ones', () async {
    await dao.upsertAll([
      sampleNotification(id: 1),
      sampleNotification(id: 2),
    ], handled: false);

    await dao.markHandled([1]);

    expect((await dao.unhandledUnread()).map((n) => n.id), [2]);
  });

  test('pruneToNewest keeps the newest and every pending mark', () async {
    await dao.upsertAll([
      for (var id = 1; id <= 6; id++) sampleNotification(id: id),
    ], handled: true);
    await dao.markRead([1], at: noon);

    expect(await dao.pruneToNewest(3), 2);

    final ids = (await dao.watchAll().first).map((n) => n.id).toSet();
    expect(ids, {1, 4, 5, 6});
  });

  test('a payload that is not an object reads as empty', () async {
    await db.customStatement(
      'INSERT INTO server_notifications '
      '(id, name, payload, created, read_at, read_pending, notified) '
      "VALUES (5, 'task.comment', 'garbage', 1760000000000, NULL, NULL, 0)",
    );

    final stored = (await dao.find(5))!;
    expect(stored.payload, isEmpty);
    expect(stored.taskId, isNull);
    expect(stored, isA<ServerNotification>());
  });
}
