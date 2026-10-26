import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/text/html_to_text.dart';

enum ActivityKind {
  comment('task.comment'),
  assigned('task.assigned'),
  mentioned('task.mentioned'),
  taskCreated('task.created'),
  taskDeleted('task.deleted'),
  projectCreated('project.created'),
  teamMemberAdded('team.member.added'),
  reminder('task.reminder'),
  other('');

  new(this.serverName);

  final String serverName;

  /// What may become an OS notification. A server reminder never does:
  /// the phone schedules the reminders itself.
  bool get notifies => this != reminder && this != other;

  static ActivityKind of(String name) {
    for (final kind in values) {
      if (kind.serverName == name && kind != other) return kind;
    }
    return other;
  }
}

/// One server notification as the inbox and the OS notification show it,
/// read from its payload once, as the web reads it; a field the payload
/// lacks is null, and each text falls back to generic wording for it.
@immutable
final class ActivityItem {
  const new({
    required this.notification,
    required this.kind,
    this.doerName,
    this.taskId,
    this.taskIdentifier,
    this.taskTitle,
    this.projectId,
    this.projectTitle,
    this.teamId,
    this.teamName,
    this.targetName,
    this.targetIsMe = false,
    this.comment,
    this.commentId,
  });

  /// [userId] is the account's own user, the "you" of an assignment or a
  /// team membership.
  factory fromNotification(ServerNotification notification, {int? userId}) {
    final payload = notification.payload;
    final task = _map(payload['task']);
    final project = _map(payload['project']);
    final target = _map(payload['assignee']) ?? _map(payload['member']);
    final team = _map(payload['team']);
    final targetId = target?['id'];
    return ActivityItem(
      notification: notification,
      kind: ActivityKind.of(notification.name),
      doerName: _userName(_map(payload['doer'])),
      taskId: notification.taskId,
      taskIdentifier: task == null ? null : _identifier(task),
      taskTitle: _text(task?['title']),
      projectId: notification.projectId,
      projectTitle: _text(project?['title']),
      teamId: switch (team?['id']) {
        final int id when id > 0 => id,
        _ => null,
      },
      teamName: _text(team?['name']),
      targetName: _userName(target),
      targetIsMe: targetId is int && targetId == userId,
      comment: switch (_map(payload['comment'])?['comment']) {
        final String html => _text(_oneLine(htmlToPlainText(html))),
        _ => null,
      },
      commentId: commentIdOf(notification),
    );
  }

  final ServerNotification notification;
  final ActivityKind kind;
  final String? doerName;
  final int? taskId;

  /// `PROJ-12`, or `#12` for a project without a prefix.
  final String? taskIdentifier;
  final String? taskTitle;
  final int? projectId;
  final String? projectTitle;
  final int? teamId;
  final String? teamName;

  /// The assignee of an assignment, the member of a team membership.
  final String? targetName;
  final bool targetIsMe;

  /// Plain text, on one line.
  final String? comment;
  final int? commentId;

  int get id => notification.id;
  bool get isRead => notification.isRead;
  DateTime get created => notification.created;
}

/// The comment the notification's payload names (a `task.comment` one
/// does), else null.
int? commentIdOf(ServerNotification notification) =>
    switch (_map(notification.payload['comment'])?['id']) {
      final int id when id > 0 => id,
      _ => null,
    };

Map<String, Object?>? _map(Object? value) => switch (value) {
  final Map<String, Object?> map => map,
  _ => null,
};

String? _text(Object? value) => switch (value) {
  final String text when text.trim().isNotEmpty => text.trim(),
  _ => null,
};

/// The web's `getDisplayName`: the name, else the username.
String? _userName(Map<String, Object?>? user) =>
    _text(user?['name']) ?? _text(user?['username']);

/// Like `Task.displayIdentifier`; the payload's task may carry no
/// identifier at all, only its index.
String? _identifier(Map<String, Object?> task) {
  final index = switch (task['index']) {
    final int index when index > 0 => index,
    _ => null,
  };
  final identifier = _text(task['identifier']);
  if (identifier != null && identifier != '-$index') return identifier;
  return index == null ? null : '#$index';
}

final _whitespace = RegExp(r'\s+');

String _oneLine(String text) => text.replaceAll(_whitespace, ' ').trim();
