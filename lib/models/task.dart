import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:vikunja_app/models/label.dart';
import 'package:vikunja_app/models/user.dart';
import 'package:vikunja_app/models/taskAttachment.dart';
import 'package:vikunja_app/utils/checkboxes_in_text.dart';

@JsonSerializable()
class Task {
  final int id;
  final int? parentTaskId, priority, bucketId;
  //final int? listId;
  final int? projectId;
  final DateTime created, updated;
  DateTime? dueDate, startDate, endDate;
  final List<DateTime> reminderDates;
  final String identifier;
  final String title, description;
  final bool done;
  Color? color;
  final double? kanbanPosition;
  final double? percent_done;
  final User createdBy;
  Duration? repeatAfter;
  final List<Task> subtasks;
  final List<Label> labels;
  final List<TaskAttachment> attachments;
  // TODO: add position(?)

  late final checkboxStatistics = getCheckboxStatistics(description);
  late final hasCheckboxes = checkboxStatistics.total != 0;

  Task({
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
    this.kanbanPosition,
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

  Task.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        title = json['title'],
        description = json['description'],
        identifier = json['identifier'],
        done = json['done'],
        reminderDates = json['reminder_dates'] != null
            ? (json['reminder_dates'] as List<dynamic>)
                .map((ts) => DateTime.parse(ts))
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
        kanbanPosition = json['kanban_position'] is int
            ? json['kanban_position'].toDouble()
            : json['kanban_position'],
        percent_done = json['percent_done'] is int
            ? json['percent_done'].toDouble()
            : json['percent_done'],
        labels = json['labels'] != null
            ? (json['labels'] as List<dynamic>)
                .map((label) => Label.fromJson(label))
                .toList()
            : [],
        subtasks = json['subtasks'] != null
            ? (json['subtasks'] as List<dynamic>)
                .map((subtask) => Task.fromJson(subtask))
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
        'reminder_dates': reminderDates
            .map((date) => date.toUtc().toIso8601String())
            .toList(),
        'due_date': dueDate?.toUtc().toIso8601String(),
        'start_date': startDate?.toUtc().toIso8601String(),
        'end_date': endDate?.toUtc().toIso8601String(),
        'priority': priority,
        'repeat_after': repeatAfter?.inSeconds,
        'hex_color':
            color?.value.toRadixString(16).padLeft(8, '0').substring(2),
        'kanban_position': kanbanPosition,
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

  Task copyWith({
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
    List<DateTime>? reminderDates,
    String? title,
    String? description,
    String? identifier,
    bool? done,
    Color? color,
    double? kanbanPosition,
    double? percent_done,
    User? createdBy,
    Duration? repeatAfter,
    List<Task>? subtasks,
    List<Label>? labels,
    List<TaskAttachment>? attachments,
  }) {
    return Task(
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
      kanbanPosition: kanbanPosition ?? this.kanbanPosition,
      percent_done: percent_done ?? this.percent_done,
      createdBy: createdBy ?? this.createdBy,
      repeatAfter: repeatAfter ?? this.repeatAfter,
      subtasks: subtasks ?? this.subtasks,
      labels: labels ?? this.labels,
      attachments: attachments ?? this.attachments,
    );
  }
}
