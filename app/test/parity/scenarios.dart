import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';

import 'backends.dart';
import 'flaky_write_client.dart';
import 'world.dart';

/// The app's offline writes, lost answers, comments and uploads, which
/// every backend must serve alike. Each case seeds what it needs, in a
/// project of its own, through [ParityBackend.server], and never asks which
/// backend it runs on. The cases avoid what the fakes keep different from
/// the server on purpose:
/// - a task's identifier and index: `-<id>` on the fakes, `#<index>` or
///   `PREFIX-<index>` on the server;
/// - `updated` in microseconds on the fakes, seconds on the server, so dates
///   are UTC and compared to the second;
/// - a gone task's code, 4002 on the fakes and 4040 from 2.8.0's trash, so
///   failures are told apart by their kind (`taskGone`), never by a code;
/// - a task of a deleted project, which the fakes remove and 2.8.0 keeps in
///   the trashed project;
/// - projects the fakes create without a permission or owner, which show as
///   the user's own with admin permission.
void parityScenarios(ParityBackend Function() backend) {
  test('S1: a task created offline and edited before the send goes as one '
      "create; the row moves to the server id and equals the server's "
      'task', () async {
    final b = backend();
    final projectId = await b.seedProject('Created offline');
    final world = await ParityWorld.open(b);
    final due = _day(3);

    world.sender.pause();
    world.writes.offline = true;
    final localId = await world.tasks.createTask(
      NewTask(projectId: projectId, title: 'Draft', dueDate: due),
    );
    await world.tasks.updateTask(
      localId,
      TaskChanges(
        title: 'Created offline',
        description: '<p>While offline</p>',
        priority: TaskPriority.urgent.value,
      ),
    );
    await world.sender.resume();

    expect(world.writes.attempts, [WriteCall.createTask]);
    expect(localId, isNegative);
    expect((await world.db.tasksDao.find(localId))!.title, 'Created offline');
    expect(world.writes.sent, isEmpty);

    world.writes.offline = false;
    await world.sendNowFully();

    expect(world.writes.sent, [WriteCall.createTask]);
    final serverId = await world.db.tasksDao.resolveId(localId);
    expect(serverId, isPositive);
    expect(await world.db.tasksDao.findRow(localId), isNull);
    final local = (await world.db.tasksDao.find(serverId))!;
    final onServer = await b.read.tasks.read(serverId);
    for (final task in [local, onServer]) {
      expect(task.projectId, projectId);
      expect(task.title, 'Created offline');
      expect(task.description, '<p>While offline</p>');
      expect(task.priority, TaskPriority.urgent);
      expect(task.dueDate, _sameSecondAs(due));
      expect(task.done, isFalse);
    }
    expect(local.identifier, onServer.identifier);
    expect(local.index, onServer.index);
    expect(onServer.createdBy?.id, b.me.id);
    expect(_titles(await b.serverTasksIn(projectId)), ['Created offline']);
    expect(await world.db.outboxDao.count(), 0);
  });

  test('S2: done on a daily task with a reminder moves its date and reminder '
      'a day on, here and on the server; the undo brings both back', () async {
    final b = backend();
    final projectId = await b.seedProject('Daily');
    final due = _day(3);
    final reminderAt = _day(2, hour: 7, minute: 30);
    final dailyId = await b.seedTask(
      NewTask(
        projectId: projectId,
        title: 'Daily with a reminder',
        dueDate: due,
        repeatAfter: const Duration(days: 1),
        reminders: [TaskReminder(reminder: reminderAt)],
      ),
    );
    final world = await ParityWorld.open(b);
    final previous = (await world.db.tasksDao.find(dailyId))!;
    expect(previous.repeats, isTrue);

    await world.tasks.setDone(dailyId, done: true);
    await world.drainFully();

    for (final task in [
      await b.read.tasks.read(dailyId),
      (await world.db.tasksDao.find(dailyId))!,
    ]) {
      expect(task.done, isFalse);
      expect(task.doneAt, isNotNull);
      expect(task.dueDate, _sameSecondAs(due.add(_oneDay)));
      expect(
        task.reminders.single.reminder,
        _sameSecondAs(reminderAt.add(_oneDay)),
      );
    }

    await world.tasks.undoDone(previous);
    await world.drainFully();

    for (final task in [
      await b.read.tasks.read(dailyId),
      (await world.db.tasksDao.find(dailyId))!,
    ]) {
      expect(task.done, isFalse);
      expect(task.dueDate, _sameSecondAs(due));
      expect(task.reminders.single.reminder, _sameSecondAs(reminderAt));
    }
    expect(world.writes.sentCount(WriteCall.updateTask), 2);
    expect(await world.db.outboxDao.count(), 0);
  });

  test('S3a: a create whose answer was lost is neither adopted by title nor '
      'sent again', () async {
    final b = backend();
    final projectId = await b.seedProject('Lost create');
    final world = await ParityWorld.open(b);
    world.writes.loseNext[WriteCall.createTask] = 1;

    final localId = await world.tasks.createTask(
      NewTask(projectId: projectId, title: 'Lost answer'),
    );
    await world.sender.drain();

    expect(world.writes.loseNext[WriteCall.createTask], 0);
    expect(await world.db.tasksDao.resolveId(localId), localId);
    expect((await world.db.outboxDao.all()).single.sentAt, isNotNull);

    final problem = (await world.db.outboxDao.loadProblems()).single;
    expect(isUnconfirmedWrite(problem.failure), isTrue);
    await world.sender.retry(problem.operationId);

    expect(world.writes.sentCount(WriteCall.createTask), 1);
    final onServer = await b.serverTasksIn(projectId);
    expect(_titles(onServer), ['Lost answer']);
    expect(await world.db.tasksDao.resolveId(localId), localId);
    expect((await world.db.tasksDao.find(localId))!.title, 'Lost answer');
  });

  test("S3b: a repeating task's done whose answer was lost is not applied "
      'twice: its date moves once', () async {
    final b = backend();
    final projectId = await b.seedProject('Lost done');
    final due = _day(2);
    final dailyId = await b.seedTask(
      NewTask(
        projectId: projectId,
        title: 'Daily, answer lost',
        dueDate: due,
        repeatAfter: const Duration(days: 1),
      ),
    );
    final world = await ParityWorld.open(b);
    final before = await b.read.tasks.read(dailyId);
    world.writes.loseNext[WriteCall.updateTask] = 1;

    await world.tasks.setDone(dailyId, done: true);
    await world.sender.drain();
    expect(world.writes.loseNext[WriteCall.updateTask], 0);
    await world.sendNowFully();

    expect(world.writes.sentCount(WriteCall.updateTask), 1);
    final onServer = await b.read.tasks.read(dailyId);
    expect(onServer.done, isFalse);
    expect(onServer.doneAt, isNotNull);
    expect(onServer.doneAt, isNot(before.doneAt));
    for (final task in [onServer, (await world.db.tasksDao.find(dailyId))!]) {
      expect(task.done, isFalse);
      expect(task.dueDate, _sameSecondAs(due.add(_oneDay)));
    }
    expect(await world.db.outboxDao.count(), 0);
  });

  test('S4: a delete that meets a task deleted elsewhere, or one whose '
      'project was deleted elsewhere, completes without a sync '
      'problem', () async {
    final b = backend();
    final projectId = await b.seedProject('Deletes');
    final doomedProjectId = await b.seedProject('Deleted elsewhere');
    final inDoomedProject = await b.seedTask(
      NewTask(projectId: doomedProjectId, title: 'Its project goes'),
    );
    final deletedElsewhere = await b.seedTask(
      NewTask(projectId: projectId, title: 'Goes elsewhere first'),
    );
    final world = await ParityWorld.open(b);

    world.sender.pause();
    await world.tasks.deleteTask(deletedElsewhere);
    await world.tasks.deleteTask(inDoomedProject);
    expect(await world.db.outboxDao.count(), 2);
    await b.server.tasks.delete(deletedElsewhere);
    await b.server.projects.delete(doomedProjectId);
    await b.settle();
    await world.sender.resume();
    await world.drainFully();

    expect(await world.db.outboxDao.loadProblems(), isEmpty);
    expect(await world.db.outboxDao.count(), 0);
    expect(await world.db.tasksDao.findRow(deletedElsewhere), isNull);
    expect(await world.db.tasksDao.findRow(inDoomedProject), isNull);
    expect(world.sender.state, OutboxSenderState.idle);
    await expectLater(b.read.tasks.read(deletedElsewhere), throwsA(_taskGone));
    await expectLater(
      b.read.tasks.read(inDoomedProject),
      throwsA(_taskOrProjectGone),
    );
  });

  test('S5: a label created offline and added to a task offline is created '
      'once online, by the user, and lands on the task under its server '
      'id', () async {
    final b = backend();
    final projectId = await b.seedProject('Labels offline');
    final taskId = await b.seedTask(
      NewTask(projectId: projectId, title: 'Labelled offline'),
    );
    final world = await ParityWorld.open(b);
    const title = 'Errand';

    world.writes.offline = true;
    final local = await world.labels.create(const NewLabel(title: title));
    await world.tasks.updateTask(
      taskId,
      TaskChanges(labels: IdSetChange(added: {local.id})),
    );
    await world.sender.drain();

    expect(local.id, isNegative);
    expect(_labelIds(await world.db.tasksDao.find(taskId)), [local.id]);
    expect(await b.serverLabelsTitled(title), isEmpty);

    world.writes.offline = false;
    await world.sendNowFully();

    expect(world.writes.sentCount(WriteCall.createLabel), 1);
    final serverId = await world.db.labelsDao.resolveId(local.id);
    expect(serverId, isPositive);
    expect(await b.serverLabelsTitled(title), [serverId]);
    final onServer = await b.read.tasks.read(taskId);
    expect(_labelIds(onServer), [serverId]);
    expect(onServer.labels.single.createdBy?.id, b.me.id);
    expect(_labelIds(await world.db.tasksDao.find(taskId)), [serverId]);
    expect(await world.db.outboxDao.count(), 0);
  });

  test('S6: a label create whose answer was lost is adopted on the next '
      'attempt, not made twice', () async {
    final b = backend();
    final world = await ParityWorld.open(b);
    const title = 'Groceries';
    world.writes.loseNext[WriteCall.createLabel] = 1;

    final local = await world.labels.create(const NewLabel(title: title));
    await world.sender.drain();

    expect(world.writes.loseNext[WriteCall.createLabel], 0);
    expect(await world.db.labelsDao.resolveId(local.id), local.id);
    expect((await world.db.outboxDao.all()).single.sentAt, isNotNull);

    await world.sendNowFully();

    expect(world.writes.sentCount(WriteCall.createLabel), 1);
    final onServer = await b.serverLabelsTitled(title);
    expect(onServer, hasLength(1));
    expect(await world.db.labelsDao.resolveId(local.id), onServer.single);
    expect(await world.db.outboxDao.count(), 0);
  });

  test('S7: a comment is written by the user as sent, edited, reacted to and '
      'deleted twice; an edit after that is NotFound, and the row counts '
      'the comment', () async {
    final b = backend();
    final projectId = await b.seedProject('Comments');
    final taskId = await b.seedTask(
      NewTask(projectId: projectId, title: 'Talked about'),
    );
    final world = await ParityWorld.open(b);

    final written = await world.details.addComment(
      taskId,
      const CommentDraft('<p>First</p>'),
    );
    expect(written.author.id, b.me.id);
    expect(written.html, '<p>First</p>');
    expect((await world.db.tasksDao.find(taskId))!.commentCount, 1);
    await b.settle();

    final edited = await world.details.editComment(
      taskId,
      written,
      const CommentDraft('<p>Edited</p>'),
    );
    expect(edited.html, '<p>Edited</p>');
    expect(edited.author.id, b.me.id);
    await b.settle();

    await world.details.addReaction(ReactionEntity.comment, written.id, '🎉');
    await b.settle();
    final reacted = (await world.details.comments(taskId)).items.single;
    expect(reacted.html, '<p>Edited</p>');
    expect(reacted.reactions.keys, ['🎉']);
    expect(reacted.reactions['🎉']!.single.id, b.me.id);
    await world.details.removeReaction(
      ReactionEntity.comment,
      written.id,
      '🎉',
    );
    await b.settle();
    expect(
      (await world.details.comments(taskId)).items.single.reactions,
      isEmpty,
    );

    await world.refreshAfterServerWrite();
    expect((await world.db.tasksDao.find(taskId))!.commentCount, 1);

    await world.details.deleteComment(taskId, written.id);
    await b.settle();
    await world.details.deleteComment(taskId, written.id);
    await b.settle();
    await expectLater(
      world.details.editComment(
        taskId,
        edited,
        const CommentDraft('<p>Back</p>'),
      ),
      throwsA(isA<NotFound>()),
    );
    expect((await world.details.comments(taskId)).items, isEmpty);
    expect((await world.db.tasksDao.find(taskId))!.commentCount, 0);
    await world.refreshAfterServerWrite();
    expect((await world.db.tasksDao.find(taskId))!.commentCount, 0);
  });

  test('S8: files queued offline, for a synced task and for one created '
      'offline, arrive with their name, size and bytes; an upload whose '
      'answer was lost is verified, not uploaded twice', () async {
    final b = backend();
    final projectId = await b.seedProject('Uploads');
    final existingId = await b.seedTask(
      NewTask(projectId: projectId, title: 'Existing'),
    );
    final world = await ParityWorld.open(b);
    final photo = [for (var i = 0; i < 70000; i++) (i * 31 + 7) % 256];
    const note = [0x48, 0x69, 0x0a];
    final uploaded = <TaskAttachment>[];
    final subscription = world.tasks.uploadedAttachments.listen(uploaded.add);
    addTearDown(subscription.cancel);

    world.writes.offline = true;
    await world.tasks.queueUpload(
      existingId,
      sourcePath: world.file('photo', photo).path,
      fileName: 'photo.bin',
    );
    final localId = await world.tasks.createTask(
      NewTask(projectId: projectId, title: 'Created offline'),
    );
    await world.tasks.queueUpload(
      localId,
      sourcePath: world.file('note', note).path,
      fileName: 'note.txt',
      mimeType: 'text/plain',
    );
    await world.sender.drain();
    expect(await world.db.outboxDao.count(), 3);
    expect(world.writes.sent, isEmpty);

    world.writes
      ..offline = false
      ..loseNext[WriteCall.upload] = 1;
    await world.sendNowFully();

    expect(world.writes.loseNext[WriteCall.upload], 0);
    expect(world.writes.sentCount(WriteCall.upload), 2);
    final createdId = await world.db.tasksDao.resolveId(localId);
    expect(createdId, isPositive);
    await world.until(() async => uploaded.length == 2);
    for (final (taskId, bytes, name) in [
      (existingId, photo, 'photo.bin'),
      (createdId, note, 'note.txt'),
    ]) {
      final onServer = (await b.read.tasks.readDetails(taskId))
          .attachments
          .single;
      expect(onServer.name, name);
      expect(onServer.size, bytes.length);
      expect(onServer.createdBy?.id, b.me.id);
      expect(uploaded.where((attachment) => attachment.taskId == taskId), [
        onServer,
      ]);
      final blob = await b.read.attachments.fetch(taskId, onServer.id);
      expect(blob.bytes, bytes);
    }
  });
}

const _oneDay = Duration(days: 1);

/// [days] after today, UTC, in whole seconds.
DateTime _day(int days, {int hour = 9, int minute = 0}) {
  final today = DateTime.now().toUtc();
  return DateTime.utc(today.year, today.month, today.day + days, hour, minute);
}

Matcher _sameSecondAs(DateTime expected) => predicate<DateTime?>(
  (actual) =>
      actual != null &&
      actual.difference(expected).abs() < const Duration(seconds: 1),
  'within a second of $expected',
);

final Matcher _taskGone = isA<NotFound>().having(
  (failure) => failure.taskGone,
  'taskGone',
  isTrue,
);

final Matcher _taskOrProjectGone = isA<NotFound>().having(
  (failure) => failure.taskGone || failure.projectGone,
  'taskGone or projectGone',
  isTrue,
);

List<String> _titles(List<Task> tasks) => [
  for (final task in tasks) task.title,
];

List<int> _labelIds(Task? task) => [
  for (final label in task?.labels ?? const <Label>[]) label.id,
];
