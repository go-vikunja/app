import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_timers.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';
import '../../helpers/zero_random.dart';

const _offline = NetworkFailure(NetworkProblem.unreachable);

String _item(String text, {required bool checked, String? id}) =>
    '<li data-checked="$checked" data-type="taskItem"'
    '${id == null ? '' : ' data-task-id="$id"'}><label><input type="checkbox"'
    '${checked ? ' checked="checked"' : ''}><span></span></label>'
    '<div><p>$text</p></div></li>';

String _list(List<String> items) =>
    '<ul data-type="taskList">${items.join()}</ul>';

List<RichTaskItem> _items(String html) => parseRichText(
  html,
  apiRoot: Uri.parse('https://vikunja.example'),
  taskLinkBases: [Uri.parse('https://vikunja.example/')],
).taskItems;

void main() {
  late AppDatabase db;
  late FakeWriteClient write;
  late FakeSyncClient read;
  late OutboxSender sender;
  late LocalTaskRepository repository;
  final now = DateTime.utc(2026, 10, 20, 12);
  final checklist = _list([
    _item('Milk', checked: false, id: 'a'),
    _item('Milk', checked: false),
  ]);
  final task = sampleTask(id: 1, title: 'Shopping', description: checklist);

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
    repository = LocalTaskRepository(
      db,
      RecordingSyncEngine(),
      sender,
      write,
      read: read,
      now: () => now,
    );
    addTearDown(repository.dispose);
    await db.tasksDao.upsertAll([task], syncRunId: 'run');
    write.serverTasks[1] = task;
  });

  Future<String> localDescription([int id = 1]) async =>
      (await db.tasksDao.find(id))!.description;

  Future<TaskChanges> queued() async =>
      decodeTaskChanges((await db.outboxDao.all()).single.payload);

  group('updateDescription', () {
    test('shows at once and is sent with its base, which is never '
        'sent', () async {
      await repository.updateDescription(1, '<p>New</p>', base: checklist);

      expect(await localDescription(), '<p>New</p>');
      await pumpEventQueue();
      expect(write.serverTasks[1]!.description, '<p>New</p>');
      expect(
        write.updates.single.$2,
        TaskChanges(description: '<p>New</p>', descriptionBase: checklist),
      );
    });

    test('the description it started from is no change, nor an empty one '
        'written the other way', () async {
      await repository.updateDescription(1, checklist, base: checklist);
      await repository.updateDescription(1, '<p></p>', base: '');

      expect(await db.outboxDao.count(), 0);
    });

    test('a change on the web meanwhile is a sync problem; Keep mine and '
        "Use the web's resolve it", () async {
      write.beforeRequest = (_) => throw _offline;
      await repository.updateDescription(1, '<p>Mine</p>', base: checklist);
      await pumpEventQueue();
      final web = task.copyWith(description: '<p>Web</p>');
      write.serverTasks[1] = web;
      read.allTasks = [web];
      write.beforeRequest = null;

      await repository.sendPendingChanges();
      final problem = (await db.outboxDao.loadProblems()).single;
      expect(problem.failure, isA<DescriptionConflict>());

      await repository.useWebDescription(problem.operationId);
      expect(await localDescription(), '<p>Web</p>');
      expect(await db.outboxDao.count(), 0);

      write.beforeRequest = (_) => throw _offline;
      await repository.updateDescription(1, '<p>Mine</p>', base: checklist);
      await pumpEventQueue();
      write.beforeRequest = null;
      await repository.sendPendingChanges();
      final again = (await db.outboxDao.loadProblems()).single;

      expect(await repository.webDescription(again.operationId), '<p>Web</p>');
      await repository.keepMyDescription(
        again.operationId,
        webDescription: '<p>Web</p>',
      );
      expect(write.serverTasks[1]!.description, '<p>Mine</p>');
      expect(await db.outboxDao.count(), 0);
    });

    test('a task not on this device queues nothing and says so', () async {
      expect(
        await repository.updateDescription(99, '<p>New</p>', base: ''),
        isFalse,
      );
      expect(
        await repository.updateDescription(1, '<p>New</p>', base: checklist),
        isTrue,
      );
    });
  });

  group('toggleChecklistItem', () {
    test('changes only that checkbox, at once, and sends it', () async {
      final second = _items(checklist)[1];

      expect(
        await repository.toggleChecklistItem(
          1,
          html: checklist,
          item: second,
          checked: true,
        ),
        isTrue,
      );

      final toggled = _list([
        _item('Milk', checked: false, id: 'a'),
        _item('Milk', checked: true),
      ]);
      expect(await localDescription(), toggled);
      await pumpEventQueue();
      expect(write.serverTasks[1]!.description, toggled);
    });

    test('records the tap by data-task-id, else by position and '
        'text', () async {
      write.beforeRequest = (_) => throw _offline;
      final items = _items(checklist);

      await repository.toggleChecklistItem(
        1,
        html: checklist,
        item: items[0],
        checked: true,
      );
      final afterFirst = await localDescription();
      await repository.toggleChecklistItem(
        1,
        html: afterFirst,
        item: _items(afterFirst)[1],
        checked: true,
      );

      final changes = await queued();
      expect(changes.descriptionBase, checklist);
      expect(changes.description, await localDescription());
      expect(changes.checklistToggles, [
        const ChecklistToggle.byId('a', checked: true),
        const ChecklistToggle.byPosition(
          ordinal: 1,
          text: 'Milk',
          checked: true,
        ),
      ]);
    });

    test('a tap on a stale view is refused and changes nothing', () async {
      write.beforeRequest = (_) => throw _offline;
      final items = _items(checklist);
      await repository.toggleChecklistItem(
        1,
        html: checklist,
        item: items[0],
        checked: true,
      );
      final afterFirst = await localDescription();

      expect(
        await repository.toggleChecklistItem(
          1,
          html: checklist,
          item: items[1],
          checked: true,
        ),
        isFalse,
      );
      expect(await localDescription(), afterFirst);
      expect((await queued()).checklistToggles, hasLength(1));
    });

    test('an item without a source offset, or one that does not match the '
        'HTML, is refused', () async {
      final unknown = _items(checklist)[0];
      const loose = RichTaskItem(checked: false, blocks: []);

      expect(
        await repository.toggleChecklistItem(
          1,
          html: checklist,
          item: loose,
          checked: true,
        ),
        isFalse,
      );
      expect(
        await repository.toggleChecklistItem(
          1,
          html: '<p>other</p>$checklist',
          item: unknown,
          checked: true,
        ),
        isFalse,
      );
      expect(await db.outboxDao.count(), 0);
    });

    test('a task whose create is still unsent takes the tap into the '
        'create', () async {
      sender.pause();
      final id = await repository.createTask(
        NewTask(projectId: 1, title: 'New', description: checklist),
      );

      expect(
        await repository.toggleChecklistItem(
          id,
          html: checklist,
          item: _items(checklist)[0],
          checked: true,
        ),
        isTrue,
      );
      expect((await db.outboxDao.all()).single.kind, 'createTask');
      await sender.resume();

      final created = write.serverTasks.values.singleWhere(
        (task) => task.title == 'New',
      );
      expect(created.description, contains('data-checked="true"'));
      expect(write.updates, isEmpty);
    });
  });
}
