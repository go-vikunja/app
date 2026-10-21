import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/attachments/pending_upload.dart';
import 'package:vikunja_mobile/core/attachments/upload_files.dart';
import 'package:vikunja_mobile/core/attachments/upload_policy.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/watch_tables.dart';
import 'package:vikunja_mobile/core/filters/local_filters.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/outbox/pending_task_ids_source.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/outbox/upload_json.dart';
import 'package:vikunja_mobile/core/repositories/local/shared_latest.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/list_downloads.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';

final _log = Logger('AccountData');

/// Tasks from the account's database. The whole account is local, so a
/// list is never paged and every refresh is a sync run. A write lands in
/// the database and the outbox in one transaction, then the sender drains;
/// a create gets a temporary negative id that the sender remaps once the
/// server has named the task. A duplicate is made by the server and is
/// online only, and so is a view's download, which needs `read` (`perPage`
/// is the server's page size).
///
/// Filters are evaluated here on every change of the tasks, with the
/// server's rules ([LocalFilters]): a view's filter and search over its
/// project, a saved filter's over the tasks outside archived projects and
/// the favourite ones. A filter the engine refuses, one that names
/// `bucket_id`, and a saved filter whose definition is unknown here keep
/// the server's answer from the last download. A filter with a relative
/// date (`due_date < now/d+1d`) is evaluated again on every event of
/// `clockTicks`, a broadcast stream, as the time alone changes its tasks.
///
/// A file to upload is stored in the account's uploads folder (`uploads`)
/// under a random name before its op is queued, so the upload survives the
/// picker's copy going; without `uploads` nothing can be queued.
final class LocalTaskRepository
    implements TaskRepository, PendingTaskIdsSource {
  new(
    this._db,
    this._sync,
    this._outbox,
    this._write, {
    this._read,
    this._perPage = 50,
    DateTime Function()? now,
    this._clockTicks = const Stream.empty(),
    this._uploads,
    this._maxUploadBytes = defaultMaxUploadBytes,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final SyncEngine _sync;
  final OutboxSender _outbox;
  final VikunjaWriteClient _write;
  final VikunjaReadClient? _read;
  final int _perPage;
  final DateTime Function() _now;
  final Stream<void> _clockTicks;
  final UploadFiles? _uploads;
  final int _maxUploadBytes;

  // Upcoming and the Overview without a saved filter watch the same tasks.
  late final SharedLatest<List<Task>> _activeOpenTasks = SharedLatest(
    _db.tasksDao.watchActiveOpenTasks,
  );

  late final LocalFilters _filters = LocalFilters(_db, now: _now);

  Stream<String> _timezoneSetting() => _db.syncStateDao
      .watchValue(SyncStateKeys.userSettings)
      .map((stored) => decodeUserSettings(stored).timezone)
      .distinct();

  /// The saved filter [pick] finds in the stored state (null once the last
  /// project list no longer names it), with the user's timezone setting.
  Stream<({SavedFilterRef? filter, String timezone})> _savedFilterSelection(
    SavedFilterRef? Function(Map<String, String> state) pick,
  ) => _db.syncStateDao
      .watchValues({SyncStateKeys.userSettings, SyncStateKeys.savedFilters})
      .map(
        (state) => (
          filter: pick(state),
          timezone: decodeUserSettings(state[SyncStateKeys.userSettings])
              .timezone,
        ),
      )
      .distinct();

  /// The open tasks of [filter]'s evaluation here, as the Overview orders
  /// them; null when the device cannot evaluate it.
  Stream<List<Task>>? _openTasksOfSavedFilter(
    SavedFilterRef filter, {
    required String timezone,
  }) {
    final definition = filter.definition;
    if (definition == null || !evaluatesLocally(definition)) return null;
    return _openTasksMatching(definition, timezone: timezone);
  }

  Stream<List<Task>> _openTasksMatching(
    SavedFilterDefinition definition, {
    String timezone = '',
  }) => _db
      .watchTables(_db.tasksDao.savedFilterTables, () async {
        final ids = await _filters.matchingForSavedFilter(
          definition,
          timezoneSetting: timezone,
          openOnly: true,
        );
        return await _db.tasksDao.loadOpenTasksAmong(ids ?? const {});
      }, alsoOn: changesWithTime(definition.filter) ? _clockTicks : null)
      .distinct(listEquals);

  @override
  Stream<List<Task>> watchOpenTasks() => _db.tasksDao.watchOpenTasks();

  @override
  Stream<List<Task>> watchSearchableTasks() =>
      _db.tasksDao.watchSearchableTasks();

  @override
  Stream<List<Task>> watchActiveOpenTasks() => _activeOpenTasks.stream;

  @override
  Stream<OverviewTasks> watchOverviewTasks() =>
      switchLatest(_savedFilterSelection(overviewFilterIn), (selection) {
        final filter = selection.filter;
        if (filter == null) {
          return watchActiveOpenTasks().map(
            (tasks) => OverviewTasks(tasks: tasks),
          );
        }
        final local = _openTasksOfSavedFilter(
          filter,
          timezone: selection.timezone,
        );
        if (local != null) {
          return local.map(
            (tasks) => OverviewTasks(
              tasks: tasks,
              filter: filter,
              filterEvaluation: FilterEvaluation.local,
            ),
          );
        }
        return _db.tasksDao
            .watchOpenTasksInList(overviewSnapshotKey(filter.projectId))
            .map(
              (list) => OverviewTasks(
                tasks: list.tasks,
                filter: filter,
                filterLoadedAt: list.loadedAt,
              ),
            );
      });

  @override
  Stream<ProjectListSource> watchProjectList(
    int projectId, {
    required int viewId,
    bool includeDone = true,
  }) => switchLatest(_timezoneSetting(), (timezone) {
    var viewChangesWithTime = false;
    return _db.watchTables(_db.tasksDao.projectListTables, () async {
      final view = viewId == 0 ? null : await _db.projectsDao.loadView(viewId);
      viewChangesWithTime = changesWithTime(view?.filter);
      return await _db.tasksDao.loadProjectList(
        projectId,
        viewId: viewId,
        includeDone: includeDone,
        matchingIds: await _filters.matchingInProject(
          projectId,
          view?.filter,
          timezoneSetting: timezone,
        ),
      );
    }, alsoOn: _clockTicks.where((_) => viewChangesWithTime));
  });

  @override
  Future<void> refreshProjectList(int projectId, {required int viewId}) async {
    await _sync.refresh();
    if (viewId == 0) return;
    await downloadViewSnapshot(
      db: _db,
      client: _readClient('A view download'),
      perPage: _perPage,
      projectId: projectId,
      viewId: viewId,
      now: _now,
    );
  }

  @override
  Stream<BoardSource> watchBoard(int projectId, int viewId) =>
      switchLatest(_timezoneSetting(), (timezone) {
        var viewChangesWithTime = false;
        return _db.watchTables(_db.tasksDao.boardTables, () async {
          final view = await _db.projectsDao.loadView(viewId);
          viewChangesWithTime =
              view != null &&
              view.bucketConfigurationMode != BucketConfigurationMode.filter &&
              changesWithTime(view.filter);
          return await _db.tasksDao.loadBoard(
            projectId,
            viewId,
            matchingIds: await _filters.matchingOnBoard(
              projectId,
              view,
              timezoneSetting: timezone,
            ),
          );
        }, alsoOn: _clockTicks.where((_) => viewChangesWithTime));
      });

  @override
  Future<void> refreshBoard(int projectId, int viewId) async {
    await _sync.refresh();
    await downloadBoard(
      db: _db,
      client: _readClient('A board download'),
      perPage: _perPage,
      projectId: projectId,
      viewId: viewId,
      now: _now,
    );
  }

  @override
  Future<void> loadMoreOfBucket(int projectId, int viewId, int bucketId) =>
      downloadNextBucketPage(
        db: _db,
        client: _readClient('A bucket download'),
        perPage: _perPage,
        projectId: projectId,
        viewId: viewId,
        bucketId: bucketId,
      );

  @override
  Future<void> placeTask(
    int taskId, {
    required int viewId,
    required BucketPlacement placement,
    bool? done,
  }) => _queue(taskId, TaskChanges(kanban: {viewId: placement}, done: done));

  @override
  Future<void> positionTask(
    int taskId, {
    required int viewId,
    required double position,
  }) => _queue(taskId, TaskChanges(positions: {viewId: position}));

  @override
  Stream<List<Task>> watchFavoriteTasks() => _db.tasksDao.watchFavoriteTasks();

  @override
  Stream<ProjectProgress> watchProjectProgress(int projectId) =>
      _db.tasksDao.watchProjectProgress(projectId);

  @override
  Stream<Map<int, int>> watchOpenTaskCounts() =>
      _db.tasksDao.watchOpenTaskCounts();

  @override
  Stream<SavedFilterTasks> watchSavedFilterTasks(int pseudoProjectId) =>
      switchLatest(
        _savedFilterSelection(
          (state) => _storedSavedFilter(state, pseudoProjectId),
        ),
        (selection) {
          final local = switch (selection.filter) {
            final filter? => _openTasksOfSavedFilter(
              filter,
              timezone: selection.timezone,
            ),
            null => null,
          };
          if (local != null) {
            return local.map(
              (tasks) => SavedFilterTasks(
                tasks: tasks,
                evaluation: FilterEvaluation.local,
              ),
            );
          }
          return _db.tasksDao
              .watchOpenTasksInList(savedFilterSnapshotKey(pseudoProjectId))
              .map(
                (list) => SavedFilterTasks(
                  tasks: list.tasks,
                  loadedAt: list.loadedAt,
                ),
              );
        },
      );

  @override
  Stream<List<Task>> watchLabelTasks(int labelId) => _openTasksMatching(
    SavedFilterDefinition(
      filter: ViewFilter(filter: 'done = false && labels in $labelId'),
    ),
  );

  static SavedFilterRef? _storedSavedFilter(
    Map<String, String> state,
    int pseudoProjectId,
  ) =>
      decodeSavedFilters(state[SyncStateKeys.savedFilters])
          .where((filter) => filter.projectId == pseudoProjectId)
          .firstOrNull;

  /// The sync brings a changed definition; only a saved filter the device
  /// cannot evaluate is downloaded.
  @override
  Future<void> refreshSavedFilter(int pseudoProjectId) async {
    await _sync.refresh();
    final stored = _storedSavedFilter(
      await _db.syncStateDao.readAll(),
      pseudoProjectId,
    );
    if (evaluatesLocally(stored?.definition)) return;
    await downloadSavedFilter(
      db: _db,
      client: _readClient('A saved filter download'),
      perPage: _perPage,
      pseudoProjectId: pseudoProjectId,
      now: _now,
    );
  }

  @override
  Future<void> refreshOpenTasks() => _sync.refresh();

  @override
  Stream<Task?> watchTask(int taskId) => _db.tasksDao.watchTask(taskId);

  @override
  Future<int> createTask(NewTask task) async {
    final id = await _db.outboxDao.queueCreate(task, now: _now());
    _drainQuietly();
    return id;
  }

  @override
  Future<void> updateTask(int taskId, TaskChanges changes) =>
      changes.isEmpty ? Future.value() : _queue(taskId, changes);

  @override
  Future<bool> updateDescription(
    int taskId,
    String html, {
    required String base,
  }) async {
    if (html == base || (isRichTextEmpty(html) && isRichTextEmpty(base))) {
      return true;
    }
    final queued = await _db.outboxDao.queueUpdate(
      taskId,
      TaskChanges(description: html, descriptionBase: base),
      now: _now(),
    );
    if (queued) _drainQuietly();
    return queued;
  }

  /// The tap is queued only while the row still has [html], checked in the
  /// same transaction, so a second tap before the view caught up cannot
  /// land on a neighbour: every later item's offset moved.
  @override
  Future<bool> toggleChecklistItem(
    int taskId, {
    required String html,
    required RichTaskItem item,
    required bool checked,
  }) async {
    final toggled = toggleTaskItem(html, item, checked: checked);
    if (toggled == null) return false;
    if (toggled == html) return true;
    final document = parseRichText(
      html,
      apiRoot: _anyApiRoot,
      taskLinkBases: const [],
    );
    final parsed = document.taskItems
        .where((candidate) => candidate.sourceOffset == item.sourceOffset)
        .firstOrNull;
    if (parsed == null) return false;
    final queued = await _db.outboxDao.queueUpdate(
      taskId,
      TaskChanges(
        description: toggled,
        descriptionBase: html,
        checklistToggles: [
          checklistToggleFor(document, parsed, checked: checked),
        ],
      ),
      now: _now(),
      ifDescription: html,
    );
    if (queued) _drainQuietly();
    return queued;
  }

  // Which task items there are does not depend on the server's links.
  static final Uri _anyApiRoot = Uri.parse('https://task-items.invalid');

  @override
  Future<void> setDone(int taskId, {required bool done}) =>
      _queue(taskId, TaskChanges(done: done));

  /// Only the dates the task had are restored; the server never shifts an
  /// unset one. On an open task the server does not shift again, so the
  /// dates go with `done: false` whether the done is still queued (the two
  /// merge), in flight, or answered. The server shifts a repeating task's
  /// reminders with its dates, so they go back too.
  @override
  Future<void> undoDone(Task previous) => _queue(
    previous.id,
    TaskChanges(
      done: false,
      dueDate: _restore(previous.repeats ? previous.dueDate : null),
      startDate: _restore(previous.repeats ? previous.startDate : null),
      endDate: _restore(previous.repeats ? previous.endDate : null),
      reminders: previous.repeats && previous.reminders.isNotEmpty
          ? previous.reminders
          : null,
    ),
  );

  @override
  Future<void> setFavorite(int taskId, {required bool favorite}) =>
      _queue(taskId, TaskChanges(isFavorite: favorite));

  @override
  Future<void> deleteTask(int taskId) async {
    final queued = await _db.outboxDao.queueDelete(taskId, now: _now());
    if (queued) {
      // The delete dropped the task's unsent uploads.
      unawaited(_outbox.sweepUploads());
      _drainQuietly();
    }
  }

  @override
  Future<String?> queueUpload(
    int taskId, {
    required String sourcePath,
    required String fileName,
    String? mimeType,
    bool moveSource = false,
  }) async {
    final uploads =
        _uploads ?? (throw StateError('Queueing an upload needs its folder'));
    final source = File(sourcePath);
    final size = await source.length();
    if (size > _maxUploadBytes) {
      if (moveSource) await _deleteQuietly(source);
      throw UploadTooLarge(size: size, maxBytes: _maxUploadBytes);
    }
    if (!await _db.outboxDao.takesUploads(taskId)) {
      if (moveSource) await _deleteQuietly(source);
      return null;
    }
    final stored = await uploads.store(source, move: moveSource);
    try {
      final id = await _db.outboxDao.queueUpload(
        taskId,
        QueuedUpload(
          file: stored.name,
          fileName: safeFileName(fileName),
          size: stored.size,
          mimeType: mimeType,
        ),
        now: _now(),
      );
      if (id == null) {
        await uploads.delete(stored.name);
        return null;
      }
      _drainQuietly();
      return id;
    } on Object {
      await uploads.delete(stored.name);
      rethrow;
    } finally {
      uploads.release(stored.name);
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException catch (error) {
      _log.info('Could not delete a file: ${error.osError?.errorCode}');
    }
  }

  /// A row left `sending` by a run that died shows as waiting until the
  /// sender takes it up again.
  @override
  Stream<List<PendingUpload>> watchPendingUploads(int taskId) => switchLatest(
    _outbox.uploadingOperations,
    (uploading) => _db.outboxDao
        .watchPendingUploads(taskId)
        .map(
          (uploads) => [
            for (final upload in uploads)
              if (upload.state == PendingUploadState.sending &&
                  !uploading.contains(upload.operationId))
                upload.withState(PendingUploadState.waiting)
              else
                upload,
          ],
        ),
  );

  @override
  Stream<TaskAttachment> get uploadedAttachments => _outbox.uploadedAttachments;

  @override
  Future<void> cancelUpload(String operationId) =>
      _outbox.cancelUpload(operationId);

  /// The server copies the task as it has it, so the task's queued
  /// changes go first; a copy without them would lose them. The request is
  /// not idempotent: a copy made without the answer arriving comes with
  /// the next sync.
  @override
  Future<int> duplicateTask(int taskId) async {
    var id = await _db.tasksDao.resolveId(taskId);
    if (await _db.outboxDao.hasQueuedOps(id)) {
      final blockedBy = await _outbox.sendNow();
      id = await _db.tasksDao.resolveId(taskId);
      if (await _db.outboxDao.hasQueuedOps(id)) {
        throw blockedBy ?? TaskNotSyncedYet(taskId);
      }
    }
    final copy = await _write.tasks.duplicate(id);
    await _db.tasksDao.upsertAll([copy]);
    _log.fine('Duplicated task $id as ${copy.id}');
    return copy.id;
  }

  @override
  Stream<int> watchPendingChanges() => _db.outboxDao.watchCount();

  @override
  Stream<List<SyncProblem>> watchSyncProblems() =>
      _db.outboxDao.watchProblems();

  @override
  Stream<Set<int>> watchPendingTaskIds() => _db.outboxDao.watchPendingTaskIds();

  @override
  Future<void> retrySyncProblem(String operationId) =>
      _outbox.retry(operationId);

  @override
  Future<void> discardSyncProblem(String operationId) =>
      _outbox.discard(operationId);

  @override
  Future<String?> webDescription(String operationId) =>
      _outbox.webDescription(operationId);

  @override
  Future<void> keepMyDescription(
    String operationId, {
    required String webDescription,
  }) => _outbox.keepMyDescription(operationId, webDescription: webDescription);

  @override
  Future<void> useWebDescription(String operationId) =>
      _outbox.useWebDescription(operationId);

  @override
  Future<VikunjaFailure?> sendPendingChanges() => _outbox.sendNow();

  @override
  void dispose() {}

  /// A task unknown here, or queued for deletion, takes no change.
  Future<void> _queue(int taskId, TaskChanges changes) async {
    final queued = await _db.outboxDao.queueUpdate(
      taskId,
      changes,
      now: _now(),
    );
    if (queued) _drainQuietly();
  }

  VikunjaReadClient _readClient(String purpose) =>
      _read ?? (throw StateError('$purpose needs the read client'));

  static DateChange? _restore(DateTime? date) =>
      date == null ? null : DateChange.set(date);

  /// The write is done; the send reports through the outbox state and the
  /// sync problems.
  void _drainQuietly() => unawaited(
    _outbox.drain().then<void>(
      (_) {},
      onError: (Object error) =>
          _log.warning('Outbox drain failed: ${error.runtimeType}'),
    ),
  );
}
