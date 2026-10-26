import 'package:vikunja_domain/vikunja_domain.dart';

/// Newest first: a task created here (a negative id, the newer the lower)
/// before every server task, then the higher server id first.
int compareNewestFirst(Task a, Task b) {
  final aIsLocal = a.id < 0;
  if (aIsLocal != b.id < 0) return aIsLocal ? -1 : 1;
  return b.id.abs().compareTo(a.id.abs());
}

/// The server's `NULLS LAST`: a missing value is last in both directions.
int compareNullsLast<T extends Comparable<Object>>(
  T? a,
  T? b, {
  required bool descending,
}) {
  if (a == null) return b == null ? 0 : 1;
  if (b == null) return -1;
  final order = a.compareTo(b);
  return descending ? -order : order;
}

/// Ignoring case first, then by code unit. The server's database collation
/// can differ (SQLite compares bytes: `Apple, Date, _under, apple`).
int compareTitles(String a, String b) {
  final ignoringCase = a.toLowerCase().compareTo(b.toLowerCase());
  return ignoringCase != 0 ? ignoringCase : a.compareTo(b);
}

/// The order of the web's Overview and Upcoming requests: due date
/// ascending with undated tasks last, then newest first.
int compareByDueDate(Task a, Task b) {
  final byDueDate = compareNullsLast(a.dueDate, b.dueDate, descending: false);
  return byDueDate != 0 ? byDueDate : compareNewestFirst(a, b);
}
