@Tags(['contract'])
@Timeout(Duration(minutes: 8))
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/attachment_downloads.dart';
import 'package:vikunja_mobile/core/attachments/upload_files.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/local/local_attachment_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';

import '../helpers/test_database.dart';
import 'helpers.dart';

// Per API version, attachments through the repository and the outbox
// against the real server: files queued offline (for a synced task and for
// one created offline) arrive once the connection is back and equal the
// server's attachments byte for byte; a cover deleted on the server no
// longer blocks an edit made in the app. One user for the whole file.
const _pace = Duration(milliseconds: 500);

/// The real write client behind a connection that is down while [offline]
/// is set; only the calls these tests make are switched.
final class _SwitchableWriteClient implements VikunjaWriteClient {
  new(this._real);

  final VikunjaWriteClient _real;
  bool offline = false;

  @override
  late final TasksWritePort tasks = _SwitchableTasks(this);

  @override
  late final AttachmentsWritePort attachments = _SwitchableAttachments(this);

  @override
  LabelsWritePort get labels => _real.labels;

  @override
  NotificationsWritePort get notifications => _real.notifications;

  @override
  SubscriptionsWritePort get subscriptions => _real.subscriptions;

  @override
  BucketsWritePort get buckets => _real.buckets;

  @override
  ProjectViewsWritePort get views => _real.views;

  @override
  ProjectsWritePort get projects => _real.projects;

  @override
  SavedFiltersPort get savedFilters => _real.savedFilters;

  @override
  CommentsWritePort get comments => _real.comments;

  @override
  ReactionsWritePort get reactions => _real.reactions;

  void _check() {
    if (offline) throw const NetworkFailure(NetworkProblem.unreachable);
  }
}

final class _SwitchableTasks implements TasksWritePort {
  new(this._client);

  final _SwitchableWriteClient _client;

  @override
  Future<Task> create(NewTask task) {
    _client._check();
    return _client._real.tasks.create(task);
  }

  @override
  Future<Task> update(
    int id,
    TaskChanges changes, {
    String Function(String current)? rebaseDescription,
  }) {
    _client._check();
    return _client._real.tasks.update(
      id,
      changes,
      rebaseDescription: rebaseDescription,
    );
  }

  @override
  Future<void> delete(int id) {
    _client._check();
    return _client._real.tasks.delete(id);
  }

  @override
  Future<Task> duplicate(int id) {
    _client._check();
    return _client._real.tasks.duplicate(id);
  }

  @override
  Future<void> markRead(int id) {
    _client._check();
    return _client._real.tasks.markRead(id);
  }
}

final class _SwitchableAttachments implements AttachmentsWritePort {
  new(this._client);

  final _SwitchableWriteClient _client;

  @override
  Future<TaskAttachment> upload(
    int taskId, {
    required String fileName,
    required Stream<List<int>> bytes,
    required int length,
    String? mimeType,
    Duration? timeout,
    CancelToken? cancel,
  }) {
    _client._check();
    return _client._real.attachments.upload(
      taskId,
      fileName: fileName,
      bytes: bytes,
      length: length,
      mimeType: mimeType,
      timeout: timeout,
      cancel: cancel,
    );
  }

  @override
  Future<void> delete(int taskId, int attachmentId) {
    _client._check();
    return _client._real.attachments.delete(taskId, attachmentId);
  }
}

Future<void> _until(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

void main() {
  group(
    'attachments through the outbox against the local Docker server',
    skip: contractSkip,
    () {
      late Dio dio;
      late ServerConnection connection;
      late TestUser user;
      late Seeder seeder;
      late Directory files;

      setUpAll(() async {
        dio = contractDio();
        connection = await DioServerConnector(dio)
            .connect('http://localhost:$contractServerPort');
        user = await registerAndLogin(dio, connection);
        seeder = Seeder(dio, connection, user);
        files = Directory.systemTemp.createTempSync('attachments_contract');
      });

      tearDownAll(() async {
        dio.close(force: true);
        await files.delete(recursive: true);
      });

      for (final apiVersion in ApiVersion.values) {
        group('over ${apiVersion.pathSegment}', () {
          late VikunjaReadClient reads;
          late _SwitchableWriteClient writes;
          late AppDatabase db;
          late OutboxSender sender;
          late LocalTaskRepository tasks;
          late LocalAttachmentRepository attachments;
          late Dio authenticated;
          late int projectId;
          late Directory uploadsFolder;

          Future<int> seedTask(String title) async {
            final id = await seeder.create('/projects/$projectId/tasks', {
              'title': title,
            });
            await Future<void>.delayed(_pace);
            return id;
          }

          Future<void> syncIn(int taskId) async {
            await db.tasksDao.upsertAll([
              await patiently(() => reads.tasks.read(taskId)),
            ], syncRunId: 'contract');
          }

          File picked(String name, List<int> bytes) =>
              File(p.join(files.path, '${apiVersion.name}-$name'))
                ..writeAsBytesSync(bytes);

          setUpAll(() async {
            projectId = await seeder.create('/projects', {
              'title': 'Attachments ${apiVersion.pathSegment}',
            });
            await Future<void>.delayed(_pace);
            final only = onlyApiVersion(connection, apiVersion);
            authenticated = createAuthenticatedDio(
              base: dio,
              connection: only,
              tokens: StaticJwt(user.jwt),
            );
            reads = createReadClient(dio: authenticated, connection: only);
            writes = _SwitchableWriteClient(
              createWriteClient(dio: authenticated, connection: only),
            );
            db = testDatabase();
            final engine = DefaultSyncEngine(
              db: db,
              client: reads,
              perPage: only.info.maxItemsPerPage,
              currentUser: AccountApi(
                authenticated,
                only,
              ).currentUserWithSettings,
            );
            addTearDown(engine.dispose);
            uploadsFolder = Directory(
              p.join(files.path, apiVersion.name, 'uploads'),
            );
            final uploads = UploadFiles(() async => uploadsFolder);
            sender = OutboxSender(
              db: db,
              writeClient: writes,
              readClient: reads,
              sync: engine,
              uploads: uploads,
              currentUserId: () => user.id,
            );
            addTearDown(sender.dispose);
            tasks = LocalTaskRepository(
              db,
              engine,
              sender,
              writes,
              read: reads,
              uploads: uploads,
              maxUploadBytes: only.info.maxFileSizeBytes ?? 20 << 20,
            );
            addTearDown(tasks.dispose);
            attachments = LocalAttachmentRepository(
              db,
              reads,
              writes,
              AttachmentDownloads(
                () async => Directory(p.join(files.path, apiVersion.name)),
              ),
              accountId: 'contract',
              uploadsEnabled: only.info.taskAttachmentsEnabled,
              maxUploadBytes: only.info.maxFileSizeBytes ?? 20 << 20,
            );
          });

          test('files queued offline arrive once the connection is back and '
              "equal the server's attachments", () async {
            final random = Random(apiVersion.index);
            final photo = [for (var i = 0; i < 70000; i++) random.nextInt(256)];
            const note = [0x48, 0x69, 0x0a];
            final existingId = await seedTask('Existing');
            await syncIn(existingId);
            final uploaded = <TaskAttachment>[];
            final subscription = tasks.uploadedAttachments.listen(uploaded.add);
            addTearDown(subscription.cancel);

            writes.offline = true;
            await tasks.queueUpload(
              existingId,
              sourcePath: picked('photo', photo).path,
              fileName: 'Ünïcødé 日本.bin',
            );
            final localId = await tasks.createTask(
              NewTask(projectId: projectId, title: 'Created offline'),
            );
            await tasks.queueUpload(
              localId,
              sourcePath: picked('note', note).path,
              fileName: 'note.txt',
              mimeType: 'text/plain',
            );
            await sender.drain();
            expect(await db.outboxDao.count(), 3);
            expect(uploadsFolder.listSync(), hasLength(2));
            final waiting = await tasks.watchPendingUploads(existingId).first;
            expect(waiting.single.lastFailure, isA<NetworkFailure>());

            writes.offline = false;
            await sender.sendNow();
            await _until(() async => await db.outboxDao.count() == 0);

            final createdId = (await tasks.watchTask(localId).first)!.id;
            expect(createdId, isPositive);
            expect(uploadsFolder.listSync(), isEmpty);
            await _until(() async => uploaded.length == 2);
            for (final (taskId, bytes, name) in [
              (existingId, photo, 'Ünïcødé 日本.bin'),
              (createdId, note, 'note.txt'),
            ]) {
              final details = await patiently(
                () => reads.tasks.readDetails(taskId),
              );
              final onServer = details.attachments.single;
              expect(onServer.name, name);
              expect(onServer.size, bytes.length);
              expect(onServer.createdBy?.id, user.id);
              expect(
                uploaded.where((attachment) => attachment.taskId == taskId),
                [onServer],
              );
              final downloaded = await attachments.download(taskId, onServer);
              expect(downloaded.readAsBytesSync(), bytes);
            }
          });

          test('a cover deleted on the server does not block an edit from '
              'the app', () async {
            final taskId = await seedTask('Covered');
            final stored = await attachments.uploadNow(
              taskId,
              picked('cover', const [1, 2, 3, 4]),
              fileName: 'cover.txt',
            );
            await Future<void>.delayed(_pace);
            await seeder.patch('/tasks/$taskId', {
              'cover_image_attachment_id': stored.id,
            });
            await Future<void>.delayed(_pace);
            await seeder.delete('/tasks/$taskId/attachments/${stored.id}');
            await Future<void>.delayed(_pace);
            expect(
              (await patiently(() => reads.tasks.readDetails(taskId)))
                  .coverImageAttachmentId,
              stored.id,
              reason: 'the server keeps the deleted cover',
            );
            await syncIn(taskId);

            await tasks.updateTask(
              taskId,
              const TaskChanges(title: 'Covered and renamed'),
            );
            await sender.sendNow();
            await _until(() async => await db.outboxDao.count() == 0);

            expect(await db.outboxDao.loadProblems(), isEmpty);
            final onServer = await patiently(() => reads.tasks.read(taskId));
            expect(onServer.title, 'Covered and renamed');
            expect(
              (await patiently(() => reads.tasks.readDetails(taskId)))
                  .coverImageAttachmentId,
              0,
            );
          });
        });
      }
    },
  );
}
