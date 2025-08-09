import 'dart:ui';

import 'package:vikunja_app/data/models/user.dart';
import 'package:vikunja_app/core/utils/constants.dart';

class Label {
  final int id;
  final String title, description;
  final DateTime created, updated;
  final User createdBy;
  final Color? color;

  late final Color textColor = color != null && color!.computeLuminance() <= 0.5
      ? vLabelLight
      : vLabelDark;

  Label({
    this.id = 0,
    required this.title,
    this.description = '',
    this.color,
    DateTime? created,
    DateTime? updated,
    required this.createdBy,
  })  : this.created = created ?? DateTime.now(),
        this.updated = updated ?? DateTime.now();
}
