import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_consent.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_providers.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_reporter.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/crash_report_fakes.dart';
import '../../helpers/server_connections.dart';

void main() {
  late FakeCrashReportSdk sdk;
  late AuthFakes auth;
  late MemoryPreferencesStore preferences;

  setUp(() {
    sdk = FakeCrashReportSdk();
    auth = AuthFakes();
    preferences = auth.preferences;
  });

  Future<CrashReporter> start({
    String? dsn = testCrashReportsDsn,
    AppPart part = AppPart.backgroundRun,
  }) async {
    final reporter = await startHeadlessCrashReports(
      part,
      dsn: () => dsn,
      preferences: preferences,
      sdk: sdk,
    );
    addTearDown(reporter.dispose);
    return reporter;
  }

  test('a build without a DSN has none: the tests run without one', () {
    expect(buildCrashReportsDsn, isNull);
  });

  test('without a DSN the SDK never starts, even when crash reports are '
      'allowed', () async {
    preferences.values[CrashReportConsentStore.key] = 'allowed';

    final reporter = await start(dsn: null);

    expect(sdk.calls, isEmpty);
    expect(reporter.running, isFalse);
    expect(currentCrashReporter, isNull);
    // No preferences either: this test has no SharedPreferences platform.
    final bare = await startHeadlessCrashReports(
      AppPart.widgetAction,
      dsn: () => null,
    );
    expect(bare.dsn, isNull);
  });

  test('not asked or declined: the SDK never starts, and a background '
      'isolate deletes nothing', () async {
    await start(part: AppPart.notificationAction);
    preferences.values[CrashReportConsentStore.key] = 'declined';
    final reporter = currentCrashReporter!;
    await reporter.dispose();
    await start(part: AppPart.widgetAction);

    expect(sdk.calls, isEmpty);
  });

  test('allowed: the Dart SDK starts with the part, leaving out the '
      'servers of the registry', () async {
    preferences.values[CrashReportConsentStore.key] = 'allowed';
    await auth.seedAccount(
      fullServer270(root: 'https://tasks.example.org'),
      tokens: issueTokens(issuedAt: DateTime.utc(2026, 11), userId: 1),
    );

    final reporter = await start(part: AppPart.widgetAction);

    expect(sdk.calls, ['start']);
    expect(sdk.started!.part, AppPart.widgetAction);
    expect(reporter.hosts, contains('tasks.example.org'));
  });

  test(
    'a background engine used again follows the stored choice: allowed, '
    'running, then declined in the app, the next call stops the SDK',
    () async {
      preferences.values[CrashReportConsentStore.key] = 'allowed';
      final first = await start(part: AppPart.notificationAction);
      expect(first.running, isTrue);

      preferences.values[CrashReportConsentStore.key] = 'declined';
      final again = await start(part: AppPart.notificationAction);

      expect(again, same(first));
      expect(sdk.calls, ['start', 'stop']);
      expect(again.running, isFalse);

      preferences.values[CrashReportConsentStore.key] = 'allowed';
      await auth.seedAccount(
        fullServer270(root: 'https://tasks.example.org'),
        tokens: issueTokens(issuedAt: DateTime.utc(2026, 11), userId: 1),
      );
      await start(part: AppPart.notificationAction);
      expect(sdk.calls, ['start', 'stop', 'start']);
      expect(again.hosts, contains('tasks.example.org'), reason: 'read again');
    },
  );

  test('a report of a running background isolate is dropped once the '
      'stored choice is no longer allowed', () async {
    preferences.values[CrashReportConsentStore.key] = 'allowed';
    final reporter = await start();
    final log = Logger('Probe')..severe('sent');
    await reporter.flush();

    preferences.values[CrashReportConsentStore.key] = 'declined';
    log.severe('dropped');
    await reporter.flush();

    expect([for (final (entry, _) in sdk.errors) entry.message], ['sent']);
    expect(sdk.calls, ['start', 'stop']);
  });

  test('a report the stored choice dropped is no repeat: allowed again, the '
      'same record within 10 minutes is sent', () async {
    preferences.values[CrashReportConsentStore.key] = 'allowed';
    final reporter = await start(part: AppPart.notificationAction);
    final log = Logger('Probe');

    preferences.values[CrashReportConsentStore.key] = 'declined';
    log.severe('X');
    await reporter.flush();
    preferences.values[CrashReportConsentStore.key] = 'allowed';
    await start(part: AppPart.notificationAction);
    log.severe('X');
    await reporter.flush();

    expect([for (final (entry, _) in sdk.errors) entry.message], ['X']);
    expect(sdk.calls, ['start', 'stop', 'start']);
  });

  test("in the app's isolate the app's reporter is used, so no second SDK "
      'starts', () async {
    final app = CrashReporter(
      dsn: testCrashReportsDsn,
      part: AppPart.app,
      sdk: FakeCrashReportSdk(),
    );
    addTearDown(app.dispose);
    preferences.values[CrashReportConsentStore.key] = 'allowed';

    expect(await start(), same(app));
    expect(sdk.calls, isEmpty);
  });

  test('every headless entry point starts its crash reports through '
      'startHeadlessCrashReports, and only the reporter starts an SDK', () {
    String read(String path) => File(path).readAsStringSync();
    expect(
      read('lib/core/background/background_entry_point.dart'),
      contains('startHeadlessCrashReports(AppPart.backgroundRun)'),
    );
    expect(
      read('lib/core/notifications/notification_entry_points.dart'),
      contains('startHeadlessCrashReports(AppPart.notificationAction)'),
    );
    expect(
      read('lib/core/widgets/widget_entry_points.dart'),
      contains('startHeadlessCrashReports(AppPart.widgetAction)'),
    );
    expect(
      read('lib/core/crash_reports/crash_report_providers.dart'),
      contains('SentryCrashReportSdk(native: false)'),
    );
    final starts = RegExp(r'\b(?:SentryFlutter|Sentry)\.init\(');
    final starters = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            starts.hasMatch(file.readAsStringSync()))
          file.path.replaceAll(r'\', '/'),
    ];
    expect(starters, ['lib/core/crash_reports/sentry_crash_report_sdk.dart']);
  });
}
