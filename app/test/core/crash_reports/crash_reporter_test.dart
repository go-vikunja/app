import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_consent.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_reporter.dart';
import 'package:vikunja_mobile/core/logging/diagnostics_log.dart';
import 'package:vikunja_mobile/core/logging/logging_setup.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';

import '../../helpers/crash_report_fakes.dart';

const _token = 'tk_0123456789abcdef';

final _log = Logger('Probe');

// Plain tests: a widget test's binding swaps FlutterError.onError itself.
void main() {
  late FakeCrashReportSdk sdk;

  setUp(() {
    sdk = FakeCrashReportSdk();
    final flutterErrorBefore = FlutterError.onError;
    final uncaughtBefore = PlatformDispatcher.instance.onError;
    final levelBefore = Logger.root.level;
    configureLogging(
      part: AppPart.app,
      printToConsole: false,
      diagnosticsDirectory: () async => null,
    );
    addTearDown(() {
      resetLoggingForTest();
      FlutterError.onError = flutterErrorBefore;
      PlatformDispatcher.instance.onError = uncaughtBefore;
      Logger.root.level = levelBefore;
    });
  });

  CrashReporter reporter({String? dsn = testCrashReportsDsn, bool app = true}) {
    final made = CrashReporter(
      dsn: dsn,
      part: app ? AppPart.app : AppPart.backgroundRun,
      sdk: sdk,
      deletesUnsent: app,
    );
    addTearDown(made.dispose);
    return made;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('without a DSN nothing starts and nothing is handed on, whatever '
      'the choice', () async {
    final made = reporter(dsn: null);

    await made.follow(CrashReportConsent.allowed);
    _log.severe('broken');
    PlatformDispatcher.instance.onError!(StateError('x'), StackTrace.empty);
    await settle();

    expect(sdk.calls, isEmpty);
    expect(sdk.errors, isEmpty);
    expect(sdk.uncaught, isEmpty);
    expect(currentCrashReporter, isNull);
  });

  test('allowed: starts with the DSN and the part; SEVERE records become '
      'reports and WARNING records breadcrumbs, redacted like the '
      'diagnostics log keeps them; uncaught errors come with the error '
      'itself', () async {
    final made = reporter(app: false)..hosts = {'tasks.example.org'};
    await made.follow(CrashReportConsent.allowed);

    expect(sdk.calls, ['start']);
    expect(sdk.started!.dsn, testCrashReportsDsn);
    expect(sdk.started!.part, AppPart.backgroundRun);
    expect(sdk.started!.hosts(), {'tasks.example.org'});

    final stack = StackTrace.current;
    _log
      ..info('not kept')
      ..warning('Retrying with $_token')
      ..severe(
        'Gave up: ${StateError('x').runtimeType}',
        StateError(_token),
        stack,
      )
      ..shout('Very broken');
    final uncaught = ArgumentError(_token);
    final flutterError = StateError(_token);
    PlatformDispatcher.instance.onError!(uncaught, stack);
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: flutterError,
        stack: stack,
        library: 'lib',
      ),
    );
    await settle();

    expect(sdk.warnings.single.message, 'Retrying with [redacted]');
    expect(sdk.warnings.single.part, 'backgroundRun');
    expect(
      [for (final (entry, _) in sdk.errors) entry.message],
      ['Gave up: StateError', 'Very broken'],
    );
    expect(sdk.errors.first.$1.error, 'StateError');
    expect(sdk.errors.first.$2, same(stack));
    expect(sdk.uncaught, [
      (uncaught, stack, false, null),
      (flutterError, stack, true, 'lib'),
    ]);
  });

  test('what comes before the choice is read waits, and goes out only '
      'if the choice allows it', () async {
    final allowedLater = reporter(app: false);
    _log.severe('early');
    PlatformDispatcher.instance.onError!(StateError('early'), StackTrace.empty);
    await settle();
    expect(sdk.errors, isEmpty);

    await allowedLater.follow(CrashReportConsent.allowed);
    await settle();
    expect(sdk.errors.single.$1.message, 'early');
    expect(sdk.uncaught, hasLength(1));
    await allowedLater.dispose();

    final other = FakeCrashReportSdk();
    final declined = CrashReporter(
      dsn: testCrashReportsDsn,
      part: AppPart.app,
      sdk: other,
    );
    addTearDown(declined.dispose);
    _log.severe('early');
    await declined.follow(CrashReportConsent.notAsked);
    await declined.follow(CrashReportConsent.allowed);
    await settle();
    expect(other.calls, ['start']);
    expect(other.errors, isEmpty, reason: 'dropped when not asked yet');
  });

  test('turning it off closes the SDK and deletes the unsent reports at '
      'once; nothing logged while off is sent; on again starts without a '
      'restart', () async {
    final made = reporter();
    await made.follow(CrashReportConsent.allowed);

    await made.follow(CrashReportConsent.declined);
    expect(sdk.calls, ['start', 'stop', 'deleteUnsent']);
    expect(made.running, isFalse);
    _log.severe('while off');
    PlatformDispatcher.instance.onError!(StateError('off'), StackTrace.empty);
    await settle();
    expect(sdk.errors, isEmpty);
    expect(sdk.uncaught, isEmpty);

    await made.follow(CrashReportConsent.allowed);
    _log.severe('on again');
    await settle();
    expect(sdk.calls, ['start', 'stop', 'deleteUnsent', 'start']);
    expect(sdk.errors.single.$1.message, 'on again');
  });

  test('the calls apply in order, the last one winning', () async {
    final made = reporter();

    unawaited(made.follow(CrashReportConsent.allowed));
    unawaited(made.follow(CrashReportConsent.declined));
    await made.follow(CrashReportConsent.allowed);
    expect(sdk.calls, ['start']);

    unawaited(made.follow(CrashReportConsent.declined));
    await made.follow(CrashReportConsent.declined);
    expect(sdk.calls, ['start', 'stop', 'deleteUnsent', 'deleteUnsent']);
    expect(made.running, isFalse);
  });

  test('declined at the start deletes what an earlier run left in the '
      "app's isolate only; not asked deletes nothing", () async {
    await reporter().follow(CrashReportConsent.declined);
    expect(sdk.calls, ['deleteUnsent']);

    final background = FakeCrashReportSdk();
    final headless = CrashReporter(
      dsn: testCrashReportsDsn,
      part: AppPart.widgetAction,
      sdk: background,
    );
    addTearDown(headless.dispose);
    await headless.follow(CrashReportConsent.declined);
    final notAsked = CrashReporter(
      dsn: testCrashReportsDsn,
      part: AppPart.app,
      sdk: background,
      deletesUnsent: true,
    );
    addTearDown(notAsked.dispose);
    await notAsked.follow(CrashReportConsent.notAsked);
    expect(background.calls, isEmpty);
  });

  test('an SDK that does not start drops what waited; allowing again '
      'tries again', () async {
    final made = reporter();
    _log.severe('waiting');
    sdk.failStart = true;

    await made.follow(CrashReportConsent.allowed);
    _log.severe('after the failure');
    await settle();
    expect(sdk.calls, isEmpty);
    expect(sdk.errors, isEmpty);

    await made.follow(CrashReportConsent.allowed);
    expect(sdk.calls, ['start']);
  });

  test('a silent Flutter error stays in the log only', () async {
    final made = reporter();
    await made.follow(CrashReportConsent.allowed);

    FlutterError.reportError(
      FlutterErrorDetails(exception: StateError('image'), silent: true),
    );
    FlutterError.reportError(
      FlutterErrorDetails(exception: StateError('build')),
    );
    await settle();

    expect(
      [for (final (error, _, _, _) in sdk.uncaught) '$error'],
      ['Bad state: build'],
    );
  });

  test('a report that repeats one of the last 10 minutes is dropped: an '
      'error by its type and first frame, a record by its logger and '
      'message; breadcrumbs repeat', () async {
    var now = DateTime.utc(2026, 11, 21, 9);
    final made = CrashReporter(
      dsn: testCrashReportsDsn,
      part: AppPart.app,
      sdk: sdk,
      clock: () => now,
    );
    addTearDown(made.dispose);
    await made.follow(CrashReportConsent.allowed);
    final here = StackTrace.current;
    final elsewhere = StackTrace.fromString('#0      other (file.dart:1:1)');

    for (var frame = 0; frame < 3; frame++) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: StateError('a $frame'), stack: here),
      );
      _log
        ..severe('Sync failed')
        ..warning('Retrying');
    }
    FlutterError.reportError(
      FlutterErrorDetails(exception: StateError('b'), stack: elsewhere),
    );
    FlutterError.reportError(
      FlutterErrorDetails(exception: ArgumentError('c'), stack: here),
    );
    Logger('Other').severe('Sync failed');
    await settle();
    expect(sdk.uncaught, hasLength(3));
    expect(sdk.errors, hasLength(2));
    expect(sdk.warnings, hasLength(3));

    now = now.add(const Duration(minutes: 9, seconds: 59));
    _log.severe('Sync failed');
    now = now.add(const Duration(seconds: 1));
    _log.severe('Sync failed');
    await settle();
    expect(sdk.errors, hasLength(3), reason: 'again after 10 minutes');
  });

  group('a report counts toward the limit and the repeats only once it '
      'reaches the SDK', () {
    var now = DateTime.utc(2026, 11, 21, 9);
    final stack = StackTrace.current;
    void fail() =>
        PlatformDispatcher.instance.onError!(StateError('early'), stack);

    CrashReporter counting({
      int bufferLimit = 20,
      int reportLimit = 20,
      Future<CrashReportConsent> Function()? storedConsent,
    }) {
      final made = CrashReporter(
        dsn: testCrashReportsDsn,
        part: storedConsent == null ? AppPart.app : AppPart.widgetAction,
        sdk: sdk,
        storedConsent: storedConsent,
        bufferLimit: bufferLimit,
        reportLimit: reportLimit,
        clock: () => now,
      );
      addTearDown(made.dispose);
      return made;
    }

    test('one from before the choice is read, cleared since the choice '
        'was not asked yet, is no repeat of the same error once the user '
        'allows reports in that run', () async {
      final made = counting();

      fail();
      await made.follow(CrashReportConsent.notAsked);
      await made.follow(CrashReportConsent.allowed);
      now = now.add(const Duration(minutes: 1));
      fail();
      await settle();

      expect(sdk.uncaught, hasLength(1));
    });

    test('one from before the choice is read counts when it is sent, and '
        'the same error within 10 minutes is a repeat', () async {
      final made = counting();

      fail();
      await made.follow(CrashReportConsent.allowed);
      now = now.add(const Duration(minutes: 1));
      fail();
      await settle();

      expect(sdk.uncaught, hasLength(1));
    });

    test('one cleared by a decline counts for nothing: a later allow in '
        'the same run sends the error again', () async {
      final made = counting(reportLimit: 1);

      fail();
      _log.severe('early record');
      await made.follow(CrashReportConsent.declined);
      await made.follow(CrashReportConsent.allowed);
      fail();
      await settle();

      expect(sdk.uncaught, hasLength(1));
      expect(sdk.errors, isEmpty, reason: 'the one report of the limit');
    });

    test('one dropped from the full buffer counts for nothing', () async {
      final made = counting(bufferLimit: 1, reportLimit: 1);

      _log.warning('fills the buffer');
      fail();
      await made.follow(CrashReportConsent.allowed);
      fail();
      await settle();

      expect(sdk.warnings, hasLength(1));
      expect(sdk.uncaught, hasLength(1));
    });

    test('a repeat of one waiting for the choice takes no place in the '
        'buffer, so a different error after it is still sent', () async {
      final made = counting(bufferLimit: 2);

      fail();
      fail();
      fail();
      PlatformDispatcher.instance.onError!(ArgumentError('other'), stack);
      await made.follow(CrashReportConsent.allowed);
      await settle();

      expect(
        [for (final (error, _, _, _) in sdk.uncaught) error.runtimeType],
        [StateError, ArgumentError],
      );
    });

    test("one a background isolate's second read of the stored choice "
        'drops counts for nothing: allowed again, the same error is '
        'sent', () async {
      var stored = CrashReportConsent.allowed;
      final made = counting(reportLimit: 1, storedConsent: () async => stored);
      await made.follow(CrashReportConsent.allowed);

      stored = CrashReportConsent.declined;
      fail();
      await made.flush();
      expect(sdk.uncaught, isEmpty);

      stored = CrashReportConsent.allowed;
      await made.follow(CrashReportConsent.allowed);
      fail();
      await made.flush();

      expect(sdk.uncaught, hasLength(1));
      expect(sdk.calls, ['start', 'stop', 'start']);
    });

    test('a background isolate reads the stored choice only for the reports '
        'the repeats and the limit may let out', () async {
      var reads = 0;
      final made = counting(
        reportLimit: 1,
        storedConsent: () async {
          reads++;
          return CrashReportConsent.allowed;
        },
      );
      await made.follow(CrashReportConsent.allowed);

      for (var i = 0; i < 50; i++) {
        _log.severe('Sync failed');
      }
      for (var i = 0; i < 5; i++) {
        _log.severe('Other failure $i');
      }
      await made.flush();
      _log
        ..severe('Sync failed')
        ..severe('Other failure 0');
      await made.flush();

      expect(reads, 1);
      expect(
        [for (final (entry, _) in sdk.errors) entry.message],
        ['Sync failed'],
      );
    });

    test('a background report on its way holds one place in the limit, not '
        'two', () async {
      var reads = 0;
      final made = CrashReporter(
        dsn: testCrashReportsDsn,
        part: AppPart.widgetAction,
        sdk: _SlowSdk(Completer<void>().future),
        storedConsent: () async {
          reads++;
          return CrashReportConsent.allowed;
        },
        reportLimit: 2,
      );
      addTearDown(made.dispose);
      await made.follow(CrashReportConsent.allowed);

      _log.severe('never answered');
      await made.flush(timeout: const Duration(milliseconds: 10));
      _log.severe('another');
      await made.flush(timeout: const Duration(milliseconds: 10));

      expect(reads, 2);
    });
  });

  test('a choice made while the SDK starts wins over what waited for the '
      'first one: none of it reaches the SDK', () async {
    final starting = Completer<void>();
    final slow = _SlowStartSdk(starting.future);
    final made = CrashReporter(
      dsn: testCrashReportsDsn,
      part: AppPart.app,
      sdk: slow,
      deletesUnsent: true,
    );
    addTearDown(made.dispose);
    _log
      ..warning('early warning')
      ..severe('early');
    PlatformDispatcher.instance.onError!(StateError('early'), StackTrace.empty);

    final allowing = made.follow(CrashReportConsent.allowed);
    await settle();
    final declining = made.follow(CrashReportConsent.declined);
    starting.complete();
    await allowing;
    await declining;
    await settle();

    expect(slow.calls, ['start', 'stop', 'deleteUnsent']);
    expect(slow.warnings, isEmpty);
    expect(slow.errors, isEmpty);
    expect(slow.uncaught, isEmpty);
  });

  test('at most 20 reports go out per isolate run; breadcrumbs have no '
      'limit', () async {
    final made = reporter();
    await made.follow(CrashReportConsent.allowed);

    for (var i = 0; i < 25; i++) {
      _log
        ..severe('Failure $i')
        ..warning('Warning $i');
    }
    await settle();

    expect(sdk.errors, hasLength(20));
    expect(sdk.warnings, hasLength(25));
  });

  test("a background isolate's report reads the stored choice again and "
      'goes only while it allows reports; then the SDK stops', () async {
    var stored = CrashReportConsent.allowed;
    final made = CrashReporter(
      dsn: testCrashReportsDsn,
      part: AppPart.notificationAction,
      sdk: sdk,
      storedConsent: () async => stored,
    );
    addTearDown(made.dispose);
    await made.follow(CrashReportConsent.allowed);
    _log.severe('sent');
    await settle();
    expect([for (final (entry, _) in sdk.errors) entry.message], ['sent']);

    stored = CrashReportConsent.declined;
    _log
      ..warning('kept in memory only')
      ..severe('dropped');
    await made.flush();

    expect([for (final (entry, _) in sdk.errors) entry.message], ['sent']);
    expect(sdk.calls, ['start', 'stop']);
    expect(made.running, isFalse);
    expect(sdk.calls, isNot(contains('deleteUnsent')));
  });

  test(
    'flush waits for the reports on their way, within its timeout',
    () async {
      final slow = Completer<void>();
      final made = CrashReporter(
        dsn: testCrashReportsDsn,
        part: AppPart.notificationAction,
        sdk: _SlowSdk(slow.future),
      );
      addTearDown(made.dispose);
      await made.follow(CrashReportConsent.allowed);
      _log.severe('slow');

      var flushed = false;
      unawaited(made.flush().then((_) => flushed = true));
      await settle();
      expect(flushed, isFalse);
      slow.complete();
      await settle();
      await settle();
      expect(flushed, isTrue);

      _log.severe('never answered');
      await made.flush(timeout: const Duration(milliseconds: 10));
    },
  );
}

final class _SlowStartSdk extends FakeCrashReportSdk {
  new(this._started);

  final Future<void> _started;

  @override
  Future<void> start(CrashReportStart start) async {
    await _started;
    await super.start(start);
  }
}

final class _SlowSdk extends FakeCrashReportSdk {
  new(this._answer);

  Future<void> _answer;

  @override
  Future<void> captureError(DiagnosticsEntry entry, StackTrace? stack) {
    final answer = _answer;
    _answer = Completer<void>().future;
    return answer;
  }
}
