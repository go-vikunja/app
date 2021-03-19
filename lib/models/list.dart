import 'package:meta/meta.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/user.dart';

class TaskList {
  final int id;
  final String title, description;
  final User owner;
  final DateTime created, updated;
  final List<Task> tasks;

  TaskList({
    @required this.id,
    @required this.title,
    this.description,
    this.owner,
    this.created,
    this.updated,
    this.tasks,
  });

  TaskList.fromJson(Map<String, dynamic> json, {tasksJson})
      : id = json['id'],
        owner = json['owner'] == null ? null : User.fromJson(json['owner']),
        description = json['description'],
        title = json['title'],
        updated = DateTime.parse(json['updated']),
        created = DateTime.parse(json['created']),
        tasks = (tasksJson == null ? [] : tasksJson as List<dynamic>)
            ?.map((taskJson) => Task.fromJson(taskJson))
            ?.toList();

  toJSON() {
    return {
      "id": this.id,
      "title": this.title,
      "description": this.description,
      "owner": this.owner?.toJSON(),
      "created": this.created?.toIso8601String(),
      "updated": this.updated?.toIso8601String(),
    };
  }
}
