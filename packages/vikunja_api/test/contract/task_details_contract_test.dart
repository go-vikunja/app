@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

// A 1x1 PNG that Go's image package decodes, so the server makes previews.
final Uint8List _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);
const _notes = 'Contract notes, plain text.';
const _vector =
    '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"> '
    '<script>alert(1)</script></svg>';

int _pngWidth(Uint8List png) => ByteData.sublistView(png, 16, 20).getUint32(0);

Future<Object?> _send(
  Dio dio,
  ServerConnection connection,
  TestUser user,
  String method,
  String path, {
  Object? Function()? body,
  String? contentType,
}) async {
  final v2 = connection.apiBaseUri(ApiVersion.v2);
  try {
    final response = await despiteWriteRaces(
      () => dio.requestUri<Object?>(
        v2.replace(path: '${v2.path}$path'),
        data: body?.call(),
        options: Options(
          method: method,
          contentType: contentType,
          headers: {'Authorization': 'Bearer ${user.jwt}'},
        ),
      ),
    );
    return response.data;
  } on DioException catch (error) {
    // Error bodies carry no secrets; the failure is far easier to read with
    // the server's message.
    throw StateError(
      '$method $path failed with ${error.response?.statusCode}: '
      '${error.response?.data}',
    );
  }
}

Map<String, Object?> _object(Object? value) => value! as Map<String, Object?>;

// SQLite answers a read right after a write with "database is locked" now
// and then.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 500));

bool _sortedByCreatedThenId(List<TaskComment> comments, {bool down = false}) {
  for (var i = 1; i < comments.length; i++) {
    final a = comments[i - 1];
    final b = comments[i];
    final order = a.created!.compareTo(b.created!) != 0
        ? a.created!.compareTo(b.created!)
        : a.id.compareTo(b.id);
    if (down ? order < 0 : order > 0) return false;
  }
  return true;
}

void main() {
  group(
    'task details, comments, attachments and by-index on local Docker servers',
    skip: contractSkip,
    () {
      for (final (:port, :version) in contractServers) {
        group('$version on :$port', () {
          late Dio dio;
          late ServerConnection connection;
          late TestUser owner;
          late TestUser commenter;
          late String identifier;
          late int projectId;
          late int otherProjectId;
          late Map<String, Object?> task;
          late int pageTaskId;
          late Map<String, int> attachmentIds;

          Future<Object?> send(
            TestUser user,
            String method,
            String path, {
            Object? Function()? body,
            String? contentType,
          }) => _send(
            dio,
            connection,
            user,
            method,
            path,
            body: body,
            contentType: contentType,
          );

          Future<void> comment(TestUser user, int taskId, String text) async {
            await send(
              user,
              'POST',
              '/tasks/$taskId/comments',
              body: () => {'comment': '<p>$text</p>'},
            );
          }

          setUpAll(() async {
            dio = contractDio();
            connection = await DioServerConnector(dio)
                .connect('http://localhost:$port');
            expect(connection.info.taskCommentsEnabled, isTrue);
            // The commenter shares the project, so that a comment of theirs
            // makes the task unread for the owner.
            owner = await registerAndLogin(dio, connection);
            commenter = await registerAndLogin(dio, connection);
            final runId = Random.secure().nextInt(1 << 20).toRadixString(16);
            identifier = 'CT$runId'.toUpperCase();
            projectId =
                _object(
                      await send(
                        owner,
                        'POST',
                        '/projects',
                        body: () => {
                          'title': 'Details contract $runId',
                          'identifier': identifier,
                        },
                      ),
                    )['id']!
                    as int;
            otherProjectId =
                _object(
                      await send(
                        owner,
                        'POST',
                        '/projects',
                        body: () => {'title': 'Details contract move $runId'},
                      ),
                    )['id']!
                    as int;
            await send(
              owner,
              'POST',
              '/projects/$projectId/users',
              body: () => {'username': commenter.username, 'permission': 1},
            );

            task = _object(
              await send(
                owner,
                'POST',
                '/projects/$projectId/tasks',
                body: () => {'title': 'Details $runId'},
              ),
            );
            final taskId = task['id']! as int;
            final uploaded = _object(
              await send(
                owner,
                'POST',
                '/tasks/$taskId/attachments',
                body: () => FormData()
                  ..files.addAll([
                    MapEntry(
                      'files',
                      MultipartFile.fromBytes(_pixel, filename: 'pixel.png'),
                    ),
                    MapEntry(
                      'files',
                      MultipartFile.fromString(_notes, filename: 'notes.txt'),
                    ),
                    MapEntry(
                      'files',
                      MultipartFile.fromString(_vector, filename: 'vector.svg'),
                    ),
                  ]),
              ),
            );
            attachmentIds = {
              for (final attachment
                  in (uploaded['success']! as List<Object?>).map(_object))
                _object(attachment['file'])['name']! as String:
                    attachment['id']! as int,
            };
            expect(
              attachmentIds.keys,
              unorderedEquals(['pixel.png', 'notes.txt', 'vector.svg']),
            );
            await send(
              owner,
              'PATCH',
              '/tasks/$taskId',
              body: () => {
                'cover_image_attachment_id': attachmentIds['pixel.png'],
              },
              contentType: 'application/merge-patch+json',
            );
            for (final (user, value) in [
              (owner, '👍'),
              (commenter, '👍'),
              (commenter, '🎉'),
            ]) {
              await send(
                user,
                'POST',
                '/tasks/$taskId/reactions',
                body: () => {'value': value},
              );
            }
            await comment(owner, taskId, 'first');
            await comment(commenter, taskId, 'second');

            pageTaskId =
                _object(
                      await send(
                        owner,
                        'POST',
                        '/projects/$projectId/tasks',
                        body: () => {'title': 'Paged comments $runId'},
                      ),
                    )['id']!
                    as int;
            // Quickly, so that some share a second.
            for (var i = 0; i < 5; i++) {
              await comment(owner, pageTaskId, 'page comment $i');
            }
            await _settle();
          });

          tearDownAll(() => dio.close(force: true));

          for (final apiVersion in ApiVersion.values) {
            group(apiVersion.pathSegment, () {
              late TasksPort reads;
              late TasksWritePort writes;
              late CommentsPort comments;
              late AttachmentsPort attachments;

              setUpAll(() {
                expect(connection.apiVersions, contains(apiVersion));
                final only = onlyVersion(connection, apiVersion);
                final authenticated = createAuthenticatedDio(
                  base: dio,
                  connection: only,
                  tokens: StaticJwt(owner.jwt),
                );
                final readClient = createReadClient(
                  dio: authenticated,
                  connection: only,
                );
                reads = readClient.tasks;
                comments = readClient.comments;
                attachments = readClient.attachments;
                writes = RetryingTasksWrites(
                  createWriteClient(dio: authenticated, connection: only).tasks,
                );
              });

              test('details: attachments, the cover, reactions, the comment '
                  'count and the subscription', () async {
                final taskId = task['id']! as int;

                final details = await reads.readDetails(taskId);

                expect(
                  {
                    for (final attachment in details.attachments)
                      attachment.name: (
                        attachment.id,
                        attachment.taskId,
                        attachment.mime.split(';').first,
                        attachment.createdBy?.id,
                      ),
                  },
                  {
                    'pixel.png': (
                      attachmentIds['pixel.png'],
                      taskId,
                      'image/png',
                      owner.id,
                    ),
                    'notes.txt': (
                      attachmentIds['notes.txt'],
                      taskId,
                      'text/plain',
                      owner.id,
                    ),
                    'vector.svg': (
                      attachmentIds['vector.svg'],
                      taskId,
                      'image/svg+xml',
                      owner.id,
                    ),
                  },
                );
                final notes = details.attachments.singleWhere(
                  (a) => a.name == 'notes.txt',
                );
                expect(notes.size, utf8.encode(_notes).length);
                expect(notes.created, isNotNull);
                expect(
                  details.coverImageAttachmentId,
                  attachmentIds['pixel.png'],
                );
                expect(details.reactions.keys, ['🎉', '👍']);
                expect(
                  details.reactions['👍']!.map((u) => u.id),
                  unorderedEquals([owner.id, commenter.id]),
                );
                expect(details.reactions['🎉']!.single.id, commenter.id);
                final all = await comments.list(taskId);
                expect(details.commentCount, all.items.length);
                expect(details.commentCount, greaterThanOrEqualTo(2));
                expect(
                  details.subscription,
                  Subscription(
                    entity: SubscriptionEntity.task,
                    entityId: taskId,
                  ),
                );
              });

              test('unread after a comment by someone else; markRead clears '
                  'it, again and again, for any task', () async {
                final taskId = task['id']! as int;
                await comment(commenter, taskId, 'unread $apiVersion');
                await _settle();

                expect((await reads.readDetails(taskId)).isUnread, isTrue);

                await writes.markRead(taskId);
                await _settle();
                expect((await reads.readDetails(taskId)).isUnread, isFalse);

                await writes.markRead(taskId);
                await writes.markRead(99999999);
                await _settle();
                expect((await reads.readDetails(taskId)).isUnread, isFalse);
              });

              test('comments: pages of two, oldest or newest first', () async {
                final oldest = <TaskComment>[];
                final newest = <TaskComment>[];
                for (var page = 1; page <= 3; page++) {
                  final ascending = await comments.list(
                    pageTaskId,
                    page: page,
                    perPage: 2,
                  );
                  final descending = await comments.list(
                    pageTaskId,
                    page: page,
                    perPage: 2,
                    newestFirst: true,
                  );
                  expect(ascending.totalPages, 3);
                  expect(ascending.perPage, 2);
                  expect(_sortedByCreatedThenId(ascending.items), isTrue);
                  expect(
                    _sortedByCreatedThenId(descending.items, down: true),
                    isTrue,
                  );
                  oldest.addAll(ascending.items);
                  newest.addAll(descending.items);
                }

                expect(oldest, hasLength(5));
                expect(oldest.map((c) => c.id).toSet(), hasLength(5));
                expect(_sortedByCreatedThenId(oldest), isTrue);
                expect(
                  newest.map((c) => c.id).toSet(),
                  oldest.map((c) => c.id).toSet(),
                );
                expect(oldest.first.html, '<p>page comment 0</p>');
                expect(oldest.first.author.id, owner.id);
                expect(oldest.first.isEdited, isFalse);
                expect(oldest.first.reactions, isEmpty);
                final beyond = await comments.list(
                  pageTaskId,
                  page: 4,
                  perPage: 2,
                );
                expect(beyond.items, isEmpty);
                expect(beyond.hasMore, isFalse);
              });

              test('previews: a PNG of an image at its width, the original '
                  'for a text file and an SVG', () async {
                final taskId = task['id']! as int;

                final preview = await attachments.fetch(
                  taskId,
                  attachmentIds['pixel.png']!,
                  preview: AttachmentPreviewSize.medium,
                );
                final original = await attachments.fetch(
                  taskId,
                  attachmentIds['pixel.png']!,
                );
                final text = await attachments.fetch(
                  taskId,
                  attachmentIds['notes.txt']!,
                  preview: AttachmentPreviewSize.medium,
                );
                final vector = await attachments.fetch(
                  taskId,
                  attachmentIds['vector.svg']!,
                  preview: AttachmentPreviewSize.medium,
                );

                expect(preview.contentType, 'image/png');
                expect(_pngWidth(preview.bytes), 200);
                expect(original.contentType, 'image/png');
                expect(original.bytes, _pixel);
                expect(text.contentType, 'text/plain');
                expect(utf8.decode(text.bytes), _notes);
                expect(vector.contentType, 'image/svg+xml');
                expect(vector.isSvg, isTrue);
                expect(utf8.decode(vector.bytes), _vector);
                await expectLater(
                  attachments.fetch(taskId, 99999999),
                  throwsA(isA<NotFound>()),
                );
              });

              test('by index: by project id and identifier in any case; an '
                  'unknown project or index is NotFound', () async {
                final taskId = task['id']! as int;
                final index = task['index']! as int;

                expect(
                  (await reads.readByIndex('$projectId', index)).id,
                  taskId,
                );
                expect((await reads.readByIndex(identifier, index)).id, taskId);
                expect(
                  (await reads.readByIndex(identifier.toLowerCase(), index)).id,
                  taskId,
                );
                await expectLater(
                  reads.readByIndex('ZZ${identifier}Q', index),
                  throwsA(isA<NotFound>()),
                );
                await expectLater(
                  reads.readByIndex(identifier, 999999),
                  throwsA(isA<NotFound>()),
                );
              });

              test('a task moved to another project: v2 follows the 307 '
                  'to it, v1 does not know the old index', () async {
                final moved = await writes.create(
                  NewTask(projectId: projectId, title: 'Moving $apiVersion'),
                );
                final oldIndex = moved.index;
                await writes.update(
                  moved.id,
                  TaskChanges(projectId: otherProjectId),
                );
                await _settle();

                final byOldIndex = reads.readByIndex('$projectId', oldIndex);
                switch (apiVersion) {
                  case ApiVersion.v2:
                    final found = await byOldIndex;
                    expect(found.id, moved.id);
                    expect(found.projectId, otherProjectId);
                  case ApiVersion.v1:
                    await expectLater(byOldIndex, throwsA(isA<NotFound>()));
                }
              });
            });
          }
        });
      }
    },
  );
}
