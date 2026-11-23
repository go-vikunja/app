import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/project/project_view.dart';

/// The fields of a project view the app creates or edits. On an update a
/// null [bucketConfigurationMode] or [position] is left as it is, and so is
/// every field in [unchanged]; the title, the kind and the filter are sent
/// otherwise, a null filter clearing the view's.
@immutable
final class ViewDraft {
  const new({
    required this.title,
    required this.kind,
    this.filter,
    this.bucketConfigurationMode,
    this.position,
    this.unchanged = const {},
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

  /// Ignored by a create.
  final Set<ViewDraftField> unchanged;

  /// This draft as an update of [view], read before it was edited: what it
  /// left as it was stays as the server has it, so that a change made
  /// elsewhere since survives.
  ViewDraft changedFrom(ProjectView view) => ViewDraft(
    title: title,
    kind: kind,
    filter: filter,
    bucketConfigurationMode: bucketConfigurationMode,
    position: position,
    unchanged: {
      if (title.trim() == view.title.trim()) ViewDraftField.title,
      if (kind == view.kind) ViewDraftField.kind,
      if (filter == view.filter) ViewDraftField.filter,
      if (bucketConfigurationMode == view.bucketConfigurationMode)
        ViewDraftField.bucketConfigurationMode,
    },
  );

  @override
  bool operator ==(Object other) =>
      other is ViewDraft &&
      other.title == title &&
      other.kind == kind &&
      other.filter == filter &&
      other.bucketConfigurationMode == bucketConfigurationMode &&
      other.position == position &&
      other.unchanged.length == unchanged.length &&
      other.unchanged.containsAll(unchanged);

  @override
  int get hashCode => Object.hash(
    title,
    kind,
    filter,
    bucketConfigurationMode,
    position,
    Object.hashAllUnordered(unchanged),
  );

  /// Without the title and the filter, which are user text.
  @override
  String toString() {
    final fields = [
      kind.wireName,
      if (filter != null) 'filter',
      if (bucketConfigurationMode case final mode?) 'mode: ${mode.wireName}',
      if (position != null) 'position: $position',
      if (unchanged.isNotEmpty)
        'unchanged: ${unchanged.map((field) => field.name).join('/')}',
    ];
    return 'ViewDraft(${fields.join(', ')})';
  }
}

enum ViewDraftField { title, kind, filter, bucketConfigurationMode }
