import 'package:vikunja_app/data/models/dto.dart';
import 'package:vikunja_app/data/models/task_dto.dart';
import 'package:vikunja_app/data/models/user_dto.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';

class BucketDto extends Dto<Bucket> {
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
  }) : created = created ?? DateTime.now(),
       updated = created ?? DateTime.now(),
       tasks = tasks ?? [];

  BucketDto.fromJSON(Map<String, dynamic> json)
    : id = json['id'],
      projectViewId = json['project_view_id'],
    title = (json['title'] ?? '') as String,
      position = json['position'] is int
          ? json['position'].toDouble()
          : json['position'],
    limit = (json['limit'] ?? 0) is int
      ? (json['limit'] ?? 0) as int
      : int.tryParse(json['limit']?.toString() ?? '') ?? 0,
    created = json['created'] != null
      ? DateTime.parse(json['created'])
      : DateTime.now(),
    updated = json['updated'] != null
      ? DateTime.parse(json['updated'])
      : DateTime.now(),
      createdBy = UserDto.fromJson(json['created_by']),
      tasks = json['tasks'] == null
          ? []
          : (json['tasks'] as List<dynamic>)
                .map((task) => TaskDto.fromJson(task))
                .toList();

  Map<String, Object?> toJSON() => {
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

  @override
  Bucket toDomain() => Bucket(
    id: id,
    projectViewId: projectViewId,
    title: title,
    position: position,
    limit: limit,
    created: created,
    updated: updated,
    createdBy: createdBy.toDomain(),
    tasks: tasks.map((e) => e.toDomain()).toList(),
  );

  static BucketDto fromDomain(Bucket b) => BucketDto(
    id: b.id,
    projectViewId: b.projectViewId,
    title: b.title,
    position: b.position,
    limit: b.limit,
    created: b.created,
    updated: b.updated,
    createdBy: UserDto.fromDomain(b.createdBy),
    tasks: b.tasks.map((e) => TaskDto.fromDomain(e)).toList(),
  );
}
