import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';
import 'package:vikunja_mobile/core/repositories/label_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_label_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_user_repository.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());

  group('LocalLabelRepository', () {
    final now = DateTime.utc(2026, 10, 11, 12);
    late FakeWriteClient write;
    late FakeSyncClient read;
    late RecordingSyncEngine sync;
    late LocalLabelRepository repository;

    setUp(() async {
      write = FakeWriteClient(clock: () => now);
      read = FakeSyncClient();
      sync = RecordingSyncEngine();
      repository = LocalLabelRepository(
        db,
        write,
        read,
        sync: sync,
        now: () => now,
      );
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

    test(
      'lists an umlaut among its base letter, the same title by id',
      () async {
        await db.labelsDao.upsertAll([
          sampleLabel(id: 3, title: 'Zahlung'),
          sampleLabel(id: 4, title: 'Ärger'),
          sampleLabel(id: 5, title: 'apfel'),
          sampleLabel(id: 6, title: 'HOME'),
        ]);

        final labels = await repository.watchAll().first;

        expect(labels.map((label) => label.title), [
          'apfel',
          'Ärger',
          'Home',
          'HOME',
          'urgent',
          'Zahlung',
        ]);
      },
    );

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

    group('a title with a U+0000 is the one the server stores, without it', () {
      const withNul = NewLabel(
        title: 'err\u0000and',
        hexColor: '0ead69',
        description: '<p>Outside</p>',
      );

      test('findOrCreate finds the label of that title', () async {
        read.allLabels = [serverLabel(40, 'errand', created: now)];

        final found = await repository.findOrCreate(withNul);

        expect(found.id, 40);
        expect(read.requests, ['labels page 1 search errand']);
        expect(write.requests, isEmpty);
      });

      test('a create sends it with the colour and description', () async {
        final created = await repository.create(withNul);

        expect(write.requests, ['create label errand']);
        expect(created.title, 'errand');
        expect(created.hexColor, '0ead69');
        expect(created.description, '<p>Outside</p>');
      });

      test('a create whose answer was lost adopts the label', () async {
        loseAnswers();

        final created = await repository.create(withNul);

        expect(created.id, 900);
        expect(read.requests, ['labels page 1 search errand']);
        expect(write.serverLabels, hasLength(1));
      });
    });

    group('update', () {
      const me = User(id: 5, username: 'me');

      setUp(() async {
        const mine = Label(
          id: 3,
          title: 'errand',
          description: '<p>Outside</p>',
          hexColor: 'ffbe0b',
          createdBy: me,
        );
        await db.labelsDao.upsertAll([mine]);
        write.serverLabels[3] = mine;
      });

      test('sends only the changes, stores the answer at once and syncs '
          'after it', () async {
        final changed = await repository.update(
          3,
          const LabelChanges(title: 'errands', hexColor: ''),
        );

        expect(write.requests, [
          'update label 3 LabelChanges(title, hexColor)',
        ]);
        expect(changed.title, 'errands');
        expect(changed.hexColor, '');
        expect(changed.description, '<p>Outside</p>');
        final stored = (await db.labelsDao.loadAll()).singleWhere(
          (label) => label.id == 3,
        );
        expect(stored, changed);
        expect(stored.createdBy, me);
        expect(sync.refreshAfterWriteCalls, 1);
      });

      test('keeps the stored creator when the answer has none', () async {
        write.serverLabels[3] = const Label(id: 3, title: 'errand');

        await repository.update(3, const LabelChanges(title: 'errands'));

        final stored = (await db.labelsDao.loadAll()).singleWhere(
          (label) => label.id == 3,
        );
        expect(stored.title, 'errands');
        expect(stored.createdBy, me);
      });

      test('refuses a blank or too long title before any request', () async {
        for (final title in ['', '   ', 'x' * 251]) {
          await expectLater(
            repository.update(3, LabelChanges(title: title)),
            throwsArgumentError,
          );
        }
        expect(
          (await repository.update(3, LabelChanges(title: 'ä' * 250))).title,
          'ä' * 250,
        );
        expect(write.requests, hasLength(1));
      });

      test("another user's label is refused and nothing changes", () async {
        write.labels.othersLabels.add(3);

        await expectLater(
          repository.update(3, const LabelChanges(title: 'mine now')),
          throwsA(isA<Forbidden>()),
        );

        expect(
          (await db.labelsDao.loadAll()).map((label) => label.title),
          containsAll(['errand', 'urgent', 'Home']),
        );
        expect(sync.refreshAfterWriteCalls, 0);
      });

      test('a failure changes nothing here', () async {
        write.beforeRequest = (_) =>
            throw const NetworkFailure(NetworkProblem.unreachable);

        await expectLater(
          repository.update(3, const LabelChanges(title: 'errands')),
          throwsA(isA<NetworkFailure>()),
        );

        expect(
          (await db.labelsDao.loadAll()).map((label) => label.title),
          contains('errand'),
        );
        expect(sync.refreshAfterWriteCalls, 0);
      });

      test('a label gone on the server goes here too', () async {
        write.serverLabels.remove(3);

        await expectLater(
          repository.update(3, const LabelChanges(title: 'errands')),
          throwsA(isA<NotFound>().having((f) => f.code, 'code', 8002)),
        );

        expect(
          (await db.labelsDao.loadAll()).map((label) => label.id),
          isNot(contains(3)),
        );
        expect(sync.refreshAfterWriteCalls, 1);
      });
    });

    group('delete', () {
      setUp(() async {
        await db.projectsDao.upsertAll([const Project(id: 1, title: 'Inbox')]);
        write.serverLabels[1] = sampleLabel(id: 1, title: 'urgent');
        await db.tasksDao.upsertAll([
          sampleTask(
            id: 10,
            title: 'Call',
            labels: [
              sampleLabel(id: 1, title: 'urgent'),
              sampleLabel(id: 2, title: 'Home'),
            ],
          ),
        ]);
      });

      test('removes the label from every task and the queued edits, and '
          'syncs after it', () async {
        await db.outboxDao.queueUpdate(
          10,
          const TaskChanges(
            title: 'Call back',
            labels: IdSetChange(removed: {1}),
          ),
          now: now,
        );

        await repository.delete(1);

        expect(write.requests, ['delete label 1']);
        expect(write.serverLabels, isNot(contains(1)));
        expect((await db.labelsDao.loadAll()).map((label) => label.id), [2]);
        expect((await db.tasksDao.find(10))!.labels.map((label) => label.id), [
          2,
        ]);
        final op = (await db.outboxDao.all()).single;
        expect(
          decodeTaskChanges(op.payload),
          const TaskChanges(title: 'Call back'),
        );
        expect(sync.refreshAfterWriteCalls, 1);
      });

      test('a label gone already is deleted here as well', () async {
        write.serverLabels.remove(1);

        await repository.delete(1);

        expect((await db.labelsDao.loadAll()).map((label) => label.id), [2]);
      });

      test("another user's label is refused and stays", () async {
        write.labels.othersLabels.add(1);

        await expectLater(repository.delete(1), throwsA(isA<Forbidden>()));

        expect((await db.tasksDao.find(10))!.labels.map((label) => label.id), [
          1,
          2,
        ]);
        expect(sync.refreshAfterWriteCalls, 0);
      });

      test('a failed sync after it is quiet', () async {
        sync.error = const NetworkFailure(NetworkProblem.unreachable);

        await repository.delete(1);
        await pumpEventQueue();

        expect(sync.refreshAfterWriteCalls, 1);
      });
    });

    test("a label is its creator's own", () {
      const me = User(id: 5, username: 'me');
      const other = User(id: 6, username: 'other');

      expect(
        isOwnLabel(const Label(id: 1, title: 'a', createdBy: me), 5),
        isTrue,
      );
      expect(
        isOwnLabel(const Label(id: 1, title: 'a', createdBy: other), 5),
        isFalse,
      );
      expect(isOwnLabel(const Label(id: 1, title: 'a'), 5), isFalse);
      expect(
        isOwnLabel(const Label(id: 1, title: 'a', createdBy: me), null),
        isFalse,
      );
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

    test('the global search asks the server with the trimmed query and '
        'remembers what it found', () async {
      read.allUsers = [ana, ben];

      expect(await repository.search(' BEN '), [ben]);
      expect(read.requests, ['search users ben']);
      expect(await repository.knownUsers(), [ben]);
    });

    test('a blank global search finds nobody without a request', () async {
      read.allUsers = [ana, ben];

      expect(await repository.search('  '), isEmpty);
      expect(read.requests, isEmpty);
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
