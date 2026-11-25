import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/filters/local_filters.dart';
import 'package:vikunja_mobile/core/repositories/bucket_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_helpers.dart';

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
    required this._read,
    required ServerVersion? serverVersion,
    required this._refreshBoard,
    DateTime Function()? now,
  }) : _filters = LocalFilters(_db, now: now ?? DateTime.now),
       _storesGoneBuckets = !(serverVersion?.isAtLeast(2, 5) ?? false);

  final AppDatabase _db;
  final VikunjaWriteClient _write;
  final VikunjaReadClient _read;
  final BoardRefresh _refreshBoard;
  final LocalFilters _filters;

  /// Before 2.5 the server stores a done or default bucket it no longer
  /// has as sent, where later ones store none; tasks sent there leave the
  /// board.
  final bool _storesGoneBuckets;

  @override
  Future<void> create(int projectId, int viewId, String title) async {
    final trimmed = checkedTitle(title);
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
    final trimmed = checkedTitle(title);
    await _stored(viewId, bucketId);
    final fresh = await _freshBuckets(projectId, viewId);
    final bucket = _freshOne(fresh, projectId, viewId, bucketId);
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
    await _stored(viewId, bucketId);
    final fresh = await _freshBuckets(projectId, viewId);
    final bucket = _freshOne(fresh, projectId, viewId, bucketId);
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
    final shown = await _db.kanbanDao.buckets(viewId);
    _find(shown, bucketId);
    if (planBucketMove(shown, bucketId, toIndex) == null) return;
    final fresh = await _freshBuckets(projectId, viewId);
    final bucket = _freshOne(fresh, projectId, viewId, bucketId);
    final freshIndex = _pastSameColumn(shown, fresh, bucketId, toIndex);
    if (freshIndex != null && _indexIn(fresh, bucketId) == freshIndex) {
      _settle(projectId, viewId, 'Bucket $bucketId in place on the server');
      return;
    }
    final position = freshIndex == null
        ? null
        : planBucketMove(fresh, bucketId, freshIndex);
    if (position == null) {
      _settle(projectId, viewId, 'Bucket $bucketId not moved after a read');
      throw BucketMoveOutdated(bucket: _find(shown, bucketId));
    }
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
    final defaultGone =
        view.defaultBucketId != bucketId &&
        !await _stillHas(projectId, viewId, view.defaultBucketId);
    Future<BucketDeletion?> planned() =>
        _planDeletion(projectId, viewId, view, bucketId, defaultGone);
    var plan = await planned();
    if (plan != null && plan.isFallback && !plan.defaultFirst) {
      await _refreshBoard(projectId, viewId);
      plan = await planned();
    }
    if (plan != null && plan.defaultFirst) {
      await _deleteAfterNewDefault(
        projectId,
        viewId,
        doomed,
        newDefault: plan.tasksGoTo,
        oldDefaultId: defaultGone ? 0 : view.defaultBucketId,
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
    bool defaultGone,
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
      defaultGone: defaultGone,
    );
  }

  /// A failed delete, or a failed check that the new default exists, puts
  /// the old default back: even when the server did delete the bucket
  /// before the answer was lost, its tasks have moved then and the old
  /// default changes nothing more.
  Future<void> _deleteAfterNewDefault(
    int projectId,
    int viewId,
    Bucket doomed, {
    required Bucket newDefault,
    required int oldDefaultId,
  }) async {
    final ProjectView answered;
    try {
      answered = await _write.views.setBuckets(
        projectId,
        viewId,
        defaultBucketId: newDefault.id,
      );
    } on Forbidden {
      throw const NewDefaultRefused();
    }
    await _storeView(viewId, answered);
    if (answered.defaultBucketId == newDefault.id) {
      try {
        if (await _stillHas(projectId, viewId, newDefault.id)) {
          await _write.buckets.delete(projectId, viewId, doomed.id);
          return;
        }
      } on Object catch (failure) {
        try {
          await _putDefaultBack(projectId, viewId, oldDefaultId);
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
    try {
      if (answered.defaultBucketId != oldDefaultId) {
        await _putDefaultBack(projectId, viewId, oldDefaultId);
      }
    } finally {
      _settle(projectId, viewId, 'Bucket ${newDefault.id} is gone');
    }
    throw NewDefaultGone(bucket: doomed, newDefault: newDefault);
  }

  Future<void> _putDefaultBack(int projectId, int viewId, int oldDefaultId) =>
      _setBuckets(projectId, viewId, defaultBucketId: oldDefaultId);

  /// From 2.5 on the answer of the view write that stored [bucketId] says
  /// so already.
  Future<bool> _stillHas(int projectId, int viewId, int bucketId) async {
    if (!_storesGoneBuckets || bucketId == 0) return true;
    final board = await _read.buckets.board(projectId, viewId, perPage: 1);
    return board.any((column) => column.bucket.id == bucketId);
  }

  Future<ProjectView> _setBuckets(
    int projectId,
    int viewId, {
    int? doneBucketId,
    int? defaultBucketId,
  }) async {
    final view = await _write.views.setBuckets(
      projectId,
      viewId,
      doneBucketId: doneBucketId,
      defaultBucketId: defaultBucketId,
    );
    await _storeView(viewId, view);
    return view;
  }

  @override
  Future<void> setDoneBucket(int projectId, int viewId, int? bucketId) async {
    final view = await _setBuckets(
      projectId,
      viewId,
      doneBucketId: bucketId ?? 0,
    );
    if (!await _stillHas(projectId, viewId, view.doneBucketId)) {
      await _setBuckets(projectId, viewId, doneBucketId: 0);
    }
    _settle(projectId, viewId, 'Set the done bucket of view $viewId');
  }

  @override
  Future<void> setDefaultBucket(
    int projectId,
    int viewId,
    int? bucketId,
  ) async {
    final view = await _setBuckets(
      projectId,
      viewId,
      defaultBucketId: bucketId ?? 0,
    );
    if (!await _stillHas(projectId, viewId, view.defaultBucketId)) {
      await _setBuckets(projectId, viewId, defaultBucketId: 0);
    }
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

  /// The server replaces title, limit and position at once (decision log:
  /// Kanban), and the stored board may be minutes old: the fields a change
  /// leaves come from the server right before it. Only the buckets' own
  /// rows are stored, as one task per bucket would cut the stored cards.
  Future<List<Bucket>> _freshBuckets(int projectId, int viewId) async {
    final board = await _read.buckets.board(projectId, viewId, perPage: 1);
    final buckets = [for (final column in board) column.bucket];
    await _db.transaction(() async {
      for (final bucket in buckets) {
        await _db.kanbanDao.updateBucket(
          viewId,
          bucket.id,
          title: bucket.title,
          limit: bucket.limit,
          position: bucket.position,
        );
      }
    });
    return buckets;
  }

  Bucket _freshOne(
    List<Bucket> fresh,
    int projectId,
    int viewId,
    int bucketId,
  ) {
    final bucket = fresh.where((bucket) => bucket.id == bucketId).firstOrNull;
    if (bucket != null) return bucket;
    _settle(projectId, viewId, 'Bucket $bucketId is gone');
    throw const NotFound(code: _bucketDoesNotExist);
  }

  /// [toIndex] is in the order the board showed; the bucket goes past the
  /// same column in the server's order, which may have changed since. Null
  /// when the server no longer has that column.
  static int? _pastSameColumn(
    List<Bucket> shown,
    List<Bucket> fresh,
    int bucketId,
    int toIndex,
  ) {
    final before = [...shown]..sort(compareBucketOrder);
    final from = before.indexWhere((bucket) => bucket.id == bucketId);
    final to = toIndex.clamp(0, before.length - 1);
    final passed = before[to].id;
    final others = [
      for (final bucket in [...fresh]..sort(compareBucketOrder))
        if (bucket.id != bucketId) bucket.id,
    ];
    final index = others.indexOf(passed);
    if (index < 0) return null;
    return to < from ? index : index + 1;
  }

  static int _indexIn(List<Bucket> buckets, int bucketId) => ([
    ...buckets,
  ]..sort(compareBucketOrder)).indexWhere((bucket) => bucket.id == bucketId);

  Future<Bucket> _stored(int viewId, int bucketId) async =>
      _find(await _db.kanbanDao.buckets(viewId), bucketId);

  /// A bucket the stored board no longer has went with a download, which
  /// only drops what the server no longer has.
  static Bucket _find(List<Bucket> buckets, int bucketId) =>
      buckets.where((bucket) => bucket.id == bucketId).firstOrNull ??
      (throw const NotFound(code: _bucketDoesNotExist));

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
