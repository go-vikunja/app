import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/label_op_json.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';
import 'package:vikunja_mobile/core/repositories/label_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_label_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_user_repository.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_timers.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';
import '../../helpers/zero_random.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());

  group('LocalLabelRepository', () {
    final now = DateTime.utc(2026, 10, 11, 12);
    const me = User(id: 5, username: 'me', name: 'Me');
    late FakeWriteClient write;
    late FakeSyncClient read;
    late RecordingSyncEngine sync;
    late OutboxSender outbox;
    late LocalLabelRepository repository;

    setUp(() async {
      write = FakeWriteClient(clock: () => now);
      read = FakeSyncClient();
      sync = RecordingSyncEngine();
      outbox = OutboxSender(
        db: db,
        writeClient: write,
        readClient: read,
        sync: sync,
        now: () => now,
        createTimer: FakeTimers().create,
        random: ZeroRandom(),
      );
      addTearDown(outbox.dispose);
      repository = LocalLabelRepository(
        db,
        write,
        sync: sync,
        now: () => now,
        currentUser: () => me,
      );
      addTearDown(repository.dispose);
      await db.labelsDao.upsertAll([
        sampleLabel(id: 1, title: 'urgent'),
        sampleLabel(id: 2, title: 'Home'),
      ]);
    });

    Future<List<OutboxRow>> ops() => db.outboxDao.all();

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

    group('create', () {
      test('stores the label at once, offline too, under a temporary id, '
          'created by the user, and queues its create', () async {
        write.beforeRequest = (_) =>
            throw const NetworkFailure(NetworkProblem.unreachable);

        final created = await repository.create(
          const NewLabel(title: 'errand', hexColor: '0ead69'),
        );

        expect(created.id, -1);
        expect(created.hexColor, '0ead69');
        expect(created.createdBy, me);
        expect(isOwnLabel(created, me.id), isTrue);
        expect(write.requests, isEmpty);
        final labels = await repository.watchAll().first;
        expect(labels.map((label) => label.title), [
          'errand',
          'Home',
          'urgent',
        ]);
        expect(labels.first, created);
        expect(labels.first.createdBy, me);
        final op = (await ops()).single;
        expect(op.kind, OutboxOperationKind.createLabel.name);
        expect(
          decodeLabelCreate(op.payload),
          const QueuedLabelCreate(
            label: NewLabel(title: 'errand', hexColor: '0ead69'),
          ),
        );
        expect(await repository.watchPendingIds().first, {-1});
      });

      test('sends it through the outbox, and the label follows the server '
          'id', () async {
        repository = LocalLabelRepository(
          db,
          write,
          outbox: outbox,
          now: () => now,
          currentUser: () => me,
        );
        final seen = <Label?>[];
        final created = await repository.create(
          const NewLabel(title: 'errand'),
        );
        final subscription = repository.watchLabel(created.id).listen(seen.add);
        addTearDown(subscription.cancel);

        await outbox.drain();
        await pumpEventQueue();

        expect(write.requests, ['create label errand']);
        expect(seen.last!.id, 900);
        expect(seen.last!.title, 'errand');
        expect(await repository.watchRemaps().first, {-1: 900});
        expect(await repository.watchPendingIds().first, isEmpty);
      });

      test('refuses a blank or too long title before any write', () async {
        for (final title in ['', '   ', '\u0000', 'x' * 251]) {
          await expectLater(
            repository.create(NewLabel(title: title)),
            throwsArgumentError,
          );
        }
        expect(await ops(), isEmpty);
        expect(await db.labelsDao.loadAll(), hasLength(2));

        final longest = await repository.create(NewLabel(title: 'ä' * 250));
        expect(longest.title, 'ä' * 250);
      });

      test('stores and sends a title without U+0000, as the server stores '
          'it, with the colour and description', () async {
        final created = await repository.create(
          const NewLabel(
            title: 'err\u0000and',
            hexColor: '0ead69',
            description: '<p>Outside</p>',
          ),
        );

        expect(created.title, 'errand');
        expect(created.description, '<p>Outside</p>');
        expect(
          decodeLabelCreate((await ops()).single.payload).label,
          const NewLabel(
            title: 'errand',
            hexColor: '0ead69',
            description: '<p>Outside</p>',
          ),
        );
      });
    });

    group('findOrCreate', () {
      test('takes the label this device has under that title, ignoring case, '
          'the same case first, without queueing', () async {
        await db.labelsDao.upsertAll([
          sampleLabel(id: 3, title: 'Einkauf'),
          sampleLabel(id: 4, title: 'einkauf'),
          sampleLabel(id: 7, title: 'einkaufen'),
        ]);

        expect(
          (await repository.findOrCreate(const NewLabel(title: 'einkauf'))).id,
          4,
        );
        expect(
          (await repository.findOrCreate(const NewLabel(title: 'EINKAUF'))).id,
          3,
        );
        expect(
          (await repository.findOrCreate(const NewLabel(title: 'Ur\u0000gent')))
              .id,
          1,
        );
        expect(await ops(), isEmpty);
        expect(write.requests, isEmpty);
        expect(read.requests, isEmpty);
      });

      test('creates one this device does not have, offline too, whose create '
          'takes a label the server has under that title', () async {
        final created = await repository.findOrCreate(
          const NewLabel(title: 'errand'),
        );

        expect(created.id, -1);
        expect(decodeLabelCreate((await ops()).single.payload).adopt, isTrue);
        expect(
          (await repository.findOrCreate(const NewLabel(title: 'Errand'))).id,
          -1,
        );
        expect(await ops(), hasLength(1));
      });
    });

    group('a label created here', () {
      setUp(() async {
        await db.projectsDao.upsertAll([const Project(id: 1, title: 'Inbox')]);
        await db.tasksDao.upsertAll([sampleTask(id: 10, title: 'Call')]);
        await repository.create(const NewLabel(title: 'errand'));
        await db.outboxDao.queueUpdate(
          10,
          const TaskChanges(labels: IdSetChange(added: {-1})),
          now: now,
        );
      });

      test('is changed here, the change folded into its create', () async {
        final changed = await repository.update(
          -1,
          const LabelChanges(title: 'errands', description: '<p>Out</p>'),
        );

        expect(changed.title, 'errands');
        expect(changed.description, '<p>Out</p>');
        expect(write.requests, isEmpty);
        final create = (await ops()).first;
        expect(
          decodeLabelCreate(create.payload).label,
          const NewLabel(title: 'errands', description: '<p>Out</p>'),
        );
        expect((await db.tasksDao.find(10))!.labels.single.title, 'errands');
      });

      test('refuses a blank title before any write', () async {
        await expectLater(
          repository.update(-1, const LabelChanges(title: ' ')),
          throwsArgumentError,
        );
        expect((await db.labelsDao.find(-1))!.title, 'errand');
      });

      test('is deleted without a request, from its tasks and the queued '
          'edits', () async {
        await repository.delete(-1);

        expect(write.requests, isEmpty);
        expect(await ops(), isEmpty);
        expect(await db.labelsDao.find(-1), isNull);
        expect((await db.tasksDao.find(10))!.labels, isEmpty);
        expect(sync.refreshAfterWriteCalls, 0);
      });

      test('that is gone is a NotFound for a change and nothing for a '
          'delete', () async {
        await repository.delete(-1);

        await expectLater(
          repository.update(-1, const LabelChanges(title: 'x')),
          throwsA(isA<NotFound>().having((f) => f.code, 'code', 8002)),
        );
        await repository.delete(-1);
        expect(write.requests, isEmpty);
      });

      test('whose create may be on the server takes a change and a delete '
          'behind it, also under the server id once answered', () async {
        final create = (await ops()).first;
        await db.outboxDao.claim(create.id, at: now);

        await repository.update(-1, const LabelChanges(title: 'errands'));
        await db.labelOpsDao.completeCreate(
          create.id,
          const Label(id: 50, title: 'errand'),
          at: now,
        );
        await repository.update(-1, const LabelChanges(hexColor: 'e69f00'));

        expect(write.requests, isEmpty);
        final edit = (await ops()).firstWhere(
          (op) => op.kind == OutboxOperationKind.updateLabel.name,
        );
        expect(edit.labelId, 50);
        expect(
          decodeLabelChanges(edit.payload),
          const LabelChanges(title: 'errands', hexColor: 'e69f00'),
        );

        await repository.delete(50);
        expect(
          (await ops()).where((op) => op.labelId != null).map((op) => op.kind),
          [OutboxOperationKind.deleteLabel.name],
        );
        expect(await db.labelsDao.find(50), isNull);
        expect(write.requests, isEmpty);
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
