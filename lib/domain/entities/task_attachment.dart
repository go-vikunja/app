import 'package:json_annotation/json_annotation.dart';

import 'package:vikunja_app/domain/entities/user.dart';

class TaskAttachmentFile {
  final int id;
  final DateTime created;
  final String mime;
  final String name;
  final int size;

  TaskAttachmentFile({
    required this.id,
    required this.created,
    required this.mime,
    required this.name,
    required this.size,
  });
}

@JsonSerializable()
class TaskAttachment {
  final int id, taskId;
  final DateTime created;
  final User createdBy;
  final TaskAttachmentFile file;
  // TODO: add file

  TaskAttachment({
    this.id = 0,
    required this.taskId,
    DateTime? created,
    required this.createdBy,
    required this.file,
  }) : this.created = created ?? DateTime.now();
}
