import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

/// Thursday 2021-06-24, the date of the web's tables, at noon.
final tableNow = DateTime(2021, 6, 24, 12);

ParsedTaskText parse(
  String text, {
  DateTime? now,
  QuickAddMagicMode mode = QuickAddMagicMode.vikunja,
}) => parseTaskText(text, now: now ?? tableNow, mode: mode);

String ymd(DateTime? date) =>
    date == null ? 'null' : '${date.year}-${date.month}-${date.day}';

String hm(DateTime? date) =>
    date == null ? 'null' : '${date.hour}:${date.minute}';
