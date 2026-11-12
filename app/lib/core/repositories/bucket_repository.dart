import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

/// Managing a kanban view's buckets (the board's columns). Online only and
/// never queued: every call goes to the server and throws its
/// `VikunjaFailure` (offline included) with nothing changed here; on
/// success the stored board follows at once and a quiet board download
/// settles counts and placements. A bucket the stored board no longer has
/// is a `NotFound` code 10001 before any request.
abstract interface class BucketRepository {
  /// Rightmost. A blank title (after trimming) is an `ArgumentError`.
  Future<void> create(int projectId, int viewId, String title);

  /// A blank title (after trimming) is an `ArgumentError`.
  Future<void> rename(int projectId, int viewId, int bucketId, String title);

  /// 0 removes the limit; one below the bucket's count is accepted.
  Future<void> setLimit(int projectId, int viewId, int bucketId, int limit);

  /// [toIndex] in the board's order after the move; the bucket gets a
  /// position between its new neighbours. Nothing is sent when it is there
  /// already or no position would put it there ([planBucketMove]).
  Future<void> move(
    int projectId,
    int viewId,
    int bucketId, {
    required int toIndex,
  });

  /// The server moves the bucket's tasks to [planBucketDeletion]'s target,
  /// planned from the view as the server has it right before. When that
  /// plan needs a new default first, it is set before the delete, and when
  /// setting it fails the delete is not sent: a refusal is a
  /// [NewDefaultRefused], and a new default the server no longer has is a
  /// [NewDefaultGone]. When the delete then fails, the old default is put
  /// back; when that fails too, a [DeleteFailedAfterNewDefault] is thrown.
  /// A bucket the tasks would fall back to that looks empty here is checked
  /// with a board download first: tasks created elsewhere since the last
  /// one are only in the server's count.
  Future<void> delete(int projectId, int viewId, int bucketId);

  /// Null clears it. Changes no task's done state.
  Future<void> setDoneBucket(int projectId, int viewId, int? bucketId);

  Future<void> setDefaultBucket(int projectId, int viewId, int? bucketId);
}

/// The server refused the new default a delete needed first, as it does
/// below admin permission; nothing was deleted.
final class NewDefaultRefused implements Exception {
  const new();
}

/// [newDefault], which was to become the view's default before [bucket]'s
/// delete, was deleted elsewhere since the last board download; the server
/// stores a default it does not have as none, so the delete would have
/// left [bucket]'s tasks in no bucket. Nothing was deleted, the old
/// default is back, and the board downloads quietly.
final class NewDefaultGone implements Exception {
  const new({required this.bucket, required this.newDefault});

  final Bucket bucket;
  final Bucket newDefault;
}

/// A delete that failed after [newDefault] had become the view's default
/// bucket for it, and putting the old default back failed too: the
/// default changed for every member.
final class DeleteFailedAfterNewDefault implements Exception {
  const new(this.failure, {required this.bucket, required this.newDefault});

  /// The delete's.
  final Object failure;
  final Bucket bucket;
  final Bucket newDefault;
}

/// Where a deleted bucket's tasks go: `tasksGoTo` is the view's default
/// bucket, or the leftmost remaining one when none is set (or the default
/// is the deleted bucket, which the server then clears).
///
/// `isFallback` marks a server bug: while no other default is set, the
/// server moves the tasks to the leftmost bucket counted before the
/// delete, so deleting the leftmost bucket strands its tasks outside every
/// bucket. `defaultFirst`: such a bucket holds tasks, so `tasksGoTo` must
/// become the default before the delete, a change of the view that needs
/// admin permission.
typedef BucketDeletion = ({
  Bucket tasksGoTo,
  bool isFallback,
  bool defaultFirst,
});

/// [defaultBucketId] is the view's (0: none); [holdsTasks] by
/// [columnHoldsTasks]. Null for the last bucket (the server refuses to
/// delete it) or one that is not in [buckets].
BucketDeletion? planBucketDeletion(
  List<Bucket> buckets,
  int bucketId, {
  required int defaultBucketId,
  required bool holdsTasks,
}) {
  final ordered = [...buckets]..sort(compareBucketOrder);
  final doomed = ordered.where((bucket) => bucket.id == bucketId).firstOrNull;
  if (doomed == null) return null;
  final remaining = [
    for (final bucket in ordered)
      if (bucket.id != bucketId) bucket,
  ];
  if (remaining.isEmpty) return null;
  final keptDefault = remaining
      .where((bucket) => bucket.id == defaultBucketId)
      .firstOrNull;
  if (keptDefault != null) {
    return (tasksGoTo: keptDefault, isFallback: false, defaultFirst: false);
  }
  final isFallback = identical(ordered.first, doomed);
  return (
    tasksGoTo: remaining.first,
    isFallback: isFallback,
    defaultFirst: isFallback && holdsTasks,
  );
}

/// The column holds tasks on the server: it shows some (a task created
/// after the download shows without being counted), or the download
/// counted some (cards moved out here stay until their moves are sent).
bool columnHoldsTasks(BoardColumn column) =>
    column.shownCount > 0 || column.bucket.count > 0;

/// The position that puts the bucket at [toIndex] of the board's order
/// (clamped), between its new neighbours as the web computes it, else
/// below a first neighbour at 0 or less; null when it is there already,
/// not in [buckets], or its new neighbours share a position that its id
/// does not sort between.
double? planBucketMove(List<Bucket> buckets, int bucketId, int toIndex) {
  final ordered = [...buckets]..sort(compareBucketOrder);
  final from = ordered.indexWhere((bucket) => bucket.id == bucketId);
  if (from < 0) return null;
  final to = toIndex.clamp(0, ordered.length - 1);
  if (to == from) return null;
  final moved = ordered.removeAt(from);
  final before = to > 0 ? ordered[to - 1] : null;
  final after = to < ordered.length ? ordered[to] : null;
  bool fits(double position) {
    final placed = _withPosition(moved, position);
    return (before == null || compareBucketOrder(before, placed) < 0) &&
        (after == null || compareBucketOrder(placed, after) < 0);
  }

  final between = calculateItemPosition(before?.position, after?.position);
  if (fits(between)) return between;
  // Halving a first neighbour's position of 0 or less does not go below
  // it, and neighbours sharing a position leave only that one, between
  // them by id.
  final fallback = switch ((before, after)) {
    (null, final after?) => after.position - 65536,
    (final before?, _?) => before.position,
    _ => null,
  };
  return fallback != null && fits(fallback) ? fallback : null;
}

Bucket _withPosition(Bucket bucket, double position) => Bucket(
  id: bucket.id,
  viewId: bucket.viewId,
  title: bucket.title,
  limit: bucket.limit,
  count: bucket.count,
  position: position,
);
