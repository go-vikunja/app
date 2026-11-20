import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'backends.dart';

/// One rule the fakes claim to follow "like the server", called on the
/// write port with no app in between: `act` seeds what it needs through
/// [ParityBackend.server] and makes the call, whose outcome must match
/// what `expected` makes for the backend.
typedef _Rule = ({
  String name,
  Future<Object?> Function(ParityBackend b) act,
  Matcher Function(ParityBackend b) expected,
});

/// An id that no backend here has given out.
const _missingId = 987654321;

final _projects = Expando<Future<int>>();

/// One project per backend for every rule.
Future<int> _projectOf(ParityBackend b) =>
    _projects[b] ??= b.seedProject('Rules');

Future<int> _task(ParityBackend b, String title) async =>
    await b.seedTask(NewTask(projectId: await _projectOf(b), title: title));

Future<int> _goneTask(ParityBackend b, String title) async {
  final id = await _task(b, title);
  await b.server.tasks.delete(id);
  await b.settle();
  return id;
}

Matcher _notFound(int code) =>
    throwsA(isA<NotFound>().having((failure) => failure.code, 'code', code));

Matcher _domainError(int code) =>
    throwsA(isA<DomainError>().having((failure) => failure.code, 'code', code));

final Matcher _taskGone = throwsA(
  isA<NotFound>().having((failure) => failure.taskGone, 'taskGone', isTrue),
);

Matcher _byMe(ParityBackend b) => completion(
  predicate<int?>((id) => id == b.me.id, 'the id of ${b.me.username}'),
);

final List<_Rule> _rules = [
  (
    name: "a task create answers with the user as the task's creator",
    act: (b) async => (await b.server.tasks.create(
      NewTask(projectId: await _projectOf(b), title: 'Mine'),
    )).createdBy?.id,
    expected: _byMe,
  ),
  (
    name: "a label create answers with the user as the label's creator",
    act: (b) async =>
        (await b.server.labels.create(const NewLabel(title: 'Created by me')))
            .createdBy
            ?.id,
    expected: _byMe,
  ),
  (
    name: 'an upload answers with the user as the uploader',
    act: (b) async => (await b.server.attachments.upload(
      await _task(b, 'With a file'),
      fileName: 'one.txt',
      bytes: Stream.value(const [0x31]),
      length: 1,
    )).createdBy?.id,
    expected: _byMe,
  ),
  (
    name: 'a comment answers with the user as its author',
    act: (b) async => (await b.server.comments.create(
      await _task(b, 'Commented'),
      '<p>Mine</p>',
    )).author.id,
    expected: _byMe,
  ),
  (
    name:
        'an update that adds a label the server does not have is a '
        'NotFound 8002',
    act: (b) async => await b.server.tasks.update(
      await _task(b, 'Unknown label'),
      const TaskChanges(labels: IdSetChange(added: {_missingId})),
    ),
    expected: (_) => _notFound(8002),
  ),
  (
    name:
        'an update that assigns a user the server does not have is a '
        'NotFound 1005',
    act: (b) async => await b.server.tasks.update(
      await _task(b, 'Unknown assignee'),
      const TaskChanges(assignees: IdSetChange(added: {_missingId})),
    ),
    expected: (_) => _notFound(1005),
  ),
  (
    name:
        "an update naming a cover that is not one of the task's "
        'attachments is a DomainError 4020',
    act: (b) async => await b.server.tasks.update(
      await _task(b, 'Foreign cover'),
      const TaskChanges(coverImageAttachmentId: _missingId),
    ),
    expected: (_) => _domainError(4020),
  ),
  (
    name: 'a delete of a task that is gone passes',
    act: (b) async =>
        await b.server.tasks.delete(await _goneTask(b, 'Gone twice')),
    expected: (_) => completes,
  ),
  (
    name: 'an update of a task that is gone is a NotFound with taskGone',
    act: (b) async => await b.server.tasks.update(
      await _goneTask(b, 'Gone, then changed'),
      const TaskChanges(title: 'Changed'),
    ),
    expected: (_) => _taskGone,
  ),
  (
    name: 'a comment on a task that is gone is a NotFound with taskGone',
    act: (b) async => await b.server.comments.create(
      await _goneTask(b, 'Gone, then commented'),
      '<p>Too late</p>',
    ),
    expected: (_) => _taskGone,
  ),
  (
    name: 'an upload to a task that is gone is a NotFound with taskGone',
    act: (b) async => await b.server.attachments.upload(
      await _goneTask(b, 'Gone, then a file'),
      fileName: 'late.txt',
      bytes: Stream.value(const [0x32]),
      length: 1,
    ),
    expected: (_) => _taskGone,
  ),
  (
    name: "a comment's edit answers without the comment's reactions",
    act: (b) async {
      final taskId = await _task(b, 'Reacted to');
      final comment = await b.server.comments.create(taskId, '<p>Hi</p>');
      await b.server.reactions.add(ReactionEntity.comment, comment.id, '🎉');
      await b.settle();
      final listed = await b.read.comments.list(taskId);
      expect(listed.items.single.reactions.keys, ['🎉']);
      return (await b.server.comments.update(
        taskId,
        comment.id,
        '<p>Hello</p>',
      )).reactions;
    },
    expected: (_) => completion(isEmpty),
  ),
  (
    name:
        'a second delete of a comment passes; an edit of it is a NotFound '
        '4015',
    act: (b) async {
      final taskId = await _task(b, 'Comment gone');
      final comment = await b.server.comments.create(taskId, '<p>Bye</p>');
      await b.server.comments.delete(taskId, comment.id);
      await b.server.comments.delete(taskId, comment.id);
      await b.settle();
      return await b.server.comments.update(taskId, comment.id, '<p>Back</p>');
    },
    expected: (_) => _notFound(4015),
  ),
  (
    name:
        'a second delete of a label passes; an update of it is a NotFound '
        '8002',
    act: (b) async {
      final label = await b.server.labels.create(
        const NewLabel(title: 'Short-lived'),
      );
      await b.server.labels.delete(label.id);
      await b.server.labels.delete(label.id);
      await b.settle();
      return await b.server.labels.update(
        label.id,
        const LabelChanges(title: 'Back'),
      );
    },
    expected: (_) => _notFound(8002),
  ),
  (
    name: 'a change of an archived project is a DomainError 3008',
    act: (b) async {
      final id = await b.seedProject('Archived, then renamed');
      await b.server.projects.update(
        id,
        const ProjectChanges(isArchived: true),
      );
      return await b.server.projects.update(
        id,
        const ProjectChanges(title: 'Renamed'),
      );
    },
    expected: (_) => _domainError(3008),
  ),
  (
    name: 'a move of an archived project is a DomainError 3008',
    act: (b) async {
      final id = await b.seedProject('Archived, then moved');
      await b.server.projects.update(
        id,
        const ProjectChanges(isArchived: true),
      );
      return await b.server.projects.move(
        id,
        position: 1000,
        parentProjectId: 0,
      );
    },
    expected: (_) => _domainError(3008),
  ),
  (
    name: 'an empty reaction is refused with an ArgumentError',
    act: (b) async => await b.server.reactions.add(
      ReactionEntity.task,
      await _task(b, 'No empty reaction'),
      '',
    ),
    expected: (_) => throwsArgumentError,
  ),
];

/// The fakes' claims about the server's rules, checked on the write ports
/// alone. A rule that holds only on the fakes shows a fake that tells the
/// server's rules wrong.
void parityRules(ParityBackend Function() backend) {
  for (final rule in _rules) {
    test('rule: ${rule.name}', () async {
      final b = backend();
      await expectLater(rule.act(b), rule.expected(b));
    });
  }
}
