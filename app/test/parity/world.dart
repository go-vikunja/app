import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_mobile/core/attachments/upload_files.dart';
import 'package:vikunja_mobile/core/attachments/upload_policy.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/local/local_label_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_details_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';

import '../helpers/test_database.dart';
import 'backends.dart';
import 'flaky_write_client.dart';

/// The app's own stack over a backend, as one account has it: a fresh
/// database synced once, the sync engine, the outbox sender and the task,
/// label and details repositories, whose writes go through [writes].
/// Everything is closed when the test ends.
final class ParityWorld {
  new _({
    required this.backend,
    required this.db,
    required this.writes,
    required this.engine,
    required this.sender,
    required this.tasks,
    required this.labels,
    required this.details,
    required this._files,
  });

  static Future<ParityWorld> open(ParityBackend backend) async {
    final db = testDatabase();
    final files = await Directory.systemTemp.createTemp('parity');
    addTearDown(() => files.delete(recursive: true));
    final writes = FlakyWriteClient(backend.server);
    final engine = DefaultSyncEngine(
      db: db,
      client: backend.read,
      perPage: backend.perPage,
      currentUser: backend.currentUser,
    );
    addTearDown(engine.dispose);
    final uploads = UploadFiles(
      () async => Directory(p.join(files.path, 'uploads')),
    );
    final sender = OutboxSender(
      db: db,
      writeClient: writes,
      readClient: backend.read,
      sync: engine,
      uploads: uploads,
      currentUserId: () => backend.me.id,
      maxUploadBytes: () => defaultMaxUploadBytes,
    );
    addTearDown(sender.dispose);
    final tasks = LocalTaskRepository(
      db,
      engine,
      sender,
      writes,
      read: backend.read,
      perPage: backend.perPage,
      uploads: uploads,
    );
    addTearDown(tasks.dispose);
    await engine.ensureInitialSync();
    return ParityWorld._(
      backend: backend,
      db: db,
      writes: writes,
      engine: engine,
      sender: sender,
      tasks: tasks,
      labels: LocalLabelRepository(
        db,
        writes,
        outbox: sender,
        sync: engine,
        currentUser: () => backend.me,
      ),
      details: LocalTaskDetailsRepository(
        db,
        backend.read,
        writes,
        me: backend.me,
      ),
      files: files,
    );
  }

  final ParityBackend backend;
  final AppDatabase db;
  final FlakyWriteClient writes;
  final DefaultSyncEngine engine;
  final OutboxSender sender;
  final LocalTaskRepository tasks;
  final LocalLabelRepository labels;
  final LocalTaskDetailsRepository details;
  final Directory _files;

  /// A drain whose transient failures (the test server answers a lost
  /// write race with a 500) are retried on the sender's timer; the second
  /// drain waits out the refresh that a send on the timer starts, which
  /// would otherwise run on into the next step.
  Future<void> drainFully() async {
    await sender.drain();
    await until(() async => await db.outboxDao.count() == 0);
    await sender.drain();
  }

  /// "Send now" until the outbox is empty, so an op that lost its answer
  /// is tried again without waiting for its backoff.
  Future<void> sendNowFully() async {
    final deadline = DateTime.now().add(_patience);
    while (await db.outboxDao.count() > 0) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure(
          'The outbox still holds ${await db.outboxDao.all()} after '
          '$_patience',
        );
      }
      await sender.sendNow();
      if (await db.outboxDao.count() == 0) break;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    await sender.drain();
  }

  /// A sync that picks up what the server stored meanwhile, such as a
  /// comment's count: it waits for a run under way, which may have read
  /// the server before, and then runs.
  Future<void> refreshAfterServerWrite() async {
    await backend.settle();
    await engine.refreshAfterWrite();
  }

  Future<void> until(Future<bool> Function() condition) async {
    final deadline = DateTime.now().add(_patience);
    while (!await condition()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('Condition not met within $_patience');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  /// A file to upload, in a folder of its own.
  File file(String name, List<int> bytes) =>
      File(p.join(_files.path, 'picked', name))
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);

  static const _patience = Duration(seconds: 30);
}
