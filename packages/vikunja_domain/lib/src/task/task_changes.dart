import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/kanban/bucket_placement.dart';
import 'package:vikunja_domain/src/task/checklist_toggle.dart';
import 'package:vikunja_domain/src/task/id_set_change.dart';
import 'package:vikunja_domain/src/task/relation_change.dart';
import 'package:vikunja_domain/src/task/task.dart';
import 'package:vikunja_domain/src/task/task_reminder.dart';

/// A date field edit: set to an instant or cleared. Null in [TaskChanges]
/// means "unchanged".
@immutable
sealed class DateChange {
  const new();

  const factory set(DateTime value) = SetDate;

  const factory clear() = ClearDate;
}

final class SetDate extends DateChange {
  const new(this.value);

  final DateTime value;

  @override
  bool operator ==(Object other) => other is SetDate && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final class ClearDate extends DateChange {
  const new();

  @override
  bool operator ==(Object other) => other is ClearDate;

  @override
  int get hashCode => 0;
}

/// The fields of one task edit. Every null field is left as it is on the
/// server; the adapters send only what is set (v2 merge-patch) or overlay
/// it on a fresh read (v1 full replace).
@immutable
final class TaskChanges {
  const new({
    this.title,
    this.description,
    this.descriptionBase,
    this.checklistToggles,
    this.done,
    this.isFavorite,
    this.priority,
    this.percentDone,
    this.hexColor,
    this.dueDate,
    this.startDate,
    this.endDate,
    this.repeatAfter,
    this.repeatMode,
    this.projectId,
    this.labels,
    this.assignees,
    this.reminders,
    this.relations,
    this.kanban,
    this.positions,
    this.coverImageAttachmentId,
  });

  final String? title;
  final String? description;

  /// The description the first unsent change of [description] started
  /// from, never sent: when the server's differs at send time, someone
  /// changed it meanwhile. Null sends [description] unchecked.
  final String? descriptionBase;

  /// Set when [description] differs from [descriptionBase] only by these
  /// checkbox taps, in order, so they can be applied again to a description
  /// changed meanwhile; null for an edit in the editor.
  final List<ChecklistToggle>? checklistToggles;

  final bool? done;
  final bool? isFavorite;
  final int? priority;
  final double? percentDone;
  final String? hexColor;
  final DateChange? dueDate;
  final DateChange? startDate;
  final DateChange? endDate;

  /// `Duration.zero` with [RepeatMode.afterAmount] removes the repeat.
  final Duration? repeatAfter;
  final RepeatMode? repeatMode;

  /// Moves the task; the server reassigns `index` and `identifier`.
  final int? projectId;

  /// Label ids to attach and detach, through the task's label endpoints.
  final IdSetChange? labels;

  /// User ids to assign and unassign, through the task's assignee
  /// endpoints.
  final IdSetChange? assignees;

  /// The task's whole reminder list; empty removes every reminder.
  final List<TaskReminder>? reminders;

  /// Relations to add and remove from this task's side, through the task's
  /// relation endpoints; the server keeps the inverse edges.
  final RelationChange? relations;

  /// Bucket placements by project view id, sent through the kanban
  /// endpoints after the body; the server bumps no `updated` for them.
  final Map<int, BucketPlacement>? kanban;

  /// List positions by project view id, sent through the task's position
  /// endpoint after [kanban]; the server bumps no `updated` for them.
  final Map<int, double>? positions;

  /// Any attachment of the task, or 0 to clear the cover. The server keeps
  /// the id of a deleted cover and then refuses every update that does not
  /// clear it (400 code 4020).
  final int? coverImageAttachmentId;

  bool get isEmpty =>
      title == null &&
      description == null &&
      done == null &&
      isFavorite == null &&
      priority == null &&
      percentDone == null &&
      hexColor == null &&
      dueDate == null &&
      startDate == null &&
      endDate == null &&
      repeatAfter == null &&
      repeatMode == null &&
      projectId == null &&
      (labels?.isEmpty ?? true) &&
      (assignees?.isEmpty ?? true) &&
      reminders == null &&
      (relations?.isEmpty ?? true) &&
      (kanban?.isEmpty ?? true) &&
      (positions?.isEmpty ?? true) &&
      coverImageAttachmentId == null;

  /// [later] wins where both set a field. A project move in [later] drops
  /// the earlier placements and positions: they name the previous
  /// project's views, and the server puts a moved task on top of the new
  /// project's views. A [done] in [later] that differs from this one's
  /// drops the earlier placements too: the moves go after the body, and
  /// one into or out of a done bucket would set the done state back. List
  /// positions do not touch the done state, so they stay. The earliest
  /// description base stays, and taps stay taps only while every
  /// description change was one.
  TaskChanges merge(TaskChanges later) => TaskChanges(
    title: later.title ?? title,
    description: later.description ?? description,
    descriptionBase: description != null
        ? descriptionBase
        : later.descriptionBase,
    checklistToggles: switch ((description, later.description)) {
      (_, null) => checklistToggles,
      (null, _) => later.checklistToggles,
      _ => switch ((checklistToggles, later.checklistToggles)) {
        (final earlier?, final later?) => [...earlier, ...later],
        _ => null,
      },
    },
    done: later.done ?? done,
    isFavorite: later.isFavorite ?? isFavorite,
    priority: later.priority ?? priority,
    percentDone: later.percentDone ?? percentDone,
    hexColor: later.hexColor ?? hexColor,
    dueDate: later.dueDate ?? dueDate,
    startDate: later.startDate ?? startDate,
    endDate: later.endDate ?? endDate,
    repeatAfter: later.repeatAfter ?? repeatAfter,
    repeatMode: later.repeatMode ?? repeatMode,
    projectId: later.projectId ?? projectId,
    labels: _mergeSets(labels, later.labels),
    assignees: _mergeSets(assignees, later.assignees),
    reminders: later.reminders ?? reminders,
    relations: switch ((relations, later.relations)) {
      (final earlier?, final later?) => earlier.merge(later),
      (final earlier, null) => earlier,
      (null, final later) => later,
    },
    kanban: switch ((kanban, later.kanban)) {
      _
          when later.projectId != null ||
              (later.done != null && later.done != done) =>
        later.kanban,
      (final earlier?, final later?) => {...earlier, ...later},
      (final earlier, null) => earlier,
      (null, final later) => later,
    },
    positions: switch ((positions, later.positions)) {
      _ when later.projectId != null => later.positions,
      (final earlier?, final later?) => {...earlier, ...later},
      (final earlier, null) => earlier,
      (null, final later) => later,
    },
    coverImageAttachmentId:
        later.coverImageAttachmentId ?? coverImageAttachmentId,
  );

  static IdSetChange? _mergeSets(IdSetChange? earlier, IdSetChange? later) =>
      switch ((earlier, later)) {
        (final earlier?, final later?) => earlier.merge(later),
        (final earlier, null) => earlier,
        (null, final later) => later,
      };

  @override
  bool operator ==(Object other) =>
      other is TaskChanges &&
      other.title == title &&
      other.description == description &&
      other.descriptionBase == descriptionBase &&
      _sameLists(other.checklistToggles, checklistToggles) &&
      other.done == done &&
      other.isFavorite == isFavorite &&
      other.priority == priority &&
      other.percentDone == percentDone &&
      other.hexColor == hexColor &&
      other.dueDate == dueDate &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.repeatAfter == repeatAfter &&
      other.repeatMode == repeatMode &&
      other.projectId == projectId &&
      other.labels == labels &&
      other.assignees == assignees &&
      _sameLists(other.reminders, reminders) &&
      other.relations == relations &&
      _sameMaps(other.kanban, kanban) &&
      _sameMaps(other.positions, positions) &&
      other.coverImageAttachmentId == coverImageAttachmentId;

  static bool _sameLists<T>(List<T>? a, List<T>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameMaps<V>(Map<int, V>? a, Map<int, V>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    return a.entries.every((entry) => b[entry.key] == entry.value);
  }

  static int? _hashMap<V>(Map<int, V>? map) => switch (map) {
    final map? => Object.hashAllUnordered(
      map.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    null => null,
  };

  @override
  int get hashCode => Object.hash(
    title,
    Object.hash(description, descriptionBase, switch (checklistToggles) {
      final list? => Object.hashAll(list),
      null => null,
    }),
    done,
    isFavorite,
    priority,
    percentDone,
    hexColor,
    dueDate,
    startDate,
    endDate,
    repeatAfter,
    repeatMode,
    projectId,
    labels,
    assignees,
    switch (reminders) {
      final list? => Object.hashAll(list),
      null => null,
    },
    relations,
    _hashMap(kanban),
    _hashMap(positions),
    coverImageAttachmentId,
  );

  /// Names the fields set, without user text such as the title.
  @override
  String toString() {
    final fields = [
      if (title != null) 'title',
      if (description != null) 'description',
      if (descriptionBase != null) 'descriptionBase',
      if (checklistToggles != null)
        'checklistToggles: ${checklistToggles!.length}',
      if (done != null) 'done: $done',
      if (isFavorite != null) 'isFavorite: $isFavorite',
      if (priority != null) 'priority: $priority',
      if (percentDone != null) 'percentDone: $percentDone',
      if (hexColor != null) 'hexColor',
      if (dueDate != null) 'dueDate',
      if (startDate != null) 'startDate',
      if (endDate != null) 'endDate',
      if (repeatAfter != null) 'repeatAfter: $repeatAfter',
      if (repeatMode != null) 'repeatMode: ${repeatMode!.name}',
      if (projectId != null) 'projectId: $projectId',
      if (labels != null) 'labels: $labels',
      if (assignees != null) 'assignees: $assignees',
      if (reminders != null) 'reminders: ${reminders!.length}',
      if (relations != null) 'relations',
      if (kanban != null) 'kanban: $kanban',
      if (positions != null) 'positions: $positions',
      if (coverImageAttachmentId != null)
        'coverImageAttachmentId: $coverImageAttachmentId',
    ];
    return 'TaskChanges(${fields.join(', ')})';
  }
}
