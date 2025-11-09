import 'dart:ui';

import 'package:vikunja_app/data/models/dto.dart';
import 'package:vikunja_app/data/models/user_dto.dart';
import 'package:vikunja_app/data/models/project_view_dto.dart';
import 'package:vikunja_app/domain/entities/project.dart';

class ProjectDto extends Dto<Project> {
  final int id;
  final double position;
  final UserDto? owner;
  final int parentProjectId;
  final String description;
  final String title;
  final DateTime created, updated;
  final Color? color;
  final bool isArchived, isFavourite;

  final List<ProjectViewDto> views;

  ProjectDto({
    this.id = 0,
    this.owner,
    this.parentProjectId = 0,
    this.description = '',
    this.position = 0,
    this.color,
    this.isArchived = false,
    this.isFavourite = false,
    this.views = const [],
    required this.title,
    created,
    updated,
  }) : created = created ?? DateTime.now(),
       updated = updated ?? DateTime.now();

  ProjectDto.fromJson(Map<String, dynamic> json)
    : title = json['title'],
      description = json['description'],
      id = json['id'],
      position = json['position'].toDouble(),
      isArchived = json['is_archived'],
      isFavourite = json['is_archived'],
      parentProjectId = json['parent_project_id'],
      views = (json['views'] is List)
          ? (json['views'] as List)
                .map<ProjectViewDto>((view) => ProjectViewDto.fromJson(view))
                .toList()
          : [],
      created = DateTime.parse(json['created']),
      updated = DateTime.parse(json['updated']),
      color = json['hex_color'] != ''
          ? Color(int.parse(json['hex_color'], radix: 16) + 0xFF000000)
          : null,
      owner = json['owner'] != null ? UserDto.fromJson(json['owner']) : null;

  Map<String, dynamic> toJSON() => {
    'id': id,
    'created': created.toUtc().toIso8601String(),
    'updated': updated.toUtc().toIso8601String(),
    'title': title,
    'owner': owner?.toJSON(),
    'description': description,
    'parent_project_id': parentProjectId,
    'hex_color': color
        ?.toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2),
    'is_archived': isArchived,
    'is_favourite': isFavourite,
    'position': position,
  };

  @override
  Project toDomain() => Project(
    id: id,
    position: position,
    owner: owner?.toDomain(),
    parentProjectId: parentProjectId,
    description: description,
    title: title,
    created: created,
    updated: updated,
    color: color,
    isArchived: isArchived,
    isFavourite: isFavourite,
    views: views.map((e) => e.toDomain()).toList(),
  );

  static ProjectDto fromDomain(Project p) => ProjectDto(
    id: p.id,
    position: p.position,
    owner: p.owner != null ? UserDto.fromDomain(p.owner!) : null,
    parentProjectId: p.parentProjectId,
    description: p.description,
    title: p.title,
    created: p.created,
    updated: p.updated,
    color: p.color,
    isArchived: p.isArchived,
    isFavourite: p.isFavourite,
    views: p.views.map((e) => ProjectViewDto.fromDomain(e)).toList(),
  );
}
