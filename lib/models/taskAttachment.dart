import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:vikunja_app/models/user.dart';

@JsonSerializable()
class TaskAttachment {
  int id, taskId;
  DateTime? created;
  User? createdBy;
  // TODO: add file

  TaskAttachment({
    required this.id,
    required this.taskId,
    this.created,
    this.createdBy,
  });

  TaskAttachment.fromJSON(Map<String, dynamic> json)
      : id = json['id'],
        taskId = json['task_id'],
        created = DateTime.parse(json['created']),
        createdBy = json['created_by'] == null
            ? null
            : User.fromJson(json['created_by']);

  toJSON() => {
    'id': id,
    'task_id': taskId,
    'created': created?.toUtc()?.toIso8601String(),
    'created_by': createdBy?.toJSON(),
  };
}