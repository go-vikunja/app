import 'package:meta/meta.dart';

@immutable
final class ChecklistStatistics {
  const new({this.total = 0, this.checked = 0});

  final int total;
  final int checked;

  bool get isEmpty => total == 0;
  bool get allDone => total > 0 && checked == total;

  @override
  bool operator ==(Object other) =>
      other is ChecklistStatistics &&
      other.total == total &&
      other.checked == checked;

  @override
  int get hashCode => Object.hash(total, checked);

  @override
  String toString() => 'ChecklistStatistics($checked of $total)';
}

/// The web's `checklistFromText`: every `data-checked="true|false"` in the
/// description HTML counts, nested lists included.
ChecklistStatistics checklistStatistics(String html) {
  var total = 0;
  var checked = 0;
  for (final match in _checkbox.allMatches(html)) {
    total++;
    if (match[1] == 'true') checked++;
  }
  return ChecklistStatistics(total: total, checked: checked);
}

/// The start offsets of those matches, ascending.
List<int> findCheckboxesInText(String html) => List.unmodifiable([
  for (final match in _checkbox.allMatches(html)) match.start,
]);

final _checkbox = RegExp('data-checked="(true|false)"');
