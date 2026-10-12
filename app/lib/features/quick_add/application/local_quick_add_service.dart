import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/label_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/repositories/user_repository.dart';
import 'package:vikunja_mobile/features/quick_add/application/project_references.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_grammar.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_lines.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_plan.dart';
import 'package:vikunja_mobile/features/tasks/application/default_project.dart';
import 'package:vikunja_mobile/features/tasks/application/label_search.dart';

final _log = Logger('QuickAdd');

/// The active account's data as this device holds it, which a plan is
/// matched against.
@immutable
final class QuickAddSnapshot {
  const new({
    this.projects = const [],
    this.labels = const [],
    this.knownUsers = const [],
    this.settings = const UserSettings(),
  });

  final List<Project> projects;
  final List<Label> labels;
  final List<User> knownUsers;
  final UserSettings settings;
}

/// Quick add over a [QuickAddSnapshot]; a new snapshot means a new service.
final class LocalQuickAddService implements QuickAddService {
  new({
    required this._snapshot,
    required this._tasks,
    required this._labels,
    required this._users,
    required this._now,
    this._grammar = const QuickAddGrammar(),
    Random? random,
  }) : _random = random ?? Random();

  // Stand in for the unmatched project's token and for every other
  // project prefix while a line is parsed again; never typed, and no part
  // of the grammar.
  static const _hiddenProject = '\uE001';
  static const _hiddenPrefix = '\uE000';

  final QuickAddSnapshot _snapshot;
  final TaskRepository _tasks;
  final LabelRepository _labels;
  final UserRepository _users;
  final DateTime Function() _now;
  final QuickAddGrammar _grammar;
  final Random _random;

  @override
  QuickAddPlan plan(
    String line, {
    int? fallbackProjectId,
    DateTime? fallbackDueDate,
  }) {
    final settings = _snapshot.settings;
    final mode = settings.quickAddMagicMode;
    final now = _now().toLocal();
    var parsed = _grammar.parse(line, now: now, mode: mode);
    final fallback = defaultProjectFor(
      _snapshot.projects,
      currentProjectId: fallbackProjectId,
      defaultProjectId: settings.defaultProjectId,
    );
    final prefixes = _grammar.prefixes(mode);
    if (parsed.text.isEmpty || prefixes == null) {
      final magicOnly = parsed.text.isEmpty && line.trim().isNotEmpty;
      final dueDate = fallbackDueDate?.toUtc();
      return QuickAddPlan(
        input: line,
        parsed: parsed,
        title: magicOnly ? line.trim() : parsed.text.trim(),
        project: fallback,
        dueDate: dueDate,
        reminders: dueDate == null ? const [] : _defaultReminders,
        magicOnly: magicOnly,
      );
    }

    final named = switch (parsed.project) {
      final name? => projectsNamed(name, _selectableProjects),
      null => const <Project>[],
    };
    final project = named.firstOrNull;
    final unmatchedProject = project == null ? parsed.project : null;
    if (unmatchedProject != null) {
      parsed = _parsedKeepingProject(line, parsed, now, mode, prefixes.project);
    }

    final labels = <Label>[];
    final newLabels = <String>[];
    for (final title in parsed.labels) {
      if (_labelTitled(title) case final label?) {
        if (!labels.any((known) => known.id == label.id)) labels.add(label);
      } else if (!_containsIgnoringCase(newLabels, title)) {
        newLabels.add(title);
      }
    }

    final assignees = <User>[];
    final resolvedNames = <String>[];
    final unresolved = <String>[];
    for (final name in parsed.assignees) {
      if (_knownUserNamed(name) case final user?) {
        resolvedNames.add(name);
        if (!assignees.any((known) => known.id == user.id)) assignees.add(user);
      } else {
        unresolved.add(name);
      }
    }

    final dueDate =
        parsed.date?.toUtc() ??
        fallbackDueDate?.toUtc() ??
        (parsed.repeats == null ? null : atDefaultTime(now, now: now).toUtc());
    return QuickAddPlan(
      input: line,
      parsed: parsed,
      title: _withoutAssignees(parsed.text, resolvedNames, prefixes.assignee),
      project: project ?? fallback,
      unmatchedProject: unmatchedProject,
      projectAmbiguous: named.length > 1,
      labels: labels,
      newLabels: newLabels,
      assignees: assignees,
      unresolvedAssignees: unresolved,
      dueDate: dueDate,
      repeat: parsed.repeats,
      priority: parsed.priority,
      reminders: dueDate == null ? const [] : _defaultReminders,
    );
  }

  List<TaskReminder> get _defaultReminders => [
    for (final period in _snapshot.settings.quickAddDefaultReminders)
      TaskReminder(
        relativePeriod: period,
        relativeTo: ReminderRelativeTo.dueDate,
      ),
  ];

  @override
  Future<QuickAddResult> submit(
    String text, {
    int? fallbackProjectId,
    DateTime? fallbackDueDate,
  }) async {
    final lines = splitQuickAddLines(text);
    final plans = [
      for (final line in lines)
        plan(
          line,
          fallbackProjectId: fallbackProjectId,
          fallbackDueDate: fallbackDueDate,
        ),
    ];
    if (plans.any((plan) => plan.project == null)) {
      throw const QuickAddNoProject();
    }
    final submission = _Submission(
      users: _users,
      labels: _labels,
      random: _random,
    );
    final ready = [
      for (final plan in plans) await _resolveAssignees(plan, submission),
    ];
    await submission.createLabels([
      for (final plan in plans)
        if (!plan.magicOnly) ...plan.newLabels,
    ]);

    final ids = <int>[];
    final unresolved = <String>[];
    Never failAt(int line, Object error, StackTrace stackTrace) {
      if (ids.isEmpty) Error.throwWithStackTrace(error, stackTrace);
      Error.throwWithStackTrace(
        QuickAddPartlyFailed(
          createdTaskIds: List.unmodifiable(ids),
          lineCount: lines.length,
          remainingText: lines.skip(line).join('\n'),
          cause: error,
        ),
        stackTrace,
      );
    }

    for (final (index, (:plan, :title, :assignees, unresolved: names))
        in ready.indexed) {
      final repeat = switch (plan.repeat) {
        final repeat? => _grammar.repeatOf(repeat),
        null => null,
      };
      final int id;
      try {
        id = await _tasks.createTask(
          NewTask(
            projectId: plan.project!.id,
            title: title,
            dueDate: plan.dueDate,
            priority: TaskPriority.fromValue(plan.priority ?? 0),
            repeatAfter: repeat?.repeatAfter ?? Duration.zero,
            repeatMode: repeat?.mode ?? RepeatMode.afterAmount,
            reminders: plan.reminders,
          ),
        );
      } on Object catch (error, stackTrace) {
        failAt(index, error, stackTrace);
      }
      ids.add(id);
      final labelIds = {
        for (final label in plan.labels) label.id,
        for (final newLabel in plan.newLabels)
          ?submission.createdLabel(newLabel)?.id,
      };
      final assigneeIds = {for (final user in assignees) user.id};
      if (labelIds.isNotEmpty || assigneeIds.isNotEmpty) {
        try {
          await _tasks.updateTask(
            id,
            TaskChanges(
              labels: labelIds.isEmpty ? null : IdSetChange(added: labelIds),
              assignees: assigneeIds.isEmpty
                  ? null
                  : IdSetChange(added: assigneeIds),
            ),
          );
        } on Object catch (error, stackTrace) {
          // The task itself is queued; adding its line again would make it
          // twice.
          failAt(index + 1, error, stackTrace);
        }
      }
      for (final name in names) {
        if (!_containsIgnoringCase(unresolved, name)) unresolved.add(name);
      }
    }
    return QuickAddResult(
      createdTaskIds: ids,
      labelsNotCreated: submission.labelsNotCreated,
      unresolvedAssignees: unresolved,
    );
  }

  /// Every name looked up on the server in the task's project, also the
  /// ones the plan resolved: a known user may have no access there. Only
  /// offline does the plan's resolution against the known people stand.
  /// The names found leave the title.
  Future<_ReadyLine> _resolveAssignees(
    QuickAddPlan plan,
    _Submission submission,
  ) async {
    final names = plan.parsed.assignees;
    if (plan.magicOnly || names.isEmpty) {
      return (
        plan: plan,
        title: plan.title.trim(),
        assignees: plan.assignees,
        unresolved: plan.unresolvedAssignees,
      );
    }
    final assignees = <User>[];
    final found = <String>[];
    final unresolved = <String>[];
    for (final name in names) {
      final search = await submission.searchAssignee(plan.project!.id, name);
      final user = search.answered ? search.user : _knownUserNamed(name);
      if (user == null) {
        unresolved.add(name);
        continue;
      }
      found.add(name);
      if (!assignees.any((known) => known.id == user.id)) assignees.add(user);
    }
    final assigneePrefix = _grammar
        .prefixes(_snapshot.settings.quickAddMagicMode)!
        .assignee;
    return (
      plan: plan,
      title: _withoutAssignees(plan.parsed.text, found, assigneePrefix),
      assignees: assignees,
      unresolved: unresolved,
    );
  }

  /// The title with [names] removed, unless nothing else would be left:
  /// the server refuses an empty title.
  String _withoutAssignees(String text, List<String> names, String prefix) {
    if (names.isEmpty) return text.trim();
    final cleaned = _grammar.cleanup(text, names, prefix).trim();
    return cleaned.isEmpty ? text.trim() : cleaned;
  }

  /// [line] parsed again with its unmatched project kept as text, so that
  /// the title and every other part come from one parse: the project's
  /// token stands behind one placeholder word and every other project
  /// prefix is hidden, so that no later project is taken instead.
  ParsedTaskText _parsedKeepingProject(
    String line,
    ParsedTaskText first,
    DateTime now,
    QuickAddMagicMode mode,
    String projectPrefix,
  ) {
    final prefix = RegExp.escape(projectPrefix);
    final item = RegExp.escape(first.project!);
    final token = RegExp(
      '(^| )($prefix(?:"$item"|\'$item\'|"$item|\'$item|$item(?= |\$)))',
    ).firstMatch(line);
    final tokenText = token?[2];
    var hidden = token == null
        ? line
        : line.replaceRange(
            token.start + token[1]!.length,
            token.end,
            _hiddenProject,
          );
    hidden = hidden.replaceAllMapped(
      RegExp('(^| )$prefix'),
      (match) => '${match[1]}$_hiddenPrefix',
    );
    String restore(String text) {
      final restored = text.replaceAll(_hiddenPrefix, projectPrefix);
      return tokenText == null
          ? restored
          : restored.replaceAll(_hiddenProject, tokenText);
    }

    final second = _grammar.parse(hidden, now: now, mode: mode);
    return ParsedTaskText(
      text: restore(second.text),
      date: second.date,
      labels: first.labels,
      project: first.project,
      priority: second.priority,
      assignees: [for (final name in second.assignees) restore(name)],
      repeats: second.repeats,
      datePhrases: [for (final phrase in second.datePhrases) restore(phrase)],
      repeatPhrase: switch (second.repeatPhrase) {
        final phrase? => restore(phrase),
        null => null,
      },
    );
  }

  // Archived projects would refuse the task.
  List<Project> get _selectableProjects => [
    for (final row in selectableProjects(_snapshot.projects)) row.node.project,
  ];

  Label? _labelTitled(String title) {
    final lower = title.toLowerCase();
    for (final label in _snapshot.labels) {
      if (label.title.toLowerCase() == lower) return label;
    }
    return null;
  }

  /// A username is unique; a display name only counts when one known user
  /// has it.
  User? _knownUserNamed(String name) {
    final lower = name.toLowerCase();
    for (final user in _snapshot.knownUsers) {
      if (user.username.toLowerCase() == lower) return user;
    }
    final byName = [
      for (final user in _snapshot.knownUsers)
        if (user.name.isNotEmpty && user.name.toLowerCase() == lower) user,
    ];
    return byName.length == 1 ? byName.single : null;
  }
}

typedef _ReadyLine = ({
  QuickAddPlan plan,
  String title,
  List<User> assignees,
  List<String> unresolved,
});

bool _containsIgnoringCase(List<String> values, String value) {
  final lower = value.toLowerCase();
  return values.any((other) => other.toLowerCase() == lower);
}

/// The network part of one submit. The first `NetworkFailure` means the
/// device is offline: later searches and label creates are skipped instead
/// of each waiting for its own timeout.
final class _Submission {
  new({required this._users, required this._labels, required this._random});

  final UserRepository _users;
  final LabelRepository _labels;
  final Random _random;
  var _reachable = true;
  final _searches = <(int, String), User?>{};
  final _created = <String, Label>{};
  final List<String> labelsNotCreated = [];

  Label? createdLabel(String title) => _created[title.toLowerCase()];

  /// The user the server finds for [name] in [projectId]; not answered
  /// when the device is offline.
  Future<({bool answered, User? user})> searchAssignee(
    int projectId,
    String name,
  ) async {
    final key = (projectId, name.toLowerCase());
    if (_searches.containsKey(key)) {
      return (answered: true, user: _searches[key]);
    }
    if (!_reachable) return (answered: false, user: null);
    try {
      final user = _searches[key] = acceptSearchedAssignee(
        await _users.searchAssignees(projectId, name),
        name,
      );
      return (answered: true, user: user);
    } on NetworkFailure {
      _reachable = false;
      return (answered: false, user: null);
    } on VikunjaFailure catch (failure) {
      _log.fine('Assignee search failed: ${failure.runtimeType}');
      return (answered: true, user: _searches[key] = null);
    }
  }

  /// Each title once, whatever its case, adopting a label of that title the
  /// server has but this device has not synced yet; a title the server
  /// cannot take or a create that fails is reported, and the tasks go
  /// without it.
  Future<void> createLabels(List<String> titles) async {
    final unique = <String>[];
    for (final title in titles) {
      if (!_containsIgnoringCase(unique, title)) unique.add(title);
    }
    for (final title in unique) {
      if (!_reachable || title.runes.length > maxLabelTitleLength) {
        labelsNotCreated.add(title);
        continue;
      }
      try {
        _created[title.toLowerCase()] = await _labels.findOrCreate(
          NewLabel(title: title, hexColor: randomLabelColor(_random)),
        );
      } on VikunjaFailure catch (failure) {
        if (failure is NetworkFailure) _reachable = false;
        _log.fine('Label create failed: ${failure.runtimeType}');
        labelsNotCreated.add(title);
      }
    }
  }
}

/// The web's rule for a `@name` searched on the server: a single result is
/// taken when its username, name or email contains the name, of several
/// the one where one of them equals it; all ignoring case.
User? acceptSearchedAssignee(List<User> found, String name) {
  final lower = name.toLowerCase();
  Iterable<String> fieldsOf(User user) => [
    user.username,
    user.name,
    ?user.email,
  ].map((field) => field.toLowerCase());
  if (found.length == 1) {
    final user = found.single;
    return fieldsOf(user).any((field) => field.contains(lower)) ? user : null;
  }
  for (final user in found) {
    if (fieldsOf(user).any((field) => field == lower)) return user;
  }
  return null;
}
