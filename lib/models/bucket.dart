import 'package:json_annotation/json_annotation.dart';

import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/user.dart';

@JsonSerializable()
class Bucket {
  int id, projectViewId, limit;
  String title;
  double? position;
  final DateTime created, updated;
  User createdBy;
  final List<Task> tasks;

  Bucket({
    this.id = 0,
    required this.projectViewId,
    required this.title,
    this.position,
    required this.limit,
    DateTime? created,
    DateTime? updated,
    required this.createdBy,
    List<Task>? tasks,
  })  : this.created = created ?? DateTime.now(),
        this.updated = created ?? DateTime.now(),
        this.tasks = tasks ?? [];

  Bucket.fromJSON(Map<String, dynamic> json)
      : id = json['id'],
        projectViewId = json['project_view_id'],
        title = json['title'],
        position = json['position'] is int
            ? json['position'].toDouble()
            : json['position'],
        limit = json['limit'],
        created = DateTime.parse(json['created']),
        updated = DateTime.parse(json['updated']),
        createdBy = User.fromJson(json['created_by']),
        tasks = json['tasks'] == null
            ? []
            : (json['tasks'] as List<dynamic>)
                .map((task) => Task.fromJson(task))
                .toList();

  toJSON() => {
        'id': id,
        'project_view_id': projectViewId,
        'title': title,
        'position': position,
        'limit': limit,
        'created': created.toUtc().toIso8601String(),
        'updated': updated.toUtc().toIso8601String(),
        'created_by': createdBy.toJSON(),
        'tasks': tasks.map((task) => task.toJSON()).toList(),
      };
}
