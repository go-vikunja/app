import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/project/project_view.dart';

/// The fields of a project view the app creates or edits. On an update the
/// title, the kind and the filter are always sent; a null
/// [bucketConfigurationMode] or [position] is left as it is.
@immutable
final class ViewDraft {
  const new({
    required this.title,
    required this.kind,
    this.filter,
    this.bucketConfigurationMode,
    this.position,
  });

  /// 1 to 250 characters.
  final String title;
  final ProjectViewKind kind;

  /// Null for none: the view shows every task, done ones included.
  final ViewFilter? filter;

  /// Kanban only; the server stores `none` for the other kinds. A new board
  /// without one, or with `none`, becomes manual with To-Do, Doing and Done.
  final BucketConfigurationMode? bucketConfigurationMode;

  /// Any value, never renumbered; a new view without one goes to
  /// id × 65536.
  final double? position;

  @override
  bool operator ==(Object other) =>
      other is ViewDraft &&
      other.title == title &&
      other.kind == kind &&
      other.filter == filter &&
      other.bucketConfigurationMode == bucketConfigurationMode &&
      other.position == position;

  @override
  int get hashCode =>
      Object.hash(title, kind, filter, bucketConfigurationMode, position);

  /// Without the title and the filter, which are user text.
  @override
  String toString() {
    final fields = [
      kind.wireName,
      if (filter != null) 'filter',
      if (bucketConfigurationMode case final mode?) 'mode: ${mode.wireName}',
      if (position != null) 'position: $position',
    ];
    return 'ViewDraft(${fields.join(', ')})';
  }
}
