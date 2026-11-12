import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/filters/local_filters.dart';
import 'package:vikunja_mobile/core/repositories/bucket_repository.dart';

final _log = Logger('AccountData');

const _bucketDoesNotExist = 10001;

typedef BoardRefresh = Future<void> Function(int projectId, int viewId);

/// Bucket changes straight to the server, written into the stored board
/// and view once answered; [_refreshBoard] (the task repository's) then
/// runs quietly, as a deleted bucket's tasks, the counts and a view changed
/// elsewhere are only known to the server. It also runs after an update
/// of a bucket deleted elsewhere, which then leaves the board.
final class LocalBucketRepository implements BucketRepository {
  new(
    this._db,
    this._write, {
    required this._refreshBoard,
    this._guest = false,
    DateTime Function()? now,
  }) : _filters = LocalFilters(_db, now: now ?? DateTime.now);

  final AppDatabase _db;
  final VikunjaWriteClient _write;
  final BoardRefresh _refreshBoard;

  /// A link-share guest's, which never changes the view.
  final bool _guest;
  final LocalFilters _filters;

  @override
  Future<void> create(int projectId, int viewId, String title) async {
    final trimmed = _checkedTitle(title);
    final buckets = await _db.kanbanDao.buckets(viewId);
    final created = await _write.buckets.create(
      projectId,
      viewId,
      title: trimmed,
      position: calculateItemPosition(buckets.lastOrNull?.position, null),
    );
    await _db.kanbanDao.putBucket(
      Bucket(
        id: created.id,
        viewId: viewId,
        title: created.title,
        limit: created.limit,
        position: created.position,
      ),
    );
    _settle(projectId, viewId, 'Created bucket ${created.id}');
  }

  @override
  Future<void> rename(
    int projectId,
    int viewId,
    int bucketId,
    String title,
  ) async {
    final trimmed = _checkedTitle(title);
    final bucket = await _stored(viewId, bucketId);
    await _update(
      projectId,
      viewId,
      bucket,
      title: trimmed,
      limit: bucket.limit,
      position: bucket.position,
    );
    _settle(projectId, viewId, 'Renamed bucket $bucketId');
  }

  @override
  Future<void> setLimit(
    int projectId,
    int viewId,
    int bucketId,
    int limit,
  ) async {
    if (limit < 0) throw ArgumentError.value(limit, 'limit');
    final bucket = await _stored(viewId, bucketId);
    await _update(
      projectId,
      viewId,
      bucket,
      title: bucket.title,
      limit: limit,
      position: bucket.position,
    );
    _settle(projectId, viewId, 'Set the limit of bucket $bucketId');
  }

  @override
  Future<void> move(
    int projectId,
    int viewId,
    int bucketId, {
    required int toIndex,
  }) async {
    final buckets = await _db.kanbanDao.buckets(viewId);
    final bucket = _find(buckets, bucketId);
    final position = planBucketMove(buckets, bucketId, toIndex);
    if (position == null) return;
    await _update(
      projectId,
      viewId,
      bucket,
      title: bucket.title,
      limit: bucket.limit,
      position: position,
    );
    _settle(projectId, viewId, 'Moved bucket $bucketId');
  }

  @override
  Future<void> delete(int projectId, int viewId, int bucketId) async {
    final doomed = await _stored(viewId, bucketId);
    // The default may have changed on the web since the last sync.
    final view = await _write.views.setBuckets(projectId, viewId);
    await _storeView(viewId, view);
    var plan = await _planDeletion(projectId, viewId, view, bucketId);
    if (plan != null && plan.isFallback && !plan.defaultFirst) {
      await _refreshBoard(projectId, viewId);
      plan = await _planDeletion(projectId, viewId, view, bucketId);
    }
    if (_guest) {
      final refused = guestDeletion(
        bucketId,
        plan,
        doneBucketId: view.doneBucketId,
        defaultBucketId: view.defaultBucketId,
      );
      if (refused != null) throw GuestViewChange(refused);
    }
    if (plan != null && plan.defaultFirst) {
      await _deleteAfterNewDefault(
        projectId,
        viewId,
        doomed,
        newDefault: plan.tasksGoTo,
        oldDefaultId: view.defaultBucketId,
      );
    } else {
      await _write.buckets.delete(projectId, viewId, bucketId);
    }
    await _db.transaction(() async {
      await _db.kanbanDao.removeBucket(
        viewId,
        bucketId,
        movesTo: plan?.tasksGoTo.id,
      );
      final stored = await _db.projectsDao.loadView(viewId);
      await _db.projectsDao.setViewBuckets(
        viewId,
        doneBucketId: stored?.doneBucketId == bucketId ? 0 : null,
        defaultBucketId: stored?.defaultBucketId == bucketId ? 0 : null,
      );
    });
    _settle(projectId, viewId, 'Deleted bucket $bucketId');
  }

  Future<BucketDeletion?> _planDeletion(
    int projectId,
    int viewId,
    ProjectView view,
    int bucketId,
  ) async {
    // The column as the board shows it, its filter evaluated here.
    final source = await _db.tasksDao.loadBoard(
      projectId,
      viewId,
      matchingIds: await _filters.matchingOnBoard(
        projectId,
        view,
        timezoneSetting: await _filters.timezoneSetting(),
      ),
    );
    final column = buildBoard(
      view: view,
      buckets: source.buckets,
      snapshot: source.snapshot,
      loadedAt: source.loadedAt,
      projectTasks: source.projectTasks,
      queued: source.queued,
      movedHere: source.movedHere,
      queuedDoneChanges: source.queuedDoneChanges,
      matchingIds: source.matchingIds,
    ).where((column) => column.bucket.id == bucketId).firstOrNull;
    return planBucketDeletion(
      source.buckets,
      bucketId,
      defaultBucketId: view.defaultBucketId,
      holdsTasks: column != null && columnHoldsTasks(column),
    );
  }

  /// A failed delete puts the old default back: even when the server did
  /// delete the bucket before the answer was lost, its tasks have moved
  /// then and the old default changes nothing more.
  Future<void> _deleteAfterNewDefault(
    int projectId,
    int viewId,
    Bucket doomed, {
    required Bucket newDefault,
    required int oldDefaultId,
  }) async {
    await _storeView(
      viewId,
      await _write.views.setBuckets(
        projectId,
        viewId,
        defaultBucketId: newDefault.id,
      ),
    );
    try {
      await _write.buckets.delete(projectId, viewId, doomed.id);
    } on Object catch (failure) {
      try {
        await _storeView(
          viewId,
          await _write.views.setBuckets(
            projectId,
            viewId,
            defaultBucketId: oldDefaultId,
          ),
        );
      } on Object {
        throw DeleteFailedAfterNewDefault(
          failure,
          bucket: doomed,
          newDefault: newDefault,
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> setDoneBucket(int projectId, int viewId, int? bucketId) async {
    if (_guest) throw const GuestViewChange();
    await _storeView(
      viewId,
      await _write.views.setBuckets(
        projectId,
        viewId,
        doneBucketId: bucketId ?? 0,
      ),
    );
    _settle(projectId, viewId, 'Set the done bucket of view $viewId');
  }

  @override
  Future<void> setDefaultBucket(
    int projectId,
    int viewId,
    int? bucketId,
  ) async {
    if (_guest) throw const GuestViewChange();
    await _storeView(
      viewId,
      await _write.views.setBuckets(
        projectId,
        viewId,
        defaultBucketId: bucketId ?? 0,
      ),
    );
    _settle(projectId, viewId, 'Set the default bucket of view $viewId');
  }

  Future<void> _update(
    int projectId,
    int viewId,
    Bucket bucket, {
    required String title,
    required int limit,
    required double position,
  }) async {
    final Bucket sent;
    try {
      sent = await _write.buckets.update(
        projectId,
        viewId,
        bucketId: bucket.id,
        title: title,
        limit: limit,
        position: position,
      );
    } on NotFound catch (failure) {
      if (failure.code == _bucketDoesNotExist) {
        _settle(projectId, viewId, 'Bucket ${bucket.id} is gone');
      }
      rethrow;
    }
    await _db.kanbanDao.updateBucket(
      viewId,
      bucket.id,
      title: sent.title,
      limit: sent.limit,
      position: sent.position,
    );
  }

  Future<void> _storeView(int viewId, ProjectView view) =>
      _db.projectsDao.setViewBuckets(
        viewId,
        doneBucketId: view.doneBucketId,
        defaultBucketId: view.defaultBucketId,
      );

  Future<Bucket> _stored(int viewId, int bucketId) async =>
      _find(await _db.kanbanDao.buckets(viewId), bucketId);

  /// A bucket the stored board no longer has went with a download, which
  /// only drops what the server no longer has.
  static Bucket _find(List<Bucket> buckets, int bucketId) =>
      buckets.where((bucket) => bucket.id == bucketId).firstOrNull ??
      (throw const NotFound(code: _bucketDoesNotExist));

  static String _checkedTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(title, 'title');
    return trimmed;
  }

  void _settle(int projectId, int viewId, String done) {
    _log.fine(done);
    unawaited(
      _refreshBoard(projectId, viewId).then<void>(
        (_) {},
        onError: (Object error) => _log.fine(
          'Board $viewId download after a bucket change failed: '
          '${error.runtimeType}',
        ),
      ),
    );
  }
}
