import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/local/local_label_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_user_repository.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());

  group('LocalLabelRepository', () {
    final now = DateTime.utc(2026, 10, 11, 12);
    late FakeWriteClient write;
    late FakeSyncClient read;
    late LocalLabelRepository repository;

    setUp(() async {
      write = FakeWriteClient(clock: () => now);
      read = FakeSyncClient();
      repository = LocalLabelRepository(db, write, read, now: () => now);
      addTearDown(repository.dispose);
      await db.labelsDao.upsertAll([
        sampleLabel(id: 1, title: 'urgent'),
        sampleLabel(id: 2, title: 'Home'),
      ]);
    });

    /// The server stores the label, then the answer is lost.
    void loseAnswers() {
      write.afterRequest = (_) async {
        read.allLabels = [...write.serverLabels.values];
        throw const NetworkFailure(NetworkProblem.timeout);
      };
    }

    Label serverLabel(int id, String title, {required DateTime created}) =>
        Label(id: id, title: title, created: created);

    test('lists the labels by title, whatever the case', () async {
      final labels = await repository.watchAll().first;

      expect(labels.map((label) => label.title), ['Home', 'urgent']);
    });

    test('a created label is stored as the server answered it', () async {
      final created = await repository.create(
        const NewLabel(title: 'errand', hexColor: '0ead69'),
      );

      expect(write.requests, ['create label errand']);
      expect(created.id, 900);
      expect(created.hexColor, '0ead69');
      final labels = await repository.watchAll().first;
      expect(labels.map((label) => label.title), ['errand', 'Home', 'urgent']);
      expect(labels.first, created);
    });

    test('a failed create throws and stores nothing', () async {
      write.beforeRequest = (_) =>
          throw const NetworkFailure(NetworkProblem.unreachable);

      await expectLater(
        repository.create(const NewLabel(title: 'errand')),
        throwsA(isA<NetworkFailure>()),
      );

      expect(write.requests, ['create label errand']);
      expect(read.requests, ['labels page 1 search errand']);
      expect(await db.labelsDao.loadAll(), hasLength(2));
    });

    test('a create the server rejects is not looked for', () async {
      write.beforeRequest = (_) =>
          throw const ValidationFailed(message: 'invalid');

      await expectLater(
        repository.create(const NewLabel(title: 'errand')),
        throwsA(isA<ValidationFailed>()),
      );

      expect(read.requests, isEmpty);
    });

    test('a create whose answer was lost adopts the label the server '
        'stored', () async {
      loseAnswers();

      final created = await repository.create(const NewLabel(title: 'errand'));

      expect(created.id, 900);
      expect(write.requests, ['create label errand']);
      expect(read.requests, ['labels page 1 search errand']);
      expect((await repository.watchAll().first).map((label) => label.title), [
        'errand',
        'Home',
        'urgent',
      ]);
    });

    test('the lookup takes the label of exactly that title with the highest '
        'id, created inside the window and new here', () async {
      write.beforeRequest = (_) =>
          throw const NetworkFailure(NetworkProblem.timeout);
      read.allLabels = [
        serverLabel(1, 'urgent', created: now),
        serverLabel(30, 'Errand', created: now),
        serverLabel(31, 'errand run', created: now),
        serverLabel(
          32,
          'errand',
          created: now.subtract(const Duration(minutes: 30)),
        ),
        serverLabel(
          33,
          'errand',
          created: now.subtract(const Duration(minutes: 59)),
        ),
        serverLabel(
          34,
          'errand',
          created: now.subtract(const Duration(hours: 2)),
        ),
      ];

      final found = await repository.create(const NewLabel(title: 'errand'));
      expect(found.id, 33);

      await expectLater(
        repository.create(const NewLabel(title: 'urgent')),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('with the lookup failing too, the failure propagates and the next '
        'create of the title looks before it posts', () async {
      loseAnswers();
      read.beforeRequest = (_) =>
          throw const NetworkFailure(NetworkProblem.unreachable);

      await expectLater(
        repository.create(const NewLabel(title: 'errand')),
        throwsA(
          isA<NetworkFailure>().having(
            (f) => f.problem,
            'problem',
            NetworkProblem.timeout,
          ),
        ),
      );
      expect(await db.labelsDao.loadAll(), hasLength(2));

      read.beforeRequest = null;
      write.afterRequest = null;
      final adopted = await repository.create(const NewLabel(title: 'errand'));

      expect(adopted.id, 900);
      expect(write.requests, ['create label errand']);
      expect(write.serverLabels, hasLength(1));
    });

    test('the next create posts when the lookup finds nothing, and looks '
        'no more once it succeeded', () async {
      write.beforeRequest = (_) =>
          throw const NetworkFailure(NetworkProblem.timeout);
      await expectLater(
        repository.create(const NewLabel(title: 'errand')),
        throwsA(isA<NetworkFailure>()),
      );

      write.beforeRequest = null;
      final created = await repository.create(const NewLabel(title: 'errand'));
      expect(created.id, 900);
      expect(read.requests, [
        'labels page 1 search errand',
        'labels page 1 search errand',
      ]);

      await repository.create(const NewLabel(title: 'errand'));
      expect(read.requests, hasLength(2));
    });

    test('findOrCreate adopts a label the server has under that title, '
        'ignoring case, instead of making a second one', () async {
      read.allLabels = [
        serverLabel(40, 'einkaufen', created: now),
        serverLabel(41, 'Einkauf', created: now),
        serverLabel(42, 'einkauf', created: now),
      ];

      final found = await repository.findOrCreate(
        const NewLabel(title: 'EINKAUF'),
      );

      expect(found.id, 41);
      expect(write.requests, isEmpty);
      expect(read.requests, ['labels page 1 search EINKAUF']);
      expect(
        (await repository.watchAll().first).map((label) => label.id),
        contains(41),
      );
      expect(
        (await repository.findOrCreate(const NewLabel(title: 'einkauf'))).id,
        42,
      );
    });

    test('findOrCreate creates a label the server does not have', () async {
      final created = await repository.findOrCreate(
        const NewLabel(title: 'errand'),
      );

      expect(created.id, 900);
      expect(read.requests, ['labels page 1 search errand']);
      expect(write.requests, ['create label errand']);
    });
  });

  group('LocalUserRepository', () {
    late FakeSyncClient read;
    late LocalUserRepository repository;
    const ana = User(id: 20, username: 'ana', name: 'Ana Lima');
    const ben = User(id: 21, username: 'ben');

    setUp(() {
      read = FakeSyncClient()..projectUsers[7] = [ana, ben];
      repository = LocalUserRepository(db, read);
      addTearDown(repository.dispose);
    });

    test('a search asks the server with the trimmed query and remembers '
        'what it found', () async {
      final found = await repository.searchAssignees(7, ' lima ');

      expect(read.requests, ['users 7 lima']);
      expect(found, [ana]);
      expect(await repository.knownUsers(), [ana]);

      expect(await repository.searchAssignees(7, ''), [ana, ben]);
      expect(await repository.knownUsers(), [ana, ben]);
    });

    test('a failed search throws and the known users stay as they '
        'were', () async {
      await db.usersDao.upsertAll([ben]);
      read.beforeRequest = (_) =>
          throw const NetworkFailure(NetworkProblem.unreachable);

      await expectLater(
        repository.searchAssignees(7, 'ana'),
        throwsA(isA<NetworkFailure>()),
      );

      expect(await repository.knownUsers(), [ben]);
    });

    test('the known users stream follows searches and syncs', () async {
      final seen = <List<User>>[];
      final subscription = repository.watchKnownUsers().listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await repository.searchAssignees(7, 'ana');
      await pumpEventQueue();
      await db.usersDao.upsertAll([ben]);
      await pumpEventQueue();

      expect(seen, [
        isEmpty,
        [ana],
        [ana, ben],
      ]);
    });
  });
}
