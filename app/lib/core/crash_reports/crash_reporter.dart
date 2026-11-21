import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_consent.dart';
import 'package:vikunja_mobile/core/logging/diagnostics_log.dart';
import 'package:vikunja_mobile/core/logging/logging_setup.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';

final _log = Logger('CrashReports');

const _dsnDefine = String.fromEnvironment('VIKUNJA_APP_SENTRY_DSN');

/// The Sentry DSN the build was made with (`--dart-define=
/// VIKUNJA_APP_SENTRY_DSN=…`, D113). Null in a build without one, which
/// has no crash reports at all: no switch, no question, no SDK.
String? get buildCrashReportsDsn {
  final dsn = _dsnDefine.trim();
  return dsn.isEmpty ? null : dsn;
}

typedef CrashReportStart = ({
  String dsn,
  AppPart part,

  /// The registered servers' hosts, read for each report.
  Iterable<String> Function() hosts,
});

/// What the reporter hands its reports to: Sentry in the app, a fake in
/// tests.
abstract interface class CrashReportSdk {
  /// Throws when the SDK could not start.
  Future<void> start(CrashReportStart start);

  Future<void> stop();

  /// The reports the native SDKs keep on the device until they are sent.
  Future<void> deleteUnsent();

  Future<void> captureUncaught(
    Object error,
    StackTrace? stack, {
    required bool flutter,
    String? library,
  });

  /// A log record from SEVERE up, as the diagnostics log keeps it.
  Future<void> captureError(DiagnosticsEntry entry, StackTrace? stack);

  /// A WARNING record, kept as a breadcrumb for the next report.
  Future<void> addWarning(DiagnosticsEntry entry);
}

enum _Phase { undecided, running, stopped }

CrashReporter? _current;

/// This isolate's reporter, if one was made: a background task that runs
/// in the app's isolate uses the app's.
CrashReporter? get currentCrashReporter => _current;

/// Hands uncaught errors (through the hooks of `configureLogging`) and the
/// app's log records to [sdk] while the user allows crash reports: SEVERE
/// and SHOUT records become reports, WARNING records breadcrumbs, both as
/// redacted as the diagnostics log keeps them. Until [follow] is first
/// called, up to [bufferLimit] of them wait in memory, a report only once;
/// they are sent only if that consent allows it. Silent Flutter errors (an
/// image that failed to load) stay in the log only, a report that repeats
/// one of the last [repeatWindow] is dropped, and at most [reportLimit] go
/// out per isolate run, each counted when it reaches [sdk]; breadcrumbs
/// have no limit. [storedConsent], for a background isolate, is read again
/// before each report that the repeats and the limit may still let out,
/// which goes, and counts, only while it allows reports. Without a [dsn] it
/// does nothing at all.
final class CrashReporter {
  new({
    required this.dsn,
    required this.part,
    required this.sdk,
    this.deletesUnsent = false,
    this.storedConsent,
    this.bufferLimit = 20,
    this.reportLimit = 20,
    this.repeatWindow = const Duration(minutes: 10),
    this.clock = DateTime.now,
  }) {
    if (dsn == null) return;
    _records = Logger.root.onRecord.listen(_onRecord);
    listenToUncaughtErrors(_onUncaught);
    _current = this;
  }

  final String? dsn;
  final AppPart part;
  final CrashReportSdk sdk;

  /// Whether turning crash reports off deletes what the native SDKs keep:
  /// only the app's isolate starts them.
  final bool deletesUnsent;

  /// Never throws.
  final Future<CrashReportConsent> Function()? storedConsent;
  final int bufferLimit;
  final int reportLimit;
  final Duration repeatWindow;
  final DateTime Function() clock;

  /// The registered servers' hosts, which every report leaves out.
  Set<String> hosts = const {};

  StreamSubscription<LogRecord>? _records;
  _Phase _phase = _Phase.undecided;
  CrashReportConsent? _wanted;
  Future<void> _changes = Future.value();
  final _waiting = <(Future<void> Function(), String?)>[];
  final _sending = <Future<void>>{};
  final _lastSeen = <String, DateTime>{};
  final _checking = <String>{};
  var _reports = 0;

  bool get running => _phase == _Phase.running;

  /// Starts the SDK when [consent] allows reports, else stops it and, in
  /// the app's isolate, deletes the unsent reports; at once, in the order
  /// of the calls. Never throws.
  Future<void> follow(CrashReportConsent consent) {
    if (dsn == null) return Future.value();
    _wanted = consent;
    return _changes = _changes.then((_) => _apply());
  }

  Future<void> _apply() async {
    final wanted = _wanted;
    if (wanted == CrashReportConsent.allowed) {
      if (_phase == _Phase.running) return;
      try {
        await sdk.start((dsn: dsn!, part: part, hosts: () => hosts));
      } on Object catch (error) {
        _phase = _Phase.stopped;
        _waiting.clear();
        _log.warning('Could not start the crash reports: ${error.runtimeType}');
        return;
      }
      _phase = _Phase.running;
      // A choice made during the start is queued and clears what waited.
      if (_wanted != CrashReportConsent.allowed) return;
      final waiting = List.of(_waiting);
      _waiting.clear();
      for (final (report, signature) in waiting) {
        _deliver(report, signature);
      }
      return;
    }
    final wasRunning = _phase == _Phase.running;
    _phase = _Phase.stopped;
    _waiting.clear();
    if (wasRunning) {
      try {
        await sdk.stop();
      } on Object catch (error) {
        _log.warning('Could not stop the crash reports: ${error.runtimeType}');
      }
    }
    if (deletesUnsent && wanted == CrashReportConsent.declined) {
      await sdk.deleteUnsent();
    }
  }

  // Never logs: a record logged here would come back to it.
  void _onRecord(LogRecord record) {
    if (record.level < Level.WARNING || record.object is UncaughtErrorReport) {
      return;
    }
    try {
      final entry = DiagnosticsEntry.capture(record, part: part.name);
      final stack = record.stackTrace;
      if (record.level < Level.SEVERE) {
        _hand(() => sdk.addWarning(entry));
      } else {
        _hand(
          () => sdk.captureError(entry, stack),
          signature: '${entry.logger}: ${entry.message}',
        );
      }
    } on Object {
      // Dropped, like a record the diagnostics log cannot keep.
    }
  }

  void _onUncaught(
    Object error,
    StackTrace? stack, {
    required bool flutter,
    required bool silent,
    String? library,
  }) {
    if (silent) return;
    _hand(
      () =>
          sdk.captureUncaught(error, stack, flutter: flutter, library: library),
      signature: '${error.runtimeType} at ${_firstFrame(stack)}',
    );
  }

  /// A [signature] makes it a report, which repeats and the limit count
  /// and which checks [storedConsent]; without one it is a breadcrumb,
  /// which stays in memory.
  void _hand(Future<void> Function() report, {String? signature}) {
    switch (_phase) {
      case _Phase.stopped:
        return;
      case _Phase.running:
        _deliver(report, signature);
      // A repeat of one waiting would only be dropped at the drain, after
      // taking another report's place.
      case _Phase.undecided
          when _waiting.length < bufferLimit && !_isWaiting(signature):
        _waiting.add((report, signature));
      case _Phase.undecided:
        break;
    }
  }

  bool _isWaiting(String? signature) =>
      signature != null && _waiting.any((waiting) => waiting.$2 == signature);

  // A report counts only when it goes to the SDK: not one dropped from the
  // full buffer, cleared with it or dropped by the stored choice.
  void _deliver(Future<void> Function() report, String? signature) {
    if (signature == null) {
      _send(report);
    } else if (storedConsent case final read?) {
      // Checked before the read too, without counting: else an error loop
      // starts a read for every repeat and every report past the limit.
      if (!_mayAdmit(signature)) return;
      _checking.add(signature);
      _send(() => _checked(read, report, signature));
    } else if (_admits(signature)) {
      _send(report);
    }
  }

  bool _repeats(String signature, DateTime now) {
    final last = _lastSeen[signature];
    return last != null && now.difference(last) < repeatWindow;
  }

  bool _mayAdmit(String signature) =>
      !_checking.contains(signature) &&
      !_repeats(signature, clock()) &&
      _reports + _checking.length < reportLimit;

  bool _admits(String signature) {
    final now = clock();
    if (_repeats(signature, now) || _reports >= reportLimit) return false;
    _reports++;
    _lastSeen[signature] = now;
    return true;
  }

  void _send(Future<void> Function() report) {
    final Future<void> sending;
    try {
      sending = report();
    } on Object {
      return;
    }
    _sending.add(sending);
    unawaited(
      sending
          .then<void>((_) {}, onError: (Object _) {})
          .whenComplete(() => _sending.remove(sending)),
    );
  }

  Future<void> _checked(
    Future<CrashReportConsent> Function() read,
    Future<void> Function() report,
    String signature,
  ) async {
    final CrashReportConsent consent;
    // Before the report is sent, so that one on its way holds no second
    // place in the limit.
    try {
      consent = await read();
    } finally {
      _checking.remove(signature);
    }
    if (consent != CrashReportConsent.allowed) {
      await follow(consent);
      return;
    }
    if (_phase == _Phase.running && _admits(signature)) await report();
  }

  /// Waits up to [timeout] in all for the reports on their way: a
  /// background isolate may end once its work is done.
  Future<void> flush({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      await () async {
        await _changes;
        await Future.wait(List.of(_sending));
      }().timeout(timeout);
    } on Object {
      // What is still on its way may be lost.
    }
  }

  /// Stops listening; the SDK stays as it is.
  Future<void> dispose() async {
    await _records?.cancel();
    _records = null;
    if (identical(_current, this)) {
      _current = null;
      listenToUncaughtErrors(null);
    }
  }
}

// Only to tell repeats apart; it never leaves the device.
String _firstFrame(StackTrace? stack) {
  if (stack == null) return '';
  for (final line in '$stack'.split('\n')) {
    if (line.trim().isNotEmpty) return line.trim();
  }
  return '';
}
