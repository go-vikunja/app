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

class TaskAttachment {
  final int id, taskId;
  final DateTime created;
  final User createdBy;
  final TaskAttachmentFile file;

  TaskAttachment({
    this.id = 0,
    required this.taskId,
    DateTime? created,
    required this.createdBy,
    required this.file,
  }) : this.created = created ?? DateTime.now();
}
