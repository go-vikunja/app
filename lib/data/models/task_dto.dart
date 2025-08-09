import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:vikunja_app/data/models/label_dto.dart';
import 'package:vikunja_app/data/models/user.dart';
import 'package:vikunja_app/data/models/taskAttachment.dart';
import 'package:vikunja_app/core/utils/checkboxes_in_text.dart';
import 'package:vikunja_app/domain/entities/task.dart';

class TaskReminderDto {
  final int relative_period;
  final String relative_to;
  DateTime reminder;

  TaskReminderDto(this.reminder, [relative_period = 0, relative_to = ""])
      : relative_period = relative_period,
        relative_to = relative_to;

  TaskReminderDto.fromJson(Map<String, dynamic> json)
      : reminder = DateTime.parse(json['reminder']),
        relative_period = json['relative_period'],
        relative_to = json['relative_to'];

  toJSON() => {
        'relative_period': relative_period,
        'relative_to': relative_to,
        'reminder': reminder.toUtc().toIso8601String(),
      };

  TaskReminder toDomain() =>
      TaskReminder(reminder, relative_period, relative_to);

  static TaskReminderDto fromDomain(TaskReminder b) =>
      TaskReminderDto(b.reminder, b.relative_period, b.relative_to);
}

@JsonSerializable()
class TaskDto {
  final int id;
  final int? parentTaskId, priority, bucketId;
  //final int? listId;
  final int? projectId;
  final DateTime created, updated;
  DateTime? dueDate, startDate, endDate;
  final List<TaskReminderDto> reminderDates;
  final String identifier;
  final String title, description;
  final bool done;
  Color? color;
  final double? position;
  final double? percent_done;
  final User createdBy;
  Duration? repeatAfter;
  final List<TaskDto> subtasks;
  final List<LabelDto> labels;
  final List<TaskAttachment> attachments;
  // TODO: add position(?)

  late final checkboxStatistics = getCheckboxStatistics(description);
  late final hasCheckboxes = checkboxStatistics.total != 0;

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
    this.percent_done,
    this.subtasks = const [],
    this.labels = const [],
    this.attachments = const [],
    DateTime? created,
    DateTime? updated,
    required this.createdBy,
    //required this.listId,
    required this.projectId,
    this.bucketId,
  })  : this.created = created ?? DateTime.now(),
        this.updated = updated ?? DateTime.now();

  bool loading = false;

  Color get textColor {
    if (color != null && color!.computeLuminance() > 0.5) {
      return Colors.black;
    }
    return Colors.white;
  }

  bool get hasDueDate => dueDate?.year != 1;
  bool get hasStartDate => startDate?.year != 1;
  bool get hasEndDate => endDate?.year != 1;

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
        parentTaskId = json['parent_task_id'],
        priority = json['priority'],
        repeatAfter = Duration(seconds: json['repeat_after']),
        color = json['hex_color'] != ''
            ? Color(int.parse(json['hex_color'], radix: 16) + 0xFF000000)
            : null,
        position = json['position'] is int
            ? json['position'].toDouble()
            : json['position'],
        percent_done = json['percent_done'] is int
            ? json['percent_done'].toDouble()
            : json['percent_done'],
        labels = json['labels'] != null
            ? (json['labels'] as List<dynamic>)
                .map((label) => LabelDto.fromJson(label))
                .toList()
            : [],
        subtasks = json['subtasks'] != null
            ? (json['subtasks'] as List<dynamic>)
                .map((subtask) => TaskDto.fromJson(subtask))
                .toList()
            : [],
        attachments = json['attachments'] != null
            ? (json['attachments'] as List<dynamic>)
                .map((attachment) => TaskAttachment.fromJSON(attachment))
                .toList()
            : [],
        updated = DateTime.parse(json['updated']),
        created = DateTime.parse(json['created']),
        //listId = json['list_id'],
        projectId = json['project_id'],
        bucketId = json['bucket_id'],
        createdBy = User.fromJson(json['created_by']);

  toJSON() => {
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
        'hex_color':
            color?.toARGB32().toRadixString(16).padLeft(8, '0').substring(2),
        'position': position,
        'percent_done': percent_done,
        'project_id': projectId,
        'labels': labels.map((label) => label.toJSON()).toList(),
        'subtasks': subtasks.map((subtask) => subtask.toJSON()).toList(),
        'attachments':
            attachments.map((attachment) => attachment.toJSON()).toList(),
        'bucket_id': bucketId,
        'created_by': createdBy.toJSON(),
        'updated': updated.toUtc().toIso8601String(),
        'created': created.toUtc().toIso8601String(),
      };

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
        percent_done: percent_done,
        labels: labels.map((e) => e.toDomain()).toList(),
        subtasks: subtasks.map((e) => e.toDomain()).toList(),
        attachments: attachments,
        updated: updated,
        created: created,
        projectId: projectId,
        bucketId: bucketId,
        createdBy: createdBy,
      );

  static TaskDto fromDomain(Task b) => TaskDto(
        id: b.id,
        title: b.title,
        description: b.description,
        identifier: b.identifier,
        done: b.done,
        reminderDates:
            b.reminderDates.map((e) => TaskReminderDto.fromDomain(e)).toList(),
        dueDate: b.dueDate,
        startDate: b.startDate,
        endDate: b.endDate,
        parentTaskId: b.parentTaskId,
        priority: b.priority,
        repeatAfter: b.repeatAfter,
        color: b.color,
        position: b.position,
        percent_done: b.percent_done,
        labels: b.labels.map((e) => LabelDto.fromDomain(e)).toList(),
        subtasks: b.subtasks.map((e) => TaskDto.fromDomain(e)).toList(),
        attachments: b.attachments,
        updated: b.updated,
        created: b.created,
        projectId: b.projectId,
        bucketId: b.bucketId,
        createdBy: b.createdBy,
      );

  TaskDto copyWith({
    int? id,
    int? parentTaskId,
    int? priority,
    int? listId,
    int? bucketId,
    DateTime? created,
    DateTime? updated,
    DateTime? dueDate,
    DateTime? startDate,
    DateTime? endDate,
    List<TaskReminderDto>? reminderDates,
    String? title,
    String? description,
    String? identifier,
    bool? done,
    Color? color,
    double? position,
    double? percent_done,
    User? createdBy,
    Duration? repeatAfter,
    List<TaskDto>? subtasks,
    List<LabelDto>? labels,
    List<TaskAttachment>? attachments,
  }) {
    return TaskDto(
      id: id ?? this.id,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      priority: priority ?? this.priority,
      //listId: listId ?? this.listId,
      projectId: projectId ?? this.projectId,
      bucketId: bucketId ?? this.bucketId,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      dueDate: dueDate ?? this.dueDate,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reminderDates: reminderDates ?? this.reminderDates,
      title: title ?? this.title,
      description: description ?? this.description,
      identifier: identifier ?? this.identifier,
      done: done ?? this.done,
      color: color ?? this.color,
      position: position ?? this.position,
      percent_done: percent_done ?? this.percent_done,
      createdBy: createdBy ?? this.createdBy,
      repeatAfter: repeatAfter ?? this.repeatAfter,
      subtasks: subtasks ?? this.subtasks,
      labels: labels ?? this.labels,
      attachments: attachments ?? this.attachments,
    );
  }
}
