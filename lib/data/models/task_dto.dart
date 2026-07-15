import 'package:flutter/material.dart';
import 'package:vikunja_app/data/models/dto.dart';
import 'package:vikunja_app/data/models/label_dto.dart';
import 'package:vikunja_app/data/models/task_attachment_dto.dart';
import 'package:vikunja_app/data/models/task_reminder_dto.dart';
import 'package:vikunja_app/data/models/user_dto.dart';
import 'package:vikunja_app/domain/entities/task.dart';

class TaskDto extends Dto<Task> {
  final int id;
  final int? parentTaskId, priority, bucketId;
  final int? projectId;
  final DateTime created, updated;
  DateTime? dueDate, startDate, endDate;
  final List<TaskReminderDto> reminderDates;
  final String identifier;
  final String title, description;
  final bool done;
  Color? color;
  final double? position;
  final double? percentDone;
  final UserDto? createdBy;
  Duration? repeatAfter;
  final List<TaskDto> subtasks;
  final List<LabelDto> labels;
  final List<TaskAttachmentDto> attachments;

  TaskDto({
    this.id = 0,
    this.identifier = '',
    this.title = '',
    this.description = '',
    this.done = false,
    this.reminderDates = const [],
    this.dueDate,
    this.startDate,
    this.endDate,
    this.parentTaskId,
    this.priority,
    this.repeatAfter,
    this.color,
    this.position,
    this.percentDone,
    this.subtasks = const [],
    this.labels = const [],
    this.attachments = const [],
    DateTime? created,
    DateTime? updated,
    required this.createdBy,
    required this.projectId,
    this.bucketId,
  }) : created = created ?? DateTime.now(),
       updated = updated ?? DateTime.now();

  TaskDto.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      title = json['title'],
      description = json['description'],
      identifier = json['identifier'],
      done = json['done'],
      reminderDates = json['reminders'] != null
          ? (json['reminders'] as List<dynamic>)
                .map((ts) => TaskReminderDto.fromJson(ts))
                .toList()
          : [],
      dueDate = DateTime.parse(json['due_date']),
      startDate = DateTime.parse(json['start_date']),
      endDate = DateTime.parse(json['end_date']),
      parentTaskId = json['parent_task_id'] ?? _extractParentTaskId(json),
      priority = json['priority'],
      repeatAfter = Duration(seconds: json['repeat_after']),
      color = json['hex_color'] != ''
          ? Color(int.parse(json['hex_color'], radix: 16) + 0xFF000000)
          : null,
      position = json['position'] is int
          ? json['position'].toDouble()
          : json['position'],
      percentDone = json['percent_done'] is int
          ? json['percent_done'].toDouble()
          : json['percent_done'],
      labels = json['labels'] != null
          ? (json['labels'] as List<dynamic>)
                .map((label) => LabelDto.fromJson(label))
                .toList()
          : [],
      subtasks = _extractSubtasks(json),
      attachments = json['attachments'] != null
          ? (json['attachments'] as List<dynamic>)
                .map((attachment) => TaskAttachmentDto.fromJSON(attachment))
                .toList()
          : [],
      updated = DateTime.parse(json['updated']),
      created = DateTime.parse(json['created']),
      projectId = json['project_id'],
      bucketId = json['bucket_id'],
      createdBy = json['created_by'] != null
          ? UserDto.fromJson(json['created_by'])
          : null;

  Map<String, Object?> toJSON() => {
    'id': id,
    'title': title,
    'description': description,
    'identifier': identifier.isNotEmpty ? identifier : null,
    'done': done,
    'reminders': reminderDates.map((date) => date.toJSON()).toList(),
    'due_date': dueDate?.toUtc().toIso8601String(),
    'start_date': startDate?.toUtc().toIso8601String(),
    'end_date': endDate?.toUtc().toIso8601String(),
    'priority': priority,
    'repeat_after': repeatAfter?.inSeconds,
    'hex_color': color
        ?.toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2),
    'position': position,
    'percent_done': percentDone,
    'project_id': projectId,
    'labels': labels.map((label) => label.toJSON()).toList(),
    'subtasks': subtasks.map((subtask) => subtask.toJSON()).toList(),
    'attachments': attachments
        .map((attachment) => attachment.toJSON())
        .toList(),
    'bucket_id': bucketId,
    'created_by': createdBy?.toJSON(),
    'updated': updated.toUtc().toIso8601String(),
    'created': created.toUtc().toIso8601String(),
  };

  @override
  Task toDomain() => Task(
    id: id,
    title: title,
    description: description,
    identifier: identifier,
    done: done,
    reminderDates: reminderDates.map((e) => e.toDomain()).toList(),
    dueDate: dueDate,
    startDate: startDate,
    endDate: endDate,
    parentTaskId: parentTaskId,
    priority: priority,
    repeatAfter: repeatAfter,
    color: color,
    position: position,
    percentDone: percentDone,
    labels: labels.map((e) => e.toDomain()).toList(),
    subtasks: subtasks.map((e) => e.toDomain()).toList(),
    attachments: attachments.map((e) => e.toDomain()).toList(),
    updated: updated,
    created: created,
    projectId: projectId,
    bucketId: bucketId,
    createdBy: createdBy?.toDomain(),
  );

  static TaskDto fromDomain(Task b) => TaskDto(
    id: b.id,
    title: b.title,
    description: b.description,
    identifier: b.identifier,
    done: b.done,
    reminderDates: b.reminderDates
        .map((e) => TaskReminderDto.fromDomain(e))
        .toList(),
    dueDate: b.dueDate,
    startDate: b.startDate,
    endDate: b.endDate,
    parentTaskId: b.parentTaskId,
    priority: b.priority,
    repeatAfter: b.repeatAfter,
    color: b.color,
    position: b.position,
    percentDone: b.percentDone,
    labels: b.labels.map((e) => LabelDto.fromDomain(e)).toList(),
    subtasks: b.subtasks.map((e) => TaskDto.fromDomain(e)).toList(),
    attachments: b.attachments
        .map((e) => TaskAttachmentDto.fromDomain(e))
        .toList(),
    updated: b.updated,
    created: b.created,
    projectId: b.projectId,
    bucketId: b.bucketId,
    createdBy: b.createdBy != null ? UserDto.fromDomain(b.createdBy!) : null,
  );

  static int? _extractParentTaskId(Map<String, dynamic> json) {
    final parentTask = json['parent_task_id'];
    if (parentTask != null) return parentTask as int?;
    final related = json['related_tasks'];
    if (related is Map) {
      final parents = related['parenttask'];
      if (parents is List && parents.isNotEmpty) {
        return (parents.first as Map<String, dynamic>)['id'] as int?;
      }
    }
    return null;
  }

  static List<TaskDto> _extractSubtasks(Map<String, dynamic> json) {
    final direct = json['subtasks'];
    if (direct is List) {
      return direct.map((s) => TaskDto.fromJson(s)).toList();
    }
    final related = json['related_tasks'];
    if (related is Map) {
      final subtaskList = related['subtask'];
      if (subtaskList is List) {
        return subtaskList.map((s) => TaskDto.fromJson(s)).toList();
      }
    }
    return [];
  }
}
