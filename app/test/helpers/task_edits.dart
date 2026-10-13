import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/outbox/task_relation_inverse.dart';

const _unset = Object();

/// [task] with the given fields replaced; a nullable field passed as null
/// is cleared, one left out stays. Dates are stored in UTC, like the rows.
Task copyTask(
  Task task, {
  String? title,
  int? projectId,
  String? description,
  bool? done,
  Object? doneAt = _unset,
  Object? dueDate = _unset,
  Object? startDate = _unset,
  Object? endDate = _unset,
  TaskPriority? priority,
  double? percentDone,
  String? hexColor,
  bool? isFavorite,
  Duration? repeatAfter,
  RepeatMode? repeatMode,
  Object? updated = _unset,
  List<Label>? labels,
  List<User>? assignees,
  List<TaskReminder>? reminders,
}) => task.copyWith(
  title: title,
  projectId: projectId,
  description: description,
  done: done,
  doneAt: _date(doneAt, task.doneAt),
  dueDate: _date(dueDate, task.dueDate),
  startDate: _date(startDate, task.startDate),
  endDate: _date(endDate, task.endDate),
  priority: priority,
  percentDone: percentDone,
  hexColor: hexColor,
  isFavorite: isFavorite,
  repeatAfter: repeatAfter,
  repeatMode: repeatMode,
  labels: labels,
  assignees: assignees,
  reminders: reminders,
  updated: _date(updated, task.updated),
);

/// The same task under another id, as a remap moves it.
Task taskWithId(Task task, int id) => Task(
  id: id,
  title: task.title,
  projectId: task.projectId,
  description: task.description,
  done: task.done,
  doneAt: task.doneAt,
  dueDate: task.dueDate,
  startDate: task.startDate,
  endDate: task.endDate,
  priority: task.priority,
  percentDone: task.percentDone,
  hexColor: task.hexColor,
  identifier: task.identifier,
  index: task.index,
  isFavorite: task.isFavorite,
  position: task.position,
  labels: task.labels,
  assignees: task.assignees,
  reminders: task.reminders,
  repeatAfter: task.repeatAfter,
  repeatMode: task.repeatMode,
  relatedTasks: task.relatedTasks,
  bucketId: task.bucketId,
  createdBy: task.createdBy,
  created: task.created,
  updated: task.updated,
);

/// What the server stores for a create: [id] and [index] assigned, the
/// identifier `-<index>` of a project without a prefix, timestamps [now],
/// the instants of relative reminders computed.
Task taskFromNewTask(
  NewTask task, {
  required int id,
  required DateTime now,
  int? index,
}) => Task(
  id: id,
  title: task.title,
  projectId: task.projectId,
  description: task.description,
  dueDate: task.dueDate?.toUtc(),
  startDate: task.startDate?.toUtc(),
  endDate: task.endDate?.toUtc(),
  priority: task.priority,
  percentDone: task.percentDone,
  hexColor: task.hexColor,
  identifier: '-${index ?? id}',
  index: index ?? id,
  isFavorite: task.isFavorite,
  repeatAfter: task.repeatAfter,
  repeatMode: task.repeatMode,
  reminders: _withInstants(
    task.reminders,
    due: task.dueDate,
    start: task.startDate,
    end: task.endDate,
  ),
  created: now.toUtc(),
  updated: now.toUtc(),
);

/// [changes] applied as the server stores them: a label or assignee added
/// is taken from [labels] or [users], else from the task; an id found in
/// neither is skipped. Reminders are replaced, and the instants of relative
/// ones follow the dates.
Task applyChangesToTask(
  Task task,
  TaskChanges changes, {
  required DateTime now,
  Map<int, Label> labels = const {},
  Map<int, User> users = const {},
}) {
  final changed = _applyFields(task, changes, now: now);
  return changed.copyWith(
    labels: _applyIds(changes.labels, task.labels, (label) => label.id, labels),
    assignees: _applyIds(
      changes.assignees,
      task.assignees,
      (user) => user.id,
      users,
    ),
    reminders:
        changes.reminders == null &&
            changes.dueDate == null &&
            changes.startDate == null &&
            changes.endDate == null
        ? task.reminders
        : _withInstants(
            changes.reminders ?? task.reminders,
            due: changed.dueDate,
            start: changed.startDate,
            end: changed.endDate,
          ),
  );
}

Task _applyFields(Task task, TaskChanges changes, {required DateTime now}) =>
    copyTask(
      task,
      title: changes.title,
      projectId: changes.projectId,
      description: changes.description,
      done: changes.done,
      doneAt: switch (changes.done) {
        null => _unset,
        true => task.doneAt ?? now,
        false => null,
      },
      dueDate: _changed(changes.dueDate),
      startDate: _changed(changes.startDate),
      endDate: _changed(changes.endDate),
      priority: switch (changes.priority) {
        final value? => TaskPriority.fromValue(value),
        null => null,
      },
      percentDone: changes.percentDone,
      hexColor: changes.hexColor,
      isFavorite: changes.isFavorite,
      repeatAfter: changes.repeatAfter,
      repeatMode: changes.repeatMode,
      updated: now,
    );

List<T> _applyIds<T>(
  IdSetChange? change,
  List<T> current,
  int Function(T item) idOf,
  Map<int, T> known,
) {
  if (change == null) return current;
  final kept = [
    for (final item in current)
      if (!change.removed.contains(idOf(item))) item,
  ];
  return [
    ...kept,
    for (final id in change.added.toList()..sort())
      if (!kept.any((item) => idOf(item) == id))
        ?(known[id] ?? current.where((item) => idOf(item) == id).firstOrNull),
  ];
}

/// The server's rule: a relative reminder's instant is its date plus the
/// period, none while that date is unset.
List<TaskReminder> _withInstants(
  List<TaskReminder> reminders, {
  required DateTime? due,
  required DateTime? start,
  required DateTime? end,
}) => [
  for (final reminder in reminders)
    if (reminder.relativeTo case final relativeTo?)
      TaskReminder(
        reminder: switch (relativeTo) {
          ReminderRelativeTo.dueDate => due,
          ReminderRelativeTo.startDate => start,
          ReminderRelativeTo.endDate => end,
        }?.toUtc().add(reminder.relativePeriod),
        relativePeriod: reminder.relativePeriod,
        relativeTo: relativeTo,
      )
    else
      TaskReminder(reminder: reminder.reminder?.toUtc()),
];

/// What the server does to a repeating task marked done: open again with
/// the dates and absolute reminders moved on, relative reminders following
/// the dates, `done_at` set to now.
Task reopenRepeating(Task task, {required DateTime now}) {
  DateTime? shifted(DateTime? date) {
    if (date == null) return null;
    return switch (task.repeatMode) {
      RepeatMode.afterAmount => date.add(task.repeatAfter),
      RepeatMode.monthly => DateTime.utc(
        date.year,
        date.month + 1,
        date.day,
        date.hour,
        date.minute,
        date.second,
      ),
      RepeatMode.fromCurrentDate => now.add(task.repeatAfter),
    };
  }

  final reopened = copyTask(
    task,
    done: false,
    doneAt: now,
    dueDate: shifted(task.dueDate),
    startDate: shifted(task.startDate),
    endDate: shifted(task.endDate),
    updated: now,
  );
  return reopened.copyWith(
    reminders: _withInstants(
      [
        for (final reminder in task.reminders)
          if (reminder.isRelative)
            reminder
          else
            TaskReminder(reminder: shifted(reminder.reminder)),
      ],
      due: reopened.dueDate,
      start: reopened.startDate,
      end: reopened.endDate,
    ),
  );
}

DateTime? _date(Object? value, DateTime? current) => switch (value) {
  _unset => current,
  final DateTime date => date.toUtc(),
  _ => null,
};

Object? _changed(DateChange? change) => switch (change) {
  null => _unset,
  SetDate(:final value) => value,
  ClearDate() => null,
};

/// [all] with [change] applied to the task [taskId] and its inverse to the
/// other tasks it names, as the server stores relations; a related task
/// appears shallow (without relations of its own), and an edge to a task
/// not in [all] is skipped.
List<Task> applyRelationChange(
  List<Task> all,
  int taskId,
  RelationChange change,
) {
  final byId = {for (final task in all) task.id: task};
  final source = byId[taskId];
  if (source == null) return all;
  Task edges(Task task, RelationChange delta, Task? Function(int id) find) {
    final related = {
      for (final MapEntry(:key, :value) in task.relatedTasks.entries)
        key: [...value],
    };
    for (final ref in delta.removed) {
      related[ref.kind]?.removeWhere((other) => other.id == ref.otherTaskId);
    }
    for (final ref in delta.added) {
      final other = find(ref.otherTaskId);
      final list = related.putIfAbsent(ref.kind, () => []);
      if (other == null || list.any((known) => known.id == other.id)) {
        continue;
      }
      list.add(other.copyWith(relatedTasks: const {}));
    }
    related.removeWhere((_, others) => others.isEmpty);
    return task.copyWith(relatedTasks: related);
  }

  RelationChange inverseFor(int otherId) => RelationChange(
    added: {
      for (final ref in change.added)
        if (ref.otherTaskId == otherId)
          TaskRelationRef(inverseRelationKind(ref.kind), taskId),
    },
    removed: {
      for (final ref in change.removed)
        if (ref.otherTaskId == otherId)
          TaskRelationRef(inverseRelationKind(ref.kind), taskId),
    },
  );

  final named = {
    for (final ref in [...change.added, ...change.removed]) ref.otherTaskId,
  };
  return [
    for (final task in all)
      if (task.id == taskId)
        edges(task, change, (id) => byId[id])
      else if (named.contains(task.id) && task.id != taskId)
        edges(task, inverseFor(task.id), (id) => id == taskId ? source : null)
      else
        task,
  ];
}
