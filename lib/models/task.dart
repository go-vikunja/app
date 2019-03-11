import 'package:vikunja_app/models/user.dart';
import 'package:meta/meta.dart';

class Task {
  final int id;
  final DateTime created, updated, due;
  final List<DateTime> reminders;
  final String text, description;
  final bool done;
  final User owner;

  Task(
      {@required this.id,
      this.created,
      this.updated,
      this.reminders,
      this.due,
      @required this.text,
      this.description,
      @required this.done,
      @required this.owner});

  Task.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        updated = DateTime.fromMillisecondsSinceEpoch(json['updated']),
        created = DateTime.fromMillisecondsSinceEpoch(json['created']),
        reminders = (json['reminderDates'] as List<dynamic>)
            ?.map((milli) => DateTime.fromMillisecondsSinceEpoch(milli))
            ?.toList(),
        due = DateTime.fromMillisecondsSinceEpoch(json['dueDate']),
        description = json['description'],
        text = json['text'],
        done = json['done'],
        owner = User.fromJson(json['createdBy']);

  toJSON() => {
        'id': id,
        'updated': updated?.millisecondsSinceEpoch,
        'created': created?.millisecondsSinceEpoch,
        'reminderDates':
            reminders?.map((date) => date.millisecondsSinceEpoch)?.toList(),
        'dueDate': due?.millisecondsSinceEpoch,
        'description': description,
        'text': text,
        'done': done ?? false,
        'createdBy': owner?.toJSON()
      };
}
