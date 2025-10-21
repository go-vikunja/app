import 'package:flutter/material.dart';
import 'package:vikunja_app/domain/entities/label.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/task_attachment.dart';
import 'package:vikunja_app/domain/entities/task_reminder.dart';
import 'package:vikunja_app/domain/entities/user.dart';

class Task {
  int id;
  int? parentTaskId, priority, bucketId;
  int? projectId;
  Project? project;
  DateTime created, updated;
  DateTime? dueDate, startDate, endDate;
  List<TaskReminder> reminderDates;
  String identifier;
  String title, description;
  bool done;
  Color? color;
  double? position;
  double? percentDone;
  User createdBy;
  Duration? repeatAfter;
  List<Task> subtasks;
  List<Label> labels;
  List<TaskAttachment> attachments;

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

  bool loading = false;

  Color get textColor {
    if (color != null && color!.computeLuminance() > 0.5) {
      return Colors.black;
    }
    return Colors.white;
  }

  bool get hasDueDate => dueDate != null && dueDate?.year != 1;

  bool get hasStartDate => startDate != null && startDate?.year != 1;

  bool get hasEndDate => endDate != null && endDate?.year != 1;

  Task copyWith({
    int? id,
    int? parentTaskId,
    int? priority,
    int? listId,
    int? projectId,
    int? bucketId,
    DateTime? created,
    DateTime? updated,
    DateTime? dueDate,
    DateTime? startDate,
    DateTime? endDate,
    List<TaskReminder>? reminderDates,
    String? title,
    String? description,
    String? identifier,
    bool? done,
    Color? color,
    double? position,
    double? percentDone,
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
      percentDone: percentDone ?? this.percentDone,
      createdBy: createdBy ?? this.createdBy,
      repeatAfter: repeatAfter ?? this.repeatAfter,
      subtasks: subtasks ?? this.subtasks,
      labels: labels ?? this.labels,
      attachments: attachments ?? this.attachments,
    );
  }
}
