import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';

LabelRow labelRow(Label label) => LabelRow(
  id: label.id,
  title: label.title,
  description: label.description,
  hexColor: label.hexColor,
  createdById: label.createdBy?.id,
  created: label.created,
  updated: label.updated,
);

Label labelFromRow(LabelRow row, {User? createdBy}) => Label(
  id: row.id,
  title: row.title,
  description: row.description,
  hexColor: row.hexColor,
  createdBy: createdBy,
  created: row.created,
  updated: row.updated,
);
