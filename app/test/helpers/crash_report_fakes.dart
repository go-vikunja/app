import 'package:flutter_riverpod/misc.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_providers.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_reporter.dart';
import 'package:vikunja_mobile/core/logging/diagnostics_log.dart';

/// A DSN of the shape Sentry gives, for no real project.
const testCrashReportsDsn =
    'https://0123456789abcdef@o1.ingest.example.invalid/1';

/// Records what the reporter hands on; [failStart] makes the next start
/// throw.
class FakeCrashReportSdk implements CrashReportSdk {
  final calls = <String>[];
  final uncaught = <(Object, StackTrace?, bool, String?)>[];
  final errors = <(DiagnosticsEntry, StackTrace?)>[];
  final warnings = <DiagnosticsEntry>[];
  CrashReportStart? started;
  bool failStart = false;

  bool get running =>
      calls.lastWhere(
        (call) => call == 'start' || call == 'stop',
        orElse: () => 'stop',
      ) ==
      'start';

  @override
  Future<void> start(CrashReportStart start) async {
    if (failStart) {
      failStart = false;
      throw StateError('no SDK');
    }
    calls.add('start');
    started = start;
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> deleteUnsent() async => calls.add('deleteUnsent');

  @override
  Future<void> captureUncaught(
    Object error,
    StackTrace? stack, {
    required bool flutter,
    String? library,
  }) async => uncaught.add((error, stack, flutter, library));

  @override
  Future<void> captureError(DiagnosticsEntry entry, StackTrace? stack) async =>
      errors.add((entry, stack));

  @override
  Future<void> addWarning(DiagnosticsEntry entry) async => warnings.add(entry);
}

/// A build with a DSN, whose reports go to [sdk].
List<Override> crashReportOverrides({
  String? dsn = testCrashReportsDsn,
  FakeCrashReportSdk? sdk,
}) => [
  crashReportsDsnProvider.overrideWithValue(dsn),
  crashReportSdkProvider.overrideWithValue(sdk ?? FakeCrashReportSdk()),
];
