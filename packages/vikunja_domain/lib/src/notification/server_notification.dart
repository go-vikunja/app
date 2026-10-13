import 'package:meta/meta.dart';

/// One of the server's in-app notifications (`GET /notifications`): a
/// comment, an assignment, a mention, a task created or deleted in a
/// shared project, a project created, a team membership, or the server's
/// own reminder. [payload] is the server's `notification` object as sent;
/// the typed getters read the fields every kind shares.
@immutable
final class ServerNotification {
  const new({
    required this.id,
    required this.name,
    required this.payload,
    required this.created,
    this.readAt,
  });

  final int id;

  /// `task.comment`, `task.assigned`, `task.mentioned`, `task.created`,
  /// `task.deleted`, `task.reminder`, `project.created`,
  /// `team.member.added`, or a kind this client does not know.
  final String name;
  final Map<String, Object?> payload;
  final DateTime created;

  /// Null while unread.
  final DateTime? readAt;

  bool get isRead => readAt != null;

  int? get taskId => switch (payload['task']) {
    {'id': final int id} => id,
    _ => null,
  };

  int? get projectId => switch (payload['project']) {
    {'id': final int id} => id,
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is ServerNotification &&
      other.id == id &&
      other.name == name &&
      other.created == created &&
      other.readAt == readAt;

  @override
  int get hashCode => Object.hash(id, name, created, readAt);
}
