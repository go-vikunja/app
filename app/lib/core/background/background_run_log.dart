import 'dart:convert';

import 'package:vikunja_mobile/core/storage/preferences_store.dart';

enum BackgroundRunOutcome {
  /// Every account's steps ran without a failure.
  completed,

  /// Some step of some account failed (offline, a server error, a session
  /// that ended); the rest ran.
  partial,

  /// The deadline stopped the run before every account had its turn.
  deadline,

  /// The OS stopped the run before it was done (Android: constraints lost,
  /// Doze, standby bucket, quota).
  stopped,

  /// The app was in front, or came to the front during the run, which
  /// keeps its accounts fresh itself.
  skipped,

  /// No account could run at all.
  nothing,
}

/// How an account's last turn in a background run ended.
enum BackgroundAccountOutcome {
  /// The sync step went through (the session was renewed on the way).
  synced,

  /// The server could not be reached.
  unreachable,

  /// The session's renewal waits for the next run: too little time was
  /// left for its answer, or another part of the app was renewing it.
  deferred,

  /// Secure storage refused to read the account's tokens.
  storageUnreadable,

  /// A step failed otherwise.
  failed,

  /// The session ended during this turn.
  sessionEnded,

  /// The account already waited for a new sign-in.
  signInNeeded,

  /// The OS (with its stop reason) or the run's own deadline (without one)
  /// stopped the run during this turn.
  stopped,
}

typedef BackgroundTurn = ({
  BackgroundAccountOutcome outcome,
  DateTime at,
  int? stopReason,
});

/// What the background runner and the UI isolate tell each other through
/// the preferences store, which every isolate reads afresh: the UI's
/// heartbeat while it is in front, when the runner last gave each account
/// its turn and when it last synced it. Instants are ISO 8601 UTC.
final class BackgroundRunLog {
  new(this._store);

  static const heartbeatKey = 'background.foregroundHeartbeat';
  static const lastRunResultKey = 'background.lastRunResult';

  static String lastRunAtKey(String accountId) =>
      'background.lastRunAt.$accountId';

  static String lastAttemptAtKey(String accountId) =>
      'background.lastAttemptAt.$accountId';

  static String lastOutcomeKey(String accountId) =>
      'background.lastOutcome.$accountId';

  final PreferencesStore _store;

  /// The UI isolate is in front at [now].
  Future<void> beat(DateTime now) => _store.setString(heartbeatKey, _iso(now));

  Future<DateTime?> lastHeartbeat() async =>
      _parse(await _store.getString(heartbeatKey));

  /// The runner synced the account successfully at [at].
  Future<void> recordAccountRun(String accountId, DateTime at) =>
      _store.setString(lastRunAtKey(accountId), _iso(at));

  Future<DateTime?> lastRunAt(String accountId) async =>
      _parse(await _store.getString(lastRunAtKey(accountId)));

  /// The account's turn in a run began at [at], whatever came of it.
  Future<void> recordAttempt(String accountId, DateTime at) =>
      _store.setString(lastAttemptAtKey(accountId), _iso(at));

  Future<DateTime?> lastAttemptAt(String accountId) async =>
      _parse(await _store.getString(lastAttemptAtKey(accountId)));

  /// The account's turn that began at [lastAttemptAt] ended with
  /// [outcome]; [stopReason] is the OS's reason for a stop, as Android's
  /// `WorkInfo` numbers it, null when the run's own deadline stopped it.
  Future<void> recordAccountOutcome(
    String accountId,
    BackgroundAccountOutcome outcome, {
    required DateTime at,
    int? stopReason,
  }) => _store.setString(
    lastOutcomeKey(accountId),
    jsonEncode({
      'at': _iso(at),
      'outcome': outcome.name,
      'stopReason': ?stopReason,
    }),
  );

  Future<BackgroundTurn?> lastOutcome(String accountId) async {
    final raw = await _store.getString(lastOutcomeKey(accountId));
    if (raw == null) return null;
    try {
      if (jsonDecode(raw)
          case {'at': final String at, 'outcome': final String outcome} &&
              final Map<String, Object?> json) {
        final parsed = BackgroundAccountOutcome.values.asNameMap()[outcome];
        final when = _parse(at);
        if (parsed != null && when != null) {
          return (
            outcome: parsed,
            at: when,
            stopReason: json['stopReason'] as int?,
          );
        }
      }
    } on Object {
      // Falls through: an unreadable record counts as none.
    }
    return null;
  }

  Future<void> recordResult(BackgroundRunOutcome outcome, DateTime at) =>
      _store.setString(
        lastRunResultKey,
        jsonEncode({'at': _iso(at), 'result': outcome.name}),
      );

  Future<({BackgroundRunOutcome outcome, DateTime at})?> lastResult() async {
    final raw = await _store.getString(lastRunResultKey);
    if (raw == null) return null;
    try {
      if (jsonDecode(raw) case {
        'at': final String at,
        'result': final String result,
      }) {
        final outcome = BackgroundRunOutcome.values.asNameMap()[result];
        final when = _parse(at);
        if (outcome != null && when != null) {
          return (outcome: outcome, at: when);
        }
      }
    } on FormatException {
      // Falls through: an unreadable record counts as none.
    }
    return null;
  }

  /// Sign-out: the account's entries go with it.
  Future<void> forget(String accountId) async {
    await _store.remove(lastRunAtKey(accountId));
    await _store.remove(lastAttemptAtKey(accountId));
    await _store.remove(lastOutcomeKey(accountId));
  }

  static String _iso(DateTime moment) => moment.toUtc().toIso8601String();

  static DateTime? _parse(String? raw) =>
      raw == null ? null : DateTime.tryParse(raw)?.toUtc();
}
