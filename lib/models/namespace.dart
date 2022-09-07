import 'package:vikunja_app/models/user.dart';

class Namespace {
  final int id;
  final DateTime created, updated;
  final String title, description;
  final User owner;

  Namespace({
    this.id = -1,
    DateTime? created,
    DateTime? updated,
    required this.title,
    this.description = '',
    required this.owner,
  })  : this.created = created ?? DateTime.now(),
        this.updated = updated ?? DateTime.now();

  Namespace.fromJson(Map<String, dynamic> json)
      : title = json['title'],
        description = json['description'],
        id = json['id'],
        created = DateTime.parse(json['created']),
        updated = DateTime.parse(json['updated']),
        owner = User.fromJson(json['owner']);

  Map<String, dynamic> toJSON() => {
        'id': id != -1 ? id : null,
        'created': created.toUtc().toIso8601String(),
        'updated': updated.toUtc().toIso8601String(),
        'title': title,
        'owner': owner.toJSON(),
        'description': description
      };

  Namespace copyWith({
    int? id,
    DateTime? created,
    DateTime? updated,
    String? title,
    String? description,
    User? owner,
  }) {
    return Namespace(
      id: id ?? this.id,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      title: title ?? this.title,
      description: description ?? this.description,
      owner: owner ?? this.owner,
    );
  }
}
