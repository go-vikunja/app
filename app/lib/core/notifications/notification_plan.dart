import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart' show SubscribedTasks;
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

  /// UTC instant, after `now` unless the entry is late (see
  /// [planNotifications]).
  final DateTime fireAt;
  final String title;
  final String body;

  /// The snooze that moved [fireAt] away from the task's own instant, so
  /// the stored row keeps it for the next plan.
  final Snooze? snooze;

  /// The task's own instant, which a snooze leaves alone.
  DateTime get occurrence => snooze?.originalFireAt.toUtc() ?? fireAt;
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

/// The task's own instant for a key's [kind] and [ordinal]: its due date
/// or the reminder at that position; null when it has none there.
DateTime? notificationInstantOf(
  Task task,
  ScheduledNotificationKind kind,
  int ordinal,
) => switch (kind) {
  ScheduledNotificationKind.dueDate => task.dueDate,
  ScheduledNotificationKind.reminder =>
    ordinal < task.reminders.length ? task.reminders[ordinal].reminder : null,
};

bool sameInstant(DateTime? a, DateTime? b) =>
    a?.millisecondsSinceEpoch == b?.millisecondsSinceEpoch;

/// The notifications an account should have, from its local data alone:
/// undone tasks, not queued for deletion, where [userId] is the creator or
/// an assignee (a task created here under a temporary id has no creator yet and
/// counts as the user's). With [subscribed], which is passed for a server that
/// sends reminders only to subscribers, the tasks it covers instead, for
/// reminders and due dates alike (decision log: Notifications and widgets). For
/// each, every reminder with an instant after [now] and, when [preferences]
/// allow, the due date at its exact instant; a reminder at that same instant is
/// left to the due date, so the moment rings once. A snooze whose
/// `originalFireAt` is the entry's own instant and whose `until` is still ahead
/// moves the entry there, which is how a notification that has fired comes
/// back. Titles and bodies are built by [describe] (localised by the caller).
/// Sorted by [DesiredNotification.fireAt], then by key.
///
/// With [late], entries whose instant passed at most that long ago are
/// planned too: [diffSchedule] keeps such a late entry only while the OS
/// still holds it at that instant, as an inexact alarm Android deferred.
/// A snooze stays applied in that window too, unless its own instant is
/// still ahead.
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
  SubscribedTasks? subscribed,
  Duration late = Duration.zero,
}) {
  if (!preferences.anyEnabled) return const [];
  final since = now.subtract(late);
  final snoozeByKey = {for (final snooze in snoozes) snooze.key: snooze};
  final desired = <DesiredNotification>[];

  DesiredNotification? entry(
    Task task,
    String key,
    ScheduledNotificationKind kind,
    DateTime at,
  ) {
    final instant = at.toUtc();
    final snooze = snoozeByKey[key];
    final applies =
        snooze != null &&
        snooze.originalFireAt.toUtc() == instant &&
        snooze.until.isAfter(instant.isAfter(now) ? now : since);
    final fireAt = applies ? snooze.until.toUtc() : instant;
    if (!fireAt.isAfter(since)) return null;
    final (:title, :body) = describe(task, kind);
    return DesiredNotification(
      key: key,
      taskId: task.id,
      kind: kind,
      fireAt: fireAt,
      title: title,
      body: body,
      snooze: applies ? snooze : null,
    );
  }

  for (final task in tasks) {
    if (task.done ||
        !(subscribed?.covers(task, userId: userId) ?? _isOwn(task, userId))) {
      continue;
    }
    final due = switch (task.dueDate) {
      final at? when preferences.dueDates => entry(
        task,
        dueNotificationKey(task.id),
        ScheduledNotificationKind.dueDate,
        at,
      ),
      _ => null,
    };
    if (due != null) desired.add(due);
    if (preferences.reminders) {
      for (final (ordinal, reminder) in task.reminders.indexed) {
        if (reminder.reminder case final at?) {
          final planned = entry(
            task,
            reminderNotificationKey(task.id, ordinal),
            ScheduledNotificationKind.reminder,
            at,
          );
          if (planned != null && !_ringsWithDue(planned, due)) {
            desired.add(planned);
          }
        }
      }
    }
  }
  return desired..sort(_byFireAtThenKey);
}

/// Whether [reminder] would ring together with [due] at the task's own due
/// instant. Neither may be snoozed: a snooze is a time the user picked.
bool _ringsWithDue(DesiredNotification reminder, DesiredNotification? due) =>
    due != null &&
    due.snooze == null &&
    reminder.snooze == null &&
    reminder.fireAt == due.fireAt;

bool _isOwn(Task task, int userId) =>
    task.id < 0 ||
    task.createdBy?.id == userId ||
    task.assignees.any((user) => user.id == userId);

int _byFireAtThenKey(DesiredNotification a, DesiredNotification b) {
  final byTime = a.fireAt.compareTo(b.fireAt);
  return byTime != 0 ? byTime : a.key.compareTo(b.key);
}

/// What to cancel and what to schedule so that the OS holds the [window]
/// and nothing else of this account. The window is the first [window]
/// count of [desired], leaving out a late entry (not after [now]) unless
/// [scheduled] holds its key at that very instant: the OS has not shown it
/// yet, and scheduling it anew would show one that has fired once more.
/// The first snoozed entry after those joins the window too: the snooze
/// lives only in the entry's row, which the caller keeps only for the
/// window, and the task alone cannot bring it back. Only one, as iOS keeps
/// room under its cap for one snooze per account beside the windows.
///
/// Only what left the window is cancelled. A key still wanted is scheduled
/// again under its id, which replaces it, when anything differs (instant,
/// title, body, [exact], [privacy]) or with [everything]; a cancel first
/// would, on Android, also take what the tray shows under that id. Cancels
/// come in [scheduled] order, schedules in [desired] order.
({
  List<int> cancelOsIds,
  List<DesiredNotification> schedule,
  List<DesiredNotification> window,
})
diffSchedule({
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
  required DateTime now,
  bool everything = false,
}) {
  final scheduledByKey = {for (final entry in scheduled) entry.key: entry};
  final candidates = desired.where(
    (entry) =>
        entry.fireAt.isAfter(now) ||
        scheduledByKey[entry.key]?.fireAt.toUtc() == entry.fireAt,
  );
  final first = window < 0 ? 0 : window;
  final wanted = [
    ...candidates.take(first),
    ...candidates.skip(first).where((entry) => entry.snooze != null).take(1),
  ];
  final wantedByKey = {for (final entry in wanted) entry.key: entry};
  final unchangedKeys = <String>{};
  final cancelOsIds = <int>[];
  for (final entry in scheduled) {
    final want = wantedByKey[entry.key];
    if (want == null) {
      cancelOsIds.add(entry.osId);
    } else if (!everything &&
        want.fireAt == entry.fireAt.toUtc() &&
        want.title == entry.title &&
        want.body == entry.body &&
        entry.exact == exact &&
        entry.privacy == privacy) {
      unchangedKeys.add(entry.key);
    }
  }
  return (
    cancelOsIds: cancelOsIds,
    schedule: [
      for (final entry in wanted)
        if (!unchangedKeys.contains(entry.key)) entry,
    ],
    window: wanted,
  );
}
