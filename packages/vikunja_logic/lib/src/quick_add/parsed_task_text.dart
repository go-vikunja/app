import 'package:meta/meta.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

enum QuickAddRepeatUnit { hours, days, weeks, months, years }

/// A repeat phrase such as `every 2 weeks` or `monthly`.
@immutable
final class QuickAddRepeat {
  const new({required this.amount, required this.unit});

  final int amount;
  final QuickAddRepeatUnit unit;

  /// How the task stores it. One month is the server's monthly mode; other
  /// month and year amounts become days (30 per month, 365 per year), a
  /// deliberate fix of the web, which drops them (D19 item 1).
  ({Duration repeatAfter, RepeatMode mode}) toTaskRepeat() {
    if (unit == QuickAddRepeatUnit.months && amount == 1) {
      return (repeatAfter: Duration.zero, mode: RepeatMode.monthly);
    }
    final repeatAfter = switch (unit) {
      QuickAddRepeatUnit.hours => Duration(hours: amount),
      QuickAddRepeatUnit.days => Duration(days: amount),
      QuickAddRepeatUnit.weeks => Duration(days: 7 * amount),
      QuickAddRepeatUnit.months => Duration(days: 30 * amount),
      QuickAddRepeatUnit.years => Duration(days: 365 * amount),
    };
    return (repeatAfter: repeatAfter, mode: RepeatMode.afterAmount);
  }

  @override
  bool operator ==(Object other) =>
      other is QuickAddRepeat && other.amount == amount && other.unit == unit;

  @override
  int get hashCode => Object.hash(amount, unit);

  @override
  String toString() => 'QuickAddRepeat($amount ${unit.name})';
}

/// What Quick Add Magic found in a title. [text] is the title with every
/// recognised part removed and trimmed, except the assignees, which stay
/// until they are resolved to users.
@immutable
final class ParsedTaskText {
  const new({
    required this.text,
    this.date,
    this.labels = const [],
    this.project,
    this.priority,
    this.assignees = const [],
    this.repeats,
    this.datePhrases = const [],
    this.repeatPhrase,
  });

  final String text;

  /// Local wall-clock time.
  final DateTime? date;
  final List<String> labels;
  final String? project;

  /// 0..5.
  final int? priority;
  final List<String> assignees;
  final QuickAddRepeat? repeats;

  /// The phrases [date] was read from, as typed and in the order they were
  /// found: the date (`tomorrow`, `17th`, `9/11`), a month word that went
  /// with an ordinal day (`sep`) and the time (`at 9:00`). Every occurrence
  /// of each was removed from [text].
  final List<String> datePhrases;

  /// The phrase [repeats] was read from, as typed (`every 2 weeks`).
  final String? repeatPhrase;

  @override
  bool operator ==(Object other) =>
      other is ParsedTaskText &&
      other.text == text &&
      other.date == date &&
      _sameItems(other.labels, labels) &&
      other.project == project &&
      other.priority == priority &&
      _sameItems(other.assignees, assignees) &&
      other.repeats == repeats &&
      _sameItems(other.datePhrases, datePhrases) &&
      other.repeatPhrase == repeatPhrase;

  @override
  int get hashCode => Object.hash(
    text,
    date,
    Object.hashAll(labels),
    project,
    priority,
    Object.hashAll(assignees),
    repeats,
    Object.hashAll(datePhrases),
    repeatPhrase,
  );

  static bool _sameItems(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'ParsedTaskText(text: $text, date: $date, labels: $labels, '
      'project: $project, priority: $priority, assignees: $assignees, '
      'repeats: $repeats, datePhrases: $datePhrases, '
      'repeatPhrase: $repeatPhrase)';
}
