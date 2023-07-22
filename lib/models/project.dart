import 'package:vikunja_app/models/user.dart';

class Project {
  final int id;
  final User? owner;
  final int parentProjectId;
  final String description;
  final String title;
  final DateTime created, updated;

  Project(
      {this.id = 0,
      this.owner,
      this.parentProjectId = 0,
      this.description = '',
      required this.title,
      created,
      updated}) :
        this.created = created ?? DateTime.now(),
        this.updated = updated ?? DateTime.now();

  Project.fromJson(Map<String, dynamic> json)
      : title = json['title'],
        description = json['description'],
        id = json['id'],
        parentProjectId = json['parent_project_id'],
        created = DateTime.parse(json['created']),
        updated = DateTime.parse(json['updated']),
        owner = json['owner'] != null ? User.fromJson(json['owner']) : null;

  Map<String, dynamic> toJSON() => {
    'id': id,
    'created': created.toUtc().toIso8601String(),
    'updated': updated.toUtc().toIso8601String(),
    'title': title,
    'owner': owner?.toJSON(),
    'description': description,
    'parent_project_id': parentProjectId
  };
}