import 'package:vikunja_domain/vikunja_domain.dart';

/// The web row's labels: one per id (the last copy, where the first
/// stood), by title.
List<Label> rowLabels(List<Label> labels) {
  final byId = <int, Label>{};
  for (final label in labels) {
    byId[label.id] = label;
  }
  return byId.values.toList()..sort((a, b) {
    final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    return byTitle != 0 ? byTitle : a.title.compareTo(b.title);
  });
}

/// The web's empty-editor rule: an untouched editor saves `<p></p>`.
bool hasDescription(Task task) =>
    task.description.isNotEmpty && task.description != '<p></p>';
