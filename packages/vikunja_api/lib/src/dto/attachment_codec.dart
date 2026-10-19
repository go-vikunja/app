import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/user_codec.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// An entry of a task's `attachments`: `{id, task_id, created_by, file:
/// {id, name, mime, size, created}, created}`. Null without an id.
TaskAttachment? parseTaskAttachment(Object? json, {required int taskId}) {
  if (json case {'id': final int id}) {
    final map = objectOf(json, 'attachment');
    final file = switch (map['file']) {
      final Map<String, Object?> file => file,
      _ => const <String, Object?>{},
    };
    return TaskAttachment(
      id: id,
      taskId: intOr(map, 'task_id', taskId),
      name: stringOr(file, 'name', ''),
      mime: stringOr(file, 'mime', ''),
      size: intOr(file, 'size', 0),
      created: dateOf(map['created']) ?? dateOf(file['created']),
      createdBy: parseUser(map['created_by']),
    );
  }
  return null;
}
