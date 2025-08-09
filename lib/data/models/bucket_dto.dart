import 'package:json_annotation/json_annotation.dart';
import 'package:vikunja_app/data/models/task_dto.dart';
import 'package:vikunja_app/data/models/user.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';

@JsonSerializable()
class BucketDto {
  int id, limit;
  int? projectViewId;
  String title;
  double? position;
  final DateTime created, updated;
  UserDto createdBy;
  final List<TaskDto> tasks;

  BucketDto({
    this.id = 0,
    required this.projectViewId,
    required this.title,
    this.position,
    required this.limit,
    DateTime? created,
    DateTime? updated,
    required this.createdBy,
    List<TaskDto>? tasks,
  })  : this.created = created ?? DateTime.now(),
        this.updated = created ?? DateTime.now(),
        this.tasks = tasks ?? [];

  BucketDto.fromJSON(Map<String, dynamic> json)
      : id = json['id'],
        projectViewId = json['project_view_id'],
        title = json['title'],
        position = json['position'] is int
            ? json['position'].toDouble()
            : json['position'],
        limit = json['limit'],
        created = DateTime.parse(json['created']),
        updated = DateTime.parse(json['updated']),
        createdBy = UserDto.fromJson(json['created_by']),
        tasks = json['tasks'] == null
            ? []
            : (json['tasks'] as List<dynamic>)
                .map((task) => TaskDto.fromJson(task))
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

  Bucket toDomain() => Bucket(
      id: id,
      projectViewId: projectViewId,
      title: title,
      position: position,
      limit: limit,
      created: created,
      updated: updated,
      createdBy: createdBy.toDomain(),
      tasks: tasks.map((e) => e.toDomain()).toList());

  static BucketDto fromDomain(Bucket b) => BucketDto(
      id: b.id,
      projectViewId: b.projectViewId,
      title: b.title,
      position: b.position,
      limit: b.limit,
      created: b.created,
      updated: b.updated,
      createdBy: UserDto.fromDomain(b.createdBy),
      tasks: b.tasks.map((e) => TaskDto.fromDomain(e)).toList());
}
