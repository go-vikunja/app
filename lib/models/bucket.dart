import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/user.dart';

@JsonSerializable()
class Bucket {
  int id, listId, limit;
  double position;
  String title;
  DateTime created, updated;
  User createdBy;
  bool isDoneBucket;
  List<Task> tasks;

  Bucket({
    @required this.id,
    @required this.listId,
    this.title,
    this.position,
    this.limit,
    this.isDoneBucket,
    this.created,
    this.updated,
    this.createdBy,
    this.tasks,
  });

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
      createdBy = json['created_by'] == null
        ? null
        : User.fromJson(json['created_by']),
      tasks = (json['tasks'] as List<dynamic>)
        ?.map((task) => Task.fromJson(task))
        ?.cast<Task>()
        ?.toList();

  toJSON() => {
    'id': id,
    'list_id': listId,
    'title': title,
    'position': position,
    'limit': limit,
    'is_done_bucket': isDoneBucket ?? false,
    'created': created?.toUtc()?.toIso8601String(),
    'updated': updated?.toUtc()?.toIso8601String(),
    'createdBy': createdBy?.toJSON(),
    'tasks': tasks?.map((task) => task.toJSON())?.toList(),
  };
}