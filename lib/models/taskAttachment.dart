import 'package:json_annotation/json_annotation.dart';

import 'package:vikunja_app/models/user.dart';

@JsonSerializable()
class TaskAttachment {
  final int id, taskId;
  late final DateTime created;
  final User createdBy;
  // TODO: add file

  TaskAttachment({
    this.id = -1,
    required this.taskId,
    DateTime? created,
    required this.createdBy,
  }) {
    this.created = created ?? DateTime.now();
  }

  TaskAttachment.fromJSON(Map<String, dynamic> json)
      : id = json['id'],
        taskId = json['task_id'],
        created = DateTime.parse(json['created']),
        createdBy = User.fromJson(json['created_by']);

  toJSON() => {
    'id': id != -1 ? id : null,
    'task_id': taskId,
    'created': created.toUtc().toIso8601String(),
    'created_by': createdBy.toJSON(),
  };
}