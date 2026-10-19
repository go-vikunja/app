import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/account/user.dart';

/// A file attached to a task, as the task read lists it (`file.*` flattened).
@immutable
final class TaskAttachment {
  const new({
    required this.id,
    required this.taskId,
    required this.name,
    this.mime = '',
    this.size = 0,
    this.created,
    this.createdBy,
  });

  final int id;
  final int taskId;
  final String name;

  /// Sniffed by the server from the bytes and may carry a charset, e.g.
  /// `text/plain; charset=utf-8`; empty when unknown.
  final String mime;

  /// Bytes.
  final int size;
  final DateTime? created;
  final User? createdBy;

  @override
  bool operator ==(Object other) =>
      other is TaskAttachment &&
      other.id == id &&
      other.taskId == taskId &&
      other.name == name &&
      other.mime == mime &&
      other.size == size;

  @override
  int get hashCode => Object.hash(id, taskId, name, mime, size);

  @override
  String toString() => 'TaskAttachment($id, $name)';
}
