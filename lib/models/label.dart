import 'dart:ui';

import 'package:vikunja_app/models/user.dart';

class Label {
  final int id;
  final String title, description;
  final DateTime created, updated;
  final User createdBy;
  final Color color;

  Label(
      {this.id,
      this.title,
      this.description,
      this.color,
      this.created,
      this.updated,
      this.createdBy});

  Label.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        title = json['title'],
        description = json['description'],
        color = json['hex_color'] == ''
            ? null
            : new Color(int.parse(json['hex_color'], radix: 16) + 0xFF000000),
        updated = DateTime.parse(json['updated']),
        created = DateTime.parse(json['created']),
        createdBy = User.fromJson(json['created_by']);

  toJSON() => {
        'id': id,
        'title': title,
        'description': description,
        'hex_color':
            color?.value?.toRadixString(16)?.padLeft(8, '0')?.substring(2),
        'created_by': createdBy?.toJSON(),
        'updated': updated?.toUtc()?.toIso8601String(),
        'created': created?.toUtc()?.toIso8601String(),
      };
}
