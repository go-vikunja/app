import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/account/user.dart';
import 'package:vikunja_domain/src/project/project.dart';
import 'package:vikunja_domain/src/task/task.dart';

/// A task in the server's trash (Vikunja 2.8.0 and newer).
@immutable
final class TrashedTask {
  const new({
    required this.task,
    required this.deletedAt,
    this.deletedBy,
    this.canDeletePermanently = false,
  });

  /// As listed; its bucket and position mean nothing.
  final Task task;

  /// UTC, to the second. The server deletes it for good 30 days later.
  final DateTime deletedAt;

  /// Null when the server names nobody. A link share has a negative id.
  final User? deletedBy;

  /// The user is admin of the task's project.
  final bool canDeletePermanently;

  @override
  bool operator ==(Object other) =>
      other is TrashedTask &&
      other.task == task &&
      other.deletedAt == deletedAt &&
      other.deletedBy == deletedBy &&
      other.canDeletePermanently == canDeletePermanently;

  @override
  int get hashCode =>
      Object.hash(task, deletedAt, deletedBy, canDeletePermanently);

  @override
  String toString() => 'TrashedTask(${task.id})';
}

/// A subproject that went into the trash with, or before, the listed
/// project.
@immutable
final class TrashedSubproject {
  const new({
    required this.id,
    required this.title,
    required this.parentProjectId,
    required this.depth,
  });

  final int id;
  final String title;
  final int parentProjectId;

  /// 1 for a child of the listed project.
  final int depth;

  @override
  bool operator ==(Object other) =>
      other is TrashedSubproject &&
      other.id == id &&
      other.title == title &&
      other.parentProjectId == parentProjectId &&
      other.depth == depth;

  @override
  int get hashCode => Object.hash(id, title, parentProjectId, depth);

  /// Without the title, which is user text.
  @override
  String toString() => 'TrashedSubproject($id, depth: $depth)';
}

/// The topmost project of a trashed subtree; only its admins see it.
@immutable
final class TrashedProject {
  const new({
    required this.project,
    required this.deletedAt,
    this.deletedBy,
    this.subprojects = const [],
  });

  /// Without views and permission; the list sends neither.
  final Project project;

  /// UTC, to the second. The server deletes it for good 30 days later.
  final DateTime deletedAt;

  /// Null when the server names nobody. A link share has a negative id.
  final User? deletedBy;

  /// Shallowest first; they come back with it on restore.
  final List<TrashedSubproject> subprojects;

  @override
  bool operator ==(Object other) =>
      other is TrashedProject &&
      other.project == project &&
      other.deletedAt == deletedAt &&
      other.deletedBy == deletedBy &&
      _sameSubprojects(other.subprojects, subprojects);

  @override
  int get hashCode =>
      Object.hash(project, deletedAt, deletedBy, Object.hashAll(subprojects));

  @override
  String toString() =>
      'TrashedProject(${project.id}, ${subprojects.length} subprojects)';

  static bool _sameSubprojects(
    List<TrashedSubproject> a,
    List<TrashedSubproject> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// What emptying one side of the trash would delete for good.
@immutable
final class TrashCount {
  const new({required this.total, required this.byOthers});

  /// Only items in projects the user is admin of: a user with write
  /// permission alone gets 0.
  final int total;

  /// How many of [total] someone else, or nobody known, moved there.
  final int byOthers;

  @override
  bool operator ==(Object other) =>
      other is TrashCount && other.total == total && other.byOthers == byOthers;

  @override
  int get hashCode => Object.hash(total, byOthers);

  @override
  String toString() => 'TrashCount($total, byOthers: $byOthers)';
}
