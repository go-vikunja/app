import 'dart:async';

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart' show SubscribedTasks;
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';
import 'package:vikunja_mobile/core/notifications/notification_plan.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/time/timers.dart';

final _log = Logger('Notifications');

typedef _Pending = ({Set<int> own, Set<int> foreign});

/// The texts of one notification; [project] is the task's project when it
/// is known locally.
typedef NotificationDescriber = ({String title, String body}) Function(
  Task task,
  ScheduledNotificationKind kind,
  Project? project,
);

/// How one run words the notifications and what the OS may show of them
/// while the device is locked: the device's privacy settings, read anew
/// for every run.
typedef NotificationPresentation = ({
  NotificationDescriber describe,
  NotificationPrivacy privacy,
});

/// Keeps the OS notifications of one account in step with its database.
/// Headless: the database, the gateway, the preferences, the presentation,
/// a clock and a timer factory are injected, so the background action
/// isolate runs it like the UI does.
///
/// [reconcile] loads the open tasks and the stored snoozes, plans what the
/// account should have, diffs that against what the table says the OS
/// holds, minus what the gateway no longer lists as pending (so a fired
/// notification is scheduled again when it is still wanted), cancels and
/// schedules through the gateway and writes the table. That list is the
/// system's on iOS; on Android it is the plugin's own record, which keeps
/// the ids of the alarms a force stop drops (see [reconcile]'s `rearm`).
/// An entry whose time passed less than [lateLimit] ago and that the OS
/// still lists, an inexact alarm Android deferred, stays while its task and
/// its instant do. Each run also withdraws the account's reminders and due
/// dates from the tray once their task is done or gone, or has moved to
/// another instant than the one they showed, and cancels those pending
/// that neither the table nor the window holds. An id that another
/// account's notification holds stays that account's: a new key probes
/// past it, and an entry it has replaced moves to a free id.
/// It runs after every change to the tasks, reminders, assignees or
/// projects (debounced), after a change of this account's preferences, and
/// whenever the caller asks. Without the notification permission, or with
/// every kind switched off, it cancels everything the account holds.
final class NotificationScheduler {
  new({
    required this.accountId,
    required this._userId,
    required this._db,
    required this._gateway,
    required this._preferences,
    required this._presentation,
    required this._window,
    Future<String?> Function()? linkKey,
    DateTime Function()? now,
    this.debounce = const Duration(milliseconds: 700),
    this._createTimer = Timer.new,
    this._followSubscriptions = false,
  }) : _linkKey = linkKey ?? _noLinkKey,
       _now = now ?? DateTime.now {
    _tableUpdates = _db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            _db.tasks,
            _db.taskReminders,
            _db.taskAssignees,
            // A project followed or unfollowed, and a renamed one's texts.
            _db.projects,
          ]),
        )
        .listen((_) => _reconcileAfterDebounce());
    _preferenceChanges = _preferences.changes.listen((change) {
      if (change.$1 == accountId) reconcileQuietly();
    });
  }

  /// Android defers an inexact alarm by up to an hour past its time, more
  /// for an app in a rare standby bucket.
  static const lateLimit = Duration(hours: 3);

  final String accountId;
  final Duration debounce;
  final int _userId;
  final AppDatabase _db;
  final NotificationGateway _gateway;
  final NotificationPreferencesStore _preferences;

  /// The table records the texts and the privacy of every entry, so a run
  /// schedules again what a run with older settings scheduled.
  final Future<NotificationPresentation> Function() _presentation;
  final int _window;

  /// The install's widget-link key, which a tap needs to switch accounts
  /// without asking; null leaves it out.
  final Future<String?> Function() _linkKey;
  final DateTime Function() _now;
  final CreateTimer _createTimer;

  /// Plans the tasks the user follows instead of those the user created or
  /// is assigned to; never for a link-share guest, who can follow nothing
  /// (decision log: Notifications and widgets).
  final bool _followSubscriptions;
  late final StreamSubscription<Object?> _tableUpdates;
  late final StreamSubscription<Object?> _preferenceChanges;

  static Future<String?> _noLinkKey() async => null;

  /// The ids the table held after the last run, for [cancelAll] once the
  /// database has gone.
  Set<int> _heldOsIds = const {};
  Future<void>? _running;
  var _requested = false;
  var _forced = false;
  var _rearming = false;
  var _rearmPending = false;
  var _disposed = false;
  Timer? _debounceTimer;

  /// Brings the OS in step with the database; a call during a run makes
  /// that run look once more before the returned future completes. Nothing
  /// after [dispose]. Gateway and database errors propagate; the next run
  /// starts from the table as it is. With [force] or [rearm], every entry
  /// of the window is scheduled again under its id, unchanged ones too, and
  /// a run that fails leaves that to the next one; the snoozes in the table
  /// stay. No run cancels an entry it still wants: scheduling an id again
  /// replaces it, while on Android a cancel would also take what the tray
  /// shows under that id.
  Future<void> reconcile({bool force = false, bool rearm = false}) {
    if (_disposed) return Future.value();
    _requested = true;
    if (force) _forced = true;
    if (rearm) _rearming = _rearmPending = true;
    return _running ??= _loop().whenComplete(() => _running = null);
  }

  /// A re-arm was asked for and has not reached the OS yet, also when this
  /// scheduler was disposed first; its successor takes it over.
  bool get rearmPending => _rearmPending;

  /// Completes once no run is under way; a run's error is left to its
  /// caller. After [dispose] a run schedules nothing more.
  Future<void> get idle async {
    try {
      await _running;
    } on Object {
      // Reported by reconcile.
    }
  }

  /// [reconcile] for the triggers, which have nobody to report to: an error
  /// is logged and the next trigger starts afresh.
  void reconcileQuietly({bool force = false, bool rearm = false}) => unawaited(
    reconcile(force: force, rearm: rearm).then<void>(
      (_) {},
      onError: (Object error) => _log.warning(
        'Could not reconcile the notifications of account $accountId: '
        '${error.runtimeType}',
      ),
    ),
  );

  /// Moves the notification [key] of [taskId] to now plus [duration]: the
  /// row is written first, the OS is told at once (iOS may suspend the
  /// action isolate within seconds), then [reconcile] settles the rest.
  /// Without a row (a reconcile drops a fired entry) the instant is taken
  /// from the task itself; a task that is gone or done, an instant that is
  /// unset or still ahead (the task's time changed since the notification
  /// fired) or a key that is not one make the snooze a no-op. With
  /// [shown], the instant the notification stood for, a key whose instant
  /// has changed since is only reconciled, which withdraws the outdated
  /// notification: its row may hold the next occurrence by now.
  Future<void> snooze({
    required String key,
    required int taskId,
    required Duration duration,
    DateTime? shown,
  }) async {
    if (shown != null && !await _stillAt(key, taskId, shown)) {
      _log.info('Ignored a snooze of task $taskId: its time has changed since');
      await reconcile();
      return;
    }
    final now = _now();
    final until = now.add(duration).toUtc();
    final capabilities = await _gateway.capabilities();
    final presentation = await _presentation();
    final linkKey = await _linkKey();
    final row = await _snoozedRow(
      key,
      taskId,
      now: now,
      until: until,
      exact: capabilities.exactAlarms,
      describe: presentation.describe,
      privacy: presentation.privacy,
    );
    if (row == null) {
      _log.info('Ignored a snooze of a notification that is not scheduled');
      return;
    }
    await _db.scheduledNotificationsDao.upsert(row);
    if (capabilities.permission == NotificationPermission.granted) {
      await _gateway.schedule(
        ScheduledNotification(
          osId: row.osId,
          fireAt: until,
          title: row.title,
          body: row.body,
          payload: NotificationPayload(
            accountId: accountId,
            taskId: row.taskId,
            key: row.key,
            linkKey: linkKey,
            occurrence: row.snoozeOriginalFireAt,
          ).toJson(),
          exact: capabilities.exactAlarms,
          privacy: presentation.privacy,
        ),
      );
    }
    _log.fine('Snoozed a notification of task $taskId by $duration');
    await reconcile();
  }

  /// [snooze] until tomorrow at the user's default due time, else 9:00,
  /// in the device's time zone.
  Future<void> snoozeUntilTomorrow({
    required String key,
    required int taskId,
    DateTime? shown,
  }) async {
    final settings = decodeUserSettings(
      (await _db.syncStateDao.readAll())[SyncStateKeys.userSettings],
    );
    final now = _now();
    await snooze(
      key: key,
      taskId: taskId,
      duration: tomorrowAt(now, settings.defaultDueTime).difference(now),
      shown: shown,
    );
  }

  Future<bool> _stillAt(String key, int taskId, DateTime shown) async {
    final parsed = parseNotificationKey(key);
    if (parsed == null) return true;
    final task = await _db.tasksDao.find(await _db.tasksDao.resolveId(taskId));
    return task != null &&
        sameInstant(
          notificationInstantOf(task, parsed.kind, parsed.ordinal),
          shown,
        );
  }

  Future<ScheduledNotificationRow?> _snoozedRow(
    String key,
    int taskId, {
    required DateTime now,
    required DateTime until,
    required bool exact,
    required NotificationDescriber describe,
    required NotificationPrivacy privacy,
  }) async {
    final parsed = parseNotificationKey(key);
    if (parsed == null) return null;
    final dao = _db.scheduledNotificationsDao;
    // A create answered meanwhile moved the task to its server id, under
    // which the plan now keys its entries.
    final resolvedId = await _db.tasksDao.resolveId(taskId);
    final resolvedKey = switch (parsed.kind) {
      ScheduledNotificationKind.dueDate => dueNotificationKey(resolvedId),
      ScheduledNotificationKind.reminder => reminderNotificationKey(
        resolvedId,
        parsed.ordinal,
      ),
    };
    final existing = await dao.find(key) ?? await dao.find(resolvedKey);
    final foreign = (await _pending())?.foreign ?? const <int>{};
    if (existing != null) {
      return existing.copyWith(
        // Another account may have taken the id over since it fired; the
        // id stays that account's, uncancelled.
        osId: foreign.contains(existing.osId)
            ? nextFreeNotificationOsId(
                notificationOsIdFor(accountId, existing.key),
                {...await dao.osIds(), ...foreign},
              )
            : null,
        fireAt: until,
        exact: exact,
        hiddenOnLockScreen: privacy.hiddenOnLockScreen,
        doneNeedsUnlock: privacy.doneNeedsUnlock,
        snoozedUntil: Value(until),
        // A second snooze keeps the task's own instant.
        snoozeOriginalFireAt: Value(
          existing.snoozeOriginalFireAt ?? existing.fireAt,
        ),
      );
    }
    final task = await _db.tasksDao.find(resolvedId);
    if (task == null || task.done) return null;
    final instant = notificationInstantOf(task, parsed.kind, parsed.ordinal);
    if (instant == null || instant.isAfter(now)) return null;
    final projects = await _db.projectsDao.loadAll();
    final (:title, :body) = describe(
      task,
      parsed.kind,
      projects.where((p) => p.id == task.projectId).firstOrNull,
    );
    return ScheduledNotificationRow(
      key: resolvedKey,
      osId: nextFreeNotificationOsId(
        notificationOsIdFor(accountId, resolvedKey),
        {...await dao.osIds(), ...foreign},
      ),
      taskId: resolvedId,
      kind: parsed.kind.name,
      fireAt: until,
      title: title,
      body: body,
      snoozedUntil: until,
      snoozeOriginalFireAt: instant.toUtc(),
      exact: exact,
      hiddenOnLockScreen: privacy.hiddenOnLockScreen,
      doneNeedsUnlock: privacy.doneNeedsUnlock,
    );
  }

  /// Cancels every notification the account holds and empties the table.
  /// Works after [dispose] and after the database has closed, from the ids
  /// of the last run and those a run scheduled since; sign-out needs that,
  /// because the registry change disposes the providers before the wipe
  /// runs.
  Future<void> cancelAll() async {
    var osIds = _heldOsIds;
    try {
      osIds = {...osIds, ...await _db.scheduledNotificationsDao.osIds()};
    } on Object catch (error) {
      _log.fine(
        'Cancelling the notifications of account $accountId from memory: '
        '${error.runtimeType}',
      );
    }
    for (final osId in osIds) {
      await _gateway.cancel(osId);
    }
    try {
      await _db.scheduledNotificationsDao.deleteAll();
    } on Object {
      // The database may be closed already; the ids are cancelled.
    }
    _heldOsIds = const {};
    _log.fine('Cancelled ${osIds.length} notifications of account $accountId');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    await _tableUpdates.cancel();
    await _preferenceChanges.cancel();
  }

  void _reconcileAfterDebounce() {
    if (_disposed) return;
    _debounceTimer?.cancel();
    _debounceTimer = _createTimer(debounce, () {
      _debounceTimer = null;
      reconcileQuietly();
    });
  }

  Future<void> _loop() async {
    while (_requested && !_disposed) {
      _requested = false;
      final force = _forced;
      final rearm = _rearming;
      _forced = false;
      _rearming = false;
      try {
        await _run(force: force, rearm: rearm);
      } on Object {
        if (force) _forced = true;
        if (rearm) _rearming = true;
        rethrow;
      }
    }
  }

  Future<void> _run({required bool force, required bool rearm}) async {
    final capabilities = await _gateway.capabilities();
    final preferences = await _preferences.read(accountId);
    if (capabilities.permission != NotificationPermission.granted ||
        !preferences.anyEnabled) {
      await cancelAll();
      if (rearm) _rearmPending = false;
      return;
    }
    final (:describe, :privacy) = await _presentation();
    final linkKey = await _linkKey();
    final now = _now();
    final rows = await _db.scheduledNotificationsDao.all();
    final pending = await _pending();
    final openTasks = await _db.tasksDao.loadOpenTasks();
    final outdated = await _outdatedInTray({
      for (final task in openTasks) task.id: task,
    });
    final scheduled = [
      for (final row in rows)
        // A past entry counts as pending only when the gateway says so, and
        // one withdrawn now is scheduled again if it is still wanted. An id
        // another account's notification has replaced is not this entry's.
        if ((pending?.own.contains(row.osId) ?? row.fireAt.isAfter(now)) &&
            !outdated.contains(row.osId))
          (
            key: row.key,
            osId: row.osId,
            fireAt: row.fireAt,
            title: row.title,
            body: row.body,
            exact: row.exact,
            privacy: NotificationPrivacy(
              hiddenOnLockScreen: row.hiddenOnLockScreen,
              doneNeedsUnlock: row.doneNeedsUnlock,
            ),
          ),
    ];
    final snoozes = [
      for (final row in rows)
        if (row.snoozedUntil case final until?)
          Snooze(
            key: row.key,
            until: until,
            originalFireAt: row.snoozeOriginalFireAt ?? row.fireAt,
          ),
    ];
    final projects = {
      for (final project in await _db.projectsDao.loadAll())
        project.id: project,
    };
    final desired = planNotifications(
      tasks: openTasks,
      userId: _userId,
      preferences: preferences,
      now: now,
      late: lateLimit,
      snoozes: snoozes,
      describe: (task, kind) => describe(task, kind, projects[task.projectId]),
      subscribed: _followSubscriptions
          ? SubscribedTasks(
              own: await _db.tasksDao.ownSubscriptions(),
              followedProjects: {
                for (final project in projects.values)
                  if (project.subscription != null) project.id,
              },
            )
          : null,
    );
    if (_disposed) return;
    final (:cancelOsIds, :schedule, :window) = diffSchedule(
      desired: desired,
      scheduled: scheduled,
      window: _window,
      exact: capabilities.exactAlarms,
      privacy: privacy,
      now: now,
      everything: force || rearm,
    );
    final osIds = _assignOsIds(window, rows, pending?.foreign ?? const {});

    // Before the schedules: an outdated one may share its id with the
    // task's next occurrence.
    final cancels = {...outdated, ...cancelOsIds};
    for (final osId in cancels) {
      await _gateway.cancel(osId);
    }
    // Known before they reach the OS, so that a sign-out meanwhile cancels
    // them too.
    _heldOsIds = {..._heldOsIds, ...osIds.values};
    for (final entry in schedule) {
      if (_disposed) return;
      await _gateway.schedule(
        ScheduledNotification(
          osId: osIds[entry.key]!,
          fireAt: entry.fireAt,
          title: entry.title,
          body: entry.body,
          payload: NotificationPayload(
            accountId: accountId,
            taskId: entry.taskId,
            key: entry.key,
            linkKey: linkKey,
            occurrence: entry.occurrence,
          ).toJson(),
          exact: capabilities.exactAlarms,
          privacy: privacy,
        ),
      );
    }
    if (rearm) _rearmPending = false;
    if (_disposed) return;
    _heldOsIds = osIds.values.toSet();
    final written = await _db.scheduledNotificationsDao.replaceAll([
      for (final entry in window)
        ScheduledNotificationRow(
          key: entry.key,
          osId: osIds[entry.key]!,
          taskId: entry.taskId,
          kind: entry.kind.name,
          fireAt: entry.fireAt,
          title: entry.title,
          body: entry.body,
          snoozedUntil: entry.snooze?.until.toUtc(),
          snoozeOriginalFireAt: entry.snooze?.originalFireAt.toUtc(),
          exact: capabilities.exactAlarms,
          hiddenOnLockScreen: privacy.hiddenOnLockScreen,
          doneNeedsUnlock: privacy.doneNeedsUnlock,
        ),
    ], sinceRead: rows);
    if (!written) {
      // Another isolate (a background snooze, its reconcile) wrote the
      // table while this run planned from the old rows: its rows stand, and
      // the next pass brings the OS in step with them.
      _requested = true;
      _log.fine(
        'The notifications of account $accountId changed during the run; '
        'looking again',
      );
      return;
    }
    // Scheduled by a run that could not record it (another isolate's write
    // overtook it, or it was disposed of), for a task that may be done by
    // now. Only after a write of this run's that succeeded: no other
    // isolate has recorded anything since the read. Only what is pending,
    // as a cancel also takes what the tray shows under the id.
    final unrecorded = (pending?.own ?? const <int>{}).difference({
      for (final row in rows) row.osId,
      ...osIds.values,
      ...cancels,
    });
    for (final osId in unrecorded) {
      await _gateway.cancel(osId);
    }
    _log.fine(
      'Reconciled the notifications of account $accountId: '
      '${outdated.length} withdrawn, ${cancelOsIds.length} cancelled, '
      '${unrecorded.length} unrecorded cancelled, ${schedule.length} '
      'scheduled, ${window.length} of ${desired.length} pending',
    );
  }

  /// The ids of this account's reminders and due dates in the tray that no
  /// longer apply: their task is done or gone, or its instant for the key
  /// is another than the one they showed. One shown without that instant
  /// (scheduled before step 40e) goes only with its task. Empty when the
  /// gateway cannot say.
  Future<Set<int>> _outdatedInTray(Map<int, Task> openTasks) async {
    final List<DeliveredNotification> delivered;
    try {
      delivered = await _gateway.delivered();
    } on Object catch (error) {
      _log.info(
        'Could not list the notifications in the tray: ${error.runtimeType}',
      );
      return const {};
    }
    final outdated = <int>{};
    for (final notification in delivered) {
      final payload = NotificationPayload.tryParse(notification.payload);
      if (payload == null || payload.accountId != accountId) continue;
      final key = parseNotificationKey(payload.key);
      if (key == null) continue;
      final task = openTasks[await _db.tasksDao.resolveId(key.taskId)];
      final moved = switch ((task, payload.occurrence)) {
        (null, _) => true,
        (final task?, final shown?) => !sameInstant(
          notificationInstantOf(task, key.kind, key.ordinal),
          shown,
        ),
        _ => false,
      };
      if (moved) outdated.add(notification.osId);
    }
    return outdated;
  }

  /// The pending ids of this account's reminders and due dates, and those
  /// whose payload is another account's or none of the app's. Null when
  /// the gateway cannot say, which leaves the table as the only record.
  Future<_Pending?> _pending() async {
    final Map<int, String?> pending;
    try {
      pending = await _gateway.pendingIds();
    } on Object catch (error) {
      _log.info(
        'Could not list the pending notifications: '
        '${error.runtimeType}',
      );
      return null;
    }
    final own = <int>{};
    final foreign = <int>{};
    for (final MapEntry(key: osId, value: json) in pending.entries) {
      final payload = NotificationPayload.tryParse(json);
      if (payload == null || payload.accountId != accountId) {
        foreign.add(osId);
      } else if (parseNotificationKey(payload.key) != null) {
        own.add(osId);
      }
    }
    return (own: own, foreign: foreign);
  }

  /// A key keeps the id its row has unless [foreign] holds it, as another
  /// account's notification has replaced it; any other key takes the hash
  /// of the account and the key, or the next id above it that neither
  /// this window nor [foreign] holds.
  Map<String, int> _assignOsIds(
    List<DesiredNotification> window,
    List<ScheduledNotificationRow> rows,
    Set<int> foreign,
  ) {
    final existing = {
      for (final row in rows)
        if (!foreign.contains(row.osId)) row.key: row.osId,
    };
    final assigned = <String, int>{};
    final taken = {...foreign};
    for (final entry in window) {
      if (existing[entry.key] case final osId?) {
        assigned[entry.key] = osId;
        taken.add(osId);
      }
    }
    for (final entry in window) {
      if (assigned.containsKey(entry.key)) continue;
      final osId = nextFreeNotificationOsId(
        notificationOsIdFor(accountId, entry.key),
        taken,
      );
      assigned[entry.key] = osId;
      taken.add(osId);
    }
    return assigned;
  }
}

/// The next day after [now] at [time], 9:00 without one, local time.
DateTime tomorrowAt(DateTime now, ClockTime? time) {
  final local = now.toLocal();
  final at = time ?? const ClockTime(9, 0);
  return DateTime(local.year, local.month, local.day + 1, at.hour, at.minute);
}
