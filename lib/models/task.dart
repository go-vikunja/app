import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:vikunja_app/models/label.dart';
import 'package:vikunja_app/models/user.dart';
import 'package:vikunja_app/utils/datetime_to_unix.dart';

@JsonSerializable()
class Task {
  final int id, parentTaskId, priority;
  final DateTime created, updated, dueDate, startDate, endDate;
  final List<DateTime> reminderDates;
  final String title, description;
  final bool done;
  final User createdBy;
  final Duration repeatAfter;
  final List<Task> subtasks;
  final List<Label> labels;

  Task(
      {@required this.id,
      this.title,
      this.description,
      this.done,
      this.reminderDates,
      this.dueDate,
      this.startDate,
      this.endDate,
      this.parentTaskId,
      this.priority,
      this.repeatAfter,
      this.subtasks,
      this.labels,
      this.created,
      this.updated,
      this.createdBy});

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
        labels = (json['labels'] as List<dynamic>)
            ?.map((label) => Label.fromJson(label))
            ?.cast<Label>()
            ?.toList(),
        subtasks = (json['subtasks'] as List<dynamic>)
            ?.map((subtask) => Task.fromJson(subtask))
            ?.cast<Task>()
            ?.toList(),
        updated = DateTime.parse(json['updated']),
        created = DateTime.parse(json['created']),
        createdBy = User.fromJson(json['created_by']);

  toJSON() => {
        'id': id,
        'title': title,
        'description': description,
        'done': done ?? false,
        'reminderDates': reminderDates
            ?.map((date) => datetimeToUnixTimestamp(date))
            ?.toList(),
        'dueDate': datetimeToUnixTimestamp(dueDate),
        'startDate': datetimeToUnixTimestamp(startDate),
        'endDate': datetimeToUnixTimestamp(endDate),
        'priority': priority,
        'repeatAfter': repeatAfter?.inSeconds,
        'labels': labels?.map((label) => label.toJSON())?.toList(),
        'subtasks': subtasks?.map((subtask) => subtask.toJSON())?.toList(),
        'createdBy': createdBy?.toJSON(),
        'updated': datetimeToUnixTimestamp(updated),
        'created': datetimeToUnixTimestamp(created),
      };
}
