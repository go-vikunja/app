import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

/// What one line of quick add creates, resolved against this device's
/// projects, labels and people. The composer previews it while the user
/// types; [QuickAddService.submit] resolves the rest and creates it.
@immutable
final class QuickAddPlan {
  const new({
    required this.input,
    required this.parsed,
    required this.title,
    required this.project,
    this.unmatchedProject,
    this.projectAmbiguous = false,
    this.labels = const [],
    this.newLabels = const [],
    this.assignees = const [],
    this.unresolvedAssignees = const [],
    this.dueDate,
    this.repeat,
    this.priority,
    this.reminders = const [],
    this.magicOnly = false,
  });

  /// The line as typed.
  final String input;
  final ParsedTaskText parsed;

  /// What the task will be called: the parsed text, with an unmatched
  /// project and unresolved assignees kept in it; the raw input when the
  /// line is magic only.
  final String title;

  /// Where the task goes: the `+project` when it matched, else the
  /// fallback (the screen's project, else the user's default project).
  /// Null without any project.
  final Project? project;

  /// A `+project` that matched no project.
  final String? unmatchedProject;

  /// The `+project` names several projects, and [project] is the first.
  final bool projectAmbiguous;
  final List<Label> labels;

  /// `*label` titles without a label of that title; created on submit,
  /// which needs a connection.
  final List<String> newLabels;
  final List<User> assignees;

  /// `@names` no user was found for (yet: the server search runs on
  /// submit).
  final List<String> unresolvedAssignees;

  /// UTC: the date phrase's, else the fallback due date, else today at the
  /// default time when the line repeats; what submit gives the task.
  final DateTime? dueDate;
  final QuickAddRepeat? repeat;
  final int? priority;

  /// The user's default quick-add reminders, when there is a due date.
  final List<TaskReminder> reminders;

  /// The whole line was magic: nothing is parsed and the raw input is the
  /// title (the web's rule).
  final bool magicOnly;

  /// Whether [dueDate] comes from a date phrase of the line.
  bool get dueDateFromText => !magicOnly && parsed.date != null;
}

/// The outcome of a submit, for the snackbar.
@immutable
final class QuickAddResult {
  const new({
    required this.createdTaskIds,
    this.labelsNotCreated = const [],
    this.unresolvedAssignees = const [],
  });

  /// Local ids (negative until each create is sent), in input order.
  final List<int> createdTaskIds;

  /// `*label` titles whose label could not be created (offline, or the
  /// server refused); the tasks were created without them.
  final List<String> labelsNotCreated;

  /// `@names` that stayed in a title because no user matched.
  final List<String> unresolvedAssignees;
}

/// Plans and creates quick-add tasks for the active account.
abstract interface class QuickAddService {
  /// The plan for one line from local data only, cheap enough for every
  /// keystroke. [fallbackProjectId] is the screen's project;
  /// [fallbackDueDate] (the sheet's own date) dates a line without a date
  /// phrase, with the user's default reminders.
  QuickAddPlan plan(
    String line, {
    int? fallbackProjectId,
    DateTime? fallbackDueDate,
  });

  /// Creates one task per non-empty line of [text] through the outbox
  /// (offline-capable), as [plan] plans it; `*label`s that do not exist
  /// are created online first, `@names` are resolved with the server's
  /// user search in the task's project when it is reachable and with the
  /// known users otherwise. Throws [QuickAddNoProject] before creating
  /// anything when a line has no project, and [QuickAddPartlyFailed] when
  /// a line fails after earlier ones were created.
  Future<QuickAddResult> submit(
    String text, {
    int? fallbackProjectId,
    DateTime? fallbackDueDate,
  });
}

/// A submit that created the tasks of the first lines and then failed:
/// those are queued and must not be added again; [remainingText] holds the
/// lines that were not created.
final class QuickAddPartlyFailed implements Exception {
  const new({
    required this.createdTaskIds,
    required this.lineCount,
    required this.remainingText,
    required this.cause,
  });

  final List<int> createdTaskIds;
  final int lineCount;
  final String remainingText;
  final Object cause;

  @override
  String toString() =>
      'QuickAddPartlyFailed(${createdTaskIds.length} of $lineCount, '
      '${cause.runtimeType})';
}

/// A quick add without a project to create the task in: no `+project`
/// matched and there is no fallback, because the account has no project a
/// task can be added to.
final class QuickAddNoProject implements Exception {
  const new();

  @override
  String toString() => 'QuickAddNoProject';
}
