import 'package:json_annotation/json_annotation.dart';

import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/user.dart';

@JsonSerializable()
class Bucket {
  int id, listId, limit;
  String title;
  double? position;
  late final DateTime created, updated;
  User createdBy;
  bool isDoneBucket;
  late final List<Task> tasks;

  Bucket({
    this.id = -1,
    required this.listId,
    required this.title,
    this.position,
    required this.limit,
    this.isDoneBucket = false,
    DateTime? created,
    DateTime? updated,
    required this.createdBy,
    List<Task>? tasks,
  }) {
    this.created = created ?? DateTime.now();
    this.updated = created ?? DateTime.now();
    this.tasks = tasks ?? [];
  }

  Bucket.fromJSON(Map<String, dynamic> json)
      : id = json['id'],
        listId = json['list_id'],
        title = json['title'],
        position = json['position'] is int
            ? json['position'].toDouble()
            : json['position'],
        limit = json['limit'],
        isDoneBucket = json['is_done_bucket'],
        created = DateTime.parse(json['created']),
        updated = DateTime.parse(json['updated']),
        createdBy = User.fromJson(json['created_by']),
        tasks = json['tasks'] == null
            ? []
            : (json['tasks'] as List<dynamic>)
                .map((task) => Task.fromJson(task))
                .toList();

  toJSON() => {
    'id': id != -1 ? id : null,
    'list_id': listId,
    'title': title,
    'position': position,
    'limit': limit,
    'is_done_bucket': isDoneBucket,
    'created': created.toUtc().toIso8601String(),
    'updated': updated.toUtc().toIso8601String(),
    'created_by': createdBy.toJSON(),
    'tasks': tasks.map((task) => task.toJSON()).toList(),
  };
}