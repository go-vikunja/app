import 'package:drift/drift.dart';

/// Instants are stored as UTC epoch milliseconds, so that SQLite can compare
/// and order them as plain integers.
final class EpochMillis extends TypeConverter<DateTime, int> {
  const new();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMillisecondsSinceEpoch(fromDb, isUtc: true);

  @override
  int toSql(DateTime value) => value.toUtc().millisecondsSinceEpoch;
}
