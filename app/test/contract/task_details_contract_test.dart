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
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/attachments/attachment_image_cache.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_details_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_resolver.dart';

import '../helpers/sample_data.dart';
import '../helpers/test_database.dart';
import 'helpers.dart';

/// A 1×1 PNG, which the server can preview.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGMwTpv5HwAE'
  'NAIyWy0K4AAAAABJRU5ErkJggg==',
);

typedef _Seed = ({
  int projectId,
  String identifier,
  int otherProjectId,
  int taskId,
  int taskIndex,
  int attachmentId,
  List<int> commentIds,
  int movedId,
  int movedOldIndex,
});

/// The SQLite server may answer "database is locked" right after a write.
Future<void> _pause() =>
    Future<void>.delayed(const Duration(milliseconds: 500));

Future<_Seed> _seed(Dio dio, ServerConnection connection, TestUser user) async {
  final seeder = Seeder(dio, connection, user);
  final run = Random.secure().nextInt(1 << 24).toRadixString(16);
  final identifier = 'DT$run'.toUpperCase();
  final projectId = await seeder.create('/projects', {
    'title': 'Details $run',
    'identifier': identifier,
  });
  await _pause();
  final otherProjectId = await seeder.create('/projects', {
    'title': 'Moved $run',
    'identifier': 'DM$run'.toUpperCase(),
  });
  await _pause();
  final task = await seeder.post('/projects/$projectId/tasks', {
    'title': 'With details $run',
  });
  final taskId = task['id']! as int;
  await _pause();
  final commentIds = <int>[];
  for (final text in ['First', 'Second', 'Third']) {
    commentIds.add(
      await seeder.create('/tasks/$taskId/comments', {
        'comment': '<p>$text</p>',
      }),
    );
    await _pause();
  }
  await seeder.post('/tasks/$taskId/reactions', {'value': '👍'});
  await _pause();
  await seeder.post('/comments/${commentIds.first}/reactions', {'value': '🎉'});
  await _pause();
  final v2 = connection.apiBaseUri(ApiVersion.v2);
  final upload = await despiteWriteRaces(
    () => dio.postUri<Map<String, Object?>>(
      v2.replace(path: '${v2.path}/tasks/$taskId/attachments'),
      data: FormData.fromMap({
        'files': MultipartFile.fromBytes(_png, filename: 'pixel.png'),
      }),
      options: Options(headers: {'Authorization': 'Bearer ${user.jwt}'}),
    ),
  );
  final [attachment as Map<String, Object?>] =
      upload.data!['success']! as List<Object?>;
  await _pause();
  final moved = await seeder.post('/projects/$projectId/tasks', {
    'title': 'Moved away $run',
  });
  await _pause();
  await seeder.patch('/tasks/${moved['id']}', {'project_id': otherProjectId});
  await _pause();
  return (
    projectId: projectId,
    identifier: identifier,
    otherProjectId: otherProjectId,
    taskId: taskId,
    taskIndex: task['index']! as int,
    attachmentId: attachment['id']! as int,
    commentIds: commentIds,
    movedId: moved['id']! as int,
    movedOldIndex: moved['index']! as int,
  );
}

// One user for the whole file: /register and /login share the limiter.
void main() {
  group(
    'task details and links against the local Docker server',
    skip: contractSkip,
    () {
      late Dio dio;
      late ServerConnection connection;
      late TestUser user;
      late _Seed seed;

      setUpAll(() async {
        dio = contractDio();
        connection = await DioServerConnector(dio)
            .connect('http://localhost:$contractServerPort');
        user = await registerAndLogin(dio, connection);
        seed = await _seed(dio, connection, user);
      });

      tearDownAll(() => dio.close(force: true));

      for (final apiVersion in ApiVersion.values) {
        group('over ${apiVersion.pathSegment}', () {
          late VikunjaReadClient reads;
          late VikunjaWriteClient writes;
          late AppDatabase db;
          late LocalTaskResolver resolver;
          late LocalTaskDetailsRepository details;

          setUp(() {
            final only = onlyApiVersion(connection, apiVersion);
            final authenticated = createAuthenticatedDio(
              base: dio,
              connection: only,
              tokens: StaticJwt(user.jwt),
            );
            reads = createReadClient(dio: authenticated, connection: only);
            writes = createWriteClient(dio: authenticated, connection: only);
            db = testDatabase();
            resolver = LocalTaskResolver(db, reads);
            details = LocalTaskDetailsRepository(db, reads, writes);
          });

          test(
            'a task id the device does not have is read and stored',
            () async {
              final task = await resolver.resolve(TaskById(seed.taskId));

              expect(task.projectId, seed.projectId);
              expect(task.title, startsWith('With details'));
              expect((await db.tasksDao.find(seed.taskId))?.title, task.title);
            },
          );

          test('an identifier no local project has is sent as typed', () async {
            final task = await resolver.resolve(
              TaskByIdentifier(seed.identifier.toLowerCase(), seed.taskIndex),
            );

            expect(task.id, seed.taskId);
          });

          test('a local project goes by its numeric id', () async {
            // A stale local identifier proves the server never saw it.
            await db.projectsDao.upsertAll([
              sampleProject(
                id: seed.projectId,
                title: 'Details',
                identifier: 'STALE',
              ),
            ]);

            final task = await resolver.resolve(
              TaskByIdentifier('stale', seed.taskIndex),
            );

            expect(task.id, seed.taskId);
          });

          test('the old address of a moved task', () async {
            final reference = TaskByIdentifier(
              seed.identifier,
              seed.movedOldIndex,
            );

            switch (apiVersion) {
              case ApiVersion.v2:
                final task = await resolver.resolve(reference);
                expect(task.id, seed.movedId);
                expect(task.projectId, seed.otherProjectId);
              case ApiVersion.v1:
                await expectLater(
                  resolver.resolve(reference),
                  throwsA(isA<NotFound>().having((f) => f.code, 'code', 4002)),
                );
            }
          });

          test('an unknown project or index is not found', () async {
            await expectLater(
              resolver.resolve(TaskByIdentifier('NO${seed.identifier}', 1)),
              throwsA(isA<NotFound>()),
            );
            await expectLater(
              resolver.resolve(TaskByIdentifier(seed.identifier, 999)),
              throwsA(isA<NotFound>().having((f) => f.code, 'code', 4002)),
            );
            await expectLater(
              resolver.resolve(const TaskById(999999999)),
              throwsA(isA<NotFound>()),
            );
          });

          test('the details of a task come in one read', () async {
            final read = await details.details(seed.taskId);

            expect(read.commentCount, 3);
            expect(read.isUnread, isFalse);
            expect(read.reactions.keys, ['👍']);
            expect(read.reactions['👍']!.single.username, user.username);
            final attachment = read.attachments.single;
            expect(attachment.id, seed.attachmentId);
            expect(attachment.name, 'pixel.png');
            expect(attachment.mime, startsWith('image/png'));
            expect(attachment.size, _png.length);
            expect(read.coverImageAttachmentId, 0);
            // The server subscribes the creator.
            expect(read.subscription?.entity, SubscriptionEntity.task);
          });

          test('comments come in both orders with their reactions', () async {
            final oldest = await details.comments(seed.taskId);
            final newest = await details.comments(
              seed.taskId,
              newestFirst: true,
            );

            expect(oldest.items.map((c) => c.id), seed.commentIds);
            expect(oldest.items.map((c) => c.html), [
              '<p>First</p>',
              '<p>Second</p>',
              '<p>Third</p>',
            ]);
            expect(oldest.items.first.author.username, user.username);
            expect(oldest.items.first.reactions.keys, ['🎉']);
            expect(oldest.items.first.isEdited, isFalse);
            expect(newest.items.map((c) => c.id), seed.commentIds.reversed);
            expect(oldest.hasMore, isFalse);
          });

          test('marking read twice is fine', () async {
            await details.markRead(seed.taskId);
            await details.markRead(seed.taskId);

            expect((await details.details(seed.taskId)).isUnread, isFalse);
          });

          test('attachment images load with the account session', () async {
            final images = AttachmentImageCache(
              (task, attachment, preview) =>
                  reads.attachments.fetch(task, attachment, preview: preview),
            );

            final preview = await images.load(
              seed.taskId,
              seed.attachmentId,
              preview: AttachmentPreviewSize.medium,
            );
            final original = await images.load(seed.taskId, seed.attachmentId);

            // 2.7.1 and newer send JPEGs of opaque images, older servers PNGs.
            expect(
              preview.contentType,
              connection.info.version!.isAtLeast(2, 7, 1)
                  ? 'image/jpeg'
                  : 'image/png',
            );
            expect(preview.bytes.length, greaterThan(_png.length));
            expect(original.contentType, 'image/png');
            expect(original.bytes, _png);
          });
        });
      }
    },
  );
}
