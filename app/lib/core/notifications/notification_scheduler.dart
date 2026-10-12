import 'dart:async';

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';
import 'package:vikunja_mobile/core/notifications/notification_plan.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';

final _log = Logger('Notifications');

/// The texts of one notification; [project] is the task's project when it
/// is known locally.
typedef NotificationDescriber = ({String title, String body}) Function(
  Task task,
  ScheduledNotificationKind kind,
  Project? project,
);

typedef CreateTimer = Timer Function(
  Duration duration,
  void Function() callback,
);

/// Keeps the OS notifications of one account in step with its database.
/// Headless: the database, the gateway, the preferences, a clock and a
/// timer factory are injected, so the background action isolate runs it
/// like the UI does.
///
/// [reconcile] loads the open tasks and the stored snoozes, plans what the
/// account should have, diffs that against what the table says the OS
/// holds (minus what the OS has dropped meanwhile, so a fired or lost
/// notification is scheduled again when it is still wanted), cancels and
/// schedules through the gateway and writes the table. It runs after every
/// change to the tasks, reminders or assignees (debounced), after a change
/// of this account's preferences, and whenever the caller asks. Without
/// the notification permission, or with every kind switched off, it
/// cancels everything the account holds.
final class NotificationScheduler {
  new({
    required this.accountId,
    required this._userId,
    required this._db,
    required this._gateway,
    required this._preferences,
    required this._describe,
    required this._window,
    DateTime Function()? now,
    this.debounce = const Duration(milliseconds: 700),
    this._createTimer = Timer.new,
  }) : _now = now ?? DateTime.now {
    _tableUpdates = _db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            _db.tasks,
            _db.taskReminders,
            _db.taskAssignees,
          ]),
        )
        .listen((_) => _reconcileAfterDebounce());
    _preferenceChanges = _preferences.changes.listen((change) {
      if (change.$1 == accountId) reconcileQuietly();
    });
  }

  final String accountId;
  final Duration debounce;
  final int _userId;
  final AppDatabase _db;
  final NotificationGateway _gateway;
  final NotificationPreferencesStore _preferences;
  final NotificationDescriber _describe;
  final int _window;
  final DateTime Function() _now;
  final CreateTimer _createTimer;
  late final StreamSubscription<Object?> _tableUpdates;
  late final StreamSubscription<Object?> _preferenceChanges;

  /// The ids the table held after the last run, for [cancelAll] once the
  /// database has gone.
  Set<int> _heldOsIds = const {};
  Future<void>? _running;
  var _requested = false;
  var _disposed = false;
  Timer? _debounceTimer;

  /// Brings the OS in step with the database; a call during a run makes
  /// that run look once more before the returned future completes. Nothing
  /// after [dispose]. Gateway and database errors propagate; the next run
  /// starts from the table as it is.
  Future<void> reconcile() {
    if (_disposed) return Future.value();
    _requested = true;
    return _running ??= _loop().whenComplete(() => _running = null);
  }

  /// [reconcile] for the triggers, which have nobody to report to: an error
  /// is logged and the next trigger starts afresh.
  void reconcileQuietly() => unawaited(
    reconcile().then<void>(
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
  /// fired) or a key that is not one make the snooze a no-op.
  Future<void> snooze({
    required String key,
    required int taskId,
    required Duration duration,
  }) async {
    final now = _now();
    final until = now.add(duration).toUtc();
    final capabilities = await _gateway.capabilities();
    final row = await _snoozedRow(
      key,
      taskId,
      now: now,
      until: until,
      exact: capabilities.exactAlarms,
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
          ).toJson(),
          exact: capabilities.exactAlarms,
        ),
      );
    }
    _log.fine('Snoozed a notification of task $taskId by $duration');
    await reconcile();
  }

  Future<ScheduledNotificationRow?> _snoozedRow(
    String key,
    int taskId, {
    required DateTime now,
    required DateTime until,
    required bool exact,
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
    if (existing != null) {
      return existing.copyWith(
        fireAt: until,
        exact: exact,
        snoozedUntil: Value(until),
        // A second snooze keeps the task's own instant.
        snoozeOriginalFireAt: Value(
          existing.snoozeOriginalFireAt ?? existing.fireAt,
        ),
      );
    }
    final task = await _db.tasksDao.find(resolvedId);
    if (task == null || task.done) return null;
    final instant = switch (parsed.kind) {
      ScheduledNotificationKind.dueDate => task.dueDate,
      ScheduledNotificationKind.reminder =>
        parsed.ordinal < task.reminders.length
            ? task.reminders[parsed.ordinal].reminder
            : null,
    };
    if (instant == null || instant.isAfter(now)) return null;
    final projects = await _db.projectsDao.loadAll();
    final (:title, :body) = _describe(
      task,
      parsed.kind,
      projects.where((p) => p.id == task.projectId).firstOrNull,
    );
    return ScheduledNotificationRow(
      key: resolvedKey,
      osId: nextFreeNotificationOsId(
        notificationOsIdFor(accountId, resolvedKey),
        await dao.osIds(),
      ),
      taskId: resolvedId,
      kind: parsed.kind.name,
      fireAt: until,
      title: title,
      body: body,
      snoozedUntil: until,
      snoozeOriginalFireAt: instant.toUtc(),
      exact: exact,
    );
  }

  /// Cancels every notification the account holds and empties the table.
  /// Works after [dispose] and after the database has closed, from the ids
  /// of the last run; sign-out needs that, because the registry change
  /// disposes the providers before the wipe runs.
  Future<void> cancelAll() async {
    Set<int> osIds;
    try {
      osIds = await _db.scheduledNotificationsDao.osIds();
    } on Object catch (error) {
      _log.fine(
        'Cancelling the notifications of account $accountId from memory: '
        '${error.runtimeType}',
      );
      osIds = _heldOsIds;
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
      await _run();
    }
  }

  Future<void> _run() async {
    final capabilities = await _gateway.capabilities();
    final preferences = await _preferences.read(accountId);
    if (capabilities.permission != NotificationPermission.granted ||
        !preferences.anyEnabled) {
      await cancelAll();
      return;
    }
    final rows = await _db.scheduledNotificationsDao.all();
    final held = await _pendingIds();
    final scheduled = [
      for (final row in rows)
        if (held == null || held.contains(row.osId))
          (
            key: row.key,
            osId: row.osId,
            fireAt: row.fireAt,
            title: row.title,
            body: row.body,
            exact: row.exact,
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
      tasks: await _db.tasksDao.loadOpenTasks(),
      userId: _userId,
      preferences: preferences,
      now: _now(),
      snoozes: snoozes,
      describe: (task, kind) => _describe(task, kind, projects[task.projectId]),
    );
    if (_disposed) return;
    final (:cancelOsIds, :schedule) = diffSchedule(
      desired: desired,
      scheduled: scheduled,
      window: _window,
      exact: capabilities.exactAlarms,
    );
    final window = desired.take(_window).toList();
    final osIds = _assignOsIds(window, rows);

    for (final osId in cancelOsIds) {
      await _gateway.cancel(osId);
    }
    for (final entry in schedule) {
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
          ).toJson(),
          exact: capabilities.exactAlarms,
        ),
      );
    }
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
    _log.fine(
      'Reconciled the notifications of account $accountId: '
      '${cancelOsIds.length} cancelled, ${schedule.length} scheduled, '
      '${window.length} of ${desired.length} pending',
    );
  }

  /// Null when the gateway cannot say, which leaves the table as the only
  /// record.
  Future<Set<int>?> _pendingIds() async {
    try {
      return await _gateway.pendingIds();
    } on Object catch (error) {
      _log.info(
        'Could not list the pending notifications: '
        '${error.runtimeType}',
      );
      return null;
    }
  }

  /// A key keeps the id its row has; a new key takes the hash of the
  /// account and the key, or the next free id above it.
  Map<String, int> _assignOsIds(
    List<DesiredNotification> window,
    List<ScheduledNotificationRow> rows,
  ) {
    final existing = {for (final row in rows) row.key: row.osId};
    final assigned = <String, int>{};
    final taken = <int>{};
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
