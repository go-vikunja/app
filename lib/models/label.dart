import 'dart:ui';

import 'package:vikunja_app/models/user.dart';
import 'package:vikunja_app/theme/constants.dart';

class Label {
  final int id;
  final String title, description;
  final DateTime created, updated;
  final User createdBy;
  final Color? color;

  late final Color textColor = color != null && color!.computeLuminance() <= 0.5 ? vLabelLight : vLabelDark;

  Label({
    this.id = -1,
    required this.title,
    this.description = '',
    this.color,
    DateTime? created,
    DateTime? updated,
    required this.createdBy,
  })  : this.created = created ?? DateTime.now(),
        this.updated = updated ?? DateTime.now();

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
        'id': id != -1 ? id : null,
        'title': title,
        'description': description,
        'hex_color':
            color?.value.toRadixString(16).padLeft(8, '0').substring(2),
        'created_by': createdBy.toJSON(),
        'updated': updated.toUtc().toIso8601String(),
        'created': created.toUtc().toIso8601String(),
      };
}
