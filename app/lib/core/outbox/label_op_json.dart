import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// A label create as queued in the outbox.
@immutable
final class QueuedLabelCreate {
  const new({required this.label, this.adopt = false, this.known = const {}});

  final NewLabel label;

  /// From `findOrCreate`: a label the server already has under the title,
  /// ignoring case, is taken instead of making one.
  final bool adopt;

  /// The labels of exactly this title the device had when the create was
  /// queued. A lost answer's lookup never takes one of them; a label the
  /// sync brought later may be the one the lost request made.
  final Set<int> known;

  /// [alsoKnown] joins [known]: the labels of a new title the device has.
  QueuedLabelCreate withChanges(
    LabelChanges changes, {
    Set<int> alsoKnown = const {},
  }) => QueuedLabelCreate(
    label: NewLabel(
      title: changes.title ?? label.title,
      hexColor: changes.hexColor ?? label.hexColor,
      description: changes.description ?? label.description,
    ),
    adopt: adopt,
    known: {...known, ...alsoKnown},
  );

  @override
  bool operator ==(Object other) =>
      other is QueuedLabelCreate &&
      other.label == label &&
      other.adopt == adopt &&
      setEquals(other.known, known);

  @override
  int get hashCode => Object.hash(label, adopt, Object.hashAllUnordered(known));
}

String encodeLabelCreate(QueuedLabelCreate create) => jsonEncode({
  'title': create.label.title,
  'hex_color': create.label.hexColor,
  'description': create.label.description,
  if (create.adopt) 'adopt': true,
  if (create.known.isNotEmpty) 'known': [...create.known]..sort(),
});

QueuedLabelCreate decodeLabelCreate(String json) => switch (jsonDecode(json)) {
  final Map<String, Object?> map => QueuedLabelCreate(
    label: NewLabel(
      title: map['title']! as String,
      hexColor: map['hex_color'] as String? ?? '',
      description: map['description'] as String? ?? '',
    ),
    adopt: map['adopt'] as bool? ?? false,
    known: {
      for (final id in map['known'] as List<Object?>? ?? const []) id! as int,
    },
  ),
  _ => throw FormatException('not a queued label create', json),
};

/// [payload], a queued create, with [at] as the time its request last left
/// the device. [encodeLabelCreate] writes none: a create is encoded afresh
/// only when no attempt can have reached the server, or after a refusal.
String withLabelCreatePostedAt(String payload, DateTime at) => jsonEncode({
  ...jsonDecode(payload) as Map<String, Object?>,
  _postedAtKey: at.toUtc().toIso8601String(),
});

/// [payload], a queued create, with [ids] added to its known labels.
String withLabelCreateKnown(String payload, Set<int> ids) {
  final map = jsonDecode(payload) as Map<String, Object?>;
  final known = {
    for (final id in map['known'] as List<Object?>? ?? const []) id! as int,
    ...ids,
  };
  return jsonEncode({
    ...map,
    if (known.isNotEmpty) 'known': [...known]..sort(),
  });
}

/// When the request of the queued create [payload] last left the device;
/// null when it never did.
DateTime? labelCreatePostedAt(String payload) => switch (jsonDecode(payload)) {
  {_postedAtKey: final String at} => DateTime.tryParse(at)?.toUtc(),
  _ => null,
};

const _postedAtKey = 'posted_at';

/// [labelTitle], the title the label has with [changes], names a failed
/// edit when the label is gone here.
String encodeLabelChanges(LabelChanges changes, {String? labelTitle}) =>
    jsonEncode({
      'title': ?changes.title,
      'hex_color': ?changes.hexColor,
      'description': ?changes.description,
      _labelTitleKey: ?labelTitle,
    });

LabelChanges decodeLabelChanges(String json) => switch (jsonDecode(json)) {
  final Map<String, Object?> map => LabelChanges(
    title: map['title'] as String?,
    hexColor: map['hex_color'] as String?,
    description: map['description'] as String?,
  ),
  _ => throw FormatException('not queued label changes', json),
};

/// A label delete as queued: the label is gone here at once, so it keeps
/// the title, which names a failed delete, and the tasks the server has the
/// label on, which get it back here when the delete is discarded.
@immutable
final class QueuedLabelDelete {
  const new({required this.title, this.taskIds = const {}});

  final String title;
  final Set<int> taskIds;
}

String encodeLabelDelete(QueuedLabelDelete delete) => jsonEncode({
  _labelTitleKey: delete.title,
  if (delete.taskIds.isNotEmpty) 'task_ids': [...delete.taskIds]..sort(),
});

QueuedLabelDelete decodeLabelDelete(String json) => switch (jsonDecode(json)) {
  final Map<String, Object?> map => QueuedLabelDelete(
    title: map[_labelTitleKey] as String? ?? '',
    taskIds: {
      for (final id in map['task_ids'] as List<Object?>? ?? const [])
        id! as int,
    },
  ),
  _ => throw FormatException('not a queued label delete', json),
};

/// The title a queued edit or delete names its label by; null without one.
String? queuedLabelTitle(String json) => switch (jsonDecode(json)) {
  {_labelTitleKey: final String title} => title,
  _ => null,
};

const _labelTitleKey = 'label_title';

/// [later] wins for every field it sets.
LabelChanges mergeLabelChanges(LabelChanges earlier, LabelChanges later) =>
    LabelChanges(
      title: later.title ?? earlier.title,
      hexColor: later.hexColor ?? earlier.hexColor,
      description: later.description ?? earlier.description,
    );

/// [label] with what [changes] set.
Label applyLabelChanges(Label label, LabelChanges changes) => Label(
  id: label.id,
  title: changes.title ?? label.title,
  description: changes.description ?? label.description,
  hexColor: changes.hexColor ?? label.hexColor,
  createdBy: label.createdBy,
  created: label.created,
  updated: label.updated,
);
