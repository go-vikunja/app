import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/user.dart';

class TaskList {
  final int id;
  int namespaceId;
  String title, description;
  final User owner;
  late final DateTime created, updated;
  late final List<Task> tasks;
  final bool isFavorite;

  TaskList({
    this.id = -1,
    required this.title,
    required this.namespaceId,
    this.description = '',
    required this.owner,
    DateTime? created,
    DateTime? updated,
    List<Task>? tasks,
    this.isFavorite = false,
  }) {
    this.created = created ?? DateTime.now();
    this.updated = updated ?? DateTime.now();
    this.tasks = tasks ?? [];
  }

  TaskList.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        owner = User.fromJson(json['owner']),
        description = json['description'],
        title = json['title'],
        updated = DateTime.parse(json['updated']),
        created = DateTime.parse(json['created']),
        isFavorite = json['is_favorite'],
        namespaceId = json['namespace_id'],
        tasks = json['tasks'] == null ? [] : (json['tasks'] as List<dynamic>)
            .map((taskJson) => Task.fromJson(taskJson))
            .toList();

  toJSON() {
    return {
      'id': id != -1 ? id : null,
      'title': title,
      'description': description,
      'owner': owner.toJSON(),
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
      'namespace_id': namespaceId
    };
  }
}
