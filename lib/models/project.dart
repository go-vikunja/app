import 'dart:ui';

import 'package:vikunja_app/models/user.dart';
import 'package:vikunja_app/models/view.dart';

class Project {
  final int id;
  final double position;
  final User? owner;
  final int parentProjectId;
  final String description;
  final String title;
  final DateTime created, updated;
  final Color? color;
  final bool isArchived, isFavourite;

  Iterable<Project>? subprojects;
  final List<ProjectView> views;

  Project(
      {this.id = 0,
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
      updated})
      : this.created = created ?? DateTime.now(),
        this.updated = updated ?? DateTime.now();

  Project.fromJson(Map<String, dynamic> json)
      : title = json['title'],
        description = json['description'],
        id = json['id'],
        position = json['position'].toDouble(),
        isArchived = json['is_archived'],
        isFavourite = json['is_archived'],
        parentProjectId = json['parent_project_id'],
        views = json['views']
            .map<ProjectView>((view) => ProjectView.fromJson(view))
            .toList(),
        created = DateTime.parse(json['created']),
        updated = DateTime.parse(json['updated']),
        color = json['hex_color'] != ''
            ? Color(int.parse(json['hex_color'], radix: 16) + 0xFF000000)
            : null,
        owner = json['owner'] != null ? User.fromJson(json['owner']) : null;

  Map<String, dynamic> toJSON() => {
        'id': id,
        'created': created.toUtc().toIso8601String(),
        'updated': updated.toUtc().toIso8601String(),
        'title': title,
        'owner': owner?.toJSON(),
        'description': description,
        'parent_project_id': parentProjectId,
        'hex_color':
            color?.value.toRadixString(16).padLeft(8, '0').substring(2),
        'is_archived': isArchived,
        'is_favourite': isFavourite,
        'position': position
      };

  Project copyWith({
    int? id,
    DateTime? created,
    DateTime? updated,
    String? title,
    User? owner,
    String? description,
    int? parentProjectId,
    Color? color,
    bool? isArchived,
    bool? isFavourite,
    int? doneBucketId,
    double? position,
  }) {
    return Project(
      id: id ?? this.id,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      title: title ?? this.title,
      owner: owner ?? this.owner,
      description: description ?? this.description,
      parentProjectId: parentProjectId ?? this.parentProjectId,
      color: color ?? this.color,
      isArchived: isArchived ?? this.isArchived,
      isFavourite: isFavourite ?? this.isFavourite,
      position: position ?? this.position,
    );
  }
}
