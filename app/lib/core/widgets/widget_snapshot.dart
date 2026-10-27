import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;

/// The JSON the native widgets render, written by the app: every text is
/// localized and formatted here, every date is epoch milliseconds, and a
/// reader skips a [version] it does not know. It never holds a token; it
/// holds task titles, which the home screen shows.
@immutable
final class WidgetSnapshot {
  const new({
    required this.key,
    required this.accountId,
    required this.state,
    required this.title,
    required this.generatedAt,
    required this.validUntil,
    this.subtitle,
    this.changesAt = const [],
    this.rows = const [],
    this.total = 0,
    this.moreLabel,
    this.countLabel,
    this.empty,
    this.message,
    this.messageLink,
    this.link,
    this.newTaskLink,
    this.newTaskLabel,
  });

  factory fromJson(Map<String, Object?> json) {
    if (json['v'] != version) {
      throw FormatException('Widget snapshot version ${json['v']}');
    }
    return WidgetSnapshot(
      key: _string(json, 'key'),
      accountId: _string(json, 'account'),
      state: _enum(WidgetSnapshotState.values, json['state']),
      title: _string(json, 'title'),
      subtitle: json['subtitle'] as String?,
      generatedAt: _date(json['generatedAt'])!,
      validUntil: _date(json['validUntil'])!,
      changesAt: [
        for (final at in json['changesAt'] as List<Object?>? ?? const [])
          _date(at)!,
      ],
      rows: [
        for (final row in json['rows'] as List<Object?>? ?? const [])
          WidgetRow.fromJson(row! as Map<String, Object?>),
      ],
      total: json['total'] as int? ?? 0,
      moreLabel: json['moreLabel'] as String?,
      countLabel: json['countLabel'] as String?,
      empty: _text(json['empty']),
      message: _text(json['message']),
      messageLink: json['messageLink'] as String?,
      link: json['link'] as String?,
      newTaskLink: json['newTaskLink'] as String?,
      newTaskLabel: json['newTaskLabel'] as String?,
    );
  }

  factory decode(String source) =>
      WidgetSnapshot.fromJson(jsonDecode(source) as Map<String, Object?>);

  static const version = 1;

  /// How many rows a snapshot carries at most; [total] counts them all.
  static const maxRows = 30;

  final String key;
  final String accountId;
  final WidgetSnapshotState state;
  final String title;

  /// The account, when more than one is signed in.
  final String? subtitle;
  final DateTime generatedAt;

  /// When the rows go stale (the next local midnight at the latest); the
  /// app writes a new snapshot before, whenever it runs.
  final DateTime validUntil;

  /// Instants before [validUntil] at which a row's tone changes (a due
  /// instant passing), for the timeline entries of iOS.
  final List<DateTime> changesAt;
  final List<WidgetRow> rows;

  /// Every matching task, [rows] included.
  final int total;

  /// "+N more" while [total] exceeds the rows.
  final String? moreLabel;

  /// [total] as screen readers hear it.
  final String? countLabel;

  /// What an empty list says, for the [WidgetSnapshotState.ok] and reauth
  /// states.
  final WidgetText? empty;

  /// What a state other than [WidgetSnapshotState.ok] says.
  final WidgetText? message;

  /// What resolves the [message]: the Account tab for an ended session,
  /// the app for a list or account that is gone.
  final String? messageLink;

  /// Opens the list in the app.
  final String? link;

  /// The header's "+", or the quick add widget's button; null where the
  /// account can add no task.
  final String? newTaskLink;
  final String? newTaskLabel;

  int get more => total - rows.length;

  Map<String, Object?> toJson() => {
    'v': version,
    'key': key,
    'account': accountId,
    'state': state.name,
    'title': title,
    'subtitle': ?subtitle,
    'generatedAt': generatedAt.millisecondsSinceEpoch,
    'validUntil': validUntil.millisecondsSinceEpoch,
    'changesAt': [for (final at in changesAt) at.millisecondsSinceEpoch],
    'rows': [for (final row in rows) row.toJson()],
    'total': total,
    'more': more,
    'moreLabel': ?moreLabel,
    'countLabel': ?countLabel,
    'empty': ?empty?.toJson(),
    'message': ?message?.toJson(),
    'messageLink': ?messageLink,
    'link': ?link,
    'newTaskLink': ?newTaskLink,
    'newTaskLabel': ?newTaskLabel,
  };

  String encode() => jsonEncode(toJson());

  /// The JSON without [generatedAt], to tell whether a new build changed
  /// anything worth a write.
  String contentFingerprint() => jsonEncode(toJson()..remove('generatedAt'));

  @override
  bool operator ==(Object other) =>
      other is WidgetSnapshot && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

enum WidgetSnapshotState {
  ok,

  /// The server ended a user's session; the rows stay, with a message.
  needsReauth,

  /// A link share's guest access ended; the rows stay, with a message.
  guestEnded,

  /// Signed out or removed: no rows until the widget is set up again.
  accountRemoved,

  /// The project, label or saved filter no longer exists.
  gone,
}

enum WidgetDueTone { overdue, today, later, none }

@immutable
final class WidgetRow {
  const new({
    required this.taskId,
    required this.title,
    required this.tone,
    required this.canDone,
    required this.semanticsLabel,
    required this.doneLabel,
    required this.link,
    this.dueLabel,
    this.dueAt,
    this.priorityLabel,
    this.priorityLevel,
    this.projectTitle,
    this.projectColor,
  });

  factory fromJson(Map<String, Object?> json) => WidgetRow(
    taskId: json['id']! as int,
    title: _string(json, 'title'),
    dueLabel: json['due'] as String?,
    dueAt: _date(json['dueAt']),
    tone: _enum(WidgetDueTone.values, json['tone']),
    priorityLabel: json['priority'] as String?,
    priorityLevel: json['priorityLevel'] as int?,
    projectTitle: json['project'] as String?,
    projectColor: json['color'] as String?,
    canDone: json['canDone']! as bool,
    semanticsLabel: _string(json, 'label'),
    doneLabel: _string(json, 'doneLabel'),
    link: _string(json, 'link'),
  );

  final int taskId;
  final String title;

  /// Day-level ("Today, 14:30", "Tomorrow", a weekday or a date), or the
  /// absolute format the user picked on the web; never "in 2 hours".
  final String? dueLabel;

  /// A reader at a later instant shows a [WidgetDueTone.today] row whose
  /// [dueAt] has passed as overdue.
  final DateTime? dueAt;
  final WidgetDueTone tone;

  /// Only where the app's rows show the priority.
  final String? priorityLabel;

  /// 1 (low) to 5 (do now).
  final int? priorityLevel;

  /// For a task from another project than the list's.
  final String? projectTitle;

  /// `rrggbb`, without `#`.
  final String? projectColor;

  /// The user may mark it done: the project allows writing and is not
  /// archived.
  final bool canDone;
  final String semanticsLabel;

  /// The Done control's content description.
  final String doneLabel;

  /// Opens the task in the app.
  final String link;

  Map<String, Object?> toJson() => {
    'id': taskId,
    'title': title,
    'due': ?dueLabel,
    'dueAt': ?dueAt?.millisecondsSinceEpoch,
    'tone': tone.name,
    'priority': ?priorityLabel,
    'priorityLevel': ?priorityLevel,
    'project': ?projectTitle,
    'color': ?projectColor,
    'canDone': canDone,
    'label': semanticsLabel,
    'doneLabel': doneLabel,
    'link': link,
  };

  @override
  bool operator ==(Object other) =>
      other is WidgetRow && jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

/// A title, an optional body and the label of what the tap does.
@immutable
final class WidgetText {
  const new(this.title, {this.body, this.action});

  final String title;
  final String? body;
  final String? action;

  Map<String, Object?> toJson() => {
    'title': title,
    'body': ?body,
    'action': ?action,
  };

  @override
  bool operator ==(Object other) =>
      other is WidgetText &&
      other.title == title &&
      other.body == body &&
      other.action == action;

  @override
  int get hashCode => Object.hash(title, body, action);
}

String _string(Map<String, Object?> json, String key) => switch (json[key]) {
  final String value => value,
  _ => throw FormatException('Widget JSON without $key'),
};

T _enum<T extends Enum>(List<T> values, Object? name) =>
    values.asNameMap()[name] ??
    (throw FormatException('Unknown widget value $name'));

DateTime? _date(Object? millis) => switch (millis) {
  final int value => DateTime.fromMillisecondsSinceEpoch(value, isUtc: true),
  null => null,
  _ => throw FormatException('A widget date that is not epoch ms: $millis'),
};

WidgetText? _text(Object? json) => switch (json) {
  {'title': final String title} && final Map<String, Object?> map => WidgetText(
    title,
    body: map['body'] as String?,
    action: map['action'] as String?,
  ),
  null => null,
  _ => throw const FormatException('A widget text without its title'),
};
