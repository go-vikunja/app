import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_lines.dart';

typedef TaskTextParser = ParsedTaskText Function(
  String text, {
  required DateTime now,
  required QuickAddMagicMode mode,
});

typedef ItemCleanup = String Function(
  String text,
  Iterable<String> items,
  String prefix,
);

typedef TaskRepeatOf = ({Duration repeatAfter, RepeatMode mode}) Function(
  QuickAddRepeat repeat,
);

/// The parts of `vikunja_logic` the quick-add service builds on, so that
/// tests can drive the service with a parser of their own.
final class QuickAddGrammar {
  const new({
    this.parse = parseTaskText,
    this.cleanup = cleanupItemText,
    this.prefixes = quickAddPrefixes,
    this.repeatOf = _taskRepeat,
    this.subtasks = parseSubtasksViaIndention,
  });

  final TaskTextParser parse;
  final ItemCleanup cleanup;
  final QuickAddPrefixes? Function(QuickAddMagicMode mode) prefixes;
  final TaskRepeatOf repeatOf;
  final SubtaskParser subtasks;
}

({Duration repeatAfter, RepeatMode mode}) _taskRepeat(QuickAddRepeat repeat) =>
    repeat.toTaskRepeat();
