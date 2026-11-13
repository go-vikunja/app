import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/session_labels.dart';

import '../../helpers/account_security_fakes.dart';
import '../../helpers/announcer_region.dart';
import '../../helpers/pump_app.dart';
import 'security_harness.dart';

void main() {
  late SecurityHarness harness;

  setUp(() => harness = SecurityHarness());

  Future<void> pumpPage(WidgetTester tester) =>
      harness.pump(tester, location: AppRoutes.accountSessions);

  const android = 'Vikunja app 0.31.0 · Android 15';
  const firefox = 'Firefox on Linux';

  Finder rowOf(String device) => find.widgetWithText(ListTile, device);

  Future<void> endFromMenu(WidgetTester tester, String device) async {
    await tester.tap(find.byTooltip(en.sessionsOptionsFor(device)));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text(en.sessionsEnd),
        matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text(label)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists where the account is signed in, newest active first, '
      'this device tagged and without an end', (tester) async {
    await pumpPage(tester);

    expect(find.text(en.sessionsIntro), findsOneWidget);
    final devices = [android, firefox, en.sessionsDartClient];
    final tops = [
      for (final device in devices) tester.getTopLeft(rowOf(device)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(
      find.descendant(
        of: rowOf(android),
        matching: find.text(en.sessionsThisDevice),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip(en.sessionsOptionsFor(android)), findsNothing);
    expect(find.byTooltip(en.sessionsOptionsFor(firefox)), findsOneWidget);
    expect(find.text('198.51.100.23'), findsOneWidget);
    expect(find.textContaining('Last active'), findsNWidgets(3));
  });

  testWidgets('ends another session after asking', (tester) async {
    await pumpPage(tester);

    await endFromMenu(tester, firefox);
    expect(find.text(en.sessionsEndBody(firefox)), findsOneWidget);
    await confirm(tester, en.cancel);
    expect(harness.security.revoked, isEmpty);

    await endFromMenu(tester, firefox);
    await confirm(tester, en.sessionsEnd);

    expect(harness.security.revoked, [fakeWebSessionId]);
    expect(rowOf(firefox), findsNothing);
    expect(rowOf(android), findsOneWidget);
  });

  testWidgets("a session's details say when it signed in; this device's "
      'points to signing out', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text(firefox));
    await tester.pumpAndSettle();
    expect(find.text(en.sessionsSignedIn), findsOneWidget);
    expect(find.textContaining('Firefox/140.0'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, en.sessionsEnd));
    await tester.pumpAndSettle();
    await confirm(tester, en.sessionsEnd);
    expect(harness.security.revoked, [fakeWebSessionId]);

    await tester.tap(find.text(android));
    await tester.pumpAndSettle();
    expect(find.text(en.sessionsThisDeviceHint), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, en.sessionsEnd), findsNothing);
  });

  testWidgets('ends all other sessions, then only this device is left', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.text(en.sessionsEndOthers));
    await tester.pumpAndSettle();
    expect(find.text(en.sessionsEndOthersBody(2)), findsOneWidget);
    await confirm(tester, en.sessionsEndOthers);

    expect(harness.security.revoked, [fakeWebSessionId, fakeScriptSessionId]);
    expect(rowOf(android), findsOneWidget);
    expect(rowOf(firefox), findsNothing);
    expect(find.text(en.sessionsNoOthers), findsOneWidget);
    expect(find.text(en.sessionsEndOthers), findsNothing);
  });

  testWidgets('without platform announcements, as on Android, the end of '
      'the other sessions is said by the live region once the dialog closed', (
    tester,
  ) async {
    useLiveRegionAnnouncements(tester);
    await pumpPage(tester);

    await tester.tap(find.text(en.sessionsEndOthers));
    await tester.pumpAndSettle();
    await confirm(tester, en.sessionsEndOthers);

    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeAnnouncements(), isEmpty);
    expect(announcerRegion(tester)?.label, en.sessionsEndedOthers(2));
  });

  testWidgets('ending all others that stops halfway says how far it got', (
    tester,
  ) async {
    harness.security.revokeFailures[fakeScriptSessionId] = const NetworkFailure(
      NetworkProblem.unreachable,
    );
    await pumpPage(tester);

    await tester.tap(find.text(en.sessionsEndOthers));
    await tester.pumpAndSettle();
    await confirm(tester, en.sessionsEndOthers);

    expect(
      find.text(
        '${en.sessionsNotAllEnded(1, 1)} ${en.accountSecurityNeedsConnection}',
      ),
      findsOneWidget,
    );
    expect(rowOf(firefox), findsNothing);
    expect(rowOf(en.sessionsDartClient), findsOneWidget);
  });

  testWidgets('a session that cannot be ended says why', (tester) async {
    harness.security.revokeFailures[fakeWebSessionId] = const NetworkFailure(
      NetworkProblem.timeout,
    );
    await pumpPage(tester);

    await endFromMenu(tester, firefox);
    await confirm(tester, en.sessionsEnd);

    expect(find.text(en.accountSecurityUnconfirmed), findsOneWidget);
    expect(rowOf(firefox), findsOneWidget);
  });

  testWidgets('offline it says so and a retry loads the list', (tester) async {
    harness.security.failures['sessions'] = const NetworkFailure(
      NetworkProblem.unreachable,
    );
    await pumpPage(tester);

    expect(find.text(en.dataFailureLoadTitle), findsOneWidget);
    expect(rowOf(android), findsNothing);

    harness.security.failures.remove('sessions');
    await tester.tap(find.text(en.retry));
    await tester.pumpAndSettle();

    expect(find.text(en.dataFailureLoadTitle), findsNothing);
    expect(rowOf(android), findsOneWidget);
  });

  testWidgets('pull to refresh reads the list again', (tester) async {
    await pumpPage(tester);
    harness.security.sessionList = harness.security.sessionList.sublist(0, 1);

    await tester.fling(find.text(en.sessionsIntro), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(rowOf(firefox), findsNothing);
    expect(find.text(en.sessionsNoOthers), findsOneWidget);
  });

  testWidgets('the refresh button reads the list again without a pull', (
    tester,
  ) async {
    await pumpPage(tester);
    harness.security.sessionList = harness.security.sessionList.sublist(0, 1);

    expect(tester.getSemantics(find.byTooltip(en.refresh)).tooltip, en.refresh);
    await tester.tap(find.byTooltip(en.refresh));
    await tester.pumpAndSettle();

    expect(rowOf(firefox), findsNothing);
    expect(find.text(en.sessionsNoOthers), findsOneWidget);
  });

  testWidgets('is in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await pumpPage(tester);

    expect(find.text(de.sessionsTitle), findsOneWidget);
    expect(find.text('Vikunja-App 0.31.0 · Android 15'), findsOneWidget);
    expect(find.text('Firefox unter Linux'), findsOneWidget);
    expect(find.text(de.sessionsThisDevice), findsOneWidget);
  });

  group('device lines', () {
    for (final (agent, line) in [
      ('Vikunja-App/0.31.0+31 (android 15)', android),
      ('Vikunja-App/1.0.0+100 (ios 18.1)', 'Vikunja app 1.0.0 · iOS 18.1'),
      ('Vikunja Mobile App', 'Vikunja Mobile App'),
      (
        'Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 '
            'Firefox/140.0',
        firefox,
      ),
      ('Dart/3.9 (dart:io)', 'An app without a name'),
      ('curl/8.4.0', 'curl/8.4.0'),
      ('', 'Unknown device'),
    ]) {
      test('"$agent" reads "$line"', () {
        expect(sessionDeviceLine(en, describeUserAgent(agent)), line);
      });
    }

    test('name this app in German', () {
      expect(
        sessionDeviceLine(
          de,
          describeUserAgent('Vikunja-App/1.0.0+100 (ios 18.1)'),
        ),
        'Vikunja-App 1.0.0 · iOS 18.1',
      );
    });

    test('name this app alone without a version or system', () {
      const device = DeviceDescription(
        kind: DeviceKind.vikunjaApp,
        raw: 'Vikunja-App',
      );

      expect(sessionDeviceLine(en, device), 'Vikunja app');
      expect(sessionDeviceLine(de, device), 'Vikunja-App');
    });

    test('show a phone for this app', () {
      for (final (agent, icon) in [
        ('Vikunja-App/0.31.0+31 (android 15)', Icons.phone_android),
        ('Vikunja-App/1.0.0+100 (ios 18.1)', Icons.phone_iphone),
      ]) {
        expect(sessionDeviceIcon(describeUserAgent(agent)), icon);
      }
    });
  });
}
