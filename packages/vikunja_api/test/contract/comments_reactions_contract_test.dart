@Tags(['contract'])
@Timeout(Duration(minutes: 8))
library;

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

Map<String, Object?> _object(Object? value) => value! as Map<String, Object?>;

// Pacing for the SQLite server, whose listeners write after each answer.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 500));

// Whole seconds: create answers carry nanoseconds, reads seconds.
DateTime _second(DateTime time) => DateTime.fromMillisecondsSinceEpoch(
  time.millisecondsSinceEpoch ~/ 1000 * 1000,
  isUtc: true,
);

String _mention(TestUser user) =>
    '<mention-user data-id="${user.username}" data-label="${user.username}" '
    'data-mention-suggestion-char="@"></mention-user>';

typedef _Client = ({
  TasksPort tasks,
  CommentsPort comments,
  CommentsWritePort commentWrites,
  ReactionsWritePort reactions,
  TasksWritePort taskWrites,
});

void main() {
  group(
    'comments, reactions and unread on local Docker servers',
    skip: contractSkip,
    () {
      for (final (:port, :version) in contractServers) {
        group('$version on :$port', () {
          late Dio dio;
          late ServerConnection connection;
          late TestUser owner;
          // A second author: the unread flag and "only the author" need one.
          late TestUser member;
          late int projectId;
          late int listViewId;
          late int readOnlyTaskId;
          late int archivedTaskId;
          late int archivedCommentId;
          late String runId;

          Future<Object?> send(
            TestUser user,
            String method,
            String path, {
            Object? body,
            String? contentType,
          }) async {
            final v2 = connection.apiBaseUri(ApiVersion.v2);
            try {
              final response = await despiteWriteRaces(
                () => dio.requestUri<Object?>(
                  v2.replace(path: '${v2.path}$path'),
                  data: body,
                  options: Options(
                    method: method,
                    contentType: contentType,
                    headers: {'Authorization': 'Bearer ${user.jwt}'},
                  ),
                ),
              );
              if (method != 'GET') await _settle();
              return response.data;
            } on DioException catch (error) {
              throw StateError(
                '$method $path failed with ${error.response?.statusCode}: '
                '${error.response?.data}',
              );
            }
          }

          Future<int> newTask(int project, String title) async =>
              _object(
                    await send(
                      owner,
                      'POST',
                      '/projects/$project/tasks',
                      body: {'title': '$title $runId'},
                    ),
                  )['id']!
                  as int;

          _Client clientOf(TestUser user, ApiVersion apiVersion) {
            final only = onlyVersion(connection, apiVersion);
            final authenticated = createAuthenticatedDio(
              base: dio,
              connection: only,
              tokens: StaticJwt(user.jwt),
            );
            final reads = createReadClient(
              dio: authenticated,
              connection: only,
            );
            final writes = createWriteClient(
              dio: authenticated,
              connection: only,
            );
            return (
              tasks: reads.tasks,
              comments: reads.comments,
              commentWrites: writes.comments,
              reactions: writes.reactions,
              taskWrites: writes.tasks,
            );
          }

          setUpAll(() async {
            dio = contractDio();
            connection = await DioServerConnector(dio)
                .connect('http://localhost:$port');
            expect(connection.info.taskCommentsEnabled, isTrue);
            owner = await registerAndLogin(dio, connection);
            member = await registerAndLogin(dio, connection);
            runId = Random.secure().nextInt(1 << 20).toRadixString(16);

            final project = _object(
              await send(
                owner,
                'POST',
                '/projects',
                body: {'title': 'Comments contract $runId'},
              ),
            );
            projectId = project['id']! as int;
            listViewId =
                (project['views']! as List<Object?>)
                        .map(_object)
                        .firstWhere(
                          (view) => view['view_kind'] == 'list',
                        )['id']!
                    as int;
            await send(
              owner,
              'POST',
              '/projects/$projectId/users',
              body: {'username': member.username, 'permission': 1},
            );

            final readOnly =
                _object(
                      await send(
                        owner,
                        'POST',
                        '/projects',
                        body: {'title': 'Read only $runId'},
                      ),
                    )['id']!
                    as int;
            await send(
              owner,
              'POST',
              '/projects/$readOnly/users',
              body: {'username': member.username, 'permission': 0},
            );
            readOnlyTaskId = await newTask(readOnly, 'Read only');

            final archived =
                _object(
                      await send(
                        owner,
                        'POST',
                        '/projects',
                        body: {'title': 'Archived comments $runId'},
                      ),
                    )['id']!
                    as int;
            archivedTaskId = await newTask(archived, 'Archived');
            archivedCommentId =
                _object(
                      await send(
                        owner,
                        'POST',
                        '/tasks/$archivedTaskId/comments',
                        body: {'comment': '<p>before archiving</p>'},
                      ),
                    )['id']!
                    as int;
            await send(
              owner,
              'PATCH',
              '/projects/$archived',
              body: {'is_archived': true},
              contentType: 'application/merge-patch+json',
            );
          });

          tearDownAll(() => dio.close(force: true));

          for (final apiVersion in ApiVersion.values) {
            group(apiVersion.pathSegment, () {
              late _Client asOwner;
              late _Client asMember;

              setUpAll(() {
                expect(connection.apiVersions, contains(apiVersion));
                asOwner = clientOf(owner, apiVersion);
                asMember = clientOf(member, apiVersion);
              });

              test('the author writes, edits and deletes a comment; each '
                  'bumps the task', () async {
                final taskId = await newTask(projectId, 'Write $apiVersion');
                Future<DateTime> taskUpdated() async =>
                    (await asOwner.tasks.read(taskId)).updated!;
                final html = [
                  '<p>Hi ${_mention(member)} &amp; &lt;you&gt;</p>',
                  '<p></p>',
                  '<p>second</p>',
                ].join();
                var before = await taskUpdated();
                // `updated` keeps whole seconds.
                await Future<void>.delayed(const Duration(milliseconds: 1100));

                final created = await despiteWriteRaces(
                  () => asOwner.commentWrites.create(taskId, html),
                );
                await _settle();

                expect(created.html, html);
                expect(created.author.id, owner.id);
                expect(created.author.username, owner.username);
                expect(created.reactions, isEmpty);
                expect(created.isEdited, isFalse);
                expect((await taskUpdated()).isAfter(before), isTrue);
                final listed = (await asOwner.comments.list(taskId)).items;
                expect(listed.single.id, created.id);
                expect(listed.single.html, html);
                expect(listed.single.created, _second(created.created!));

                before = await taskUpdated();
                await Future<void>.delayed(const Duration(milliseconds: 1100));
                final updated = await despiteWriteRaces(
                  () => asOwner.commentWrites.update(
                    taskId,
                    created.id,
                    '<p>edited</p>',
                  ),
                );
                await _settle();

                expect(updated.id, created.id);
                expect(updated.html, '<p>edited</p>');
                expect(updated.author.id, owner.id);
                expect(updated.created, _second(created.created!));
                expect(updated.updated!.isAfter(created.updated!), isTrue);
                expect((await taskUpdated()).isAfter(before), isTrue);
                expect(
                  (await asOwner.comments.list(taskId)).items.single.html,
                  '<p>edited</p>',
                );

                // The same body again: v2 answers 304 and reads it.
                final unchanged = await despiteWriteRaces(
                  () => asOwner.commentWrites.update(
                    taskId,
                    created.id,
                    '<p>edited</p>',
                  ),
                );
                expect(unchanged.html, '<p>edited</p>');
                expect(unchanged.author.id, owner.id);
                await _settle();

                before = await taskUpdated();
                await Future<void>.delayed(const Duration(milliseconds: 1100));
                await despiteWriteRaces(
                  () => asOwner.commentWrites.delete(taskId, created.id),
                );
                await _settle();

                expect((await asOwner.comments.list(taskId)).items, isEmpty);
                expect((await taskUpdated()).isAfter(before), isTrue);
                // Gone already: a read confirms it.
                await asOwner.commentWrites.delete(taskId, created.id);
                await expectLater(
                  asOwner.commentWrites.update(taskId, created.id, '<p>x</p>'),
                  throwsA(isA<NotFound>().having((f) => f.code, 'code', 4015)),
                );
              });

              test('only the author changes a comment, not even the '
                  "project's owner", () async {
                final taskId = await newTask(projectId, 'Authors $apiVersion');
                final mine = await despiteWriteRaces(
                  () => asOwner.commentWrites.create(taskId, '<p>owner</p>'),
                );
                final theirs = await despiteWriteRaces(
                  () => asMember.commentWrites.create(taskId, '<p>member</p>'),
                );
                await _settle();

                expect(theirs.author.id, member.id);
                await expectLater(
                  asMember.commentWrites.update(taskId, mine.id, '<p>x</p>'),
                  throwsA(isA<Forbidden>()),
                );
                await expectLater(
                  asMember.commentWrites.delete(taskId, mine.id),
                  throwsA(isA<Forbidden>()),
                );
                await expectLater(
                  asOwner.commentWrites.update(taskId, theirs.id, '<p>x</p>'),
                  throwsA(isA<Forbidden>()),
                );
                await expectLater(
                  asOwner.commentWrites.delete(taskId, theirs.id),
                  throwsA(isA<Forbidden>()),
                );
                expect(
                  {
                    for (final comment in (await asOwner.comments.list(
                      taskId,
                    )).items)
                      comment.id: comment.html,
                  },
                  {mine.id: '<p>owner</p>', theirs.id: '<p>member</p>'},
                );
              });

              test('the permission in the details; a read share can neither '
                  'comment nor react', () async {
                final taskId = await newTask(projectId, 'Perm $apiVersion');

                expect(
                  (await asOwner.tasks.readDetails(taskId)).maxPermission,
                  Permission.admin,
                );
                expect(
                  (await asMember.tasks.readDetails(taskId)).maxPermission,
                  Permission.write,
                );
                expect(
                  (await asMember.tasks.readDetails(readOnlyTaskId))
                      .maxPermission,
                  Permission.read,
                );
                await expectLater(
                  asMember.commentWrites.create(readOnlyTaskId, '<p>x</p>'),
                  throwsA(isA<Forbidden>()),
                );
                await expectLater(
                  asMember.reactions.add(
                    ReactionEntity.task,
                    readOnlyTaskId,
                    '👍',
                  ),
                  throwsA(isA<Forbidden>()),
                );
              });

              test('an archived project refuses every comment and reaction '
                  'write', () async {
                Matcher archived() => throwsA(
                  isA<DomainError>().having((f) => f.code, 'code', 3008),
                );

                await expectLater(
                  asOwner.commentWrites.create(archivedTaskId, '<p>x</p>'),
                  archived(),
                );
                await expectLater(
                  asOwner.commentWrites.update(
                    archivedTaskId,
                    archivedCommentId,
                    '<p>x</p>',
                  ),
                  archived(),
                );
                await expectLater(
                  asOwner.commentWrites.delete(
                    archivedTaskId,
                    archivedCommentId,
                  ),
                  archived(),
                );
                await expectLater(
                  asOwner.reactions.add(
                    ReactionEntity.task,
                    archivedTaskId,
                    '👍',
                  ),
                  archived(),
                );
                // Reading still works.
                expect(
                  (await asOwner.comments.list(archivedTaskId)).items.single.id,
                  archivedCommentId,
                );
              });

              test('reactions on a task and a comment: add, add again, '
                  'remove, remove one never added', () async {
                final taskId = await newTask(projectId, 'React $apiVersion');
                final comment = await despiteWriteRaces(
                  () => asOwner.commentWrites.create(taskId, '<p>react</p>'),
                );
                await _settle();
                Future<void> paced(Future<void> Function() write) async {
                  await despiteWriteRaces(write);
                  await _settle();
                }

                final before = (await asOwner.tasks.read(taskId)).updated;
                await paced(
                  () =>
                      asMember.reactions.add(ReactionEntity.task, taskId, '👍'),
                );
                await paced(
                  () =>
                      asOwner.reactions.add(ReactionEntity.task, taskId, '👍'),
                );
                await paced(
                  () =>
                      asOwner.reactions.add(ReactionEntity.task, taskId, '👍'),
                );
                await paced(
                  () =>
                      asOwner.reactions.add(ReactionEntity.task, taskId, '❤️'),
                );
                await paced(
                  () => asMember.reactions.add(
                    ReactionEntity.comment,
                    comment.id,
                    '🎉',
                  ),
                );
                await paced(
                  () => asMember.reactions.add(
                    ReactionEntity.comment,
                    comment.id,
                    '👨‍👩‍👧‍👦',
                  ),
                );

                final details = await asOwner.tasks.readDetails(taskId);
                expect(details.reactions.keys, ['❤️', '👍']);
                expect(
                  [for (final user in details.reactions['👍']!) user.id],
                  [member.id, owner.id],
                );
                expect(
                  [for (final user in details.reactions['❤️']!) user.id],
                  [owner.id],
                );
                var listed = (await asOwner.comments.list(taskId)).items.single;
                expect(listed.reactions.keys, ['🎉', '👨‍👩‍👧‍👦']);
                expect(listed.reactions['🎉']!.single.id, member.id);
                // Reactions bump nothing.
                expect((await asOwner.tasks.read(taskId)).updated, before);
                expect(listed.updated, _second(comment.updated!));

                await paced(
                  () => asOwner.reactions.remove(
                    ReactionEntity.task,
                    taskId,
                    '👍',
                  ),
                );
                await paced(
                  () => asOwner.reactions.remove(
                    ReactionEntity.task,
                    taskId,
                    '🚀',
                  ),
                );
                // Only the user's own reaction goes.
                await paced(
                  () => asOwner.reactions.remove(
                    ReactionEntity.comment,
                    comment.id,
                    '🎉',
                  ),
                );
                await paced(
                  () => asMember.reactions.remove(
                    ReactionEntity.comment,
                    comment.id,
                    '👨‍👩‍👧‍👦',
                  ),
                );

                final after = await asMember.tasks.readDetails(taskId);
                expect(
                  after.reactions.map(
                    (value, users) =>
                        MapEntry(value, [for (final u in users) u.id]),
                  ),
                  {
                    '❤️': [owner.id],
                    '👍': [member.id],
                  },
                );
                listed = (await asMember.comments.list(taskId)).items.single;
                expect(
                  listed.reactions.map(
                    (value, users) =>
                        MapEntry(value, [for (final u in users) u.id]),
                  ),
                  {
                    '🎉': [member.id],
                  },
                );
              });

              test("another user's comment makes the task unread for the "
                  'owner only, in the details and every list; mark-read '
                  'clears it', () async {
                final unreadTask = await newTask(projectId, 'Unread');
                final quietTask = await newTask(projectId, 'Quiet');
                // The owner's own comment would make it unread for the member,
                // and nothing but mark-read clears that.
                await despiteWriteRaces(
                  () => asMember.commentWrites.create(unreadTask, '<p>a</p>'),
                );
                await despiteWriteRaces(
                  () => asMember.commentWrites.create(unreadTask, '<p>b</p>'),
                );
                await _settle();

                const expand = TaskQuery(
                  expand: {TaskExpand.commentCount, TaskExpand.isUnread},
                  perPage: 50,
                );
                Future<Map<int, (int, bool)>> listed(
                  _Client client,
                  Future<Page<Task>> Function(TasksPort tasks) list,
                ) async => {
                  for (final task in (await list(client.tasks)).items)
                    if (task.id == unreadTask || task.id == quietTask)
                      task.id: (task.commentCount, task.isUnread),
                };
                final lists = <String, Future<Page<Task>> Function(TasksPort)>{
                  'all tasks': (tasks) => tasks.list(expand),
                  'project': (tasks) => tasks.listInProject(projectId, expand),
                  'list view': (tasks) =>
                      tasks.listInView(projectId, listViewId, expand),
                };

                // The flag is set by a listener after the answer.
                for (var i = 0; i < 20; i++) {
                  if ((await asOwner.tasks.readDetails(unreadTask)).isUnread) {
                    break;
                  }
                  await _settle();
                }
                expect(
                  (await asOwner.tasks.readDetails(unreadTask)).isUnread,
                  isTrue,
                );
                expect(
                  (await asMember.tasks.readDetails(unreadTask)).isUnread,
                  isFalse,
                );
                for (final MapEntry(key: name, value: list) in lists.entries) {
                  expect(await listed(asOwner, list), {
                    unreadTask: (2, true),
                    quietTask: (0, false),
                  }, reason: name);
                  expect(await listed(asMember, list), {
                    unreadTask: (2, false),
                    quietTask: (0, false),
                  }, reason: name);
                }
                // Without the expands neither is sent.
                final plain = await asOwner.tasks.read(unreadTask);
                expect((plain.commentCount, plain.isUnread), (0, false));

                final before = (await asOwner.tasks.read(unreadTask)).updated;
                await despiteWriteRaces(
                  () => asOwner.taskWrites.markRead(unreadTask),
                );
                await _settle();

                expect(
                  (await asOwner.tasks.readDetails(unreadTask)).isUnread,
                  isFalse,
                );
                for (final MapEntry(key: name, value: list) in lists.entries) {
                  expect(await listed(asOwner, list), {
                    unreadTask: (2, false),
                    quietTask: (0, false),
                  }, reason: name);
                }
                // Marking read is invisible to the incremental sync.
                expect((await asOwner.tasks.read(unreadTask)).updated, before);
              });
            });
          }
        });
      }
    },
  );
}
