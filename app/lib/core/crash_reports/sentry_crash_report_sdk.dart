import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_scrubber.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_reporter.dart';
import 'package:vikunja_mobile/core/logging/diagnostics_log.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';

/// The integrations Sentry's own setup adds that stay; every other one is
/// removed, so that a new version's addition stays off until it is looked
/// at: no error hooks of its own, its isolate listener included (the app's
/// in `configureLogging` see every uncaught error, which then reaches Sentry
/// only through the reporter, with its repeat rule, limit and stored
/// choice), no automatic breadcrumbs, screenshots, view hierarchy, replay,
/// frames, app start or sessions.
const keptSentryIntegrations = {
  'EnricherIntegration',
  'InMemoryTelemetryProcessorIntegration',
  'InstrumentationSpanFactorySetupIntegration',
  'TrackBeforeSendUsageIntegration',
  // sentry_flutter's, only in the app's isolate:
  'WidgetsFlutterBindingIntegration',
  'LoadReleaseIntegration',
  // Its close closes what sentry_flutter started for the native SDK, also
  // on Android, where it does not start that SDK.
  'NativeSdkIntegration',
  'LoadContextsIntegration',
};

const _inAppPackages = [
  'vikunja_mobile',
  'vikunja_api',
  'vikunja_domain',
  'vikunja_logic',
  'vikunja_storage_flush',
  'vikunja_widgets',
];

/// Sentry for the crash reports (decision log: Diagnostics). [native] in the
/// app's isolate: `SentryFlutter` with the native SDKs, which keep unsent
/// reports on the device. On Android the app starts the native SDK itself, with
/// its own scrubber, which then also reports Java and NDK crashes and ANRs; on
/// iOS, which has no scrubber of the app's, the native SDK captures nothing on
/// its own. Elsewhere the Dart SDK alone, which keeps nothing on the device:
/// the native SDKs are one per process, and a background engine may share the
/// app's.
final class SentryCrashReportSdk implements CrashReportSdk {
  new({required this.native, this._initFlutter = SentryFlutter.init});

  final bool native;
  final Future<void> Function(FlutterOptionsConfiguration) _initFlutter;
  Iterable<String> Function() _hosts = () => const [];

  bool get _nativeOnAndroid =>
      native && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> start(CrashReportStart start) async {
    _hosts = start.hosts;
    final info = await PackageInfo.fromPlatform();
    final release = '${info.packageName}@${info.version}+${info.buildNumber}';
    void configure(SentryOptions options) => configureCrashReportOptions(
      options,
      start: start,
      release: release,
      dist: info.buildNumber,
    );
    if (!native) {
      await Sentry.init(configure);
      return;
    }
    // Before Dart's SDK, so that nothing starts when the scrubber is not in
    // place.
    if (_nativeOnAndroid) {
      await deviceChannel.invokeMethod<void>('startNativeCrashReports', {
        'dsn': start.dsn,
        'release': release,
        'dist': info.buildNumber,
      });
    }
    try {
      await _initFlutter((options) {
        configureNativeCrashReportOptions(
          options,
          platform: defaultTargetPlatform,
        );
        configure(options);
      });
    } on Object {
      // Sentry may already run when a step after its start throws.
      try {
        await stop();
      } on Object {
        // The failed start is what the caller learns of.
      }
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await Sentry.close();
    } finally {
      if (_nativeOnAndroid) await _stopNative();
    }
  }

  // Sentry.close() closes only what SentryFlutter started itself.
  Future<void> _stopNative() =>
      deviceChannel.invokeMethod<void>('stopNativeCrashReports');

  @override
  Future<void> deleteUnsent() => deleteUnsentCrashReports();

  @override
  Future<void> captureUncaught(
    Object error,
    StackTrace? stack, {
    required bool flutter,
    String? library,
  }) => Sentry.captureException(
    ThrowableMechanism(
      Mechanism(
        type: flutter ? 'FlutterError' : 'PlatformDispatcher.onError',
        handled: false,
        data: {'library': ?library},
      ),
      error,
    ),
    stackTrace: stack,
  );

  @override
  Future<void> captureError(DiagnosticsEntry entry, StackTrace? stack) =>
      Sentry.captureEvent(
        SentryEvent(
          level: SentryLevel.error,
          logger: entry.logger,
          message: SentryMessage(entry.message),
          tags: {'error.type': ?entry.error},
        ),
        stackTrace: stack,
      );

  @override
  Future<void> addWarning(DiagnosticsEntry entry) =>
      Sentry.addBreadcrumb(crashReportBreadcrumb(entry, hosts: _hosts()));
}

/// A WARNING record as a breadcrumb, redacted when it is made, since the
/// native SDKs keep the breadcrumbs for their own reports, which the
/// app's scrubber never sees.
Breadcrumb crashReportBreadcrumb(
  DiagnosticsEntry entry, {
  Iterable<String> hosts = const [],
}) => Breadcrumb(
  message: scrubCrashReportText(entry.message, hosts: hosts),
  category: crashReportLogCategory,
  level: SentryLevel.warning,
  timestamp: entry.at,
  data: {'logger': entry.logger, 'error': ?entry.error},
);

/// What both isolates' SDKs share: no personal data, tracing, logs or
/// client reports; the app's breadcrumbs only; every report scrubbed.
@visibleForTesting
void configureCrashReportOptions(
  SentryOptions options, {
  required CrashReportStart start,
  required String release,
  required String dist,
}) {
  options
    ..release = release
    ..dist = dist
    ..sendDefaultPii = false
    ..attachStacktrace = false
    ..attachThreads = false
    ..enablePrintBreadcrumbs = false
    ..recordHttpBreadcrumbs = false
    ..captureFailedRequests = false
    ..sendClientReports = false
    ..tracesSampleRate = null
    ..tracesSampler = null
    ..maxBreadcrumbs = 50
    ..considerInAppFramesByDefault = false
    ..beforeBreadcrumb = _onlyTheAppsBreadcrumbs
    ..beforeSendTransaction = _noTransactions
    ..beforeSend = (event, _) =>
        scrubCrashReport(event, part: start.part.name, hosts: start.hosts());
  _inAppPackages.forEach(options.addInAppInclude);
  for (final integration in List.of(options.integrations)) {
    if (!keptSentryIntegrations.contains('${integration.runtimeType}')) {
      options.removeIntegration(integration);
    }
  }
  // The last assignment of either callback, after the native options too:
  // Sentry starts with what was set when a step before throws, and without
  // a DSN it does not start.
  options.dsn = start.dsn;
}

Breadcrumb? _onlyTheAppsBreadcrumbs(Breadcrumb? breadcrumb, Hint _) =>
    breadcrumb?.category == crashReportLogCategory ? breadcrumb : null;

SentryTransaction? _noTransactions(SentryTransaction _, Hint _) => null;

/// The native SDKs collect nothing on their own: no sessions, breadcrumbs,
/// tracing, screenshots or replay. On Android the app starts the native SDK
/// itself (`NativeCrashReports.kt`), with its crash and ANR reports; on iOS
/// it captures no crash, app hang or watchdog termination, which would
/// leave without the app's scrubber.
@visibleForTesting
void configureNativeCrashReportOptions(
  SentryFlutterOptions options, {
  required TargetPlatform platform,
}) {
  options
    ..enableAutoSessionTracking = false
    ..enableAutoNativeBreadcrumbs = false
    ..enableAutoPerformanceTracing = false
    ..enableFramesTracking = false
    ..enableNativeTraceSync = false
    ..enableUserInteractionBreadcrumbs = false
    ..enableUserInteractionTracing = false
    ..enableTimeToFullDisplayTracing = false
    ..captureNativeFailedRequests = false
    ..attachScreenshot = false
    ..attachViewHierarchy = false
    ..reportPackages = false;
  options.replay
    ..sessionSampleRate = 0
    ..onErrorSampleRate = 0;
  switch (platform) {
    case TargetPlatform.android:
      options.autoInitializeNativeSdk = false;
    case TargetPlatform.iOS:
      options
        ..enableNativeCrashHandling = false
        ..enableAppHangTracking = false
        ..enableWatchdogTerminationTracking = false;
    case _:
      break;
  }
}

/// The folders the native SDKs keep unsent reports, their scope and
/// their install id in: Android's `<cache>/sentry` and `files/INSTALLATION`;
/// iOS's `<Caches>/io.sentry`, `<Caches>/INSTALLATION` and the crash
/// handler's `<Caches>/SentryCrash`.
Future<List<FileSystemEntity>> crashReportCaches({
  TargetPlatform? platform,
  Future<Directory> Function() cache = getApplicationCacheDirectory,
  Future<Directory> Function() support = getApplicationSupportDirectory,
}) async => switch (platform ?? defaultTargetPlatform) {
  TargetPlatform.android => [
    Directory(p.join((await cache()).path, 'sentry')),
    File(p.join((await support()).path, 'INSTALLATION')),
  ],
  TargetPlatform.iOS => [
    for (final name in ['io.sentry', 'SentryCrash'])
      Directory(p.join((await cache()).path, name)),
    File(p.join((await cache()).path, 'INSTALLATION')),
  ],
  _ => const [],
};

/// Never throws: what cannot be deleted now is tried again at the next
/// start while crash reports are off.
Future<void> deleteUnsentCrashReports({
  Future<List<FileSystemEntity>> Function() caches = crashReportCaches,
}) async {
  try {
    for (final entity in await caches()) {
      try {
        if (entity.existsSync()) await entity.delete(recursive: true);
      } on FileSystemException {
        // Tried again next time.
      }
    }
  } on Object {
    // No folder to look in.
  }
}
