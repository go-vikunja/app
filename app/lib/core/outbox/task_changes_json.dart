import 'dart:convert';

import 'package:vikunja_domain/vikunja_domain.dart';

/// `TaskChanges` as stored in the outbox and in `tasks.pending_changes`:
/// the wire names, absent for unchanged, an empty string for a cleared date,
/// label and assignee deltas as `{"added": [...], "removed": [...]}`,
/// relation deltas as `{"added": [{"kind", "other"}], "removed": [...]}`,
/// kanban placements as `{"<view id>": {"bucket_id", "position"}}`
/// (`position` absent to keep the server's), list positions as
/// `{"<view id>": <position>}`, and the description's base and checkbox
/// taps as `description_base` and `checklist_toggles`
/// (`[{"item_id", "checked"}]` or `[{"ordinal", "text", "checked"}]`),
/// which are never sent.
String encodeTaskChanges(TaskChanges changes) =>
    jsonEncode(taskChangesToJson(changes));

TaskChanges decodeTaskChanges(String json) => switch (jsonDecode(json)) {
  final Map<String, Object?> map => taskChangesFromJson(map),
  _ => const TaskChanges(),
};

Map<String, Object?> taskChangesToJson(TaskChanges changes) => {
  'title': ?changes.title,
  'description': ?changes.description,
  'description_base': ?changes.descriptionBase,
  if (changes.checklistToggles case final toggles?)
    'checklist_toggles': _togglesJson(toggles),
  'done': ?changes.done,
  'is_favorite': ?changes.isFavorite,
  'priority': ?changes.priority,
  'percent_done': ?changes.percentDone,
  'hex_color': ?changes.hexColor,
  if (changes.dueDate case final date?) 'due_date': _dateJson(date),
  if (changes.startDate case final date?) 'start_date': _dateJson(date),
  if (changes.endDate case final date?) 'end_date': _dateJson(date),
  'repeat_after': ?changes.repeatAfter?.inSeconds,
  'repeat_mode': ?changes.repeatMode?.value,
  'project_id': ?changes.projectId,
  if (changes.labels case final labels?) 'labels': _idSetJson(labels),
  if (changes.assignees case final assignees?)
    'assignees': _idSetJson(assignees),
  if (changes.reminders case final reminders?)
    'reminders': remindersToJson(reminders),
  if (changes.relations case final relations?)
    'relations': _relationsJson(relations),
  if (changes.kanban case final kanban?) 'kanban': _kanbanJson(kanban),
  if (changes.positions case final positions?)
    'positions': _positionsJson(positions),
  'cover_image_attachment_id': ?changes.coverImageAttachmentId,
};

TaskChanges taskChangesFromJson(Map<String, Object?> json) => TaskChanges(
  title: json['title'] as String?,
  description: json['description'] as String?,
  descriptionBase: json['description_base'] as String?,
  checklistToggles: _toggles(json['checklist_toggles']),
  done: json['done'] as bool?,
  isFavorite: json['is_favorite'] as bool?,
  priority: json['priority'] as int?,
  percentDone: (json['percent_done'] as num?)?.toDouble(),
  hexColor: json['hex_color'] as String?,
  dueDate: _dateChange(json['due_date']),
  startDate: _dateChange(json['start_date']),
  endDate: _dateChange(json['end_date']),
  repeatAfter: switch (json['repeat_after']) {
    final int seconds => Duration(seconds: seconds),
    _ => null,
  },
  repeatMode: switch (json['repeat_mode']) {
    final int value => RepeatMode.fromValue(value),
    _ => null,
  },
  projectId: json['project_id'] as int?,
  labels: _idSetChange(json['labels']),
  assignees: _idSetChange(json['assignees']),
  reminders: switch (json['reminders']) {
    final List<Object?> list => remindersFromJson(list),
    _ => null,
  },
  relations: _relationChange(json['relations']),
  kanban: _kanban(json['kanban']),
  positions: _positions(json['positions']),
  coverImageAttachmentId: json['cover_image_attachment_id'] as int?,
);

/// Instants in UTC; `reminder` is absent while a relative one has none.
List<Map<String, Object?>> remindersToJson(List<TaskReminder> reminders) => [
  for (final reminder in reminders)
    {
      'reminder': ?reminder.reminder?.toUtc().toIso8601String(),
      'relative_period': reminder.relativePeriod.inSeconds,
      'relative_to': ?reminder.relativeTo?.wireName,
    },
];

List<TaskReminder> remindersFromJson(List<Object?> json) => [
  for (final item in json)
    if (item is Map<String, Object?>)
      TaskReminder(
        reminder: switch (item['reminder']) {
          final String iso => DateTime.parse(iso).toUtc(),
          _ => null,
        },
        relativePeriod: Duration(seconds: item['relative_period'] as int? ?? 0),
        relativeTo: ReminderRelativeTo.fromWire(item['relative_to'] as String?),
      ),
];

List<Map<String, Object?>> _togglesJson(List<ChecklistToggle> toggles) => [
  for (final toggle in toggles)
    {
      'item_id': ?toggle.itemId,
      'ordinal': ?toggle.ordinal,
      'text': ?toggle.text,
      'checked': toggle.checked,
    },
];

/// Null, as for an edit in the editor, when a tap cannot be read back: it
/// could not be applied again, so a changed description becomes a
/// conflict for the user to resolve.
List<ChecklistToggle>? _toggles(Object? value) {
  if (value is! List<Object?>) return null;
  final toggles = <ChecklistToggle>[];
  for (final item in value) {
    switch (item) {
      case {'item_id': final String itemId, 'checked': final bool checked}:
        toggles.add(ChecklistToggle.byId(itemId, checked: checked));
      case {
        'ordinal': final int ordinal,
        'text': final String text,
        'checked': final bool checked,
      }:
        toggles.add(
          ChecklistToggle.byPosition(
            ordinal: ordinal,
            text: text,
            checked: checked,
          ),
        );
      default:
        return null;
    }
  }
  return toggles;
}

Map<String, Object?> _idSetJson(IdSetChange change) => {
  'added': [...change.added]..sort(),
  'removed': [...change.removed]..sort(),
};

IdSetChange? _idSetChange(Object? value) => switch (value) {
  final Map<String, Object?> map => IdSetChange(
    added: _ids(map['added']),
    removed: _ids(map['removed']),
  ),
  _ => null,
};

Set<int> _ids(Object? value) => {
  if (value is List<Object?>)
    for (final id in value)
      if (id is int) id,
};

Map<String, Object?> _relationsJson(RelationChange change) => {
  'added': _refsJson(change.added),
  'removed': _refsJson(change.removed),
};

List<Map<String, Object?>> _refsJson(Set<TaskRelationRef> refs) => [
  for (final ref
      in [...refs]..sort(
        (a, b) => a.kind.index != b.kind.index
            ? a.kind.index.compareTo(b.kind.index)
            : a.otherTaskId.compareTo(b.otherTaskId),
      ))
    {'kind': ref.kind.wireName, 'other': ref.otherTaskId},
];

RelationChange? _relationChange(Object? value) => switch (value) {
  final Map<String, Object?> map => RelationChange(
    added: _refs(map['added']),
    removed: _refs(map['removed']),
  ),
  _ => null,
};

Set<TaskRelationRef> _refs(Object? value) => {
  if (value is List<Object?>)
    for (final item in value)
      if (item case {'kind': final String wire, 'other': final int other})
        if (TaskRelationKind.fromWire(wire) case final kind?)
          TaskRelationRef(kind, other),
};

Map<String, Object?> _kanbanJson(Map<int, BucketPlacement> kanban) => {
  for (final MapEntry(key: viewId, value: placement)
      in kanban.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
    '$viewId': {
      'bucket_id': placement.bucketId,
      'position': ?placement.position,
    },
};

Map<int, BucketPlacement>? _kanban(Object? value) => switch (value) {
  final Map<String, Object?> map => {
    for (final MapEntry(:key, :value) in map.entries)
      if ((int.tryParse(key), value) case (
        final viewId?,
        {'bucket_id': final int bucketId},
      ))
        viewId: BucketPlacement(
          bucketId: bucketId,
          position: switch (value) {
            {'position': final num position} => position.toDouble(),
            _ => null,
          },
        ),
  },
  _ => null,
};

Map<String, Object?> _positionsJson(Map<int, double> positions) => {
  for (final MapEntry(key: viewId, value: position)
      in positions.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
    '$viewId': position,
};

Map<int, double>? _positions(Object? value) => switch (value) {
  final Map<String, Object?> map => {
    for (final MapEntry(:key, :value) in map.entries)
      if ((int.tryParse(key), value) case (final viewId?, final num position))
        viewId: position.toDouble(),
  },
  _ => null,
};

String _dateJson(DateChange change) => switch (change) {
  SetDate(:final value) => value.toUtc().toIso8601String(),
  ClearDate() => '',
};

DateChange? _dateChange(Object? value) => switch (value) {
  '' => const DateChange.clear(),
  final String iso => DateChange.set(DateTime.parse(iso).toUtc()),
  _ => null,
};
