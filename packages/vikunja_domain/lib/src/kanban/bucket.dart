import 'package:meta/meta.dart';

/// A column of a kanban view. In a filter-mode view the ids are the
/// indexes of the view's bucket configuration, not database ids.
@immutable
final class Bucket {
  const new({
    required this.id,
    required this.viewId,
    required this.title,
    required this.position,
    this.limit = 0,
    this.count = 0,
  });

  final int id;
  final int viewId;

  /// As the server names it; the web does not translate bucket titles.
  final String title;

  /// 0 for no limit.
  final int limit;

  /// The server's total of tasks in the bucket, not only the loaded ones.
  final int count;
  final double position;

  bool get isFull => limit > 0 && count >= limit;

  @override
  bool operator ==(Object other) =>
      other is Bucket &&
      other.id == id &&
      other.viewId == viewId &&
      other.title == title &&
      other.limit == limit &&
      other.count == count &&
      other.position == position;

  @override
  int get hashCode => Object.hash(id, viewId, title, limit, count, position);

  @override
  String toString() =>
      'Bucket($id, view $viewId, count $count, limit $limit, at $position)';
}
