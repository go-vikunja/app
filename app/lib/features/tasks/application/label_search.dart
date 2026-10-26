import 'dart:math';

import 'package:vikunja_domain/vikunja_domain.dart';

/// The server's limit for a label title, in code points.
const int maxLabelTitleLength = Label.maxTitleLength;

/// The colours the web picks from at random for a new label.
const newLabelColors = [
  'ffbe0b',
  'fd8a09',
  'fb5607',
  'ff006e',
  'efbdeb',
  '8338ec',
  '5f5ff6',
  '3a86ff',
  '4c91ff',
  '0ead69',
  '25be8b',
  '073b4c',
  '373f47',
];

String randomLabelColor(Random random) =>
    newLabelColors[random.nextInt(newLabelColors.length)];

/// [labels] whose title contains the trimmed [query], ignoring case.
List<Label> filterLabels(List<Label> labels, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return labels;
  return [
    for (final label in labels)
      if (label.title.toLowerCase().contains(needle)) label,
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
