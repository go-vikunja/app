import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/background/background_providers.dart';
import 'package:vikunja_mobile/core/background/background_run_log.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/logging/redaction.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/core/outbox/failure_json.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/core/platform/background_permissions.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/support/session_end_log.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/home/application/app_version.dart';
import 'package:vikunja_mobile/features/notifications/application/os_notification_capabilities.dart';

part 'support_details.g.dart';

final _log = Logger('SupportDetails');

/// A part of the support details as it was read, possibly as none, or
/// [known] false when reading it failed.
@immutable
final class Collected<T extends Object> {
  const new(this.value) : known = true;

  const new unknown() : value = null, known = false;

  final T? value;
  final bool known;
}

typedef SyncTimes = ({DateTime? last, DateTime? full});
typedef BackgroundTurn = ({DateTime? started, DateTime? synced});
typedef BackgroundRunResult = ({BackgroundRunOutcome outcome, DateTime at});

@immutable
final class SupportSnapshot {
  const new({
    required this.createdAt,
    required this.device,
    required this.accounts,
  });

  final DateTime createdAt;
  final DeviceSupport device;

  /// In registry order.
  final Collected<List<AccountSupport>> accounts;
}

@immutable
final class DeviceSupport {
  const new({
    required this.platform,
    required this.app,
    required this.osVersion,
    required this.deviceLocale,
    required this.notifications,
    required this.background,
    required this.lastBackgroundRun,
  });

  /// `android` or `ios`, as `Platform.operatingSystem` names it.
  final String platform;
  final Collected<AppVersion> app;
  final Collected<String> osVersion;
  final Collected<String> deviceLocale;
  final Collected<NotificationCapabilities> notifications;
  final Collected<BackgroundState> background;
  final Collected<BackgroundRunResult> lastBackgroundRun;

  bool get isIos => platform == 'ios';
}

@immutable
final class AccountSupport {
  const new({
    required this.isGuest,
    required this.active,
    required this.needsSignIn,
    required this.server,
    required this.serverVersion,
    required this.tier,
    required this.apiVersions,
    required this.apiV2Missing,
    required this.features,
    required this.syncTimes,
    required this.syncInSession,
    required this.sendingInSession,
    required this.backgroundTurn,
    required this.queue,
    required this.notifications,
    required this.lastSessionEnd,
  });

  final bool isGuest;
  final bool active;
  final bool needsSignIn;

  /// Shown only when the user asks for the addresses.
  final Uri server;

  /// As the server reported it; sanitised when rendered.
  final String serverVersion;
  final SupportTier tier;
  final Set<ApiVersion> apiVersions;
  final bool apiV2Missing;
  final Set<Capability> features;
  final Collected<SyncTimes> syncTimes;

  /// Null when this app session has no sync engine for the account.
  final Collected<String> syncInSession;

  /// Null when this app session has no outbox sender for the account.
  final Collected<String> sendingInSession;
  final Collected<BackgroundTurn> backgroundTurn;
  final Collected<QueueSummary> queue;
  final Collected<NotificationPreferences> notifications;
  final Collected<SessionEndRecord> lastSessionEnd;
}

/// One queued op as the support details read it: never its payload or
/// task.
@immutable
final class QueuedOp {
  const new({
    required this.kind,
    required this.state,
    required this.createdAt,
    this.attempts = 0,
    this.nextAttemptAt,
    this.lastError,
    this.sentAt,
  });

  final String kind;
  final String state;
  final DateTime createdAt;
  final int attempts;
  final DateTime? nextAttemptAt;

  /// The stored failure JSON, of which only [failureLabel]'s keys are read.
  final String? lastError;
  final DateTime? sentAt;
}

@immutable
final class QueueSummary {
  const new({
    this.byKind = const {},
    this.fresh = 0,
    this.waiting = 0,
    this.dueAgain = 0,
    this.heldForSignIn = 0,
    this.inFlight = 0,
    this.failed = 0,
    this.otherState = 0,
    this.lastErrors = const {},
    this.mayHaveReachedServer = 0,
    this.mostAttempts = 0,
    this.oldest,
  });

  factory of(Iterable<QueuedOp> ops) {
    final byKind = <String, int>{};
    final lastErrors = <String, int>{};
    var fresh = 0;
    var waiting = 0;
    var dueAgain = 0;
    var heldForSignIn = 0;
    var inFlight = 0;
    var failed = 0;
    var otherState = 0;
    var mayHaveReachedServer = 0;
    var mostAttempts = 0;
    DateTime? oldest;
    for (final op in ops) {
      final kind = _word(op.kind);
      byKind[kind] = (byKind[kind] ?? 0) + 1;
      final error = _failureFields(op.lastError);
      if (error != null) {
        final label = _labelOf(error);
        lastErrors[label] = (lastErrors[label] ?? 0) + 1;
      }
      if (op.state == OutboxState.pending.name) {
        if (op.nextAttemptAt != null) {
          waiting++;
        } else if (op.lastError == null) {
          fresh++;
        } else if (error?['kind'] == 'session_ended') {
          heldForSignIn++;
        } else {
          dueAgain++;
        }
      } else if (op.state == OutboxState.sending.name) {
        inFlight++;
      } else if (op.state == OutboxState.failed.name) {
        failed++;
      } else {
        otherState++;
      }
      if (op.sentAt != null) mayHaveReachedServer++;
      if (op.attempts > mostAttempts) mostAttempts = op.attempts;
      if (oldest == null || op.createdAt.isBefore(oldest)) {
        oldest = op.createdAt;
      }
    }
    return QueueSummary(
      byKind: byKind,
      fresh: fresh,
      waiting: waiting,
      dueAgain: dueAgain,
      heldForSignIn: heldForSignIn,
      inFlight: inFlight,
      failed: failed,
      otherState: otherState,
      lastErrors: lastErrors,
      mayHaveReachedServer: mayHaveReachedServer,
      mostAttempts: mostAttempts,
      oldest: oldest,
    );
  }

  /// Op kinds as stored, letters only.
  final Map<String, int> byKind;

  /// Pending and never tried.
  final int fresh;

  /// Pending behind a backoff.
  final int waiting;

  /// Pending after a failure, without a backoff ("Send now").
  final int dueAgain;

  /// Pending until the account signs in again.
  final int heldForSignIn;
  final int inFlight;
  final int failed;

  /// A state this version does not know.
  final int otherState;

  /// [failureLabel]s of the ops' last errors.
  final Map<String, int> lastErrors;

  /// Ops with `sent_at`: an attempt may have reached the server without an
  /// answer.
  final int mayHaveReachedServer;
  final int mostAttempts;
  final DateTime? oldest;

  int get total => byKind.values.fold(0, (sum, count) => sum + count);
}

/// The queue of [db] through its own query: the columns of [QueuedOp] only.
Future<QueueSummary> readQueueSummary(AppDatabase db) async {
  final outbox = db.outbox;
  final query = db.selectOnly(outbox)
    ..addColumns([
      outbox.kind,
      outbox.state,
      outbox.attempts,
      outbox.nextAttemptAt,
      outbox.lastError,
      outbox.sentAt,
      outbox.createdAt,
    ]);
  final rows = await query.get();
  return QueueSummary.of([
    for (final row in rows)
      if (row.readWithConverter<DateTime, int>(outbox.createdAt)
          case final createdAt?)
        QueuedOp(
          kind: row.read(outbox.kind) ?? '',
          state: row.read(outbox.state) ?? '',
          createdAt: createdAt,
          attempts: row.read(outbox.attempts) ?? 0,
          nextAttemptAt: row.readWithConverter<DateTime?, int>(
            outbox.nextAttemptAt,
          ),
          lastError: row.read(outbox.lastError),
          sentAt: row.readWithConverter<DateTime?, int>(outbox.sentAt),
        ),
  ]);
}

/// The two sync times of [db], read as single keys: the table also holds
/// the account's settings.
Future<SyncTimes> readSyncTimes(AppDatabase db) async {
  final keys = {SyncStateKeys.lastSyncedAt, SyncStateKeys.lastFullSyncAt};
  final rows = await (db.select(
    db.syncState,
  )..where((row) => row.key.isIn(keys))).get();
  final values = {for (final row in rows) row.key: row.value};
  DateTime? parse(String key) => switch (values[key]) {
    final String raw => DateTime.tryParse(raw)?.toUtc(),
    null => null,
  };
  return (
    last: parse(SyncStateKeys.lastSyncedAt),
    full: parse(SyncStateKeys.lastFullSyncAt),
  );
}

/// A stored failure's kind and its problem or reason, code and HTTP
/// status: never its message.
String? failureLabel(String? json) => switch (_failureFields(json)) {
  final fields? => _labelOf(fields),
  null => null,
};

Map<String, Object?>? _failureFields(String? json) {
  if (json == null) return null;
  try {
    if (jsonDecode(json) case final Map<String, Object?> map) {
      return {
        for (final key in const [
          'kind',
          'problem',
          'reason',
          'code',
          'status_code',
        ])
          if (map.containsKey(key)) key: map[key],
      };
    }
  } on FormatException {
    // Falls through: unreadable.
  }
  return const {'kind': 'unreadable'};
}

String _labelOf(Map<String, Object?> fields) {
  final kind = switch (fields['kind']) {
    final String kind when _word(kind).isNotEmpty => _word(kind),
    _ => 'unknown',
  };
  final detail = switch (fields['problem'] ?? fields['reason']) {
    final String detail when _word(detail).isNotEmpty => '/${_word(detail)}',
    _ => '',
  };
  final code = switch (fields['code']) {
    final int code => ' code $code',
    _ => '',
  };
  final status = switch (fields['status_code']) {
    final int status => ' HTTP $status',
    _ => '',
  };
  return '$kind$detail$code$status';
}

String _word(String raw) {
  final word = raw.replaceAll(RegExp('[^A-Za-z_]'), '');
  return word.length > 40 ? word.substring(0, 40) : word;
}

/// What the support details show, collected once when the page opens.
@riverpod
Future<SupportSnapshot> supportSnapshot(Ref ref) async {
  final createdAt = ref.read(clockProvider)().toUtc();
  final device = await _collectDevice(ref);
  final accounts = await _collect('accounts', () => _collectAccounts(ref));
  return SupportSnapshot(
    createdAt: createdAt,
    device: device,
    accounts: accounts,
  );
}

Future<Collected<T>> _collect<T extends Object>(
  String part,
  FutureOr<T?> Function() read,
) async {
  try {
    return Collected<T>(await read());
  } on Object catch (error) {
    _log.info('Support details without $part: ${error.runtimeType}');
    return Collected<T>.unknown();
  }
}

Future<DeviceSupport> _collectDevice(Ref ref) async {
  final identity = await _collect(
    'the client identity',
    () => ref.read(clientIdentityProvider),
  );
  final osVersion = identity.value?.osVersion ?? '';
  return DeviceSupport(
    platform:
        identity.value?.platform ?? defaultTargetPlatform.name.toLowerCase(),
    app: await _collect('the app version', () => ref.read(appVersionProvider)),
    osVersion: osVersion.isEmpty
        ? const Collected.unknown()
        : Collected(osVersion),
    deviceLocale: await _collect(
      'the device locale',
      () => PlatformDispatcher.instance.locale.toString(),
    ),
    notifications: await _collect(
      'the notification permission',
      () => ref.read(osNotificationCapabilitiesProvider.future),
    ),
    background: await _collect(
      'the background state',
      () => ref.read(backgroundPermissionsProvider).read(),
    ),
    lastBackgroundRun: await _collect(
      'the last background run',
      () => ref.read(backgroundRunLogProvider).lastResult(),
    ),
  );
}

Future<List<AccountSupport>> _collectAccounts(Ref ref) async {
  final state = await ref.read(accountsProvider.future);
  return [
    for (final entry in state.accounts)
      await _collectAccount(
        ref,
        entry,
        active: entry.id == state.activeAccountId,
      ),
  ];
}

Future<AccountSupport> _collectAccount(
  Ref ref,
  RegisteredAccount entry, {
  required bool active,
}) async {
  final id = entry.id;
  final connection = entry.connection;
  final info = connection.info;
  return AccountSupport(
    isGuest: entry.account.isLinkShare,
    active: active,
    needsSignIn: entry.account.needsReauth,
    server: connection.rootUri,
    serverVersion: info.version?.display ?? info.rawVersion,
    tier: connection.capabilities.tier,
    apiVersions: connection.apiVersions,
    apiV2Missing: connection.apiV2Missing,
    features: connection.capabilities.all,
    syncTimes: await _collect(
      'the sync times',
      () => readSyncTimes(ref.read(appDatabaseProvider(id))),
    ),
    syncInSession: await _collect('the sync status', () async {
      if (!ref.exists(syncEngineProvider(id))) return null;
      return _syncLabel(ref.read(syncEngineProvider(id)).currentStatus);
    }),
    sendingInSession: await _collect('the sender state', () async {
      if (!ref.exists(outboxSenderProvider(id))) return null;
      return _senderLabel(ref.read(outboxSenderProvider(id)));
    }),
    backgroundTurn: await _collect('the background turn', () async {
      final log = ref.read(backgroundRunLogProvider);
      return (
        started: await log.lastAttemptAt(id),
        synced: await log.lastRunAt(id),
      );
    }),
    queue: await _collect(
      'the queue',
      () => readQueueSummary(ref.read(appDatabaseProvider(id))),
    ),
    notifications: await _collect(
      'the notification settings',
      () => ref.read(notificationPreferencesStoreProvider).read(id),
    ),
    lastSessionEnd: await _collect(
      'the last session end',
      () => ref.read(sessionEndLogProvider).read(id),
    ),
  );
}

String _syncLabel(SyncStatus status) => switch (status) {
  SyncNeverRun() => 'never run',
  SyncRunning() => 'running',
  SyncIdle() => 'idle',
  SyncFailed(:final failure) => 'failed, ${_labelOf(failureToJson(failure))}',
};

String _senderLabel(OutboxSender sender) => switch (sender.blockedBy) {
  final failure? =>
    '${sender.state.name}, blocked by ${_labelOf(failureToJson(failure))}',
  null => sender.state.name,
};

/// The support details as plain English "key: value" lines, the same in
/// every app language so reports compare. Hosts only with [showServers].
String renderSupportDetails(
  SupportSnapshot snapshot, {
  required bool showServers,
  required String appLanguage,
}) {
  final lines = <String>[
    'Support details',
    'Created: ${_time(snapshot.createdAt)}',
    ..._deviceLines(snapshot.device, appLanguage: appLanguage),
  ];
  final accounts = snapshot.accounts;
  if (!accounts.known) {
    lines.addAll(['', 'Accounts: unknown']);
  } else if (accounts.value case final list? when list.isNotEmpty) {
    final servers = <Uri, int>{};
    for (final account in list) {
      servers.putIfAbsent(account.server, () => servers.length + 1);
    }
    for (final (index, account) in list.indexed) {
      lines
        ..add('')
        ..addAll(
          _accountLines(
            account,
            number: index + 1,
            server: showServers
                ? describeUriForLog(account.server)
                : '<server-${servers[account.server]}>',
          ),
        );
    }
  } else {
    lines.addAll(['', 'Accounts: none']);
  }
  return redactSecrets('${lines.join('\n')}\n');
}

List<String> _deviceLines(DeviceSupport device, {required String appLanguage}) {
  final app = _known(
    device.app,
    (app) => app.build.isEmpty
        ? _token(app.version)
        : '${_token(app.version)} (${_token(app.build)})',
  );
  final os = _known(device.osVersion, _token);
  final locale = _known(
    device.deviceLocale,
    (locale) => locale.replaceAll(RegExp('[^A-Za-z0-9_-]'), ''),
  );
  final permission = _known(
    device.notifications,
    (capabilities) => switch (capabilities.permission) {
      NotificationPermission.granted => 'allowed',
      NotificationPermission.denied => 'denied',
      NotificationPermission.notAsked => 'not asked yet',
    },
  );
  final exactAlarms = device.isIos
      ? 'n/a'
      : _known(
          device.notifications,
          (capabilities) =>
              capabilities.exactAlarms ? 'allowed' : 'not allowed',
        );
  final state = device.background.value ?? const BackgroundState();
  // Exempt from it means the optimisation is off for the app.
  final batteryOptimisation = switch (state.ignoresBatteryOptimizations) {
    true => 'off',
    false => 'on',
    null => 'unknown',
  };
  final powerSaving = _onOff(state.powerSaveMode);
  final lowPowerMode = _onOff(state.lowPowerMode);
  final lastRun = _recorded(
    device.lastBackgroundRun,
    (run) => '${run.outcome.name}, ${_time(run.at)}',
  );
  return [
    'App: $app',
    'Platform: ${_token(device.platform)} $os',
    'Language: app ${_token(appLanguage)}, device $locale',
    'Notifications: $permission',
    'Exact alarms: $exactAlarms',
    if (device.isIos) ...[
      'Background App Refresh: ${state.backgroundRefresh ?? 'unknown'}',
      'Low Power Mode: $lowPowerMode',
    ] else ...[
      'Battery optimisation: $batteryOptimisation',
      if (state.backgroundRestricted case final restricted?)
        'Background restricted: ${restricted ? 'yes' : 'no'}',
      if (state.standbyBucket case final bucket?) 'Standby bucket: $bucket',
      'Power saving: $powerSaving',
    ],
    'Last background run: $lastRun',
  ];
}

List<String> _accountLines(
  AccountSupport account, {
  required int number,
  required String server,
}) {
  final apis = switch ((
    account.apiVersions.contains(ApiVersion.v1),
    account.apiVersions.contains(ApiVersion.v2),
  )) {
    (true, true) => 'API v1 and v2',
    (true, false) => 'API v1',
    (false, true) => 'API v2',
    (false, false) => 'no API',
  };
  final version = _token(account.serverVersion);
  final features = [for (final capability in account.features) capability.name]
    ..sort();
  final syncTimes = account.syncTimes;
  String syncTime(DateTime? time) => !syncTimes.known
      ? 'unknown'
      : time == null
      ? 'never'
      : _time(time);
  final notifications = _known(
    account.notifications,
    (preferences) => [
      'reminders ${_onOff(preferences.reminders)}',
      'due dates ${_onOff(preferences.dueDates)}',
      'activity ${_onOff(preferences.activity)}',
    ].join(', '),
  );
  final support = [
    account.tier.name,
    apis,
    if (account.apiV2Missing) 'v2 missing',
  ].join(', ');
  final sessionEnd = _recorded(
    account.lastSessionEnd,
    (end) => '${end.reason}, ${_partName(end.part)}, ${_time(end.at)}',
  );
  return [
    'Account $number${account.active ? ' (active)' : ''}',
    'Kind: ${account.isGuest ? 'guest' : 'user'}',
    'Sign-in: ${account.needsSignIn ? 'needs sign-in' : 'signed in'}',
    'Server: $server',
    'Server version: ${version.isEmpty ? 'unknown' : version}',
    'Server support: $support',
    'Features: ${features.isEmpty ? 'none' : features.join(', ')}',
    'Last sync: ${syncTime(syncTimes.value?.last)}',
    'Last full sync: ${syncTime(syncTimes.value?.full)}',
    if (_present(account.syncInSession) case final status?)
      'Sync in this session: $status',
    if (_present(account.sendingInSession) case final state?)
      'Sending in this session: $state',
    'Background turn: ${_recorded(account.backgroundTurn, _turn)}',
    ..._queueLines(account.queue),
    'Notifications: $notifications',
    'Last session end: $sessionEnd',
  ];
}

List<String> _queueLines(Collected<QueueSummary> collected) {
  final queue = collected.value;
  if (!collected.known || queue == null) return ['Unsent changes: unknown'];
  if (queue.total == 0) return ['Unsent changes: 0'];
  // A failure's label may end in a number, so its count goes first.
  String counts(Map<String, int> counts, {bool countFirst = false}) {
    final entries = counts.entries.toList()
      ..sort(
        (a, b) => b.value != a.value
            ? b.value.compareTo(a.value)
            : a.key.compareTo(b.key),
      );
    return [
      for (final MapEntry(:key, :value) in entries)
        if (countFirst) '$value $key' else '$key $value',
    ].join(', ');
  }

  final states = [
    'new ${queue.fresh}',
    'waiting ${queue.waiting}',
    if (queue.dueAgain > 0) 'due again ${queue.dueAgain}',
    'held for sign-in ${queue.heldForSignIn}',
    'in flight ${queue.inFlight}',
    'failed ${queue.failed}',
    if (queue.otherState > 0) 'other ${queue.otherState}',
  ];
  return [
    'Unsent changes: ${queue.total} (${counts(queue.byKind)})',
    '  ${states.join(', ')}',
    if (queue.lastErrors.isNotEmpty)
      '  last errors: ${counts(queue.lastErrors, countFirst: true)}',
    '  may have reached the server: ${queue.mayHaveReachedServer}',
    '  most attempts: ${queue.mostAttempts}',
    if (queue.oldest case final oldest?) '  oldest: ${_time(oldest)}',
  ];
}

String _turn(BackgroundTurn turn) => switch (turn) {
  (started: null, synced: null) => 'none recorded',
  (:final started, :final synced) =>
    'started ${started == null ? 'never' : _time(started)}, '
        'synced ${synced == null ? 'never' : _time(synced)}',
};

String _partName(String part) => switch (AppPart.values.asNameMap()[part]) {
  AppPart.app => 'app',
  AppPart.backgroundRun => 'background run',
  AppPart.notificationAction => 'notification action',
  AppPart.widgetAction => 'widget action',
  null => part,
};

/// Null while the part does not exist in this session; `unknown` when it
/// could not be read.
String? _present(Collected<String> collected) =>
    collected.known ? collected.value : 'unknown';

String _known<T extends Object>(
  Collected<T> collected,
  String Function(T value) describe,
) => switch (collected.value) {
  final value? when collected.known => describe(value),
  _ => 'unknown',
};

String _recorded<T extends Object>(
  Collected<T> collected,
  String Function(T value) describe,
) => !collected.known
    ? 'unknown'
    : switch (collected.value) {
        final value? => describe(value),
        null => 'none recorded',
      };

String _onOff(bool? on) => switch (on) {
  true => 'on',
  false => 'off',
  null => 'unknown',
};

String _token(String value) {
  final token = value.replaceAll(RegExp('[^A-Za-z0-9.+_-]'), '');
  return token.length > 40 ? token.substring(0, 40) : token;
}

String _time(DateTime time) {
  final utc = time.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-'
      '${two(utc.day)} ${two(utc.hour)}:${two(utc.minute)} UTC';
}
