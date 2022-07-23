import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:vikunja_app/components/date_extension.dart';

import 'package:vikunja_app/models/label.dart';
import 'package:vikunja_app/models/user.dart';
import 'package:vikunja_app/models/taskAttachment.dart';

@JsonSerializable()
class Task {
  int id, parentTaskId, priority, listId, bucketId;
  DateTime created, updated, dueDate, startDate, endDate;
  List<DateTime> reminderDates;
  String title, description;
  bool done;
  Color color;
  User createdBy;
  Duration repeatAfter;
  List<Task> subtasks;
  List<Label> labels;
  List<TaskAttachment> attachments;
  bool loading = false;
  // TODO: add kanbanPosition, position(?)

  Task(
      {@required this.id,
      this.title,
      this.description,
      this.done = false,
      this.reminderDates,
      this.dueDate,
      this.startDate,
      this.endDate,
      this.parentTaskId,
      this.priority,
      this.repeatAfter,
      this.color,
      this.subtasks,
      this.labels,
      this.attachments,
      this.created,
      this.updated,
      this.createdBy,
      this.listId,
      this.bucketId});

  Task.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        title = json['title'],
        description = json['description'],
        done = json['done'],
        reminderDates = (json['reminder_dates'] as List<dynamic>)
            ?.map((ts) => DateTime.parse(ts))
            ?.cast<DateTime>()
            ?.toList(),
        dueDate = DateTime.parse(json['due_date']),
        startDate = DateTime.parse(json['start_date']),
        endDate = DateTime.parse(json['end_date']),
        parentTaskId = json['parent_task_id'],
        priority = json['priority'],
        repeatAfter = Duration(seconds: json['repeat_after']),
        color = json['hex_color'] == ''
            ? null
            : new Color(int.parse(json['hex_color'], radix: 16) + 0xFF000000),
        labels = (json['labels'] as List<dynamic>)
            ?.map((label) => Label.fromJson(label))
            ?.cast<Label>()
            ?.toList(),
        subtasks = (json['subtasks'] as List<dynamic>)
            ?.map((subtask) => Task.fromJson(subtask))
            ?.cast<Task>()
            ?.toList(),
        attachments = (json['attachments'] as List<dynamic>)
            ?.map((attachment) => TaskAttachment.fromJSON(attachment))
            ?.cast<TaskAttachment>()
            ?.toList(),
        updated = DateTime.parse(json['updated']),
        created = DateTime.parse(json['created']),
        listId = json['list_id'],
        bucketId = json['bucket_id'],
        createdBy = json['created_by'] == null
            ? null
            : User.fromJson(json['created_by']);

  toJSON() => {
        'id': id,
        'title': title,
        'description': description,
        'done': done ?? false,
        'reminder_dates':
            reminderDates?.map((date) => date?.toUtc()?.toIso8601String())?.toList(),
        'due_date': dueDate?.toUtc()?.toIso8601String(),
        'start_date': startDate?.toUtc()?.toIso8601String(),
        'end_date': endDate?.toUtc()?.toIso8601String(),
        'priority': priority,
        'repeat_after': repeatAfter?.inSeconds,
        'hex_color': color?.value?.toRadixString(16)?.padLeft(8, '0')?.substring(2),
        'labels': labels?.map((label) => label.toJSON())?.toList(),
        'subtasks': subtasks?.map((subtask) => subtask.toJSON())?.toList(),
        'attachments': attachments?.map((attachment) => attachment.toJSON())?.toList(),
        'bucket_id': bucketId,
        'created_by': createdBy?.toJSON(),
        'updated': updated?.toUtc()?.toIso8601String(),
        'created': created?.toUtc()?.toIso8601String(),
      };

  Color get textColor => color != null
      ? color.computeLuminance() > 0.5 ? Colors.black : Colors.white
      : null;
}
