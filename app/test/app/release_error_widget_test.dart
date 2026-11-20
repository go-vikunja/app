import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/widgets/release_error_widget.dart';
import 'package:vikunja_mobile/core/logging/diagnostics_log.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/features/about/application/support_details.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations_en.dart';

import '../helpers/pump_app.dart';

class _Failing extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => throw StateError('TITLE-MARKER');
}

// Texts whose error widget message cannot be built.
final class _BrokenTexts extends AppLocalizationsEn {
  @override
  String get errorWidgetMessage => throw StateError('no text');
}

final class _BrokenTextsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const new();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(_BrokenTexts());

  @override
  bool shouldReload(_BrokenTextsDelegate old) => false;
}

final _snapshot = SupportSnapshot(
  createdAt: DateTime.utc(2026, 11, 18, 9),
  device: const DeviceSupport(
    platform: 'android',
    app: Collected((version: '1.0.0', build: '42')),
    osVersion: Collected('16'),
    deviceLocale: Collected('en_US'),
    notifications: Collected.unknown(),
    background: Collected.unknown(),
    lastBackgroundRun: Collected(null),
  ),
  accounts: Collected([
    AccountSupport(
      id: 'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1',
      isGuest: false,
      active: true,
      needsSignIn: false,
      server: Uri.parse('https://tasks.example.org'),
      serverVersion: '2.8.0',
      tier: SupportTier.full,
      apiVersions: const {ApiVersion.v1},
      apiV2Missing: false,
      features: const {},
      syncTimes: const Collected.unknown(),
      syncInSession: const Collected(null),
      sendingInSession: const Collected(null),
      backgroundTurn: const Collected.unknown(),
      queue: const Collected.unknown(),
      notifications: const Collected.unknown(),
      lastSessionEnd: const Collected(null),
      sessionEndDiagnosis: const Collected(null),
    ),
  ]),
  log: Collected([
    DiagnosticsEntry(
      at: DateTime.utc(2026, 11, 18, 8, 59, 58),
      part: 'app',
      level: 'SEVERE',
      logger: 'Flutter',
      message: 'Uncaught error (widgets library)',
      error: 'StateError',
    ),
  ]),
);

void main() {
  late List<String> copied;

  setUp(() => copied = []);

  void mockClipboard(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

  // flutter_test checks that the builder is back before the tear-downs run.
  Future<void> inRelease(Future<void> Function() body) async {
    final before = ErrorWidget.builder;
    installErrorWidget(debug: false);
    try {
      await body();
    } finally {
      ErrorWidget.builder = before;
    }
  }

  Future<void> pumpInApp(WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportSnapshotProvider.overrideWith((ref) async => _snapshot),
        ],
        child: const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                Text('Above'),
                SizedBox(height: 120, child: _Failing()),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isA<StateError>());
  }

  test("a debug build keeps Flutter's error widget", () {
    final before = ErrorWidget.builder;
    try {
      installErrorWidget();

      expect(ErrorWidget.builder, same(before));
    } finally {
      ErrorWidget.builder = before;
    }
  });

  testWidgets('in release, a widget that fails to build shows a short '
      'message and Copy support details instead of a grey box', (tester) async {
    final semantics = tester.ensureSemantics();
    await inRelease(() async {
      await pumpInApp(tester);

      expect(find.byType(ReleaseErrorWidget), findsOneWidget);
      expect(find.text(en.errorWidgetMessage), findsOneWidget);
      expect(find.text(en.errorWidgetCopySupportDetails), findsOneWidget);
      expect(find.textContaining('TITLE-MARKER'), findsNothing);
      expect(find.text('Above'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
    semantics.dispose();
  });

  testWidgets('Copy support details copies the text the support details '
      'page shows, servers hidden, and says it did', (tester) async {
    mockClipboard(tester);
    await inRelease(() async {
      await pumpInApp(tester);

      await tester.tap(find.text(en.errorWidgetCopySupportDetails));
      await tester.pumpAndSettle();

      expect(copied, [
        renderSupportDetails(_snapshot, showServers: false, appLanguage: 'en'),
      ]);
      expect(copied.single, contains('Server: <server-1>\n'));
      expect(copied.single, isNot(contains('tasks.example.org')));
      expect(copied.single, contains('  error: StateError\n'));
      expect(find.text(en.copiedToClipboard), findsOneWidget);
    });
  });

  testWidgets('without the app around it, it still shows in English and '
      "copies this isolate's log", (tester) async {
    mockClipboard(tester);
    final log = DiagnosticsLog(
      part: AppPart.app,
      directory: () async => null,
      now: () => DateTime.utc(2026, 11, 18, 9),
    )..add(LogRecord(Level.SEVERE, 'Probe failed', 'Probe'));
    useDiagnosticsLog(log);
    addTearDown(() => useDiagnosticsLog(null));
    await inRelease(() async {
      usePhoneSurface(tester);
      await tester.pumpWidget(const _Failing());
      expect(tester.takeException(), isA<StateError>());

      expect(find.text(en.errorWidgetMessage), findsOneWidget);
      await tester.tap(find.text(en.errorWidgetCopySupportDetails));
      await tester.pumpAndSettle();

      expect(copied.single, contains('\nAccounts: unknown\n'));
      expect(
        copied.single,
        contains('2026-11-18 09:00:00 UTC [app] SEVERE Probe: Probe failed\n'),
      );
      expect(find.text(en.copiedToClipboard), findsOneWidget);
    });
  });

  testWidgets("a failure within the message falls back to Flutter's error "
      'widget instead of nesting the message without end', (tester) async {
    await inRelease(() async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        Localizations(
          locale: const Locale('en'),
          delegates: const [
            DefaultWidgetsLocalizations.delegate,
            _BrokenTextsDelegate(),
          ],
          child: const _Failing(),
        ),
      );
      // The widget's own failure, then the message's: two, not endless.
      expect(tester.takeException(), contains('Multiple exceptions (2)'));

      expect(find.byType(ReleaseErrorWidget), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ReleaseErrorWidget),
          matching: find.byType(ErrorWidget),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('a failed copy says so', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.setData'
          ? throw PlatformException(code: 'no_clipboard')
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await inRelease(() async {
      await pumpInApp(tester);

      await tester.tap(find.text(en.errorWidgetCopySupportDetails));
      await tester.pumpAndSettle();

      expect(find.text(en.copyToClipboardFailed), findsOneWidget);
    });
  });
}
