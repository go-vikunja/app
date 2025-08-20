import 'dart:ui';

import 'package:vikunja_app/data/models/user_dto.dart';
import 'package:vikunja_app/core/utils/constants.dart';
import 'package:vikunja_app/domain/entities/label.dart';

class LabelDto {
  final int id;
  final String title, description;
  final DateTime created, updated;
  final UserDto createdBy;
  final Color? color;

  late final Color textColor = color != null && color!.computeLuminance() <= 0.5
      ? vLabelLight
      : vLabelDark;

  LabelDto({
    this.id = 0,
    required this.title,
    this.description = '',
    this.color,
    DateTime? created,
    DateTime? updated,
    required this.createdBy,
  }) : this.created = created ?? DateTime.now(),
       this.updated = updated ?? DateTime.now();

  LabelDto.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      title = json['title'],
      description = json['description'],
      color = json['hex_color'] == ''
          ? null
          : new Color(int.parse(json['hex_color'], radix: 16) + 0xFF000000),
      updated = DateTime.parse(json['updated']),
      created = DateTime.parse(json['created']),
      createdBy = UserDto.fromJson(json['created_by']);

  toJSON() => {
    'id': id,
    'title': title,
    'description': description,
    'hex_color': color
        ?.toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2),
    'created_by': createdBy.toJSON(),
    'updated': updated.toUtc().toIso8601String(),
    'created': created.toUtc().toIso8601String(),
  };

  Label toDomain() => Label(
    id: id,
    title: title,
    description: description,
    created: created,
    updated: updated,
    createdBy: createdBy.toDomain(),
    color: color,
  );

  static LabelDto fromDomain(Label b) => LabelDto(
    id: b.id,
    title: b.title,
    description: b.description,
    created: b.created,
    updated: b.updated,
    createdBy: UserDto.fromDomain(b.createdBy),
    color: b.color,
  );
}
