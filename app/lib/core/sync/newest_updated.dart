import 'package:vikunja_domain/vikunja_domain.dart';

/// The newest server `updated` among what a run read itself, for its
/// watermark; rows other code writes meanwhile do not count. A value more
/// than the tolerance ahead of the device clock when it is read is left
/// out and kept for the log: a server whose clock once ran fast would
/// otherwise put every delta in the future for good.
final class NewestUpdated {
  new({required this._now, required this._tolerance});

  final DateTime Function() _now;
  final Duration _tolerance;
  DateTime? _within;
  DateTime? _ahead;

  DateTime? get value => _within;

  /// The newest value left out; null when none was.
  DateTime? get aheadOfClock => _ahead;

  void addTasks(Iterable<Task> tasks) =>
      addAll(tasks.map((task) => task.updated));

  void addAll(Iterable<DateTime?> values) {
    final bound = _now().toUtc().add(_tolerance);
    for (final value in values.nonNulls) {
      if (value.isAfter(bound)) {
        _ahead = _later(_ahead, value);
      } else {
        _within = _later(_within, value);
      }
    }
  }

  static DateTime _later(DateTime? a, DateTime b) =>
      a == null || b.isAfter(a) ? b : a;
}
