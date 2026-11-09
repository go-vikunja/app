import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/account/user.dart';

/// What the server tells about a trashed item when a request names it
/// (Vikunja 2.8.0 and newer): with code 4040 the task is in the trash, with
/// 3018 its project, or a project above it, is.
@immutable
final class TrashDetails {
  const new({
    required this.id,
    this.deletedAt,
    this.deletedBy,
    this.canRestore = false,
    this.projectId,
    this.trashedRootId,
    this.canRestoreRoot = false,
  });

  /// The task for 4040, the trashed project for 3018.
  final int id;
  final DateTime? deletedAt;

  /// Null when the server names nobody. A link share has a negative id.
  final User? deletedBy;

  /// The user may restore it now: that needs write permission for a task,
  /// admin for a project, and nothing archived above it. False for a
  /// project below a trashed root.
  final bool canRestore;

  /// The task's project; set for 4040 only.
  final int? projectId;

  /// For 3018 below a trashed root: the topmost trashed project, which
  /// brings this one back when it is restored.
  final int? trashedRootId;

  /// For 3018 below a trashed root: the user may restore [trashedRootId].
  final bool canRestoreRoot;

  @override
  bool operator ==(Object other) =>
      other is TrashDetails &&
      other.id == id &&
      other.deletedAt == deletedAt &&
      other.deletedBy == deletedBy &&
      other.canRestore == canRestore &&
      other.projectId == projectId &&
      other.trashedRootId == trashedRootId &&
      other.canRestoreRoot == canRestoreRoot;

  @override
  int get hashCode => Object.hash(
    id,
    deletedAt,
    deletedBy,
    canRestore,
    projectId,
    trashedRootId,
    canRestoreRoot,
  );

  @override
  String toString() => 'TrashDetails($id, canRestore: $canRestore)';
}
