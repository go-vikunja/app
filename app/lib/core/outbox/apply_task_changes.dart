import 'package:drift/drift.dart' show Value;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';

/// [row] with [changes] applied, as the server would store them: marking
/// done sets `done_at` to [now] unless the row already has one, undoing
/// clears it.
TaskRow applyTaskChanges(
  TaskRow row,
  TaskChanges changes, {
  required DateTime now,
}) => row.copyWith(
  title: changes.title,
  description: changes.description,
  done: changes.done,
  doneAt: switch (changes.done) {
    null => const Value.absent(),
    true => Value(row.doneAt ?? now.toUtc()),
    false => const Value(null),
  },
  isFavorite: changes.isFavorite,
  priority: changes.priority,
  percentDone: changes.percentDone,
  hexColor: changes.hexColor,
  dueDate: _date(changes.dueDate),
  startDate: _date(changes.startDate),
  endDate: _date(changes.endDate),
  repeatAfter: changes.repeatAfter?.inSeconds,
  repeatMode: changes.repeatMode?.value,
  projectId: changes.projectId,
);

/// [task] with [changes] folded into the create, for an edit of a task the
/// server has not been asked for yet. `done`, labels, assignees,
/// relations, kanban placements and list positions are not among a new
/// task's fields and are left out; see [changesAfterCreate].
NewTask applyChangesToNewTask(NewTask task, TaskChanges changes) => NewTask(
  projectId: changes.projectId ?? task.projectId,
  title: changes.title ?? task.title,
  description: changes.description ?? task.description,
  dueDate: _newDate(changes.dueDate, task.dueDate),
  startDate: _newDate(changes.startDate, task.startDate),
  endDate: _newDate(changes.endDate, task.endDate),
  priority: switch (changes.priority) {
    final value? => TaskPriority.fromValue(value),
    null => task.priority,
  },
  percentDone: changes.percentDone ?? task.percentDone,
  hexColor: changes.hexColor ?? task.hexColor,
  repeatAfter: changes.repeatAfter ?? task.repeatAfter,
  repeatMode: changes.repeatMode ?? task.repeatMode,
  isFavorite: changes.isFavorite ?? task.isFavorite,
  reminders: changes.reminders ?? task.reminders,
);

/// What of [changes] a create cannot carry: an update queued behind it,
/// sent once the server has named the task. The server ignores labels in
/// a create body, and labels, assignees, relations, kanban placements and
/// list positions go through their own endpoints, which need the task's
/// id; a cover names one of the task's attachments, which only exist
/// after the create.
TaskChanges changesAfterCreate(TaskChanges changes) => TaskChanges(
  done: changes.done,
  labels: changes.labels,
  assignees: changes.assignees,
  relations: changes.relations,
  kanban: changes.kanban,
  positions: changes.positions,
  coverImageAttachmentId: changes.coverImageAttachmentId,
);

/// [changes] without any change to the labels in [labelIds].
TaskChanges withoutLabels(TaskChanges changes, Set<int> labelIds) {
  final labels = switch (changes.labels) {
    IdSetChange(:final added, :final removed) => IdSetChange(
      added: added.difference(labelIds),
      removed: removed.difference(labelIds),
    ),
    null => null,
  };
  return _rebuilt(
    changes,
    labels: (labels?.isEmpty ?? true) ? null : labels,
    relations: changes.relations,
    kanban: changes.kanban,
    positions: changes.positions,
  );
}

/// [changes] with its relation change replaced by [relations]; an empty one
/// is left out.
TaskChanges withRelations(TaskChanges changes, RelationChange? relations) =>
    _rebuilt(
      changes,
      labels: changes.labels,
      relations: (relations?.isEmpty ?? true) ? null : relations,
      kanban: changes.kanban,
      positions: changes.positions,
    );

/// [changes] without kanban placements and list positions, which a project
/// move makes moot: they name the previous project's views.
TaskChanges withoutPlacements(TaskChanges changes) => _rebuilt(
  changes,
  labels: changes.labels,
  relations: changes.relations,
  kanban: null,
  positions: null,
);

/// [changes] without any edge to the tasks in [taskIds].
TaskChanges withoutRelatedTasks(TaskChanges changes, Set<int> taskIds) {
  final relations = changes.relations;
  if (relations == null) return changes;
  bool kept(TaskRelationRef ref) => !taskIds.contains(ref.otherTaskId);
  return withRelations(
    changes,
    RelationChange(
      added: relations.added.where(kept).toSet(),
      removed: relations.removed.where(kept).toSet(),
    ),
  );
}

/// Every other-task id [changes] names in its relations.
Set<int> relatedTaskIds(TaskChanges changes) => {
  for (final ref in [
    ...?changes.relations?.added,
    ...?changes.relations?.removed,
  ])
    ref.otherTaskId,
};

/// [changes] checked against [base] from now on: the user chose their
/// description over [base], the one changed on the web they saw, but not
/// over a change made after that.
TaskChanges withDescriptionBase(TaskChanges changes, String base) => _rebuilt(
  changes,
  description: (html: changes.description, base: base, toggles: null),
  labels: changes.labels,
  relations: changes.relations,
  kanban: changes.kanban,
  positions: changes.positions,
);

/// [changes] without their description: the user chose the server's.
TaskChanges withoutDescription(TaskChanges changes) => _rebuilt(
  changes,
  description: (html: null, base: null, toggles: null),
  labels: changes.labels,
  relations: changes.relations,
  kanban: changes.kanban,
  positions: changes.positions,
);

/// A [description] of null keeps the description, its base and its taps.
TaskChanges _rebuilt(
  TaskChanges changes, {
  required IdSetChange? labels,
  required RelationChange? relations,
  required Map<int, BucketPlacement>? kanban,
  required Map<int, double>? positions,
  ({String? html, String? base, List<ChecklistToggle>? toggles})? description,
}) => TaskChanges(
  title: changes.title,
  description: description == null ? changes.description : description.html,
  descriptionBase: description == null
      ? changes.descriptionBase
      : description.base,
  checklistToggles: description == null
      ? changes.checklistToggles
      : description.toggles,
  done: changes.done,
  isFavorite: changes.isFavorite,
  priority: changes.priority,
  percentDone: changes.percentDone,
  hexColor: changes.hexColor,
  dueDate: changes.dueDate,
  startDate: changes.startDate,
  endDate: changes.endDate,
  repeatAfter: changes.repeatAfter,
  repeatMode: changes.repeatMode,
  projectId: changes.projectId,
  labels: labels,
  assignees: changes.assignees,
  reminders: changes.reminders,
  relations: relations,
  kanban: kanban,
  positions: positions,
  coverImageAttachmentId: changes.coverImageAttachmentId,
);

bool changesDates(TaskChanges changes) =>
    changes.dueDate != null ||
    changes.startDate != null ||
    changes.endDate != null;

/// [reminders] with the instant of every relative one computed from the
/// task's dates as the server computes it: the referenced date plus the
/// period, null while that date is unset. Absolute ones are kept.
List<TaskReminder> withLocalInstants(
  List<TaskReminder> reminders, {
  required DateTime? dueDate,
  required DateTime? startDate,
  required DateTime? endDate,
}) => [
  for (final reminder in reminders)
    switch (reminder.relativeTo) {
      null => reminder,
      final relativeTo => TaskReminder(
        reminder: switch (relativeTo) {
          ReminderRelativeTo.dueDate => dueDate,
          ReminderRelativeTo.startDate => startDate,
          ReminderRelativeTo.endDate => endDate,
        }?.toUtc().add(reminder.relativePeriod),
        relativePeriod: reminder.relativePeriod,
        relativeTo: relativeTo,
      ),
    },
];

DateTime? _newDate(DateChange? change, DateTime? current) => switch (change) {
  null => current,
  SetDate(:final value) => value.toUtc(),
  ClearDate() => null,
};

Value<DateTime?> _date(DateChange? change) => switch (change) {
  null => const Value.absent(),
  SetDate(:final value) => Value(value.toUtc()),
  ClearDate() => const Value(null),
};
