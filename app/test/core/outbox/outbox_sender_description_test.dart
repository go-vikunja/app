import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_timers.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';
import '../../helpers/zero_random.dart';

String _item(String text, {required bool checked, String? id}) =>
    '<li data-checked="$checked" data-type="taskItem"'
    '${id == null ? '' : ' data-task-id="$id"'}><label><input type="checkbox"'
    '${checked ? ' checked="checked"' : ''}><span></span></label>'
    '<div><p>$text</p></div></li>';

String _list(List<String> items) =>
    '<ul data-type="taskList">${items.join()}</ul>';

// A queued description change that knows its base is checked against the
// server's right before the write: unchanged, it goes as queued; changed,
// taps are applied again and an edit becomes a sync problem.
void main() {
  late AppDatabase db;
  late FakeWriteClient write;
  late FakeSyncClient read;
  late OutboxSender sender;
  final now = DateTime.utc(2026, 10, 20, 12);
  final original = _list([
    _item('Milk', checked: false, id: 'a'),
    _item('Eggs', checked: false),
  ]);
  final task = sampleTask(id: 1, title: 'Shopping', description: original);

  setUp(() async {
    db = testDatabase();
    write = FakeWriteClient(clock: () => now);
    read = FakeSyncClient()..allTasks = [task];
    sender = OutboxSender(
      db: db,
      writeClient: write,
      readClient: read,
      sync: RecordingSyncEngine(),
      now: () => now,
      createTimer: FakeTimers().create,
      random: ZeroRandom(),
    );
    addTearDown(sender.dispose);
    await db.tasksDao.upsertAll([task], syncRunId: 'run');
    write.serverTasks[1] = task;
  });

  Future<String> localDescription() async =>
      (await db.tasksDao.find(1))!.description;

  /// A tap on the item with [text] as the repository queues it.
  Future<void> tap(String text, {required bool checked}) async {
    final html = await localDescription();
    final document = parseRichText(
      html,
      apiRoot: Uri.parse('https://example.invalid'),
      taskLinkBases: const [],
    );
    final item = document.taskItems.firstWhere(
      (item) => checklistItemText(item) == text,
    );
    final queued = await db.outboxDao.queueUpdate(
      1,
      TaskChanges(
        description: toggleTaskItem(html, item, checked: checked),
        descriptionBase: html,
        checklistToggles: [
          checklistToggleFor(document, item, checked: checked),
        ],
      ),
      now: now,
      ifDescription: html,
    );
    expect(queued, isTrue);
  }

  Future<void> edit(String html) async {
    final base = await localDescription();
    expect(
      await db.outboxDao.queueUpdate(
        1,
        TaskChanges(description: html, descriptionBase: base),
        now: now,
      ),
      isTrue,
    );
  }

  void changeOnTheWeb(String description) {
    final changed = write.serverTasks[1]!.copyWith(description: description);
    write.serverTasks[1] = changed;
    read.allTasks = [changed];
  }

  group('the server still has the base', () {
    test('an edit is sent as queued', () async {
      await edit('<p>Rewritten</p>');

      await sender.drain();

      expect(write.serverTasks[1]!.description, '<p>Rewritten</p>');
      expect(await localDescription(), '<p>Rewritten</p>');
      expect(await db.outboxDao.count(), 0);
      expect(write.updates.single.$2.description, '<p>Rewritten</p>');
    });

    test('taps made offline go as one write, byte for byte', () async {
      await tap('Milk', checked: true);
      await tap('Eggs', checked: true);
      await tap('Milk', checked: false);
      final local = await localDescription();

      await sender.drain();

      expect(
        local,
        _list([
          _item('Milk', checked: false, id: 'a'),
          _item('Eggs', checked: true),
        ]),
      );
      expect(write.serverTasks[1]!.description, local);
      expect(write.updates, hasLength(1));
      expect(await db.outboxDao.count(), 0);
    });

    test('an empty description counts as unchanged however it is '
        'written', () async {
      final empty = task.copyWith(description: '');
      await db.tasksDao.upsertAll([empty], syncRunId: 'run');
      write.serverTasks[1] = empty;
      await edit('<p>First words</p>');
      changeOnTheWeb('<p></p>');

      await sender.drain();

      expect(write.serverTasks[1]!.description, '<p>First words</p>');
      expect(await db.outboxDao.loadProblems(), isEmpty);
    });

    test('a base with a U+0000 is the one the server stored without '
        'it', () async {
      await db.tasksDao.upsertAll([
        task.copyWith(description: '<p>Ol\u0000d</p>'),
      ], syncRunId: 'run');
      write.serverTasks[1] = task.copyWith(description: '<p>Old</p>');
      await edit('<p>New</p>');

      await sender.drain();

      expect(write.serverTasks[1]!.description, '<p>New</p>');
      expect(await db.outboxDao.loadProblems(), isEmpty);
    });

    test('a description change without a base overwrites whatever the '
        'server has', () async {
      expect(
        await db.outboxDao.queueUpdate(
          1,
          const TaskChanges(description: '<p>Unchecked</p>'),
          now: now,
        ),
        isTrue,
      );
      changeOnTheWeb('<p>Web</p>');

      await sender.drain();

      expect(write.serverTasks[1]!.description, '<p>Unchecked</p>');
    });
  });

  group('the description changed on the web meanwhile', () {
    test('taps are applied to the server description: by id, else by '
        'position and text, every other byte of it kept', () async {
      await tap('Milk', checked: true);
      await tap('Eggs', checked: true);
      final web =
          '<h1>Saturday</h1>\r\n${_list([_item('Milk', checked: false, id: 'a'), _item('Eggs', checked: false), _item('Bread', checked: false, id: 'c')])}<p>added on the web</p>';
      changeOnTheWeb(web);

      await sender.drain();

      final expected =
          '<h1>Saturday</h1>\r\n${_list([_item('Milk', checked: true, id: 'a'), _item('Eggs', checked: true), _item('Bread', checked: false, id: 'c')])}<p>added on the web</p>';
      expect(write.serverTasks[1]!.description, expected);
      expect(await localDescription(), expected);
      expect(await db.outboxDao.count(), 0);
      expect(await db.outboxDao.loadProblems(), isEmpty);
    });

    test('a tap whose item is gone or changed is dropped', () async {
      await tap('Milk', checked: true);
      await tap('Eggs', checked: true);
      final web = _list([_item('Eggs (6)', checked: false)]);
      changeOnTheWeb(web);

      await sender.drain();

      expect(write.serverTasks[1]!.description, web);
      expect(await localDescription(), web);
      expect(await db.outboxDao.loadProblems(), isEmpty);
    });

    test('an edit fails as a description conflict: nothing is written, the '
        'local edit stays until the user decides', () async {
      await edit('<p>Mine</p>');
      changeOnTheWeb('<p>Web</p>');

      await sender.drain();

      final problem = (await db.outboxDao.loadProblems()).single;
      expect(problem.failure, isA<DescriptionConflict>());
      expect(problem.changes?.description, '<p>Mine</p>');
      expect(write.serverTasks[1]!.description, '<p>Web</p>');
      expect(write.updates, isEmpty);
      expect(await localDescription(), '<p>Mine</p>');
    });

    test('an edit the server already has (a re-send after a lost answer) '
        'is no conflict', () async {
      await edit('<p>Mine</p>');
      changeOnTheWeb('<p>Mine</p>');

      await sender.drain();

      expect(await db.outboxDao.loadProblems(), isEmpty);
      expect(await db.outboxDao.count(), 0);
      expect(write.serverTasks[1]!.description, '<p>Mine</p>');
      expect(await localDescription(), '<p>Mine</p>');
    });

    test('an edit with a U+0000 the server already has without it is no '
        'conflict', () async {
      await edit('<p>Mi\u0000ne</p>');
      changeOnTheWeb('<p>Mine</p>');

      await sender.drain();

      expect(await db.outboxDao.loadProblems(), isEmpty);
      expect(await db.outboxDao.count(), 0);
      expect(write.updates, hasLength(1));
    });

    test('taps followed by an edit are an edit', () async {
      await tap('Milk', checked: true);
      await edit('<p>Mine</p>');
      changeOnTheWeb('<p>Web</p>');

      await sender.drain();

      expect(
        (await db.outboxDao.loadProblems()).single.failure,
        isA<DescriptionConflict>(),
      );
    });

    test('Keep mine sends the edit over the web change', () async {
      await edit('<p>Mine</p>');
      changeOnTheWeb('<p>Web</p>');
      await sender.drain();
      final problem = (await db.outboxDao.loadProblems()).single;

      expect(await sender.webDescription(problem.operationId), '<p>Web</p>');
      await sender.keepMyDescription(
        problem.operationId,
        webDescription: '<p>Web</p>',
      );

      expect(write.serverTasks[1]!.description, '<p>Mine</p>');
      expect(await localDescription(), '<p>Mine</p>');
      expect(await db.outboxDao.count(), 0);
    });

    test('Keep mine overwrites only the web change the user saw: a later one, '
        'with a tap merged meanwhile, is a conflict again', () async {
      await edit('<p>Mine</p>');
      changeOnTheWeb('<p>Web</p>');
      await sender.drain();
      final problem = (await db.outboxDao.loadProblems()).single;
      sender.pause();
      await sender.keepMyDescription(
        problem.operationId,
        webDescription: '<p>Web</p>',
      );
      changeOnTheWeb('<p>Web, again</p>');
      await edit('<p>Mine, again</p>');

      await sender.resume();
      await sender.drain();

      expect(write.serverTasks[1]!.description, '<p>Web, again</p>');
      expect(
        (await db.outboxDao.loadProblems()).single.failure,
        isA<DescriptionConflict>(),
      );
    });

    test('the description on the web is read for the conflict, null when '
        'the task is gone there', () async {
      await edit('<p>Mine</p>');
      changeOnTheWeb('<p>Web</p>');
      await sender.drain();
      final problem = (await db.outboxDao.loadProblems()).single;

      expect(await sender.webDescription(problem.operationId), '<p>Web</p>');
      read.allTasks = [];
      expect(await sender.webDescription(problem.operationId), isNull);
      expect(await sender.webDescription('gone'), isNull);
    });

    test("Use the web's drops the edit and stores the server "
        'description', () async {
      await edit('<p>Mine</p>');
      changeOnTheWeb('<p>Web</p>');
      await sender.drain();
      final problem = (await db.outboxDao.loadProblems()).single;

      await sender.useWebDescription(problem.operationId);

      expect(await localDescription(), '<p>Web</p>');
      expect((await db.tasksDao.findRow(1))!.pendingChanges, isNull);
      expect(await db.outboxDao.count(), 0);
      expect(write.updates, isEmpty);
    });

    test("Use the web's still sends what else the change holds", () async {
      await edit('<p>Mine</p>');
      expect(
        await db.outboxDao.queueUpdate(
          1,
          const TaskChanges(isFavorite: true),
          now: now,
        ),
        isTrue,
      );
      changeOnTheWeb('<p>Web</p>');
      await sender.drain();
      final problem = (await db.outboxDao.loadProblems()).single;

      await sender.useWebDescription(problem.operationId);

      expect(write.serverTasks[1]!.isFavorite, isTrue);
      expect(write.serverTasks[1]!.description, '<p>Web</p>');
      final stored = (await db.tasksDao.find(1))!;
      expect(stored.description, '<p>Web</p>');
      expect(stored.isFavorite, isTrue);
      expect(await db.outboxDao.count(), 0);
      expect(write.updates.single.$2, const TaskChanges(isFavorite: true));
    });

    test("Use the web's fails with the read and changes nothing", () async {
      await edit('<p>Mine</p>');
      changeOnTheWeb('<p>Web</p>');
      await sender.drain();
      final problem = (await db.outboxDao.loadProblems()).single;
      read.beforeRequest = (_) async =>
          throw const NetworkFailure(NetworkProblem.unreachable);

      await expectLater(
        sender.useWebDescription(problem.operationId),
        throwsA(isA<NetworkFailure>()),
      );
      expect(await localDescription(), '<p>Mine</p>');
      expect(await db.outboxDao.loadProblems(), hasLength(1));
    });

    test('the stored op keeps the base and the taps, never sent', () async {
      await tap('Milk', checked: true);

      final payload = decodeTaskChanges(
        (await db.outboxDao.all()).single.payload,
      );

      expect(payload.descriptionBase, original);
      expect(payload.checklistToggles, [
        const ChecklistToggle.byId('a', checked: true),
      ]);
    });
  });
}
