import 'package:drift/drift.dart' show Value;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/time/moments.dart';

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
  doneBase: changes.doneBase,
);

/// [changes] with [base] as the server's state before its Done was first
/// sent.
TaskChanges withDoneBase(TaskChanges changes, DoneBase base) => _rebuilt(
  changes,
  labels: changes.labels,
  relations: changes.relations,
  kanban: changes.kanban,
  positions: changes.positions,
  doneBase: base,
);

/// [changes] that can still be sent after the occurrence is complete.
TaskChanges withoutDoneAndSchedule(TaskChanges changes) => _rebuilt(
  changes,
  labels: changes.labels,
  relations: changes.relations,
  kanban: changes.kanban,
  positions: changes.positions,
  dropDone: true,
  dropSchedule: true,
);

/// The occurrence-specific edits not reflected in [current]. A completed
/// occurrence does not prove these landed: the server may have advanced
/// its old dates and reminders even if it took our combined request.
TaskChanges unmatchedSchedule(TaskChanges changes, Task current) {
  DateChange? unmatchedDate(DateChange? change, DateTime? actual) =>
      sameSecond(_newDate(change, actual), actual) ? null : change;

  final reminders = changes.reminders;
  return TaskChanges(
    dueDate: unmatchedDate(changes.dueDate, current.dueDate),
    startDate: unmatchedDate(changes.startDate, current.startDate),
    endDate: unmatchedDate(changes.endDate, current.endDate),
    reminders:
        reminders != null &&
            !sameReminders(
              withLocalInstants(
                reminders,
                dueDate: current.dueDate,
                startDate: current.startDate,
                endDate: current.endDate,
              ),
              current.reminders,
            )
        ? reminders
        : null,
  );
}

/// The fields of [changes] without a conflict check of their own that
/// differ from [current], whose cover is [coverImageAttachmentId]. After a
/// lost answer a differing one is ambiguous: it may never have landed, or
/// landed and was changed on the web since. A description with a base is
/// checked when it is sent, so it is not among them.
TaskChanges unmatchedBody(
  TaskChanges changes,
  Task current, {
  required int? coverImageAttachmentId,
}) {
  T? unmatched<T>(T? change, bool Function(T) same) =>
      change == null || same(change) ? null : change;

  return TaskChanges(
    title: unmatched(changes.title, (title) => title == current.title),
    description: changes.descriptionBase != null
        ? null
        : unmatched(
            changes.description,
            (description) => description == current.description,
          ),
    isFavorite: unmatched(
      changes.isFavorite,
      (favorite) => favorite == current.isFavorite,
    ),
    priority: unmatched(
      changes.priority,
      (priority) => priority == current.priority.value,
    ),
    percentDone: unmatched(
      changes.percentDone,
      (percent) => percent.clamp(0, 1) == current.percentDone,
    ),
    hexColor: unmatched(
      changes.hexColor,
      (color) => _hexColor(color) == _hexColor(current.hexColor),
    ),
    repeatAfter: unmatched(
      changes.repeatAfter,
      (after) => after.inSeconds == current.repeatAfter.inSeconds,
    ),
    repeatMode: unmatched(
      changes.repeatMode,
      (mode) => mode == current.repeatMode,
    ),
    projectId: unmatched(
      changes.projectId,
      (projectId) => projectId == current.projectId,
    ),
    coverImageAttachmentId: unmatched(
      changes.coverImageAttachmentId,
      (cover) => cover == coverImageAttachmentId,
    ),
  );
}

/// The server's values in [current], when a notice is made, of the fields
/// [held] holds back, so "Keep my version" can tell what changed since.
TaskChanges heldBaseOf(
  TaskChanges held,
  Task current, {
  required int? coverImageAttachmentId,
}) {
  T? base<T>(Object? field, T value) => field == null ? null : value;
  return TaskChanges(
    title: base(held.title, current.title),
    description: base(held.description, current.description),
    isFavorite: base(held.isFavorite, current.isFavorite),
    priority: base(held.priority, current.priority.value),
    percentDone: base(held.percentDone, current.percentDone),
    hexColor: base(held.hexColor, current.hexColor),
    repeatAfter: base(held.repeatAfter, current.repeatAfter),
    repeatMode: base(held.repeatMode, current.repeatMode),
    projectId: base(held.projectId, current.projectId),
    coverImageAttachmentId: held.coverImageAttachmentId == null
        ? null
        : coverImageAttachmentId,
  );
}

/// What a notice held back that "Keep my version" may apply: none of its
/// dates and reminders, which were set for the previous occurrence.
TaskChanges heldBody(TaskChanges held) => TaskChanges(
  title: held.title,
  description: held.description,
  isFavorite: held.isFavorite,
  priority: held.priority,
  percentDone: held.percentDone,
  hexColor: held.hexColor,
  repeatAfter: held.repeatAfter,
  repeatMode: held.repeatMode,
  projectId: held.projectId,
  coverImageAttachmentId: held.coverImageAttachmentId,
);

/// The fields of [heldBody] whose value in [current] is still the server's
/// [base] from when the notice was made: one changed since, here or on the
/// web, or without a recorded base, is left as it is. A description goes
/// with that base, so a web change by the time it is sent is a conflict.
TaskChanges stillApplicable(
  TaskChanges held,
  TaskChanges base,
  Task current, {
  required int? coverImageAttachmentId,
}) {
  final body = heldBody(held);
  final changed = unmatchedBody(
    base,
    current,
    coverImageAttachmentId: coverImageAttachmentId,
  );
  T? keep<T>(T? value, Object? baseValue, Object? changedValue) =>
      baseValue != null && changedValue == null ? value : null;
  final description = keep(
    body.description,
    base.description,
    changed.description,
  );
  return TaskChanges(
    title: keep(body.title, base.title, changed.title),
    description: description,
    descriptionBase: description == null ? null : base.description,
    isFavorite: keep(body.isFavorite, base.isFavorite, changed.isFavorite),
    priority: keep(body.priority, base.priority, changed.priority),
    percentDone: keep(body.percentDone, base.percentDone, changed.percentDone),
    hexColor: keep(body.hexColor, base.hexColor, changed.hexColor),
    repeatAfter: keep(body.repeatAfter, base.repeatAfter, changed.repeatAfter),
    repeatMode: keep(body.repeatMode, base.repeatMode, changed.repeatMode),
    projectId: keep(body.projectId, base.projectId, changed.projectId),
    coverImageAttachmentId: keep(
      body.coverImageAttachmentId,
      base.coverImageAttachmentId,
      changed.coverImageAttachmentId,
    ),
  );
}

/// [changes] without the fields [unmatchedBody] compares: after a lost
/// answer, those already on the server need not go again and the others
/// must not.
TaskChanges withoutBody(TaskChanges changes) => _rebuilt(
  changes,
  description: changes.descriptionBase == null
      ? (html: null, base: null, toggles: null)
      : null,
  labels: changes.labels,
  relations: changes.relations,
  kanban: changes.kanban,
  positions: changes.positions,
  dropBody: true,
);

/// As the server keeps it: six lowercase hex digits without `#`.
String _hexColor(String color) {
  var hex = color.trim().toLowerCase();
  if (hex.startsWith('#')) hex = hex.substring(1);
  return hex.length == 3
      ? hex.split('').map((digit) => '$digit$digit').join()
      : hex;
}

/// [changes] without their done base: the Done it was taken for was taken
/// back.
TaskChanges withoutDoneBase(TaskChanges changes) => _rebuilt(
  changes,
  labels: changes.labels,
  relations: changes.relations,
  kanban: changes.kanban,
  positions: changes.positions,
  dropDoneBase: true,
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

/// [changes] with the label ids of [mapping] replaced. An id then both
/// added and removed (a label swapped for its twin on the server) is an add
/// when [carried], the labels the task has now, holds it, else a removal.
TaskChanges withLabelIdsMapped(
  TaskChanges changes,
  Map<int, int> mapping, {
  required Set<int> carried,
}) {
  final labels = changes.labels;
  if (labels == null || mapping.isEmpty) return changes;
  int mapped(int id) => mapping[id] ?? id;
  final added = labels.added.map(mapped).toSet();
  final removed = labels.removed.map(mapped).toSet();
  final both = added.intersection(removed);
  final change = IdSetChange(
    added: added.difference(both.difference(carried)),
    removed: removed.difference(both.intersection(carried)),
  );
  return _rebuilt(
    changes,
    labels: change.isEmpty ? null : change,
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

TaskChanges withoutPlacementsOn(TaskChanges changes, Set<int> viewIds) {
  final kanban = {...?changes.kanban}
    ..removeWhere((viewId, _) => viewIds.contains(viewId));
  return _rebuilt(
    changes,
    labels: changes.labels,
    relations: changes.relations,
    kanban: kanban.isEmpty ? null : kanban,
    positions: changes.positions,
  );
}

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

/// [changes] without their cover: the attachment it names is gone from the
/// task.
TaskChanges withoutCover(TaskChanges changes) => _rebuilt(
  changes,
  labels: changes.labels,
  relations: changes.relations,
  kanban: changes.kanban,
  positions: changes.positions,
  dropCover: true,
);

/// A [description] of null keeps the description, its base and its taps;
/// a [doneBase] of null keeps the one of [changes] unless [dropDone] or
/// [dropDoneBase].
TaskChanges _rebuilt(
  TaskChanges changes, {
  required IdSetChange? labels,
  required RelationChange? relations,
  required Map<int, BucketPlacement>? kanban,
  required Map<int, double>? positions,
  ({String? html, String? base, List<ChecklistToggle>? toggles})? description,
  DoneBase? doneBase,
  bool dropDone = false,
  bool dropDoneBase = false,
  bool dropSchedule = false,
  bool dropCover = false,
  bool dropBody = false,
}) => TaskChanges(
  title: dropBody ? null : changes.title,
  description: description == null ? changes.description : description.html,
  descriptionBase: description == null
      ? changes.descriptionBase
      : description.base,
  checklistToggles: description == null
      ? changes.checklistToggles
      : description.toggles,
  done: dropDone ? null : changes.done,
  isFavorite: dropBody ? null : changes.isFavorite,
  priority: dropBody ? null : changes.priority,
  percentDone: dropBody ? null : changes.percentDone,
  hexColor: dropBody ? null : changes.hexColor,
  dueDate: dropSchedule ? null : changes.dueDate,
  startDate: dropSchedule ? null : changes.startDate,
  endDate: dropSchedule ? null : changes.endDate,
  repeatAfter: dropBody ? null : changes.repeatAfter,
  repeatMode: dropBody ? null : changes.repeatMode,
  projectId: dropBody ? null : changes.projectId,
  labels: labels,
  assignees: changes.assignees,
  reminders: dropSchedule ? null : changes.reminders,
  relations: relations,
  kanban: kanban,
  positions: positions,
  coverImageAttachmentId: dropCover || dropBody
      ? null
      : changes.coverImageAttachmentId,
  doneBase: dropDone || dropDoneBase ? null : doneBase ?? changes.doneBase,
);

bool changesDates(TaskChanges changes) =>
    changes.dueDate != null ||
    changes.startDate != null ||
    changes.endDate != null;

/// [reminders] with the instant of every relative one computed from the
/// task's dates as the server computes it: the referenced date plus the
/// period, null while that date is unset or when no date can hold the sum.
/// Absolute ones are kept. Every instant is in whole seconds, as the server
/// keeps them.
List<TaskReminder> withLocalInstants(
  List<TaskReminder> reminders, {
  required DateTime? dueDate,
  required DateTime? startDate,
  required DateTime? endDate,
}) => [
  for (final reminder in reminders)
    switch (reminder.relativeTo) {
      null => TaskReminder(
        reminder: _inWholeSeconds(reminder.reminder),
        relativePeriod: reminder.relativePeriod,
      ),
      final relativeTo => TaskReminder(
        reminder: _inWholeSeconds(
          relativeReminderInstant(
            switch (relativeTo) {
              ReminderRelativeTo.dueDate => dueDate,
              ReminderRelativeTo.startDate => startDate,
              ReminderRelativeTo.endDate => endDate,
            }?.toUtc(),
            reminder.relativePeriod,
          ),
        ),
        relativePeriod: reminder.relativePeriod,
        relativeTo: relativeTo,
      ),
    },
];

/// [instant] without the fraction of its second, in its own time zone: the
/// server keeps whole seconds, so a finer instant set here would read as
/// moved once the server's copy is synced, and its notification with it.
DateTime inWholeSeconds(DateTime instant) => instant.subtract(
  Duration(
    microseconds:
        instant.microsecondsSinceEpoch % Duration.microsecondsPerSecond,
  ),
);

DateTime? _inWholeSeconds(DateTime? instant) =>
    instant == null ? null : inWholeSeconds(instant);

DateTime? _newDate(DateChange? change, DateTime? current) => switch (change) {
  null => current,
  SetDate(:final value) => inWholeSeconds(value.toUtc()),
  ClearDate() => null,
};

Value<DateTime?> _date(DateChange? change) => switch (change) {
  null => const Value.absent(),
  SetDate(:final value) => Value(inWholeSeconds(value.toUtc())),
  ClearDate() => const Value(null),
};
