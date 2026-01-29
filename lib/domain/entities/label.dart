import 'dart:ui';

import 'package:vikunja_app/domain/entities/user.dart';

class Label {
  final int id;
  final String title, description;
  final DateTime created, updated;
  final User createdBy;
  final Color? color;

  Label({
    this.id = 0,
    required this.title,
    this.description = '',
    this.color,
    DateTime? created,
    DateTime? updated,
    required this.createdBy,
  }) : created = created ?? DateTime.now(),
       updated = updated ?? DateTime.now();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Label && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
