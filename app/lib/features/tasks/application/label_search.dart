import 'dart:math';

import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/filters/search_index.dart';
import 'package:vikunja_mobile/features/tasks/application/color_palette.dart';

/// The server's limit for a label title, in code points.
const int maxLabelTitleLength = Label.maxTitleLength;

/// A new label's colour: one of the [okabeItoColors] at random.
String randomLabelColor(Random random) =>
    okabeItoColors[random.nextInt(okabeItoColors.length)];

/// [labels] whose title contains the trimmed [query], ignoring case and
/// accents.
List<Label> filterLabels(List<Label> labels, String query) {
  final needle = foldForSearch(query.trim());
  if (needle.isEmpty) return labels;
  return [
    for (final label in labels)
      if (foldForSearch(label.title).contains(needle)) label,
  ];
}

/// The title a "Create label" row offers: the trimmed [query], unless it is
/// empty or some label already has exactly that title, ignoring case.
String? labelTitleToCreate(List<Label> labels, String query) {
  final title = query.trim();
  if (title.isEmpty) return null;
  final lower = title.toLowerCase();
  final exists = labels.any((label) => label.title.toLowerCase() == lower);
  return exists ? null : title;
}
