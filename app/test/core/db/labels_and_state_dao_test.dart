import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());

  group('labels', () {
    const alice = User(id: 7, username: 'alice');
    const urgent = Label(id: 3, title: 'urgent', createdBy: alice);
    const later = Label(id: 4, title: 'later');

    test('round trip with the creator, ordered by id', () async {
      await db.labelsDao.upsertAll(const [later, urgent]);

      final all = await db.labelsDao.loadAll();

      expect(all, [urgent, later]);
      expect(all.first.createdBy, alice);
      expect(all.last.createdBy, isNull);
    });

    test('purging keeps only the given ids', () async {
      await db.labelsDao.upsertAll(const [later, urgent]);

      expect(await db.labelsDao.purgeNotIn([4]), 1);
      expect(await db.labelsDao.loadAll(), [later]);
    });

    test('the stream follows changes', () async {
      final seen = <List<Label>>[];
      final subscription = db.labelsDao.watchAll().listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await db.labelsDao.upsertAll(const [urgent]);
      await pumpEventQueue();

      expect(seen, [
        isEmpty,
        [urgent],
      ]);
    });
  });

  group('sync state', () {
    test('writes, replaces and removes keys', () async {
      await db.syncStateDao.write({'phase': 'tasks', 'last_id': '10'});
      await db.syncStateDao.write({'last_id': '20', 'phase': null});

      expect(await db.syncStateDao.readAll(), {'last_id': '20'});
    });

    test('one value is watched until it is removed', () async {
      final seen = <String?>[];
      final subscription = db.syncStateDao
          .watchValue('user_settings')
          .listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await db.syncStateDao.write({'user_settings': '{}'});
      await pumpEventQueue();
      await db.syncStateDao.write({'user_settings': null});
      await pumpEventQueue();

      expect(seen, [null, '{}', null]);
    });
  });

  group('users', () {
    const ana = User(id: 20, username: 'ana', name: 'Ana Lima');

    test('found by id, without the email, which is not stored', () async {
      await db.usersDao.upsertAll([
        const User(id: 20, username: 'ana', name: 'Ana Lima', email: 'a@x.io'),
      ]);

      expect(await db.usersDao.find(20), ana);
      expect(await db.usersDao.find(21), isNull);
    });

    test('the stream follows changes, ordered by id', () async {
      final seen = <List<User>>[];
      final subscription = db.usersDao.watchAll().listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await db.usersDao.upsertAll(const [User(id: 30, username: 'zoe'), ana]);
      await pumpEventQueue();

      expect(seen, [
        isEmpty,
        [ana, const User(id: 30, username: 'zoe')],
      ]);
    });
  });
}
