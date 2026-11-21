import 'dart:async';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_consent.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_reporter.dart';
import 'package:vikunja_mobile/core/crash_reports/sentry_crash_report_sdk.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

part 'crash_report_providers.g.dart';

final _log = Logger('CrashReports');

/// [buildCrashReportsDsn]; tests override it.
@Riverpod(keepAlive: true)
String? crashReportsDsn(Ref ref) => buildCrashReportsDsn;

@Riverpod(keepAlive: true)
CrashReportSdk crashReportSdk(Ref ref) => SentryCrashReportSdk(native: true);

/// The app's reporter: it follows the device's choice at once and leaves
/// the registered servers' hosts out of every report. Bootstrap listens
/// to it for the app's lifetime.
@Riverpod(keepAlive: true)
CrashReporter crashReporter(Ref ref) {
  final reporter = CrashReporter(
    dsn: ref.watch(crashReportsDsnProvider),
    part: AppPart.app,
    sdk: ref.watch(crashReportSdkProvider),
    deletesUnsent: true,
  );
  ref
    ..onDispose(() => unawaited(reporter.dispose()))
    ..listen(accountsProvider, (_, next) {
      if (next.value case final state?) reporter.hosts = serverHostsOf(state);
    }, fireImmediately: true)
    ..listen(crashReportConsentControllerProvider, (_, next) {
      if (next.value case final consent?) unawaited(reporter.follow(consent));
    }, fireImmediately: true);
  return reporter;
}

String? _buildDsn() => buildCrashReportsDsn;

Set<String> serverHostsOf(AccountRegistryState state) => {
  for (final entry in state.accounts) ...[
    entry.connection.rootUri.host,
    ?entry.connection.info.frontendUrl?.host,
  ],
}..removeWhere((host) => host.isEmpty);

/// For a background run, a notification action or a widget action: the
/// isolate's reporter, made on the first call, set to the stored choice and
/// to the registered servers on every call, as a background engine may be
/// used again after the user turned crash reports off; each of its reports
/// reads the choice again before it goes. In the app's own isolate the
/// app's, which follows the choice itself; without a DSN, one that never
/// starts the SDK. Never throws.
Future<CrashReporter> startHeadlessCrashReports(
  AppPart part, {
  String? Function() dsn = _buildDsn,
  PreferencesStore? preferences,
  CrashReportSdk? sdk,
}) async {
  final current = currentCrashReporter;
  if (current != null && current.part == AppPart.app) return current;
  // Only with a DSN: a build or test without one has no preferences to read.
  PreferencesStore store() => preferences ?? SharedPreferencesStore();
  final reporter =
      current ??
      CrashReporter(
        dsn: dsn(),
        part: part,
        sdk: sdk ?? SentryCrashReportSdk(native: false),
        storedConsent: () => readStoredCrashReportConsent(store),
      );
  if (reporter.dsn == null) return reporter;
  final consent = await readStoredCrashReportConsent(store);
  if (consent == CrashReportConsent.allowed) {
    try {
      reporter.hosts = serverHostsOf(await AccountRegistry(store()).load());
    } on Object catch (error) {
      _log.warning(
        'Could not read the servers to leave out: ${error.runtimeType}',
      );
    }
  }
  await reporter.follow(consent);
  return reporter;
}

/// The stored choice as another isolate wrote it: [SharedPreferencesStore]
/// has no cache. One that cannot be read counts as declined. Never throws.
Future<CrashReportConsent> readStoredCrashReportConsent(
  PreferencesStore Function() store,
) async {
  try {
    return await CrashReportConsentStore(store()).read();
  } on Object catch (error) {
    _log.warning(
      'Could not read the crash report choice: ${error.runtimeType}',
    );
    return CrashReportConsent.declined;
  }
}
