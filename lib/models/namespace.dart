import 'package:vikunja_app/models/user.dart';
import 'package:meta/meta.dart';

class Namespace {
  final int id;
  final DateTime created, updated;
  final String title, description;
  final User owner;

  Namespace(
      {@required this.id,
      this.created,
      this.updated,
      @required this.title,
      this.description,
      this.owner});

  Namespace.fromJson(Map<String, dynamic> json)
      : title = json['title'],
        description = json['description'],
        id = json['id'],
        created = DateTime.parse(json['created']),
        updated = DateTime.parse(json['updated']),
        owner = json['owner'] == null ? null : User.fromJson(json['owner']);

  toJSON() => {
        "created": created?.toIso8601String(),
        "updated": updated?.toIso8601String(),
        "title": title,
        "owner": owner?.toJSON(),
        "description": description
      };
}
