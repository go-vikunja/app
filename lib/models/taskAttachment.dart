import 'package:json_annotation/json_annotation.dart';

import 'package:vikunja_app/models/user.dart';

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

  TaskAttachmentFile.fromJSON(Map<String, dynamic> json)
      : id = json['id'],
        created = DateTime.parse(json['created']),
        mime = json['mime'],
        name = json['name'],
        size = json['size'];

  toJSON() => {
    'id': id,
    'created': created.toUtc().toIso8601String(),
    'mime': mime,
    'name': name,
    'size': size,
  };
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

  TaskAttachment.fromJSON(Map<String, dynamic> json)
      : id = json['id'],
        taskId = json['task_id'],
        created = DateTime.parse(json['created']),
        file = TaskAttachmentFile.fromJSON(json['file']),
        createdBy = User.fromJson(json['created_by']);

  toJSON() => {
    'id': id,
    'task_id': taskId,
    'created': created.toUtc().toIso8601String(),
    'created_by': createdBy.toJSON(),
    'file': file.toJSON(),
  };
}