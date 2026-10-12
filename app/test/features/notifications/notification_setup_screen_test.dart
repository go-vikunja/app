import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/home/presentation/home_shell.dart';
import 'package:vikunja_mobile/features/notifications/application/notifications_onboarding.dart';
import 'package:vikunja_mobile/features/notifications/presentation/notification_setup_screen.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/notification_ui_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

const granted = NotificationCapabilities(
  permission: NotificationPermission.granted,
  exactAlarms: true,
);
const grantedInexact = NotificationCapabilities(
  permission: NotificationPermission.granted,
  exactAlarms: false,
);
const notAsked = NotificationCapabilities(
  permission: NotificationPermission.notAsked,
  exactAlarms: false,
);
const denied = NotificationCapabilities(
  permission: NotificationPermission.denied,
  exactAlarms: false,
);

void main() {
  late AuthFakes auth;
  late NotificationFakes notifications;

  setUp(() {
    auth = AuthFakes(notificationsOnboarded: false);
    notifications = NotificationFakes(capabilities: notAsked)
      ..answerRequestWith(granted);
  });

  GoRouter routerOf(WidgetTester tester) =>
      containerOf(tester).read(appRouterProvider);

  String location(WidgetTester tester) =>
      routerOf(tester).state.matchedLocation;

  bool onboarded() =>
      auth.preferences.values[notificationsOnboardedKey] == 'true';

  Future<void> pumpSetup(WidgetTester tester, {SyncFakes? sync}) async {
    await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    await pumpVikunjaApp(
      tester,
      auth: auth,
      sync: sync,
      notifications: notifications,
    );
  }

  /// The buttons sit below the fold on the default test surface.
  Future<void> tapButton(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> resume(WidgetTester tester) async {
    [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
    await tester.pumpAndSettle();
  }

  testWidgets('a synced account that was never onboarded opens the setup', (
    tester,
  ) async {
    await pumpSetup(tester);

    expect(location(tester), AppRoutes.notificationsSetup);
    expect(find.byType(NotificationSetupScreen), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
    expect(find.text(en.notificationSetupTitle), findsOneWidget);
    expect(find.text(en.notificationSetupReminders), findsOneWidget);
    expect(find.text(en.notificationSetupDueDates), findsOneWidget);
    expect(find.text(en.notificationSetupOnlyYours), findsOneWidget);
    expect(notifications.calls('requestPermission'), 0);
  });

  testWidgets('Turn on asks for the permission, then opens the shell', (
    tester,
  ) async {
    await pumpSetup(tester);

    await tapButton(tester, en.notificationSetupTurnOn);

    expect(notifications.calls('requestPermission'), 1);
    expect(notifications.calls('initialize'), greaterThan(0));
    expect(onboarded(), isTrue);
    expect(location(tester), AppRoutes.overview);
    expect(find.byType(HomeShell), findsOneWidget);
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));

  testWidgets('a denied permission still finishes the setup', (tester) async {
    notifications.answerRequestWith(denied);
    await pumpSetup(tester);

    await tapButton(tester, en.notificationSetupTurnOn);

    expect(onboarded(), isTrue);
    expect(location(tester), AppRoutes.overview);
  }, variant: const TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('a request the plugin refuses still finishes the setup', (
    tester,
  ) async {
    notifications.gateway.beforeCall = (call) async {
      if (call == 'requestPermission') throw StateError('in progress');
    };
    await pumpSetup(tester);

    await tapButton(tester, en.notificationSetupTurnOn);

    expect(notifications.calls('requestPermission'), 1);
    expect(onboarded(), isTrue);
    expect(location(tester), AppRoutes.overview);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Not now skips the request and opens the shell', (tester) async {
    await pumpSetup(tester);

    await tapButton(tester, en.notificationSetupNotNow);

    expect(notifications.calls('requestPermission'), 0);
    expect(onboarded(), isTrue);
    expect(location(tester), AppRoutes.overview);
  });

  testWidgets('the setup is shown only once', (tester) async {
    await pumpSetup(tester);
    await tapButton(tester, en.notificationSetupNotNow);

    routerOf(tester).go(AppRoutes.notificationsSetup);
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.overview);
    expect(find.byType(NotificationSetupScreen), findsNothing);
  });

  testWidgets('an onboarded device opens the shell', (tester) async {
    auth = AuthFakes();
    await pumpSetup(tester);

    expect(location(tester), AppRoutes.overview);
    expect(find.byType(NotificationSetupScreen), findsNothing);
  });

  testWidgets('the setup waits for the first sync', (tester) async {
    final sync = SyncFakes(status: const SyncNeverRun());
    final firstSync = Completer<void>();
    sync.engine.onEnsureInitialSync = () => firstSync.future;
    await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    await pumpVikunjaApp(
      tester,
      auth: auth,
      sync: sync,
      notifications: notifications,
      settle: false,
    );
    await pumpUntil(tester, find.byType(FirstSyncScreen));
    expect(location(tester), AppRoutes.firstSync);

    firstSync.complete();
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.notificationsSetup);
    expect(find.byType(NotificationSetupScreen), findsOneWidget);

    await tapButton(tester, en.notificationSetupNotNow);
    expect(location(tester), AppRoutes.overview);
  });

  group('exact alarms on Android', () {
    setUp(() => notifications.answerRequestWith(grantedInexact));

    testWidgets('a second step explains them and opens the setting', (
      tester,
    ) async {
      await pumpSetup(tester);

      await tapButton(tester, en.notificationSetupTurnOn);

      expect(onboarded(), isFalse);
      expect(location(tester), AppRoutes.notificationsSetup);
      expect(find.text(en.notificationSetupExactTitle), findsOneWidget);
      expect(find.text(en.notificationSetupExactBody), findsOneWidget);
      expect(find.text(en.notificationSetupReminders), findsNothing);

      await tapButton(tester, en.notificationSetupExactAllow);
      expect(notifications.calls('openExactAlarmSettings'), 1);
      expect(location(tester), AppRoutes.notificationsSetup);
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('continues when the app resumes with exact alarms allowed', (
      tester,
    ) async {
      await pumpSetup(tester);
      await tapButton(tester, en.notificationSetupTurnOn);
      await tapButton(tester, en.notificationSetupExactAllow);

      notifications.gateway.current = granted;
      await resume(tester);

      expect(onboarded(), isTrue);
      expect(location(tester), AppRoutes.overview);
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('stays when the app resumes without them', (tester) async {
      await pumpSetup(tester);
      await tapButton(tester, en.notificationSetupTurnOn);

      await resume(tester);

      expect(onboarded(), isFalse);
      expect(find.text(en.notificationSetupExactTitle), findsOneWidget);
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('Skip opens the shell', (tester) async {
      await pumpSetup(tester);
      await tapButton(tester, en.notificationSetupTurnOn);

      await tapButton(tester, en.notificationSetupSkip);

      expect(onboarded(), isTrue);
      expect(location(tester), AppRoutes.overview);
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('iOS has no exact-alarm step', (tester) async {
      await pumpSetup(tester);

      await tapButton(tester, en.notificationSetupTurnOn);

      expect(onboarded(), isTrue);
      expect(location(tester), AppRoutes.overview);
    }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));
  });

  testWidgets('in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await pumpSetup(tester);

    expect(find.text(de.notificationSetupTitle), findsOneWidget);
    expect(find.text(de.notificationSetupTurnOn), findsOneWidget);
    expect(find.text(de.notificationSetupNotNow), findsOneWidget);
  });
}
