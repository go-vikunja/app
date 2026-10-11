import 'package:meta/meta.dart';

/// Ids to add to and remove from a set the server holds, such as a task's
/// labels or assignees. Only the difference travels, so members someone
/// else added or removed meanwhile keep their state.
@immutable
final class IdSetChange {
  const new({this.added = const {}, this.removed = const {}});

  final Set<int> added;
  final Set<int> removed;

  bool get isEmpty => added.isEmpty && removed.isEmpty;

  /// [later] wins for an id both touch.
  IdSetChange merge(IdSetChange later) => IdSetChange(
    added: {...added.difference(later.removed), ...later.added},
    removed: {...removed.difference(later.added), ...later.removed},
  );

  /// [current] with this change applied.
  Set<int> applyTo(Iterable<int> current) => {
    for (final id in current)
      if (!removed.contains(id)) id,
    ...added,
  };

  @override
  bool operator ==(Object other) =>
      other is IdSetChange &&
      _sameSet(other.added, added) &&
      _sameSet(other.removed, removed);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(added),
    Object.hashAllUnordered(removed),
  );

  @override
  String toString() => 'IdSetChange(+$added, -$removed)';

  static bool _sameSet(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);
}
