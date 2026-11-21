import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/background/background_entry_point.dart';
import 'package:vikunja_mobile/core/background/background_run_log.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_consent.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_reporter.dart';
import 'package:vikunja_mobile/core/logging/diagnostics_log.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';

import '../../helpers/crash_report_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Duration flush(
    TargetPlatform platform, {
    required Duration elapsed,
    Duration deadline = const Duration(seconds: 25),
  }) => backgroundFlushTimeout(platform, deadline: deadline, elapsed: elapsed);

  test('on iOS the crash reports get at most 2 s after a run, and never '
      "past the run's deadline", () {
    expect(
      flush(TargetPlatform.iOS, elapsed: const Duration(seconds: 3)),
      const Duration(seconds: 2),
    );
    expect(
      flush(TargetPlatform.iOS, elapsed: const Duration(milliseconds: 24500)),
      const Duration(milliseconds: 500),
    );
    expect(
      flush(TargetPlatform.iOS, elapsed: const Duration(seconds: 25)),
      Duration.zero,
    );
    expect(
      flush(TargetPlatform.iOS, elapsed: const Duration(seconds: 31)),
      Duration.zero,
    );
  });

  test('on Android they get 5 s, well within the 10 min of a worker', () {
    expect(
      flush(
        TargetPlatform.android,
        deadline: const Duration(minutes: 9),
        elapsed: const Duration(minutes: 8, seconds: 59),
      ),
      const Duration(seconds: 5),
    );
  });

  // A one-off task in the app's isolate uses the app's reporter; without
  // the platform's plugins in a test, the run itself ends at once.
  group('a run', () {
    late _UnansweredSdk sdk;

    setUp(() async {
      sdk = _UnansweredSdk();
      final reporter = CrashReporter(
        dsn: testCrashReportsDsn,
        part: AppPart.app,
        sdk: sdk,
      );
      addTearDown(reporter.dispose);
      await reporter.follow(CrashReportConsent.allowed);
      Logger('Probe').severe('on its way');
    });

    test('waits for the crash reports on their way before it ends', () async {
      var ended = false;
      final run = runBackgroundTask('periodic')
          .whenComplete(() => ended = true);

      await sdk.runEnded.future;
      await pumpEventQueue();
      expect(ended, isFalse);

      sdk.answer.complete();
      expect(await run, BackgroundRunOutcome.nothing);
    });

    test('on iOS ends after 2 s although a report never answers', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final took = Stopwatch()..start();

      expect(await runBackgroundTask('periodic'), BackgroundRunOutcome.nothing);

      expect(took.elapsed, greaterThanOrEqualTo(const Duration(seconds: 2)));
      expect(sdk.answer.isCompleted, isFalse);
    });
  });
}

/// Answers no report until [answer] completes; [runEnded] completes when
/// the run reports that it could not start.
final class _UnansweredSdk extends FakeCrashReportSdk {
  final answer = Completer<void>();
  final runEnded = Completer<void>();

  @override
  Future<void> captureError(DiagnosticsEntry entry, StackTrace? stack) {
    if (entry.message.startsWith('Could not start a background run') &&
        !runEnded.isCompleted) {
      runEnded.complete();
    }
    return answer.future;
  }
}
