import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

/// Managing a project's views. Online only and never queued: every call goes
/// to the server (project admin permission, a `Forbidden` otherwise; allowed
/// on archived projects) and throws its `VikunjaFailure`, offline included,
/// with nothing changed here; on success the stored project's views follow
/// at once and a sync runs quietly. A view the stored project no longer has
/// is a `NotFound` code 3014 before any request.
abstract interface class ProjectViewRepository {
  /// Returns the new view's id. Without a position the view goes last. A
  /// blank title (after trimming) is an `ArgumentError`; a filter the
  /// server refuses a `DomainError` code 4024, 4019 or 4016.
  Future<int> createView(int projectId, ViewDraft view);

  /// Fails like [createView].
  Future<void> updateView(int projectId, int viewId, ViewDraft view);

  /// [toIndex] in the project's view order after the move ([sortedViews]);
  /// the view gets a position between its new neighbours. Nothing is sent
  /// when it is there already or no position would put it there
  /// ([planViewMove]).
  Future<void> moveView(int projectId, int viewId, {required int toIndex});

  /// The project's only view is a [LastViewNotDeletable] before any
  /// request: the server would delete it, and the project would open on
  /// nothing.
  Future<void> deleteView(int projectId, int viewId);
}

final class LastViewNotDeletable implements Exception {
  const new();
}

/// By position, then id: the server orders by position alone.
List<ProjectView> sortedViews(Iterable<ProjectView> views) =>
    [...views]..sort(_compareViews);

int _compareViews(ProjectView a, ProjectView b) {
  final byPosition = a.position.compareTo(b.position);
  return byPosition != 0 ? byPosition : a.id.compareTo(b.id);
}

/// The position that puts the view at [toIndex] of [sortedViews] (clamped),
/// between its new neighbours as the web computes it, else below a first
/// neighbour at 0 or less; null when it is there already, not in [views],
/// or its new neighbours share a position that its id does not sort
/// between.
double? planViewMove(List<ProjectView> views, int viewId, int toIndex) {
  final ordered = sortedViews(views);
  final from = ordered.indexWhere((view) => view.id == viewId);
  if (from < 0) return null;
  final to = toIndex.clamp(0, ordered.length - 1);
  if (to == from) return null;
  final moved = ordered.removeAt(from);
  final before = to > 0 ? ordered[to - 1] : null;
  final after = to < ordered.length ? ordered[to] : null;
  bool fits(double position) {
    final placed = viewAt(moved, position);
    return (before == null || _compareViews(before, placed) < 0) &&
        (after == null || _compareViews(placed, after) < 0);
  }

  final between = calculateItemPosition(before?.position, after?.position);
  if (fits(between)) return between;
  // Halving a first neighbour's position of 0 or less does not go below it,
  // and neighbours sharing a position leave only that one, between them by
  // id.
  final fallback = switch ((before, after)) {
    (null, final after?) => after.position - 65536,
    (final before?, _?) => before.position,
    _ => null,
  };
  return fallback != null && fits(fallback) ? fallback : null;
}

/// [view] at [position], everything else kept.
ProjectView viewAt(ProjectView view, double position) => ProjectView(
  id: view.id,
  projectId: view.projectId,
  title: view.title,
  kind: view.kind,
  position: position,
  filter: view.filter,
  bucketConfigurationMode: view.bucketConfigurationMode,
  defaultBucketId: view.defaultBucketId,
  doneBucketId: view.doneBucketId,
);
