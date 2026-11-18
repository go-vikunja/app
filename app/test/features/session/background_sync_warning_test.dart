import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/platform/app_settings_page.dart';
import 'package:vikunja_mobile/core/platform/background_permissions.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';
import 'package:vikunja_mobile/features/notifications/presentation/notification_setup_screen.dart';
import 'package:vikunja_mobile/features/session/application/background_restriction.dart';
import 'package:vikunja_mobile/features/session/presentation/background_sync_warning.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/guest_app.dart';
import '../../helpers/notification_ui_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

final class _Background implements BackgroundPermissions {
  new(this.state);

  BackgroundState state;

  @override
  Future<BackgroundState> read() async => state;
}

final class _SettingsPage implements AppSettingsPage {
  int opened = 0;
  bool opens = true;

  @override
  Future<bool> open() async {
    opened++;
    return opens;
  }
}

const _restricted = <(String, BackgroundState, BackgroundRestriction)>[
  (
    'iOS: Background App Refresh denied',
    BackgroundState(backgroundRefresh: 'denied', lowPowerMode: false),
    BackgroundRestriction.refreshOff,
  ),
  (
    'iOS: Background App Refresh restricted',
    BackgroundState(backgroundRefresh: 'restricted'),
    BackgroundRestriction.refreshRestricted,
  ),
  (
    'Android: background restricted',
    BackgroundState(
      ignoresBatteryOptimizations: false,
      backgroundRestricted: true,
      standbyBucket: 'active',
    ),
    BackgroundRestriction.restricted,
  ),
  (
    'Android: the restricted standby bucket',
    BackgroundState(backgroundRestricted: false, standbyBucket: 'restricted'),
    BackgroundRestriction.restricted,
  ),
];

const _unrestricted = <(String, BackgroundState)>[
  ('nothing known', BackgroundState()),
  (
    'iOS: available, in Low Power Mode',
    BackgroundState(backgroundRefresh: 'available', lowPowerMode: true),
  ),
  (
    'iOS: denied while in Low Power Mode, which turns it off for every app',
    BackgroundState(backgroundRefresh: 'denied', lowPowerMode: true),
  ),
  ('iOS: unknown', BackgroundState(backgroundRefresh: 'unknown')),
  (
    'Android: battery optimised, battery saver on, a rare bucket',
    BackgroundState(
      ignoresBatteryOptimizations: false,
      powerSaveMode: true,
      backgroundRestricted: false,
      standbyBucket: 'rare',
    ),
  ),
  ('Android: an unknown bucket', BackgroundState(standbyBucket: 'other')),
];

void main() {
  group('backgroundRestrictionOf', () {
    for (final (name, state, restriction) in _restricted) {
      test(name, () => expect(backgroundRestrictionOf(state), restriction));
    }
    for (final (name, state) in _unrestricted) {
      test('none: $name', () => expect(backgroundRestrictionOf(state), null));
    }
    test('only a restriction by policy has no setting to change', () {
      expect(BackgroundRestriction.refreshOff.hasSetting, isTrue);
      expect(BackgroundRestriction.restricted.hasSetting, isTrue);
      expect(BackgroundRestriction.refreshRestricted.hasSetting, isFalse);
    });
  });

  group('in the Account tab', () {
    late _Background background;
    late _SettingsPage settings;

    List<Override> overrides() => [
      backgroundPermissionsProvider.overrideWithValue(background),
      appSettingsPageProvider.overrideWithValue(settings),
    ];

    Future<void> pumpAccountTab(WidgetTester tester) async {
      usePhoneSurface(tester, logicalSize: const Size(360, 3000));
      await pumpSignedInApp(tester, overrides: overrides());
      await openTab(tester, en.tabAccount);
    }

    setUp(() {
      background = _Background(const BackgroundState());
      settings = _SettingsPage();
    });

    for (final (name, state, restriction) in _restricted) {
      testWidgets('shows for $name', (tester) async {
        background.state = state;
        await pumpAccountTab(tester);

        expect(find.text(en.backgroundSyncLimitedTitle), findsOneWidget);
        expect(
          find.text(switch (restriction) {
            BackgroundRestriction.restricted => en.backgroundSyncLimitedAndroid,
            _ => en.backgroundSyncLimitedIos,
          }),
          findsOneWidget,
        );
        final button = find.widgetWithText(
          TextButton,
          en.backgroundSyncOpenSettings,
        );
        if (!restriction.hasSetting) {
          expect(button, findsNothing);
          return;
        }
        await tester.tap(button);
        await tester.pump();
        expect(settings.opened, 1);
      });
    }

    for (final (name, state) in _unrestricted) {
      testWidgets('nothing for $name', (tester) async {
        background.state = state;
        await pumpAccountTab(tester);

        expect(find.text(en.accountSyncNow), findsOneWidget);
        expect(find.byType(BackgroundSyncWarning), findsOneWidget);
        expect(find.text(en.backgroundSyncLimitedTitle), findsNothing);
      });
    }

    testWidgets('says so when the settings do not open', (tester) async {
      background.state = const BackgroundState(backgroundRestricted: true);
      settings.opens = false;
      await pumpAccountTab(tester);

      await tester.tap(
        find.widgetWithText(TextButton, en.backgroundSyncOpenSettings),
      );
      await tester.pump();

      expect(settings.opened, 1);
      expect(
        find.widgetWithText(SnackBar, en.backgroundSyncSettingsNotOpened),
        findsOneWidget,
      );
    });

    testWidgets('read again when the app comes back from the settings', (
      tester,
    ) async {
      background.state = const BackgroundState(backgroundRefresh: 'denied');
      await pumpAccountTab(tester);
      expect(find.text(en.backgroundSyncLimitedTitle), findsOneWidget);

      background.state = const BackgroundState(backgroundRefresh: 'available');
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text(en.backgroundSyncLimitedTitle), findsNothing);
    });

    testWidgets('nothing for a guest alone, whose session signs in again by '
        'itself', (tester) async {
      background.state = const BackgroundState(backgroundRefresh: 'denied');
      usePhoneSurface(tester, logicalSize: const Size(360, 3000));
      await pumpGuestApp(
        tester,
        auth: AuthFakes(),
        data: SyncFakes(),
        overrides: overrides(),
      );
      await openTab(tester, en.tabAccount);

      expect(find.text(en.accountSyncNow), findsOneWidget);
      expect(find.text(en.backgroundSyncLimitedTitle), findsNothing);
    });
  });

  testWidgets('on the notification setup step, with the way to the settings', (
    tester,
  ) async {
    final auth = AuthFakes(notificationsOnboarded: false);
    final settings = _SettingsPage();
    await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    await pumpVikunjaApp(
      tester,
      auth: auth,
      notifications: NotificationFakes(
        capabilities: const NotificationCapabilities(
          permission: NotificationPermission.notAsked,
          exactAlarms: true,
        ),
      ),
      overrides: [
        backgroundPermissionsProvider.overrideWithValue(
          _Background(const BackgroundState(backgroundRestricted: true)),
        ),
        appSettingsPageProvider.overrideWithValue(settings),
      ],
    );

    expect(find.byType(NotificationSetupScreen), findsOneWidget);
    expect(find.text(en.backgroundSyncLimitedAndroid), findsOneWidget);
    await tester.ensureVisible(find.text(en.backgroundSyncOpenSettings));
    await tester.tap(find.text(en.backgroundSyncOpenSettings));
    await tester.pump();
    expect(settings.opened, 1);
  });

  group('the app settings page', () {
    const channel = MethodChannel('io.vikunja.app/device');
    late List<MethodCall> calls;
    late Object? Function(MethodCall call) answer;

    setUp(() {
      calls = [];
      answer = (_) => true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return answer(call);
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
    });

    PlatformAppSettingsPage page({bool mobile = true}) =>
        PlatformAppSettingsPage(
          excursions: AppExcursions(now: DateTime.now),
          mobile: mobile,
        );

    testWidgets('asks the device channel to open it', (tester) async {
      expect(await page().open(), isTrue);
      expect(calls.single.method, 'openAppSettings');
    });

    testWidgets('a refusal or an error is false, never thrown', (tester) async {
      answer = (_) => false;
      expect(await page().open(), isFalse);
      answer = (_) => throw PlatformException(code: 'gone');
      expect(await page().open(), isFalse);
    });

    testWidgets('not asked off a phone', (tester) async {
      expect(await page(mobile: false).open(), isFalse);
      expect(calls, isEmpty);
    });
  });
}
