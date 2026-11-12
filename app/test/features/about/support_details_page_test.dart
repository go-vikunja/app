import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/files/link_share_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/features/about/application/support_details.dart';
import 'package:vikunja_mobile/features/about/presentation/support_details_page.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/team_sharing_fakes.dart';

final _snapshot = SupportSnapshot(
  createdAt: DateTime.utc(2026, 11, 12, 14, 3),
  device: const DeviceSupport(
    platform: 'android',
    app: Collected((version: '1.0.0', build: '42')),
    osVersion: Collected('14'),
    deviceLocale: Collected('en_GB'),
    notifications: Collected.unknown(),
    background: Collected.unknown(),
    lastBackgroundRun: Collected(null),
  ),
  accounts: Collected([
    AccountSupport(
      isGuest: false,
      active: true,
      needsSignIn: false,
      server: Uri.parse('https://tasks.example.org/vikunja'),
      serverVersion: '2.8.0',
      tier: SupportTier.full,
      apiVersions: const {ApiVersion.v1, ApiVersion.v2},
      apiV2Missing: false,
      features: const {Capability.apiV2},
      syncTimes: const Collected((last: null, full: null)),
      syncInSession: const Collected(null),
      sendingInSession: const Collected(null),
      backgroundTurn: const Collected((started: null, synced: null)),
      queue: const Collected.unknown(),
      notifications: const Collected(NotificationPreferences()),
      lastSessionEnd: const Collected(null),
    ),
  ]),
);

void main() {
  late FakeLinkShareActions actions;

  setUp(() => actions = FakeLinkShareActions());

  Future<void> pumpPage(
    WidgetTester tester, {
    Future<SupportSnapshot>? snapshot,
  }) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportSnapshotProvider.overrideWith(
            (ref) => snapshot ?? Future.value(_snapshot),
          ),
          linkShareActionsProvider.overrideWithValue(actions),
        ],
        child: const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: SupportDetailsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder details() => find.textContaining('Support details\nCreated:');

  String shownText(WidgetTester tester) => tester.widget<Text>(details()).data!;

  TextButton share(WidgetTester tester) => tester.widget<TextButton>(
    find.widgetWithText(TextButton, en.supportDetailsShare),
  );

  testWidgets('shows the details without the server address until the '
      'switch asks for it', (tester) async {
    await pumpPage(tester);

    expect(find.text(en.supportDetailsIntro), findsOneWidget);
    expect(shownText(tester), contains('Server: <server-1>\n'));
    expect(shownText(tester), isNot(contains('tasks.example.org')));

    await tester.tap(find.text(en.supportDetailsShowServers));
    await tester.pumpAndSettle();

    expect(
      shownText(tester),
      contains('Server: https://tasks.example.org/vikunja\n'),
    );
  });

  testWidgets('the text is not selectable', (tester) async {
    await pumpPage(tester);

    expect(details(), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    expect(find.byType(SelectionArea), findsNothing);
  });

  testWidgets('Share hands the text as shown to the share sheet, with the '
      'title as its subject', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text(en.supportDetailsShowServers));
    await tester.pumpAndSettle();

    await tester.tap(find.text(en.supportDetailsShare));
    await tester.pumpAndSettle();

    final shared = actions.sharedTexts.single;
    expect(shared.text, startsWith(shownText(tester)));
    expect(shared.text, contains('https://tasks.example.org/vikunja'));
    expect(shared.subject, en.supportDetailsTitle);
    expect(actions.shared, isEmpty);
  });

  testWidgets('while the details are collected, Share waits', (tester) async {
    final snapshot = Completer<SupportSnapshot>();
    usePhoneSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportSnapshotProvider.overrideWith((ref) => snapshot.future),
          linkShareActionsProvider.overrideWithValue(actions),
        ],
        child: const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: SupportDetailsPage(),
        ),
      ),
    );
    await pumpFrames(tester, 2);

    expect(share(tester).onPressed, isNull);
    expect(find.bySemanticsLabel(en.supportDetailsTitle), findsWidgets);
    expect(details(), findsNothing);

    snapshot.complete(_snapshot);
    await tester.pumpAndSettle();

    expect(share(tester).onPressed, isNotNull);
    expect(details(), findsOneWidget);
  });

  testWidgets('a share sheet that is missing says so', (tester) async {
    actions.available = false;
    await pumpPage(tester);

    await tester.tap(find.text(en.supportDetailsShare));
    await tester.pumpAndSettle();

    expect(find.text(en.shareFailureGeneric), findsOneWidget);
  });
}
