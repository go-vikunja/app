import 'package:meta/meta.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/user.dart';

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
      this.tasks});

  TaskList.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        owner = User.fromJson(json['owner']),
        description = json['description'],
        title = json['title'],
        updated = DateTime.fromMillisecondsSinceEpoch(json['updated']),
        created = DateTime.fromMillisecondsSinceEpoch(json['created']),
        tasks = (json['tasks'] == null ? [] : json['tasks'] as List<dynamic>)
            ?.map((taskJson) => Task.fromJson(taskJson))
            ?.toList();

  toJSON() {
    return {
      "id": this.id,
      "title": this.title,
      "description": this.description,
      "owner": this.owner?.toJSON(),
      "created": this.created?.millisecondsSinceEpoch,
      "updated": this.updated?.millisecondsSinceEpoch,
    };
  }
}
