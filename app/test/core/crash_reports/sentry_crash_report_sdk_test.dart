import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_scrubber.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_reporter.dart';
import 'package:vikunja_mobile/core/crash_reports/sentry_crash_report_sdk.dart';
import 'package:vikunja_mobile/core/logging/diagnostics_log.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';

import '../../helpers/crash_report_fakes.dart';

const _host = 'tasks.example.org';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SentryFlutterOptions configured({
    TargetPlatform platform = TargetPlatform.android,
  }) {
    final options = SentryFlutterOptions()
      ..addIntegration(IsolateErrorIntegration())
      ..addIntegration(OnErrorIntegration())
      ..addIntegration(LoadReleaseIntegration())
      ..addIntegration(RunZonedGuardedIntegration(() async {}, (_, _) async {}))
      ..addIntegration(_ScreenshotIntegration());
    configureNativeCrashReportOptions(options, platform: platform);
    configureCrashReportOptions(
      options,
      start: (
        dsn: testCrashReportsDsn,
        part: AppPart.backgroundRun,
        hosts: () => {_host},
      ),
      release: 'io.vikunja.app@1.0.0+7',
      dist: '7',
    );
    return options;
  }

  test('no personal data, tracing, print breadcrumbs or client reports; the '
      "app's own frames in-app", () {
    final options = configured();

    expect(options.dsn, testCrashReportsDsn);
    expect(options.release, 'io.vikunja.app@1.0.0+7');
    expect(options.dist, '7');
    expect(options.sendDefaultPii, isFalse);
    expect(options.attachStacktrace, isFalse);
    expect(options.attachThreads, isFalse);
    expect(options.enablePrintBreadcrumbs, isFalse);
    expect(options.recordHttpBreadcrumbs, isFalse);
    expect(options.captureFailedRequests, isFalse);
    expect(options.sendClientReports, isFalse);
    expect(options.tracesSampleRate, isNull);
    expect(options.tracesSampler, isNull);
    expect(options.isTracingEnabled(), isFalse);
    expect(options.considerInAppFramesByDefault, isFalse);
    expect(options.inAppIncludes, contains('vikunja_mobile'));
  });

  test('only the listed integrations stay: no error hooks of its own, its '
      'isolate listener included, no automatic breadcrumbs', () {
    expect(
      {
        for (final integration in configured().integrations)
          '${integration.runtimeType}',
      },
      {'LoadReleaseIntegration'},
    );
  });

  test("a background isolate's Dart SDK keeps no isolate listener either: "
      "Sentry.init adds it before the app's configuration, which removes "
      'it', () async {
    late List<String> added;
    late List<String> kept;
    await Sentry.init((options) {
      added = [
        for (final integration in options.integrations)
          '${integration.runtimeType}',
      ];
      configureCrashReportOptions(
        options,
        start: (
          dsn: testCrashReportsDsn,
          part: AppPart.backgroundRun,
          hosts: () => const [],
        ),
        release: 'io.vikunja.app@1.0.0+7',
        dist: '7',
      );
      kept = [
        for (final integration in options.integrations)
          '${integration.runtimeType}',
      ];
    });
    addTearDown(Sentry.close);

    expect(added, contains('IsolateErrorIntegration'));
    expect(kept, isNot(contains('IsolateErrorIntegration')));
    expect(kept.toSet().difference(keptSentryIntegrations), isEmpty);
  });

  test('the native SDKs collect nothing on their own: no sessions, '
      'breadcrumbs, tracing, failed requests, screenshots, view hierarchy or '
      'replay', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      final options = configured(platform: platform);

      expect(options.enableAutoSessionTracking, isFalse);
      expect(options.enableAutoNativeBreadcrumbs, isFalse);
      expect(options.enableAutoPerformanceTracing, isFalse);
      expect(options.enableFramesTracking, isFalse);
      expect(options.enableNativeTraceSync, isFalse);
      expect(options.enableUserInteractionBreadcrumbs, isFalse);
      expect(options.enableUserInteractionTracing, isFalse);
      expect(options.captureNativeFailedRequests, isFalse);
      expect(options.recordHttpBreadcrumbs, isFalse);
      expect(options.attachScreenshot, isFalse);
      expect(options.attachViewHierarchy, isFalse);
      expect(options.reportPackages, isFalse);
      expect(options.replay.sessionSampleRate, 0);
      expect(options.replay.onErrorSampleRate, 0);
    }
  });

  test('Android: sentry_flutter does not start the native SDK, which the '
      'app starts itself with its scrubber', () {
    final options = configured();

    expect(options.autoInitializeNativeSdk, isFalse);
    expect(
      keptSentryIntegrations,
      contains('NativeSdkIntegration'),
      reason: "its close closes sentry_flutter's side of the native SDK",
    );
  });

  test('iOS, without a scrubber of the native reports: the native SDK '
      'captures no crash, app hang or watchdog termination', () {
    final options = configured(platform: TargetPlatform.iOS);

    expect(options.autoInitializeNativeSdk, isTrue);
    expect(options.enableNativeCrashHandling, isFalse);
    expect(options.enableAppHangTracking, isFalse);
    expect(options.enableWatchdogTerminationTracking, isFalse);
  });

  group("the app's isolate on Android", () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> calls;
    late bool nativeStarts;
    late bool nativeStopFails;

    setUp(() {
      calls = [];
      nativeStarts = false;
      nativeStopFails = false;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      PackageInfo.setMockInitialValues(
        appName: 'Vikunja',
        packageName: 'io.vikunja.app',
        version: '1.0.0',
        buildNumber: '7',
        buildSignature: '',
      );
      messenger.setMockMethodCallHandler(deviceChannel, (call) async {
        calls.add(call);
        if ((call.method == 'startNativeCrashReports' && !nativeStarts) ||
            (call.method == 'stopNativeCrashReports' && nativeStopFails)) {
          throw PlatformException(code: 'unavailable');
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(deviceChannel, null);
        debugDefaultTargetPlatformOverride = null;
      });
    });

    test('starts the native SDK with the DSN, release and dist first; when '
        'it does not start, nothing starts', () async {
      final sdk = SentryCrashReportSdk(native: true);

      await expectLater(
        sdk.start((
          dsn: testCrashReportsDsn,
          part: AppPart.app,
          hosts: () => const [],
        )),
        throwsA(isA<PlatformException>()),
      );

      expect(calls.single.method, 'startNativeCrashReports');
      expect(calls.single.arguments, {
        'dsn': testCrashReportsDsn,
        'release': 'io.vikunja.app@1.0.0+7',
        'dist': '7',
      });
      expect(Sentry.isEnabled, isFalse);
    });

    CrashReportStart appStart() => (
      dsn: testCrashReportsDsn,
      part: AppPart.app,
      hosts: () => const <String>[],
    );

    test('once the native SDK started, SentryFlutter starts, with the DSN '
        'set last, after the native options', () async {
      nativeStarts = true;
      final order = <String>[];
      final options = _RecordingOptions();
      final sdk = SentryCrashReportSdk(
        native: true,
        initFlutter: (configure) async {
          order
            ..addAll([for (final call in calls) call.method])
            ..add('SentryFlutter.init');
          await configure(options);
        },
      );

      await sdk.start(appStart());

      expect(order, ['startNativeCrashReports', 'SentryFlutter.init']);
      expect(calls, hasLength(1), reason: 'no stop');
      expect(options.dsn, testCrashReportsDsn);
      expect(options.autoInitializeNativeSdkWhenDsnSet, isFalse);
      expect(options.integrationsWhenDsnSet, isEmpty);
    });

    test("when SentryFlutter fails after Dart's SDK started, both SDKs stop "
        'again', () async {
      nativeStarts = true;
      addTearDown(Sentry.close);
      final sdk = SentryCrashReportSdk(
        native: true,
        initFlutter: (_) async {
          await Sentry.init((options) {
            options.dsn = testCrashReportsDsn;
          });
          throw StateError('an integration that throws');
        },
      );

      await expectLater(sdk.start(appStart()), throwsStateError);

      expect(Sentry.isEnabled, isFalse);
      expect(
        [for (final call in calls) call.method],
        ['startNativeCrashReports', 'stopNativeCrashReports'],
      );
    });

    test('the failed start is what the caller sees, also when the stop after '
        'it fails too', () async {
      nativeStarts = true;
      nativeStopFails = true;
      final sdk = SentryCrashReportSdk(
        native: true,
        initFlutter: (_) async => throw StateError('no SentryFlutter'),
      );

      await expectLater(sdk.start(appStart()), throwsStateError);

      expect(
        [for (final call in calls) call.method],
        ['startNativeCrashReports', 'stopNativeCrashReports'],
      );
    });

    test('iOS: the native switches come before the DSN, so a failing one '
        'leaves Sentry without it', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      late _RecordingOptions options;
      Future<void> start(_RecordingOptions given) => SentryCrashReportSdk(
        native: true,
        initFlutter: (configure) async {
          await configure(options = given);
        },
      ).start(appStart());

      await start(_RecordingOptions());
      expect(options.dsn, testCrashReportsDsn);
      expect(options.nativeCrashHandlingWhenDsnSet, isFalse);

      await expectLater(
        start(_RecordingOptions(failingNativeSwitch: true)),
        throwsStateError,
      );
      expect(options.dsn, isNull);
      expect(calls, isEmpty, reason: 'no channel on iOS');
    });

    test('stopping closes the native SDK the app started, also when '
        "Dart's SDK is not running", () async {
      await SentryCrashReportSdk(native: true).stop();
      expect(
        [for (final call in calls) call.method],
        ['stopNativeCrashReports'],
      );

      calls.clear();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await SentryCrashReportSdk(native: true).stop();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await SentryCrashReportSdk(native: false).stop();
      expect(calls, isEmpty, reason: "iOS's and a background isolate's");
    });
  });

  test('every report goes through the scrubber, tagged with the part; only '
      "the app's breadcrumbs and no transactions", () async {
    final options = configured();

    final event = await options.beforeSend!(
      SentryEvent(
        message: SentryMessage('failed at https://$_host/api'),
        user: SentryUser(id: 'someone'),
      ),
      Hint(),
    );
    expect(event!.message!.formatted, 'failed at https://<server>/api');
    expect(event.user, isNull);
    expect(event.tags, {'app.part': 'backgroundRun'});

    final hint = Hint();
    expect(
      options.beforeBreadcrumb!(Breadcrumb(category: 'navigation'), hint),
      isNull,
    );
    final ours = Breadcrumb(category: crashReportLogCategory);
    expect(options.beforeBreadcrumb!(ours, hint), same(ours));
    expect(options.beforeSendTransaction, isNotNull);
  });

  test('a report whose scrubbing throws partway is dropped by the app '
      'itself, whatever the Sentry SDK does with a failing callback, and '
      'through a real Sentry start nothing is sent, while a report scrubbed '
      'whole is', () async {
    SentryEvent failPartway(
      SentryEvent event, {
      required String part,
      Iterable<String> hosts = const [],
    }) {
      event.message = SentryMessage('scrubbed');
      throw StateError('a scrubber that fails partway');
    }

    var failing = true;
    void configure(SentryOptions options) => configureCrashReportOptions(
      options,
      start: (
        dsn: testCrashReportsDsn,
        part: AppPart.app,
        hosts: () => const {_host},
      ),
      release: 'io.vikunja.app@1.0.0+7',
      dist: '7',
      scrub: (event, {required part, hosts = const []}) => failing
          ? failPartway(event, part: part, hosts: hosts)
          : scrubCrashReport(event, part: part, hosts: hosts),
    );

    final options = SentryFlutterOptions();
    configure(options);
    expect(
      await options.beforeSend!(
        SentryEvent(message: SentryMessage('failed'), tags: {'server': _host}),
        Hint(),
      ),
      isNull,
    );

    late _KeptEnvelopes transport;
    await Sentry.init((options) {
      configure(options);
      transport = _KeptEnvelopes(options);
      options.transport = transport;
    });
    addTearDown(Sentry.close);
    await Sentry.captureEvent(
      SentryEvent(message: SentryMessage('failed'), tags: {'server': _host}),
    );
    await Sentry.captureException(StateError('at https://$_host/api'));
    expect(transport.sent, isEmpty);

    failing = false;
    await Sentry.captureEvent(SentryEvent(message: SentryMessage('control')));
    expect(transport.sent, hasLength(1), reason: 'the transport is reached');
  });

  test('a warning becomes a breadcrumb redacted when it is made', () {
    final breadcrumb = crashReportBreadcrumb(
      DiagnosticsEntry(
        at: DateTime.utc(2026, 11, 21, 9),
        part: 'app',
        level: 'WARNING',
        logger: 'Sync',
        message: 'Retrying https://$_host/api',
        error: 'SocketException',
      ),
      hosts: const [_host],
    );

    expect(breadcrumb.category, crashReportLogCategory);
    expect(breadcrumb.level, SentryLevel.warning);
    expect(breadcrumb.message, 'Retrying https://<server>/api');
    expect(breadcrumb.data, {'logger': 'Sync', 'error': 'SocketException'});
    expect(breadcrumb.timestamp, DateTime.utc(2026, 11, 21, 9));
  });

  test('deleting the unsent reports removes the folders and the install '
      'id, and minds neither a missing one nor a failure', () async {
    final root = await Directory.systemTemp.createTemp('crash_reports');
    addTearDown(() => root.delete(recursive: true));
    final cache = Directory('${root.path}/cache/sentry')
      ..createSync(recursive: true);
    File('${cache.path}/outbox.envelope').writeAsStringSync('report');
    final installation = File('${root.path}/files/INSTALLATION')
      ..createSync(recursive: true)
      ..writeAsStringSync('id');
    final missing = Directory('${root.path}/cache/io.sentry');

    await deleteUnsentCrashReports(
      caches: () async => [cache, installation, missing],
    );

    expect(cache.existsSync(), isFalse);
    expect(installation.existsSync(), isFalse);
    await deleteUnsentCrashReports(caches: () async => throw StateError('x'));
  });

  test("the native SDKs' folders: on iOS the install id and the crash "
      "handler's reports too", () async {
    Future<Directory> cache() async => Directory('/c');
    Future<Directory> support() async => Directory('/s');
    Future<List<String>> paths(TargetPlatform platform) async => [
      for (final entity in await crashReportCaches(
        platform: platform,
        cache: cache,
        support: support,
      ))
        '${entity is Directory ? 'dir' : 'file'} ${entity.path}',
    ];

    expect(await paths(TargetPlatform.android), [
      'dir /c/sentry',
      'file /s/INSTALLATION',
    ]);
    expect(await paths(TargetPlatform.iOS), [
      'dir /c/io.sentry',
      'dir /c/SentryCrash',
      'file /c/INSTALLATION',
    ]);
    expect(await paths(TargetPlatform.macOS), isEmpty);
  });
}

/// Notes what the other options were when the DSN was set;
/// [failingNativeSwitch] makes iOS's watchdog switch throw.
final class _RecordingOptions extends SentryFlutterOptions {
  new({this.failingNativeSwitch = false}) {
    addIntegration(_ScreenshotIntegration());
  }

  final bool failingNativeSwitch;
  bool? autoInitializeNativeSdkWhenDsnSet;
  bool? nativeCrashHandlingWhenDsnSet;
  List<String>? integrationsWhenDsnSet;

  @override
  set enableWatchdogTerminationTracking(bool value) {
    if (failingNativeSwitch) throw StateError('a setter that throws');
    super.enableWatchdogTerminationTracking = value;
  }

  @override
  set dsn(String? value) {
    autoInitializeNativeSdkWhenDsnSet = autoInitializeNativeSdk;
    nativeCrashHandlingWhenDsnSet = enableNativeCrashHandling;
    integrationsWhenDsnSet = [
      for (final integration in integrations) '${integration.runtimeType}',
    ];
    super.dsn = value;
  }
}

/// Keeps every envelope Sentry would send.
final class _KeptEnvelopes implements Transport {
  new(this._options);

  final SentryOptions _options;
  final sent = <String>[];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    final bytes = <int>[];
    await envelope.envelopeStream(_options).forEach(bytes.addAll);
    sent.add(String.fromCharCodes(bytes));
    return SentryId.newId();
  }
}

/// Stands for an integration a later Sentry version adds.
final class _ScreenshotIntegration implements Integration<SentryOptions> {
  @override
  void call(Hub hub, SentryOptions options) {}

  @override
  void close() {}
}
