import 'package:vikunja_app/models/user.dart';
import 'package:meta/meta.dart';

import 'list.dart';

class Task {
  int id, list_id;
  DateTime created, updated, due;
  List<DateTime> reminders;
  String title, description;
  bool done;
  User owner;
  bool loading = false;
  TaskList list;

  Task(
      {@required this.id,
      this.created,
      this.updated,
      this.reminders,
      this.due,
      @required this.title,
      this.description,
      @required this.done,
      @required this.owner,
      this.loading,
      this.list_id});

  Task.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        updated = DateTime.parse(json['updated']),
        created = DateTime.parse(json['created']),
        reminders = (json['reminder_dates'] as List<dynamic>)
            ?.map((r) => DateTime.parse(r))
            ?.toList(),
        due =
            json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
        description = json['description'],
        title = json['title'],
        done = json['done'],
        list_id = json['list_id'],
        owner = json['created_by'] == null ? null : User.fromJson(json['created_by']);

  toJSON() => {
        'id': id,
        'updated': updated?.toIso8601String(),
        'created': created?.toIso8601String(),
        'reminder_dates':
            reminders?.map((date) => date.toIso8601String())?.toList(),
        'due_date': due?.toUtc()?.toIso8601String(),
        'description': description,
        'title': title,
        'done': done ?? false,
        'created_by': owner?.toJSON(),
        'list_id': list_id
      };
}
