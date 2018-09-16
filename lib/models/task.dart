import 'package:fluttering_vikunja/models/user.dart';
import 'package:meta/meta.dart';

class Task {
  final int id;
  final DateTime created, updated, reminder, due;
  final String text, description;
  final bool done;
  final User owner;

  Task(
      {@required this.id,
      this.created,
      this.updated,
      this.reminder,
      this.due,
      @required this.text,
      this.description,
      this.done,
      @required this.owner});

  Task.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        updated = DateTime.fromMillisecondsSinceEpoch(json['updated']),
        created = DateTime.fromMillisecondsSinceEpoch(json['created']),
        reminder = DateTime.fromMillisecondsSinceEpoch(json['reminderDate']),
        due = DateTime.fromMillisecondsSinceEpoch(json['dueDate']),
        description = json['description'],
        text = json['text'],
        done = json['done'],
        owner = User.fromJson(json['createdBy']);
}

class TaskList {
  final int id;
  final String title, description;
  final User owner;
  final DateTime created, updated;
  final List<Task> tasks;

  TaskList(
      {@required this.id,
      @required this.title,
      this.description,
      this.owner,
      this.created,
      this.updated,
      @required this.tasks});

  TaskList.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        owner = User.fromJson(json['owner']),
        description = json['description'],
        title = json['title'],
        updated = DateTime.fromMillisecondsSinceEpoch(json['updated']),
        created = DateTime.fromMillisecondsSinceEpoch(json['created']),
        tasks = json['tasks'].map((taskJson) => Task.fromJson(taskJson));
}
