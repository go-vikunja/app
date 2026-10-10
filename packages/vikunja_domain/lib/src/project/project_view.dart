import 'package:meta/meta.dart';

enum ProjectViewKind {
  list('list'),
  gantt('gantt'),
  table('table'),
  kanban('kanban');

  new(this.wireName);

  final String wireName;

  static ProjectViewKind? fromWire(String? name) =>
      values.where((k) => k.wireName == name).firstOrNull;
}

enum BucketConfigurationMode {
  none('none'),
  manual('manual'),
  filter('filter');

  new(this.wireName);

  final String wireName;

  static BucketConfigurationMode fromWire(String? name) =>
      values.where((m) => m.wireName == name).firstOrNull ?? none;
}

/// The filter a view applies server-side on top of every request.
@immutable
final class ViewFilter {
  const new({
    this.filter = '',
    this.search = '',
    this.sortBy = const [],
    this.orderBy = const [],
    this.includeNulls = false,
  });

  final String filter;
  final String search;
  final List<String> sortBy;
  final List<String> orderBy;
  final bool includeNulls;
}

@immutable
final class ProjectView {
  const new({
    required this.id,
    required this.projectId,
    required this.title,
    required this.kind,
    this.position = 0,
    this.filter,
    this.bucketConfigurationMode = BucketConfigurationMode.none,
    this.defaultBucketId = 0,
    this.doneBucketId = 0,
  });

  final int id;
  final int projectId;
  final String title;
  final ProjectViewKind kind;
  final double position;
  final ViewFilter? filter;
  final BucketConfigurationMode bucketConfigurationMode;

  /// 0 when the view has none.
  final int defaultBucketId;
  final int doneBucketId;

  @override
  bool operator ==(Object other) =>
      other is ProjectView && other.id == id && other.projectId == projectId;

  @override
  int get hashCode => Object.hash(id, projectId);

  @override
  String toString() => 'ProjectView($id, ${kind.wireName}, $title)';
}
