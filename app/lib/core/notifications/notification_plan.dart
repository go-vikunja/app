import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';

/// A notification the account should have pending, before the OS id and
/// the window are applied. [key] is stable across reschedules:
/// `<taskId>:reminder:<ordinal>` or `<taskId>:due`.
@immutable
final class DesiredNotification {
  const new({
    required this.key,
    required this.taskId,
    required this.kind,
    required this.fireAt,
    required this.title,
    required this.body,
    this.snooze,
  });

  final String key;
  final int taskId;
  final ScheduledNotificationKind kind;

  /// UTC instant, always after `now`.
  final DateTime fireAt;
  final String title;
  final String body;

  /// The snooze that moved [fireAt] away from the task's own instant, so
  /// the stored row keeps it for the next plan.
  final Snooze? snooze;
}

/// A snooze the user asked for from a notification: that key fires at
/// [until] instead, until the task's own time changes or it has fired.
@immutable
final class Snooze {
  const new({
    required this.key,
    required this.until,
    required this.originalFireAt,
  });

  final String key;
  final DateTime until;

  /// The time the snoozed notification would have had; a different time
  /// in the plan means the task changed and the snooze is dropped.
  final DateTime originalFireAt;
}

String reminderNotificationKey(int taskId, int ordinal) =>
    '$taskId:reminder:$ordinal';

String dueNotificationKey(int taskId) => '$taskId:due';

/// The parts of a key; null for anything that is not one. The ordinal is 0
/// for a due date.
({int taskId, ScheduledNotificationKind kind, int ordinal})?
parseNotificationKey(String key) {
  final parts = key.split(':');
  final taskId = int.tryParse(parts.first);
  if (taskId == null) return null;
  return switch (parts) {
    [_, 'due'] => (
      taskId: taskId,
      kind: ScheduledNotificationKind.dueDate,
      ordinal: 0,
    ),
    [_, 'reminder', final ordinal] when int.tryParse(ordinal) != null => (
      taskId: taskId,
      kind: ScheduledNotificationKind.reminder,
      ordinal: int.parse(ordinal),
    ),
    _ => null,
  };
}

/// The notifications an account should have, from its local data alone
/// (D17): undone tasks, not queued for deletion, where [userId] is the
/// creator or an assignee (a task created here under a temporary id has no
/// creator yet and counts as the user's); each reminder with an instant
/// after [now] and, when [preferences] allow, the due date at its exact
/// instant. A snooze whose `originalFireAt` is the entry's own instant and
/// whose `until` is still ahead moves the entry there, which is how a
/// notification that has fired comes back. Titles and bodies are built by
/// [describe] (localised by the caller). Sorted by
/// [DesiredNotification.fireAt], then by key.
List<DesiredNotification> planNotifications({
  required List<Task> tasks,
  required int userId,
  required NotificationPreferences preferences,
  required DateTime now,
  required List<Snooze> snoozes,
  required ({String title, String body}) Function(
    Task task,
    ScheduledNotificationKind kind,
  )
  describe,
}) {
  if (!preferences.anyEnabled) return const [];
  final snoozeByKey = {for (final snooze in snoozes) snooze.key: snooze};
  final desired = <DesiredNotification>[];

  void add(Task task, String key, ScheduledNotificationKind kind, DateTime at) {
    final instant = at.toUtc();
    final snooze = snoozeByKey[key];
    final applies =
        snooze != null &&
        snooze.originalFireAt.toUtc() == instant &&
        snooze.until.isAfter(now);
    final fireAt = applies ? snooze.until.toUtc() : instant;
    if (!fireAt.isAfter(now)) return;
    final (:title, :body) = describe(task, kind);
    desired.add(
      DesiredNotification(
        key: key,
        taskId: task.id,
        kind: kind,
        fireAt: fireAt,
        title: title,
        body: body,
        snooze: applies ? snooze : null,
      ),
    );
  }

  for (final task in tasks) {
    if (task.done || !_isOwn(task, userId)) continue;
    if (preferences.reminders) {
      for (final (ordinal, reminder) in task.reminders.indexed) {
        if (reminder.reminder case final at?) {
          add(
            task,
            reminderNotificationKey(task.id, ordinal),
            ScheduledNotificationKind.reminder,
            at,
          );
        }
      }
    }
    if (preferences.dueDates) {
      if (task.dueDate case final due?) {
        add(
          task,
          dueNotificationKey(task.id),
          ScheduledNotificationKind.dueDate,
          due,
        );
      }
    }
  }
  return desired..sort(_byFireAtThenKey);
}

bool _isOwn(Task task, int userId) =>
    task.id < 0 ||
    task.createdBy?.id == userId ||
    task.assignees.any((user) => user.id == userId);

int _byFireAtThenKey(DesiredNotification a, DesiredNotification b) {
  final byTime = a.fireAt.compareTo(b.fireAt);
  return byTime != 0 ? byTime : a.key.compareTo(b.key);
}

/// What to cancel and what to schedule so that the OS holds the first
/// [window] of [desired] and nothing else of this account: an entry
/// already scheduled with the same key, instant, title and body, as
/// [exact] and with the same [privacy] as this run schedules, is left
/// alone, unless [force] has every entry cancelled and scheduled again.
/// Cancels come in [scheduled] order, schedules in [desired] order.
({List<int> cancelOsIds, List<DesiredNotification> schedule}) diffSchedule({
  required List<DesiredNotification> desired,
  required List<
    ({
      String key,
      int osId,
      DateTime fireAt,
      String title,
      String body,
      bool exact,
      NotificationPrivacy privacy,
    })
  >
  scheduled,
  required int window,
  required bool exact,
  required NotificationPrivacy privacy,
  bool force = false,
}) {
  final wanted = desired.take(window < 0 ? 0 : window).toList();
  final wantedByKey = {for (final entry in wanted) entry.key: entry};
  final unchangedKeys = <String>{};
  final cancelOsIds = <int>[];
  for (final entry in scheduled) {
    final want = wantedByKey[entry.key];
    if (!force &&
        want != null &&
        want.fireAt == entry.fireAt.toUtc() &&
        want.title == entry.title &&
        want.body == entry.body &&
        entry.exact == exact &&
        entry.privacy == privacy) {
      unchangedKeys.add(entry.key);
    } else {
      cancelOsIds.add(entry.osId);
    }
  }
  return (
    cancelOsIds: cancelOsIds,
    schedule: [
      for (final entry in wanted)
        if (!unchangedKeys.contains(entry.key)) entry,
    ],
  );
}
