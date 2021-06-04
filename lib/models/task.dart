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
        reminderDates = (json['reminderDates'] as List<dynamic>)
            ?.map((ts) => dateTimeFromUnixTimestamp(ts))
            ?.cast<DateTime>()
            ?.toList(),
        dueDate = dateTimeFromUnixTimestamp(json['dueDate']),
        startDate = dateTimeFromUnixTimestamp(json['startDate']),
        endDate = dateTimeFromUnixTimestamp(json['endDate']),
        parentTaskId = json['parentTaskID'],
        priority = json['priority'],
        repeatAfter = Duration(seconds: json['repeatAfter']),
        labels = (json['labels'] as List<dynamic>)
            ?.map((label) => Label.fromJson(label))
            ?.cast<Label>()
            ?.toList(),
        subtasks = (json['subtasks'] as List<dynamic>)
            ?.map((subtask) => Task.fromJson(subtask))
            ?.cast<Task>()
            ?.toList(),
        updated = dateTimeFromUnixTimestamp(json['updated']),
        created = dateTimeFromUnixTimestamp(json['created']),
        createdBy = User.fromJson(json['createdBy']);

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
